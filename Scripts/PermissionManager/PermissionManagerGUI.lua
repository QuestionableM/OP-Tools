--[[
    Copyright (c) 2021 Questionable Mark
]]

if PermissionManagerGUI then return end
PermissionManagerGUI = class()

PermissionManagerGUI.TogglableItems = {
    "AdminToolPermission", "FreeCameraPermission",
    "WorldCleanerPermission", "PlayerKickerPermission",
    "SelectedPlayer", "SP_text"
}

function PermissionManagerGUI.client_updatePlayerInfo(self, idx)
    local playerTable = OP.getAllPlayers_exc()
    self.gui.page = ((self.gui.page or -1) + idx) % #playerTable
    if OP.getAdminFlag() then
        if #playerTable > 0 then
            sm.audio.play("GUI Item drag")
            local selectedPlayer = playerTable[self.gui.page + 1]
            if self.gui.currentPlayer == nil or selectedPlayer ~= self.gui.currentPlayer then
                GUI_STUFF.setItemsVisible(self.gui.interface, self.TogglableItems, false)
                self.gui.currentPlayer = selectedPlayer
                self.gui.wait_for_data = true
                self.gui.interface:setVisible("WaitingData", self.gui.wait_for_data)
                self.gui.interface:setVisible("SP_label", false)
                self.gui.interface:setText("SelectedPlayer", ("[#ffff00%s#ffffff/#ffff00%s#ffffff] Selected player: #ffff00%s#ffffff"):format(self.gui.page + 1, #playerTable, selectedPlayer.name))
                self.network:sendToServer("server_getPlayerPermissions", {sPlayer = selectedPlayer, rPlayer = sm.localPlayer.getPlayer()})
            end
        else
            OP.display("error", false, "No players to choose from", 3)
            self:client_resetInterface()
        end
    else
        OP.display("error", false, "You do not have permission to use this tool!")
    end
end

function PermissionManagerGUI.server_getPlayerPermissions(self, data)
    self.network:sendToClient(data.sPlayer, "client_requestPlayerPermissions", data.rPlayer)
end

function PermissionManagerGUI.client_setPlayerPermissions(self, data)
    if self.gui.currentPlayer ~= nil and self.gui.currentPlayer == data.player then
        for button_id, permission in pairs(data.btn_data) do
            self.gui.buttonData[button_id].state = permission
            local currentButton = self.gui.buttonData[button_id]
            self.gui.interface:setText(currentButton.button, ("%s = %s"):format(currentButton.name, OP.bools[currentButton.state].string))
        end
        self.gui.wait_for_data = nil
        self.gui.animationStep = nil
        self.gui.interface:setVisible("WaitingData", false)
        self.gui.interface:setText("WaitingData", "Waiting for data")
        GUI_STUFF.setItemsVisible(self.gui.interface, self.TogglableItems, true)
    end
end

function PermissionManagerGUI.server_receivePlayerPermissions(self, data)
    self.network:sendToClient(data.r_player, "client_setPlayerPermissions", data.main_data)
end

function PermissionManagerGUI.client_requestPlayerPermissions(self, d_player)
    self.network:sendToServer("server_receivePlayerPermissions", {
        main_data = {
            btn_data = {
                AdminToolPermission = OP.getPermission("AdminTool"),
                FreeCameraPermission = OP.getPermission("FreeCamera"),
                WorldCleanerPermission = OP.getPermission("WorldCleaner"),
                PlayerKickerPermission = OP.getPermission("PlayerKicker")
            }, player = sm.localPlayer.getPlayer()
        }, r_player = d_player
    })
end

function PermissionManagerGUI.client_onPrevPlayerCallback(self) self:client_updatePlayerInfo(-1) end
function PermissionManagerGUI.client_onNextPlayerCallback(self) self:client_updatePlayerInfo(1) end

function PermissionManagerGUI.client_resetInterface(self)
    self.gui.wait_for_data = nil
    self.gui.animationStep = nil
    self.gui.currentPlayer = nil
    self.gui.page = nil
    self.gui.interface:setVisible("WaitingData", false)
    self.gui.interface:setText("WaitingData", "Waiting for data")
    GUI_STUFF.setItemsVisible(self.gui.interface, self.TogglableItems, false)
    self.gui.interface:setVisible("SP_label", true)
end

function PermissionManagerGUI.client_onPermissionButtonCallback(self, caller)
    if self.gui.currentPlayer ~= nil then
        if OP.exists(self.gui.currentPlayer) then
            self.gui.buttonData[caller].state = not self.gui.buttonData[caller].state
            local curBtn = self.gui.buttonData[caller]
            local curBoolState = OP.bools[curBtn.state]
            self.gui.interface:setText(caller, ("%s = %s"):format(curBtn.name, curBoolState.string))
            sm.audio.play(curBoolState.sound, sm.camera.getPosition())
            self.network:sendToServer("server_resendButtonData", {btn_id = curBtn.id, state = curBtn.state, player = self.gui.currentPlayer})
            return
        else
            OP.display("error", false, "Selected player doesn't exist anyore!", 3)
        end
    end
    self:client_resetInterface()
end

function PermissionManagerGUI.server_resendButtonData(self, data)
    self.network:sendToClient(data.player, "client_setPermissionData", {btn_id = data.btn_id, state = data.state})
end

function PermissionManagerGUI.client_setPermissionData(self, data)
    OP.setPermission(data.btn_id, data.state)
    if data.state then
        OP.display("blip", false, "You can now use #ffff00"..data.btn_id.."#ffffff!", 3)
    else
        OP.display("blip", false, "You can no longer use #ffff00"..data.btn_id.."#ffffff", 3)
    end
end

local function CREATE_GUI_CALLBACKS(self, gui, callback_table)
    for id, callback in pairs(callback_table) do
        self[callback.callback] = function(self)
            self:client_onPermissionButtonCallback(callback.button)
        end
        gui:setButtonCallback(callback.button, callback.callback)
    end
end

function PermissionManagerGUI.client_loadPMGUI(self)
    local gui = GUI_STUFF.createGuiLayout(GUI_STUFF.guis.PermissionManagerGui)
    CREATE_GUI_CALLBACKS(self, gui, {
        [1] = {button = "AdminToolPermission", callback = "client_onAdminToolPermissionCallback"},
        [2] = {button = "FreeCameraPermission", callback = "client_onFreeCameraPermissionCallback"},
        [3] = {button = "WorldCleanerPermission", callback = "client_onWorldCleanerPermissionCallback"},
        [4] = {button = "PlayerKickerPermission", callback = "client_onPlayerKickerPermissionCallback"}
    })
    gui:setButtonCallback("NextPlayer", "client_onNextPlayerCallback")
    gui:setButtonCallback("PrevPlayer", "client_onPrevPlayerCallback")
    return gui
end