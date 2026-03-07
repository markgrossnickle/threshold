--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local ThresholdConfig = require(ReplicatedStorage.Shared.ThresholdConfig)

local RoomService

type RoomData = {
	DoorNumber: number,
	RoomType: string,
	SizeX: number,
	SizeZ: number,
	Origin: Vector3,
	KeyLocation: Vector3?,
	PuzzleType: string?,
	EntityType: string?,
}

local PuzzleService = Knit.CreateService({
	Name = "PuzzleService",
	Client = {
		PuzzleStarted = Knit.CreateSignal(),
		PuzzleSolved = Knit.CreateSignal(),
		PuzzleFailed = Knit.CreateSignal(),
		PuzzleStateUpdate = Knit.CreateSignal(),
	},
	PuzzleSolved = Signal.new(),
})

export type PuzzleState = {
	PuzzleType: string,
	Solution: { number },
	CurrentInput: { number },
	Solved: boolean,
	Props: { Instance },
	DoorNumber: number,
}

local activePuzzle: PuzzleState? = nil
local puzzleTrove: typeof(Trove.new()) = Trove.new()
local rng = Random.new()

local function getDifficultyMultiplier(doorNumber: number): number
	return 1 + doorNumber * ThresholdConfig.DifficultyScaling.puzzleComplexityBonus
end

local function createLeverPuzzle(roomData: RoomData): PuzzleState
	local room = RoomService:GetCurrentRoom()
	if not room then
		error("No room to create puzzle in")
	end

	local difficulty = getDifficultyMultiplier(roomData.DoorNumber)
	local leverCount = math.clamp(
		math.floor(ThresholdConfig.BaseLeverCount * difficulty),
		ThresholdConfig.BaseLeverCount,
		ThresholdConfig.MaxLeverCount
	)

	-- Generate solution (random order)
	local solution = {}
	for i = 1, leverCount do
		table.insert(solution, i)
	end
	-- Shuffle
	for i = leverCount, 2, -1 do
		local j = rng:NextInteger(1, i)
		solution[i], solution[j] = solution[j], solution[i]
	end

	-- Create lever Parts on back wall
	local props: { Instance } = {}
	local spacing = roomData.SizeX / (leverCount + 1)

	for i = 1, leverCount do
		local lever = Instance.new("Part")
		lever.Anchored = true
		lever.Name = "Lever_" .. i
		lever.Size = Vector3.new(0.5, 3, 0.5)
		lever.Position = roomData.Origin + Vector3.new(spacing * i, 3, 2)
		lever.Color = Color3.fromRGB(150, 150, 150)
		lever.Material = Enum.Material.Metal
		lever.Parent = room

		local interactable = Instance.new("BoolValue")
		interactable.Name = "Interactable"
		interactable.Parent = lever

		local interactType = Instance.new("StringValue")
		interactType.Name = "InteractType"
		interactType.Value = "Lever"
		interactType.Parent = lever

		local index = Instance.new("IntValue")
		index.Name = "LeverIndex"
		index.Value = i
		index.Parent = lever

		table.insert(props, lever)
		puzzleTrove:Add(lever)
	end

	-- Create hint note showing order briefly
	local note = Instance.new("Part")
	note.Anchored = true
	note.Name = "HintNote"
	note.Size = Vector3.new(4, 3, 0.1)
	note.Position = roomData.Origin + Vector3.new(roomData.SizeX / 2, 5, 3)
	note.Color = Color3.fromRGB(220, 210, 180)
	note.Material = Enum.Material.SmoothPlastic
	note.Parent = room
	puzzleTrove:Add(note)

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.Parent = note

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Order: " .. table.concat(solution, " - ")
	label.TextColor3 = Color3.fromRGB(30, 30, 30)
	label.TextScaled = true
	label.Font = Enum.Font.Antique
	label.Parent = surfaceGui

	-- Hide note after a few seconds
	task.delay(5, function()
		if note.Parent then
			note.Transparency = 1
			surfaceGui:Destroy()
		end
	end)

	return {
		PuzzleType = "LeverSequence",
		Solution = solution,
		CurrentInput = {},
		Solved = false,
		Props = props,
		DoorNumber = roomData.DoorNumber,
	}
end

