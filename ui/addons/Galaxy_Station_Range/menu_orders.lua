local yvgstr_menu = {}
local Funcs = {}

-- ffi setup
local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
	typedef uint64_t UniverseID;
	typedef struct {
		int64_t trade;
		int64_t defence;
		int64_t missile;
	} SupplyBudget;
	float GetDistanceBetween(UniverseID component1id, UniverseID component2id);
	int GetPlayerShipNumFreeActorSlots(void);
	SupplyBudget GetSupplyBudget(UniverseID containerid);
	bool HasCustomConversation(UniverseID entityid);
]]

local function init()
	for _, menu in ipairs(Menus) do
    if menu.name == "OrdersMenu" then
      yvgstr_menu = menu
      
      menu.displayMenu = Funcs.yvgstr_displayMenu
      menu.buttonDetails = Funcs.yvgstr_buttonDetails
	  menu.onRowChanged = Funcs.yvgstr_onRowChanged
      break
    end
  end
end

-- Menu member functions
function Funcs.yvgstr_buttonDetails()
	local menu = yvgstr_menu
	
	if menu.rowDataMap[Helper.currentDefaultTableRow] then
		local rowdata = menu.rowDataMap[Helper.currentDefaultTableRow]
		if IsValidComponent(menu.entity) then
			if type(rowdata) == "table" then
				if rowdata[1] == "mission" then
					print(rowdata[2])
					Helper.closeMenuForSubSection(menu, false, "gMainMissions_manager", { 0, 0, rowdata[2] })
					menu.cleanup()
				end
			elseif rowdata == "container" then
				Helper.closeMenuForSubSection(menu, false, "gMain_object", { 0, 0, menu.container })
				menu.cleanup()
			elseif rowdata == "skills" then
				Helper.closeMenuForSubSection(menu, false, "gMain_charProfileMenu", { 0, 0, menu.entity, menu.owner == "player" })
				menu.cleanup()
			elseif rowdata == "subordinates" then
				Helper.closeMenuForSubSection(menu, false, "gMain_objectShips", { 0, 0, menu.container, menu.typestring })
				menu.cleanup()
			elseif rowdata == "restrictions" then
				if menu.typestring == "architect" then
					ToggleFactionTradeRestriction(menu.container)
					Helper.updateCellText(menu.selecttable, Helper.currentDefaultTableRow, 4, GetTradeRestrictions(menu.container).faction and ReadText(1001, 2617) or ReadText(1001, 2618))
				elseif menu.typestring == "manager" then
					Helper.closeMenuForSubSection(menu, false, "gMain_objectTradeRestrictions", { 0, 0, menu.entity })
					menu.cleanup()
				end
			elseif rowdata == "priceoverrides" then
				Helper.closeMenuForSubSection(menu, false, "gMain_objectPriceOverrides", { 0, 0, menu.entity })
				menu.cleanup()
			elseif rowdata == "tradewares" then
				Helper.closeMenuForSubSection(menu, false, "gMain_objectTradeWares", { 0, 0, menu.entity })
				menu.cleanup()
			elseif rowdata == "budget" then
				local wantedmoney = 0
				if menu.typestring == "architect" then
					wantedmoney = GetComponentData(menu.entity, "wantedmoney")
				else
					wantedmoney = GetComponentData(menu.entity, "productionmoney")
					local supplybudget = C.GetSupplyBudget(ConvertIDTo64Bit(menu.container))
					wantedmoney = wantedmoney + tonumber(supplybudget.trade) / 100 + tonumber(supplybudget.defence) / 100 + tonumber(supplybudget.missile) / 100
				end
				Helper.closeMenuForSubSection(menu, false, "gMain_moneyTransferMenu", {0, 0, menu.entity, wantedmoney })
				menu.cleanup()
			elseif rowdata == "command" then
				if menu.typestring == "defencecontrol" then
					menu.blackboard_attackenemies = not menu.blackboard_attackenemies
					SetNPCBlackboard(menu.entity, "$config_attackenemies", Helper.convertComponentIDs(menu.blackboard_attackenemies))
					Helper.updateCellText(menu.selecttable, Helper.currentDefaultTableRow, 1, menu.blackboard_attackenemies and ReadText(1001, 4214) or ReadText(1001, 4213))
					AttackEnemySettingChanged(menu.entity)
				end
			elseif rowdata == "subordinaterange" then
				local subordianterangecomponenttype = ""

				if IsComponentClass(menu.subordinaterangecomponent, "cluster") then
					menu.subordinaterangecomponent = GetContextByClass(menu.entity, "galaxy")
					subordianterangecomponenttype = ReadText(20001, 901)
				elseif IsComponentClass(menu.subordinaterangecomponent, "sector") then
					if GetComponentData(menu.container, "maxradarrange") > 30000 then
						menu.subordinaterangecomponent = GetContextByClass(menu.entity, "cluster")
						subordianterangecomponenttype = ReadText(20001, 101)
					else
						menu.subordinaterangecomponent = GetContextByClass(menu.entity, "zone")
						subordianterangecomponenttype = ReadText(20001, 301)
					end
				elseif IsComponentClass(menu.subordinaterangecomponent, "zone") then
					menu.subordinaterangecomponent = GetContextByClass(menu.entity, "sector")
					subordianterangecomponenttype = ReadText(20001, 201)
				elseif IsComponentClass(menu.subordinaterangecomponent, "galaxy") then
					menu.subordinaterangecomponent = GetContextByClass(menu.entity, "zone")
					subordianterangecomponenttype = ReadText(20001, 301)
				end
				
				SetNPCBlackboard(menu.entity, "$config_subordinate_range", Helper.convertComponentIDs(menu.subordinaterangecomponent))
				AIRangeUpdated(menu.container, menu.entity)

				Helper.updateCellText(menu.selecttable, Helper.currentDefaultTableRow, 4, subordianterangecomponenttype)
			elseif rowdata == "supply" then
				Helper.closeMenuForSubSection(menu, false, "gMain_objectSupply", {0, 0, menu.container })
				menu.cleanup()
			elseif rowdata == "refuel_auto" then
				menu.autorefuel = not menu.autorefuel
				SetNPCBlackboard(menu.entity, "$config_autorefuel", Helper.convertComponentIDs(menu.autorefuel))
				Helper.updateCellText(menu.selecttable, Helper.currentDefaultTableRow, 4, menu.autorefuel and ReadText(1001, 2617) or ReadText(1001, 2618))
			elseif rowdata == "shoppinglist" then
				ClearTradeQueue(menu.container)
				menu.dontdisplaytradequeue = true
				menu.displayMenu()
			elseif rowdata == "comeaboard" then
				Helper.closeMenuForSubSection(menu, false, "gMain_charOrders_comeaboard", menu.entity)
				menu.cleanup()
			end
		else
			Helper.closeMenuAndCancel(menu)
			menu.cleanup()
		end
	end
