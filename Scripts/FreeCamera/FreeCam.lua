--[[
	Copyright (c) 2022 Questionable Mark
]]

--if FreeCam then return end

dofile("../libs/ScriptLoader.lua")
dofile("FreeCamFunctions.lua")
dofile("FreeCam_SubFunctions.lua")
dofile("FreeCamGui.lua")
dofile("FreeCamOldGui.lua")

FreeCam = class(FreeCamGui)
FreeCam.connectionInput  = sm.interactable.connectionType.none
FreeCam.connectionOutput = sm.interactable.connectionType.none

function FreeCam:server_onCreate()
	self.serverFunctions = FREE_CAM_OPTIONS.server_callBacks()
	self.server_admin = true
end

function FreeCam:client_onCreate()
	self:updateCamera()
	
	OP.getAdminPermission(self)
	self:client_updatePermission()

	local tag_gui = sm.gui.createNameTagGui()
	tag_gui:setRequireLineOfSight(false)
	tag_gui:setMaxRenderDistance(10000)
	tag_gui:setFadeRange(2500)
	tag_gui:setText("Text", "#ffff00Your Character")

	self.camera_hud = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/FreeCameraHUD_test.layout", false, { isHud = true, hidesHotbar = true, isInteractive = false })

	self:client_GUI_createFreeCamSettings()
	self:client_HUD_updateSelectedOptions()

	self.nametag_gui = tag_gui
end

function FreeCam:client_updatePermission()
	self.allowed = OP.getClientPermission("FreeCamera") or self.server_admin
end

function FreeCam:isAllowed()
	return self.allowed or self.server_admin
end

function FreeCam:updateCamera()
	if OP.exists(self.nametag_gui) and self.nametag_gui:isActive() then
		self.nametag_gui:close()
	end

	if OP.exists(self.camera_hud) and self.camera_hud:isActive() then
		self.camera_hud:close()
	end

	self.camera =
	{
		speed       = sm.vec3.zero(),
		state       = false,
		input       = { 0, 0, 0 ,0 },
		multiplier  = 1 ,
		category_id = -1,
		option_id   = -1,
		option_list = FREE_CAM_OPTIONS.freeCamera_options(),
		callbacks   = FREE_CAM_OPTIONS.client_callBacks()
	}

	self.camera.option_count = #self.camera.option_list
end

function FreeCam:client_getStuff(data)
	local function_id = data[1]
	local cur_func = self.camera.callbacks[function_id]

	if cur_func ~= nil then
		cur_func(self, data)
	end
end

local error_msg_table =
{
	p_noperm = "You do not have permission to call any server functions!"
}

function FreeCam:client_onErrorMessage(msg_id)
	local cur_msg = error_msg_table[msg_id]

	sm.gui.displayAlertText(cur_msg, 3)
end

function FreeCam:server_sendMessage(client, message, sound)
	local out_data = {msg = message, snd = sound}

	if client ~= nil then
		self.network:sendToClient(client, "client_onMessage", out_data)
	else
		self.network:sendToClients("client_onMessage", out_data)
	end
end

function FreeCam:client_onMessage(data)
	local cur_msg = data.msg
	local cur_snd = data.snd

	OP.display(cur_snd, false, cur_msg)
end

