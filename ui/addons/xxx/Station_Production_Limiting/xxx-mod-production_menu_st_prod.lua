-- section == gMain_objectProduction
-- param == { 0, 0, object, productionmodule }

local menu = {}
local parentHookFunc = {}
local hook = {}


-- original code ... slightly modified (removed backward compatibility to < 4.30)

function hook.buttonConfigBrake(type, ware, prodmethod)
	if type == "ware" then
		Helper.closeMenuForSubSection(menu, false, "gMain_Station_Prod_Slider", { 0, 0, prodmethod, ware, menu.module })
		menu.cleanup()
	end
end

function hook.St_Prod_UpdateModuleInfo(module, prodbrake)
	local station = GetComponentData(module, "parent")
	local manager
	if station then
		manager = GetComponentData(station, "tradenpc")
	end

	if manager then
		-- must have a manager or nothing happens
		local proddata = GetProductionModuleData(module)

		-- xxx mod
		menu.player = xxxLibrary.getPlayerEntity()
		-- end xxx mod

		local globaldebug = 0
		if menu.player then
			globaldebug = GetNPCBlackboard(menu.player, "$St_Prod_Data_Debug") or 0
		end

		-- get the station debug level from manager BlackBoard
		local stationdebug = GetNPCBlackboard(manager, "$St_Prod_Data_Debug")
		if not stationdebug or stationdebug == "" then
			stationdebug = 0
		end
		-- hook.remotelog("production_menu_st_prod Global: " .. tostring(globaldebug) .. " Station: " .. tostring(stationdebug))

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

		if mdproddata[moduid] then
			-- get prodbrake and debug from the BlackBoard
			local mdprodbrake = mdproddata[moduid][4]
			local mdprevremainingcycletime = mdproddata[moduid][9] -- take the previous remainingcycletime
			local mddebug = mdproddata[moduid][5] or 0
			if not prodbrake then
				prodbrake = tonumber(mdprodbrake)
			end
			prevremainingcycletime = tonumber(mdprevremainingcycletime)
		else
			prevremainingcycletime = -10
			if not prodbrake then
				-- do not add to BlackBoard unless prodbrake set (turret, urv or missile forge)
				skipmodule = true
				if effectivedebug > 1 then
					hook.remotelog(GetComponentData(station, "name") .. " - " .. GetComponentData(module, "name") .. ". Skipping " .. proddata.products[1]["ware"] .. "s. Remaining " .. string.format("%1.2f", proddata.remainingcycletime) .. "s  - not limited.")
				end
			end
		end

		if prodbrake and prodbrake == 0 then
			-- stop braking this module
			skipmodule = true
			hook.remotelog("Skipping " .. GetComponentData(station, "name") .. " " .. moduid .. " prodbrake removed")
		end

		local proddatakeys = {}
		-- pass production data for this module onto the manager
		local exportproddata = { GetCurTime(), sequence, stage, tonumber(prodbrake), mddebug, proddata.state, proddata.cycletime, proddata.cycleefficiency, tonumber(proddata.remainingcycletime), prevremainingcycletime, proddata.products, proddata.presources, proddata.sresources }
		mdproddata[moduid] = exportproddata
		if skipmodule == false then
			-- update BlackBoard
			if effectivedebug > 0 then
				local zonename = GetComponentData(station, "zone") or "UnknownZone"
				hook.remotelog("Polling: " .. GetComponentData(station, "name") .. " - " .. tostring(zonename) .. " " .. moduid .. " rem_cycletime: " .. string.format("%4.3f", proddata.remainingcycletime) .. "s" .. " prevrem_cycletime: " .. string.format("%4.3f", prevremainingcycletime) .. "s")
			end
			SetNPCBlackboard(manager, "$St_Prod_Data", mdproddata)
			for k, v in pairs(mdproddata) do
				table.insert(proddatakeys, k)
			end
			SetNPCBlackboard(manager, "$St_Prod_DataKeys", proddatakeys) -- pass the keys to allow hash to be read in md script
		end
	else
		hook.remotelog("There is no Production Manager on " .. GetComponentData(menu.object, "name") .. " Cannot limit production")
	end
end

function hook.St_Prod_RemainingCycletime(eventname, module)
	-- hook.remotelog("Event: " .. eventname .. " , " .. GetComponentData(module, "name"))
	hook.St_Prod_UpdateModuleInfo(module)
end

