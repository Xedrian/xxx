-- section == gMain_remoteNPCList
-- param == { 0, 0, entitytype, missionactor, category }

local overrideFuncs = {}
local menu = {}

overrideFuncs.updateInterval = 1.0

function overrideFuncs.cleanup()
	UnregisterAddonBindings("ego_detailmonitor", "comm")

	menu.title = nil
	menu.entitytype = nil
	menu.missionactor = nil
	menu.category = nil
	menu.npcs = {}
	menu.entitytypesetup = {}
	menu.returning = nil

	menu.infotable = nil
	menu.selecttable = nil
end

function overrideFuncs.buttonComm(actor)
	Helper.closeMenuForSubConversation(menu, false, "default", actor, nil, (not Helper.useFullscreenDetailmonitor()) and "facecopilot" or nil)
	menu.cleanup()
end

function overrideFuncs.buttonTrade(actor)
	Helper.closeMenuForSubConversation(menu, false, "trade", actor, nil, (not Helper.useFullscreenDetailmonitor()) and "facecopilot" or nil)
	menu.cleanup()
end

function overrideFuncs.buttonPlotCourse(component)
	if IsSameComponent(GetActiveGuidanceMissionComponent(), component) then
		Helper.closeMenuForSection(menu, false, "gMainNav_abort_plotcourse")
	else
		Helper.closeMenuForSection(menu, false, "gMainNav_plotcourse", { component, false })
	end
	menu.cleanup()
end

function overrideFuncs.buttonExtend(row, category)
	menu.extended[category] = not menu.extended[category]
	menu.preselectrow = row
	menu.pretoprow = GetTopRow(menu.selecttable)
	menu.displayMenu()
end

function overrideFuncs.hotkey(action)
	local rowdata = menu.rowDataMap[Helper.currentDefaultTableRow]
	if action == "INPUT_ACTION_ADDON_DETAILMONITOR_C" then
		if rowdata and rowdata[2] and GetComponentData(rowdata[2], "isremotecommable") and (not IsSameComponent(GetContextByClass(rowdata[2], "room"), GetPlayerRoom())) then
			menu.buttonComm(rowdata[2])
		end
	end
end

