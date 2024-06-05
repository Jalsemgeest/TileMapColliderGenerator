@tool
class_name TileMapCollisionGenerator
extends StaticBody2D

#-DECLARATIONS-#

var _tilemap_node: TileMap
var _collision_polygon_node: CollisionPolygon2D

#-EXPORTS-#

@warning_ignore("unused_private_class_variable")
@export_placeholder("TileMapActionProperty") var _refresh: String = "" : set = _refresh_action

## NodePath to the tilemap.
@export_node_path("TileMap") var tilemap_node_path: NodePath : set = set_tilemap_node_path

## NodePath to CollisionPolygon2D node for which polygon data will be generated. If unset, it will generate it's own.
## Note: You should not set this if you want separate floating objects to be included as well.
@export_node_path("CollisionPolygon2D") var collision_polygon_node_path: NodePath : set = set_collision_polygon_node_path


## Whether we will use the physics material or the tiles themselves.
@export var reference_physics_material: bool = true

## The layer that will be targetted when referencing your tilemap.
@export var target_layer: int = 0

## Tiles that have a physics layer return the original orientation of the physics
## layer by default. With this enabled you can respect the orientation within your
## tilemap. This is mainly provided so if this is fixed within Godot you can
## disable this.
@export var force_respect_flipped_tiles_physics: bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func _refresh_action(value: String) -> void:
	if _collision_polygon_node == null:
		# Delete all children collisionpolygon2d nodes.
		for child in get_children():
			print(str(child))
			if child is CollisionPolygon2D:
				child.get_parent().remove_child(child)
				child.queue_free()
	
	set_polygons_on_colliders()

func set_polygons_on_colliders() -> void:
	var polygons = []
	if reference_physics_material:
		polygons = get_tiles_with_physics()
	else:
		polygons = get_polygons()
	# Polygons to remove will hold the actual polygons
	var polygons_to_remove := []
	# Index to remove is a dictionary so that searching is faster
	var index_to_remove := {}

	while true:
		# Clear the polygons to remove
		polygons_to_remove = []
		index_to_remove = {}
		
		# Start looping
		for index in polygons.size():
			# Skip if the polygon is due to remove
			if index_to_remove.get(index, false) == true:
				continue

			var polygon_a = polygons[index]

			# Loop from the start of the array to
			# the current polygon
			for secondary_index in index:
				# Skip if the polygon is due to remove
				if index_to_remove.get(secondary_index, false) == true:
					continue

				var polygon_b = polygons[secondary_index]
				var merged_polygons = Geometry2D.merge_polygons(polygon_a, polygon_b)

				# The polygons dind't merge so skip to the next loop
				if merged_polygons.size() != 1:
					continue

				# Replace the polygon with the merged one
				polygons[secondary_index] = merged_polygons[0]
				
				# Mark to remove the already merged polygon
				polygons_to_remove.append(polygon_a)
				index_to_remove[index] = true
				break

		# There is no polygon to remove so we finished
		if polygons_to_remove.size() == 0:
			break

		# Remove the polygons marked to be removed
		for polygon in polygons_to_remove:
			var index = polygons.find(polygon)
			polygons.pop_at(index)

	if len(polygons) == 0:
		print("Could not find any polygons.")
	elif _collision_polygon_node != null:
		_collision_polygon_node.polygon = polygons[0]
		print("Set the assigned polygon shape.")
	else:
		var count = 0
		for polygon in polygons:
			var polygon_shape = CollisionPolygon2D.new()
			polygon_shape.polygon = polygon
			polygon_shape.name = "TMCG-CollisionPolygon2D-"+str(count)
			count += 1
			add_child(polygon_shape)
			polygon_shape.owner = get_parent()
		print("Added " + str(len(polygons)) + "(s) unique polygons.")

