--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local ThresholdConfig = require(ReplicatedStorage.Shared.ThresholdConfig)

local GameService

local PlayerService = Knit.CreateService({
	Name = "PlayerService",
	Client = {
		HPChanged = Knit.CreateSignal(),
		StaminaChanged = Knit.CreateSignal(),
		BatteryChanged = Knit.CreateSignal(),
		FlashlightToggled = Knit.CreateSignal(),
		PlayerDied = Knit.CreateSignal(),
		KeyPickedUp = Knit.CreateSignal(),
	},
	PlayerDied = Signal.new(),
})

export type PlayerState = {
	HP: number,
	Stamina: number,
	Battery: number,
	FlashlightOn: boolean,
	IsSprinting: boolean,
	IsCrouching: boolean,
	HasKey: boolean,
	IsAlive: boolean,
}

local playerStates: { [Player]: PlayerState } = {}
local playerTroves: { [Player]: typeof(Trove.new()) } = {}

function PlayerService:InitializePlayer(player: Player): ()
	local state: PlayerState = {
		HP = ThresholdConfig.MaxHP,
		Stamina = 1.0, -- 0.0 to 1.0
		Battery = 1.0, -- 0.0 to 1.0
		FlashlightOn = false,
		IsSprinting = false,
		IsCrouching = false,
		HasKey = false,
		IsAlive = true,
	}
	playerStates[player] = state

	self.Client.HPChanged:Fire(player, state.HP)
	self.Client.StaminaChanged:Fire(player, state.Stamina)
	self.Client.BatteryChanged:Fire(player, state.Battery)
end

function PlayerService:GetPlayerState(player: Player): PlayerState?
	return playerStates[player]
end

function PlayerService.Client:GetPlayerState(player: Player): PlayerState?
	return playerStates[player]
end

function PlayerService:DamagePlayer(player: Player, damage: number): ()
	local state = playerStates[player]
	if not state or not state.IsAlive then
		return
	end

	state.HP = math.max(0, state.HP - damage)
	self.Client.HPChanged:Fire(player, state.HP)

	if state.HP <= 0 then
		state.IsAlive = false
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
		end
		self.Client.PlayerDied:Fire(player)
		self.PlayerDied:Fire(player)
		GameService:OnPlayerDied(player)
	end
end

function PlayerService:HealPlayer(player: Player, amount: number): ()
	local state = playerStates[player]
	if not state or not state.IsAlive then
		return
	end

	state.HP = math.min(ThresholdConfig.MaxHP, state.HP + amount)
	self.Client.HPChanged:Fire(player, state.HP)
end

function PlayerService.Client:ToggleFlashlight(player: Player): ()
	local state = playerStates[player]
	if not state or not state.IsAlive then
		return
	end
	state.FlashlightOn = not state.FlashlightOn
	self.Server.Client.FlashlightToggled:Fire(player, state.FlashlightOn)
end

function PlayerService.Client:SetSprinting(player: Player, sprinting: boolean): ()
	local state = playerStates[player]
	if not state or not state.IsAlive then
		return
	end
	state.IsSprinting = sprinting

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if sprinting and state.Stamina > 0 then
				humanoid.WalkSpeed = ThresholdConfig.BaseWalkSpeed * ThresholdConfig.SprintMultiplier
			else
				humanoid.WalkSpeed = ThresholdConfig.BaseWalkSpeed
			end
		end
	end
end

function PlayerService.Client:SetCrouching(player: Player, crouching: boolean): ()
	local state = playerStates[player]
	if not state or not state.IsAlive then
		return
	end
	state.IsCrouching = crouching

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if crouching then
				humanoid.WalkSpeed = ThresholdConfig.BaseWalkSpeed * ThresholdConfig.CrouchSpeedMultiplier
				-- Shrink hitbox slightly
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					humanoid.HipHeight = 0.5
				end
			else
				humanoid.WalkSpeed = if state.IsSprinting and state.Stamina > 0
					then ThresholdConfig.BaseWalkSpeed * ThresholdConfig.SprintMultiplier
					else ThresholdConfig.BaseWalkSpeed
				humanoid.HipHeight = 2
			end
		end
	end