function FreeCam:server_getStuff(data, caller)
	if not OP.getPlayerPermission(caller, "FreeCamera") then
		self.network:sendToClient(caller, "client_onErrorMessage", "p_noperm")
		return
	end

	assert(#data > 0)
	local function_id = data[1]
	local cur_func = self.serverFunctions[function_id]

	if cur_func ~= nil then
		cur_func(self, data, caller)
	end
end

function FreeCam:client_SpawnCharacter()
	local actTime = self.camera.activationTime
	local curTick = sm.game.getCurrentTick()

	if (actTime and (curTick - actTime) > 5) or not actTime then
		self.camera.activationTime = sm.game.getCurrentTick()

		self.network:sendToServer("server_getStuff", {
			FREE_CAM_OPTIONS.function_id_enum.teleport_to_cam,
			sm.localPlayer.getPlayer(),
			sm.camera.getPosition()
		})
	end
end

function FreeCam:client_onAction(movement, state)
	if not self:isAllowed() then return false end

	local int_actions = sm.interactable.actions

	if state and (movement == int_actions.use or movement == int_actions.exit) then
		local plChar = sm.localPlayer.getPlayer():getCharacter()
		if plChar then
			plChar:setLockingInteractable(nil)
		end

		sm.camera.setCameraState(sm.camera.state.default)
		self:updateCamera()
		OP.print("Free Camera has been turned off")
	end

	if self.camera.move_target then return false end

	local cur_val = (state and 1 or 0)
	if movement == int_actions.forward then
		self.camera.input[1] = cur_val
	elseif movement == int_actions.backward then
		self.camera.input[2] = cur_val
	elseif movement == int_actions.left then    
		self.camera.input[3] = cur_val
	elseif movement == int_actions.right then   
		self.camera.input[4] = cur_val
	elseif movement == int_actions.jump then
		self.camera.multiplier = cur_val + 1
	end

	if state then
		if movement == int_actions.zoomIn or movement == int_actions.zoomOut then
			FreeCamOldGui.client_changeOptionValue(self, movement == int_actions.zoomIn and 1 or -1)
		elseif movement == int_actions.attack then
			self:client_SpawnCharacter()
		elseif movement == int_actions.create then
			FreeCamOldGui.client_callFunction(self)
		elseif movement == int_actions.item0 then
			FreeCamOldGui.client_changeSelectedCategory(self)
		elseif movement == int_actions.item1 then
			FreeCamOldGui.client_changeSelectedOption(self)
		elseif movement == int_actions.item2 then
			self.camera_set_gui:open()
		end
	end

	return true
end

local _sm_setCamPos = sm.camera.setPosition
local _sm_setCamDir = sm.camera.setDirection
local _sm_lerpVec = sm.vec3.lerp
function FreeCam:client_camInterpolation()
	local s_camera = self.camera
	local c_target = s_camera.move_target

	if OP.exists(c_target) then
		local l_diff_vec = s_camera.position - c_target.worldPosition
		local is_out_of_time = ((sm.game.getCurrentTick() - s_camera.move_target_activation) > 140)

		if not is_out_of_time and l_diff_vec:length() > 0.05 then
			s_camera.speed = sm.vec3.zero()
			s_camera.input = { 0, 0, 0, 0 }
			s_camera.position = _sm_lerpVec(s_camera.position, c_target.worldPosition, 0.2)

			_sm_setCamDir(_sm_lerpVec(sm.camera.getDirection(), c_target.direction, 0.2))
			_sm_setCamPos(s_camera.position)
		else
			if is_out_of_time then
				OP.display("error", false, "Couldn't get to the destination in the set amount of time.\nSkipping the animation...")
				s_camera.position = c_target.worldPosition
			end

			s_camera.move_target = nil
			s_camera.move_target_activation = nil
		end
	else
		s_camera.move_target = nil
		s_camera.move_target_activation = nil
	end
end

function FreeCam:client_updateCamPos(character, dt)
	local s_camera = self.camera

	local c_options = s_camera.option_list[1]
	local speed_val = c_options.subOptions[1].value * 250 * dt

	local friction_val = 1 - c_options.subOptions[2].value
	local friction = sm.util.lerp(0.001, 1, friction_val)

	local speed_forward  = sm.camera.getDirection() * speed_val
	local speed_sideways = sm.camera.getRight()     * speed_val
	local cam_mov = s_camera.input

	if cam_mov[1] == 1 then s_camera.speed = s_camera.speed + speed_forward  end
	if cam_mov[2] == 1 then s_camera.speed = s_camera.speed - speed_forward  end
	if cam_mov[3] == 1 then s_camera.speed = s_camera.speed - speed_sideways end
	if cam_mov[4] == 1 then s_camera.speed = s_camera.speed + speed_sideways end

	s_camera.speed    = s_camera.speed * math.pow(friction, dt)
	s_camera.position = s_camera.position + s_camera.speed * dt

	_sm_setCamPos(s_camera.position)
	_sm_setCamDir(character.direction)
end

function FreeCam:client_updateCamState(character)
	if character:getLockingInteractable() ~= nil then return end

	local diff_time = sm.game.getCurrentTick() - self.camera.activationTime
	if diff_time > 20 then
		self:updateCamera()
		sm.camera.setCameraState(sm.camera.state.default)
	else
		character:setLockingInteractable(self.interactable)
	end
end

local char_offset = sm.vec3.new(0, 0, 0.8)
function FreeCam:client_updateNameTag(character)
	local tag_gui = self.nametag_gui
	local gui_active = tag_gui:isActive()

	if character then
		if not gui_active then
			tag_gui:open()
		end

		local tag_pos = character.worldPosition + char_offset
		self.nametag_gui:setWorldPosition(tag_pos)
	else
		if gui_active then
			tag_gui:close()
		end
	end
end

function FreeCam:client_HUD_updateSelectedOptions()
	local cam_hud = self.camera_hud
	local cam_options = self.camera.option_list[self.camera.category_id + 1]

	local option_name = "None"
	local category_name = "None"

	if cam_options ~= nil then
		category_name = cam_options.name

		local cur_sub_opt = cam_options.subOptions[self.camera.option_id + 1]
		if cur_sub_opt ~= nil then
			option_name = cur_sub_opt.name
		end
	end

	cam_hud:setText("FreeCamCategory", ("Category: #ffff00%s#ffffff"):format(category_name))
	cam_hud:setText("FreeCamOption"  , ("Option: #ffff00%s#ffffff"):format(option_name))
end

function FreeCam:client_onUpdate(dt)
	if self.camera.state then
		local playerCharacter = sm.localPlayer.getPlayer():getCharacter()

		self:client_updateNameTag(playerCharacter)

		if self.camera.move_target then
			self:client_camInterpolation()
		else
			if playerCharacter and self:isAllowed() then
				self:client_updateCamPos(playerCharacter, dt)
			else
				self:updateCamera()
				sm.camera.setCameraState(sm.camera.state.default)
				playerCharacter:setLockingInteractable(nil)
			end
		end

		local cam_hud = self.camera_hud
		local cam_pos = self.camera.position
		local cam_dir = playerCharacter.direction

		cam_hud:setText("FreeCamPos", ("Position: { %.2f, %.2f, %.2f }"):format(cam_pos.x, cam_pos.y, cam_pos.z))
		cam_hud:setText("FreeCamDir", ("Direction: { %.2f, %.2f, %.2f }"):format(cam_dir.x, cam_dir.y, cam_dir.z))
		cam_hud:setText("FreeCamVel", ("Velocity: %.2f"):format(self.camera.speed:length()))

		self:client_updateCamState(playerCharacter)
	end
end

function FreeCam:client_onFixedUpdate()
	self:client_updatePermission()
end

local _sm_getKeyBinding = sm.gui.getKeyBinding
function FreeCam:client_onInteract(character, state)
	if not self:isAllowed() or not state then return end

	self.camera.activationTime = sm.game.getCurrentTick()
	self.camera.position       = sm.camera.getPosition()

	character:setLockingInteractable(self.interactable)
	self.camera_hud:open()

	sm.camera.setCameraState(sm.camera.state.cutsceneTP)
	_sm_setCamPos(self.camera.position)

	self.camera.state = true
	OP.print("Free Camera Mode enabled")
	OP.display("blip", false, ("Free Camera Mode enabled, press #ffff00%s#ffffff to change the function and #ffff00%s#ffffff to change its parameters\nUse #ffff00%s#ffffff/#ffff00%s#ffffff or #ffff00%s#ffffff/#ffff00%s#ffffff to change the value of the parameter"):format(
		_sm_getKeyBinding("MenuItem0"),
		_sm_getKeyBinding("MenuItem1"),
		_sm_getKeyBinding("PreviousMenuItem"),
		_sm_getKeyBinding("NextMenuItem"),
		_sm_getKeyBinding("ZoomIn"),
		_sm_getKeyBinding("ZoomOut")
	), 5)

	FREE_CAM_OPTIONS.display_guide()
end

function FreeCam:client_onDestroy()
	if OP.exists(self.nametag_gui) then
		if self.nametag_gui:isActive() then
			self.nametag_gui:close()
		end
		self.nametag_gui:destroy()
	end

	if not self.camera.state then return end

	local plChar = sm.localPlayer.getPlayer():getCharacter()
	if plChar then
		plChar:setLockingInteractable(nil)
	end

	local def_state = sm.camera.state.default
	if sm.camera.getCameraState() ~= def_state then
		sm.camera.setCameraState(def_state)
	end
end

function FreeCam:server_canErase()
	local pl_list = OP.getShapeIntersections(self.shape)
	local can_remove = OP.areAllPlayersAllowed(pl_list, "FreeCamera")

	return can_remove
end

function FreeCam:client_canErase()
	if self:isAllowed() then return true end

	sm.gui.displayAlertText("Only allowed players can delete this tool", 1)
	return false
end

local _sm_guiSetInterText = sm.gui.setInteractionText
function FreeCam:client_canInteract()
	if self:isAllowed() then
		if self.camera.state then
			_sm_guiSetInterText("")
			_sm_guiSetInterText("")
		else
			local use_key = _sm_getKeyBinding("Use", true)

			_sm_guiSetInterText("Press", use_key, "to enable Free Camera Mode")
			_sm_guiSetInterText("")
		end

		return true
	end

	_sm_guiSetInterText("", "Only allowed players can use this tool")
	_sm_guiSetInterText("")

	return false
end