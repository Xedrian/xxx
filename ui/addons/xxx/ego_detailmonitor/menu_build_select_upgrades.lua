
-- section == cArch_selectUpgradesMenu
-- param == { 0, 0, trader, buildership_or_module, object, macro, sequence, stage, buildlimit, dronewares }
-- param2 == upgradeplan

local menu = {
	name = "SelectUpgradesMenu",
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
	menu.title = nil
	menu.entity = nil
	menu.object = nil
	menu.macro = nil
	menu.buildlimit = nil
	menu.upgrades = {}
	menu.upgradeplan = {}
	menu.shipbuilding = nil

	menu.infotable = nil
	menu.selecttable = nil
end

-- Menu member functions

function menu.buttonSelect()
	if menu.rowDataMap[Helper.currentDefaultTableRow] then
		local upgrade = menu.rowDataMap[Helper.currentDefaultTableRow]
		Helper.closeMenuForSubSection(menu, false, "gMain_buildUpgradesSliderMenu", {0, 0, menu.entity, upgrade.upgrade, upgrade.name, upgrade.operational, upgrade.total, menu.upgradeplan, menu.macro ~= nil, menu.buildership, menu.object, menu.macro, menu.sequence, menu.stage, menu.buildlimit})
		menu.cleanup()
	end
end

function menu.buttonOK()
	if menu.shipbuilding and menu.macro ~= nil and GetMacroUnitStorageCapacity(menu.macro, menu.sequence, menu.stage, menu.buildlimit) > 0 then
		Helper.closeMenuForSubSection(menu, false, "gMain_selectDronesMenu", { 0, 0, menu.entity, menu.buildership, menu.object, menu.macro, menu.sequence, menu.stage, menu.buildlimit, menu.upgradeplan, menu.param[10] })
	else
		Helper.closeMenuForSubSection(menu, false, "cArch_buildcost", { 0, 0, menu.entity, menu.buildership, menu.object, menu.macro, menu.sequence, menu.stage, menu.upgradeplan, menu.buildlimit, nil, menu.object ~= nil })
	end
	menu.cleanup()
end

function menu.onShowMenu()
	DebugError("show menu_build_select_upgrades")
	menu.entity = menu.param[3]
	menu.buildership = menu.param[4]
	menu.object = menu.param[5]
	menu.macro = menu.param[6]
	menu.sequence = menu.param[7]
	menu.stage = menu.param[8]
	menu.buildlimit = menu.param[9] == nil and true or (menu.param[9] ~= 0)
	menu.upgradeplan = menu.param2
	menu.title = ReadText(1001, 2817)

	menu.shipbuilding = false
	if GetComponentData(menu.entity, "typestring") == "shiptrader" then
		menu.shipbuilding = true
	end

	-- Title line as one TableView (Entity running the shop)
	local setup = Helper.createTableSetup(menu)

	local name, typestring, typeicon, typename, ownericon = GetComponentData(menu.entity, "name", "typestring", "typeicon", "typename", "ownericon")
	setup:addTitleRow{
		Helper.createIcon(typeicon, false, 255, 255, 255, 100, 0, 0, Helper.headerCharacterIconSize, Helper.headerCharacterIconSize),
		Helper.createFontString(typename .. " " .. name, false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize),
		Helper.createIcon(ownericon, false, 255, 255, 255, 100, 0, 0, Helper.headerCharacterIconSize, Helper.headerCharacterIconSize)	-- text depends on selection
	}
	
	setup:addTitleRow({
		Helper.getEmptyCellDescriptor()
	}, nil, {3})

	local infodesc = setup:createCustomWidthTable({ Helper.scaleX(Helper.headerCharacterIconSize), 0, Helper.scaleX(Helper.headerCharacterIconSize) + 37 }, false, true)
	
	
	-- Second TableView, rest of the menu (ware list)
	setup = Helper.createTableSetup(menu)
	
	setup:addHeaderRow({ 
		Helper.createFontString(menu.title, false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerCharacterRow2FontSize, false, 0, 0, Helper.headerCharacterRow2Height) 
	}, nil, {3})
	
	if menu.object then
		if menu.sequence == "" and not menu.buildlimit then
			menu.upgrades = GetAllUpgrades(menu.object, menu.buildlimit)
		else
			menu.upgrades = GetBuildStageUpgrades(menu.object, menu.sequence, menu.stage, menu.buildlimit)
		end
		if not menu.upgradeplan then
			menu.upgradeplan = {}
			for ut, upgrade in Helper.orderedPairs(menu.upgrades) do
				if not (ut == "totaltotal" or ut == "totalfree" or ut == "totaloperational" or ut == "totalconstruction" or ut == "estimated") then
					if upgrade.total ~= 0 then
						table.insert(menu.upgradeplan, { ut, upgrade.operational / upgrade.total })
					end
				end
			end
		end
	else
		menu.upgrades = GetAllMacroUpgrades(menu.macro, menu.sequence, menu.stage, menu.buildlimit)
		if not menu.upgradeplan then
			menu.upgradeplan = {}
			for _, upgrade in ipairs(menu.upgrades) do
				if upgrade.total ~= 0 then
					upgrade.operational = 0 -- math.floor(0.25 * upgrade.total)
					table.insert(menu.upgradeplan, { upgrade.upgrade, upgrade.operational / upgrade.total })
				end
			end
		end
	end

	if menu.shipbuilding then
		setup:addHeaderRow({ 
			ReadText(1001, 3100), 
			Helper.createFontString(ReadText(1001, 1202), false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, ReadText(1026, 1817)),
			Helper.createFontString(ReadText(1001, 2808), false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, ReadText(1026, 1818))
		})
	else
		setup:addHeaderRow({ 
			ReadText(1001, 3100), 
			Helper.createFontString(ReadText(1001, 1202), false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, ReadText(1026, 1802)),
		}, nil, {2, 1})
	end
	for ut, upgrade in Helper.orderedPairs(menu.upgrades) do
		if not (ut == "totaltotal" or ut == "totalfree" or ut == "totaloperational" or ut == "totalconstruction" or ut == "estimated") then
			if upgrade.total ~= 0 then
				if not upgrade.upgrade then
					upgrade.upgrade = ut
				end
				local operational
				for _, upgradeplanentry in ipairs(menu.upgradeplan) do
					if upgradeplanentry[1] == upgrade.upgrade then
						operational = Helper.round(upgradeplanentry[2] * upgrade.total)
						break
					end
				end
				if not upgrade.operational then
					upgrade.operational = operational
				end

				if menu.shipbuilding then
					local price = 2 * GetUpgradesResources(menu.buildership, menu.macro or menu.object, menu.sequence, menu.stage, menu.buildlimit, {{ upgrade.upgrade, operational / upgrade.total }}).totalprice

					setup:addSimpleRow({
						upgrade.name, 
						Helper.createFontString(operational .. " / " .. upgrade.total, false, "right"),
						Helper.createFontString(ConvertMoneyString(price, false, true, 5, true) .. " " .. ReadText(1001, 101), false, "right")
					}, upgrade)
				else
					setup:addSimpleRow({
						upgrade.name, 
						Helper.createFontString(operational .. " / " .. upgrade.total, false, "right")
					}, upgrade, {2, 1})
				end
			end
		end
	end
	setup:addFillRows(11, nil, {3})
	
	local selectdesc = setup:createCustomWidthTable({ 0, 150, 150 }, false, false, true, 1, 0, 0, Helper.tableCharacterOffsety, 500)
	
	-- button table
	setup = Helper.createTableSetup(menu)
	setup:addSimpleRow({ 
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 2669), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_B", true), nil, ReadText(1026, 1805)),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 3105), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_Y", true)),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 2962), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true), nil, ReadText(1026, 1804)),
		Helper.getEmptyCellDescriptor()
	}, nil, nil, false, menu.transparent)
	local buttondesc = setup:createCustomWidthTable({48, 150, 48, 150, 0, 150, 48, 150, 48}, false, false, true, 2, 1, 0, 550, 0, false)
	
	-- create tableview
	menu.infotable, menu.selecttable, menu.buttontable = Helper.displayThreeTableView(menu, infodesc, selectdesc, buttondesc, false)

	-- set button scripts
	local nooflines = 3
	for ut, upgrade in Helper.orderedPairs(menu.upgrades) do
		if not (ut == "totaltotal" or ut == "totalfree" or ut == "totaloperational" or ut == "totalconstruction" or ut == "estimated") then
			if upgrade.total ~= 0 then
				if not upgrade.upgrade then
					upgrade.upgrade = ut
				end
				nooflines = nooflines + 1
			end
		end
	end

	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 2, function () return menu.onCloseElement("back") end)
	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 6, menu.buttonSelect)
	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 8, menu.buttonOK)

	-- clear descriptors again
	Helper.releaseDescriptors()
end

-- menu.updateInterval = 2.0

function menu.onUpdate()
end

function menu.onRowChanged(row, rowdata)
	if rowdata then
		local active = (rowdata.operational < rowdata.total) or menu.macro ~= nil
		local mot_change
		if active then
			if menu.shipbuilding then
				mot_change = ReadText(1026, 1819)
			else
				mot_change = ReadText(1026, 1803)
			end
		end
		Helper.removeButtonScripts(menu, menu.buttontable, 1, 6)
		SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(1001, 3105), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, active, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_Y", true), nil, mot_change), 1, 6)
		Helper.setButtonScript(menu, nil, menu.buttontable, 1, 6, menu.buttonSelect)
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
