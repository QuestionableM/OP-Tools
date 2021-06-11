--[[
	Copyright (c) 2021 Questionable Mark
]]

if AdminTool then return end
dofile("../libs/ScriptLoader.lua")
dofile("AdminTool_Functions.lua")
dofile("AdminToolGUI.lua")
AdminTool = class(AdminToolGUI)
AdminTool.connectionInput = sm.interactable.connectionType.none
AdminTool.connectionOutput = sm.interactable.connectionType.none

function AdminTool:server_onCreate()
	OP.setMainAdminTool(self.shape)
	self.allowedPlayers = {}
	self.serverFunctions = ADMIN_F.load_serverFunctions()
	self.server_admin = true
end

function AdminTool:SecondaryFunction(res, cOp)
	if cOp.pushMode and not cOp.explosionMode then
		if res.type == "body" then
			local direction = res.directionWorld
			local impulse = res:getBody():getMass() / 300
			sm.physics.applyImpulse(res:getShape(), direction * impulse, true)
		elseif res.type == "character" then
			local cur_char = res:getCharacter()
			local impulse = cur_char:getMass() / 25
			local direction = red.directionWorld * impulse

			if cur_char:isTumbling() then
				cur_char:applyTumblingImpulse(direction)
			else
				sm.physics.applyImpulse(cur_char, direction)
			end
		end
	elseif cOp.explosionMode and not cOp.pushMode then
		sm.physics.explode(res.pointWorld, 9999, 1, 10, 100000, "PropaneTank - ExplosionSmall", self.shape)
	end
end

function AdminTool:CompareObjectProperties(body, cOp)
	local destructible = (body:isDestructable() ~= not cOp.destructable)
	local buildable = (body:isBuildable() ~= not cOp.buildable)
	local paintable = (body:isPaintable() ~= not cOp.paintable)
	local connectable = (body:isConnectable() ~= not cOp.connectable)
	local liftable = (body:isLiftable() ~= not cOp.liftable)
	local usable = (body:isUsable() ~= not cOp.usable)
	local erasable = (body:isErasable() ~= not cOp.erasable)
	local convToDynamic = (body:isConvertibleToDynamic() ~= not cOp.convToDynamic)

	return (destructible or buildable or paintable or connectable or liftable or usable or erasable or convToDynamic)
end

function AdminTool:CreationProperties(res, cOp)
	local _body = res:getBody()
	local _bodies = sm.body.getCreationBodies(_body)

	local any_change = false

	for id, body in pairs(_bodies) do
		if self:CompareObjectProperties(body, cOp) then
			body:setDestructable(not cOp.destructable)
			body:setBuildable(not cOp.buildable)
			body:setPaintable(not cOp.paintable)
			body:setConnectable(not cOp.connectable)
			body:setLiftable(not cOp.liftable)
			body:setUsable(not cOp.usable)
			body:setErasable(not cOp.erasable)
			body:setConvertibleToDynamic(not cOp.convToDynamic)

			any_change = true
		end
	end

	if any_change then
		sm.effect.playEffect("DeleteAll", self.shape.worldPosition)
	end
end

function AdminTool.RemoveShape(shape, point)
	local s_uuid = shape:getShapeUuid()
	local effect_pos = shape:getWorldPosition()

	if sm.item.isBlock(s_uuid) then
		local blk_pos = shape:getClosestBlockLocalPosition(point)
		effect_pos = shape.body:transformPoint((blk_pos + sm.vec3.new(0.5, 0.5, 0.5)) * 0.25)

		shape:destroyBlock(blk_pos, sm.vec3.new(1, 1, 1), 0)
	else
		shape:destroyShape(0)
	end

	sm.effect.playEffect("Delete", effect_pos)
end

function AdminTool:SingleObjectMode(res, obj_v, cOp)
	local obj, col, mat, los, sta = ADMIN_F.checkFunctions(cOp.objectMode, cOp.paintMode, cOp.materialMode, cOp.loseOnly, cOp.staticOnly, obj_v, res)

	local cur_obj = res:getShape()
	local obj_uuid = tostring(cur_obj:getShapeUuid())
	local is_tool = OP.tool_uuids[obj_uuid]

	if not (obj and col and mat and los and sta) or is_tool then return end

	if not cOp.painterMode then
		self.RemoveShape(cur_obj, res.pointWorld)
	else
		local cur_col = self.shape.color
		if cur_obj:getColor() ~= cur_col then
			sm.effect.playEffect("Paint", cur_obj:getWorldPosition(), nil, nil, nil, {Color = cur_col})
			cur_obj:setColor(cur_col)
		end
	end
