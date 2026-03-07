--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Promise = require(ReplicatedStorage.Packages.Promise)

local ThresholdConfig = require(ReplicatedStorage.Shared.ThresholdConfig)

local PropBuilder = require(script.PropBuilder)

export type RoomType = "Empty" | "Key" | "Puzzle" | "Entity" | "Dark" | "Trap" | "Safe"

export type RoomData = {
	DoorNumber: number,
	RoomType: RoomType,
	SizeX: number,
	SizeZ: number,
	Origin: Vector3,
	KeyLocation: Vector3?,
	PuzzleType: string?,
	EntityType: string?,
}

local RoomService = Knit.CreateService({
	Name = "RoomService",
	Client = {
		RoomGenerated = Knit.CreateSignal(),
		RoomClearing = Knit.CreateSignal(),
	},
	RoomGenerated = Signal.new(), -- (roomData: RoomData)
	RoomClearing = Signal.new(),
})

local currentRoom: Folder? = nil
local currentRoomData: RoomData? = nil
local currentRoomTrove: typeof(Trove.new()) = Trove.new()
local roomOrigin = Vector3.new(0, 0, 0)

local rng = Random.new()

local function pickRoomType(doorNumber: number): RoomType
	if doorNumber % ThresholdConfig.SafeRoomInterval == 0 then
		return "Safe"
	end

	local weights = ThresholdConfig.RoomWeights
	local roll = rng:NextNumber()
	local cumulative = 0.0

	for _, roomType in ThresholdConfig.RoomTypes do
		cumulative += weights[roomType]
		if roll <= cumulative then
			return roomType :: RoomType
		end
	end

	return "Empty"
end

