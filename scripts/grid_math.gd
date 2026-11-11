extends RefCounted


static func world_to_cell(world_position: Vector2, origin: Vector2, board_pixels: float, cells: int) -> Vector2i:
	var cell_pixels := board_pixels / float(cells)
	var local := world_position - origin
	var column := int(floor(local.x / cell_pixels))
	var top_row := int(floor(local.y / cell_pixels))
	return Vector2i(column, cells - 1 - top_row)


static func cell_center(cell: Vector2i, origin: Vector2, board_pixels: float, cells: int) -> Vector2:
	var cell_pixels := board_pixels / float(cells)
	var top_row := cells - 1 - cell.y
	return origin + Vector2(
		(float(cell.x) + 0.5) * cell_pixels,
		(float(top_row) + 0.5) * cell_pixels
	)


static func in_bounds(cell: Vector2i, cells: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cells and cell.y < cells


static func point_in_rect(point: Vector2, rect: Array) -> bool:
	if rect.size() < 4:
		return false
	var x := float(rect[0])
	var y := float(rect[1])
	var width := float(rect[2])
	var height := float(rect[3])
	return point.x >= x and point.x <= x + width and point.y >= y and point.y <= y + height
