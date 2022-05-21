--[[
	Copyright (c) 2022 Questionable Mark
]]

if PlayerCrasherGUI then return end
PlayerCrasherGUI = class()

function PlayerCrasherGUI:client_GUI_switchWidget(is_main_gui)
	local gui_int = self.gui.interface

	gui_int:setVisible("MainGuiBG", is_main_gui)
	gui_int:setVisible("ConfirmDialogBG", not is_main_gui)
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

function PlayerCrasherGUI:client_GUI_onDestroy()
	if self.gui and OP.exists(self.gui.interface) then
		self.gui.interface:destroy()
		self.gui.interface = nil
	end
end

function PlayerCrasherGUI:client_GUI_openGui()
	if not self:isAllowed() then return end

	local gui_int = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/PlayerKickerGUI.layout", false, { backgroundAlpha = 0.5, hidesHotbar = true })

	--init main gui callbacks
	gui_int:setButtonCallback("NextPlayer", "client_updateCurrentPlayer")
	gui_int:setButtonCallback("PrevPlayer", "client_updateCurrentPlayer")
	gui_int:setButtonCallback("ChangeMode", "client_changeMode")
	gui_int:setButtonCallback("KickEveryone", "client_kickEveryone")
	gui_int:setButtonCallback("KickCurrent", "client_kickSelected")

	--init confirm gui callbacks
	gui_int:setButtonCallback("Confirm_Yes", "client_CD_OnYesCallback")
	gui_int:setButtonCallback("Confirm_No", "client_CD_OnNoCallback")

	gui_int:setOnCloseCallback("client_GUI_onDestroy")

	self.gui.interface = gui_int
	self:client_updateGuiText()

	if self.gui.p_instance ~= nil then
		if OP.exists(self.gui.p_instance) then
			local player_table = OP.getAllPlayers_exc()
			gui_int:setText("SelectedPlayer", ("(#ffff00%s#ffffff/#ffff00%s#ffffff) Selected Player: #ffff00%s#ffffff"):format(self.gui.p_id + 1, #player_table, self.gui.p_instance.name))
		else
			self.gui.p_instance = nil
		end
	end

	gui_int:open()
end

function PlayerCrasherGUI:client_CD_OnYesCallback()
	local s_gui = self.gui

	self.network:sendToServer("server_getCrashInfo", { s_gui.crashModes[s_gui.mode + 1].id, s_gui.confirm_data })

	self.gui.confirm_data = nil
	self.gui.interface:close()
end

function PlayerCrasherGUI:client_CD_OnNoCallback()
	self:client_GUI_switchWidget(true)

	self.gui.confirm_data = nil
	sm.audio.play("Blueprint - Close")
end

function PlayerCrasherGUI:client_constructDialog(description, player, output)
	self.gui.confirm_data = player
	self.gui.interface:setText("Confirm_Desc", description)

	self:client_GUI_switchWidget(false)

	sm.audio.play("Blueprint - Open")
end

function PlayerCrasherGUI:client_updateGuiText()
	local s_gui = self.gui
	local cur_mode = s_gui.mode

	local Kick_mode = s_gui.crashModes[cur_mode + 1].name
	local Text = s_gui.texts[cur_mode + 1]

	local gui_int = s_gui.interface

	gui_int:setText("CurrentSetting", ("Current Mode: #ffff00%s#ffffff"):format(Kick_mode))
	gui_int:setText("KickCurrent", ("%s selected player"):format(Text))
	gui_int:setText("KickEveryone", ("%s everyone"):format(Text))
end

function PlayerCrasherGUI:client_changeMode()
	sm.audio.play("GUI Item drag")
	self.gui.mode = (self.gui.mode + 1) % #self.gui.crashModes
	self:client_updateGuiText()
end

local function getCurrentModeAndTexts(self, id)
	local cur_mode = self.gui.crashModes[self.gui.mode + 1].id

	local cur_text = self.gui.text[cur_mode].tinker_confirm:format(id)
	local cur_output = self.gui.text[cur_mode].tinker_crashMsg

	return cur_text, cur_output
end

function PlayerCrasherGUI:client_kickEveryone()
	if not self:isAllowed() then return end

	local CText, CTextOutput = getCurrentModeAndTexts(self, "everyone")
	self:client_constructDialog(CText, nil, CTextOutput)
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
			OP.display("Blueprint - Close", false, "#ff0000Selected player doesn't exist anymore!#ffffff", 2)
		end
	else
		OP.display("WeldTool - Error", false, "#ffff00Select a player#ffffff", 3)
	end
end