local Players=game:GetService('Players')
local UserInputService=game:GetService('UserInputService')
local RunService=game:GetService('RunService')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local player=Players.LocalPlayer
local action=ReplicatedStorage:WaitForChild('FlightAction')
local notice=ReplicatedStorage:WaitForChild('FlightNotice')
local Rules=require(ReplicatedStorage:WaitForChild('FlightRules'))
local gui=Instance.new('ScreenGui')
gui.Name='FlightForestHUD'
gui.ResetOnSpawn=false
gui.DisplayOrder=10
gui.Parent=player:WaitForChild('PlayerGui')
local function rounded(obj)
 local c=Instance.new('UICorner')
 c.CornerRadius=UDim.new(0,14)
 c.Parent=obj
 local stroke=Instance.new('UIStroke')
 stroke.Color=Color3.fromRGB(121,221,196)
 stroke.Transparency=0.55
 stroke.Parent=obj
end
local function text(parent,content,size)
 local label=Instance.new('TextLabel')
 label.BackgroundTransparency=1
 label.TextColor3=Color3.fromRGB(239,255,247)
 label.Font=Enum.Font.GothamBold
 label.TextSize=size or 17
 label.TextWrapped=true
 label.Text=content
 label.Parent=parent
 return label
end
local panel=Instance.new('Frame')
panel.Position=UDim2.fromOffset(12,12)
panel.Size=UDim2.fromOffset(230,100)
panel.BackgroundColor3=Color3.fromRGB(17,43,39)
panel.BackgroundTransparency=0.12
panel.Parent=gui
rounded(panel)
local title=text(panel,Rules.VERSION,16)
title.Position,title.Size=UDim2.fromOffset(10,8),UDim2.new(1,-20,0,24)
local stats=text(panel,'…',17)
stats.Position,stats.Size=UDim2.fromOffset(10,36),UDim2.new(1,-20,0,48)
local status=text(panel,'',13)
status.Position,status.Size=UDim2.fromOffset(10,76),UDim2.new(1,-20,0,24)
-- Compact pictograms leave the flight view clear.
local carryingBadge=text(gui,'⬡',28)
carryingBadge.Position,carryingBadge.Size=UDim2.new(1,-160,1,-80),UDim2.fromOffset(40,40)
local guide=text(gui,'➤',40)
guide.AnchorPoint=Vector2.new(0.5,0.5)
guide.TextColor3=Color3.fromRGB(255,225,70)
guide.Size=UDim2.fromOffset(60,60)
local progress=text(gui,'',20)
progress.Position,progress.Size=UDim2.new(0.5,-90,0,12),UDim2.fromOffset(180,30)
local outline=Instance.new('Highlight')
outline.FillTransparency=0.8
outline.OutlineColor=Color3.fromRGB(255,225,70)
outline.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
outline.Parent=workspace
-- Server notices remain diagnostic data; core play uses world effects and symbols.
notice.OnClientEvent:Connect(function() end)
local function button(caption,offsetY,color)
 local b=Instance.new('TextButton')
 b.AnchorPoint=Vector2.new(1,1)
 b.Position=UDim2.new(1,-18,1,offsetY)
 b.Size=UDim2.fromOffset(106,58)
 b.Text,b.TextColor3=caption,Color3.new(1,1,1)
 b.BackgroundColor3=color
 b.Font,b.TextSize=Enum.Font.GothamBold,30
 b.AutoButtonColor=true
 b.Parent=gui
 rounded(b)
 return b
end
local up=button('▲',-284,Color3.fromRGB(47,132,156))
local down=button('▼',-218,Color3.fromRGB(47,132,156))
local fly=button('',-152,Color3.fromRGB(42,158,109))
-- Draw feather wings from UI shapes, independent of emoji/font availability.
local feathers={}
for _,side in {-1,1} do
 for i=1,4 do
  local f=Instance.new('Frame')
  f.AnchorPoint=Vector2.new(0.5,0.5)
  f.Size=UDim2.fromOffset(9,30-i*3)
  f.Position=UDim2.new(0.5,side*(8+i*7),0.5,4-i*3)
  f.Rotation=side*(25+i*9)
  f.BackgroundColor3=Color3.new(1,1,1)
  f.BorderSizePixel=0
  f.Parent=fly
  local corner=Instance.new('UICorner'); corner.CornerRadius=UDim.new(1,0); corner.Parent=f
  table.insert(feathers,{frame=f,side=side,index=i})
 end
