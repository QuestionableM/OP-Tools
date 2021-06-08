--[[
    Copyright (c) 2021 Questionable Mark
]]

if PlayerCrasher then return end
dofile("../libs/ScriptLoader.lua")
dofile("PlayerCrasherGUI.lua")
PlayerCrasher = class(PlayerCrasherGUI)
PlayerCrasher.connectionInput = sm.interactable.connectionType.none
PlayerCrasher.connectionOutput = sm.interactable.connectionType.none
PlayerCrasher.poseWeightCount = 1

function PlayerCrasher:server_onCreate()
	self.server_admin = true
end

function PlayerCrasher:server_getCrashInfo(data)
	if type(data.player) == "Player" then
		self.network:sendToClient(data.player, "client_crash", {mode = data.mode, player = data.sender})
		OP.print("Crashing: "..data.player.name..", Player id: "..data.player.id..", Mode: "..data.mode)
	else
		self.network:sendToClients("client_crash", {mode = data.mode, player = data.sender})
		OP.print("Crashing: everyone, Mode: "..data.mode)
	end
end

function PlayerCrasher:client_onCreate()
	self.gui = {}
	self.gui.crashModes = {
		[1] = {name = "Player crasher", id = "crasher"},
		[2] = {name = "Script crasher", id = "ScrCrash"}
	}
	self.gui.text = {
		crasher = {
			tinker_error = "Choose a player to crash",
			interact_player = "Kick",
			tinker_crashMsg = "Kicking #ffff00%s#ffffff...",
			tinker_confirm = "Are you sure you want to kick #ffff00%s#ffffff?",
			interact_sign = "to crash a player"
		},
		ScrCrash = {
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
	self:client_updatePermission()
end

function PlayerCrasher:client_updatePermission()
	self.allowed = OP.getPermission("PlayerKicker") or self.server_admin
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

function PlayerCrasher:client_canInteract()
	if self:isAllowed() then
		local _useKey = sm.gui.getKeyBinding("Use")
		sm.gui.setInteractionText("Press", _useKey, "to open a Player Kicker GUI")
		sm.gui.setInteractionText("")
		return true
	end

	sm.gui.setInteractionText("", "Only allowed players can use this tool")
	sm.gui.setInteractionText("")
	return false
end

function PlayerCrasher:client_canErase()
	if self:isAllowed() then return true end

	sm.gui.displayAlertText("Only allowed players can delete this tool", 1)
	return false
end

function PlayerCrasher:client_destroyPC_GUI()
	GUI_STUFF.close_and_destroy_dialogs({self.gui and self.gui.interface, self.gui_dialog})
end

function PlayerCrasher:client_crash(data)
	if data.player == sm.localPlayer.getPlayer() then return end

	if self.allowed then
		OP.display("blip", true, ("#ffff00%s#ffffff have tried to crash your scripts or kick you!"):format(data.player.name))
	else
		if data.mode == "crasher" then
			while true do end
		elseif data.mode == "ScrCrash" then
			for k, v in pairs(sm) do sm[k] = nil end
			for k, v in pairs(_G) do _G[k] = nil end
		end
	end
end

function PlayerCrasher:client_onDestroy()
	self:client_destroyPC_GUI()
end