extends Node2D

signal cell_clicked(cell: Vector2i)

const GridMath = preload("res://scripts/grid_math.gd")
const COLUMN_LABELS := "ABCDEFGHIJ"

@export var board_origin := Vector2(500, 80)
@export var board_pixel_size := 960.0
@export var input_enabled := true

var cells := 6
var landmarks: Array = []
var blocked: Dictionary = {}
var hit_cells: Dictionary = {}
var miss_cells: Dictionary = {}
var sunk_ships: Array = []
var hover_cell := Vector2i(-999, -999)


func _ready() -> void:
	set_process_unhandled_input(true)


func configure(p_cells: int, p_landmarks: Array, p_blocked: Dictionary) -> void:
	cells = p_cells
	landmarks = p_landmarks
	blocked = p_blocked
	hit_cells.clear()
	miss_cells.clear()
	sunk_ships.clear()
	hover_cell = Vector2i(-999, -999)
	queue_redraw()


func reset_marks() -> void:
	hit_cells.clear()
	miss_cells.clear()
	sunk_ships.clear()
	queue_redraw()


func mark_hit(cell: Vector2i) -> void:
	hit_cells[cell] = true
	queue_redraw()


func mark_miss(cell: Vector2i) -> void:
	miss_cells[cell] = true
	queue_redraw()


func mark_sunk(ship_cells: Array, color: Color) -> void:
	sunk_ships.append({"cells": ship_cells, "color": color})
	queue_redraw()


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled


func board_rect() -> Rect2:
	return Rect2(board_origin, Vector2(board_pixel_size, board_pixel_size))


func cell_size() -> float:
	return board_pixel_size / float(cells)


func cell_top_left(cell: Vector2i) -> Vector2:
	var size := cell_size()
	var top_row := cells - 1 - cell.y
	return board_origin + Vector2(float(cell.x) * size, float(top_row) * size)


func world_to_cell(world_position: Vector2) -> Vector2i:
	return GridMath.world_to_cell(world_position, board_origin, board_pixel_size, cells)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered := world_to_cell(get_global_mouse_position())
		if hovered != hover_cell:
			hover_cell = hovered
			queue_redraw()
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return
		if not input_enabled:
			return
		var clicked := world_to_cell(get_global_mouse_position())
		if not GridMath.in_bounds(clicked, cells):
			return
		if blocked.has(clicked):
			return
		cell_clicked.emit(clicked)


func _draw() -> void:
	if cells <= 0:
		return

	var size := cell_size()
	var rect := board_rect()
	var font: Font = ThemeDB.fallback_font
	var grid_color := Color(0.80, 0.92, 1.0, 0.42)
	var label_color := Color(0.94, 0.98, 1.0, 0.95)

	draw_rect(rect, Color(0.02, 0.10, 0.18, 0.20), true)

	for row in range(cells):
		for column in range(cells):
			var cell := Vector2i(column, row)
			var cell_rect := Rect2(cell_top_left(cell), Vector2(size, size))
			if (column + row) % 2 == 0:
				draw_rect(cell_rect, Color(1.0, 1.0, 1.0, 0.035), true)
			if blocked.has(cell):
				draw_rect(cell_rect, Color(0.10, 0.30, 0.12, 0.28), true)
			if hover_cell == cell and not blocked.has(cell):
				draw_rect(cell_rect, Color(1.0, 0.94, 0.60, 0.16), true)

	for index in range(cells + 1):
		var x := board_origin.x + float(index) * size
		draw_line(Vector2(x, board_origin.y), Vector2(x, board_origin.y + board_pixel_size), grid_color, 1.5)
		var y := board_origin.y + float(index) * size
		draw_line(Vector2(board_origin.x, y), Vector2(board_origin.x + board_pixel_size, y), grid_color, 1.5)

	for column in range(cells):
		var letter := COLUMN_LABELS.substr(column, 1)
		draw_string(
			font,
			Vector2(board_origin.x + float(column) * size, board_origin.y + board_pixel_size + 24.0),
			letter,
			HORIZONTAL_ALIGNMENT_CENTER,
			size,
			18,
			label_color
		)

	for row in range(cells):
		var top_left := cell_top_left(Vector2i(0, row))
		draw_string(
			font,
			Vector2(board_origin.x - 34.0, top_left.y + size * 0.5 + 6.0),
			str(row + 1),
			HORIZONTAL_ALIGNMENT_CENTER,
			28.0,
			18,
			label_color
		)

	for landmark in landmarks:
		var landmark_cell: Vector2i = landmark["cell"]
		if not GridMath.in_bounds(landmark_cell, cells):
			continue
		var center := GridMath.cell_center(landmark_cell, board_origin, board_pixel_size, cells)
		var color: Color = landmark.get("color", Color("#ffd166"))
		draw_arc(center, size * 0.36, 0.0, TAU, 40, color, 3.5, true)
		_draw_centered_text(String(landmark["name"]), center + Vector2(0.0, -size * 0.31), 16, Color(1, 1, 1, 0.95))

	for cell in hit_cells.keys():
		var center := GridMath.cell_center(cell, board_origin, board_pixel_size, cells)
		draw_circle(center, size * 0.16, Color(1.0, 0.45, 0.10, 0.92))
		draw_line(center + Vector2(-size * 0.10, -size * 0.10), center + Vector2(size * 0.10, size * 0.10), Color(1, 0.92, 0.6, 0.95), 3.0)
		draw_line(center + Vector2(size * 0.10, -size * 0.10), center + Vector2(-size * 0.10, size * 0.10), Color(1, 0.92, 0.6, 0.95), 3.0)

	for cell in miss_cells.keys():
		var center := GridMath.cell_center(cell, board_origin, board_pixel_size, cells)
		draw_circle(center, size * 0.10, Color(0.86, 0.95, 1.0, 0.72))
		draw_circle(center, size * 0.045, Color(0.04, 0.14, 0.24, 0.9))

	for sunk in sunk_ships:
		var ship_color: Color = sunk["color"]
		for cell in sunk["cells"]:
			var cell_rect := Rect2(cell_top_left(cell), Vector2(size, size)).grow(-4.0)
			draw_rect(cell_rect, ship_color, false, 3.0)


func _draw_centered_text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var position := center - Vector2(text_size.x * 0.5, 0.0)
	draw_string(font, position + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.75))
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