function hook.addProdLimit(setup, module)
	local station = GetComponentData(module, "parent") or nil
	-- get build stage and sequence to use as unique key for this prod module
	local sequence, stage = GetComponentData(module, "sequence", "stage")
	if sequence and sequence == "" then
		sequence = "a"
	end
	local manager = GetComponentData(station, "tradenpc")
	local mdproddata = GetNPCBlackboard(manager, "$St_Prod_Data")

	setup:addHeaderRow({
	-- Helper.getEmptyCellDescriptor(),
		ReadText(360003, 1),
		ReadText(1001, 13)
	}, nil, { 3, 1 })
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
				local fixedprodmethod = hook.getprodmethod(menu.module, prodmethod) -- correct prod method
				hook.remotelog(_ .. " " .. ware.ware .. " - " .. fixedprodmethod)
				AddKnownItem("productionmethods", fixedprodmethod) -- make sure that you know about this production method

				local color = menu.white
				if menu.zoneowner and IsWareIllegalTo(ware.ware, menu.owner, menu.zoneowner) then
					color = menu.orange
				end

				local moduid = sequence .. "_" .. stage .. "_" .. ware.ware
				local mdprodbrake
				if mdproddata and mdproddata[moduid] then
					-- get prodbrake from the BlackBoard
					mdprodbrake = hook.stringf(mdproddata[moduid][4] * 100 * -1)
					-- hook.remotelog("addProdLimit " .. GetComponentData(station,"name") .. " - " .. GetComponentData(module,"name") .. " prodbrake: " .. mdprodbrake .. "%") 
				end

				setup:addSimpleRow({
					Helper.createButton(nil, Helper.createButtonIcon("dock_repair_active", nil, 255, 255, 255, 100), false, menu.unlocked.production_resources),
					Helper.unlockInfo(menu.unlocked.production_resources, Helper.createFontString(ware.name, false, "left", color.r, color.g, color.b, color.a)),
					Helper.createFontString((mdprodbrake or 0) .. " %", false, "right")
				}, nil, { 1, 2, 1 })
				AddKnownItem("wares", ware.ware)
			end
		end
	end
end

function hook.getprodmethod(module, prodmethod)
	-- fudge the production method
	local macro = GetComponentData(module, "macro")
	local prod = "default"
	if macro then
		if string.match(macro, "ol_macro$") then
			prod = "omicron"
		elseif string.match(macro, "dv_macro$") then
			prod = "devries"
		elseif string.match(macro, "xe_macro$") then
			prod = "xenon"
		end
	end
	--hook.remotelog("Prod module - " .. prod)

	local newprodmethod = string.gsub(prodmethod, "default", tostring(prod))
	local libentry = GetLibraryEntry("productionmethods", newprodmethod) or nil
	if libentry then
		-- use the race specific production method instead of default
		return newprodmethod
	else
		return prodmethod
	end
end

function hook.stringf(s)
	return string.format("%g", string.format("%1.2f", s))
end

function hook.remotelog(s)
	-- DebugError("remotelog " .. version .. " " .. tostring(s))
	AddUITriggeredEvent("St_Prod_Logger", "", s)
end

function hook.addProdLimitButtons(productionInfoTable, nooflines)
	nooflines = nooflines + 1
	if #productionInfoTable == 0 then
		nooflines = nooflines + 1
	else
		for _, ware in ipairs(productionInfoTable) do
			local prodmethod = GetWareData(ware.ware, "productionmethod")
			local fixedprodmethod = hook.getprodmethod(menu.module, prodmethod) -- correct prod method
			Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
				return hook.buttonConfigBrake("ware", ware.name, fixedprodmethod)
			end)
			nooflines = nooflines + 1
		end
	end
	return nooflines
end


-- hook from xxx-modified original menu -- hooks call original Station_Production_Limit functions

function hook.onShowMenuHookAddRows(setup)
	parentHookFunc.onShowMenuHookAddRows(setup)
	hook.addProdLimit(setup, menu.module)
end

function hook.onShowMenuHookAddButtonScripts(nooflines)
	nooflines = parentHookFunc.onShowMenuHookAddButtonScripts(nooflines)
	if menu.owner == "player" then
		nooflines = hook.addProdLimitButtons(GetPossibleProducts(menu.module), nooflines)
	end
	return nooflines
end

local function init()
	for _, existingMenu in ipairs(Menus) do
		if existingMenu.name == "ProductionMenu" then
			menu = existingMenu
			parentHookFunc.onShowMenuHookAddRows = menu.onShowMenuHookAddRows
			parentHookFunc.onShowMenuHookAddButtonScripts = menu.onShowMenuHookAddButtonScripts
			menu.onShowMenuHookAddRows = hook.onShowMenuHookAddRows
			menu.onShowMenuHookAddButtonScripts = hook.onShowMenuHookAddButtonScripts
			RegisterEvent("St_Prod_RemainingCycletime", hook.St_Prod_RemainingCycletime)
			break
		end
	end
end

init()