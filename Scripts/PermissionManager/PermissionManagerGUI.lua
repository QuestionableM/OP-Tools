--[[
	Copyright (c) 2021 Questionable Mark
]]

if PermissionManagerGUI then return end
PermissionManagerGUI = class()

function PermissionManagerGUI:client_loadPMGUI()
	if not self.isAdmin then return end

	local gui = GUI_STUFF.createGuiLayout(GUI_STUFF.guis.PermissionManagerGui)

	self.gui = {}
	self.gui.buttonData = {
		AdminToolPerm = {name = "Admin Tool", id = "AdminTool", state = false},
		FreeCamPerm = {name = "Free Camera", id = "FreeCamera", state = false},
		WorldCleanerPerm = {name = "World Cleaner", id = "WorldCleaner", state = false},
		PlayerKickerPerm = {name = "Player Kicker", id = "PlayerKicker", state = false}
	}
	self.gui.cur_page = -1

	for btn, k in pairs(self.gui.buttonData) do
		gui:setButtonCallback(btn, "client_onPermissionButtonCallback")
	end

	for k, btn in pairs({"Next", "Prev"}) do
		gui:setButtonCallback(btn.."Player", "client_updatePlayerInfo")
	end

	gui:setOnCloseCallback("client_GUI_ResetInterface")

	self.gui.interface = gui
end

function PermissionManagerGUI:client_GUI_OpenGui()
	if not self.isAdmin then return end

	self:client_GUI_UpdateCurrentPage()
	self.gui.interface:open()
end

local _AudioPlay = sm.audio.play
function PermissionManagerGUI:client_onPermissionButtonCallback(btn_name)
	if not self.isAdmin then return end
	local cur_player = self.gui.current_player

	if OP.exists(cur_player) then
		local buttonData = self.gui.buttonData
		local cur_btn_data = buttonData[btn_name]

		cur_btn_data.state = not cur_btn_data.state
		local cur_bool = OP.bools[cur_btn_data.state]

		self.gui.interface:setText(btn_name, ("%s = %s"):format(cur_btn_data.name, cur_bool.string))
		_AudioPlay(cur_bool.sound)

		self.network:sendToServer("server_GUI_SetPermission", {
			player = cur_player,
			tool = cur_btn_data.id,
			state = cur_btn_data.state
		})
	else
		OP.display("error", false, "The specified player doesn't exist anymore!", 3)
		self:client_GUI_ResetInterface()
	end
end

function PermissionManagerGUI:server_GUI_SetPermission(data, caller)
	if caller == OP.server_admin then
		local l_Tool = data.tool
		local l_State = data.state
		local l_Player = data.player

		OP.setPlayerPermission(l_Player, l_Tool, l_State)

		self.network:sendToClient(l_Player, "client_GUI_SetLocalPermission", {
			tool = l_Tool,
			state = l_State
		})
	else
		self.network:sendToClient(caller, "client_onErrorMessage", "p_udata")
	end
end

local tool_name_conv = {
	AdminTool = "Admin Tool",
	FreeCamera = "Free Camera",
	WorldCleaner = "World Cleaner",
	PlayerKicker = "Player Kicker"
}
function PermissionManagerGUI:client_GUI_SetLocalPermission(data)
	local state = data.state
	local tool = data.tool

	OP.setClientPermission(tool, state)

	local cur_text = (state and "now" or "no longer")
	local cur_tool_name = tool_name_conv[tool]
	OP.display("blip", false, ("You can %s use #ffff00%s#ffffff"):format(cur_text, cur_tool_name), 3)
end

local _clamp = sm.util.clamp
local _GetLocalPlayer = sm.localPlayer.getPlayer
local _GetAllPlayersEX = OP.getAllPlayers_exc
function PermissionManagerGUI:client_updatePlayerInfo(btn_name)
	if not self.isAdmin then return end

	local btn_id = btn_name:sub(0, 4)
	local idx = ("Next" and 1 or -1)

	local player_list = _GetAllPlayersEX()
	local player_count = #player_list

	if player_count > 0 then
		local new_value = _clamp(self.gui.cur_page + idx, 0, player_count - 1)
		local new_player = player_list[new_value + 1]

		if (new_value == self.gui.cur_page and self.gui.current_player == new_player) then return end

		self.gui.current_player = new_player

		self.gui.cur_page = new_value
		self:client_GUI_UpdateCurrentPage()

		local gui_int = self.gui.interface
		
		gui_int:setText("CurPlayer", ("Player: #ffff00%s#ffffff"):format(new_player.name))

		self:client_GUI_SetSelectState(true)
		self:client_GUI_SetWaitingState(false)

		_AudioPlay("GUI Item drag")

		self.network:sendToServer("server_requestClientData", new_player)
	else
		OP.display("error", false, "No players to choose", 3)

		if self.gui.current_player then
			self:client_GUI_ResetInterface()
		end
	end
