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
panel.Size=UDim2.fromOffset(255,132)
panel.BackgroundColor3=Color3.fromRGB(17,43,39)
panel.BackgroundTransparency=0.12
panel.Parent=gui
rounded(panel)
local title=text(panel,'FLIGHT FOREST · 0.2',18)
title.Position,title.Size=UDim2.fromOffset(10,8),UDim2.new(1,-20,0,24)
local stats=text(panel,'Loading your wings...',17)
stats.Position,stats.Size=UDim2.fromOffset(10,36),UDim2.new(1,-20,0,48)
local status=text(panel,'',13)
status.Position,status.Size=UDim2.fromOffset(10,87),UDim2.new(1,-20,0,32)
local quest=text(gui,'',17)
quest.AnchorPoint=Vector2.new(0.5,0)
quest.Position,quest.Size=UDim2.new(0.5,0,0,155),UDim2.new(0.85,0,0,46)
quest.BackgroundTransparency=0.18
quest.BackgroundColor3=Color3.fromRGB(26,45,48)
rounded(quest)
local toast=text(gui,'',18)
toast.AnchorPoint=Vector2.new(0.5,0)
toast.Position,toast.Size=UDim2.new(0.5,0,0,208),UDim2.new(0.85,0,0,60)
toast.BackgroundColor3=Color3.fromRGB(37,83,71)
toast.BackgroundTransparency=0.1
toast.Visible=false
rounded(toast)
local toastId=0
notice.OnClientEvent:Connect(function(message)
 toastId+=1
 local id=toastId
 toast.Text=message
 toast.Visible=true
 task.delay(6,function() if id==toastId then toast.Visible=false end end)
end)
local function button(caption,offsetY,color)
 local b=Instance.new('TextButton')
 b.AnchorPoint=Vector2.new(1,1)
 b.Position=UDim2.new(1,-18,1,offsetY)
 b.Size=UDim2.fromOffset(106,58)
 b.Text,b.TextColor3=caption,Color3.new(1,1,1)
 b.BackgroundColor3=color
 b.Font,b.TextSize=Enum.Font.GothamBold,18
 b.AutoButtonColor=true
 b.Parent=gui
 rounded(b)
 return b
end
local up=button('▲ UP / עלייה',-284,Color3.fromRGB(47,132,156))
local down=button('▼ DOWN / ירידה',-218,Color3.fromRGB(47,132,156))
local fly=button('לעוף / F',-152,Color3.fromRGB(42,158,109))
local home=button('לבסיס',-86,Color3.fromRGB(92,91,128))
home.Size=UDim2.fromOffset(106,46)
local homeConfirmUntil=0
fly.Activated:Connect(function() action:FireServer('toggle') end)
home.Activated:Connect(function()
 if (player:GetAttribute('Carrying') or '')~='' and os.clock()>homeConfirmUntil then
  homeConfirmUntil=os.clock()+3
  home.Text='ביטול נשיאה?'
  task.delay(3,function() home.Text='לבסיס' end)
  return
 end
 action:FireServer('home')
 home.Text='לבסיס'
end)
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
 local coins=player:GetAttribute('Coins') or 0
 local delivered=player:GetAttribute('Deliveries') or 0
 stats.Text='Flight Power '..power..'  |  Coins '..coins..'\nWings '..Rules.tier(delivered)..'  |  Blocks '..delivered
 local carrying=player:GetAttribute('Carrying') or ''
 if carrying~='' then
  quest.Text='המפלצת בעקבותיך! החזר את הבלוק לקרן האור הירוקה בבסיס'
 elseif player:GetAttribute('Training') then
  quest.Text='אימון פעיל! הישאר ברוח הכחולה כדי לצבור כוח טיסה'
 elseif power<10 then
  quest.Text='לחץ לעוף • עלה ברוח הכחולה • חפש בלוק בעץ הנמוך'
 else
  quest.Text='אימון ← טיסה ← גניבת בלוק ← בריחה מהמפלצת ← פרס בבסיס'
 end
 fly.Text=if player:GetAttribute('Flying') then 'לנחות / F' else 'לעוף / F'
end
for _,name in {'FlightPower','Coins','Deliveries','Carrying','Training','Flying'} do
 player:GetAttributeChangedSignal(name):Connect(refresh)
end
refresh()
local sendTimer,hudTimer=0,0
RunService.RenderStepped:Connect(function(dt)
 sendTimer+=dt
 hudTimer+=dt
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass('Humanoid')
 local root=character and character:FindFirstChild('HumanoidRootPart')
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
  status.Text='Speed '..(player:GetAttribute('FlightSpeed') or 0)..' | Height '..altitude..' / '..(player:GetAttribute('MaxAltitude') or 83)..'\n'..(player:GetAttribute('SaveStatus') or 'Loading')
 end
end)
