-- helper ----------------------------------------------------
function string:split( sep )
	local sep, fields = sep or ":", {}
	local pattern = string.format( "([^%s]+)", sep )
	self:gsub( pattern, function( c ) fields[ #fields+1 ] = c end )

	return fields
end

function round( num )
	return math.floor( num + 0.5 )
end


function string:startsWith( txt )
	return string.sub( self, 1, string.len( txt ) ) == txt
end


function Texture( url, default ) 
	local atlas = ""
	local img = ""

	if default ~= nil then 
		local parts = default:split( "/" )
		atlas = parts[ 1 ]
		img = parts[ 2 ]
	end

	if texture ~= nil then 
		local parts = texture:split( "/" )
		atlas = parts[ 1 ]
		img = parts[ 2 ]
	end

	return atlas, img
end


function Color( hex, alpha )
	if hex == nil then return nil end

	if hex:startsWith( "#" ) then 
		hex = string.sub( hex, 2, string.len( hex ) ) 
	end

	local r, g, b = hex:match( "(%w%w)(%w%w)(%w%w)" )
	r = ( tonumber( r, 16 ) or 0 ) / 255
	g = ( tonumber( g, 16 ) or 0 ) / 255
	b = ( tonumber( b, 16 ) or 0 ) / 255

	return vmath.vector4( r, g, b, alpha or 1 )
end