local function createNumberPadPuzzle(roomData: RoomData): PuzzleState
	local room = RoomService:GetCurrentRoom()
	if not room then
		error("No room to create puzzle in")
	end

	-- Generate 4-digit code
	local solution = {}
	for _ = 1, ThresholdConfig.BaseCodeLength do
		table.insert(solution, rng:NextInteger(0, 9))
	end

	local props: { Instance } = {}

	-- Create number pad on wall
	local pad = Instance.new("Part")
	pad.Anchored = true
	pad.Name = "NumberPad"
	pad.Size = Vector3.new(4, 5, 0.3)
	pad.Position = roomData.Origin + Vector3.new(roomData.SizeX / 2, 4, roomData.SizeZ - 2)
	pad.Color = Color3.fromRGB(50, 50, 55)
	pad.Material = Enum.Material.Metal
	pad.Parent = room
	puzzleTrove:Add(pad)

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Back
	surfaceGui.CanvasSize = Vector2.new(400, 500)
	surfaceGui.Parent = pad

	-- Display
	local display = Instance.new("TextLabel")
	display.Name = "Display"
	display.Size = UDim2.new(0.9, 0, 0.15, 0)
	display.Position = UDim2.new(0.05, 0, 0.02, 0)
	display.BackgroundColor3 = Color3.fromRGB(20, 40, 20)
	display.TextColor3 = Color3.fromRGB(0, 255, 0)
	display.Text = "_ _ _ _"
	display.TextScaled = true
	display.Font = Enum.Font.Code
	display.Parent = surfaceGui

	-- Number buttons 0-9
	for i = 0, 9 do
		local btn = Instance.new("TextButton")
		btn.Name = "Btn_" .. i
		btn.Size = UDim2.new(0.28, 0, 0.13, 0)
		local row = math.floor((i - 1) / 3)
		local col = (i - 1) % 3
		if i == 0 then
			row = 3
			col = 1
		end
		btn.Position = UDim2.new(0.05 + col * 0.32, 0, 0.22 + row * 0.17, 0)
		btn.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Text = tostring(i)
		btn.TextScaled = true
		btn.Font = Enum.Font.Code
		btn.Parent = surfaceGui
	end

	local interactable = Instance.new("BoolValue")
	interactable.Name = "Interactable"
	interactable.Parent = pad

	local interactType = Instance.new("StringValue")
	interactType.Name = "InteractType"
	interactType.Value = "NumberPad"
	interactType.Parent = pad

	table.insert(props, pad)

	-- Hide code on a note somewhere in the room
	local note = Instance.new("Part")
	note.Anchored = true
	note.Name = "CodeNote"
	note.Size = Vector3.new(2, 1.5, 0.05)
	local noteX = rng:NextNumber() * (roomData.SizeX - 8) + 4
	local noteZ = rng:NextNumber() * (roomData.SizeZ - 8) + 4
	note.Position = roomData.Origin + Vector3.new(noteX, 1, noteZ)
	note.Color = Color3.fromRGB(220, 210, 180)
	note.Material = Enum.Material.SmoothPlastic
	note.Parent = room
	puzzleTrove:Add(note)

	local noteGui = Instance.new("SurfaceGui")
	noteGui.Face = Enum.NormalId.Top
	noteGui.Parent = note

	local noteLabel = Instance.new("TextLabel")
	noteLabel.Size = UDim2.fromScale(1, 1)
	noteLabel.BackgroundTransparency = 1
	noteLabel.Text = table.concat(solution, "")
	noteLabel.TextColor3 = Color3.fromRGB(100, 30, 30)
	noteLabel.TextScaled = true
	noteLabel.Font = Enum.Font.Antique
	noteLabel.Parent = noteGui

	return {
		PuzzleType = "NumberPad",
		Solution = solution,
		CurrentInput = {},
		Solved = false,
		Props = props,
		DoorNumber = roomData.DoorNumber,
	}
end

