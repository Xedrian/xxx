-- section == gMain_CrewList
-- param == { 0, 0, object }


local menu = {}

local override = {
	toprow = 0,
	selectrow = 2
}

function override.onShowMenu()
	menu.object = menu.param[3]
	menu.isplayership = IsSameComponent(menu.object, GetPlayerPrimaryShipID())
	menu.unlocked = {}

	if IsComponentClass(menu.object, "station") then
		menu.type = "station"
		menu.category = "stationtypes"
	elseif IsComponentClass(menu.object, "ship_xl") then
		menu.category = "shiptypes_xl"
	elseif IsComponentClass(menu.object, "ship_l") then
		menu.category = "shiptypes_l"
	elseif IsComponentClass(menu.object, "ship_m") then
		menu.category = "shiptypes_m"
	elseif IsComponentClass(menu.object, "ship_s") then
		menu.category = "shiptypes_s"
	elseif IsComponentClass(menu.object, "ship_xs") then
		menu.category = "shiptypes_xs"
	else
		menu.category = GetModuleType(menu.object)
	end

	local container = GetContextByClass(menu.object, "container", false)
	local name, objectowner = GetComponentData(menu.object, "name", "owner")
	if container then
		menu.title = GetComponentData(container, "name") .. " - " .. (name ~= "" and name or ReadText(1001, 56)) .. " - " .. ReadText(1001, 80)
	else
		menu.title = (name ~= "" and name or ReadText(1001, 56)) .. " - " .. ReadText(1001, 80)
	end

	-- Title line as one TableView
	local setup = Helper.createTableSetup(menu)

	local isplayer, reveal = GetComponentData(menu.object, "isplayerowned", "revealpercent")
	setup:addSimpleRow({
		Helper.createButton(nil, Helper.createButtonIcon("menu_info", nil, 255, 255, 255, 100), false, nil, nil, nil, Helper.headerRow1Height, Helper.headerRow1Height, nil, nil, nil, ReadText(1026, 4300)),
		Helper.createFontString(menu.title .. (isplayer and "" or " (" .. reveal .. " %)"), false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, Helper.headerRow1Height, Helper.headerRow1Width)
	}, nil, { 1, 1 }, false, Helper.defaultTitleBackgroundColor)
	setup:addTitleRow({
		Helper.getEmptyCellDescriptor()
	}, nil, { 2 })

	local infodesc = setup:createCustomWidthTable({ Helper.headerRow1Height, 0 }, false, false, true, 3, 1)

	setup = Helper.createTableSetup(menu)

	menu.unlocked.operator_name = IsInfoUnlockedForPlayer(menu.object, "operator_name")
	menu.unlocked.operator_details = IsInfoUnlockedForPlayer(menu.object, "operator_details")
	menu.unlocked.operator_commands = IsInfoUnlockedForPlayer(menu.object, "operator_commands")

	setup:addHeaderRow({
		ReadText(1001, 76),
		ReadText(20180212, 1000),
	}, nil, {2, 1 })


	menu.crew = GetNPCs(menu.object)
	if #menu.crew > 0 then
		local displayed = false
		for _, npc in ipairs(menu.crew) do
			local name, typestring, typeicon, typename, owner = GetComponentData(npc, "name", "typestring", "typeicon", "typename", "owner")
			if menu.isplayership and owner == "player" or owner == objectowner then
				displayed = true

				setup:addSimpleRow({
					Helper.createIcon(typeicon, false, 255, 255, 255, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight),
					typename .. " " .. Helper.unlockInfo(menu.unlocked.operator_name, name),
					xxxLibrary.createStarsText(xxxLibrary.getColorStringForCombinedSkill(GetComponentData(npc, "combinedskill")) .. "*")
				}, npc)
			end
		end
		if not displayed then
			setup:addSimpleRow({
				ReadText(1001, 4300)
			}, nil, { 3 })
		end
	else
		setup:addSimpleRow({
			ReadText(1001, 4300)
		}, nil, { 2 })
	end

	setup:addFillRows(16)

	local selectdesc = setup:createCustomWidthTable({ Helper.standardTextHeight, 0, 50 }, false, false, true, 1, 0, 0, Helper.tableOffsety, 485, nil, menu.toprow, menu.selectrow)

	-- button table
	setup = Helper.createTableSetup(menu)
	setup:addSimpleRow({
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 2669), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_B", true)),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 3216), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, menu.unlocked.operator_details, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true), nil, ReadText(1026, 4301)),
		Helper.getEmptyCellDescriptor()
	}, nil, nil, false, menu.transparent)
	local buttondesc = setup:createCustomWidthTable({ 48, 150, 48, 150, 0, 150, 48, 150, 48 }, false, false, true, 2, 1, 0, 555, 0, false)

	-- create tableview
	menu.infotable, menu.selecttable, menu.buttontable = Helper.displayThreeTableView(menu, infodesc, selectdesc, buttondesc, false)

	-- set button scripts
	Helper.setButtonScript(menu, nil, menu.infotable, 1, 1, menu.buttonShipEncyclopedia)

	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 2, function() return menu.onCloseElement("back") end)
	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 8, menu.buttonComm)

	-- clear descriptors again
	Helper.releaseDescriptors()
end

function override.onRowChanged(row, rowdata)
	menu.toprow = GetTopRow(menu.selecttable)
	menu.selectrow = Helper.currentDefaultTableRow
end


local function init()
	for _, existingMenu in ipairs(Menus) do
		if existingMenu.name == "CrewMenu" then
			menu = existingMenu
			for k, v in pairs(override) do
				menu[k] = v
			end
			break
		end
	end
end

init()
