local menu = {
	name = "Station_Prod_Config",
}

local function init()
	Menus = Menus or { }
	table.insert(Menus, menu)
	if Helper then
		Helper.registerMenu(menu)
	end
    RegisterEvent("St_Prod_Player", menu.St_Prod_Player)
end

function menu.cleanup()
	menu.title = nil

	menu.infotable = nil
	menu.selecttable = nil
	
	menu.priware = nil
	menu.module = nil
	menu.manager = nil
	menu.globaldebug = nil
	menu.globaldebugN = nil
	menu.stationdebug = nil
	menu.stationdebugN = nil
	menu.moduledebug = nil
	menu.moduledebugN = nil
	menu.modulelimited = nil
end

-- Menu member functions

function menu.onShowMenu()
	menu.priware = menu.param[3]
	menu.module = menu.param[4]
	menu.title = ReadText(360003, 1) .. " - " .. ReadText(360003, 20)
	menu.moduledebug = 2
  
	-- get the global debug level from player BlackBoard
	local playership = GetPlayerPrimaryShipID()
    if playership then
		local player = GetComponentData(playership, "controlentity")
		if player then 
			menu.player = player
		end
	end

	if menu.player then 
		menu.globaldebug = GetNPCBlackboard(menu.player, "$St_Prod_Data_Debug") or 0		
	else
		menu.globaldebug = 0
	end
	menu.globaldebugN = menu.globaldebug

 	-- get the station debug level from manager BlackBoard
	local station = GetComponentData(menu.module, "parent")
	if station then
		menu.manager = GetComponentData(station, "tradenpc")
	end
	menu.stationdebug = 0		
	if menu.manager then
		menu.stationdebug = GetNPCBlackboard(menu.manager, "$St_Prod_Data_Debug") or 0
	end
	menu.stationdebugN = menu.stationdebug
	
	-- get the module debug level from manager BlackBoard
	local moduid = menu.getuid()

	if menu.manager then
		local mdproddata = GetNPCBlackboard(menu.manager, "$St_Prod_Data") or {}
		if mdproddata[moduid] then 
			menu.moduledebug = mdproddata[moduid][5] or 0
			menu.modulelimited = true
		else 
			menu.moduledebug = "_"
			menu.modulelimited = false
		end
	end

	local setup = Helper.createTableSetup(menu)
	setup:addTitleRow({
		Helper.createFontString(menu.title, false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, Helper.headerRow1Height, Helper.headerRow1Width)
	})
	setup:addTitleRow({ 
		Helper.createFontString("", false, "left", 129, 160, 182, 100, Helper.headerRow2Font, Helper.headerRow2FontSize, false, Helper.headerRow2Offsetx, Helper.headerRow2Offsety, Helper.headerRow2Height, Helper.headerRow1Width)	-- text depends on selection
	})
	local infodesc = setup:createCustomWidthTable({0}, false)

	setup = Helper.createTableSetup(menu)
	-- Debug level
	setup:addHeaderRow({
		ReadText(360003, 40)
		}, nil, {8})
	-- Global
	menu.addRadio(setup, ReadText(360003, 30) .. ReadText(1001, 120 ), {0,1,2,3}, menu.globaldebug)
	-- Station
	menu.addRadio(setup, ReadText(1001, 3) .. ReadText(1001, 120 ) .. " " .. GetComponentData(GetComponentData(menu.module,"parent"),"name"), {0,1,2,3}, menu.stationdebug)
	-- Production Module
	setup:addSimpleRow({
		Helper.getEmptyCellDescriptor()
	}, nil, {8})
	setup:addSimpleRow({
		Helper.getEmptyCellDescriptor(),
--		Helper.createFontString(ReadText(360003, 50), false, "right"),
		Helper.createFontString("", false, "right"),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 14), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true)
	}, nil, {1,6,1})

	setup:addFillRows(5, nil, {8})

	-- Write production limits to Logbook
	setup:addHeaderRow({ 
		ReadText(360003, 70) .. ReadText(1001, 5700)
		}, nil, {8})
	setup:addSimpleRow({
		Helper.getEmptyCellDescriptor(),
		ReadText(360003, 30) .. ReadText(1001, 120 ),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 14), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true)
	}, nil, {1,6,1})
	setup:addSimpleRow({
		Helper.getEmptyCellDescriptor(),
		ReadText(1001, 3) .. ReadText(1001, 120 ) .. " " .. GetComponentData(GetComponentData(menu.module,"parent"),"name"),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 14), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true)
	}, nil, {1,6,1})
	local text = ReadText(1001, 45) .. ReadText(1001, 120 ) .. " " .. GetComponentData(menu.module,"name") .. " - " .. GetWareData(menu.priware, "name")
	if not menu.modulelimited then
		text =  text  .. "\27Y - " .. ReadText(360003, 90) .. "\27X" 
	end
	setup:addSimpleRow({
		Helper.getEmptyCellDescriptor(),
		text,
		Helper.createButton(Helper.createButtonText(ReadText(1001, 14), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, menu.modulelimited)
	}, nil, {1,6,1})

	setup:addFillRows(10, nil, {7})

	-- Clear Production Limiting
	setup:addHeaderRow({ 
		ReadText(1001, 5706) .. " " .. ReadText(360003, 1)
		}, nil, {8})
	setup:addSimpleRow({
		Helper.getEmptyCellDescriptor(),
		ReadText(360003, 30) .. ReadText(1001, 120 ),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 14), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true)
	}, nil, {1,6,1})
	setup:addFillRows(13, nil, {7})
	setup:addSimpleRow({
		Helper.getEmptyCellDescriptor(),
		ReadText(1001, 3) .. ReadText(1001, 120 ) .. " " .. " - " .. GetComponentData(GetComponentData(menu.module,"parent"),"name"),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 14), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true)
	}, nil, {1,6,1})

	local selectdesc = setup:createCustomWidthTable({ 5 * Helper.standardTextOffsetx, 0, Helper.standardButtonWidth, Helper.standardButtonWidth, Helper.standardButtonWidth, Helper.standardButtonWidth, 2 * Helper.standardTextOffsetx, 15 * Helper.standardTextOffsetx }, false, false, true, 1, 0, 0, Helper.tableOffsety)

	-- create tableview
	menu.infotable, menu.selecttable = Helper.displayTwoTableView(menu, infodesc, selectdesc, false)

	-- set button scripts
	-- debug
	menu.addRadioButtons(2, 3, 4, "global")
	menu.addRadioButtons(3, 3, 4, "station")

	Helper.setButtonScript(menu, nil, menu.selecttable, 5, 8, function () return menu.debugApply() end)

	-- logbook
	Helper.setButtonScript(menu, nil, menu.selecttable, 7, 8, function () return menu.logbook("global") end)
	Helper.setButtonScript(menu, nil, menu.selecttable, 8, 8, function () return menu.logbook("station") end)
	if menu.modulelimited then
		Helper.setButtonScript(menu, nil, menu.selecttable, 9, 8, function () return menu.logbook("module") end)
	end

	-- clear
	Helper.setButtonScript(menu, nil, menu.selecttable, 12, 8, function () return menu.clear("global") end)
	Helper.setButtonScript(menu, nil, menu.selecttable, 14, 8, function () return menu.clear("station") end)

	-- clear descriptors again
	Helper.releaseDescriptors()