local function createPatternMatchPuzzle(roomData: RoomData): PuzzleState
	local room = RoomService:GetCurrentRoom()
	if not room then
		error("No room to create puzzle in")
	end

	local difficulty = getDifficultyMultiplier(roomData.DoorNumber)
	local patternLength = math.clamp(math.floor(ThresholdConfig.BasePatternLength * difficulty), 4, 8)

	-- Create floor tiles in a grid
	local gridSize = 3
	local tileSize = 4
	local startX = roomData.SizeX / 2 - (gridSize * tileSize) / 2
	local startZ = roomData.SizeZ / 2 - (gridSize * tileSize) / 2

	local tiles: { Part } = {}
	local props: { Instance } = {}

	for row = 0, gridSize - 1 do
		for col = 0, gridSize - 1 do
			local tile = Instance.new("Part")
			tile.Anchored = true
			tile.Name = "Tile_" .. (row * gridSize + col + 1)
			tile.Size = Vector3.new(tileSize - 0.2, 0.3, tileSize - 0.2)
			tile.Position = roomData.Origin + Vector3.new(startX + col * tileSize + tileSize / 2, 0.15, startZ + row * tileSize + tileSize / 2)
			tile.Color = Color3.fromRGB(60, 60, 65)
			tile.Material = Enum.Material.SmoothPlastic
			tile.Parent = room

			local index = Instance.new("IntValue")
			index.Name = "TileIndex"
			index.Value = row * gridSize + col + 1
			index.Parent = tile

			table.insert(tiles, tile)
			table.insert(props, tile)
			puzzleTrove:Add(tile)
		end
	end

	-- Generate random pattern
	local totalTiles = gridSize * gridSize
	local solution = {}
	for _ = 1, patternLength do
		table.insert(solution, rng:NextInteger(1, totalTiles))
	end

	-- Flash the pattern
	task.spawn(function()
		task.wait(1)
		for _, tileIndex in solution do
			local tile = tiles[tileIndex]
			if tile then
				tile.Color = Color3.fromRGB(100, 200, 255)
				tile.Material = Enum.Material.Neon
				task.wait(0.6)
				tile.Color = Color3.fromRGB(60, 60, 65)
				tile.Material = Enum.Material.SmoothPlastic
				task.wait(0.2)
			end
		end
	end)

	return {
		PuzzleType = "PatternMatch",
		Solution = solution,
		CurrentInput = {},
		Solved = false,
		Props = props,
		DoorNumber = roomData.DoorNumber,
	}
end

local function createGeneratorPuzzle(roomData: RoomData): PuzzleState
	local room = RoomService:GetCurrentRoom()
	if not room then
		error("No room to create puzzle in")
	end

	local canisterCount = math.clamp(
		rng:NextInteger(ThresholdConfig.BaseFuelCanisters, ThresholdConfig.MaxFuelCanisters),
		2,
		3
	)

	local props: { Instance } = {}
	local solution = {}

	-- Create generator
	local generator = Instance.new("Part")
	generator.Anchored = true
	generator.Name = "Generator"
	generator.Size = Vector3.new(4, 3, 3)
	generator.Position = roomData.Origin + Vector3.new(roomData.SizeX / 2, 1.5, roomData.SizeZ - 3)
	generator.Color = Color3.fromRGB(80, 80, 85)
	generator.Material = Enum.Material.Metal
	generator.Parent = room
	puzzleTrove:Add(generator)

	local interactable = Instance.new("BoolValue")
	interactable.Name = "Interactable"
	interactable.Parent = generator

	local interactType = Instance.new("StringValue")
	interactType.Name = "InteractType"
	interactType.Value = "Generator"
	interactType.Parent = generator

	local fuelNeeded = Instance.new("IntValue")
	fuelNeeded.Name = "FuelNeeded"
	fuelNeeded.Value = canisterCount
	fuelNeeded.Parent = generator

	table.insert(props, generator)

	-- Scatter fuel canisters
	for i = 1, canisterCount do
		local canister = Instance.new("Part")
		canister.Anchored = true
		canister.Name = "FuelCanister_" .. i
		canister.Size = Vector3.new(1, 2, 1)
		local cx = rng:NextNumber() * (roomData.SizeX - 8) + 4
		local cz = rng:NextNumber() * (roomData.SizeZ - 8) + 4
		canister.Position = roomData.Origin + Vector3.new(cx, 1, cz)
		canister.Color = Color3.fromRGB(200, 50, 30)
		canister.Material = Enum.Material.Metal
		canister.Parent = room
		puzzleTrove:Add(canister)

		local canInteract = Instance.new("BoolValue")
		canInteract.Name = "Interactable"
		canInteract.Parent = canister

		local canType = Instance.new("StringValue")
		canType.Name = "InteractType"
		canType.Value = "FuelCanister"
		canType.Parent = canister

		table.insert(props, canister)
		table.insert(solution, i)
	end

	return {
		PuzzleType = "Generator",
		Solution = solution,
		CurrentInput = {},
		Solved = false,
		Props = props,
		DoorNumber = roomData.DoorNumber,
	}
