--[[
	Copyright (c) 2023 Questionable Mark
]]

if OP_TOOLS_SCRIPT_LOADED then return end
OP_TOOLS_SCRIPT_LOADED = true

--Self check the description for infections
if type(op_jsonOpen) == "function" and type(op_chatMessage) == "function" then
	local descr_data = op_jsonOpen("$CONTENT_DATA/description.json")
	if descr_data then
		local dependencies = descr_data.dependencies
		if type(dependencies) == "table" and #dependencies > 0 then
			op_chatMessage("#ff0000WARNING#ffffff: OP Tools is infected. Here's the list of infections:")

			for k, dependency in pairs(dependencies) do
				local dep_id = dependency.fileId or 0
				local dep_name = dependency.name or "UNKNOWN"
				op_chatMessage(("%i -> SteamId: #ffff00%i#ffffff Name: #ffff00%s#ffffff"):format(k, dep_id, dep_name))
			end

			op_chatMessage("These mods open backdoors in your game or waiting for a certain amount of people to get infected to start the payload. Please report them as soon as possible.")
		end
	end
end

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