--[[
    Copyright (c) 2021 Questionable Mark
]]

if ADMIN_F then return end
ADMIN_F = class(nil)

function ADMIN_F.server_load_playerFunctions()
    local player_functions = {
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
        colorPickerMode = false
    }
    return player_functions
end

function ADMIN_F.checkFunctions(object_mode, paint_mode, material_mode, lose_only, static_only, tool_raycast, other_raycast)
    local object, color, material, lose, static = nil

    local isValid = type(tool_raycast) == "RaycastResult" and tool_raycast.valid and tool_raycast.type == "body"
    local isRaycast = type(other_raycast) == "RaycastResult"

    local object_mode_secondArg = isRaycast and other_raycast:getShape():getShapeUuid() or other_raycast:getShapeUuid()
    local paint_mode_secondArg = isRaycast and other_raycast:getShape():getColor() or other_raycast:getColor()
    local material_mode_secondArg = isRaycast and other_raycast:getShape():getMaterial() or other_raycast:getMaterial()

    if object_mode then object = isValid and tool_raycast:getShape():getShapeUuid() == object_mode_secondArg end
    if paint_mode then color = isValid and tool_raycast:getShape():getColor() == paint_mode_secondArg end
    if material_mode then material = isValid and tool_raycast:getShape():getMaterial() == material_mode_secondArg end
    if lose_only and not static_only then lose = other_raycast:getBody():isDynamic() end
    if static_only and not lose_only then static = other_raycast:getBody():isStatic() end

    return object, color, material, lose, static
end

function ADMIN_F.load_serverFunctions()
    local server_functions = {
        admin = function(self, data)
            self.allowedPlayers[data.player.id] = {
                player = data.player,
                settings = ADMIN_F.server_load_playerFunctions()
            }
        end;
        r_admin = function(self, data)
            if self.allowedPlayers[data.player.id] ~= nil and self.allowedPlayers[data.player.id].player == data.player then
                self.allowedPlayers[data.player.id] = nil
            end
        end;
        getTabData = function(self, data)
            if self.allowedPlayers[data.player.id] ~= nil and self.allowedPlayers[data.player.id].settings ~= nil then
                if data.pFunction and (data.bool == true and self.allowedPlayers[data.player.id].settings[data.pFunction] == true) then
                    self.allowedPlayers[data.player.id].settings[data.pFunction] = false
                end
                self.allowedPlayers[data.player.id].settings[data.id] = data.bool
            end
        end;
        setColor = function(self, data)
            if tostring(data.color) ~= tostring(self.shape.color) then
                self.shape:setColor(data.color)
            end
        end
    }
    return server_functions
end

function ADMIN_F.load_guiInfo()
    local gui_options = {
        page = -1,
        option_page = -1,
        options = {
            [1] = {
                name = "Filters",
                params = {
                    [1] = {name = "Filter All Mode", bool = false, id = "thanosMode"},
                    [2] = {name = "Color Filter Mode", bool = false, id = "paintMode"},
                    [3] = {name = "Object Filter Mode", bool = false, id = "objectMode"},
                    [4] = {name = "Material Filter Mode", bool = false, id = "materialMode"},
                    [5] = {name = "Lose Only Filter", bool = false, id = "loseOnly", pairedFunction = "staticOnly", pairedId = 6},
                    [6] = {name = "Static Only Filter", bool = false, id = "staticOnly", pairedFunction = "loseOnly", pairedId = 5}
                }
            },
            [2] = {
                name = "Modes",
                params = {
                    [1] = {name = "Painter Mode", bool = false, id = "painterMode"}
                }
            },
            [3] = {
                name = "Secondary Functions",
                params = {
                    [1] = {name = "Push Mode", bool = false, id = "pushMode", pairedFunction = "explosionMode", pairedId = 2},
                    [2] = {name = "Explosion Mode", bool = false, id = "explosionMode", pairedFunction = "pushMode", pairedId = 1}
                }
            }
        }
    }
    return gui_options
end

function ADMIN_F.load_adminTool_instruction()
    instruction = (
        "\n#ff0000COLOR PICKER INSTRUCTION#ffffff:\n"..
        "#ffff00%s#ffffff - go out of the color picker mode\n"..
        "#ffff00%s#ffffff - pick the color of the shape you're looking at\n"..
        "#ffff00%s#ffffff - give the color to the admin tool\n"..
        "#ffff00%s#ffffff/#ffff00%s#ffffff or #ffff00%s#ffffff/#ffff00%s#ffffff - change the color value of the selected colors\n"..
        "hold #ffff00%s#ffffff - select #ff0000R#ffffff value to change\n"..
        "hold #ffff00%s#ffffff - select #00ff00G#ffffff value to change\n"..
        "hold #ffff00%s#ffffff - select #0000ffB#ffffff value to change\n"..
        "hold #ffff00%s#ffffff - to double the scroll speed\n"
    ):format(
        sm.gui.getKeyBinding("Use"),
        sm.gui.getKeyBinding("Attack"),
        sm.gui.getKeyBinding("Create"),
        sm.gui.getKeyBinding("ZoomIn"), sm.gui.getKeyBinding("ZoomOut"), sm.gui.getKeyBinding("PreviousMenuItem"), sm.gui.getKeyBinding("NextMenuItem"),
        sm.gui.getKeyBinding("MenuItem0"),
        sm.gui.getKeyBinding("MenuItem1"),
        sm.gui.getKeyBinding("MenuItem2"),
        sm.gui.getKeyBinding("Jump")
    )
    return instruction
end