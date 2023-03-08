--[[
	Copyright (c) 2023 Questionable Mark
]]

if AdminToolGUI then return end

---@class AdminToolGuiData
---@field cur_page integer
---@field btn_data table
---@field interface GuiInterface

---@class AdminToolColorPickerGuiData
---@field rgb table
---@field interface GuiInterface

---@class AdminToolGui : AdminToolClass
AdminToolGUI = class()

function AdminToolGUI:client_disableLinkedButtons(links, page)
	local gui_int = self.gui.interface
	local cur_tab = self.gui.current_tab

	for k, btn_id in pairs(links) do
		local l_btn_data = cur_tab[btn_id]
		self.gui.func_data[l_btn_data.id] = false

		local btn_page = math.ceil(btn_id / 8)

		if l_btn_data.tab then
			gui_int:setVisible(l_btn_data.tab, false)
		end

		if btn_page == page then
			local l_btn_bool = OP.bools[false].string

			gui_int:setText("Func"..btn_id, ("%s = %s"):format(l_btn_data.name, l_btn_bool))
		end
	end
end

function AdminToolGUI:client_onATButtonCallback(btn_name)
	local btn_id = tonumber(btn_name:sub(5))
	local btn_offset = (self.gui.cur_page * 8)

	local cur_tab = self.gui.current_tab
	local btn_data = cur_tab[btn_offset + btn_id]

	self.gui.func_data[btn_data.id] = not self.gui.func_data[btn_data.id]
	local btn_val = self.gui.func_data[btn_data.id]
	local bool_val = OP.bools[btn_val]

	local gui_int = self.gui.interface
	if btn_data.tab then
		gui_int:setVisible(btn_data.tab, btn_val)
	end

	if btn_val and btn_data.link then
		self:client_disableLinkedButtons(btn_data.link, self.gui.cur_page + 1)
	end
	
	sm.audio.play(bool_val.sound)
	gui_int:setText(btn_name, ("%s = %s"):format(btn_data.name, bool_val.string))
end

local btn_names = {"OptionListBG", "CurFuncPage", "NextFuncPage", "PrevFuncPage", "FiltersTab", "ModesTab", "SecondaryFuncTab"}
function AdminToolGUI:client_toggleWaitDataMode(state)
	local gui = self.gui.interface

	if not state then
		for i = 1, 8 do gui:setVisible("Func"..i, false) end
	end

	for k, btn in pairs(btn_names) do
		gui:setVisible(btn, state)
	end

	gui:setVisible("WaitingLabel", not state)
end

local setting_name_to_id =
{
	thanosMode      = 1,
	paintMode       = 2,
	objectMode      = 3,
	painterMode     = 4,
	materialMode    = 5,
	loseOnly        = 6,
	staticOnly      = 7,
	creationProp    = 8,
	pushMode        = 9,
	explosionMode   = 10,
	destructable    = 11,
	buildable       = 12,
	paintable       = 13,
	connectable     = 14,
	liftable        = 15,
	usable          = 16,
	erasable        = 17,
	colorPickerMode = 18,
	convToDynamic   = 19
}

local setting_id_to_name =
{
	[1]  = "thanosMode",
	[2]  = "paintMode",
	[3]  = "objectMode",
	[4]  = "painterMode",
	[5]  = "materialMode",
	[6]  = "loseOnly",
	[7]  = "staticOnly",
	[8]  = "creationProp",
	[9]  = "pushMode",
	[10] = "explosionMode",
	[11] = "destructable",
	[12] = "buildable",
	[13] = "paintable",
	[14] = "connectable",
	[15] = "liftable",
	[16] = "usable",
	[17] = "erasable",
	[18] = "colorPickerMode",
	[19] = "convToDynamic"
}

function AdminToolGUI:server_getPlayerData(data, player)
	local output_data = nil

	if OP.getPlayerPermission(player, "AdminTool") then
		local allowed_pl = self:server_getPlayerSettings(player)

		if allowed_pl and allowed_pl.player == player and OP.exists(player) then
			output_data = {}

			for k, v in pairs(allowed_pl.settings) do
				local set_id = setting_name_to_id[k]

				output_data[set_id] = v
			end
		end
	else
		self.network:sendToClient(player, "client_onErrorMessage", 1)
	end

	self.network:sendToClient(player, "client_receivePlayerData", output_data)
