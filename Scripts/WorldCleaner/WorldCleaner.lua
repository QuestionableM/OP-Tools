--[[
    Copyright (c) 2021 Questionable Mark
]]

if WorldCleaner then return end
dofile("../libs/ScriptLoader.lua")
dofile("WorldCleanerGUI.lua")
WorldCleaner = class(WorldCleanerGUI)
WorldCleaner.connectionInput = sm.interactable.connectionType.none
WorldCleaner.connectionOutput = sm.interactable.connectionType.none
function WorldCleaner.server_onCreate(self)
    self.stuffToDelete = {units = {}, bodies = {}, shapes = {}}
    self.server_msg_table = {
        lift = {d_lifts = true, msg = "Lifts were deleted"},
        loseBodies = {id = "lose", msg = "#ffff00%s#ffffff lose bodies were deleted"},
        allBodies = {id = "all", msg = "#ffff00%s#ffffff bodies were deleted"},
        units = {d_units = true, msg = "#ffff00%s#ffffff units were deleted"},
        everything = {id = "all", d_units = true, d_lifts = true, msg = "all lifts and #ffff00%s#ffffff bodies / units were deleted"},
        optools = {id = "optools", msg = "#ffff00%s#ffffff OP Tools were deleted"},
        c_item = {id = "c_item", msg = "#ffff00%s#ffffff certain shapes were deleted"}
    }
    local creation_bodies = sm.body.getCreationBodies(self.shape.body)
    if OP.isCreationDynamic(creation_bodies) then
        for id, body in pairs(creation_bodies) do
            for id, shape in pairs(body:getShapes()) do shape:destroyShape(0) end
        end
    end
    OP.setAdminFlag()
    self.server_admin = true
end
function WorldCleaner.countStuffToDelete(self, deleteBodies, deleteLifts, deleteUnits)
    if deleteBodies then
        if deleteBodies == "lose" then
            for k, body in pairs(OP.getAllDynamicBodies()) do
                table.insert(self.stuffToDelete.bodies, body)
            end
        elseif deleteBodies == "all" then
            for k, body in pairs(sm.body.getAllBodies()) do
                table.insert(self.stuffToDelete.bodies, body)
            end
        elseif deleteBodies == "optools" then
            for k, body in pairs(sm.body.getAllBodies()) do
                for k, shape in pairs(body:getShapes()) do
                    if OP.tool_uuids[tostring(shape.uuid)] then
                        table.insert(self.stuffToDelete.shapes, shape)
                    end
                end
            end
        end
    end
    if deleteLifts then
        for id, player in pairs(sm.player.getAllPlayers()) do player:removeLift() end
    end
    if deleteUnits then
        if sm.unit.HACK_getAllUnits_HACK then
            for k, unit in pairs(sm.unit.HACK_getAllUnits_HACK()) do table.insert(self.stuffToDelete.units, unit) end
        elseif sm.unit.getAllUnits then
            for k, unit in pairs(sm.unit.getAllUnits()) do table.insert(self.stuffToDelete.units, unit) end
        end
    end
end
function WorldCleaner.server_countCertainItem(self, uuid)
    for id, body in pairs(sm.body.getAllBodies()) do
        for id, shape in pairs(body:getShapes()) do
            if shape.uuid == uuid then table.insert(self.stuffToDelete.shapes, shape) end
        end
    end
end
function WorldCleaner.server_clean(self, data)
    if not data.ready then
        local current_func = self.server_msg_table[data.case]
        if current_func then
            if data.case == "c_item" then
                self:server_countCertainItem(data.uuid)
            else
                self:countStuffToDelete(current_func.id, current_func.d_lifts, current_func.d_units)
            end
            self.network:sendToClient(data.player, "client_display", {
                msg = current_func.msg,
                amount = #self.stuffToDelete.bodies + #self.stuffToDelete.units + #self.stuffToDelete.shapes
            })
        end
    else
        OP.deleteBodies(self.stuffToDelete.bodies, true)
        OP.deleteShapes(self.stuffToDelete.shapes, true)
        OP.deleteUnits(self.stuffToDelete.units, true)
    end
end
function WorldCleaner.client_onCreate(self)
    self.mode = {
        page = -1,
        settings = {
            [1] = {name = "Everything", id = "everything", confirm = true},
            [2] = {name = "Lose only bodies", id = "loseBodies", confirm = true},
            [3] = {name = "All bodies", id = "allBodies", confirm = true},
            [4] = {name = "Lifts", id = "lift", sound = "ConnectTool - Released"},
            [5] = {name = "Units", id = "units", confirm = true},
            [6] = {name = "All OP Tools", id = "optools", confirm = true},
            [7] = {name = "Selected item", id = "c_item", confirm = true}
        }
    }
    self.allowed = OP.getPermission("WorldCleaner") or self.server_admin