end
local landing=text(fly,'↓',23)
landing.Size=UDim2.fromOffset(24,32); landing.Position=UDim2.new(0.5,-12,0.5,-16)
local upgrade=button('+5 ●',-86,Color3.fromRGB(170,126,35))
upgrade.TextSize=20
upgrade.Activated:Connect(function() action:FireServer('upgrade') end)
local stealButton=button('⬡',-350,Color3.fromRGB(180,143,34))
stealButton.Visible=false
local selectedPrompt=nil
local promptHolding=false
stealButton.InputBegan:Connect(function(input)
 if selectedPrompt and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then
  promptHolding=true; selectedPrompt:InputHoldBegin()
 end
end)
UserInputService.InputEnded:Connect(function(input)
 if promptHolding and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then
  promptHolding=false
  if selectedPrompt then selectedPrompt:InputHoldEnd() end
 end
end)
local drop=button('⬡ ↓',-20,Color3.fromRGB(165,109,48))
drop.Activated:Connect(function() action:FireServer('drop') end)
fly.Activated:Connect(function() action:FireServer('toggle') end)
local heldUp,heldDown={},{}
local function hold(buttonObj,held)
 buttonObj.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then held[input]=true end
 end)
end
hold(up,heldUp)
hold(down,heldDown)
UserInputService.InputEnded:Connect(function(input)
 heldUp[input],heldDown[input]=nil,nil
end)
local keys={}
UserInputService.InputBegan:Connect(function(input,processed)
 if processed or UserInputService:GetFocusedTextBox() then return end
 keys[input.KeyCode]=true
 if input.KeyCode==Enum.KeyCode.R then action:FireServer('drop') end
 if input.KeyCode==Enum.KeyCode.F then action:FireServer('toggle') end
end)
UserInputService.InputEnded:Connect(function(input) keys[input.KeyCode]=nil end)
local function clear()
 table.clear(keys); table.clear(heldUp); table.clear(heldDown)
end
UserInputService.WindowFocusReleased:Connect(clear)
player.CharacterAdded:Connect(clear)
local function refresh()
 local power=player:GetAttribute('FlightPower') or 1
 stats.Text='↑ '..power..'   ● '..(player:GetAttribute('Coins') or 0)..'   ⬡ '..(player:GetAttribute('CollectionCount') or 0)..' / '..(player:GetAttribute('BaseCapacity') or 5)
 local carrying=(player:GetAttribute('Carrying') or '')~=''
 carryingBadge.Visible=carrying
 drop.Visible=carrying
 landing.Visible=player:GetAttribute('Flying')==true
 fly.BackgroundColor3=if landing.Visible then Color3.fromRGB(40,118,185) else Color3.fromRGB(42,158,109)
 local step=player:GetAttribute('TutorialStep') or 1
 progress.Text=if step<=7 then string.rep('● ',step)..string.rep('○ ',7-step) else ''
end
local function guideTarget()
 local world=workspace:FindFirstChild('FlightForest')
 if not world then return nil,nil end
 local step=player:GetAttribute('TutorialStep') or 1
 if step==3 then
  local ring=world:FindFirstChild('TrainingRing1')
  local marker=ring and ring:FindFirstChild('RingMarker')
  return if marker then marker.Position else nil,ring
 elseif step==1 or step==2 then
  return nil,nil

 elseif (player:GetAttribute('Carrying') or '')~='' then
  local plot=world:FindFirstChild('Collection_'..player.UserId)
  local full=player:GetAttribute('BaseFull')
  local upgradePad=plot and plot:FindFirstChild('UpgradePad')
  return if full and upgradePad then upgradePad.Position else player:GetAttribute('BasePosition'),if full and upgradePad then upgradePad else plot
 elseif step>=4 and step<=7 then
  local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
  local target,distance=nil,math.huge
  if root then
   for _,model in world:GetChildren() do
    local main=model:IsA('Model') and model:FindFirstChild('MainBlock')
    local prompt=main and main:FindFirstChildOfClass('ProximityPrompt')
    if prompt and prompt.Enabled and (main.Position-root.Position).Magnitude<distance then
     target,distance=model,(main.Position-root.Position).Magnitude
    end
   end
  end
  return if target then target.MainBlock.Position else nil,target
 end
 return nil,nil
end
for _,name in {'FlightPower','Coins','Deliveries','Carrying','Training','Flying','TutorialStep','CollectionCount','BaseCapacity','UpgradeCost','BaseFull'} do
 player:GetAttributeChangedSignal(name):Connect(refresh)
