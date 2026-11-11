extends RefCounted


static func place_fleet(allowed_cells: Array, ship_lengths: Array, rng: RandomNumberGenerator) -> Array:
	var allowed: Dictionary = {}
	for cell in allowed_cells:
		allowed[cell] = true

	for attempt in 400:
		var occupied: Dictionary = {}
		var ships: Array = []
		var ok := true

		for length_value in ship_lengths:
			var length := int(length_value)
			var options: Array = []
			for cell in allowed_cells:
				for direction in [Vector2i(1, 0), Vector2i(0, 1)]:
					var ship_cells: Array = []
					var valid := true
					for index in length:
						var candidate: Vector2i = cell + direction * index
						if not allowed.has(candidate) or occupied.has(candidate):
							valid = false
							break
						ship_cells.append(candidate)
					if valid:
						options.append(ship_cells)

			if options.is_empty():
				ok = false
				break

			var chosen: Array = options[rng.randi_range(0, options.size() - 1)]
			for cell in chosen:
				occupied[cell] = true
			ships.append(chosen)

		if ok:
			return ships

	return []
