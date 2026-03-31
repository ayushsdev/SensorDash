import Foundation

/// Utility for dynamically loading private frameworks and resolving symbols at runtime.
enum FrameworkLoader {
    /// Load a framework from the given path. Returns an opaque handle or nil.
    static func load(_ path: String) -> UnsafeMutableRawPointer? {
        dlopen(path, RTLD_LAZY)
    }

    /// Resolve a symbol name from a framework handle and cast to the desired function pointer type.
    static func symbol<T>(_ handle: UnsafeMutableRawPointer, _ name: String) -> T? {
        guard let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    /// Convenience: load framework + resolve symbol in one call.
    static func resolve<T>(framework path: String, symbol name: String) -> T? {
        guard let handle = load(path) else { return nil }
        return symbol(handle, name)
    }
}
