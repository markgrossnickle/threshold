--!strict
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local PlatformUtil = {}

function PlatformUtil.isMobile(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function PlatformUtil.isConsole(): boolean
	return GuiService:IsTenFootInterface()
end

function PlatformUtil.isPC(): boolean
	return UserInputService.KeyboardEnabled and not GuiService:IsTenFootInterface()
end

function PlatformUtil.isGamepad(): boolean
	return UserInputService.GamepadEnabled
end

function PlatformUtil.hasTouchScreen(): boolean
	return UserInputService.TouchEnabled
end

return table.freeze(PlatformUtil)
