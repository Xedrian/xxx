-- section == gMain_object, gMain_object_closeup
-- param == { 0, 0, object [, map history] [, extendedcategories] }

-- ffi setup
local ffi = require("ffi")
local C = ffi.C
ffi.cdef [[
	typedef uint64_t UniverseID;
	typedef struct {
		const char* macro;
		const char* ware;
		uint32_t amount;
		uint32_t capacity;
	} AmmoData;
	typedef struct {
		int64_t trade;
		int64_t defence;
		int64_t missile;
	} SupplyBudget;
	typedef struct {
		uint32_t ID;
		const char* Name;
		const char* RawName;
		const char* WeaponMacro;
		const char* Ware;
		float DamageFactor;
		float CoolingFactor;
		float ReloadFactor;
		float SpeedFactor;
		float LifeTimeFactor;
		float MiningFactor;
		float StickTimeFactor;
		float ChargeTimeFactor;
		float BeamLengthFactor;
		uint32_t AddedAmount;
	} UIWeaponMod;
	uint32_t GetAmmoStorage(AmmoData* result, uint32_t resultlen, UniverseID defensibleid, const char* ammotype);
	bool GetInstalledWeaponMod(UniverseID weaponid, UIWeaponMod* weaponmod);
	uint32_t GetNumAmmoStorage(UniverseID defensibleid, const char* ammotype);
	SupplyBudget GetSupplyBudget(UniverseID containerid);
	bool IsPlayerCameraTargetViewPossible(UniverseID targetid, bool force);
	bool IsVRVersion(void);
	void SetPlayerCameraCockpitView(bool force);
	void SetPlayerCameraTargetView(UniverseID targetid, bool force);
]]

local menu = {}

local override = {
	name = "ObjectMenu",
	updateInterval = 2.0,
	hasStorageStatus = nil,
	hasDefenceStatus = nil
}

function override.cleanup()
	menu.type = nil
	menu.title = nil
	menu.object = nil
	menu.category = nil
	menu.unlocked = {}
	menu.playership = nil
	menu.data = {}
	menu.settoprow = nil
	menu.setselectedrow = nil
	menu.isplayership = nil
	menu.isplayer = nil
	menu.hasunit = nil
	menu.sellbuyswitch = nil
	menu.dontdisplaytradequeue = nil
	menu.tradequeuestart = nil
	menu.infotext = nil
	menu.traderestrictions = nil
	menu.buildingarchitect = nil
	menu.buildingcontainer = nil
	menu.container = nil

	menu.buttontable = nil
	menu.selecttable = nil

	menu.hasStorageStatus = nil
	menu.hasDefenceStatus = nil

	menu.weeaponLibPrimary = nil
	menu.weeaponLibSecondary = nil
	menu.turretLib = nil
end

function override.findUpgradeTurretMacroByName(upgradeName)
	local ret
	for _, item in ipairs(menu.turretLib) do
		if item.name == upgradeName then
			ret = item.id
			break
		end
	end
	return ret
end

function override.displayMenu()
	-- Remove possible button scripts from previous view
	Helper.removeAllButtonScripts(menu)
	Helper.currentTableRow = {}
	Helper.currentTableRowData = nil
	menu.rowDataMap = {}
	if not IsComponentOperational(menu.object) and not IsComponentConstruction(menu.object) then
		Helper.closeMenuAndReturn(menu)
		menu.cleanup()
	else
		menu.selecttable, menu.buttontable = Helper.displayTwoTableView(menu, menu.createTableSelect(), menu.createTableButton(), false)
		menu.addButtonScripts()
		Helper.releaseDescriptors()
	end
end

function override.onUpdate()
	if IsComponentOperational(menu.object) or IsComponentConstruction(menu.object) then
		local nooflines = 3
		--- General ---
		nooflines = nooflines + 1
		if menu.extendedcategories.general then
			nooflines = nooflines + 1
			if menu.type == "block" then
				nooflines = nooflines + 1
			end
			nooflines = nooflines + 2
			if not IsComponentClass(menu.object, "ship_xl") and not IsComponentClass(menu.object, "ship_l") and not IsComponentClass(menu.object, "station") and menu.type ~= "block" then
				nooflines = nooflines + 1
			end
			if IsComponentClass(menu.object, "ship") then
				nooflines = nooflines + 2
			end
			if menu.data.radarrange > 0 then
				nooflines = nooflines + 1
			end
			if menu.type == "block" and menu.data.efficiencybonus > 0 then
				nooflines = nooflines + 1
			end
			if (menu.type == "station") or ((menu.type == "ship") and GetBuildAnchor(menu.object)) then
				nooflines = nooflines + 1
			end
			if IsComponentClass(menu.object, "ship_xl") or IsComponentClass(menu.object, "ship_l") then
				nooflines = nooflines + 1
			elseif menu.isplayership and GetComponentData(menu.object, "boardingnpc") then
				nooflines = nooflines + 1
			end
		end

		--- NPCs ---
		if menu.type ~= "block" and not menu.isplayership then
			nooflines = nooflines + 1
			if menu.extendedcategories.npcs then
				for i, npc in ipairs(menu.data.controlentities) do
					Helper.updateCellText(menu.selecttable, nooflines, 4, Helper.unlockInfo(menu.unlocked.operator_commands, Helper.parseAICommand(npc)))
					nooflines = nooflines + 1
					if menu.unlocked.managed_ships and #menu.data.npcs[tostring(npc)] > 0 then
						-- nooflines = nooflines + 1 --
						if menu.extendedcategories["npcs" .. tostring(npc)] then
							for i, component in ipairs(menu.data.npcs[tostring(npc)]) do
								nooflines = nooflines + 1
							end
							if i ~= #menu.data.controlentities then
								nooflines = nooflines + 1
							end
						end
					end
				end
			end
		end

		--- NPCS II ---
		if menu.type == "station" then
			nooflines = nooflines + 1
		end

		--- Upkeep Missions ---
		if not menu.isplayership and menu.isplayer then
			if #menu.data.upkeep > 0 then
				nooflines = nooflines + 1
				if menu.extendedcategories.upkeep then
					for _, entry in ipairs(menu.data.upkeep) do
						nooflines = nooflines + 1
					end
				end
			end
		end

		--- Production ---
		if menu.data.productionmodules and #menu.data.productionmodules > 0 then
			nooflines = nooflines + 1
			if menu.extendedcategories.production then
				for _, module in ipairs(menu.data.productionmodules) do
					if IsComponentOperational(module) then
						if menu.unlocked[module].production_time then
							local proddata = GetProductionModuleData(module)
							if next(proddata) then
								if proddata.state ~= "producing" or proddata.remainingtime > 0 then
									Helper.updateCellText(menu.selecttable, nooflines, 5, ConvertTimeString(proddata.remainingtime, "%h" .. ReadText(1001, 102) .. " %M" .. ReadText(1001, 103) .. " %S" .. ReadText(1001, 100)))
								end
							end
						end
					else
						Helper.updateCellText(menu.selecttable, nooflines + i, 1, GetComponentData(module), { r = 255, g = 0, b = 0, a = 100 })
						Helper.updateCellText(menu.selecttable, nooflines + i, 3, "---")
						Helper.updateCellText(menu.selecttable, nooflines + i, 4, "---")
						Helper.removeButton(menu, menu.selecttable, nooflines + i, 5)
					end
					nooflines = nooflines + 1
				end
			end
		end
	end
end

function override.onRowChanged(row, rowdata)
	if IsComponentOperational(menu.object) or IsComponentConstruction(menu.object) then
		local override = false
		if menu.isplayer and rowdata then
			if rowdata[1] == "npccategory" then
				local hasmanager = GetComponentData(menu.object, "tradenpc")
				if menu.type == "station" and not hasmanager then
					override = true
					Helper.updateCellText(menu.selecttable, 2, 1, menu.infotext .. " - \27R" .. ReadText(1001, 1118) .. "\27X")
				elseif rowdata[2] then
					override = true
					Helper.updateCellText(menu.selecttable, 2, 1, menu.infotext .. " - \27Y" .. ReadText(1001, 1130) .. "\27X")
				end
			elseif rowdata[1] == "productioncategory" then
				local allproducing = true
				for i = #menu.data.productionmodules, 1, -1 do
					if IsComponentOperational(menu.data.productionmodules[i]) then
						if allproducing then
							if not GetComponentData(menu.data.productionmodules[i], "isproducing") then
								allproducing = false
							end
						end
					end
				end
				if not allproducing then
					override = true
					Helper.updateCellText(menu.selecttable, 2, 1, menu.infotext .. " - \27R" .. ReadText(1001, 1119) .. "\27X")
				end
			elseif rowdata[1] == "production" then
				local proddata = menu.data.proddata[tostring(rowdata[2])]
				if proddata.state == "waitingforresources" then
					override = true
					Helper.updateCellText(menu.selecttable, 2, 1, menu.infotext .. " - \27R" .. ReadText(1001, 1120) .. "\27X")
				elseif proddata.state == "waitingforstorage" then
					override = true
					Helper.updateCellText(menu.selecttable, 2, 1, menu.infotext .. " - \27R" .. ReadText(1001, 1121) .. "\27X")
				elseif not GetComponentData(rowdata[2], "isfunctional") then
					override = true
					Helper.updateCellText(menu.selecttable, 2, 1, menu.infotext .. " - \27R" .. ReadText(1001, 1122) .. "\27X")
				end
			elseif rowdata[1] == "storage" then
				if rowdata[2] == 2 then
					override = true
					Helper.updateCellText(menu.selecttable, 2, 1, menu.infotext .. " - \27R" .. ReadText(1001, 1123) .. "\27X")
				elseif rowdata[2] == 1 then
					override = true
					Helper.updateCellText(menu.selecttable, 2, 1, menu.infotext .. " - \27Y" .. ReadText(1001, 1124) .. "\27X")
				end
			elseif rowdata[1] == "ware" then
				if rowdata[2] then
					override = true
					Helper.updateCellText(menu.selecttable, 2, 1, menu.infotext .. " - \27R" .. ReadText(1001, 1125) .. "\27X")
				else
					override = true
					Helper.updateCellText(menu.selecttable, 2, 1, menu.infotext .. " - \27Y" .. ReadText(1001, 1126) .. "\27X")
				end
			elseif rowdata[1] == "npc" and rowdata[3] ~= nil then
				if not rowdata[3] then
					override = true
					Helper.updateCellText(menu.selecttable, 2, 1, menu.infotext .. " - \27Y" .. ReadText(1001, 1128) .. "\27X")
				elseif not rowdata[4] then
					override = true
					Helper.updateCellText(menu.selecttable, 2, 1, menu.infotext .. " - \27Y" .. ReadText(1001, 1129) .. "\27X")
				end
			end
		end
		if not override then
			Helper.updateCellText(menu.selecttable, 2, 1, menu.infotext)
		end

		-- DETAILS
		Helper.removeButtonScripts(menu, menu.buttontable, 1, 8)
		if rowdata and rowdata[1] == "name" then
			local active = (menu.type ~= "block") and menu.isplayer
			local mot_rename
			if active then
				if menu.type == "station" then
					mot_rename = ReadText(1026, 1110)
				elseif menu.type == "ship" then
					mot_rename = ReadText(1026, 1101)
				end
			elseif not menu.isplayer then
				if menu.type == "station" then
					mot_rename = ReadText(1026, 1111)
				end
			end
			SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(1001, 1114), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, active, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true), nil, mot_rename), 1, 8)
		elseif rowdata and rowdata[1] == "zone" then
			local rename = (menu.type == "station") and (GetComponentData(menu.object, "owner") == "player") and GetComponentData(GetComponentData(menu.object, "zoneid"), "istemporaryzone")
			local mot_showonmap
			if not rename then
				if menu.type == "station" then
					mot_showonmap = ReadText(1026, 1112)
				elseif menu.type == "ship" then
					mot_showonmap = ReadText(1026, 1102)
				end
			end
			SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(rename and ReadText(1001, 1114) or ReadText(1001, 3408), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true), nil, mot_showonmap), 1, 8)
		elseif rowdata and rowdata[1] == "tradequeue" then
			SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(1001, 73), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, (menu.type ~= "block") and (GetComponentData(menu.object, "owner") == "player"), 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true)), 1, 8)
		elseif rowdata and (rowdata[1] == "npccategory" or rowdata[1] == "productioncategory" or rowdata[1] == "ware") then
			SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(1001, 2961), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, false, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true)), 1, 8)
		elseif rowdata and rowdata[1] == "npc" then
			SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(1001, 2961), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, menu.unlocked.operator_name, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true), nil, menu.unlocked.operator_name and ReadText(1026, 1103) or nil), 1, 8)
		elseif rowdata and rowdata[1] == "weapons" then
			SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(1001, 2961), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, menu.isplayership, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true), nil, menu.isplayership and ReadText(1026, 1126) or ""), 1, 8)
		else
			local mot_details
			if rowdata then
				if rowdata[1] == "npcs" then
					if menu.type == "station" then
						mot_details = ReadText(1026, 1113)
					end
				elseif rowdata[1] == "storage" then
					if menu.type == "station" then
						mot_details = ReadText(1026, 1114)
					elseif menu.type == "ship" then
						mot_details = ReadText(1026, 1121)
					end
				elseif rowdata[1] == "upkeep" then
					mot_details = ReadText(1026, 1115)
				elseif rowdata[1] == "production" then
					mot_details = ReadText(1026, 1116)
				end
			end
			SetCellContent(menu.buttontable, Helper.createButton(Helper.createButtonText(ReadText(1001, 2961), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, rowdata ~= nil, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true), nil, mot_details), 1, 8)
		end
		Helper.setButtonScript(menu, nil, menu.buttontable, 1, 8, menu.buttonDetails)
	end
