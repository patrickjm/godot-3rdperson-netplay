extends RigidBody

var accel = 12.0;
var deaccel = 15.0;
var jump_velocity = 7.5;

slave var local_dir = Vector3();
slave var local_input = [0, 0, 0];

sync var linear_velocity = Vector3();
sync var body_rotation = [0.0, 0.0];
sync var transform_pos = Vector3();
sync var camera_aim = Vector3();

var max_speed = 6.0;
var on_floor = false;
var moving = false;
var jumping = false;

onready var ui_health = get_node("/root/world/gui/healthbar/health");
onready var ui_crosshair = get_node("/root/world/gui/crosshair");

onready var body = get_node("body");
onready var models = get_node("body/models");
onready var camera = get_node("camera");
onready var camera_instance = get_node("camera/cam");
onready var skeleton = get_node("body/models/Armature/Skeleton");
onready var animation = get_node("body/models/AnimationPlayer");

sync var health = 0.0;
sync var is_dying = false;
sync var is_aiming = false;

var player_name = "";
var dying_time = 0.0;
var next_shoot = 0.0;
var next_aim = 0.0;

var pfb_missile;
var pfb_explosion;

func _init():
	moving = false;
	player_name = "";
	health = 100.0;
	is_dying = false;
	is_aiming = false;
	dying_time = 0.0;
	next_shoot = 0.0;
	next_aim = 0.0;

func _ready():
	pfb_missile = load("res://prefabs/rocket.tscn");
	pfb_explosion = load("res://prefabs/explosion.tscn");
	
	if (!is_network_master()):
		camera.queue_free();
	else:
		camera.set_active(true);
		camera.excl.append(self);
	
	set_process(true);
	set_fixed_process(true);

func _process(delta):
	update_gui();
	update_body(delta);
	dying_think();

func _fixed_process(delta):
	animation_switcher();
	local_input();
	aim_think();
	shoot_think();

func update_gui():
	if (!is_network_master()):
		return;
	
	ui_health.set_text(str(int(health)).pad_zeros(3));
	
	if (is_aiming && !ui_crosshair.is_visible()):
		ui_crosshair.show();
	
	if (!is_aiming && ui_crosshair.is_visible()):
		ui_crosshair.hide();

func update_body(delta):
	if (!is_dying):
		var trans = body.get_transform();
		trans.basis = Matrix3(Quat(trans.basis).slerp(Quat(Vector3(0,1,0), body_rotation[1]), 5*delta));
		body.set_transform(trans);
	
	var bone_id = skeleton.find_bone("stomach");
	var bone_pose = skeleton.get_bone_pose(bone_id);
	if (!is_dying):
		bone_pose.basis = bone_pose.basis.rotated(Vector3(1,0,0), deg2rad(-body_rotation[0]));
	skeleton.set_bone_custom_pose(bone_id, bone_pose);

func animation_switcher():
	if (is_dying):
		set_animation("dying");
		return;
	
	var hv_len = linear_velocity;
	hv_len.y = 0;
	hv_len = hv_len.length();
	
	if (hv_len > 0.5):
		set_animation("walk");
		return;
	
	set_animation("idle");

func set_animation(ani, speed = 1.0, force = false):
	if (animation.get_current_animation() != ani || force):
		animation.play(ani);
	if (animation.get_speed() != speed || force):
		animation.set_speed(speed);

func local_input():
	if (!is_network_master()):
		return;
	
	if (gamestate.cl_chatting):
		local_input[0] = false;
		local_input[1] = false;
		local_input[2] = false;
	else:
		local_input[0] = Input.is_action_pressed("jump");
		local_input[1] = Input.is_action_pressed("shoot");
		local_input[2] = Input.is_action_pressed("aim");
	
	rset_unreliable("local_input", local_input);
	body_rotation[0] = camera.pitch;
	
	camera_aim = -camera_instance.get_global_transform().basis[2];
	rset_unreliable("camera_aim", camera_aim);

func get_object_name():
	if (is_network_master()):
		return "";
	else:
		return player_name;

func give_damage(attacker, dmg):
	if (!get_tree().is_network_server() || is_dying):
		return;
	
	health = clamp(health-dmg, 0.0, 100.0);
	rset("health", health);
	
	if (health <= 0.0):
		dying_time = gamestate.world.time;
		rset("is_dying", true);
		
		gamestate.chatmgr.broadcast_msg(str(gamestate.players[get_name().to_int()], " is wrecked by ", gamestate.players[attacker], "."));

func dying_think():
	if (!is_dying || !get_tree().is_network_server()):
		return;
	
	if (gamestate.world.time < dying_time+gamestate.spawn_delay):
		return;
	
	set_global_transform(Transform(Matrix3(), gamestate.get_random_spawnpoint()));
	rset("health", 100.0);
	rset("is_dying", false);

func aim_think():
	if (!get_tree().is_network_server()):
		return;
	
	if (is_dying):
		is_aiming = false;
	
	if (gamestate.world.time > next_aim && local_input[2] && !is_dying):
		is_aiming = !is_aiming;
		next_aim = gamestate.world.time + 0.5;
	
	rset("is_aiming", is_aiming);

