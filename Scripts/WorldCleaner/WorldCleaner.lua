--[[
	Copyright (c) 2023 Questionable Mark
]]

if WorldCleaner then return end

dofile("$CONTENT_DATA/Scripts/libs/ScriptLoader.lua")
dofile("WorldCleanerGUI.lua")

---@class WorldCleanerClass : ShapeClass
---@field gui GuiInterface
---@field client_initializeGui function
WorldCleaner = class(WorldCleanerGUI)
WorldCleaner.connectionInput = sm.interactable.connectionType.none
WorldCleaner.connectionOutput = sm.interactable.connectionType.none

function WorldCleaner:server_reloadDataTable(data, caller)
	if caller ~= nil then return end

	self.server_stuffToDelete = {units = {}, shapes = {}, bodies = {}}
end

function WorldCleaner:server_onCreate()
	self:server_reloadDataTable()
	self.server_admin = true
end

local clear_msg_ids = WorldCleanerGUI.clear_message_ids

local body_filter_mask  = clear_msg_ids.all_bodies + clear_msg_ids.lose_bodies + clear_msg_ids.cur_creation
local shape_filter_mask = clear_msg_ids.cert_creation + clear_msg_ids.op_tools

local _tabInsert = table.insert
function WorldCleaner:server_countStuffToDelete(mode, caller)
	if caller ~= nil then return end

	local cur_case = mode[2]

	local is_everything = (cur_case == clear_msg_ids.everything)
	local body_filter   = (bit.band(cur_case, body_filter_mask)  ~= 0)
	local shape_filter  = (bit.band(cur_case, shape_filter_mask) ~= 0)

	if is_everything or body_filter then
		local cur_cr_filter = (cur_case == clear_msg_ids.cur_creation)

		local all_creations = {}
		if cur_cr_filter then
			all_creations = { sm.body.getCreationBodies(self.shape.body) }
		else
			local all_bodies = sm.body.getAllBodies()
			all_creations = sm.body.getCreationsFromBodies(all_bodies)
		end

		local lose_filter = (cur_case == clear_msg_ids.lose_bodies)
		for k, creation in pairs(all_creations) do
			if cur_cr_filter or not lose_filter or (lose_filter and OP.isCreationDynamic(creation)) then
				for k, body in pairs(creation) do
					_tabInsert(self.server_stuffToDelete.bodies, body)
				end
			end
		end
	elseif shape_filter then
		local all_bodies = sm.body.getAllBodies()
		local mode_uuid = mode[3]

		for k, body in pairs(all_bodies) do
			local body_shapes = body:getShapes()

			for k, shape in pairs(body_shapes) do
				if (mode_uuid and shape.uuid == mode_uuid) or OP.tool_uuids[tostring(shape.uuid)] then
					_tabInsert(self.server_stuffToDelete.shapes, shape)
				end
			end
		end
	end

	if is_everything or cur_case == clear_msg_ids.units then
		local all_units = sm.unit.getAllUnits()

		for k, unit in pairs(all_units) do
			_tabInsert(self.server_stuffToDelete.units, unit)
		end
	end

	if is_everything or cur_case == clear_msg_ids.lifts then
		local all_players = sm.player.getAllPlayers()

		for k, player in pairs(all_players) do
			if OP.exists(player) then
				player:removeLift()
			end
		end
	end
end

function WorldCleaner:server_clean(data, caller)
	if not OP.getPlayerPermission(caller, "WorldCleaner") then
		self.network:sendToClient(caller, "client_errorNoPerm")
		return
	end

	if not data[1] then
		self:server_countStuffToDelete(data)

		local stuff_del = self.server_stuffToDelete
		local item_count = #stuff_del.shapes + #stuff_del.bodies + #stuff_del.units

		self.network:sendToClient(caller, "client_displayMessage", { data[2], item_count })
	else
		local stuffToDelete = self.server_stuffToDelete

		OP.deleteBodies(stuffToDelete.bodies, true)
		OP.deleteShapes(stuffToDelete.shapes, true)
		OP.deleteUnits(stuffToDelete.units, true)

		self:server_reloadDataTable()
	end
end

