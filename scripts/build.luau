local fs = require('@lune/fs')
local roblox = require('@lune/roblox')
local serde = require('@lune/serde')
local luau = require('@lune/luau')
local game = roblox.deserializePlace(fs.readFile('original/ido-roblox-backup.rbxl'))
local originalXml = roblox.serializePlace(game, true)
local code = roblox.deserializeModel(fs.readFile('build/code.rbxm'))[1]
local entries = serde.decode('json', fs.readFile('scripts-map.json'))
for _, entry in entries do
 local node = game
 for _, index in entry.route do node = node:GetChildren()[index] end
 assert(node.ClassName == entry.class and node:GetFullName() == entry.name, 'Original hierarchy changed')
 local source = code:FindFirstChild(entry.id).Source
 luau.compile(source)
 node.Source = source
end
local output = roblox.serializePlace(game)
local restored = roblox.deserializePlace(output)
assert(#restored:GetDescendants() == #game:GetDescendants(), 'Instance count changed')
fs.writeFile('build/before.rbxlx', roblox.serializePlace(game, true))
fs.writeFile('build/after.rbxlx', roblox.serializePlace(restored, true))
-- First migration must reproduce the entire original data model, including references.
local original = roblox.deserializePlace(fs.readFile('original/ido-roblox-backup.rbxl'))
for _, entry in entries do
 local node, base = game, original
 for _, index in entry.route do
  node = node:GetChildren()[index]
  base = base:GetChildren()[index]
 end
 node.Source = base.Source
end
fs.writeFile('build/original.rbxlx', originalXml)
fs.writeFile('build/source-reset.rbxlx', roblox.serializePlace(game, true))
-- Add new systems only after verifying the untouched original hierarchy.
local function inject(name, className, parent)
 local source = code:FindFirstChild(name).Source
 luau.compile(source)
 local object = roblox.Instance.new(className)
 object.Name, object.Source, object.Parent = name, source, parent
end
inject('FlightRules', 'ModuleScript', restored:GetService('ReplicatedStorage'))
inject('WorldServer', 'Script', restored:GetService('ServerScriptService'))
inject('FlightClient', 'LocalScript', restored:GetService('StarterPlayer'):FindFirstChild('StarterPlayerScripts'))
assert(restored:GetService('ReplicatedStorage'):FindFirstChild('FlightRules'))
assert(restored:GetService('ServerScriptService'):FindFirstChild('WorldServer'))
assert(restored:GetService('StarterPlayer'):FindFirstChild('StarterPlayerScripts'):FindFirstChild('FlightClient'))
fs.writeFile('build/playtest.rbxl', roblox.serializePlace(restored))
print('Built and roundtrip-verified', #entries, 'scripts;', #game:GetDescendants(), 'instances')
