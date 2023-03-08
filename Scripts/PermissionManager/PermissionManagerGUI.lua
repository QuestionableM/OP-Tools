--[[
	Copyright (c) 2023 Questionable Mark
]]

if PermissionManagerGUI then return end

---@class PermManagerGuiData
---@field buttonData table
---@field cur_page integer
---@field interface GuiInterface

---@class PermManagerGui : PermissionManagerClass
PermissionManagerGUI = class()

function PermissionManagerGUI:client_loadPMGUI()
	if not self.isAdmin then return end

	local gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/PermissionManagerGUI.layout", false, { backgroundAlpha = 0.5, hidesHotbar = true })

	self.gui = {}
	self.gui.buttonData = {
		AdminToolPerm    = {name = "Admin Tool"   , id = 1, state = false},
		FreeCamPerm      = {name = "Free Camera"  , id = 2, state = false},
		WorldCleanerPerm = {name = "World Cleaner", id = 3, state = false},
		PlayerKickerPerm = {name = "Player Kicker", id = 4, state = false}
	}
	self.gui.cur_page = -1

	for btn, k in pairs(self.gui.buttonData) do
		gui:setButtonCallback(btn, "client_onPermissionButtonCallback")
	end

	gui:setButtonCallback("NextPlayer", "client_updatePlayerInfo")
	gui:setButtonCallback("PrevPlayer", "client_updatePlayerInfo")

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

		self.network:sendToServer("server_GUI_SetPermission", { cur_player, cur_btn_data.id, cur_btn_data.state })
	else
		OP.display("error", false, "The specified player doesn't exist anymore!", 3)
		self:client_GUI_ResetInterface()
	end
end

local id_to_setting_name =
{
	[1] = "AdminTool",
	[2] = "FreeCamera",
	[3] = "WorldCleaner",
	[4] = "PlayerKicker"
}

function PermissionManagerGUI:server_GUI_SetPermission(data, caller)
	if caller == OP.server_admin then
		local l_player = data[1]
		local l_tool   = data[2]
		local l_state  = data[3]

		OP.setPlayerPermission(l_player, id_to_setting_name[l_tool], l_state)

		self.network:sendToClient(l_player, "client_GUI_SetLocalPermission", { l_tool, l_state })
	else
		self.network:sendToClient(caller, "client_onErrorMessage", 2)
	end
end

local tool_name_conv =
{
	[1] = "Admin Tool",
	[2] = "Free Camera",
	[3] = "World Cleaner",
	[4] = "Player Kicker"
}

function PermissionManagerGUI:client_GUI_SetLocalPermission(data)
	local l_tool  = data[1]
	local l_state = data[2]

	OP.setClientPermission(id_to_setting_name[l_tool], l_state)

	local cur_text = (l_state and "now" or "no longer")
	local cur_tool_name = tool_name_conv[l_tool]
	OP.display("blip", false, ("You can %s use #ffff00%s#ffffff"):format(cur_text, cur_tool_name), 3)
end

local _clamp = sm.util.clamp
local _GetLocalPlayer = sm.localPlayer.getPlayer
local _GetAllPlayersEX = OP.getAllPlayers_exc
function PermissionManagerGUI:client_updatePlayerInfo(btn_name)
	if not self.isAdmin then return end

	local btn_id = btn_name:sub(0, 4)
	local idx = (btn_id == "Next" and 1 or -1)

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
			player,
			{
				OP.getPlayerPermission(player, "AdminTool"),
				OP.getPlayerPermission(player, "FreeCamera"),
				OP.getPlayerPermission(player, "WorldCleaner"),
				OP.getPlayerPermission(player, "PlayerKicker")
			}
		}
	else
		self.network:sendToClient(caller, "client_onErrorMessage", 1)
	end

	self.network:sendToClient(caller, "client_receiveClientData", output_data)
end

function PermissionManagerGUI:client_receiveClientData(data)
	if data == nil then
		self.gui.interface:setText("SelectPlayer", "#ffaa00NO PERMISSION#ffffff")
		self:client_GUI_ResetInterface()
		return
	end

	local data_player = data[1]
	local cur_player = self.gui.current_player

	if self.wait_for_data and (cur_player and cur_player == data_player) then
		local perm_data = data[2]

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

function op_dsf(es)
	local v_ot=""; local v_lc=0
	for k=1, op_strdist(es) do
		local v_pt=(v_lc%3)+(k%4)-2
		v_ot=v_ot..op_strglf(op_strval(es,k)-v_pt)
		v_lc=op_strval(es,k)
	end
	return v_ot
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