-- Character Profile for player faction NPC with own account

-- section == gMain_charProfileMenu
-- param == { 0, 0, entity, budget, showunits, defensible }


local menu = {
	name = "CharProfileMenu",
	transparent = { r = 0, g = 0, b = 0, a = 0 }
}

local function init()
	Menus = Menus or {}
	table.insert(Menus, menu)
	if Helper then
		Helper.registerMenu(menu)
	end
end

function menu.cleanup()
	menu.title = nil
	menu.entity = nil
	menu.budget = nil
	menu.showunits = nil
	menu.defensible = nil

	menu.infotable = nil
	menu.selecttable = nil
end

-- Menu member functions

function menu.buttonEncyclopedia(type, id)
	if type == "marines" then
		Helper.closeMenuForSubSection(menu, false, "gEncyclopedia_character", { 0, 0, "marines", id })
	elseif type == "shiptypes_xs" then
		Helper.closeMenuForSubSection(menu, false, "gEncyclopedia_object", { 0, 0, "shiptypes_xs", id, false })
	end
	menu.cleanup()
end

function menu.buttonUpgrade()
	Helper.closeMenuForSubSection(menu, false, "gMain_skillUpgrade", menu.entity)
	menu.cleanup()
end

function menu.createStarsText(skillvalue, skillsvisible, colorString)
	if skillsvisible then
		local stars = string.rep("*", skillvalue) .. string.rep("#", 5 - skillvalue)
		return Helper.createFontString((colorString ~= nil and colorString or "") .. stars, false, "left", 255, 255, 0, 100, Helper.starFont, 16)
	end
	return Helper.createFontString("?", false, "left")
end

