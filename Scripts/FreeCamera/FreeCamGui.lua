--[[
	Copyright (c) 2022 Questionable Mark
]]

FreeCamGui = class()

function FreeCamGui:client_GUI_buttonCallback(btn_name)
	local btn_idx = tonumber(btn_name:sub(-1))
	local option_id = self:client_GUI_getSettingPageOffset(btn_idx)

	local s_camera = self.camera
	local cur_category = s_camera.option_list[self.gui_current_tab]
	local cur_option   = cur_category.subOptions[option_id]

	local is_updated = self:client_GUI_setCamCategoryAndPage(btn_idx)

	if cur_option.gui_ex then
		local cur_opt_func = cur_option.func
		if cur_opt_func ~= nil then
			cur_opt_func(self, cur_category, cur_option)
		end
	else
		if is_updated then
			sm.audio.play("PotatoRifle - Equip", s_camera.position)
		end
	end
end

function FreeCamGui:client_GUI_updateBooleanWidget(slot, cur_option)
	local cam_gui = self.camera_set_gui
	local cur_val = cur_option.value

	cam_gui:setButtonState("ToggleOn"..slot, cur_val)
	cam_gui:setButtonState("ToggleOf"..slot, not cur_val)
end

function FreeCamGui:client_GUI_toggleCallback(btn_name)
	local button_idx = tonumber(btn_name:sub(-1))
	local button_act = btn_name:sub(7, 8)

	local new_bool_state = (button_act == "On")

	local cur_option = self:client_GUI_getCurrentSubOption(button_idx)
	if new_bool_state == cur_option.value then return end
	cur_option.value = new_bool_state

	self:client_GUI_updateBooleanWidget(button_idx, cur_option)
	self:client_GUI_setCamCategoryAndPage(button_idx)

	local sub_opt_post_update = cur_option.post_update
	if sub_opt_post_update ~= nil then
		local cur_category = self.camera.option_list[self.gui_current_tab]

		sub_opt_post_update(self, cur_category, cur_option)
	end

	sm.audio.play(OP.bools[new_bool_state].sound, self.camera.position)
end

function FreeCamGui:client_GUI_getSettingPageOffset(widget_id)
	local cur_setting_page = (self.gui_setting_page - 1) * 4
	return cur_setting_page + widget_id
end

function FreeCamGui:client_GUI_updateButtonNames()
	local cur_tab = self.gui_current_tab
	local page_offset = (self.gui_setting_page - 1) * 4

	local s_camera = self.camera
	local cur_category = s_camera.option_list[cur_tab]
	local sub_opt = cur_category.subOptions
	local cur_opt_id = s_camera.option_id + 1
	local set_gui = self.camera_set_gui

	for i = 1, 4 do
		local cur_id = page_offset + i
		local cur_option = sub_opt[cur_id]

		if cur_option ~= nil and cur_option.type == 4 and not cur_option.gui_ex then --is button
			local is_selected = (cur_opt_id == cur_id)
			set_gui:setText("Button"..i, is_selected and "Option Selected" or "Select Option")
		end
	end
end

function FreeCamGui:client_GUI_setCamCategoryAndPage(widget_id)
	local s_camera = self.camera
	local option_id = self:client_GUI_getSettingPageOffset(widget_id)

	local new_category = self.gui_current_tab - 1
	local l_should_update = false
	if s_camera.category_id ~= new_category then
		s_camera.category_id = new_category
		l_should_update = true
	end

	local new_opt_id = option_id - 1
	if not l_should_update and s_camera.option_id == new_opt_id then
		return false
	end

	s_camera.option_id = new_opt_id

	self:client_GUI_updateButtonNames()
	self:client_HUD_updateSelectedOptions()

	return true
end

local _sm_guiGetKeyBinding = sm.gui.getKeyBinding
function FreeCamGui:client_GUI_updateStatusWidget(slot, is_valid, self_ex)
	local cam_gui = self.camera_set_gui
	local l_status_name = "ValStatus"..slot

	if is_valid then
		if self_ex then
			local chat_btn = _sm_guiGetKeyBinding("Chat")

			cam_gui:setText(l_status_name, ("Press #ffff00%s#ffffff to use"):format(chat_btn))
		end
	else
		cam_gui:setText(l_status_name, "#ff0000Invalid Value#ffffff")
	end

	cam_gui:setVisible(l_status_name, self_ex or not is_valid)
end

