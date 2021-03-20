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
function AdminTool.server_onCreate(self)
    OP.setMainAdminTool(self.shape)
    self.allowedPlayers = {}
    self.serverFunctions = ADMIN_F.load_serverFunctions()
    OP.setAdminFlag()
    self.server_admin = true
end
function AdminTool.server_onFixedUpdate(self,dt)
    if OP.getMainAdminTool() == nil then OP.setMainAdminTool(self.shape) end
    if OP.getMainAdminTool() == self.shape then
        local b, v = sm.physics.raycast(self.shape.worldPosition, self.shape.worldPosition + self.shape.up)
        for playerId, player in pairs(sm.player.getAllPlayers()) do
            local _CurAlwd = self.allowedPlayers[player.id]
            if player.character and _CurAlwd ~= nil and _CurAlwd.player == player then
                local offset = player.character:isCrouching() and 0.269 or 0.565
                local bool, res = sm.physics.raycast(player.character.worldPosition + sm.vec3.new(0, 0, offset), player.character.worldPosition + player.character.direction * 2500)
                if bool and player.character:isAiming() then
                    local cOp = _CurAlwd.settings
                    if player.character:isCrouching() and (cOp.explosionMode or cOp.pushMode) then
                        if res:getCharacter() ~= player.character and res:getBody() ~= self.shape.body then
                            if cOp.pushMode and not cOp.explosionMode then
                                if res.type == "body" then
                                    local direction = res.directionWorld
                                    local impulse = res:getBody():getMass() / 300
                                    sm.physics.applyImpulse(res:getShape(), direction * impulse, true)
                                elseif res.type == "character" then
                                    if res:getCharacter():isTumbling() then
                                        local direction = res.directionWorld
                                        local impulse = res:getCharacter():getMass() / 25
                                        res:getCharacter():applyTumblingImpulse(direction * impulse)
                                    else
                                        local direction = res.directionWorld
                                        local impulse = res:getCharacter():getMass() / 25
                                        sm.physics.applyImpulse(res:getCharacter(), direction * impulse)
                                    end
                                end
                            elseif cOp.explosionMode and not cOp.pushMode then
                                sm.physics.explode(res.pointWorld, 9999, 1, 10, 100000, "PropaneTank - ExplosionSmall", self.shape)
                            end
                        end
                    else
                        if not cOp.colorPickerMode then
                            if res.type == "body" and res:getBody() ~= self.shape.body then
                                if not cOp.creationProp then
                                    if not cOp.thanosMode then
                                        local obj, col, mat, los, sta = ADMIN_F.checkFunctions(cOp.objectMode, cOp.paintMode, cOp.materialMode, cOp.loseOnly, cOp.staticOnly, v, res)
                                        if (obj == nil or obj) and (col == nil or col) and (mat == nil or mat) and (los == nil or los) and (sta == nil or sta) and not OP.tool_uuids[tostring(res:getShape():getShapeUuid())] then
                                            if not cOp.painterMode then
                                                local _Shape = res:getShape()
                                                local _EffectPos = sm.vec3.zero()
                                                if sm.item.isBlock(_Shape:getShapeUuid()) then
                                                    local _Pos = _Shape:getClosestBlockLocalPosition(res.pointWorld)
                                                    _Shape:destroyBlock(_Pos, sm.vec3.new(1, 1, 1), 0)
                                                    _EffectPos = res.pointWorld
                                                else
                                                    _Shape:destroyShape(0)
                                                    _EffectPos = _Shape:getWorldPosition()
                                                end
                                                sm.effect.playEffect("Delete", _EffectPos)
                                            else
                                                if res:getShape():getColor() ~= self.shape.color then
                                                    sm.effect.playEffect("Paint", res:getShape():getWorldPosition(), nil, nil, nil, {Color = self.shape.color})
                                                    sm.shape.setColor(res:getShape(), self.shape.color)
                                                end
                                            end
                                        end
                                    else
                                        for id, body in pairs(sm.body.getCreationShapes(res:getBody())) do
                                            local obj, col, mat, los, sta = ADMIN_F.checkFunctions(cOp.objectMode, cOp.paintMode, cOp.materialMode, cOp.loseOnly, cOp.staticOnly, v, body)
                                            if (obj == nil or obj) and (col == nil or col) and (mat == nil or mat) and (los == nil or los) and (sta == nil or sta) and not OP.tool_uuids[tostring(body:getShapeUuid())] then
                                                if not cOp.painterMode then
                                                    sm.shape.destroyShape(body, 0)
                                                    sm.effect.playEffect("DeleteAll", body:getWorldPosition())
                                                else
                                                    if body:getColor() ~= self.shape.color then
                                                        sm.shape.setColor(body, self.shape.color)
                                                        sm.effect.playEffect("PaintAll", body:getWorldPosition(), nil, nil, nil, {Color = self.shape.color})
                                                    end
                                                end
                                            end
                                        end
                                    end
                                else
                                    for id, body in pairs(sm.body.getCreationBodies(res:getBody())) do
                                        body:setDestructable(not cOp.destructable)
                                        body:setBuildable(not cOp.buildable)
                                        body:setPaintable(not cOp.paintable)
                                        body:setConnectable(not cOp.connectable)
                                        body:setLiftable(not cOp.liftable)
                                        body:setUsable(not cOp.usable)
                                        body:setErasable(not cOp.erasable)
                                    end
                                end
                            elseif res.type == "harvestable" and res:getHarvestable() then
                                local _CurHvs = res:getHarvestable()
                                if not cOp.painterMode and OP.exists(_CurHvs) then
                                    _CurHvs:destroy()
                                    sm.effect.playEffect("Delete", _CurHvs.worldPosition)
                                end
                            elseif res.type == "character" and res:getCharacter() then
                                local _Character = res:getCharacter()
                                local _Unit = _Character:getUnit()
                                if OP.exists(_Unit) and not _Character:isPlayer() then
                                    if not cOp.painterMode then
                                        _Unit:destroy()
                                        sm.effect.playEffect("Delete", _Character:getWorldPosition())
                                    else
                                        if _Character:getColor() ~= self.shape.color then
                                            _Character:setColor(self.shape.color)
                                            sm.effect.playEffect("Paint", _Character:getWorldPosition(), nil, nil, nil, {Color = self.shape.color})
                                        end
                                    end
                                end
                            end
                        else
                            if (res.type == "body" and res:getShape() ~= self.shape) or res.type == "joint" or res.type == "harvestable" or res.type == "character" then
                                local _CurShapeColor = (res.type == "body" and res:getShape()) or (res.type == "harvestable" and res:getHarvestable()) or (res.type == "joint" and res:getJoint()) or (res.type == "character" and res:getCharacter())
                                _CurShapeColor = _CurShapeColor:getColor()
                                if tostring(_CurShapeColor) ~= tostring(self.shape.color) then
                                    sm.effect.playEffect("Paint", self.shape.worldPosition, nil, nil, nil, {Color = _CurShapeColor})
                                    sm.effect.playEffect("Paint", res.pointWorld, nil, nil, nil, {Color = _CurShapeColor})
                                    self.shape:setColor(_CurShapeColor)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
