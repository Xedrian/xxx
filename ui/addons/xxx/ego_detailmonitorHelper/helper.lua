
Helper.colorStringDefault = "\x1bX"
Helper.colorStringWhite = Helper.colorStringDefault
Helper.colorStringRed = "\x1bR"
Helper.colorStringYellow = "\x1bY"
Helper.colorStringGreen = "\x1bG"
Helper.colorStringCyan = "\x1bC"
Helper.colorStringMagenta = "\x1bM"
Helper.colorStringBlue = "\x1bB"
Helper.colorStringBlueLight = "\x1bU"
Helper.colorStringGray = "\x1bA"
Helper.colorStringGray2 = "\x1bZ"
Helper.colorStringOrange = "\x1b#FFFF8000#"

function Helper.scaleX(x)
	local xx
	if Helper.useFullscreenDetailmonitor() or true then
		xx = Helper.pda_width
	else
		xx = GetViewSize()
	end
	if not xx then
		return x
	else
		return (x * xx / Helper.standardSizeX) -- remove round to avoid some uply spaces -- it seems ui can still work with with floats
	end
end

function Helper.scaleY(y)
	local yy
	if Helper.useFullscreenDetailmonitor() or true then
		yy = Helper.pda_height
	else
		local _, height = GetViewSize()
		yy = height
	end
	if not yy then
		return y
	else
		return (y * yy / Helper.standardSizeY) -- remove round to avoid some uply spaces  -- it seems ui can still work with with floats
	end
end
