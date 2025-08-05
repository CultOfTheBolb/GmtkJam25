shader_type spatial;

uniform vec3 color : source_color;
uniform float size = 5.0;
uniform float intensity = 0.05;
uniform float rate = 0.17;

void vertex() {
	float time = round(TIME / rate) * rate;
	
	float x = pow(abs(cos(VERTEX.y * size + time)), 0.5) * intensity - pow(abs(cos(VERTEX.z * size * 0.7)), 0.5) * intensity * 1.3;
	float y = pow(abs(cos(VERTEX.x * size + time)), 0.5) * intensity - pow(abs(cos(VERTEX.z * size * 0.7)), 0.5) * intensity * 1.3;
	float z = pow(abs(cos(VERTEX.y * size + time)), 0.5) * intensity - pow(abs(cos(VERTEX.x * size * 0.7)), 0.5) * intensity * 1.3;
	
	VERTEX += vec3(x, y, z);
}

void fragment() {
	ALBEDO = color;
}