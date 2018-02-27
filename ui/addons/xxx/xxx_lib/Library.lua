-- ffi setup
local ffi = require("ffi")
local C = ffi.C
ffi.cdef [[
	typedef uint64_t UniverseID;
	typedef struct {
    	const char* name;
    	float hull;
    	float shield;
    	bool hasShield;
	} ComponentDetails;
	typedef struct {
		int64_t trade;
		int64_t defence;
		int64_t missile;
	} SupplyBudget;
	UniverseID GetPlayerID(void);
	UniverseID GetPlayerCoPilotID(void);
	UniverseID GetPlayerComputerID(void);
	UniverseID GetPlayerObjectID(void);
	UniverseID GetPlayerShipID(void);
	ComponentDetails GetComponentDetails(const UniverseID componentid);
	bool IsShip(const UniverseID componentid);
	bool IsStation(const UniverseID componentid);
	SupplyBudget GetSupplyBudget(UniverseID containerid);
]]

xxxLibrary = {}

function xxxLibrary.isStation(compontent)
	return C.IsStation(ConvertStringTo64Bit(tostring(compontent)));
end

function xxxLibrary.isShip(component)
	return C.IsShip(ConvertStringTo64Bit(tostring(component)));
end

function xxxLibrary.getColorStringForComponent(component)
	local retString = ""
	local retColor = Helper.standardColor
	local owner, isEmemy = GetComponentData(component, "owner", "isenemy")
	if owner == "player" then
		retString = Helper.colorStringGreen
		retColor = Helper.statusGreen
	elseif isEmemy then
		retString = Helper.colorStringRed
		retColor = Helper.statusRed
	end
	return retString, retColor
end

function xxxLibrary.getColorStringForCombinedSkill(combinedskill)
	local color = Helper.colorStringRed
	if combinedskill >= 40 then
		color = Helper.colorStringOrange
		if combinedskill >= 60 then
			color = Helper.colorStringYellow
			if combinedskill >= 80 then
				color = Helper.colorStringGreen
				if combinedskill >= 100 then
					color = Helper.colorStringCyan
				end
			end
		end
	end
	return color
end

function xxxLibrary.darkenColor(color, toPercentBrightness)
	local theColor = {} -- avoid by ref problems ;)
	if not (toPercentBrightness < 1) then
		toPercentBrightness = toPercentBrightness / 100
	end
	theColor["r"] = math.floor(color.r * toPercentBrightness)
	theColor["g"] = math.floor(color.g * toPercentBrightness)
	theColor["b"] = math.floor(color.b * toPercentBrightness)
	theColor["a"] = color.a
	return theColor
end

function xxxLibrary.getColorStringForSkillValue(skill)
	local color = Helper.colorStringRed
	if skill >= 2 then
		color = Helper.colorStringOrange
		if skill >= 3 then
			color = Helper.colorStringYellow
			if skill >= 4 then
				color = Helper.colorStringGreen
				if skill >= 5 then
					color = Helper.colorStringCyan
				end
			end
		end
	end
	return color
end

function xxxLibrary.createStarsText(value)
	return Helper.createFontString(value, false, "center", 255, 255, 255, 100, Helper.starFont, Helper.standardFontSize, nil, nil, (Helper.standardTextHeight - Helper.standardFontSize) / 2)
end

function xxxLibrary.createNpcBookmarkIconButton(npc, getButtonForTrueOrIconForFalse, useOwnerIcon)
	local ret
	local isenemy, typeicon = GetComponentData(npc, "isenemy", useOwnerIcon and "ownericon" or "typeicon")

	-- use white if button & bookmarked OR Icon only
	local color = (xxxLibrary.isBookmark(npc) and getButtonForTrueOrIconForFalse or not getButtonForTrueOrIconForFalse) and { r = 255, g = 255, b = 255, a = 100 } or nil

	if getButtonForTrueOrIconForFalse then
		local icon = Helper.createButtonIcon(typeicon, nil, 255, 255, 255, 100)
		ret = Helper.createButton(nil, icon, false, nil, nil, nil, Helper.standardTextHeight, Helper.standardTextHeight, color, nil)
	else
		ret = Helper.createIcon(typeicon, false, color.r, color.g, color.b, color.a, 0, 0, Helper.standardTextHeight, Helper.standardTextHeight)
	end
	return ret
