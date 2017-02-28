extends Spatial

var time = 0.0;

func _ready():
	get_node("clouds").set_emitting(true);
	get_node("fires").set_emitting(true);
	
	set_process(true);

func _process(delta):
	time += delta;
	
	if (time > 2.0):
		set_process(false);
		queue_free();
		return;