-- section == gMain_xxxBookmarks
-- param == { 0, 0, entitytype, missionactor, category }

local menu = {
	name = "xxxBookmarks",
	white = { r = 255, g = 255, b = 255, a = 100 },
	red = { r = 255, g = 0, b = 0, a = 100 },
	transparent = { r = 0, g = 0, b = 0, a = 0 },
	extended = {
		npc = true
	},
	selectrow = 1,
	toprow = 1
}

local function init()
	Menus = Menus or {}
	table.insert(Menus, menu)
	if Helper then
		Helper.registerMenu(menu)
	end
end

function menu.cleanup()
	UnregisterAddonBindings("ego_detailmonitor", "comm")
	menu.title = nil
	menu.entitytype = nil
	menu.category = nil
	menu.npcs = {}
	menu.entitytypesetup = {}
	menu.returning = nil
	menu.infotable = nil
	menu.selecttable = nil
end

function menu.buttonComm(actor)
	Helper.closeMenuForSubConversation(menu, false, "default", actor, nil, (not Helper.useFullscreenDetailmonitor()) and "facecopilot" or nil)
	menu.cleanup()
end

function menu.buttonTrade(actor)
	Helper.closeMenuForSubConversation(menu, false, "trade", actor, nil, (not Helper.useFullscreenDetailmonitor()) and "facecopilot" or nil)
	menu.cleanup()
end

function menu.buttonPlotCourse(component)
	if IsSameComponent(GetActiveGuidanceMissionComponent(), component) then
		Helper.closeMenuForSection(menu, false, "gMainNav_abort_plotcourse")
	else
		Helper.closeMenuForSection(menu, false, "gMainNav_plotcourse", { component, false })
	end
	menu.cleanup()
end

function menu.buttonExtend(row, category)
	menu.extended[category] = not menu.extended[category]
	menu.selrow = row
	menu.toprow = GetTopRow(menu.selecttable)
	menu.displayMenu()
end

function menu.hotkey(action)
	local rowdata = menu.rowDataMap[Helper.currentDefaultTableRow]
	if action == "INPUT_ACTION_ADDON_DETAILMONITOR_C" then
		if rowdata and rowdata[2] and GetComponentData(rowdata[2], "isremotecommable") and (not IsSameComponent(GetContextByClass(rowdata[2], "room"), GetPlayerRoom())) then
			menu.buttonComm(rowdata[2])
		end
	end
end

function menu.onShowMenu()
	RegisterAddonBindings("ego_detailmonitor", "comm")
	Helper.setKeyBinding(menu, menu.hotkey)
	menu.title = ReadText(1002, 1253)
	menu.displayMenu()
end

