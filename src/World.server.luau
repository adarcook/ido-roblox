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
local states, trees, rings, rotors = {}, {}, {}, {}
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
 player:SetAttribute('FlightPower',s.power)
 player:SetAttribute('Coins',s.coins)
 player:SetAttribute('Deliveries',s.deliveries)
 player:SetAttribute('WingTier',Rules.tier(s.deliveries))
 player:SetAttribute('FlightSpeed',math.floor(Rules.speed(s.power,s.deliveries,s.carry ~= nil)))
 player:SetAttribute('MaxAltitude',Rules.ceiling(s.power))
 player:SetAttribute('Carrying',if s.carry then s.carry.config.rarity else '')
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
 if not s or not s.loaded or not s.canSave or s.saving then return end
 s.saving = true
 local totals = table.clone(s.earned)
 local ok = pcall(function()
  store:UpdateAsync('player_'..player.UserId,function(old)
   old = if type(old)=='table' then old else {}
   local sessions = if type(old.sessions)=='table' then old.sessions else {}
   local applied = sessions[s.session] or {power=0,coins=0,deliveries=0}
   old.power = math.min(Rules.MAX_POWER,(tonumber(old.power) or 1)+math.max(0,totals.power-applied.power))
   old.coins = (tonumber(old.coins) or 0)+math.max(0,totals.coins-applied.coins)
   old.deliveries = (tonumber(old.deliveries) or 0)+math.max(0,totals.deliveries-applied.deliveries)
   sessions[s.session] = {power=totals.power,coins=totals.coins,deliveries=totals.deliveries,time=os.time()}
   -- Old closed sessions can be discarded; current retries keep their checkpoint.
   for key,value in sessions do
    if key ~= s.session and (value.time or 0) < os.time()-86400*7 then sessions[key]=nil end
   end
   old.sessions = sessions
   return old
  end)
 end)
 s.saving = false
 if player.Parent then player:SetAttribute('SaveStatus',if ok then 'Saved' else 'Save retry pending') end
 if not ok then warn('Flight progress save deferred for user',player.UserId) end
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
-- The floor and trees form a visible forest; the backup's world remains intact.
part('Meadow',Vector3.new(560,2,560),CFrame.new(origin+Vector3.new(0,-1,0)),Color3.fromRGB(83,147,86),Enum.Material.Grass)
for i=1,32 do
 local x,z = rng:NextNumber(-250,250),rng:NextNumber(-250,250)
 if Vector3.new(x,0,z).Magnitude > 65 then
  part('SmallTrunk',Vector3.new(3,14,3),CFrame.new(origin+Vector3.new(x,7,z)),Color3.fromRGB(104,71,47),Enum.Material.Wood)
  local leaf = part('SmallCrown',Vector3.new(18,17,18),CFrame.new(origin+Vector3.new(x,21,z)),Color3.fromRGB(58,rng:NextInteger(125,170),83),Enum.Material.Grass)
  leaf.Shape = Enum.PartType.Ball
  leaf.CanCollide = false
 end
end

-- Wooden wind trainer, moving blades and ascending rings.
local trainingPosition = origin+Vector3.new(-38,0,-32)
local deck = part('WindTrainingDeck',Vector3.new(26,2,26),CFrame.new(trainingPosition+Vector3.new(0,2,0)),Color3.fromRGB(153,106,61))
label(deck,'WIND TRAINING\nHover in the blue wind: +1 Power / 2 sec',Color3.fromRGB(166,226,255))
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
 label(marker,'RING '..i..'  +3 POWER',Color3.fromRGB(255,224,127),100)
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
 if not Rules.canSteal(s.power,tree.config.required,s.carry~=nil,tree.owner==nil and tree.available,distance) then
  if s.power<tree.config.required then tell(player,'Train first! This tree needs Power '..tree.config.required) end
  return
 end
 tree.available,tree.owner,tree.wakeAt=false,player,os.clock()+2.5
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
 tree.status.Text='WAKING UP!\nEscape to the green HOME beacon!'
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
 prompt.ActionText='Steal Lucky Block'
 prompt.ObjectText=tree.config.rarity..' | Power '..tree.config.required
 prompt.MaxActivationDistance,prompt.HoldDuration,prompt.RequiresLineOfSight=12,0.6,false
 prompt.Triggered:Connect(function(player) steal(player,tree) end)
 tree.block,tree.prompt=block,prompt
