-- The original Lucky Block model is reused; all alpha scenery is additive at runtime.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local DataStoreService = game:GetService('DataStoreService')
local HttpService = game:GetService('HttpService')
local TweenService = game:GetService('TweenService')
local Debris = game:GetService('Debris')
local Rules = require(ReplicatedStorage:WaitForChild('FlightRules'))
local remote = Instance.new('RemoteEvent')
remote.Name = 'FlightAction'
remote.Parent = ReplicatedStorage
local notice = Instance.new('RemoteEvent')
notice.Name = 'FlightNotice'
notice.Parent = ReplicatedStorage
local world = Instance.new('Folder')
world.Name = 'FlightForest'
world.Parent = workspace
local template = workspace:WaitForChild('LuckyBlock'):Clone()
template.Parent = nil
local oldBlock = workspace.LuckyBlock
-- The original instance stays available for inspection, but cannot be stolen twice.
oldBlock.Parent = game:GetService('ServerStorage')
local floor = workspace:FindFirstChild('Baseplate')
local ground = if floor and floor:IsA('BasePart') then floor.Position.Y + floor.Size.Y / 2 else 0
local origin = Vector3.new(0, ground, 0)
local basePosition = origin + Vector3.new(0, 4, 0)
local states, trees, rings, rotors, guardians = {}, {}, {}, {}, {}
local store = DataStoreService:GetDataStore('IdoFlightForest_v1')
local rng = Random.new(437)
local function part(name, size, cf, color, material, parent)
 local p = Instance.new('Part')
 p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
 p.Material = material or Enum.Material.WoodPlanks
 p.Anchored = true
 p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
 p.Parent = parent or world
 return p
end
local function label(p, text, color, distance)
 local gui = Instance.new('BillboardGui')
 gui.Size = UDim2.fromOffset(230, 65)
 gui.StudsOffset = Vector3.new(0, 5, 0)
 gui.MaxDistance = distance or 190
 gui.AlwaysOnTop = true
 gui.Parent = p
 local t = Instance.new('TextLabel')
 t.Size = UDim2.fromScale(1, 1)
 t.BackgroundColor3 = Color3.fromRGB(19, 36, 35)
 t.BackgroundTransparency = 0.18
 t.Text, t.TextColor3 = text, color or Color3.new(1,1,1)
 t.TextSize = 17
 t.Font = Enum.Font.GothamBold
 t.TextWrapped = true
 t.Parent = gui
 local corner = Instance.new('UICorner')
 corner.CornerRadius = UDim.new(0,10)
 corner.Parent = t
 return t
end
local function tell(player, text)
 if player.Parent then notice:FireClient(player,text) end
end
local function rootOf(player)
 local c = player.Character
 local h = c and c:FindFirstChildOfClass('Humanoid')
 return if h and h.Health > 0 then c:FindFirstChild('HumanoidRootPart') else nil
end
local function update(player)
 local s = states[player]
 if not s then return end
 player:SetAttribute('BaseCapacity',Rules.capacity(s.baseLevel))
 player:SetAttribute('UpgradeCost',Rules.upgradeCost(s.baseLevel) or 0)
 player:SetAttribute('FlightPower',s.power)
 player:SetAttribute('Coins',s.coins)
 player:SetAttribute('Deliveries',s.deliveries)
 player:SetAttribute('WingTier',Rules.tier(s.deliveries))
 player:SetAttribute('FlightSpeed',math.floor(Rules.speed(s.power,s.deliveries,s.carry ~= nil)))
 player:SetAttribute('TutorialStep',s.tutorial or 1)
 player:SetAttribute('Carrying',if s.carry then s.carry.config.rarity else '')
end
local function tutorial(player,event)
 local s=states[player]
 if not s or not s.loaded then return end
 s.tutorial=Rules.nextTutorial(s.tutorial,event)
 update(player)
end
local function gain(player, power, coins, deliveries)
 local s = states[player]
 if not s or not s.loaded then return end
 local nextPower = math.min(Rules.MAX_POWER,s.power+power)
 s.earned.power += nextPower-s.power
 s.earned.coins += coins
 s.earned.deliveries += deliveries
 s.power, s.coins, s.deliveries = nextPower, s.coins+coins, s.deliveries+deliveries
 update(player)
