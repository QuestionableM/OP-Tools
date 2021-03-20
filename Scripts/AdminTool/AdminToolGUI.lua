--[[
    Copyright (c) 2021 Questionable Mark
]]

if AdminToolGUI then return end
AdminToolGUI = class()

function AdminToolGUI.client_onGuiCallback(self, caller_btn)
    if not GUI_STUFF.is_gui_supported() then return end
    self.new_gui.buttonData[caller_btn].state = not self.new_gui.buttonData[caller_btn].state
    local currentButton = self.new_gui.buttonData[caller_btn]
    self.new_gui.interface:setText(caller_btn, (currentButton.name.." = %s"):format(OP.bools[currentButton.state].string))
    if type(currentButton.pB) == "table" then
        for id, button in pairs(currentButton.pB) do
            if self.new_gui.buttonData[button] ~= nil and self.new_gui.buttonData[button].state then
                self.new_gui.buttonData[button].state = false
                self.new_gui.interface:setText(button, (self.new_gui.buttonData[button].name.." = %s"):format(OP.bools[self.new_gui.buttonData[button].state].string))
            end
        end
    end
    sm.audio.play(OP.bools[currentButton.state].sound)
end

local function togglePage(self, filter_p, mode_p, sOp_p, filter_t, mode_t, sF_t)
    if not GUI_STUFF.is_gui_supported() then return end
    sm.audio.play("Handbook - Turn page")
    self.new_gui.interface:setVisible("FiltersPage", filter_p)
    self.new_gui.interface:setVisible("ModesPage", mode_p)
    self.new_gui.interface:setVisible("SecondaryOptionsPage", sOp_p)
    self.new_gui.interface:setButtonState("FiltersTab", filter_t)
    self.new_gui.interface:setButtonState("ModesTab", mode_t)
    self.new_gui.interface:setButtonState("SFunctionsTab", sF_t)
end

function AdminToolGUI.client_onFiltersTabCallback(self) togglePage(self, true, false, false, true, false, false) end
function AdminToolGUI.client_onModesTabCallback(self) togglePage(self, false, true, false, false, true, false) end
function AdminToolGUI.client_onSecondaryModeCallback(self) togglePage(self, false, false, true, false, false, true) end

function AdminToolGUI.server_sendButtonData(self, player)
    if not GUI_STUFF.is_gui_supported() then return end
    if self.allowedPlayers[player.id] ~= nil and self.allowedPlayers[player.id].player == player then
        local bD = self.allowedPlayers[player.id].settings
        self.network:sendToClient(player, "client_receiveButtonData", {
            {button = "FilterAll", state = bD.thanosMode},
            {button = "ColorFilter", state = bD.paintMode},
            {button = "ObjectFilter", state = bD.objectMode},
            {button = "MatFilter", state = bD.materialMode},
            {button = "LoseOnly", state = bD.loseOnly},
            {button = "StaticOnly", state = bD.staticOnly},
            {button = "PainterMode", state = bD.painterMode},
            {button = "PushMode", state = bD.pushMode},
            {button = "ExplMode", state = bD.explosionMode},
            {button = "ColorPicker", state = bD.colorPickerMode}
        })
    end
end
function AdminToolGUI.client_requestButtonData(self)
    self.network:sendToServer("server_sendButtonData", sm.localPlayer.getPlayer())
end

function AdminToolGUI.client_receiveButtonData(self, data)
    if not GUI_STUFF.is_gui_supported() then return end
    for button, b_data in pairs(self.new_gui.buttonData) do
        for b, button_data in pairs(data) do
            if button == button_data.button and button_data.state ~= b_data.state then
                self.new_gui.buttonData[button].state = button_data.state
                self.new_gui.interface:setText(button, (b_data.name.." = %s"):format(OP.bools[self.new_gui.buttonData[button].state].string))
            end
        end
    end
end

