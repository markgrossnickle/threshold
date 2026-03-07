--!strict
--[=[
	@class PlayerData
	@server
]=]

export type PlayerData = {
	BestDoor: number,
	TotalRuns: number,
	TotalDeaths: number,
	CollectedLore: { [string]: boolean },
	UnlockedCosmetics: { [string]: boolean },
	EquippedFlashlightSkin: string,
	EquippedOutfit: string,
}

local playerDataTemplate: PlayerData = {
	BestDoor = 0,
	TotalRuns = 0,
	TotalDeaths = 0,
	CollectedLore = {},
	UnlockedCosmetics = {},
	EquippedFlashlightSkin = "Default",
	EquippedOutfit = "Default",
}

return playerDataTemplate
