--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)

local ThresholdConfig = require(ReplicatedStorage.Shared.ThresholdConfig)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local RoomController = Knit.CreateController({
	Name = "RoomController",
})

local fadeFrame: Frame? = nil
local doorLabel: TextLabel? = nil
local screenGui: ScreenGui? = nil
local trove = Trove.new()

local function createUI(): ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RoomTransitionUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.Parent = PlayerGui
	screenGui = gui

	-- Fade overlay
	local frame = Instance.new("Frame")
	frame.Name = "FadeOverlay"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ZIndex = 10
	frame.Parent = gui
	fadeFrame = frame

	-- Door number label
	local label = Instance.new("TextLabel")
	label.Name = "DoorLabel"
	label.Size = UDim2.fromScale(0.4, 0.1)
	label.Position = UDim2.fromScale(0.3, 0.45)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.TextScaled = true
	label.Font = Enum.Font.Antique
	label.Text = ""
	label.TextTransparency = 1
	label.ZIndex = 11
	label.Parent = gui
	doorLabel = label
end

local function fadeToBlack(duration: number): ()
	if not fadeFrame then
		return
	end
	fadeFrame.BackgroundTransparency = 1
	local tween = TweenService:Create(fadeFrame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 0,
	})
	tween:Play()
	tween.Completed:Wait()
end

local function fadeFromBlack(duration: number): ()
	if not fadeFrame then
		return
	end
	fadeFrame.BackgroundTransparency = 0
	local tween = TweenService:Create(fadeFrame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	tween:Play()
	tween.Completed:Wait()
end

local function showDoorNumber(doorNumber: number): ()
	if not doorLabel then
		return
	end
	doorLabel.Text = "Door " .. doorNumber
	doorLabel.TextTransparency = 1

	local fadeIn = TweenService:Create(doorLabel, TweenInfo.new(0.5), { TextTransparency = 0 })
	fadeIn:Play()
	fadeIn.Completed:Wait()

	task.wait(ThresholdConfig.RoomNumberDisplayTime)

	local fadeOut = TweenService:Create(doorLabel, TweenInfo.new(0.5), { TextTransparency = 1 })
	fadeOut:Play()
end

function RoomController:KnitInit(): ()
	createUI()
end

function RoomController:KnitStart(): ()
	local RoomService = Knit.GetService("RoomService")
	local GameService = Knit.GetService("GameService")

	RoomService.RoomClearing:Connect(function()
		task.spawn(function()
			fadeToBlack(ThresholdConfig.RoomTransitionFadeTime)
		end)
	end)

	RoomService.RoomGenerated:Connect(function(_roomData)
		task.spawn(function()
			fadeFromBlack(ThresholdConfig.RoomTransitionFadeTime)
		end)
	end)

	GameService.DoorNumberChanged:Connect(function(doorNumber)
		task.spawn(function()
			showDoorNumber(doorNumber)
		end)
	end)
end

return RoomController
