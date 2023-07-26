@tool
extends EditorPlugin

const RED = Color(1, 0, 0)
const WHITE = Color(1, 1, 1)

var generate_button
var plugin
var line_edit
var progress_bar
var label
var vbox
var type_selector
var threading_select

func create_ui():
	vbox = VBoxContainer.new()
	var hbox = HBoxContainer.new()

	type_selector = OptionButton.new()
	type_selector.add_item('Trimesh')
	type_selector.add_item('Convex')
	type_selector.add_item('Multiple Convex')

	generate_button = Button.new()
	generate_button.text = 'Generate Collisions'
	var clb = Callable(self, '_on_generate_button_pressed')
	generate_button.connect('pressed', clb)

	label = Label.new()
	line_edit = LineEdit.new()


	var threading_label = Label.new()
	threading_label.text = 'Threading:'
	threading_select = OptionButton.new()
	for i in range(1, OS.get_processor_count() + 1):
		if i == 1:
			threading_select.add_item('Disabled')
		else:
			threading_select.add_item(str(i))

	var editor_viewport = get_editor_interface().get_editor_main_screen()
	await get_tree().process_frame

	line_edit.custom_minimum_size.x = editor_viewport.get_rect().size.x / 3
	progress_bar = ProgressBar.new()

	hbox.add_child(line_edit)
	hbox.add_child(type_selector)
	hbox.add_child(label)
	hbox.add_child(threading_label)
	hbox.add_child(threading_select)

	vbox.add_child(hbox)
	vbox.add_child(progress_bar)
	vbox.add_child(generate_button)


func _enter_tree():
	plugin = EditorPlugin.new()
	create_ui()
	add_control_to_bottom_panel(vbox, 'Generate Collisions')


func _exit_tree():
	remove_control_from_bottom_panel(vbox)


func label_error(msg):
	label.text = msg
	label.add_theme_color_override('font_color', RED)


func reset_label():
	label.text = ''
	label.add_theme_color_override('font_color', WHITE)


func find_all(node: Node, name_contains: String, result: Array) -> void:
	if node is MeshInstance3D and name_contains in node.name:
		result.push_back(node)

	for child in node.get_children():
		find_all(child, name_contains, result)

func create_collision_shape_from_mesh(mesh: Mesh):
	var col = CollisionShape3D.new()
	var cps = ConvexPolygonShape3D.new()
	cps.points = mesh.get_mesh_arrays()
	col.shape = cps

	return col

func generate_collisions_batch(data):
	var meshes = data[0]
	var type = data[1]
	var progress_step = data[2]
	for node in meshes:
		var static_body_child = node.get_child(0)
		if static_body_child and static_body_child is StaticBody3D:
			static_body_child.queue_free()

		await get_tree().process_frame

		print_debug('tete')
		match type:
			0:
				node.create_trimesh_collision()
			1:
				node.create_convex_collision()
			2:
				node.create_multiple_convex_collisions()

		progress_bar.value += progress_step


func _on_generate_button_pressed():
	reset_label()

	# Get the current scene
	var eds = plugin.get_editor_interface().get_selection()
	var selection = eds.get_selected_nodes()
	if not selection:
		return label_error('Error: No nodes selected!')

	# Get children of selected node
	var nodes = selection[0].get_children()
	if not len(nodes):
		return label_error('Error: Selected node has no children!')

	var name_contains = line_edit.text
	# Find all nodes with names that contain the specified string
	var matching_nodes = []
	find_all(selection[0], name_contains, matching_nodes)

	if not len(matching_nodes):
		return label_error('Error: Zero matching nodes found!')

	label.text = 'Processing ' + str(len(matching_nodes)) + ' nodes...'

	var type = type_selector.get_selected()
	progress_bar.value = 0.0
	var progress_step = 100.0 / matching_nodes.size()

	var thread_count = threading_select.get_selected()
	if thread_count == 0:
		generate_collisions_batch([matching_nodes, type, progress_step])
	else:
		var batches = []
		var batch_size = floor(matching_nodes.size() / thread_count)
		var remaining_nodes = matching_nodes.size() - batch_size * thread_count
		var node_index = 0
		for i in range(thread_count):
			var batch = []
			var size = batch_size
			if remaining_nodes > 0:
				size += remaining_nodes
				remaining_nodes = 0
			for j in range(size):
				batch.append(matching_nodes[node_index])
				node_index += 1
			batches.append(batch)

		for batch in batches:
			var thread = Thread.new()
			var clb = Callable(self, 'generate_collisions_batch').bind([batch, type, progress_step])
			thread.start(clb)


func _unregister():
	remove_control_from_bottom_panel(vbox)
