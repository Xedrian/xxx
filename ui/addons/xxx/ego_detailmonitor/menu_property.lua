-- section == gMainInfo_property
-- param == { 0, 0, faction [, mode, modeparam] }
-- param2 == { 0, 0, restoreselection }

-- modes: - "sellship", param: { returnsection, buildmodule_or_container }
--		  - "selectobject", param: { returnsection, refcomponent, nil, nil, potentialsubordinate, disablestations, disablecapships, disablesmallships, canhavedrones, nosubordinate, noorder, haspilot, hascargocapacity, checkforbuildmodule, hasbuildingmodule, hascontrolentity, allowbuildingmodules }



-- ffi setup
local ffi = require("ffi")
local C = ffi.C
ffi.cdef [[
	typedef uint64_t UniverseID;
	typedef struct {
		int x;
		int y;
	} ResolutionInfo;
	double GetCurrentGameTime(void);
	bool GetLargeHUDMenusOption(void);
	ResolutionInfo GetWindowSize(void);
	bool IsVRMode(void);
]]

local menu = {}
local overrideFuncs = {}

local function init()
	for mnuKey, existingMenu in ipairs(Menus) do
		if existingMenu.name == "PropertyMenu" then
			menu = existingMenu

			menu.selectColsCount = 10
			menu.updateInterval = 1
			menu.sortedStationsByClusterAndZone = {}

			menu.display = overrideFuncs.display
			menu.addContainerRow = overrideFuncs.addContainerRow
			menu.createSection = overrideFuncs.createSection
			menu.setButtonsForSection = overrideFuncs.setButtonsForSection
			break
		end
	end
end

