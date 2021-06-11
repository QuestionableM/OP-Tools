--[[
	Copyright (c) 2021 Questionable Mark
]]

if ADMIN_F then return end
ADMIN_F = class()

function ADMIN_F.server_load_playerFunctions()
	local player_functions = {
		thanosMode = false,
		paintMode = false,
		objectMode = false,
		painterMode = false,
		materialMode = false,
		loseOnly = false,
		staticOnly = false,
		creationProp = false,
		pushMode = false,
		explosionMode = false,
		destructable = false,
		buildable = false,
		paintable = false,
		connectable = false,
		liftable = false,
		usable = false,
		erasable = false,
		colorPickerMode = false,
		convToDynamic = false
	}
	return player_functions
end

function ADMIN_F.checkFunctions(object_mode, paint_mode, material_mode, lose_only, static_only, tool_raycast, other_raycast)
	local object, color, material, lose, static = nil

	local isValid = type(tool_raycast) == "RaycastResult" and tool_raycast.valid and tool_raycast.type == "body"
	local isRaycast = type(other_raycast) == "RaycastResult"

	local object_mode_secondArg = isRaycast and other_raycast:getShape():getShapeUuid() or other_raycast:getShapeUuid()
	local paint_mode_secondArg = isRaycast and other_raycast:getShape():getColor() or other_raycast:getColor()
	local material_mode_secondArg = isRaycast and other_raycast:getShape():getMaterial() or other_raycast:getMaterial()

	if object_mode then object = isValid and tool_raycast:getShape():getShapeUuid() == object_mode_secondArg end
	if paint_mode then color = isValid and tool_raycast:getShape():getColor() == paint_mode_secondArg end
	if material_mode then material = isValid and tool_raycast:getShape():getMaterial() == material_mode_secondArg end
	if lose_only and not static_only then lose = other_raycast:getBody():isDynamic() end
	if static_only and not lose_only then static = other_raycast:getBody():isStatic() end

	return (object == nil or object),
	(color == nil or color),
	(material == nil or material),
	(lose == nil or lose), 
	(static == nil or static)
end

function ADMIN_F.load_serverFunctions()
	local server_functions = {
		admin = function(self, data)
			self.allowedPlayers[data.player.id] = {
				player = data.player,
				settings = ADMIN_F.server_load_playerFunctions()
			}
		end;
		r_admin = function(self, data)
			if self.allowedPlayers[data.player.id] ~= nil and self.allowedPlayers[data.player.id].player == data.player then
				self.allowedPlayers[data.player.id] = nil
			end
		end;
		getTabData = function(self, data)
			if self.allowedPlayers[data.player.id] ~= nil and self.allowedPlayers[data.player.id].settings ~= nil then
				if data.pFunction and (data.bool == true and self.allowedPlayers[data.player.id].settings[data.pFunction] == true) then
					self.allowedPlayers[data.player.id].settings[data.pFunction] = false
				end
				self.allowedPlayers[data.player.id].settings[data.id] = data.bool
			end
		end;
		setColor = function(self, data)
			if tostring(data.color) ~= tostring(self.shape.color) then
				self.shape:setColor(data.color)
			end
		end
	}
	return server_functions
end