local function createPart(parent: Instance, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createRoomShell(folder: Folder, sizeX: number, sizeZ: number, origin: Vector3): ()
	local height = ThresholdConfig.RoomHeight
	local thick = ThresholdConfig.WallThickness
	local wallColor = ThresholdConfig.WallColor
	local wallMat = ThresholdConfig.WallMaterial
	local floorColor = ThresholdConfig.FloorColor
	local ceilColor = ThresholdConfig.CeilingColor

	-- Floor
	local floor = createPart(
		folder,
		Vector3.new(sizeX, thick, sizeZ),
		origin + Vector3.new(sizeX / 2, -thick / 2, sizeZ / 2),
		floorColor,
		ThresholdConfig.FloorMaterial
	)
	floor.Name = "Floor"

	-- Ceiling
	local ceiling = createPart(
		folder,
		Vector3.new(sizeX, thick, sizeZ),
		origin + Vector3.new(sizeX / 2, height + thick / 2, sizeZ / 2),
		ceilColor,
		ThresholdConfig.CeilingMaterial
	)
	ceiling.Name = "Ceiling"

	-- Left wall (along Z axis at X=0)
	createPart(
		folder,
		Vector3.new(thick, height, sizeZ),
		origin + Vector3.new(-thick / 2, height / 2, sizeZ / 2),
		wallColor,
		wallMat
	).Name = "WallLeft"

	-- Right wall (along Z axis at X=sizeX)
	createPart(
		folder,
		Vector3.new(thick, height, sizeZ),
		origin + Vector3.new(sizeX + thick / 2, height / 2, sizeZ / 2),
		wallColor,
		wallMat
	).Name = "WallRight"

	-- Back wall (entry side, Z=0) — two pieces with door gap
	local doorW = ThresholdConfig.DoorWidth
	local doorH = ThresholdConfig.DoorHeight
	local halfWall = (sizeX - doorW) / 2

	-- Left piece of back wall
	createPart(
		folder,
		Vector3.new(halfWall, height, thick),
		origin + Vector3.new(halfWall / 2, height / 2, -thick / 2),
		wallColor,
		wallMat
	).Name = "BackWallLeft"

	-- Right piece of back wall
	createPart(
		folder,
		Vector3.new(halfWall, height, thick),
		origin + Vector3.new(sizeX - halfWall / 2, height / 2, -thick / 2),
		wallColor,
		wallMat
	).Name = "BackWallRight"

	-- Top piece above door
	createPart(
		folder,
		Vector3.new(doorW, height - doorH, thick),
		origin + Vector3.new(sizeX / 2, doorH + (height - doorH) / 2, -thick / 2),
		wallColor,
		wallMat
	).Name = "BackWallTop"

	-- Entry door (initially open, locks after entering)
	local entryDoor = createPart(
		folder,
		Vector3.new(doorW, doorH, thick / 2),
		origin + Vector3.new(sizeX / 2, doorH / 2, -thick / 4),
		Color3.fromRGB(80, 50, 30),
		Enum.Material.Wood
	)
	entryDoor.Name = "EntryDoor"
	entryDoor.Transparency = 1 -- starts invisible/open
	entryDoor.CanCollide = false

	-- Front wall (exit side, Z=sizeZ) — two pieces with door gap
	createPart(
		folder,
		Vector3.new(halfWall, height, thick),
		origin + Vector3.new(halfWall / 2, height / 2, sizeZ + thick / 2),
		wallColor,
		wallMat
	).Name = "FrontWallLeft"

	createPart(
		folder,
		Vector3.new(halfWall, height, thick),
		origin + Vector3.new(sizeX - halfWall / 2, height / 2, sizeZ + thick / 2),
		wallColor,
		wallMat
	).Name = "FrontWallRight"

	createPart(
		folder,
		Vector3.new(doorW, height - doorH, thick),
		origin + Vector3.new(sizeX / 2, doorH + (height - doorH) / 2, sizeZ + thick / 2),
		wallColor,
		wallMat
	).Name = "FrontWallTop"

	-- Exit door
	local exitDoor = createPart(
		folder,
		Vector3.new(doorW, doorH, thick / 2),
		origin + Vector3.new(sizeX / 2, doorH / 2, sizeZ + thick / 4),
		Color3.fromRGB(80, 50, 30),
		Enum.Material.Wood
	)
	exitDoor.Name = "ExitDoor"
	exitDoor.CanCollide = true
end

local function addRoomLighting(folder: Folder, sizeX: number, sizeZ: number, origin: Vector3, roomType: RoomType): ()
	local height = ThresholdConfig.RoomHeight

	if roomType == "Dark" then
		-- Minimal lighting
		local dim = Instance.new("PointLight")
		dim.Brightness = 0.2
		dim.Range = 10
		dim.Color = ThresholdConfig.EmergencyLightColor

		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Position = origin + Vector3.new(sizeX / 2, height - 1, sizeZ / 2)
		anchor.Name = "LightAnchor"
		dim.Parent = anchor
		anchor.Parent = folder
		return
	end

	local lightCount = rng:NextInteger(1, 3)
	local isEmergency = roomType == "Entity" and rng:NextNumber() < 0.3

	for i = 1, lightCount do
		local light = Instance.new("PointLight")
		if isEmergency then
			light.Color = ThresholdConfig.EmergencyLightColor
			light.Brightness = 0.8
		else
			light.Color = ThresholdConfig.NormalLightColor
			light.Brightness = ThresholdConfig.NormalLightBrightness
		end
		light.Range = ThresholdConfig.NormalLightRange

		local xPos = sizeX * (i / (lightCount + 1))
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Position = origin + Vector3.new(xPos, height - 1, sizeZ / 2)
		anchor.Name = "LightAnchor" .. i
		light.Parent = anchor
		anchor.Parent = folder
	end
end

local function placeKey(folder: Folder, sizeX: number, sizeZ: number, origin: Vector3): Vector3
	local margin = 4
	local keyX = rng:NextNumber() * (sizeX - margin * 2) + margin
	local keyZ = rng:NextNumber() * (sizeZ - margin * 2) + margin
	local keyPos = origin + Vector3.new(keyX, 1.5, keyZ)

	local key = Instance.new("Part")
	key.Name = "Key"
	key.Anchored = true
	key.Size = Vector3.new(1, 0.5, 2)
	key.Color = Color3.fromRGB(255, 200, 50)
	key.Material = Enum.Material.Neon
	key.Position = keyPos
	key.Parent = folder

	-- Interaction tag
	local tag = Instance.new("BoolValue")
	tag.Name = "Interactable"
	tag.Parent = key

	local typeVal = Instance.new("StringValue")
	typeVal.Name = "InteractType"
	typeVal.Value = "Key"
	typeVal.Parent = key

	return keyPos
end

local function addCeilingHoles(folder: Folder, sizeX: number, sizeZ: number, origin: Vector3): ()
	local ceiling: Part? = folder:FindFirstChild("Ceiling") :: Part?
	if not ceiling then
		return
	end

	local holeCount = rng:NextInteger(0, 3)
	for _ = 1, holeCount do
		local holeX = rng:NextNumber() * (sizeX - 6) + 3
		local holeZ = rng:NextNumber() * (sizeZ - 6) + 3
		local holeSize = rng:NextNumber() * 3 + 2

		local hole = Instance.new("Part")
		hole.Name = "CeilingHole"
		hole.Anchored = true
		hole.Size = Vector3.new(holeSize, ThresholdConfig.WallThickness + 0.2, holeSize)
		hole.Position = origin + Vector3.new(holeX, ThresholdConfig.RoomHeight + ThresholdConfig.WallThickness / 2, holeZ)
		hole.Color = Color3.fromRGB(5, 5, 5)
		hole.Material = Enum.Material.SmoothPlastic
		hole.Transparency = 0
		hole.Parent = folder
	end
end

function RoomService:GenerateRoom(doorNumber: number): RoomData
	-- Clean up previous room
	currentRoomTrove:Clean()

	local roomType = pickRoomType(doorNumber)
	local sizeX = rng:NextInteger(ThresholdConfig.RoomMinSize, ThresholdConfig.RoomMaxSize)
	local sizeZ = rng:NextInteger(ThresholdConfig.RoomMinSize, ThresholdConfig.RoomMaxSize)

	local folder = Instance.new("Folder")
	folder.Name = "Room_" .. doorNumber
	currentRoomTrove:Add(folder)

	createRoomShell(folder, sizeX, sizeZ, roomOrigin)
	addRoomLighting(folder, sizeX, sizeZ, roomOrigin, roomType)
	addCeilingHoles(folder, sizeX, sizeZ, roomOrigin)

	local roomData: RoomData = {
		DoorNumber = doorNumber,
		RoomType = roomType,
		SizeX = sizeX,
		SizeZ = sizeZ,
		Origin = roomOrigin,
		KeyLocation = nil,
		PuzzleType = nil,
		EntityType = nil,
	}

	-- Room-type-specific setup
	if roomType == "Key" then
		roomData.KeyLocation = placeKey(folder, sizeX, sizeZ, roomOrigin)
		-- Lock exit door
		local exitDoor = folder:FindFirstChild("ExitDoor") :: Part?
		if exitDoor then
			exitDoor.CanCollide = true
			exitDoor.Transparency = 0
			local locked = Instance.new("BoolValue")
			locked.Name = "Locked"
			locked.Value = true
			locked.Parent = exitDoor
		end
	elseif roomType == "Puzzle" then
		local puzzleTypes = ThresholdConfig.PuzzleTypes
		roomData.PuzzleType = puzzleTypes[rng:NextInteger(1, #puzzleTypes)]
		-- Lock exit door
		local exitDoor = folder:FindFirstChild("ExitDoor") :: Part?
		if exitDoor then
			exitDoor.CanCollide = true
			exitDoor.Transparency = 0
			local locked = Instance.new("BoolValue")
			locked.Name = "Locked"
			locked.Value = true
			locked.Parent = exitDoor
		end
	elseif roomType == "Entity" then
		-- Pick which entities are unlocked at this door number
		local available = {}
		for entityName, unlockDoor in ThresholdConfig.EntityUnlockDoors do
			if doorNumber >= unlockDoor then
				table.insert(available, entityName)
			end
		end
		if #available > 0 then
			roomData.EntityType = available[rng:NextInteger(1, #available)]
		end
	end

	-- Add props (not in safe rooms — they get special furniture)
	if roomType ~= "Safe" then
		PropBuilder.populateRoom(folder, sizeX, sizeZ, roomOrigin, rng)
	else
		PropBuilder.populateSafeRoom(folder, sizeX, sizeZ, roomOrigin)
	end

	folder.Parent = workspace

	currentRoom = folder
	currentRoomData = roomData

	self.RoomGenerated:Fire(roomData)
	self.Client.RoomGenerated:FireAll(roomData)

	return roomData
end

function RoomService:GetCurrentRoom(): Folder?
	return currentRoom
end

function RoomService:GetCurrentRoomData(): RoomData?
	return currentRoomData
end

function RoomService:UnlockExitDoor(): ()
	if not currentRoom then
		return
	end
	local exitDoor = currentRoom:FindFirstChild("ExitDoor") :: Part?
	if exitDoor then
		local locked = exitDoor:FindFirstChild("Locked") :: BoolValue?
		if locked then
			locked.Value = false
		end
		exitDoor.Transparency = 1
		exitDoor.CanCollide = false
	end
end

function RoomService:LockEntryDoor(): ()
	if not currentRoom then
		return
	end
	local entryDoor = currentRoom:FindFirstChild("EntryDoor") :: Part?
	if entryDoor then
		entryDoor.Transparency = 0
		entryDoor.CanCollide = true
	end
end

function RoomService:AreAllPlayersNearExit(): boolean
	if not currentRoom or not currentRoomData then
		return false
	end
	local data = currentRoomData
	local exitPos = data.Origin + Vector3.new(data.SizeX / 2, 0, data.SizeZ)
	local threshold = 10

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local dist = (root.Position - exitPos).Magnitude
					if dist > threshold then
						return false
					end
				end
			end
		end
	end
	return true
end

function RoomService:GetSpawnPosition(): Vector3
	if not currentRoomData then
		return Vector3.new(0, 3, 5)
	end
	local data = currentRoomData
	return data.Origin + Vector3.new(data.SizeX / 2, 3, 5)
end

function RoomService:ClearRoom(): ()
	self.RoomClearing:Fire()
	self.Client.RoomClearing:FireAll()
	currentRoomTrove:Clean()
	currentRoom = nil
	currentRoomData = nil
end

function RoomService:KnitInit(): ()
	-- Pre-create workspace folder for rooms
end

function RoomService:KnitStart(): ()
	-- Room generation is triggered by GameService
end

return RoomService