end

function PlayerService.Client:PickUpKey(player: Player): ()
	local state = playerStates[player]
	if not state or not state.IsAlive then
		return
	end
	state.HasKey = true
	self.Server.Client.KeyPickedUp:Fire(player)
end

function PlayerService.Client:UseKey(player: Player): boolean
	local state = playerStates[player]
	if not state or not state.HasKey then
		return false
	end
	state.HasKey = false

	local RoomService = Knit.GetService("RoomService")
	RoomService:UnlockExitDoor()
	return true
end

function PlayerService.Client:Interact(player: Player, targetPath: string): ()
	-- Server-side interaction validation
	local target = workspace:FindFirstChild(targetPath, true)
	if not target then
		return
	end

	local interactable = target:FindFirstChild("Interactable")
	if not interactable then
		return
	end

	local interactType = target:FindFirstChild("InteractType") :: StringValue?
	if not interactType then
		return
	end

	local state = playerStates[player]
	if not state or not state.IsAlive then
		return
	end

	if interactType.Value == "Key" then
		state.HasKey = true
		self.Server.Client.KeyPickedUp:Fire(player)
		target:Destroy()
	elseif interactType.Value == "Search" then
		-- Cabinet search — just an interaction confirmation
		-- Could hide a key here in future
	end
end

function PlayerService:ResetAllPlayers(): ()
	for _, player in Players:GetPlayers() do
		self:InitializePlayer(player)
		-- Reset walk speed
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = ThresholdConfig.BaseWalkSpeed
				humanoid.HipHeight = 2
			end
		end
	end
end

function PlayerService:_startUpdateLoop(): ()
	local TICK = 1 / 30
	task.spawn(function()
		while true do
			task.wait(TICK)
			for player, state in playerStates do
				if not state.IsAlive then
					continue
				end

				-- Stamina
				if state.IsSprinting and state.Stamina > 0 then
					state.Stamina = math.max(0, state.Stamina - TICK / ThresholdConfig.SprintDuration)
					if state.Stamina <= 0 then
						-- Force stop sprint
						state.IsSprinting = false
						local character = player.Character
						if character then
							local humanoid = character:FindFirstChildOfClass("Humanoid")
							if humanoid then
								humanoid.WalkSpeed = ThresholdConfig.BaseWalkSpeed
							end
						end
					end
					self.Client.StaminaChanged:Fire(player, state.Stamina)
				elseif not state.IsSprinting and state.Stamina < 1 then
					state.Stamina = math.min(1, state.Stamina + TICK / ThresholdConfig.SprintRecharge)
					self.Client.StaminaChanged:Fire(player, state.Stamina)
				end

				-- Battery
				if state.FlashlightOn and state.Battery > 0 then
					state.Battery = math.max(0, state.Battery - TICK / ThresholdConfig.FlashlightBattery)
					if state.Battery <= 0 then
						state.FlashlightOn = false
						self.Client.FlashlightToggled:Fire(player, false)
					end
					self.Client.BatteryChanged:Fire(player, state.Battery)
				elseif not state.FlashlightOn and state.Battery < 1 then
					state.Battery = math.min(1, state.Battery + TICK * ThresholdConfig.FlashlightRechargeRate / ThresholdConfig.FlashlightBattery)
					self.Client.BatteryChanged:Fire(player, state.Battery)
				end
			end
		end
	end)
end

function PlayerService:KnitInit(): ()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			self:InitializePlayer(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerStates[player] = nil
		if playerTroves[player] then
			playerTroves[player]:Clean()
			playerTroves[player] = nil
		end
	end)
end

function PlayerService:KnitStart(): ()
	GameService = Knit.GetService("GameService")
	self:_startUpdateLoop()
end

return PlayerService