end
resetTree=function(tree, delaySeconds)
 local owner=tree.owner
 if owner then stopCarry(owner) end
 tree.owner,tree.available=nil,false
 if tree.block then tree.block:Destroy() end
 tree.monster:PivotTo(tree.monsterHome)
 tree.status.Text='Zzz... sleeping\n'..tree.config.rarity..' | Power '..tree.config.required
 task.delay(delaySeconds or 0,function()
  makeBlock(tree)
  tree.available=true
 end)
end
for index,config in Rules.TREES do
 local color=Color3.fromRGB(table.unpack(config.color))
 local location=origin+Vector3.new(config.x,0,config.z)
 local model=Instance.new('Model')
 model.Name=config.name
 model.Parent=world
 local trunk=part('AncientTrunk',Vector3.new(15,config.height,15),CFrame.new(location+Vector3.new(0,config.height/2,0)),Color3.fromRGB(115,77,48),Enum.Material.Wood,model)
 for j=1,4 do
  local y=config.height*(0.25+j*0.16)
  part('Branch',Vector3.new(42-j*3,3,9),CFrame.new(location+Vector3.new((if j%2==0 then -1 else 1)*8,y,0))*CFrame.Angles(0,j*0.8,0),Color3.fromRGB(133,93,57),Enum.Material.Wood,model)
 end
 local crown=part('Canopy',Vector3.new(58,30,58),CFrame.new(location+Vector3.new(0,config.height+10,0)),color,Enum.Material.Grass,model)
 crown.Shape,crown.CanCollide=Enum.PartType.Ball,false
 local landing=location+Vector3.new(24,config.height,0)
 part('TreasureBranch',Vector3.new(40,3,15),CFrame.new(landing-Vector3.new(10,0,0)),Color3.fromRGB(165,115,63),Enum.Material.Wood,model)
 label(trunk,config.name..'\n'..config.rarity..' · Power '..config.required,color,350)
 local monster=Instance.new('Model')
 monster.Name='SleepingMonster'..index
 monster.Parent=world
 local home=CFrame.new(landing+Vector3.new(-4,8,8))
 local body=part('MonsterBody',Vector3.new(10,9,9),home,color,Enum.Material.SmoothPlastic,monster)
 body.Shape,body.CanCollide=Enum.PartType.Ball,false
 monster.PrimaryPart=body
 for _,side in {-1,1} do
  local eye=part('Eye',Vector3.new(2,0.6,0.5),home*CFrame.new(side*2,1,-4.4),Color3.fromRGB(37,26,50),Enum.Material.Neon,monster)
  eye.CanCollide=false
  local wing=part('MonsterWing',Vector3.new(8,1.5,6),home*CFrame.new(side*7,0,0)*CFrame.Angles(0,0,side*0.3),color,Enum.Material.Wood,monster)
  wing.CanCollide=false
 end
 local tree={config=config,home=CFrame.new(landing+Vector3.new(6,5,0)),monster=monster,monsterHome=home,available=true}
 tree.status=label(body,'Zzz... sleeping\n'..config.rarity..' | Power '..config.required,color,190)
 table.insert(trees,tree)
 makeBlock(tree)
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
   local weld=Instance.new('WeldConstraint')
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
 local s={power=1,coins=0,deliveries=0,earned={power=0,coins=0,deliveries=0},loaded=false,canSave=false,session=HttpService:GenerateGUID(false),direction=Vector3.zero,flying=false,training=0,lastToggle=0,lastAction=0}
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
   s.power=math.clamp(tonumber(data.power) or 1,1,Rules.MAX_POWER)
   s.coins=math.max(0,tonumber(data.coins) or 0)
   s.deliveries=math.max(0,tonumber(data.deliveries) or 0)
  end
  s.loaded,s.canSave=true,ok
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
 elseif action=='toggle' and now-s.lastToggle>0.5 then
  s.lastToggle=now
  flight(player,not s.flying)
 elseif action=='home' and now-s.lastToggle>1 then
  s.lastToggle=now
  if s.carry then resetTree(s.carry) end
  flight(player,false)
  player.Character:PivotTo(CFrame.new(basePosition+Vector3.new(0,6,9)))
  root.AssemblyLinearVelocity=Vector3.zero
  tell(player,'Back home. Fly to the wooden wind trainer to grow stronger!')
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
   if root.Position.Y-origin.Y>Rules.ceiling(s.power) then
    target=Vector3.new(target.X,math.min(-5,target.Y),target.Z)
   end
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
    if s.training>=2 then s.training-=2; gain(player,1,0,0) end
   else s.training=0 end
   for _,ring in rings do
    if s.flying and (root.Position-ring.position).Magnitude<6 and now-(ring.cooldowns[player] or -100)>8 then
     ring.cooldowns[player]=now
     gain(player,3,0,0)
     tell(player,'Great flying! Ring bonus: +3 Flight Power')
    end
   end
   if s.carry and (root.Position-basePosition).Magnitude<23 then
    local tree=s.carry
    local oldTier=Rules.tier(s.deliveries)
    gain(player,tree.config.power,tree.config.coins,1)
    local rewardGlow=part('OpenedBlockReward',Vector3.new(4,4,4),CFrame.new(basePosition+Vector3.new(0,7,0)),Color3.fromRGB(table.unpack(tree.config.color)),Enum.Material.Neon)
    rewardGlow.Shape,rewardGlow.CanCollide=Enum.PartType.Ball,false
    TweenService:Create(rewardGlow,TweenInfo.new(1.2),{Size=Vector3.new(22,22,22),Transparency=1}):Play()
    Debris:AddItem(rewardGlow,1.3)
    resetTree(tree,8)
    tell(player,'BLOCK OPENED! +'..tree.config.coins..' coins  +'..tree.config.power..' Power'..(if Rules.tier(s.deliveries)>oldTier then ' | NEW WINGS!' else ''))
    task.spawn(save,player)
   end
   if root.Position.Y<ground-70 or (Vector3.new(root.Position.X,ground,root.Position.Z)-origin).Magnitude>850 then
    if s.carry then resetTree(s.carry) end
    flight(player,false)
    player.Character:PivotTo(CFrame.new(basePosition+Vector3.new(0,6,9)))
    root.AssemblyLinearVelocity=Vector3.zero
   end
  end
 end
 for _,tree in trees do
  if tree.owner then
   local root=rootOf(tree.owner)
   if not root then resetTree(tree); continue end
   if now>=tree.wakeAt then
    tree.status.Text='AWAKE!\nChasing the thief!'
    local current=tree.monster:GetPivot().Position
    local delta=root.Position-current
    if delta.Magnitude<7 then
     local player=tree.owner
     resetTree(tree,4)
     flight(player,false)
     player.Character:PivotTo(CFrame.new(basePosition+Vector3.new(0,6,9)))
     root.AssemblyLinearVelocity=Vector3.new(0,10,15)
     tell(player,'Caught! The block returned to its tree. Your progress is safe — try again!')
    elseif delta.Magnitude>0.1 then
     local position=current+delta.Unit*math.min(delta.Magnitude,tree.config.speed*math.min(dt,0.1))
     tree.monster:PivotTo(CFrame.lookAt(position,root.Position))
    end
   end
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
print('Flight Forest ready: all eight stages, four trees, tablet flight, training and rewards')
