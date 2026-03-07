--!strict
local ThresholdConfig = {}

-- General
ThresholdConfig.MaxDoors = 100
ThresholdConfig.MaxPlayers = 4
ThresholdConfig.SafeRoomInterval = 10 -- every N doors is a safe room

-- Room dimensions
ThresholdConfig.RoomMinSize = 20
ThresholdConfig.RoomMaxSize = 40
ThresholdConfig.RoomHeight = 15
ThresholdConfig.WallThickness = 2
ThresholdConfig.DoorWidth = 6
ThresholdConfig.DoorHeight = 8

-- Room type weights (must sum to 1.0)
ThresholdConfig.RoomWeights = {
	Empty = 0.15,
	Key = 0.20,
	Puzzle = 0.15,
	Entity = 0.25,
	Dark = 0.15,
	Trap = 0.10,
}

-- Room types list for iteration
ThresholdConfig.RoomTypes = { "Empty", "Key", "Puzzle", "Entity", "Dark", "Trap" }

-- Props
ThresholdConfig.MinProps = 5
ThresholdConfig.MaxProps = 12
ThresholdConfig.PropPadding = 2 -- min distance between props

-- Player stats
ThresholdConfig.MaxHP = 100
ThresholdConfig.SprintMultiplier = 1.5
ThresholdConfig.SprintDuration = 5 -- seconds of full sprint
ThresholdConfig.SprintRecharge = 3 -- seconds to full recharge
ThresholdConfig.CrouchSpeedMultiplier = 0.5
ThresholdConfig.BaseWalkSpeed = 16

-- Flashlight
ThresholdConfig.FlashlightBattery = 180 -- seconds
ThresholdConfig.FlashlightRechargeRate = 0.33 -- battery seconds recovered per real second (off)
ThresholdConfig.FlashlightRange = 60
ThresholdConfig.FlashlightAngle = 45
ThresholdConfig.FlashlightBrightness = 2

-- Entity damage
ThresholdConfig.EntityDamageLight = 30
ThresholdConfig.EntityDamageHeavy = 50
ThresholdConfig.EntityInstantKillHP = 100
ThresholdConfig.EntityWarningDuration = 2.5 -- seconds of warning before spawn

-- Entity unlock doors
ThresholdConfig.EntityUnlockDoors = {
	Shadow = 1,
	Crawler = 5,
	Mimic = 10,
	Whisper = 15,
	Watcher = 25,
	Glitch = 35,
	Devourer = 50,
}

-- Entity speeds
ThresholdConfig.EntitySpeeds = {
	Shadow = 40,
	Crawler = 20,
	Glitch = 35,
}

-- Entity timings
ThresholdConfig.EntityLingerTime = { min = 8, max = 12 } -- seconds entities stay
ThresholdConfig.WatcherLookThreshold = 2 -- seconds of looking triggers attack
ThresholdConfig.WatcherDespawnTime = 8
ThresholdConfig.GlitchChargeDuration = 3

-- Difficulty scaling
ThresholdConfig.DifficultyScaling = {
	entitySpeedBonus = 0.005, -- per door number
	lightReduction = 0.005, -- per door number
	puzzleComplexityBonus = 0.02, -- per door number
	entityCountBonus = 0.01, -- per door number, multiplied by player count
}

-- Lighting
ThresholdConfig.BaseFogEnd = 200
ThresholdConfig.DarkRoomFogEnd = 60
ThresholdConfig.AmbientLight = Color3.fromRGB(15, 15, 20)
ThresholdConfig.DarkRoomAmbient = Color3.fromRGB(5, 5, 8)
ThresholdConfig.EmergencyLightColor = Color3.fromRGB(180, 30, 30)
ThresholdConfig.NormalLightColor = Color3.fromRGB(200, 180, 150)
ThresholdConfig.NormalLightBrightness = 1.5
ThresholdConfig.NormalLightRange = 30

-- Room materials and colors
ThresholdConfig.WallColor = Color3.fromRGB(60, 55, 50)
ThresholdConfig.FloorColor = Color3.fromRGB(50, 45, 42)
ThresholdConfig.CeilingColor = Color3.fromRGB(40, 38, 35)
ThresholdConfig.WallMaterial = Enum.Material.Concrete
ThresholdConfig.FloorMaterial = Enum.Material.Concrete
ThresholdConfig.CeilingMaterial = Enum.Material.Concrete

-- Puzzle config
ThresholdConfig.PuzzleTypes = { "LeverSequence", "NumberPad", "PatternMatch", "WireConnect", "Generator" }
ThresholdConfig.BaseLeverCount = 3
ThresholdConfig.MaxLeverCount = 5
ThresholdConfig.BaseCodeLength = 4
ThresholdConfig.BasePatternLength = 4
ThresholdConfig.BaseWireCount = 3
ThresholdConfig.MaxWireCount = 4
ThresholdConfig.BaseFuelCanisters = 2
ThresholdConfig.MaxFuelCanisters = 3

-- Multiplayer scaling
ThresholdConfig.EntityCountPerPlayer = 0.5 -- additional entity chance multiplier per extra player
ThresholdConfig.EntitySpeedPerPlayer = 0.05 -- speed bonus per extra player

-- Transition timing
ThresholdConfig.RoomTransitionFadeTime = 0.8
ThresholdConfig.DoorOpenTime = 1.0
ThresholdConfig.RoomNumberDisplayTime = 2.0

-- Mobile
ThresholdConfig.MobileButtonSize = 48
ThresholdConfig.MobileParticleReduction = 0.5

return table.freeze(ThresholdConfig)
