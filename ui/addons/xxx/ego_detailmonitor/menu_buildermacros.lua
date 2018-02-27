-- section == cArch_stationmacros
-- param == { 0, 0, architect, buildership_or_module, forBuilding, dronewares }

-- ffi setup
local ffi = require("ffi")
local C = ffi.C
ffi.cdef [[
	bool IsDemoVersion(void);
]]

local menu = {
	name = "BuilderMacrosMenu",
	transparent = { r = 0, g = 0, b = 0, a = 0 }
}

local function init()
	Menus = Menus or { }
	table.insert(Menus, menu)
	if Helper then
		Helper.registerMenu(menu)
	end
end

function menu.cleanup()
	menu.architect = nil
	menu.buildership = nil
	menu.forBuilding = nil
	menu.builderMacros = {}
	menu.productgroups = {}
	menu.category = nil
	menu.shipbuilding = nil
	menu.buildanchor = nil
	menu.buildanchormacro = nil
	menu.demolimit = nil

	menu.infotable = nil
	menu.selecttable = nil
end

-- Menu member functions

function menu.buttonEncyclopedia(macro)
	Helper.closeMenuForSubSection(menu, false, "gEncyclopedia_object", { 0, 0, menu.category, macro, menu.category == "stationtypes" })
	menu.cleanup()
end

function menu.buttonBuild()
	if menu.rowDataMap[Helper.currentDefaultTableRow] then
		Helper.closeMenuForSubSection(menu, false, "cArch_selectUpgradesMenu", { 0, 0, menu.architect, menu.buildership, nil, menu.rowDataMap[Helper.currentDefaultTableRow], "", 0, true, menu.param[6] })
		menu.cleanup()
	end
end

