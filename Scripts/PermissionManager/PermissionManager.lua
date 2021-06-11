--[[
	Copyright (c) 2021 Questionable Mark
]]

if PermissionManager then return end
dofile("../libs/ScriptLoader.lua")
dofile("PermissionManagerGUI.lua")
PermissionManager = class(PermissionManagerGUI)
PermissionManager.connectionInput = sm.interactable.connectionType.none
PermissionManager.connectionOutput = sm.interactable.connectionType.none

function PermissionManager:server_onCreate()
	self.isAdmin = true
end

function PermissionManager:client_onCreate()
	if not self.isAdmin then return end

	self:client_loadPMGUI()
end

function PermissionManager:client_onFixedUpdate()
	self:client_GUI_UpdateWaitAnimation()
end

local _GetKeyBinding = sm.gui.getKeyBinding
local _SetInteractionText = sm.gui.setInteractionText
function PermissionManager:client_canInteract()
	if self.isAdmin then
		local _useKey = _GetKeyBinding("Use")
		_SetInteractionText("Press", _useKey, "to open the GUI of Permission Manager")
		_SetInteractionText("")
		return true
	end

	_SetInteractionText("", "Only server admin can use this tool")
	_SetInteractionText("")
	return false
end

function PermissionManager:client_onInteract(character, state)
	if not state or not self.isAdmin then return end

	self:client_GUI_OpenGui()
end

local _DisplayAlertText = sm.gui.displayAlertText
function PermissionManager:client_canErase()
	if self.isAdmin then return true end
	_DisplayAlertText("Only server admin can break this tool", 1)
	return false
end

function PermissionManager:client_onDestroy()
	GUI_STUFF.close_and_destroy_dialogs({self.gui and self.gui.interface})
end