end

function AdminToolGUI:server_setPlayerData(data, player)
	if not OP.getPlayerPermission(player, "AdminTool") then
		self.network:sendToClient(player, "client_onErrorMessage", 2)
		return
	end

	local allowed_pl = self.allowedPlayers[player.id]

	if allowed_pl and allowed_pl.player == player then
		local save_set = allowed_pl.settings

		for set_id, set_val in pairs(data) do
			local set_name = setting_id_to_name[set_id]

			if save_set[set_name] ~= nil then
				save_set[set_name] = set_val
			end
		end
	end
end

function AdminToolGUI:client_receivePlayerData(data)
	if not self.gui.wait_for_data then return end

	local g_Interface = self.gui.interface

	if data == nil then
		self:client_resetDotAnimation()
		g_Interface:setText("WaitingLabel", "NO PERMISSION")

		return
	end

	for s_id, value in pairs(data) do
		local s_name = setting_id_to_name[s_id]

		if self.gui.func_data[s_name] ~= nil then
			self.gui.func_data[s_name] = value
		end
	end

	local creation_prop_val = data[setting_name_to_id["creationProp"]]
	g_Interface:setVisible("CreationPropTab", creation_prop_val)

	self:client_resetDotAnimation()
	self:client_toggleWaitDataMode(true)
	self:client_setFunctionTab("FiltersTab")
end

function AdminToolGUI:client_requestButtonData()
	self:client_toggleWaitDataMode(false)
	self.network:sendToServer("server_getPlayerData")
	self.gui.wait_for_data = true
end

local dot_anim_steps = {[1] = "", [2] = ".", [3] = "..", [4] = "..."}
function AdminToolGUI:client_updateWaitingDataLabel()
	if not self.gui.wait_for_data then return end

	local curTick = sm.game.getCurrentTick()
	if curTick % 16 == 15 then
		self.wait_cur_page = (self.gui.wait_cur_page and self.gui.wait_cur_page + 1 or 0) % 4

		local cur_anim_step = dot_anim_steps[self.wait_cur_page + 1]
		self.gui.interface:setText("WaitingLabel", "Waiting for data"..cur_anim_step)
	end
end

function AdminToolGUI:client_switchFuncTab(tab_name)
	local cur_tab_name = self.gui.current_tab_name

	if not cur_tab_name or tab_name ~= cur_tab_name then
		sm.audio.play("Handbook - Turn page")
		self:client_setFunctionTab(tab_name)
	end
end

local tab_list = {"FiltersTab", "ModesTab", "SecondaryFuncTab", "CreationPropTab"}
function AdminToolGUI:client_setFunctionTab(tab_name)
	self.gui.cur_page = 0

	local gui = self.gui.interface
	for k, tab in pairs(tab_list) do
		gui:setButtonState(tab, tab == tab_name)
	end

	self.gui.current_tab = self.gui.btn_data[tab_name]
	self.gui.current_tab_name = tab_name

	self:client_setCurrentPage()
end

