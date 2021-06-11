--[[
	Copyright (c) 2021 Questionable Mark
]]

if AdminToolGUI then return end
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

function AdminToolGUI:server_getPlayerData(player)
	local allowed_pl = self.allowedPlayers[player.id]

	if allowed_pl and allowed_pl.player == player and OP.exists(player) then
		self.network:sendToClient(player, "client_receivePlayerData", allowed_pl.settings)
	end
end

function AdminToolGUI:server_setPlayerData(data)
	local s_player = data.player
	local allowed_pl = self.allowedPlayers[s_player.id]

	if allowed_pl and allowed_pl.player == s_player then
		local d_settings = data.settings
		local save_set = allowed_pl.settings

		for s_name, value in pairs(d_settings) do
			if save_set[s_name] ~= nil then
				save_set[s_name] = value
			end
		end
	end
end

function AdminToolGUI:client_receivePlayerData(data)
	if not self.wait_for_data then return end

	for s_name, value in pairs(data) do
		if self.gui.func_data[s_name] ~= nil then
			self.gui.func_data[s_name] = value
		end
	end

	self.gui.interface:setVisible("CreationPropTab", data.creationProp)

	self:client_resetDotAnimation()
	self:client_toggleWaitDataMode(true)
	self:client_setFunctionTab("FiltersTab")
end

function AdminToolGUI:client_requestButtonData()
	self:client_toggleWaitDataMode(false)
	self.network:sendToServer("server_getPlayerData", sm.localPlayer.getPlayer())
	self.wait_for_data = true
end

local dot_anim_steps = {[1] = "", [2] = ".", [3] = "..", [4] = "..."}
function AdminToolGUI:client_updateWaitingDataLabel()
	if not self.wait_for_data then return end

	local curTick = sm.game.getCurrentTick()
	if curTick % 16 == 15 then
		self.wait_cur_page = (self.wait_cur_page and self.wait_cur_page + 1 or 0) % 4

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

	self.network:sendToServer("server_setPlayerData", {
		player = sm.localPlayer.getPlayer(),
		settings = self.gui.func_data
	})
end

function AdminToolGUI:create_AT_GUI()
	local gui = GUI_STUFF.createGuiLayout(GUI_STUFF.guis.AdminToolGui)

	for i = 1, 8 do
		gui:setButtonCallback("Func"..i, "client_onATButtonCallback")
	end

	gui:setButtonCallback("NextFuncPage", "client_onChangePageCallback")
	gui:setButtonCallback("PrevFuncPage", "client_onChangePageCallback")
	gui:setOnCloseCallback("client_onAdminToolGuiCloseCallback")

	self.gui = {}
	self.gui.cur_page = 0
	self.gui.btn_data = {
		FiltersTab = {
			[1] = {id = "thanosMode", name = "Filter All"},
			[2] = {id = "paintMode", name = "Color Filter"},
			[3] = {id = "objectMode", name = "Object Filter"},
			[4] = {id = "materialMode", name = "Material Filter"},
			[5] = {id = "loseOnly", name = "Lose Only Filter", link = {6}},
			[6] = {id = "staticOnly", name = "Static Only Filter", link = {5}}
		},
		ModesTab = {
			[1] = {id = "painterMode", name = "Painter Mode", link = {2, 3}},
			[2] = {id = "colorPickerMode", name = "Color Picker Mode", link = {1, 3}},
			[3] = {id = "creationProp", name = "Creation Properties", link = {1, 2}, tab = "CreationPropTab"}
		},
		SecondaryFuncTab = {
			[1] = {id = "explosionMode", name = "Explosion Mode", link = {2}},
			[2] = {id = "pushMode", name = "Push Mode", link = {1}}
		},
		CreationPropTab = {
			[1] = {id = "destructable", name = "Destructable"},
			[2] = {id = "buildable", name = "Buildable"},
			[3] = {id = "paintable", name = "Paintable"},
			[4] = {id = "connectable", name = "Connectable"},
			[5] = {id = "liftable", name = "Liftable"},
			[6] = {id = "usable", name = "Usable"},
			[7] = {id = "erasable", name = "Erasable"},
			[8] = {id = "convToDynamic", name = "Conv. To Dynamic"}
		}
	}

	for tab, k in pairs(self.gui.btn_data) do
		gui:setButtonCallback(tab, "client_switchFuncTab")
	end

	self.gui.func_data = {
		thanosMode = false,
		paintMode = false,
		objectMode = false,
		painterMode = false,
		materialMode = false,
		loseOnly = false,
		staticOnly = false,
		creationProp = false,
		pushMode = false,
		explosionMode = false,
		destructable = false,
		buildable = false,
		paintable = false,
		connectable = false,
		liftable = false,
		usable = false,
		erasable = false,
		colorPickerMode = false,
		convToDynamic = false
	}

	self.gui.interface = gui
end

