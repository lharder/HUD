require( "hud.util" )


-- GLOBAL
HUD = {}

--------------------------------------
-- RADAR 
local Radar = {}

function Radar.new( id, player, x, y, scale, hexcol, bgTexture  ) 
	
	local r = {}
	r.id = id               -- id of this radar instance in the HUD
	r.player = player       -- gameobject at the center of the radar
	r.x = x                 -- x position of radar relative to HUD
	r.y = y                 -- y position of radar relative to HUD
	r.scale = scale	or 1    -- scaling factor for the ratio  display : reality 
	r.contacts = {}         -- currently active blips on this radar

	
	-- Add a new blip to the radar
	function r:registerBlip( contactId, color, weight )
		table.insert( r.contacts, contactId )

		local pos = go.get_position( contactId )
		msg.post( "/collection0/hud#gui", "updateRadarBlip", { 
			radarId = r.id,
			contactId = contactId, 
			pos = pos,
			color = color,
			weight = weight 
		})
	end
	

	-- Gets called by HUD every CLOCKTICK secs: 
	-- update blip positions in GUI
	function r:tick( secs ) 
		local playerPos = go.get_position( r.player )

		local blips = {}
		for i, contactId in ipairs( r.contacts ) do 

			local contactPos = go.get_position( contactId )
			if contactPos == nil then
				-- gameobject no longer exists: remove from blips list
				table.remove( r.contacts, contactId )			
			else
				local pos = playerPos - contactPos
				pos.x = pos.x / r.scale
				pos.y = pos.y / r.scale
				pos.z = pos.z / r.scale

				blips[ i ] = { 
					id = r.id, 
					contactId = contactId, 
					pos = pos 
				}
			end
		end	
		
		msg.post( "/collection0/hud#gui", "updateRadarBlips", blips )
	end

	
	-- inform HUD about new radar instance and create its GUI nodes
	msg.post( "/collection0/hud#gui", "createRadar", { id = id, x = x, y = y, color = hexcol, bgTexture = bgTexture } )

	return r
end



--------------------------------------
-- Different bar types
local Bar = {}
local HBar = {}
local VBar = {}


-- Utility functions -----------------
local function tween( steps, startCol, endCol )
	local intermediates = {}
	for i = 1, steps, 1 do 
		local fact = i / steps
		intermediates[ i ] = vmath.lerp( fact, startCol, endCol )
	end
	return intermediates
end

local function concatArrays( arr01, arr02 ) 
	for i, v in pairs( arr02 ) do
		table.insert( arr01, v )
	end
	return arr01
end
-------------------------------------

function Bar.new( id, x, y, width, height, min, max, value, colHi, colMid, colLo, isVertical ) 
	local b = {}

	b.id = id
	b.x = x
	b.y = y
	b.min = min
	b.max = max
	b.width = width
	b.height = height
	b.value = value
	b.isVertical = isVertical
	
	if isVertical then
		b.pixPerUnit = height / ( max - min )
	else
		b.pixPerUnit = width / ( max - min )
	end
	
	-- three colors, defaults: green, yellow, red
	if colHi == nil then colHi = "#00ff00" end
	colHi = Color( colHi, 1 )

	if colMid == nil then colMid = "ffff00" end
	colMid = Color( colMid, 1 )

	if colLo == nil then colLo = "ff0000" end
	colLo = Color( colLo, 1 )
	
	-- color gradients precalculated per possible values
	local one3rd = round( ( max - min ) / 3 )
	local hi = tween( one3rd, colHi, colHi )
	local mid = tween( one3rd, colMid, colHi )
	local lo = tween( one3rd, colLo, colMid )
	b.colors = concatArrays( lo, mid )
	b.colors = concatArrays( b.colors, hi )
	table.insert( b.colors, colHi )  -- extra slots to make up
	table.insert( b.colors, colHi )  -- for rounding 
	-- pprint( b.colors )

	local uiValue = b.value
	if b.min < 1 then uiValue = uiValue + ( -1 * b.min ) end
	local colIndex = uiValue + 1
	uiValue = uiValue * b.pixPerUnit 
		
	-- inform HUD about new bar instance and create its GUI nodes
	msg.post( "/collection0/hud#gui", "createBar", { 
		id = b.id, 
		x = b.x, 
		y = b.y, 
		width = b.width, 
		height = b.height, 
		value = uiValue,
		color = b.colors[ colIndex ],
		isVertical = b.isVertical
	})


	function b:getValue()
		return b.value
	end


	function b:setCaption( caption, x, y, color, scale, rotate )
		if type( scale ) == "number" then scale = vmath.vector3( scale, scale, scale ) end
		if type( rotate ) == "number" then rotate = vmath.quat_rotation_z( math.rad( rotate ) ) end
		
		-- inform HUD about new caption and set properties of the GUI node
		msg.post( "/collection0/hud#gui", "setCaptionBar", { 
			id = b.id, 
			caption = caption,
			x = x, 
			y = y, 
			color = Color( color ),
			scale = scale,
			rotate = rotate
		})
	end
	
		
	function b:update( value ) 
		if value >= b.min and value <= b.max then

			-- check if a change in UI is required at all
			local oldUiValue = round( b.value * b.pixPerUnit )

			-- set new value, calculate new colIndex
			b.value = value
			
			local uiValue = b.value
			if b.min < 1 then uiValue = uiValue + ( -1 * b.min ) end
			local colIndex = uiValue + 1     -- array index must start at 1, not 0
			uiValue = uiValue * b.pixPerUnit 
			
			if uiValue ~= oldUiValue then
				
				-- update UI
				msg.post( "/collection0/hud#gui", "updateBar", { 
					id = b.id,
					value = uiValue,
					color = b.colors[ colIndex ],
					isVertical = b.isVertical
				})
			end
		end
	end

	
	return b
end



--------------------------------------
-- HUD 
function HUD.new( hudfactory, listener )
	local CLOCKTICK = 0.33

	local hud = {}
	hud._et = {}
	hud.gameobject = collectionfactory.create( hudfactory ) 
	
	local clock = nil 
	local radars = {}
	local bars = {}

	
	function hud:newRadar( player, x, y, scale, hexcol, bgTexture ) 
		-- create and remember radar instance
		-- next index as id for this radar
		local radarId = table.getn( radars ) + 1
		local radar = Radar.new( radarId, player, x, y, scale, hexcol, bgTexture )
		table.insert( radars, radar )

		return radarId
	end


	function hud:radar( id )
		return radars[ id ]
	end


	function hud:newHBar( name, x, y, width, height, min, max, value, colHi, colMid, colLo ) 
		return newBar( name, x, y, width, height, min, max, value, colHi, colMid, colLo, false )
	end

	function hud:newVBar( name, x, y, width, height, min, max, value, colHi, colMid, colLo ) 
		return newBar( name, x, y, width, height, min, max, value, colHi, colMid, colLo, true )
	end
	
	
	function newBar( name, x, y, width, height, min, max, value, colHi, colMid, colLo, isVertical ) 
		-- create and remember bar instance
		-- user provides id/name of new bar
		local bar = Bar.new( name, x, y, width, height, min, max, value, colHi, colMid, colLo, isVertical )
		bars[ name ] = bar
		
		return bar
	end
	

	-- update HUD every CLOCKTICK secs:
	-- call all radars to update themselves	
	clock = timer.delay( CLOCKTICK, true, function()
		for i, radar in ipairs( radars ) do 
			radar.tick( CLOCKTICK )
		end
	end )
	if clock == timer.INVALID_TIMER_HANDLE then print( "Error: Failed to init timer!..." ) end
	
	return hud
end