function AdminTool.server_onDestroy(self)
    OP.deleteMainAdminTool(self.shape)
end
function AdminTool.server_networking(self,data)
    if type(self.serverFunctions[data.mode]) == "function" then
        self.serverFunctions[data.mode](self, data)
    end
end
function AdminTool.client_onCreate(self)
    self.stuff = {}
    self.gui = ADMIN_F.load_guiInfo()
    self.allowed = OP.getPermission("AdminTool") or self.server_admin
    if self.allowed then
        sm.gui.displayAlertText("Check the workshop page of #ffff00OP Tools#ffffff for instructions")
        self.network:sendToServer("server_networking", {mode = "admin", player = sm.localPlayer.getPlayer()})
    end
    if GUI_STUFF.is_gui_supported() then
        self.new_gui = {}
        self.new_gui.buttonData = {
            FilterAll = {state = false, name = "Filter All", id = "thanosMode"},
            ColorFilter = {state = false, name = "Color Filter", id = "paintMode"},
            ObjectFilter = {state = false, name = "Object Filter", id = "objectMode"},
            MatFilter = {state = false, name = "Material Filter", id = "materialMode"},
            LoseOnly = {state = false, name = "Lose Only Filter", id = "loseOnly", pB = {"StaticOnly"}},
            StaticOnly = {state = false, name = "Static Only Filter", id = "staticOnly", pB = {"LoseOnly"}},
            PainterMode = {state = false, name = "Painter Mode", id = "painterMode", pB = {"ColorPicker"}},
            PushMode = {state = false, name = "Push Mode", id = "pushMode", pB = {"ExplMode"}},
            ExplMode = {state = false, name = "Explosion Mode", id = "explosionMode", pB = {"PushMode"}},
            ColorPicker = {state = false, name = "Color Picker Mode", id = "colorPickerMode", pB = {"PainterMode"}}
        }
        self:create_AT_GUI()
    end
