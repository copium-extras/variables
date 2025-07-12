import ctypes
import os
import sys
import time

DLL_NAME = "my_module.dll" 
DLL_FOLDER = os.path.join("zig-out", "bin")
DLL_PATH = os.path.join(DLL_FOLDER, DLL_NAME)

print(f"--- Python Game Loop ---")

# --- THIS IS THE FIX ---
# On Windows, we must explicitly tell Python where to find the dependencies
# of our main DLL (i.e., where to find SDL3.dll).
# This must be done *before* loading the DLL.
if sys.platform == "win32":
    try:
        # This is the modern way (Python 3.8+)
        os.add_dll_directory(os.path.abspath(DLL_FOLDER))
        print(f"Added DLL search path: {os.path.abspath(DLL_FOLDER)}")
    except AttributeError:
        # Fallback for older Python: add to PATH. Less secure.
        os.environ['PATH'] = os.path.abspath(DLL_FOLDER) + ';' + os.environ['PATH']
        print(f"Added to PATH for DLL search: {os.path.abspath(DLL_FOLDER)}")
# --- END OF FIX ---


# 1. Load the DLL
try:
    my_dll = ctypes.CDLL(DLL_PATH)
    print(f"Successfully loaded {DLL_NAME}")
except OSError as e:
    print(f"\n[ERROR] Failed to load DLL '{DLL_PATH}'.\nDetails: {e}")
    exit(1)

# 2. Get all our functions and set their return types
try:
    init_func = my_dll.init
    init_func.restype = ctypes.c_int

    poll_func = my_dll.poll_events
    poll_func.restype = ctypes.c_bool

    shutdown_func = my_dll.shutdown
except AttributeError as e:
    print(f"\n[ERROR] A required function was not found in the DLL: {e}")
    exit(1)

# 3. Main Application Logic
try:
    print("Calling init()...")
    if init_func() != 0:
        print("[ERROR] Zig DLL failed to initialize. Check console for details.")
        exit(1)

    print("Starting main loop... (Close the SDL window to exit)")
    while True:
        if poll_func():
            print("Quit signal received from DLL.")
            break
        time.sleep(0.016)

finally:
    print("Calling shutdown()...")
    shutdown_func()
    print("--- Script finished. ---")