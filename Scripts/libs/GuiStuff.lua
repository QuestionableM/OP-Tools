--[[
	Copyright (c) 2021 Questionable Mark
]]

if GUI_STUFF then return end
GUI_STUFF = class()

function GUI_STUFF.close_and_destroy_dialogs(d_table)
	for id, gui in pairs(d_table) do
		if OP.exists(gui) then
			gui:close()
			gui:destroy()
		end
	end
end

function GUI_STUFF.isGuiActive(gui)
	if gui == nil then return false end
	if sm.exists(gui) then return gui:isActive() end
	return false
end

print("[OPTools] GUI Library has been loaded")