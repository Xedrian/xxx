local overrideFuncs = {}

local xxxMainMenu = {
	originalMainMenuCreateSetup = nil
}

local menu = {}

function overrideFuncs.crewlist(playership, onplatform, incockpit, hascrew)

	local items = {}

	if onplatform then
		table.insert(items, {
			-- return to ship
			icon = "mm_ic_crew_exitplatform",
			name = ReadText(1002, 1006),
			section = "gMain_leavePlatform",
			info = ReadText(1002, 21049),
			shortcut = { "action", 211 } -- "INPUT_ACTION_UNDOCK"
		})
	elseif not incockpit then
		table.insert(items, {
			-- Return to cockpit
			icon = "mm_ic_crew_entercockpit",
			name = ReadText(1002, 1007),
			section = "gMain_leavePlatform",
			info = ReadText(1002, 21050)
		})
	else
		-- Crew
		table.insert(items, {
			icon = "mm_ic_crew_enterbackroom",
			name = ReadText(1002, 20006),
			section = "gMain_crew",
			info = ReadText(1002, 21051)
		})
	end

	-- talk to crew via com is always available
	table.insert(items, {
		-- Talk to crew remotely
		icon = "mm_ic_crew_callremotely",
		name = ReadText(1002, 1076),
		section = "gMain_crewList",
		sectionparam = { 0, 0, playership },
		condition = hascrew,
		info = ReadText(1002, 21048)
	})
	return items
end

function overrideFuncs.commlinklist(playersector)

	-- only list was updated ---
	-- IMPORTANT: Keep in sync with detailmonitor/menu_remotenpcs.lua
	local entitytypesetup = {
		-- Crew for Albion Skunk
		[1] = { { type = "pilot", info = ReadText(1002, 21019) }, { type = "engineer", info = ReadText(1002, 21020) }, { type = "marine", info = ReadText(1002, 21021) }, icon = "mm_ic_comm_crewforplayer", name = ReadText(1002, 20002), info = ReadText(1002, 21018) },
		-- Crew for capital ship
		[2] = { { type = "commander", info = ReadText(1002, 21023) }, { type = "engineer", info = ReadText(1002, 21024) }, { type = "defencecontrol", info = ReadText(1002, 21025) }, { type = "architect", info = ReadText(1002, 21026) }, icon = "mm_ic_comm_crewforcapship", name = ReadText(1002, 20003), info = ReadText(1002, 21022) },
		-- Crew for station
		[3] = { { type = "manager", info = ReadText(1002, 21028) }, { type = "engineer", info = ReadText(1002, 21024) }, { type = "defencecontrol", info = ReadText(1002, 21029) }, icon = "mm_ic_comm_crewforstation", name = ReadText(1002, 20004), info = ReadText(1002, 21027) },
		-- Specialist for station
		[4] = { { type = "specialistagriculture", info = ReadText(1002, 21501) }, { type = "specialistpowerstorage", info = ReadText(1002, 21502) }, { type = "specialistfood", info = ReadText(1002, 21503) }, { type = "specialistchemical", info = ReadText(1002, 21504) }, { type = "specialistprecision", info = ReadText(1002, 21505) }, { type = "specialistweapons", info = ReadText(1002, 21506) }, { type = "specialistpharmaceuticals", info = ReadText(1002, 21507) }, { type = "specialistmetals", info = ReadText(1002, 21508) }, { type = "specialistgeophysics", info = ReadText(1002, 21509) }, { type = "specialistsurfacesystems", info = ReadText(1002, 21510) }, { type = "specialistpowersupply", info = ReadText(1002, 21511) }, { type = "specialistaquatics", info = ReadText(1002, 21512) }, icon = "mm_ic_comm_specialistforstation", name = ReadText(1002, 20005), info = ReadText(1002, 21030) },
		-- Trader
		[5] = { { type = "miningsupplier", info = ReadText(1002, 21034) }, { type = "junkdealer", info = ReadText(1002, 21035) }, { type = "spacefarmer", info = ReadText(1002, 21036) }, { type = "shiptech", info = ReadText(1002, 21037) }, { type = "equipment", info = ReadText(1002, 21038) }, { type = "foodmerchant", info = ReadText(1002, 21039) }, { type = "shadyguy", info = ReadText(20208, 2301) }, icon = "mm_ic_comm_trader", name = ReadText(1002, 12032), info = ReadText(1002, 21031) },
		-- Ship services
		[6] = { { type = "shiptrader", info = ReadText(1002, 21032) }, { type = "smallshiptrader", info = ReadText(1002, 21052) }, { type = "licencetrader", info = ReadText(1002, 21033) }, { type = "engineer", info = ReadText(1002, 21041) }, { type = "upgradetrader", info = ReadText(1002, 21042) }, { type = "dronetrader", info = ReadText(1002, 21043) }, { type = "armsdealer", info = ReadText(1002, 21044) }, { type = "recruitment", info = ReadText(1002, 21045) }, icon = "mm_ic_comm_services", name = ReadText(1002, 12036), info = ReadText(1002, 21040) },
	}

	--- the rest of code was left untouched

	local npcs = playersector and GetNPCsInSectorOnStations(playersector, 60000) or {}

	local returnvalue = {}
	-- Mission contacts
	local count = menu.npccount(npcs, nil, true)
	table.insert(returnvalue, { icon = "mm_ic_comm_missioncontacts", name = ReadText(1002, 20001) .. " (" .. count .. ")", condition = count > 0, section = "gMain_remoteNPCList", sectionparam = { 0, 0, nil, true }, info = ReadText(1002, 21017) })

	for i, section in ipairs(entitytypesetup) do
		local list = {}
		local totalcount = 0
		for _, type in ipairs(section) do
			local icon, name = GetEntityTypeData(type.type, "icon", "name")
			count = menu.npccount(npcs, type.type)
			totalcount = totalcount + count
			table.insert(list, { icon = icon, name = name .. " (" .. count .. ")", condition = count > 0, section = "gMain_remoteNPCList", sectionparam = { 0, 0, type.type, nil, i + 1 }, info = type.info })
		end
		table.insert(returnvalue, { icon = section.icon, name = section.name .. " (" .. totalcount .. ")", condition = totalcount > 0, list = list, info = section.info })
	end

	-- Police Chief
	count = menu.npccount(npcs, "lawenforcement")
	local icon, name = GetEntityTypeData("lawenforcement", "icon", "name")
	table.insert(returnvalue, { icon = icon, name = name .. " (" .. count .. ")", condition = count > 0, section = "gMain_remoteNPCList", sectionparam = { 0, 0, "lawenforcement", nil }, info = ReadText(1002, 21046) })

	return returnvalue
end

function overrideFuncs.xxxCreateSetup()
	xxxMainMenu.originalMainMenuCreateSetup()
	-- add booksmarks to trade section
	table.insert(menu.setup.top[6].list, {
		icon = "mm_ic_trading",
		name = "Bookmarks",
		section = "gMain_xxxBookmarks",
		sectionparam = { 0, 0 }
	})
end

local function init()
	if Menus then
		for _, existingMenu in ipairs(Menus) do
			if existingMenu.name == "MainMenu" then
				menu = existingMenu
				xxxMainMenu.originalMainMenuCreateSetup = menu.createSetup
				menu.createSetup = overrideFuncs.xxxCreateSetup
				menu.commlinklist = overrideFuncs.commlinklist
				menu.crewlist = overrideFuncs.crewlist
			end
		end
	end
end

init()
