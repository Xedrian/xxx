-- section == gMain_objectProduction
-- param == { 0, 0, object, productionmodule }

local menu = {}
local override = {
	transparent = { r = 0, g = 0, b = 0, a = 0 }
}

function menu.cleanup()
	menu.title = nil
	menu.object = nil
	menu.container = nil
	menu.module = nil
	menu.category = nil
	menu.proddata = {}
	menu.unlocked = {}
	menu.zoneowner = nil
	menu.owner = nil

	menu.infotable = nil
	menu.selecttable = nil
	menu.buttontable = nil
end

-- Menu member functions

--[[function menu.buttonShipEncyclopedia()
	Helper.closeMenuForSubSection(menu, false, "gEncyclopedia_object", { 0, 0, menu.category, GetComponentData(menu.object, "macro"), menu.category == "stationtypes" })
	menu.cleanup()
end

function menu.buttonEncyclopedia(type, id)
	if type == "ware" then
		Helper.closeMenuForSubSection(menu, false, "gEncyclopedia_ware", { 0, 0, "wares", id })
		menu.cleanup()
	elseif type == "moduletypes_efficiency" or type == "moduletypes_production" then
		Helper.closeMenuForSubSection(menu, false, "gEncyclopedia_object", { 0, 0, type, id, false })
		menu.cleanup()
	end
end]]

