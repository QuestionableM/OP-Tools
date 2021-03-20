--[[
    Copyright (c) 2021 Questionable Mark
]]

if PlayerCrasherGUI then return end
PlayerCrasherGUI = class()

function PlayerCrasherGUI.client_sToServer(self, modeId, player)
    self.network:sendToServer("server_getCrashInfo", {
        mode = modeId,
        player = player,
        sender = sm.localPlayer.getPlayer()
    })
end

function PlayerCrasherGUI.client_generateGUI(self)
    if not GUI_STUFF.is_gui_supported() then return end
    self.client_onNewGuiCloseCallback = function(self)
        if self.new_gui and OP.exists(self.new_gui.interface) then
            self.new_gui.interface:destroy()
            self.new_gui.interface = nil
        end
        self.client_onNewGuiCloseCallback = nil
    end

    self.new_gui.interface = GUI_STUFF.CONSTRUCT_GUI(self, GUI_STUFF.guis.PlayerKickerGui, {
        [1] = {button = "NextPlayer", callback = "client_nextPlayer"},
        [2] = {button = "PrevPlayer", callback = "client_prevPlayer"},
        [3] = {button = "ChangeMode", callback = "client_changeMode"},
        [4] = {button = "KickEveryone", callback = "client_kickEveryone"},
        [5] = {button = "KickCurrent", callback = "client_kickSelected"}
    }, "client_onNewGuiCloseCallback", true)
    self.new_gui.interface:setText("CurrentSetting", ("Current mode: #ffff00%s#ffffff"):format(self.gui.crashModes[self.new_gui.mode + 1].name))
    local Text = self.new_gui.texts[self.new_gui.mode + 1]
    self.new_gui.interface:setText("KickCurrent", ("%s selected player"):format(Text))
    self.new_gui.interface:setText("KickEveryone", ("%s everyone"):format(Text))

    if self.new_gui.p_instance ~= nil then
        if OP.exists(self.new_gui.p_instance) then
            local player_table = OP.getAllPlayers_exc()
            self.new_gui.interface:setText("SelectedPlayer", ("(#ffff00%s#ffffff/#ffff00%s#ffffff) Selected player: #ffff00%s#ffffff"):format(self.new_gui.p_id + 1, #player_table, self.new_gui.p_instance.name))
        else
            self.new_gui.p_instance = nil
        end
    end
end

function PlayerCrasherGUI.client_constructDialog(self, description, player, output)
    if not GUI_STUFF.is_gui_supported() then return end
    sm.audio.play("Blueprint - Open")
    self.new_gui.interface:close()
    GUI_STUFF.open_dialog(
        self, description,
        function(self)
            OP.display("Retrowildblip", true, output:format(type(player) == "Player" and player.name or player))
            self.animation.state = true
            self:client_sToServer(self.gui.crashModes[self.new_gui.mode + 1].id, player)
            self.new_gui.p_instance = nil
            self:client_generateGUI()
        end,
        function(self) self:client_generateGUI() end,
        "Blueprint - Delete", "Blueprint - Close"
    )
end

function PlayerCrasherGUI.client_changeMode(self)
    if not GUI_STUFF.is_gui_supported() then return end
    sm.audio.play("GUI Item drag")
    self.new_gui.mode = (self.new_gui.mode + 1) % #self.gui.crashModes
    local Kick_mode = self.gui.crashModes[self.new_gui.mode + 1].name
    local Text = self.new_gui.texts[self.new_gui.mode + 1]
    self.new_gui.interface:setText("CurrentSetting", ("Current mode: #ffff00%s#ffffff"):format(Kick_mode))
    self.new_gui.interface:setText("KickCurrent", ("%s selected player"):format(Text))
    self.new_gui.interface:setText("KickEveryone", ("%s everyone"):format(Text))
end
local function getCurrentModeAndTexts(self, id)
    local CurrentMode = self.gui.crashModes[self.new_gui.mode + 1].id
    local CText = self.gui.text[CurrentMode].tinker_confirm:format(id)
    local CTextOutput = self.gui.text[CurrentMode].tinker_crashMsg
    return CText, CTextOutput
end
function PlayerCrasherGUI.client_kickEveryone(self)
    if not GUI_STUFF.is_gui_supported() then return end
    local CText, CTextOutput = getCurrentModeAndTexts(self, "everyone")
    self:client_constructDialog(CText, "everyone", CTextOutput)
end
function PlayerCrasherGUI.client_kickSelected(self)
    if not GUI_STUFF.is_gui_supported() then return end
    if self.new_gui.p_instance ~= nil then
        if OP.exists(self.new_gui.p_instance) then
            local CText, CTextOutput = getCurrentModeAndTexts(self, self.new_gui.p_instance.name)
            self:client_constructDialog(CText, self.new_gui.p_instance, CTextOutput)
        else
            self.new_gui.p_instance = nil
            self.new_gui.interface:setText("SelectedPlayer", "Select a player")
            OP.display("Blueprint - Close", true, "#ff0000The selected player doesn't exist anymore!#ffffff", 2)
        end
    else
        OP.display("WeldTool - Error", true, "#ffff00Select a player#ffffff", 3)
    end
end
function PlayerCrasherGUI.client_updateCurrentPlayer(self, idx)
    if not GUI_STUFF.is_gui_supported() then return end
    sm.audio.play("GUI Item drag")
    local playerTable = OP.getAllPlayers_exc()
    self.new_gui.p_instance = nil
    if #playerTable > 0 then
        self.new_gui.p_id = (self.new_gui.p_id + idx) % #playerTable
        local pl = playerTable[self.new_gui.p_id + 1]
        self.new_gui.p_instance = pl
        self.new_gui.interface:setText("SelectedPlayer", ("(#ffff00%s#ffffff/#ffff00%s#ffffff) Selected player: #ffff00%s#ffffff"):format(self.new_gui.p_id + 1, #playerTable, pl.name))
    else
        self.new_gui.interface:setText("SelectedPlayer", "Select a player")
        sm.gui.displayAlertText("#ffff00No players to choose from#ffffff", 1.5)
    end
end
function PlayerCrasherGUI.client_nextPlayer(self) self:client_updateCurrentPlayer(1) end
function PlayerCrasherGUI.client_prevPlayer(self) self:client_updateCurrentPlayer(-1) end