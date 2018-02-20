-- section == gMain_objectPlatforms
-- param == { 0, 0, object [, platform] }

local menu = {
	name = "PlatformsMenu",
	white = { r = 255, g = 255, b = 255, a = 100 },
	red = { r = 255, g = 0, b = 0, a = 100 },
	transparent = { r = 0, g = 0, b = 0, a = 0 },
	extendedcategories = {}
}

local overrideFuncs = {}

function overrideFuncs.displayMenu()
	-- Remove possible button scripts from previous view
	Helper.removeAllButtonScripts(menu)
	Helper.currentTableRow = {}
	Helper.currentTableRowData = nil
	menu.rowDataMap = {}

	local container = GetContextByClass(menu.object, "container", false)
	local name, objectowner = GetComponentData(menu.object, "name", "owner")
	if container then
		menu.title = GetComponentData(container, "name") .. " - " .. (name ~= "" and name or ReadText(1001, 56)) .. " - " .. ReadText(1001, 1116)
	else
		menu.title = (name ~= "" and name or ReadText(1001, 56)) .. " - " .. ReadText(1001, 1116)
	end

	-- Title line as one TableView
	local setup = Helper.createTableSetup(menu)

	setup:addSimpleRow({
		Helper.createButton(nil, Helper.createButtonIcon("menu_info", nil, 255, 255, 255, 100), false),
		Helper.createFontString(menu.title, false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, Helper.headerRow1Height, Helper.headerRow1Width)
	}, nil, { 1, 1 }, false, Helper.defaultTitleBackgroundColor)
	setup:addTitleRow({
		Helper.getEmptyCellDescriptor()
	}, nil, { 3 })

	local infodesc = setup:createCustomWidthTable({ Helper.scaleX(Helper.headerCharacterIconSize), 0, Helper.scaleX(Helper.headerCharacterIconSize) + 37 }, false, true, true, 3, 1)

	setup = Helper.createTableSetup(menu)

	menu.platforms = GetPlatforms(menu.object)
	for _, platform in ipairs(menu.platforms) do
		local npcs = GetPrioritizedPlatformNPCs(platform)
		table.sort(npcs, Helper.sortEntityTypeAndName)
		setup:addSimpleRow({
			Helper.createButton(Helper.createButtonText(menu.extendedcategories[tostring(platform)] and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, #npcs > 0, 0, 0, Helper.tableRowHeight, Helper.tableRowHeight),
			GetComponentData(platform, "name") .. " (" .. #npcs .. ")"
		}, { "platform", platform }, { 1, 4 }, false, Helper.defaultHeaderBackgroundColor)
		if #npcs > 0 then
			if menu.extendedcategories[tostring(platform)] then
				for _, npc in ipairs(npcs) do
					local name, typestring, typeicon, typename, owner, ownername, ownericon, isenemy = GetComponentData(npc, "name", "typestring", "typeicon", "typename", "owner", "ownername", "ownericon", "isenemy")
					local color = menu.white
					if isenemy then
						color = menu.red
					end
					local addition = ""
					if typestring == "shiptrader" then
						local buildmodule = GetComponentData(npc, "buildmodule")
						if buildmodule then
							local buildermacros = GetBuilderMacros(buildmodule)
							if IsMacroClass(buildermacros[1].macro, "ship_xl") then
								addition = " [" .. ReadText(1001, 48) .. "]"
							elseif IsMacroClass(buildermacros[1].macro, "ship_l") then
								addition = " [" .. ReadText(1001, 49) .. "]"
							end
						end
					end

					setup:addSimpleRow({
						Helper.getEmptyCellDescriptor(),
						xxxLibrary.createNpcBookmarkIconButton(npc, true),
						Helper.createFontString(typename .. " " .. name .. addition, false, "left", color.r, color.g, color.b, color.a),
						Helper.createIcon(ownericon, false, color.r, color.g, color.b, color.a, 0,0, Helper.standardTextHeight, Helper.standardTextHeight),
						Helper.createFontString(ownername, false, "left", color.r, color.g, color.b, color.a),
					}, { "npc", npc }, { 1, 1, 1, 1, 1 })
				end
			end
		end
	end

	setup:addFillRows(16)

	local selectdesc = setup:createCustomWidthTable({
		Helper.standardTextHeight,
		Helper.standardTextHeight,
		0,
		Helper.standardTextHeight,
		230
	}, false, false, true, 1, 0, 0, Helper.tableOffsety, 485, false, menu.settoprow, menu.setselectedrow)
	menu.settoprow = nil
	menu.setselectedrow = nil

	-- button table
	setup = Helper.createTableSetup(menu)
	setup:addSimpleRow({
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 2669), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_B", true)),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(IsSameComponent(GetActiveGuidanceMissionComponent(), menu.object) and ReadText(1001, 1110) or ReadText(1001, 1109), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, not menu.isplayership, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_Y", true)),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 3216), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, false, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true)),
		Helper.getEmptyCellDescriptor()
	}, nil, nil, false, menu.transparent)
	local buttondesc = setup:createCustomWidthTable({ 48, 150, 48, 150, 0, 150, 48, 150, 48 }, false, false, true, 2, 1, 0, 555, 0, false)

	-- create tableview
	menu.infotable, menu.selecttable, menu.buttontable = Helper.displayThreeTableView(menu, infodesc, selectdesc, buttondesc, false)

	-- set button scripts
	Helper.setButtonScript(menu, nil, menu.infotable, 1, 1, menu.buttonShipEncyclopedia)

	local nooflines = 1
	for _, platform in ipairs(menu.platforms) do
		local npcs = GetPrioritizedPlatformNPCs(platform)
		if #npcs > 0 then
			local row = nooflines
			Helper.setButtonScript(menu, nil, menu.selecttable, row, 1, function() return menu.buttonCategoryExtend(tostring(platform), row) end)
			if menu.extendedcategories[tostring(platform)] then
				for _, npc in ipairs(npcs) do
					nooflines = nooflines + 1
					local npcRow = nooflines

					local _npc = npc

					Helper.setButtonScript(menu, nil, menu.selecttable, npcRow, 2, function()
						local rowdata = menu.rowDataMap[npcRow]
						if (rowdata[1] == "npc") and (not menu.isplayership) and GetComponentData(rowdata[2], "isremotecommable") then
							xxxLibrary.toggleBookmark(rowdata[2])
							menu.setselectedrow = npcRow
							menu.settoprow = GetTopRow(menu.selecttable)
							menu.displayMenu()
							-- return menu.buttonComm(rowdata[2])
						end
					end)
				end
			end
		end
		nooflines = nooflines + 1
	end

	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 2, function() return menu.onCloseElement("back") end)

	-- clear descriptors again
	Helper.releaseDescriptors()
end


local function init()
	for _, existingMenu in ipairs(Menus) do
		if existingMenu.name == "PlatformsMenu" then
			menu = existingMenu
			for k, v in pairs(overrideFuncs) do
				menu[k] = v
			end
			break
		end
	end
end

init()
