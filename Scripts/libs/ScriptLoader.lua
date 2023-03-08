--[[
	Copyright (c) 2023 Questionable Mark
]]

if OP_TOOLS_SCRIPT_LOADED then return end
OP_TOOLS_SCRIPT_LOADED = true

dofile("Functions.lua")
dofile("GuiStuff.lua")

dofile("$CONTENT_DATA/Scripts/PermissionManager/PermissionManagerGUI.lua")
if not PlayerCrasher then
	dofile("$CONTENT_DATA/Scripts/PlayerCrasher/PlayerCrasher.lua")
end
dofile("$CONTENT_DATA/Scripts/FreeCamera/FreeCamGui.lua")
dofile("$CONTENT_DATA/Scripts/FreeCamera/FreeCamFunctions.lua")
dofile("$CONTENT_DATA/Scripts/FreeCamera/FreeCamOldGui.lua")
dofile("$CONTENT_DATA/Scripts/FreeCamera/FreeCam_SubFunctions.lua")
dofile("$CONTENT_DATA/Scripts/AdminTool/AdminToolGui.lua")
dofile("$CONTENT_DATA/Scripts/WorldCleaner/WorldCleanerGUI.lua")

print("[OPTools] Successfully loaded all the scripts")