end
function AdminTool.client_onDestroy(self)
    GUI_STUFF.close_and_destroy_dialogs({self.new_gui.interface})
    if self.allowed then sm.gui.displayAlertText("Admin tool has been destroyed") end
    if self.color then sm.localPlayer.getPlayer():getCharacter():setLockingInteractable(nil) end
end
function AdminTool.client_canInteract(self)
    if self.allowed then
        if not self.color then
            local _useKey = sm.gui.getKeyBinding("Use")
            local _tinkerKey = sm.gui.getKeyBinding("Tinker")
            if not GUI_STUFF.is_gui_supported() then
                local _crawlKey = sm.gui.getKeyBinding("Crawl")
                if self.gui.selectedPage == nil then
                    sm.gui.setInteractionText("Press", _useKey, "or", _crawlKey.." + ".._useKey, "to choose the option to change")
                else
                    sm.gui.setInteractionText("Press", _useKey, "to change the selected page, or", _crawlKey.." + ".._useKey, "to switch back to page menu")
                end
                if sm.localPlayer.getPlayer():getCharacter():isCrouching() then
                    sm.gui.setInteractionText("Press", _tinkerKey, "open a color picker")
                else
                    sm.gui.setInteractionText("Press", _tinkerKey, "to change the parameter")
                end
            else
                sm.gui.setInteractionText("Press", _useKey, "to open Admin Tool GUI")
                sm.gui.setInteractionText("Press", _tinkerKey, "to open color picker GUI")
            end
        else
            sm.gui.setInteractionText("")
            sm.gui.setInteractionText("")
        end
    else
        sm.gui.setInteractionText("", "Only allowed players can use this tool")
        sm.gui.setInteractionText("")
    end
    return true
end
function AdminTool.client_canErase(self)
    if self.allowed then return true end
    sm.gui.displayAlertText("Only allowed players can delete this tool", 1)
    return false
end
function AdminTool.client_onFixedUpdate(self)
    local permission = OP.getPermission("AdminTool") or self.server_admin
    if self.allowed ~= permission then
        self.allowed = permission
        if self.allowed then
            self.network:sendToServer("server_networking", {mode = "admin", player = sm.localPlayer.getPlayer()})
        else
            self.network:sendToServer("server_networking", {mode = "r_admin", player = sm.localPlayer.getPlayer()})
        end
    end
    local local_char = sm.localPlayer.getPlayer():getCharacter()
    if not self.allowed and self.color and local_char ~= nil and local_char:getLockingInteractable() == self.interactable then
        local_char:setLockingInteractable(nil)
        self.color = nil
    end
    if not GUI_STUFF.is_gui_supported() or not (self.new_gui and GUI_STUFF.isGuiActive(self.new_gui.interface)) or self.allowed then return end
    self.new_gui.interface:close()