function overrideFuncs.onShowMenu()
	menu.entitytype = menu.param[3]
	menu.missionactor = menu.param[4] and menu.param[4] ~= 0
	menu.category = menu.param[5]
	if menu.param2 ~= nil then
		menu.returning = true
		menu.lasthirednpc = menu.param2[2]
	end
	if not menu.returning then
		menu.extended = {}
	end

	RegisterAddonBindings("ego_detailmonitor", "comm")
	Helper.setKeyBinding(menu, menu.hotkey)

	menu.title = ReadText(1002, 1253)

	menu.npcs = GetNPCsInSectorOnStations(GetComponentData(GetPlayerPrimaryShipID(), "sectorid"), 60000)

	-- IMPORTANT: Keep in sync with mainmenu/mainmenu.lua
	menu.entitytypesetup = {
		-- Mission contacts
		[1] = { missions = true, icon = "mm_ic_comm_missioncontacts", name = ReadText(1002, 20001), info = ReadText(1002, 21017) },
		-- Crew for Albion Skunk
		[2] = { { type = "pilot", info = ReadText(1002, 21019) }, { type = "engineer", info = ReadText(1002, 21020) }, { type = "marine", info = ReadText(1002, 21021) }, icon = "mm_ic_comm_crewforplayer", name = ReadText(1002, 20002), info = ReadText(1002, 21018) },
		-- Crew for capital ship
		[3] = { { type = "commander", info = ReadText(1002, 21023) }, { type = "engineer", info = ReadText(1002, 21024) }, { type = "defencecontrol", info = ReadText(1002, 21025) }, { type = "architect", info = ReadText(1002, 21026) }, icon = "mm_ic_comm_crewforcapship", name = ReadText(1002, 20003), info = ReadText(1002, 21022) },
		-- Crew for station
		[4] = { { type = "manager", info = ReadText(1002, 21028) }, { type = "engineer", info = ReadText(1002, 21024) }, { type = "defencecontrol", info = ReadText(1002, 21029) }, icon = "mm_ic_comm_crewforstation", name = ReadText(1002, 20004), info = ReadText(1002, 21027) },
		-- Specialist for station
		[5] = { { type = "specialistagriculture", info = ReadText(1002, 21501) }, { type = "specialistpowerstorage", info = ReadText(1002, 21502) }, { type = "specialistfood", info = ReadText(1002, 21503) }, { type = "specialistchemical", info = ReadText(1002, 21504) }, { type = "specialistprecision", info = ReadText(1002, 21505) }, { type = "specialistweapons", info = ReadText(1002, 21506) }, { type = "specialistpharmaceuticals", info = ReadText(1002, 21507) }, { type = "specialistmetals", info = ReadText(1002, 21508) }, { type = "specialistgeophysics", info = ReadText(1002, 21509) }, { type = "specialistsurfacesystems", info = ReadText(1002, 21510) }, { type = "specialistpowersupply", info = ReadText(1002, 21511) }, { type = "specialistaquatics", info = ReadText(1002, 21512) }, icon = "mm_ic_comm_specialistforstation", name = ReadText(1002, 20005), info = ReadText(1002, 21030) },
		-- Trader
		[6] = { { type = "miningsupplier", info = ReadText(1002, 21034) }, { type = "junkdealer", info = ReadText(1002, 21035) }, { type = "spacefarmer", info = ReadText(1002, 21036) }, { type = "shiptech", info = ReadText(1002, 21037) }, { type = "equipment", info = ReadText(1002, 21038) }, { type = "foodmerchant", info = ReadText(1002, 21039) }, { type = "shadyguy", info = ReadText(20208, 2301) }, icon = "mm_ic_comm_trader", name = ReadText(1002, 12032), info = ReadText(1002, 21031) },
		-- Ship services
		[7] = { { type = "shiptrader", info = ReadText(1002, 21032) }, { type = "smallshiptrader", info = ReadText(1002, 21052) }, { type = "licencetrader", info = ReadText(1002, 21033) }, { type = "engineer", info = ReadText(1002, 21041) }, { type = "upgradetrader", info = ReadText(1002, 21042) }, { type = "dronetrader", info = ReadText(1002, 21043) }, { type = "armsdealer", info = ReadText(1002, 21044) }, { type = "recruitment", info = ReadText(1002, 21045) }, icon = "mm_ic_comm_services", name = ReadText(1002, 12036), info = ReadText(1002, 21040) },
		-- Polie Chief
		[8] = { type = "lawenforcement", info = ReadText(1002, 21046) }
	}

	for i, category in ipairs(menu.entitytypesetup) do
		if #category > 1 then
			local count = 0
			for j, subcategory in ipairs(category) do
				if (not menu.returning) and (((menu.category == nil) or (i == menu.category)) and ((subcategory.type == menu.entitytype) and (subcategory.missions == menu.missionactor))) then
					menu.extended[i] = true
					menu.extended[i .. "_" .. j] = true
				end
				subcategory.npcs = menu.getNPCs(subcategory.type, subcategory.missions)
				table.sort(subcategory.npcs, Helper.sortComponentName)
				count = count + #subcategory.npcs
			end
			category.count = count
		else
			if (not menu.returning) and ((category.type == menu.entitytype) and (category.missions == menu.missionactor)) then
				menu.extended[i] = true
			end
			category.npcs = menu.getNPCs(category.type, category.missions)
			table.sort(category.npcs, Helper.sortComponentName)
		end
	end

	menu.displayMenu()
end