function overrideFuncs.display(firsttime)
	menu.lastupdate = C.GetCurrentGameTime()

	Helper.removeAllButtonScripts(menu)
	Helper.currentTableRow = {}
	Helper.currentTableRowData = nil
	menu.rowDataMap = {}

	menu.autopilottarget = GetAutoPilotTarget()

	local setup = Helper.createTableSetup(menu)

	local cols
	local colsLayout

	--local buttonsize = Helper.scaleY(Helper.headerRow1Height)
	local buttonsize = Helper.headerRow1Height

	if menu.faction ~= "player" then
		cols = { Helper.createFontString(menu.title, false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, Helper.headerRow1Height, Helper.headerRow1Width) }
		colsLayout = { 4 }
		setup:addTitleRow(cols, nil, colsLayout)
	else
		cols = {
			Helper.createButton(nil, Helper.createButtonIcon("mm_ic_info_propertyowned", nil, 255, 255, 255, 100), false, false, 0, 0, buttonsize, buttonsize, nil, nil, nil, ReadText(1026, 3906)),
			Helper.createButton(nil, Helper.createButtonIcon("menu_inventory", nil, 255, 255, 255, 100), false, menu.mode ~= "sellship", 0, 0, buttonsize, buttonsize, nil, nil, nil, ReadText(1026, 3907)),
			Helper.createButton(nil, Helper.createButtonIcon("menu_weapons", nil, 255, 255, 255, 100), false, menu.mode ~= "sellship", 0, 0, buttonsize, buttonsize, nil, nil, nil, ReadText(1026, 3908)),
			Helper.createFontString(menu.title, false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, Helper.headerRow1Height, Helper.headerRow1Width)
		}
		colsLayout = { 1, 1, 1, 1 }
		setup:addSimpleRow(cols, nil, colsLayout, false, Helper.defaultTitleBackgroundColor)
	end
	cols = { Helper.createFontString("", false, "left", 129, 160, 182, 100, Helper.headerRow2Font, Helper.headerRow2FontSize, true, Helper.headerRow2Offsetx, Helper.headerRow2Offsety, 2 * Helper.headerRow2Height, Helper.headerRow1Width) }
	colsLayout = { 4 }
	setup:addTitleRow(cols, nil, colsLayout)

	local infodesc = setup:createCustomWidthTable({ buttonsize, buttonsize, buttonsize, 0 }, false, false, true, (menu.faction ~= "player") and 0 or 3, 2, nil, nil, nil)

	menu.stations = GetContainedStationsByOwner(menu.faction)
	menu.ships = GetContainedShipsByOwner(menu.faction)
	menu.drones = {}

	for i = #menu.ships, 1, -1 do
		local commander = GetCommander(menu.ships[i])
		if commander then
			table.remove(menu.ships, i)
		elseif IsSameComponent(menu.ships[i], menu.playership) then
			table.remove(menu.ships, i)
		elseif menu.mode == "sellship" and (not GetComponentData(menu.ships[i], "issellable")) then
			table.remove(menu.ships, i)
		elseif IsComponentClass(menu.ships[i], "drone") then
			local dronecommander = GetDroneCommander(menu.ships[i])
			if not IsSameComponent(dronecommander, menu.playership) then
				table.insert(menu.drones, 1, menu.ships[i])
			end
			table.remove(menu.ships, i)
		end
	end
	menu.subordinates = {}

	setup = Helper.createTableSetup(menu)

	if menu.mode ~= "sellship" then
		menu.createSection(setup, "stations", ReadText(1001, 4), menu.stations, "-- " .. ReadText(1001, 33) .. " --", true)
	end
	menu.createSection(setup, "ships", ReadText(1001, 6), menu.ships, "-- " .. ReadText(1001, 34) .. " --", true)
	setup:addFillRows(16, nil, { 10 })

	local selectTableWidths = {
		Helper.standardTextHeight, -- col 1: collapse/expand
		Helper.standardTextHeight, -- col 2: checkbox
		0, -- col 3:  name => autosize columns

	-- HINT if ship has no jump drive cols 4+5 will be 6+7
		Helper.standardTextHeight, -- col 4: drone info icon
		42, -- col 5: drone count text (width needs to fit max "999")

		Helper.standardTextHeight, -- col 6: jump fuel icon
		55, -- col 7:  jump fuel load in percent -- width of "55" fits for "100%"

		50, -- col 8: three stars captain/manager + engineer + defencecontrol

		Helper.standardTextHeight, -- col 9:  warning-icon
		138 -- col 10:  cargo / sellprice

	-- more then 10 cols are not ALLOWED by GUI!
	}

	menu.selectColsCount = table.getLength(selectTableWidths)

	local selectdesc = setup:createCustomWidthTable(selectTableWidths, false, false, true, 1, 0, 0, Helper.tableOffsety + Helper.headerRow2Height, 460, false, menu.toprow, menu.selectrow, menu.selectcol)

	menu.toprow = nil
	menu.selectrow = nil
	menu.selectcol = nil

	-- button table
	setup = Helper.createTableSetup(menu)

	cols = {
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 2669), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_B", true)),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 3408), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, not menu.mode, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_BACK", true)),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 3216), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, not menu.mode, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_Y", true)),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(menu.mode and ReadText(1001, 3102) or ReadText(1001, 2961), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true)),
		Helper.getEmptyCellDescriptor()
	}
	colsLayout = nil

	setup:addSimpleRow(cols, nil, colsLayout, false, menu.transparent)
	local buttondesc = setup:createCustomWidthTable({ 48, 150, 48, 150, 0, 150, 48, 150, 48 }, false, false, true, 2, 1, 0, 560, 0, false)

	-- create tableview
	menu.infotable, menu.selecttable, menu.buttontable = Helper.displayThreeTableView(menu, infodesc, selectdesc, buttondesc, false, "", "", 0, 0, 0, 0, "both", firsttime)

	local offsetrow = 1
	if menu.mode ~= "sellship" then
		offsetrow = menu.setButtonsForSection("stations", menu.stations, offsetrow)
	end
	if menu.tripheader then
		Helper.updateCellText(menu.selecttable, offsetrow, 3, ReadText(1001, 6) .. " (" .. ReadText(1001, 2937) .. ")")
		menu.tripheader = nil
	end
	offsetrow = menu.setButtonsForSection("ships", menu.ships, offsetrow)

	-- set button scripts
	if menu.faction == "player" then
		Helper.setButtonScript(menu, nil, menu.infotable, 1, 2, menu.buttonInventory)
		Helper.setButtonScript(menu, nil, menu.infotable, 1, 3, menu.buttonWeaponUpgrades)
	end

	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 2, function()
		return menu.onCloseElement("back")
	end)
	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 4, menu.buttonShowMap)
	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 6, menu.buttonComm)
	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 8, menu.buttonDetails)

	-- clear descriptors again
	Helper.releaseDescriptors()