end
local function save(player)
 local s = states[player]
 if not s or not s.loaded or not s.canSave or s.saving then return false end
 s.saving = true
 local totals = table.clone(s.earned)
 local collection=table.clone(s.collectionEarned)
 local tutorialDone=s.tutorial>7
 local ok = pcall(function()
  store:UpdateAsync('player_'..player.UserId,function(old)
   old = if type(old)=='table' then old else {}
   local sessions = if type(old.sessions)=='table' then old.sessions else {}
   local applied = sessions[s.session] or {power=0,coins=0,deliveries=0}
   old.power = math.min(Rules.MAX_POWER,(tonumber(old.power) or 1)+math.max(0,totals.power-applied.power))
   old.coins = (tonumber(old.coins) or 0)+math.max(0,totals.coins-applied.coins)
   old.deliveries = (tonumber(old.deliveries) or 0)+math.max(0,totals.deliveries-applied.deliveries)
   old.collection=Rules.collectionMerge(if type(old.collection)=='table' then old.collection else {},collection,if type(applied.collection)=='table' then applied.collection else {})
   old.tutorialDone=old.tutorialDone==true or tutorialDone
   sessions[s.session] = {power=totals.power,coins=totals.coins,deliveries=totals.deliveries,collection=collection,time=os.time()}
   -- Old closed sessions can be discarded; current retries keep their checkpoint.
   for key,value in sessions do
    if key ~= s.session and (value.time or 0) < os.time()-86400*7 then sessions[key]=nil end
   end
   old.sessions = sessions
   return old
  end)
 end)
 if ok then s.savedCoins=totals.coins end
 s.saving = false
 if player.Parent then player:SetAttribute('SaveStatus',if ok then 'Saved' else 'Save retry pending') end
 if not ok then warn('Flight progress save deferred for user',player.UserId) end
 return ok
end

-- A base large enough for the tablet player to land without precision aiming.
local pad = part('ReturnBase',Vector3.new(38,2,38),CFrame.new(basePosition),Color3.fromRGB(57,177,148))
label(pad,'HOME BASE\nBring your Lucky Block here!',Color3.fromRGB(157,255,217),320)
local glow = part('HomeBeacon',Vector3.new(2,65,2),CFrame.new(basePosition+Vector3.new(0,33,0)),Color3.fromRGB(107,255,198),Enum.Material.Neon)
glow.CanCollide,glow.Transparency = false,0.65
local spawn = Instance.new('SpawnLocation')
spawn.Name,spawn.Size,spawn.CFrame = 'FlightSpawn',Vector3.new(6,1,6),CFrame.new(basePosition+Vector3.new(0,2,10))
spawn.Anchored,spawn.Neutral,spawn.Duration = true,true,0
spawn.Transparency = 1
spawn.Parent = world
for _, item in workspace:GetChildren() do
 if item:IsA('SpawnLocation') then item.Enabled=false end
end
-- A corridor with open biome seams: walls bound the sides, never altitude.
for i,zone in Rules.ZONES do
 local center=(zone.start+zone.finish)/2
 local color=Color3.fromRGB(table.unpack(zone.color))
 part(zone.name..'Floor',Vector3.new(180,2,zone.finish-zone.start),CFrame.new(origin+Vector3.new(0,-1,center)),color,Enum.Material[zone.material])
 for _,side in {-1,1} do
  part(zone.name..'Wall',Vector3.new(6,210,zone.finish-zone.start),CFrame.new(origin+Vector3.new(side*93,104,center)),color:Lerp(Color3.new(0.15,0.15,0.2),0.45),Enum.Material.Slate)
 end
 local sign=part(zone.name..'Sign',Vector3.new(20,2,2),CFrame.new(origin+Vector3.new(0,5,zone.start)),color,Enum.Material.Neon)
 sign.CanCollide=false
 label(sign,'◆ '..i,color,110)
end
part('HomeMeadow',Vector3.new(180,2,160),CFrame.new(origin),Color3.fromRGB(83,147,86),Enum.Material.Grass)
for x=-2,2 do
 for z=-2,2 do
  part('OuterLandingGround',Vector3.new(1024,4,1024),CFrame.new(origin+Vector3.new(x*1024,-5,z*1024)),Color3.fromRGB(65,100,80),Enum.Material.Grass)
 end
end

-- Wooden wind trainer, moving blades and ascending rings.
local trainingPosition = origin+Vector3.new(-38,0,-32)
local deck = part('WindTrainingDeck',Vector3.new(26,2,26),CFrame.new(trainingPosition+Vector3.new(0,2,0)),Color3.fromRGB(153,106,61))
label(deck,'↑ ↑ ↑',Color3.fromRGB(166,226,255))
world:SetAttribute('TrainingPosition',trainingPosition+Vector3.new(0,20,0))
local wind = part('WindColumn',Vector3.new(18,34,18),CFrame.new(trainingPosition+Vector3.new(0,20,0)),Color3.fromRGB(125,224,255),Enum.Material.Neon)
wind.Transparency,wind.CanCollide = 0.85,false
local particles = Instance.new('ParticleEmitter')
particles.Texture='rbxasset://textures/particles/sparkles_main.dds'
particles.Color=ColorSequence.new(Color3.fromRGB(170,240,255))
particles.Rate,particles.Speed,particles.Lifetime=15,NumberRange.new(10,15),NumberRange.new(1,2)
particles.EmissionDirection=Enum.NormalId.Top
particles.Parent=wind
for _,x in {-13,13} do
 part('TrainerPost',Vector3.new(2,24,2),CFrame.new(trainingPosition+Vector3.new(x,12,10)),Color3.fromRGB(121,79,48))
