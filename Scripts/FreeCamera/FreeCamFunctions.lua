--[[
	Copyright (c) 2021 Questionable Mark
]]

if FREE_CAM_OPTIONS then return end
FREE_CAM_OPTIONS = class()

local _sm_getKeyBind = sm.gui.getKeyBinding
function FREE_CAM_OPTIONS.display_guide()
	sm.gui.chatMessage(
		(
			"\n#ff0000FREE CAMERA INSTRUCTIONS#ffffff:\n"..
			"#ffff00%s#ffffff - close the free camera tool\n"..
			"#ffff00%s#ffffff - use the chosen function\n"..
			"#ffff00%s#ffffff - spawn your own character at the location of the camera\n"..
			"#ffff00%s%s%s%s#ffffff - move\n"..
			"#ffff00%s#ffffff - switch the function\n"..
			"#ffff00%s#ffffff - switch the parameters of the selected function\n"..
			"#ffff00%s#ffffff/#ffff00%s#ffffff or #ffff00%s#ffffff/#ffff00%s#ffffff - change the chosen parameter of the function\n"..
			"#ffff00%s#ffffff - double the scrolling speed\n"
		):format(
			_sm_getKeyBind("Use"),
			_sm_getKeyBind("Create"),
			_sm_getKeyBind("Attack"),
			_sm_getKeyBind("Forward"),_sm_getKeyBind("StrafeLeft"),_sm_getKeyBind("Backward"),_sm_getKeyBind("StrafeRight"),
			_sm_getKeyBind("MenuItem0"),
			_sm_getKeyBind("MenuItem1"),
			_sm_getKeyBind("ZoomIn"),_sm_getKeyBind("ZoomOut"),_sm_getKeyBind("PreviousMenuItem"),_sm_getKeyBind("NextMenuItem"),
			_sm_getKeyBind("Jump")
		)
	)
end