end

function overrideFuncs.addContainerRow(setup, component, iteration, subordinatewarning)
	local isStation = xxxLibrary.isStation(component)
	local isShip = xxxLibrary.isShip(component)
	local buildAnchor = GetBuildAnchor(component)
	local isConstructionVesselAttached = (not isStation) and (buildAnchor ~= nil)

	menu.tripheader = menu.tripheader or (isShip and (not buildAnchor) and (GetComponentData(component, "numtrips") > 0))

	local subordinates = xxxLibrary.getSubordinates(component)

	local name = GetComponentData(component, "name")
	local storage = GetStorageData(component)
	local warning, cargoWarning, creditWarning = xxxLibrary.hasObjectWarningSplit(component)

	menu.subordinates[tostring(component)] = subordinates or {}
	name = xxxLibrary.componentNameUpdate(component, name, iteration, menu.mode == "sellship")

	local columns = {}
	local columnSetup = {}

	local nameColumnColSpan = menu.selectColsCount

	-- col1 - expand / collapse
	local button = ""
	if #subordinates > 0 then
		local buttonText = Helper.createButtonText(menu.extendedcategories[tostring(component)] and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100)
		local choosenColor = Helper.defaultButtonBackgroundColor
		local criticalDamageIndicator = xxxLibrary.subordinatesHasCriticalDamage(subordinates)
		if criticalDamageIndicator > 2 then
			choosenColor = Helper.statusRed
		elseif criticalDamageIndicator > 1 then
			choosenColor = Helper.statusOrange
		elseif criticalDamageIndicator > 0 then
			choosenColor = Helper.statusYellow
		end

		-- yellow and red is put down in brightness
		button = Helper.createButton(buttonText, nil, false, true, 0, 0, 0, Helper.standardTextHeight, criticalDamageIndicator == 2 and xxxLibrary.darkenColor(choosenColor, 0.75) or choosenColor)
	end
	table.insert(columns, button)
	table.insert(columnSetup, 1)
	nameColumnColSpan = nameColumnColSpan - 1

	-- col2 - checkbox
	local chkChecked = menu.selectedcontainers[tostring(component)] ~= nil
	local chkColor = subordinatewarning and menu.yellow or nil

	local cansell = false
	if (menu.mode == "sellship") then
		if not IsSameComponent(component, menu.playership) and (not GetBuildAnchor(component)) then
			local pilot = GetComponentData(component, "pilot")
			if (not pilot) or (not GetNPCBlackboard(pilot, "$shiptrader_docking")) then
				if GetTotalValue(component, true, GetContextByClass(menu.modeparam[2], "container")) then
					cansell = true
				end
			end
		end
	end

	local chkActive = (menu.mode ~= "selectobject") and ((not isStation) or (#subordinates > 0)) and ((not isConstructionVesselAttached))

	if menu.mode == "sellship" then
		if not IsSameComponent(component, menu.playership) and (not GetBuildAnchor(component)) then
			local pilot = GetComponentData(component, "pilot")
			if (not pilot) or (not GetNPCBlackboard(pilot, "$shiptrader_docking")) then
				if GetTotalValue(component, true, GetContextByClass(menu.modeparam[2], "container")) then
					chkActive = true
				end
			end
		end
	end

	local chkMouseOverText = ReadText(1026, 1009) or nil
	table.insert(columns, Helper.createCheckBox(chkChecked, false, chkColor, chkActive, 2, 2, Helper.standardTextHeight - 4, Helper.standardTextHeight - 4, chkMouseOverText))
	table.insert(columnSetup, 1)
	nameColumnColSpan = nameColumnColSpan - 1

	-- col3 - name | Dummy will be override in the end
	table.insert(columns, name)
	table.insert(columnSetup, nameColumnColSpan)

	-- col4
	if isStation then
		local buildingStatusText, buildCompleted = xxxLibrary.fetchStationBuildingStatus(component)
		if buildingStatusText ~= "" then

			table.insert(columns, Helper.createIcon("architect_inactive", false, 255, 255, 255, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight))
			table.insert(columnSetup, 1)
			nameColumnColSpan = nameColumnColSpan - 1

			table.insert(columns, Helper.createFontString(buildingStatusText, false, "right"))
			table.insert(columnSetup, 3)
			nameColumnColSpan = nameColumnColSpan - 3
		end
	elseif isShip then

		-- icon double arrow to right: droneability_seta
		-- icon double arrow down: action_dock
		-- icon double arrow up: action_undock
		-- icon attack-cross: action_attack

		local hasJumpDrive, macro, tmpName = GetComponentData(component, "hasjumpdrive", "macro", "name")

		local isSmallCollectorShip = string.match(macro, "units_size_m_") and string.match(macro, "_collector_")

		local relevantDroneCount, icon = xxxLibrary.fetchDroneInfo(component, isSmallCollectorShip)

		local hasDrones = relevantDroneCount ~= nil and relevantDroneCount ~= "0"

		if hasDrones then
			-- if drone count is "0" and not colorized we assume it should not be displayed
			-- drone info
			table.insert(columns, Helper.createIcon(icon, false, 255, 255, 255, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight))
			table.insert(columnSetup, 1)
			nameColumnColSpan = nameColumnColSpan - 1
			table.insert(columns, Helper.createFontString(relevantDroneCount, false, "right"))
			table.insert(columnSetup, 1)
			nameColumnColSpan = nameColumnColSpan - 1
		end

		-- fuel
		if hasJumpDrive then
			table.insert(columns, Helper.createIcon("ware_fuelcells", false, 255, 255, 255, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight))
			table.insert(columnSetup, 1)
			nameColumnColSpan = nameColumnColSpan - 1

			local fuelamount = GetComponentData(component, "cargo")["fuelcells"] or 0
			local fuelcapacity = GetWareCapacity(component, "fuelcells")
			local fueltextStr = ""
			if fuelcapacity > 0 then
				fueltextStr = (math.floor(fuelamount / fuelcapacity * 100)) .. "%"
			end
			local fueltext = Helper.createFontString(fueltextStr, false, "right")
			table.insert(columns, fueltext)
			table.insert(columnSetup, 1)
			nameColumnColSpan = nameColumnColSpan - 1
		else
			if hasDrones then
				-- if ship has drones but no jump create a 2col empty block to align up to the rest
				table.insert(columns, "")
				table.insert(columnSetup, 2)
				nameColumnColSpan = nameColumnColSpan - 2
			end
		end
	end

	local threeSkill = xxxLibrary.fetchComponentCrewSkills(component)

	-- 3 skills
	table.insert(columns, threeSkill)
	table.insert(columnSetup, 1)
	nameColumnColSpan = nameColumnColSpan - 1

	-- col6 - cargo / sellprice
	local cargoColSpan = 2

	if menu.mode ~= "sellship" then
		-- col7 - info
		if warning > 0 then
			-- warning got higher priority
			table.insert(columns, Helper.createIcon("workshop_error", false, warning == 2 and 255 or 192, warning == 2 and 0 or 192, 0, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight))
			table.insert(columnSetup, 1)
			nameColumnColSpan = nameColumnColSpan - 1
			cargoColSpan = cargoColSpan - 1
		elseif creditWarning > 0 then
			local color = creditWarning > 1 and Helper.statusRed or Helper.statusYellow
			table.insert(columns, Helper.createIcon("xxx_credits", false, color.r, color.g, color.b, color.a, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight))
			table.insert(columnSetup, 1)
			nameColumnColSpan = nameColumnColSpan - 1
			cargoColSpan = cargoColSpan - 1
		end
	end

	if menu.mode ~= "sellship" then
		if next(storage) and storage.capacity > 0 then
			local singleWareStorageExceeded = cargoWarning
			local sCargoText = ""
			if singleWareStorageExceeded == 1 then
				sCargoText = sCargoText .. Helper.colorStringYellow
			end
			-- sCargoText = sCargoText .. ConvertIntegerString(storage.stored, true, 4, true)
			sCargoText = sCargoText .. math.floor(storage.stored / storage.capacity * 100) .. "%"
			sCargoText = sCargoText .. Helper.colorStringDefault
			sCargoText = sCargoText .. " / "

			sCargoText = sCargoText .. ConvertIntegerString(storage.capacity, true, 4, true)
			-- sCargoText = sCargoText .. " " .. ReadText(1001, 110)

			-- tmp cargo text to adjust last col width to required min
			-- sCargoText = "100% / 99.999 k m³"

			table.insert(columns, Helper.createFontString(sCargoText, false, "right"))
		else
			table.insert(columns, Helper.getEmptyCellDescriptor()) -- blank cargo col if no capacity
		end
	else
		local totalprice = GetTotalValue(component, true, GetContextByClass(menu.modeparam[2], "container"))
		local totalPriceStr = (totalprice > 0 and ConvertMoneyString(totalprice, false, 0, false, true) or "-") .. " " .. ReadText(1001, 101)
		table.insert(columns, Helper.createFontString(totalPriceStr, false, "right"))
	end

	table.insert(columnSetup, cargoColSpan)
	nameColumnColSpan = nameColumnColSpan - cargoColSpan


	-- finally fix the colspan of name column
	columnSetup[3] = nameColumnColSpan

	-- add table row
	setup:addSimpleRow(columns, component, columnSetup, false, Helper.defaultHeaderBackgroundColor) -- change background color to "black"

	if isStation then
		AddKnownItem("stationtypes", GetComponentData(component, "macro"))
	elseif IsComponentClass(component, "ship_xl") then
		AddKnownItem("shiptypes_xl", GetComponentData(component, "macro"))
	elseif IsComponentClass(component, "ship_l") then
		AddKnownItem("shiptypes_l", GetComponentData(component, "macro"))
	elseif IsComponentClass(component, "ship_m") then
		AddKnownItem("shiptypes_m", GetComponentData(component, "macro"))
	elseif IsComponentClass(component, "ship_s") then
		AddKnownItem("shiptypes_s", GetComponentData(component, "macro"))
	elseif IsComponentClass(component, "ship_xs") then
		AddKnownItem("shiptypes_xs", GetComponentData(component, "macro"))
	end

	if menu.extendedcategories[tostring(component)] then
		for _, subordinate in ipairs(subordinates) do
			menu.addContainerRow(setup, subordinate, iteration + 1, true)
		end
	end
end

function overrideFuncs.createSection(setup, name, header, array, nonetext, addheader)

	-- ### prepare header data ### --
	-- 1: expand/collapse ###
	local itemExpandCollapse = #array > 0 and Helper.createButton(Helper.createButtonText(menu.extendedcategories[name] and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight) or ""

	-- 2: check box ###
	local chkChecked = menu.selectedcontainers[name] ~= nil
	local chkColor = (name == "stations") and menu.yellow or nil
	chkColor = nil
	local chkActive = (menu.mode ~= "selectobject") and ((#array > 0) or (menu.faction == "player")) or (name == "ships" and menu.faction == "player")
	local chkMouseOverText = (name == "stations") and ReadText(1026, 1010) or nil
	local itemCheckbox = Helper.createCheckBox(chkChecked, false, chkColor, chkActive, 2, 2, Helper.standardTextHeight - 4, Helper.standardTextHeight - 4, chkMouseOverText)
	chkChecked = nil
	chkColor = nil
	chkActive = nil
	chkMouseOverText = nil

	-- 5: (ships only) Fuel / Drones
	-- 6: storage capacity
	local itemStorageCapacity = (menu.mode == "sellship") and ReadText(1001, 2808) or ReadText(20180212, 1001) .. " " .. ReadText(1001, 110)
	-- ### build header data ### --
	if addheader then
		if name == "ships" then
			setup:addSimpleRow({
				itemExpandCollapse,
				itemCheckbox,
				header,
				Helper.createFontString(ReadText(20180212, 1000), false, "center"),
				Helper.createFontString(itemStorageCapacity, false, "right")
			}, nil, { 1, 1, menu.selectColsCount - 5, 1, 2 }, false, Helper.defaultHeaderBackgroundColor)
		else
			setup:addSimpleRow({
				itemExpandCollapse,
				itemCheckbox,
				header,
				Helper.createFontString(ReadText(20180212, 1000), false, "center"),
				Helper.createFontString(itemStorageCapacity, false, "right")
			}, nil, { 1, 1, menu.selectColsCount - 5, 1, 2 }, false, Helper.defaultHeaderBackgroundColor)
		end
	else
		setup:addSimpleRow({ itemExpandCollapse, itemCheckbox, header }, nil, { 1, 1, menu.selectColsCount - 2 }, false, Helper.defaultHeaderBackgroundColor)
	end

	itemExpandCollapse = nil
	itemCheckbox = nil

	-- itemStorageCapacity = nil

	if menu.extendedcategories[name] then
		if name == "ships" and menu.faction == "player" then
			local subordinates = GetSubordinates(menu.playership)
			for i = #subordinates, 1, -1 do
				if IsComponentClass(subordinates[i], "ship_xs") then
					table.remove(subordinates, i)
				elseif menu.mode == "sellship" and (not GetComponentData(subordinates[i], "issellable")) then
					table.remove(subordinates, i)
				end
			end
			menu.subordinates[tostring(menu.playership)] = subordinates


			-- albion skunk
			setup:addSimpleRow({
				#subordinates > 0 and Helper.createButton(Helper.createButtonText(menu.extendedcategories[tostring(menu.playership)] and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight) or "",
				Helper.createCheckBox(menu.selectedcontainers[tostring(menu.playership)] ~= nil, false, nil, (menu.mode ~= "selectobject") and (#subordinates > 0), 2, 2, Helper.standardTextHeight - 4, Helper.standardTextHeight - 4, nil),
				GetComponentData(menu.playership, "name")
			}, menu.playership, { 1, 1, menu.selectColsCount - 2 }, false, Helper.defaultHeaderBackgroundColor)
			AddKnownItem("shiptypes_s", GetComponentData(menu.playership, "macro"))
			if menu.extendedcategories[tostring(menu.playership)] then
				for _, subordinate in ipairs(subordinates) do
					menu.addContainerRow(setup, subordinate, 1, false)
				end
			end
			---
		end

		if #array == 0 and not (name == "ships" and menu.faction == "player") then
			setup:addSimpleRow({
				Helper.getEmptyCellDescriptor(),
				nonetext
			}, nil, { 2, menu.selectColsCount - 2 })
		elseif #array ~= 0 then
			if name == "stations" then
				menu.sortedStationsByClusterAndSector = {}
				local grpIdentifier = ""
				for _, component in ipairs(array) do
					local tmpName, cluster, clusterId, sector, sectorId = GetComponentData(component, "name", "cluster", "clusterid", "sector", "sectorid")
					grpIdentifier = "stationGrp-" .. cluster .. "-" .. sector
					if not menu.sortedStationsByClusterAndSector[grpIdentifier] then
						menu.sortedStationsByClusterAndSector[grpIdentifier] = {
							clusterId = clusterId,
							cluster = cluster,
							sectorId = sectorId,
							sector = sector,
							subordinates = {}
						}
						table.insert(menu.sortedStationsByClusterAndSector, grpIdentifier)
					end
					table.insert(menu.sortedStationsByClusterAndSector[grpIdentifier].subordinates, component)
				end

				for _, grpIdentifier in ipairs(menu.sortedStationsByClusterAndSector) do

					local choosenColor = Helper.defaultButtonBackgroundColor
					local criticalDamageIndicator = xxxLibrary.subordinatesHasCriticalDamage(menu.sortedStationsByClusterAndSector[grpIdentifier].subordinates)
					if criticalDamageIndicator > 2 then
						choosenColor = Helper.statusRed
					elseif criticalDamageIndicator > 1 then
						choosenColor = Helper.statusOrange
					elseif criticalDamageIndicator > 0 then
						choosenColor = Helper.statusYellow
					end

					local grpIsExpanded = menu.extendedcategories[grpIdentifier]
					setup:addSimpleRow({
						Helper.createButton(Helper.createButtonText(grpIsExpanded and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight, choosenColor),
						menu.sortedStationsByClusterAndSector[grpIdentifier].cluster .. " - " .. menu.sortedStationsByClusterAndSector[grpIdentifier].sector .. " (" .. (#menu.sortedStationsByClusterAndSector[grpIdentifier].subordinates) .. " " .. ReadText(1001, 4) .. ")"
					}, nil, { 1, menu.selectColsCount - 1 }, false)
					if grpIsExpanded then
						for _, subordinate in ipairs(menu.sortedStationsByClusterAndSector[grpIdentifier].subordinates) do
							menu.addContainerRow(setup, subordinate, 0, false)
						end
					end
				end
			else
				for i, component in ipairs(array) do
					menu.addContainerRow(setup, component, 0, false)
				end
			end
		end
	end
end

function overrideFuncs.setButtonsForSection(name, array, offsetrow)
	if #array > 0 or (name == "ships" and menu.faction == "player") then
		local row = offsetrow
		Helper.setCheckBoxScript(menu, nil, menu.selecttable, row, 2, function()
			return menu.checkboxSelected(name, row)
		end)
		Helper.setButtonScript(menu, nil, menu.selecttable, row, 1, function()
			return menu.buttonExtend(name, row)
		end)
	end
	local nooflines = offsetrow + 1
	if menu.extendedcategories[name] then
		if name == "ships" and menu.faction == "player" then
			nooflines = menu.addContainerButtonScript(menu.playership, nooflines)
		end
		if #array == 0 and not (name == "ships" and menu.faction == "player") then
			nooflines = nooflines + 1
		elseif #array ~= 0 then

			if name == "stations" then
				for _, grpIdentifier in ipairs(menu.sortedStationsByClusterAndSector) do
					local grpIsExpanded = menu.extendedcategories[grpIdentifier]

					local clusterSectorRow = nooflines
					Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
						return menu.buttonExtend(grpIdentifier, clusterSectorRow)
					end)

					nooflines = nooflines + 1
					if grpIsExpanded then
						for _, component in ipairs(menu.sortedStationsByClusterAndSector[grpIdentifier].subordinates) do
							nooflines = menu.addContainerButtonScript(component, nooflines)
						end
					end
				end
			else
				for i, component in ipairs(array) do
					nooflines = menu.addContainerButtonScript(component, nooflines)
				end
			end
		end
	end
	return nooflines
end

-- library function



init()
