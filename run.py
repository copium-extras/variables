import ctypes
import os
import sys

# --- Configuration ---
LIB_NAME = "my_module"
LIB_FOLDER = os.path.join("zig-out", "bin")

print(f"--- Python Test Script for Zig Variable System ---")

# --- Library Loading (No changes here) ---
def find_and_load_library():
    """Determines the correct library extension for the OS, finds it, and loads it."""
    if sys.platform.startswith('win'):
        ext = '.dll'
    elif sys.platform.startswith('darwin'):
        ext = '.dylib'
    else: # Assumes Linux or other Unix-like OS
        ext = '.so'
    
    dll_path = os.path.join(LIB_FOLDER, f"{LIB_NAME}{ext}")

    print(f"Attempting to load library: {dll_path}")

    if not os.path.exists(dll_path):
        print(f"\n[ERROR] Library not found at '{dll_path}'.")
        print("Please compile the Zig project first by running: zig build")
        exit(1)

    if sys.platform == "win32":
        try:
            os.add_dll_directory(os.path.abspath(LIB_FOLDER))
        except AttributeError:
            os.environ['PATH'] = os.path.abspath(LIB_FOLDER) + ';' + os.environ['PATH']

    try:
        loaded_dll = ctypes.CDLL(dll_path)
        print(f"Successfully loaded {os.path.basename(dll_path)}")
        return loaded_dll
    except OSError as e:
        print(f"\n[ERROR] Failed to load DLL '{dll_path}'.\nDetails: {e}")
        exit(1)

# 1. Load the DLL
my_dll = find_and_load_library()

# 2. Define all function prototypes (No changes here)
try:
    init_func = my_dll.init
    init_func.restype = ctypes.c_int
    shutdown_func = my_dll.shutdown
    make_func = my_dll.make
    make_func.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p]
    make_func.restype = ctypes.c_int
    mod_func = my_dll.mod
    mod_func.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p]
    mod_func.restype = ctypes.c_int
    remove_func = my_dll.remove
    remove_func.argtypes = [ctypes.c_char_p]
    remove_func.restype = ctypes.c_int
    get_type_func = my_dll.get_type
    get_type_func.argtypes = [ctypes.c_char_p]
    get_type_func.restype = ctypes.c_int
    get_value_as_string_func = my_dll.get_value_as_string
    get_value_as_string_func.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_size_t]
    get_value_as_string_func.restype = ctypes.c_int
except AttributeError as e:
    print(f"\n[ERROR] A required function was not found in the DLL: {e}")
    exit(1)

# --- Python Helper Functions (No changes here) ---
def c_str(s: str) -> bytes:
    return s.encode('utf-8')

ZIG_TYPE_MAP = { 0: "number", 1: "boolean", 2: "string", 3: "array", 4: "object", 5: "null" }

def get_variable(name: str):
    name_c = c_str(name)
    type_int = get_type_func(name_c)
    if type_int < 0:
        return "error", f"Variable '{name}' not found (code: {type_int})"
    type_str = ZIG_TYPE_MAP.get(type_int, "unknown")
    buffer_size = 256
    buffer = ctypes.create_string_buffer(buffer_size)
    bytes_written = get_value_as_string_func(name_c, buffer, buffer_size)
    if bytes_written < 0:
        return "error", f"Could not retrieve value (code: {bytes_written})"
    value = buffer.value.decode('utf-8')
    return type_str, value

# 3. Main Application Logic
try:
    print("\nCalling init()...")
    if init_func() == 0:
        print(" > Success: init() returned 0.")
    else:
        print(" > Failure: init() did not return 0.")

    print("\n--- Running Variable System Tests ---")
    
    # Test `make` with explicit status checks
    print("\n--- 1. Testing 'make' ---")
    ret = make_func(c_str("score"), c_str("dynam"), c_str("number"), c_str("120.5"))
    print(f" > make 'score': {'Success' if ret == 0 else 'Failed'} (code: {ret})")
    ret = make_func(c_str("player_name"), c_str("const"), c_str("string"), c_str("Alice"))
    print(f" > make 'player_name': {'Success' if ret == 0 else 'Failed'} (code: {ret})")
    ret = make_func(c_str("is_active"), c_str("dynam"), c_str("boolean"), c_str("true"))
    print(f" > make 'is_active': {'Success' if ret == 0 else 'Failed'} (code: {ret})")
    
    # Test `get` (verification step)
    print("\n--- 2. Verifying variables with 'get' ---")
    var_type, var_value = get_variable("player_name")
    print(f" > get 'player_name' -> Type: {var_type}, Value: '{var_value}'")
    var_type, var_value = get_variable("score")
    print(f" > get 'score' -> Type: {var_type}, Value: '{var_value}'")
    var_type, var_value = get_variable("is_active")
    print(f" > get 'is_active' -> Type: {var_type}, Value: '{var_value}'")
    var_type, var_value = get_variable("non_existent_var")
    print(f" > get 'non_existent_var' -> Type: {var_type}, Value: '{var_value}'")
    
    # Test `mod` with explicit status checks
    print("\n--- 3. Testing 'mod' ---")
    ret = mod_func(c_str("score"), c_str("number"), c_str("999.0"))
    print(f" > mod 'score': {'Success' if ret == 0 else 'Failed'} (code: {ret})")
    print("   Verifying change...")
    var_type, var_value = get_variable("score")
    print(f" > get 'score' after mod -> Type: {var_type}, Value: '{var_value}'")
    
    # Test `remove` with explicit status checks
    print("\n--- 4. Testing 'remove' ---")
    ret = remove_func(c_str("is_active"))
    print(f" > remove 'is_active': {'Success' if ret == 0 else 'Failed'} (code: {ret})")
    print("   Verifying removal...")
    var_type, var_value = get_variable("is_active")
    print(f" > get 'is_active' after remove -> Type: {var_type}, Value: '{var_value}'")
    
    print("\n--- Variable tests complete. ---")

finally:
    print("\nCalling shutdown()...")
    shutdown_func()
    print("--- Script finished. ---")