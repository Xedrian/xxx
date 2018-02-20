
-- section == gMain_objectProduction
-- param == { 0, 0, object, productionmodule }

local menu = {
	name = "Station_Production",
	white = { r = 255, g = 255, b = 255, a = 100 },
	orange = { r = 255, g = 192, b = 0, a = 100 },
	red = { r = 255, g = 0, b = 0, a = 100 }
}

local function init()
	Menus = Menus or { }
	table.insert(Menus, menu)
	if Helper then
		Helper.registerMenu(menu)
	end
	RegisterEvent("St_Prod_RemainingCycletime", menu.St_Prod_RemainingCycletime)
	RegisterEvent("St_Prod_Player", menu.St_Prod_Player)
end

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
end

-- Menu member functions

function menu.buttonShipEncyclopedia()
	Helper.closeMenuForSubSection(menu, false, "gEncyclopedia_object", { 0, 0, menu.category, GetComponentData(menu.object, "macro"), menu.category == "stationtypes" })
	menu.cleanup()
end

function menu.buttonEncyclopedia(type, id)
	local version = tonumber(string.sub(GetVersionString(), string.find(GetVersionString(), '(',1,true) + 1, string.find(GetVersionString(), '(',1,true) + 6)) or 208022
	if type == "ware" then
		if version < 208022 then -- compensate for gEncyclopedia_ware parameter change
			Helper.closeMenuForSubSection(menu, false, "gEncyclopedia_ware", { 0, 0, id })
		else
			Helper.closeMenuForSubSection(menu, false, "gEncyclopedia_ware", { 0, 0, "wares", id })
		end
		menu.cleanup()
	elseif type == "moduletypes_efficiency" or type == "moduletypes_production" then
		Helper.closeMenuForSubSection(menu, false, "gEncyclopedia_object", { 0, 0, type, id, false })
		menu.cleanup()
	end
end

function menu.buttonConfigBrake(type, ware, prodmethod)
	if type == "ware" then
		Helper.closeMenuForSubSection(menu, false, "gMain_Station_Prod_Slider", { 0, 0, prodmethod, ware, menu.module })
		menu.cleanup()
	end
end 

