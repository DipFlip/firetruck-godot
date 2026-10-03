shader_type canvas_item;
render_mode unshaded;
uniform sampler2D town_image : hint_screen_texture, repeat_disable, filter_linear;
uniform float focus_top = 0.27;
uniform float focus_bottom = 0.73;
// Set from the camera: a wider shot is a more distant subject with deeper
// depth of field, so the town overview stays nearly sharp.
uniform float strength = 1.0;
void fragment() {
 // The blur circle grows linearly with depth away from the sharp band, as
 // with a real lens. Screen height stands in for depth at the fixed pitch.
 float distance_out = max(focus_top-SCREEN_UV.y,SCREEN_UV.y-focus_bottom);
 float blur = clamp(distance_out/0.26,0.0,1.3)*strength;
 vec2 radius = SCREEN_PIXEL_SIZE*3.6*blur;
 vec3 color = texture(town_image,SCREEN_UV).rgb*0.40;
 color += texture(town_image,SCREEN_UV+vec2(radius.x,radius.y)).rgb*0.15;
 color += texture(town_image,SCREEN_UV+vec2(-radius.x,radius.y)).rgb*0.15;
 color += texture(town_image,SCREEN_UV+vec2(radius.x,-radius.y)).rgb*0.15;
 color += texture(town_image,SCREEN_UV-radius).rgb*0.15;
 // Very light lens shading, with no raised blacks or white colour wash.
 vec2 edge = (SCREEN_UV-0.5)*2.0;
 color *= 1.0-0.045*dot(edge,edge);
 COLOR=vec4(color,1.0);
}
