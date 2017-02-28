extends Node

var time;
var env;
var gui;

func _init():
	time = 0.0;

func _ready():
	env = get_node("env");
	gui = get_node("gui");
	
	gamestate.world_ready();
	set_process(true);

func _process(delta):
	time += delta;