function menu.onShowMenu()
	menu.object = menu.param[3]
	menu.module = menu.param[4]
	menu.unlocked = {}

	-- if player off ship then can't get player object
	local version = tonumber(string.sub(GetVersionString(), string.find(GetVersionString(), '(',1,true) + 1, string.find(GetVersionString(), '(',1,true) + 6)) or 208022
	local playership = GetPlayerPrimaryShipID()
    if playership then 
		local player = GetComponentData(playership, "controlentity")
		if not player then -- ask md script to send player to menu.St_Prod_Player which sets menu.player
			if version < 208022 then -- compensate for AddUITriggeredEvent parameter change
				AddUITriggeredEvent("St_Prod_GetPlayer", "")
			else
				AddUITriggeredEvent("St_Prod_GetPlayer", "none", "")
			end
		end
	else
		if version < 208022 then -- compensate for AddUITriggeredEvent parameter change
			AddUITriggeredEvent("St_Prod_GetPlayer", "")
		else
			AddUITriggeredEvent("St_Prod_GetPlayer", "none", "")
		end
	end

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
		Helper.createButton(nil, Helper.createButtonIcon("menu_info", nil, 255, 255, 255, 100), false),
		Helper.createFontString(menu.title .. (menu.owner == "player" and "" or " (" .. GetComponentData(menu.object, "revealpercent") .. " %)"), false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, Helper.headerRow1Height, Helper.headerRow1Width)
	}, nil, {1, 1}, false, Helper.defaultTitleBackgroundColor)
	setup:addTitleRow({ 
		Helper.createFontString(menu.zoneowner and string.format(ReadText(1001, 72), zoneownername) or "", false, "left", 129, 160, 182, 100, Helper.headerRow2Font, Helper.headerRow2FontSize, false, Helper.headerRow2Offsetx, Helper.headerRow2Offsety, Helper.headerRow2Height, Helper.headerRow1Width)	-- text depends on selection
	}, nil, {2})
	local infodesc = setup:createCustomWidthTable({Helper.headerRow1Height, 0}, false, false, true, 2, 1)

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
		}, nil, {3, 1})
		if menu.proddata.state == "noresources" then
			setup:addSimpleRow({ 
				Helper.unlockInfo(menu.unlocked.production_time, Helper.createFontString(ReadText(1001, 1604), false, "left", 255, 0, 0, 100)) 
			}, nil, {3, 1})
		elseif menu.proddata.state == "nostorage" then
			setup:addSimpleRow({ 
				Helper.unlockInfo(menu.unlocked.production_time, Helper.createFontString(ReadText(1001, 1605), false, "left", 255, 0, 0, 100)) 
			}, nil, {3, 1})
		elseif menu.proddata.state ~= "producing" then
			setup:addSimpleRow({ 
				Helper.unlockInfo(menu.unlocked.production_time, ReadText(1001, 1606)) 
			}, nil, {4})
		else
			setup:addSimpleRow({ 
				string.format("%s (%s %%)", ReadText(1001, 1607), Helper.unlockInfo(menu.unlocked.production_time, math.floor(menu.proddata.cycleprogress))), 
				Helper.createFontString(Helper.unlockInfo(menu.unlocked.production_time, ConvertTimeString(menu.proddata.remainingcycletime, "%h" .. ReadText(1001, 102) .. " %M" .. ReadText(1001, 103) .. " %S" .. ReadText(1001, 100))), false, "right") 
			}, nil, {3, 1})
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
				ReadText(1001, 1608), 
				Helper.createFontString(Helper.unlockInfo(menu.unlocked.production_time, timestring), false, "right") 
			}, nil, {3, 1})
		else
			setup:addSimpleRow({ 
				ReadText(1001, 1608), 
				Helper.createFontString(Helper.unlockInfo(menu.unlocked.production_time, ConvertTimeString(menu.proddata.remainingtime , "%h" .. ReadText(1001, 102) .. " %M" .. ReadText(1001, 103) .. " %S" .. ReadText(1001, 100))), false, "right") 
			}, nil, {3, 1})
		end

		menu.addWares(setup, menu.proddata.products, ReadText(1001, 1610), 1)
		menu.addWares(setup, menu.proddata.presources, ReadText(1001, 1611), -1)
		menu.addWares(setup, menu.proddata.sresources, ReadText(1001, 1612), -1)

		if menu.owner == "player" then 
			menu.addProdLimit(setup, menu.module)
		end
		
		local name, hullpercent, threshold, efffactor, effbonus = GetComponentData(menu.module, "name", "hullpercent", "efficiencythreshold", "efficiencyfactor", "efficiencybonus")
		local infobutton = Helper.createButton(nil, Helper.createButtonIcon("menu_info", nil, 255, 255, 255, 100), false, menu.unlocked.efficiency_type)
		menu.proddata.efficiencyupgrades = GetEfficiencyUpgrades(menu.module)

		menu.addEfficiencyEntries(setup, "product", name, hullpercent, threshold, efffactor, effbonus)
		--menu.addEfficiencyEntries(setup, "primary", name, hullpercent, threshold, efffactor, effbonus)
		--menu.addEfficiencyEntries(setup, "cycle", name, hullpercent, threshold, efffactor, effbonus)
	end

	setup:addFillRows(17)

	local selectdesc = setup:createCustomWidthTable({ Helper.standardButtonWidth, 0, 176, 176 }, false, false, true, 1, 0, 0, Helper.tableOffsety)
	-- create tableview
	menu.infotable, menu.selecttable = Helper.displayTwoTableView(menu, infodesc, selectdesc, false)

	-- set button scripts
	Helper.setButtonScript(menu, nil, menu.infotable, 1, 1, menu.buttonShipEncyclopedia)
	local nooflines = 4
	if menu.proddata.state ~= "empty" then
		nooflines = menu.addWareButtons(menu.proddata.products, nooflines)
		nooflines = menu.addWareButtons(menu.proddata.presources, nooflines)
		nooflines = menu.addWareButtons(menu.proddata.sresources, nooflines)
		if menu.owner == "player" then 
			nooflines = menu.addProdLimitButtons(GetPossibleProducts(menu.module), nooflines)
		end
	end

	-- clear descriptors again
	Helper.releaseDescriptors()
