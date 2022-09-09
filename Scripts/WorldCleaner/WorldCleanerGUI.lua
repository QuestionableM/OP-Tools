--[[
	Copyright (c) 2022 Questionable Mark
]]

if WorldCleanerGUI then return end

---@class WorldCleanerGUI : WorldCleanerClass
WorldCleanerGUI = class()

local message_id_enum =
{
	everything    = 0x1,
	all_bodies    = 0x2,
	lose_bodies   = 0x4,
	op_tools      = 0x8,
	lifts         = 0x10,
	units         = 0x20,
	cert_creation = 0x40,
	cur_creation  = 0x80
}

local button_names =
{
	DeleteEverything = {id = message_id_enum.everything   , name = "Everything"        },
	AllBodies        = {id = message_id_enum.all_bodies   , name = "All Bodies"        },
	LoseOnly         = {id = message_id_enum.lose_bodies  , name = "All Lose Bodies"   },
	OpTools          = {id = message_id_enum.op_tools     , name = "All OP Tools"      },
	Lifts            = {id = message_id_enum.lifts                                     },
	Units            = {id = message_id_enum.units                                     },
	CurCreation      = {id = message_id_enum.cur_creation , name = "Connected Creation"}
}

WorldCleanerGUI.clear_message_ids = message_id_enum

local wc_gui_widget_enum =
{
	main_gui       = 1,
	confirm_dialog = 2,
	item_dialog    = 3
}

local wc_gui_widget_names =
{
	"MainGuiBG",
	"ConfirmDialogBG",
	"ItemDialogBG"
}

function WorldCleanerGUI:client_sendToServer(case, uuid)
	if not self:isAllowed() then return end

	self.network:sendToServer("server_clean", { false, case, uuid })
end

function WorldCleanerGUI:client_GUI_switchWidget(id)
	local s_gui = self.gui

	for i = 1, 3 do
		s_gui:setVisible(wc_gui_widget_names[i], i == id)
	end
end

function WorldCleanerGUI:client_ID_OnNoCallback()
	self.gui_part_uuid = nil
	self:client_GUI_switchWidget(wc_gui_widget_enum.main_gui)

	sm.audio.play("Blueprint - Close")
end

function WorldCleanerGUI:client_ID_OnYesCallback()
	self:client_sendToServer(message_id_enum.cert_creation, self.gui_part_uuid)
	self.gui:close()
end

function WorldCleanerGUI:client_GUI_deleteCObject()
	if not self:isAllowed() then return end

	local uuid = self:client_isShapePlaced()
	if uuid == nil then return end

	self.gui_part_uuid = uuid

	local s_gui = self.gui
	s_gui:setMeshPreview("ItemDiag_PartImage", uuid)
	s_gui:setText("ItemDiag_PartName", ("Part Name: #ffff00%s#ffffff"):format(sm.shape.getShapeTitle(uuid)))
	s_gui:setText("ItemDiag_PartUuid", ("Part Uuid: #ffff00%s#ffffff"):format(tostring(uuid)))

	self:client_GUI_switchWidget(wc_gui_widget_enum.item_dialog)

	sm.audio.play("Blueprint - Open")
end

function WorldCleanerGUI:client_CD_OnYesCallback()
	self:client_sendToServer(self.gui_confirm_id)
	self.gui:close()
end

function WorldCleanerGUI:client_CD_OnNoCallback()
	self:client_GUI_switchWidget(wc_gui_widget_enum.main_gui)

	self.gui_confirm_id = nil
	sm.audio.play("Blueprint - Close")
end

function WorldCleanerGUI:client_constructDialog(description, id)
	self.gui_confirm_id = id
	self.gui:setText("Confirm_Desc", ("Are you sure that you want to delete #ffff00%s#ffffff?"):format(description))

	self:client_GUI_switchWidget(wc_gui_widget_enum.confirm_dialog)

	sm.audio.play("Blueprint - Open")
end

function WorldCleanerGUI:client_GUI_onButtonCallback(btn_name)
	if not self:isAllowed() then return end

	local btn_data = button_names[btn_name]
	if btn_data.name then
		self:client_constructDialog(btn_data.name, btn_data.id)
		return
	end

	self:client_sendToServer(btn_data.id)
end

function WorldCleanerGUI:client_onWCGuiDestroy()
	if OP.exists(self.gui) then
		self.gui:destroy()
	end

	self.gui_part_uuid  = nil
	self.gui_confirm_id = nil
	self.gui = nil
end

function WorldCleanerGUI:client_initializeGui()
	if not self:isAllowed() then return end

	local gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/WorldCleanerGUI.layout", false, { backgroundAlpha = 0.5, hidesHotbar = true })

	gui:setButtonCallback("CObject", "client_GUI_deleteCObject")
	for btn, v in pairs(button_names) do
		gui:setButtonCallback(btn, "client_GUI_onButtonCallback")
	end

	--initialize construct dialog callbacks
	gui:setButtonCallback("Confirm_Yes", "client_CD_OnYesCallback")
	gui:setButtonCallback("Confirm_No", "client_CD_OnNoCallback")

	--initialize item dialog callbacks
	gui:setButtonCallback("ItemDiag_Yes", "client_ID_OnYesCallback")
	gui:setButtonCallback("ItemDiag_No", "client_ID_OnNoCallback")

	gui:setOnCloseCallback("client_onWCGuiDestroy")
	gui:open()

	self.gui = gui
end