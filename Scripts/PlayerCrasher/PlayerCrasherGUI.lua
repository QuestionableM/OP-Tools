--[[
    Copyright (c) 2021 Questionable Mark
]]

if PlayerCrasherGUI then return end
PlayerCrasherGUI = class()

function PlayerCrasherGUI:client_sToServer(modeId, player)
	self.network:sendToServer("server_getCrashInfo", {
		mode = modeId,
		player = player,
		sender = sm.localPlayer.getPlayer()
	})
end

function PlayerCrasherGUI:client_updateCurrentPlayer(btn_name)
	if not self:isAllowed() then return end

	local btn_id = btn_name:sub(0, 4)
	local idx = (btn_id == "Next" and 1 or -1)

	local playerTable = OP.getAllPlayers_exc()
	self.gui.p_instance = nil

	if #playerTable > 0 then
		self.gui.p_id = (self.gui.p_id + idx) % #playerTable
		
		local pl = playerTable[self.gui.p_id + 1]
		self.gui.p_instance = pl
		self.gui.interface:setText("SelectedPlayer", ("(#ffff00%s#ffffff/#ffff00%s#ffffff) Selected Player: #ffff00%s#ffffff"):format(self.gui.p_id + 1, #playerTable, pl.name))
		sm.audio.play("GUI Item drag")
	else
		self.gui.interface:setText("SelectedPlayer", "Select a Player")
		sm.gui.displayAlertText("#ffff00No players to choose from#ffffff", 1.5)
		sm.audio.play("WeldTool - Error")
	end
end

function PlayerCrasherGUI:client_generateGUI()
	if not self:isAllowed() then return end

	self.client_onNewGuiCloseCallback = function(self)
		if self.gui and OP.exists(self.gui.interface) then
			self.gui.interface:destroy()
			self.gui.interface = nil
		end
		self.client_onNewGuiCloseCallback = nil
	end

	self.gui.interface = GUI_STUFF.CONSTRUCT_GUI(self, GUI_STUFF.guis.PlayerKickerGui, {
		[1] = {button = "NextPlayer", callback = "client_updateCurrentPlayer"},
		[2] = {button = "PrevPlayer", callback = "client_updateCurrentPlayer"},
		[3] = {button = "ChangeMode", callback = "client_changeMode"},
		[4] = {button = "KickEveryone", callback = "client_kickEveryone"},
		[5] = {button = "KickCurrent", callback = "client_kickSelected"}
	}, "client_onNewGuiCloseCallback", true)

	self:client_updateGuiText()

	if self.gui.p_instance ~= nil then
		if OP.exists(self.gui.p_instance) then
			local player_table = OP.getAllPlayers_exc()
			self.gui.interface:setText("SelectedPlayer", ("(#ffff00%s#ffffff/#ffff00%s#ffffff) Selected Player: #ffff00%s#ffffff"):format(self.gui.p_id + 1, #player_table, self.gui.p_instance.name))
		else
			self.gui.p_instance = nil
		end
	end
end

function PlayerCrasherGUI:client_constructDialog(description, player, output)
	sm.audio.play("Blueprint - Open")
	self.gui.interface:close()
	GUI_STUFF.open_dialog(
		self, description,
		function(self)
			OP.display("Retrowildblip", true, output:format(type(player) == "Player" and player.name or player))
			self.animation.state = true
			self:client_sToServer(self.gui.crashModes[self.gui.mode + 1].id, player)
			self.gui.p_instance = nil
			self:client_generateGUI()
		end,
		function(self) self:client_generateGUI() end,
		"Blueprint - Delete", "Blueprint - Close"
	)
end

function PlayerCrasherGUI:client_updateGuiText()
	local _gui = self.gui
	local cur_mode = _gui.mode

	local Kick_mode = _gui.crashModes[cur_mode + 1].name
	local Text = _gui.texts[cur_mode + 1]

	local _ui = _gui.interface

	_ui:setText("CurrentSetting", ("Current Mode: #ffff00%s#ffffff"):format(Kick_mode))
	_ui:setText("KickCurrent", ("%s selected player"):format(Text))
	_ui:setText("KickEveryone", ("%s everyone"):format(Text))
end

function PlayerCrasherGUI:client_changeMode()
	sm.audio.play("GUI Item drag")
	self.gui.mode = (self.gui.mode + 1) % #self.gui.crashModes
	self:client_updateGuiText()
end

local function getCurrentModeAndTexts(self, id)
	local CurrentMode = self.gui.crashModes[self.gui.mode + 1].id
	local CText = self.gui.text[CurrentMode].tinker_confirm:format(id)
	local CTextOutput = self.gui.text[CurrentMode].tinker_crashMsg

	return CText, CTextOutput
end

function PlayerCrasherGUI:client_kickEveryone()
	if not self:isAllowed() then return end

	local CText, CTextOutput = getCurrentModeAndTexts(self, "everyone")
	self:client_constructDialog(CText, "everyone", CTextOutput)
end

function PlayerCrasherGUI:client_kickSelected()
	if not self:isAllowed() then return end

	if self.gui.p_instance ~= nil then
		if OP.exists(self.gui.p_instance) then
			local CText, CTextOutput = getCurrentModeAndTexts(self, self.gui.p_instance.name)
			self:client_constructDialog(CText, self.gui.p_instance, CTextOutput)
		else
			self.gui.p_instance = nil
			self.gui.interface:setText("SelectedPlayer", "Select a Player")
			OP.display("Blueprint - Close", true, "#ff0000Selected player doesn't exist anymore!#ffffff", 2)
		end
	else
		OP.display("WeldTool - Error", true, "#ffff00Select a player#ffffff", 3)
	end
end