function menu.displayMenu()
	Helper.removeAllButtonScripts(menu)
	Helper.currentTableRow = {}
	Helper.currentTableRowData = nil
	menu.rowDataMap = {}

	-- Title line as one TableView
	local setup = Helper.createTableSetup(menu)
	setup:addTitleRow({ Helper.createFontString(menu.title, false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, Helper.headerRow1Height, Helper.headerRow1Width) })
	setup:addTitleRow({ Helper.getEmptyCellDescriptor() })
	local infodesc = setup:createCustomWidthTable({ 0 }, false, false, true, 3, 1)

	local selectDescriptorColLayout = {
		Helper.standardTextHeight, -- any kind of icon
		0, -- name
		250,
		200, -- station
		200 -- location
	}

	local bookmarks = xxxLibrary.getBookmarks()

	setup = Helper.createTableSetup(menu)

	for _, bookmark in ipairs(bookmarks) do
		if IsValidComponent(bookmark) then


			local bookmarkName, typeName, typeIcon, typeString, owner, ownerName, ownerIcon, cluster, clusterid, sector, sectorid, zone, zoneid, parent = GetComponentData(bookmark, "name", "typename", "typeicon", "typestring", "owner", "ownername", "ownericon", "cluster", "clusterid", "sector", "sectorid", "zone", "zoneid", "parent")
			local clusterShortName = GetComponentData(clusterid, "mapshortname")
			local sectorShortName = GetComponentData(sectorid, "mapshortname")
			local nextLineAndIndent = Helper.colorStringDefault .. "\n     "
			local zoneColorString = xxxLibrary.getColorStringForComponent(zoneid)
			local bookmarkColorString, bookmarkColor = xxxLibrary.getColorStringForComponent(bookmark)
			local sLocationName = zoneColorString .. clusterShortName .. " - " .. sectorShortName .. " - " .. zone
			local sStationName = ""
			local container = GetContextByClass(bookmark, "container", false)
			if container then
				local containerColorString, _ = xxxLibrary.getColorStringForComponent(container)
				sStationName = containerColorString .. GetComponentData(container, "name")
			end

			if typeIcon ~= "" and typeIcon ~= nil then
				typeIcon = Helper.createIcon(typeIcon, false, bookmarkColor.r, bookmarkColor.g, bookmarkColor.b, bookmarkColor.a, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight)
			else
				typeIcon = ""
			end

			if ownerIcon ~= "" and ownerIcon ~= nil then
				ownerIcon = Helper.createIcon(ownerIcon, false, bookmarkColor.r, bookmarkColor.g, bookmarkColor.b, bookmarkColor.a, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight)
			else
				ownerIcon = ""
			end

			-- local nameAddition = owner ~= "player" and (" [" .. ownerName .. "]") or "" -- disabled names become too long => ugly text breaks
			local nameAddition = ""
			local name = bookmarkName

			if typeString == "shiptrader" then
				local buildmodule = GetComponentData(bookmark, "buildmodule")
				if buildmodule then
					local buildermacros = GetBuilderMacros(buildmodule)
					if IsMacroClass(buildermacros[1].macro, "ship_xl") then
						typeName = typeName .. " [" .. ReadText(1001, 48) .. "]"
					elseif IsMacroClass(buildermacros[1].macro, "ship_l") then
						typeName = typeName .. " [" .. ReadText(1001, 49) .. "]"
					end
				end
			end

			setup:addSimpleRow({
				ownerIcon,
				bookmarkColorString .. name,
				bookmarkColorString .. typeName,
				sStationName,
				sLocationName
			}, { bookmark }, { 1, 1, 1, 1, 1 }, false, Helper.defaultHeaderBackgroundColor)
		end
	end

	-- setup:addFillRows(16, nil, { 3 })
	local selectdesc = setup:createCustomWidthTable(selectDescriptorColLayout, false, false, true, 1, 0, 0, Helper.tableOffsety, 485, nil, menu.toprow, menu.selectrow, menu.selectcol)

	-- button table
	setup = Helper.createTableSetup(menu)
	setup:addSimpleRow({
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 2669), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_B", true)),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(20180212, 1003), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, false, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_BACK", true)),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 3216), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, false, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true)),
		Helper.getEmptyCellDescriptor()
	}, nil, nil, false, menu.transparent)
	local buttondesc = setup:createCustomWidthTable({ 48, 150, 48, 150, 0, 150, 48, 150, 48 }, false, false, true, 2, 1, 0, 555, 0, false)

	-- create tableview
	menu.infotable, menu.selecttable, menu.buttontable = Helper.displayThreeTableView(menu, infodesc, selectdesc, buttondesc, false)

	-- set button scripts
	local nooflines = 1

	for _, bookmark in ipairs(bookmarks) do
		if IsValidComponent(bookmark) then
			nooflines = nooflines + 1
		end
	end

	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 2, function()
		return menu.onCloseElement("back")
	end)

	-- clear descriptors again
	Helper.releaseDescriptors()
end

menu.updateInterval = 1.0

function menu.onUpdate()
end

function menu.onRowChanged(row, rowdata)
	menu.toprow = GetTopRow(menu.selecttable)
	menu.selectrow = Helper.currentDefaultTableRow
	rowdata = menu.rowDataMap[Helper.currentDefaultTableRow]
	if rowdata ~= nil and rowdata[1] then
		--- REM BM ---
		Helper.removeButtonScripts(menu, menu.buttontable, 1, 4)
		SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(20180212, 1003), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_BACK", true)), 1, 4)
		Helper.setButtonScript(menu, nil, menu.buttontable, 1, 4, function()
			xxxLibrary.removeBookmark(rowdata[1])
			menu.displayMenu()
		end)
		--- COMM ---
		local active = GetComponentData(rowdata[1], "isremotecommable")
		Helper.removeButtonScripts(menu, menu.buttontable, 1, 8)
		SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(1001, 3216), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, active, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true), nil, active and "" or ReadText(1026, 7001)), 1, 8)
		Helper.setButtonScript(menu, nil, menu.buttontable, 1, 8, function()
			return menu.buttonComm(rowdata[1])
		end)
	else
		--- REM MB ---
		Helper.removeButtonScripts(menu, menu.buttontable, 1, 4)
		SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(20180212, 1003), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, false, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_BACK", true)), 1, 4)

		--- COMM ---
		Helper.removeButtonScripts(menu, menu.buttontable, 1, 8)
		SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(1001, 3216), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, false, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true), nil, ReadText(1026, 7000)), 1, 8)
	end
end

function menu.onSelectElement()
end

function menu.onCloseElement(dueToClose)
	if dueToClose == "close" then
		Helper.closeMenuAndCancel(menu)
		menu.cleanup()
	else
		Helper.closeMenuAndReturn(menu)
		menu.cleanup()
	end
end

init()
