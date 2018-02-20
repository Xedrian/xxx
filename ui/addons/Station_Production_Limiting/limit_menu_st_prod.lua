local menu = {
	name = "Station_Prod_Limit",
}

local function init()
	Menus = Menus or { }
	table.insert(Menus, menu)
	if Helper then
		Helper.registerMenu(menu)
	end
end

function menu.cleanup()
	menu.title = nil
	menu.method = nil
	menu.module = nil
	menu.production = nil

	menu.infotable = nil
	menu.selecttable = nil
	menu.prodbrake = nil
	menu.maxslider = nil
	menu.moduid = nil
	menu.manager = nil
	menu.priware = nil
	menu.product = nil
	menu.slider1val = nil
	menu.cargo = nil
end

-- Menu member functions

-- Button Scripts
function menu.buttonOK()	
	if GetSliderValue(menu.slider) then
		local value1, value2, value3, value4 = GetSliderValue(menu.slider)  -- get slider value
		local prodbrake = tonumber(value1 / menu.maxslider) or 0 -- production brake or recycle factor
		local mdproddata
		if menu.prodbrake ~= prodbrake then -- its changed
			if prodbrake ~= 0 then
				if menu.manager then
					mdproddata = GetNPCBlackboard(menu.manager, "$St_Prod_Data") or {}
					if mdproddata == "" then -- force mdproddata to be a table
						mdproddata = {}
					end
					if mdproddata[menu.moduid] then -- set prodbrake on the BlackBoard
						mdproddata[menu.moduid][4] = prodbrake
						SetNPCBlackboard(menu.manager, "$St_Prod_Data", mdproddata) -- update the BlackBoard
					else -- create new BlackBoard entry
						local sequence, stage = GetComponentData(menu.module, "sequence", "stage")
						if sequence and sequence == "" then 
							sequence = "a" 
						end
						local products = {}
						if menu.production and menu.production.products and #menu.production.products > 0 then -- needs a Production method
							products[1] = {ware=menu.production.products[1].ware, name=menu.production.products[1].name}
							local exportproddata = {GetCurTime(), sequence, stage, tonumber(prodbrake), 0, "unknown", 0, 100, -10, 0, products, {}, {}}
							mdproddata[menu.moduid] = exportproddata
							SetNPCBlackboard(menu.manager, "$St_Prod_Data", mdproddata) -- update $St_Prod_Data on the BlackBoard
							local proddatakeys = {}
							for k,v in pairs(mdproddata) do
								table.insert(proddatakeys, k)
							end
							SetNPCBlackboard(menu.manager, "$St_Prod_DataKeys", proddatakeys) -- pass the keys to allow hash to be read in md script
						end
					end
				else
					menu.remotelog(ReadText(360003, 1) .. " requires a station production manager")
				end
			else
				if menu.manager then
					mdproddata = GetNPCBlackboard(menu.manager, "$St_Prod_Data") or {}		
					if mdproddata[menu.moduid] then -- remove the BlackBoard entry
						mdproddata[menu.moduid] = nil
						local numentries = 0
						for k,v in pairs(mdproddata) do
							numentries = numentries + 1
						end
						if numentries > 0 then
							SetNPCBlackboard(menu.manager, "$St_Prod_Data", mdproddata) -- update the BlackBoard
							local proddatakeys = {}
							for k,v in pairs(mdproddata) do
								table.insert(proddatakeys, k)
							end
							SetNPCBlackboard(menu.manager, "$St_Prod_DataKeys", proddatakeys) -- pass the keys to allow hash to be read in md script
						else
							menu.remotelog("Wiping the blackboard for " .. GetComponentData(GetComponentData(menu.module,"parent"),"name"))
							SetNPCBlackboard(menu.manager, "$St_Prod_Data", "") -- wipe the BlackBoard
							SetNPCBlackboard(menu.manager, "$St_Prod_DataKeys", "") -- wipe the keys
						end
					end
				end
			end
		end
	else
		menu.remotelog("Unable to get Slider value for " .. menu.warename .. " - Skipping")
	end
	Helper.closeMenuAndReturn(menu, nil)
	menu.cleanup()
