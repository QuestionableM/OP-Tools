--[[
	Copyright (c) 2022 Questionable Mark
]]

FreeCamGui = class()

function FreeCamGui:client_GUI_buttonCallback(btn_name)
	print("client_GUI_buttonCallback", btn_name)
end

function FreeCamGui:client_GUI_toggleCallback(btn_name)
	print("client_GUI_toggleCallback", btn_name)
end

function FreeCamGui:client_GUI_getSettingPageOffset(widget_id)
	local cur_setting_page = (self.gui_setting_page - 1) * 4
	return cur_setting_page + widget_id
end

function FreeCamGui:client_GUI_setCamCategoryAndPage(widget_id)
	local s_camera = self.camera
	local option_id = self:client_GUI_getSettingPageOffset(widget_id)

	s_camera.category_id = self.gui_current_tab - 1
	s_camera.option_id   = option_id - 1

	self:client_HUD_updateSelectedOptions()
end

function FreeCamGui:client_GUI_onTextChangedCallback(widget, text)
	local cam_gui = self.camera_set_gui
	local widget_idx = tonumber(widget:sub(-1))

	local status_widget = "ValStatus"..widget_idx

	local number_value = tonumber(text)
	if number_value ~= nil then
		local page_offset = (self.gui_setting_page - 1) * 4
		local cur_category = self.camera.option_list[self.gui_current_tab]

		local cur_opt = cur_category.subOptions[page_offset + widget_idx]
		if cur_opt.value ~= number_value then
			cur_opt.value = sm.util.clamp(number_value, cur_opt.minValue, cur_opt.maxValue)

			local cur_opt_update = cur_opt.update
			if cur_opt_update ~= nil then
				cur_opt_update(self, cur_category, cur_opt)
			end
		end
	else
		cam_gui:setText(status_widget, "#ff0000Invalid Value#ffffff")
	end

	cam_gui:setVisible(status_widget, number_value == nil)

	self:client_GUI_setCamCategoryAndPage(widget_idx)
end

function FreeCamGui:client_GUI_getCurrentSubOption(widget_id) --remove if not used
	local page_offset = (self.gui_setting_page - 1) * 4
	local cur_options = self.camera.option_list[self.gui_current_tab]

	return cur_options.subOptions[page_offset + widget_id]
end

function FreeCamGui:client_GUI_onTextAcceptedCallback(widget, text)
	local cam_gui = self.camera_set_gui
	local widget_idx = tonumber(widget:sub(-1))
	local s_camera = self.camera

	local number_value = tonumber(text)
	if number_value ~= nil then
		local cur_category = s_camera.option_list[self.gui_current_tab]

		local option_id = self:client_GUI_getSettingPageOffset(widget_idx)
		local cur_option = cur_category.subOptions[option_id]

		cam_gui:setText(widget, tostring(cur_option.value))

		local cur_opt_func = cur_option.func
		if cur_opt_func ~= nil then
			cur_opt_func(self, cur_category, cur_option)

			sm.audio.play("Retrowildblip", s_camera.position)
		end
	else
		sm.audio.play("WeldTool - Error", s_camera.position)
	end

	self:client_GUI_setCamCategoryAndPage(widget_idx)
end

function FreeCamGui:client_GUI_onListBoxUpdateCallback(btn_name)
	local s_camera = self.camera

	local btn_idx = tonumber(btn_name:sub(-1))
	local btn_pref = btn_name:sub(0, 1)
	local step_value = (btn_pref == "R" and 1 or -1)

	local cur_category = s_camera.option_list[self.gui_current_tab]
	local cur_option = self:client_GUI_getCurrentSubOption(btn_idx)

	local new_val = sm.util.clamp(cur_option.value + step_value, 1, cur_option.maxValue)
	if new_val ~= cur_option.value then
		cur_option.value = new_val

		local cur_obj_list = cur_category.listStorage[cur_option.listName]
		local cur_list_obj = cur_obj_list[cur_option.value]

		local cam_gui = self.camera_set_gui
		cam_gui:setText("ListValue"..btn_idx, cur_list_obj.name)
		cam_gui:setText("ListPage"..btn_idx, ("%s / %s"):format(cur_option.value, cur_option.maxValue))
		
		sm.audio.play("GUI Item drag", self.camera.position)
		self:client_GUI_setCamCategoryAndPage(btn_idx)
	end
