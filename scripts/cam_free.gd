extends Spatial

const SPEED = 10.0;
const SENSITIVITY = 0.3;

var pitch = 0.0;
var yaw = 0.0;
var cam;

func _ready():
	cam = get_node("cam");
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED);
	
	set_process_input(true);
	set_fixed_process(true);

func _input(ie):
	if (Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED):
		return;
	
	if (ie.type == InputEvent.MOUSE_MOTION):
		pitch = clamp(pitch-ie.relative_y*SENSITIVITY, -89.0, 89.0);
		yaw = fmod(yaw-ie.relative_x*SENSITIVITY, 360.0);
		
		cam.set_rotation(Vector3(deg2rad(pitch), 0, 0));
		set_rotation(Vector3(0, deg2rad(yaw), 0));

func _fixed_process(delta):
	if (Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED):
		return;
	
	var aim = cam.get_global_transform().basis;
	var dir = Vector3();
	
	if (Input.is_action_pressed("forward")):
		dir -= aim[2];
	if (Input.is_action_pressed("backward")):
		dir += aim[2];
	if (Input.is_action_pressed("left")):
		dir -= aim[0];
	if (Input.is_action_pressed("right")):
		dir += aim[0];
	
	dir = dir.normalized();
	set_translation(get_translation()+dir*SPEED*delta);
