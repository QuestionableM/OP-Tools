--[[
	Copyright (c) 2022 Questionable Mark
]]

--if FREE_CAM_OPTIONS then return end
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
			"#ffff00%s#ffffff/#ffff00%s#ffffff - change the chosen parameter of the function\n"..
			"#ffff00%s#ffffff - double the scrolling speed\n"
		):format(
			_sm_getKeyBind("Use"),
			_sm_getKeyBind("Create"),
			_sm_getKeyBind("Attack"),
			_sm_getKeyBind("Forward"),_sm_getKeyBind("StrafeLeft"),_sm_getKeyBind("Backward"),_sm_getKeyBind("StrafeRight"),
			_sm_getKeyBind("MenuItem0"),
			_sm_getKeyBind("MenuItem1"),
			_sm_getKeyBind("PreviousMenuItem"),_sm_getKeyBind("NextMenuItem"),
			_sm_getKeyBind("Jump")
		)
	)
end

local option_type_enum =
{
	value   = 1,
	list    = 2,
	boolean = 3,
	button  = 4
}

FREE_CAM_OPTIONS.function_id_enum =
{
	spawn_explosion = 1,
	teleport_char = 2,
	set_global_time = 3,
	spawn_unit = 4,
	hijack_char = 5,
	recover_player_chars = 6,
	lock_controls = 7,
	recover_off_world_chars = 8,
	set_char_speed = 9,
	set_char_property = 10,
	remove_unit = 11,
	spawn_harvestable = 12,
	remove_harvestable = 13,
	shoot_projectile = 14,
	teleport_to_cam = 15
}