function AdminToolGUI.client_onATGUI_close(self)
    local packedButtonData = {}
    for id, buttonData in pairs(self.new_gui.buttonData) do
        packedButtonData[#packedButtonData + 1] = {state = buttonData.state, id = buttonData.id}
    end
    self.network:sendToServer("server_receiveGUIButtonData", {
        caller = sm.localPlayer.getPlayer(),
        bData = packedButtonData
    })
end

function AdminToolGUI.server_receiveGUIButtonData(self, data)
    if not GUI_STUFF.is_gui_supported() then return end
    if self.allowedPlayers[data.caller.id] ~= nil and self.allowedPlayers[data.caller.id].player == data.caller then
        for id, buttonData in pairs(data.bData) do
            if self.allowedPlayers[data.caller.id].settings[buttonData.id] ~= nil then
                self.allowedPlayers[data.caller.id].settings[buttonData.id] = buttonData.state
            end
        end
    end
end

function AdminToolGUI.construct_AT_GUI(self, callback_table, on_destroy_callback)
    if not GUI_STUFF.is_gui_supported() then return end
    local gui = GUI_STUFF.createGuiLayout(GUI_STUFF.guis.AdminToolGui)

    gui:setButtonCallback("FiltersTab", "client_onFiltersTabCallback")
    gui:setButtonCallback("ModesTab", "client_onModesTabCallback")
    gui:setButtonCallback("SFunctionsTab", "client_onSecondaryModeCallback")

    for id, callback in pairs(callback_table) do
        self[callback.callback] = function(self)
            self:client_onGuiCallback(callback.button)
        end

        gui:setButtonCallback(callback.button, callback.callback)
        local currentButton = self.new_gui.buttonData[callback.button]
        gui:setText(callback.button, (currentButton.name.." = %s"):format(OP.bools[currentButton.state].string))
    end

    if on_destroy_callback then gui:setOnCloseCallback(on_destroy_callback) end
    return gui
end

function AdminToolGUI.create_AT_GUI(self)
    if not GUI_STUFF.is_gui_supported() then return end
    self.new_gui.interface = AdminToolGUI.construct_AT_GUI(self, {
            [1] = {button = "FilterAll", callback = "client_onFilterAllCallback"},
            [2] = {button = "ColorFilter", callback = "client_onColorFilterCallback"},
            [3] = {button = "ObjectFilter", callback = "client_onObjectFilterCallback"},
            [4] = {button = "MatFilter", callback = "client_onMatFilterCallback"},
            [5] = {button = "LoseOnly", callback = "client_onLoseOnlyCallback"},
            [6] = {button = "StaticOnly", callback = "client_onStaticOnlyCallback"},
            [7] = {button = "PainterMode", callback = "client_onPainterModeCallback"},
            [8] = {button = "PushMode", callback = "client_onPushModeCallback"},
            [9] = {button = "ExplMode", callback = "client_onExplModeCallback"},
            [10] = {button = "ColorPicker", callback = "client_onColorPickerModeCallback"}
        }, "client_onATGUI_close"
    )
end

function AdminToolGUI.client_PrepareColorPicker_GUI(self, data)
    local _gui = GUI_STUFF.createGuiLayout(GUI_STUFF.guis.ColorPicker)
    self.client_ColorPicker_onDestroy = function(self)
        sm.audio.play("Blueprint - Close")
        self.ColorPicker_onDestroy = nil
        self.color_picker_gui.interface:destroy()
        self.color_picker_gui = nil
    end
    _gui:setOnCloseCallback("client_ColorPicker_onDestroy")

    for i, k in pairs(data) do
        if k.d_button then
            local _FuncNameRight = "client_onRight"..k.button.."press"
            local _FuncNameLeft = "client_onLeft"..k.button.."press"
            self[_FuncNameRight] = function(self)
                self:client_onRGBValueChange(k.val, 1)
            end
            self[_FuncNameLeft] = function(self)
                self:client_onRGBValueChange(k.val, -1)
            end
            _gui:setButtonCallback(k.button.."LB", _FuncNameLeft)
            _gui:setButtonCallback(k.button.."RB", _FuncNameRight)
        elseif k.callback then
            _gui:setButtonCallback(k.button, k.callback)
        end
    end

    return _gui
end

function AdminToolGUI.create_ColorPicker_GUI(self)
    if not GUI_STUFF.is_gui_supported() then return end
    self.color_picker_gui = {}
    self.color_picker_gui.interface = AdminToolGUI.client_PrepareColorPicker_GUI(self, {
        {button = "G_", d_button = true, val = "G_value"},
        {button = "R_", d_button = true, val = "R_value"},
        {button = "B_", d_button = true, val = "B_value"},
        {button = "ValMultiplier", callback = "client_onValMultiplierChange"},
        {button = "ApplyButton", callback = "client_onApplyButtonPress"}
    })
    self.color_picker_gui.char_tab = {
        R_value = "#ff0000R#ffffff",
        G_value = "#00ff00G#ffffff",
        B_value = "#0000ffB#ffffff"
    }
    local _hexColor = tostring(self.shape.color)
    self.color_picker_gui.rgb = {
        R_value = tonumber("0x".._hexColor:sub(1, 2)),
        G_value = tonumber("0x".._hexColor:sub(3, 4)),
        B_value = tonumber("0x".._hexColor:sub(5, 6))
    }
    self.color_picker_gui.multiplier = {
        page = 0,
        tab = {[1] = 1, [2] = 10, [3] = 100}
    }
    self.color_picker_gui.interface:setText("R_value", "#ff0000R#ffffff: #ffff00"..self.color_picker_gui.rgb.R_value.."#ffffff")
    self.color_picker_gui.interface:setText("G_value", "#00ff00G#ffffff: #ffff00"..self.color_picker_gui.rgb.G_value.."#ffffff")
    self.color_picker_gui.interface:setText("B_value", "#0000ffB#ffffff: #ffff00"..self.color_picker_gui.rgb.B_value.."#ffffff")
    AdminToolGUI.client_UpdateColorPickerPreview(self)
    self.color_picker_gui.interface:open()
end

function AdminToolGUI.client_UpdateColorPickerPreview(self)
    local _rgb = self.color_picker_gui.rgb
    local _Hex = ("#%02x%02x%02x"):format(_rgb.R_value, _rgb.G_value, _rgb.B_value)
    local _RGBString = ("#ffffffRGB: [#%02x0000%s#ffffff; #00%02x00%s#ffffff; #0000%02x%s#ffffff]"):format(
        _rgb.R_value, _rgb.R_value, _rgb.G_value, _rgb.G_value, _rgb.B_value, _rgb.B_value
    )
    local _H, _S, _V = AdminToolGUI.RGB_TO_HSV(_rgb.R_value, _rgb.G_value, _rgb.B_value, 0)
    local _HSVString = ("HSV: [#ffff00%00d#ffffff; #ffff00%00d#ffffff; #ffff00%00d#ffffff]"):format(_H*360, _S*100, _V*100)
    self.color_picker_gui.interface:setText("ColorPreview", _Hex.."COLOR PREVIEW\n".._Hex.."#".._Hex.."\n\n".._RGBString.."\n".._HSVString)
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

function AdminToolGUI.client_onApplyButtonPress(self)
    local _ColTab = self.color_picker_gui.rgb
    local _Color = sm.color.new(("%02x%02x%02x"):format(_ColTab.R_value, _ColTab.G_value, _ColTab.B_value))
    if tostring(_Color) ~= tostring(self.shape.color) then
        self.network:sendToServer("server_networking", {mode = "setColor", color = _Color})
        sm.audio.play("Retrowildblip")
    else
        OP.display("error", true, "The selected color is already applied to the admin tool!", 2)
    end
end

function AdminToolGUI.client_onRGBValueChange(self, index, value)
    local _CurMul = self.color_picker_gui.multiplier.tab[self.color_picker_gui.multiplier.page + 1]
    local _MulVal = value * _CurMul
    local _LastValue = self.color_picker_gui.rgb[index]
    self.color_picker_gui.rgb[index] = math.min(255, math.max(self.color_picker_gui.rgb[index] + _MulVal, 0))

    if _LastValue ~= self.color_picker_gui.rgb[index] then
        local _CurChar = self.color_picker_gui.char_tab[index]
        self.color_picker_gui.interface:setText(index, _CurChar..": #ffff00"..self.color_picker_gui.rgb[index].."#ffffff")
        sm.audio.play("GUI Item released")
        AdminToolGUI.client_UpdateColorPickerPreview(self)
    end
end

function AdminToolGUI.client_onValMultiplierChange(self)
    self.color_picker_gui.multiplier.page = (self.color_picker_gui.multiplier.page + 1) % #self.color_picker_gui.multiplier.tab
    local _CurrentMul = self.color_picker_gui.multiplier.tab[self.color_picker_gui.multiplier.page + 1]
    sm.audio.play("GUI Item drag")
    self.color_picker_gui.interface:setText("ValMultiplier", "Multiplier: ".._CurrentMul)
end