end

-- menu.updateInterval = 2.0
function menu.addRadio(setup, text, buttons, value)
	-- menu.remotelog("addRadio: '" .. tostring(text) .. "' " .. tostring(#buttons) .. " " .. tostring(value))
	local radio = {Helper.getEmptyCellDescriptor(), text}
	for button = 1, #buttons, 1 do
		table.insert(radio, Helper.createButton(Helper.createButtonText(buttons[button], "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true))
	end
	table.insert(radio, Helper.getEmptyCellDescriptor())
	table.insert(radio, Helper.createFontString(value, false, "center"))
	setup:addSimpleRow(radio)
end

function menu.addRadioButtons(row, col, numbuttons, scope)
	-- menu.remotelog("addRadioButtons: " .. tostring(row) .. "," .. tostring(col) .. "," .. tostring(numbuttons) .. " " .. tostring(scope))
	for buttoncol = col, col + numbuttons, 1 do
		Helper.setButtonScript(menu, nil, menu.selecttable, row, buttoncol, function () return menu.debug(row, buttoncol - col, scope) end)
	end
end

function menu.St_Prod_Player(eventname, player)
	menu.remotelog("Player from md: " .. eventname .. " , " .. tostring(player))
	menu.player = player
end

function menu.debugApply() -- apply the new debug settings
	Helper.updateCellText(menu.selecttable, 5, 2, "")

	if menu.player then 
		SetNPCBlackboard(menu.player, "$St_Prod_Data_Debug", menu.globaldebugN) -- set Global Debug level
		local globaldebug = GetNPCBlackboard(menu.player, "$St_Prod_Data_Debug") or ""		
		if menu.globaldebug ~= globaldebug then
			menu.remotelog("Global Debug - Before: " .. tostring(menu.globaldebug) .. " Now: " .. tostring(globaldebug))
			menu.globaldebug = globaldebug
		end
	else
		menu.remotelog("Player unknown")
	end
	
	if menu.manager then
		SetNPCBlackboard(menu.manager, "$St_Prod_Data_Debug", menu.stationdebugN) -- set Station Debug level
		local stationdebug = GetNPCBlackboard(menu.manager, "$St_Prod_Data_Debug") or ""		
		if menu.stationdebug ~= stationdebug then
			menu.remotelog("Station Debug - Before: " .. tostring(menu.stationdebug) .. " Now: " .. tostring(stationdebug))
			menu.stationdebug = stationdebug
		end
	end
end

function menu.getuid()
	-- get build stage and sequence to use as unique key for this prod module
	local sequence, stage = GetComponentData(menu.module, "sequence", "stage")
	if sequence and sequence == "" then 
		sequence = "a" 
	end
	local moduid = sequence .. "_" .. stage .. "_" .. menu.priware
	-- DebugError("Moduid is " .. moduid)
	return moduid
end

function menu.debug(row, value, scope)
	-- menu.remotelog("Debug: " .. tostring(row) .. "," .. tostring(value) .. " " .. tostring(scope))
	Helper.updateCellText(menu.selecttable, row, 8, value)
	Helper.updateCellText(menu.selecttable, 5, 2, "\27Y" .. ReadText(360003, 50) .. "\27X")
	--menu.remotelog(tostring(menu.globaldebug) .. " " .. tostring(menu.globaldebugN) .. " " .. tostring(value))
	--menu.remotelog(tostring(menu.stationdebug) .. " " .. tostring(menu.stationdebugN) .. " " .. tostring(value))
	if scope == "global" then
		menu.globaldebugN = value
	elseif scope == "station" then
		menu.stationdebugN = value
	elseif scope == "module" then
		menu.moduledebugN = value
	end
	if menu.globaldebug ~= menu.globaldebugN or menu.stationdebugN ~= menu.stationdebug then
		Helper.updateCellText(menu.selecttable, 5, 2, "\27Y" .. ReadText(360003, 50) .. "\27X")		
	else
		Helper.updateCellText(menu.selecttable, 5, 2, "")		
	end
end

function menu.logbook(scope)
	menu.remotelog("LogBook: " .. tostring(scope))
	if scope == "global" then
		local owner = GetComponentData(menu.player, "owner")
		if owner then
			local playerstations = GetContainedStationsByOwner(owner) or {}
			for _, station in ipairs(playerstations) do
				local manager = GetComponentData(station, "tradenpc") 
				if manager then
					menu.logbymanager(manager, station)
				end
			end
		else
			menu.remotelog("Logbook: production limiting - No player stations found")
		end
	elseif scope == "station" then
		local station = GetComponentData(menu.module, "parent")
		if station then
			menu.logbymanager(menu.manager, station)
		else
			menu.remotelog("Logbook: production limiting - Unknown station")
		end
	elseif scope == "module" then
		local mdproddata = GetNPCBlackboard(menu.manager, "$St_Prod_Data") or {}		
		local moduid = menu.getuid()
		if mdproddata[moduid] then
			local mdprodbrake = mdproddata[moduid][4]
			local priware = mdproddata[moduid][11][1]["name"]
			if mdprodbrake then
				menu.logbymodule(menu.module, priware, mdprodbrake)
			end
		end
	end
end

function menu.logbymanager(manager, station)
	if manager then
		local mdproddata = GetNPCBlackboard(manager, "$St_Prod_Data")		
		local keys = GetNPCBlackboard(manager, "$St_Prod_DataKeys")		
		if mdproddata then
			-- menu.remotelog("Iterating through BlackBoard for " .. GetComponentData(station, "name") .. ". entries: " .. #keys)
			if #keys > 0 then
				for _, key in ipairs(keys) do
					local proddata = mdproddata[key]
					if proddata then 
						local sequence = proddata[2]
						if sequence == "a" then 
							sequence = "" 
						end
						local stage = proddata[3]
						local mdprodbrake = proddata[4]
						local priware = proddata[11][1]["name"]
						local prodmodules = GetProductionModules(station) or {}
						for _, prodmod in ipairs(prodmodules) do
							if GetComponentData(prodmod, "sequence") and GetComponentData(prodmod, "sequence") == sequence and GetComponentData(prodmod, "stage") and GetComponentData(prodmod, "stage") == stage then
								if mdprodbrake then
									menu.logbymodule(prodmod, priware , mdprodbrake)
								end
								break
							end
						end
					end
				end
			end
		else
			-- menu.remotelog("menu.logbymanager - No $St_Prod_Data for " .. GetComponentData(station, "name"))
		end
	else
		-- menu.remotelog("menu.logbymanager - No manager")
	end
end

function menu.logbymodule(module, product, prodbrake)
	if menu.manager then -- do nothing without a manager
		local station = GetComponentData(module, "parent")
		if station then 
			local zone = GetComponentData(GetComponentData(station, "parent"), "name") or "Unknown zone"
			local stationdesc = (GetComponentData(station, "name") or "Unknown Station") .. " - " .. (GetComponentData(module, "name") or "Unknown Module") .. " " .. ReadText(1001, 2953) .. " " .. tostring(zone) .. ". "
			stationdesc = stationdesc .. ReadText(360003, 100) .. menu.stringf(prodbrake * 100) .. "%" .. " - " .. tostring(product) 
			AddLogbookEntry("general", stationdesc)
			menu.remotelog("Adding to logbook: " .. stationdesc)
		end
	end
end

function menu.clear(scope)
	menu.remotelog("Clear production limits: " .. tostring(scope))
	if scope == "global" then
		if menu.player then 
			local owner = GetComponentData(menu.player, "owner")
			if owner then
				local playerstations = GetContainedStationsByOwner(owner) or {}
				for _, station in ipairs(playerstations) do
					local manager = GetComponentData(station, "tradenpc") 
					if manager and GetNPCBlackboard(manager, "$St_Prod_Data") then
						menu.remotelog("Wiping the blackboard for " .. (GetComponentData(station,"name") or "Unknown Station"))
						SetNPCBlackboard(manager, "$St_Prod_Data", "") -- wipe the BlackBoard
						SetNPCBlackboard(manager, "$St_Prod_DataKeys", "") -- wipe the keys
					end
				end
			end
		else  -- find the player
			local version = tonumber(string.sub(GetVersionString(), string.find(GetVersionString(), '(',1,true) + 1, string.find(GetVersionString(), '(',1,true) + 6)) or 208022
			if version < 208022 then -- compensate for AddUITriggeredEvent parameter change
				AddUITriggeredEvent("St_Prod_GetPlayer", "")
			else
				AddUITriggeredEvent("St_Prod_GetPlayer", "none", "")
			end
		end
	elseif scope == "station" then
		if menu.manager and GetNPCBlackboard(menu.manager, "$St_Prod_Data") then
			local station = GetComponentData(menu.module,"parent")
			if station then 
				menu.remotelog("Wiping the blackboard for " .. (GetComponentData(station,"name") or "Unknown Station"))
			else
				menu.remotelog("Wiping the blackboard for Unknown Station")
			end
			SetNPCBlackboard(menu.manager, "$St_Prod_Data", "") -- wipe the BlackBoard
			SetNPCBlackboard(menu.manager, "$St_Prod_DataKeys", "") -- wipe the keys
		end
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

function menu.onUpdate()
end

function menu.onRowChanged(row, rowdata)
	if rowdata then
		
	end
end

function menu.onSelectElement()
	local rowdata = Helper.currentTableRowData
	if rowdata then
	end
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