end

function AdminTool:AllObjectMode(res, obj_v, cOp)
	local c_body = res:getBody()
	local c_shapes = sm.body.getCreationShapes(c_body)

	for id, shape in pairs(c_shapes) do
		local obj, col, mat, los, sta = ADMIN_F.checkFunctions(cOp.objectMode, cOp.paintMode, cOp.materialMode, cOp.loseOnly, cOp.staticOnly, obj_v, shape)

		local b_uuid = tostring(shape:getShapeUuid())
		local is_tool = OP.tool_uuids[b_uuid]

		if obj and col and mat and los and sta and not is_tool then
			local shape_pos = shape:getWorldPosition()

			if not cOp.painterMode then
				shape:destroyShape(0)
				sm.effect.playEffect("DeleteAll", shape_pos)
			else
				local sel_col = self.shape.color
				if shape:getColor() ~= sel_col then
					shape:setColor(sel_col)
					sm.effect.playEffect("PaintAll", shape_pos, nil, nil, nil, {Color = sel_col})
				end
			end
		end
	end
end

function AdminTool:FirstFunction_Character(res, cOp)
	local _Character = res:getCharacter()
	local _Unit = _Character:getUnit()
	if not OP.exists(_Unit) or _Character:isPlayer() then return end
	
	local _CharPos = _Character:getWorldPosition()
	if not cOp.painterMode then
		_Unit:destroy()
		sm.effect.playEffect("Delete", _CharPos)
	else
		local _col = self.shape.color
		if _Character:getColor() ~= _col then
			_Character:setColor(_col)
			sm.effect.playEffect("Paint", _CharPos, nil, nil, nil, {Color = _col})
		end
	end
end

function AdminTool:FirstFunction(res, obj_v, cOp)
	if res.type == "body" and res:getBody() ~= self.shape.body then
		if not cOp.creationProp then
			if not cOp.thanosMode then
				self:SingleObjectMode(res, obj_v, cOp)
			else
				self:AllObjectMode(res, obj_v, cOp)
			end
		else
			self:CreationProperties(res, cOp)
		end
	elseif res.type == "joint" and res:getJoint() then
		local s_jnt = res:getJoint()
		local _shape = s_jnt:getShapeA()
		if not cOp.painterMode and OP.exists(_shape) then
			self.RemoveShape(_shape, res.pointWorld)
		end
	elseif res.type == "harvestable" and res:getHarvestable() then
		local _CurHvs = res:getHarvestable()
		if not cOp.painterMode and OP.exists(_CurHvs) then
			_CurHvs:destroy()
			sm.effect.playEffect("Delete", _CurHvs.worldPosition)
		end
	elseif res.type == "character" and res:getCharacter() then
		self:FirstFunction_Character(res, cOp)
	end
end

function AdminTool:ColorPickerFunction(res)
	if (res.type == "body" and res:getShape() ~= self.shape) or res.type == "joint" or res.type == "harvestable" or res.type == "character" then
		local _CurShapeColor = (res.type == "body" and res:getShape()) or (res.type == "harvestable" and res:getHarvestable()) or (res.type == "joint" and res:getJoint()) or (res.type == "character" and res:getCharacter())
		_CurShapeColor = _CurShapeColor:getColor()
		local _shape = self.shape

		if _CurShapeColor ~= _shape.color then
			sm.effect.playEffect("Paint", _shape.worldPosition, nil, nil, nil, {Color = _CurShapeColor})
			sm.effect.playEffect("Paint", res.pointWorld, nil, nil, nil, {Color = _CurShapeColor})
			_shape:setColor(_CurShapeColor)
		end
	end
end

function AdminTool:MainFunction(player, pl_settings, res, obj_v)
	local cOp = pl_settings.settings
	if player.character:isCrouching() and (cOp.explosionMode or cOp.pushMode) then
		if res:getCharacter() ~= player.character and res:getBody() ~= self.shape.body then
			self:SecondaryFunction(res, cOp)
		end
	else
		if not cOp.colorPickerMode then
			self:FirstFunction(res, obj_v, cOp)
		else
			self:ColorPickerFunction(res)
		end
	end