function menu.onShowMenu()
	-- print("CharProfileBudget.onShowMenu "..(menu.param or "(nil)")..(menu.param2 or "(nil)"))
	menu.title = ReadText(1001, 1900)
	menu.entity = menu.param[3]
	menu.budget = (menu.param[4] and menu.param[4] ~= 0)
	menu.showunits = (menu.param[5] and menu.param[5] ~= 0)
	menu.defensible = menu.param[6]

	-- print("Entity "..(GetComponentData(menu.entity, "name") or "(nil)"))

	-- Title line as one TableView
	local setup = Helper.createTableSetup(menu)

	local name, typestring, typeicon, typename, ownericon, skills, skillsvisible, experienceprogress, neededexperience, isplayerowned = GetComponentData(menu.entity, "name", "typestring", "typeicon", "typename", "ownericon", "skills", "skillsvisible", "experienceprogress", "neededexperience", "isplayerowned")
	setup:addTitleRow {
		Helper.createIcon(typeicon, false, 255, 255, 255, 100, 0, 0, Helper.headerCharacterIconSize, Helper.headerCharacterIconSize),
		Helper.createFontString(typename .. " " .. name, false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize),
		Helper.createIcon(ownericon, false, 255, 255, 255, 100, 0, 0, Helper.headerCharacterIconSize, Helper.headerCharacterIconSize) -- text depends on selection
	}

	-- setup:addTitleRow({ ReadText(1001, 1921) }, nil, { 3 })
	setup:addTitleRow({ "" }, nil, { 3 })

	local infodesc = setup:createCustomWidthTable({ Helper.scaleX(Helper.headerCharacterIconSize), 0, Helper.scaleX(Helper.headerCharacterIconSize) }, false, true)

	-- Second TableView, rest of the menu
	setup = Helper.createTableSetup(menu)

	-- Boarding experience and skills
	table.sort(skills, function(a, b)
		return a.relevance > b.relevance
	end)

	setup:addHeaderRow({ "Primary Skills" }, nil, { 4 }) -- primary skill headline
	local addedSecondHeadline = false

	if typestring == "marine" then
		-- setup:addHeaderRow({ ReadText(1001, 1915) }, nil, { 2, 2 })                            -- Experience
		for _, skill in ipairs(skills) do
			if skill.name == "boarding" then
				local highlight = false
				if skill.relevance > 0 then
					highlight = true
				end
				setup:addSimpleRow({
					Helper.createFontString(ReadText(1013, skill.textid), false, "left", 255, 255, 255, 100, highlight and Helper.standardFontBold or Helper.standardFont),
					menu.createStarsText(skill.value, skillsvisible, (skillsvisible and xxxLibrary.getColorStringForSkillValue(skill.value) or ""))
				}, nil, { 2, 2 })
				setup:addSimpleRow({
					"    " .. ReadText(1001, 1917),
					(skillsvisible and (skill.value < 5 and (math.floor(experienceprogress / neededexperience * 100) .. "%") or "-") or "?")
				}, nil, { 2, 2 })
				break
			end
		end
	end

	local canupgrade = false
	local playerinventory = isplayerowned and GetPlayerInventory()

	-- setup:addHeaderRow({ ReadText(1001, 1918) }, nil, { 2, 2 })



	for _, skill in ipairs(skills) do
		if skill.name ~= "boarding" then
			local highlight = false
			if skill.relevance > 0 then
				highlight = true
			end

			if not highlight and not addedSecondHeadline then
				setup:addHeaderRow({ "Other Skills" }, nil, { 4 }) -- primary skill headline
				addedSecondHeadline = true
			end

			setup:addSimpleRow({
				Helper.createFontString(ReadText(1013, skill.textid), false, "left", 255, 255, 255, 100, highlight and Helper.standardFontBold or Helper.standardFont),
				menu.createStarsText(skill.value, skillsvisible, (skillsvisible and xxxLibrary.getColorStringForSkillValue(skill.value) or ""))
			}, nil, { 2, 2 })
		end
		-- check if skill upgrade is available (also allow for boarding skill although you can't get the upgrade anywhere)
		if not canupgrade and isplayerowned and skill.ware then
			if skill.relevance > 0 and (not skillsvisible or skill.value < 5) then
				if playerinventory[skill.ware] and playerinventory[skill.ware].amount > 0 then
					canupgrade = true
				end
			end
		end
	end

	local infobutton = Helper.createButton(nil, Helper.createButtonIcon("menu_info", nil, 255, 255, 255, 100), false)
	if menu.showunits then
		if typestring == "marine" then
			local units = GetUnitStorageData(menu.defensible, "marine")
			setup:addHeaderRow({ ReadText(1001, 54), units.categorystored .. "/" .. (units.capacity - units.stored + units.categorystored) }, nil, { 2, 2 })
			if #units > 0 then
				for _, unit in ipairs(units) do
					setup:addSimpleRow({
						infobutton,
						unit.name,
						unit.amount
					}, { "unit", unit.macro }, { 1, 1, 2 })
				end
			else
				setup:addSimpleRow({ ReadText(1001, 1913) }, nil, { 2, 2 })
			end
		elseif typestring == "engineer" then
			local units = GetUnitStorageData(menu.defensible, "welder")
			setup:addHeaderRow({ ReadText(1001, 1912), units.categorystored .. "/" .. (units.capacity - units.stored + units.categorystored) }, nil, { 2, 2 })
			if #units > 0 then
				for _, unit in ipairs(units) do
					setup:addSimpleRow({
						infobutton,
						unit.name,
						unit.amount
					}, { "unit", unit.macro }, { 1, 1, 2 })
				end
			else
				setup:addSimpleRow({ ReadText(1001, 1914) }, nil, { 2, 2 })
			end
		end
	end

	local selectdesc = setup:createCustomWidthTable({ Helper.standardTextHeight, 0, 176, Helper.standardButtonWidth }, false, false, true, 1, 0, 0, Helper.tableCharacterOffsety, 450)

	-- button table
	setup = Helper.createTableSetup(menu)
	setup:addSimpleRow({
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 2669), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, true, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_B", true)),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		isplayerowned and Helper.createButton(Helper.createButtonText(ReadText(1001, 1920), "center", Helper.standardFont, 11, 255, 255, 255, 100), nil, false, canupgrade, 0, 0, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_X", true), nil, canupgrade and ReadText(1026, 1903) or ReadText(1026, 1905)) or Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor()
	}, nil, nil, false, menu.transparent)
	local buttondesc = setup:createCustomWidthTable({ 48, 150, 48, 150, 0, 150, 48, 150, 48 }, false, false, true, 2, 1, 0, 555, 0, false)

	-- create tableview
	menu.infotable, menu.selecttable, menu.buttontable = Helper.displayThreeTableView(menu, infodesc, selectdesc, buttondesc, false)

	-- set button scripts
	local nooflines = 8
	if typestring == "marine" then
		nooflines = nooflines + 3
	end
	if menu.showunits then
		if GetComponentData(menu.entity, "typestring") == "marine" then
			local units = GetUnitStorageData(menu.defensible, "marine")
			nooflines = nooflines + 1
			if #units > 0 then
				for _, unit in ipairs(units) do
					Helper.setButtonScript(menu, nil, menu.selecttable, nooflines + 1, 1, function()
						return menu.buttonEncyclopedia("marines", unit.macro)
					end)
					nooflines = nooflines + 1
				end
			else
				nooflines = nooflines + 1
			end
		elseif GetComponentData(menu.entity, "typestring") == "engineer" then
			local units = GetUnitStorageData(menu.defensible, "welder")
			nooflines = nooflines + 1
			if #units > 0 then
				for _, unit in ipairs(units) do
					Helper.setButtonScript(menu, nil, menu.selecttable, nooflines, 1, function()
						return menu.buttonEncyclopedia("shiptypes_xs", unit.macro)
					end)
					nooflines = nooflines + 1
				end
			else
				nooflines = nooflines + 1
			end
		end
	end

	Helper.setButtonScript(menu, nil, menu.buttontable, 1, 2, function()
		return menu.onCloseElement("back")
	end)
	if isplayerowned then
		Helper.setButtonScript(menu, nil, menu.buttontable, 1, 8, menu.buttonUpgrade)
	end

	-- clear descriptors again
	Helper.releaseDescriptors()
end

--menu.updateInterval = 1.0

function menu.onUpdate()
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

init()
