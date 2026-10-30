local fs = require('@lune/fs')
local roblox = require('@lune/roblox')
local serde = require('@lune/serde')
if not fs.isDir('src') then fs.writeDir('src') end
local game = roblox.deserializePlace(fs.readFile('original/ido-roblox-backup.rbxl'))
local entries, classes, assets = {}, {}, {}
local tree = {['$className']='Folder'}
local function walk(node, path)
 for index, child in node:GetChildren() do
  local route = table.clone(path)
  table.insert(route, index)
  classes[child.ClassName] = (classes[child.ClassName] or 0) + 1
  if child:IsA('LuaSourceContainer') then
   local id = string.format('script_%03d', #entries + 1)
   local file = 'src/' .. id .. '.luau'
   fs.writeFile(file, child.Source)
   table.insert(entries, {id=id, file=file, route=route, name=child:GetFullName(), class=child.ClassName})
   tree[id] = {['$path']=file}
  end
  if child:IsA('Animation') then table.insert(assets, {name=child:GetFullName(), id=child.AnimationId}) end
  walk(child, route)
 end
end
walk(game, {})
fs.writeFile('scripts-map.json', serde.encode('json', entries, true))
fs.writeFile('inventory.json', serde.encode('json', {classes=classes, animations=assets}, true))
fs.writeFile('default.project.json', serde.encode('json', {name='ido-roblox-code',tree=tree}, true))
fs.writeFile('original/inspection.rbxlx', roblox.serializePlace(game, true))
print('Extracted', #entries, 'scripts; animations', #assets)