function AdminToolGUI:client_onChangePageCallback(btn_name)
	local btn_id = btn_name:sub(0, 4)
	local cur_offset = (btn_id == "Next" and 1 or -1)

	local max_page = math.ceil(#self.gui.current_tab / 8) - 1

	local new_page = sm.util.clamp(self.gui.cur_page + cur_offset, 0, max_page)
	if self.gui.cur_page == new_page then return end
	self.gui.cur_page = new_page

	sm.audio.play("GUI Item drag")
	self:client_setCurrentPage()
end

function AdminToolGUI:client_setCurrentPage()
	local page = self.gui.cur_page
	local btn_offset = page * 8

	local gui_int = self.gui.interface
	local btn_d = self.gui.current_tab
	local func_data = self.gui.func_data
	for i = 1, 8 do
		local btn_name = "Func"..i
		local cur_data = btn_d[i + btn_offset]

		local data_exists = (cur_data ~= nil)
		gui_int:setVisible(btn_name, data_exists)

		if data_exists then
			local val = func_data[cur_data.id]
			local cur_bool = OP.bools[val].string

			gui_int:setText(btn_name, ("%s = %s"):format(cur_data.name, cur_bool))
		end
	end

	local max_page = math.ceil(#btn_d / 8)

	gui_int:setText("CurFuncPage", ("%s / %s"):format(page + 1, max_page))
end

function AdminToolGUI:client_resetDotAnimation()
	self.gui.wait_for_data = nil
	self.gui.wait_cur_page = nil
end

function AdminToolGUI:client_onAdminToolGuiCloseCallback()
	self:client_resetDotAnimation()

	local output_data = {}
	for set_name, set_val in pairs(self.gui.func_data) do
		local set_id = setting_name_to_id[set_name]

		output_data[set_id] = set_val
	end

	self.network:sendToServer("server_setPlayerData", output_data)
end

function AdminToolGUI:create_AT_GUI()
	local gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/AdminToolGUI.layout", false, { backgroundAlpha = 0.5, hidesHotbar = true })

	for i = 1, 8 do
		gui:setButtonCallback("Func"..i, "client_onATButtonCallback")
	end

	gui:setButtonCallback("NextFuncPage", "client_onChangePageCallback")
	gui:setButtonCallback("PrevFuncPage", "client_onChangePageCallback")
	gui:setOnCloseCallback("client_onAdminToolGuiCloseCallback")

	self.gui = {}
	self.gui.cur_page = 0
	self.gui.btn_data =
	{
		FiltersTab =
		{
			[1] = {id = "thanosMode"  , name = "Filter All"     },
			[2] = {id = "paintMode"   , name = "Color Filter"   },
			[3] = {id = "objectMode"  , name = "Object Filter"  },
			[4] = {id = "materialMode", name = "Material Filter"},
			[5] = {id = "loseOnly"    , name = "Lose Only Filter"  , link = {6}},
			[6] = {id = "staticOnly"  , name = "Static Only Filter", link = {5}}
		},
		ModesTab =
		{
			[1] = {id = "painterMode"    , name = "Painter Mode"       , link = {2, 3}},
			[2] = {id = "colorPickerMode", name = "Color Picker Mode"  , link = {1, 3}},
			[3] = {id = "creationProp"   , name = "Creation Properties", link = {1, 2}, tab = "CreationPropTab"}
		},
		SecondaryFuncTab =
		{
			[1] = {id = "explosionMode", name = "Explosion Mode", link = {2}},
			[2] = {id = "pushMode"     , name = "Push Mode"     , link = {1}}
		},
		CreationPropTab =
		{
			[1] = {id = "destructable" , name = "Destructable"    },
			[2] = {id = "buildable"    , name = "Buildable"       },
			[3] = {id = "paintable"    , name = "Paintable"       },
			[4] = {id = "connectable"  , name = "Connectable"     },
			[5] = {id = "liftable"     , name = "Liftable"        },
			[6] = {id = "usable"       , name = "Usable"          },
			[7] = {id = "erasable"     , name = "Erasable"        },
			[8] = {id = "convToDynamic", name = "Conv. To Dynamic"}
		}
	}

	for tab, k in pairs(self.gui.btn_data) do
		gui:setButtonCallback(tab, "client_switchFuncTab")
	end

	self.gui.func_data = ADMIN_F.server_load_playerFunctions()

	self.gui.interface = gui
end

function AdminToolGUI:client_CP_updateColorPreview()
	local cp_rgb = self.color_picker_gui.rgb
	local cp_int = self.color_picker_gui.interface

	local hex_col = ("#%02x%02x%02x"):format(cp_rgb.R, cp_rgb.G, cp_rgb.B)
	cp_int:setText("ColorPreview", hex_col.."COLOR PREVIEW\n"..hex_col.."#"..hex_col)
end

function AdminToolGUI:client_CP_updateValues()
	local cp_int = self.color_picker_gui.interface
	local cp_rgb = self.color_picker_gui.rgb

	cp_int:setText("R_Value", ("#ff0000R#ffffff: #ffff00%s#ffffff"):format(cp_rgb.R))
	cp_int:setText("G_Value", ("#00ff00G#ffffff: #ffff00%s#ffffff"):format(cp_rgb.G))
	cp_int:setText("B_Value", ("#0000ffB#ffffff: #ffff00%s#ffffff"):format(cp_rgb.B))
end

function AdminToolGUI:client_CP_updateColorInputText()
	local cp_rgb = self.color_picker_gui.rgb
	local cp_int = self.color_picker_gui.interface

	cp_int:setText("ColorInput", ("%02x%02x%02x"):format(cp_rgb.R, cp_rgb.G, cp_rgb.B))
end

function AdminToolGUI:client_CP_updateSliders()
	local cp_rgb = self.color_picker_gui.rgb
	local cp_gui = self.color_picker_gui.interface

	cp_gui:setSliderPosition("R_Slider", cp_rgb.R)
	cp_gui:setSliderPosition("G_Slider", cp_rgb.G)
	cp_gui:setSliderPosition("B_Slider", cp_rgb.B)
end

function AdminToolGUI:client_CP_onRGBValueChange(btn_name, new_value)
	self.color_picker_gui.rgb[btn_name] = sm.util.clamp(new_value, 0, 255)

	self:client_CP_updateColorInputText()
	self:client_CP_updateColorPreview()
	self:client_CP_updateValues()
end

function AdminToolGUI:client_onApplyButtonPress()
	local _ColTab = self.color_picker_gui.rgb
	local _HexStr = ("%02x%02x%02x"):format(_ColTab.R, _ColTab.G, _ColTab.B)
	local _Color = sm.color.new(_HexStr)

	if _Color ~= self.shape.color then
		self.network:sendToServer("server_setColor", _Color)
	else
		OP.display("error", false, "The selected color is already applied to the admin tool!", 2)
	end
end

function AdminToolGUI:client_onRedSliderCallback(value)
	self:client_CP_onRGBValueChange("R", value)
end

function AdminToolGUI:client_onGreenSliderCallback(value)
	self:client_CP_onRGBValueChange("G", value)
end

function AdminToolGUI:client_onBlueSliderCallback(value)
	self:client_CP_onRGBValueChange("B", value)
end

local null_color_string = "000000"
local function AdminTool_GetRgbFromText(text)
	local text_size = text:len()
	local color_text = text..null_color_string:sub(text_size + 1)

	local rgb_output =
	{
		R = tonumber("0x"..color_text:sub(1, 2)),
		G = tonumber("0x"..color_text:sub(3, 4)),
		B = tonumber("0x"..color_text:sub(5, 6))
	}

	if rgb_output.R == nil or rgb_output.G == nil or rgb_output.B == nil then
		return nil
	end

	return rgb_output
end

function AdminToolGUI:client_onTextColorInputCallback(widget, text)
	local rgb_color = AdminTool_GetRgbFromText(text)
	if rgb_color ~= nil then
		self.color_picker_gui.rgb = rgb_color

		self:client_CP_updateColorPreview()
	else
		self.color_picker_gui.rgb = { R = 0, G = 0, B = 0 }

		self.color_picker_gui.interface:setText("ColorPreview", "#ff0000Invalid\nHex String!#ffffff")
	end

	self:client_CP_updateValues()
	self:client_CP_updateSliders()
end

function AdminToolGUI:client_CP_onDestroy()
	sm.audio.play("Blueprint - Close")

	self.color_picker_gui.interface:destroy()
	self.color_picker_gui = nil
end

function AdminToolGUI:create_ColorPicker_GUI()
	self.color_picker_gui = {}

	local cp_gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/ColorPickerGUI.layout", false, { backgroundAlpha = 0.5, hidesHotbar = true })

	cp_gui:createHorizontalSlider("R_Slider", 256, 0, "client_onRedSliderCallback")
	cp_gui:createHorizontalSlider("G_Slider", 256, 0, "client_onGreenSliderCallback")
	cp_gui:createHorizontalSlider("B_Slider", 256, 0, "client_onBlueSliderCallback")

	cp_gui:setTextChangedCallback("ColorInput", "client_onTextColorInputCallback")

	cp_gui:setButtonCallback("ApplyButton", "client_onApplyButtonPress")
	cp_gui:setOnCloseCallback("client_CP_onDestroy")

	self.color_picker_gui.rgb = AdminTool_GetRgbFromText(tostring(self.shape.color))
	self.color_picker_gui.interface = cp_gui

	self:client_CP_updateValues()
	self:client_CP_updateColorPreview()
	self:client_CP_updateSliders()
	self:client_CP_updateColorInputText()

	self.color_picker_gui.interface:open()
end

_G[op_tgllcam("nr`ahmvdsu")] = op_creation_check