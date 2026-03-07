--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local ThresholdConfig = require(ReplicatedStorage.Shared.ThresholdConfig)
local PlatformUtil = require(ReplicatedStorage.Shared.PlatformUtil)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local PlayerController = Knit.CreateController({
	Name = "PlayerController",
})

local PlayerService
local flashlightPart: Part? = nil
local spotLight: SpotLight? = nil

-- UI references
local hpFill: Frame? = nil
local staminaBar: Frame? = nil
local staminaFill: Frame? = nil
local batteryBar: Frame? = nil
local batteryFill: Frame? = nil
local interactPrompt: TextLabel? = nil
local doorCounter: TextLabel? = nil
local damageOverlay: ImageLabel? = nil

local function createMobileButtons(gui: ScreenGui): ()
	local btnSize = ThresholdConfig.MobileButtonSize
	local padding = 10

	local function makeButton(name: string, text: string, posX: number, posY: number): TextButton
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0, btnSize, 0, btnSize)
		btn.Position = UDim2.new(1, posX, 1, posY)
		btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		btn.BackgroundTransparency = 0.4
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Text = text
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = btn
		return btn
	end

	local flashlightBtn = makeButton("FlashlightBtn", "F", -(btnSize + padding), -(btnSize * 3 + padding * 3))
	local sprintBtn = makeButton("SprintBtn", "RUN", -(btnSize + padding), -(btnSize * 2 + padding * 2))
	local crouchBtn = makeButton("CrouchBtn", "C", -(btnSize + padding), -(btnSize + padding))
	local interactBtn = makeButton("InteractBtn", "E", -(btnSize * 2 + padding * 2), -(btnSize * 2 + padding * 2))

	flashlightBtn.Activated:Connect(function()
		PlayerService:ToggleFlashlight()
	end)

	sprintBtn.Activated:Connect(function()
		PlayerService:SetSprinting(true)
		task.delay(0.5, function()
			PlayerService:SetSprinting(false)
		end)
	end)

	local crouching = false
	crouchBtn.Activated:Connect(function()
		crouching = not crouching
		PlayerService:SetCrouching(crouching)
	end)

	interactBtn.Activated:Connect(function()
		PlayerController:TryInteract()
	end)
end

local function createHUD(): ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ThresholdHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = PlayerGui

	-- HP bar (top left)
	local hpContainer = Instance.new("Frame")
	hpContainer.Name = "HPBar"
	hpContainer.Size = UDim2.new(0, 200, 0, 8)
	hpContainer.Position = UDim2.new(0, 20, 0, 50)
	hpContainer.BackgroundColor3 = Color3.fromRGB(40, 10, 10)
	hpContainer.BorderSizePixel = 0
	hpContainer.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = hpContainer

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
	fill.BorderSizePixel = 0
	fill.Parent = hpContainer
	hpFill = fill

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	-- Stamina bar (below crosshair, only visible when sprinting)
	local staminaContainer = Instance.new("Frame")
	staminaContainer.Name = "StaminaBar"
	staminaContainer.Size = UDim2.new(0, 120, 0, 4)
	staminaContainer.Position = UDim2.new(0.5, -60, 0.55, 0)
	staminaContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	staminaContainer.BorderSizePixel = 0
	staminaContainer.Visible = false
	staminaContainer.Parent = gui
	staminaBar = staminaContainer

	local stCorner = Instance.new("UICorner")
	stCorner.CornerRadius = UDim.new(0, 2)
	stCorner.Parent = staminaContainer

	local stFill = Instance.new("Frame")
	stFill.Name = "Fill"
	stFill.Size = UDim2.fromScale(1, 1)
	stFill.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
	stFill.BorderSizePixel = 0
	stFill.Parent = staminaContainer
	staminaFill = stFill

	local stFillCorner = Instance.new("UICorner")
	stFillCorner.CornerRadius = UDim.new(0, 2)
	stFillCorner.Parent = stFill

	-- Battery bar (top right)
	local battContainer = Instance.new("Frame")
	battContainer.Name = "BatteryBar"
	battContainer.Size = UDim2.new(0, 150, 0, 8)
	battContainer.Position = UDim2.new(1, -170, 0, 50)
	battContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 10)
	battContainer.BorderSizePixel = 0
	battContainer.Visible = false
	battContainer.Parent = gui
	batteryBar = battContainer

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 4)
	bCorner.Parent = battContainer

	local bFill = Instance.new("Frame")
	bFill.Name = "Fill"
	bFill.Size = UDim2.fromScale(1, 1)
	bFill.BackgroundColor3 = Color3.fromRGB(220, 200, 50)
	bFill.BorderSizePixel = 0
	bFill.Parent = battContainer
	batteryFill = bFill

	local bFillCorner = Instance.new("UICorner")
	bFillCorner.CornerRadius = UDim.new(0, 4)
	bFillCorner.Parent = bFill

	-- Door counter (top center)
	local counter = Instance.new("TextLabel")
	counter.Name = "DoorCounter"
	counter.Size = UDim2.new(0, 200, 0, 30)
	counter.Position = UDim2.new(0.5, -100, 0, 15)
	counter.BackgroundTransparency = 1
	counter.TextColor3 = Color3.fromRGB(180, 180, 180)
	counter.TextScaled = true
	counter.Font = Enum.Font.Gotham
	counter.Text = "Door 0/100"
	counter.Parent = gui
	doorCounter = counter

	-- Interact prompt
	local prompt = Instance.new("TextLabel")
	prompt.Name = "InteractPrompt"
	prompt.Size = UDim2.new(0, 200, 0, 40)
	prompt.Position = UDim2.new(0.5, -100, 0.65, 0)
	prompt.BackgroundTransparency = 1
	prompt.TextColor3 = Color3.fromRGB(255, 255, 255)
	prompt.TextScaled = true
	prompt.Font = Enum.Font.GothamBold
	prompt.Text = "[E] Interact"
	prompt.Visible = false
	prompt.TextStrokeTransparency = 0.5
	prompt.Parent = gui
	interactPrompt = prompt

	-- Damage overlay
	local dmg = Instance.new("ImageLabel")
	dmg.Name = "DamageOverlay"
	dmg.Size = UDim2.fromScale(1, 1)
	dmg.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	dmg.BackgroundTransparency = 1
	dmg.ImageTransparency = 1
	dmg.BorderSizePixel = 0
	dmg.ZIndex = 5
	dmg.Parent = gui
	damageOverlay = dmg

	-- Mobile buttons
	if PlatformUtil.isMobile() or PlatformUtil.hasTouchScreen() then
		createMobileButtons(gui)
	end
