--[[
	Copyright (c) 2022 Questionable Mark
]]

--if FREE_CAM_SUB then return end
FREE_CAM_SUB = class()

local free_cam_function_ids = FREE_CAM_OPTIONS.function_id_enum

function FREE_CAM_SUB.SUB_updateCameraData(self, curCategory, curOpt)
	local is_active = curOpt.value

	self.camera_hud:setVisible("CamDataBP", is_active)

	OP.enable_free_cam_data = is_active
end

function FREE_CAM_SUB.SUB_setTime(self, curCategory, curOpt)
	self.network:sendToServer("server_getStuff", { free_cam_function_ids.set_global_time, curOpt.value })
end

function FREE_CAM_SUB.SUB_timeUpdate(self, curCategory, curOpt)
	local l_value = curOpt.value
	sm.render.setOutdoorLighting(l_value)

	local l_time = l_value * 24
	local t_hours = math.floor(l_time) % 24
	local t_minutes = math.floor(l_time * 60) % 60
	local t_seconds = math.floor(l_time * 3600) % 60

	OP.display("highlight", false, ("#ffff00Time#ffffff set to #ffff00%.2f#ffffff or #ffff00%02d#ffffff:#ffff00%02d#ffffff:#ffff00%02d#ffffff"):format(l_value, t_hours, t_minutes, t_seconds))
end

function FREE_CAM_SUB.SUB_teleportCam(self, curCategory, curOpt)
	if curOpt.value > 0 then
		local cur_player = sm.player.getAllPlayers()[curOpt.value]
		if cur_player and cur_player.character then
			self.camera.move_target = cur_player.character
			self.camera.move_target_activation = sm.game.getCurrentTick()

			OP.display("blip", false, ("Moving your camera to #ffff00%s#ffffff"):format(cur_player.name))
		else
			OP.display("error", false, ("#ffff00%s#ffffff doesn't have a character"):format(cur_player.name))
		end
	else
		OP.display("error", false, "Pick a player")
	end
end

function FREE_CAM_SUB.SUB_teleportCamUpdate(self, curCategory, curOpt)
	local player_list = sm.player.getAllPlayers()
	curOpt.maxValue = #player_list
	
	local pl_idx = math.min(curOpt.value, curOpt.maxValue)
	local cur_player = player_list[pl_idx]

	sm.gui.displayAlertText(("Move to #ffff00%s#ffffff"):format(cur_player.name))
end

local function cameraRaycast(distance)
	local _CamPos = sm.camera.getPosition()
	local _CamDir = sm.camera.getDirection()
	local bool, result = sm.physics.raycast(_CamPos, _CamPos + _CamDir * distance)
	return bool, result
end

function FREE_CAM_SUB.SUB_charHijacker(self)
	local bool, result = cameraRaycast(100)
	if not (bool and result.type == "character") then
		OP.display("error", false, "You have to aim on characters in order to use this option")
		return
	end

	local res_char = result:getCharacter()
	local l_player = sm.localPlayer.getPlayer()

	if l_player:getCharacter() == res_char then
		OP.display("error", false, "You can't hijack your own character")
		return
	end

	if OP.isUnit(res_char) then
		OP.display("error", false, "You can't hijack a unit")
		return
	end

	if res_char:isTumbling() or res_char:isDowned() or res_char:isDiving() then
		OP.display("error", false, "You can't hijack downed / tumbling / diving characters")
		return
	end

	self.camera.activationTime = sm.game.getCurrentTick()
	self.camera.position = res_char.worldPosition

	self.network:sendToServer("server_getStuff", { free_cam_function_ids.hijack_char, res_char })
end

function FREE_CAM_SUB.SUB_charSpeed(self, cur_category, cur_option)
	local bool, result = cameraRaycast(100)
	if bool and result.type == "character" then
		self.network:sendToServer("server_getStuff", { free_cam_function_ids.set_char_speed, result:getCharacter(), cur_option.value })
	else
		OP.display("error", false, "You have to aim on characters in order to use this option")
	end
end

local function CharTeleporter_DisplayPickedCharName(character)
	if character:isPlayer() then
		OP.display("open", false, ("#ffff00%s#ffffff is selected for teleporting"):format(character:getPlayer().name))
	else
		OP.display("open", false, ("Character (id: #ffff00%s#ffffff) is selected for teleporting"):format(character.id))
	end
end

local function CharTeleporter_PickCharacter(self, result)
	if result.type == "character" then
		local res_char = result:getCharacter()

		self.camera.charToTeleport = res_char
		CharTeleporter_DisplayPickedCharName(res_char)

		return
	elseif result.type == "body" then
		local l_shape = result:getShape()
		local s_inter = l_shape:getInteractable()

		if s_inter ~= nil and (s_inter:hasSteering() or s_inter:hasSeat()) then
			local s_character = s_inter:getSeatCharacter()
			if s_character ~= nil then
				self.camera.charToTeleport = s_character
				CharTeleporter_DisplayPickedCharName(s_character)
			else
				OP.display("error", false, "No characters on the seat")
			end

			return
		end
	end

	OP.display("error", false, "You have to aim on seats / characters in order to use this option")
end