end

function xxxLibrary.getPlayerEntity()
	return ConvertStringTo64Bit(tostring(C.GetPlayerID()))
end

function xxxLibrary.getBookmarks()
	-- local entityId = playerShipId
	local bookmarks = GetNPCBlackboard(xxxLibrary.getPlayerEntity(), "$xxxBookmarks") or {}
	if type(bookmarks) ~= 'table' then
		bookmarks = {}
	end

	local bookmarksToLoad = {}

	for _, bookmark in ipairs(bookmarks) do
		if type(bookmark) ~= "string" and IsValidComponent(bookmark) then
			table.insert(bookmarksToLoad, bookmark)
		end
	end
	return bookmarks
end

function xxxLibrary.setBookmarks(bookmarks)
	local bookmarksToSave = {}
	for _, bookmark in ipairs(bookmarks) do
		if IsValidComponent(bookmark) then
			table.insert(bookmarksToSave, bookmark)
		end
	end

	SetNPCBlackboard(xxxLibrary.getPlayerEntity(), "$xxxBookmarks", bookmarksToSave)
end

function xxxLibrary.isBookmark(entity)
	local entityKey = tostring(entity)
	local bookmarks = xxxLibrary.getBookmarks()
	local found = false
	for _, bookmarkedEntity in ipairs(bookmarks) do
		if tostring(bookmarkedEntity) == entityKey then
			found = true
			break
		end
	end
	return found
end

function xxxLibrary.addBookmark(entity)
	-- local entityKey = tostring(entity)
	if not xxxLibrary.isBookmark(entity) then
		local bookmarks = xxxLibrary.getBookmarks()
		table.insert(bookmarks, entity)
		xxxLibrary.setBookmarks(bookmarks)
		SetNPCBlackboard(entity, "$xxxBookmarkFlag", 1)
	end
end

function xxxLibrary.removeBookmark(entity)
	local entityKey = tostring(entity)
	if xxxLibrary.isBookmark(entity) then
		local bookmarks = xxxLibrary.getBookmarks()
		local newBookmarks = {}
		for _, bookmarkedEntity in ipairs(bookmarks) do
			if not (tostring(bookmarkedEntity) == entityKey) then
				table.insert(newBookmarks, bookmarkedEntity)
			end
		end
		xxxLibrary.setBookmarks(newBookmarks)
		SetNPCBlackboard(entity, "$xxxBookmarkFlag", nil)
	end
end

function xxxLibrary.toggleBookmark(entity)
	if xxxLibrary.isBookmark(entity) then
		xxxLibrary.removeBookmark(entity)
	else
		xxxLibrary.addBookmark(entity)
	end
end

function xxxLibrary.indentSubordinateName(name, iteration)

	if iteration == nil then
		iteration = 1
	end

	-- iteration indent
	if iteration > 0 then
		-- name = " " .. name
		for i = 1, iteration do
			name = "  " .. name
		end
		-- name = " " .. name
	end

	return name
end

