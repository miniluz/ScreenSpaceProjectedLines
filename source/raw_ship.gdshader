shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo : source_color;
uniform float thickness;


void vertex() {
	vec4 vect = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1));
	
	if (CUSTOM0.w * CUSTOM0.w > 0.1) {
	
	float thick = thickness * round(CUSTOM0.w);
	vec4 next = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(CUSTOM0.xyz, 1));
	vec4 prev = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(CUSTOM1.xyz, 1));
	
	vec2 scaling = vec2(VIEWPORT_SIZE.x/VIEWPORT_SIZE.y, 1.);
	vec2 inv_scaling = vec2(VIEWPORT_SIZE.y/VIEWPORT_SIZE.x, 1.);
	
	vec2 A = prev.xy * scaling / prev.z;
	vec2 B = vect.xy * scaling / vect.z;
	vec2 C = next.xy * scaling / next.z;
	
	vec2 AB = normalize(A-B);
	vec2 CB = normalize(C-B);
	float cosb = dot(AB, CB);
	vec2 offset;
	
	if (cosb < -0.99) {
		offset = vec2(-AB.y, AB.x) * thick;
	}
	else {
	
	float isinb = inversesqrt(1. - cosb * cosb);
	
	vec2 u = AB * thick * isinb;
	vec2 v = CB * thick * isinb;
	
	offset = (u + v);
	
	const float limit = 2.;
	
	if (offset.x*offset.x + offset.y*offset.y > limit * limit * thick * thick) {
		offset = normalize(offset) * limit * abs(thick);
	}
	
	}
	
	POSITION = vect + vec4(offset * inv_scaling,0,0) + vec4(0,0,0.01,0);
	
	}
	else {
		POSITION = vect;
	}
	
}

void fragment() {
	ALBEDO = albedo.rgb;
	EMISSION = albedo.rgb;
}
