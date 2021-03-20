--[[
    Copyright (c) 2021 Questionable Mark
]]

if PlayerCrasher then return end
dofile("../libs/ScriptLoader.lua")
dofile("PlayerCrasherGUI.lua")
PlayerCrasher = class(PlayerCrasherGUI)
PlayerCrasher.connectionInput = sm.interactable.connectionType.none
PlayerCrasher.connectionOutput = sm.interactable.connectionType.none
PlayerCrasher.poseWeightCount = 1
function PlayerCrasher.server_onCreate(self)
    OP.setAdminFlag()
    self.server_admin = true
end
function PlayerCrasher.server_getCrashInfo(self, data)
    if type(data.player) == "Player" then
        self.network:sendToClient(data.player, "client_crash", {mode = data.mode, player = data.sender})
        OP.print("Crashing: "..data.player.name..", Player id: "..data.player.id..", Mode: "..data.mode)
    else
        self.network:sendToClients("client_crash", {mode = data.mode, player = data.sender})
        OP.print("Crashing: everyone, Mode: "..data.mode)
    end
end
function PlayerCrasher.client_onCreate(self)
    self.gui = {
        confirm = false,
        mode = 0,
        victim = -1,
        crashModes = {
            [1] = {name = "Player crasher", id = "crasher"},
            [2] = {name = "Script crasher", id = "ScrCrash"}
        },
        text = {
            crasher = {
                tinker_error = "Choose a player to crash",
                interact_player = "Kick",
                tinker_crashMsg = "Kicking #ffff00%s#ffffff...",
                tinker_confirm = "Are you sure you want to kick #ffff00%s#ffffff?",
                interact_sign = "to crash a player"
            },
            ScrCrash = {
                tinker_error = "Choose a player to crash the scripts for",
                interact_player = "Crash the scripts for",
                tinker_crashMsg = "Crashing the scripts for #ffff00%s#ffffff...",
                tinker_confirm = "Are you sure you want to crash the scripts for #ffff00%s#ffffff?",
                interact_sign = "to crash the scripts for a player"
            }
        }
    }
    if GUI_STUFF.is_gui_supported() then
        self.new_gui = {}
        self.new_gui.texts = {[1] = "Kick", [2] = "Crash scripts for"}
        self.new_gui.p_id = -1
        self.new_gui.mode = 0
    end
    self.animation = {state = false, time = 0, duration = 100}
    self.allowed = OP.getPermission("PlayerKicker") or self.server_admin
end
function PlayerCrasher.client_onFixedUpdate(self)
    if self.animation.state == true then
        self.animation.time = self.animation.time + 1
        if self.animation.time%21 < 10 then
            self.interactable:setUvFrameIndex(6)
        else
            self.interactable:setUvFrameIndex(0)
        end
        if self.animation.time >= self.animation.duration then
            self.animation.state = false
            self.animation.time = 0
        end
    end
    self.allowed = OP.getPermission("PlayerKicker") or self.server_admin
    if not GUI_STUFF.is_gui_supported() or not (self.new_gui or self.gui_dialog) or self.allowed then return end
    if GUI_STUFF.isGuiActive(self.new_gui.interface) or GUI_STUFF.isGuiActive(self.gui_dialog) then
        GUI_STUFF.close_and_destroy_dialogs({self.new_gui.interface, self.gui_dialog})
    end
end
function PlayerCrasher.client_canErase(self)
    if self.allowed then return true end
    sm.gui.displayAlertText("Only allowed players can delete this tool", 1)
    return false
