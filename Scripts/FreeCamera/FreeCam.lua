--[[
    Copyright (c) 2021 Questionable Mark
]]

if FreeCam then return end
dofile("../libs/ScriptLoader.lua")
dofile("FreeCamFunctions.lua")
dofile("FreeCam_SubFunctions.lua")
FreeCam = class()
FreeCam.connectionInput = sm.interactable.connectionType.none
FreeCam.connectionOutput = sm.interactable.connectionType.none
function FreeCam.server_onCreate(self)
    self.units = FREE_CAM_OPTIONS.loadUnitInfo()
    self.harvestables = FREE_CAM_OPTIONS.loadHarvestableInfo()
    self.serverFunctions = FREE_CAM_OPTIONS.server_callBacks()
    OP.setAdminFlag()
    self.server_admin = true
end
function FreeCam.client_onCreate(self)
    self:updateCamera()
    self.allowed = OP.getPermission("FreeCamera") or self.server_admin
end
local function limitData(value, min_value, max_value)
    return math.max(math.min(value, max_value), min_value)
end
function FreeCam.updateCamera(self)
    self.camera = {
        speed = sm.vec3.zero(),
        state = false,
        movement = {x = {0, 0}, y = {0, 0}},
        multiplier = 1,
        mode = {
            page = -1,
            optionPage = -1,
            options = FREE_CAM_OPTIONS.freeCamera_options()
        },
        callBacks = FREE_CAM_OPTIONS.client_callBacks()
    }
end
function FreeCam.client_getStuff(self, data)
    if type(self.camera.callBacks[data.type]) == "function" then
        self.camera.callBacks[data.type](self, data)
    end
end
function FreeCam.server_getStuff(self, data)
    if type(self.serverFunctions[data.type]) == "function" then
        self.serverFunctions[data.type](self, data)
    end