end
local hub = trainingPosition+Vector3.new(0,18,11)
part('WheelAxle',Vector3.new(3,3,5),CFrame.new(hub),Color3.fromRGB(92,59,39))
for i=1,4 do
 local blade=part('WindBlade',Vector3.new(3,13,1),CFrame.new(hub),Color3.fromRGB(196,151,93))
 blade.CanCollide=false
 table.insert(rotors,{part=blade,hub=hub,angle=i*math.pi/2})
end
for i=1,6 do
 local pos=origin+Vector3.new(-38+i*14,18+i*9,-54)
 local folder=Instance.new('Model')
 folder.Name='TrainingRing'..i
 folder.Parent=world
 for j=1,16 do
  local angle=j*math.pi*2/16
  local cf=CFrame.new(pos)*CFrame.Angles(0,0,angle)*CFrame.new(0,7,0)
  local segment=part('WoodRing',Vector3.new(3,1,1),cf,Color3.fromRGB(209,161,88),nil,folder)
  segment.CanCollide=false
 end
 local marker=part('RingMarker',Vector3.one,CFrame.new(pos+Vector3.new(0,9,0)),Color3.new(1,1,1),nil,folder)
 marker.Transparency,marker.CanCollide=1,false
 label(marker,'◎ +3',Color3.fromRGB(255,224,127),100)
 table.insert(rings,{position=pos,cooldowns={}})
end

local resetTree
local function stopCarry(player)
 local s=states[player]
 if not s then return end
 if s.track then s.track:Stop(); s.track:Destroy(); s.track=nil end
 if s.animation then s.animation:Destroy(); s.animation=nil end
 if s.weld then s.weld:Destroy(); s.weld=nil end
 s.carry=nil
 update(player)
end
local function steal(player,tree)
 local s=states[player]
 local root=rootOf(player)
 if not s or not s.loaded or not root then return end
 local distance=(root.Position-tree.block.MainBlock.Position).Magnitude
 if not Rules.canSteal(s.power,1,s.carry~=nil,tree.owner==nil and tree.available,distance) then return end
 if s.tutorial<4 then return end
 if distance<=12 then tutorial(player,'approach') end
 tree.available,tree.owner,tree.wakeAt=false,player,os.clock()+2.5
 tree.droppedAt=nil
 tree.guardian.alerts[tree]=true
 tutorial(player,'steal')
 tree.prompt.Enabled=false
 s.carry=tree
 for _,obj in tree.block:GetDescendants() do
  if obj:IsA('BasePart') then obj.Anchored=false; obj.CanCollide=false; obj.Massless=true end
 end
 tree.block:PivotTo(root.CFrame*CFrame.new(0,0.5,-3))
 local weld=Instance.new('WeldConstraint')
 weld.Part0,weld.Part1,weld.Parent=root,tree.block.MainBlock,tree.block.MainBlock
 s.weld=weld
 local animator=player.Character:FindFirstChildOfClass('Humanoid'):FindFirstChildOfClass('Animator')
 if animator then
  local animation=Instance.new('Animation')
  animation.AnimationId='rbxassetid://76020890425719'
  s.animation=animation
  local ok,track=pcall(function() return animator:LoadAnimation(animation) end)
  if ok then s.track=track; track.Looped=true; track.Priority=Enum.AnimationPriority.Action; track:Play() end
 end
 tree.guardian.status.Text='! ! !'
 local highlight=Instance.new('Highlight')
 highlight.Name='CarryHighlight'
 highlight.FillColor=Color3.fromRGB(255,225,70)
 highlight.FillTransparency=0.6
 highlight.Parent=tree.block
 tell(player,'You stole a '..tree.config.rarity..' block! FLY HOME — the monster is waking up!')
 update(player)
end
local function makeBlock(tree)
 local block=template:Clone()
 block.Name=tree.config.name..'LuckyBlock'
 block.Parent=world
 local main=block:FindFirstChild('MainBlock')
 assert(main and main:IsA('BasePart'),'Original Lucky Block has no MainBlock')
 block.PrimaryPart=main
 for _,obj in block:GetDescendants() do
  if obj:IsA('BasePart') then obj.Anchored=false; obj.CanCollide=false; obj.Massless=true end
 end
 main.Anchored=true
 block:PivotTo(tree.home)
 local prompt=main:FindFirstChildOfClass('ProximityPrompt')
 if not prompt then prompt=Instance.new('ProximityPrompt'); prompt.Parent=main end
 main.Color=Color3.fromRGB(table.unpack(tree.config.color))
 prompt.ActionText='⬡'
 prompt.ObjectText=''
 prompt.MaxActivationDistance,prompt.HoldDuration,prompt.RequiresLineOfSight=12,0.6,false
 prompt.Triggered:Connect(function(player) steal(player,tree) end)
 tree.block,tree.prompt=block,prompt
end
resetTree=function(tree, delaySeconds)
 local owner=tree.owner
 if owner then stopCarry(owner) end
 tree.owner,tree.available=nil,false
 if tree.block then tree.block:Destroy() end
 tree.guardian.alerts[tree]=nil
 tree.droppedAt=nil
 task.delay(delaySeconds or 0,function()
  makeBlock(tree)
  tree.available=true
 end)
