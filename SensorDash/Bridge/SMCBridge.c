#include "SMCBridge.h"
#include <string.h>
#include <stdio.h>

static uint32_t _strtoul(const char *str, int size, int base) {
    uint32_t total = 0;
    for (int i = 0; i < size; i++) {
        if (base == 16) {
            total += (unsigned char)str[i] << (size - 1 - i) * 8;
        } else {
            total += (unsigned char)str[i] << (size - 1 - i) * 8;
        }
    }
    return total;
}

static void _ultostr(char *str, uint32_t val) {
    str[0] = (char)(val >> 24);
    str[1] = (char)(val >> 16);
    str[2] = (char)(val >> 8);
    str[3] = (char)val;
    str[4] = '\0';
}

static kern_return_t SMCCall(io_connect_t conn, int index, SMCKeyData_t *inputStruct, SMCKeyData_t *outputStruct) {
    size_t inputSize = sizeof(SMCKeyData_t);
    size_t outputSize = sizeof(SMCKeyData_t);
    return IOConnectCallStructMethod(conn, index, inputStruct, inputSize, outputStruct, &outputSize);
}

static kern_return_t SMCGetKeyInfo(io_connect_t conn, uint32_t key, SMCKeyData_keyInfo_t *info) {
    SMCKeyData_t inputStruct = {0};
    SMCKeyData_t outputStruct = {0};

    inputStruct.key = key;
    inputStruct.data8 = SMC_CMD_READ_KEYINFO;

    kern_return_t result = SMCCall(conn, KERNEL_INDEX_SMC, &inputStruct, &outputStruct);
    if (result == KERN_SUCCESS) {
        *info = outputStruct.keyInfo;
    }
    return result;
}

kern_return_t SMCOpen(io_connect_t *conn) {
    io_service_t service = IOServiceGetMatchingService(
        kIOMainPortDefault,
        IOServiceMatching("AppleSMC")
    );
    if (service == 0) {
        return KERN_FAILURE;
    }
    kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, conn);
    IOObjectRelease(service);
    return result;
}

kern_return_t SMCClose(io_connect_t conn) {
    return IOServiceClose(conn);
}

kern_return_t SMCReadKey(io_connect_t conn, const char *key, SMCVal_t *val) {
    SMCKeyData_t inputStruct = {0};
    SMCKeyData_t outputStruct = {0};

    memset(val, 0, sizeof(SMCVal_t));
    strncpy(val->key, key, 4);
    val->key[4] = '\0';

    inputStruct.key = _strtoul(key, 4, 16);
    inputStruct.data8 = SMC_CMD_READ_KEYINFO;

    kern_return_t result = SMCCall(conn, KERNEL_INDEX_SMC, &inputStruct, &outputStruct);
    if (result != KERN_SUCCESS) return result;

    val->dataSize = outputStruct.keyInfo.dataSize;
    _ultostr(val->dataType, outputStruct.keyInfo.dataType);

    inputStruct.keyInfo.dataSize = val->dataSize;
    inputStruct.data8 = SMC_CMD_READ_BYTES;

    result = SMCCall(conn, KERNEL_INDEX_SMC, &inputStruct, &outputStruct);
    if (result != KERN_SUCCESS) return result;

    memcpy(val->bytes, outputStruct.bytes, sizeof(val->bytes));
    return KERN_SUCCESS;
}

double SMCGetTemperature(io_connect_t conn, const char *key) {
    SMCVal_t val;
    kern_return_t result = SMCReadKey(conn, key, &val);
    if (result != KERN_SUCCESS) return -1.0;

    if (val.dataSize == 2 && memcmp(val.dataType, "sp78", 4) == 0) {
        int16_t raw = (int16_t)((val.bytes[0] << 8) | val.bytes[1]);
        return raw / 256.0;
    }
    if (val.dataSize == 2 && memcmp(val.dataType, "flt ", 4) == 0) {
        // Some Apple Silicon Macs use flt type
        uint16_t raw = (uint16_t)((val.bytes[0] << 8) | val.bytes[1]);
        float *fp = (float *)&raw;
        return (double)*fp;
    }
    // Try interpreting as sp78 anyway for Apple Silicon
    if (val.dataSize == 2) {
        int16_t raw = (int16_t)((val.bytes[0] << 8) | val.bytes[1]);
        double temp = raw / 256.0;
        if (temp > -40.0 && temp < 200.0) return temp;
    }
    return -1.0;
}

int SMCGetFanCount(io_connect_t conn) {
    SMCVal_t val;
    kern_return_t result = SMCReadKey(conn, "FNum", &val);
    if (result != KERN_SUCCESS) return 0;
    return (int)val.bytes[0];
}

static int SMCGetFanValue(io_connect_t conn, int fanIndex, const char *suffix) {
    char key[5];
    snprintf(key, sizeof(key), "F%d%s", fanIndex, suffix);
    SMCVal_t val;
    kern_return_t result = SMCReadKey(conn, key, &val);
    if (result != KERN_SUCCESS) return 0;

    if (val.dataSize == 2 && memcmp(val.dataType, "fpe2", 4) == 0) {
        return (int)(((val.bytes[0] << 8) | val.bytes[1]) >> 2);
    }
    if (val.dataSize == 2 && memcmp(val.dataType, "fp4c", 4) == 0) {
        return (int)(((val.bytes[0] << 8) | val.bytes[1]) >> 4);
    }
    if (val.dataSize == 2) {
        return (int)(((val.bytes[0] << 8) | val.bytes[1]) >> 2);
    }
    return 0;
}

int SMCGetFanRPM(io_connect_t conn, int fanIndex) {
    return SMCGetFanValue(conn, fanIndex, "Ac");
}

int SMCGetFanMinRPM(io_connect_t conn, int fanIndex) {
    return SMCGetFanValue(conn, fanIndex, "Mn");
}

int SMCGetFanMaxRPM(io_connect_t conn, int fanIndex) {
    return SMCGetFanValue(conn, fanIndex, "Mx");
}

double SMCGetPower(io_connect_t conn, const char *key) {
    SMCVal_t val;
    kern_return_t result = SMCReadKey(conn, key, &val);
    if (result != KERN_SUCCESS) return -1.0;

    if (val.dataSize == 2 && memcmp(val.dataType, "sp78", 4) == 0) {
        int16_t raw = (int16_t)((val.bytes[0] << 8) | val.bytes[1]);
        return raw / 256.0;
    }
    if (val.dataSize == 4) {
        // flt type (float32)
        uint32_t raw = ((uint32_t)val.bytes[0] << 24) | ((uint32_t)val.bytes[1] << 16) |
                       ((uint32_t)val.bytes[2] << 8) | (uint32_t)val.bytes[3];
        float f;
        memcpy(&f, &raw, sizeof(float));
        return (double)f;
    }
    if (val.dataSize == 2) {
        uint16_t raw = (uint16_t)((val.bytes[0] << 8) | val.bytes[1]);
        return raw / 256.0;
    }
    return -1.0;
}

uint32_t SMCGetKeyCount(io_connect_t conn) {
    SMCVal_t val;
    kern_return_t result = SMCReadKey(conn, "#KEY", &val);
    if (result != KERN_SUCCESS) return 0;
    return ((uint32_t)val.bytes[0] << 24) | ((uint32_t)val.bytes[1] << 16) |
           ((uint32_t)val.bytes[2] << 8) | (uint32_t)val.bytes[3];
}

bool SMCKeyExists(io_connect_t conn, const char *key) {
    SMCVal_t val;
    return SMCReadKey(conn, key, &val) == KERN_SUCCESS && val.dataSize > 0;
}