end

function menu.buttonConfig()
	Helper.closeMenuForSubSection(menu, false, "gMain_Station_Prod_Config", { 0, 0, menu.priware, menu.module })
	menu.cleanup()
end

function menu.onShowMenu()
	menu.method = menu.param[3]
	menu.warename = menu.param[4]
	menu.module = menu.param[5]
	
	menu.production = GetLibraryEntry("productionmethods", menu.method) or nil
	local menuname = ReadText(1001, 2408)
	if menu.production and menu.production.products and #menu.production.products > 0 then
		menu.product = menu.production.products[1].name
		menu.priware = menu.production.products[1].ware
	else
		menu.remotelog(menu.warename .. ". No Production method from GetLibrary('productionmethods').")
		menu.product = menu.warename
		menu.priware = ReadText(20212, 101)
	end
	menu.title = ReadText(360003, 1) .. " - " .. menu.product

	-- get build stage and sequence to use as unique key for this prod module
	local sequence, stage = GetComponentData(menu.module, "sequence", "stage")
	if sequence and sequence == "" then 
		sequence = "a" 
	end
	menu.moduid = sequence .. "_" .. stage .. "_" .. menu.priware
	menu.prodbrake = 0
	local station = GetComponentData(menu.module,"parent")
	if station then
		menu.manager = GetComponentData(station, "tradenpc")
		if menu.manager then
			local mdproddata = GetNPCBlackboard(menu.manager, "$St_Prod_Data") or {}		
			if mdproddata[menu.moduid] then -- get prodbrake from the BlackBoard
				menu.prodbrake = mdproddata[menu.moduid][4]
			end
		end
	end

	local setup = Helper.createTableSetup(menu)
	setup:addSimpleRow({
		Helper.createButton(nil, Helper.createButtonIcon("dock_repair_active", nil, 255, 255, 255, 100), false),
		Helper.createFontString(menu.title, false, "left", 255, 255, 255, 100, Helper.headerRow1Font, Helper.headerRow1FontSize, false, Helper.headerRow1Offsetx, Helper.headerRow1Offsety, Helper.headerRow1Height, Helper.headerRow1Width)
	}, nil, {1, 1}, false, Helper.defaultTitleBackgroundColor)
	setup:addTitleRow({ 
		Helper.createFontString("", false, "left", 129, 160, 182, 100, Helper.headerRow2Font, Helper.headerRow2FontSize, false, Helper.headerRow2Offsetx, Helper.headerRow2Offsety, Helper.headerRow2Height, Helper.headerRow1Width)	-- text depends on selection
	}, nil, {2})
	local infodesc = setup:createCustomWidthTable({Helper.headerRow1Height, 0}, false, false, true, 2, 1)

	setup = Helper.createTableSetup(menu)
	setup:addSimpleRow({
		ReadText(1001, 1603), 
		ConvertTimeString(menu.production.cycle or 0, "%h" .. ReadText(1001, 102) .. " %M" .. ReadText(1001, 103) .. " %S" .. ReadText(1001, 100))
	}, nil, {3, 1})

	-- Products
	menu.addWares(setup, menu.production.products, ReadText(1001, 1610), 1)
	-- Primary resources
	menu.addWares(setup, menu.production.presources, ReadText(1001, 1611), -1)
	-- Secondary resources
	-- no space :(
	
	setup:addFillRows(14, nil, {4})

	local resources = {} -- find the smallest amount from presources, sresources and products
	menu.maxslider = 100
	if menu.production then
		if menu.production.presources then
			table.insert(resources, menu.production.presources)
		end
		if menu.production.sresources then
			table.insert(resources, menu.production.sresources)
		end
		if menu.production.products then
			table.insert(resources, menu.production.products)
		end
		
		for _, slidersource in ipairs(resources) do
			if #slidersource ~= 0 then -- find smallest ware amount		
				for _, resource in ipairs(slidersource) do
					if resource.amount < menu.maxslider then
						menu.maxslider = resource.amount
					end
				end
			end
		end
	end

	local sliderinfo = {
		["background"] = "tradesellbuy_blur", 
		["captionLeft"] = "", 
		["captionCenter"] = ReadText(360003, 100), 
		["captionRight"] = "", 
		["min"] = 0,
		["minSelectable"] = 0,
		["max"] = menu.maxslider,
		["zero"] = 0,
		["start"] = math.floor(menu.prodbrake * menu.maxslider) or 0
	}
	local scale1info = { 
		["left"] = nil,
		["right"] = nil,
		["center"] = false,
		["inverted"] = false,
		["suffix"] = nil
	}
	local scale2info = {
		["left"] = nil,
		["right"] = nil,
		["center"] = true,
		["factor"] = (100 / menu.maxslider),
		["inverted"] = false,
		["suffix"] = "%"
	}
	local sliderdesc = Helper.createSlider(sliderinfo, scale1info, scale2info, 3, Helper.sliderOffsetx, 443)
	setup:addSimpleRow({ 
		Helper.createButton(Helper.createButtonText(ReadText(1001, 2669), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 2 * Helper.standardTextOffsetx, 0.8 * Helper.standardTextHeight, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_B", true)),
		Helper.getEmptyCellDescriptor(),
		Helper.getEmptyCellDescriptor(),
		Helper.createButton(Helper.createButtonText(ReadText(1001, 14), "center", Helper.standardFont, Helper.standardFontSize, 255, 255, 255, 100), nil, false, true, 7 * Helper.standardTextOffsetx, 0.8 * Helper.standardTextHeight, 150, 25, nil, Helper.createButtonHotkey("INPUT_STATE_DETAILMONITOR_A", true)),
	}, nil, {1, 1, 1, 1, 1}, false, menu.transparent)
	local selectdesc = setup:createCustomWidthTable({0, 200, 200, 200}, false, false, true, 1, 0, 0, Helper.tableOffsety)

	-- create tableview
	menu.infotable, menu.selecttable, menu.slider = Helper.displayTwoTableSliderView(menu, infodesc, selectdesc, sliderdesc, true)

	-- set button scripts
	Helper.setButtonScript(menu, nil, menu.infotable, 1, 1, menu.buttonConfig)
	Helper.setButtonScript(menu, nil, menu.selecttable, 15, 1, function () return menu.onCloseElement("back") end)
	Helper.setButtonScript(menu, nil, menu.selecttable, 15, 4, menu.buttonOK)

	-- clear descriptors again
	Helper.releaseDescriptors()
end

 -- menu.updateInterval = 2.0

function menu.addWares(setup, waretable, title, usage)
	local prodrate = tonumber(1 - menu.prodbrake) or 1 -- production rate
	local container = GetContextByClass(menu.module, "container", false)
	local cargo = {}
	if container then 
		cargo = GetComponentData(container, "cargo") or {}
	end
	
	setup:addHeaderRow({ 
		title, 
		(usage > 0 and ReadText(1001, 1600) or ReadText(1001, 1609)) .. " (" .. ReadText(360003, 10) .. ")",
		(usage > 0 and ReadText(1001, 1600) or ReadText(1001, 1609)) .. " (" .. ReadText(1001, 102) .. ")",
		ReadText(1001, 20) .. " / " .. ReadText(1001, 1127) 
		})
	if waretable then
		if #waretable == 0 then
			setup:addSimpleRow({ 
				Helper.getEmptyCellDescriptor(), 
				"-- " .. ReadText(1001, 32) .. " --", 
				Helper.getEmptyCellDescriptor() 
			})
		else
			for _, resource in ipairs(waretable) do
				setup:addSimpleRow({
					resource.name, 
					Helper.createFontString(ConvertIntegerString(math.floor(resource.amount * prodrate + 0.5),true, 4, true)  .. " / " .. ConvertIntegerString(math.floor(resource.amount + 0.5),true, 4, true) , false, "right"),
					Helper.createFontString(ConvertIntegerString(resource.amount * prodrate * 3600 / menu.production.cycle, true, 4, true) .. " / " .. ConvertIntegerString(resource.amount * 3600 / menu.production.cycle, true, 4, true), false, "right"),
					Helper.createFontString(ConvertIntegerString(cargo[resource.ware] or 0, true, 4, true) .. " / " .. ConvertIntegerString(GetWareProductionLimit(container, resource.ware) or 0, true, 4, true), false, "right") 
				}, resource.ware)
			end
		end
	end
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
	local container = GetContextByClass(menu.module, "container", false)
	local cargo = {}
	if container then 
		local cargo = GetComponentData(container, "cargo") or {}
	end
	if GetSliderValue(menu.slider) then -- make sure that the slider has data
		local value1, value2, value3, value4 = GetSliderValue(menu.slider)  -- get slider value
		local prodbrake = tonumber(value1 / menu.maxslider) or 0 -- production brake or recycle factor
		local prodrate = tonumber(1 - prodbrake) or 1 -- production rate
		local linenum = 3
		if menu.production and menu.production.products and #menu.production.products ~= 0 then -- update Products		
			for _, resource in ipairs(menu.production.products) do
				if menu.slider1val and menu.slider1val ~= value1 then -- update on change only
					-- menu.remotelog("value1: " .. tostring(value1))
					Helper.updateCellText(menu.selecttable, linenum, 2, ConvertIntegerString(math.floor(resource.amount * prodrate + 0.5),true, 4, true)  .. " / " .. ConvertIntegerString(math.floor(resource.amount + 0.5),true, 4, true) )
					Helper.updateCellText(menu.selecttable, linenum, 3, ConvertIntegerString(resource.amount * prodrate * 3600 / menu.production.cycle, true, 4, true) .. " / " .. ConvertIntegerString(resource.amount * 3600 / menu.production.cycle, true, 4, true))
				end
				if menu.cargo and cargo and menu.cargo[resource.ware] ~= cargo[resource.ware] then -- update on change only
					Helper.updateCellText(menu.selecttable, linenum, 4, ConvertIntegerString(cargo[resource.ware] or 0, true, 4, true) .. " / " .. ConvertIntegerString(GetWareProductionLimit(container, resource.ware) or 0, true, 4, true))
				end
				linenum = linenum + 1
			end
		end
		linenum = linenum + 1 -- skip header row
		if menu.production and menu.production.presources and #menu.production.presources ~= 0 then -- update Primary Resources		
			for _, resource in ipairs(menu.production.presources) do
				if menu.slider1val and menu.slider1val ~= value1 then -- update on change only
					Helper.updateCellText(menu.selecttable, linenum, 2, ConvertIntegerString(math.floor(resource.amount * prodrate + 0.5),true, 4, true)  .. " / " .. ConvertIntegerString(math.floor(resource.amount + 0.5),true, 4, true))
					Helper.updateCellText(menu.selecttable, linenum, 3, ConvertIntegerString(resource.amount * prodrate * 3600 / menu.production.cycle, true, 4, true) .. " / " .. ConvertIntegerString(resource.amount * 3600 / menu.production.cycle, true, 4, true))
				end
				if menu.cargo and cargo and menu.cargo[resource.ware] ~= cargo[resource.ware] then -- update on change only
					Helper.updateCellText(menu.selecttable, linenum, 4, ConvertIntegerString(cargo[resource.ware] or 0, true, 4, true) .. " / " .. ConvertIntegerString(GetWareProductionLimit(container, resource.ware) or 0, true, 4, true))
				end
				linenum = linenum + 1
			end
		end
		menu.slider1val = value1
		menu.cargo = cargo
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

init()
