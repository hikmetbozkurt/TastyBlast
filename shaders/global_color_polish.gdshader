shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool visual_boost_enabled = true;
uniform float brightness : hint_range(0.8, 1.2, 0.01) = 1.06;
uniform float contrast : hint_range(0.8, 1.2, 0.01) = 1.05;
uniform float saturation : hint_range(0.8, 1.3, 0.01) = 1.10;

void fragment() {
	vec4 source = textureLod(screen_texture, SCREEN_UV, 0.0);
	vec3 polished = source.rgb;
	if (visual_boost_enabled) {
		polished *= brightness;
		polished = (polished - vec3(0.5)) * contrast + vec3(0.5);
		float luminance = dot(polished, vec3(0.2126, 0.7152, 0.0722));
		polished = mix(vec3(luminance), polished, saturation);
	}
	COLOR = vec4(clamp(polished, vec3(0.0), vec3(1.0)), source.a);
}
