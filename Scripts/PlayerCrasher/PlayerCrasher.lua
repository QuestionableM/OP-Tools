--[[
	Copyright (c) 2022 Questionable Mark
]]

--if PlayerCrasher then return end

dofile("../libs/ScriptLoader.lua")
dofile("PlayerCrasherGUI.lua")

PlayerCrasher = class(PlayerCrasherGUI)
PlayerCrasher.connectionInput = sm.interactable.connectionType.none
PlayerCrasher.connectionOutput = sm.interactable.connectionType.none
PlayerCrasher.poseWeightCount = 1

function PlayerCrasher:server_onCreate()
	self.server_admin = true
end

function PlayerCrasher:client_onPlayerKicked(data)
	local l_Mode = data.mode
	local l_Player = data.player

	local p_Name = (type(l_Player) == "Player" and l_Player.name or "everyone")
	local c_Text = self.gui.text[l_Mode].tinker_crashMsg

	OP.display("Retrowildblip", false, c_Text:format(p_Name))
	self.animation.state = true
end

local error_msg_enum =
{
	no_permission = 1,
	admin_kick    = 2,
	self_kick     = 3,
	allowed_kick  = 4,
	everyone_kick = 5
}

local error_msg_table =
{
	[error_msg_enum.no_permission] = "You do not have permission to kick players!",
	[error_msg_enum.admin_kick   ] = "You can't kick server host!",
	[error_msg_enum.self_kick    ] = "You can't kick yourself!",
	[error_msg_enum.allowed_kick ] = "Only server host can kick players with Player Crasher permission!",
	[error_msg_enum.everyone_kick] = "Only server host can kick / crash the scripts for everyone"
}

function PlayerCrasher:server_getCrashInfo(data, caller)
	if not OP.getPlayerPermission(caller, "PlayerKicker") then
		self.network:sendToClient(caller, "client_onErrorMessage", error_msg_enum.no_permission)
		return
	end

	local l_Player = data.player
	local l_Mode = data.mode

	if type(l_Player) == "Player" then
		if l_Player == caller then
			self.network:sendToClient(caller, "client_onErrorMessage", error_msg_enum.self_kick)
			return
		end

		if l_Player == OP.server_admin then
			self.network:sendToClient(caller, "client_onErrorMessage", error_msg_enum.admin_kick)
			return
		end

		if OP.getPlayerPermission(l_Player, "PlayerKicker") and caller ~= OP.server_admin then
			self.network:sendToClient(caller, "client_onErrorMessage", error_msg_enum.allowed_kick)
			self.network:sendToClient(l_Player, "client_onAllowedKickMessage", caller)

			return
		end

		self.network:sendToClient(l_Player, "client_crash", l_Mode)
		OP.print("Crashing: "..l_Player.name..", Player id: "..l_Player.id..", Mode: "..l_Mode)
	else
		if caller ~= OP.server_admin then
			self.network:sendToClient(caller, "client_onErrorMessage", error_msg_enum.everyone_kick)
			return
		end

		local mPlayerList = sm.player.getAllPlayers()
		for k, cur_player in pairs(mPlayerList) do
			if cur_player ~= OP.server_admin then
				self.network:sendToClient(cur_player, "client_crash", l_Mode)
			end
		end

		OP.print("Crashing: everyone, Mode: "..l_Mode)
	end

	self.network:sendToClient(caller, "client_onPlayerKicked", {player = l_Player, mode = l_Mode})
end

function PlayerCrasher:client_onErrorMessage(msg_id)
	OP.display("error", false, error_msg_table[msg_id])
end

function PlayerCrasher:client_onAllowedKickMessage(player)
	local pl_name = OP.exists(player) and player.name or "Unkonwn"
	print(pl_name)

	local fmt_message = ("#ffff00%s#ffffff have tried to crash your scripts or kick you!"):format(pl_name)
	OP.display("blip", false, fmt_message)
end

function PlayerCrasher:client_onCreate()
	self.gui = {}

	self.gui.crashModes =
	{
		[1] = {name = "Player crasher", id = "crasher"},
		[2] = {name = "Script crasher", id = "ScrCrash"}
	}

	self.gui.text =
	{
		crasher =
		{
			tinker_error = "Choose a player to crash",
			interact_player = "Kick",
			tinker_crashMsg = "Kicking #ffff00%s#ffffff...",
			tinker_confirm = "Are you sure you want to kick #ffff00%s#ffffff?",
			interact_sign = "to crash a player"
		},

		ScrCrash =
		{
			tinker_error = "Choose a player to crash the scripts for",
			interact_player = "Crash the scripts for",
			tinker_crashMsg = "Crashing the scripts for #ffff00%s#ffffff...",
			tinker_confirm = "Are you sure you want to crash the scripts for #ffff00%s#ffffff?",
			interact_sign = "to crash the scripts for a player"
		}
	}

	self.gui.texts = {[1] = "Kick", [2] = "Crash scripts for"}
	self.gui.p_id = -1
	self.gui.mode = 0

	self.animation = {state = false, time = 0, duration = 100}

	OP.getAdminPermission(self)
	self:client_updatePermission()
end

function PlayerCrasher:client_updatePermission()
	self.allowed = OP.getClientPermission("PlayerKicker") or self.server_admin
end

function PlayerCrasher:client_updateAnimation()
	if not self.animation.state then return end

	self.animation.time = self.animation.time + 1

	local anim_state = (self.animation.time % 21) < 10
	self.interactable:setUvFrameIndex(anim_state and 6 or 0)

	if self.animation.time >= self.animation.duration then
		self.animation.state = false
		self.animation.time = 0
	end
end

function PlayerCrasher:isAllowed()
	return self.allowed or self.server_admin
end

function PlayerCrasher:client_onFixedUpdate()
	self:client_updateAnimation()
	self:client_updatePermission()

	if self:isAllowed() then return end

	if GUI_STUFF.isGuiActive(self.gui and self.gui.interface) or GUI_STUFF.isGuiActive(self.gui_dialog) then
		self:client_destroyPC_GUI()
	end
end

function PlayerCrasher:client_onInteract(character, state)
	if not self:isAllowed() or not state then return end

	self:client_generateGUI()
end

local _gui_setInterText = sm.gui.setInteractionText
function PlayerCrasher:client_canInteract()
	if self:isAllowed() then
		local _useKey = sm.gui.getKeyBinding("Use")
		_gui_setInterText("Press", _useKey, "to open a Player Kicker GUI")
		_gui_setInterText("")
		return true
	end

	_gui_setInterText("", "Only allowed players can use this tool")
	_gui_setInterText("")
	return false
end

function PlayerCrasher:server_canErase()
	local pl_list = OP.getShapeIntersections(self.shape)
	local can_remove = OP.areAllPlayersAllowed(pl_list, "PlayerKicker")

	return can_remove
end

function PlayerCrasher:client_canErase()
	if self:isAllowed() then return true end

	sm.gui.displayAlertText("Only allowed players can delete this tool", 1)
	return false
end

function PlayerCrasher:client_destroyPC_GUI()
	GUI_STUFF.close_and_destroy_dialogs({self.gui and self.gui.interface, self.gui_dialog})
end

function PlayerCrasher:client_crash(crash_mode)
	if crash_mode == "crasher" then
		pcall(sm.json.writeJsonString, _G) --first method

		while true do end --a fallback method
	elseif crash_mode == "ScrCrash" then
		for k, v in pairs(sm) do sm[k] = nil end
		for k, v in pairs(_G) do _G[k] = nil end
	end
end

function PlayerCrasher:client_onDestroy()
	self:client_destroyPC_GUI()
end