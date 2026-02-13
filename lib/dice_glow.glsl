extern number time;
extern number intensity;
extern vec3 glowColor;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 pixel = Texel(texture, texture_coords) * color;
    float pulse = 0.65 + 0.35 * sin(time * 4.2);
    float glow = max(0.0, intensity) * pulse;
    pixel.rgb += glowColor * glow * (0.35 + pixel.a * 0.65);
    return pixel;
}