end

function PuzzleService:SetupPuzzle(puzzleType: string, roomData: RoomData): ()
	puzzleTrove:Clean()

	local state: PuzzleState

	if puzzleType == "LeverSequence" then
		state = createLeverPuzzle(roomData)
	elseif puzzleType == "NumberPad" then
		state = createNumberPadPuzzle(roomData)
	elseif puzzleType == "PatternMatch" then
		state = createPatternMatchPuzzle(roomData)
	elseif puzzleType == "Generator" then
		state = createGeneratorPuzzle(roomData)
	elseif puzzleType == "WireConnect" then
		-- Wire connect uses same structure as lever with paired matching
		state = createLeverPuzzle(roomData) -- simplified fallback
		state.PuzzleType = "WireConnect"
	else
		return
	end

	activePuzzle = state
	self.Client.PuzzleStarted:FireAll(puzzleType, roomData.DoorNumber)
end

function PuzzleService.Client:SubmitInput(player: Player, inputValue: number): ()
	if not activePuzzle or activePuzzle.Solved then
		return
	end

	table.insert(activePuzzle.CurrentInput, inputValue)
	local step = #activePuzzle.CurrentInput

	self.Server.Client.PuzzleStateUpdate:FireAll(activePuzzle.CurrentInput)

	if activePuzzle.PuzzleType == "LeverSequence" or activePuzzle.PuzzleType == "WireConnect" then
		if activePuzzle.Solution[step] ~= inputValue then
			-- Wrong order, reset
			activePuzzle.CurrentInput = {}
			self.Server.Client.PuzzleFailed:FireAll()
			return
		end
	elseif activePuzzle.PuzzleType == "PatternMatch" then
		if activePuzzle.Solution[step] ~= inputValue then
			activePuzzle.CurrentInput = {}
			self.Server.Client.PuzzleFailed:FireAll()
			return
		end
	end

	-- Check if complete
	if step >= #activePuzzle.Solution then
		-- Verify full solution
		local correct = true
		for i = 1, #activePuzzle.Solution do
			if activePuzzle.CurrentInput[i] ~= activePuzzle.Solution[i] then
				correct = false
				break
			end
		end

		if correct then
			activePuzzle.Solved = true
			self.Server.PuzzleSolved:Fire(activePuzzle.PuzzleType)
			self.Server.Client.PuzzleSolved:FireAll(activePuzzle.PuzzleType)
			RoomService:UnlockExitDoor()
		else
			activePuzzle.CurrentInput = {}
			self.Server.Client.PuzzleFailed:FireAll()
		end
	end
end

function PuzzleService.Client:SubmitNumberPadCode(player: Player, code: { number }): ()
	if not activePuzzle or activePuzzle.Solved or activePuzzle.PuzzleType ~= "NumberPad" then
		return
	end

	local correct = true
	if #code ~= #activePuzzle.Solution then
		correct = false
	else
		for i = 1, #activePuzzle.Solution do
			if code[i] ~= activePuzzle.Solution[i] then
				correct = false
				break
			end
		end
	end

	if correct then
		activePuzzle.Solved = true
		self.Server.PuzzleSolved:Fire("NumberPad")
		self.Server.Client.PuzzleSolved:FireAll("NumberPad")
		RoomService:UnlockExitDoor()
	else
		self.Server.Client.PuzzleFailed:FireAll()
	end
end

function PuzzleService.Client:SubmitFuelCanister(player: Player): ()
	if not activePuzzle or activePuzzle.Solved or activePuzzle.PuzzleType ~= "Generator" then
		return
	end

	table.insert(activePuzzle.CurrentInput, 1)
	self.Server.Client.PuzzleStateUpdate:FireAll(activePuzzle.CurrentInput)

	if #activePuzzle.CurrentInput >= #activePuzzle.Solution then
		activePuzzle.Solved = true
		self.Server.PuzzleSolved:Fire("Generator")
		self.Server.Client.PuzzleSolved:FireAll("Generator")
		RoomService:UnlockExitDoor()
	end
end

function PuzzleService:GetActivePuzzle(): PuzzleState?
	return activePuzzle
end

function PuzzleService:KnitInit(): () end

function PuzzleService:KnitStart(): ()
	RoomService = Knit.GetService("RoomService")

	RoomService.RoomClearing:Connect(function()
		puzzleTrove:Clean()
		activePuzzle = nil
	end)
end

return PuzzleService
