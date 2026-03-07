--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Promise = require(ReplicatedStorage.Packages.Promise)

local ThresholdConfig = require(ReplicatedStorage.Shared.ThresholdConfig)

local RoomService
local EntityService
local PuzzleService
local PlayerService
local PlayerDataService

local GameService = Knit.CreateService({
	Name = "GameService",
	Client = {
		GameStateChanged = Knit.CreateSignal(),
		DoorNumberChanged = Knit.CreateSignal(),
		GameOver = Knit.CreateSignal(),
		Victory = Knit.CreateSignal(),
	},
})

type GameState = "Lobby" | "Playing" | "Transitioning" | "GameOver"

local gameState: GameState = "Lobby"
local currentDoor: number = 0
local gameActive: boolean = false

local function setGameState(newState: GameState)
	gameState = newState
	GameService.Client.GameStateChanged:FireAll(newState)
end

function GameService:GetGameState(): GameState
	return gameState
end

function GameService:GetCurrentDoor(): number
	return currentDoor
end

function GameService.Client:GetCurrentDoor(player: Player): number
	return currentDoor
end

function GameService.Client:GetGameState(player: Player): string
	return gameState
end

function GameService:StartGame(): ()
	if gameActive then
		return
	end
	gameActive = true
	currentDoor = 0

	-- Track run
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			PlayerDataService:WaitForProfile(player)
				:andThen(function()
					local runs = PlayerDataService:Read(player, { "TotalRuns" }) or 0
					PlayerDataService:Write(player, { "TotalRuns" }, runs + 1)
				end)
				:catch(function(err)
					warn("Failed to update TotalRuns:", err)
				end)
		end)
	end

	PlayerService:ResetAllPlayers()
	self:AdvanceToNextRoom()
end

function GameService:AdvanceToNextRoom(): ()
	if not gameActive then
		return
	end

	setGameState("Transitioning")
	currentDoor += 1

	self.Client.DoorNumberChanged:FireAll(currentDoor)

	if currentDoor > ThresholdConfig.MaxDoors then
		self:Victory()
		return
	end

	-- Clean previous room and generate new one
	RoomService:ClearRoom()
	task.wait(ThresholdConfig.RoomTransitionFadeTime)

	local roomData = RoomService:GenerateRoom(currentDoor)

	-- Teleport players to room spawn
	local spawnPos = RoomService:GetSpawnPosition()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					root.CFrame = CFrame.new(spawnPos)
				end
			end
		end
	end

	task.wait(0.5)
	RoomService:LockEntryDoor()
	setGameState("Playing")

	-- Handle room-type-specific logic
	if roomData.RoomType == "Entity" and roomData.EntityType then
		-- Delay entity spawn slightly
		task.delay(rng(), function()
			if gameState == "Playing" and currentDoor == roomData.DoorNumber then
				EntityService:SpawnEntity(roomData.EntityType, roomData)
			end
		end)
	elseif roomData.RoomType == "Puzzle" and roomData.PuzzleType then
		PuzzleService:SetupPuzzle(roomData.PuzzleType, roomData)
	end

	-- Start exit door check loop
	task.spawn(function()
		while gameActive and gameState == "Playing" and currentDoor == roomData.DoorNumber do
			local exitDoor = RoomService:GetCurrentRoom() and RoomService:GetCurrentRoom():FindFirstChild("ExitDoor") :: Part?
			if exitDoor then
				local locked = exitDoor:FindFirstChild("Locked") :: BoolValue?
				local isLocked = locked and locked.Value == true
				if not isLocked and RoomService:AreAllPlayersNearExit() then
					self:AdvanceToNextRoom()
					break
				end
			end
			task.wait(0.5)
		end
	end)
end

local _rng = Random.new()
local function rng(): number
	return _rng:NextNumber() * 3 + 2 -- 2-5 second delay for entities
end

function GameService:OnPlayerDied(player: Player): ()
	if not gameActive then
		return
	end

	-- Check if all players are dead
	local anyAlive = false
	for _, p in Players:GetPlayers() do
		local character = p.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				anyAlive = true
				break
			end
		end
	end

	if not anyAlive then
		self:GameOver()
	end
end

function GameService:GameOver(): ()
	gameActive = false
	setGameState("GameOver")

	-- Update best door for all players
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			PlayerDataService:WaitForProfile(player)
				:andThen(function()
					local best = PlayerDataService:Read(player, { "BestDoor" }) or 0
					if currentDoor > best then
						PlayerDataService:Write(player, { "BestDoor" }, currentDoor)
					end
					local deaths = PlayerDataService:Read(player, { "TotalDeaths" }) or 0
					PlayerDataService:Write(player, { "TotalDeaths" }, deaths + 1)
				end)
				:catch(function(err)
					warn("Failed to save player data:", err)
				end)
		end)
	end

	self.Client.GameOver:FireAll(currentDoor)

	-- Restart after delay
	task.delay(5, function()
		RoomService:ClearRoom()
		currentDoor = 0
		setGameState("Lobby")
		-- Auto-restart for now
		task.wait(3)
		if #Players:GetPlayers() > 0 then
			self:StartGame()
		end
	end)
end

function GameService:Victory(): ()
	gameActive = false
	setGameState("GameOver")

	-- Save best door as 100
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			PlayerDataService:WaitForProfile(player)
				:andThen(function()
					PlayerDataService:Write(player, { "BestDoor" }, ThresholdConfig.MaxDoors)
				end)
				:catch(function(err)
					warn("Failed to save victory:", err)
				end)
		end)
	end

	self.Client.Victory:FireAll()

	task.delay(10, function()
		RoomService:ClearRoom()
		currentDoor = 0
		setGameState("Lobby")
	end)
end

function GameService:ReviveDeadPlayers(): ()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health <= 0 then
				player:LoadCharacter()
				task.wait(0.5)
				local newChar = player.Character
				if newChar then
					local root = newChar:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root then
						root.CFrame = CFrame.new(RoomService:GetSpawnPosition())
					end
				end
				PlayerService:InitializePlayer(player)
			end
		end
	end
end

function GameService:KnitInit(): () end

function GameService:KnitStart(): ()
	RoomService = Knit.GetService("RoomService")
	EntityService = Knit.GetService("EntityService")
	PuzzleService = Knit.GetService("PuzzleService")
	PlayerService = Knit.GetService("PlayerService")
	PlayerDataService = Knit.GetService("PlayerDataService")

	-- Revive dead players at safe rooms
	RoomService.RoomGenerated:Connect(function(roomData)
		if roomData.RoomType == "Safe" then
			self:ReviveDeadPlayers()
		end
	end)

	-- Auto-start when first player joins
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			if gameState == "Lobby" and #Players:GetPlayers() >= 1 then
				task.wait(3)
				if gameState == "Lobby" then
					self:StartGame()
				end
			end
		end)
	end)
end

return GameService
