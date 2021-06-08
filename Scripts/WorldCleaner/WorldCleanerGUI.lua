--[[
    Copyright (c) 2021 Questionable Mark
]]

if WorldCleanerGUI then return end
WorldCleanerGUI = class()

local button_names = {
	DeleteEverything = {id = "everything", name = "Everything"},
	AllBodies = {id = "all_b", name = "All Bodies"},
	LoseOnly = {id = "lose_b", name = "All Lose Bodies"},
	OpTools = {id = "op_t", name = "All OP Tools"},
	Lifts = {id = "lift"},
	Units = {id = "unit"},
	CurCreation = {id = "c_creation", name = "Connected Creation"}
}

function WorldCleanerGUI:client_initializeGui()
	if not self:isAllowed() then return end

	self.gui = GUI_STUFF.createGuiLayout(GUI_STUFF.guis.WorldCleanerGui)

	self.client_GUI_onButtonCallback = function(self, btn_name)
		if not self:isAllowed() then return end

		local btn_data = button_names[btn_name]
		if btn_data.name then
			self:client_constructDialog(btn_data.name, btn_data.id)
			return
		end

		sm.audio.play("ConnectTool - Released")
		self:client_sendToServer(btn_data.id)
	end

	self.client_GUI_deleteCObject = function(self)
		if not self:isAllowed() then return end

		local uuid = self:client_isShapePlaced()
		self.gui:close()
		if uuid == nil then return end
		self:client_constructItemDialog(uuid)
	end

	self.gui:setButtonCallback("CObject", "client_GUI_deleteCObject")
	for btn, v in pairs(button_names) do
		self.gui:setButtonCallback(btn, "client_GUI_onButtonCallback")
	end

	self.gui:setOnCloseCallback("client_onWCGuiDestroy")

	self.gui:open()
end

function WorldCleanerGUI:client_onWCGuiDestroy()
	if OP.exists(self.gui) then self.gui:destroy() end
	self.gui = nil
	self.client_GUI_onButtonCallback = nil
	self.client_GUI_deleteCObject = nil
end

function WorldCleanerGUI:client_sendToServer(case, uuid)
    self.network:sendToServer("server_clean", {
        ready = false,
        case = case,
        uuid = uuid,
        player = sm.localPlayer.getPlayer()
    })
end

function WorldCleanerGUI:client_constructDialog(description, id)
    sm.audio.play("Blueprint - Open")
    self.gui:close()

    GUI_STUFF.open_dialog(
        self, ("Are you sure that you want to delete #ffff00%s#ffffff?"):format(description),
        function(self) self:client_sendToServer(id) end,
        function(self) self:client_initializeGui() end,
        "Blueprint - Delete", "Blueprint - Close"
    )
end

function WorldCleanerGUI:client_constructItemDialog(uuid)
	self.gui_item_dialog = GUI_STUFF.createGuiLayout(GUI_STUFF.guis.ItemDialogGui)
	self.client_onItemDialogCloseCallback = function(self)
		self.client_onItemDialogCloseCallback = nil
		self.client_onItemDialogNoCallback = nil
		self.client_onItemDialogYesCallback = nil
		self.gui_item_dialog:destroy()
		self.gui_item_dialog = nil
	end
	self.client_onItemDialogButtonCallback = function(self, btn_name)
		self.gui_item_dialog:close()
		local is_yes = (btn_name == "Yes")

		local snd_name = (is_yes and "Delete" or "Close")
		sm.audio.play("Blueprint - "..snd_name)

		if is_yes then
			self:client_sendToServer("c_item", uuid)
			return
		end

		self:client_initializeGui()
	end
	self.gui_item_dialog:setButtonCallback("Yes", "client_onItemDialogButtonCallback")
	self.gui_item_dialog:setButtonCallback("No", "client_onItemDialogButtonCallback")
	self.gui_item_dialog:setOnCloseCallback("client_onItemDialogCloseCallback")
	self.gui_item_dialog:setIconImage("PartImage", uuid)
	self.gui_item_dialog:setText("PartName", ("Part name: #ffff00%s#ffffff"):format(sm.shape.getShapeTitle(uuid)))
	self.gui_item_dialog:setText("PartUuid", ("Part uuid: #ffff00%s#ffffff"):format(tostring(uuid)))
	sm.audio.play("Blueprint - Open")
	self.gui_item_dialog:open()
end