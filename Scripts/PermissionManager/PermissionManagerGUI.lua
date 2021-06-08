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

function PermissionManagerGUI:client_updatePlayerInfo(btn_name)
	if not self.isAdmin then return end

	local btn_id = btn_name:sub(0, 4)
	local idx = (btn_id == "Next" and 1 or -1)

	local playerTable = OP.getAllPlayers_exc()
	self.gui.page = ((self.gui.page or -1) + idx) % #playerTable

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
end

function PermissionManagerGUI:server_getPlayerPermissions(data)
	self.network:sendToClient(data.sPlayer, "client_requestPlayerPermissions", data.rPlayer)
end

function PermissionManagerGUI:client_setPlayerPermissions(data)
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

function PermissionManagerGUI:server_receivePlayerPermissions(data)
	self.network:sendToClient(data.r_player, "client_setPlayerPermissions", data.main_data)
end

function PermissionManagerGUI:client_requestPlayerPermissions(d_player)
	self.network:sendToServer("server_receivePlayerPermissions", {
		r_player = d_player,
		main_data = {
			player = sm.localPlayer.getPlayer(),
			btn_data = {
				AdminToolPermission = OP.getPermission("AdminTool"),
				FreeCameraPermission = OP.getPermission("FreeCamera"),
				WorldCleanerPermission = OP.getPermission("WorldCleaner"),
				PlayerKickerPermission = OP.getPermission("PlayerKicker")
			}
		}
	})
end

function PermissionManagerGUI:client_resetInterface()
	self.gui.wait_for_data = nil
	self.gui.animationStep = nil
	self.gui.currentPlayer = nil
	self.gui.page = nil
	self.gui.interface:setVisible("WaitingData", false)
	self.gui.interface:setText("WaitingData", "Waiting for data")
	GUI_STUFF.setItemsVisible(self.gui.interface, self.TogglableItems, false)
	self.gui.interface:setVisible("SP_label", true)
end

function PermissionManagerGUI:client_onPermissionButtonCallback(btn_name)
	if not self.isAdmin then return end

	if self.gui.currentPlayer ~= nil then
		if OP.exists(self.gui.currentPlayer) then
			self.gui.buttonData[btn_name].state = not self.gui.buttonData[btn_name].state

			local curBtn = self.gui.buttonData[btn_name]
			local curBoolState = OP.bools[curBtn.state]

			self.gui.interface:setText(btn_name, ("%s = %s"):format(curBtn.name, curBoolState.string))
			sm.audio.play(curBoolState.sound)

			self.network:sendToServer("server_resendButtonData", {btn_id = curBtn.id, state = curBtn.state, player = self.gui.currentPlayer})
			return
		else
			OP.display("error", false, "Selected player doesn't exist anyore!", 3)
		end
	end
	self:client_resetInterface()
end

function PermissionManagerGUI:server_resendButtonData(data)
	self.network:sendToClient(data.player, "client_setPermissionData", {btn_id = data.btn_id, state = data.state})
end

function PermissionManagerGUI:client_setPermissionData(data)
	OP.setPermission(data.btn_id, data.state)
	local cur_wrd = (data.state and "now" or "no longer")

	OP.display("blip", false, ("You can %s use #ffff00%s#ffffff!"):format(cur_wrd, data.btn_id), 3)
end

function PermissionManagerGUI:client_loadPMGUI()
	local gui = GUI_STUFF.createGuiLayout(GUI_STUFF.guis.PermissionManagerGui)

	for btn, k in pairs(self.gui.buttonData) do
		gui:setButtonCallback(btn, "client_onPermissionButtonCallback")
	end
	
	gui:setButtonCallback("NextPlayer", "client_updatePlayerInfo")
	gui:setButtonCallback("PrevPlayer", "client_updatePlayerInfo")

	return gui
end