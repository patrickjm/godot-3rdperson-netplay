extends RigidBody

slave var transform = Transform();
slave var lv = Vector3();
slave var av = Vector3();

func _ready():
	set_can_sleep(false);

func _integrate_forces(state):
	if (get_tree().is_network_server()):
		rset_unreliable("transform", state.get_transform());
		rset_unreliable("lv", state.get_linear_velocity());
		rset_unreliable("av", state.get_angular_velocity());
	else:
		var trans = state.get_transform();
		if (trans.origin.distance_to(transform.origin) < 2.0):
			trans.origin = trans.origin.linear_interpolate(transform.origin, 10*state.get_step());
			trans.basis = Matrix3(Quat(trans.basis).slerp(Quat(transform.basis), 10*state.get_step()));
		else:
			trans.origin = transform.origin;
			trans.basis = transform.basis;
			
		state.set_transform(trans);
		state.set_linear_velocity(lv);
		state.set_angular_velocity(av);
