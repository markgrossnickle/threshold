--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local ThresholdConfig = require(ReplicatedStorage.Shared.ThresholdConfig)

local PlayerService
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

local EntityService = Knit.CreateService({
	Name = "EntityService",
	Client = {
		EntityWarning = Knit.CreateSignal(),
		EntitySpawned = Knit.CreateSignal(),
		EntityDespawned = Knit.CreateSignal(),
		EntityAttack = Knit.CreateSignal(),
	},
	EntitySpawned = Signal.new(),
	EntityDespawned = Signal.new(),
})

local activeEntity: { model: Model?, entityType: string, trove: typeof(Trove.new()) }? = nil
local rng = Random.new()

local function getAlivePlayers(): { Player }
	local alive = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				table.insert(alive, player)
			end
		end
	end
	return alive
end

local function getPlayerPosition(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	return root.Position
end

local function isPlayerCrouching(player: Player): boolean
	local state = PlayerService:GetPlayerState(player)
	return state ~= nil and state.IsCrouching
end

local function isPlayerMoving(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	return root.AssemblyLinearVelocity.Magnitude > 1
end

local function isPlayerHidden(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end

	-- Check if near a hideable object
	local room = RoomService:GetCurrentRoom()
	if not room then
		return false
	end

	for _, obj in room:GetDescendants() do
		if obj:FindFirstChild("Hideable") then
			local primaryPart = if obj:IsA("Model") then obj.PrimaryPart else if obj:IsA("BasePart") then obj else nil
			if primaryPart then
				local dist = (root.Position - primaryPart.Position).Magnitude
				if dist < 5 then
					return true
				end
			end
		end
	end
	return false
end

local function createEntityModel(entityType: string, position: Vector3, folder: Folder): Model
	local model = Instance.new("Model")
	model.Name = entityType .. "Entity"

	if entityType == "Shadow" then
		-- Tall dark humanoid silhouette
		local body = Instance.new("Part")
		body.Anchored = true
		body.Name = "Body"
		body.Size = Vector3.new(3, 8, 2)
		body.Position = position + Vector3.new(0, 4, 0)
		body.Color = Color3.fromRGB(10, 10, 10)
		body.Material = Enum.Material.SmoothPlastic
		body.Transparency = 0.3
		body.Parent = model

		-- Red eyes
		for _, xOff in { -0.5, 0.5 } do
			local eye = Instance.new("Part")
			eye.Anchored = true
			eye.Name = "Eye"
			eye.Size = Vector3.new(0.3, 0.15, 0.1)
			eye.Position = position + Vector3.new(xOff, 7, 1.05)
			eye.Color = Color3.fromRGB(255, 0, 0)
			eye.Material = Enum.Material.Neon
			eye.Parent = model
		end

		model.PrimaryPart = body
	elseif entityType == "Crawler" then
		-- Spider-like, low to ground
		local body = Instance.new("Part")
		body.Anchored = true
		body.Name = "Body"
		body.Size = Vector3.new(3, 1, 4)
		body.Position = position + Vector3.new(0, 0.5, 0)
		body.Color = Color3.fromRGB(220, 210, 200)
		body.Material = Enum.Material.SmoothPlastic
		body.Parent = model

		-- Legs
		for i = 1, 6 do
			local leg = Instance.new("Part")
			leg.Anchored = true
			leg.Name = "Leg" .. i
			leg.Size = Vector3.new(0.2, 0.2, 3)
			local side = if i <= 3 then -1 else 1
			local zOff = ((i - 1) % 3 - 1) * 1.2
			leg.CFrame = CFrame.new(position + Vector3.new(side * 2, 0.3, zOff))
				* CFrame.Angles(0, 0, math.rad(side * 30))
			leg.Color = Color3.fromRGB(200, 190, 180)
			leg.Material = Enum.Material.SmoothPlastic
			leg.Parent = model
		end

		model.PrimaryPart = body
	elseif entityType == "Mimic" then
		-- Looks like a cabinet but slightly off
		local body = Instance.new("Part")
		body.Anchored = true
		body.Name = "Body"
		body.Size = Vector3.new(3, 5, 2)
		body.Position = position + Vector3.new(0, 2.5, 0)
		body.Color = Color3.fromRGB(70, 52, 38)
		body.Material = Enum.Material.Wood
		body.Parent = model
		model.PrimaryPart = body
	elseif entityType == "Whisper" then
		-- Invisible entity, just a small anchor part
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.Name = "Body"
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Position = position
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.Parent = model
		model.PrimaryPart = anchor
	elseif entityType == "Watcher" then
		-- Giant eye
		local eye = Instance.new("Part")
		eye.Anchored = true
		eye.Name = "Body"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(6, 6, 6)
		eye.Position = position + Vector3.new(0, 8, 0)
		eye.Color = Color3.fromRGB(255, 255, 200)
		eye.Material = Enum.Material.Neon
		eye.Transparency = 0.2
		eye.Parent = model

		-- Iris
		local iris = Instance.new("Part")
		iris.Anchored = true
		iris.Name = "Iris"
		iris.Shape = Enum.PartType.Ball
		iris.Size = Vector3.new(2, 2, 2)
		iris.Position = position + Vector3.new(0, 8, 3)
		iris.Color = Color3.fromRGB(150, 0, 0)
		iris.Material = Enum.Material.Neon
		iris.Parent = model

		model.PrimaryPart = eye
	elseif entityType == "Glitch" then
		-- Corrupted humanoid
		local body = Instance.new("Part")
		body.Anchored = true
		body.Name = "Body"
		body.Size = Vector3.new(2, 6, 2)
		body.Position = position + Vector3.new(0, 3, 0)
		body.Color = Color3.fromRGB(rng:NextInteger(0, 255), rng:NextInteger(0, 255), rng:NextInteger(0, 255))
		body.Material = Enum.Material.Neon
		body.Parent = model

		local head = Instance.new("Part")
		head.Anchored = true
		head.Name = "Head"
		head.Shape = Enum.PartType.Ball
		head.Size = Vector3.new(2, 2, 2)
		head.Position = position + Vector3.new(0, 7, 0)
		head.Color = Color3.fromRGB(rng:NextInteger(0, 255), rng:NextInteger(0, 255), rng:NextInteger(0, 255))
		head.Material = Enum.Material.Neon
		head.Parent = model

		model.PrimaryPart = body
	elseif entityType == "Devourer" then
		-- Floor mouth parts
		local mouth = Instance.new("Part")
		mouth.Anchored = true
		mouth.Name = "Body"
		mouth.Size = Vector3.new(10, 1, 10)
		mouth.Position = position + Vector3.new(0, -0.5, 0)
		mouth.Color = Color3.fromRGB(30, 5, 5)
		mouth.Material = Enum.Material.SmoothPlastic
		mouth.Transparency = 0.5
		mouth.CanCollide = false
		mouth.Parent = model

		-- Tendrils
		for i = 1, 5 do
			local tendril = Instance.new("Part")
			tendril.Anchored = true
			tendril.Name = "Tendril" .. i
			tendril.Size = Vector3.new(0.3, 4, 0.3)
			local angle = (i / 5) * math.pi * 2
			tendril.Position = position + Vector3.new(math.cos(angle) * 3, 2, math.sin(angle) * 3)
			tendril.Color = Color3.fromRGB(20, 5, 5)
			tendril.Material = Enum.Material.SmoothPlastic
			tendril.Parent = model
		end

		model.PrimaryPart = mouth
	end

	model.Parent = folder
	return model
end

function EntityService:SpawnEntity(entityType: string, roomData: RoomData): ()
	if activeEntity then
		self:DespawnEntity()
	end

	local trove = Trove.new()
	local room = RoomService:GetCurrentRoom()
	if not room then
		return
	end

	-- Warning phase
	self.Client.EntityWarning:FireAll(entityType, ThresholdConfig.EntityWarningDuration)
	task.wait(ThresholdConfig.EntityWarningDuration)

	-- Spawn position
	local spawnPos = roomData.Origin + Vector3.new(roomData.SizeX / 2, 0, roomData.SizeZ - 3)
	local model = createEntityModel(entityType, spawnPos, room :: any)
	trove:Add(model)

	activeEntity = {
		model = model,
		entityType = entityType,
		trove = trove,
	}

	self.EntitySpawned:Fire(entityType)
	self.Client.EntitySpawned:FireAll(entityType, spawnPos)

	-- Run entity behavior
	task.spawn(function()
		self:_runBehavior(entityType, model, roomData, trove)
	end)
end

function EntityService:_runBehavior(
	entityType: string,
	model: Model,
	roomData: RoomData,
	trove: typeof(Trove.new())
): ()
	local lingerTime = rng:NextNumber() * (ThresholdConfig.EntityLingerTime.max - ThresholdConfig.EntityLingerTime.min)
		+ ThresholdConfig.EntityLingerTime.min
	local startTime = tick()
	local doorScaling = 1 + roomData.DoorNumber * ThresholdConfig.DifficultyScaling.entitySpeedBonus
	local playerCount = #getAlivePlayers()
	local playerScaling = 1 + (playerCount - 1) * ThresholdConfig.EntitySpeedPerPlayer

	if entityType == "Shadow" then
		-- Rushes toward players. Hide to survive.
		local speed = ThresholdConfig.EntitySpeeds.Shadow * doorScaling * playerScaling
		while tick() - startTime < lingerTime and activeEntity and activeEntity.model == model do
			local players = getAlivePlayers()
			for _, player in players do
				if not isPlayerHidden(player) then
					local playerPos = getPlayerPosition(player)
					if playerPos and model.PrimaryPart then
						local dir = (playerPos - model.PrimaryPart.Position)
						local dist = dir.Magnitude
						if dist < 3 then
							PlayerService:DamagePlayer(player, ThresholdConfig.EntityInstantKillHP)
							self.Client.EntityAttack:FireAll(entityType, player)
						else
							local move = dir.Unit * speed * (1 / 30)
							model.PrimaryPart.Position = model.PrimaryPart.Position + move
						end
					end
				end
			end
			task.wait(1 / 30)
		end
	elseif entityType == "Crawler" then
		-- Drops near players. Crouch to avoid.
		while tick() - startTime < lingerTime and activeEntity and activeEntity.model == model do
			local players = getAlivePlayers()
			for _, player in players do
				if not isPlayerCrouching(player) then
					local playerPos = getPlayerPosition(player)
					if playerPos and model.PrimaryPart then
						local dist = (playerPos - model.PrimaryPart.Position).Magnitude
						if dist < 4 then
							PlayerService:DamagePlayer(player, ThresholdConfig.EntityDamageHeavy)
							self.Client.EntityAttack:FireAll(entityType, player)
						end
					end
				end
			end
			-- Move toward random player
			local target = players[rng:NextInteger(1, math.max(1, #players))]
			if target then
				local targetPos = getPlayerPosition(target)
				if targetPos and model.PrimaryPart then
					local dir = (targetPos - model.PrimaryPart.Position)
					if dir.Magnitude > 2 then
						model.PrimaryPart.Position = model.PrimaryPart.Position
							+ dir.Unit * ThresholdConfig.EntitySpeeds.Crawler * doorScaling * (1 / 30)
					end
				end
			end
			task.wait(1 / 30)
		end
	elseif entityType == "Mimic" then
		-- Sits still. Damages on interaction. Just wait for linger time.
		-- Interaction damage is handled via interact system detecting Mimic
		local interactable = Instance.new("BoolValue")
		interactable.Name = "Interactable"
		interactable.Parent = model.PrimaryPart
		trove:Add(interactable)

		local interactType = Instance.new("StringValue")
		interactType.Name = "InteractType"
		interactType.Value = "Mimic"
		interactType.Parent = model.PrimaryPart
		trove:Add(interactType)

		task.wait(lingerTime)
	elseif entityType == "Whisper" then
		-- Follows closest player. Damages if too close and player is still.
		while tick() - startTime < lingerTime and activeEntity and activeEntity.model == model do
			local players = getAlivePlayers()
			local closest: Player? = nil
			local closestDist = math.huge
			for _, player in players do
				local pos = getPlayerPosition(player)
				if pos and model.PrimaryPart then
					local dist = (pos - model.PrimaryPart.Position).Magnitude
					if dist < closestDist then
						closestDist = dist
						closest = player
					end
				end
			end
			if closest then
				local targetPos = getPlayerPosition(closest)
				if targetPos and model.PrimaryPart then
					if isPlayerMoving(closest) then
						-- Reset distance — move away
						model.PrimaryPart.Position = targetPos
							+ Vector3.new(rng:NextNumber() * 20 - 10, 0, rng:NextNumber() * 20 - 10)
					else
						-- Approach
						local dir = (targetPos - model.PrimaryPart.Position)
						if dir.Magnitude > 0.1 then
							model.PrimaryPart.Position = model.PrimaryPart.Position + dir.Unit * 8 * (1 / 30)
						end
						if dir.Magnitude < 3 then
							PlayerService:DamagePlayer(closest, ThresholdConfig.EntityDamageLight)
							self.Client.EntityAttack:FireAll(entityType, closest)
						end
					end
				end
			end
			task.wait(1 / 30)
		end
	elseif entityType == "Watcher" then
		-- Client-side handles look detection and tells server
		-- For now, just linger and despawn
		task.wait(ThresholdConfig.WatcherDespawnTime)
	elseif entityType == "Glitch" then
		-- Teleports around, charges at random player
		local chargeTarget: Player? = nil
		local charging = false
		local chargeStart = 0

		while tick() - startTime < lingerTime and activeEntity and activeEntity.model == model do
			local players = getAlivePlayers()
			if not charging then
				-- Teleport randomly
				if rng:NextNumber() < 0.05 then
					local rx = rng:NextNumber() * roomData.SizeX
					local rz = rng:NextNumber() * roomData.SizeZ
					if model.PrimaryPart then
						model.PrimaryPart.Position = roomData.Origin + Vector3.new(rx, 3, rz)
					end
				end
				-- Start charge
				if rng:NextNumber() < 0.02 and #players > 0 then
					chargeTarget = players[rng:NextInteger(1, #players)]
					charging = true
					chargeStart = tick()
					if chargeTarget then
						self.Client.EntityAttack:FireAll(entityType, chargeTarget)
					end
				end
			else
				-- Charging at target
				if chargeTarget and model.PrimaryPart then
					local targetPos = getPlayerPosition(chargeTarget)
					if targetPos then
						local dir = (targetPos - model.PrimaryPart.Position)
						if dir.Magnitude < 3 then
							PlayerService:DamagePlayer(chargeTarget, ThresholdConfig.EntityDamageHeavy)
							charging = false
						else
							model.PrimaryPart.Position = model.PrimaryPart.Position
								+ dir.Unit * ThresholdConfig.EntitySpeeds.Glitch * doorScaling * (1 / 30)
						end
					end
				end
				if tick() - chargeStart > ThresholdConfig.GlitchChargeDuration then
					charging = false
				end
			end
			task.wait(1 / 30)
		end
	elseif entityType == "Devourer" then
		-- Floor opens, tendrils grab. Must jump / stay on furniture.
		-- Damage players touching floor near entity
		while tick() - startTime < lingerTime and activeEntity and activeEntity.model == model do
			local players = getAlivePlayers()
			for _, player in players do
				local pos = getPlayerPosition(player)
				if pos and model.PrimaryPart then
					local dist = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(
						model.PrimaryPart.Position.X,
						0,
						model.PrimaryPart.Position.Z
					)).Magnitude
					if dist < 6 and pos.Y < roomData.Origin.Y + 2 then
						-- Player is on the floor near the devourer
						PlayerService:DamagePlayer(player, ThresholdConfig.EntityDamageLight)
						self.Client.EntityAttack:FireAll(entityType, player)
					end
				end
			end
			task.wait(0.5)
		end
	end

	self:DespawnEntity()
end

function EntityService:DespawnEntity(): ()
	if not activeEntity then
		return
	end
	local entityType = activeEntity.entityType
	activeEntity.trove:Clean()
	activeEntity = nil
	self.EntityDespawned:Fire(entityType)
	self.Client.EntityDespawned:FireAll(entityType)
end

function EntityService.Client:ReportWatcherLook(player: Player): ()
	-- Client reports they looked at the Watcher too long
	if activeEntity and activeEntity.entityType == "Watcher" then
		PlayerService:DamagePlayer(player, ThresholdConfig.EntityInstantKillHP)
		self.Server.Client.EntityAttack:FireAll("Watcher", player)
	end
end

function EntityService:KnitInit(): () end

function EntityService:KnitStart(): ()
	PlayerService = Knit.GetService("PlayerService")
	RoomService = Knit.GetService("RoomService")

	-- Despawn entity when room clears
	RoomService.RoomClearing:Connect(function()
		self:DespawnEntity()
	end)
end

return EntityService
