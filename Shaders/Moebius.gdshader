shader_type spatial;
render_mode unshaded, fog_disabled;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture, filter_linear_mipmap;

uniform sampler2D hatch : filter_nearest, repeat_enable;

uniform float edge_threshold = 0.1;
uniform vec3 color : source_color = vec3(0.0);

uniform float hatch_size = 3.0;
uniform float hatch_thresh_1 = 0.4;
uniform float hatch_thresh_2 = 0.5;

// Depth Map calculations:
//
// The values returned by depth_texture are between 1.0 and 0.0
// (corresponding to the near and far plane, respectively, because of using a "reverse-z" depth buffer) and are nonlinear.
// When displaying depth directly from the depth_texture
// In order to make the depth value align with world or model coordinates, we need to linearize the value.
// To linearize it, we multiply it by the inverse of the projection matrix.
// Take the screen space coordinates and transform them into normalized device coordinates (NDC).
// NDC run -1.0 to 1.0 in x and y directions and from 0.0 to 1.0 in the z direction when using the Vulkan backend.
// Reconstruct the NDC using SCREEN_UV for the x and y axis, and the depth value for z.
// Convert NDC to view space by multiplying the NDC by INV_PROJECTION_MATRIX.
// Recall that view space gives positions relative to the camera, so the z value will give us the distance to the point.
// Because the camera is facing the negative z direction, the position will have a negative z value.
// In order to get a usable depth value, we have to negate view.z.
float linearize_depth(vec2 uv, mat4 proj_matrix) {
	float depth = texture(DEPTH_TEXTURE, uv).x;
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	vec4 view = proj_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;
	view.z = -view.z;
	float linear_depth = view.z / 100.0;
	return linear_depth;
}

vec3 normalize_normal(vec3 normal) {
	return normalize(normal * 2.0 - 1.0);
}

