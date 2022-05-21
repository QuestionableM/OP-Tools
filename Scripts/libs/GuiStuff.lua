--[[
	Copyright (c) 2021 Questionable Mark
]]

if GUI_STUFF then return end
GUI_STUFF = class()

function GUI_STUFF.open_dialog(self, description, yes_callback, no_callback, on_yes_sound, on_no_sound)
	local gui_diag = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/ConfirmationDialog_GUI.layout", false, { backgroundAlpha = 0.5, hidesHotbar = true })

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

	gui_diag:setButtonCallback("Yes", "client_onDialogYesCallback")
	gui_diag:setButtonCallback("No", "client_onDialogNoCallback")
	gui_diag:setOnCloseCallback("client_onDialogCloseCallback")
	gui_diag:setText("GUIDesc", description)
	gui_diag:open()

	self.gui_dialog = gui_diag
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
		if OP.exists(gui) then
			gui:close()
			gui:destroy()
		end
	end
end

function GUI_STUFF.isGuiActive(gui)
	if gui == nil then return false end
	if sm.exists(gui) then return gui:isActive() end
	return false
end

print("[OPTools] GUI Library has been loaded")