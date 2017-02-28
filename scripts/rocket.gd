extends RigidBody

var owner;
var models;
var run_time;

signal exploded(owner, pos);

func _init():
	owner = -1;
	run_time = 0.0;

func _ready():
	models = get_node("rocket");
	models.hide();
	
	set_process(true);

func _process(delta):
	run_time += delta;
	
	if (run_time > 5.0):
		emit_signal("exploded", owner, get_global_transform().origin);
		queue_free();
		return;

func _integrate_forces(state):
	if (!models.is_visible()):
		models.show();
	
	var lv = state.get_linear_velocity();
	var transform = state.get_transform();
	models.look_at(transform.origin+lv.normalized(), Vector3(0,1,0));
	
	if (state.get_contact_count() > 0):
		emit_signal("exploded", owner, get_global_transform().origin);
		set_process(false);
		queue_free();