end

menu.updateInterval = 0.2

function menu.St_Prod_UpdateModuleInfo(module, prodbrake)
	local station = GetComponentData(module,"parent")
	local manager
	if station then 
		manager = GetComponentData(station, "tradenpc")
	end

	if manager then -- must have a manager or nothing happens
		local proddata = GetProductionModuleData(module)
		
		-- get the global debug level from player BlackBoard
		local playership = GetPlayerPrimaryShipID()
		if playership then 
			local player = GetComponentData(playership, "controlentity")
			-- menu.remotelog("Playership is " .. tostring(playership) .. " player is " .. tostring(player))
			if player then 
				menu.player = player
			end
		end

		local globaldebug = 0
		if menu.player then 
			globaldebug = GetNPCBlackboard(menu.player, "$St_Prod_Data_Debug") or 0		
		end

		-- get the station debug level from manager BlackBoard
		local stationdebug = GetNPCBlackboard(manager, "$St_Prod_Data_Debug")		
		if not stationdebug or stationdebug == "" then
			stationdebug = 0
		end
		-- menu.remotelog("production_menu_st_prod Global: " .. tostring(globaldebug) .. " Station: " .. tostring(stationdebug))

		local effectivedebug = tonumber(globaldebug) -- effectivedebug is the higher of the two
		if tonumber(stationdebug) > tonumber(globaldebug) then
			effectivedebug = tonumber(stationdebug)
		end
	
		-- get build stage and sequence to use as unique key for this prod module
		local sequence, stage = GetComponentData(module, "sequence", "stage")
		if sequence and sequence == "" then 
			sequence = "a" 
		end
		local buildstage = "[" .. sequence .. "," .. stage .. "]"
		local moduid = sequence .. "_" .. stage .. "_" .. proddata.products[1]["ware"]

		-- get production data for this manager
		local mdproddata = GetNPCBlackboard(manager, "$St_Prod_Data") or {}		
		local skipmodule = false
		local prevremainingcycletime
		
		if mdproddata[moduid] then -- get prodbrake and debug from the BlackBoard
			local mdprodbrake = mdproddata[moduid][4]
			local mdprevremainingcycletime = mdproddata[moduid][9] -- take the previous remainingcycletime
			local mddebug = mdproddata[moduid][5] or 0
			if not prodbrake then
				prodbrake = tonumber(mdprodbrake)
			end
			prevremainingcycletime = tonumber(mdprevremainingcycletime)
		else
			prevremainingcycletime = -10
			if not prodbrake then -- do not add to BlackBoard unless prodbrake set (turret, urv or missile forge)
				skipmodule = true
				if effectivedebug > 1 then 
					menu.remotelog(GetComponentData(station, "name") .. " - " .. GetComponentData(module, "name") .. ". Skipping " .. proddata.products[1]["ware"] .. "s. Remaining " .. string.format("%1.2f", proddata.remainingcycletime) .. "s  - not limited.")
				end
			end		
		end
		
		if prodbrake and prodbrake == 0 then -- stop braking this module
			skipmodule = true
			menu.remotelog("Skipping " .. GetComponentData(station, "name") .. " " .. moduid .. " prodbrake removed")
		end
			
		local proddatakeys = {}
		-- pass production data for this module onto the manager
		local exportproddata = {GetCurTime(), sequence, stage, tonumber(prodbrake), mddebug ,proddata.state, proddata.cycletime, proddata.cycleefficiency, tonumber(proddata.remainingcycletime), prevremainingcycletime, proddata.products, proddata.presources, proddata.sresources}
		mdproddata[moduid] = exportproddata
		if skipmodule == false then -- update BlackBoard
			if effectivedebug > 0 then
				local zonename = GetComponentData(station, "zone") or "UnknownZone"
				menu.remotelog("Polling: " .. GetComponentData(station, "name") .. " - " .. tostring(zonename) .. " " .. moduid .. " rem_cycletime: " .. string.format("%4.3f", proddata.remainingcycletime) .. "s" .. " prevrem_cycletime: " .. string.format("%4.3f", prevremainingcycletime) .. "s")
			end
			SetNPCBlackboard(manager, "$St_Prod_Data", mdproddata)
			for k,v in pairs(mdproddata) do
				table.insert(proddatakeys, k)
			end
			SetNPCBlackboard(manager, "$St_Prod_DataKeys", proddatakeys) -- pass the keys to allow hash to be read in md script
		end
	else
		menu.remotelog("There is no Production Manager on " .. GetComponentData(menu.object, "name") .. " Cannot limit production" )	
	end