end
-- Winged creatures with a head, beak, tail, feet and layered feather wings.
for index,config in Rules.TREES do
 local zone=Rules.ZONES[index]
 local color=Color3.fromRGB(table.unpack(config.color))
 local location=origin+Vector3.new(config.x,config.height,config.z)
 local monster=Instance.new('Model')
 monster.Name=config.name
 monster.Parent=world
 local home=CFrame.new(location+Vector3.new(0,12,16))
 local body=part('CreatureBody',Vector3.new(6,5,11),home,color,Enum.Material.SmoothPlastic,monster)
 body.Shape,body.CanCollide=Enum.PartType.Ball,false
 monster.PrimaryPart=body
 local head=part('Head',Vector3.new(5,5,5),home*CFrame.new(0,3,-5),color,Enum.Material.SmoothPlastic,monster)
 head.Shape=Enum.PartType.Ball
 if index==1 then part('Beak',Vector3.new(2,1.5,4),home*CFrame.new(0,2,-8),Color3.fromRGB(255,194,65),Enum.Material.SmoothPlastic,monster) end
 part('Tail',Vector3.new(3,1,9),home*CFrame.new(0,0,8)*CFrame.Angles(-0.3,0,0),color,Enum.Material.SmoothPlastic,monster)
 if index==2 then
  body.Material=Enum.Material.Ice
  body.Size=Vector3.new(10,2,8)
  for spike=1,5 do
   part('CrystalSpine',Vector3.new(1,3+spike,1),home*CFrame.new(0,3,spike-3)*CFrame.Angles(0,0,0.5),Color3.fromRGB(145,245,255),Enum.Material.Ice,monster)
  end
 elseif index==3 then
  body.Size=Vector3.new(6,6,15)
  for _,side in {-1,1} do
   part('DragonHorn',Vector3.new(1,5,1),home*CFrame.new(side*2,6,-4)*CFrame.Angles(0,0,-side*0.4),Color3.fromRGB(255,220,145),Enum.Material.Slate,monster)
  end
  for spike=1,6 do
   part('DragonSpine',Vector3.new(1,3,2),home*CFrame.new(0,4,spike*2-5),Color3.fromRGB(190,70,35),Enum.Material.Slate,monster)
  end
 elseif index==4 then
  body.Material=Enum.Material.DiamondPlate
  head.Size=Vector3.new(3,4,10)
  part('PterosaurCrest',Vector3.new(1,6,8),home*CFrame.new(0,6,-2)*CFrame.Angles(0.4,0,0),color,Enum.Material.Metal,monster)
  for _,side in {-1,1} do
   part('Engine',Vector3.new(3,3,6),home*CFrame.new(side*4,0,3),Color3.fromRGB(70,80,95),Enum.Material.Metal,monster)
   part('EngineGlow',Vector3.new(2,2,1),home*CFrame.new(side*4,0,6),Color3.fromRGB(70,255,240),Enum.Material.Neon,monster)
  end
 end
 local wings={}
 for _,side in {-1,1} do
  local eye=part('Eye',Vector3.new(0.6,1.2,1),home*CFrame.new(side*2.4,3,-6),Color3.fromRGB(20,30,45),Enum.Material.Neon,monster)
  if index~=2 then part('Talons',Vector3.new(1.5,2,3),home*CFrame.new(side*2,-3,-1),Color3.fromRGB(255,194,65),Enum.Material.SmoothPlastic,monster) end
  for feather=1,5 do
   local relative=CFrame.new(side*(4+feather*1.3),1,feather*0.7)*CFrame.Angles(0,side*0.15,side*0.2)
   local wing=part(if index==1 then 'CreatureFeather' else 'WingMembrane',Vector3.new(if index==1 then 2 else 3,0.7,9-feather*0.6),home*relative,color:Lerp(Color3.new(1,1,1),feather*0.1),if index==2 then Enum.Material.Ice elseif index==4 then Enum.Material.Metal else Enum.Material.SmoothPlastic,monster)
   table.insert(wings,{part=wing,relative=relative,side=side})
  end
 end
 for _,obj in monster:GetChildren() do if obj:IsA('BasePart') then obj.CanCollide=false end end
 local guardian={model=monster,home=home,zone=zone,config=config,alerts={},wings=wings}
 guardian.status=label(body,'Zzz',color,100)
 table.insert(guardians,guardian)
 -- Three independently stealable blocks share one territorial guardian.
 for slot=1,3 do
  local position=location+Vector3.new((slot-2)*45,0,-15)
  part('TreasurePillar',Vector3.new(13,config.height,13),CFrame.new(position-Vector3.new(0,config.height/2,0)),Color3.fromRGB(table.unpack(zone.color)),Enum.Material[zone.material])
  part('TreasurePlatform',Vector3.new(23,2,21),CFrame.new(position),color,Enum.Material.WoodPlanks)
  local kind=(index-1)*3+slot
  local blockConfig=Rules.COLLECTIBLES[kind]
  local tree={config=blockConfig,kind=kind,guardian=guardian,home=CFrame.new(position+Vector3.new(0,5,0)),available=true}
  table.insert(trees,tree)
  makeBlock(tree)
 end
