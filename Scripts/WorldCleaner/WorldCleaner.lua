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

function WorldCleaner:server_clean(data)
	if not data.ready then
		self:server_countStuffToDelete(data)

		local stuff_del = self.server_stuffToDelete

		self.network:sendToClient(data.player, "client_displayMessage", {
			id = data.case,
			count = #stuff_del.shapes + #stuff_del.bodies + #stuff_del.units
		})
	else
		local stuffToDelete = self.server_stuffToDelete

		OP.deleteBodies(stuffToDelete.bodies, true)
		OP.deleteShapes(stuffToDelete.shapes, true)
		OP.deleteUnits(stuffToDelete.units, true)

		self:server_reloadDataTable()
	end
end

local message_table = {
	everything = "Lifts / Units / Shapes",
	all_b = "Shapes",
	lose_b = "Lose Bodies",
	op_t = "OP Tools",
	lift = "Lifts",
	unit = "Units",
	c_item = "Certain Shapes",
	c_creation = "Shapes"
}

function WorldCleaner:client_displayMessage(data)
	local cur_word = message_table[data.id]
	local cur_msg = ("%s were deleted"):format(cur_word)

	if data.id ~= "lift" then
		cur_msg = ("#ffff00%s#ffffff %s"):format(data.count, cur_msg)
	end

	sm.gui.displayAlertText(cur_msg, 2)

	self.network:sendToServer("server_clean", {ready = true})
end

function WorldCleaner:client_onCreate()
	self:client_updatePermission()
end

function WorldCleaner:client_updatePermission()
	self.allowed = OP.getPermission("WorldCleaner") or self.server_admin
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

function WorldCleaner:client_onFixedUpdate()
	self:client_updateAnimation()
	self:client_updatePermission()

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

function WorldCleaner:client_canInteract()
	if self:isAllowed() then
		local _useKey = sm.gui.getKeyBinding("Use")
		sm.gui.setInteractionText("Press", _useKey, "to open the GUI of World Cleaner")
		sm.gui.setInteractionText("")
		return true
	end

	sm.gui.setInteractionText("", "Only allowed players can use this tool")
	sm.gui.setInteractionText("")
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