function overrideFuncs.addNpcRow(setup, npc, indent, category)

	local cols = {}
	local colWidths = {}
	local nameColSpan = menu.colCount

	local type = category.missions and "missions" or category.type

	local npcTypesWithSkills = {
		"pilot", "engineer", "marine", "commander", "defencecontrol", "architect", "manager",
		"specialistagriculture", "specialistpowerstorage", "specialistfood", "specialistchemical",
		"specialistprecision", "specialistweapons", "specialistpharmaceuticals", "specialistmetals",
		"specialistgeophysics", "specialistsurfacesystems", "specialistpowersupply", "specialistaquatics"
	}

	if ident == nil then
		ident = 0
	end

	-- ident cols
	if indent > 0 then
		table.insert(cols, Helper.getEmptyCellDescriptor())
		table.insert(colWidths, indent)
		nameColSpan = nameColSpan - indent
	end




	local typestring, ownericon, typename, name, combinedskill, container = GetComponentData(npc, "typestring", "ownericon", "typename", "name", "combinedskill", "container")
	local colorStringForName, colorForIcon = xxxLibrary.getColorStringForComponent(npc)

	if type ~= "missions" then
		-- col 1 - icon
		--table.insert(cols, Helper.createIcon(ownericon, false, colorForIcon.r, colorForIcon.g, colorForIcon.b, colorForIcon.a, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight))
		table.insert(cols, xxxLibrary.createNpcBookmarkIconButton(npc, true, true))
		table.insert(colWidths, 1)
		nameColSpan = nameColSpan - 1
	end

	if type == "missions" then
		name = typename .. " " .. name
	elseif type == "shiptrader" then
		local buildmodule = GetComponentData(npc, "buildmodule")
		local buildermacros = GetBuilderMacros(buildmodule)
		if IsMacroClass(buildermacros[1].macro, "ship_xl") then
			name = name .. " [" .. ReadText(1001, 48) .. "]"
		elseif IsMacroClass(buildermacros[1].macro, "ship_l") then
			name = name .. " [" .. ReadText(1001, 49) .. "]"
		end
	end

	-- col 2 - name -- colspan is fixed after we know the final cols
	table.insert(cols, colorStringForName .. name)
	table.insert(colWidths, 1)
	local insertPosition = #colWidths

	if table.hasValue(npcTypesWithSkills, type) then
		-- col 3 -- skill icon
		table.insert(cols, xxxLibrary.createStarsText(xxxLibrary.getColorStringForCombinedSkill(combinedskill) .. "*"))
		table.insert(colWidths, 1)
		nameColSpan = nameColSpan - 1

		-- col 4 -- skill value
		table.insert(cols, combinedskill)
		table.insert(colWidths, 1)
		nameColSpan = nameColSpan - 1
	end

	local colorStringForStationName = xxxLibrary.getColorStringForComponent(container)

	-- col 5 -- npc location
	table.insert(cols, colorStringForStationName .. GetComponentData(container, "name"))
	table.insert(colWidths, 1)
	nameColSpan = nameColSpan - 1

	-- fix the name column colspan
	colWidths[insertPosition] = nameColSpan

	setup:addSimpleRow(cols, { category.info, npc }, colWidths, false, Helper.defaultHeaderBackgroundColor)
end