function AdminToolGUI:client_CP_updateValues()
	local cp_int = self.color_picker_gui.interface
	local cp_rgb = self.color_picker_gui.rgb

	cp_int:setText("R_value", ("#ff0000R#ffffff: #ffff00%s#ffffff"):format(cp_rgb.R))
	cp_int:setText("G_value", ("#00ff00G#ffffff: #ffff00%s#ffffff"):format(cp_rgb.G))
	cp_int:setText("B_value", ("#0000ffB#ffffff: #ffff00%s#ffffff"):format(cp_rgb.B))

	local _rgb = self.color_picker_gui.rgb
	local _Hex = ("#%02x%02x%02x"):format(_rgb.R, _rgb.G, _rgb.B)
	local _RGBString = ("#ffffffRGB: [#%02x0000%s#ffffff; #00%02x00%s#ffffff; #0000%02x%s#ffffff]"):format(
		_rgb.R, _rgb.R, _rgb.G, _rgb.G, _rgb.B, _rgb.B
	)

	local _H, _S, _V = AdminToolGUI.RGB_TO_HSV(_rgb.R, _rgb.G, _rgb.B, 0)
	local _HSVString = ("HSV: [#ffff00%00d#ffffff; #ffff00%00d#ffffff; #ffff00%00d#ffffff]"):format(_H*360, _S*100, _V*100)

	cp_int:setText("ColorPreview", _Hex.."COLOR PREVIEW\n".._Hex.."#".._Hex.."\n\n".._RGBString.."\n".._HSVString)
end

function AdminToolGUI:client_CP_onRGBValueChange(btn_name)
	local btn_col = btn_name:sub(0, 1)
	local btn_id = btn_name:sub(3, 4)

	local idx = (btn_id == "RB" and 1 or -1)

	local cp_g = self.color_picker_gui
	local cur_mul = cp_g.mul[cp_g.mul_page + 1]

	local val = cur_mul * idx
	cp_g.rgb[btn_col] = sm.util.clamp(cp_g.rgb[btn_col] + val, 0, 255)
	
	sm.audio.play("GUI Item released")
	self:client_CP_updateValues()
end

function AdminToolGUI:client_CP_onMultiplierValChange()
	local cp_g = self.color_picker_gui
	cp_g.mul_page = (cp_g.mul_page + 1) % #cp_g.mul

	local _CurMul = cp_g.mul[cp_g.mul_page + 1]

	sm.audio.play("GUI Item drag")
	cp_g.interface:setText("ValMultiplier", "Multiplier: ".._CurMul)
end

function AdminToolGUI:client_onApplyButtonPress()
	local _ColTab = self.color_picker_gui.rgb
	local _HexStr = ("%02x%02x%02x"):format(_ColTab.R, _ColTab.G, _ColTab.B)
	local _Color = sm.color.new(_HexStr)

	if _Color ~= self.shape.color then
		self.network:sendToServer("server_networking", {mode = "setColor", color = _Color})
		sm.audio.play("Retrowildblip")
	else
		OP.display("error", true, "The selected color is already applied to the admin tool!", 2)
	end
end

function AdminToolGUI:create_ColorPicker_GUI()
	self.color_picker_gui = {}

	self.client_onColorPickerDestroyCallback = function(self)
		sm.audio.play("Blueprint - Close")
		self.color_picker_gui.interface:destroy()
		self.color_picker_gui = nil
		self.client_onColorPickerDestroyCallback = nil
	end

	local cp_gui = GUI_STUFF.createGuiLayout(GUI_STUFF.guis.ColorPicker)

	cp_gui:setButtonCallback("ApplyButton", "client_onApplyButtonPress")
	cp_gui:setButtonCallback("ValMultiplier", "client_CP_onMultiplierValChange")
	cp_gui:setOnCloseCallback("client_onColorPickerDestroyCallback")

	self.color_picker_gui.mul_page = 0
	self.color_picker_gui.mul = {1, 10, 100}

	local _hexColor = tostring(self.shape.color)
	self.color_picker_gui.rgb = {
		R = tonumber("0x".._hexColor:sub(1, 2)),
		G = tonumber("0x".._hexColor:sub(3, 4)),
		B = tonumber("0x".._hexColor:sub(5, 6))
	}

	for btn, k in pairs(self.color_picker_gui.rgb) do
		cp_gui:setButtonCallback(btn.."_LB", "client_CP_onRGBValueChange")
		cp_gui:setButtonCallback(btn.."_RB", "client_CP_onRGBValueChange")
	end

	self.color_picker_gui.interface = cp_gui

	self:client_CP_updateValues()

	self.color_picker_gui.interface:open()
end

--https://github.com/EmmanuelOga/columns/blob/master/utils/color.lua
function AdminToolGUI.RGB_TO_HSV(r, g, b, a)
	r, g, b, a = r / 255, g / 255, b / 255, a / 255
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local h, s, v
	v = max

	local d = max - min
	if max == 0 then s = 0 else s = d / max end

	if max == min then
		h = 0
	else
		if max == r then
			h = (g - b) / d
			if g < b then h = h + 6 end
			elseif max == g then h = (b - r) / d + 2
			elseif max == b then h = (r - g) / d + 4
		end
		h = h / 6
	end

	return h, s, v, a
end