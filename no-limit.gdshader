shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo : source_color;
uniform float thickness;


void vertex() {
	vec4 vect = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1));
	
	if (CUSTOM0.w * CUSTOM0.w < 0.1) {
		/* This runs if CUSTOM0 is not set */
		/* It's done so you can see what the ship looks like in the editor normally */
		
		POSITION = vect;
	
	}
	
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
	
	if (cosb * cosb > 0.99) {
		// Done so you don't take the inverse square root of 0.
		offset = vec2(-AB.y, AB.x) * CUSTOM0.w;
	}
	else {
		
		float isinb = inversesqrt(1. - cosb * cosb);
		
		vec2 u = AB * CUSTOM0.w * isinb;
		vec2 v = CB * CUSTOM0.w * isinb;
		
		offset = u + v;
	
	}
	
	POSITION = vect + vec4(offset * inv_scaling * thickness,0,0); // + vec4(0,0,0.01,0);
	
}

void fragment() {
	ALBEDO = albedo.rgb;
	EMISSION = albedo.rgb;
}