end
function WorldCleaner.client_onInteract(self, character, state)
    if state and self.allowed then
        if GUI_STUFF.is_gui_supported() then self:client_initializeGui()
        else
            if not self.confirm then
                local id_val = character:isCrouching() and -1 or 1
                self.mode.page = (self.mode.page + id_val) % #self.mode.settings
                OP.display("drag", true, ("(#ffff00%s#ffffff/#ffff00%s#ffffff)\nDelete #ffff00%s#ffffff"):format(self.mode.page + 1, #self.mode.settings, self.mode.settings[self.mode.page + 1].name))
            else
                OP.display("close", true, "Operation cancelled")
                self.confirm = false
            end
        end
    end
end
function WorldCleaner.client_isShapePlaced(self)
    local hit, result = sm.physics.raycast(self.shape.worldPosition, self.shape.worldPosition + self.shape.at * 0.25)
    if hit and result.type == "body" then return result:getShape():getShapeUuid() end
    if not self.anim_duration then self.anim_duration = 62 end
    OP.display("error", false, "A shape / block has to be placed on top of world cleaner in order to use that function")
end
function WorldCleaner.client_onTinker(self, character, state)
    if state and self.allowed and not GUI_STUFF.is_gui_supported() then
        if self.mode.page > -1 then
            local currentSetting = self.mode.settings[self.mode.page + 1]
            local s_uuid = nil
            if currentSetting.id == "c_item" then
                s_uuid = self:client_isShapePlaced()
                if s_uuid == nil then return end
            end
            if self.confirm or not currentSetting.confirm then
                sm.audio.play(currentSetting.sound or "Blueprint - Delete")
                self:client_sendToServer(currentSetting.id, s_uuid)
                self.confirm = false
            else
                OP.display("open", true, ("Are you sure that you want to delete #ffff00%s#ffffff?"):format(currentSetting.name))
                self.confirm = true
            end
        else
            OP.display("open", true, "Choose an option")
        end
    end
end
function WorldCleaner.client_onFixedUpdate(self)
    if self.anim_duration then
        if self.anim_duration % 21 == 20 then
            sm.particle.createParticle("construct_welding", self.shape.worldPosition + self.shape.at * 0.25)
        end
        self.anim_duration = (self.anim_duration > 1 and self.anim_duration - 1) or nil
    end
    self.allowed = OP.getPermission("WorldCleaner") or self.server_admin
    if not GUI_STUFF.is_gui_supported() or not (self.gui_dialog or self.new_gui or self.gui_item_dialog) or self.allowed then return end
    if GUI_STUFF.isGuiActive(self.gui_dialog) or GUI_STUFF.isGuiActive(self.new_gui.interface) or GUI_STUFF.isGuiActive(self.gui_item_dialog) then
        GUI_STUFF.close_and_destroy_dialogs({self.gui_dialog, self.new_gui and self.new_gui.interface, self.gui_item_dialog})
    end
end
function WorldCleaner.client_display(self, data)
    if self.allowed then
        self.network:sendToServer("server_clean", {ready = true})
        sm.gui.displayAlertText((data.msg):format(data.amount))
    end
end
function WorldCleaner.client_canErase(self)
    if self.allowed then return true end
    sm.gui.displayAlertText("Only allowed players can delete this tool", 1)
    return false
end
function WorldCleaner.client_canInteract(self)
    if self.allowed then
        local _useKey = sm.gui.getKeyBinding("Use")
        local _tinkerKey = sm.gui.getKeyBinding("Tinker")
        if GUI_STUFF.is_gui_supported() then
            sm.gui.setInteractionText("Press", _useKey, "to open the GUI of World Cleaner")
            sm.gui.setInteractionText("")
        else
            local _crawlKey = sm.gui.getKeyBinding("Crawl")
            sm.gui.setInteractionText("Press", _useKey, "or", _crawlKey.." + ".._useKey, "to choose the mode")
            sm.gui.setInteractionText("Press", _tinkerKey, "to delete stuff")
        end
        return true
    end
    sm.gui.setInteractionText("", "Only allowed players can use this tool")
    sm.gui.setInteractionText("")
    return false
end
function WorldCleaner.client_onDestroy(self)
    GUI_STUFF.close_and_destroy_dialogs({self.gui_dialog, self.new_gui and self.new_gui.interface, self.gui_item_dialog})
end