function xxxLibrary.hasObjectWarningSplit(object)
	local error = 0
	local cargoWarning = 0
	local creditWarning = 0

	if IsComponentOperational(object) then
		local buildingmodule = GetComponentData(object, "buildingmodule")
		local buildingarchitect
		local buildingcontainer
		if buildingmodule then
			buildingcontainer = GetContextByClass(buildingmodule, "container")
			if buildingcontainer then
				buildingarchitect = GetComponentData(buildingcontainer, "architect")
			end
		end

		local traderestrictions = GetTradeRestrictions(object)
		local hasmanager = GetComponentData(object, "tradenpc")
		if IsComponentClass(object, "station") and not hasmanager then
			-- No manager
			error = error > 1 and error or 2
		elseif hasmanager then
			if not traderestrictions.faction then
				local wantedmoney = GetComponentData(hasmanager, "productionmoney")
				local supplybudget = C.GetSupplyBudget(ConvertIDTo64Bit(object))
				wantedmoney = wantedmoney + tonumber(supplybudget.trade) / 100 + tonumber(supplybudget.defence) / 100 + tonumber(supplybudget.missile) / 100
				if wantedmoney > GetAccountData(hasmanager, "money") then
					-- not enough money
					creditWarning = creditWarning > 0 and 2 or 1
				end
			else
				local subordinaterangecomponent = GetNPCBlackboard(hasmanager, "$config_subordinate_range")
				if not subordinaterangecomponent then
					if GetComponentData(object, "maxradarrange") > 30000 then
						subordinaterangecomponent = GetContextByClass(object, "cluster")
					else
						subordinaterangecomponent = GetContextByClass(object, "sector")
					end
				end
				if not IsContainerOperationalRangeSufficient(object, subordinaterangecomponent) then
					-- operational range too short
					error = error > 0 and error or 1
				end
			end
		end
		local architect = GetComponentData(object, "architect")
		if architect then
			if not traderestrictions.faction then
				if GetComponentData(architect, "wantedmoney") > GetAccountData(architect, "money") then
					-- not enough money
					creditWarning = creditWarning > 0 and 2 or 1
				end
			end
		end
		if buildingarchitect then
			local buildingtraderestrictions = GetTradeRestrictions(buildingcontainer)
			if not buildingtraderestrictions.faction then
				if GetComponentData(buildingarchitect, "wantedmoney") > GetAccountData(buildingarchitect, "money") then
					-- not enough money
					creditWarning = creditWarning > 0 and 2 or 1
				end
			end
		end

		local productionmodules = GetProductionModules(object)
		local productcycleamounts = {}
		for _, module in ipairs(productionmodules) do
			if IsComponentOperational(module) then
				if not GetComponentData(module, "isproducing") then
					-- not producing
					error = error > 1 and error or 2
				end

				local proddata = GetProductionModuleData(module)
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
		end

		local products, resources = GetComponentData(object, "products", "pureresources")
		local cargo = GetComponentData(object, "cargo")
		if next(products) then
			for _, ware in ipairs(products) do
				local cycleamount = productcycleamounts[ware] and productcycleamounts[ware] + 1 or 0
				if GetWareCapacity(object, ware, false) <= cycleamount or (GetWareProductionLimit(object, ware) - cycleamount) < (cargo[ware] or 0) then
					-- not enough storage
					error = error > 1 and error or 2
				end
			end
		end
		if next(resources) then
			for _, ware in ipairs(resources) do
				if GetWareCapacity(object, ware, false) == 0 or GetWareProductionLimit(object, ware) < (cargo[ware] or 0) then
					-- not enough storage
					cargoWarning = cargoWarning > 0 and cargoWarning or 1
				end
			end
		end
	end

	return error, cargoWarning, creditWarning
end

function xxxLibrary.componentNameUpdate(component, name, iteration, sellship)

	name = xxxLibrary.componentPrefixName(component) .. name .. xxxLibrary.componentPostfixName(component)

	-- auto pilot target
	if not sellship and IsSameComponent(GetAutoPilotTarget(), component) then
		name = ">> " .. name
	end

	name = xxxLibrary.indentSubordinateName(name, iteration)

	return name
end

function xxxLibrary.componentPrefixName(component)
	local sPrefix = ""
	return sPrefix
end

