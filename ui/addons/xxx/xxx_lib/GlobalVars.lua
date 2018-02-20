function dumpVar(var)
	if type(var) == 'table' then
		local s = '{ ' .. "\n"
		for k, v in pairs(var) do
			if type(k) ~= 'number' then
				k = '"' .. k .. '"'
			end

			s = s .. '[' .. k .. '] = ' .. dumpVar(v) .. ',' .. "\n"
		end
		return s .. '} ' .. "\n"
	else
		return tostring(var)
	end
end

function debugVar(var)
	DebugError(dumpVar(var))
end