--!strict
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)

local ThresholdConfig = require(ReplicatedStorage.Shared.ThresholdConfig)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local AtmosphereController = Knit.CreateController({
	Name = "AtmosphereController",
})

local roomTrove = Trove.new()

-- Sound references
local heartbeat: Sound? = nil

local function setupLighting(): ()
	Lighting.Ambient = ThresholdConfig.AmbientLight
	Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
	Lighting.Brightness = 0
	Lighting.ClockTime = 0
	Lighting.GlobalShadows = true
	Lighting.Technology = Enum.Technology.Future

	-- Fog
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.5
	atmosphere.Color = Color3.fromRGB(10, 10, 15)
	atmosphere.Decay = Color3.fromRGB(5, 5, 8)
	atmosphere.Glare = 0
	atmosphere.Haze = 8

	-- Fog via FogEnd
	Lighting.FogEnd = ThresholdConfig.BaseFogEnd
	Lighting.FogStart = 10
	Lighting.FogColor = Color3.fromRGB(5, 5, 8)

	-- Color correction
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Parent = Lighting
	end
	cc.Brightness = -0.05
	cc.Contrast = 0.1
	cc.Saturation = -0.3
	cc.TintColor = Color3.fromRGB(240, 230, 255)
end

local function setupSounds(): ()
	-- Ambient drone
	local drone = Instance.new("Sound")
	drone.Name = "AmbientDrone"
	drone.SoundId = "" -- placeholder, no asset IDs
	drone.Looped = true
	drone.Volume = 0.3
	drone.Parent = SoundService

	-- Heartbeat
	local hb = Instance.new("Sound")
	hb.Name = "Heartbeat"
	hb.SoundId = "" -- placeholder
	hb.Looped = true
	hb.Volume = 0
	hb.PlaybackSpeed = 1
	hb.Parent = SoundService
	heartbeat = hb
end

local function createGrainOverlay(): ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FilmGrain"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1
	gui.Parent = PlayerGui

	-- Semi-transparent noise frame
	local grain = Instance.new("Frame")
	grain.Name = "Grain"
	grain.Size = UDim2.fromScale(1, 1)
	grain.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	grain.BackgroundTransparency = 0.95
	grain.BorderSizePixel = 0
	grain.Parent = gui

	-- Vignette (dark edges)
	local vignette = Instance.new("ImageLabel")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundTransparency = 1
	vignette.ImageColor3 = Color3.fromRGB(0, 0, 0)
	vignette.ImageTransparency = 0.3
	vignette.ZIndex = 2
	vignette.Parent = gui
end

function AtmosphereController:SetRoomAtmosphere(roomType: string, doorNumber: number): ()
	roomTrove:Clean()

	local fogEnd = ThresholdConfig.BaseFogEnd
	local ambient = ThresholdConfig.AmbientLight

	-- Darken with progression
	local darkenFactor = 1 - doorNumber * ThresholdConfig.DifficultyScaling.lightReduction
	darkenFactor = math.clamp(darkenFactor, 0.3, 1)

	if roomType == "Dark" then
		fogEnd = ThresholdConfig.DarkRoomFogEnd
		ambient = ThresholdConfig.DarkRoomAmbient
	elseif roomType == "Safe" then
		fogEnd = 300
		ambient = Color3.fromRGB(40, 35, 30)
	elseif roomType == "Entity" then
		fogEnd = ThresholdConfig.BaseFogEnd * 0.7
	end

	fogEnd *= darkenFactor

	-- Tween lighting
	TweenService:Create(Lighting, TweenInfo.new(1), {
		FogEnd = fogEnd,
		Ambient = ambient,
	}):Play()

	-- Heartbeat speed based on door number
	if heartbeat then
		heartbeat.PlaybackSpeed = 1 + doorNumber * 0.005
		heartbeat.Volume = math.clamp(doorNumber * 0.003, 0, 0.4)
	end

	-- Light flicker in non-safe rooms
	if roomType ~= "Safe" then
		local flickerConnection = RunService.Heartbeat:Connect(function()
			if math.random() < 0.005 then
				-- Brief flicker
				local origAmbient = Lighting.Ambient
				Lighting.Ambient = Color3.fromRGB(2, 2, 3)
				task.delay(0.05 + math.random() * 0.1, function()
					Lighting.Ambient = origAmbient
				end)
			end
		end)
		roomTrove:Add(flickerConnection)
	end
end

function AtmosphereController:SetEntityProximityEffect(intensity: number): ()
	if heartbeat then
		heartbeat.Volume = math.clamp(intensity * 0.5, 0, 0.5)
		heartbeat.PlaybackSpeed = 1 + intensity * 0.5
	end

	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		cc.Saturation = -0.3 - intensity * 0.4
	end
end

function AtmosphereController:KnitInit(): ()
	setupLighting()
	setupSounds()
	createGrainOverlay()
end

function AtmosphereController:KnitStart(): ()
	local RoomService = Knit.GetService("RoomService")
	local GameService = Knit.GetService("GameService")

	RoomService.RoomGenerated:Connect(function(roomData)
		self:SetRoomAtmosphere(roomData.RoomType, roomData.DoorNumber)
	end)

	GameService.GameOver:Connect(function()
		roomTrove:Clean()
		if heartbeat then
			heartbeat.Volume = 0
		end
	end)

	GameService.Victory:Connect(function()
		roomTrove:Clean()
		if heartbeat then
			heartbeat.Volume = 0
		end
		-- Bright victory lighting
		TweenService:Create(Lighting, TweenInfo.new(2), {
			FogEnd = 1000,
			Ambient = Color3.fromRGB(100, 90, 80),
		}):Play()
	end)
end

return AtmosphereController