end

function menu.St_Prod_RemainingCycletime(eventname, module)
	-- menu.remotelog("Event: " .. eventname .. " , " .. GetComponentData(module, "name"))
	menu.St_Prod_UpdateModuleInfo(module)
end

function menu.St_Prod_Player(eventname, player)
	-- menu.remotelog("Player from md: " .. eventname .. " , " .. tostring(player))
	menu.player = player
end

function menu.onUpdate()
	local proddata = GetProductionModuleData(menu.module)
	if next(proddata) then
		if proddata.state == "producing" then
			if math.floor(menu.proddata.cycleprogress) ~= math.floor(proddata.cycleprogress) then
				menu.proddata.cycleprogress = proddata.cycleprogress
				if menu.unlocked.production_time then
					Helper.updateCellText(menu.selecttable, 2, 1, string.format("%s (%s %%)", ReadText(1001, 1607), math.floor(proddata.cycleprogress)))
				end
			end
			if math.floor(menu.proddata.remainingcycletime) ~= math.floor(proddata.remainingcycletime) then
				menu.proddata.remainingcycletime = proddata.remainingcycletime
				if menu.unlocked.production_time then
					Helper.updateCellText(menu.selecttable, 2, 4, ConvertTimeString(proddata.remainingcycletime, "%h" .. ReadText(1001, 102) .. " %M" .. ReadText(1001, 103) .. " %S" .. ReadText(1001, 100)))
				end
			end
			if math.floor(menu.proddata.remainingtime) ~= math.floor(proddata.remainingtime) then
				menu.proddata.remainingtime = proddata.remainingtime
				if menu.unlocked.production_time then
					Helper.updateCellText(menu.selecttable, 3, 4, ConvertTimeString(proddata.remainingtime, "%h" .. ReadText(1001, 102) .. " %M" .. ReadText(1001, 103) .. " %S" .. ReadText(1001, 100)))
				end
			end
			menu.updateWares(proddata.products, menu.proddata.products, 4, 1)
			menu.updateWares(proddata.presources, menu.proddata.presources, 5 + (#proddata.products > 0 and #proddata.products or 1), -1)
			menu.updateWares(proddata.sresources, menu.proddata.sresources, 6 + (#proddata.products > 0 and #proddata.products or 1) + (#proddata.presources > 0 and #proddata.presources or 1), -1)
		else
			if proddata.state == "noresources" then
				Helper.updateCellText(menu.selecttable, 2, 1, Helper.unlockInfo(menu.unlocked.production_time, Helper.createFontString(ReadText(1001, 1604), false, "left", 255, 0, 0, 100)))
			elseif proddata.state == "nostorage" then
				Helper.updateCellText(menu.selecttable, 2, 1, Helper.unlockInfo(menu.unlocked.production_time, Helper.createFontString(ReadText(1001, 1605), false, "left", 255, 0, 0, 100)))
			elseif proddata.state ~= "producing" then
				Helper.updateCellText(menu.selecttable, 2, 1, Helper.unlockInfo(menu.unlocked.production_time, ReadText(1001, 1606)))
			end
			Helper.updateCellText(menu.selecttable, 3, 1, ReadText(1001, 1608))
			Helper.updateCellText(menu.selecttable, 3, 4, Helper.unlockInfo(menu.unlocked.production_time, ConvertTimeString(proddata.remainingtime , "%h" .. ReadText(1001, 102) .. " %M" .. ReadText(1001, 103) .. " %S" .. ReadText(1001, 100))))
		end
	end
end

function menu.onRowChanged(row, rowdata)
end

function menu.onSelectElement()
end

function menu.onCloseElement(dueToClose)
	if menu.interactive then
		if dueToClose == "close" then
			Helper.closeMenuAndCancel(menu)
			menu.cleanup()
		else
			Helper.closeMenuAndReturn(menu)
			menu.cleanup()
		end
	else
		if dueToClose == "close" then
			Helper.closeNonInteractiveMenuAndCancel(menu)
			menu.cleanup()
		else
			Helper.closeNonInteractiveMenuAndReturn(menu)
			menu.cleanup()
		end
	end
end

function menu.getEfficiencyString(eff, inverted)
	if eff == 1.0 then
		return ReadText(1001, 18)
	end
	if inverted then
		if eff == 0.0 then		-- infinity? o_O
			return "+ oo"
		end
		eff = 1.0 / eff
	end
	local sign = eff < 1.0 and "-" or "+"
	return string.format("%s %d %%", sign, math.abs(eff - 1.0) * 100 + 0.5)
end

function menu.addProdLimit(setup, module)
	local station = GetComponentData(module,"parent") or nil
	-- get build stage and sequence to use as unique key for this prod module
	local sequence, stage = GetComponentData(module, "sequence", "stage")
	if sequence and sequence == "" then 
		sequence = "a" 
	end
	local manager = GetComponentData(station, "tradenpc")
	local mdproddata = GetNPCBlackboard(manager, "$St_Prod_Data")
	
	setup:addHeaderRow({ 
		Helper.getEmptyCellDescriptor(), 
		ReadText(360003, 1),
		ReadText(1001, 13)
	}, nil, {1, 2, 1})
--	if module and IsComponentClass(module, "production") then
--		AddKnownItem("moduletypes_production", GetComponentData(module, "macro"))
--	end
	local productionInfoTable = GetPossibleProducts(module)
	if (productionInfoTable and #productionInfoTable == 0) or not manager then
		if not manager then
			setup:addSimpleRow({ 
				Helper.getEmptyCellDescriptor(), 
				"\27R -- " .. ReadText(20208, 601) .. " " .. ReadText(1001, 3605) .. " -- \27X" 
			})
		else
			setup:addSimpleRow({ 
				Helper.getEmptyCellDescriptor(), 
				"-- " .. ReadText(1001, 32) .. " --" 
			})
		end
	else
		if productionInfoTable then 
			for _, ware in ipairs(productionInfoTable) do
				local prodmethod = GetWareData(ware.ware, "productionmethod")
				local fixedprodmethod = menu.getprodmethod(menu.module, prodmethod) -- correct prod method
				menu.remotelog(_ .. " " .. ware.ware .. " - " .. fixedprodmethod)
				AddKnownItem("productionmethods", fixedprodmethod) -- make sure that you know about this production method

				local color = menu.white
				if menu.zoneowner and IsWareIllegalTo(ware.ware, menu.owner, menu.zoneowner) then
					color = menu.orange
				end
		
				local moduid = sequence .. "_" .. stage .. "_" .. ware.ware
				local mdprodbrake
				if mdproddata and mdproddata[moduid] then -- get prodbrake from the BlackBoard
					mdprodbrake = menu.stringf(mdproddata[moduid][4] * 100 * -1)
					-- menu.remotelog("addProdLimit " .. GetComponentData(station,"name") .. " - " .. GetComponentData(module,"name") .. " prodbrake: " .. mdprodbrake .. "%") 
				end

				setup:addSimpleRow({ 
					Helper.createButton(nil, Helper.createButtonIcon("dock_repair_active", nil, 255, 255, 255, 100), false, menu.unlocked.production_resources), 
					Helper.unlockInfo(menu.unlocked.production_resources, Helper.createFontString(ware.name, false, "left", color.r, color.g, color.b, color.a)), 
					Helper.createFontString((mdprodbrake or 0) .. " %", false, "right")
				}, nil, {1, 2, 1})
				AddKnownItem("wares", ware.ware)
			end
		end
	end
end

function menu.getprodmethod(module, prodmethod) -- fudge the production method
	local macro = GetComponentData(module, "macro")
	local prod = "default"
	if macro then 
		if string.match(macro, "ol_macro$" ) then
			prod = "omicron"
		elseif string.match(macro, "dv_macro$" ) then
			prod = "devries"
		elseif string.match(macro, "xe_macro$" ) then
			prod = "xenon"
		end
	end
	--menu.remotelog("Prod module - " .. prod)

	local newprodmethod = string.gsub(prodmethod, "default", tostring(prod))
	local libentry = GetLibraryEntry("productionmethods", newprodmethod) or nil
	if libentry then -- use the race specific production method instead of default
		return newprodmethod
	else
		return prodmethod
	end
end

function menu.stringf(s)
	return string.format("%g", string.format("%1.2f", s))
end

function menu.remotelog(s)
	local version = tonumber(string.sub(GetVersionString(), string.find(GetVersionString(), '(',1,true) + 1, string.find(GetVersionString(), '(',1,true) + 6)) or 208022
	-- DebugError("remotelog " .. version .. " " .. tostring(s))
	if version < 208022 then -- compensate for AddUITriggeredEvent parameter change
		AddUITriggeredEvent("St_Prod_Logger", s)
	else
		AddUITriggeredEvent("St_Prod_Logger", "", s)
	end
end

function menu.addProdLimitButtons(productionInfoTable, nooflines)
	nooflines = nooflines + 1
	if #productionInfoTable == 0 then
		nooflines = nooflines + 1
	else
		for _, ware in ipairs(productionInfoTable) do
			local prodmethod = GetWareData(ware.ware, "productionmethod")
			local fixedprodmethod = menu.getprodmethod(menu.module, prodmethod) -- correct prod method

			Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function () return menu.buttonConfigBrake("ware", ware.name, fixedprodmethod) end)
			nooflines = nooflines + 1
		end
	end

	return nooflines
end

function menu.addWares(setup, waretable, title, usage)
	setup:addHeaderRow({ 
		Helper.createIcon("menu_info", false, 255, 255, 255, 100, 0, 0, Helper.standardTextHeight, Helper.standardButtonWidth), 
		title, 
		ReadText(1001, 20) .. " / " .. ReadText(1001, 1127), 
		(usage > 0 and ReadText(1001, 1600) or ReadText(1001, 1609)) .. " / " .. ReadText(1001, 102)
	})
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
			setup:addSimpleRow({ 
				Helper.createButton(nil, Helper.createButtonIcon(GetWareData(ware.ware, "icon"), nil, 255, 255, 255, 100), false, usage > 0 and menu.unlocked.production_products or menu.unlocked.production_resources), 
				Helper.unlockInfo(usage > 0 and menu.unlocked.production_products or menu.unlocked.production_resources, Helper.createFontString(ware.name, false, "left", color.r, color.g, color.b, color.a)), 
				Helper.createFontString(Helper.estimateString(menu.proddata.estimated) .. ConvertIntegerString(ware.amount, true, 4, true) .. " / " .. ConvertIntegerString(GetWareProductionLimit(menu.container or menu.object, ware.ware), true, 4, true), false, "right"), 
				Helper.createFontString(Helper.unlockInfo(usage > 0 and menu.unlocked.production_rate or menu.unlocked.consumption_rate, ConvertIntegerString(usage * ware.cycle * 3600 / menu.proddata.cycletime, true, 4, true)), false, "right")
			})
			AddKnownItem("wares", ware.ware)
		end
	end
end

function menu.addWareButtons(waretable, nooflines)
	nooflines = nooflines + 1
	if #waretable == 0 then
		nooflines = nooflines + 1
	else
		for _, ware in ipairs(waretable) do
			Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function () return menu.buttonEncyclopedia("ware", ware.ware) end)
			nooflines = nooflines + 1
		end
	end

	return nooflines
end

function menu.addEfficiencyEntries(setup, type, name, hullpercent, threshold, efffactor, effbonus)
	local sectiontitle = ""
	if type == "product" then
		sectiontitle = ReadText(1001, 1619)
	elseif type == "primary" then
		sectiontitle = ReadText(1001, 1620)
	elseif type == "cycle" then
		sectiontitle = ReadText(1001, 1621)
	else
		sectiontitle = ReadText(1001, 10000)
	end

	setup:addHeaderRow({ 
		sectiontitle,
		ReadText(1001, 13)
	}, nil, {3, 1})
		
	local displayed = false

	if menu.proddata.efficiency.efficiency[type] > 0 then
		if threshold < 1 then
			displayed = true
			setup:addSimpleRow({ 
				Helper.unlockInfo(menu.unlocked.efficiency_type, name .. " (" .. ReadText(1001, 1) .. ReadText(1001, 120) .. " " .. hullpercent .. "%)"),
				Helper.createFontString(Helper.unlockInfo(menu.unlocked.efficiency_amount, Helper.round(menu.proddata.efficiency.efficiency[type] * (threshold * efffactor + effbonus - 1) * 100, 2)) .. " %", false, "right") 
			}, nil, {3, 1})
		end

		if #menu.proddata.efficiencyupgrades > 0 and menu.proddata.efficiency.efficiency then
			for _, effmodule in ipairs(menu.proddata.efficiencyupgrades) do
				displayed = true
				local name, efffactor, effbonus = GetMacroData(effmodule, "name", "efficiencyfactor", "efficiencybonus")
				setup:addSimpleRow({ 
					Helper.unlockInfo(menu.unlocked.efficiency_type, name),
					Helper.createFontString(Helper.unlockInfo(menu.unlocked.efficiency_amount, Helper.round(menu.proddata.efficiency.efficiency[type] * (threshold * efffactor + effbonus - threshold) * 100, 2)) .. " %", false, "right") 
				}, nil, {3, 1})
			end
		end
	end

	if menu.proddata.efficiency.specialist and menu.proddata.efficiency.specialist.specialist and menu.proddata.efficiency.specialist[type] > 0 then
		displayed = true
		local specialistname = GetComponentData(menu.proddata.efficiency.specialist.specialist, "name")
		setup:addSimpleRow({ 
			Helper.unlockInfo(menu.unlocked.efficiency_type, specialistname),
			Helper.createFontString(Helper.unlockInfo(menu.unlocked.efficiency_amount, Helper.round(menu.proddata.efficiency.specialist[type] * 100, 2)) .. " %", false, "right") 
		}, nil, {3, 1})
	end

	if menu.proddata.efficiency.sunlight and menu.proddata.efficiency.sunlight[type] > 0 then
		displayed = true
		setup:addSimpleRow({ 
			Helper.unlockInfo(menu.unlocked.efficiency_type, ReadText(1001, 2412)),
			Helper.createFontString(Helper.unlockInfo(menu.unlocked.efficiency_amount, Helper.round(menu.proddata.efficiency.sunlight[type] * 100, 2)) .. " %", false, "right") 
		}, nil, {3, 1})
	end

	if menu.proddata.efficiency.secondary and menu.proddata.efficiency.secondary[type] > 0 then
		displayed = true
		setup:addSimpleRow({  
			Helper.unlockInfo(menu.unlocked.efficiency_type, ReadText(1001, 1615)),
			Helper.createFontString(Helper.unlockInfo(menu.unlocked.efficiency_amount, Helper.round(menu.proddata.efficiency.secondary[type] * 100, 2)) .. " %", false, "right") 
		}, nil, {3, 1})
	end

	if not displayed then
		setup:addSimpleRow({  
			"-- " .. (type == "cycle" and ReadText(1001, 1623) or ReadText(1001, 1622)) .. " --"
		}, nil, {3, 1})
	end
end

function menu.updateWares(waretable, oldwaretable, headerrow, usage)
	if #waretable ~= 0 then
		for i, ware in ipairs(waretable) do
			if oldwaretable[i].amount ~= ware.amount then
				oldwaretable[i].amount = ware.amount
				Helper.updateCellText(menu.selecttable, headerrow + i, 3, ConvertIntegerString(ware.amount, true, 4, true) .. " / " .. ConvertIntegerString(GetWareProductionLimit(menu.container or menu.object, ware.ware), true, 4, true))
				Helper.updateCellText(menu.selecttable, headerrow + i, 4, ConvertIntegerString(usage * ware.cycle * 3600 / menu.proddata.cycletime, true, 4, true))
			end
		end
	end
end

init()
