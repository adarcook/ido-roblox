local RunService = game:GetService("RunService")

local luckyBlock = script.Parent
local mainBlock = luckyBlock:WaitForChild("MainBlock")

local leftMotor = mainBlock:WaitForChild("LeftWingMotor")
local rightMotor = mainBlock:WaitForChild("RightWingMotor")

local leftPosition = CFrame.new(-mainBlock.Size.X / 2, 0.3, 0)
local rightPosition = CFrame.new(mainBlock.Size.X / 2, 0.3, 0)

local BASE_ANGLE = 24
local FLAP_AMOUNT = 12
local SPEED = 3.6

local t = 0

RunService.Heartbeat:Connect(function(dt)
	t += dt

	local mainWave = math.sin(t * SPEED)
	local softWave = math.sin(t * SPEED * 2 + 0.4) * 1.3

	local angle = BASE_ANGLE + mainWave * FLAP_AMOUNT + softWave

	leftMotor.C0 =
		leftPosition
		* CFrame.Angles(0, 0, math.rad(-angle))

	rightMotor.C0 =
		rightPosition
		* CFrame.Angles(0, 0, math.rad(angle))
end)