function overrideFuncs.addCategory(setup, extended, category, indent)
	local active = false
	local title
	local categoryIcon

	if category.type then
		title, categoryIcon = GetEntityTypeData(category.type, "name", "icon")
	else
		title = category.name
		categoryIcon = category.icon
	end

	if category.type or category.missions then
		-- no subcategories -- npcs only
		title = title .. " (" .. #category.npcs .. ")"
		active = #category.npcs > 0
	else
		-- category has subcategorie
		title = title .. " (" .. category.count .. ")"
		active = category.count > 0
	end

	local cols = {}
	local colWidths = {}
	local nameColSpan = menu.colCount

	if indent == nil then
		indent = 0
	end

	-- ident cols
	if indent > 0 then
		table.insert(cols, Helper.getEmptyCellDescriptor())
		table.insert(colWidths, indent)
		nameColSpan = nameColSpan - indent
	end

	-- expender col
	table.insert(cols, Helper.createButton(Helper.createButtonText(extended and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, active, 0, 0, 0, Helper.standardTextHeight))
	table.insert(colWidths, 1)
	nameColSpan = nameColSpan - 1

	-- icon col
	table.insert(cols, Helper.createIcon(categoryIcon, false, 255, 255, 255, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight))
	table.insert(colWidths, 1)
	nameColSpan = nameColSpan - 1

	-- text col
	table.insert(cols, title)
	table.insert(colWidths, nameColSpan)

	setup:addSimpleRow(cols, { category.info, nil }, colWidths, false, Helper.defaultHeaderBackgroundColor)
end

function overrideFuncs.displayMenu()
	Helper.removeAllButtonScripts(menu)
	Helper.currentTableRow = {}
	Helper.currentTableRowData = nil
	menu.rowDataMap = {}

	local columnLayout = {
		Helper.standardTextHeight,
		Helper.standardTextHeight,
		Helper.standardTextHeight,
		0, -- name
		Helper.standardTextHeight * 1.2, -- skill icon
		45, -- skill value
		320 -- where the npc is located
	}

	menu.colCount = #columnLayout


	-- Title line as one TableView
	local setup = Helper.createTableSetup(menu)

	setup:addTitleRow({ Helper.createFontString(menu.title, false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, Helper.headerRow1Height, Helper.headerRow1Width) })
	setup:addTitleRow({ Helper.getEmptyCellDescriptor() })

	local infodesc = setup:createCustomWidthTable({ 0 }, false, false, true, 3, 1)

	setup = Helper.createTableSetup(menu)

	local nooflines = 1
	for i, category in ipairs(menu.entitytypesetup) do


		if #category > 1 then
			menu.addCategory(setup, menu.extended[i], category, 0)
			nooflines = nooflines + 1
			if menu.extended[i] then
				for j, subcategory in ipairs(category) do
					menu.addCategory(setup, menu.extended[i .. "_" .. j], subcategory, 1)
					nooflines = nooflines + 1
					if menu.extended[i .. "_" .. j] then
						if (not menu.returning) and ((menu.category == nil) or (i == menu.category)) and ((subcategory.type == menu.entitytype) and (subcategory.missions == menu.missionactor)) then
							if not menu.preselectrow then
								menu.preselectrow = nooflines
								if menu.preselectrow > 16 then
									menu.pretoprow = menu.preselectrow - 15
								end
							end
						end
						for _, npc in ipairs(subcategory.npcs) do
							if IsValidComponent(npc) and not IsSameComponent(npc, menu.lasthirednpc) then
								menu.addNpcRow(setup, npc, 2, subcategory)
								nooflines = nooflines + 1
							end
						end
					end
				end
			end
		else
			menu.addCategory(setup, menu.extended[i], category, 0)
			nooflines = nooflines + 1
			if menu.extended[i] then
				if (not menu.returning) and ((category.type == menu.entitytype) and (category.missions == menu.missionactor)) then
					if not menu.preselectrow then
						menu.preselectrow = nooflines
						if menu.preselectrow > 16 then
							menu.pretoprow = menu.preselectrow - 15
						end
					end
				end
				for _, npc in ipairs(category.npcs) do
					local typeicon, typename, name = GetComponentData(npc, "typeicon", "typename", "name")
					menu.addNpcRow(setup, npc, 1, category)
					nooflines = nooflines + 1
				end
			end
		end
	end

	setup:addFillRows(16, nil, { 4 })
	local selectdesc = setup:createCustomWidthTable(columnLayout, false, false, true, 1, 0, 0, Helper.tableOffsety, 485, nil, menu.pretoprow, menu.preselectrow)
	menu.pretoprow = nil
	menu.preselectrow = nil

	-- button table
	setup = Helper.createTableSetup(menu)
	setup:addSimpleRow({
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 2669), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_B", true)),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 3216), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, false, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_BACK", true)),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 1109), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, false, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_Y", true)),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 7000), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, false, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true)),
		Helper.getEmptyCellDescriptor()
	}, nil, nil, false, menu.transparent)
	local buttondesc = setup:createCustomWidthTable({ 48, 150, 48, 150, 0, 150, 48, 150, 48 }, false, false, true, 2, 1, 0, 555, 0, false)

	-- create tableview
	menu.infotable, menu.selecttable, menu.buttontable = Helper.displayThreeTableView(menu, infodesc, selectdesc, buttondesc, false)

	-- set button scripts
	local nooflines = 1
	for i, category in ipairs(menu.entitytypesetup) do
		if #category > 1 then
			local row = nooflines
			Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
				return menu.buttonExtend(row, i)
			end)
			nooflines = nooflines + 1
			if menu.extended[i] then
				for j, subcategory in ipairs(category) do
					local row = nooflines
					Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 2, function()
						return menu.buttonExtend(row, i .. "_" .. j)
					end)
					nooflines = nooflines + 1
					if menu.extended[i .. "_" .. j] then
						for _, npc in ipairs(subcategory.npcs) do
							if IsValidComponent(npc) and not IsSameComponent(npc, menu.lasthirednpc) then

								local npcRow = nooflines
								local _npc = npc

								Helper.setButtonScript(menu, nil, menu.selecttable, npcRow, 3, function()
									local rowdata = menu.rowDataMap[npcRow]
									if (not menu.isplayership) and GetComponentData(_npc, "isremotecommable") then
										xxxLibrary.toggleBookmark(_npc)
										menu.preselectrow = npcRow
										menu.pretoprow = GetTopRow(menu.selecttable)
										menu.displayMenu()
									end
								end)

								nooflines = nooflines + 1
							end
						end
					end
				end
			end
		else
			local row = nooflines
			Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
				return menu.buttonExtend(row, i)
			end)
			nooflines = nooflines + 1
			if menu.extended[i] then
				for _, npc in ipairs(category.npcs) do
					nooflines = nooflines + 1
				end
			end
		end
	end

	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 2, function()
		return menu.onCloseElement("back")
	end)

	-- clear descriptors again
	Helper.releaseDescriptors()
