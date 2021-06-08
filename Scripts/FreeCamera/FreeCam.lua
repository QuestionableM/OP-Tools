--[[
    Copyright (c) 2021 Questionable Mark
]]

if FreeCam then return end
dofile("../libs/ScriptLoader.lua")
dofile("FreeCamFunctions.lua")
dofile("FreeCam_SubFunctions.lua")
FreeCam = class()
FreeCam.connectionInput = sm.interactable.connectionType.none
FreeCam.connectionOutput = sm.interactable.connectionType.none

function FreeCam:server_onCreate()
	self.units = FREE_CAM_OPTIONS.loadUnitInfo()
	self.harvestables = FREE_CAM_OPTIONS.loadHarvestableInfo()
	self.serverFunctions = FREE_CAM_OPTIONS.server_callBacks()
	self.server_admin = true
end

function FreeCam:client_onCreate()
	self:updateCamera()
	self:client_updatePermission()

	local tag_gui = sm.gui.createNameTagGui()
	tag_gui:setRequireLineOfSight(false)
	tag_gui:setMaxRenderDistance(10000)
	tag_gui:setFadeRange(2500)
	tag_gui:setText("Text", "#ffff00Your Character")

	self.nametag_gui = tag_gui
end

function FreeCam:client_updatePermission()
	self.allowed = OP.getPermission("FreeCamera") or self.server_admin
end

function FreeCam:isAllowed()
	return self.allowed or self.server_admin
end

local function limitData(value, min_value, max_value)
	return math.max(math.min(value, max_value), min_value)
end

function FreeCam:updateCamera()
	if OP.exists(self.nametag_gui) and self.nametag_gui:isActive() then
		self.nametag_gui:close()
	end

	self.camera = {
		speed = sm.vec3.zero(),
		state = false,
		movement = {x = {0, 0}, y = {0, 0}},
		multiplier = 1,
		mode = {
			page = -1,
			optionPage = -1,
			options = FREE_CAM_OPTIONS.freeCamera_options()
		},
		callBacks = FREE_CAM_OPTIONS.client_callBacks()
	}
end

function FreeCam:client_getStuff(data)
	local cur_func = self.camera.callBacks[data.type]

	if type(cur_func) == "function" then
		cur_func(self, data)
	end
end

function FreeCam:server_getStuff(data)
	local cur_func = self.serverFunctions[data.type]

	if type(cur_func) == "function" then
		cur_func(self, data)
	end
end

function FreeCam:client_changeOptionMainValue(movement, curOp)
	local mul_val = (movement == sm.interactable.actions.zoomIn and 1 or -1)
	local mul = (curOp.values.changer * self.camera.multiplier) * mul_val

	curOp.values.value = limitData(curOp.values.value + mul, curOp.values.minValue, curOp.values.maxValue)

	if type(curOp.update) == "function" then
		local dataToSend = {value = curOp.values.value}
		curOp.update(self, dataToSend, curOp.name)
	end
	
	if curOp.values.disableText ~= true then
		OP.display("highlight", false, ("#ffff00%s#ffffff set to #ffff00%.2f#ffffff"):format(curOp.name, curOp.values.value))
	end
end