function FREE_CAM_OPTIONS.freeCamera_options()
	local functionTable = {
		[1] = {
			name = "Camera Functions",
			func = function(self, data, od)
				if (od.option_page + 1) > 0 then
					local current_option = data.subOptions[od.option_page + 1]
					if current_option.name == "Time" then
						FREE_CAM_SUB.SUB_setTime(self, current_option.values.value)
					elseif current_option.name == "Move to Player" then
						FREE_CAM_SUB.SUB_teleportCam(self, current_option.values)
					else
						OP.display("error", false, "This parameter doesn't have a function")
					end
				else
					OP.display("error", false, "Choose an option")
				end
			end,
			update = function(self, data, option)
				if option == "Time" then
					sm.render.setOutdoorLighting(data.value)
					local time = data.value * 24
					local hours = math.floor(time) % 24
					local minutes = math.floor(time * 60) % 60
					local seconds = math.floor(time * 3600) % 60
					OP.display("highlight", false, ("#ffff00Time#ffffff set to #ffff00%.2f#ffffff or #ffff00%02d#ffffff:#ffff00%02d#ffffff:#ffff00%02d#ffffff"):format(data.value, hours, minutes, seconds))
				elseif option == "Move to Player" then
					data.subTab.values.maxValue = #sm.player.getAllPlayers()
					local index = math.min(data.value, #sm.player.getAllPlayers())
					local playerToTeleport = sm.player.getAllPlayers()[index]
					sm.gui.displayAlertText(("Move to #ffff00%s#ffffff"):format(playerToTeleport.name))
				end
			end,
			subOptions = {
				[1] = {name = "Camera Speed",	values = {value = 1,changer = 0.01,minValue = 0,maxValue = 20}},
				[2] = {name = "Camera Friction",values = {value = 1,changer = 0.01, minValue = 0, maxValue = 1}},
				[3] = {name = "Time",			values = {value = sm.render.getOutdoorLighting(), changer = 0.01, minValue = 0, maxValue = 1},disableText = true},
				[4] = {name = "Move to Player",	values = {value = 0, changer = 1, minValue = 1, maxValue = #sm.player.getAllPlayers()},disableText = true}
			}
		},
		[2] = {
			name = "Explosion Spawner",
			func = function(self, data)
				local cam_pos = sm.camera.getPosition()
				local bool, result = sm.physics.raycast(cam_pos, cam_pos + sm.camera.getDirection() * 1000)
				if bool then
					local settings = data.subOptions
					local explosion = {
						lvl = settings[1].values.value,
						rad = settings[2].values.value,
						imp = settings[3].values.value,
						impRad = settings[4].values.value
					}
					self.network:sendToServer("server_getStuff", {type = "explosion", expl = explosion, pos = result.pointWorld})
				end
			end,
			subOptions = {
				[1] = {name = "Explosion Level",			values = {value = 5, changer = 1, minValue = 1, maxValue = math.huge}},
				[2] = {name = "Explosion Radius",			values = {value = 0.3, changer = 0.1, minValue = 0.3, maxValue = 50}},
				[3] = {name = "Explosion Impulse Strength",	values = {value = 1000, changer = 500, minValue = 10, maxValue = math.huge}},
				[4] = {name = "Explosion Impulse Sadius",	values = {value = 10, changer = 1, minValue = 1, maxValue = 500}}
			}
		},
		[3] = {
			name = "Projectile Launcher",
			func = function(self, data)
				projSet = data.subOptions

				local curProj
				if projSet[1].values.value > 0 then
					self.network:sendToServer("server_getStuff", {
						type = "shoot",
						amount = projSet[4].values.value,
						pos = sm.camera.getPosition(),
						dir = sm.camera.getDirection() * projSet[2].values.value,
						spread = projSet[3].values.value,
						proj = data.numberNames.projectiles[projSet[1].values.value].id
					})
				else
					OP.display("error", false, "Choose the projectile")
				end
			end,
			subOptions = {
				[1] = {name = "Projectile", 			values = {value = 0, changer = 1, minValue = 1, maxValue = 20, displayNames = "projectiles"}},
				[2] = {name = "Projectile Speed", 		values = {value = 100, changer = 1, minValue = 1, maxValue = math.huge}},
				[3] = {name = "Spread", 				values = {value = 1, changer = 1, minValue = 0, maxValue = 180}},
				[4] = {name = "Projectiles Per Shot",	values = {value = 1, changer = 1, minValue = 1, maxValue = 100}}
			},
			numberNames = {
				projectiles = {
					[1] = {name = "Potato",			id = "potato"},
					[2] = {name = "Small potato",	id = "smallpotato"},
					[3] = {name = "Fries",			id = "fries"},
					[4] = {name = "Tomato",			id = "tomato"},
					[5] = {name = "Carrot",			id = "carrot"},
					[6] = {name = "Redbeet",		id = "redbeet"},
					[7] = {name = "Broccoli",		id = "broccoli"},
					[8] = {name = "Pineapple",		id = "pineapple"},
					[9] = {name = "Orange",			id = "orange"},
					[10] = {name = "Blueberry",		id = "blueberry"},
					[11] = {name = "Banana",		id = "banana"},
					[12] = {name = "Tape",			id = "tape"},
					[13] = {name = "Explosive Tape",id = "explosivetape"},
					[14] = {name = "Water",			id = "water"},
					[15] = {name = "Fertilizer",	id = "fertilizer"},
					[16] = {name = "Chemical",		id = "chemical"},
					[17] = {name = "Pesticide",		id = "pesticide"},
					[18] = {name = "Seed",			id = "seed"},
					[19] = {name = "Glowstick",		id = "glowstick"},
					[20] = {name = "Epic Loot",		id = "epicloot"}
				}
			}
		},
		[4] = {
			name = "Unit Spawner",
			func = function(self, data, od)
				local _selParam = (od.option_page + 1)
				if (_selParam > 0) then
					if _selParam == 1 then
						FREE_CAM_SUB.SUB_creatureSpawner(self, data)
					elseif _selParam == 4 then
						FREE_CAM_SUB.SUB_destroyUnit(self)
					else
						OP.display("error", false, "This option doesn't have a function")
					end
				else
					OP.display("error", false, "Choose an option")
				end
			end,
			subOptions = {
				[1] = {name = "Spawn Unit", 			values = {value = 0, changer = 1, minValue = 1, maxValue = 7, displayNames = "creatures"}},
				[2] = {name = "Amount of Units", 		values = {value = 1, changer = 1, minValue = 1, maxValue = 100}},
				[3] = {name = "Spawn Without Spreading",values = false},
				[4] = {name = "Remove Unit"}
			},
			numberNames = {
				creatures = {
					[1] = {name = "Tapebot", id = "tapebot"},
					[2] = {name = "Red Tapebot", id = "tapebotR"},
					[3] = {name = "Totebot", id = "totebotG"},
					[4] = {name = "Haybot", id = "haybot"},
					[5] = {name = "Farmbot", id = "farmbot"},
					[6] = {name = "Worm", id = "worm"},
					[7] = {name = "Woc", id = "woc"}
				}
			}
		},
		[5] = {
			name = "Harvestable Functions",
			func = function(self, data, od)
				local _opPage = (od.option_page + 1)
				if _opPage == 1 then
					FREE_CAM_SUB.SUB_createHarvestable(self, data)
				elseif _opPage == 2 then
					FREE_CAM_SUB.SUB_removeHarvestable(self, data)
				else
					OP.display("error", false, "Choose an Option")
				end
			end,
			subOptions = {
				[1] = {name = "Spawn Harvestable", values = {value = 0, changer = 1, minValue = 1, maxValue = 37, displayNames = "harvestableNames"}},
				[2] = {name = "Remove Harvestable"}
			},
			numberNames = {
				harvestableNames = {
					[1] = {name = "Burnt Spike Tree 1", id = "hvs_burntforest_spiketree01"},
					[2] = {name = "Burnt Spike Tree 2", id = "hvs_burntforest_spiketree02"},
					[3] = {name = "Burnt Spruce Tree 1", id = "hvs_burntforest_spruce01"},
					[4] = {name = "Burnt Spruce Tree 2", id = "hvs_burntforest_spruce02"},
					[5] = {name = "Burnt Spruce Tree 3", id = "hvs_burntforest_spruce03"},
					[6] = {name = "Burnt Spruce Tree 4", id = "hvs_burntforest_spruce04"},
					[7] = {name = "Burnt Spruce Tree 5", id = "hvs_burntforest_spruce05"},
					[8] = {name = "Burnt Birch Tree 1", id = "hvs_burntforest_birch01"},
					[9] = {name = "Cotton Plant", id = "hvs_farmables_cottonplant"},
					[10] = {name = "Corn Plant", id = "hvs_farmables_cornplant"},
					[11] = {name = "Pigment Flower", id = "hvs_farmables_pigmentflower"},
					[12] = {name = "Hay Pile 1", id = "hvs_fillers_haypile_01"},
					[13] = {name = "Hay Pile 2", id = "hvs_fillers_haypile_02"},
					[14] = {name = "Hay Pile 3", id = "hvs_fillers_haypile_03"},
					[15] = {name = "Leaf Pile 1", id = "hvs_leafpile_01"},
					[16] = {name = "Leaf Pile 2", id = "hvs_leafpile_02"},
					[17] = {name = "Small Stone 1", id = "hvs_stone_small01"},
					[18] = {name = "Small Stone 2", id = "hvs_stone_small02"},
					[19] = {name = "Small Stone 3", id = "hvs_stone_small03"},
					[20] = {name = "Medium Stone 1", id = "hvs_stone_medium01"},
					[21] = {name = "Medium Stone 2", id = "hvs_stone_medium02"},
					[22] = {name = "Medium Stone 3", id = "hvs_stone_medium03"},
					[23] = {name = "Large Stone 1", id = "hvs_stone_large01"},
					[24] = {name = "Large Stone 2", id = "hvs_stone_large02"},
					[25] = {name = "Large Stone 3", id = "hvs_stone_large03"},
					[26] = {name = "Birch Tree 1", id = "harvestable_tree_birch01"},
					[27] = {name = "Birch Tree 2", id = "harvestable_tree_birch02"},
					[28] = {name = "Birch Tree 3", id = "harvestable_tree_birch03"},
					[29] = {name = "Leafy Tree 1", id = "harvestable_tree_leafy01"},
					[30] = {name = "Leafy Tree 2", id = "harvestable_tree_leafy02"},
					[31] = {name = "Leafy Tree 3", id = "harvestable_tree_leafy03"},
					[32] = {name = "Pine Tree 1", id = "harvestable_tree_pine01"},
					[33] = {name = "Pine Tree 2", id = "harvestable_tree_pine02"},
					[34] = {name = "Pine Tree 3", id = "harvestable_tree_pine03"},
					[35] = {name = "Spruce Tree 1", id = "harvestable_tree_spruce01"},
					[36] = {name = "Spruce Tree 2", id = "harvestable_tree_spruce02"},
					[37] = {name = "Spruce Tree 3", id = "harvestable_tree_spruce03"}
				}
			}
		},
		[6] = {
			name = "Character Functions",
			func = function(self, data, od)
				local _opPage = (od.option_page + 1)
				if _opPage > 0 then
					if _opPage == 1 then
						FREE_CAM_SUB.SUB_charHijacker(self)
					elseif _opPage == 2 then
						FREE_CAM_SUB.SUB_charSpeed(self, data.subOptions[od.option_page + 1].values)
					elseif _opPage == 3 then
						FREE_CAM_SUB.SUB_charTeleporter(self)
					else
						local option = data.subOptions[od.option_page + 1]
						FREE_CAM_SUB.SUB_CharFunctions(self, option, option.s_ex)
					end
				else
					OP.display("error", false, "Choose an option first")
				end
			end,
			subOptions = {
				[1] = {name = "Character Hijacker"},
				[2] = {name = "Character Speed", values = {value = 0, changer = 1, minValue = -100, maxValue = 100}},
				[3] = {name = "Character Teleporter"},
				[4] = {name = "Set Tumble", id = "tumble"},
				[5] = {name = "Set Downed", id = "downChar"},
				[6] = {name = "Set Swimming", s_ex = true, id = "charSwim"},
				[7] = {name = "Set Diving", id = "charDive"}
			}
		},
		[7] = {
			name = "Player Functions",
			func = function(self, data, od)
				local _opPage = (od.option_page + 1)
				if _opPage > 0 then
					if _opPage == 1 then
						FREE_CAM_SUB.SUB_playerRecover(self)
					elseif _opPage == 2 then
						FREE_CAM_SUB.SUB_playerLocker(self)
					elseif _opPage == 3 then
						FREE_CAM_SUB.SUB_recoverOffWorldPlayers(self, data.subOptions[od.option_page + 1].values.value)
					end
				else
					OP.display("error", false, "Choose an option first")
				end
			end,
			update = function(self, data, option)
				if option == "Recover Off-world Players" then
					OP.display("highlight", true, ("Safe distance set to #ffff00%s#ffffff"):format(data.value))
				end
			end,
			subOptions = {
				[1] = {name = "Recover Missing Player Characters"},
				[2] = {name = "Player Locker"},
				[3] = {name = "Recover Off-world Players", values = {value = 710, changer = 10, minValue = 0, maxValue = 1400}, disableText = true}
			}
		}
	}
	return functionTable
end

function FREE_CAM_OPTIONS.client_callBacks()
	local callBackTable = {
		setTime = function(self, data) sm.render.setOutdoorLighting(data.time) end,
		charLock = function(self, data) OP.toggleLockedCamera() end
	}
	return callBackTable
end

local local_server_table = {}

function local_server_table.explosion(self, data)
	OP.betterExplosion(data.pos, data.expl.lvl, data.expl.rad, data.expl.imp, data.expl.impRad, "PropaneTank - ExplosionSmall", true)
end

function local_server_table.spawnChar(self, data, caller)
	if data.position then
		local char = sm.character.createCharacter(caller, sm.world.getCurrentWorld(), data.position, data.dir.yaw, data.dir.pitch)
		caller:setCharacter(char)
		OP.print(("\"%s\" has been teleported, new position = %s"):format(caller.name, char.worldPosition))
	end
end

function local_server_table.time(self, data, caller)
	local d_Value = data.value

	self.network:sendToClients("client_getStuff", {type = "setTime", time = d_Value})
	OP.print(("time set to %s"):format(d_Value))

	local frmt_text = ("#ffff00Time#ffffff set to #ffff00%.2f#ffffff for everyone"):format(d_Value)
	self:server_sendMessage(caller, frmt_text, "blip")
end

function local_server_table.spawnCreature(self, data)
	local _CurUnit = self.units[data.id]
	if not _CurUnit then return end

	if data.no_spread then
		for i = 1, data.amount do
			pcall(sm.unit.createUnit, _CurUnit.uuid, data.position, data.rotation.yaw)
		end
	else
		local _Right = sm.vec3.new(1.0, 0.0, 0.0):rotateZ(data.rotation.yaw)
		local _Forward = sm.vec3.new(0.0, 1.0, 0.0):rotateZ(data.rotation.yaw)

		local size_x = math.ceil(math.sqrt(data.amount))
		local size_y = math.ceil(data.amount / size_x)
		local _Offset = -(_Right * (((_CurUnit.spacing * size_y) / 2) + (_CurUnit.spacing / 2)))

		local spawned = 0
		for x = 1, size_x do
			local _ForwardOffset = (_Forward * ((x * _CurUnit.spacing) - _CurUnit.spacing))
			for y = 1, size_y do
				local _RightOffset = (_Right * y * _CurUnit.spacing)
				local _FinalPos = data.position + _RightOffset + _ForwardOffset + _Offset
				pcall(sm.unit.createUnit, _CurUnit.uuid, _FinalPos, data.rotation.yaw)
				spawned = spawned + 1
				if spawned >= data.amount then return end
			end
		end
	end
end

function local_server_table.hijack(self, data, caller)
	local d_Character = data.character

	if OP.exists(d_Character) then
		if d_Character:isPlayer() then
			d_Character:getPlayer():setCharacter(d_Character)
			local char = sm.character.createCharacter(caller, sm.world.getCurrentWorld(), d_Character.worldPosition)
			caller:setCharacter(char)
		else
			caller:setCharacter(d_Character)
		end

		OP.print(("Character %s has been hijacked"):format(d_Character.id))
	end
end

function local_server_table.recover(self, data, caller)
	local amount = 0
	for k, player in pairs(sm.player.getAllPlayers()) do
		if player.character == nil then
			local char = sm.character.createCharacter(player, sm.world.getCurrentWorld(), sm.vec3.new(0, 0, 50))
			player:setCharacter(char)
			amount = amount + 1
		end
	end

	OP.print(("%s players got their characters back"):format(amount))
	local frmt_text = ("#ffff00%s#ffffff players got their characters back"):format(amount)

	self:server_sendMessage(caller, frmt_text, "blip")
end

function local_server_table.lockControls(self, data, caller)
	local d_Player = data.player
	if d_Player == OP.server_admin then
		self:server_sendMessage(caller, "You can't lock controls for server admin!", "error")
		return
	end

	self.network:sendToClient(d_Player, "client_getStuff", {type = "charLock"})
	OP.print(("locked controls for \"%s\""):format(d_Player.name))
end

function local_server_table.recoverOff(self, data, caller)
	local recoveredPlayers = 0
	for k, player in pairs(sm.player.getAllPlayers()) do
		if player.character ~= nil and OP.checkWorldPosition(player.character.worldPosition, data.safeZone) then
			local char = sm.character.createCharacter(player, sm.world.getCurrentWorld(), sm.vec3.new(0, 0, 50))
			player:setCharacter(char)
			recoveredPlayers = recoveredPlayers + 1
		end
	end

	OP.print(("%s players have been returned back to the world"):format(recoveredPlayers))
	local frmt_text = ("#ffff00%s#ffffff players were rescued from outside the world"):format(recoveredPlayers)

	self:server_sendMessage(caller, frmt_text, "blip")
end

function local_server_table.charSpeed(self, data, caller)
	local d_Char = data.character
	if OP.exists(d_Char) then
		local d_Value = data.value
		d_Char:setMovementSpeedFraction(d_Value)

		OP.print(("character speed has been changed to %s (char id = %s)"):format(d_Value, d_Char.id))
		local frmt_text = ("Set the speed of #ffff00%s#ffffff for a character [id: #ffff00%s#ffffff]"):format(d_Value, d_Char.id)

		self:server_sendMessage(caller, frmt_text, "blip")
	else
		OP.print("ERROR: changing the speed for non-existant character")
	end
end

local char_state_translation = {
	tumble = "Set Tumble",
	downChar = "Set Downed",
	charSwim = "Set Swimming",
	charDive = "Set Diving"
}

function local_server_table.charProp(self, data, caller)
	local d_Char = data.char
	if OP.exists(d_Char) then
		local d_Type = data.id
		local cur_setting = nil

		if d_Type == "tumble" then
			cur_setting = not d_Char:isTumbling()
			d_Char:setTumbling(cur_setting)
		elseif d_Type == "downChar" then
			cur_setting = not d_Char:isDowned()
			d_Char:setDowned(cur_setting)
		elseif d_Type == "charSwim" then
			cur_setting = not d_Char:isSwimming()
			d_Char:setSwimming(cur_setting)
		elseif d_Type == "charDive" then
			cur_setting = not d_Char:isDiving()
			d_Char:setDiving(cur_setting)
		end

		local t_TypeName = char_state_translation[d_Type]
		OP.print(("%s for character to %s, id = %s"):format(cur_setting, cur_setting, d_Char.id))
		local frmt_text = ("#ffff00%s#ffffff is %s for character [id: #ffff00%s#ffffff]"):format(t_TypeName, OP.bools[cur_setting].string, d_Char.id)

		self:server_sendMessage(caller, frmt_text, "blip")
	else
		OP.print("ERROR: tried to down a non-existant character")
	end
end

function local_server_table.charTp(self, data, caller)
	local d_Char = data.character
	if OP.exists(d_Char) then
		local player = d_Char:getPlayer()
		local char = sm.character.createCharacter(player, sm.world.getCurrentWorld(), data.position, data.rotation.yaw, data.rotation.pitch, d_Char)
		player:setCharacter(char)

		OP.print(("\"%s\" has been teleported, new position = %s"):format(player.name, data.position))
		local frmt_text = ("#ffff00%s#ffffff has been teleported"):format(d_Char:getPlayer().name)

		self:server_sendMessage(caller, frmt_text, "blip")
	else
		OP.print("ERROR: tried to teleport a non-existant character")
	end
end

function local_server_table.unitDel(self, data)
	local d_Unit = data.unit
	if OP.exists(d_Unit) then
		OP.print(("Unit %s has been destroyed"):format(d_Unit.id))
		d_Unit:destroy()
	else
		OP.print("ERROR: tried to delete a non-existant unit")
	end
end

function local_server_table.spawnHarvestable(self, data)
	local _CurHvs = self.harvestables[data.id]
	if _CurHvs then
		local _RotationQuat = sm.quat.angleAxis(math.rad(90), sm.vec3.new(1, 0, 0))
		_RotationQuat = _RotationQuat * sm.quat.angleAxis(math.rad(math.random(-3600, 3600) / 100), sm.vec3.new(0, 1, 0))
		pcall(sm.harvestable.create, _CurHvs, data.position, _RotationQuat)
	end
end

function local_server_table.removeHarvestable(self, data)
	local d_Hvs = data.hvs
	if OP.exists(d_Hvs) then
		OP.print(("Harvestable %s has been destroyed"):format(d_Hvs.id))
		pcall(sm.harvestable.destroy, d_Hvs)
	else
		OP.print("ERROR: tried to delete a non-existant harvestable")
	end
end

local _sm_gunSpread = sm.noise.gunSpread
local _sm_projAttack = sm.projectile.projectileAttack
function local_server_table.shoot(self, data, caller)
	local s_Amount = data.amount
	local s_Direction = data.dir
	local s_Position = data.pos
	local s_Projectile = data.proj
	local s_Spread = data.spread

	for i = 1, data.amount do
		local s_Dir = _sm_gunSpread(s_Direction, s_Spread)
		_sm_projAttack(s_Projectile, 20, s_Position, s_Dir, caller)
	end
end

function FREE_CAM_OPTIONS.server_callBacks()
	return local_server_table
end

local _sm_newUuid = sm.uuid.new
function FREE_CAM_OPTIONS.loadUnitInfo()
	local units = {
		woc = {uuid = _sm_newUuid("264a563a-e304-430f-a462-9963c77624e9"), spacing = 2},
		tapebot = {uuid = _sm_newUuid("04761b4a-a83e-4736-b565-120bc776edb2"), spacing = 1},
		tapebotR = {uuid = _sm_newUuid("c3d31c47-0c9b-4b07-9bd4-8f022dc4333e"), spacing = 1},
		totebotG = {uuid = _sm_newUuid("8984bdbf-521e-4eed-b3c4-2b5e287eb879"), spacing = 1},
		haybot = {uuid = _sm_newUuid("c8bfb8f3-7efc-49ac-875a-eb85ac0614db"), spacing = 1.5},
		farmbot = {uuid = _sm_newUuid("9f4fde94-312f-4417-b13b-84029c5d6b52"), spacing = 4.5},
		worm = {uuid = _sm_newUuid("48c03f69-3ec8-454c-8d1a-fa09083363b1"), spacing = 0.5}
	}
	return units
end

function FREE_CAM_OPTIONS.loadHarvestableInfo()
	local harvestables = {
		hvs_burntforest_spiketree01 = _sm_newUuid("9ef210c0-ea30-4442-a1fe-924b5609b0cc"),
		hvs_burntforest_spiketree02 = _sm_newUuid("2bae67d4-c8ef-4c6e-a1a7-42281d0b7489"),
		hvs_burntforest_spruce01 = _sm_newUuid("8f7a8108-2712-47b3-bce2-f25315165094"),
		hvs_burntforest_spruce02 = _sm_newUuid("515aed88-0594-42b6-a352-617e5f5a3e45"),
		hvs_burntforest_spruce03 = _sm_newUuid("2d5aa53d-eb9c-478c-a70f-c57a43753814"),
		hvs_burntforest_spruce04 = _sm_newUuid("c08b553a-a917-4e26-bbb6-7b8523789cad"),
		hvs_burntforest_spruce05 = _sm_newUuid("d3fcfc06-a6b6-4598-99b1-9a6445b976b3"),
		hvs_burntforest_birch01 = _sm_newUuid("b5f90719-fbca-4c59-89c3-187cdb5553d4"),
		hvs_farmables_cottonplant = _sm_newUuid("c591d94b-d7d1-4305-a9dd-76ef06d6fb49"),
		hvs_farmables_cornplant = _sm_newUuid("39a5aeba-a021-4117-8cad-e08ad159281d"),
		hvs_farmables_pigmentflower = _sm_newUuid("f7567939-d170-437e-b5c4-352ee9d5850d"),
		hvs_fillers_haypile_01 = _sm_newUuid("a1ee78c2-0b46-467c-927b-0b3c67cd9d90"),
		hvs_fillers_haypile_02 =  _sm_newUuid("57bfa2f0-f949-467e-bb85-a9eed63e2c41"),
		hvs_fillers_haypile_03 = _sm_newUuid("e6e501ac-e1d8-4304-bd9f-e60383eeba4a"),
		hvs_leafpile_01 = _sm_newUuid("6f9e92fd-07dd-4679-9b3c-4305b67e449f"),
		hvs_leafpile_02 = _sm_newUuid("bf8902e7-f163-4bfc-bb54-c2f11bb84bf7"),
		hvs_stone_small01 = _sm_newUuid("0d3362ae-4cb3-42ae-8a08-d3f9ed79e274"),
		hvs_stone_small02 = _sm_newUuid("f6b8e9b8-5592-46b6-acf9-86123bf630a9"),
		hvs_stone_small03 = _sm_newUuid("60ad4b7f-a7ef-4944-8a87-0844e6305513"),
		hvs_stone_medium01 = _sm_newUuid("ab5b947e-a223-4842-83dd-aa6b23ac2b86"),
		hvs_stone_medium02 = _sm_newUuid("5da6c862-8a5c-4b56-90d3-5f038d569c4a"),
		hvs_stone_medium03 = _sm_newUuid("90e0ef6a-8409-4459-8926-e5351d7da611"),
		hvs_stone_large01 = _sm_newUuid("ab362045-0444-4749-9f24-f5e850162857"),
		hvs_stone_large02 = _sm_newUuid("63fb92b3-e1dc-4b5c-9ed3-7b572bc01ca4"),
		hvs_stone_large03 = _sm_newUuid("67111401-1ee1-4bfb-8780-fa878352f90d"),
		harvestable_tree_birch01 = _sm_newUuid("c4ea19d3-2469-4059-9f13-3ddb4f7e0b79"),
		harvestable_tree_birch02 = _sm_newUuid("711c3e72-7ba1-4424-ae70-c13d23afe818"),
		harvestable_tree_birch03 = _sm_newUuid("a7aa52af-4276-4b2d-af44-36bc41864e04"),
		harvestable_tree_leafy01 = _sm_newUuid("91ec04ea-9bf7-4a9d-bb7f-3d0125ff78c7"),
		harvestable_tree_leafy02 = _sm_newUuid("4d482999-98b7-4023-a149-d47be709b8f7"),
		harvestable_tree_leafy03 = _sm_newUuid("3db0a60d-8668-4c8a-8dd2-f5ceb294977e"),
		harvestable_tree_pine01 = _sm_newUuid("8411caba-63db-4b93-ad67-7ae8e350d360"),
		harvestable_tree_pine02 = _sm_newUuid("1cb503a4-9306-412f-9e13-371bc634af60"),
		harvestable_tree_pine03 = _sm_newUuid("fa864e51-67db-4ac9-823b-cfbdf523375d"),
		harvestable_tree_spruce01 = _sm_newUuid("73f968f0-d3a3-4334-86a8-a90203a3a56d"),
		harvestable_tree_spruce02 = _sm_newUuid("86324c5b-e97a-41f6-aa2c-7c6462f1f2e7"),
		harvestable_tree_spruce03 = _sm_newUuid("27aa53ea-1e09-4251-a284-437f93850409")
	}
	return harvestables
end