function override.onShowMenu()
	menu.object = menu.param[3]
	menu.module = menu.param[4]
	menu.unlocked = {}

	menu.container = GetContextByClass(menu.object, "container", false)
	local name = GetComponentData(menu.object, "name")
	if menu.container then
		menu.title = GetComponentData(menu.container, "name") .. " - " .. (name ~= "" and name or ReadText(1001, 56))
	else
		menu.title = (name ~= "" and name or ReadText(1001, 56)) .. " - " .. GetComponentData(menu.module, "name")
	end

	menu.owner = GetComponentData(menu.object, "owner")
	local zone = GetComponentData(menu.object, "zoneid")
	menu.zoneowner = GetComponentData(zone, "owner")
	local zoneownername = GetComponentData(zone, "ownername")

	if IsComponentClass(menu.object, "station") then
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

	local setup = Helper.createTableSetup(menu)
	setup:addSimpleRow({
		Helper.createButton(nil, Helper.createButtonIcon("menu_info", nil, 255, 255, 255, 100), false, nil, nil, nil, nil, nil, nil, nil, nil, ReadText(1026, 2300)),
		Helper.createFontString(menu.title .. (menu.owner == "player" and "" or " (" .. GetComponentData(menu.object, "revealpercent") .. " %)"), false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, Helper.headerRow1Height, Helper.headerRow1Width)
	}, nil, { 1, 1 }, false, Helper.defaultTitleBackgroundColor)
	setup:addTitleRow({
		Helper.createFontString(menu.zoneowner and string.format(ReadText(1001, 72), zoneownername) or "", false, "left", 129, 160, 182, 100, Helper.headerRow2Font, Helper.headerRow2FontSize, false, Helper.headerRow2Offsetx, Helper.headerRow2Offsety, Helper.headerRow2Height, Helper.headerRow1Width) -- text depends on selection
	}, nil, { 2 })
	local infodesc = setup:createCustomWidthTable({ Helper.headerRow1Height, 0 }, false, false, true, 3, 1)

	setup = Helper.createTableSetup(menu)
	--[[ GetProductionModuleData() return value = {
		state = "ProductionState",
		cycletime = CycleTime (only if state == "producing", otherwise 0),
		cycleefficiency = cycle efficiency percentage (100% default),
		remainingcycletime = Time remaining for this cycle (only if state == "producing", otherwise 0),
		cycleprogress = percentage of current cycle progress (only if state = "producing", otherwise 0),
		remainingtime = time until out of resources (does not take limited storage space into account),
		products = {
			efficiency = product efficiency percentage (100% default),
			[1] = { ware = "wareid", name = "Ware Name", amount = storageamount, cycle = cycleamount },
			[2] = ...
		},
		presources = { ... },    -- primary resources, analogous to products table
		sresources = { ... },    -- secondary resources, analogous to products table
	} ]]
	menu.proddata = GetProductionModuleData(menu.module)
	menu.unlocked.production_products = IsInfoUnlockedForPlayer(menu.module, "production_products")
	menu.unlocked.production_resources = IsInfoUnlockedForPlayer(menu.module, "production_resources")
	menu.unlocked.production_rate = IsInfoUnlockedForPlayer(menu.module, "production_rate")
	menu.unlocked.consumption_rate = IsInfoUnlockedForPlayer(menu.module, "consumption_rate")
	menu.unlocked.production_time = IsInfoUnlockedForPlayer(menu.module, "production_time")
	menu.unlocked.efficiency_type = IsInfoUnlockedForPlayer(menu.module, "efficiency_type")
	menu.unlocked.efficiency_amount = IsInfoUnlockedForPlayer(menu.module, "efficiency_amount")

	if menu.proddata.productionmethod then
		AddKnownItem("productionmethods", menu.proddata.productionmethod)
	end

	if menu.proddata.state == "empty" then
		setup:addSimpleRow({ ReadText(1001, 1601) })
	else
		setup:addHeaderRow({
			ReadText(1001, 1600),
			ReadText(1001, 24)
		}, nil, { 3, 1 })
		if menu.proddata.state == "noresources" then
			setup:addSimpleRow({
				Helper.unlockInfo(menu.unlocked.production_time, Helper.createFontString(ReadText(1001, 1604), false, "left", 255, 0, 0, 100))
			}, nil, { 3, 1 })
		elseif menu.proddata.state == "nostorage" then
			setup:addSimpleRow({
				Helper.unlockInfo(menu.unlocked.production_time, Helper.createFontString(ReadText(1001, 1605), false, "left", 255, 0, 0, 100))
			}, nil, { 3, 1 })
		elseif menu.proddata.state ~= "producing" then
			setup:addSimpleRow({
				Helper.unlockInfo(menu.unlocked.production_time, ReadText(1001, 1606))
			}, nil, { 4 })
		else
			setup:addSimpleRow({
				Helper.createFontString(string.format("%s (%s %%)", ReadText(1001, 1607), Helper.unlockInfo(menu.unlocked.production_time, math.floor(menu.proddata.cycleprogress))), false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, ReadText(1026, 2301)),
				Helper.createFontString(Helper.unlockInfo(menu.unlocked.production_time, ConvertTimeString(menu.proddata.remainingcycletime, "%h" .. ReadText(1001, 102) .. " %M" .. ReadText(1001, 103) .. " %S" .. ReadText(1001, 100))), false, "right", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, ReadText(1026, 2302))
			}, nil, { 3, 1 })
		end
		if menu.proddata.state == "producing" and menu.proddata.remainingtime == 0 then
			local timestring = "4.2 " .. ReadText(1001, 112)
			local clustermacro = GetComponentData(GetComponentData(menu.object, "clusterid"), "macro")
			if clustermacro == "cluster_a_macro" then
				-- Maelstrom
				timestring = "0.9 " .. ReadText(1001, 112)
			elseif clustermacro == "cluster_b_macro" then
				-- Albion
				timestring = "4.2 " .. ReadText(1001, 112)
			elseif clustermacro == "cluster_c_macro" then
				-- Omycron Lyrae
				timestring = "3.7 " .. ReadText(1001, 112)
			elseif clustermacro == "cluster_d_macro" then
				-- DeVries
				timestring = "11.4 " .. ReadText(1001, 112)
			end
			setup:addSimpleRow({
				Helper.createFontString(ReadText(1001, 1608), false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, ReadText(1026, 2303)),
				Helper.createFontString(Helper.unlockInfo(menu.unlocked.production_time, timestring), false, "right")
			}, nil, { 3, 1 })
		else
			setup:addSimpleRow({
				Helper.createFontString(ReadText(1001, 1608), false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, ReadText(1026, 2303)),
				Helper.createFontString(Helper.unlockInfo(menu.unlocked.production_time, ConvertTimeString(menu.proddata.remainingtime, "%h" .. ReadText(1001, 102) .. " %M" .. ReadText(1001, 103) .. " %S" .. ReadText(1001, 100))), false, "right")
			}, nil, { 3, 1 })
		end

		menu.addWares(setup, menu.proddata.products, ReadText(1001, 1610), 1)
		menu.addWares(setup, menu.proddata.presources, ReadText(1001, 1611), -1)
		menu.addWares(setup, menu.proddata.sresources, ReadText(1001, 1612), -1)

		menu.onShowMenuHookAddRows(setup)

		local name, hullpercent, threshold, efffactor, effbonus = GetComponentData(menu.module, "name", "hullpercent", "efficiencythreshold", "efficiencyfactor", "efficiencybonus")
		local infobutton = Helper.createButton(nil, Helper.createButtonIcon("menu_info", nil, 255, 255, 255, 100), false, menu.unlocked.efficiency_type)
		menu.proddata.efficiencyupgrades = GetEfficiencyUpgrades(menu.module)

		menu.addEfficiencyEntries(setup, "product", name, hullpercent, threshold, efffactor, effbonus)
		--menu.addEfficiencyEntries(setup, "primary", name, hullpercent, threshold, efffactor, effbonus)
		--menu.addEfficiencyEntries(setup, "cycle", name, hullpercent, threshold, efffactor, effbonus)
	end

	setup:addFillRows(10)

	local selectdesc = setup:createCustomWidthTable({ Helper.standardTextHeight, 0, 176, 176 }, false, false, true, 1, 0, 0, Helper.tableOffsety, 460 )
	-- create tableview
	menu.infotable, menu.selecttable, menu.buttontable = Helper.displayThreeTableView(menu, infodesc, selectdesc, menu.createTableButton(), false)

	-- set button scripts
	Helper.setButtonScript(menu, nil, menu.infotable, 1, 1, menu.buttonShipEncyclopedia)
	local nooflines = 4
	if menu.proddata.state ~= "empty" then
		nooflines = menu.addWareButtons(menu.proddata.products, nooflines)
		nooflines = menu.addWareButtons(menu.proddata.presources, nooflines)
		nooflines = menu.addWareButtons(menu.proddata.sresources, nooflines)
		nooflines = menu.onShowMenuHookAddButtonScripts(nooflines) -- hook for adding buttons scripts
	end

	menu.addButtonScriptsButtonTable()

	-- clear descriptors again
	Helper.releaseDescriptors()
