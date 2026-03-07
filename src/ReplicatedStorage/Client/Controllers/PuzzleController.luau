--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local PuzzleController = Knit.CreateController({
	Name = "PuzzleController",
})

local puzzleTrove = Trove.new()
local numberPadInput: { number } = {}

local function createNumberPadUI(): ()
	local PuzzleService = Knit.GetService("PuzzleService")

	local gui = Instance.new("ScreenGui")
	gui.Name = "NumberPadUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Parent = PlayerGui
	puzzleTrove:Add(gui)

	local frame = Instance.new("Frame")
	frame.Name = "PadFrame"
	frame.Size = UDim2.fromScale(0.25, 0.45)
	frame.Position = UDim2.fromScale(0.375, 0.275)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	-- Display
	local display = Instance.new("TextLabel")
	display.Name = "Display"
	display.Size = UDim2.new(0.9, 0, 0.12, 0)
	display.Position = UDim2.new(0.05, 0, 0.03, 0)
	display.BackgroundColor3 = Color3.fromRGB(15, 30, 15)
	display.TextColor3 = Color3.fromRGB(0, 255, 0)
	display.Text = "_ _ _ _"
	display.TextScaled = true
	display.Font = Enum.Font.Code
	display.Parent = frame

	local displayCorner = Instance.new("UICorner")
	displayCorner.CornerRadius = UDim.new(0, 6)
	displayCorner.Parent = display

	numberPadInput = {}

	-- Buttons 1-9 and 0
	for i = 1, 10 do
		local num = if i == 10 then 0 else i
		local row = math.floor((i - 1) / 3)
		local col = (i - 1) % 3
		if i == 10 then
			row = 3
			col = 1
		end

		local btn = Instance.new("TextButton")
		btn.Name = "Btn" .. num
		btn.Size = UDim2.new(0.27, 0, 0.14, 0)
		btn.Position = UDim2.new(0.05 + col * 0.31, 0, 0.2 + row * 0.17, 0)
		btn.BackgroundColor3 = Color3.fromRGB(70, 70, 75)
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Text = tostring(num)
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.Parent = frame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = btn

		btn.Activated:Connect(function()
			if #numberPadInput < 4 then
				table.insert(numberPadInput, num)
				-- Update display
				local displayText = ""
				for j = 1, 4 do
					if j <= #numberPadInput then
						displayText ..= tostring(numberPadInput[j])
					else
						displayText ..= "_"
					end
					if j < 4 then
						displayText ..= " "
					end
				end
				display.Text = displayText

				if #numberPadInput == 4 then
					PuzzleService:SubmitNumberPadCode(numberPadInput)
				end
			end
		end)
	end

	-- Clear button
	local clearBtn = Instance.new("TextButton")
	clearBtn.Name = "ClearBtn"
	clearBtn.Size = UDim2.new(0.27, 0, 0.14, 0)
	clearBtn.Position = UDim2.new(0.05, 0, 0.2 + 3 * 0.17, 0)
	clearBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
	clearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	clearBtn.Text = "CLR"
	clearBtn.TextScaled = true
	clearBtn.Font = Enum.Font.GothamBold
	clearBtn.Parent = frame

	local clearCorner = Instance.new("UICorner")
	clearCorner.CornerRadius = UDim.new(0, 6)
	clearCorner.Parent = clearBtn

	clearBtn.Activated:Connect(function()
		numberPadInput = {}
		display.Text = "_ _ _ _"
	end)

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0.27, 0, 0.14, 0)
	closeBtn.Position = UDim2.new(0.05 + 2 * 0.31, 0, 0.2 + 3 * 0.17, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "X"
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = frame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeBtn

	closeBtn.Activated:Connect(function()
		gui:Destroy()
	end)
end

function PuzzleController:KnitInit(): () end

function PuzzleController:KnitStart(): ()
	local PuzzleService = Knit.GetService("PuzzleService")

	PuzzleService.PuzzleStarted:Connect(function(puzzleType: string, _doorNumber: number)
		puzzleTrove:Clean()
		if puzzleType == "NumberPad" then
			createNumberPadUI()
		end
	end)

	PuzzleService.PuzzleSolved:Connect(function(_puzzleType: string)
		puzzleTrove:Clean()
		-- Success feedback
		local gui = Instance.new("ScreenGui")
		gui.Name = "PuzzleSolvedUI"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 35
		gui.Parent = PlayerGui

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.3, 0.08)
		label.Position = UDim2.fromScale(0.35, 0.4)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(100, 255, 100)
		label.Text = "PUZZLE SOLVED"
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextStrokeTransparency = 0.3
		label.Parent = gui

		task.delay(2, function()
			gui:Destroy()
		end)
	end)

	PuzzleService.PuzzleFailed:Connect(function()
		numberPadInput = {}
		-- Brief red flash
		local gui = Instance.new("ScreenGui")
		gui.Name = "PuzzleFailUI"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 35
		gui.Parent = PlayerGui

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.3, 0.06)
		label.Position = UDim2.fromScale(0.35, 0.42)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 80, 80)
		label.Text = "WRONG - TRY AGAIN"
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextStrokeTransparency = 0.3
		label.Parent = gui

		task.delay(1.5, function()
			gui:Destroy()
		end)
	end)
end

return PuzzleController