end

function override.addControlEntity(setup, entity, last)
	if entity then
		local name, typestring, typeicon, typename, iscontrolentity = GetComponentData(entity, "name", "typestring", "typeicon", "typename", "iscontrolentity")
		local aicommand = Helper.parseAICommand(entity)
		local hasmoney = true
		local noMoneyState = 0
		local hasrange = true

		local ships = {}

		if typestring ~= "architect" then
			ships = GetSubordinates(GetContextByClass(entity, "controllable"), typestring)
			for i = #ships, 1, -1 do
				if GetBuildAnchor(ships[i]) then
					table.remove(ships, i)
				elseif IsComponentClass(ships[i], "drone") then
					table.remove(ships, i)
				end
			end
		end
		menu.data.npcs[tostring(entity)] = ships

		local showShips = #ships > 0 and menu.unlocked.managed_ships

		if menu.isplayer then
			if typestring == "manager" or typestring == "architect" then
				if IsSameComponent(entity, buildingarchitect) then
					local buildingtraderestrictions = GetTradeRestrictions(buildingcontainer)
					if not buildingtraderestrictions.faction then
						if GetComponentData(entity, "wantedmoney") > GetAccountData(entity, "money") then
							hasmoney = false
							noMoneyState = noMoneyState + 1
						end
					end
				else
					local wantedmoney = 0
					if typestring == "architect" then
						wantedmoney = GetComponentData(entity, "wantedmoney")
					else
						wantedmoney = GetComponentData(entity, "productionmoney")
						local supplybudget = C.GetSupplyBudget(ConvertIDTo64Bit(menu.object))
						wantedmoney = wantedmoney + tonumber(supplybudget.trade) / 100 + tonumber(supplybudget.defence) / 100 + tonumber(supplybudget.missile) / 100
					end
					if not menu.traderestrictions.faction then
						if wantedmoney > GetAccountData(entity, "money") then
							hasmoney = false
							noMoneyState = noMoneyState + 1
						end
					end
				end
			end
			if typestring == "manager" then
				if menu.traderestrictions.faction then
					local subordinaterangecomponent = GetNPCBlackboard(entity, "$config_subordinate_range")
					if not subordinaterangecomponent then
						if GetComponentData(menu.object, "maxradarrange") > 30000 then
							subordinaterangecomponent = GetContextByClass(menu.object, "cluster")
						else
							subordinaterangecomponent = GetContextByClass(menu.object, "sector")
						end
					end
					hasrange = IsContainerOperationalRangeSufficient(menu.object, subordinaterangecomponent)
				end
			end
		end
		if menu.isplayer and (not hasmoney or not hasrange) then
			setup:addSimpleRow({
				showShips and #ships and Helper.createButton(Helper.createButtonText(menu.extendedcategories["npcs" .. tostring(entity)] and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight) or "",
				-- Helper.createIcon(typeicon, false, 255, 255, 255, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight),
				xxxLibrary.createNpcBookmarkIconButton(entity, menu.unlocked.operator_name),
				typename .. " " .. Helper.unlockInfo(menu.unlocked.operator_name, name),
				iscontrolentity and Helper.unlockInfo(menu.unlocked.operator_commands, aicommand) or Helper.getEmptyCellDescriptor(),
				Helper.createIcon(not hasmoney and "xxx_credits" or "workshop_error", false, 192, 192, 0, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight)
			}, { "npc", entity, hasmoney, hasrange }, { 1, 1, 1, 3, 1 })
		else
			setup:addSimpleRow({
				showShips and #ships and Helper.createButton(Helper.createButtonText(menu.extendedcategories["npcs" .. tostring(entity)] and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight) or "",
				-- Helper.createIcon(typeicon, false, 255, 255, 255, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight),
				xxxLibrary.createNpcBookmarkIconButton(entity, menu.unlocked.operator_name),
				typename .. " " .. Helper.unlockInfo(menu.unlocked.operator_name, name),
				iscontrolentity and Helper.unlockInfo(menu.unlocked.operator_commands, aicommand) or Helper.getEmptyCellDescriptor()
			}, { "npc", entity }, { 1, 1, 1, 4 })
		end



		-- local ships = {}



		if showShips then
			if menu.extendedcategories["npcs" .. tostring(entity)] then
				--[[
				setup:addSimpleRow({
					Helper.createButton(Helper.createButtonText(menu.extendedcategories["npcs" .. tostring(entity)] and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
					"  " .. #ships .. " " .. (#ships == 1 and ReadText(1001, 5) or ReadText(1001, 6)),
					ReadText(1001, 16),
					ReadText(1001, 12)
				}, nil, {1, 2, 2, 2}, false, Helper.defaultHeaderBackgroundColor)
				]]

				for i, component in ipairs(ships) do
					local controlentity = GetComponentData(component, "controlentity")
					local aicommand = Helper.parseAICommand(controlentity)
					local data = { name = GetComponentData(component, "name"), aicommand = aicommand, hullpercent = GetComponentData(component, "hullpercent") }
					menu.unlocked[component] = { name = IsInfoUnlockedForPlayer(menu.object, "operator_commands"), operator_commands = IsInfoUnlockedForPlayer(component, "operator_commands") }

					setup:addSimpleRow({
						Helper.getEmptyCellDescriptor(),
						Helper.createButton(nil, Helper.createButtonIcon("menu_info", nil, 255, 255, 255, 100), false, menu.unlocked[component].name),
						xxxLibrary.indentSubordinateName(Helper.unlockInfo(menu.unlocked[component].name, data.name), 1),
						Helper.unlockInfo(menu.unlocked[component].operator_commands, aicommand),
						Helper.getStatusBar(data.hullpercent, Helper.scaleY(menu.statusHeight), Helper.scaleX(menu.statusWidth - 5) + 5, true)
					}, { "ship", component }, { 1, 1, 1, 2, 2 })

					if IsComponentClass(component, "station") then
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
				end
				if not last then
					setup:addHeaderRow({ Helper.createFontString("", false, Helper.standardHalignment, Helper.standardColor.r, Helper.standardColor.g, Helper.standardColor.b, Helper.standardColor.a, Helper.standardFont, 6, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, 6) }, nil, { 7 })
				end
			end
		end
	end
end

-- table creation

function override.createTableSelect()
	local setup = Helper.createTableSetup(menu)
	menu.createSectionInfoline(setup)
	menu.createSectionGeneral(setup)
	menu.createSectionEmployees(setup)
	menu.createSectionUpkeep(setup)
	menu.createSectionProduction(setup)
	menu.createSectionStorage(setup)
	menu.createSectionTradequeue(setup)
	menu.createSectionUnits(setup)
	menu.createSectionWeapons(setup)
	menu.createSectionAmmunition(setup)
	menu.createSectionPlayshipUpgrades(setup)
	menu.createSectionStatistics(setup)
	setup:addFillRows(18 - (menu.extendedcategories.tradequeue and #menu.data.tradequeue or 0), nil, { 6 })
	return setup:createCustomWidthTable({ Helper.standardTextHeight, Helper.standardTextHeight, 0, 250, menu.statusWidth, menu.statusWidth - Helper.standardTextHeight - 5, Helper.standardTextHeight }, false, false, true, 1, 2, 0, 0, 550, true, menu.settoprow, menu.setselectedrow)
end

function override.createPlayershipCategory(setup, category, title, none)
	local upgrades = GetAllUpgrades(menu.object, true, category)
	local factor = 1
	if category == "engine" then
		factor = 0.5
	end

	local totalslots = 0
	if category == "software" then
		local organizeupgrades = {}

		for ut, upgrade in Helper.orderedPairs(upgrades) do
			if not (ut == "totaltotal" or ut == "totalfree" or ut == "totaloperational" or ut == "totalconstruction" or ut == "estimated") then
				local index = menu.findbytag(organizeupgrades, upgrade.tags)
				if not index then
					totalslots = totalslots + 1
					table.insert(organizeupgrades, upgrade.tags)
				end
			end
		end
	else
		totalslots = upgrades.totaltotal
	end

	setup:addHeaderRow({
		Helper.getEmptyCellDescriptor(),
		title,
		ReadText(1001, 3103) .. " (" .. factor * upgrades.totaloperational .. " / " .. factor * totalslots .. ")"
	}, nil, { 1, 3, 3 })
	local displayed = false
	for ut, upgrade in Helper.orderedPairs(upgrades) do
		if not (ut == "totaltotal" or ut == "totalfree" or ut == "totaloperational" or ut == "totalconstruction" or ut == "estimated") then
			if upgrade.operational ~= 0 then
				displayed = true
				setup:addSimpleRow({
					"",
					Helper.createButton(nil, Helper.createButtonIcon(GetWareData(upgrade.ware, "icon"), nil, 255, 255, 255, 100), false),
					upgrade.name,
					Helper.createFontString(factor * upgrade.operational, false, "right")
				}, nil, { 1, 1, 2, 3 })
				AddKnownItem("wares", upgrade.ware)
			end
		end
	end
	if not displayed then
		setup:addSimpleRow({
			Helper.getEmptyCellDescriptor(),
			"--- " .. none .. " ---"
		}, nil, { 1, 6 })
	end
end

function override.createPlayershipCategoryButtons(category, nooflines)
	local upgrades = GetAllUpgrades(menu.object, true, category)
	nooflines = nooflines + 1
	local displayed = false
	for ut, upgrade in Helper.orderedPairs(upgrades) do
		if not (ut == "totaltotal" or ut == "totalfree" or ut == "totaloperational" or ut == "totalconstruction" or ut == "estimated") then
			if upgrade.operational ~= 0 then
				displayed = true
				Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 2, function()
					return menu.buttonEncyclopediaCategory("ware", upgrade.ware)
				end)
				nooflines = nooflines + 1
			end
		end
	end
	if not displayed then
		nooflines = nooflines + 1
	end

	return nooflines
end

function override.createSectionInfoline(setup)
	setup:addSimpleRow({
		Helper.createButton(nil, Helper.createButtonIcon("menu_info", nil, 255, 255, 255, 100), false),
		Helper.createFontString(menu.title .. (menu.isplayer and "" or " (" .. GetComponentData(menu.object, "revealpercent") .. " %)"), false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, Helper.headerRow1Height, Helper.headerRow1Width)
	}, nil, { 1, 6 }, false, Helper.defaultTitleBackgroundColor)

	local commander
	if menu.type ~= "block" then
		commander = GetCommander(menu.object)
	end
	menu.unlocked.operator_name = IsInfoUnlockedForPlayer(menu.object, "operator_name")
	local zonename = GetComponentData(menu.object, "zone")
	menu.infotext = (commander and (ReadText(1001, 1112) .. ReadText(1001, 120) .. " " .. Helper.unlockInfo(menu.unlocked.operator_name, GetComponentData(commander, "name")) .. ", ") or "") .. ReadText(1001, 10) .. ReadText(1001, 120) .. " " .. zonename
	setup:addTitleRow({
		Helper.createFontString(menu.infotext, false, "left", 129, 160, 182, 100, Helper.headerRow2Font, Helper.headerRow2FontSize, false, Helper.headerRow2Offsetx, Helper.headerRow2Offsety, Helper.headerRow2Height, Helper.headerRow1Width) -- text depends on selection
	}, nil, { 7 })
end

function override.createSectionGeneral(setup)
	--- General ---
	if not menu.extendedcategories.general then
		setup:addSimpleRow({
			Helper.createButton(Helper.createButtonText(menu.extendedcategories.general and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
			ReadText(1001, 1111)
		}, nil, { 1, 6 }, false, Helper.defaultHeaderBackgroundColor)
	else
		setup:addSimpleRow({
			Helper.createButton(Helper.createButtonText(menu.extendedcategories.general and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
			ReadText(1001, 1111),
			ReadText(1001, 13),
			ReadText(1001, 12)
		}, nil, { 1, 2, 2, 2 }, false, Helper.defaultHeaderBackgroundColor)

		setup:addSimpleRow({
			Helper.getEmptyCellDescriptor(),
			ReadText(1001, 2809),
			Helper.unlockInfo(menu.unlocked.name, GetComponentData(menu.object, "name"))
		}, { "name" }, { 1, 2, 4 })

		if menu.type == "block" then
			setup:addSimpleRow({
				Helper.getEmptyCellDescriptor(),
				ReadText(1001, 1134),
				Helper.unlockInfo(menu.unlocked[tostring(menu.container)].name, GetComponentData(menu.container, "name"))
			}, { "partof" }, { 1, 2, 4 })
		end
		local zonename = GetComponentData(menu.object, "zone")
		setup:addSimpleRow({
			Helper.getEmptyCellDescriptor(),
			ReadText(1001, 10),
			Helper.unlockInfo(menu.unlocked.name, zonename)
		}, { "zone" }, { 1, 2, 4 })

		menu.data.hull, menu.data.hullmax, menu.data.hullpercent = GetComponentData(menu.object, "hull", "hullmax", "hullpercent")
		setup:addSimpleRow({
			Helper.getEmptyCellDescriptor(),
			ReadText(1001, 1),
			Helper.createFontString(string.format("%s / %s (%d %%)", ConvertIntegerString(menu.data.hull, true, 4, true), ConvertIntegerString(menu.data.hullmax, true, 4, true), menu.data.hullpercent), false, "right"),
			Helper.getStatusBar(menu.data.hullpercent, Helper.scaleY(menu.statusHeight), Helper.scaleX(menu.statusWidth - 5) + 5, true)
		}, nil, { 1, 2, 2, 2 })
		if not IsComponentClass(menu.object, "ship_xl") and not IsComponentClass(menu.object, "ship_l") and not IsComponentClass(menu.object, "station") and menu.type ~= "block" then
			menu.data.shield, menu.data.shieldmax, menu.data.shieldpercent = GetComponentData(menu.object, "shield", "shieldmax", "shieldpercent")
			if menu.isplayership then
				local shieldgens = GetComponentData(menu.object, "shieldgenerators")
				local hull = 0
				for _, shieldgen in ipairs(shieldgens) do
					hull = hull + GetComponentData(shieldgen, "hullpercent")
				end
				menu.data.shieldgenhull = hull / #shieldgens
				setup:addSimpleRow({
					Helper.getEmptyCellDescriptor(),
					ReadText(1001, 2),
					Helper.createFontString(string.format("%s / %s (%d %%)", ConvertIntegerString(menu.data.shield, true, 4, true), ConvertIntegerString(menu.data.shieldmax, true, 4, true), menu.data.shieldpercent), false, "right"),
					Helper.getStatusBar(menu.data.shieldgenhull, Helper.scaleY(menu.statusHeight), Helper.scaleX(menu.statusWidth - 5) + 5, true)
				}, nil, { 1, 2, 2, 2 })
			else
				setup:addSimpleRow({
					Helper.getEmptyCellDescriptor(),
					ReadText(1001, 2),
					Helper.createFontString(string.format("%s / %s (%d %%)", ConvertIntegerString(menu.data.shield, true, 4, true), ConvertIntegerString(menu.data.shieldmax, true, 4, true), menu.data.shieldpercent), false, "right"),
					Helper.getEmptyCellDescriptor()
				}, nil, { 1, 2, 2, 2 })
			end
		end
		if IsComponentClass(menu.object, "ship") then
			menu.data.maxforwardspeed = GetComponentData(menu.object, "maxforwardspeed")
			if IsComponentClass(menu.object, "ship_xl") or IsComponentClass(menu.object, "ship_l") or menu.isplayership then
				local engines = GetComponentData(menu.object, "engines")
				if next(engines) then
					local hull = 0
					for _, engine in ipairs(engines) do
						hull = hull + GetComponentData(engine, "hullpercent")
					end
					menu.data.enginehull = hull / #engines
					setup:addSimpleRow({
						Helper.getEmptyCellDescriptor(),
						ReadText(1001, 1103),
						Helper.createFontString(ConvertIntegerString(menu.data.maxforwardspeed, true, nil, true) .. " " .. ReadText(1001, 107) .. "/" .. ReadText(1001, 100), false, "right"),
						Helper.getStatusBar(menu.data.enginehull, Helper.scaleY(menu.statusHeight), Helper.scaleX(menu.statusWidth - 5) + 5, true)
					}, nil, { 1, 2, 2, 2 })
				else
					setup:addSimpleRow({
						Helper.getEmptyCellDescriptor(),
						ReadText(1001, 1103),
						ReadText(1001, 89)
					}, nil, { 1, 2, 2, 2 })
				end
			else
				setup:addSimpleRow({
					Helper.getEmptyCellDescriptor(),
					ReadText(1001, 1103),
					Helper.createFontString(ConvertIntegerString(menu.data.maxforwardspeed, true, nil, true) .. " " .. ReadText(1001, 107) .. "/" .. ReadText(1001, 100), false, "right"),
					Helper.getEmptyCellDescriptor()
				}, nil, { 1, 2, 2, 2 })
			end
			local jumpdrivestatus
			if GetComponentData(menu.object, "hasjumpdrive") then
				jumpdrivestatus = ReadText(1001, 14)
			else
				jumpdrivestatus = ReadText(1001, 30)
			end
			setup:addSimpleRow({
				Helper.getEmptyCellDescriptor(),
				ReadText(1001, 1104),
				jumpdrivestatus,
				Helper.getEmptyCellDescriptor()
			}, nil, { 1, 2, 2, 2 })
		end
		if menu.type == "block" then
			menu.data.radarrange = GetComponentData(menu.object, "radarrange")
		else
			menu.data.radarrange = GetComponentData(menu.object, "maxradarrange")
		end
		if menu.data.radarrange > 0 then
			setup:addSimpleRow({
				Helper.getEmptyCellDescriptor(),
				ReadText(1001, 2426),
				Helper.createFontString(ConvertIntegerString(menu.data.radarrange, true, 2, true) .. " " .. ReadText(1001, 107), false, "right"),
				Helper.getEmptyCellDescriptor()
			}, nil, { 1, 2, 2, 2 })
		end
		if menu.type == "block" then
			menu.data.efficiencybonus = GetComponentData(menu.object, "efficiencybonus")
			if menu.data.efficiencybonus > 0 then
				menu.unlocked.efficiency_amount = IsInfoUnlockedForPlayer(menu.object, "efficiency_amount")
				setup:addSimpleRow({
					Helper.getEmptyCellDescriptor(),
					ReadText(1001, 1602),
					Helper.createFontString(Helper.unlockInfo(menu.unlocked.efficiency_amount, Helper.round(menu.data.efficiencybonus * 100)) .. " %", false, "right"),
					Helper.getEmptyCellDescriptor()
				}, nil, { 1, 2, 2, 2 })
			end
		end
		if (menu.type == "station") or ((menu.type == "ship") and GetBuildAnchor(menu.object)) then
			setup:addSimpleRow({
				Helper.getEmptyCellDescriptor(),
				ReadText(1001, 1115),
				GetComponentData(menu.object, "tradesubscription") and ReadText(1001, 2617) or ReadText(1001, 2618),
				Helper.getEmptyCellDescriptor()
			}, nil, { 1, 2, 2, 2 })
		end
		if IsComponentClass(menu.object, "ship_xl") or IsComponentClass(menu.object, "ship_l") then
			setup:addSimpleRow({
				Helper.getEmptyCellDescriptor(),
				ReadText(1001, 1324),
				Helper.createFontString(GetComponentData(menu.object, "boardingresistance"), false, "right"),
				Helper.getEmptyCellDescriptor()
			}, nil, { 1, 2, 2, 2 })
		elseif menu.isplayership and GetComponentData(menu.object, "boardingnpc") then
			setup:addSimpleRow({
				Helper.getEmptyCellDescriptor(),
				ReadText(1001, 1325),
				Helper.createFontString(GetComponentData(menu.object, "boardingstrength"), false, "right"),
				Helper.getEmptyCellDescriptor()
			}, nil, { 1, 2, 2, 2 })
		end
	end
end

function override.createSectionEmployees(setup)
	--- NPCs ---
	menu.data.npcs = GetNPCs(menu.object)
	local buildingmodule = GetComponentData(menu.object, "buildingmodule")
	if buildingmodule then
		menu.buildingcontainer = GetContextByClass(buildingmodule, "container")
		if menu.buildingcontainer then
			menu.buildingarchitect = GetComponentData(menu.buildingcontainer, "architect")
			table.insert(menu.data.npcs, menu.buildingarchitect)
		end
	end
	if menu.type ~= "block" and not menu.isplayership then
		menu.unlocked.operator_name = IsInfoUnlockedForPlayer(menu.object, "operator_name")
		menu.unlocked.operator_commands = IsInfoUnlockedForPlayer(menu.object, "operator_commands")
		menu.unlocked.managed_ships = IsInfoUnlockedForPlayer(menu.object, "managed_ships")
		menu.data.orders = menu.getControlEntityCount(menu.object)
		menu.traderestrictions = GetTradeRestrictions(menu.object)

		local hasmanager = GetComponentData(menu.object, "tradenpc")
		local employeeflag = false
		local moneyflag = 0

		if hasmanager then
			if not menu.traderestrictions.faction then
				local wantedmoney = GetComponentData(hasmanager, "productionmoney")
				local supplybudget = C.GetSupplyBudget(ConvertIDTo64Bit(menu.object))
				wantedmoney = wantedmoney + tonumber(supplybudget.trade) / 100 + tonumber(supplybudget.defence) / 100 + tonumber(supplybudget.missile) / 100
				if wantedmoney > GetAccountData(hasmanager, "money") then
					-- employeeflag = true
					moneyflag = moneyflag + 1
				end
			else
				local subordinaterangecomponent = GetNPCBlackboard(hasmanager, "$config_subordinate_range")
				if not subordinaterangecomponent then
					if GetComponentData(menu.object, "maxradarrange") > 30000 then
						subordinaterangecomponent = GetContextByClass(menu.object, "cluster")
					else
						subordinaterangecomponent = GetContextByClass(menu.object, "sector")
					end
				end
				employeeflag = not IsContainerOperationalRangeSufficient(menu.object, subordinaterangecomponent)
			end
		end
		local architect = GetComponentData(menu.object, "architect")
		if architect then
			if not menu.traderestrictions.faction then
				if GetComponentData(architect, "wantedmoney") > GetAccountData(architect, "money") then
					-- employeeflag = true
					moneyflag = moneyflag + 1
				end
			end
		end
		if menu.buildingarchitect then
			local buildingtraderestrictions = GetTradeRestrictions(menu.buildingcontainer)
			if not buildingtraderestrictions.faction then
				if GetComponentData(menu.buildingarchitect, "wantedmoney") > GetAccountData(menu.buildingarchitect, "money") then
					-- employeeflag = true
					moneyflag = moneyflag + 1
				end
			end
		end

		local icon
		local color = Helper.statusYellow
		if employeeflag or (menu.type == "station" and not hasmanager) then
			icon = "workshop_icon"
		else
			icon = "xxx_credits"
			if moneyflag > 1 then
				color = Helper.statusRed
			end
		end

		local cols = {}
		local colsLayout = {}
		local colspanNameCol = 6
		local rowData = { "npccategory" }

		table.insert(cols, Helper.createButton(Helper.createButtonText(menu.extendedcategories.npcs and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight))
		table.insert(colsLayout, 1)

		table.insert(cols, ReadText(1001, 1108) .. " (" .. Helper.unlockInfo(menu.unlocked.operator_name, menu.data.orders .. (menu.data.orders ~= 1 and " " .. ReadText(1001, 77) or " " .. ReadText(1001, 76))) .. ")")
		table.insert(colsLayout, colspanNameCol) -- will fixed in the end

		local hasIcon = menu.isplayer and ((menu.type == "station" and not hasmanager) or (employeeflag or moneyflag > 0))

		if menu.extendedcategories.npcs then
			table.insert(cols, ReadText(1001, 78))
			local thisColWidth = hasIcon and 3 or 4
			table.insert(colsLayout, thisColWidth)
			colspanNameCol = colspanNameCol - thisColWidth
		end

		if hasIcon then
			table.insert(cols, Helper.createIcon(icon, false, color.r, color.g, color.b, color.a, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight))
			table.insert(colsLayout, 1)
			table.insert(rowData, employeeflag or moneyflag)
			colspanNameCol = colspanNameCol - 1
		end

		colsLayout[2] = colspanNameCol
		setup:addSimpleRow(cols, rowData, colsLayout, false, Helper.defaultHeaderBackgroundColor)

		cols = nil
		colsLayout = nil
		rowData = nil

		if menu.extendedcategories.npcs then
			menu.data.controlentities = {}
			for i, npc in ipairs(menu.data.npcs) do
				local iscontrolentity, isplayerowned = GetComponentData(npc, "iscontrolentity", "isplayerowned")
				if iscontrolentity or (menu.isplayer and isplayerowned) then
					table.insert(menu.data.controlentities, npc)
				end
			end
			for i, npc in ipairs(menu.data.controlentities) do
				menu.addControlEntity(setup, npc, i == #menu.data.controlentities)
			end
		end
	end

	--- NPCS II ---
	if menu.type == "station" then
		if IsSameComponent(GetComponentData(menu.object, "zoneid"), GetComponentData(menu.playership, "zoneid")) then
			setup:addSimpleRow({
				Helper.getEmptyCellDescriptor(),
				ReadText(1001, 1116) .. ReadText(1001, 120) .. " " .. #menu.data.npcs + (menu.buildingarchitect and -1 or 0),
			}, { "npcs" }, { 1, 6 }, false, Helper.defaultHeaderBackgroundColor)
		else
			setup:addSimpleRow({
				Helper.getEmptyCellDescriptor(),
				ReadText(1001, 1116) .. ReadText(1001, 120) .. " " .. ReadText(1001, 1117),
			}, nil, { 1, 6 }, false, Helper.defaultHeaderBackgroundColor)
		end
	end
end

function override.createSectionUpkeep(setup)
	--- Upkeep Missions ---
	if not menu.isplayership and menu.isplayer then
		menu.data.upkeep = {}
		local numMissions = GetNumMissions()
		for i = 1, numMissions do
			local missionID, name, description, difficulty, maintype, subtype, faction, reward, rewardtext, _, _, _, _, missiontime, _, abortable, disableguidance, associatedcomponent = GetMissionDetails(i, Helper.standardFont, Helper.standardFontSize, Helper.scaleX(425))
			local objectiveText, objectiveIcon, timeout, progressname, curProgress, maxProgress = GetMissionObjective(i, Helper.standardFont, Helper.standardFontSize, Helper.scaleX(425))

			if maintype == "upkeep" then
				local container = GetContextByClass(associatedcomponent, "container", true)
				local buildanchor = GetBuildAnchor(container)
				container = buildanchor or container

				if IsSameComponent(container, menu.object) then
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
						["timeout"] = (timeout and timeout ~= -1) and timeout or (missiontime or -1), -- timeout can be nil, if mission has no objective
						["progressName"] = progressname,
						["curProgress"] = curProgress,
						["maxProgress"] = maxProgress or 0, -- maxProgress can be nil, if mission has n objective
						["component"] = associatedcomponent,
						["disableguidance"] = disableguidance,
						["ID"] = missionID,
						["associatedcomponent"] = associatedcomponent
					}

					table.insert(menu.data.upkeep, entry)
				end
			end
		end

		if #menu.data.upkeep > 0 then
			if not menu.extendedcategories.upkeep then
				setup:addSimpleRow({
					Helper.createButton(Helper.createButtonText(menu.extendedcategories.upkeep and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
					ReadText(1001, 3305)
				}, nil, { 1, 6 }, false, Helper.defaultHeaderBackgroundColor)
			else
				setup:addSimpleRow({
					Helper.createButton(Helper.createButtonText(menu.extendedcategories.upkeep and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
					ReadText(1001, 3305)
				}, nil, { 1, 6 }, false, Helper.defaultHeaderBackgroundColor)

				for _, entry in ipairs(menu.data.upkeep) do
					local entity = GetContextByClass(entry.associatedcomponent, "entity", true)
					setup:addSimpleRow({
						Helper.createIcon("missionoffer_" .. entry.type .. "_active", false, nil, nil, nil, nil, 3, 0, Helper.standardTextHeight * 2, Helper.standardTextHeight * 2),
						Helper.createFontString((entity and (GetComponentData(entity, "typename") .. ReadText(1001, 120) .. " ") or "") .. entry.name .. (entry.difficulty == 0 and "" or " [" .. ConvertMissionLevelString(entry.difficulty) .. "]") .. (entry.disableguidance and " [" .. ReadText(1001, 3311) .. "]" or "") .. "\n     " .. (entry.objectiveText or ""), false, "left", 255, 255, 255, 100, Helper.standardFont, Helper.standardFontSize, true, nil, nil, 2 * Helper.standardTextHeight - 5)
					}, { "upkeep", entry }, { 2, 5 })
				end
			end
		end
	end
end

function override.createSectionProduction(setup)
	--- Production ---
	menu.data.productionmodules = GetProductionModules(menu.object)
	menu.data.proddata = {}
	local allproducing = true
	for i = #menu.data.productionmodules, 1, -1 do
		if not IsComponentOperational(menu.data.productionmodules[i]) then
			table.remove(menu.data.productionmodules, i)
		else
			menu.data.proddata[tostring(menu.data.productionmodules[i])] = GetProductionModuleData(menu.data.productionmodules[i])
			if allproducing then
				if not GetComponentData(menu.data.productionmodules[i], "isproducing") then
					allproducing = false
				end
			end
		end
	end
	if #menu.data.productionmodules > 0 then
		if not menu.extendedcategories.production then
			if menu.isplayer and not allproducing then
				setup:addSimpleRow({
					Helper.createButton(Helper.createButtonText(menu.extendedcategories.production and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
					ReadText(1001, 1106) .. ReadText(1001, 120) .. " " .. #menu.data.productionmodules,
					Helper.createIcon("workshop_error", false, 255, 0, 0, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight)
				}, { "productioncategory" }, { 1, 5, 1 }, false, Helper.defaultHeaderBackgroundColor)
			else
				setup:addSimpleRow({
					Helper.createButton(Helper.createButtonText(menu.extendedcategories.production and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
					ReadText(1001, 1106) .. ReadText(1001, 120) .. " " .. #menu.data.productionmodules
				}, { "productioncategory" }, { 1, 6 }, false, Helper.defaultHeaderBackgroundColor)
			end
		else
			if menu.isplayer and not allproducing then
				setup:addSimpleRow({
					Helper.createButton(Helper.createButtonText(menu.extendedcategories.production and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
					ReadText(1001, 1106) .. ReadText(1001, 120) .. " " .. #menu.data.productionmodules,
					ReadText(1001, 1600) .. " / " .. ReadText(1001, 102),
					ReadText(1001, 1107),
					ReadText(1001, 1602),
					Helper.createIcon("workshop_error", false, 255, 0, 0, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight)
				}, { "productioncategory" }, { 1, 2, 1, 1, 1, 1 }, false, Helper.defaultHeaderBackgroundColor)
			else
				setup:addSimpleRow({
					Helper.createButton(Helper.createButtonText(menu.extendedcategories.production and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
					ReadText(1001, 1106) .. ReadText(1001, 120) .. " " .. #menu.data.productionmodules,
					ReadText(1001, 1600) .. " / " .. ReadText(1001, 102),
					ReadText(1001, 1107),
					ReadText(1001, 1602)
				}, { "productioncategory" }, { 1, 2, 1, 1, 2 }, false, Helper.defaultHeaderBackgroundColor)
			end

			table.sort(menu.data.productionmodules, Helper.sortComponentName)
			for _, module in ipairs(menu.data.productionmodules) do
				local proddata = menu.data.proddata[tostring(module)]
				if next(proddata) and proddata.products then
					local product = proddata.products[1]

					local remainingtime = "4.2 " .. ReadText(1001, 112)
					if proddata.state == "producing" and proddata.remainingtime == 0 then
						local clustermacro = GetComponentData(GetComponentData(menu.object, "clusterid"), "macro")
						if clustermacro == "cluster_a_macro" then
							-- Maelstrom
							remainingtime = "0.9 " .. ReadText(1001, 112)
						elseif clustermacro == "cluster_b_macro" then
							-- Albion
							remainingtime = "4.2 " .. ReadText(1001, 112)
						elseif clustermacro == "cluster_c_macro" then
							-- Omycron Lyrae
							remainingtime = "3.7 " .. ReadText(1001, 112)
						elseif clustermacro == "cluster_d_macro" then
							-- DeVries
							remainingtime = "11.4 " .. ReadText(1001, 112)
						end
					else
						remainingtime = ConvertTimeString(proddata.remainingtime, "%h" .. ReadText(1001, 102) .. " %M" .. ReadText(1001, 103) .. " %S" .. ReadText(1001, 100))
					end

					menu.unlocked[module] = { name = IsInfoUnlockedForPlayer(module, "name"), production_time = IsInfoUnlockedForPlayer(module, "production_time"), efficiency_amount = IsInfoUnlockedForPlayer(module, "efficiency_amount") }
					if proddata.state == "waitingforresources" or proddata.state == "waitingforstorage" or not GetComponentData(module, "isfunctional") then
						setup:addSimpleRow({
							Helper.getEmptyCellDescriptor(),
							Helper.unlockInfo(menu.unlocked[module].name, GetComponentData(module, "name")),
							Helper.createFontString(Helper.unlockInfo(menu.unlocked[module].efficiency_amount, ConvertIntegerString(product.cycle * 3600 / proddata.cycletime, true, 4, true) .. "x " .. GetWareData(product.ware, "name")), false, "left"),
							Helper.createFontString(Helper.unlockInfo(menu.unlocked[module].production_time, remainingtime), false, "right"),
							Helper.createFontString(Helper.unlockInfo(menu.unlocked[module].efficiency_amount, Helper.round(proddata.products.efficiency * 100) .. " %"), false, "right"),
							Helper.createIcon("workshop_error", false, 255, 0, 0, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight)
						}, { "production", module }, { 1, 2, 1, 1, 1, 1 })
					else
						setup:addSimpleRow({
							Helper.getEmptyCellDescriptor(),
							Helper.unlockInfo(menu.unlocked[module].name, GetComponentData(module, "name")),
							Helper.createFontString(Helper.unlockInfo(menu.unlocked[module].efficiency_amount, ConvertIntegerString(product.cycle * 3600 / proddata.cycletime, true, 4, true) .. "x " .. GetWareData(product.ware, "name")), false, "left"),
							Helper.createFontString(Helper.unlockInfo(menu.unlocked[module].production_time, remainingtime), false, "right"),
							Helper.createFontString(Helper.unlockInfo(menu.unlocked[module].efficiency_amount, Helper.round(proddata.products.efficiency * 100) .. " %"), false, "right")
						}, { "production", module }, { 1, 2, 1, 1, 2 })
					end
				end
			end
		end
	end
end

function override.createSectionStorage(setup)
	--- Storage ---
	menu.data.storagemodules = GetStorageData(menu.object)
	menu.data.cargo = {}
	for _, cargobay in ipairs(menu.data.storagemodules) do
		for _, ware in ipairs(cargobay) do
			menu.data.cargo[ware.ware] = ware.amount
		end
	end
	menu.data.cargototal = 0
	if menu.data.cargo then
		local i = 0
		for _, _ in pairs(menu.data.cargo) do
			i = i + 1
		end
		menu.data.cargototal = i
	end
	local storagetext, storageamount, storagecapacity, estimated, si_unit
	if next(menu.data.storagemodules) and (menu.data.storagemodules.capacity > 0 or menu.data.storagemodules.estimated) then
		storagetext = ReadText(1001, 1400) .. " (" .. menu.data.cargototal .. " " .. (menu.data.cargototal == 1 and ReadText(1001, 45) or ReadText(1001, 46)) .. ")"
		storageamount = menu.data.storagemodules.stored
		storagecapacity = menu.data.storagemodules.capacity
		estimated = menu.data.storagemodules.estimated
		si_unit = " " .. ReadText(1001, 110)
	elseif menu.hasInventory(menu.object) and not menu.isplayership then
		storagetext = ReadText(1001, 2202)
		storageamount = nil
		si_unit = ""
	end
	if storagetext then
		menu.hasStorageStatus = true
		menu.unlocked.storage_warelist = IsInfoUnlockedForPlayer(menu.object, "storage_warelist") or (menu.type == "station" and estimated ~= nil)
		menu.unlocked.storage_amounts = IsInfoUnlockedForPlayer(menu.object, "storage_amounts") or (menu.type == "station" and estimated ~= nil)
		menu.unlocked.storage_capacity = IsInfoUnlockedForPlayer(menu.object, "storage_capacity") or (menu.type == "station" and estimated ~= nil)

		local productcycleamounts = {}
		for _, module in ipairs(menu.data.productionmodules) do
			local proddata = menu.data.proddata[tostring(module)]
			if next(proddata) then
				if proddata.state ~= "empty" and proddata.state ~= "waitingforresources" then
					for _, product in ipairs(proddata.products) do
						if not productcycleamounts[product.ware] or productcycleamounts[product.ware] < product.cycle then
							productcycleamounts[product.ware] = product.cycle
						end
					end
				end
			end
		end

		local fullstorage = 0
		local products, resources = GetComponentData(menu.object, "products", "pureresources")
		if products then
			for _, ware in ipairs(products) do
				local cycleamount = productcycleamounts[ware] and productcycleamounts[ware] + 1 or 0
				if fullstorage < 2 and (GetWareCapacity(menu.object, ware, false) <= cycleamount or (GetWareProductionLimit(menu.object, ware) - cycleamount) < (menu.data.cargo[ware] or 0)) then
					fullstorage = 2
				end
			end
		end
		if fullstorage < 1 and resources then
			for _, ware in ipairs(resources) do
				if fullstorage < 1 and (GetWareCapacity(menu.object, ware, false) == 0 or GetWareProductionLimit(menu.object, ware) < (menu.data.cargo[ware] or 0)) then
					fullstorage = 1
				end
			end
		end

		local cols = {}
		local colsLayout = {}
		local isPlayerAndStorageExceeded = menu.isplayer and (fullstorage) > 0

		-- collapse / expand
		table.insert(cols, Helper.createButton(Helper.createButtonText((menu.extendedcategories.storage and menu.data.cargototal > 0) and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, menu.unlocked.storage_warelist and menu.data.cargototal > 0, 0, 0, 0, Helper.standardTextHeight))
		table.insert(colsLayout, 1)
		-- text
		table.insert(cols, storagetext)
		table.insert(colsLayout, 2)
		-- storage info (col:3)
		table.insert(cols, Helper.createFontString(ReadText(1001, 1402) .. ReadText(1001, 120) .. " " .. Helper.estimateString(menu.type == "station" and estimated) .. (storageamount and Helper.unlockInfo(menu.unlocked.storage_amounts, ConvertIntegerString(storageamount, true, 4, true)) or "") .. (storagecapacity and " / " .. Helper.unlockInfo(menu.unlocked.storage_capacity, ConvertIntegerString(storagecapacity, true, 4, true)) or "") .. si_unit, false, "left"))

		if not (menu.extendedcategories.storage or (menu.data.cargototal == 0)) then
			table.insert(colsLayout, isPlayerAndStorageExceeded and 3 or 4)
		else
			table.insert(colsLayout, 2)
			-- cargo count text
			table.insert(cols, Helper.createFontString(ReadText(1001, 20) .. (products and next(products) and " / " .. ReadText(1001, 1127) or ""), false, "right"))
			table.insert(colsLayout, isPlayerAndStorageExceeded and 1 or 2)
		end

		-- info button
		if isPlayerAndStorageExceeded then
			table.insert(cols, Helper.createIcon("workshop_error", false, (fullstorage == 2) and 255 or 196, (fullstorage == 2) and 0 or 196, 0, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight))
			table.insert(colsLayout, 1)
		end

		setup:addSimpleRow(cols, { "storage", fullstorage }, colsLayout, false, Helper.defaultHeaderBackgroundColor)

		-- expanded
		if not ((not menu.extendedcategories.storage) or (menu.data.cargototal == 0)) then


			local owner = GetComponentData(menu.object, "owner")
			local zone = GetComponentData(menu.object, "zoneid")
			local zoneowner = GetComponentData(zone, "owner")
			for ware, amount in Helper.orderedPairsByWareName(menu.data.cargo) do
				local name, icon = GetWareData(ware, "name", "icon")
				local cycleamount = productcycleamounts[ware] and productcycleamounts[ware] + 1 or 0
				local limit = 0
				if menu.isplayer and menu.type ~= "block" then
					limit = GetWareProductionLimit(menu.object, ware)
				end
				local color = menu.white
				if zoneowner and IsWareIllegalTo(ware, owner, zoneowner) then
					color = menu.orange
				end

				cols = {}
				colsLayout = {}

				table.insert(cols, Helper.getEmptyCellDescriptor())
				table.insert(colsLayout, 1)
				table.insert(cols, Helper.createButton(nil, Helper.createButtonIcon(icon, nil, 255, 255, 255, 100), false, menu.unlocked.storage_warelist))
				table.insert(colsLayout, 1)
				table.insert(cols, Helper.unlockInfo(menu.unlocked.storage_warelist, Helper.createFontString(name, false, "left", color.r, color.g, color.b, color.a)))
				table.insert(colsLayout, 1)

				table.insert(cols, Helper.createFontString(Helper.estimateString(menu.type == "station" and estimated) .. Helper.unlockInfo(menu.unlocked.storage_amounts, ConvertIntegerString(amount, true, 4, true) .. (limit > 0 and " / " .. ConvertIntegerString(limit, true, 4, true) or "")), false, "right"))

				local rowInfo

				if menu.isplayer and next(products) and (GetWareCapacity(menu.object, ware, false) <= cycleamount or (limit - cycleamount) < amount) then
					table.insert(colsLayout, 3)

					table.insert(cols, Helper.createIcon("workshop_error", false, productcycleamounts[ware] and 255 or 196, productcycleamounts[ware] and 0 or 196, 0, 100, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight))
					table.insert(colsLayout, 1)
					rowInfo = { "ware", productcycleamounts[ware] }
				else
					table.insert(colsLayout, 4)
				end

				setup:addSimpleRow(cols, rowInfo, colsLayout)

				AddKnownItem("wares", ware)
			end
		end
	end
end

function override.createSectionTradequeue(setup)
	--- Tradequeue ---
	menu.data.tradequeue = ((menu.type == "ship") and (not GetBuildAnchor(menu.object))) and GetShoppingList(menu.object) or {}
	if not menu.dontdisplaytradequeue then
		if next(menu.data.tradequeue) then
			local maxtrips = 3
			if PlayerPrimaryShipHasContents("trademk2") then
				maxtrips = 5
			elseif PlayerPrimaryShipHasContents("trademk3") then
				maxtrips = 7
			end
			setup:addSimpleRow({
				Helper.createButton(Helper.createButtonText(menu.extendedcategories.tradequeue and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
				ReadText(1001, 2937) .. " (" .. #menu.data.tradequeue .. "/" .. maxtrips .. ")"
			}, { "tradequeue" }, { 1, 5 }, false, Helper.defaultHeaderBackgroundColor)
			if menu.extendedcategories.tradequeue then
				for i, item in ipairs(menu.data.tradequeue) do
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
							Helper.getEmptyCellDescriptor(),
							Helper.createFontString(string.format(text .. "\n" .. ReadText(1001, 2994), ConvertIntegerString(item.amount, true, nil, true), item.name, item.stationname, cluster, sector, zone), true, "left", nil, nil, nil, nil, Helper.standardFont, Helper.scaleFont(Helper.standardFont, Helper.standardFontSize), true, nil, nil, 0, Helper.scaleX(Helper.standardSizeX - Helper.standardButtonWidth) - 26)
						}, { "tradequeue" }, { 1, 6 })
					else
						local profittext = ""
						if item.isbuyoffer then
							local trade = GetTradeData(item.id)
							local profit = GetReferenceProfit(menu.object, trade.ware, item.price, item.amount, i - 1)
							profittext = " [" .. string.format(ReadText(1001, 6203), (profit and ConvertMoneyString(profit, false, true, 6, true) or ReadText(1001, 2672)) .. " " .. ReadText(1001, 101)) .. "]"
						end
						setup:addSimpleRow({
							Helper.getEmptyCellDescriptor(),
							Helper.createFontString(item.station and string.format((item.isbuyoffer and ReadText(1001, 2976) or ReadText(1001, 2975)) .. profittext .. "\n" .. ReadText(1001, 2977), ConvertIntegerString(item.amount, true, nil, true), item.name, ConvertMoneyString(RoundTotalTradePrice(item.price * item.amount), false, true, nil, true), item.stationname, cluster, sector, zone) or string.format((item.isbuyoffer and ReadText(1001, 2976) or ReadText(1001, 2975)), ConvertIntegerString(item.amount, true, nil, true), item.name, ConvertMoneyString(RoundTotalTradePrice(item.price * item.amount), false, true, nil, true)), true, "left", nil, nil, nil, nil, Helper.standardFont, Helper.scaleFont(Helper.standardFont, Helper.standardFontSize), true, nil, nil, 0, Helper.scaleX(Helper.standardSizeX - Helper.standardButtonWidth) - 26)
						}, { "tradequeue" }, { 1, 6 })
					end
				end
			end
		end
	end
end

function override.createSectionUnits(setup)
	--- Units ---
	menu.unlocked.units_amount = IsInfoUnlockedForPlayer(menu.object, "units_amount")
	menu.unlocked.units_capacity = IsInfoUnlockedForPlayer(menu.object, "units_capacity")
	menu.unlocked.units_details = IsInfoUnlockedForPlayer(menu.object, "units_details")
	if IsComponentClass(menu.object, "defensible") then
		menu.data.units = GetUnitStorageData(menu.object)
		if #menu.data.units > 0 then
			for _, unit in ipairs(menu.data.units) do
				if unit.amount > 0 then
					menu.data.units.header = true
					break
				end
			end
			if menu.data.units.header or menu.isplayership then
				local numplayerdrones, playerdronescapacity = 0, 0
				if menu.isplayership then
					menu.data.playerdrones = GetPlayerDroneStorageData()
					numplayerdrones = #menu.data.playerdrones
					playerdronescapacity = GetPlayerDroneSlots()
				end
				if not menu.extendedcategories.units then
					setup:addSimpleRow({
						Helper.createButton(Helper.createButtonText(menu.extendedcategories.units and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
						ReadText(1001, 22) .. " (" .. Helper.unlockInfo(menu.unlocked.units_amount, menu.data.units.stored + numplayerdrones) .. " / " .. Helper.unlockInfo(menu.unlocked.units_capacity, menu.data.units.capacity + playerdronescapacity) .. ")"
					}, nil, { 1, 6 }, false, Helper.defaultHeaderBackgroundColor)
				else
					setup:addSimpleRow({
						Helper.createButton(Helper.createButtonText(menu.extendedcategories.units and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
						ReadText(1001, 22) .. " (" .. Helper.unlockInfo(menu.unlocked.units_amount, menu.data.units.stored + numplayerdrones) .. " / " .. Helper.unlockInfo(menu.unlocked.units_capacity, menu.data.units.capacity + playerdronescapacity) .. ")",
						ReadText(1001, 20),
						ReadText(1001, 1403)
					}, nil, { 1, 2, 2, 2 }, false, Helper.defaultHeaderBackgroundColor)

					menu.hasunit = false
					table.sort(menu.data.units, function(a, b)
						return a.name < b.name
					end)
					for _, unit in ipairs(menu.data.units) do
						if unit.amount > 0 then
							menu.hasunit = true
							local category
							if IsMacroClass(unit.macro, "npc") then
								category = "marines"
							else
								category = "shiptypes_xs"
							end

							local ware = GetMacroData(unit.macro, "ware")
							local icon

							if ware then
								icon = GetWareData(ware, "icon")
							end

							if not icon then
								icon = "ware_default"
							end

							setup:addSimpleRow({
								Helper.getEmptyCellDescriptor(),
								Helper.createButton(nil, Helper.createButtonIcon(icon, nil, 255, 255, 255, 100), false, menu.unlocked.units_details),
								Helper.unlockInfo(menu.unlocked.units_details, unit.name),
								Helper.createFontString(Helper.unlockInfo(menu.unlocked.units_amount, unit.amount), false, "right"),
								Helper.createFontString(Helper.unlockInfo(menu.unlocked.units_details, unit.unavailable), false, "right")
							}, nil, { 1, 1, 1, 2, 2 })
							AddKnownItem(category, unit.macro)
						end
					end
					if menu.isplayership then
						--[[
						if menu.hasunit then
							setup:addHeaderRow({
								Helper.createFontString("", false, Helper.standardHalignment, Helper.standardColor.r, Helper.standardColor.g, Helper.standardColor.b, Helper.standardColor.a, Helper.standardFont, 6, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, 6)
							}, nil, { 7 })
						end
						]]
						if #menu.data.playerdrones > 0 then
							local dronemacros = {}
							local removed = {}
							for i, drone in pairs(menu.data.playerdrones) do
								if type(i) ~= "string" then
									if dronemacros[drone.macro] then
										menu.data.playerdrones[dronemacros[drone.macro]].amount = menu.data.playerdrones[dronemacros[drone.macro]].amount + drone.amount + 1
										table.insert(removed, i)
									else
										drone.amount = drone.amount + 1
										dronemacros[drone.macro] = i
									end
								end
							end
							for i = #removed, 1, -1 do
								table.remove(menu.data.playerdrones, removed[i])
							end
							table.sort(menu.data.playerdrones, Helper.sortName)
							for _, drone in ipairs(menu.data.playerdrones) do
								local icon = GetMacroData(drone.macro, "icon")
								-- The +1 comes from one of these drones already being active as a subordinate and in order to comply with the format of the UnitStorageData
								setup:addSimpleRow({
									"",
									Helper.createButton(nil, Helper.createButtonIcon(icon ~= "" and icon or "menu_info", nil, 255, 255, 255, 100), false),
									drone.name,
									Helper.createFontString(drone.amount, false, "right"),
									Helper.createFontString("-", false, "right")
								}, nil, { 1, 1, 1, 2, 2 })
								AddKnownItem("shiptypes_xs", drone.macro)
							end
						end
					end
				end
			end
		end
	end
end

function override.createSectionWeapons(setup)
	--- Weapons ---
	menu.data.weapons = GetAllWeapons(menu.object)
	for i = #menu.data.weapons.missiles, 1, -1 do
		if menu.data.weapons.missiles[i].amount == 0 then
			table.remove(menu.data.weapons.missiles, i)
		end
	end
	menu.data.upgrades = GetAllUpgrades(menu.object, false)
	menu.data.upgradeShields = menu.fetchShieldgenerators()
	menu.notupgradeturrets = GetNotUpgradesByClass(menu.object, "turret")
	menu.notupgradeturrets.totaloperational = 0
	menu.notupgradeturrets.totaltotal = 0
	for i, turret in ipairs(menu.notupgradeturrets) do
		local name, macro = GetComponentData(turret, "name", "macro")
		local defence_status = IsInfoUnlockedForPlayer(turret, "defence_status")
		local defence_level = IsInfoUnlockedForPlayer(turret, "defence_level")
		if not defence_status or not defence_level then
			menu.notupgradeturrets.estimated = true
		end
		if menu.notupgradeturrets[macro] then
			if IsComponentOperational(turret) and defence_status then
				menu.notupgradeturrets.totaloperational = menu.notupgradeturrets.totaloperational + 1
				menu.notupgradeturrets[macro].operational = menu.notupgradeturrets[macro].operational + 1
			end
			if defence_level then
				menu.notupgradeturrets.totaltotal = menu.notupgradeturrets.totaltotal + 1
				menu.notupgradeturrets[macro].total = menu.notupgradeturrets[macro].total + 1
			end
		else
			local operational = 0
			if IsComponentOperational(turret) and defence_status then
				menu.notupgradeturrets.totaloperational = menu.notupgradeturrets.totaloperational + 1
				operational = 1
			end
			if defence_level then
				menu.notupgradeturrets.totaltotal = menu.notupgradeturrets.totaltotal + 1
				menu.notupgradeturrets[macro] = { name = name, operational = operational, total = 1, macro = macro }
			end
		end
	end
	local defencelevel, defencestatus, estimated
	if ((next(menu.data.weapons.weapons) and (#menu.data.weapons.weapons ~= 0)) or (next(menu.data.weapons.missiles) and (#menu.data.weapons.missiles ~= 0))) and (menu.data.upgrades.totaltotal ~= 0 or menu.data.upgrades.estimated) and not menu.isplayership then
		defencelevel = menu.data.upgrades.totaltotal + #menu.data.weapons.weapons + #menu.data.weapons.missiles + menu.notupgradeturrets.totaltotal
		defencestatus = menu.data.upgrades.totaloperational + #menu.data.weapons.weapons + #menu.data.weapons.missiles + menu.notupgradeturrets.totaloperational
		estimated = menu.data.upgrades.estimated or menu.notupgradeturrets.estimated
	elseif #menu.data.weapons.weapons ~= 0 or #menu.data.weapons.missiles ~= 0 then
		defencestatus = #menu.data.weapons.weapons + #menu.data.weapons.missiles
	elseif (not menu.isplayership) and (menu.data.upgrades.totaltotal ~= 0 or menu.data.upgrades.estimated) then
		defencelevel = menu.data.upgrades.totaltotal + menu.notupgradeturrets.totaltotal
		defencestatus = menu.data.upgrades.totaloperational + menu.notupgradeturrets.totaloperational
		estimated = menu.data.upgrades.estimated or menu.notupgradeturrets.estimated
	end
	if defencestatus then
		menu.hasDefenceStatus = true
		menu.unlocked.defence_level = IsInfoUnlockedForPlayer(menu.object, "defence_level") or (menu.type == "station" and estimated ~= nil)
		menu.unlocked.defence_status = IsInfoUnlockedForPlayer(menu.object, "defence_status") or (menu.type == "station" and estimated ~= nil)
		if not menu.extendedcategories.weapons then
			setup:addSimpleRow({
				Helper.createButton(Helper.createButtonText(menu.extendedcategories.weapons and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, menu.data.upgrades.totaltotal > 0 or menu.notupgradeturrets.totaltotal ~= 0 or #menu.data.weapons.weapons ~= 0 or #menu.data.weapons.missiles ~= 0, 0, 0, 0, Helper.standardTextHeight),
				Helper.createFontString(ReadText(1001, 1105) .. " (" .. Helper.estimateString(menu.type == "station" and estimated) .. Helper.unlockInfo(menu.unlocked.defence_status, defencestatus) .. (defencelevel and " / " .. Helper.unlockInfo(menu.unlocked.defence_level, defencelevel) or "") .. ")", false, "left")
			}, nil, { 1, 6 }, false, Helper.defaultHeaderBackgroundColor)
		else
			if not menu.isplayership then
				setup:addSimpleRow({
					Helper.createButton(Helper.createButtonText(menu.extendedcategories.weapons and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
					Helper.createFontString(ReadText(1001, 1105) .. " (" .. Helper.estimateString(menu.type == "station" and estimated) .. Helper.unlockInfo(menu.unlocked.defence_status, defencestatus) .. (defencelevel and " / " .. Helper.unlockInfo(menu.unlocked.defence_level, defencelevel) or "") .. ")", false, "left"),
					ReadText(1001, 1311),
					ReadText(1001, 1322)
				}, nil, { 1, 2, 2, 2 }, false, Helper.defaultHeaderBackgroundColor)
			else
				setup:addSimpleRow({
					Helper.createButton(Helper.createButtonText(menu.extendedcategories.weapons and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
					Helper.createFontString(ReadText(1001, 1105) .. " (" .. Helper.estimateString(menu.type == "station" and estimated) .. Helper.unlockInfo(menu.unlocked.defence_status, defencestatus) .. (defencelevel and " / " .. Helper.unlockInfo(menu.unlocked.defence_level, defencelevel) or "") .. ")", false, "left"),
					ReadText(1001, 1303),
					ReadText(1001, 1302),
					ReadText(1001, 12)
				}, { "weapons" }, { 1, 2, 1, 1, 2 }, false, Helper.defaultHeaderBackgroundColor)
			end

			if not menu.isplayership then


				for ut, upgrade in Helper.orderedPairs(menu.data.upgrades) do
					if (ut == "shieldgenerator" or ut == "shieldgenerator_cap") and not (ut == "totaltotal" or ut == "totalfree" or ut == "totaloperational" or ut == "totalconstruction" or ut == "estimated") then
						if upgrade.total ~= 0 then
							setup:addSimpleRow({
								Helper.getEmptyCellDescriptor(),
								Helper.createButton(Helper.createButtonText(menu.extendedcategories["shield_" .. ut] and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
								upgrade.name,
								Helper.createFontString(Helper.estimateString(estimated) .. Helper.unlockInfo(menu.unlocked.defence_status, upgrade.operational), false, "right"),
								Helper.createFontString(Helper.estimateString(estimated) .. Helper.unlockInfo(menu.unlocked.defence_level, upgrade.total), false, "right")
							}, nil, { 1, 1, 1, 2, 2 })

							if menu.extendedcategories["shield_" .. ut] then
								if menu.data.upgradeShields[ut]["count"] > 0 then
									for macro, shieldTypeData in pairs(menu.data.upgradeShields[ut]) do
										if macro ~= "count" then
											setup:addSimpleRow({
												Helper.getEmptyCellDescriptor(),
												Helper.createButton(nil, Helper.createButtonIcon(shieldTypeData.icon, nil, 255, 255, 255, 100), false, nil),
												shieldTypeData.name,
												Helper.createFontString(Helper.estimateString(estimated) .. Helper.unlockInfo(menu.unlocked.defence_status, shieldTypeData.count), false, "right"),
												""
											}, nil, { 1, 1, 1, 2, 2 })
										end
									end
									setup:addHeaderRow({ Helper.createFontString("", false, Helper.standardHalignment, Helper.standardColor.r, Helper.standardColor.g, Helper.standardColor.b, Helper.standardColor.a, Helper.standardFont, 6, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, 6) }, nil, { 7 })
								end
							end
						end
					end
				end

				for ut, upgrade in Helper.orderedPairs(menu.data.upgrades) do
					if not (ut == "shieldgenerator" or ut == "shieldgenerator_cap") and not (ut == "totaltotal" or ut == "totalfree" or ut == "totaloperational" or ut == "totalconstruction" or ut == "estimated") then
						if upgrade.total ~= 0 then
							setup:addSimpleRow({
								Helper.getEmptyCellDescriptor(),
								Helper.createButton(nil, Helper.createButtonIcon("ware_default", nil, 255, 255, 255, 100), false, nil),
								upgrade.name,
								Helper.createFontString(Helper.estimateString(estimated) .. Helper.unlockInfo(menu.unlocked.defence_status, upgrade.operational), false, "right"),
								Helper.createFontString(Helper.estimateString(estimated) .. Helper.unlockInfo(menu.unlocked.defence_level, upgrade.total), false, "right")
							}, nil, { 1, 1, 1, 2, 2 })
						end
					end
				end

				for macro, turret in pairs(menu.notupgradeturrets) do
					if type(turret) == "table" and turret.operational ~= 0 then
						setup:addSimpleRow({
							Helper.getEmptyCellDescriptor(),
							Helper.createButton(nil, Helper.createButtonIcon("ware_default", nil, 255, 255, 255, 100), false, nil),
							turret.name,
							Helper.createFontString(Helper.estimateString(menu.notupgradeturrets.estimated) .. Helper.unlockInfo(menu.unlocked.defence_status, turret.operational), false, "right"),
							Helper.createFontString(Helper.estimateString(menu.notupgradeturrets.estimated) .. Helper.unlockInfo(menu.unlocked.defence_level, turret.total), false, "right")
						}, nil, { 1, 1, 1, 2, 2 })
					end
				end
			end

			local infobutton = Helper.createButton(nil, Helper.createButtonIcon("menu_info", nil, 255, 255, 255, 100), false)
			if #menu.data.weapons.weapons ~= 0 then
				if not menu.isplayership then
					setup:addHeaderRow({
						Helper.getEmptyCellDescriptor(),
						ReadText(1001, 1301),
						ReadText(1001, 1303),
						ReadText(1001, 1302),
						ReadText(1001, 12)
					}, nil, { 1, 2, 1, 1, 2 })
				end
				table.sort(menu.data.weapons.weapons, function(a, b)
					return a.name < b.name
				end)
				local ffiinstalledmod = ffi.new("UIWeaponMod")
				for i, weapon in ipairs(menu.data.weapons.weapons) do
					weapon.hull = GetComponentData(weapon.component, "hullpercent")
					setup:addSimpleRow({
						"",
						infobutton,
						weapon.name .. (C.GetInstalledWeaponMod(ConvertIDTo64Bit(weapon.component), ffiinstalledmod) and "*" or ""),
						Helper.createFontString(ConvertIntegerString(weapon.dps, true, nil, true), false, "right"),
						Helper.createFontString(ConvertIntegerString(weapon.range, true, nil, true) .. " " .. ReadText(1001, 107), false, "right"),
						Helper.getStatusBar(weapon.hull, Helper.scaleY(menu.statusHeight), Helper.scaleX(menu.statusWidth - 5) + 5, true)
					}, { "weapons" }, { 1, 1, 1, 1, 1, 2 })
					AddKnownItem("weapontypes_primary", weapon.macro)
				end
			end
			if #menu.data.weapons.missiles ~= 0 then
				local header = false
				table.sort(menu.data.weapons.missiles, function(a, b)
					return a.name < b.name
				end)
				for _, missile in ipairs(menu.data.weapons.missiles) do
					if missile.amount > 0 then
						if not header then
							setup:addHeaderRow({
								Helper.getEmptyCellDescriptor(),
								ReadText(1001, 1304),
								ReadText(1001, 1306),
								ReadText(1001, 1305),
								menu.isplayership and ReadText(1001, 1202) or Helper.getEmptyCellDescriptor()
							}, nil, { 1, 2, 1, 1, 2 })
							header = true
						end
						setup:addSimpleRow({
							"",
							infobutton,
							missile.name,
							Helper.createFontString(ConvertIntegerString(missile.damage, true, nil, true), false, "right"),
							Helper.createFontString(ConvertIntegerString(missile.speed, true, nil, true) .. " " .. ReadText(1001, 107) .. "/" .. ReadText(1001, 100), false, "right"),
							menu.isplayership and Helper.createFontString(ConvertIntegerString(missile.amount, true, nil, true), false, "right") or Helper.getEmptyCellDescriptor()
						}, nil, { 1, 1, 1, 1, 1, 2 })
						AddKnownItem("weapontypes_secondary", missile.macro)
					end
				end
			end
		end
	end
end

function override.createSectionAmmunition(setup)
	--- Ammunition ---
	if not menu.isplayership then
		-- gather ammunition data,
		menu.data.ammunition = {}
		menu.data.ammunition.total = 0
		menu.data.ammunition.totalcapacity = 0
		menu.data.ammunition.knowncapacity = 0
		-- NB: if we want to only display the ammunition type if there are any equipped, switch to GetNumAllMissiles and GetAllMissiles
		if IsComponentClass(menu.object, "defensible") then
			local nummissiles = C.GetNumAmmoStorage(ConvertIDTo64Bit(menu.object), "missile")
			local missiles = ffi.new("AmmoData[?]", nummissiles)

			local showcapacity = IsInfoUnlockedForPlayer(menu.object, "defence_level")
			local showamount = IsInfoUnlockedForPlayer(menu.object, "defence_status")

			nummissiles = C.GetAmmoStorage(missiles, nummissiles, ConvertIDTo64Bit(menu.object), "missile")
			for i = 0, nummissiles - 1 do
				local missilename, icon = GetWareData(ffi.string(missiles[i].ware), "name", "icon")

				if icon == "" then
					icon = "ware_default"
				end

				table.insert(menu.data.ammunition, { missilename, missiles[i].amount, icon, ffi.string(missiles[i].macro) })
				menu.data.ammunition.totalcapacity = menu.data.ammunition.totalcapacity + missiles[i].capacity
				if showcapacity then
					menu.data.ammunition.knowncapacity = menu.data.ammunition.totalcapacity
				end
				if showamount then
					menu.data.ammunition.total = menu.data.ammunition.total + missiles[i].amount
				end
				--local shipname = GetComponentData(menu.object, "name")
				--print(shipname .. " has " .. missiles[i].amount .. " " .. missilename)
			end

			-- and display the ammunition data.
			if menu.data.ammunition.totalcapacity > 0 then
				if not menu.extendedcategories.ammunition then
					-- if the section is not extended, only show the header and the ship's ammunition totals.
					setup:addSimpleRow({
						Helper.createButton(Helper.createButtonText(menu.extendedcategories.ammunition and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, menu.data.ammunition.knowncapacity ~= 0, 0, 0, 0, Helper.standardTextHeight),
						Helper.createFontString(ReadText(1001, 2800) .. " (" .. Helper.unlockInfo(showamount, menu.data.ammunition.total) .. " / " .. Helper.unlockInfo(showcapacity, menu.data.ammunition.knowncapacity) .. ")", false, "left")
					}, nil, { 1, 6 }, false, Helper.defaultHeaderBackgroundColor)
				else
					-- if the section is extended, add "Total Available" to header,
					setup:addSimpleRow({
						Helper.createButton(Helper.createButtonText(menu.extendedcategories.ammunition and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, #menu.data.ammunition ~= 0, 0, 0, 0, Helper.standardTextHeight),
						Helper.createFontString(ReadText(1001, 2800) .. " (" .. Helper.unlockInfo(showamount, menu.data.ammunition.total) .. " / " .. Helper.unlockInfo(showcapacity, menu.data.ammunition.knowncapacity) .. ")", false, "left"),
						ReadText(1001, 1322)
					}, nil, { 1, 4, 2 }, false, Helper.defaultHeaderBackgroundColor)
					-- and add a row for every ammunition type that can be used by menu.object.
					for _, missile in ipairs(menu.data.ammunition) do
						setup:addSimpleRow({
							Helper.getEmptyCellDescriptor(),
							Helper.createButton(nil, Helper.createButtonIcon(missile[3], nil, 255, 255, 255, 100), false, nil),
							Helper.createFontString(Helper.unlockInfo(showcapacity, missile[1]), false, "left"),
							Helper.createFontString(Helper.unlockInfo(showamount, missile[2]), false, "right")
						}, nil, { 1, 1, 3, 2 })
					end
				end
			end
		end
	end
end

function override.createSectionPlayshipUpgrades(setup)
	--- Playership upgrades ---
	if menu.isplayership then
		local playershipupgradecategories = { "engine", "shieldgenerator", "scanner", "software" }
		local playershipupgradetitles = { ReadText(1001, 1103), ReadText(1001, 1317), ReadText(1001, 74), ReadText(1001, 87) }
		local playershipupgradenones = { ReadText(1001, 88), ReadText(1001, 89), ReadText(1001, 90), ReadText(1001, 91) }

		setup:addSimpleRow({
			Helper.createButton(Helper.createButtonText(menu.extendedcategories.playerupgrades and "-" or "+", "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 0, 0, 0, Helper.standardTextHeight),
			Helper.createFontString(ReadText(1001, 3100) .. " (" .. menu.getNumberOfUpgrades(playershipupgradecategories) .. ")", false, "left")
		}, nil, { 1, 6 }, false, Helper.defaultHeaderBackgroundColor)

		if menu.extendedcategories.playerupgrades then
			for i, category in ipairs(playershipupgradecategories) do
				menu.createPlayershipCategory(setup, category, playershipupgradetitles[i], playershipupgradenones[i])
			end
		end
	end
end

function override.createSectionStatistics(setup)
	--- Statistics ---
	if ((menu.type == "station") or ((menu.type == "ship") and GetBuildAnchor(menu.object))) and (GetComponentData(menu.object, "tradesubscription") or menu.isplayer) then
		setup:addSimpleRow({
			Helper.getEmptyCellDescriptor(),
			ReadText(1001, 1131)
		}, { "stats" }, { 1, 6 }, false, Helper.defaultHeaderBackgroundColor)
	end
end

function override.createTableButton()

	local tradeoffers = GetComponentData(menu.object, "tradeoffers") or {}
	menu.sellbuyswitch = nil
	local hasselloffers, hasbuyoffers
	for _, tradeid in ipairs(tradeoffers) do
		local tradedata = GetTradeData(tradeid)
		if tradedata.isbuyoffer then
			hasbuyoffers = true
			if hasselloffers then
				break
			end
		elseif tradedata.isselloffer then
			hasselloffers = true
			if hasbuyoffers then
				break
			end
		end
	end
	if hasselloffers and (not hasbuyoffers) then
		menu.sellbuyswitch = true
	elseif (not hasselloffers) and hasbuyoffers then
		menu.sellbuyswitch = false
	end

	-- button table
	local setup = Helper.createTableSetup(menu)
	local mot_plotcourse
	if not menu.isplayership then
		if menu.type == "station" then
			mot_plotcourse = ReadText(1026, 1109)
		elseif menu.type == "ship" then
			mot_plotcourse = ReadText(1026, 1100)
		elseif menu.type == "block" then
			mot_plotcourse = ReadText(1026, 1104)
		end
	end
	setup:addSimpleRow({
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 2669), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_B", true)),
		Helper.getEmptyCellDescriptor(),
		((menu.type == "station") or ((menu.type == "ship") and GetBuildAnchor(menu.object))) and
				Helper.createButton(Helper.createButtonText(ReadText(1001, 1113), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, #tradeoffers > 0, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_BACK", true), nil, (#tradeoffers > 0) and ReadText(1026, 1108) or nil) or
				(((not C.IsVRVersion()) and (not menu.isplayership)) and
						Helper.createButton(Helper.createButtonText(ReadText(1001, 1133), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, IsFullscreenWidgetSystem() and (not IsFirstPerson()) and C.IsPlayerCameraTargetViewPossible(ConvertIDTo64Bit(menu.object), true), 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_BACK", true), nil, (not IsFullscreenWidgetSystem()) and ReadText(1026, 1123) or nil) or
						Helper.getEmptyCellDescriptor()),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 1109), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, not menu.isplayership, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_Y", true), nil, mot_plotcourse),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 2961), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true)),
		Helper.getEmptyCellDescriptor()
	}, nil, nil, false, menu.transparent)
	return setup:createCustomWidthTable({ 48, 150, 48, 150, 0, 150, 48, 150, 48 }, false, false, true, 2, 1, 0, 555, 0, false)
end

-- button scripts

function override.addButtonScripts()
	local nooflines = 1
	nooflines = menu.addButtonScriptsHeader(nooflines)
	nooflines = menu.addButtonScriptsGeneral(nooflines)
	nooflines = menu.addButtonScriptsEmployees(nooflines)
	nooflines = menu.addButtonScriptsUpkeep(nooflines)
	nooflines = menu.addButtonScriptsProduction(nooflines)
	nooflines = menu.addButtonScriptsStorage(nooflines)
	nooflines = menu.addButtonScriptTradequeue(nooflines)
	nooflines = menu.addButtonScriptsUnits(nooflines)
	nooflines = menu.addButtonScriptsWeapons(nooflines)
	nooflines = menu.addButtonScriptsAmmunition(nooflines)
	nooflines = menu.addButtonScriptsPlayshipUpgrades(nooflines)
	nooflines = menu.addButtonScriptsStatistics(nooflines)

	menu.addButtonScriptsButtonTable()
end

function override.addButtonScriptsHeader(nooflines)
	Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, menu.buttonEncyclopedia)
	return nooflines + 2
end

function override.addButtonScriptsGeneral(nooflines)
	--- General ---
	Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
		return menu.buttonCategoryExtend("general", 3)
	end)
	nooflines = nooflines + 1
	if menu.extendedcategories.general then
		nooflines = nooflines + 1
		if menu.type == "block" then
			nooflines = nooflines + 1
		end
		nooflines = nooflines + 2
		if not IsComponentClass(menu.object, "ship_xl") and not IsComponentClass(menu.object, "ship_l") and not IsComponentClass(menu.object, "station") and menu.type ~= "block" then
			nooflines = nooflines + 1
		end
		if IsComponentClass(menu.object, "ship") then
			nooflines = nooflines + 2
		end
		if menu.data.radarrange > 0 then
			nooflines = nooflines + 1
		end
		if menu.type == "block" and menu.data.efficiencybonus > 0 then
			nooflines = nooflines + 1
		end
		if (menu.type == "station") or ((menu.type == "ship") and GetBuildAnchor(menu.object)) then
			nooflines = nooflines + 1
		end
		if IsComponentClass(menu.object, "ship_xl") or IsComponentClass(menu.object, "ship_l") then
			nooflines = nooflines + 1
		elseif menu.isplayership and GetComponentData(menu.object, "boardingnpc") then
			nooflines = nooflines + 1
		end
	end
	return nooflines
end

function override.addButtonScriptsEmployees(nooflines)
	--- NPCs ---
	if menu.type ~= "block" and not menu.isplayership then
		local categoryline = nooflines
		Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
			return menu.buttonCategoryExtend("npcs", categoryline)
		end)
		nooflines = nooflines + 1 -- npc expand button
		if menu.extendedcategories.npcs then
			for i, npc in ipairs(menu.data.controlentities) do

				local npcRow = nooflines
				if menu.unlocked.operator_name then
					Helper.setButtonScript(menu, nil, menu.selecttable, npcRow, 2, function()
						local rowdata = menu.rowDataMap[npcRow]
						if GetComponentData(npc, "isremotecommable") then
							xxxLibrary.toggleBookmark(npc)
							menu.setselectedrow = npcRow
							menu.settoprow = GetTopRow(menu.selecttable)
							menu.displayMenu()
							-- return menu.buttonComm(rowdata[2])
						end
					end)
				end

				nooflines = nooflines + 1
				local npcName = GetComponentData(npc, "name")
				if menu.unlocked.managed_ships and #menu.data.npcs[tostring(npc)] > 0 then
					local shipline = nooflines

					shipline = shipline - 1 -- we put the button on the same line

					Helper.setButtonScript(menu, nil, menu.selecttable, shipline, 1, function()
						return menu.buttonCategoryExtend("npcs" .. tostring(npc), shipline)
					end)
					--nooflines = nooflines + 1

					if menu.extendedcategories["npcs" .. tostring(npc)] then

						for i, component in ipairs(menu.data.npcs[tostring(npc)]) do
							local category
							if IsComponentClass(component, "station") then
								category = "stationtypes"
							elseif IsComponentClass(component, "ship_xl") then
								category = "shiptypes_xl"
							elseif IsComponentClass(component, "ship_l") then
								category = "shiptypes_l"
							elseif IsComponentClass(component, "ship_m") then
								category = "shiptypes_m"
							elseif IsComponentClass(component, "ship_s") then
								category = "shiptypes_s"
							elseif IsComponentClass(component, "ship_xs") then
								category = "shiptypes_xs"
							end
							Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 2, function()
								return menu.buttonEncyclopediaCategory(category, GetComponentData(component, "macro"))
							end)
							nooflines = nooflines + 1
						end
						if i ~= #menu.data.controlentities then
							nooflines = nooflines + 1
						end
					end
				end
			end
		end
	end

	--- NPCS II ---
	if menu.type == "station" then
		nooflines = nooflines + 1
	end
	return nooflines
end

function override.addButtonScriptsUpkeep(nooflines)
	--- Upkeep Missions ---
	if not menu.isplayership and menu.isplayer then
		if #menu.data.upkeep > 0 then
			local categoryline = nooflines
			Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
				return menu.buttonCategoryExtend("upkeep", categoryline)
			end)
			nooflines = nooflines + 1

			if menu.extendedcategories.upkeep then
				for _, entry in ipairs(menu.data.upkeep) do
					nooflines = nooflines + 1
				end
			end
		end
	end
	return nooflines
end

function override.addButtonScriptsProduction(nooflines)
	--- Production ---
	if menu.data.productionmodules and #menu.data.productionmodules > 0 then
		local categoryline = nooflines
		Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
			return menu.buttonCategoryExtend("production", categoryline)
		end)
		nooflines = nooflines + 1
		if menu.extendedcategories.production then
			for _, module in ipairs(menu.data.productionmodules) do
				if next(menu.data.proddata[tostring(module)]) then
					nooflines = nooflines + 1
				end
			end
		end
	end
	return nooflines
end

function override.addButtonScriptsStorage(nooflines)
	--- Storage ---
	if menu.hasStorageStatus then
		local categoryline = nooflines
		Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
			return menu.buttonCategoryExtend("storage", categoryline)
		end)
		nooflines = nooflines + 1
		if menu.extendedcategories.storage then
			for ware, amount in Helper.orderedPairsByWareName(menu.data.cargo) do
				Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 2, function()
					return menu.buttonEncyclopediaCategory("ware", ware)
				end)
				nooflines = nooflines + 1
			end
		end
	end
	return nooflines
end

function override.addButtonScriptTradequeue(nooflines)
	--- Tradequeue ---
	if not menu.dontdisplaytradequeue then
		if next(menu.data.tradequeue) then
			menu.tradequeuestart = nooflines
			Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
				return menu.buttonCategoryExtend("tradequeue", menu.tradequeuestart)
			end)
			nooflines = nooflines + 1
			if menu.extendedcategories.tradequeue then
				for i, item in ipairs(menu.data.tradequeue) do
					nooflines = nooflines + 1
				end
			end
		end
	end
	return nooflines
end

function override.addButtonScriptsUnits(nooflines)
	--- Units ---
	if IsComponentClass(menu.object, "defensible") and (menu.data.units.header or menu.isplayership) then
		local categoryline = nooflines
		Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
			return menu.buttonCategoryExtend("units", categoryline)
		end)
		nooflines = nooflines + 1
		if menu.extendedcategories.units then
			for _, unit in ipairs(menu.data.units) do
				if unit.amount > 0 then
					Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 2, function()
						return menu.buttonEncyclopediaCategory("unit", unit.macro)
					end)
					nooflines = nooflines + 1
				end
			end
			if menu.isplayership then
				--[[
				if menu.hasunit then
					nooflines = nooflines + 1
				end
				]]
				if #menu.data.playerdrones > 0 then
					for _, drone in ipairs(menu.data.playerdrones) do
						Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 2, function()
							return menu.buttonEncyclopediaCategory("unit", drone.macro)
						end)
						nooflines = nooflines + 1
					end
				end
			end
		end
	end
	return nooflines
end

function override.addButtonScriptsWeapons(nooflines)
	--- Weapons ---
	if menu.hasDefenceStatus then
		local categoryline = nooflines
		Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
			return menu.buttonCategoryExtend("weapons", categoryline)
		end)
		nooflines = nooflines + 1

		if menu.extendedcategories.weapons then
			if not menu.isplayership then
				for ut, upgrade in Helper.orderedPairs(menu.data.upgrades) do
					if (ut == "shieldgenerator" or ut == "shieldgenerator_cap") and not (ut == "totaltotal" or ut == "totalfree" or ut == "totaloperational" or ut == "totalconstruction" or ut == "estimated") then
						if upgrade.total ~= 0 then
							local shieldline = nooflines
							Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 2, function()
								return menu.buttonCategoryExtend("shield_" .. ut, shieldline)
							end)
							nooflines = nooflines + 1

							if menu.extendedcategories["shield_" .. ut] then
								if menu.data.upgradeShields[ut]["count"] > 0 then
									for macro, shieldTypeData in pairs(menu.data.upgradeShields[ut]) do
										if macro ~= "count" then

											Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 2, function()
												return menu.buttonEncyclopediaWeapon("shieldgentypes", macro)
											end)

											nooflines = nooflines + 1
										end
									end

									nooflines = nooflines + 1
								end
							end
						end
					end
				end

				for ut, upgrade in Helper.orderedPairs(menu.data.upgrades) do
					if not (ut == "shieldgenerator" or ut == "shieldgenerator_cap") and not (ut == "totaltotal" or ut == "totalfree" or ut == "totaloperational" or ut == "totalconstruction" or ut == "estimated") then
						if upgrade.total ~= 0 then
							if string.match(ut, "turret") then
								local macroName = ut .. "_macro"
								-- upgrade turrets have proper macros
								Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 2, function()
									return menu.buttonEncyclopediaWeapon("turrettypes", macroName)
								end)
							end
							nooflines = nooflines + 1
						end
					end
				end

				for macro, turret in pairs(menu.notupgradeturrets) do
					if type(turret) == "table" and turret.operational ~= 0 then
						Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 2, function()
							return menu.buttonEncyclopediaWeapon("turrettypes", turret.macro)
						end)
						nooflines = nooflines + 1
					end
				end
			end

			if #menu.data.weapons.weapons ~= 0 then
				if not menu.isplayership then
					nooflines = nooflines + 1
				end
				for i, weapon in ipairs(menu.data.weapons.weapons) do
					Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 2, function()
						return menu.buttonEncyclopediaWeapon("weapontypes_primary", weapon.macro)
					end)
					nooflines = nooflines + 1
				end
			end
			if #menu.data.weapons.missiles ~= 0 then
				local header = false
				for _, missile in ipairs(menu.data.weapons.missiles) do
					if missile.amount > 0 then
						if not header then
							nooflines = nooflines + 1
							header = true
						end
						Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 2, function()
							return menu.buttonEncyclopediaWeapon("weapontypes_secondary", missile.macro)
						end)
						nooflines = nooflines + 1
					end
				end
			end
		end
	end
	return nooflines
end

function override.addButtonScriptsAmmunition(nooflines)
	--- Ammunition ---
	if not menu.isplayership then
		if menu.data.ammunition.totalcapacity > 0 then
			local categoryline = nooflines
			-- function Helper.setButtonScript(menu, id, tableobj, row, col, script, overSound, downSound)
			-- returns "menu.buttonCategoryExtend()" if the specified button is activated. this sets menu.extendedcategories.ammunition when activated.
			--	for further functionality of that button look up menu.extendedcategories.ammunition in menu.displayMenu()
			Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
				return menu.buttonCategoryExtend("ammunition", categoryline)
			end)
			nooflines = nooflines + 1
			if menu.extendedcategories.ammunition and #menu.data.ammunition then
				for _, ammo in ipairs(menu.data.ammunition) do
					Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 2, function()
						return menu.buttonEncyclopediaWeapon("weapontypes_secondary", ammo[4])
					end)
					nooflines = nooflines + 1
				end
			end
		end
	end
	return nooflines
end

function override.addButtonScriptsPlayshipUpgrades(nooflines)
	--- Playership upgrades ---
	if menu.isplayership then
		local categoryline = nooflines
		Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
			return menu.buttonCategoryExtend("playerupgrades", categoryline)
		end)

		local playershipupgradecategories = { "engine", "shieldgenerator", "scanner", "software" }

		if menu.extendedcategories.playerupgrades then
			nooflines = nooflines + 1
			for i, category in ipairs(playershipupgradecategories) do
				nooflines = menu.createPlayershipCategoryButtons(category, nooflines)
			end
		end
	end
	return nooflines
end

function override.addButtonScriptsStatistics(nooflines)
	--- Statistics ---
	if ((menu.type == "station") or ((menu.type == "ship") and GetBuildAnchor(menu.object))) and (GetComponentData(menu.object, "tradesubscription") or menu.isplayer) then
		nooflines = nooflines + 1
	end
	return nooflines
end

function override.addButtonScriptsButtonTable()
	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 2, function()
		return menu.onCloseElement("back")
	end)
	if (menu.type == "station") or ((menu.type == "ship") and GetBuildAnchor(menu.object)) then
		Helper.setButtonScript(menu, nil, menu.buttontable, 1, 4, menu.buttonTradeOffers)
	else
		Helper.setButtonScript(menu, nil, menu.buttontable, 1, 4, menu.buttonShow)
	end
	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 6, menu.buttonPlotCourse)
	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 8, menu.buttonDetails)
	return nooflines
end

function override.fetchShieldgenerators()
	local ret = {}
	ret["unknown"] = { count = 0 }
	ret["shieldgenerator"] = { count = 0 }
	ret["shieldgenerator_cap"] = { count = 0 }

	-- it looks like shieldgenerator are only return when are nearby the station/ship (range: unknown ....)
	local shieldgenerators = GetComponentData(menu.object, "shieldgenerators")
	for _, shieldgenerator in ipairs(shieldgenerators) do
		local macro, name, icon = GetComponentData(shieldgenerator, "macro", "name", "icon")

		local type = "unknown"
		if string.match(macro, "shieldgenerator_size_m") then
			type = "shieldgenerator"
		elseif string.match(macro, "shieldgenerator_size_l") then
			type = "shieldgenerator_cap"
		end

		if icon == "" then
			icon = "ware_default"
		end

		if ret[type][macro] then
			ret[type]["count"] = ret[type]["count"] + 1
			ret[type][macro]["count"] = ret[type][macro]["count"] + 1
		else
			ret[type]["count"] = ret[type]["count"] + 1
			ret[type][macro] = {
				macro = macro,
				name = name,
				icon = icon,
				count = 1
			}
		end
	end

	table.sort(ret.shieldgenerator, function(a, b)
		if type(a) == 'table' and type(b) == 'table' then
			return a.name < b.name
		else
			return false
		end
	end)
	table.sort(ret.shieldgenerator_cap, function(a, b)
		if type(a) == 'table' and type(b) == 'table' then
			return a.name < b.name
		else
			return false
		end
	end)
	return ret
end

local function init()
	for mnuKey, existingMenu in ipairs(Menus) do
		if existingMenu.name == "ObjectMenu" then
			menu = existingMenu
			for k, v in pairs(override) do
				menu[k] = v
			end
			break
		end
	end
end

init()
