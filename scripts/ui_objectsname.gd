extends Control

export(DynamicFont) var font;
export(Color) var text_color;
export(NodePath) var objects_node;

var objects = [];
var margin = Vector3(0, 1.6, 0);

func _ready():
	if (typeof(objects_node) == TYPE_NODE_PATH && !objects_node.is_empty()):
		objects_node = get_node(objects_node);
	
	set_process(true);

func _process(delta):
	if (!is_visible() || !get_viewport().get_camera()):
		return;
	
	objects.clear();
	
	for i in objects_node.get_children():
		if (!i.has_method("get_object_name")):
			continue;
		var name = i.get_object_name();
		if (name == ""):
			continue;
		var pos = get_viewport().get_camera().unproject_position(i.get_global_transform().origin+margin);
		objects.append({'pos': pos, 'name': name});
	
	update();

func _draw():
	for i in objects:
		draw_string(font, i.pos, i.name, text_color);
