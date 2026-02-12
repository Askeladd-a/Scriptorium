local GL = require( "lib.frogl" )

local COMMON = {}

local ShaderCopy = nil
local QuadMesh = nil

function COMMON.Init()
	ShaderCopy = love.graphics.newShader(
		"shader/copy.FRG.glsl",
		"shader/copy.VTX.glsl",
		{
			debugname="Shader.CopyTexture"
		}
	)
end

function COMMON.DrawFullscreenTriangle()
	love.graphics.drawFromShader( "triangles", 3, 1 )
end

function COMMON.CopyTexture( Source, Target, FlipU, FlipV )
	GL.PushEvent( "Copy texture" )

	ShaderCopy:send( "FlipU", (FlipU or false) )
	ShaderCopy:send( "FlipV", (FlipV or false) )
	ShaderCopy:send( "TextureBuffer", Source )

	love.graphics.setBlendMode( "none" )
	love.graphics.setShader( ShaderCopy )
	love.graphics.setCanvas( Target )

	COMMON.DrawFullscreenTriangle()

	GL.PopEvent()
end

function COMMON.GetQuadMesh()
	if not QuadMesh then
		local Vertices = {
			-- Position, UV
			{ 0.0, 0.0,  0.0, 0.0 },
			{ 1.0, 0.0,  1.0, 0.0 },
			{ 0.0, 1.0,  0.0, 1.0 },
			{ 1.0, 1.0,  1.0, 1.0 }
		}

		local Map = { 1, 3, 2, 4 }

		QuadMesh = love.graphics.newMesh( Vertices, "strip", "static" )
		QuadMesh:setVertexMap( Map )
	end

	return QuadMesh
end

return COMMON