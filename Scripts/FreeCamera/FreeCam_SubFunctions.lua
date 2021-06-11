--[[
	Copyright (c) 2021 Questionable Mark
]]

if FREE_CAM_SUB then return end
FREE_CAM_SUB = class()

function FREE_CAM_SUB.SUB_setTime(self, value)
	OP.display("blip", false, ("#ffff00Time#ffffff set to #ffff00%s#ffffff for everyone"):format(value))
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
	if bool and result.type == "character" then
		local _ResChar = result:getCharacter()
		local _LocPl = sm.localPlayer.getPlayer()
		if _LocPl:getCharacter() ~= _ResChar then
			if not OP.isUnit(_ResChar) then
				if not (_ResChar:isTumbling() or _ResChar:isDowned() or _ResChar:isDiving()) then
					self.camera.activationTime = sm.game.getCurrentTick()
					self.camera.move_target = _ResChar
					self.camera.move_target_activation = sm.game.getCurrentTick()
					self.network:sendToServer("server_getStuff", {
						type = "hijack",
						player = _LocPl,
						character = _ResChar
					})
				else
					OP.display("error", false, "You can't hijack downed / tumbled / diving characters")
				end
			else
				OP.display("error", false, "You can't hijack a unit")
			end
		else
			OP.display("error", false, "You can't hijack your own character")
		end
	else
		OP.display("error", false, "You have to aim on characters in order to use this option")
	end
end

function FREE_CAM_SUB.SUB_charSpeed(self, values)
	local bool, result = cameraRaycast(100)
	if bool and result.type == "character" then
		OP.display("blip", false, ("Set the speed of #ffff00%s#ffffff for a character [id: #ffff00%s#ffffff]"):format(values.value, result:getCharacter().id))
		self.network:sendToServer("server_getStuff", {
			type = "charSpeed",
			character = result:getCharacter(),
			value = values.value
		})
	else
		OP.display("error", false, "You have to aim on characters in order to use this option")
	end
end

function FREE_CAM_SUB.SUB_charTeleporter(self)
	local bool, result = cameraRaycast(100)
	if bool then
		if not self.camera.charToTeleport then
			if result.type == "character" then
				if result:getCharacter():isPlayer() then
					self.camera.charToTeleport = result:getCharacter()
					OP.display("open", false, ("#ffff00%s#ffffff is selected for teleporting"):format(result:getCharacter():getPlayer().name))
				else
					OP.display("error", false, "This character isn't owned by anyone")
				end
			elseif result.type == "body" and (result:getShape():getInteractable() ~= nil and (result:getShape():getInteractable():getType() == "steering" or result:getShape():getInteractable():getType() == "seat")) then
				local character = result:getShape():getInteractable():getSeatCharacter()
				if character ~= nil then
					self.camera.charToTeleport = character
					OP.display("open", false, ("#ffff00%s#ffffff is selected for teleporting"):format(character:getPlayer().name))
				else
					OP.display("error", false, "No characters on the seat")
				end
			else
				OP.display("error", false, "You have to aim on seats / characters in order to use this option")
			end
		else
			if type(self.camera.charToTeleport) == "Character" then
				if OP.exists(self.camera.charToTeleport) then
					if sm.localPlayer.getPlayer():getCharacter() == self.camera.charToTeleport then
						self.camera.activationTime = sm.game.getCurrentTick()
					end
					OP.display("blip", false, ("#ffff00%s#ffffff has been teleported"):format(self.camera.charToTeleport:getPlayer().name))
					self.network:sendToServer("server_getStuff", {
						type = "charTp",
						character = self.camera.charToTeleport,
						position = result.pointWorld + sm.vec3.new(0, 0, 0.72),
						rotation = OP.directionToRadians(sm.camera.getDirection())
					})
				else
					OP.display("error", false, "#ff0000ERROR#ffffff: This character doesn't exist anymore!")
				end
			else
				OP.display("error", false, "#ff0000ERROR#ffffff: The chosen object is not a character!")
			end
			self.camera.charToTeleport = nil
		end
	end
end