function WorldCleaner:client_errorNoPerm(msg_id)
	OP.display("error", false, "You do not have permission to use clean function!", 3)
end

local message_table = {
	[clear_msg_ids.everything   ] = {text = "Lifts / Units / Shapes"               },
	[clear_msg_ids.all_bodies   ] = {text = "Shapes"                               },
	[clear_msg_ids.lose_bodies  ] = {text = "Lose Bodies"                          },
	[clear_msg_ids.op_tools     ] = {text = "OP Tools"                             },
	[clear_msg_ids.lifts        ] = {text = "Lifts", snd = "ConnectTool - Released"},
	[clear_msg_ids.units        ] = {text = "Units", snd = "ConnectTool - Released"},
	[clear_msg_ids.cert_creation] = {text = "Certain Shapes"},
	[clear_msg_ids.cur_creation ] = {text = "Shapes"}
}

function WorldCleaner:client_displayMessage(data)
	local msg_id    = data[1]
	local obj_count = data[2]

	local cur_data = message_table[msg_id]
	local cur_msg = ("%s were deleted"):format(cur_data.text)

	sm.audio.play(cur_data.snd or "Blueprint - Delete")

	if msg_id ~= clear_msg_ids.lifts then
		cur_msg = ("#ffff00%s#ffffff %s"):format(obj_count, cur_msg)
	end

	sm.gui.displayAlertText(cur_msg, 2)

	self.network:sendToServer("server_clean", { true })
end

function WorldCleaner:client_onCreate()
	OP.getAdminPermission(self)
	self:client_updateClientPermission()
end

function WorldCleaner:client_isShapePlaced()
	local ray_pos = self.shape.worldPosition
	local ray_dir = ray_pos + self.shape.at * 0.25

	local hit, result = sm.physics.raycast(ray_pos, ray_dir)
	if hit and result.type == "body" then
		return result:getShape():getShapeUuid()
	end

	if not self.anim_duration then self.anim_duration = 62 end
	OP.display("error", false, "A shape / block has to be placed on top of World Cleaner in order to use that function")
end

function WorldCleaner:client_updateAnimation()
	if not self.anim_duration then return end

	if self.anim_duration % 21 == 20 then
		local _shape = self.shape
		sm.particle.createParticle("construct_welding", _shape.worldPosition + _shape.at * 0.25)
	end

	self.anim_duration = (self.anim_duration > 1 and self.anim_duration - 1) or nil
end

function WorldCleaner:client_updateClientPermission()
	self.allowed = OP.getClientPermission("WorldCleaner") or self.server_admin
end

function WorldCleaner:client_onFixedUpdate()
	self:client_updateClientPermission()
	self:client_updateAnimation()

	if not self:isAllowed() and GUI_STUFF.isGuiActive(self.gui) then
		self:client_closeAllGUIs()
	end
end

function WorldCleaner:isAllowed()
	return self.allowed or self.server_admin
end

function WorldCleaner:client_canErase()
	if self:isAllowed() then return true end

	sm.gui.displayAlertText("Only allowed players can delete this tool", 1)
	return false
end

function WorldCleaner:server_canErase()
	local pl_list    = OP.getShapeIntersections(self.shape)
	local can_remove = OP.areAllPlayersAllowed(pl_list, "WorldCleaner")

	return can_remove
end

local _gui_setInterText = sm.gui.setInteractionText
local cleaner_interact_error = OP.getHypertext("Only allowed players can use this tool")
function WorldCleaner:client_canInteract()
	if self:isAllowed() then
		local _useKey = sm.gui.getKeyBinding("Use", true)

		_gui_setInterText("Press", _useKey, "to open the GUI of World Cleaner")
		_gui_setInterText("")

		return true
	end

	_gui_setInterText(cleaner_interact_error)
	_gui_setInterText("")

	return false
end

function WorldCleaner:client_onInteract(character, state)
	if not self:isAllowed() or not state then return end

	self:client_initializeGui()
end

function WorldCleaner:client_closeAllGUIs()
	GUI_STUFF.close_and_destroy_dialogs({ self.gui })
end

function WorldCleaner:client_onDestroy()
	self:client_closeAllGUIs()
end