--[[
	Copyright (c) 2022 Questionable Mark
]]

if FreeCamOldGui then return end
FreeCamOldGui = class()

local _sm_getKeyBinding = sm.gui.getKeyBinding
function FreeCamOldGui.client_displayStartInfo()
	OP.print("Free Camera Mode enabled")
	OP.display("blip", false, ("Free Camera Mode enabled, press #ffff00%s#ffffff to change the category and #ffff00%s#ffffff to change its parameters\nUse #ffff00%s#ffffff/#ffff00%s#ffffff to change the value of the parameter"):format(
		_sm_getKeyBinding("MenuItem0"),
		_sm_getKeyBinding("MenuItem1"),
		_sm_getKeyBinding("PreviousMenuItem"),
		_sm_getKeyBinding("NextMenuItem")
	), 5)
end

function FreeCamOldGui.client_changeSelectedCategory(self)
	local s_camera = self.camera

	s_camera.category_id = (s_camera.category_id + 1) % s_camera.option_count
	s_camera.option_id = -1

	local cur_category = s_camera.option_list[s_camera.category_id + 1]

	OP.display("drag", false, ("[#ffff00%s#ffffff/#ffff00%s#ffffff] Camera category set to #ffff00%s#ffffff\nPress #ffff00%s#ffffff to change its parameters"):format(
		s_camera.category_id + 1,
		s_camera.option_count,
		cur_category.name,
		_sm_getKeyBinding("MenuItem1")
	))

	self:client_HUD_updateSelectedOptions()
end

function FreeCamOldGui.client_changeSelectedOption(self)
	local s_camera = self.camera

	if s_camera.category_id <= -1 then
		OP.display("error", false, "Choose a category to change its options")
		return
	end

	local cur_category = s_camera.option_list[s_camera.category_id + 1]
	local option_count = #cur_category.subOptions

	s_camera.option_id = (s_camera.option_id + 1) % option_count

	local cur_option = cur_category.subOptions[s_camera.option_id + 1]
	local option_type = cur_option.type

	if option_type >= 1 and option_type <= 3 then
		OP.display("release", false, ("[#ffff00%s#ffffff/#ffff00%s#ffffff] #ffff00%s#ffffff can be changed with #ffff00%s#ffffff/#ffff00%s#ffffff now"):format(
			s_camera.option_id + 1,
			option_count,
			cur_option.name,
			_sm_getKeyBinding("PreviousMenuItem"),
			_sm_getKeyBinding("NextMenuItem")
		))
	else
		OP.display("release", false, ("[#ffff00%s#ffffff/#ffff00%s#ffffff] #ffff00%s#ffffff is selected"):format(s_camera.option_id + 1, option_count, cur_option.name))
	end

	self:client_HUD_updateSelectedOptions()
end

local _sm_util_clamp = sm.util.clamp
local value_change_functions =
{
	[1] = function(self, curCategory, subOpt, movement)
		local l_changer = (subOpt.changer * self.camera.multiplier) * movement

		subOpt.value = _sm_util_clamp(subOpt.value + l_changer, subOpt.minValue, subOpt.maxValue)

		local sub_opt_update = subOpt.update
		if sub_opt_update ~= nil then
			sub_opt_update(self, curCategory, subOpt)
		else
			sm.gui.displayAlertText(("#ffff00%s#ffffff set to #ffff00%.2f#ffffff"):format(subOpt.name, subOpt.value))
		end

		local sub_opt_post_update = subOpt.post_update
		if sub_opt_post_update ~= nil then
			sub_opt_post_update(self, curCategory, subOpt)
		end

		sm.audio.play("GUI Inventory highlight", self.camera.position)
	end,
	[2] = function(self, curCategory, subOpt, movement)
		subOpt.value = _sm_util_clamp(subOpt.value + movement, 1, subOpt.maxValue)

		local cur_list = curCategory.listStorage[subOpt.listName]
		local cur_list_obj = cur_list[subOpt.value]

		local sub_opt_update = subOpt.update
		if sub_opt_update ~= nil then
			sub_opt_update(self, curCategory, subOpt)
		else
			sm.gui.displayAlertText(("[#ffff00%s#ffffff/#ffff00%s#ffffff] #ffff00%s#ffffff set to #ffff00%s#ffffff"):format(subOpt.value, subOpt.maxValue, subOpt.name, cur_list_obj.name))
		end

		sm.audio.play("GUI Inventory highlight", self.camera.position)
	end,
	[3] = function(self, curCategory, subOpt, movement)
		subOpt.value = not subOpt.value

		local cur_bool = OP.bools[subOpt.value]
		OP.display(cur_bool.sound, false, ("#ffff00%s#ffffff set to #ffff00%s#ffffff"):format(subOpt.name, cur_bool.string))

		local sub_opt_post_update = subOpt.post_update
		if sub_opt_post_update ~= nil then
			sub_opt_post_update(self, curCategory, subOpt)
		end
	end,
	[4] = function(self, curCategory, subOpt, movement)
		sm.gui.displayAlertText("This option has no changable values")
	end
}

function FreeCamOldGui.client_changeOptionValue(self, movement)
	local s_camera = self.camera

	if s_camera.category_id <= -1 then
		sm.gui.displayAlertText("Choose a category")
		return
	end

	if s_camera.option_id <= -1 then
		sm.gui.displayAlertText("Choose an option")
		return
	end

	local cur_category = s_camera.option_list[s_camera.category_id + 1]
	local cur_sub_opt = cur_category.subOptions[s_camera.option_id + 1]

	value_change_functions[cur_sub_opt.type](self, cur_category, cur_sub_opt, movement)
end

function FreeCamOldGui.client_callFunction(self)
	local s_camera = self.camera

	if s_camera.category_id <= -1 then
		OP.display("noAmmo", false, "Select a category")
		return
	end

	local cur_category = s_camera.option_list[s_camera.category_id + 1]
	if not cur_category.individual_functions then
		local category_func = cur_category.func

		if category_func ~= nil then
			category_func(self, cur_category, s_camera.category_id, s_camera.option_id)
		else
			OP.display("noAmmo", false, "This category doesn't have a function")
		end
	else
		local cur_option = cur_category.subOptions[s_camera.option_id + 1]
		if cur_option ~= nil then
			local option_func = cur_option.func

			if option_func ~= nil then
				option_func(self, cur_category, cur_option)
			else
				OP.display("noAmmo", false, "This option doesn't have a function!")
			end
		else
			OP.display("noAmmo", false, "Select an option")
		end
	end
end