function xxxLibrary.getSubordinates(component)
	local subordinates = GetSubordinates(component)
	for i = #subordinates, 1, -1 do
		if IsComponentClass(subordinates[i], "ship_xs") then
			table.remove(subordinates, i)
		end
	end
	return subordinates
end

function xxxLibrary.componentPostfixName(component)
	local sPostfix = ""

	-- trips
	local isShip = IsComponentClass(component, "ship")
	if isShip and (not GetBuildAnchor(component)) then
		local numtrips = GetComponentData(component, "numtrips")
		if numtrips > 0 then
			local maxtrips = (PlayerPrimaryShipHasContents("trademk3") and 7) or (PlayerPrimaryShipHasContents("trademk2") and 5) or 3
			sPostfix = sPostfix .. " (" .. numtrips .. "/" .. maxtrips .. ")"
		end
	end

	if true then

		-- self damage
		local damageIndicator, damageColor, damageText = xxxLibrary.fetchDamageIndicator(component)
		if damageIndicator > 0 then
			sPostfix = sPostfix .. " | " .. damageColor .. damageText .. Helper.colorStringDefault
		end

		--[[ -- removed the expand/collapse button is colored instead
		-- subordinate hull-damage indicator
		local subOrdinateCriticalDamage, subOrdinateCriticalDamageColor = xxxLibrary.subordinatesHasCriticalDamage(component)
		if subOrdinateCriticalDamage > 0 then
			sPostfix = sPostfix .. " | " .. subOrdinateCriticalDamageColor .. ReadText(1001, 1503) .. "!!" -- text: subordinates
			sPostfix = sPostfix .. Helper.colorStringDefault
		end
		]]
	end

	return sPostfix
end

function xxxLibrary.subordinatesHasCriticalDamage(subordinates)
	local criticalDamageLevel = 0 -- 1: at least one subordinate has hull < 70%, 2: at least one subordinate has hull < 45%
	local criticalDamageLevelColor = Helper.colorStringDefault
	for i = #subordinates, 1, -1 do
		local thisCriticalDamageLevel, thisCriticalDamageLevelColor = xxxLibrary.fetchDamageIndicator(subordinates[i])
		if thisCriticalDamageLevel > criticalDamageLevel then
			criticalDamageLevel = thisCriticalDamageLevel
			criticalDamageLevelColor = thisCriticalDamageLevelColor
			if criticalDamageLevel > 1 then
				break -- -- dont process further sub if max dmg-level found
			end
		end

		local subordinates2 = xxxLibrary.getSubordinates(subordinates[i])
		local criticalDamageLevelFromSub, criticalDamageLevelColorFromSub = xxxLibrary.subordinatesHasCriticalDamage(subordinates2)
		if criticalDamageLevelFromSub > criticalDamageLevel then
			criticalDamageLevel = criticalDamageLevelFromSub
			criticalDamageLevelColor = criticalDamageLevelColorFromSub
			if criticalDamageLevel > 1 then
				break -- -- dont process further sub if max dmg-level found
			end
		end
	end
	return criticalDamageLevel, criticalDamageLevelColor
end

function xxxLibrary.fetchDamageIndicator(compontent)
	local damageIndicator = 0
	local damageColor = Helper.colorStringDefault
	local damageText = ''

	-- local hullPercent, shieldPercent, shieldMax = GetComponentData(compontent, "hullpercent", "shieldpercent", "shieldmax")
	local cDetail = C.GetComponentDetails(ConvertIDTo64Bit(compontent));
	local hullPercent = cDetail.hull;
	local shieldPercent = cDetail.shield;
	local shieldMax = cDetail.hasShield and 100 or 0;
	-- DebugError(cDetail.hull .. "|" .. cDetail.shield .. "|" .. (cDetail.hasShield and "1" or "0"));

	if (hullPercent <= 70) and (shieldMax > 0 and shieldPercent <= 10 or shieldMax == 0) then
		-- if (shields <= 10% or no shields at all) and hull is damaged @70%
		if hullPercent <= 45 then
			damageIndicator = 3
			damageColor = Helper.colorStringRed
			damageText = ReadText(10002, 56) -- hull critical
		elseif hullPercent <= 70 then
			damageIndicator = 2
			damageColor = Helper.colorStringOrange
			damageText = ReadText(10002, 55) -- hull damaged
		end
	else
		if shieldMax > 0 then
			if shieldPercent <= 30 then
				damageIndicator = 1
				damageColor = Helper.colorStringYellow
				damageText = ReadText(10002, 50) -- shields critical
			end
		end
	end
	return damageIndicator, damageColor, damageText