end

function Funcs.yvgstr_displayMenu()
	local menu = yvgstr_menu
	
	-- Remove possible button scripts from previous view
	Helper.removeAllButtonScripts(menu)
	Helper.currentTableRow = {}
	Helper.currentTableRowData = nil
	menu.rowDataMap = {}

	-- Title line as one TableView
	local setup = Helper.createTableSetup(menu)
	
	local name, typestring, typeicon, typename, owner, ownericon = GetComponentData(menu.entity, "name", "typestring", "typeicon", "typename", "owner", "ownericon")
	menu.typestring = typestring
	menu.owner = owner
	setup:addTitleRow{
		Helper.createIcon(typeicon, false, 255, 255, 255, 100, 0, 0, Helper.headerCharacterIconSize, Helper.headerCharacterIconSize),
		Helper.createFontString(typename .. " " .. name, false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize),
		ownericon and Helper.createIcon(ownericon, false, 255, 255, 255, 100, 0, 0, Helper.headerCharacterIconSize, Helper.headerCharacterIconSize) or Helper.getEmptyCellDescriptor()
	}
	
	setup:addTitleRow({
		Helper.getEmptyCellDescriptor()
	}, nil, {3})
	
	local infodesc = setup:createCustomWidthTable({ Helper.scaleX(Helper.headerCharacterIconSize), 0, Helper.scaleX(Helper.headerCharacterIconSize) + 37 }, false, true)

	setup = Helper.createTableSetup(menu)
	
	local container, hasownaccount, aicommandstack, aicommandaction, aicommandactionparam = GetComponentData(menu.entity, "container", "hasownaccount", "aicommandstack", "aicommandaction", "aicommandactionparam")
	local money = GetAccountData(menu.entity, "money")
	local subordinates = GetSubordinates(container, typestring)
	for i = #subordinates, 1, -1 do
		if GetBuildAnchor(subordinates[i]) then
			table.remove(subordinates, i)
		elseif IsComponentClass(subordinates[i], "drone") then
			table.remove(subordinates, i)
		end
	end
	menu.container = container

	menu.unlocked.operator_name = IsInfoUnlockedForPlayer(container, "operator_name")
	menu.unlocked.operator_details = IsInfoUnlockedForPlayer(container, "operator_details")
	menu.unlocked.operator_commands = IsInfoUnlockedForPlayer(container, "operator_commands")
	menu.unlocked.managed_ships = IsInfoUnlockedForPlayer(container, "managed_ships")
	
	setup:addSimpleRow({
		ReadText(1001, 1918)
	}, "skills", {4})
	setup:addSimpleRow({
		ReadText(1001, 4200),
		GetComponentData(container, "name")
	}, ((menu.typestring == "commander") or (menu.typestring == "pilot")) and "comeaboard" or "container", {3, 1})
	setup:addHeaderRow({
		ReadText(1001, 79)
	}, nil, {4})
	
	if menu.typestring == "defencecontrol" then
		menu.blackboard_attackenemies = GetNPCBlackboard(menu.entity, "$config_attackenemies")
		menu.blackboard_attackenemies = menu.blackboard_attackenemies and menu.blackboard_attackenemies ~= 0
	end
	local spacing = ""
	if #aicommandstack > 0 then
		for i, command in ipairs(aicommandstack) do
			setup:addSimpleRow({
				Helper.unlockInfo(menu.unlocked.operator_commands, string.format(spacing .. command.command, IsComponentClass(command.param, "component") and GetComponentData(command.param, "name") or nil)),
			}, menu.typestring == "defencecontrol" and "command" or nil, {4})
			spacing = spacing .. "  "
		end
	else
		local aicommand = Helper.parseAICommand(menu.entity)
		setup:addSimpleRow({
			Helper.unlockInfo(menu.unlocked.operator_commands, aicommand),
		}, menu.typestring == "defencecontrol" and "command" or nil, {4})
		spacing = spacing .. "  "
	end
	if aicommandaction ~= "" then
		setup:addSimpleRow({
			Helper.unlockInfo(menu.unlocked.operator_commands, string.format(spacing .. aicommandaction, IsComponentClass(aicommandactionparam, "component") and GetComponentData(aicommandactionparam, "name") or nil)),
		}, nil, {4})
	end

	-- entity settings for player owned only
	if owner == "player" then
		local addedblackline = false
		if hasownaccount then
			if not addedblackline then
				addedblackline = true
				setup:addHeaderRow({
					Helper.createFontString("", false, Helper.standardHalignment, Helper.standardColor.r, Helper.standardColor.g, Helper.standardColor.b, Helper.standardColor.a, Helper.standardFont, 6, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, 6)
				}, nil, {4})
			end
			setup:addSimpleRow({ 
				ReadText(1001, 1908), 
				Helper.createFontString(ConvertMoneyString(money, false, true, 0, true) .. " " .. ReadText(1001, 101), false, "right")
			}, "budget", {3, 1})

			if menu.typestring == "architect" then
				local wantedmoney = GetComponentData(menu.entity, "wantedmoney")
				setup:addSimpleRow({ 
					ReadText(1001, 1919), 
					Helper.createFontString(ConvertMoneyString(wantedmoney, false, true, 0, true) .. " " .. ReadText(1001, 101), false, "right")
				}, nil, {3, 1})
			elseif menu.typestring == "manager" then
				local productionmoney = GetComponentData(menu.entity, "productionmoney")
				local supplybudget = C.GetSupplyBudget(ConvertIDTo64Bit(container))
				local trademoney, defencemoney, missilemoney = tonumber(supplybudget.trade) / 100, tonumber(supplybudget.defence) / 100, tonumber(supplybudget.missile) / 100
				if not menu.extendedcategories["wantedmoney"] then
					setup:addSimpleRow({ 
						Helper.createButton(Helper.createButtonText("+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
						ReadText(1001, 1919),
						Helper.createFontString(ConvertMoneyString(productionmoney + trademoney + defencemoney + missilemoney, false, true, 0, true) .. " " .. ReadText(1001, 101), false, "right")
					}, nil, {1, 2, 1})
				else
					setup:addSimpleRow({ 
						Helper.createButton(Helper.createButtonText("-", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
						ReadText(1001, 1919),
						Helper.createFontString(ConvertMoneyString(productionmoney + trademoney + defencemoney + missilemoney, false, true, 0, true) .. " " .. ReadText(1001, 101), false, "right")
					}, nil, {1, 2, 1})

					setup:addSimpleRow({ 
						Helper.getEmptyCellDescriptor(),
						ReadText(1001, 1600), 
						Helper.createFontString(ConvertMoneyString(productionmoney, false, true, 0, true) .. " " .. ReadText(1001, 101), false, "right")
					}, nil, {1, 2, 1})
					setup:addSimpleRow({ 
						Helper.getEmptyCellDescriptor(),
						ReadText(20214, 900), 
						Helper.createFontString(ConvertMoneyString(trademoney, false, true, 0, true) .. " " .. ReadText(1001, 101), false, "right")
					}, nil, {1, 2, 1})
					setup:addSimpleRow({ 
						Helper.getEmptyCellDescriptor(),
						ReadText(20214, 300), 
						Helper.createFontString(ConvertMoneyString(defencemoney, false, true, 0, true) .. " " .. ReadText(1001, 101), false, "right")
					}, nil, {1, 2, 1})
					setup:addSimpleRow({ 
						Helper.getEmptyCellDescriptor(),
						ReadText(1001, 1304), 
						Helper.createFontString(ConvertMoneyString(missilemoney, false, true, 0, true) .. " " .. ReadText(1001, 101), false, "right")
					}, nil, {1, 2, 1})
				end
			end
		end

		if menu.typestring == "architect" or menu.typestring == "manager" then
			if not addedblackline then
				addedblackline = true
				setup:addHeaderRow({
					Helper.createFontString("", false, Helper.standardHalignment, Helper.standardColor.r, Helper.standardColor.g, Helper.standardColor.b, Helper.standardColor.a, Helper.standardFont, 6, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, 6)
				}, nil, {4})
			end
			local traderestrictions = GetTradeRestrictions(container)
			setup:addSimpleRow({
				ReadText(1001, 4202),
				traderestrictions.faction and ReadText(1001, 2617) or ReadText(1001, 2618)
			}, "restrictions", {3, 1})
		end

		if menu.typestring == "architect" or menu.typestring == "manager" then
			if not addedblackline then
				addedblackline = true
				setup:addHeaderRow({
					Helper.createFontString("", false, Helper.standardHalignment, Helper.standardColor.r, Helper.standardColor.g, Helper.standardColor.b, Helper.standardColor.a, Helper.standardFont, 6, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, 6)
				}, nil, {4})
			end
			if (menu.typestring == "manager") and GetComponentData(container, "istradestation") then
				setup:addSimpleRow({
					ReadText(1001, 4228)
				}, "tradewares", {4})
			else
				setup:addSimpleRow({
					ReadText(1001, 4226)
				}, "priceoverrides", {4})
			end
		end

		local tradenpc = GetComponentData(container, "tradenpc")
		if tradenpc and (menu.typestring == "manager" or menu.typestring == "defencecontrol") then
			if not addedblackline then
				addedblackline = true
				setup:addHeaderRow({
					Helper.createFontString("", false, Helper.standardHalignment, Helper.standardColor.r, Helper.standardColor.g, Helper.standardColor.b, Helper.standardColor.a, Helper.standardFont, 6, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, 6)
				}, nil, {4})
			end
			setup:addSimpleRow({
				ReadText(1001, 4229)
			}, "supply", {4})
		end

		if menu.typestring == "commander" then
			if not addedblackline then
				addedblackline = true
				setup:addHeaderRow({
					Helper.createFontString("", false, Helper.standardHalignment, Helper.standardColor.r, Helper.standardColor.g, Helper.standardColor.b, Helper.standardColor.a, Helper.standardFont, 6, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, 6)
				}, nil, {4})
			end
			local temp = GetNPCBlackboard(menu.entity, "$config_autorefuel")
			menu.autorefuel = temp and temp ~= 0
			setup:addSimpleRow({
				ReadText(1001, 4224),
				menu.autorefuel and ReadText(1001, 2617) or ReadText(1001, 2618)
			}, "refuel_auto", {3, 1})
		end

		if not menu.dontdisplaytradequeue and (menu.typestring == "pilot" or menu.typestring == "commander") then
			local tradequeue = GetShoppingList(container)
			if next(tradequeue) then
				setup:addHeaderRow({
					ReadText(1001, 2937)
				}, nil, {4})
				for i, item in ipairs(tradequeue) do
						local cluster, sector, zone, isplayerowned = GetComponentData(item.station, "cluster", "sector", "zone", "isplayerowned")
					if item.iswareexchange or isplayerowned then
						local text
						if item.ispassive then
							if item.isbuyoffer then
								text = ReadText(1001, 2993) -- object transfers to
							else
								text = ReadText(1001, 2995) -- object receives
							end
						else
							if item.isbuyoffer then
								text = ReadText(1001, 2993) -- object transfers to
							else
								text = ReadText(1001, 2992) -- object transfers from
							end
						end
						setup:addSimpleRow({ 
							Helper.createFontString(string.format(text .. "\n" .. ReadText(1001, 2994), ConvertIntegerString(item.amount, true, nil, true), item.name, item.stationname, cluster, sector, zone), false, "left", nil, nil, nil, nil, nil, nil, true, nil, nil, 0, Helper.standardSizeX)
						}, "shoppinglist", {4})
					else
						local profittext = ""
						if item.isbuyoffer then
							local trade = GetTradeData(item.id)
							local profit = GetReferenceProfit(menu.container, trade.ware, item.price, item.amount, i - 1)
							profittext = " [" .. string.format(ReadText(1001, 6203), (profit and ConvertMoneyString(profit, false, true, 6, true) or ReadText(1001, 2672)) .. " " .. ReadText(1001, 101)) .. "]"
						end
						setup:addSimpleRow({ 
							Helper.createFontString(item.station and string.format((item.isbuyoffer and ReadText(1001, 2976) or ReadText(1001, 2975)) .. profittext .. "\n" .. ReadText(1001, 2977), ConvertIntegerString(item.amount, true, nil, true), item.name, ConvertMoneyString(RoundTotalTradePrice(item.price * item.amount), false, true, nil, true), item.stationname, cluster, sector, zone) or string.format((item.isbuyoffer and ReadText(1001, 2976) or ReadText(1001, 2975)), ConvertIntegerString(item.amount, true, nil, true), item.name, ConvertMoneyString(RoundTotalTradePrice(item.price * item.amount), false, true, nil, true)), false, "left", nil, nil, nil, nil, nil, nil, true, nil, nil, 0, Helper.standardSizeX)
						}, "shoppinglist", {4})
					end
				end
			end
		end
	end
	
	setup:addHeaderRow({
		ReadText(1001, 1503)
	}, nil, {4})
	setup:addSimpleRow({
		ReadText(1001, 4201),
		Helper.unlockInfo(menu.unlocked.managed_ships, #subordinates)
	}, "subordinates", {3, 1})
	
	-- entity settings for player owned only
	if owner == "player" then
		if (menu.typestring == "manager") or (menu.typestring == "architect") then
			menu.subordinaterangecomponent = GetNPCBlackboard(menu.entity, "$config_subordinate_range")
			local subordinaterangecomponenttype
			if not menu.subordinaterangecomponent then
				if GetComponentData(container, "maxradarrange") > 30000 then
					menu.subordinaterangecomponent = GetContextByClass(container, "cluster")
					subordinaterangecomponenttype = ReadText(20001, 101)
				else
					menu.subordinaterangecomponent = GetContextByClass(container, "sector")
					subordinaterangecomponenttype = ReadText(20001, 201)
				end
			else
				if IsComponentClass(menu.subordinaterangecomponent, "cluster") then
					subordinaterangecomponenttype = ReadText(20001, 101)
				elseif IsComponentClass(menu.subordinaterangecomponent, "sector") then
					subordinaterangecomponenttype = ReadText(20001, 201)
				elseif IsComponentClass(menu.subordinaterangecomponent, "zone") then
					subordinaterangecomponenttype = ReadText(20001, 301)
				elseif IsComponentClass(menu.subordinaterangecomponent, "galaxy") then
					subordinaterangecomponenttype = ReadText(20001, 901)
				end
			end
			setup:addSimpleRow({
				ReadText(1001, 4212),
				subordinaterangecomponenttype
			}, "subordinaterange", {3, 1})
		end

		local numMissions   = GetNumMissions()
		local missionList = {}

		for i = 1, numMissions do
			local missionID, name, description, difficulty, maintype, subtype, faction, reward, rewardtext, _, _, _, _, missiontime, _, abortable, disableguidance, associatedcomponent = GetMissionDetails(i, Helper.standardFont, Helper.standardFontSize, Helper.scaleX(425))
			local objectiveText, objectiveIcon, timeout, progressname, curProgress, maxProgress = GetMissionObjective(i, Helper.standardFont, Helper.standardFontSize, Helper.scaleX(425))
			if IsSameComponent(associatedcomponent, menu.entity) then
				local entry = {
					["active"] = (i == activeMission),
					["name"] = name,
					["description"] = description,
					["difficulty"] = difficulty,
					["type"] = subtype,
					["faction"] = faction,
					["reward"] = reward,
					["rewardtext"] = rewardtext,
					["objectiveText"] = objectiveText,
					["objectiveIcon"] = objectiveIcon,
					["timeout"] = (timeout and timeout ~= -1) and timeout or (missiontime or -1),		-- timeout can be nil, if mission has no objective
					["progressName"] = progressname,
					["curProgress"] = curProgress,
					["maxProgress"] = maxProgress or 0,	-- maxProgress can be nil, if mission has n objective
					["component"] = associatedcomponent,
					["disableguidance"] = disableguidance,
					["ID"] = missionID,
					["associatedcomponent"] = associatedcomponent
				}
				table.insert(missionList, entry)
			end
		end
		if #missionList > 0 then
			setup:addHeaderRow({
				ReadText(1001, 5702)
			}, nil, {4})
			for _, entry in ipairs(missionList) do
				setup:addSimpleRow({
					Helper.createIcon("missionoffer_" .. entry.type .. "_active", false, nil, nil, nil, nil, 0, 0, 2 * Helper.standardTextHeight, 2 * Helper.standardTextHeight), 
					Helper.createFontString(entry.name .. (entry.difficulty == 0 and "" or " [" .. ConvertMissionLevelString(entry.difficulty) .. "]") .. (entry.disableguidance and " [" .. ReadText(1001, 3311) .. "]" or "") .. "\n     " .. (entry.objectiveText or ""), false, "left", 255, 255, 255, 100, Helper.standardFont, Helper.standardFontSize, true)
				}, {"mission", entry.ID}, {2, 2})
			end
		end
	end
	
	-- setup:addFillRows(14)

	local selectdesc = setup:createCustomWidthTable({Helper.scaleX(Helper.standardButtonWidth), Helper.scaleX(2 * Helper.standardTextHeight - Helper.standardButtonWidth) - 5, 0, Helper.scaleX(500)}, false, true, true, 1, 0, 0, Helper.scaleY(Helper.tableCharacterOffsety), Helper.scaleY(450), false, menu.toprow, menu.selectrow)
	menu.toprow = nil
	menu.selectrow = nil

	-- button table
	setup = Helper.createTableSetup(menu)

	local blackboard_shiptrader_docking = GetNPCBlackboard(menu.entity, "$shiptrader_docking")
	blackboard_shiptrader_docking = blackboard_shiptrader_docking and blackboard_shiptrader_docking ~= 0
	local blackboard_ship_parking = GetNPCBlackboard(menu.entity, "$ship_parking")
	blackboard_ship_parking = blackboard_ship_parking and blackboard_ship_parking ~= 0
	local isdocked, isdocking = GetComponentData(menu.container, "isdocked", "isdocking")
	local commander = GetCommander(menu.container)
	local neworder_active = (not blackboard_shiptrader_docking) and (not blackboard_ship_parking) and (not isdocked) and (not isdocking) and ((not commander) or IsSameComponent(commander, GetPlayerPrimaryShipID()))

	setup:addSimpleRow({ 
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 2669), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_B", true)),
		Helper.getEmptyCellDescriptor(),
		((owner == "player") and ((menu.typestring == "pilot") or (menu.typestring == "commander"))) and Helper.createButton(Helper.createButtonText(ReadText(1002, 2020), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, neworder_active, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_BACK", true), nil, neworder_active and "" or ReadText(1026, 20004)) or Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 3216), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_Y", true), nil, ReadText(1026, 4200)),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 2961), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true)),
		Helper.getEmptyCellDescriptor()
	}, nil, nil, false, menu.transparent)
	local buttondesc = setup:createCustomWidthTable({48, 150, 48, 150, 0, 150, 48, 150, 48}, false, false, true, 2, 1, 0, 555, 0, false)

	-- create tableview
	menu.infotable, menu.selecttable, menu.buttontable = Helper.displayThreeTableView(menu, infodesc, selectdesc, buttondesc, false)

	local nooflines = 4
	if #aicommandstack > 0 then
		for i, command in ipairs(aicommandstack) do
			nooflines = nooflines + 1
		end
	else
		nooflines = nooflines + 1
	end
	if aicommandaction ~= "" then
		nooflines = nooflines + 1
	end

	-- entity settings for player owned only
	if owner == "player" then
		local addedblackline = false
		if hasownaccount then
			if not addedblackline then
				addedblackline = true
				nooflines = nooflines + 1
			end
			nooflines = nooflines + 1

			if menu.typestring == "architect" then
				nooflines = nooflines + 1
			elseif menu.typestring == "manager" then
				local line = nooflines
				Helper.setButtonScript(menu, nil, menu.selecttable, line, 1, function () return menu.buttonExtend("wantedmoney", line) end)
				nooflines = nooflines + 1
			end
		end
	end
	
	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 2, function () return menu.onCloseElement("back") end)
	if (owner == "player") and ((menu.typestring == "pilot") or (menu.typestring == "commander")) then
		Helper.setButtonScript(menu, nil, menu.buttontable, 1, 4, menu.buttonNewOrder)
	end
	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 6, menu.buttonComm)
	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 8, menu.buttonDetails)

	-- clear descriptors again
	Helper.releaseDescriptors()