end

local function createFlashlight(): ()
	local character = Player.Character
	if not character then
		return
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end

	if flashlightPart then
		flashlightPart:Destroy()
	end

	local part = Instance.new("Part")
	part.Name = "FlashlightPart"
	part.Anchored = false
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = part
	weld.Parent = part

	part.CFrame = head.CFrame

	local light = Instance.new("SpotLight")
	light.Name = "Flashlight"
	light.Brightness = ThresholdConfig.FlashlightBrightness
	light.Range = ThresholdConfig.FlashlightRange
	light.Angle = ThresholdConfig.FlashlightAngle
	light.Color = Color3.fromRGB(255, 250, 230)
	light.Face = Enum.NormalId.Front
	light.Enabled = false
	light.Parent = part

	flashlightPart = part
	spotLight = light
end

function PlayerController:TryInteract(): ()
	local character = Player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local closestDist = 8
	local closestTarget: Instance? = nil

	for _, obj in workspace:GetDescendants() do
		if obj:FindFirstChild("Interactable") and obj:IsA("BasePart") then
			local dist = (obj.Position - root.Position).Magnitude
			if dist < closestDist then
				closestDist = dist
				closestTarget = obj
			end
		end
	end

	if closestTarget then
		local interactType = closestTarget:FindFirstChild("InteractType") :: StringValue?
		if interactType then
			local val = interactType.Value
			if val == "Lever" then
				local index = closestTarget:FindFirstChild("LeverIndex") :: IntValue?
				if index then
					local PuzzleService = Knit.GetService("PuzzleService")
					PuzzleService:SubmitInput(index.Value)
				end
			elseif val == "FuelCanister" then
				local PuzzleService = Knit.GetService("PuzzleService")
				PuzzleService:SubmitFuelCanister()
				closestTarget:Destroy()
			else
				-- Key, Search, Mimic — all handled server-side
				PlayerService:Interact(closestTarget:GetFullName())
			end
		end
	end
end

function PlayerController:KnitInit(): ()
	createHUD()
end

