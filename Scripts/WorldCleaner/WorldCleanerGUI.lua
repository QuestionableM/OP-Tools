--[[
    Copyright (c) 2021 Questionable Mark
]]

if WorldCleanerGUI then return end
WorldCleanerGUI = class()

function WorldCleanerGUI.client_initializeGui(self)
    if not GUI_STUFF.is_gui_supported() then return end
    self.new_gui = {}

    self.client_deleteEverything = function(self) self:client_constructDialog("Everything", "everything") end
    self.client_deleteAllBodies = function(self) self:client_constructDialog("All bodies", "allBodies") end
    self.client_deleteLoseOnlyBodies = function(self) self:client_constructDialog("All lose bodies", "loseBodies") end
    self.client_deleteOpTools = function(self) self:client_constructDialog("All Op Tools", "optools") end
    self.client_deleteLifts = function(self) sm.audio.play("ConnectTool - Released") self:client_sendToServer("lift") end
    self.client_deleteUnits = function(self) sm.audio.play("ConnectTool - Released") self:client_sendToServer("units") end
    self.client_deleteCObject = function(self)
        local uuid = self:client_isShapePlaced()
        self.new_gui.interface:close()
        if uuid == nil then return end
        self:client_constructItemDialog(uuid)
    end

    self.new_gui.interface = GUI_STUFF.CONSTRUCT_GUI(self, GUI_STUFF.guis.WorldCleanerGui, {
            [1] = {button = "DeleteEverything", callback = "client_deleteEverything"},
            [2] = {button = "AllBodies", callback = "client_deleteAllBodies"},
            [3] = {button = "LoseOnly", callback = "client_deleteLoseOnlyBodies"},
            [4] = {button = "OpTools", callback = "client_deleteOpTools"},
            [5] = {button = "Lifts", callback = "client_deleteLifts"},
            [6] = {button = "Units", callback = "client_deleteUnits"},
            [7] = {button = "CObject", callback = "client_deleteCObject"}
        }, "client_destroyGUI", true
    )
    self.new_gui.page = 0
end

function WorldCleanerGUI.client_sendToServer(self, case, uuid)
    self.network:sendToServer("server_clean", {
        ready = false,
        case = case,
        uuid = uuid,
        player = sm.localPlayer.getPlayer()
    })
end

function WorldCleanerGUI.client_destroyGUI(self)
    if not GUI_STUFF.is_gui_supported() then return end
    if sm.exists(self.new_gui.interface) then self.new_gui.interface:destroy() end
    self.new_gui = nil
    self.client_deleteAllBodies = nil
    self.client_deleteLoseOnlyBodies = nil
    self.client_deleteOpTools = nil
    self.client_deleteUnits = nil
    self.client_deleteCObject = nil
    self.client_deleteEverything = nil
    self.client_deleteLifts = nil
end
function WorldCleanerGUI.client_constructDialog(self, description, id)
    if not GUI_STUFF.is_gui_supported() then return end
    sm.audio.play("Blueprint - Open")
    self.new_gui.interface:close()
    GUI_STUFF.open_dialog(
        self, ("Are you sure that you want to delete #ffff00%s#ffffff?"):format(description),
        function(self) self:client_sendToServer(id) end,
        function(self) self:client_initializeGui() end,
        "Blueprint - Delete", "Blueprint - Close"
    )
end
function WorldCleanerGUI.client_constructItemDialog(self, uuid)
    self.gui_item_dialog = GUI_STUFF.createGuiLayout(GUI_STUFF.guis.ItemDialogGui)
    self.client_onItemDialogCloseCallback = function(self)
        self.client_onItemDialogCloseCallback = nil
        self.client_onItemDialogNoCallback = nil
        self.client_onItemDialogYesCallback = nil
        self.gui_item_dialog:destroy()
        self.gui_item_dialog = nil
    end
    self.client_onItemDialogYesCallback = function(self)
        self.gui_item_dialog:close()
        sm.audio.play("Blueprint - Delete")
        self:client_sendToServer("c_item", uuid)
    end
    self.client_onItemDialogNoCallback = function(self)
        self.gui_item_dialog:close()
        sm.audio.play("Blueprint - Close")
        self:client_initializeGui()
    end
    self.gui_item_dialog:setButtonCallback("Yes", "client_onItemDialogYesCallback")
    self.gui_item_dialog:setButtonCallback("No", "client_onItemDialogNoCallback")
    self.gui_item_dialog:setOnCloseCallback("client_onItemDialogCloseCallback")
    self.gui_item_dialog:setIconImage("PartImage", uuid)
    self.gui_item_dialog:setText("PartName", ("Part name: #ffff00%s#ffffff"):format(sm.shape.getShapeTitle(uuid)))
    self.gui_item_dialog:setText("PartUuid", ("Part uuid: #ffff00%s#ffffff"):format(tostring(uuid)))
    sm.audio.play("Blueprint - Open")
    self.gui_item_dialog:open()
end