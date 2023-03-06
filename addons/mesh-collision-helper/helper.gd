tool
extends EditorPlugin

const RED = Color(1, 0, 0)
const WHITE = Color(1, 1, 1)

var generate_button
var plugin
var line_edit
var progress_bar
var label
var vbox


func create_ui():
	vbox = VBoxContainer.new()
	var hbox = HBoxContainer.new()

	generate_button = Button.new()
	generate_button.text = "Generate Trimesh Collisions"
	generate_button.connect("pressed", self, "_on_generate_button_pressed")

	label = Label.new()
	line_edit = LineEdit.new()

	var editor_viewport = get_editor_interface().get_editor_viewport()
	yield(get_tree(), 'idle_frame')

	line_edit.rect_min_size.x = editor_viewport.rect_size.x / 3
	progress_bar = ProgressBar.new()

	hbox.add_child(line_edit)
	hbox.add_child(label)

	vbox.add_child(hbox)
	vbox.add_child(progress_bar)
	vbox.add_child(generate_button)


func _enter_tree():
	plugin = EditorPlugin.new()
	create_ui()
	add_control_to_bottom_panel(vbox, "GenerateCollisions")


func _exit_tree():
	remove_control_from_bottom_panel(vbox)


func label_error(msg):
	label.text = msg
	label.add_color_override("font_color", RED)


func reset_label():
	label.text = ''
	label.add_color_override("font_color", WHITE)


func find_all(node: Node, name_contains : String, result : Array) -> void:
	if node is MeshInstance and name_contains in node.name:
		result.push_back(node)

	for child in node.get_children():
		find_all(child, name_contains, result)


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
	progress_bar.value = 0.0
	var progress_step = 100.0 / matching_nodes.size()
	# Generate trimesh collisions for each matching node
	for node in matching_nodes:
		var static_body_child = node.get_child(0)
		if static_body_child:
			static_body_child.queue_free()

		yield(get_tree(), "idle_frame")
		node.create_trimesh_collision()
		progress_bar.value += progress_step


func _register():
	var icon =  get_editor_interface().get_base_control().get_icon("Node", "EditorIcons")
	add_custom_type("GenerateCollisions", "EditorPlugin", load("generate_collisions.gd"), icon)


func _unregister():
	remove_control_from_bottom_panel(vbox)
	remove_custom_type("GenerateCollisions")
