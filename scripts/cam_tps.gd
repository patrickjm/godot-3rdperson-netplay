extends Spatial

var cam = null;
var pitch = 0.0;
var yaw = 0.0;
var dist = 2.5;
var curRange;
var curPivotRange;
var sensitivity = 0.3;
var ray_res = {};
var excl = [];
var pos = Vector3();
var target = Vector3();

func _init():
	curRange = dist;
	curPivotRange = 0.0;

func _ready():
	cam = get_node("cam");

func set_active(active):
	if (active):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED);
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE);
	
	set_process(active);
	set_fixed_process(active);
	set_process_input(active);

func _input(ie):
	if (Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED):
		return;
	
	if (ie.type == InputEvent.MOUSE_MOTION):
		pitch = clamp(pitch+ie.relative_y*sensitivity, -89.0, 89.0);
		yaw = fmod(yaw-ie.relative_x*sensitivity, 360.0);

func _process(delta):
	var pivot = get_global_transform().origin;
	var pr = 0.0;
	var r = dist;
	if (get_parent().is_aiming):
		r = 1.6;
		pr = 0.8
	curRange = lerp(curRange, r, 5*delta);
	curPivotRange = lerp(curPivotRange, pr, 5*delta);
	var m = Vector3(curPivotRange*cos(deg2rad(yaw)),0.0,curPivotRange*-sin(deg2rad(yaw)));
	
	pos = pivot;
	pos.x += curRange*sin(deg2rad(yaw))*cos(deg2rad(pitch));
	pos.y += curRange*sin(deg2rad(pitch));
	pos.z += curRange*cos(deg2rad(yaw))*cos(deg2rad(pitch));
	pos += m;
	
	target = pivot;
	target += m;
	
	var cast_from = pos;
	
	if (!ray_res.empty() && (ray_res.collider extends StaticBody || ray_res.collider extends RigidBody)):
		cast_from = ray_res.position;
	
	cam.look_at_from_pos(cast_from, target, Vector3(0,1,0));

func _fixed_process(delta):
	ray_res = get_world().get_direct_space_state().intersect_ray(target, pos, excl);
