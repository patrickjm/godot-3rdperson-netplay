extends Control

var messages;
var input;
var animation;

func _init():
	gamestate.chatmgr = self;

func _ready():
	messages = get_node("bg/chatMessages");
	messages.set_scroll_follow(true);
	messages.set_scroll_active(false);
	
	input = get_node("chatInput");
	input.hide();
	
	animation = get_node("AnimationPlayer");
	animation.play("fade_out");
	
	set_process_input(true);

func _input(ie):
	if (ie.type == InputEvent.KEY):
		if (ie.pressed && (ie.scancode == KEY_RETURN || ie.scancode == KEY_ENTER)):
			if (input.is_visible() && input.has_focus()):
				rpc("send_chat", get_tree().get_network_unique_id(), input.get_text());
				
				messages.set_scroll_active(false);
				input.set_text("");
				input.hide();
				
				gamestate.cl_chatting = false;
				animation.play("fade_out");
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED);
			else:
				messages.set_scroll_active(true);
				input.show();
				input.grab_focus();
				
				animation.play("fade_in");
				gamestate.cl_chatting = true;
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE);

master func send_chat(id, msg):
	msg = str(msg).strip_edges();
	
	if (msg.length() <= 0):
		return;
	
	if (msg.begins_with("/")):
		msg = msg.substr(1, msg.length()-1);
		msg = msg.split(" ", false);
		
		if (msg[0] == "online"):
			if (id == get_tree().get_network_unique_id()):
				add_message("Players Online:");
			else:
				rpc_id(id, "add_message", "Players Online:");
			
			var num = 0;
			for i in gamestate.players.values():
				num += 1;
				if (id == get_tree().get_network_unique_id()):
					add_message(str(num, ". ", i));
				else:
					rpc_id(id, "add_message", str(num, ". ", i));
		
		else:
			rpc_id(id, "add_message", "Command not found.");
		return;
	
	if (id == 1 && gamestate.sv_dedicated):
		msg = "Server: "+msg;
	else:
		msg = gamestate.players[id]+": "+msg;
	
	rpc("add_message", msg);
	if (gamestate.sv_dedicated):
		print("[Chat] ", msg);

func broadcast_msg(msg):
	if (!get_tree().is_network_server()):
		return;
	
	rpc("add_message", msg);
	if (gamestate.sv_dedicated):
		print("[Chat] ", msg);

func send_msg_to(id, msg):
	if (!get_tree().is_network_server()):
		return;
	
	rpc_id(id, "add_message", msg);
	if (gamestate.sv_dedicated):
		print("[Chat] ", msg);

sync func add_message(msg):
	if (messages.get_text() != ""):
		messages.newline();
	
	messages.add_text(msg);
	
	if (!gamestate.cl_chatting):
		animation.play("fade_out");
