--[[
    Copyright (c) 2021 Questionable Mark
]]

if PermissionManager then return end
dofile("../libs/ScriptLoader.lua")
dofile("PermissionManagerGUI.lua")
PermissionManager = class(PermissionManagerGUI)
PermissionManager.connectionInput = sm.interactable.connectionType.none
PermissionManager.connectionOutput = sm.interactable.connectionType.none
function PermissionManager.server_onCreate(self)
    self.isAdmin = true
    OP.setAdminFlag()
end
function PermissionManager.client_onCreate(self)
    if GUI_STUFF.is_gui_supported() and self.isAdmin then
        self.gui = {}
        self.gui.interface = self:client_loadPMGUI()
        self.gui.buttonData = {
            AdminToolPermission = {name = "Admin Tool", button = "AdminToolPermission", id = "AdminTool", state = false},
            FreeCameraPermission = {name = "Free Camera", button = "FreeCameraPermission", id = "FreeCamera", state = false},
            WorldCleanerPermission = {name = "World Cleaner", button = "WorldCleanerPermission", id = "WorldCleaner", state = false},
            PlayerKickerPermission = {name = "Player Kicker", button = "PlayerKickerPermission", id = "PlayerKicker", state = false}
        }
    end
end
local animationSteps = {[1] = "", [2] = ".", [3] = "..", [4] = "..."}
function PermissionManager.client_onFixedUpdate(self)
    if self.gui and self.gui.wait_for_data then
        local currentTick = sm.game.getCurrentTick() % 16
        if currentTick == 15 then
            self.gui.animationStep = ((self.gui.animationStep or -1) + 1) % #animationSteps
            self.gui.interface:setText("WaitingData", ("Waiting for data%s"):format(animationSteps[self.gui.animationStep + 1]))
        end
    end
end
function PermissionManager.client_canInteract(self)
    if self.isAdmin then
        if GUI_STUFF.is_gui_supported() then
            local _useKey = sm.gui.getKeyBinding("Use")
            sm.gui.setInteractionText("Press", _useKey, "to open the GUI of Permission Manager")
        else
            sm.gui.setInteractionText("", "Scrap Mechanic version has to be higher than 0.4.8 in order to use that block")
        end
        sm.gui.setInteractionText("")
        return true
    end
    sm.gui.setInteractionText("", "Only server admin can use this tool")
    sm.gui.setInteractionText("")
    return false
end
function PermissionManager.client_onInteract(self, character, state)
    if state and self.isAdmin and GUI_STUFF.is_gui_supported() then self.gui.interface:open() end
end
function PermissionManager.client_canErase(self)
    if self.isAdmin then return true end
    sm.gui.displayAlertText("Only server admin can break this tool", 1)
    return false
end
function PermissionManager.client_onDestroy(self)
    GUI_STUFF.close_and_destroy_dialogs({self.gui and self.gui.interface})
end