func shoot_think():
	if (!get_tree().is_network_server() || is_dying || !is_aiming):
		return;
	
	if (gamestate.world.time < next_shoot || !local_input[1]):
		return;
	
	var pos = get_node("body/shoot_pos").get_global_transform().origin;
	var impulse = (camera_aim+Vector3(0, 0.1, 0))*30;
	
	rpc("spawn_missile", get_name().to_int(), pos, impulse);
	next_shoot = gamestate.world.time+0.5;

sync func spawn_missile(owner, pos, impulse):
	var inst = pfb_missile.instance();
	inst.set_name("missile");
	inst.owner = owner;
	inst.set_global_transform(Transform(Matrix3(), pos));
	inst.apply_impulse(Vector3(), impulse);
	
	if (get_tree().get_network_unique_id() == owner):
		inst.add_collision_exception_with(self);
	
	if (get_tree().is_network_server()):
		inst.add_collision_exception_with(gamestate.player_by_id(owner));
		inst.connect("exploded", self, "missile_exploded");
	
	gamestate.world.env.add_child(inst, true);

func missile_exploded(owner, pos):
	if (!get_tree().is_network_server()):
		return;
	
	for i in gamestate.get_players():
		var dist = pos.distance_to(i.get_global_transform().origin);
		if (dist <= 4.0 && !i.is_dying):
			i.give_damage(owner, rand_range(30, 40)*(1.0-dist/4.0));
	
	rpc("create_explosion", pos);

sync func create_explosion(pos):
	var inst = pfb_explosion.instance();
	inst.set_name("expl");
	inst.set_global_transform(Transform(Matrix3(), pos));
	gamestate.world.env.add_child(inst, true);

func _integrate_forces(state):
	if (is_network_master()):
		client_movement(state);
	
	if (get_tree().is_network_server()):
		server_movement(state);
	else:
		client_update(state);

func client_movement(state):
	var dir = Vector3();
	var aim = camera_instance.get_global_transform().basis;
	
	if (!gamestate.cl_chatting):
		if Input.is_action_pressed("left"):
			dir -= aim[0];
		if Input.is_action_pressed("right"):
			dir += aim[0];
		if Input.is_action_pressed("forward"):
			dir -= aim[2];
		if Input.is_action_pressed("backward"):
			dir += aim[2];
	
	dir.y = 0;
	dir = dir.normalized();
	local_dir = dir;
	
	if (dir.length() > 0.0):
		body_rotation[1] = -atan2(dir.x, dir.z);
	
	if (is_aiming):
		body_rotation[1] = -deg2rad(camera.yaw-180);
	
	rset_unreliable("local_dir", local_dir);
	rset_unreliable("body_rotation", body_rotation);

func server_movement(state):
	var lv = state.get_linear_velocity()
	var g = state.get_total_gravity();
	var delta = state.get_step();
	
	lv += g*delta # Apply gravity
	
	var up = -g.normalized() # (up is against gravity)
	var vv = up.dot(lv) # Vertical velocity
	var hv = lv - up*vv # Horizontal velocity
	
	var hdir = hv.normalized() # Horizontal direction
	var hspeed = hv.length() # Horizontal speed
	
	var floor_velocity;
	var onfloor = false;
	var dir = Vector3();
	if (!is_dying):
		dir = local_dir;
	var speed = max_speed;
	if (is_aiming):
		speed *= 0.5;
	
	if (state.get_contact_count() > 0):
		for i in range(state.get_contact_count()):
			if (state.get_contact_local_shape(i) != 1):
				continue
			
			onfloor = true
			break
	
	var jump_attempt = local_input[0] && !is_dying;
	var target_dir = (dir - up*dir.dot(up)).normalized();
	
	moving = false;
	
	if (onfloor):
		if (dir.length() > 0.1):
			hdir = target_dir;
			
			if (hspeed < speed):
				hspeed = min(hspeed+(accel*delta), speed);
			else:
				hspeed = speed;
			
			moving = true;
		else:
			hspeed -= deaccel*delta;
			if (hspeed < 0):
				hspeed = 0;
		
		hv = hdir*hspeed;
		
		if (not jumping and jump_attempt):
			vv = jump_velocity;
			
			jumping = true;
	else:
		var hs;
		if (dir.length() > 0.1):
			hv += target_dir*(accel*0.2)*delta;
			if (hv.length() > speed):
				hv = hv.normalized()*speed;
	
	if (jumping and vv < 0):
		jumping = false;
	
	lv = hv + up*vv;
	on_floor = onfloor;
	
	state.set_linear_velocity(lv);
	linear_velocity = lv;
	rset_unreliable("linear_velocity", linear_velocity);
	
	transform_pos = state.get_transform().origin;
	rset_unreliable("transform_pos", state.get_transform().origin);

func client_update(state):
	var transform = state.get_transform();
	if (transform.origin.distance_to(transform_pos) < 2.0):
		transform.origin = transform.origin.linear_interpolate(transform_pos, 10*state.get_step());
	else:
		transform.origin = transform_pos;
	state.set_transform(transform);
	state.set_linear_velocity(linear_velocity);