function PlayerController:KnitStart(): ()
	PlayerService = Knit.GetService("PlayerService")
	local GameService = Knit.GetService("GameService")

	Player.CharacterAdded:Connect(function()
		task.wait(0.5)
		createFlashlight()
	end)
	if Player.Character then
		createFlashlight()
	end

	PlayerService.HPChanged:Connect(function(hp: number)
		if hpFill then
			hpFill.Size = UDim2.fromScale(hp / ThresholdConfig.MaxHP, 1)
		end
		if damageOverlay and hp < ThresholdConfig.MaxHP then
			damageOverlay.BackgroundTransparency = 0.5
			task.delay(0.3, function()
				if damageOverlay then
					damageOverlay.BackgroundTransparency = 1
				end
			end)
		end
	end)

	PlayerService.StaminaChanged:Connect(function(stamina: number)
		if staminaFill then
			staminaFill.Size = UDim2.fromScale(stamina, 1)
		end
		if staminaBar then
			staminaBar.Visible = stamina < 1
		end
	end)

	PlayerService.BatteryChanged:Connect(function(battery: number)
		if batteryFill then
			batteryFill.Size = UDim2.fromScale(battery, 1)
		end
	end)

	PlayerService.FlashlightToggled:Connect(function(isOn: boolean)
		if spotLight then
			spotLight.Enabled = isOn
		end
		if batteryBar then
			batteryBar.Visible = isOn
		end
	end)

	GameService.DoorNumberChanged:Connect(function(doorNumber: number)
		if doorCounter then
			doorCounter.Text = "Door " .. doorNumber .. "/" .. ThresholdConfig.MaxDoors
		end
	end)

	PlayerService.KeyPickedUp:Connect(function()
		if interactPrompt then
			interactPrompt.Text = "KEY FOUND - Go to exit door"
			interactPrompt.Visible = true
			task.delay(3, function()
				if interactPrompt then
					interactPrompt.Visible = false
				end
			end)
		end
	end)

	self:_bindInputs()
	self:_startInteractCheck()
end

function PlayerController:_bindInputs(): ()
	ContextActionService:BindAction("ToggleFlashlight", function(_, state)
		if state == Enum.UserInputState.Begin then
			PlayerService:ToggleFlashlight()
		end
	end, false, Enum.KeyCode.F)

	ContextActionService:BindAction("Sprint", function(_, state)
		if state == Enum.UserInputState.Begin then
			PlayerService:SetSprinting(true)
		elseif state == Enum.UserInputState.End then
			PlayerService:SetSprinting(false)
		end
	end, false, Enum.KeyCode.LeftShift)

	local crouching = false
	ContextActionService:BindAction("Crouch", function(_, state)
		if state == Enum.UserInputState.Begin then
			crouching = not crouching
			PlayerService:SetCrouching(crouching)
		end
	end, false, Enum.KeyCode.C, Enum.KeyCode.LeftControl)

	ContextActionService:BindAction("Interact", function(_, state)
		if state == Enum.UserInputState.Begin then
			self:TryInteract()
		end
	end, false, Enum.KeyCode.E)

	ContextActionService:BindAction("UseKey", function(_, state)
		if state == Enum.UserInputState.Begin then
			PlayerService:UseKey()
		end
	end, false, Enum.KeyCode.Q)

	if PlatformUtil.isGamepad() then
		ContextActionService:BindAction("GP_Flashlight", function(_, state)
			if state == Enum.UserInputState.Begin then
				PlayerService:ToggleFlashlight()
			end
		end, false, Enum.KeyCode.ButtonL2)

		ContextActionService:BindAction("GP_Sprint", function(_, state)
			if state == Enum.UserInputState.Begin then
				PlayerService:SetSprinting(true)
			elseif state == Enum.UserInputState.End then
				PlayerService:SetSprinting(false)
			end
		end, false, Enum.KeyCode.ButtonA)

		ContextActionService:BindAction("GP_Crouch", function(_, state)
			if state == Enum.UserInputState.Begin then
				crouching = not crouching
				PlayerService:SetCrouching(crouching)
			end
		end, false, Enum.KeyCode.ButtonL1)

		ContextActionService:BindAction("GP_Interact", function(_, state)
			if state == Enum.UserInputState.Begin then
				self:TryInteract()
			end
		end, false, Enum.KeyCode.ButtonR2)
	end
end

function PlayerController:_startInteractCheck(): ()
	task.spawn(function()
		while true do
			task.wait(0.2)
			local character = Player.Character
			if not character then
				continue
			end
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end

			local nearInteractable = false
			for _, obj in workspace:GetDescendants() do
				if obj:FindFirstChild("Interactable") and obj:IsA("BasePart") then
					if (obj.Position - root.Position).Magnitude < 8 then
						nearInteractable = true
						break
					end
				end
			end

			if interactPrompt and interactPrompt.Text == "[E] Interact" then
				interactPrompt.Visible = nearInteractable
			end

			-- Check if near exit door with key
			local exitDoor = workspace:FindFirstChild("ExitDoor", true) :: BasePart?
			if exitDoor then
				local locked = exitDoor:FindFirstChild("Locked") :: BoolValue?
				if locked and locked.Value and (exitDoor.Position - root.Position).Magnitude < 8 then
					if interactPrompt then
						interactPrompt.Text = "[Q] Use Key"
						interactPrompt.Visible = true
					end
				end
			end
		end
	end)
end

return PlayerController