end

-- One physical plot per player. Counts retain every delivery; each kind has a display stack.
local plotSlots={}
local function renderCollection(player)
 local s=states[player]
 if not s then return end
 if not s.plot then
  local slot=1
  while plotSlots[slot] do slot+=1 end
  plotSlots[slot]=player
  s.plotSlot=slot
  local row=math.floor((slot-1)/2)
  s.base=origin+Vector3.new(if slot%2==1 then -55 else 55,4,-105-row*100)
  s.plot=Instance.new('Model'); s.plot.Name='Collection_'..player.UserId; s.plot.Parent=world
  local platform=part('PersonalBase',Vector3.new(48,2,86),CFrame.new(s.base),Color3.fromRGB(47,135,126),Enum.Material.WoodPlanks,s.plot)
  local beacon=part('PersonalBeacon',Vector3.new(1,45,1),CFrame.new(s.base+Vector3.new(0,23,18)),Color3.fromRGB(100,255,195),Enum.Material.Neon,s.plot)
  beacon.CanCollide=false; beacon.Transparency=0.5
  player:SetAttribute('BasePosition',s.base)
  label(platform,'⌂ '..player.DisplayName,Color3.new(1,1,1),160)
 end
 if s.display then s.display:Destroy() end
 s.display=Instance.new('Model'); s.display.Name='CollectedBlocks'; s.display.Parent=s.plot
 local total=Rules.collectionCount(s.collection)
 local capacity=math.max(Rules.capacity(s.baseLevel),total)
 local kinds={}
 for kind,count in s.collection do for _=1,count do table.insert(kinds,kind) end end
 for slot=1,capacity do
  local position=s.base+Vector3.new(((slot-1)%5-2)*8,2,math.floor((slot-1)/5)*8-18)
  local occupied=kinds[slot]~=nil
  local socket=part('Slot'..slot,Vector3.new(7,0.5,7),CFrame.new(position),if occupied then Color3.fromRGB(100,255,170) else Color3.fromRGB(65,90,95),Enum.Material.Neon,s.display)
  socket.CanCollide=false
  if occupied then
   local block=template:Clone()
   for _,obj in block:GetDescendants() do
    if obj:IsA('BaseScript') or obj:IsA('ProximityPrompt') then obj:Destroy()
    elseif obj:IsA('BasePart') then obj.Anchored=true; obj.CanCollide=false end
   end
   block.PrimaryPart=block.MainBlock
   block.MainBlock.Color=Color3.fromRGB(table.unpack(Rules.COLLECTIBLES[kinds[slot]].color))
   block.Parent=s.display
   block:PivotTo(CFrame.new(position+Vector3.new(0,4,0)))
  end
 end
 if not s.upgradePad then
  s.upgradePad=part('UpgradePad',Vector3.new(8,1,8),CFrame.new(s.base+Vector3.new(19,2,18)),Color3.fromRGB(255,195,65),Enum.Material.Neon,s.plot)
  s.slotLabel=label(s.upgradePad,'',Color3.new(1,1,1),100)
 end
 s.slotLabel.Text='⬡ '..total..' / '..capacity..'   +5 ● '..(Rules.upgradeCost(s.baseLevel) or '✓')
 player:SetAttribute('BaseFull',total>=capacity)
 player:SetAttribute('CollectionCount',total)
end
local function upgrade(player)
 local s=states[player]
 local root=rootOf(player)
 if not s or not s.loaded or not s.canSave or s.upgrading or s.saving or not root or not s.base or (root.Position-(s.base+Vector3.new(19,2,18))).Magnitude>18 then return end
 local cost=Rules.upgradeCost(s.baseLevel)
 if not cost or s.coins<cost then return end
 s.upgrading=true
 if not save(player) then s.upgrading=false; return end
 s.saving=true
 local earnedBefore=s.savedCoins or 0
 local expected=s.baseLevel
 local purchased=false
 local ok,data=pcall(function()
  return store:UpdateAsync('player_'..player.UserId,function(old)
   purchased=false
   if type(old)~='table' then return nil end
   local result=Rules.purchaseBase(old,expected)
   purchased=result~=nil
   return result
  end)
 end)
 s.saving=false; s.upgrading=false
 if ok and purchased and data then
  s.baseLevel=data.baseLevel
  s.coins=data.coins+s.earned.coins-earnedBefore
  renderCollection(player); update(player)
 end