end
refresh()
local sendTimer,hudTimer,wingPhase=0,0,0
RunService.RenderStepped:Connect(function(dt)
 local step=player:GetAttribute('TutorialStep') or 1
 local pulse=0.12+0.3*(1+math.sin(os.clock()*5))
 fly.BackgroundTransparency=if step==1 then pulse else 0
 up.BackgroundTransparency=if step==2 then pulse else 0
 stealButton.BackgroundTransparency=if step==5 then pulse else 0
 local rootNow=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 local base=player:GetAttribute('BasePosition')
 local cost=player:GetAttribute('UpgradeCost') or 0
 upgrade.Visible=rootNow~=nil and base~=nil and (rootNow.Position-(base+Vector3.new(19,2,18))).Magnitude<18 and cost>0
 upgrade.Text='+5 ● '..cost
 upgrade.BackgroundTransparency=if player:GetAttribute('BaseFull') then pulse else 0
 for _,feather in feathers do
  feather.frame.Rotation=feather.side*(25+feather.index*9+(if player:GetAttribute('Flying') then math.sin(os.clock()*5)*12 else 0))
 end
 local position,target=guideTarget()
 local nextPrompt=nil
 if rootNow then
  local world=workspace:FindFirstChild('FlightForest')
  local nearest=12
  if world then
   for _,model in world:GetChildren() do
    local main=model:IsA('Model') and model:FindFirstChild('MainBlock')
    local prompt=main and main:FindFirstChildOfClass('ProximityPrompt')
    if prompt and prompt.Enabled and (main.Position-rootNow.Position).Magnitude<nearest then
     nearest=(main.Position-rootNow.Position).Magnitude; nextPrompt=prompt
    end
   end
  end
 end
 if selectedPrompt~=nextPrompt then
  if promptHolding and selectedPrompt then selectedPrompt:InputHoldEnd() end
  promptHolding=false; selectedPrompt=nextPrompt
 end
 stealButton.Visible=selectedPrompt~=nil and (player:GetAttribute('Carrying') or '')==''
 outline.Adornee=target
 outline.OutlineTransparency=0.15+0.25*(1+math.sin(os.clock()*4))
 local camera=workspace.CurrentCamera
 guide.Visible=position~=nil and camera~=nil
 if position and camera then
  local viewport=camera.ViewportSize
  local projected,onScreen=camera:WorldToViewportPoint(position)
  local center=viewport/2
  local delta=Vector2.new(projected.X,projected.Y)-center
  if projected.Z<0 then delta=-delta end
  if delta.Magnitude<1 then delta=Vector2.new(0,-1) end
  local x=math.clamp(center.X+delta.X,60,viewport.X-150)
  local y=math.clamp(center.Y+delta.Y,100,viewport.Y-100)
  guide.Position=UDim2.fromOffset(x,y+math.sin(os.clock()*4)*6)
  guide.Rotation=if onScreen then 90 else math.deg(math.atan2(delta.Y,delta.X))
 end
 sendTimer+=dt
 hudTimer+=dt
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass('Humanoid')
 local root=character and character:FindFirstChild('HumanoidRootPart')
 -- Animate all visible players locally; Motor C0 preserves the feather shape.
 wingPhase+=dt
 for _,other in Players:GetPlayers() do
  local c=other.Character
  local r=c and c:FindFirstChild('HumanoidRootPart')
  local wings=c and c:FindFirstChild('FlightWings')
  if r and wings then
   local speed=r.AssemblyLinearVelocity.Magnitude
   local flying=other:GetAttribute('Flying')
   local amount=if flying then 0.15+math.clamp(speed/160,0,0.5) else 0.035
   for _,motor in wings:GetDescendants() do
    if motor:IsA('Motor6D') and motor.Name=='FlightFeatherMotor' then
     motor.C0=motor:GetAttribute('RestC0')*CFrame.Angles(0,0,math.sin(wingPhase*(if flying then 5+math.min(speed/10,8) else 2)) *amount*motor:GetAttribute('Side'))
    end
   end
  end
 end
 if sendTimer>=0.065 and humanoid and root and player:GetAttribute('Flying') then
  sendTimer=0
  local direction=humanoid.MoveDirection
  if direction.Magnitude<0.05 then
   local x=(if keys[Enum.KeyCode.D] then 1 else 0)-(if keys[Enum.KeyCode.A] then 1 else 0)
   local z=(if keys[Enum.KeyCode.S] then 1 else 0)-(if keys[Enum.KeyCode.W] then 1 else 0)
   local camera=workspace.CurrentCamera
   if camera then
    local look=Vector3.new(camera.CFrame.LookVector.X,0,camera.CFrame.LookVector.Z)
    if look.Magnitude>0.01 then direction=look.Unit*(-z)+camera.CFrame.RightVector*x end
   end
  end
  local rise=next(heldUp)~=nil or keys[Enum.KeyCode.E] or keys[Enum.KeyCode.Space]
  local descend=next(heldDown)~=nil or keys[Enum.KeyCode.Q]
  local vertical=(if rise then 1 else 0)-(if descend then 1 else 0)
  action:FireServer('move',Vector3.new(direction.X,vertical,direction.Z))
 end
 if hudTimer>=0.25 then
  hudTimer=0
  local altitude=if root then math.floor(root.Position.Y) else 0
  local saved=player:GetAttribute('SaveStatus') or ''
  status.Text='➤ '..(player:GetAttribute('FlightSpeed') or 0)..'   ↕ '..altitude..'   '..(if saved=='Saved' or saved=='Ready' then '✓' elseif saved=='Loading' then '…' else '⚠')
 end
end)