function menu.onShowMenu()
	DebugError("show menu_buildermacros")
	menu.architect = menu.param[3]
	menu.buildership = menu.param[4]
	menu.forBuilding = (menu.param[5] and menu.param[5] ~= 0)

	menu.shipbuilding = false
	if GetComponentData(menu.architect, "typestring") == "shiptrader" then
		menu.shipbuilding = true
	end

	menu.demolimit = false
	if C.IsDemoVersion() then
		local numstations = #GetContainedStationsByOwner("player", nil, true)
		menu.demolimit = menu.forBuilding and (not menu.shipbuilding) and (numstations >= 2)
	end

	local title = menu.shipbuilding and ReadText(1001, 1802) or ReadText(1001, 1800)

	local setup = Helper.createTableSetup(menu)
	local name, typestring, typeicon, typename, ownericon = GetComponentData(menu.architect, "name", "typestring", "typeicon", "typename", "ownericon")
	setup:addTitleRow {
		Helper.createIcon(typeicon, false, 255, 255, 255, 100, 0, 0, Helper.headerCharacterIconSize, Helper.headerCharacterIconSize),
		Helper.createFontString(typename .. " " .. name, false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize),
		Helper.createIcon(ownericon, false, 255, 255, 255, 100, 0, 0, Helper.headerCharacterIconSize, Helper.headerCharacterIconSize)    -- text depends on selection
	}

	setup:addTitleRow({
		menu.demolimit and ("\27R" .. ReadText(1098, 51)) or Helper.getEmptyCellDescriptor()
	}, nil, { 3 })

	local infodesc = setup:createCustomWidthTable({ Helper.scaleX(Helper.headerCharacterIconSize), 0, Helper.scaleX(Helper.headerCharacterIconSize) + 37 }, false, true)

	setup = Helper.createTableSetup(menu)
	if menu.shipbuilding then
		setup:addHeaderRow({
			ReadText(1001, 2301),
			Helper.createFontString(ReadText(1001, 2415), false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, ReadText(1026, 1815)),
			Helper.createFontString(ReadText(1001, 1402), false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, ReadText(1026, 1816)),
		}, nil, { 2, 1, 1 })
	else
		setup:addHeaderRow({
			ReadText(1001, 1801),
			ReadText(1001, 2808),
			ReadText(1015, 71)
		}, nil, { 2, 1, 1 })
	end

	menu.builderMacros = menu.buildership and GetBuilderMacros(menu.buildership) or {}
	local infobutton = Helper.createButton(nil, Helper.createButtonIcon("menu_info", nil, 255, 255, 255, 100), false, true, 0, 0, 0, 0, nil, nil, nil, menu.shipbuilding and ReadText(1026, 1814) or ReadText(1026, 1801))

	menu.productgroups = {}
	local groupcount = 0
	for _, entry in ipairs(menu.builderMacros) do
		local purpose, purposename = GetMacroData(entry.macro, "primarypurpose", "primarypurposename")
		if purpose then
			if menu.productgroups[purpose] then
				table.insert(menu.productgroups[purpose], entry)
			else
				menu.productgroups[purpose] = { entry, name = purposename }
				groupcount = groupcount + 1
			end
		else
			if menu.productgroups[""] then
				table.insert(menu.productgroups[""], entry)
			else
				menu.productgroups[""] = { entry, name = ReadText(20213, 100) }
				groupcount = groupcount + 1
			end
		end
	end

	for purpose, group in Helper.orderedPairs(menu.productgroups) do
		if menu.shipbuilding or groupcount > 1 then
			setup:addHeaderRow({
				group.name
			}, nil, { 2 })
		end
		table.sort(group, function(a, b)
			return a.name < b.name
		end)
		for _, entry in ipairs(group) do
			if menu.shipbuilding then
				local storagetags, storagecapacity = GetMacroData(entry.macro, "storagenames", "storagecapacity")
				setup:addSimpleRow({
					infobutton,
					entry.name,
					storagetags,
					Helper.createFontString(ConvertIntegerString(storagecapacity, true, 4, true) .. " " .. ReadText(1001, 110), false, "right")
				}, entry.macro)
			else

				local duration = ConvertTimeString(GetBuildSlotDuration(entry.macro, "", 0), "%h:%M:%S")
				local upgrades = GetAllMacroUpgrades(entry.macro, "", 0, true)
				local upgradeplan = {}
				for _, upgrade in ipairs(upgrades) do
					if upgrade.total ~= 0 then
						upgrade.operational = 0 -- math.floor(0.25 * upgrade.total)
						table.insert(upgradeplan, { upgrade.upgrade, upgrade.operational / upgrade.total })
					end
				end
				local resources = GetBuildSlotResources(menu.buildership, entry.macro, "", 0, upgradeplan)
				local price = (next(resources) and resources.totalprice or 0)
				price = ConvertMoneyString(RoundTotalTradePrice(price), false, true, 5, true)
				setup:addSimpleRow({
					infobutton,
					entry.name,
					price,
					duration,
				}, entry.macro, { 1, 1, 1, 1 })
			end
			if IsMacroClass(entry.macro, "station") then
				menu.category = "stationtypes"
			elseif IsMacroClass(entry.macro, "ship_xl") then
				menu.category = "shiptypes_xl"
			elseif IsMacroClass(entry.macro, "ship_l") then
				menu.category = "shiptypes_l"
			elseif IsMacroClass(entry.macro, "ship_m") then
				menu.category = "shiptypes_m"
			elseif IsMacroClass(entry.macro, "ship_s") then
				menu.category = "shiptypes_s"
			elseif IsMacroClass(entry.macro, "ship_xs") then
				menu.category = "shiptypes_xs"
			end
			AddKnownItem(menu.category, entry.macro)
			if menu.shipbuilding then
				local productionmethod = GetBuildProductionMethod(menu.buildership, entry.macro)
				if productionmethod then
					AddKnownItem("productionmethods", productionmethod)
				end
			end
		end
	end
	setup:addFillRows(15)
	local selectdesc
	if menu.shipbuilding then
		selectdesc = setup:createCustomWidthTable({ Helper.standardTextHeight, 0, 300, 150 }, false, false, true, 1, 0, 0, Helper.tableCharacterOffsety, 428, false, nil)
	else
		selectdesc = setup:createCustomWidthTable({ Helper.standardTextHeight, 0, 150, 150 }, false, false, true, 1, 0, 0, Helper.tableCharacterOffsety, 428, false, nil)
	end

	-- button table
	setup = Helper.createTableSetup(menu)
	setup:addTitleRow({
		Helper.getEmptyCellDescriptor()
	}, nil, { 9 })

	local mot_build
	if menu.demolimit then
		mot_build = "\27R" .. ReadText(1098, 51)
	else
		if menu.forBuilding then
			if menu.shipbuilding then
				mot_build = ReadText(1026, 1813)
			else
				if menu.demolimit then
					mot_build = "\27R" .. ReadText(1026, 1841)
				else
					mot_build = ReadText(1026, 1800)
				end
			end
		else
			if menu.shipbuilding then
				mot_build = ReadText(1026, 1839)
			end
		end
	end
	setup:addSimpleRow({
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 2669), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_B", true)),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1010, 3), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, menu.forBuilding and (not menu.demolimit), 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true), nil, mot_build),
		Helper.getEmptyCellDescriptor()
	}, nil, nil, false, menu.transparent)
	local buttondesc = setup:createCustomWidthTable({ 48, 150, 48, 150, 0, 150, 48, 150, 48 }, false, false, true, 2, 2, 0, 520, 0, false)

	-- create tableview
	menu.infotable, menu.selecttable, menu.buttontable = Helper.displayThreeTableView(menu, infodesc, selectdesc, buttondesc, false)

	-- set button scripts
	local nooflines = 2
	for purpose, group in Helper.orderedPairs(menu.productgroups) do
		if menu.shipbuilding or groupcount > 1 then
			nooflines = nooflines + 1
		end
		for _, entry in ipairs(group) do
			Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
				return menu.buttonEncyclopedia(entry.macro)
			end)
			nooflines = nooflines + 1
		end
	end

	Helper.setButtonScript(menu, nil, menu.buttontable, 2, 2, function()
		return menu.onCloseElement("back")
	end)
	Helper.setButtonScript(menu, nil, menu.buttontable, 2, 8, menu.buttonBuild)

	-- clear descriptors again
	Helper.releaseDescriptors()
