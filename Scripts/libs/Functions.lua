--[[
    Copyright (c) 2021 Questionable Mark
]]

if OP then return end
OP = class()

local constants = {
    isAdmin = false,
    lockedCamera = false,
    permissions = {
        AdminTool = false,
        WorldCleaner = false,
        PlayerKicker = false,
        FreeCamera = false
    },
    op_sounds = {
        error = "WeldTool - Error",
        blip = "Retrowildblip",
        highlight = "GUI Inventory highlight",
        noAmmo = "PotatoRifle - NoAmmo",
        drag = "GUI Item drag",
        release = "GUI Item released",
        open = "Blueprint - Open",
        close = "Blueprint - Close",
        delete = "Blueprint - Delete",
        build = "Blueprint - Build"
    }
}

OP.bools = {
    [true] = {string = "#00c000true#ffffff", sound = "Lever on"},
    [false] = {string = "#c00000false#ffffff", sound = "Lever off"}
}
OP.tool_uuids = {
    ["387edd9e-ed0f-4ea6-bf3c-2b40851225e7"] = true,
    ["c8e4139d-b93d-4df5-a292-382ad21215a9"] = true,
    ["26888ae6-d636-425d-87b9-1f75da083bfb"] = true,
    ["94a05693-da51-4910-b311-705299dc3656"] = true,
    ["07545436-fb40-459d-aaac-88ad5a9e4fc5"] = true
}

function OP.setAdminFlag() constants.isAdmin = true end
function OP.getAdminFlag() return constants.isAdmin end

function OP.getPermission(tool)
    if constants.permissions[tool] ~= nil then return constants.permissions[tool] end
end

function OP.setPermission(tool, bool)
    if constants.permissions[tool] ~= nil and not constants.isAdmin then constants.permissions[tool] = bool end
end

function OP.directionToRadians(dir)
    local result = {}
    result.pitch = math.asin(dir.z)
    result.yaw = math.atan2(dir.y, dir.x) - math.pi / 2
    return result
end

function OP.toggleLockedCamera()
    constants.lockedCamera = not constants.lockedCamera
    sm.localPlayer.setLockedControls(constants.lockedCamera)
end

function OP.setMainAdminTool(adminTool)
    if (constants.main_admin_tool ~= nil and constants.main_admin_tool == adminTool) then return end
    constants.main_admin_tool = adminTool
end

function OP.getMainAdminTool() return constants.main_admin_tool end

function OP.deleteMainAdminTool(adminTool)
    if adminTool ~= constants.main_admin_tool then return end
    constants.main_admin_tool = nil
end

function OP.display(sound, globalSound, text, duration)
    if constants == nil then return end
    if sound then
        if globalSound then
            sm.audio.play(constants.op_sounds[sound] or sound)
        else
            sm.audio.play(constants.op_sounds[sound] or sound, sm.camera.getPosition() + sm.camera.getDirection())
        end
    end
    if text then sm.gui.displayAlertText(text, duration or 3) end
end

function OP.betterExplosion(position, ExplosionLevel, explosionRadius, explosionImpulse, explosionMagnitude, effect, pushPlayers)
    sm.physics.explode(position, ExplosionLevel, explosionRadius, 1, 1, effect)
    for _,body in pairs(sm.body.getAllBodies()) do
        local distance = (position - body:getWorldPosition()):length()
        if distance < explosionMagnitude and body:isDynamic() then
            local direction = (position - body:getWorldPosition()):normalize()
            local impulse_strength = explosionImpulse - (explosionImpulse * (distance / explosionMagnitude))
            sm.physics.applyImpulse(body, -(direction * impulse_strength), true)
        end
    end
    if pushPlayers then
        for _, player in pairs(sm.player.getAllPlayers()) do
            local player_distance = (position - player.character.worldPosition):length()
            if player_distance < explosionMagnitude then
                local direction = (position - player.character.worldPosition):normalize()
                local player_impulse_strength = explosionImpulse - (explosionImpulse * (player_distance / explosionMagnitude))
                sm.physics.applyImpulse(player.character, -(direction * (player_impulse_strength / 10)), false)
            end
        end
    end
end

function OP.checkWorldPosition(cPos, limit)
    if math.abs(cPos.x) > limit or math.abs(cPos.y) > limit or math.abs(cPos.z) > limit then return true end
    return false
end

function OP.print(text) print("[OPTools] "..text) end

function OP.getAllPlayers_exc()
    local player_table = {}
    for id, player in pairs(sm.player.getAllPlayers()) do
        if player ~= sm.localPlayer.getPlayer() then table.insert(player_table, player) end
    end
    return player_table
end

function OP.exists(Item)
    local success, error = pcall(sm.exists, Item)
    if success and type(error) == "boolean" and error then return true end
    return false
end

function OP.deleteBodies(body_table, show_effect)
    for id, body in pairs(body_table) do
        if OP.exists(body) then
            for s_id, shape in pairs(body:getShapes()) do
                if OP.exists(shape) then
                    shape:destroyShape(0)
                    if show_effect then
                        sm.effect.playEffect("DeleteAll", shape.worldPosition)
                    end
                end
            end
        end
        body_table[id] = nil
    end
end

function OP.deleteShapes(shape_table, show_effect)
    for shape_id, shape in pairs(shape_table) do
        if OP.exists(shape) then
            shape:destroyShape(0)
            if show_effect then
                sm.effect.playEffect("DeleteAll", shape.worldPosition)
            end
        end
        shape_table[shape_id] = nil
    end
end

function OP.deleteUnits(unit_table, show_effect)
    for unit_id, unit in pairs(unit_table) do
        if OP.exists(unit) and unit.character then
            unit:destroy()
            if show_effect then
                sm.effect.playEffect("DeleteAll", unit.character.worldPosition)
            end
        end
        unit_table[unit_id] = nil
    end
end

function OP.isCreationStatic(creation)
    for id, body in pairs(creation) do
        if body:isDynamic() then return false end
    end
    return true
end

function OP.isCreationDynamic(creation)
    for id, body in pairs(creation) do
        if body:isStatic() then return false end
    end
    return true
end

function OP.isUnit(character)
    local _Unit = character:getUnit()
    return (_Unit and _Unit.id > 0)
end

function OP.getAllDynamicBodies()
    local dynamic_bodies = {}
    for id, creation in pairs(sm.body.getCreationsFromBodies(sm.body.getAllBodies())) do
        if OP.isCreationDynamic(creation) then
            for id, body in pairs(creation) do
                table.insert(dynamic_bodies, body)
            end
        end
    end
    return dynamic_bodies
end

print("[OPTools] function library has been loaded")