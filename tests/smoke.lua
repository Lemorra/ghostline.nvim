local ghostline = require("ghostline")

assert(type(ghostline) == "table", "ghostline should return a module table")
assert(type(ghostline.setup) == "function", "ghostline.setup should be available")
assert(ghostline.setup() == nil, "setup should not return a value")
assert(ghostline.setup({}) == nil, "setup should accept an options table")

local ok = pcall(ghostline.setup, "invalid")
assert(not ok, "setup should reject non-table options")

print("ghostline smoke tests passed")