end
function AdminTool.client_onAction(self, key, state)
    if state then
        if key == sm.interactable.actions.use then
            sm.localPlayer.getPlayer():getCharacter():setLockingInteractable(nil)
            local _Color = sm.color.new(("%02x%02x%02x"):format(self.color.rgb.r.value, self.color.rgb.g.value, self.color.rgb.b.value))
            self.network:sendToServer("server_networking", {mode = "setColor", color = _Color})
            OP.display("close", true, "Color picker has been closed")
            self.color = nil
        elseif key == sm.interactable.actions.item0 then self.color.rgb.r.bool = true
        elseif key == sm.interactable.actions.item1 then self.color.rgb.g.bool = true
        elseif key == sm.interactable.actions.item2 then self.color.rgb.b.bool = true
        elseif key == sm.interactable.actions.zoomIn or key == sm.interactable.actions.zoomOut then
            if self.color.rgb.r.bool or self.color.rgb.g.bool or self.color.rgb.b.bool then
                for color, b in pairs(self.color.rgb) do
                    if self.color.rgb[color].bool then
                        local mul = (1 * self.color.multiplier)
                        local subtractColor = self.color.rgb[color].value - mul
                        local addColor = self.color.rgb[color].value + mul
                        local isZoomIn = key == sm.interactable.actions.zoomIn
                        self.color.rgb[color].value = math.max(math.min(isZoomIn and addColor or subtractColor, 255), 0)
                    end
                end
                local col = self.color.rgb
                local hexCol = tostring(sm.color.new(col.r.value / 255, col.g.value / 255, col.b.value / 255)):sub(0, 6)
                OP.display("highlight", true, ("Color set to RGB:( #ff0000%s#ffffff/#00ff00%s#ffffff/#0000ff%s#ffffff ) HEX:(#%s %s #ffffff)"):format(col.r.value, col.g.value, col.b.value, hexCol, hexCol), 1)
            else
                sm.gui.displayAlertText("Select a color to change", 1)
            end
        elseif key == sm.interactable.actions.create then
            local _Color = sm.color.new(("%02x%02x%02x"):format(self.color.rgb.r.value, self.color.rgb.g.value, self.color.rgb.b.value))
            self.network:sendToServer("server_networking", {mode = "setColor", color = _Color})
        elseif key == sm.interactable.actions.jump then self.color.multiplier = 2
        elseif key == sm.interactable.actions.attack then
            local bool, result = sm.localPlayer.getRaycast(100)
            if bool and (result.type == "joint" or result.type == "body") then
                local col = result.type == "joint" and result:getJoint():getColor() or result:getShape():getColor()
                local hexCol = tostring(col):sub(1,6)
                local rgbCol = {
                    r = tonumber("0x"..hexCol:sub(1, 2)),
                    g = tonumber("0x"..hexCol:sub(3, 4)),
                    b = tonumber("0x"..hexCol:sub(5, 6))
                }
                for color, values in pairs(self.color.rgb) do
                    self.color.rgb[color].value = rgbCol[color]
                end
                sm.gui.displayAlertText(("Picked the color RGB:( #ff0000%s#ffffff/#00ff00%s#ffffff/#0000ff%s#ffffff ) HEX:(#%s %s #ffffff)"):format(rgbCol.r, rgbCol.g, rgbCol.b, hexCol, hexCol))
            end
        end
    elseif state == false then
        if key == sm.interactable.actions.item0 then self.color.rgb.r.bool = false
        elseif key == sm.interactable.actions.item1 then self.color.rgb.g.bool = false
        elseif key == sm.interactable.actions.item2 then self.color.rgb.b.bool = false
        elseif key == sm.interactable.actions.jump then self.color.multiplier = 1
        end
    end
    return true
