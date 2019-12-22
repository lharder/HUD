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
-- BAR 
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
	if colHi == nil then colHi = "#72ffff" end
	colHi = Color( colHi, 1 )

	--if colMid == nil then colMid = "#00787a" end
	if colMid == nil then colMid = "#ffff00" end
	colMid = Color( colMid, 1 )

	if colLo == nil then colLo = "#e06100" end
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
-- COMINFO DEVICE 
local Cominfo = {}

function Cominfo.new( id, x, y )
	local com = {}

	com.id = id
	com.x = x
	com.y = y
	com.width = 240
	com.height = 240

	-- defaults 	
	com.outerRing = { min = 0,   max = 100,  value = 0 }
	com.innerRing = { min = 0,   max = 100,  value = 0 }
	com.imageIndex = 0
	com.tray = { isOpen = true,  subject = "",  description = "" }

	
	function com:setOuterValue( value, min, max )
		if value == nil then return end
		if min ~= nil then com.outerRing.min = min end
		if max ~= nil then com.outerRing.max = max end

		local scaledValue = math.floor( value * ( 35 / com.outerRing.max ) ) 	  -- 35 dot states available
		if scaledValue >= 0 and scaledValue <= 34 then
			com.outerRing.value = value

			msg.post( "/collection0/hud#gui", "setOuterValue", { 
				id = com.id,
				value = scaledValue
			})
		end
	end

	
	function com:getOuterValue()
		return com.outerRing.value 
	end

	
	function com:setInnerValue( value, min, max )
		if value == nil then return end
		if min ~= nil then com.innerRing.min = min end
		if max ~= nil then com.innerRing.max = max end

		local scaledValue = math.floor( value * ( 360 / com.innerRing.max ) )	-- 360 degrees/states available
		if scaledValue >= 0 and scaledValue <= 360 then
			com.innerRing.value = value

			msg.post( "/collection0/hud#gui", "setInnerValue", { 
				id = com.id,
				value = scaledValue
			})
		end
	end

	
	function com:getInnerValue()
		return com.innerRing.value 
	end


	function com:addClickListener( url, nodename )
		if nodename == nil then nodename = "/indicator" end
		
		msg.post( "/collection0/hud#gui", "addClickListener", { 
			nodename = com.id .. nodename,
			listener = url
		})
		com.clicklistener = url
	end


	function com:attach( nodename )
		com.imageIndex = com.imageIndex + 1
		msg.post( "/collection0/hud#gui", "attachToCenter", { 
			id = com.id,
			node = nodename
		})
	end
	

	-- Infobox Tray --------------------------------------
	function com.tray:open()
		msg.post( "/collection0/hud#gui", "openInfobox", { 
			id = com.id
		})
		com.tray.isOpen = true
	end

	function com.tray:close()
		msg.post( "/collection0/hud#gui", "closeInfobox", { 
			id = com.id
		})
		com.tray.isOpen = false
	end
	

	function com.tray:setSubject( txt )
		msg.post( "/collection0/hud#gui", "setSubject", { 
			id = com.id,
			subject = txt
		})
	end

	function com.tray:setDescription( txt )
		msg.post( "/collection0/hud#gui", "setDescription", { 
			id = com.id,
			description = txt
		})
	end

	function com.tray:attach( node )
		msg.post( "/collection0/hud#gui", "attachToTray", { 
			id = com.id,
			node = node
		})
	end

	
	-- Create and return new HUD --------------------------------------
	msg.post( "/collection0/hud#gui", "createCominfo", { 
		id = com.id,
		x = com.x,
		y = com.y
	})
	
	return com
end


--------------------------------------
-- Button 
local Button = {}

function Button.new( name, x, y, caption, listener, width, height ) 
	local btn = {}

	btn.id = name
	btn.x = x
	btn.y = y
	btn.width = width
	btn.height = height
	btn.caption = caption
	btn.listener = listener

	msg.post( "/collection0/hud#gui", "createButton", { 
		id = btn.id,
		x = btn.x,
		y = btn.y,
		width = btn.width,
		height = btn.height,
		caption = btn.caption,
		listener = btn.listener
	})

	return btn
end



--------------------------------------
-- Image
local Image = {}

function Image.new( name, x, y, texture, width, height, listener ) 
	local img = {}

	img.id = name
	img.x = x
	img.y = y
	img.texture = texture
	img.width = width
	img.height = height
	img.listener = listener

	img.cooldown = 0

	msg.post( "/collection0/hud#gui", "createImage", { 
		id = img.id,
		x = img.x,
		y = img.y,
		texture = img.texture,
		width = img.width,
		height = img.height,
		listener = img.listener
	})


	function img:set( texture )
		if socket.gettime() > img.cooldown then
			img.cooldown = socket.gettime() + .5

			img.texture = texture
			msg.post( "/collection0/hud#gui", "setImage", { 
				id = img.id,
				texture = img.texture,
			})
		end
	end


	function img:swipe( texture, deltaX, deltaY )
		if deltaX == nil then deltaX = -1 end
		if deltaY == nil then deltaY =  0 end
		
		if socket.gettime() > img.cooldown then
			img.cooldown = socket.gettime() + .5
			
			img.texture = texture
			msg.post( "/collection0/hud#gui", "swipeImage", { 
				id = img.id,
				texture = img.texture,
				deltaX = deltaX,
				deltaY = deltaY
			})
		end
	end
	
	
	return img
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
	local cominfos = {}
	local buttons = {}


	-- Radar
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


	-- Bars
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

	
	-- Cominfo
	function hud:newCominfo( name, x, y ) 
		-- user provides id/name of new bar
		local cominfo = Cominfo.new( name, x, y )
		cominfos[ cominfo ] = cominfo

		return cominfo
	end


	function hud:cominfo( id )
		return cominfos[ id ]
	end


	-- buttons
	function hud:newButton( name, x, y, width, height, caption, listener ) 
		local btn = Button.new( name, x, y, width, height, caption, listener )
		return btn
	end


	-- images
	function hud:newImage( name, x, y, texture, width, height, listener ) 
		return Image.new( name, x, y, texture, width, height, listener )
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