end

function AdminTool:server_onFixedUpdate(dt)
	if OP.getMainAdminTool() == nil then OP.setMainAdminTool(self.shape) end
	if OP.getMainAdminTool() == self.shape then
		local b, obj_v = sm.physics.raycast(self.shape.worldPosition, self.shape.worldPosition + self.shape.up)

		for playerId, player in pairs(sm.player.getAllPlayers()) do
			local _CurAlwd = self.allowedPlayers[player.id]

			if player.character and _CurAlwd ~= nil and _CurAlwd.player == player then
				local offset = player.character:isCrouching() and 0.269 or 0.565
				local pl_char = player.character

				local ray_pos = pl_char.worldPosition + sm.vec3.new(0, 0, offset)
				local ray_dir = pl_char.worldPosition + pl_char.direction * 2500

				local bool, res = sm.physics.raycast(ray_pos, ray_dir)
				if bool and player.character:isAiming() then
					self:MainFunction(player, _CurAlwd, res, obj_v)
				end
			end
		end
	end
end

function AdminTool:server_onDestroy()
	OP.deleteMainAdminTool(self.shape)
end

function AdminTool:server_networking(data)
	local cur_func = self.serverFunctions[data.mode]

	if type(cur_func) == "function" then
		cur_func(self, data)
	end
end

function AdminTool:client_updatePermission()
	return OP.getPermission("AdminTool") or self.server_admin
end

function AdminTool:isAllowed()
	return self.allowed or self.server_admin
end

function AdminTool:client_onCreate()
    self.allowed = self:client_updatePermission()

    if self:isAllowed() then
        sm.gui.displayAlertText("Check the workshop page of #ffff00OP Tools#ffffff for instructions")
        self.network:sendToServer("server_networking", {mode = "admin", player = sm.localPlayer.getPlayer()})
    end

    self:create_AT_GUI()
end

function AdminTool:client_onDestroy()
	local main_gui = (self.gui and self.gui.interface)
	local cp_gui = (self.color_picker_gui and self.color_picker_gui.interface)
	GUI_STUFF.close_and_destroy_dialogs({main_gui, cp_gui})

	if self:isAllowed() then
		sm.gui.displayAlertText("Admin Tool has been destroyed")
	end
end

local _setInteractionText = sm.gui.setInteractionText
local _getKeyBinding = sm.gui.getKeyBinding

function AdminTool:client_canInteract()
	if self:isAllowed() then
		local _useKey = _getKeyBinding("Use")
		local _tinkerKey = _getKeyBinding("Tinker")

		_setInteractionText("Press", _useKey, "to open Admin Tool GUI")
		_setInteractionText("Press", _tinkerKey, "to open color picker GUI")
	end

	_setInteractionText("", "Only allowed players can use this tool")
	_setInteractionText("")
	return true
end

function AdminTool:client_canErase()
	if self:isAllowed() then return true end

	sm.gui.displayAlertText("Only allowed players can delete this tool", 1)
	return false
end

function AdminTool:client_onFixedUpdate()
	self:client_updateWaitingDataLabel()
	local permission = self:client_updatePermission()

	if self.allowed ~= permission then
		self.allowed = permission

		local _mode = self:isAllowed() and "admin" or "r_admin"
		local loc_pl = sm.localPlayer.getPlayer()

		self.network:sendToServer("server_networking", {mode = _mode, player = loc_pl})
	end

	if self:isAllowed() then return end

	if GUI_STUFF.isGuiActive(self.gui and self.gui.interface) then
		self.gui.interface:close()
	end

	if GUI_STUFF.isGuiActive(self.color_picker_gui and self.color_picker_gui.interface) then
		self.color_picker_gui.interface:close()
	end
end

function AdminTool:client_onTinker(character, state)
	if not self:isAllowed() or not state then return end

	self:create_ColorPicker_GUI()
	sm.audio.play("Blueprint - Open")
end

function AdminTool:client_onInteract(character, state)
	if not self:isAllowed() or not state then return end

	self.gui.interface:open()
	self:client_requestButtonData()
end