end

function Funcs.yvgstr_onRowChanged(row, rowdata)
	local menu = yvgstr_menu
	
	if menu.rowDataMap[Helper.currentDefaultTableRow] then
		rowdata = menu.rowDataMap[Helper.currentDefaultTableRow]
		Helper.removeButtonScripts(menu, menu.buttontable, 1, 8)
		local name
		if rowdata == "command" or rowdata == "subordinaterange" or rowdata == "budget" or (rowdata == "restrictions" and menu.typestring == "architect") or rowdata == "refuel_auto" then
			name = ReadText(1001, 3105)
		elseif rowdata == "shoppinglist" then
			name = ReadText(1001, 73)
		elseif rowdata == "comeaboard" then
			name = ReadText(1001, 4227)
		else
			name = ReadText(1001, 2961)
		end
		local active = false
		if rowdata ~= nil then
			if (rowdata ~= "command") or (menu.owner == "player") then
				local aicommand = GetComponentData(menu.entity, "aicommandraw")
				if (rowdata ~= "comeaboard") or ((menu.owner == "player") and (not GetCommander(menu.container)) and (not IsComponentClass(menu.object, "drone")) and (C.GetDistanceBetween(ConvertIDTo64Bit(menu.container), ConvertIDTo64Bit(GetPlayerPrimaryShipID())) < 60000) and (C.GetPlayerShipNumFreeActorSlots() > 0) and ((aicommand == "") or (aicommand == "follow") or (aicommand == "wait")) and C.HasCustomConversation(ConvertIDTo64Bit(menu.entity))) then
					active = true
				end
			end
		end
		local mot_details
		if rowdata == "skills" then
			mot_details = ReadText(1026, 4201)
		elseif rowdata == "comeaboard" then
			mot_details = ReadText(1026, 4202)
		elseif rowdata == "refuel_auto" then
			mot_details = ReadText(1026, 4204)
		elseif rowdata == "supply" then
			mot_details = ReadText(1026, 4216)
		elseif rowdata == "subordinates" then
			mot_details = ReadText(1026, 4207)
		elseif rowdata == "container" then
			mot_details = IsComponentClass(menu.container, "station") and ReadText(1026, 4209) or ReadText(1026, 4208)
		elseif rowdata == "budget" then
			mot_details = ReadText(1026, 4210)
		elseif rowdata == "restrictions" then
			mot_details = ReadText(1026, 4211)
		elseif rowdata == "priceoverrides" then
			mot_details = ReadText(1026, 4212)
		elseif rowdata == "tradewares" then
			mot_details = ReadText(1026, 4212)
		elseif rowdata == "subordinaterange" then
			mot_details = ReadText(1026, 4214)
		elseif rowdata == "mission" then
			mot_details = ReadText(1026, 4215)
		end
		SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(name, "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, active, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true), nil, active and mot_details or nil), 1, 8)
		Helper.setButtonScript(menu, nil, menu.buttontable, 1, 8, menu.buttonDetails)

		local helptext = ""
		local helpcolor = menu.white
		if rowdata == "subordinaterange" then
			if GetComponentData(menu.container, "maxradarrange") <= 30000 then
				helptext = string.format(ReadText(1001, 4225), GetRadarModuleName(menu.container))
				helpcolor = menu.red
			end
		end
		Helper.updateCellText(menu.infotable, 2, 1, helptext, helpcolor)
	else
		Helper.removeButtonScripts(menu, menu.buttontable, 1, 8)
		SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(1001, 2961), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, false, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true)), 1, 8)
	end
end

init()