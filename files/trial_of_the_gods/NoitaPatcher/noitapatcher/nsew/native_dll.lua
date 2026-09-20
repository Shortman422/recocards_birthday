
local ffi = require("ffi")

native_dll = {}

native_dll.lib = ffi.load(__nsew_path .. "nsew_native.dll")

return native_dll