end
function FreeCam.client_onAction(self, movement, state)
    if not self.allowed then return end
    if state then
        if movement == sm.interactable.actions.use or movement == sm.interactable.actions.exit then
            sm.localPlayer.getPlayer():getCharacter():setLockingInteractable(nil)
            sm.camera.setCameraState(sm.camera.state.default)
            self:updateCamera()
            OP.print("free camera has been turned off")
        end
        if self.camera.move_target then return end
        if movement == sm.interactable.actions.forward and self.camera.x ~= -1 then self.camera.movement.x[1] = 1
        elseif movement == sm.interactable.actions.backward and self.camera.x ~= 1 then self.camera.movement.x[2] = 1
        elseif movement == sm.interactable.actions.left and self.camera.y ~= 1 then self.camera.movement.y[1] = 1
        elseif movement == sm.interactable.actions.right and self.camera.y ~= -1 then self.camera.movement.y[2] = 1
        elseif movement == sm.interactable.actions.zoomIn or movement == sm.interactable.actions.zoomOut then
            if self.camera.mode.page > -1 then
                local currentOption = self.camera.mode.options[self.camera.mode.page + 1]
                if type(currentOption.values) == "table" then
                    local table = self.camera.mode.options[self.camera.mode.page + 1]
                    local isZoomIn = movement == sm.interactable.actions.zoomIn
                    local mul = subTable.values.changer * self.camera.multiplier
                    table.values.value = limitData(isZoomIn and table.valus.value + mul or table.values.value - mul, table.values.minValue, table.values.maxValue)
                    if type(table.update) == "function" then
                        local dataToSend = {value = table.values.value}
                        self.camera.mode.options[self.camera.mode.page + 1].update(self, dataToSend, table.name)
                    end
                    if table.values.disableText ~= true then
                        OP.display("highlight", false, ("#ffff00%s#ffffff set to #ffff00%.2f#ffffff"):format(table.name, table.values.value))
                    end
                elseif type(currentOption.subOptions) == "table" then
                    if self.camera.mode.optionPage > -1 then
                        local _CurOption = currentOption.subOptions[self.camera.mode.optionPage + 1]
                        local _ValuesType = type(_CurOption.values)

                        if _ValuesType == "table" then
                            local isZoomIn = movement == sm.interactable.actions.zoomIn
                            local mul = _CurOption.values.changer * self.camera.multiplier
                            _CurOption.values.value = limitData(isZoomIn and _CurOption.values.value + mul or _CurOption.values.value - mul, _CurOption.values.minValue, _CurOption.values.maxValue)
                            if type(currentOption.update) == "function" then
                                local dataToSend = {
                                    value = _CurOption.values.value,
                                    table = currentOption,
                                    subTab = _CurOption
                                }
                                self.camera.mode.options[self.camera.mode.page + 1].update(self, dataToSend, _CurOption.name)
                            end
                            if _CurOption.disableText ~= true then
                                if type(currentOption.numberNames) == "table" and currentOption.numberNames[_CurOption.values.displayNames] then
                                    OP.display("highlight", false, ("[#ffff00%s#ffffff/#ffff00%s#ffffff] #ffff00%s#ffffff set to #ffff00%s#ffffff"):format(_CurOption.values.value, #currentOption.numberNames[_CurOption.values.displayNames], _CurOption.name, currentOption.numberNames[_CurOption.values.displayNames][_CurOption.values.value].name))
                                else
                                    OP.display("highlight", false, ("#ffff00%s#ffffff set to #ffff00%.2f#ffffff"):format(_CurOption.name, _CurOption.values.value))
                                end
                            end
                        elseif _ValuesType == "boolean" then
                            _CurOption.values = not _CurOption.values
                            local _CurBool = OP.bools[_CurOption.values]
                            OP.display(_CurBool.sound, false, ("#ffff00%s#ffffff set to #ffff00%s#ffffff"):format(_CurOption.name, _CurBool.string))
                        else
                            sm.gui.displayAlertText("This option has no changable values")
                        end
                    else
                        sm.gui.displayAlertText("Choose an option")
                    end
                else
                    sm.gui.displayAlertText("This parameter has no changable values")
                end
            else
                sm.gui.displayAlertText("Choose a parameter")
            end
        elseif movement == sm.interactable.actions.attack and ((self.camera.activationTime and (sm.game.getCurrentTick() - self.camera.activationTime) > 5) or not self.camera.activationTime) then
            self.camera.activationTime = sm.game.getCurrentTick()
            self.network:sendToServer("server_getStuff", {type = "spawnChar", player = sm.localPlayer.getPlayer(), position = self.camera.position, dir = OP.directionToRadians(sm.camera.getDirection())})
        elseif movement == sm.interactable.actions.create then
            if self.camera.mode.page > -1 then
                local currentOption = self.camera.mode.options[self.camera.mode.page + 1]
                if type(currentOption.func) == "function" then
                    local otherData = {
                        option = self.camera.mode.page,
                        option_page = self.camera.mode.optionPage
                    }
                    self.camera.mode.options[self.camera.mode.page + 1].func(self, currentOption, otherData)
                else
                    OP.display("noAmmo", false, "This parameter doesn't have a function")
                end
            else
                OP.display("noAmmo", false, "Choose an option")
            end
        elseif movement == sm.interactable.actions.item0 then
            self.camera.mode.page = (self.camera.mode.page + 1) % (#self.camera.mode.options)
            local selectedOption = self.camera.mode.options[self.camera.mode.page + 1]
            if type(selectedOption.subOptions) == "table" then
                OP.display("drag", false, ("[#ffff00%s#ffffff/#ffff00%s#ffffff] Camera option set to #ffff00%s#ffffff\npress #ffff00%s#ffffff to change its parameters"):format(self.camera.mode.page + 1, #self.camera.mode.options, selectedOption.name, sm.gui.getKeyBinding("MenuItem1")))
            else
                if type(selectedOption.values) == "table" then
                    OP.display("drag", false, ("[#ffff00%s#ffffff/#ffff00%s#ffffff] Camera option set to #ffff00%s#ffffff\nit can be changed with #ffff00%s#ffffff/#ffff00%s#ffffff or #ffff00%s#ffffff/#ffff00%s#ffffff"):format(self.camera.mode.page + 1, #self.camera.mode.options, selectedOption.name, sm.gui.getKeyBinding("PreviousMenuItem"), sm.gui.getKeyBinding("NextMenuItem"), sm.gui.getKeyBinding("ZoomIn"), sm.gui.getKeyBinding("ZoomOut")))
                else
                    OP.display("drag", false, ("[#ffff00%s#ffffff/#ffff00%s#ffffff] Camera option set to #ffff00%s#ffffff"):format(self.camera.mode.page + 1, #self.camera.mode.options, selectedOption.name))
                end
            end
            self.camera.mode.optionPage = -1
        elseif movement == sm.interactable.actions.item1 then
            if self.camera.mode.page > -1 then
                local selectedOption = self.camera.mode.options[self.camera.mode.page + 1]
                if type(selectedOption.subOptions) == "table" then
                    self.camera.mode.optionPage = (self.camera.mode.optionPage + 1) % (#selectedOption.subOptions)

                    local _CurrentOption = selectedOption.subOptions[self.camera.mode.optionPage + 1]
                    local _ValuesType = type(_CurrentOption.values)

                    if _ValuesType == "table" or _ValuesType == "boolean" then
                        OP.display("release", false, ("[#ffff00%s#ffffff/#ffff00%s#ffffff] #ffff00%s#ffffff can be changed with #ffff00%s#ffffff/#ffff00%s#ffffff or #ffff00%s#ffffff/#ffff00%s#ffffff now"):format(self.camera.mode.optionPage + 1, #selectedOption.subOptions, selectedOption.subOptions[self.camera.mode.optionPage + 1].name, sm.gui.getKeyBinding("PreviousMenuItem"), sm.gui.getKeyBinding("NextMenuItem"), sm.gui.getKeyBinding("ZoomIn"), sm.gui.getKeyBinding("ZoomOut")))
                    else
                        OP.display("release", false, ("[#ffff00%s#ffffff/#ffff00%s#ffffff] #ffff00%s#ffffff is selected"):format(self.camera.mode.optionPage + 1, #selectedOption.subOptions, selectedOption.subOptions[self.camera.mode.optionPage + 1].name))
                    end
                else
                    OP.display("error", false, ("#ffff00%s#ffffff has no changable options yet"):format(selectedOption.name))
                end
            else
                OP.display("error", false, "Choose a function to change its parameters")
            end
        elseif movement == sm.interactable.actions.jump then self.camera.multiplier = 2
        end
    else
        if movement == sm.interactable.actions.forward then self.camera.movement.x[1] = 0
        elseif movement == sm.interactable.actions.backward then self.camera.movement.x[2] = 0
        elseif movement == sm.interactable.actions.left then self.camera.movement.y[1] = 0
        elseif movement == sm.interactable.actions.right then self.camera.movement.y[2] = 0
        elseif movement == sm.interactable.actions.jump then self.camera.multiplier = 1
        end
    end
    return true
end

function FreeCam.client_onUpdate(self, dt)
    if self.camera.state then
        local playerCharacter = sm.localPlayer.getPlayer():getCharacter()
        if self.camera.move_target then
            local _MovT = self.camera.move_target
            local _DiffVec = self.camera.position - _MovT.worldPosition
            local _IsOutOfTime = ((sm.game.getCurrentTick() - self.camera.move_target_activation) > 140)
            if not _IsOutOfTime and _DiffVec:length() > 0.05 and OP.exists(_MovT) then
                self.camera.speed = sm.vec3.zero()
                self.camera.movement.x = {0, 0}
                self.camera.movement.y = {0, 0}
                self.camera.position = sm.vec3.lerp(self.camera.position, _MovT.worldPosition, 0.2)
                sm.camera.setDirection(sm.vec3.lerp(sm.camera.getDirection(), _MovT.direction, 0.2))
                sm.camera.setPosition(self.camera.position)
            else
                if _IsOutOfTime then
                    OP.display("error", false, "Couldn't get to the destination in the set amount of time.\nSkipping the animation...")
                    self.camera.position = _MovT.worldPosition
                end
                self.camera.move_target = nil
                self.camera.move_target_activation = nil
            end
        else
            if playerCharacter and self.allowed then
                local speedVal = self.camera.mode.options[1].subOptions[1].values.value
                local friction = self.camera.mode.options[1].subOptions[2].values.value
                local speed_forward = (sm.camera.getDirection() / 5) * speedVal
                local speed_sideways = (sm.camera.getRight() / 5) * speedVal
                local cam_mov = self.camera.movement
                if cam_mov.x[1] == 1 then self.camera.speed = self.camera.speed + speed_forward end
                if cam_mov.x[2] == 1 then self.camera.speed = self.camera.speed - speed_forward end
                if cam_mov.y[1] == 1 then self.camera.speed = self.camera.speed - speed_sideways end
                if cam_mov.y[2] == 1 then self.camera.speed = self.camera.speed + speed_sideways end
                self.camera.position = self.camera.position + self.camera.speed
                self.camera.speed = self.camera.speed * (1 - (friction * 0.5))
                sm.camera.setPosition(self.camera.position)
                sm.camera.setDirection(playerCharacter.direction)
            else
                self:updateCamera()
                sm.camera.setCameraState(sm.camera.state.default)
                playerCharacter:setLockingInteractable(nil)
            end
        end
        if playerCharacter:getLockingInteractable() == nil then
            if (sm.game.getCurrentTick() - self.camera.activationTime) > 20 then
                self:updateCamera()
                sm.camera.setCameraState(sm.camera.state.default)
            else
                playerCharacter:setLockingInteractable(self.interactable)
            end
        end
    end
end
function FreeCam.client_onFixedUpdate(self) self.allowed = OP.getPermission("FreeCamera") or self.server_admin end
function FreeCam.client_onInteract(self, character, state)
    if state and self.allowed then
        self.camera.activationTime = sm.game.getCurrentTick()
        self.camera.position = sm.camera.getPosition()
        character:setLockingInteractable(self.interactable)
        sm.camera.setCameraState(sm.camera.state.cutsceneTP)
        sm.camera.setPosition(self.camera.position)
        sm.camera.setDirection(sm.camera.getDirection())
        self.camera.state = true
        OP.print("free camera mode enabled")
        OP.display("blip", false, ("Free camera mode enabled, press #ffff00%s#ffffff to change the function and #ffff00%s#ffffff to change its parameters\nUse #ffff00%s#ffffff/#ffff00%s#ffffff or #ffff00%s#ffffff/#ffff00%s#ffffff to change the value of the parameter"):format(sm.gui.getKeyBinding("MenuItem0"),sm.gui.getKeyBinding("MenuItem1"),sm.gui.getKeyBinding("PreviousMenuItem"),sm.gui.getKeyBinding("NextMenuItem"),sm.gui.getKeyBinding("ZoomIn"),sm.gui.getKeyBinding("ZoomOut")),5)
        FREE_CAM_OPTIONS.display_guide()
    end
end
function FreeCam.client_onDestroy(self)
    sm.localPlayer.setLockedControls(false)
    if self.camera.state then
        sm.localPlayer.getPlayer():getCharacter():setLockingInteractable(nil)
        if sm.camera.getCameraState() ~= sm.camera.state.default then
            sm.camera.setCameraState(sm.camera.state.default)
        end
    end
end
function FreeCam.client_canErase(self)
    if self.allowed then return true end
    sm.gui.displayAlertText("Only allowed players can delete this tool", 1)
    return false
end
function FreeCam.client_canInteract(self)
    if self.allowed then
        if self.camera.state then
            sm.gui.setInteractionText("")
            sm.gui.setInteractionText("")
        else
            sm.gui.setInteractionText("Press", sm.gui.getKeyBinding("Use"), "to enable free camera mode")
            sm.gui.setInteractionText("")
        end
        return true
    end
    sm.gui.setInteractionText("", "Only allowed players can use this tool")
    sm.gui.setInteractionText("")
    return false
end