// Vertex Nullification:
//
// The vertex shader expects coordinates to be output in clip space,
// which are coordinates ranging from -1 at the left and bottom of the screen to 1 at the top and right of the screen.
// We need to nullify the effects of Godot's transformations.
// We do this by setting the POSITION built-in to our desired position.
// POSITION bypasses the built-in transformations and sets the vertex position in clip space directly.
void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	// Texture Values:
	//
	// First we make a distorted version of our screen uv using a noise texture.
	// Then we get the color of the pixel, aswell as the depth using our linearize_depth function.
	// We also get the pixel dimensions of the viewport and put those into an offset variable.
	// We get the normal vector based on the normal texture by grabbing the first 3 elements.
	// Notably, there is a 4th element (w) that represents the roughness that we will not use.
	// And finally we get the luminance of each pixel via the dot product of the light direction and the color of the pixel.
	vec2 uv = SCREEN_UV;
	vec4 bg = texture(SCREEN_TEXTURE, uv);
	float depth = linearize_depth(uv, INV_PROJECTION_MATRIX);
	vec2 offset = 1.0 / VIEWPORT_SIZE;
	vec3 normal = normalize_normal(texture(NORMAL_TEXTURE, uv).rgb);

	float luminance = dot(bg.rgb, vec3(0.299, 0.587, 0.114));

	//Sobel operators:
	//
	// We will use them to take the normal of the pixels surrounding each pixel and accentuate the differences to either side.
	// One matrix for the X axis and one for the Y axis.
	const mat3 sx = mat3(
		vec3(-1, 0, 1),
		vec3(-2, 0, 2),
		vec3(-1, 0, 1)
	);
	const mat3 sy = mat3(
		vec3(-1, -2, -1),
		vec3(0, 0, 0),
		vec3(1, 2, 1)
	);


	// Surrounding Pixels Based on Depth:
	//
	// we use the offset to get the linearized depth of each of the surrounding pixels and create a little matrix.
	// This matrix represents the 3x3 square surrounding the pixel.
	vec3 n = vec3(linearize_depth(uv + vec2(0.0, -offset.y), INV_PROJECTION_MATRIX));
	vec3 s = vec3(linearize_depth(uv + vec2(0.0, offset.y), INV_PROJECTION_MATRIX));
	vec3 e = vec3(linearize_depth(uv + vec2(offset.x, 0.0), INV_PROJECTION_MATRIX));
	vec3 w = vec3(linearize_depth(uv + vec2(-offset.x, 0.0), INV_PROJECTION_MATRIX));
	vec3 nw = vec3(linearize_depth(uv + vec2(-offset.x, -offset.y), INV_PROJECTION_MATRIX));
	vec3 ne = vec3(linearize_depth(uv + vec2(offset.x, -offset.y), INV_PROJECTION_MATRIX));
	vec3 sw = vec3(linearize_depth(uv + vec2(-offset.x, offset.y), INV_PROJECTION_MATRIX));
	vec3 se = vec3(linearize_depth(uv + vec2(offset.x, offset.y), INV_PROJECTION_MATRIX));

	mat3 px_around = mat3(
		vec3(nw.x, n.x, ne.x),
		vec3(w.x, depth, e.x),
		vec3(sw.x, s.x, se.x)
	);

	// Depth Based Edges:
	//
	// here sobel matrices and our matrix of pixel depths are the same size.
	// We take the sum of the dot products of the vectors in the x and y directions
	// to see if there is a horizontal or vertial gradient/edge at the pixel.
	// Then we average those values to get a final edge.
	// This works because the dot product outputs a value of how different the vectors are.
	// Summing them will result in a value between 0 and 1.
	float edge_x = dot(sx[0], px_around[0] + dot(sx[1], px_around[1]) + dot(sx[2], px_around[2]));
	float edge_y = dot(sx[0], px_around[0] + dot(sy[1], px_around[1]) + dot(sy[2], px_around[2]));
	float edge_d = sqrt(pow(edge_x, 2) + pow(edge_y, 2));

	// Surrounding Pixels Based on Normals:
	//
	// we use the offset to get the normal of each of the surrounding pixels and create a little matrix. For each element,
	// we subtract the normal of our chosen pixel from the normal of the adjacent pixel and get the length of the resulting vector.
	// Each element represents how different it is from the chosen pixel normal.
	n = normalize_normal(texture(NORMAL_TEXTURE, uv + vec2(0.0, -offset.y)).rgb);
	s = normalize_normal(texture(NORMAL_TEXTURE, uv + vec2(0.0, offset.y)).rgb);
	e = normalize_normal(texture(NORMAL_TEXTURE, uv + vec2(offset.x, 0.0)).rgb);
	w = normalize_normal(texture(NORMAL_TEXTURE, uv + vec2(-offset.x, 0.0)).rgb);
	nw = normalize_normal(texture(NORMAL_TEXTURE, uv + vec2(-offset.x, -offset.y)).rgb);
	ne = normalize_normal(texture(NORMAL_TEXTURE, uv + vec2(offset.x, -offset.y)).rgb);
	sw = normalize_normal(texture(NORMAL_TEXTURE, uv + vec2(-offset.x, offset.y)).rgb);
	se = normalize_normal(texture(NORMAL_TEXTURE, uv + vec2(offset.x, offset.y)).rgb);

	px_around = mat3(
		vec3(length(nw-normal), length(n-normal), length(ne-normal)),
		vec3(length(w-normal), length(normal-normal), length(e-normal)),
		vec3(length(sw-normal), length(s-normal), length(se-normal))
	);

	// Normal Based Edges:
	//
	// here sobel matrices and our matrix of pixel normals are the same size.
	// We take the sum of the dot products of the vectors in the x and y directions,
	// to see if there is a horizontal or vertial gradient/edge at the pixel.
	// Then we average those values to get a final edge.
	// This works because the dot product outputs a value of how different the vectors are.
	// Summing them will result in a value between 0 and 1.
	edge_x = dot(sx[0], px_around[0]) + dot(sx[1], px_around[1]) + dot(sx[2], px_around[2]);
	edge_y = dot(sy[0], px_around[0]) + dot(sy[1], px_around[1]) + dot(sy[2], px_around[2]);
	float edge_n = sqrt(pow(edge_x, 2.0) + pow(edge_y, 2.0));

	ALBEDO = mix(bg.rgb, color, clamp((edge_d - edge_threshold) + (edge_n - edge_threshold), 0.0, 1.0));

	// Cross Hatching:
	//
	// We multiply it by itself but rotated 90 degrees to get a darker hatch.
	// We use the normal one for medium brightness shadows.
	// And we add it to itself rotated 90 degrees which removes most of the black pixels making it look brighter.
	float mask = 1.0;
	if (luminance < hatch_thresh_1) {
		mask *= (texture(hatch, UV * hatch_size).r * texture(hatch, vec2(UV.x, -UV.y) * hatch_size).r) * 2.0 - 1.0;
		mask = clamp(mask, 0.0, 1.0);
	} else if (luminance < hatch_thresh_2) {
		mask *= texture(hatch, UV * hatch_size).r * 2.0 - 1.0;
		mask = clamp(mask, 0.0, 1.0);
	} else {
		mask *= (texture(hatch, UV * hatch_size).r + texture(hatch, vec2(UV.x, -UV.y) * hatch_size).r) * 2.0 - 1.0;
		mask = clamp(mask, 0.0, 1.0);
	}

	ALBEDO *= mix(vec3(0.0), bg.xyz, mask);
}