end
local function drop(player)
 local s=states[player]
 local root=rootOf(player)
 if not s or not s.carry or not root then return end
 local tree=s.carry
 stopCarry(player)
 tree.owner=nil
 tree.guardian.alerts[tree]=nil
 local highlight=tree.block:FindFirstChild('CarryHighlight')
 if highlight then highlight:Destroy() end
 -- A server-owned physical assembly falls under gravity.
 local main=tree.block.MainBlock
 main.Anchored=false
 main.CanCollide=true
 main.Massless=false
 tree.block:PivotTo(CFrame.new(root.Position+root.CFrame.LookVector*7))
 main:SetNetworkOwner(nil)
 main.AssemblyLinearVelocity=root.AssemblyLinearVelocity+root.CFrame.LookVector*8
 tree.available=true
 tree.droppedAt=os.clock()
 tree.prompt.ActionText='⬡'
 tree.prompt.Enabled=true
 tell(player,'Block left here! Pick it up later (returns to its biome after 10 minutes).')
end

local wingColors={Color3.fromRGB(236,242,255),Color3.fromRGB(94,216,255),Color3.fromRGB(204,135,255),Color3.fromRGB(255,211,93)}
local function characterWings(player,character)
 local torso=character:FindFirstChild('UpperTorso') or character:FindFirstChild('Torso')
 if not torso then return end
 local folder=Instance.new('Model')
 folder.Name='FlightWings'
 folder.Parent=character
 for _,side in {-1,1} do
  for feather=1,5 do
   local p=part('FlightFeather',Vector3.new(0.55,3.8-feather*0.25,0.3),torso.CFrame*CFrame.new(side*(0.8+feather*0.43),0.8-feather*0.2,0.65)*CFrame.Angles(0,0,-side*0.6),wingColors[1],Enum.Material.SmoothPlastic,folder)
   p.Anchored,p.CanCollide,p.Massless=false,false,true
   p.CanTouch=false
   local weld=Instance.new('Motor6D')
   weld.Name='FlightFeatherMotor'
   weld.C0=torso.CFrame:ToObjectSpace(p.CFrame)
   weld:SetAttribute('RestC0',weld.C0)
   weld:SetAttribute('Side',side)
   weld.Part0,weld.Part1,weld.Parent=torso,p,p
  end
 end
 local function recolor()
  local color=wingColors[(player:GetAttribute('WingTier') or 0)+1]
  for _,p in folder:GetChildren() do if p:IsA('BasePart') then p.Color=color end end
 end
 recolor()
 -- Character destruction releases this per-character connection.
 local connection=player:GetAttributeChangedSignal('WingTier'):Connect(recolor)
 folder.Destroying:Connect(function() connection:Disconnect() end)
end
local function flight(player,enabled)
 local s=states[player]
 local root=rootOf(player)
 if not s or not root then return end
 local h=player.Character:FindFirstChildOfClass('Humanoid')
 s.flying=enabled
 if enabled then tutorial(player,'toggle'); s.takeoffPosition=root.Position end
 s.direction=Vector3.zero
 s.inputTime=os.clock()
 h.AutoRotate=not enabled
 h.PlatformStand=enabled
 if s.velocity then s.velocity:Destroy(); s.velocity=nil end
 if s.align then s.align:Destroy(); s.align=nil end
 if s.attachment then s.attachment:Destroy(); s.attachment=nil end
 if enabled then
  s.liftUntil=os.clock()+0.45
  local attachment=Instance.new('Attachment')
  attachment.Parent=root
  local velocity=Instance.new('LinearVelocity')
  velocity.Attachment0=attachment
  velocity.RelativeTo=Enum.ActuatorRelativeTo.World
  velocity.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
  velocity.ForceLimitsEnabled=false
  velocity.VectorVelocity=Vector3.new(0,15,0)
  velocity.Parent=root
  local align=Instance.new('AlignOrientation')
  align.Attachment0,align.Mode=attachment,Enum.OrientationAlignmentMode.OneAttachment
  align.MaxTorque,align.Responsiveness=100000,12
  align.CFrame=root.CFrame.Rotation
  align.Parent=root
  s.velocity,s.align,s.attachment=velocity,align,attachment
  root.AssemblyLinearVelocity=Vector3.new(0,15,0)
 else
  h:ChangeState(Enum.HumanoidStateType.GettingUp)
 end
 player:SetAttribute('Flying',enabled)
end
local function cleanupFlight(player)
 local s=states[player]
 if not s then return end
 for _,key in {'velocity','align','attachment'} do
  if s[key] then s[key]:Destroy(); s[key]=nil end
 end
 s.flying=false
 player:SetAttribute('Flying',false)
end
local function characterAdded(player,character)
 local s=states[player]
 if not s then return end
 if s.carry then resetTree(s.carry) end
 cleanupFlight(player)
 local root=character:WaitForChild('HumanoidRootPart',10)
 local h=character:WaitForChild('Humanoid',10)
 if not root or not h or not character.Parent then return end
 character:PivotTo(CFrame.new(basePosition+Vector3.new(0,6,9)))
 characterWings(player,character)
 h.Died:Connect(function()
  if s.carry then resetTree(s.carry) end
  cleanupFlight(player)
 end)