function FREE_CAM_SUB.SUB_CharFunctions(self, option, self_executable)
	local bool, result = cameraRaycast(100)
	if bool and result.type == "character" then
		if self_executable or sm.localPlayer.getPlayer():getCharacter() ~= result:getCharacter() then
			local sel_char = result:getCharacter()
			local setting_bool = false
			if option.id == "tumble" then
				setting_bool = sel_char:isTumbling()
			elseif option.id == "downChar" then
				setting_bool = sel_char:isDowned()
			elseif option.id == "charSwim" then
				setting_bool = sel_char:isSwimming()
			elseif option.id == "charDive" then
				setting_bool = sel_char:isDiving()
			end
			OP.display("blip", false, ("#ffff00%s#ffffff is %s for character [id: #ffff00%s#ffffff]"):format(option.name, OP.bools[not setting_bool].string, sel_char.id))
			self.network:sendToServer("server_getStuff", {
				type = option.id,
				character = sel_char
			})
		else
			OP.display("error", false, "You can't use that function on your own character")
		end
	else
		OP.display("error", false, "You have to aim on characters in order to use this function")
	end
end

function FREE_CAM_SUB.SUB_destroyUnit(self)
	local bool, result = cameraRaycast(100)
	if bool and result.type == "character" then
		local _UnitChar = result:getCharacter()
		if OP.isUnit(_UnitChar) then
			self.network:sendToServer("server_getStuff", {
				type = "unitDel",
				unit = _UnitChar:getUnit()
			})
		else
			OP.display("error", false, "This is not a unit")
		end
	else
		OP.display("error", false, "You have to aim on units in order to use this function")
	end
end

function FREE_CAM_SUB.SUB_playerRecover(self)
	self.network:sendToServer("server_getStuff", {type = "recover", sender = sm.localPlayer.getPlayer()})
end

function FREE_CAM_SUB.SUB_playerLocker(self)
	local bool, result = cameraRaycast(100)
	if bool and result.type == "character" then
		local _CurChar = result:getCharacter()
		if _CurChar:isPlayer() then
			if sm.localPlayer.getPlayer():getCharacter() ~= _CurChar then
				self.network:sendToServer("server_getStuff", {
					type = "lockControls",
					player = _CurChar:getPlayer()
				})
			else
				OP.display("error", false, "You can't lock your own character")
			end
		else
			OP.display("error", false, "This character doesn't belong to any player")
		end
	else
		OP.display("error", false, "You have to aim on characters in order to use this option")
	end
end

function FREE_CAM_SUB.SUB_recoverOffWorldPlayers(self, value)
	self.network:sendToServer("server_getStuff", {type = "recoverOff", safeZone = value, sender = sm.localPlayer.getPlayer()})
end

function FREE_CAM_SUB.SUB_creatureSpawner(self, data)
	local subOp = data.subOptions
	if subOp[1].values.value > 0 then
		local bool, result = cameraRaycast(100)
		if bool then
			self.network:sendToServer("server_getStuff", {
				type = "spawnCreature",
				id = data.numberNames.creatures[subOp[1].values.value].id,
				player = sm.localPlayer.getPlayer(),
				position = result.pointWorld,
				rotation = OP.directionToRadians(sm.camera.getDirection()),
				amount = subOp[2].values.value,
				no_spread = subOp[3].values
			})
		else
			OP.display("error", false, "The raycast couldn't hit anything")
		end
	else
		OP.display("error", false, "Choose a unit to spawn")
	end
end

function FREE_CAM_SUB.SUB_createHarvestable(self, data)
	local CurSub = data.subOptions
	if CurSub[1].values.value > 0 then
		local bool, result = cameraRaycast(100)
		if bool then
			self.network:sendToServer("server_getStuff", {
				type = "spawnHarvestable",
				id = data.numberNames.harvestableNames[CurSub[1].values.value].id,
				position = result.pointWorld,
				player = sm.localPlayer.getPlayer(),
				rotation = OP.directionToRadians(sm.camera.getDirection())
			})
		end
	else
		OP.display("error", false, "Choose a harvestable to spawn")
	end
end

function FREE_CAM_SUB.SUB_removeHarvestable(self, data)
	local bool, result = cameraRaycast(100)
	if bool then
		if result.type == "harvestable" then
			self.network:sendToServer("server_getStuff", {
				type = "removeHarvestable",
				player = sm.localPlayer.getPlayer(),
				hvs = result:getHarvestable()
			})
		else
			OP.display("error", false, "In order to use this function you have to aim on harvestables")
		end
	else
		OP.display("error", false, "The raycast couldn't hit anything")
	end
end