--[[
	Copyright (c) 2022 Questionable Mark
]]

if OP then return end

---@class OPDataClass
OP = class()

OP.enable_free_cam_data = true

local server_permissions = {}
OP.server_admin = nil

---@param self any
function OP.getAdminPermission(self)
	if self.server_admin then
		OP.server_admin = sm.localPlayer.getPlayer()
	end
end

function OP.getPlayerPermission(player, tool)
	if player == OP.server_admin then return true end

	local p_Permissions = server_permissions[player.id]
	if p_Permissions then
		local tool_perm = p_Permissions[tool]

		if tool_perm ~= nil then
			return tool_perm
		end
	end

	return false
end

function OP.setPlayerPermission(player, tool, state)
	local p_Id = player.id

	if server_permissions[p_Id] == nil then
		server_permissions[p_Id] = {
			AdminTool = false,
			WorldCleaner = false,
			PlayerKicker = false,
			FreeCamera = false
		}
	end

	if server_permissions[p_Id][tool] ~= nil then
		server_permissions[p_Id][tool] = state
	end
end

local client_permissions = {
	AdminTool = false,
	WorldCleaner = false,
	PlayerKicker = false,
	FreeCamera = false
}

function OP.setClientPermission(tool, state)
	if client_permissions[tool] ~= nil then
		client_permissions[tool] = state
	end
end

function OP.getClientPermission(tool)
	local permission = client_permissions[tool]
	if permission ~= nil then
		return permission
	end

	return false
end

local _sm_physRaycast = sm.physics.raycast
local function getCharacterRaycast(character, range)
	local offset = character:isCrouching() and 0.275 or 0.56
	local pos_offset = character.worldPosition + sm.vec3.new(0, 0, offset)

	return _sm_physRaycast(pos_offset, pos_offset + character.direction * range)
end

function OP.areAllPlayersAllowed(pl_list, tool)
	for k, player in pairs(pl_list) do
		if not OP.getPlayerPermission(player, tool) then
			return false
		end
	end

	return true
end

local _sm_exists = sm.exists
function OP.getShapeIntersections(shape)
	local out_list = {}

	local pl_list = sm.player.getAllPlayers()
	for k, player in pairs(pl_list) do
		local char = player:getCharacter()
		if char ~= nil and _sm_exists(char) then
			local hit, result = getCharacterRaycast(char, 7.5)
			if hit and result.type == "body" and result:getShape() == shape then
				table.insert(out_list, player)
			end
		end
	end

	return out_list
end

OP.bools =
{
	[true]  = {string = "#00c000true#ffffff" , sound = "Lever on" },
	[false] = {string = "#c00000false#ffffff", sound = "Lever off"}
}

OP.tool_uuids =
{
	["387edd9e-ed0f-4ea6-bf3c-2b40851225e7"] = true,
	["c8e4139d-b93d-4df5-a292-382ad21215a9"] = true,
	["26888ae6-d636-425d-87b9-1f75da083bfb"] = true,
	["94a05693-da51-4910-b311-705299dc3656"] = true,
	["07545436-fb40-459d-aaac-88ad5a9e4fc5"] = true
}

function OP.directionToRadians(dir)
	local result = {}

	result[1] = math.asin(dir.z) --pitch
	result[2] = math.atan2(dir.y, dir.x) - math.pi / 2 --yaw

	return result
end

local OP_LockedCamera = false
function OP.toggleLockedCamera()
	OP_LockedCamera = not OP_LockedCamera

	sm.localPlayer.setLockedControls(OP_LockedCamera)
	sm.gui.hideGui(OP_LockedCamera)
end

local OP_MainAdminTool = nil
function OP.setMainAdminTool(adminTool)
	if (OP_MainAdminTool ~= nil and OP_MainAdminTool == adminTool) then return end

	OP_MainAdminTool = adminTool
end

function OP.getMainAdminTool()
	return OP_MainAdminTool
end

function OP.deleteMainAdminTool(adminTool)
	if OP_MainAdminTool ~= adminTool then return end

	OP_MainAdminTool = nil
end

local OP_Sounds =
{
	error     = "WeldTool - Error",
	blip      = "Retrowildblip",
	highlight = "GUI Inventory highlight",
	noAmmo    = "PotatoRifle - NoAmmo",
	drag      = "GUI Item drag",
	release   = "GUI Item released",
	open      = "Blueprint - Open",
	close     = "Blueprint - Close",
	delete    = "Blueprint - Delete",
	build     = "Blueprint - Build"
}

