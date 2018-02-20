function string.split(str, delimiter)
	local result = {}
	local from = 1
	local delim_from, delim_to = string.find(str, delimiter, from)
	while delim_from do
		table.insert(result, string.sub(str, from, delim_from - 1))
		from = delim_to + 1
		delim_from, delim_to = string.find(str, delimiter, from)
	end
	if string.len(str) > from then
		table.insert(result, string.sub(str, from))
	end
	return result
end

function table.implode(origTab, d)
	local newstr = ""

	local tab = table.rebuild(origTab)

	if (#tab == 1) then
		return tab[1]
	end
	for ii = 1, (#tab - 1) do
		newstr = newstr .. tab[ii] .. d
	end
	if #tab > 0 then
		newstr = newstr .. tab[#tab]
	end
	return newstr
end

function table.rebuild(tab)
	local rebuildTab = {}
	for _, v in pairs(tab) do
		table.insert(rebuildTab, v)
	end
	return rebuildTab
end

function table.getLength(tab)
	local count = 0
	for _ in pairs(tab) do
		count = count + 1
	end
	return count
end

function table.hasValue(tab, val)
	for _, value in ipairs(tab) do
		if value == val then
			return true
		end
	end
	return false
end

function table.removeKey(tab, key)
	local element = tab[key]
	table[key] = nil

	local refactoredTable = {}
	for k, v in pairs(table) do
		if v ~= nil then
			refactoredTable[k] = v
		end
	end
	tab = refactoredTable
	return element
end

function table.removeValue(tab, value)
	local newTable = {}

	for _, v in ipairs(tab) do
		if v ~= value then
			table.insert(newTable, v)
		end
	end
	return newTable
end

function table.hasKey(tab, key)
	local ret = false
	for k, v in pairs(tab) do
		if k == key then
			ret = true
			break
		end
	end
	return ret
end