end
local function joined(player)
 local s={baseLevel=0,tutorial=1,collection=table.create(#Rules.COLLECTIBLES,0),collectionEarned=table.create(#Rules.COLLECTIBLES,0),power=1,coins=0,deliveries=0,earned={power=0,coins=0,deliveries=0},loaded=false,canSave=false,session=HttpService:GenerateGUID(false),direction=Vector3.zero,flying=false,training=0,lastToggle=0,lastAction=0}
 states[player]=s
 player.RespawnLocation=spawn
 player:SetAttribute('SaveStatus','Loading')
 player:SetAttribute('Flying',false)
 update(player)
 player.CharacterAdded:Connect(function(character) characterAdded(player,character) end)
 if player.Character then task.spawn(characterAdded,player,player.Character) end
 task.spawn(function()
  local ok,data
  for attempt=1,3 do
   ok,data=pcall(function() return store:GetAsync('player_'..player.UserId) end)
   if ok then break end
   task.wait(attempt*2)
  end
  if states[player]~=s then return end
  if ok and type(data)=='table' then
   s.tutorial=if data.tutorialDone==true then 8 else 1
   if type(data.collection)=='table' then
    for i=1,#Rules.COLLECTIBLES do s.collection[i]=math.max(0,math.floor(tonumber(data.collection[i]) or 0)) end
   end
   s.baseLevel=Rules.migrateLevel(data.baseLevel,s.collection)
   s.power=math.clamp(tonumber(data.power) or 1,1,Rules.MAX_POWER)
   s.coins=math.max(0,tonumber(data.coins) or 0)
   s.deliveries=math.max(0,tonumber(data.deliveries) or 0)
  end
  s.loaded,s.canSave=true,ok
  renderCollection(player)
  player:SetAttribute('SaveStatus',if ok then 'Ready' else 'Session only — saving unavailable')
  update(player)
  if not ok then tell(player,'Progress could not load. You can play, but this session will not overwrite your saved progress.') end
 end)
end
Players.PlayerAdded:Connect(joined)
for _,player in Players:GetPlayers() do task.spawn(joined,player) end
Players.PlayerRemoving:Connect(function(player)
 local s=states[player]
 if not s then return end
 if s.carry then resetTree(s.carry) end
 for _,ring in rings do ring.cooldowns[player]=nil end
 while s.saving do task.wait(0.1) end
 save(player)
 if s.plot then s.plot:Destroy(); plotSlots[s.plotSlot]=nil end
 states[player]=nil
end)
remote.OnServerEvent:Connect(function(player,action,direction)
 local s=states[player]
 local root=rootOf(player)
 if not s or not root or type(action)~='string' then return end
 local now=os.clock()
 if action=='move' then
  if now-s.lastAction < 0.035 then return end
  s.lastAction=now
  if typeof(direction)~='Vector3' then return end
  for _,v in {direction.X,direction.Y,direction.Z} do if v~=v or math.abs(v)>10 then return end end
  s.direction=if direction.Magnitude>1 then direction.Unit else direction
  s.inputTime=now
 elseif action=='upgrade' then
  upgrade(player)
 elseif action=='drop' then
  drop(player)
 elseif action=='toggle' and now-s.lastToggle>0.5 and now>=(s.knockUntil or 0) then
  s.lastToggle=now
  flight(player,not s.flying)

 end
end)

 local tickTimer,saveTimer=0,0
RunService.Heartbeat:Connect(function(dt)
 tickTimer+=dt
 saveTimer+=dt
 local now=os.clock()
 for _,rotor in rotors do
  rotor.part.CFrame=CFrame.new(rotor.hub)*CFrame.Angles(0,0,now*1.8+rotor.angle)*CFrame.new(0,7,0)
 end
 for player,s in states do
  local root=rootOf(player)
  if not root then continue end
  if s.flying and s.velocity then
   local direction=if now-(s.inputTime or 0)<0.6 then s.direction else Vector3.zero
   local target=direction*Rules.speed(s.power,s.deliveries,s.carry~=nil)
   if now<(s.liftUntil or 0) then target=Vector3.new(target.X,math.max(12,target.Y),target.Z) end
   if (root.Position-trainingPosition).Magnitude<28 and root.Position.Y<ground+40 then
    target+=Vector3.new(0,7,0)
   end
   s.velocity.VectorVelocity=s.velocity.VectorVelocity:Lerp(target,math.min(1,dt*9))
   local flat=Vector3.new(direction.X,0,direction.Z)
   if flat.Magnitude>0.1 then s.align.CFrame=CFrame.lookAt(Vector3.zero,flat) end
  end
  if tickTimer>=0.2 and s.loaded then
   local offset=root.Position-trainingPosition
   local training=s.flying and math.abs(offset.X)<10 and math.abs(offset.Z)<10 and offset.Y>5 and offset.Y<39
   player:SetAttribute('Training',training)
   if training then
    s.training+=tickTimer
    if s.training>=2 then s.training-=2; gain(player,1,0,0); tutorial(player,'train') end
   else s.training=0 end
   for _,ring in rings do
    if s.flying and (root.Position-ring.position).Magnitude<6 and now-(ring.cooldowns[player] or -100)>8 then
     ring.cooldowns[player]=now
     gain(player,3,0,0)
     tutorial(player,'train')
     tell(player,'Great flying! Ring bonus: +3 Flight Power')
    end
   end
   if s.tutorial==2 and s.flying and s.takeoffPosition and root.Position.Y>s.takeoffPosition.Y+3 then tutorial(player,'fly') end
   if s.tutorial==4 then
    for _,tree in trees do
     if tree.available and (root.Position-tree.block.MainBlock.Position).Magnitude<=12 then tutorial(player,'approach'); break end
    end
   end
   if s.carry and not Rules.inZone(s.carry.guardian.zone,root.Position.X-origin.X,root.Position.Z-origin.Z) then tutorial(player,'escape') end
   if s.carry and s.base and (root.Position-s.base).Magnitude<26 and Rules.canStore(s.collection,s.baseLevel) then
    local tree=s.carry
    local oldTier=Rules.tier(s.deliveries)
    s.collection[tree.kind]+=1
    s.collectionEarned[tree.kind]+=1
    renderCollection(player)
    tutorial(player,'deliver')
    gain(player,tree.config.power,tree.config.coins,1)
    local rewardGlow=part('OpenedBlockReward',Vector3.new(4,4,4),CFrame.new(s.base+Vector3.new(0,7,0)),Color3.fromRGB(table.unpack(tree.config.color)),Enum.Material.Neon)
    rewardGlow.Shape,rewardGlow.CanCollide=Enum.PartType.Ball,false
    TweenService:Create(rewardGlow,TweenInfo.new(1.2),{Size=Vector3.new(22,22,22),Transparency=1}):Play()
    Debris:AddItem(rewardGlow,1.3)
    resetTree(tree,8)
    tell(player,'BLOCK ADDED TO YOUR BASE! +'..tree.config.coins..' coins  +'..tree.config.power..' Power'..(if Rules.tier(s.deliveries)>oldTier then ' | NEW WINGS!' else ''))
    task.spawn(save,player)
   end
   if root.Position.Y<ground-70 or (Vector3.new(root.Position.X,ground,root.Position.Z)-origin).Magnitude>2500 then
    if s.carry then resetTree(s.carry) end
    flight(player,false)
    player.Character:PivotTo(CFrame.new(basePosition+Vector3.new(0,6,9)))
    root.AssemblyLinearVelocity=Vector3.zero
   end
  end
 end
 for _,tree in trees do
  if tree.droppedAt and now-tree.droppedAt>600 then resetTree(tree) end
 end
 for _,guardian in guardians do
  local target,nearest=nil,math.huge
  local current=guardian.model:GetPivot().Position
  for tree in guardian.alerts do
   local root=tree.owner and rootOf(tree.owner)
   if root and now>=tree.wakeAt then
    local distance=(root.Position-current).Magnitude
    if distance<nearest then target={tree=tree,root=root}; nearest=distance end
   end
  end
  if target then
   guardian.status.Text='!'
   local root=target.root
   if Rules.guardianCanCatch(guardian.zone,root.Position.X-origin.X,root.Position.Z-origin.Z,current.X-origin.X,current.Z-origin.Z,nearest) then
    local player=target.tree.owner
    local state=states[player]
    if now>=(state.knockUntil or 0) then
     state.knockUntil=now+2
     if Rules.guardianCanReclaim(guardian.zone,root.Position.X-origin.X,root.Position.Z-origin.Z) then resetTree(target.tree,4) end
     flight(player,false)
     root.AssemblyLinearVelocity=Vector3.new(0,-65,0)
    end
   else
    local delta=root.Position-current
    if delta.Magnitude>0.01 then
     local pos=current+delta.Unit*math.min(delta.Magnitude,guardian.config.speed*math.min(dt,0.1))
     guardian.model:PivotTo(CFrame.lookAt(pos,root.Position))
    end
   end
  else
   guardian.status.Text='Zzz'
   guardian.model:PivotTo(guardian.model:GetPivot():Lerp(guardian.home,math.min(1,dt*3)))
  end
  local cf=guardian.model:GetPivot()
  for _,wing in guardian.wings do
   wing.part.CFrame=cf*CFrame.Angles(0,0,math.sin(now*(if target then 9 else 3))*0.3*wing.side)*wing.relative
  end
 end
 if tickTimer>=0.2 then tickTimer=0 end
 if saveTimer>=45 then
  saveTimer=0
  for player in states do task.spawn(save,player) end
 end
end)
game:BindToClose(function()
 for player in states do task.spawn(function()
  local s=states[player]
  while s and s.saving do task.wait(0.1) end
  save(player)
 end) end
 local deadline=os.clock()+25
 repeat
  task.wait(0.2)
  local saving=false
  for _,s in states do if s.saving then saving=true end end
  if not saving then break end
 until os.clock()>deadline
end)
print('v8 Wings & Base ready')