function FreeCamGui:client_GUI_onTextChangedCallback(widget, text)
	local cam_gui = self.camera_set_gui
	local widget_idx = tonumber(widget:sub(-1))

	local status_widget = "ValStatus"..widget_idx

	local page_offset = (self.gui_setting_page - 1) * 4
	local cur_category = self.camera.option_list[self.gui_current_tab]
	local cur_opt = cur_category.subOptions[page_offset + widget_idx]

	local number_value = tonumber(text)
	local is_num_valid = (number_value ~= nil)
	if is_num_valid then
		if cur_opt.value ~= number_value then
			cur_opt.value = sm.util.clamp(number_value, cur_opt.minValue, cur_opt.maxValue)

			local cur_opt_post_update = cur_opt.post_update
			if cur_opt_post_update ~= nil then
				cur_opt_post_update(self, cur_category, cur_opt)
			end
		end
	end

	self:client_GUI_updateStatusWidget(widget_idx, is_num_valid, cur_opt.gui_ex)
	self:client_GUI_setCamCategoryAndPage(widget_idx)

	sm.audio.play("GUI Inventory highlight", self.camera.position)
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

		if cur_option.gui_ex then
			local cur_opt_func = cur_option.func
			if cur_opt_func ~= nil then
				cur_opt_func(self, cur_category, cur_option)
			end
		end
	else
		sm.audio.play("WeldTool - Error", s_camera.position)
	end

	self:client_GUI_setCamCategoryAndPage(widget_idx)
end

function FreeCamGui:client_GUI_updateListBoxWidget(slot, cur_category, cur_option)
	local cur_gui_update_func = cur_option.gui_update
	if cur_gui_update_func ~= nil then
		cur_gui_update_func(self, cur_option, slot)
	else
		local cur_option_list = cur_category.listStorage[cur_option.listName]
		local cur_list_val = cur_option_list[cur_option.value]

		local cam_gui = self.camera_set_gui
		cam_gui:setText("ListValue"..slot, cur_list_val and cur_list_val.name or "Select Item")
		cam_gui:setText("ListPage"..slot, ("%s / %s"):format(cur_option.value, cur_option.maxValue))
	end
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

		self:client_GUI_updateListBoxWidget(btn_idx, cur_category, cur_option)
		
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

	self.camera.category_id = cur_tab_idx - 1
	self.camera.option_id = -1
	self:client_HUD_updateSelectedOptions()

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

		cam_gui:setText(btn_name, cam_options[cur_idx].tab_name)
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

		self:client_GUI_updateStatusWidget(slot, true, cur_option.gui_ex)
	end,
	[2] = function(self, slot, cur_category, cur_option, gui) --init list box data
		self:client_GUI_updateListBoxWidget(slot, cur_category, cur_option)
	end,
	[3] = function(self, slot, cur_category, cur_option, gui) --init boolean data
		self:client_GUI_updateBooleanWidget(slot, cur_option)
	end,
	[4] = function(self, slot, cur_category, cur_option, gui) --init button data
		local btn_name = "Button"..slot
		local option_id = self:client_GUI_getSettingPageOffset(slot)

		if cur_option.gui_ex then
			gui:setText(btn_name, "Call Function")
		else
			local cur_opt_id = self.camera.option_id + 1
			local cur_cat_id = self.camera.category_id + 1

			local l_selected = (cur_opt_id == option_id and self.gui_current_tab == cur_cat_id)

			gui:setText(btn_name, l_selected and "Option Selected" or "Select Option")
		end
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

function FreeCamGui:client_GUI_resetValuesCallback()
	local cam_category_list = self.camera.option_list

	for k, cur_category in ipairs(cam_category_list) do
		for v, cur_opt_obj in ipairs(cur_category.subOptions) do
			if cur_opt_obj.default ~= nil then
				cur_opt_obj.value = cur_opt_obj.default
			end

			local cur_post_update_func = cur_opt_obj.post_update
			if cur_post_update_func ~= nil then
				cur_post_update_func(self, cur_category, cur_opt_obj)
			end
		end
	end

	self:client_GUI_updateSettingsTab()
end

function FreeCamGui:client_GUI_setListBoxFocus(btn_name)
	local btn_idx = tonumber(btn_name:sub(-1))

	local is_updated = self:client_GUI_setCamCategoryAndPage(btn_idx)

	local cur_category = self.camera.option_list[self.gui_current_tab]
	local cur_option = self:client_GUI_getCurrentSubOption(btn_idx)

	if cur_option.gui_ex then
		local cur_opt_func = cur_option.func
		if cur_opt_func ~= nil then
			cur_opt_func(self, cur_category, cur_option)
		end
	else
		if is_updated then
			sm.audio.play("PotatoRifle - Equip", self.camera.position)
		end
	end
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
		cam_gui:setButtonCallback("ListValue"..i, "client_GUI_setListBoxFocus")

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
	cam_gui:setButtonCallback("RestoreDefaults", "client_GUI_resetValuesCallback")

	self.gui_current_tab  = 1

	self.gui_tab_shift    = 0
	self.gui_tab_shift_max = #self.camera.option_list - 3
	
	self.gui_setting_page = 1
	self.gui_setting_page_count = 0

	self.camera_set_gui = cam_gui

	self:client_GUI_updateTabs()
end