end

function FreeCamGui:client_GUI_switchTabPage(btn_name)
	local btn_pref = btn_name:sub(0, 1)
	local step_value = (btn_pref == "R" and 1 or -1)

	local l_new_page = sm.util.clamp(self.gui_setting_page + step_value, 1, self.gui_setting_page_count)
	if self.gui_setting_page == l_new_page then return end

	self.gui_setting_page = l_new_page

	self:client_GUI_updateSettingsTab()

	sm.audio.play("GUI Item drag", self.camera.position)
end

function FreeCamGui:client_GUI_updateTabName()
	local cur_tab = self.gui_current_tab
	local cam_options = self.camera.option_list[cur_tab]

	self.camera_set_gui:setText("CurTabName", cam_options.name)
end

function FreeCamGui:client_GUI_tabSelectCallback(button_name)
	local button_idx = tonumber(button_name:sub(-1))

	local cur_tab_idx = button_idx + self.gui_tab_shift
	if cur_tab_idx == self.gui_current_tab then return end

	self.gui_setting_page = 1
	self.gui_current_tab = cur_tab_idx

	self:client_GUI_updateTabName()
	self:client_GUI_updateTabSelection()

	sm.audio.play("Handbook - Turn page", self.camera.position)
end

function FreeCamGui:client_GUI_updateTabSelection()
	local cam_gui = self.camera_set_gui
	local cur_tab = self.gui_current_tab
	local tab_shift = self.gui_tab_shift

	for i = 1, 3 do
		cam_gui:setButtonState("TabButton"..i, (tab_shift + i) == cur_tab)
	end

	self:client_GUI_updateSettingsTab()
end

function FreeCamGui:client_GUI_shiftPageCallback(button_name)
	local f_letter = button_name:sub(0, 1)
	local step_value = (f_letter == "R" and 1 or -1)

	local new_tab_shift = sm.util.clamp(self.gui_tab_shift + step_value, 0, self.gui_tab_shift_max)
	if new_tab_shift == self.gui_tab_shift then return end

	self.gui_tab_shift = new_tab_shift

	self:client_GUI_updateTabs()
	sm.audio.play("GUI Item released", self.camera.position)
end

function FreeCamGui:client_GUI_updateTabs()
	local cam_gui = self.camera_set_gui
	local cam_options = self.camera.option_list
	local cur_tab = self.gui_current_tab
	local tab_shift = self.gui_tab_shift

	for i = 1, 3 do
		local cur_idx = tab_shift + i
		local btn_name = "TabButton"..i

		cam_gui:setText(btn_name, cam_options[cur_idx].name)
		cam_gui:setButtonState(btn_name, cur_idx == cur_tab)
	end

	cam_gui:setVisible("L_ShiftTab", tab_shift > 0)
	cam_gui:setVisible("R_ShiftTab", tab_shift < self.gui_tab_shift_max)
end

local value_editor_names =
{
	"ValInputBG_", --id1
	"ListBoxBG_",  --id2
	"BooleanBG_",  --id3
	"ButtonBG_"    --id4
}

local value_setter_functions =
{
	[1] = function(self, slot, cur_category, cur_option, gui) --init value input data
		gui:setText("ValInput"..slot, tostring(cur_option.value))
		gui:setVisible("ValStatus"..slot, false)
	end,
	[2] = function(self, slot, cur_category, cur_option, gui) --init list box data
		local list_name = cur_option.listName
		local list_data = cur_category.listStorage[list_name]

		local cur_value = cur_option.value
		local cur_item = list_data[cur_value]
		local item_name = (cur_item ~= nil and cur_item.name or "Select Item")

		gui:setText("ListValue"..slot, item_name)
		gui:setText("ListPage"..slot, ("%s / %s"):format(cur_value, cur_option.maxValue))
	end,
	[3] = function(self, slot, cur_category, cur_option, gui) --init boolean data
		local cur_val = cur_option.value

		--IMPLEMENT LATER, WAITING FOR BUG FIX UPDATE
		--gui:setButtonState("ToggleOn"..slot,     cur_val)
		--gui:setButtonState("ToggleOf"..slot, not cur_val)
	end,
	[4] = function(self, slot, cur_category, cur_option, gui) --init button data

	end
}