func get_points(position: Vector2, cell_size: Vector2) -> Array:
	var x = position.x
	var y = position.y
	#1   2
	#
	#0   3
	return [
		Vector2(x * cell_size.x, y * cell_size.y + cell_size.y),  # 0
		Vector2(x * cell_size.x, y * cell_size.y),  # 1
		Vector2(x * cell_size.x + cell_size.x, y * cell_size.y),  # 2
		Vector2(x * cell_size.x + cell_size.x, y * cell_size.y + cell_size.y)  # 3
	]
	
# Generate the edges/polygon from a tile points
func get_tile_polygon(points) -> Array:
	return [points[0], points[1], points[1], points[2], points[2], points[3], points[3], points[0]]

func get_polygons() -> Array:
	var polygons := []
	var used_cells = _tilemap_node.get_used_cells(target_layer)
	var tile_size = _tilemap_node.tile_set.tile_size
	for cell in used_cells:
		var polygon = get_tile_polygon(get_points(cell, Vector2(tile_size.x, tile_size.y)))
		polygons.append(polygon)
	return polygons

func get_tiles_with_physics() -> Array:
	var shapes = []
	var used_cells = _tilemap_node.get_used_cells(target_layer)
	for cell_pos in used_cells:
		var tile_data = _tilemap_node.get_cell_tile_data(target_layer, cell_pos)
		# We will use the local and the tilesize to calculate all of the physics points.
		if tile_data.get_collision_polygons_count(0) != 0:
			var flip_h := 0
			var flip_v := 0
			if force_respect_flipped_tiles_physics:
				var alt := _tilemap_node.get_cell_alternative_tile(target_layer,cell_pos)
				flip_h = alt & TileSetAtlasSource.TRANSFORM_FLIP_H
				flip_v = alt & TileSetAtlasSource.TRANSFORM_FLIP_V
			var local_pos = _tilemap_node.map_to_local(cell_pos)
			var physics_coords = tile_data.get_collision_polygon_points(0, 0)
			var shape: Array[Vector2] = []
			
			for coord in physics_coords:
				if flip_h and !flip_v:
					shape.append(Vector2((coord.x * -1) + local_pos.x, coord.y + local_pos.y))
				elif flip_v and !flip_h:
					shape.append(Vector2(coord.x + local_pos.x, (coord.y * -1) + local_pos.y))
				elif flip_h and flip_v:
					shape.append(Vector2((coord.x * -1) + local_pos.x, (coord.y * -1) + local_pos.y))
				else:
					shape.append(Vector2(coord.x + local_pos.x, coord.y + local_pos.y))
			shapes.append(shape)
	return shapes

func set_tilemap_node_path(value: NodePath) -> void:
	tilemap_node_path = value

	if not is_inside_tree():
		print("TileMap must be a within the scene of TileMapCollisionGenerator.")
		return
	
	if tilemap_node_path.is_empty():
		_tilemap_node = null
		print("CollidionPolygon2D path is empty.")
		return

	_tilemap_node = get_node(tilemap_node_path) as TileMap
	
	if not _tilemap_node:
		push_error("tilemap_node_path should point to proper TileMap node.")

func set_collision_polygon_node_path(value: NodePath) -> void:
	collision_polygon_node_path = value
	
	if not is_inside_tree():
		print("CollidionPolygon2D must be a within the scene of TileMapCollisionGenerator.")
		return
	
	if collision_polygon_node_path.is_empty():
		_collision_polygon_node = null
		print("CollidionPolygon2D path is empty.")
		return

	_collision_polygon_node = get_node(collision_polygon_node_path) as CollisionPolygon2D
	
	if not _collision_polygon_node:
		print("collision_polygon_node_path should point to proper CollisionPolygon2D node.")
		print("CollisionPolygon2D will be generated for each unique shape.")

func _enter_tree():
	set_tilemap_node_path(tilemap_node_path)
	set_collision_polygon_node_path(collision_polygon_node_path)
	pass


func _exit_tree():
	pass
