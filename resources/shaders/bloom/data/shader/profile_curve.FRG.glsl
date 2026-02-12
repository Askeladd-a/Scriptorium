#pragma language glsl4

varying vec4 VarScreenPosition;
varying vec2 VarVertexCoord;

uniform sampler2D TextureBuffer;
uniform vec2 ResolutionSize;

out vec4 FragColor;
void pixelmain()
{
	vec2 UV = VarVertexCoord.xy;

	vec2 PixelSize =  1.0 / (ResolutionSize);

	float ScaledAxis = (UV.x - 0.5) * 0.25 + 0.5;

	vec3 Sample = texture( TextureBuffer, vec2( ScaledAxis, 0.5 ), -999 ).rgb;
	float Position = dot( Sample, vec3(1.0 / 3.0) ); // Lazy grayscale conversion

	float ScaleReference = (UV.y) * 1.5 - 0.25;

	float Mask = abs( ScaleReference - Position );
	float MaskLine = 1.0 - smoothstep( 0.0, 2.0 * PixelSize.y, Mask );

	vec4 OutColor = vec4( 1.0 ) * MaskLine;

	// OutColor.r = Mask;

	FragColor = OutColor;
}