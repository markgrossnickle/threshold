--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)

local ThresholdConfig = require(ReplicatedStorage.Shared.ThresholdConfig)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local EntityController = Knit.CreateController({
	Name = "EntityController",
})

local entityTrove = Trove.new()
local warningGui: ScreenGui? = nil
local warningFrame: Frame? = nil
local watcherLookTime: number = 0
local watcherActive: boolean = false

local function createWarningUI(): ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "EntityWarningUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Parent = PlayerGui
	warningGui = gui

	-- Vignette warning frame
	local frame = Instance.new("Frame")
	frame.Name = "WarningVignette"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	warningFrame = frame
end

local function pulseWarning(duration: number): ()
	if not warningFrame then
		return
	end
	local startTime = tick()
	while tick() - startTime < duration do
		local t = (tick() - startTime) / duration
		local pulse = math.sin(t * math.pi * 6) * 0.3 + 0.7
		warningFrame.BackgroundTransparency = pulse
		task.wait(1 / 30)
	end
	warningFrame.BackgroundTransparency = 1
end

local function cameraShake(intensity: number, duration: number): ()
	local startTime = tick()
	local originalCFrame = Camera.CFrame
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		if elapsed > duration then
			connection:Disconnect()
			return
		end
		local decay = 1 - (elapsed / duration)
		local offset = Vector3.new(
			(math.random() - 0.5) * intensity * decay,
			(math.random() - 0.5) * intensity * decay,
			0
		)
		Camera.CFrame = Camera.CFrame * CFrame.new(offset)
	end)
end

local function flashScreen(color: Color3, duration: number): ()
	if not warningGui then
		return
	end
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0
	flash.BorderSizePixel = 0
	flash.ZIndex = 20
	flash.Parent = warningGui

	local tween = TweenService:Create(flash, TweenInfo.new(duration), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		flash:Destroy()
	end)
end

function EntityController:KnitInit(): ()
	createWarningUI()
end

function EntityController:KnitStart(): ()
	local EntityService = Knit.GetService("EntityService")

	-- Warning phase
	EntityService.EntityWarning:Connect(function(entityType: string, duration: number)
		task.spawn(function()
			-- Flicker lights effect via warning
			pulseWarning(duration)
		end)
	end)

	-- Entity spawned
	EntityService.EntitySpawned:Connect(function(entityType: string, _position: Vector3)
		-- Jump scare effects
		flashScreen(Color3.fromRGB(255, 255, 255), 0.15)
		cameraShake(0.5, 0.5)

		-- Entity-specific effects
		if entityType == "Watcher" then
			watcherActive = true
			watcherLookTime = 0
			self:_startWatcherTracking()
		end
	end)

	-- Entity despawned
	EntityService.EntityDespawned:Connect(function(entityType: string)
		entityTrove:Clean()
		watcherActive = false
	end)

	-- Entity attack
	EntityService.EntityAttack:Connect(function(entityType: string, targetPlayer: Player)
		if targetPlayer == Player then
			-- Jump scare!
			flashScreen(Color3.fromRGB(200, 0, 0), 0.3)
			cameraShake(1.5, 0.8)
		end
	end)
end

function EntityController:_startWatcherTracking(): ()
	local EntityService = Knit.GetService("EntityService")

	local connection = RunService.RenderStepped:Connect(function(dt)
		if not watcherActive then
			return
		end

		-- Check if camera is looking at the Watcher entity
		local watcherModel = workspace:FindFirstChild("WatcherEntity", true)
		if not watcherModel or not watcherModel.PrimaryPart then
			return
		end

		local camCF = Camera.CFrame
		local toWatcher = (watcherModel.PrimaryPart.Position - camCF.Position).Unit
		local lookDir = camCF.LookVector
		local dot = lookDir:Dot(toWatcher)

		if dot > 0.7 then
			-- Looking at watcher
			watcherLookTime += dt
			if watcherLookTime >= ThresholdConfig.WatcherLookThreshold then
				EntityService:ReportWatcherLook()
				watcherActive = false
			end
		else
			watcherLookTime = math.max(0, watcherLookTime - dt * 0.5)
		end
	end)

	entityTrove:Add(connection)
end

return EntityController
