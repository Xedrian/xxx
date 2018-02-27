
-- section == cArch_buildcost
-- param == { 0, 0, architect, buildership_or_module, component, macro, sequence, stage, upgradeplan, buildlimit, targethullfraction, upgradesonly, droneplan, ammoplan }

local menu = {
	name = "BuildCostMenu",
	white = { r = 255, g = 255, b = 255, a = 100 },
	red = { r = 255, g = 0, b = 0, a = 100 },
	green = { r = 0, g = 255, b = 0, a = 100 }
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
	menu.component = nil
	menu.macro = nil
	menu.sequence = nil
	menu.stage = nil
	menu.upgradeplan = nil
	menu.shipbuilding = nil
	menu.cost = nil
	menu.current = nil
	menu.buildlimit = nil
	menu.targethullfraction = nil
	menu.upgradesonly = nil
	menu.droneplan = {}
	menu.hasentries = nil
	menu.isokbuttonenabled = nil
	menu.neededresources = {}

	menu.infotable = nil
	menu.selecttable = nil
end

-- Menu member functions

function menu.buttonOK()
	local sellercontainer = GetContextByClass(menu.buildership, "container", true)
	if menu.shipbuilding then
		for _, entry in ipairs(menu.droneplan) do
			if entry[2] > 0 then
				RemoveCargo(sellercontainer, entry[3], entry[2])
			end
		end
		local success = true
		local playerMoney = GetPlayerMoney()
		if playerMoney >= RoundTotalTradePrice(menu.cost) then
			TransferPlayerMoneyTo(RoundTotalTradePrice(menu.cost), menu.architect)
		else
			success = false
		end
		if menu.upgradesonly then
			if menu.upgradeplan then
				Helper.closeMenuForSubSection(menu, false, "cArch_upgrade", { menu.component, menu.sequence, menu.stage, {}, menu.upgradeplan, menu.buildlimit, menu.droneplan, RoundTotalTradePrice(menu.cost)})
			elseif next(menu.droneplan) then
				Helper.closeMenuForSubSection(menu, false, "cArch_drones", { menu.component, menu.droneplan, RoundTotalTradePrice(menu.cost)})
			elseif next(menu.ammoplan) then
				Helper.closeMenuForSubSection(menu, false, "cArch_ammo", { menu.component, menu.ammoplan, RoundTotalTradePrice(menu.cost)})
			end
		elseif menu.targethullfraction then
			Helper.closeMenuForSubSection(menu, false, "cArch_repair", { menu.component, menu.sequence, menu.stage, menu.targethullfraction, menu.buildlimit, RoundTotalTradePrice(menu.cost) })
		else
			Helper.closeMenuForSection(menu, false, "cArch_buildstation", { menu.macro, success, menu.buildplan, menu.upgradeplan, menu.droneplan, RoundTotalTradePrice(menu.cost) })
		end
	else
		if menu.upgradesonly then
			if menu.upgradeplan then
				Helper.closeMenuForSubSection(menu, false, "cArch_upgrade", { menu.component, menu.sequence, menu.stage, {}, menu.upgradeplan, menu.buildlimit})
			elseif next(menu.droneplan) then
				Helper.closeMenuForSubSection(menu, false, "cArch_drones", { menu.component, menu.droneplan})
			elseif next(menu.ammoplan) then
				Helper.closeMenuForSubSection(menu, false, "cArch_ammo", { menu.component, menu.ammoplan})
			end
		elseif menu.targethullfraction then
			Helper.closeMenuForSubSection(menu, false, "cArch_repair", { menu.component, menu.sequence, menu.stage, menu.targethullfraction, menu.buildlimit })
		elseif menu.sequence == "" and menu.stage == 0 then
			Helper.closeMenuForSection(menu, false, "cArch_buildermacrosResult", { menu.macro, menu.buildplan, menu.upgradeplan })
		else
			Helper.closeMenuForSection(menu, false, "cArch_buildtreeResult", { menu.buildplan, menu.upgradeplan })
		end
	end
	menu.cleanup()
end

function menu.buttonEncyclopedia(ware)
	Helper.closeMenuForSubSection(menu, false, "gEncyclopedia_ware", { 0, 0, "wares", ware })
	menu.cleanup()
end

function menu.onShowMenu()
	DebugError("show menu_buildcost")
	menu.architect = menu.param[3]
	menu.buildership = menu.param[4]
	menu.component = menu.param[5]
	menu.macro = menu.param[6]
	if menu.macro == GetPlayerPrimaryShipMacro() then
		DebugError("IMPORTANT - Tell Florian immediately. menu_buildcost.lua was called with the playership, should not happen. BuildModule: " .. GetComponentData(menu.buildership, "name"))
	end
	menu.sequence = menu.param[7]
	menu.stage = menu.param[8]
	menu.upgradeplan = menu.param[9]
	menu.buildlimit = menu.param[10] ~= 0
	menu.targethullfraction = menu.param[11] ~= 0 and menu.param[11] or nil
	menu.upgradesonly = menu.param[12] ~= 0 and menu.param[12] or false
	menu.droneplan = menu.param[13] or {}
	menu.ammoplan = menu.param[14] or {}
	if menu.sequence == nil then
		menu.current = true
		menu.sequence, menu.stage, _, menu.upgradeplan = GetCurrentBuildSlot(menu.component)
	end

	menu.shipbuilding = false
	if GetComponentData(menu.architect, "typestring") == "shiptrader" then
		menu.shipbuilding = true
	end

	local playerMoney = GetPlayerMoney()

	local title = string.format(ReadText(1001, 3600), (menu.component and GetComponentData(menu.component, "name") or GetMacroData(menu.macro, "name")))

	local setup = Helper.createTableSetup(menu)
	local name, typestring, typeicon, typename, ownericon = GetComponentData(menu.architect, "name", "typestring", "typeicon", "typename", "ownericon")
	setup:addTitleRow({
		Helper.createIcon(typeicon, false, 255, 255, 255, 100, 0, 0, Helper.headerCharacterIconSize, Helper.headerCharacterIconSize),
		Helper.createFontString(typename .. " " .. name, false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize),
		Helper.createIcon(ownericon, false, 255, 255, 255, 100, 0, 0, Helper.headerCharacterIconSize, Helper.headerCharacterIconSize)	-- text depends on selection
	}, nil, {2, 4, 1})
	setup:addTitleRow({ 
		Helper.createFontString(title, false, "left", 129, 160, 182, 100, Helper.headerRow2Font, Helper.headerRow2FontSize, false, Helper.headerRow2Offsetx, Helper.headerRow2Offsety, Helper.headerRow2Height, Helper.headerRow1Width)	-- text depends on selection
	}, nil , {7})

	setup:addHeaderRow({ 
		Helper.getEmptyCellDescriptor(),
		ReadText(1001, 2809),
		Helper.createFontString(ReadText(1001, 1400), false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, menu.shipbuilding and ReadText(1026, 1828) or ReadText(1026, 1807)),
		menu.current and ReadText(1001, 3603) or Helper.createFontString(ReadText(1001, 3605), false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, menu.shipbuilding and ReadText(1026, 1827) or ReadText(1026, 1808)),
		menu.current and ReadText(1001, 3604) or (Helper.createFontString(menu.shipbuilding and ReadText(1001, 2808) or ReadText(1001, 3601), false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, menu.shipbuilding and ReadText(1026, 1840) or ReadText(1026, 1809)))
	}, nil, {1, 2, 1, 1, 2})

	menu.buildplan = {
		{ menu.sequence, menu.stage }
	} 
	menu.cost = 0

	local resources
	if menu.current then
		resources = GetCurrentBuildSlotResources(menu.buildership)
	elseif menu.targethullfraction then
		resources = GetRepairResources(menu.buildership, menu.component, menu.sequence, menu.stage, menu.buildlimit, menu.targethullfraction)
	else
		if menu.upgradeplan then
			if menu.upgradesonly then
				resources = GetUpgradesResources(menu.buildership, menu.component, menu.sequence, menu.stage, menu.buildlimit, menu.upgradeplan)
			else
				resources = GetBuildSlotResources(menu.buildership, menu.macro, menu.sequence, menu.stage, menu.upgradeplan)
			end
		else
			if next(menu.droneplan) or next(menu.ammoplan) then
				resources = {}
			else
				resources = GetBuildSlotResources(menu.buildership, menu.macro, menu.sequence, menu.stage)
			end
		end
	end
	if next(resources) then
		table.sort(resources, function (a, b) return a.cycle > b.cycle end)
	end

	menu.neededresources = GetNeededBuildSlotResources(menu.buildership)

	local cargo = GetComponentData(GetContextByClass(menu.buildership, "container", true), "cargo")

	menu.hasentries = false

	for _, entry in ipairs(resources) do
		if entry.cycle > 0 then
			local icon, component = GetWareData(entry.ware, "icon", "component")
			local price = entry.price + (menu.shipbuilding and entry.price or 0)
			local color = menu.white
			if (not menu.current) and menu.shipbuilding and ((cargo[entry.ware] or 0) < entry.cycle) then
				color = menu.red
			end
			setup:addSimpleRow({ 
				Helper.createButton(nil, Helper.createButtonIcon(icon, nil, 255, 255, 255, 100), false, true, 0, 0, 0, 0, nil, nil, nil, ReadText(1026, 1806)),
				Helper.createFontString(entry.name, false, "left", color.r, color.g, color.b, color.a),
				Helper.createFontString(ConvertIntegerString(cargo[entry.ware] or 0, true, 0, true), false, "right", color.r, color.g, color.b, color.a),
				Helper.createFontString(ConvertIntegerString(entry.cycle, true, 0, true), false, "right", color.r, color.g, color.b, color.a),
				Helper.createFontString(menu.current and ConvertIntegerString(menu.getNeededResourceAmount(entry.ware), true, 0, false) or ConvertMoneyString(RoundTotalTradePrice(price), false, true, 5, true) .. " " .. ReadText(1001, 101), false, "right", color.r, color.g, color.b, color.a)
			}, nil, {1, 2, 1, 1, 2})
			AddKnownItem("wares", entry.ware)
			menu.hasentries = true
			if not menu.current then
				menu.cost = menu.cost + price
			end
		end
	end

	if next(menu.droneplan) then
		for _, entry in ipairs(menu.droneplan) do
			if entry[2] ~= 0 then
				local name = GetWareData(entry[3], "name")
				local price
				if entry[2] < 0 then
					price = entry[2] * GetContainerWarePrice(menu.buildership, entry[3], true) * 0.80
				else
					price = entry[2] * GetContainerWarePrice(menu.buildership, entry[3], false) * 1.00
				end
				local color = menu.white
				if (not menu.current) and menu.shipbuilding and ((cargo[entry[3]] or 0) < entry[2]) then
					color = menu.red
				end
				setup:addSimpleRow({ 
					Helper.createButton(nil, Helper.createButtonIcon(GetWareData(entry[3], "icon"), nil, 255, 255, 255, 100), false, true, 0, 0),
					Helper.createFontString(name, false, "left", color.r, color.g, color.b, color.a),
					Helper.createFontString(ConvertIntegerString(cargo[entry[3]] or 0, true, 0, true), false, "right", color.r, color.g, color.b, color.a),
					Helper.createFontString(ConvertIntegerString(entry[2], true, 0, true), false, "right", color.r, color.g, color.b, color.a),
					Helper.createFontString(ConvertMoneyString(RoundTotalTradePrice(price), false, true, 5, true) .. " " .. ReadText(1001, 101), false, "right", color.r, color.g, color.b, color.a)
				}, nil, {1, 2, 1, 1, 2})
				AddKnownItem("wares", entry[3])
				menu.hasentries = true
				menu.cost = menu.cost + price
			end
		end
	end

	if next(menu.ammoplan) then
		for _, entry in ipairs(menu.ammoplan) do
			if entry[2] ~= 0 then
				local name = GetWareData(entry[3], "name")
				local price
				if entry[2] < 0 then
					price = entry[2] * GetContainerWarePrice(menu.buildership, entry[3], true) * 0.80
				else
					price = entry[2] * GetContainerWarePrice(menu.buildership, entry[3], false) * 1.00
				end
				local color = menu.white
				if (not menu.current) and menu.shipbuilding and ((cargo[entry[3]] or 0) < entry[2]) then
					color = menu.red
				end
				setup:addSimpleRow({ 
					Helper.createButton(nil, Helper.createButtonIcon(GetWareData(entry[3], "icon"), nil, 255, 255, 255, 100), false, true, 0, 0),
					Helper.createFontString(name, false, "left", color.r, color.g, color.b, color.a),
					Helper.createFontString(ConvertIntegerString(cargo[entry[3]] or 0, true, 0, true), false, "right", color.r, color.g, color.b, color.a),
					Helper.createFontString(ConvertIntegerString(entry[2], true, 0, true), false, "right", color.r, color.g, color.b, color.a),
					Helper.createFontString(ConvertMoneyString(price, false, true, 5, true) .. " " .. ReadText(1001, 101), false, "right", color.r, color.g, color.b, color.a)
				}, nil, {1, 2, 1, 1, 2})
				AddKnownItem("wares", entry[3])
				menu.hasentries = true
				menu.cost = menu.cost + price
			end
		end
	end

	local infodesc = setup:createCustomWidthTable({ Helper.scaleX(Helper.standardButtonWidth), Helper.scaleX(Helper.headerCharacterIconSize - Helper.standardButtonWidth) - 5, Helper.scaleX(menu.current and 350 or 400), Helper.scaleX(menu.current and 150 or 100), Helper.scaleX(menu.current and 150 or 100), 0, Helper.scaleX(Helper.headerCharacterIconSize) + 37}, false, true, true, 1, 3, 0, 0, Helper.scaleY(menu.shipbuilding and 410 or 500))
	
	local selectdesc, buttondesc
	if not menu.current then
		setup = Helper.createTableSetup(menu)
		
		local emptyFontStringSmall = Helper.createFontString("", false, Helper.standardHalignment, Helper.standardColor.r, Helper.standardColor.g, Helper.standardColor.b, Helper.standardColor.a, Helper.standardFont, 6, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, 6)

		setup:addHeaderRow({ emptyFontStringSmall }, nil, {4})
		setup:addTitleRow({ 
			Helper.getEmptyCellDescriptor(),
			Helper.createFontString((menu.shipbuilding and ReadText(1001, 2927) or ReadText(1001, 3602)), false, "left", 255, 255, 255, 100, Helper.standardFontBold, nil, nil, nil, nil, nil, nil, menu.shipbuilding and ReadText(1026, 1829) or ReadText(1026, 1810)),
			Helper.getEmptyCellDescriptor(),
			Helper.createFontString(ConvertMoneyString(menu.cost, false, true, 5, true) .. " " .. ReadText(1001, 101), false, "right", 255, 255, 255, 100, Helper.standardFontBold)
		}, nil, nil, nil, Helper.defaultSimpleBackgroundColor)
		if menu.shipbuilding then
			setup:addHeaderRow({ emptyFontStringSmall }, nil, {4})

			setup:addTitleRow({ 
				Helper.getEmptyCellDescriptor(), 
				Helper.createFontString(ReadText(1001, 2003), false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, ReadText(1026, 1830)), 
				Helper.getEmptyCellDescriptor(), 
				Helper.createFontString(ConvertMoneyString(playerMoney, false, true, 5, true) .. " " .. ReadText(1001, 101), false, "right")
			}, nil, nil, nil, Helper.defaultSimpleBackgroundColor)

			local color = menu.white
			if RoundTotalTradePrice(menu.cost) > 0 then
				color = menu.red
			else
				color = menu.green
			end
			setup:addTitleRow({ 
				Helper.getEmptyCellDescriptor(), 
				ReadText(1001, 2005), 
				Helper.getEmptyCellDescriptor(), 
				Helper.createFontString(ConvertMoneyString(-RoundTotalTradePrice(menu.cost), false, true, 5, true) .. " " .. ReadText(1001, 101), false, "right", color.r, color.g, color.b, color.a)
			}, nil, nil, nil, Helper.defaultSimpleBackgroundColor)

			if playerMoney < RoundTotalTradePrice(menu.cost) then
				color = menu.red
			else
				color = menu.white
			end
			setup:addTitleRow({ 
				Helper.getEmptyCellDescriptor(), 
				Helper.createFontString(ReadText(1001, 2004), false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, ReadText(1026, 1831)), 
				Helper.getEmptyCellDescriptor(), 
				Helper.createFontString(ConvertMoneyString(playerMoney - RoundTotalTradePrice(menu.cost), false, true, 5, true) .. " " .. ReadText(1001, 101), false, "right", color.r, color.g, color.b, color.a)
			}, nil, nil, nil, Helper.defaultSimpleBackgroundColor)
		end

		selectdesc = setup:createCustomWidthTable({Helper.standardButtonWidth, 500 + Helper.headerCharacterIconSize - Helper.standardButtonWidth, 100, 0}, false, false, true, 0, 0, 0, menu.shipbuilding and 415 or 505)

		setup = Helper.createTableSetup(menu)
		menu.isokbuttonenabled = menu.hasentries and (not menu.shipbuilding or playerMoney >= RoundTotalTradePrice(menu.cost))
		setup:addSimpleRow({ 
			Helper.getEmptyCellDescriptor(),
			Helper.createButton(Helper.createButtonText(ReadText(1001, 2669), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_B", true), nil, ReadText(1026, 1805)),
			Helper.getEmptyCellDescriptor(),
			Helper.getEmptyCellDescriptor(),
			Helper.getEmptyCellDescriptor(),
			Helper.getEmptyCellDescriptor(),
			Helper.getEmptyCellDescriptor(),
			Helper.createButton(Helper.createButtonText(ReadText(1001, 14), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, menu.isokbuttonenabled, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_A", true), nil, menu.shipbuilding and ReadText(1026, 1812) or ReadText(1026, 1811)),
			Helper.getEmptyCellDescriptor()
		})
		buttondesc = setup:createCustomWidthTable({48, 150, 48, 150, 0, 150, 48, 150, 48}, false, false, false, 2, 1, 0, 550)
	end

	-- create tableview
	if menu.current then
		menu.infotable = Helper.displayTableView(menu, infodesc, false)
	else
		menu.infotable, menu.selecttable, menu.buttontable = Helper.displayThreeTableView(menu, infodesc, selectdesc, buttondesc, false)
	end

	-- set button scripts
	local nooflines = 4
	for i, entry in ipairs(resources) do
		if entry.cycle > 0 then
			Helper.setButtonScript(menu, nil, menu.infotable, nooflines, 1, function () return menu.buttonEncyclopedia(entry.ware) end)
			nooflines = nooflines + 1
		end
	end
	if next(menu.droneplan) then
		for i, entry in ipairs(menu.droneplan) do
			if entry[2] ~= 0 then
				Helper.setButtonScript(menu, nil, menu.infotable, nooflines, 1, function () return menu.buttonEncyclopedia(entry[3]) end)
				nooflines = nooflines + 1
			end
		end
	end
	if not menu.current then
		Helper.setButtonScript(menu, nil, menu.buttontable, 1, 2, function () return menu.onCloseElement("back") end)
		Helper.setButtonScript(menu, nil, menu.buttontable, 1, 8, menu.buttonOK)
	end

	-- clear descriptors again
	Helper.releaseDescriptors()
end

menu.updateInterval = 1.0

function menu.onUpdate()
	local currentplayermoney = GetPlayerMoney()
	if not menu.current then
		if menu.shipbuilding then
			Helper.updateCellText(menu.selecttable, 4, 4, ConvertMoneyString(currentplayermoney, false, true, 5, true) .. " " .. ReadText(1001, 101))
			local color
			if currentplayermoney < RoundTotalTradePrice(menu.cost) then
				color = menu.red
			else
				color = menu.white
			end
			Helper.updateCellText(menu.selecttable, 6, 4, ConvertMoneyString(currentplayermoney - RoundTotalTradePrice(menu.cost), false, true, 5, true) .. " " .. ReadText(1001, 101), color)
		end
		if menu.hasentries then
			local isokbuttonenabled = (not menu.shipbuilding) or (currentplayermoney >= RoundTotalTradePrice(menu.cost))
			if menu.isokbuttonenabled ~= isokbuttonenabled then
				menu.isokbuttonenabled = isokbuttonenabled
				Helper.removeButtonScripts(menu, menu.buttontable, 1, 8)
				SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(1001, 14), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, menu.isokbuttonenabled, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_A", true)), 1, 8)
				Helper.setButtonScript(menu, nil, menu.buttontable, 1, 8, menu.buttonOK)
			end
		end
	end
end

function menu.onRowChanged(row, rowdata)
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

function menu.getNeededResourceAmount(resource)
	for _, neededresource in ipairs(menu.neededresources) do
		if resource == neededresource.ware then
			return neededresource.cycle
		end
	end
	return 0
end

init()
