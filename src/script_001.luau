local luckyBlock = script.Parent
local mainBlock = luckyBlock:WaitForChild("MainBlock")
local prompt = mainBlock:WaitForChild("ProximityPrompt")

local isStolen = false

local CARRY_ANIMATION_ID = "rbxassetid://76020890425719"

print("✅ StealScript loaded")

prompt.Triggered:Connect(function(player)

	print("🔥 Steal triggered by", player.Name)

	if isStolen then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not rootPart or not humanoid then
		return
	end

	isStolen = true
	prompt.Enabled = false

	-- הופכים את כל חלקי הלאקי בלוק לניידים
	for _, obj in ipairs(luckyBlock:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = false
			obj.CanCollide = false
			obj.Massless = true
		end
	end

	-- שמים את כל המודל מול השחקן
	luckyBlock:PivotTo(
		rootPart.CFrame * CFrame.new(0, 0.5, -3)
	)

	-- מחברים את הגוף המרכזי לשחקן
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = rootPart
	weld.Part1 = mainBlock
	weld.Parent = mainBlock

	print("✅ LuckyBlock attached")

	-- אנימציית נשיאה
	local animator = humanoid:FindFirstChildOfClass("Animator")

	if animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = CARRY_ANIMATION_ID

		local success, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)

		if success then
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Action
			track:Play()
		else
			warn("Carry animation failed")
		end
	end
end)