local function CharTeleporter_TeleportCharacter(self, result)
	local char_to_tp = self.camera.charToTeleport
	if type(char_to_tp) ~= "Character" then
		self.camera.charToTeleport = nil

		OP.display("error", false, "#ff0000ERROR#ffffff: The chosen object is not a character!")
		return
	end

	if not OP.exists(char_to_tp) then
		self.camera.charToTeleport = nil

		OP.display("error", false, "#ff0000ERROR#ffffff: This character doesn't exist anymore!")
		return
	end

	if sm.localPlayer.getPlayer():getCharacter() == char_to_tp then
		self.camera.activationTime = sm.game.getCurrentTick()
	end

	self.network:sendToServer("server_getStuff", {
		free_cam_function_ids.teleport_char,
		char_to_tp,
		result.pointWorld + sm.vec3.new(0, 0, char_to_tp:getHeight() / 2)
	})

	self.camera.charToTeleport = nil
end

function FREE_CAM_SUB.SUB_charTeleporter(self, cur_category, cur_option)
	local bool, result = cameraRaycast(100)
	if bool then
		if not self.camera.charToTeleport then
			CharTeleporter_PickCharacter(self, result)
		else
			CharTeleporter_TeleportCharacter(self, result)
		end
	end
end

function FREE_CAM_SUB.SUB_CharFunctions(self, cur_category, cur_option)
	local bool, result = cameraRaycast(100)
	if not (bool and result.type == "character") then
		OP.display("error", false, "You have to aim on characters in order to use this function")
		return
	end

	local res_char = result:getCharacter()
	local l_char = sm.localPlayer.getPlayer():getCharacter()

	if cur_option.self_ex or l_char ~= res_char then
		self.network:sendToServer("server_getStuff", { free_cam_function_ids.set_char_property, res_char, cur_option.id })
	else
		OP.display("error", false, "You can't use that function on your own character")
	end
end

function FREE_CAM_SUB.SUB_destroyUnit(self)
	local bool, result = cameraRaycast(100)
	if not bool or result.type ~= "character" then
		OP.display("error", false, "You have to aim at unit in order to use this function")
		return
	end

	local unit_char = result:getCharacter()
	if OP.isUnit(unit_char) then
		self.network:sendToServer("server_getStuff", { free_cam_function_ids.remove_unit, unit_char:getUnit() })
	else
		OP.display("error", false, "This is not a unit")
	end
end

function FREE_CAM_SUB.SUB_playerRecover(self, cur_category, cur_option)
	self.network:sendToServer("server_getStuff", { free_cam_function_ids.recover_player_chars })
end

function FREE_CAM_SUB.SUB_playerLocker(self, cur_category, cur_option)
	local bool, result = cameraRaycast(100)
	if not (bool and result.type == "character") then
		OP.display("error", false, "You have to aim on characters in order to use this option")
		return
	end

	local cur_char = result:getCharacter()
	if not cur_char:isPlayer() then
		OP.display("error", false, "This character doesn't belong to any player")
		return
	end

	if sm.localPlayer.getPlayer():getCharacter() ~= cur_char then
		self.network:sendToServer("server_getStuff", { free_cam_function_ids.lock_controls, cur_char:getPlayer() })
	else
		OP.display("error", false, "You can't lock your own character")
	end
end

function FREE_CAM_SUB.SUB_recoverOffWorldPlayers(self, cur_category, cur_option)
	self.network:sendToServer("server_getStuff", { free_cam_function_ids.recover_off_world_chars, cur_option.value })
end

function FREE_CAM_SUB.SUB_recoverOffWorldPlayersUpdate(self, cur_category, cur_option)
	OP.display("highlight", true, ("Safe distance set to #ffff00%s#ffffff"):format(cur_option.value))
end

function FREE_CAM_SUB.SUB_creatureSpawner(self, cur_category, cur_option)
	local sub_opt = cur_category.subOptions
	local unit_id = sub_opt[1].value

	if unit_id <= 0 then
		OP.display("error", false, "Choose a unit to spawn")
		return
	end

	local bool, result = cameraRaycast(100)
	if not bool then
		OP.display("error", false, "The raycast couldn't hit anything")
		return
	end

	self.network:sendToServer("server_getStuff", {
		free_cam_function_ids.spawn_unit,
		unit_id, --unit id
		sub_opt[2].value, --amount
		sub_opt[3].value, --no spread
		result.pointWorld, --position
		OP.directionToRadians(sm.camera.getDirection()) --rotation
	})
end

function FREE_CAM_SUB.SUB_createHarvestable(self, cur_category, cur_option)
	local sub_opt = cur_category.subOptions
	local hvs_id = sub_opt[1].value

	if hvs_id <= 0 then
		OP.display("error", false, "Choose the harvestable")
		return
	end

	local bool, result = cameraRaycast(100)
	if bool then
		self.network:sendToServer("server_getStuff", {
			free_cam_function_ids.spawn_harvestable,
			hvs_id,
			result.pointWorld
		})
	end
end

function FREE_CAM_SUB.SUB_removeHarvestable(self, data)
	local bool, result = cameraRaycast(100)
	if not bool then
		OP.display("error", false, "The raycast couldn't hit anything")
		return
	end

	if result.type ~= "harvestable" then
		OP.display("error", false, "In order to use this function you have to aim on harvestables")
		return
	end

	self.network:sendToServer("server_getStuff", { free_cam_function_ids.remove_harvestable, result:getHarvestable() })
end