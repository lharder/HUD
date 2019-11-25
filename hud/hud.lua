-- GLOBAL
HUD = {}

--------------------------------------
-- RADAR 
local Radar = {}

function Radar.new( id, player, scale ) 
	
	local r = {}
	r.id = id				-- id of this radar instance in the HUD
	r.player = player		-- gameobject at the center of the radar
	r.scale = scale	or 1	-- scaling factor for the radar display : reality
	r.contacts = {}			-- currently active blips on this radar

	
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
		for i, contactId in ipairs( r.contacts ) do 

			local contactPos = go.get_position( contactId )
			local pos = playerPos - contactPos
			pos.x = pos.x / r.scale
			pos.y = pos.y / r.scale
			pos.z = pos.z / r.scale
			
			msg.post( "/collection0/hud#gui", "updateRadarBlip", { 
				id = r.id,
				contactId = contactId, 
				pos = pos
			})
		end	
	end
	

	
	return r
end
--------------------------------------


--------------------------------------
-- HUD 
function HUD.new( hudfactory, listener )
	local CLOCKTICK = 0.33

	local hud = {}
	hud._et = {}
	hud.gameobject = collectionfactory.create( hudfactory ) 
	
	local clock = nil 
	local radars = {}

	
	function hud:newRadar( player, x, y, scale, hexcol, bgTexture ) 
		-- create and remember radar instance
		-- next index as id for this radar
		local radarId = table.getn( radars ) + 1
		local radar = Radar.new( radarId, player, scale )
		table.insert( radars, radar )

		-- inform HUD about new radar instance and create its GUI nodes
		msg.post( "/collection0/hud#gui", "createRadar", { id = radarId, x = x, y = y, color = hexcol, bgTexture = bgTexture } )

		return radarId
	end


	function hud:radar( id )
		return radars[ id ]
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