end

menu.updateInterval = 2.0

function menu.onUpdate()
	if menu.shipbuilding and not menu.forBuilding then
		menu.buildanchor = menu.buildanchor or (menu.buildership and GetBuildAnchor(menu.buildership) or nil)
		if menu.buildanchor then
			menu.buildanchormacro = menu.buildanchormacro or GetComponentData(menu.buildanchor, "macro")
			local _, _, curprogress = GetCurrentBuildSlot(menu.buildanchor)

			local nooflines = 2
			for purpose, group in Helper.orderedPairs(menu.productgroups) do
				if menu.shipbuilding or groupcount > 1 then
					nooflines = nooflines + 1
				end
				table.sort(group, function(a, b)
					return a.name < b.name
				end)
				for _, entry in ipairs(group) do
					if entry.macro == menu.buildanchormacro then
						Helper.updateCellText(menu.selecttable, nooflines, 2, entry.name .. " (" .. string.format(ReadText(1001, 1805), curprogress) .. ")")
					end
					nooflines = nooflines + 1
				end
			end
		end
	end
end

function menu.onRowChanged(row, rowdata)
	local rowdata = menu.rowDataMap and menu.rowDataMap[Helper.currentDefaultTableRow]
	if rowdata then
		local upgrades = GetAllMacroUpgrades(rowdata, "", 0, true)
		local upgradeplan = {}
		for _, upgrade in ipairs(upgrades) do
			if upgrade.total ~= 0 then
				upgrade.operational = 0 -- math.floor(0.25 * upgrade.total)
				table.insert(upgradeplan, { upgrade.upgrade, upgrade.operational / upgrade.total })
			end
		end
		if rowdata == GetPlayerPrimaryShipMacro() then
			DebugError("IMPORTANT - Tell Florian immediately. menu_buildermacros.lua is requesting the resources of the playership, should not happen. BuildModule: " .. GetComponentData(menu.buildership, "name"))
		end
		local resources = GetBuildSlotResources(menu.buildership, rowdata, "", 0, upgradeplan)
		local price = (menu.shipbuilding and 2 or 1) * (next(resources) and resources.totalprice or 0)
		Helper.updateCellText(menu.buttontable, 1, 1, (menu.shipbuilding and ReadText(1001, 2808) or ReadText(1001, 1803)) .. ReadText(1001, 120) .. " " .. ConvertMoneyString(RoundTotalTradePrice(price), false, true, 5, true) .. " " .. ReadText(1001, 101) .. ", " .. ReadText(1001, 1705) .. ReadText(1001, 120) .. " " .. ConvertTimeString(GetBuildSlotDuration(rowdata, "", 0), "%h:%M:%S"))
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
