--[[
	Copyright (c) 2021 Questionable Mark
]]

if FREE_CAM_SUB then return end
FREE_CAM_SUB = class()

function FREE_CAM_SUB.SUB_setTime(self, value)
	self.network:sendToServer("server_getStuff", {type = "time", value = value})
end

function FREE_CAM_SUB.SUB_teleportCam(self, data)
	if data.value > 0 then
		local player = sm.player.getAllPlayers()[data.value]
		if player.character then
			self.camera.move_target = player.character
			self.camera.move_target_activation = sm.game.getCurrentTick()
			OP.display("blip", false, ("Moving your camera to #ffff00%s#ffffff..."):format(player.name))
		else
			OP.display("error", false, ("#ffff00%s#ffffff doesn't have a character"):format(player.name))
		end
	else
		OP.display("error", false, "Pick a player")
	end
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

	local _ResChar = result:getCharacter()
	local _LocPl = sm.localPlayer.getPlayer()

	if _LocPl:getCharacter() == _ResChar then
		OP.display("error", false, "You can't hijack your own character")
		return
	end

	if OP.isUnit(_ResChar) then
		OP.display("error", false, "You can't hijack a unit")
		return
	end

	if (_ResChar:isTumbling() or _ResChar:isDowned() or _ResChar:isDiving()) then
		OP.display("error", false, "You can't hijack downed / tumbled / diving characters")
		return
	end

	self.camera.activationTime = sm.game.getCurrentTick()
	self.camera.position = _ResChar.worldPosition
	self.network:sendToServer("server_getStuff", {type = "hijack", character = _ResChar})
end

function FREE_CAM_SUB.SUB_charSpeed(self, values)
	local bool, result = cameraRaycast(100)
	if bool and result.type == "character" then
		self.network:sendToServer("server_getStuff", {
			type = "charSpeed",
			character = result:getCharacter(),
			value = values.value
		})
	else
		OP.display("error", false, "You have to aim on characters in order to use this option")
	end
end

local function CharTeleporter_PickCharacter(self, result)
	if result.type == "character" then
		local c_Char = result:getCharacter()

		if c_Char:isPlayer() then
			self.camera.charToTeleport = c_Char
			OP.display("open", false, ("#ffff00%s#ffffff is selected for teleporting"):format(c_Char:getPlayer().name))
		else
			OP.display("error", false, "This character isn't owned by anyone")
		end
	elseif result.type == "body" then
		local shape = result:getShape()
		local s_Inter = shape:getInteractable()

		if s_Inter == nil then return end

		if not (s_Inter:hasSteering() or s_Inter:hasSeat()) then return end

		local character = s_Inter:getSeatCharacter()
		if character ~= nil then
			self.camera.charToTeleport = character
			OP.display("open", false, ("#ffff00%s#ffffff is selected for teleporting"):format(character:getPlayer().name))
		else
			OP.display("error", false, "No characters on the seat")
		end
	else
		OP.display("error", false, "You have to aim on seats / characters in order to use this option")
	end
end

local function CharTeleporter_TeleportCharacter(self, result)
	local c_CharToTeleport = self.camera.charToTeleport
	if type(c_CharToTeleport) ~= "Character" then
		OP.display("error", false, "#ff0000ERROR#ffffff: The chosen object is not a character!")
		return
	end

	if not OP.exists(c_CharToTeleport) then
		OP.display("error", false, "#ff0000ERROR#ffffff: This character doesn't exist anymore!")
		return
	end

	if sm.localPlayer.getPlayer():getCharacter() == c_CharToTeleport then
		self.camera.activationTime = sm.game.getCurrentTick()
	end

	self.network:sendToServer("server_getStuff", {
		type = "charTp",
		character = c_CharToTeleport,
		position = result.pointWorld + sm.vec3.new(0, 0, 0.72),
		rotation = OP.directionToRadians(sm.camera.getDirection())
	})

	self.camera.charToTeleport = nil
end

function FREE_CAM_SUB.SUB_charTeleporter(self)
	local bool, result = cameraRaycast(100)
	if bool then
		if not self.camera.charToTeleport then
			CharTeleporter_PickCharacter(self, result)
		else
			CharTeleporter_TeleportCharacter(self, result)
		end
	end
end

function FREE_CAM_SUB.SUB_CharFunctions(self, option, self_executable)
	local bool, result = cameraRaycast(100)
	if not (bool and result.type == "character") then
		OP.display("error", false, "You have to aim on characters in order to use this function")
		return
	end

	local r_Character = result:getCharacter()
	if self_executable or sm.localPlayer.getPlayer():getCharacter() ~= r_Character then
		self.network:sendToServer("server_getStuff", {type = "charProp", id = option.id, char = r_Character})
	else
		OP.display("error", false, "You can't use that function on your own character")
	end
end

function FREE_CAM_SUB.SUB_destroyUnit(self)
	local bool, result = cameraRaycast(100)
	if not (bool and result.type == "character") then
		OP.display("error", false, "You have to aim on units in order to use this function")
		return
	end

	local _UnitChar = result:getCharacter()
	if OP.isUnit(_UnitChar) then
		self.network:sendToServer("server_getStuff", {
			type = "unitDel",
			unit = _UnitChar:getUnit()
		})
	else
		OP.display("error", false, "This is not a unit")
	end
end

function FREE_CAM_SUB.SUB_playerRecover(self)
	self.network:sendToServer("server_getStuff", {type = "recover"})
end

function FREE_CAM_SUB.SUB_playerLocker(self)
	local bool, result = cameraRaycast(100)
	if not (bool and result.type == "character") then
		OP.display("error", false, "You have to aim on characters in order to use this option")
		return
	end

	local _CurChar = result:getCharacter()
	if not _CurChar:isPlayer() then
		OP.display("error", false, "This character doesn't belong to any player")
		return
	end

	if sm.localPlayer.getPlayer():getCharacter() ~= _CurChar then
		self.network:sendToServer("server_getStuff", {type = "lockControls", player = _CurChar:getPlayer()})
	else
		OP.display("error", false, "You can't lock your own character")
	end
end

function FREE_CAM_SUB.SUB_recoverOffWorldPlayers(self, value)
	self.network:sendToServer("server_getStuff", {type = "recoverOff", safeZone = value})
end

function FREE_CAM_SUB.SUB_creatureSpawner(self, data)
	local subOp = data.subOptions
	if subOp[1].values.value <= 0 then
		OP.display("error", false, "Choose a unit to spawn")
		return
	end

	local bool, result = cameraRaycast(100)
	if not bool then
		OP.display("error", false, "The raycast couldn't hit anything")
		return
	end

	self.network:sendToServer("server_getStuff", {
		type = "spawnCreature",
		id = data.numberNames.creatures[subOp[1].values.value].id,
		position = result.pointWorld,
		rotation = OP.directionToRadians(sm.camera.getDirection()),
		amount = subOp[2].values.value,
		no_spread = subOp[3].values
	})
end

function FREE_CAM_SUB.SUB_createHarvestable(self, data)
	local CurSub = data.subOptions
	if CurSub[1].values.value <= 0 then
		OP.display("error", false, "Choose a harvestable to spawn")
		return
	end

	local bool, result = cameraRaycast(100)
	if bool then
		self.network:sendToServer("server_getStuff", {
			type = "spawnHarvestable",
			id = data.numberNames.harvestableNames[CurSub[1].values.value].id,
			position = result.pointWorld,
			rotation = OP.directionToRadians(sm.camera.getDirection())
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

	self.network:sendToServer("server_getStuff", {type = "removeHarvestable", hvs = result:getHarvestable()})
end