function FreeCamGui:client_GUI_prepareSettingData(slot, cur_category, cur_option)
	local cam_gui = self.camera_set_gui

	local type_id = (cur_option and cur_option.type or 0)

	for i = 1, 4 do
		local cur_name = value_editor_names[i]..slot
		cam_gui:setVisible(cur_name, i == type_id)
	end

	local setter_func = value_setter_functions[type_id]
	if setter_func ~= nil then
		setter_func(self, slot, cur_category, cur_option, cam_gui)
	end
end

function FreeCamGui:client_GUI_updateSettingsTab()
	local cam_gui = self.camera_set_gui
	local cur_tab = self.gui_current_tab
	local cur_idx_offset = (self.gui_setting_page - 1) * 4

	local cur_category = self.camera.option_list[cur_tab]
	local sub_options = cur_category.subOptions

	for i = 1, 4 do
		local cur_idx = cur_idx_offset + i
		local cur_sub_opt = sub_options[cur_idx]
		local set_name_widget = "SettingName"..i

		local sub_opt_exists = (cur_sub_opt ~= nil)
		cam_gui:setVisible(set_name_widget, sub_opt_exists)
		if sub_opt_exists then
			cam_gui:setText(set_name_widget, cur_sub_opt.name)
		end

		self:client_GUI_prepareSettingData(i, cur_category, cur_sub_opt)
	end

	self.gui_setting_page_count = math.ceil(#sub_options / 4)
	cam_gui:setText("SettingsPage", ("%s / %s"):format(self.gui_setting_page, self.gui_setting_page_count))
end

function FreeCamGui:client_GUI_openGui()
	self.camera_set_gui:open()

	self:client_GUI_updateTabName()
	self:client_GUI_updateSettingsTab()
end

function FreeCamGui:client_GUI_createFreeCamSettings()
	local cam_gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/FreeCameraSettingsGui.layout", false, { hidesHotbar = true, backgroundAlpha = 0.5 })

	for i = 1, 4 do
		cam_gui:setButtonCallback("Button"..i, "client_GUI_buttonCallback")
		cam_gui:setButtonCallback("ToggleOf"..i, "client_GUI_toggleCallback")
		cam_gui:setButtonCallback("ToggleOn"..i, "client_GUI_toggleCallback")

		cam_gui:setButtonCallback("L_ListButton"..i, "client_GUI_onListBoxUpdateCallback")
		cam_gui:setButtonCallback("R_ListButton"..i, "client_GUI_onListBoxUpdateCallback")

		local val_inp_name = "ValInput"..i
		cam_gui:setTextAcceptedCallback(val_inp_name, "client_GUI_onTextAcceptedCallback")
		cam_gui:setTextChangedCallback(val_inp_name, "client_GUI_onTextChangedCallback")
	end

	for i = 1, 3 do
		cam_gui:setButtonCallback("TabButton"..i, "client_GUI_tabSelectCallback")
	end

	cam_gui:setButtonCallback("L_ShiftTab", "client_GUI_shiftPageCallback")
	cam_gui:setButtonCallback("R_ShiftTab", "client_GUI_shiftPageCallback")

	cam_gui:setButtonCallback("R_SetTurnPage", "client_GUI_switchTabPage")
	cam_gui:setButtonCallback("L_SetTurnPage", "client_GUI_switchTabPage")

	self.gui_current_tab  = 1

	self.gui_tab_shift    = 0
	self.gui_tab_shift_max = #self.camera.option_list - 3
	
	self.gui_setting_page = 1
	self.gui_setting_page_count = 0

	self.camera_set_gui = cam_gui

	self:client_GUI_updateTabs()
end