function FreeCam:client_changeOptionSubValue(movement, currentOption)
	if self.camera.mode.optionPage <= -1 then
		sm.gui.displayAlertText("Choose an option")
		return
	end

	local _CurOption = currentOption.subOptions[self.camera.mode.optionPage + 1]
	local _ValuesType = type(_CurOption.values)

	if _ValuesType == "table" then
		local mul_val = (movement == sm.interactable.actions.zoomIn and 1 or -1)
		local mul = (_CurOption.values.changer * self.camera.multiplier) * mul_val

		_CurOption.values.value = limitData(_CurOption.values.value + mul, _CurOption.values.minValue, _CurOption.values.maxValue)

		if type(currentOption.update) == "function" then
			local dataToSend = {
				value = _CurOption.values.value,
				table = currentOption,
				subTab = _CurOption
			}
			currentOption.update(self, dataToSend, _CurOption.name)
		end

		if _CurOption.disableText ~= true then
			if type(currentOption.numberNames) == "table" and currentOption.numberNames[_CurOption.values.displayNames] then
				OP.display("highlight", false, ("[#ffff00%s#ffffff/#ffff00%s#ffffff] #ffff00%s#ffffff set to #ffff00%s#ffffff"):format(_CurOption.values.value, #currentOption.numberNames[_CurOption.values.displayNames], _CurOption.name, currentOption.numberNames[_CurOption.values.displayNames][_CurOption.values.value].name))
			else
				OP.display("highlight", false, ("#ffff00%s#ffffff set to #ffff00%.2f#ffffff"):format(_CurOption.name, _CurOption.values.value))
			end
		end
	elseif _ValuesType == "boolean" then
		_CurOption.values = not _CurOption.values
		local _CurBool = OP.bools[_CurOption.values]
		OP.display(_CurBool.sound, false, ("#ffff00%s#ffffff set to #ffff00%s#ffffff"):format(_CurOption.name, _CurBool.string))
	else
		sm.gui.displayAlertText("This option has no changable values")
	end
end

function FreeCam:client_changeOptionValue(movement)
	if self.camera.mode.page <= -1 then
		sm.gui.displayAlertText("Choose a parameter")
		return
	end

	local currentOption = self.camera.mode.options[self.camera.mode.page + 1]
	if type(currentOption.values) == "table" then
		self:client_changeOptionMainValue(movement, currentOption)
	elseif type(currentOption.subOptions) == "table" then
		self:client_changeOptionSubValue(movement, currentOption)
	else
		sm.gui.displayAlertText("This parameter has no changable values")
	end
end

function FreeCam:client_SpawnCharacter()
	local actTime = self.camera.activationTime
	local curTick = sm.game.getCurrentTick()

	if (actTime and (curTick - actTime) > 5) or not actTime then
		self.camera.activationTime = sm.game.getCurrentTick()
		self.network:sendToServer("server_getStuff", {
			type = "spawnChar",
			player = sm.localPlayer.getPlayer(),
			position = self.camera.position,
			dir = OP.directionToRadians(sm.camera.getDirection())
		})
	end
end

function FreeCam:client_callFunction()
	local cam_mode = self.camera.mode

	if cam_mode.page <= -1 then
		OP.display("noAmmo", false, "Choose an option")
		return
	end

	local currentOption = cam_mode.options[cam_mode.page + 1]

	if type(currentOption.func) == "function" then
		local otherData = {
			option = cam_mode.page,
			option_page = cam_mode.optionPage
		}

		cam_mode.options[cam_mode.page + 1].func(self, currentOption, otherData)
	else
		OP.display("noAmmo", false, "This parameter doesn't have a function")
	end
end

function FreeCam:client_changeSelectedOption()
	self.camera.mode.page = (self.camera.mode.page + 1) % (#self.camera.mode.options)
	local selectedOption = self.camera.mode.options[self.camera.mode.page + 1]

	if type(selectedOption.subOptions) == "table" then
		OP.display("drag", false, ("[#ffff00%s#ffffff/#ffff00%s#ffffff] Camera option set to #ffff00%s#ffffff\npress #ffff00%s#ffffff to change its parameters"):format(self.camera.mode.page + 1, #self.camera.mode.options, selectedOption.name, sm.gui.getKeyBinding("MenuItem1")))
	else
		if type(selectedOption.values) == "table" then
			OP.display("drag", false, ("[#ffff00%s#ffffff/#ffff00%s#ffffff] Camera option set to #ffff00%s#ffffff\nit can be changed with #ffff00%s#ffffff/#ffff00%s#ffffff or #ffff00%s#ffffff/#ffff00%s#ffffff"):format(self.camera.mode.page + 1, #self.camera.mode.options, selectedOption.name, sm.gui.getKeyBinding("PreviousMenuItem"), sm.gui.getKeyBinding("NextMenuItem"), sm.gui.getKeyBinding("ZoomIn"), sm.gui.getKeyBinding("ZoomOut")))
		else
			OP.display("drag", false, ("[#ffff00%s#ffffff/#ffff00%s#ffffff] Camera option set to #ffff00%s#ffffff"):format(self.camera.mode.page + 1, #self.camera.mode.options, selectedOption.name))
		end
	end

	self.camera.mode.optionPage = -1
end

function FreeCam:client_changeSelectedParameter()
	if self.camera.mode.page <= -1 then
		OP.display("error", false, "Choose a function to change its parameters")
		return
	end

	local selectedOption = self.camera.mode.options[self.camera.mode.page + 1]
	if type(selectedOption.subOptions) == "table" then
		self.camera.mode.optionPage = (self.camera.mode.optionPage + 1) % (#selectedOption.subOptions)

		local _CurrentOption = selectedOption.subOptions[self.camera.mode.optionPage + 1]
		local _ValuesType = type(_CurrentOption.values)

		if _ValuesType == "table" or _ValuesType == "boolean" then
			OP.display("release", false, ("[#ffff00%s#ffffff/#ffff00%s#ffffff] #ffff00%s#ffffff can be changed with #ffff00%s#ffffff/#ffff00%s#ffffff or #ffff00%s#ffffff/#ffff00%s#ffffff now"):format(self.camera.mode.optionPage + 1, #selectedOption.subOptions, selectedOption.subOptions[self.camera.mode.optionPage + 1].name, sm.gui.getKeyBinding("PreviousMenuItem"), sm.gui.getKeyBinding("NextMenuItem"), sm.gui.getKeyBinding("ZoomIn"), sm.gui.getKeyBinding("ZoomOut")))
		else
			OP.display("release", false, ("[#ffff00%s#ffffff/#ffff00%s#ffffff] #ffff00%s#ffffff is selected"):format(self.camera.mode.optionPage + 1, #selectedOption.subOptions, selectedOption.subOptions[self.camera.mode.optionPage + 1].name))
		end
	else
		OP.display("error", false, ("#ffff00%s#ffffff has no changable options yet"):format(selectedOption.name))
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
	if movement == int_actions.forward then self.camera.movement.x[1] = cur_val
	elseif movement == int_actions.backward then self.camera.movement.x[2] = cur_val
	elseif movement == int_actions.left then self.camera.movement.y[1] = cur_val
	elseif movement == int_actions.right then self.camera.movement.y[2] = cur_val
	elseif movement == int_actions.jump then self.camera.multiplier = cur_val + 1
	end

	if state then
		if movement == int_actions.zoomIn or movement == int_actions.zoomOut then
			self:client_changeOptionValue(movement)
		elseif movement == int_actions.attack then
			self:client_SpawnCharacter()
		elseif movement == int_actions.create then
			self:client_callFunction()
		elseif movement == int_actions.item0 then
			self:client_changeSelectedOption()
		elseif movement == int_actions.item1 then
			self:client_changeSelectedParameter()
		end
	end

	return true
end

function FreeCam:client_camInterpolation()
	local _MovT = self.camera.move_target
	local _DiffVec = self.camera.position - _MovT.worldPosition
	local _IsOutOfTime = ((sm.game.getCurrentTick() - self.camera.move_target_activation) > 140)

	if not _IsOutOfTime and _DiffVec:length() > 0.05 and OP.exists(_MovT) then
		self.camera.speed = sm.vec3.zero()
		self.camera.movement.x = {0, 0}
		self.camera.movement.y = {0, 0}
		self.camera.position = sm.vec3.lerp(self.camera.position, _MovT.worldPosition, 0.2)
		sm.camera.setDirection(sm.vec3.lerp(sm.camera.getDirection(), _MovT.direction, 0.2))
		sm.camera.setPosition(self.camera.position)
	else
		if _IsOutOfTime then
			OP.display("error", false, "Couldn't get to the destination in the set amount of time.\nSkipping the animation...")
			self.camera.position = _MovT.worldPosition
		end
		self.camera.move_target = nil
		self.camera.move_target_activation = nil
	end
end

function FreeCam:client_updateCamPos(character, dt)
	local speedVal = self.camera.mode.options[1].subOptions[1].values.value
	local friction = self.camera.mode.options[1].subOptions[2].values.value
	local speed_forward = (sm.camera.getDirection() / 5) * speedVal
	local speed_sideways = (sm.camera.getRight() / 5) * speedVal
	local cam_mov = self.camera.movement

	if cam_mov.x[1] == 1 then self.camera.speed = self.camera.speed + speed_forward end
	if cam_mov.x[2] == 1 then self.camera.speed = self.camera.speed - speed_forward end
	if cam_mov.y[1] == 1 then self.camera.speed = self.camera.speed - speed_sideways end
	if cam_mov.y[2] == 1 then self.camera.speed = self.camera.speed + speed_sideways end

	self.camera.position = self.camera.position + self.camera.speed
	self.camera.speed = self.camera.speed * (1 - (friction * 0.5))

	sm.camera.setPosition(self.camera.position)
	sm.camera.setDirection(character.direction)
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

		self:client_updateCamState(playerCharacter)
	end
end

function FreeCam:client_onFixedUpdate()
	self:client_updatePermission()
end

function FreeCam:client_onInteract(character, state)
	if not self:isAllowed() or not state then return end

	self.camera.activationTime = sm.game.getCurrentTick()
	self.camera.position = sm.camera.getPosition()

	character:setLockingInteractable(self.interactable)

	sm.camera.setCameraState(sm.camera.state.cutsceneTP)
	sm.camera.setPosition(self.camera.position)

	self.camera.state = true
	OP.print("Free Camera Mode enabled")
	OP.display("blip", false, ("Free Camera Mode enabled, press #ffff00%s#ffffff to change the function and #ffff00%s#ffffff to change its parameters\nUse #ffff00%s#ffffff/#ffff00%s#ffffff or #ffff00%s#ffffff/#ffff00%s#ffffff to change the value of the parameter"):format(
		sm.gui.getKeyBinding("MenuItem0"),
		sm.gui.getKeyBinding("MenuItem1"),
		sm.gui.getKeyBinding("PreviousMenuItem"),
		sm.gui.getKeyBinding("NextMenuItem"),
		sm.gui.getKeyBinding("ZoomIn"),
		sm.gui.getKeyBinding("ZoomOut")
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

function FreeCam:client_canErase()
	if self:isAllowed() then return true end

	sm.gui.displayAlertText("Only allowed players can delete this tool", 1)
	return false
end

function FreeCam:client_canInteract()
	if self:isAllowed() then
		if self.camera.state then
			sm.gui.setInteractionText("")
			sm.gui.setInteractionText("")
		else
			local use_key = sm.gui.getKeyBinding("Use")
			sm.gui.setInteractionText("Press", use_key, "to enable Free Camera Mode")
			sm.gui.setInteractionText("")
		end
		return true
	end

	sm.gui.setInteractionText("", "Only allowed players can use this tool")
	sm.gui.setInteractionText("")
	return false
end