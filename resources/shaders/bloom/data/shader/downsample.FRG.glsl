#pragma language glsl4

varying vec4 VarScreenPosition;
varying vec2 VarVertexCoord;

uniform sampler2D TextureBuffer;
uniform vec2 PixelSize;

uniform bool UseAntiFlicker;
uniform sampler2D PreviousBuffer;
uniform mat4 PreviousViewProjectionMatrix;
uniform float TemporalBlend;

uniform int WeightMode;

vec3 MaxVec3( vec3 A, vec3 B )
{
	return vec3(
		max( A.r, B.r ),
		max( A.g, B.g ),
		max( A.b, B.b )
	);
}

vec3 MinVec3( vec3 A, vec3 B )
{
	return vec3(
		min( A.r, B.r ),
		min( A.g, B.g ),
		min( A.b, B.b )
	);
}

// Works for both rgba16f (+65504) and rg11b10f (+65024)
vec3 SafeHDR( vec3 Color )
{
	return vec3(
		min( Color.r, 65000 ),
		min( Color.g, 65000 ),
		min( Color.b, 65000 )
	);
}

//---------------------------------------
// Bloom coords and weights
//---------------------------------------
const vec2 BloomCoords[13] = vec2[13](
	vec2( -1.0,  1.0 ), vec2( 1.0,  1.0 ),
	vec2( -1.0, -1.0 ), vec2( 1.0, -1.0 ),

	vec2( -2.0, 2.0 ), vec2( 0.0, 2.0 ), vec2( 2.0, 2.0 ),
	vec2( -2.0, 0.0 ), vec2( 0.0, 0.0 ), vec2( 2.0, 0.0 ),
	vec2( -2.0,-2.0 ), vec2( 0.0,-2.0 ), vec2( 2.0,-2.0 )
);

const float OneOverFour = (1.0 / 4.0) * 0.5;
const float OneOverNine = (1.0 / 9.0) * 0.5;

const float BloomWeightsOld[13] = float[13](
	// 4 samples
	// (1 / 4) * 0.5f = 0.125f
	OneOverFour, OneOverFour,
	OneOverFour, OneOverFour,

	// 9 samples
	// (1 / 9) * 0.5f
	OneOverNine, OneOverNine, OneOverNine,
	OneOverNine, OneOverNine, OneOverNine,
	OneOverNine, OneOverNine, OneOverNine
);

const float BloomWeightsNew[13] = float[13](
	0.125, 0.125,
	0.125, 0.125,

	0.03125, 0.0625, 0.03125,
	0.0625,  0.125,  0.0625,
	0.03125, 0.0625, 0.03125
);

float MaxBrightness( vec3 Color )
{
	return max( max( Color.r, Color.g ), Color.b );
}

//----------------------------------------
// Partial Karis average
// (Weight pixels per block of 2x2)
//----------------------------------------
// Karis's luma weighted average (using brightness instead of luma)
// Goal is to eliminate fireflies during mip0 to mp1 downsample
// Use average on 13 taps, not just 4, COD use partial average
// and not full average of all the 13 taps at once.
//----------------------------------------
// https://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare/
// https://graphicrants.blogspot.com/2013/12/tone-mapping.html
//----------------------------------------
vec3 AverageBlock(
	vec3 Sample1,
	vec3 Sample2,
	vec3 Sample3,
	vec3 Sample4
)
{
	vec4 SampleBrightness = vec4(
		MaxBrightness( Sample1 ),
		MaxBrightness( Sample2 ),
		MaxBrightness( Sample3 ),
		MaxBrightness( Sample4 )
	);

	vec4 Weights = 1.0 / ( SampleBrightness + 1.0 );
	float WeightSum = Weights.x + Weights.y + Weights.z + Weights.w;

	vec3 Result = (
		Sample1 * Weights.x +
		Sample2 * Weights.y +
		Sample3 * Weights.z +
		Sample4 * Weights.w
	) * ( 1.0 / WeightSum );

	return Result;
}

vec3 AveragePixelsPartial( vec2 UV )
{
	/*
		0 = Top Left
		1 = Top Right
		2 = Bottom Left
		3 = Bottom Right

		4 = Far Top Left
		5 = Far Top Middle
		6 = Far Top Right
		7 = Far Left
		8 = Center
		9 = Far Right
		10 = Far Bottom Left
		11 = Far Bottom Middle
		12 = Far Bottom Right

		4 - 5 - 6
		| 0 - 1 |
		7 | 8 | 9
		| 2 - 3 |
	   10 - 11 - 12
	*/
	vec3 Samples[13];

	for( int i = 0; i < 13; i++ )
	{
		vec2 CurrentUV = UV + BloomCoords[i] * PixelSize;
		Samples[i] = Texel( TextureBuffer, CurrentUV ).rgb;
	}

	vec3 Center = AverageBlock( Samples[0], Samples[1], Samples[2], Samples[3] );

	vec3 TopLeft = AverageBlock( Samples[4], Samples[5], Samples[8], Samples[7] );
	vec3 TopRight = AverageBlock( Samples[5], Samples[6], Samples[9], Samples[8] );
	vec3 BottomLeft = AverageBlock( Samples[7], Samples[8], Samples[11], Samples[10] );
	vec3 BottomRight = AverageBlock( Samples[8], Samples[9], Samples[12], Samples[11] );

	// Weights from Jimenez slides:
	// 0.5 + 0.125 + 0.125 + 0.125 + 0.125 = 1
	vec3 Result = 0.5 * Center + 0.125 * (
		TopLeft +
		TopRight +
		BottomLeft +
		BottomRight
	);

	return Result;
}

out vec4 FragColor;
void pixelmain()
{
	vec2 UV = VarVertexCoord.xy;
	vec3 OutColor = vec3( 0.0 );

	if( UseAntiFlicker )
	{
		OutColor = AveragePixelsPartial( UV );
	}
	else
	{
		for( int i = 0; i < 13; i++ )
		{
			float Weight = 0.0;

			if( WeightMode == 0 )
			{
				Weight = BloomWeightsOld[i];
			}
			else
			{
				Weight = BloomWeightsNew[i];
			}

			vec2 CurrentUV = UV + BloomCoords[i] * PixelSize;
			OutColor += Weight * Texel( TextureBuffer, CurrentUV ).rgb;
		}
	}

	OutColor = SafeHDR( OutColor );

	FragColor = vec4( OutColor, 1.0 );
}