end

function xxxLibrary.fetchComponentCrewSkills(component)

	local threeStarContent
	local threeStarContentText = ""
	local threeStarItems = { "tradenpc", "engineer", "defencenpc" }

	if xxxLibrary.isShip(component) then
		threeStarItems = { "pilot", "engineer", "defencenpc" }
	end

	local macro = GetComponentData(component, "macro")

	if string.match(macro, "units_size_m_") or string.match(macro, "units_size_s_") then
		-- if small ship, we have only controlentity/pilot
		threeStarItems = { "pilot" }
	end

	local npcDataAll = {
	-- controlentity = { exists = false, skill = 0, name = "" }, -- manager or captain or pilot
		tradenpc = { exists = false, skill = 0, name = "" },
		pilot = { exists = false, skill = 0, name = "" },
		engineer = { exists = false, skill = 0, name = "" },
		defencenpc = { exists = false, skill = 0, name = "" },
	}

	for _, npcKey in ipairs(threeStarItems) do
		local npc = GetComponentData(component, npcKey)
		if npc ~= nil then
			npcDataAll[npcKey].exists = true
			npcDataAll[npcKey].skill, npcDataAll[npcKey].name = GetComponentData(npc, "combinedskill", "name")
		end
	end

	for _, npcKey in ipairs(threeStarItems) do
		local color = npcDataAll[npcKey].exists and xxxLibrary.getColorStringForCombinedSkill(npcDataAll[npcKey].skill) or Helper.colorStringDefault
		local text = npcDataAll[npcKey].exists and "*" or "#"
		threeStarContentText = threeStarContentText .. color .. text
	end

	if threeStarContentText ~= "" then
		threeStarContent = xxxLibrary.createStarsText(threeStarContentText)
	end
	return threeStarContent
end

function xxxLibrary.internalGetSequenceAndStage(buildtree, seqInfo)
	if seqInfo.seqidx == 0 then
		return "", 0
	elseif seqInfo.stageidx == 0 then
		return buildtree[seqInfo.seqidx].sequence, 0
	elseif seqInfo.seqidx then
		return buildtree[seqInfo.seqidx].sequence, buildtree[seqInfo.seqidx][seqInfo.stageidx].stage
	end
end

function xxxLibrary.internalGetBuildStatus(buildtree, cursequence, curstage, seqInfo)
	local sequence, stage = xxxLibrary.internalGetSequenceAndStage(buildtree, seqInfo)
	local buildingState
	if sequence and stage then
		if cursequence and cursequence == sequence and curstage == stage then
			-- currently building this stage
			buildingState = 0
		elseif sequence == "" and stage == 0 then
			-- base module done (base module is always either "building" or "done")
			buildingState = 1
		elseif buildtree[seqInfo.seqidx][seqInfo.stageidx].stage <= buildtree[seqInfo.seqidx].currentstage then
			buildingState = 1
		elseif not cursequence and (seqInfo.stageidx == 1 or buildtree[seqInfo.seqidx][seqInfo.stageidx - 1].stage == buildtree[seqInfo.seqidx].currentstage) then
			-- available (not currently building, stage is the first one not built in this sequence)
			buildingState = 0
		else
			-- not built and not available yet
			buildingState = 0
		end
		return buildingState
	end
