@tool
extends EditorPlugin


func _enter_tree():
	# Initialization of the plugin goes here.
	@warning_ignore("unsafe_method_access")
	var action_plugin: EditorInspectorPlugin = load("res://addons/tilemapcollidergenerator/editors/tilemap_action_property_inspector_plugin.gd").new()
	if action_plugin != null:
		add_inspector_plugin(action_plugin)

func _exit_tree():
	# Clean-up of the plugin goes here.
	pass