end

function overrideFuncs.onUpdate()
end

function overrideFuncs.onRowChanged(row, rowdata)
	rowdata = menu.rowDataMap[Helper.currentDefaultTableRow]
	if rowdata and rowdata[1] then
		Helper.updateCellText(menu.infotable, 2, 1, rowdata[1])
	else
		Helper.updateCellText(menu.infotable, 2, 1, "")
	end
	if rowdata and rowdata[2] then
		--- COMM ---
		local active = GetComponentData(rowdata[2], "isremotecommable") and (not IsSameComponent(GetContextByClass(rowdata[2], "room"), GetPlayerRoom()))
		Helper.removeButtonScripts(menu, menu.buttontable, 1, 4)
		SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(1001, 3216), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, active, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_BACK", true), nil, active and "" or ReadText(1026, 7001)), 1, 4)
		Helper.setButtonScript(menu, nil, menu.buttontable, 1, 4, function()
			return menu.buttonComm(rowdata[2])
		end)
		--- PLOT COURSE ---
		Helper.removeButtonScripts(menu, menu.buttontable, 1, 6)
		SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(IsSameComponent(GetActiveGuidanceMissionComponent(), rowdata[2]) and ReadText(1001, 1110) or ReadText(1001, 1109), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_Y", true)), 1, 6)
		Helper.setButtonScript(menu, nil, menu.buttontable, 1, 6, function()
			return menu.buttonPlotCourse(rowdata[2])
		end)
		--- TRADE WITH ---
		local typestring, isitemtrader = GetComponentData(rowdata[2], "typestring", "isitemtrader")
		local typecheck = isitemtrader
		local callback = function()
			return menu.buttonTrade(rowdata[2])
		end
		if (typestring == "shiptrader") or (typestring == "smallshiptrader") then
			typecheck = true
			callback = function()
				return menu.buttonComm(rowdata[2])
			end
		elseif typestring == "licencetrader" then
			typecheck = true
		end
		Helper.removeButtonScripts(menu, menu.buttontable, 1, 8)
		SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(1001, 7000), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, typecheck and active, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true), nil, (typecheck and active) and "" or ReadText(1026, 7002)), 1, 8)
		Helper.setButtonScript(menu, nil, menu.buttontable, 1, 8, callback)
	else
		--- COMM ---
		Helper.removeButtonScripts(menu, menu.buttontable, 1, 4)
		SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(1001, 3216), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, false, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_BACK", true), nil, ReadText(1026, 7000)), 1, 4)
		--- PLOT COURSE ---
		Helper.removeButtonScripts(menu, menu.buttontable, 1, 6)
		SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(1001, 1109), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, false, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_Y", true), nil, ReadText(1026, 7000)), 1, 6)
		--- TRADE WITH ---
		Helper.removeButtonScripts(menu, menu.buttontable, 1, 8)
		SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(1001, 7000), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, false, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true), nil, ReadText(1026, 7000)), 1, 8)
	end
end

function overrideFuncs.onSelectElement()
end

function overrideFuncs.onCloseElement(dueToClose)
	if dueToClose == "close" then
		Helper.closeMenuAndCancel(menu)
		menu.cleanup()
	else
		Helper.closeMenuAndReturn(menu)
		menu.cleanup()
	end
end

function overrideFuncs.getNPCs(entitytype, missionactor)
	local entitytype2 = nil --(entitytype == "shiptrader") and "smallshiptrader" or nil
	local npcs = {}
	for _, npc in ipairs(menu.npcs) do
		local owner, isenemy, type, iscontrolentity, isspecialist, ismissionactor = GetComponentData(npc, "owner", "isenemy", "typestring", "iscontrolentity", "isspecialist", "ismissionactor")
		if (isspecialist or missionactor or not iscontrolentity) and owner ~= "player" and not isenemy and ((entitytype == nil) or (type == entitytype) or (type == entitytype2)) and ((missionactor == nil) or (ismissionactor == missionactor)) then
			table.insert(npcs, npc)
		end
	end
	return npcs
end

local function init()
	for _, existingMenu in ipairs(Menus) do
		if existingMenu.name == "RemoteNPCsMenu" then
			menu = existingMenu
			for k, v in pairs(overrideFuncs) do
				menu[k] = v
			end
			break
		end
	end
end


init()