end



-- for stations only!
function xxxLibrary.fetchStationBuildingStatus(component)

	local ret = ""
	local completed = false

	local buildingmodule = GetComponentData(component, "buildingmodule")
	if buildingmodule then
		local buildtree = GetBuildTree(component)

		local debug = false

		if string.find(GetComponentData(component, "name"), "Mil") or string.find(GetComponentData(component, "name"), "Metallschmiede I") then
			-- debugVar("Tree of Mil")
			-- debugVar(buildtree)
			-- debugVar("End: Tree of Mil")
			debug = true
			DebugError(GetComponentData(component, "name"))
		end

		local upgradeImportance = 0.5 -- without upgrades a stage is only complete to 70% (with ALL upgrades => 100%)
		local upgradeCompletionFactor
		local upgradeTable = GetBuildStageUpgrades(component, "", 0, true)
		if upgradeTable.totaltotal > 0 then
			if debug then
				DebugError(upgradeTable.totaloperational .. "/" .. upgradeTable.totaltotal)
			end
			upgradeCompletionFactor = upgradeTable.totaloperational / upgradeTable.totaltotal
		else
			upgradeCompletionFactor = 1
		end
		local stageCount = 1 -- base stage is not in buildtree .. wtf?!
		local stageCountDone = (1 - upgradeImportance) + (upgradeImportance * upgradeCompletionFactor) -- base stage should be always done


		local cursequence, curstage, curprogress = GetCurrentBuildSlot(component)
		for seqidx, seqdata in ipairs(buildtree) do
			for stageidx, stagedata in ipairs(seqdata) do
				stageCount = stageCount + 1
				local seqInfo = { seqidx = seqidx, stageidx = stageidx }
				if xxxLibrary.internalGetBuildStatus(buildtree, cursequence, curstage, seqInfo) == 1 then
					upgradeTable = GetBuildStageUpgrades(component, seqidx, stageidx, true)
					if upgradeTable.totaltotal > 0 then
						upgradeCompletionFactor = upgradeTable.totaloperational / upgradeTable.totaltotal
					else
						upgradeCompletionFactor = 1
					end
					-- we count a stage only to (1-upgradeImportance)% done if no upgrades were selected; 100% done if all upgrades for this stage are build
					stageCountDone = stageCountDone + (1 - upgradeImportance) + (upgradeImportance * upgradeCompletionFactor)
				end
			end
		end

		if debug then
			DebugError("Count-Stages: " .. stageCount .. " - Stage-Done:" .. stageCountDone)
		end

		local totalBuildState = math.floor(stageCountDone / stageCount * 100)
		totalBuildState = string.format("%d%%", totalBuildState)

		if curprogress then
			ret = string.format("%d%%", curprogress) .. " / " .. totalBuildState
		else
			ret = Helper.colorStringGreen .. " + / " .. totalBuildState
		end

		if (stageCount == stageCountDone) and (curprogress == nil) then
			ret = Helper.colorStringCyan .. ReadText(20180212, 1002)
			completed = true
		end
	end
	return ret, completed
end