end


function PermissionManagerGUI:server_requestClientData(player, caller)
	local output_data = nil
	if caller == OP.server_admin then
		output_data = {
			player = player,
			perm = {
				AdminTool = OP.getPlayerPermission(player, "AdminTool"),
				FreeCamera = OP.getPlayerPermission(player, "FreeCamera"),
				WorldCleaner = OP.getPlayerPermission(player, "WorldCleaner"),
				PlayerKicker = OP.getPlayerPermission(player, "PlayerKicker")
			}
		}
	else
		output_data = "nperm"
		self.network:sendToClient(caller, "client_onErrorMessage", "p_getdata")
	end

	self.network:sendToClient(caller, "client_receiveClientData", output_data)
end

function PermissionManagerGUI:client_receiveClientData(data)
	if data == "nperm" then
		self.gui.interface:setText("SelectPlayer", "#ffaa00NO PERMISSION#ffffff")
		self:client_GUI_ResetInterface()
		return
	end

	local cur_player = self.gui.current_player

	if self.wait_for_data and (cur_player and cur_player == data.player) then
		local perm_data = data.perm

		for btn, btn_data in pairs(self.gui.buttonData) do
			local cur_data = perm_data[btn_data.id]

			if cur_data ~= nil then
				self.gui.buttonData[btn].state = cur_data
			end
		end

		self:client_GUI_SetWaitingState(true)
	end
end


function PermissionManagerGUI:client_GUI_SetSelectState(state)
	local gui_int = self.gui.interface

	for k, btn in pairs({"CurPlayer", "PermissionBG"}) do
		gui_int:setVisible(btn, state)
	end

	gui_int:setVisible("SelectPlayer", not state)
end

function PermissionManagerGUI:client_GUI_SetWaitingState(state, ignore_timer)
	local gui_int = self.gui.interface

	for k, btn in pairs({"AdminToolPerm", "WorldCleanerPerm", "FreeCamPerm", "PlayerKickerPerm", "QLabel"}) do
		gui_int:setVisible(btn, state)
	end

	if state then
		local btn_data = self.gui.buttonData
		for k, btn in pairs({"AdminToolPerm", "WorldCleanerPerm", "FreeCamPerm", "PlayerKickerPerm"}) do
			local cur_btn_data = btn_data[btn]
			local cur_bool_str = OP.bools[cur_btn_data.state].string

			gui_int:setText(btn, ("%s = %s"):format(cur_btn_data.name, cur_bool_str))
		end
	end

	gui_int:setVisible("WaitDataLabel", not state)

	if not ignore_timer then
		self.wait_for_data = (not state and true or nil)
		self.anim_step = (not state and 0 or nil)
	end
end

local _GetCurrentTick = sm.game.getCurrentTick
local anim_steps = {[1] = "", [2] = ".", [3] = "..", [4] = "..."}
function PermissionManagerGUI:client_GUI_UpdateWaitAnimation()
	if not self.wait_for_data then return end

	local cur_tick = _GetCurrentTick() % 16

	if cur_tick == 15 then
		self.anim_step = (self.anim_step + 1) % 4
		local cur_step = anim_steps[self.anim_step + 1]

		self.gui.interface:setText("WaitDataLabel", ("Waiting for Data%s"):format(cur_step))
	end
end

function PermissionManagerGUI:client_GUI_UpdateCurrentPage()
	local player_amount = #_GetAllPlayersEX()
	local gui = self.gui

	gui.interface:setText("CurPage", ("%s / %s"):format(gui.cur_page + 1, player_amount))
end

function PermissionManagerGUI:client_GUI_ResetInterface()
	self.gui.current_player = nil
	self.gui.cur_page = -1
	self.wait_for_data = nil
	self.anim_step = nil

	self:client_GUI_UpdateCurrentPage()

	self:client_GUI_SetWaitingState(false, true)
	self:client_GUI_SetSelectState(false)
end