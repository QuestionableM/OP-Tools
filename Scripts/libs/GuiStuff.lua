--[[
	Copyright (c) 2021 Questionable Mark
]]

if GUI_STUFF then return end
GUI_STUFF = class()

GUI_STUFF.guis = {
	AdminToolGui = "AdminToolGUI.layout",
	WorldCleanerGui = "WorldCleaner_GUI.layout",
	PlayerKickerGui = "PlayerKicker_GUI.layout",
	PermissionManagerGui = "PermissionManagerGUI.layout",
	ConfirmDialogGui = "ConfirmationDialog_GUI.layout",
	ItemDialogGui = "ItemDialogGUI.layout",
	ColorPicker = "ColorPickerGUI.layout"
}

local GUI_SUPPORTED = (sm.gui and type(sm.gui.createGuiFromLayout) == "function")

if GUI_SUPPORTED then
	print("[OPTools] GUI libraries are supported by the current game version!")
else
	print("[OPTools] GUI libraries are not supported by the current game version!")
	sm.gui.displayAlertText("#ffff00OP TOOLS DOESN'T WORK WITH OLD VERSIONS OF SCRAP MECHANIC", 20)
end

function GUI_STUFF.createGuiLayout(gui_name)
	local gui_path = "$CONTENT_d14c9984-f872-411b-8e0e-993e829e9bbb/Gui/Layouts/"..gui_name
	return sm.gui.createGuiFromLayout(gui_path)
end

function GUI_STUFF.setItemsVisible(gui, item_table, state)
	for id, item in pairs(item_table) do gui:setVisible(item, state) end
end

function GUI_STUFF.open_dialog(self, description, yes_callback, no_callback, on_yes_sound, on_no_sound)
	self.gui_dialog = GUI_STUFF.createGuiLayout(GUI_STUFF.guis.ConfirmDialogGui)
	self.client_onDialogYesCallback = function(self)
		self.gui_dialog:close()
		if yes_callback and type(yes_callback) == "function" then yes_callback(self) end
		if on_yes_sound then sm.audio.play(on_yes_sound) end
	end
	self.client_onDialogNoCallback = function(self)
		self.gui_dialog:close()
		if no_callback and type(no_callback) == "function" then no_callback(self) end
		if on_no_sound then sm.audio.play(on_no_sound) end
	end
	self.client_onDialogCloseCallback = function(self)
		self.client_onDialogYesCallback = nil
		self.client_onDialogNoCallback = nil
		self.client_onDialogCloseCallback = nil
		if OP.exists(self.gui_dialog) then
			self.gui_dialog:destroy()
		end
		self.gui_dialog = nil
	end
	self.gui_dialog:setButtonCallback("Yes", "client_onDialogYesCallback")
	self.gui_dialog:setButtonCallback("No", "client_onDialogNoCallback")
	self.gui_dialog:setOnCloseCallback("client_onDialogCloseCallback")
	self.gui_dialog:setText("GUIDesc", description)
	self.gui_dialog:open()
end

function GUI_STUFF.CONSTRUCT_GUI(self, gui_path, callbacks, on_close_callback, open_gui)
	local gui = GUI_STUFF.createGuiLayout(gui_path)
	for id, callback in pairs(callbacks) do
		if type(self[callback.callback]) == "function" then
			gui:setButtonCallback(callback.button, callback.callback)
		else
			OP.print("Couldn't find the callback \""..callback.callback.."\"")
		end
	end

	if on_close_callback ~= nil then
		if type(self[on_close_callback]) == "function" then
			gui:setOnCloseCallback(on_close_callback)
		else
			OP.print("Couldn't set OnCloseCallback, callback \""..on_close_callback.."\" doesn't exist!")
		end
	end

	if open_gui then gui:open() end
	return gui
end

function GUI_STUFF.close_and_destroy_dialogs(d_table)
	for id, gui in pairs(d_table) do
		if gui ~= nil and OP.exists(gui) then
			gui:close()
			gui:destroy()
		end
	end
end

function GUI_STUFF.isGuiActive(gui)
	if gui == nil then return end
	if sm.exists(gui) then return gui:isActive() end
	return false
end

print("[OPTools] GUI Library has been loaded")