function xxxLibrary.fetchDroneInfo(component, isSmallCollectorShip)

	local icon
	local relevantDroneCount

	local droneInfoCount = xxxLibrary.fetchDroneInfoCount(component)

	local pilot, architect = GetComponentData(component, "pilot", "architect")
	if pilot or architect then
		local aiCommandRaw = "none"
		if architect then
			local container = GetContextByClass(architect, "container")
			local buildanchor = GetBuildAnchor(container)
			if buildanchor ~= nil then
				aiCommandRaw = "build"
			end
		elseif pilot then
			aiCommandRaw = GetComponentData(pilot, "aicommandraw")
		end

		if aiCommandRaw == "patrol" or aiCommandRaw == "attackobject" or aiCommandRaw == "escort" then
			icon = "xxx_drontype_attack" --  => attack drones
			relevantDroneCount = droneInfoCount.attackDroneCount
		elseif aiCommandRaw == "mining" then
			icon = "xxx_drontype_mine" --  => mining drones
			relevantDroneCount = droneInfoCount.collectorDroneCount
			--TODO: split collector drones:: display ore collector drones for ore collectors and liquid collector drones for liquid collector
		elseif aiCommandRaw == "trade" or aiCommandRaw == "dockat" then
			icon = "xxx_drontype_trade" --  => cargo drones
			relevantDroneCount = droneInfoCount.transportDroneCount
		elseif aiCommandRaw == "build" then
			icon = "xxx_drontype_build" --  => builder drones
			relevantDroneCount = droneInfoCount.buildDroneCount
		end

		if relevantDroneCount ~= nil then
			relevantDroneCount = xxxLibrary.colorizeDroneCount(relevantDroneCount, aiCommandRaw, isSmallCollectorShip)
		end
	end

	return relevantDroneCount, icon
end

function xxxLibrary.colorizeDroneCount(count, aiCommandRaw, isSmallCollectorShip)

	local coloredString = "" .. count -- uncolored so far

	local chooseColor = Helper.colorStringRed -- default color is red (IF: min-values are set to > 0)

	local minForYellow = 0
	local minForGreen = 0

	if aiCommandRaw == "build" then
		-- plz adjust this
		minForYellow = 10
		minForGreen = minForYellow * 2
	elseif aiCommandRaw == "trade" or aiCommandRaw == "dockat" then
		-- plz adjust this
		minForYellow = 10
		minForGreen = minForYellow * 2
	elseif aiCommandRaw == "mining" then
		-- plz adjust this
		if isSmallCollectorShip then
			-- small collector can only take 3 drones so: 1=red, 2=yellow, 3=green
			minForYellow = 2
			minForGreen = 3
		else
			minForYellow = 15
			minForGreen = minForYellow * 2
		end


	elseif aiCommandRaw == "patrol" or aiCommandRaw == "attackobject" or aiCommandRaw == "escort" then
		-- (xed) to my mind ... its not required to colorize attack drones ...
	end

	if minForYellow > 0 or minForGreen > 0 then
		if minForYellow > 0 then
			if count >= minForYellow then
				chooseColor = Helper.colorStringYellow
				if count >= minForGreen then
					chooseColor = Helper.colorStringGreen
				end
			end
		end
		coloredString = chooseColor .. coloredString
	end
	return coloredString
end

function xxxLibrary.fetchDroneInfoCount(component)
	local ret = {
		buildDroneCount = 0,
		collectorDroneCount = 0,
		collectorLiquidDroneCount = 0,
		collectorRubbleCount = 0,
		attackDroneCount = 0,
		transportDroneCount = 0
	}
	local units = GetUnitStorageData(component)
	for _, unit in ipairs(units) do
		if (string.match(unit.macro, "_welder_drone_")) then
			ret.buildDroneCount = ret.buildDroneCount + unit.amount
		elseif (string.match(unit.macro, "_liquid_collector_")) then
			ret.collectorLiquidDroneCount = ret.collectorLiquidDroneCount + unit.amount
			ret.collectorDroneCount = ret.collectorDroneCount + unit.amount
		elseif (string.match(unit.macro, "_rubble_collector_")) then
			ret.collectorRubbleCount = ret.collectorRubbleCount + unit.amount
			ret.collectorDroneCount = ret.collectorDroneCount + unit.amount
		elseif (string.match(unit.macro, "_drone_attackdrone_") or string.match(unit.macro, "_drone_missiledrone_")) then
			ret.attackDroneCount = ret.attackDroneCount + unit.amount
		elseif string.match(unit.macro, "_xs_transp_empty_") then
			ret.transportDroneCount = ret.transportDroneCount + unit.amount
		end
	end
	return ret
end