end
function AdminTool.client_onTinker(self, character, state)
    if state and self.allowed then
        if not GUI_STUFF.is_gui_supported() then
            if character:isCrouching() then
                character:setLockingInteractable(self.interactable)
                local hex = tostring(self.shape.color)
                self.color = {
                    rgb = {
                        r = {value = tonumber("0x"..hex:sub(1, 2)), bool = false},
                        g = {value = tonumber("0x"..hex:sub(3, 4)), bool = false},
                        b = {value = tonumber("0x"..hex:sub(5, 6)), bool = false}
                    }, multiplier = 1
                }
                local message = ADMIN_F.load_adminTool_instruction()
                sm.gui.chatMessage(message)
                OP.display("open", true, ("Color picker mode activated, press #ffff00%s#ffffff to close it"):format(sm.gui.getKeyBinding("Use")))
            else
                if not self.gui.selectedPage then
                    if (self.gui.page + 1) > 0 then
                        self.gui.selectedPage = (self.gui.page + 1)
                        OP.display("open", true, ("#ffff00%s#ffffff option page has been selected"):format(self.gui.options[self.gui.selectedPage].name))
                    else
                        OP.display("error", true, "Choose an option page")
                    end
                else
                    if (self.gui.option_page + 1) > 0 then
                        self.gui.options[self.gui.selectedPage].params[self.gui.option_page + 1].bool = not self.gui.options[self.gui.selectedPage].params[self.gui.option_page + 1].bool
                        local guiOption = self.gui.options[self.gui.selectedPage].params[self.gui.option_page + 1]
                        if guiOption.pairedId and (guiOption.bool == true and self.gui.options[self.gui.selectedPage].params[guiOption.pairedId].bool == true) then
                            self.gui.options[self.gui.selectedPage].params[guiOption.pairedId].bool = false
                        end
                        local curBool = OP.bools[guiOption.bool]
                        OP.display(curBool.sound, true, ("(#ffff00%s#ffffff/#ffff00%s#ffffff) #ffff00%s#ffffff is %s"):format(self.gui.option_page + 1, #self.gui.options[self.gui.selectedPage].params, guiOption.name, curBool.string))
                        self.network:sendToServer("server_networking", {mode = "getTabData", id = guiOption.id, bool = guiOption.bool, pFunction = guiOption.pairedFunction, player = sm.localPlayer.getPlayer()})
                    else
                        OP.display("error", true, "Choose on option")
                    end
                end
            end
        else
            AdminToolGUI.create_ColorPicker_GUI(self)
            sm.audio.play("Blueprint - Open")
        end
    end
end
function AdminTool.client_onInteract(self, character, state)
    if state and self.allowed then
        if not GUI_STUFF.is_gui_supported() then
            if self.gui.selectedPage == nil then
                self.gui.page = ((character:isCrouching() and self.gui.page - 1) or self.gui.page + 1) % #self.gui.options
                OP.display("drag", true, ("(#ffff00%s#ffffff/#ffff00%s#ffffff) Selected page is #ffff00%s#ffffff"):format(self.gui.page + 1, #self.gui.options, self.gui.options[self.gui.page + 1].name))
            else
                if character:isCrouching() then
                    OP.display("close", true, "Switched back to page menu")
                    self.gui.selectedPage = nil
                    self.gui.option_page = -1
                    self.gui.page = -1
                else
                    self.gui.option_page = ((character:isCrouching() and self.gui.option_page - 1) or self.gui.option_page + 1) % #self.gui.options[self.gui.selectedPage].params
                    local selectedPage = self.gui.options[self.gui.selectedPage].params
                    OP.display("drag", true, ("(#ffff00%s#ffffff/#ffff00%s#ffffff) #ffff00%s#ffffff is %s"):format(self.gui.option_page + 1, #selectedPage, selectedPage[self.gui.option_page + 1].name, OP.bools[selectedPage[self.gui.option_page + 1].bool].string))
                end
            end
        else
            self.new_gui.interface:open()
            self:client_requestButtonData()
        end
    end
end