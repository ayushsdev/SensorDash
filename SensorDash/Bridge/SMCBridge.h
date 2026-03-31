#ifndef SMCBridge_h
#define SMCBridge_h

#include <stdint.h>
#include <stdbool.h>
#include <IOKit/IOKitLib.h>

// SMC data types
typedef struct {
    char major;
    char minor;
    char build;
    char reserved;
    uint16_t release;
} SMCKeyData_vers_t;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
    uint32_t dataSize;
    uint32_t dataType;
    uint8_t  dataAttributes;
} SMCKeyData_keyInfo_t;

typedef struct {
    uint32_t            key;
    SMCKeyData_vers_t   vers;
    SMCKeyData_pLimitData_t pLimitData;
    SMCKeyData_keyInfo_t keyInfo;
    uint8_t             result;
    uint8_t             status;
    uint8_t             data8;
    uint32_t            data32;
    uint8_t             bytes[32];
} SMCKeyData_t;

typedef struct {
    char key[5];
    uint32_t dataSize;
    char dataType[5];
    uint8_t bytes[32];
} SMCVal_t;

// SMC kernel selectors
#define KERNEL_INDEX_SMC 2

// SMC commands
#define SMC_CMD_READ_BYTES  5
#define SMC_CMD_WRITE_BYTES 6
#define SMC_CMD_READ_INDEX  8
#define SMC_CMD_READ_KEYINFO 9
#define SMC_CMD_READ_PLIMIT 11
#define SMC_CMD_READ_VERS   12

// Public C functions
kern_return_t SMCOpen(io_connect_t *conn);
kern_return_t SMCClose(io_connect_t conn);
kern_return_t SMCReadKey(io_connect_t conn, const char *key, SMCVal_t *val);
double SMCGetTemperature(io_connect_t conn, const char *key);
int SMCGetFanCount(io_connect_t conn);
int SMCGetFanRPM(io_connect_t conn, int fanIndex);
int SMCGetFanMinRPM(io_connect_t conn, int fanIndex);
int SMCGetFanMaxRPM(io_connect_t conn, int fanIndex);
double SMCGetPower(io_connect_t conn, const char *key);
uint32_t SMCGetKeyCount(io_connect_t conn);
bool SMCKeyExists(io_connect_t conn, const char *key);

#endif
