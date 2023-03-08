--[[
	Copyright (c) 2023 Questionable Mark
]]

if FreeCam then return end

dofile("../libs/ScriptLoader.lua")
dofile("FreeCamFunctions.lua")
dofile("FreeCam_SubFunctions.lua")
dofile("FreeCamGui.lua")
dofile("FreeCamOldGui.lua")

---@class CameraDataClass
---@field speed Vec3
---@field state boolean
---@field input integer[]
---@field multiplier integer
---@field category_id integer
---@field option_id integer
---@field option_list table
---@field callbacks table
---@field activationTime integer
---@field move_target Character
---@field position Vec3
---@field option_count integer
---@field charToTeleport Character

---@class FreeCamClass : ShapeClass
---@field camera CameraDataClass
---@field camera_hud GuiInterface
---@field camera_set_gui GuiInterface
---@field client_GUI_createFreeCamSettings function
---@field client_GUI_openGui function
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

	self.camera_hud = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/FreeCameraHUD.layout", false, { isHud = true, hidesHotbar = true, isInteractive = false })

	self:client_GUI_createFreeCamSettings()
	self:client_HUD_updateSelectedOptions()
end

function FreeCam:client_updatePermission()
	self.allowed = OP.getClientPermission("FreeCamera") or self.server_admin
end

function FreeCam:isAllowed()
	return self.allowed or self.server_admin
end

function FreeCam:updateCamera()
	local s_cam = self.camera
	if s_cam and s_cam.state then
		local loc_pl = sm.localPlayer.getPlayer()
		local pl_char = loc_pl.character
		if OP.exists(pl_char) then
			pl_char:setNameTag("")
		end
	end

	if OP.exists(self.camera_hud) and self.camera_hud:isActive() then
		self.camera_hud:close()
	end

	if OP.exists(self.camera_set_gui) and self.camera_set_gui:isActive() then
		self.camera_set_gui:close()
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

local client_char_prop_names =
{
	[1] = "Set Tumble",
	[2] = "Set Downed",
	[3] = "Set Swimming",
	[4] = "Set Diving"
}

local client_message_ids =
{
	[1]  = {msg = "You do not have permission to call any server functions!", sound = "error"},
	[2]  = function(data) OP.display("blip", false, ("#ffff00%s#ffffff has been teleported"):format(data[2].name)) end,
	[3]  = function(data) OP.display("blip", false, ("Character (id: #ffff00%s#ffffff) has been teleported"):format(data[2])) end,
	[4]  = function(data) OP.display("blip", false, ("#ffff00Time#ffffff set to #ffff00%.2f#ffffff for everyone"):format(data[2])) end,
	[5]  = function(data) OP.display("blip", false, ("#ffff00%s#ffffff players got their characters back"):format(data[2])) end,
	[6]  = {msg = "You can't lock controls for server admin!"      , sound = "error"},
	[7]  = {msg = "You can't lock controls for your own character!", sound = "error"},
	[8]  = function(data) OP.display("blip", false, ("#ffff00%s#ffffff players were rescued from outside the world"):format(data[2])) end,
	[9]  = function(data) OP.display("blip", false, ("Set the speed to #ffff00%s#ffffff for a character [id: #ffff00%s#ffffff]"):format(data[2], data[3])) end,
	[10] = function(data)
		local type_id = data[2]
		local bool_data = data[3]
		local char_id = data[4]

		local cur_prop_name = client_char_prop_names[type_id]
		local bool_string = OP.bools[bool_data].string

		OP.display("blip", false, ("#ffff00%s#ffffff is %s for character [id: #ffff00%s#ffffff]"):format(cur_prop_name, bool_string, char_id))
	end
}

function FreeCam:server_sendMsg(caller, data)
	self.network:sendToClient(caller, "client_onMessage", data)
end

function FreeCam:client_onMessage(data)
	local l_msg_id = data[1]
	local l_msg_data = client_message_ids[l_msg_id]
	if type(l_msg_data) == "function" then
		l_msg_data(data)
	else
		OP.display(l_msg_data.sound, false, l_msg_data.msg)
	end
end

function FreeCam:server_getStuff(data, caller)
	if not OP.getPlayerPermission(caller, "FreeCamera") then
		self.network:sendToClient(caller, "client_onMessage", { 1 })
		return
	end

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
			self:client_GUI_openGui()
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

local _sm_camera_setFov = sm.camera.setFov
local _sm_camera_getDirection = sm.camera.getDirection
local _sm_camera_getRight = sm.camera.getRight
function FreeCam:client_updateCamPos(character, dt)
	local s_camera = self.camera

	local sub_opt = s_camera.option_list[1].subOptions

	local fov_val = sub_opt[3].value
	s_camera.fov_value = sm.util.lerp(s_camera.fov_value, fov_val, dt * 7.5)
	_sm_camera_setFov(s_camera.fov_value)

	local speed_val = sub_opt[1].value * 250 * dt
	local speed_forward  = _sm_camera_getDirection() * speed_val
	local speed_sideways = _sm_camera_getRight()     * speed_val

	local cam_mov = s_camera.input
	if cam_mov[1] == 1 then s_camera.speed = s_camera.speed + speed_forward  end
	if cam_mov[2] == 1 then s_camera.speed = s_camera.speed - speed_forward  end
	if cam_mov[3] == 1 then s_camera.speed = s_camera.speed - speed_sideways end
	if cam_mov[4] == 1 then s_camera.speed = s_camera.speed + speed_sideways end

	local friction_val = 1 - sub_opt[2].value
	local friction = sm.util.lerp(0.001, 1, friction_val)

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

function FreeCam:client_onInteract(character, state)
	if not self:isAllowed() or not state then return end

	local s_camera = self.camera

	local cur_fov = sm.camera.getFov()
	s_camera.fov_value      = cur_fov
	s_camera.activationTime = sm.game.getCurrentTick()
	s_camera.position       = sm.camera.getPosition()
	s_camera.state          = true

	local sub_opt_one = s_camera.option_list[1].subOptions
	sub_opt_one[6].value   = OP.enable_free_cam_data
	sub_opt_one[3].value   = cur_fov
	sub_opt_one[3].default = cur_fov

	character:setNameTag("Your Character", sm.color.new(0xffff00ff))

	self.camera_hud:setVisible("CamDataBP", OP.enable_free_cam_data)
	self.camera_hud:open()

	character:setLockingInteractable(self.interactable)
	sm.camera.setCameraState(sm.camera.state.cutsceneTP)
	_sm_setCamPos(s_camera.position)

	FreeCamOldGui.client_displayStartInfo()
end

function FreeCam:client_onDestroy()
	GUI_STUFF.close_and_destroy_dialogs({ self.camera_hud, self.camera_set_gui })

	if self.camera.state then
		local pl_char = sm.localPlayer.getPlayer():getCharacter()
		if OP.exists(pl_char) then
			pl_char:setLockingInteractable(nil)
			pl_char:setNameTag("")
		end

		local def_state = sm.camera.state.default
		if sm.camera.getCameraState() ~= def_state then
			sm.camera.setCameraState(def_state)
		end
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
local _sm_getKeyBinding = sm.gui.getKeyBinding
local cam_interact_error = OP.getHypertext("Only allowed players can use this tool")
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

	_sm_guiSetInterText(cam_interact_error)
	_sm_guiSetInterText("")

	return false
end