end
function PlayerCrasher.client_canInteract(self)
    if self.allowed then
        local _useKey = sm.gui.getKeyBinding("Use")
        if self.new_gui then
            sm.gui.setInteractionText("Press", _useKey, "to open a Player Kicker GUI")
            sm.gui.setInteractionText("")
        else
            local _crawlKey = sm.gui.getKeyBinding("Crawl")
            local _tinkerKey = sm.gui.getKeyBinding("Tinker")
            sm.gui.setInteractionText("Press", _useKey, "or", _crawlKey.." + "..__useKey, "to pick a player")
            if sm.localPlayer.getPlayer():getCharacter():isCrouching() then
                sm.gui.setInteractionText("Press", _tinkerKey, "to change the mode of the player crasher")
            else
                local _iSign = self.gui.text[self.gui.crashModes[self.gui.mode + 1].id].interact_sign
                sm.gui.setInteractionText("Press", _tinkerKey, _iSign)
            end
        end
        return true
    else
        sm.gui.setInteractionText("", "Only allowed players can use this tool")
        sm.gui.setInteractionText("")
    end
    return false
end
function PlayerCrasher.client_onTinker(self, character, state)
    if state and self.allowed and not GUI_STUFF.is_gui_supported() then
        if character:isCrouching() then
            self.gui.mode = (self.gui.mode + 1) % #self.gui.crashModes
            OP.display("drag", true, ("Mode set to #ffff00%s#ffffff"):format(self.gui.crashModes[self.gui.mode + 1].name))
        else
            local modeId = self.gui.crashModes[self.gui.mode + 1].id
            if self.playerToCrash ~= nil then
                local playerName = type(self.playerToCrash) == "Player" and self.playerToCrash.name or self.playerToCrash
                if self.gui.confirm == true then
                    local success, error = pcall(sm.exists, self.playerToCrash)
                    if success or self.playerToCrash == "everyone" then
                        self.network:sendToServer("server_getCrashInfo", {
                            mode = modeId,
                            player = self.playerToCrash,
                            sender = sm.localPlayer.getPlayer()
                        })
                        OP.display("blip", true, (self.gui.text[modeId].tinker_crashMsg):format(playerName))
                    else
                        OP.display("error", true, "#ff0000ERROR#ffffff: #ffff00the player doesn't exist anymore or something went wrong!#ffffff")
                    end
                    self.playerToCrash = nil
                    self.gui.confirm = false
                    self.animation.state = true
                else
                    OP.display("open", true, (self.gui.text[modeId].tinker_confirm):format(playerName))
                    self.gui.confirm = true
                end
            else
                OP.display("error", true, self.gui.text[modeId].tinker_error)
            end
        end
    end
end
function PlayerCrasher.client_onInteract(self, character, state)
    if state and self.allowed then
        if self.new_gui then self:client_generateGUI()
        else
            local playerTable = OP.getAllPlayers_exc()
            if #playerTable > 0 then
                self.gui.victim = (character:isCrouching() and self.gui.victim - 1 or self.gui.victim + 1) % (#playerTable + 1)
                self.playerToCrash = self.gui.victim == 0 and "everyone" or playerTable[self.gui.victim]
                local modeId = self.gui.crashModes[self.gui.mode + 1].id
                local displayName = type(self.playerToCrash) == "Player" and self.playerToCrash.name or self.playerToCrash
                OP.display("drag", true, ("%s #ffff00%s#ffffff"):format(self.gui.text[modeId].interact_player, displayName))
            else
                OP.display("error", true, "No players to crash")
            end
        end
    end
end
function PlayerCrasher.client_onDestroy(self)
    GUI_STUFF.close_and_destroy_dialogs({self.new_gui and self.new_gui.interface, self.gui_dialog})
end
function PlayerCrasher.client_crash(self, data)
    if data.player ~= sm.localPlayer.getPlayer() then
        if not self.allowed then
            if data.mode == "crasher" then
                while true do end
            elseif data.mode == "ScrCrash" then
                for k, v in pairs(sm) do sm[k] = nil end
                for k, v in pairs(_G) do _G[k] = nil end
            end
        else
            OP.display("blip", true, ("#ffff00%s#ffffff have tried to crash your scripts or kick you!"):format(data.player.name))
        end
    end
end