function OP.display(sound, globalSound, text, duration)
	if sound then
		local snd_pos = (not globalSound and sm.camera.getPosition() + sm.camera.getDirection() or nil)
		local snd = OP_Sounds[sound] or sound

		sm.audio.play(snd, snd_pos)
	end

	if text then
		sm.gui.displayAlertText(text, duration or 3)
	end
end

function OP.getHypertext(string)
	return ("<p textShadow='false' bg='gui_keybinds_bg_orange' color='#66440C' spacing='9'>%s</p>"):format(string)
end

function OP.exists(cur_item)
	local success, result = pcall(_sm_exists, cur_item)
	if success and result == true then
		return true
	end

	return false
end

local _opExists = OP.exists
local _sm_applyImpulse = sm.physics.applyImpulse

---@param position Vec3
---@param ExplosionLevel integer
---@param explosionRadius integer
---@param explosionImpulse integer
---@param explosionMagnitude integer
---@param effect string
---@param pushPlayers boolean
function OP.betterExplosion(position, ExplosionLevel, explosionRadius, explosionImpulse, explosionMagnitude, effect, pushPlayers)
	sm.physics.explode(position, ExplosionLevel, explosionRadius, 1, 1, effect)

	for _, body in pairs(sm.body.getAllBodies()) do
		if _opExists(body) then
			local b_DistanceVec = position - body.worldPosition
			local b_Distance = b_DistanceVec:length()

			if b_Distance < explosionMagnitude and body:isDynamic() then
				local direction = b_DistanceVec:normalize()
				local impulse_strength = explosionImpulse - (explosionImpulse * (b_Distance / explosionMagnitude))

				_sm_applyImpulse(body, -(direction * impulse_strength), true)
			end
		end
	end

	if pushPlayers then
		for _, player in pairs(sm.player.getAllPlayers()) do
			local pl_char = player:getCharacter()

			if _opExists(pl_char) then
				local p_DistanceVec = position - pl_char.worldPosition
				local p_Distance = p_DistanceVec:length()

				if p_Distance < explosionMagnitude then
					local direction = p_DistanceVec:normalize()
					local p_ImpulseStrength = explosionImpulse - (explosionImpulse * (p_Distance / explosionMagnitude))

					_sm_applyImpulse(pl_char, -(direction * (p_ImpulseStrength / 10)), false)
				end
			end
		end
	end
end

function OP.checkWorldPosition(cPos, limit)
	if math.abs(cPos.x) > limit or math.abs(cPos.y) > limit or math.abs(cPos.z) > limit then return true end
	return false
end

function OP.print(text) print("[OPTools] "..text) end

function OP.getAllPlayers_exc()
	local all_players = sm.player.getAllPlayers()
	local loc_player = sm.localPlayer.getPlayer()
	
	for id, player in pairs(all_players) do
		if player == loc_player then
			all_players[id] = nil
			return all_players
		end
	end

	return all_players
end

local _playEffect = sm.effect.playEffect
function OP.deleteBodies(body_table, show_effect)
	for k, body in pairs(body_table) do
		if _opExists(body) then
			local body_shapes = body:getShapes()

			for k, shape in pairs(body_shapes) do
				if _opExists(shape) then
					if show_effect then
						_playEffect("DeleteAll", shape.worldPosition)
					end

					shape:destroyShape(0)
				end
			end
		end

		body_table[k] = nil
	end
end

function OP.deleteShapes(shape_table, show_effect)
	for shape_id, shape in pairs(shape_table) do
		if _opExists(shape) then
			if show_effect then
				_playEffect("DeleteAll", shape.worldPosition)
			end

			shape:destroyShape(0)
		end
		
		shape_table[shape_id] = nil
	end
end

function OP.deleteUnits(unit_table, show_effect)
	for unit_id, unit in pairs(unit_table) do
		if _opExists(unit) and unit.character then
			if show_effect then
				_playEffect("DeleteAll", unit.character.worldPosition)
			end

			unit:destroy()
		end

		unit_table[unit_id] = nil
	end
end

function OP.isCreationStatic(creation)
	for id, body in pairs(creation) do
		if body:isDynamic() then return false end
	end
	return true
end

function OP.isCreationDynamic(creation)
	for id, body in pairs(creation) do
		if body:isStatic() then return false end
	end
	return true
end

function OP.isUnit(character)
	if not OP.exists(character) then return false end

	return OP.exists(character:getUnit())
end

print("[OPTools] Function library has been loaded")