end

function override.onShowMenuHookAddRows(setup)
	return
end

function override.onShowMenuHookAddButtonScripts(nooflines)
	return nooflines
end

function override.createTableButton()
	local setup = Helper.createTableSetup(menu)
	setup:addSimpleRow({
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 2669), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_B", true)),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor()
	}, nil, nil, false, menu.transparent)
	return setup:createCustomWidthTable({ 48, 150, 48, 150, 0, 150, 48, 150, 48 }, false, false, true, 2, 1, 0, 555, 0, false)
end

function override.addButtonScriptsButtonTable()
	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 2, function()
		return menu.onCloseElement("back")
	end)
end

function override.addWares(setup, waretable, title, usage)
	setup:addHeaderRow({
	-- Helper.createIcon("menu_info", false, 255, 255, 255, 100, 0, 0, Helper.standardTextHeight, Helper.standardButtonWidth),
		title,
		Helper.createFontString(ReadText(1001, 20) .. " / " .. ReadText(1001, 1127), false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, ReadText(1026, 2305)),
		Helper.createFontString((usage > 0 and ReadText(1001, 1600) or ReadText(1001, 1609)) .. " / " .. ReadText(1001, 102), false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, usage > 0 and ReadText(1026, 2306) or ReadText(1026, 2307))
	}, nil, { 2, 1, 1 })
	if #waretable == 0 then
		setup:addSimpleRow({
			Helper.getEmptyCellDescriptor(),
			"-- " .. ReadText(1001, 32) .. " --"
		})
	else
		for _, ware in ipairs(waretable) do
			local color = menu.white
			if menu.zoneowner and IsWareIllegalTo(ware.ware, menu.owner, menu.zoneowner) then
				color = menu.orange
			end
			local active = usage > 0 and menu.unlocked.production_products or menu.unlocked.production_resources
			setup:addSimpleRow({
				Helper.createButton(nil, Helper.createButtonIcon(GetWareData(ware.ware, "icon"), nil, 255, 255, 255, 100), false, active, nil, nil, nil, nil, nil, nil, nil, ReadText(1026, 2304)),
				Helper.unlockInfo(usage > 0 and menu.unlocked.production_products or menu.unlocked.production_resources, Helper.createFontString(ware.name, false, "left", color.r, color.g, color.b, color.a)),
				Helper.createFontString(Helper.estimateString(menu.proddata.estimated) .. ConvertIntegerString(ware.amount, true, 4, true) .. " / " .. ConvertIntegerString(GetWareProductionLimit(menu.container or menu.object, ware.ware), true, 4, true), false, "right"),
				Helper.createFontString(Helper.unlockInfo(usage > 0 and menu.unlocked.production_rate or menu.unlocked.consumption_rate, ConvertIntegerString(usage * ware.cycle * 3600 / menu.proddata.cycletime, true, 4, true)), false, "right")
			})
			AddKnownItem("wares", ware.ware)
		end
	end
end

function override.addWareButtons(waretable, nooflines)
	nooflines = nooflines + 1
	if #waretable == 0 then
		nooflines = nooflines + 1
	else
		for _, ware in ipairs(waretable) do
			Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
				return menu.buttonEncyclopedia("ware", ware.ware)
			end)
			nooflines = nooflines + 1
		end
	end

	return nooflines
end

local function init()
	for _, existingMenu in ipairs(Menus) do
		if existingMenu.name == "ProductionMenu" then
			menu = existingMenu
			for k, v in pairs(override) do
				menu[k] = v
			end
			break
		end
	end
end

init()