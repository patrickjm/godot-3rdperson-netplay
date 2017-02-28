extends Control

func _ready():
	gamestate.mainmenu = self;
	
	get_node("btnHost").connect("pressed", self, "_btnHost_pressed");
	get_node("btnConnect").connect("pressed", self, "_btnConnect_pressed");
	
	for i in OS.get_cmdline_args():
		if i == '-sv':
			host_dedicated_server();

func set_message(msg):
	get_node("lblMsg").set_text(str(msg));

func _btnHost_pressed():
	var name = get_node("lnName").get_text();
	var port = get_node("lnPort").get_text().to_int();
	var maxcl = get_node("lnMaxPlayers").get_text().to_int();
	var dedicated = get_node("chkDedicated").is_pressed();
	
	gamestate.sv_dedicated = dedicated;
	gamestate.cl_name = name;
	
	if (!gamestate.host_game(port, maxcl)):
		return;
	
	disable_control();

func host_dedicated_server():
	var name = get_node("lnName").get_text();
	var port = get_node("lnPort").get_text().to_int();
	var maxcl = get_node("lnMaxPlayers").get_text().to_int();
	
	gamestate.sv_dedicated = true;
	gamestate.cl_name = name;
	
	if (!gamestate.host_game(port, maxcl)):
		return;
	
	disable_control();

func _btnConnect_pressed():
	var name = get_node("lnName").get_text();
	var ip = get_node("lnIP").get_text();
	var port = get_node("lnPort").get_text().to_int();
	
	if (!gamestate.join_game(ip, port)):
		return;
	
	gamestate.cl_name = name;
	disable_control();

func disable_control():
	get_node("btnHost").set_disabled(true);
	get_node("btnConnect").set_disabled(true);

func enable_control():
	get_node("btnHost").set_disabled(false);
	get_node("btnConnect").set_disabled(false);
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE);
