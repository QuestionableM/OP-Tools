--[[
	Copyright (c) 2021 Questionable Mark
]]

if WorldCleaner then return end
dofile("../libs/ScriptLoader.lua")
dofile("WorldCleanerGUI.lua")
WorldCleaner = class(WorldCleanerGUI)
WorldCleaner.connectionInput = sm.interactable.connectionType.none
WorldCleaner.connectionOutput = sm.interactable.connectionType.none

function WorldCleaner:server_reloadDataTable()
	self.server_stuffToDelete = {units = {}, shapes = {}, bodies = {}}
end

function WorldCleaner:server_onCreate()
	self:server_reloadDataTable()
	self.server_admin = true
end

local _tabInsert = table.insert
function WorldCleaner:server_countStuffToDelete(mode)
	local cur_case = mode.case
	local is_everything = cur_case == "everything"

	local body_filter = (cur_case == "all_b" or cur_case == "lose_b" or cur_case == "c_creation")
	local shape_filter = (cur_case == "c_item" or cur_case == "op_t")

	if is_everything or body_filter then
		local all_bodies = sm.body.getAllBodies()
		local cur_cr_filter = cur_case == "c_creation"

		local all_creations = cur_cr_filter and {sm.body.getCreationBodies(self.shape.body)} or sm.body.getCreationsFromBodies(all_bodies)

		local lose_filter = (cur_case == "lose_b")

		for k, creation in pairs(all_creations) do
			if cur_cr_filter or not lose_filter or (lose_filter and OP.isCreationDynamic(creation)) then
				for k, body in pairs(creation) do
					_tabInsert(self.server_stuffToDelete.bodies, body)
				end
			end
		end
	elseif shape_filter then
		local all_bodies = sm.body.getAllBodies()

		for k, body in pairs(all_bodies) do
			local body_shapes = body:getShapes()

			for k, shape in pairs(body_shapes) do
				if (mode.uuid and shape.uuid == mode.uuid) or OP.tool_uuids[tostring(shape.uuid)] then
					_tabInsert(self.server_stuffToDelete.shapes, shape)
				end
			end
		end
	end

	if is_everything or mode.case == "unit" then
		local all_units = sm.unit.getAllUnits()

		for k, unit in pairs(all_units) do
			_tabInsert(self.server_stuffToDelete.units, unit)
		end
	end

	if is_everything or mode.case == "lift" then
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
		self.network:sendToClient(caller, "client_errorMessage", "p_clean")
		return
	end

	if not data.ready then
		self:server_countStuffToDelete(data)

		local stuff_del = self.server_stuffToDelete
		local item_count = #stuff_del.shapes + #stuff_del.bodies + #stuff_del.units

		self.network:sendToClient(caller, "client_displayMessage", {id = data.case, count = item_count})
	else
		local stuffToDelete = self.server_stuffToDelete

		OP.deleteBodies(stuffToDelete.bodies, true)
		OP.deleteShapes(stuffToDelete.shapes, true)
		OP.deleteUnits(stuffToDelete.units, true)

		self:server_reloadDataTable()
	end
end

local error_msg_table = {
	p_clean = "You do not have permission to use clean function!"
}

function WorldCleaner:client_errorMessage(msg_id)
	local cur_msg = error_msg_table[msg_id]

	OP.display("error", false, cur_msg, 3)
end

local message_table = {
	everything = {text = "Lifts / Units / Shapes"},
	all_b = {text = "Shapes"},
	lose_b = {text = "Lose Bodies"},
	op_t = {text = "OP Tools"},
	lift = {text = "Lifts", snd = "ConnectTool - Released"},
	unit = {text = "Units", snd = "ConnectTool - Released"},
	c_item = {text = "Certain Shapes"},
	c_creation = {text = "Shapes"}
}

function WorldCleaner:client_displayMessage(data)
	local cur_data = message_table[data.id]
	local cur_msg = ("%s were deleted"):format(cur_data.text)
	local cur_snd = cur_data.snd

	sm.audio.play(cur_snd or "Blueprint - Delete")

	if data.id ~= "lift" then
		cur_msg = ("#ffff00%s#ffffff %s"):format(data.count, cur_msg)
	end

	sm.gui.displayAlertText(cur_msg, 2)

	self.network:sendToServer("server_clean", {ready = true})
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

	if self:isAllowed() then return end

	local new_gui = self.new_gui and self.new_gui.interface
	if GUI_STUFF.isGuiActive(self.gui_dialog) or GUI_STUFF.isGuiActive(new_gui) or GUI_STUFF.isGuiActive(self.gui_item_dialog) then
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
	local pl_list = OP.getShapeIntersections(self.shape)
	local can_remove = OP.areAllPlayersAllowed(pl_list, "WorldCleaner")

	return can_remove
end

local _gui_setInterText = sm.gui.setInteractionText
function WorldCleaner:client_canInteract()
	if self:isAllowed() then
		local _useKey = sm.gui.getKeyBinding("Use")
		_gui_setInterText("Press", _useKey, "to open the GUI of World Cleaner")
		_gui_setInterText("")
		return true
	end

	_gui_setInterText("", "Only allowed players can use this tool")
	_gui_setInterText("")
	return false
end

function WorldCleaner:client_onInteract(character, state)
	if not self:isAllowed() or not state then return end

	self:client_initializeGui()
end

function WorldCleaner:client_closeAllGUIs()
	GUI_STUFF.close_and_destroy_dialogs({self.gui_dialog, self.new_gui and self.new_gui.interface, self.gui_item_dialog})
end

function WorldCleaner:client_onDestroy()
	self:client_closeAllGUIs()
end