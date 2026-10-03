shader_type spatial;
render_mode diffuse_burley;
uniform vec4 paint : source_color = vec4(1.0);
uniform float roughness = 0.34;
uniform float metal = 0.0;
uniform float squash = 1.0;
uniform mat4 body_from_mesh;
uniform mat4 mesh_from_body;
void vertex() {
 vec4 body = body_from_mesh * vec4(VERTEX,1.0);
 // Chassis, fenders and wheel coverage retain their resting silhouette.
 if(body.y > 0.38) {
  body.y = 0.38 + (body.y - 0.38) * squash;
  vec3 normal_body = mat3(body_from_mesh) * NORMAL;
  normal_body.y /= squash;
  NORMAL = normalize(mat3(mesh_from_body) * normal_body);
 }
 VERTEX = (mesh_from_body * body).xyz;
}
void fragment() {
 ALBEDO=paint.rgb;
 ROUGHNESS=roughness;
 METALLIC=metal;
 SPECULAR=.42;
 CLEARCOAT=.30;
 CLEARCOAT_ROUGHNESS=.28;
}