local _sm_newUuid = sm.uuid.new
function FREE_CAM_OPTIONS.freeCamera_options()
	local functionTable = {
		[1] = {
			name = "Camera Functions",
			tab_name = "Camera Func.",
			individual_functions = true,
			subOptions = {
				[1] = {name = "Camera Speed"      , type = option_type_enum.value  , value = 1, changer = 0.01, minValue = 0, maxValue = 20},
				[2] = {name = "Camera Friction"   , type = option_type_enum.value  , value = 1, changer = 0.01, minValue = 0, maxValue = 1 },
				[3] = {name = "Camera Fov"        , type = option_type_enum.value  , value = 0, changer = 1, minValue = 1, maxValue = 179},
				[4] = {name = "Time"              , type = option_type_enum.value  , func = FREE_CAM_SUB.SUB_setTime    , update = FREE_CAM_SUB.SUB_timeUpdate       , value = sm.render.getOutdoorLighting(), changer = 0.01, minValue = 0, maxValue = 1},
				[5] = {name = "Move to Player"    , type = option_type_enum.value  , func = FREE_CAM_SUB.SUB_teleportCam, update = FREE_CAM_SUB.SUB_teleportCamUpdate, value = 0, changer = 1, minValue = 1, maxValue = #sm.player.getAllPlayers()},
				[6] = {name = "Enable Camera Data", type = option_type_enum.boolean, post_update = FREE_CAM_SUB.SUB_updateCameraData, value = OP.enable_free_cam_data}
			}
		},
		[2] = {
			name = "Explosion Spawner",
			tab_name = "Expl. Spawner",
			func = function(self, cur_category, category_id, option_id)
				local cam_pos = sm.camera.getPosition()
				local bool, result = sm.physics.raycast(cam_pos, cam_pos + sm.camera.getDirection() * 1000)
				if bool then
					local l_settings = cur_category.subOptions
					self.network:sendToServer("server_getStuff", {
						FREE_CAM_OPTIONS.function_id_enum.spawn_explosion,
						l_settings[1].value, --explosion level
						l_settings[2].value, --explosion radius
						l_settings[3].value, --explosion impulse strength
						l_settings[4].value, --explosion impulse radius
						result.pointWorld
					})
				end
			end,
			subOptions = {
				[1] = {name = "Explosion Level"           , type = option_type_enum.value, value = 5   , changer = 1  , minValue = 1  , maxValue = 99999999},
				[2] = {name = "Explosion Radius"          , type = option_type_enum.value, value = 0.3 , changer = 0.1, minValue = 0.3, maxValue = 50},
				[3] = {name = "Explosion Impulse Strength", type = option_type_enum.value, value = 1000, changer = 500, minValue = 10 , maxValue = 99999999},
				[4] = {name = "Explosion Impulse Radius"  , type = option_type_enum.value, value = 10  , changer = 1  , minValue = 1  , maxValue = 500}
			}
		},
		[3] = {
			name = "Projectile Launcher",
			tab_name = "Proj. Launcher",
			func = function(self, cur_category, category_id, option_id)
				local sub_opt = cur_category.subOptions
				local proj_id = sub_opt[1].value
				if proj_id > 0 then
					self.network:sendToServer("server_getStuff", {
						FREE_CAM_OPTIONS.function_id_enum.shoot_projectile,
						proj_id,          --projectile id
						sub_opt[3].value, --spread
						sub_opt[4].value, --proj per shot
						sm.camera.getPosition(),
						sm.camera.getDirection() * sub_opt[2].value
					})
				else
					OP.display("error", false, "Choose the projectile")
				end
			end,
			subOptions = {
				[1] = {name = "Projectile",           type = option_type_enum.list , value = 0  , maxValue = 20, listName = "projectiles"},
				[2] = {name = "Projectile Speed",     type = option_type_enum.value, value = 100, changer = 1, minValue = 1, maxValue = 99999999 },
				[3] = {name = "Spread",               type = option_type_enum.value, value = 1  , changer = 1, minValue = 0, maxValue = 180      },
				[4] = {name = "Projectiles Per Shot", type = option_type_enum.value, value = 1  , changer = 1, minValue = 1, maxValue = 100      }
			},
			listStorage = {
				projectiles = {
					[1]  = {name = "Potato",         id = "potato"       },
					[2]  = {name = "Small potato",   id = "smallpotato"  },
					[3]  = {name = "Fries",          id = "fries"        },
					[4]  = {name = "Tomato",         id = "tomato"       },
					[5]  = {name = "Carrot",         id = "carrot"       },
					[6]  = {name = "Redbeet",        id = "redbeet"      },
					[7]  = {name = "Broccoli",       id = "broccoli"     },
					[8]  = {name = "Pineapple",      id = "pineapple"    },
					[9]  = {name = "Orange",         id = "orange"       },
					[10] = {name = "Blueberry",      id = "blueberry"    },
					[11] = {name = "Banana",         id = "banana"       },
					[12] = {name = "Tape",           id = "tape"         },
					[13] = {name = "Explosive Tape", id = "explosivetape"},
					[14] = {name = "Water",          id = "water"        },
					[15] = {name = "Fertilizer",     id = "fertilizer"   },
					[16] = {name = "Chemical",       id = "chemical"     },
					[17] = {name = "Pesticide",      id = "pesticide"    },
					[18] = {name = "Seed",           id = "seed"         },
					[19] = {name = "Glowstick",      id = "glowstick"    },
					[20] = {name = "Epic Loot",      id = "epicloot"     }
				}
			}
		},
		[4] = {
			name = "Unit Spawner",
			tab_name = "Unit Spawner",
			individual_functions = true,
			subOptions = {
				[1] = {name = "Spawn Unit"             , type = option_type_enum.list   , func = FREE_CAM_SUB.SUB_creatureSpawner, value = 0, maxValue = 7, listName = "creatures"},
				[2] = {name = "Amount of Units"        , type = option_type_enum.value  , value = 1, changer = 1, minValue = 1, maxValue = 100},
				[3] = {name = "Spawn Without Spreading", type = option_type_enum.boolean, value = false},
				[4] = {name = "Remove Unit"            , type = option_type_enum.button , func = FREE_CAM_SUB.SUB_destroyUnit}
			},
			listStorage = {
				creatures = {
					[1] = {name = "Tapebot"    , uuid = _sm_newUuid("04761b4a-a83e-4736-b565-120bc776edb2"), spacing = 1  },
					[2] = {name = "Red Tapebot", uuid = _sm_newUuid("c3d31c47-0c9b-4b07-9bd4-8f022dc4333e"), spacing = 1  },
					[3] = {name = "Totebot"    , uuid = _sm_newUuid("8984bdbf-521e-4eed-b3c4-2b5e287eb879"), spacing = 1  },
					[4] = {name = "Haybot"     , uuid = _sm_newUuid("c8bfb8f3-7efc-49ac-875a-eb85ac0614db"), spacing = 1.5},
					[5] = {name = "Farmbot"    , uuid = _sm_newUuid("9f4fde94-312f-4417-b13b-84029c5d6b52"), spacing = 4.5},
					[6] = {name = "Worm"       , uuid = _sm_newUuid("48c03f69-3ec8-454c-8d1a-fa09083363b1"), spacing = 0.5},
					[7] = {name = "Woc"        , uuid = _sm_newUuid("264a563a-e304-430f-a462-9963c77624e9"), spacing = 2  }
				}
			}
		},
		[5] = {
			name = "Harvestable Functions",
			tab_name = "Harvest. Func.",
			individual_functions = true,
			subOptions = {
				[1] = {name = "Spawn Harvestable" , type = option_type_enum.list  , func = FREE_CAM_SUB.SUB_createHarvestable, value = 0, maxValue = 37, listName = "harvestableNames"},
				[2] = {name = "Remove Harvestable", type = option_type_enum.button, func = FREE_CAM_SUB.SUB_removeHarvestable}
			},
			listStorage = {
				harvestableNames = {
					[1] = {name = "Burnt Spike Tree 1" , uuid = _sm_newUuid("9ef210c0-ea30-4442-a1fe-924b5609b0cc")},
					[2] = {name = "Burnt Spike Tree 2" , uuid = _sm_newUuid("2bae67d4-c8ef-4c6e-a1a7-42281d0b7489")},
					[3] = {name = "Burnt Spruce Tree 1", uuid = _sm_newUuid("8f7a8108-2712-47b3-bce2-f25315165094")},
					[4] = {name = "Burnt Spruce Tree 2", uuid = _sm_newUuid("515aed88-0594-42b6-a352-617e5f5a3e45")},
					[5] = {name = "Burnt Spruce Tree 3", uuid = _sm_newUuid("2d5aa53d-eb9c-478c-a70f-c57a43753814")},
					[6] = {name = "Burnt Spruce Tree 4", uuid = _sm_newUuid("c08b553a-a917-4e26-bbb6-7b8523789cad")},
					[7] = {name = "Burnt Spruce Tree 5", uuid = _sm_newUuid("d3fcfc06-a6b6-4598-99b1-9a6445b976b3")},
					[8] = {name = "Burnt Birch Tree 1" , uuid = _sm_newUuid("b5f90719-fbca-4c59-89c3-187cdb5553d4")},
					[9] = {name = "Cotton Plant"       , uuid = _sm_newUuid("c591d94b-d7d1-4305-a9dd-76ef06d6fb49")},
					[10] = {name = "Corn Plant"        , uuid = _sm_newUuid("39a5aeba-a021-4117-8cad-e08ad159281d")},
					[11] = {name = "Pigment Flower"    , uuid = _sm_newUuid("f7567939-d170-437e-b5c4-352ee9d5850d")},
					[12] = {name = "Hay Pile 1"        , uuid = _sm_newUuid("a1ee78c2-0b46-467c-927b-0b3c67cd9d90")},
					[13] = {name = "Hay Pile 2"        , uuid = _sm_newUuid("57bfa2f0-f949-467e-bb85-a9eed63e2c41")},
					[14] = {name = "Hay Pile 3"        , uuid = _sm_newUuid("e6e501ac-e1d8-4304-bd9f-e60383eeba4a")},
					[15] = {name = "Leaf Pile 1"       , uuid = _sm_newUuid("6f9e92fd-07dd-4679-9b3c-4305b67e449f")},
					[16] = {name = "Leaf Pile 2"       , uuid = _sm_newUuid("bf8902e7-f163-4bfc-bb54-c2f11bb84bf7")},
					[17] = {name = "Small Stone 1"     , uuid = _sm_newUuid("0d3362ae-4cb3-42ae-8a08-d3f9ed79e274")},
					[18] = {name = "Small Stone 2"     , uuid = _sm_newUuid("f6b8e9b8-5592-46b6-acf9-86123bf630a9")},
					[19] = {name = "Small Stone 3"     , uuid = _sm_newUuid("60ad4b7f-a7ef-4944-8a87-0844e6305513")},
					[20] = {name = "Medium Stone 1"    , uuid = _sm_newUuid("ab5b947e-a223-4842-83dd-aa6b23ac2b86")},
					[21] = {name = "Medium Stone 2"    , uuid = _sm_newUuid("5da6c862-8a5c-4b56-90d3-5f038d569c4a")},
					[22] = {name = "Medium Stone 3"    , uuid = _sm_newUuid("90e0ef6a-8409-4459-8926-e5351d7da611")},
					[23] = {name = "Large Stone 1"     , uuid = _sm_newUuid("ab362045-0444-4749-9f24-f5e850162857")},
					[24] = {name = "Large Stone 2"     , uuid = _sm_newUuid("63fb92b3-e1dc-4b5c-9ed3-7b572bc01ca4")},
					[25] = {name = "Large Stone 3"     , uuid = _sm_newUuid("67111401-1ee1-4bfb-8780-fa878352f90d")},
					[26] = {name = "Birch Tree 1"      , uuid = _sm_newUuid("c4ea19d3-2469-4059-9f13-3ddb4f7e0b79")},
					[27] = {name = "Birch Tree 2"      , uuid = _sm_newUuid("711c3e72-7ba1-4424-ae70-c13d23afe818")},
					[28] = {name = "Birch Tree 3"      , uuid = _sm_newUuid("a7aa52af-4276-4b2d-af44-36bc41864e04")},
					[29] = {name = "Leafy Tree 1"      , uuid = _sm_newUuid("91ec04ea-9bf7-4a9d-bb7f-3d0125ff78c7")},
					[30] = {name = "Leafy Tree 2"      , uuid = _sm_newUuid("4d482999-98b7-4023-a149-d47be709b8f7")},
					[31] = {name = "Leafy Tree 3"      , uuid = _sm_newUuid("3db0a60d-8668-4c8a-8dd2-f5ceb294977e")},
					[32] = {name = "Pine Tree 1"       , uuid = _sm_newUuid("8411caba-63db-4b93-ad67-7ae8e350d360")},
					[33] = {name = "Pine Tree 2"       , uuid = _sm_newUuid("1cb503a4-9306-412f-9e13-371bc634af60")},
					[34] = {name = "Pine Tree 3"       , uuid = _sm_newUuid("fa864e51-67db-4ac9-823b-cfbdf523375d")},
					[35] = {name = "Spruce Tree 1"     , uuid = _sm_newUuid("73f968f0-d3a3-4334-86a8-a90203a3a56d")},
					[36] = {name = "Spruce Tree 2"     , uuid = _sm_newUuid("86324c5b-e97a-41f6-aa2c-7c6462f1f2e7")},
					[37] = {name = "Spruce Tree 3"     , uuid = _sm_newUuid("27aa53ea-1e09-4251-a284-437f93850409")}
				}    
			}
		},
		[6] = {
			name = "Character Functions",
			tab_name = "Char. Func.",
			individual_functions = true,
			subOptions = {
				[1] = {name = "Character Hijacker"  , type = option_type_enum.button, func = FREE_CAM_SUB.SUB_charHijacker},
				[2] = {name = "Character Speed"     , type = option_type_enum.value , func = FREE_CAM_SUB.SUB_charSpeed, value = 0, changer = 1, minValue = -100, maxValue = 100},
				[3] = {name = "Character Teleporter", type = option_type_enum.button, func = FREE_CAM_SUB.SUB_charTeleporter},
				[4] = {name = "Set Tumble"          , type = option_type_enum.button, func = FREE_CAM_SUB.SUB_CharFunctions, id = 1},
				[5] = {name = "Set Downed"          , type = option_type_enum.button, func = FREE_CAM_SUB.SUB_CharFunctions, id = 2},
				[6] = {name = "Set Swimming"        , type = option_type_enum.button, func = FREE_CAM_SUB.SUB_CharFunctions, id = 3, self_ex = true},
				[7] = {name = "Set Diving"          , type = option_type_enum.button, func = FREE_CAM_SUB.SUB_CharFunctions, id = 4}
			}
		},
		[7] = {
			name = "Player Functions",
			tab_name = "Player Func.",
			individual_functions = true,
			subOptions = {
				[1] = {name = "Recover Missing Player Characters", type = option_type_enum.button, func = FREE_CAM_SUB.SUB_playerRecover, gui_ex = true},
				[2] = {name = "Player Locker"                    , type = option_type_enum.button, func = FREE_CAM_SUB.SUB_playerLocker },
				[3] = {name = "Recover Off-world Players"        , type = option_type_enum.value , func = FREE_CAM_SUB.SUB_recoverOffWorldPlayers, gui_ex = true, update = FREE_CAM_SUB.SUB_recoverOffWorldPlayersUpdate, value = 710, changer = 10, minValue = 0, maxValue = 1400}
			}
		}
	}
	return functionTable
end

local client_function_id_enum =
{
	set_global_time = 1,
	lock_character = 2
}

function FREE_CAM_OPTIONS.client_callBacks()
	local callBackTable =
	{
		[1] = function(self, data) sm.render.setOutdoorLighting(data[2]) end,
		[2] = function(self, data) OP.toggleLockedCamera()               end
	}

	return callBackTable
end

local char_property_state_data = 
{
	[1] = {
		name = "Set Tumble",
		func = function(character)
			local l_output = not character:isTumbling()
			character:setTumbling(l_output)

			return l_output
		end
	},
	[2] = {
		name = "Set Downed",
		func = function(character)
			local l_output = not character:isDowned()
			character:setDowned(l_output)
			
			return l_output
		end
	},
	[3] = {
		name = "Set Swimming",
		func = function(character)
			local l_output = not character:isSwimming()
			character:setSwimming(l_output)

			return l_output
		end
	},
	[4] = {
		name = "Set Diving",
		func = function(character)
			local l_output = not character:isDiving()
			character:setDiving(l_output)

			return l_output
		end
	}
}

local local_server_table =
{
	[1] = function(self, data)
		local expl_level       = data[2]
		local expl_radius      = data[3]
		local expl_impulse_str = data[4]
		local expl_impulse_rad = data[5]
		local expl_pos         = data[6]
	
		OP.betterExplosion(expl_pos, expl_level, expl_radius, expl_impulse_str, expl_impulse_rad, "PropaneTank - ExplosionSmall", true)
	end,
	[2] = function(self, data, caller)
		local d_character = data[2]
		local d_char_pos  = data[3]

		if OP.exists(d_character) then
			d_character:setWorldPosition(d_char_pos)
			
			OP.print(("Character %s has been teleported. New position = %s"):format(d_character.id, d_char_pos))

			if d_character:isPlayer() then
				self:server_sendMsg(caller, { 2, d_character:getPlayer() })
			else
				self:server_sendMsg(caller, { 3, d_character.id })
			end
		else
			OP.display("ERROR: Tried to teleport a non-existant character")
		end
	end,
	[3] = function(self, data, caller)
		local d_value = data[2]

		self.network:sendToClients("client_getStuff", { client_function_id_enum.set_global_time, d_value })
		OP.print(("Time set to %s"):format(d_value))

		self:server_sendMsg(caller, { 4, d_value })
	end,
	[4] = function(self, data)
		local d_unit_id = data[2]
		local d_unit_amount = data[3]
		local d_no_spread = data[4]
		local d_unit_pos = data[5]
		local d_unit_rot = data[6]
		local d_unit_rot_yaw = d_unit_rot[2]

		local cur_category = self.camera.option_list[4]
		local cur_unit = cur_category.listStorage.creatures[d_unit_id]
		if cur_unit == nil then return end

		local _sm_unit_createUnit = sm.unit.createUnit
		local cur_unit_uuid = cur_unit.uuid

		if d_no_spread then
			for i = 1, d_unit_amount do
				pcall(_sm_unit_createUnit, cur_unit_uuid, d_unit_pos, d_unit_rot_yaw)
			end
		else
			local l_right_vec   = sm.vec3.new(1.0, 0.0, 0.0):rotateZ(d_unit_rot_yaw)
			local l_forward_vec = sm.vec3.new(0.0, 1.0, 0.0):rotateZ(d_unit_rot_yaw)

			local l_spacing = cur_unit.spacing

			local size_x = math.ceil(math.sqrt(d_unit_amount))
			local size_y = math.ceil(d_unit_amount / size_x)
			local _Offset = -(l_right_vec * (((l_spacing * size_y) / 2) + (l_spacing / 2)))

			local spawned = 0
			for x = 1, size_x do
				local l_forward_offset = (l_forward_vec * ((x * l_spacing) - l_spacing))

				for y = 1, size_y do
					local l_right_offset = (l_right_vec * y * l_spacing)
					local l_final_pos = d_unit_pos + l_right_offset + l_forward_offset + _Offset

					pcall(_sm_unit_createUnit, cur_unit_uuid, l_final_pos, d_unit_rot_yaw)
					spawned = spawned + 1

					if spawned >= d_unit_amount then return end
				end
			end
		end
	end,
	[5] = function(self, data, caller)
		local d_character = data[2]

		if OP.exists(d_character) then
			if d_character:isPlayer() then
				d_character:getPlayer():setCharacter(nil)

				local char = sm.character.createCharacter(caller, sm.world.getCurrentWorld(), d_character.worldPosition)
				caller:setCharacter(char)
			else
				caller:setCharacter(d_character)
			end

			OP.print(("Character %s has been hijacked"):format(d_character.id))
		else
			OP.print("ERROR: Tried to hijack a non-existant character")
		end
	end,
	[6] = function(self, data, caller)
		local amount = 0
		for k, player in pairs(sm.player.getAllPlayers()) do
			if player.character == nil then
				local char = sm.character.createCharacter(player, sm.world.getCurrentWorld(), sm.vec3.new(0, 0, 50))
				player:setCharacter(char)
				amount = amount + 1
			end
		end

		OP.print(("%s players got their characters back"):format(amount))

		self:server_sendMsg(caller, { 5, amount })
	end,
	[7] = function(self, data, caller) --local controls
		local d_player = data[2]
		if d_player == OP.server_admin then
			self:server_sendMsg(caller, { 6 })
			return
		end

		if d_player == caller then
			self:server_sendMsg(caller, { 7 })
			return
		end

		self.network:sendToClient(d_player, "client_getStuff", { client_function_id_enum.lock_character })
		OP.print(("locked controls for \"%s\""):format(d_player.name))
	end,
	[8] = function(self, data, caller) --recoverOff
		local d_safe_zone = data[2]

		local c_recovered_players = 0
		for k, player in pairs(sm.player.getAllPlayers()) do
			local pl_char = player.character

			if OP.exists(pl_char) and OP.checkWorldPosition(pl_char.worldPosition, d_safe_zone) then
				pl_char:setWorldPosition(sm.vec3.new(0, 0, 50))

				c_recovered_players = c_recovered_players + 1
			end
		end

		OP.print(("%s players have been returned back to the world"):format(c_recovered_players))

		self:server_sendMsg(caller, { 8, c_recovered_players })
	end,
	[9] = function(self, data, caller) --char speed
		local d_character = data[2]
		if OP.exists(d_character) then
			local d_value = data[3]
			d_character:setMovementSpeedFraction(d_value)

			OP.print(("character speed has been changed to %s (char id = %s)"):format(d_value, d_character.id))

			self:server_sendMsg(caller, { 9, d_value, d_character.id })
		else
			OP.print("ERROR: changing the speed for non-existant character")
		end
	end,
	[10] = function(self, data, caller) --char properties
		local d_character = data[2]
		if OP.exists(d_character) then
			local d_type_id = data[3]
			local l_state_data = char_property_state_data[d_type_id]
			local cur_setting = l_state_data.func(d_character)

			local l_state_name = l_state_data.name
			OP.print(("%s for character to %s, id = %s"):format(l_state_name, cur_setting, d_character.id))

			self:server_sendMsg(caller, { 10, d_type_id, cur_setting, d_character.id })
		else
			OP.print("ERROR: tried to down a non-existant character")
		end
	end,
	[11] = function(self, data) --unit delete
		local d_unit = data[2]
		if OP.exists(d_unit) then
			OP.print(("Unit %s has been destroyed"):format(d_unit.id))
			d_unit:destroy()
		else
			OP.print("ERROR: tried to delete a non-existant unit")
		end
	end,
	[12] = function(self, data) --spawn harvestable
		local d_hvs_id  = data[2]
		local d_hvs_pos = data[3] 

		local cur_category = self.camera.option_list[5]
		local cur_hvs = cur_category.listStorage.harvestableNames[d_hvs_id]
		if cur_hvs ~= nil then
			local cur_hvs_uuid = cur_hvs.uuid

			local l_rot_quat = sm.quat.angleAxis(math.rad(90), sm.vec3.new(1, 0, 0))
			l_rot_quat = l_rot_quat * sm.quat.angleAxis(math.rad(math.random(-36000, 36000) / 100), sm.vec3.new(0, 1, 0))

			pcall(sm.harvestable.createHarvestable, cur_hvs_uuid, d_hvs_pos, l_rot_quat)
		end
	end,
	[13] = function(self, data) --remove harvestable
		local d_hvs = data[2]
		if OP.exists(d_hvs) then
			OP.print(("Harvestable %s has been destroyed"):format(d_hvs.id))
			pcall(sm.harvestable.destroy, d_hvs)
		else
			OP.print("ERROR: tried to delete a non-existant harvestable")
		end
	end,
	[14] = function(self, data, caller) --shoot projectile
		local d_proj_id = data[2]
		local d_spread = data[3]
		local d_proj_per_shot = data[4]
		local d_cam_pos = data[5]
		local d_cam_dir = data[6]

		local cur_category = self.camera.option_list[3]
		local cur_projectile = cur_category.listStorage.projectiles[d_proj_id].id

		local _sm_gunSpread = sm.noise.gunSpread
		local _sm_projAttack = sm.projectile.projectileAttack

		for i = 1, d_proj_per_shot do
			local s_Dir = _sm_gunSpread(d_cam_dir, d_spread)
			_sm_projAttack(cur_projectile, 20, d_cam_pos, s_Dir, caller)
		end
	end,
	[15] = function(self, data, caller) --shoot projectile
		local d_player = data[2]
		local d_character = d_player:getCharacter()

		if OP.exists(d_character) then
			local cam_pos = data[3]
			d_character:setWorldPosition(cam_pos)

			OP.print(("%s has been teleported to camera"):format(d_player.name))
		else
			OP.print("ERROR: Tried to teleport a non-existant character")
		end
	end
}

function FREE_CAM_OPTIONS.server_callBacks()
	return local_server_table
end