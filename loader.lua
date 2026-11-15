local base = "https://raw.githubusercontent.com/sixsens666/bigblackbee/main/"
local seed = 1192521637
local assetsHash = "97c243407d09"
local root = "Bee Swarm/"
local env = getgenv()

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local lookup = {}
for i = 1, #alphabet do lookup[alphabet:byte(i)] = i - 1 end

local function fetch(name)
    return game:HttpGet(base .. name .. "?t=" .. os.time())
end

-- base64 decode + keystream xor, returns the raw string
local function decode(text)
    local state = seed
    local out, chunk, count = {}, {}, 0
    local function push(byte)
        state = (state * 1664525 + 1013904223) % 4294967296
        count += 1
        chunk[count] = string.char(bit32.bxor(byte, math.floor(state / 65536) % 256))
        if count >= 4000 then
            out[#out + 1] = table.concat(chunk, "", 1, count)
            count = 0
        end
    end
    local len = #text
    for i = 1, len, 4 do
        local a, b, c, d = text:byte(i, i + 3)
        local n = lookup[a] * 262144 + lookup[b] * 4096 + (lookup[c] or 0) * 64 + (lookup[d] or 0)
        push(math.floor(n / 65536))
        if c ~= 61 then push(math.floor(n / 256) % 256) end
        if d ~= 61 then push(n % 256) end
    end
    out[#out + 1] = table.concat(chunk, "", 1, count)
    return table.concat(out)
end

local function unpack(raw)
    local files, pos = {}, 1
    while pos <= #raw do
        local nameEnd = raw:find("\n", pos, true)
        local lenEnd = raw:find("\n", nameEnd + 1, true)
        local size = tonumber(raw:sub(nameEnd + 1, lenEnd - 1))
        files[raw:sub(pos, nameEnd - 1)] = raw:sub(lenEnd + 1, lenEnd + size)
        pos = lenEnd + size + 1
    end
    return files
end

local function ensureFolder(path)
    local built = ""
    for segment in path:gmatch("[^/]+") do
        built = built == "" and segment or (built .. "/" .. segment)
        if not isfolder(built) then makefolder(built) end
    end
end

ensureFolder(root .. "configs")

local stampPath = root .. ".assets"
local assets = {}
local needAssets = not (isfile(stampPath) and readfile(stampPath) == assetsHash)
if needAssets then
    assets = unpack(decode(fetch("assets.dat")))
    for name, data in pairs(assets) do
        ensureFolder((root .. name):match("^(.*)/[^/]+$"))
        writefile(root .. name, data)
    end
    writefile(stampPath, assetsHash)
end

local sources = unpack(decode(fetch("code.dat")))
local nativeReadfile = env.readfile
env.readfile = function(path)
    return sources[path] or nativeReadfile(path)
end

env.BeeSwarmRelease = true
assert(loadstring(sources[root .. "init.lua"], "@" .. root .. "init.lua"))()
