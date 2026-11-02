-- Prints what build_dictionary.py needs from Data.lua, one tab-separated line each:
--   L <key> <id> <markers, comma-separated>
--   P <key> <English> <native>
-- Usage: lua tools/dump_data.lua Data.lua
GetBuildInfo = function() return "1.60.1", "0", "", 16001 end
local ns = {}
assert(loadfile(arg[1]))("EzTongues", ns)
for _, t in ipairs(ns.TONGUES) do
    io.write("L\t", t.key, "\t", t.id, "\t", table.concat(t.markers, ","), "\n")
    for _, p in ipairs(t.phrases) do
        io.write("P\t", t.key, "\t", p[1], "\t", p[2], "\n")
    end
end
