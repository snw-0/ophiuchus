local ecs = {}

function ecs.spawn_shot(kind, start_x, start_y, dx, dy)
	id = idcounter.get_id("entity")
	c_identities[id] =	{name = "Pellet", birth_frame = gamestate.game_frame}
	c_positions[id] =	{x = start_x, y = start_y, half_w = 1, half_h = 1}
	c_movements[id] =
	{
		kind = "projectile", dx = dx, dy = dy, dx_acc = 0, dy_acc = 0,
		projectile_data =
		{
			collides_with_map = true, collides_with_hitboxes = true,
			collision_responses =
			{
				wall = "explode_small",
				void = "vanish",
				enemy = "explode_small"
			},
			attack =
			{
				damage = 5,
				push = 1.5
			},
		},
	}
	c_drawables[id] =	{sprite = "bullet_23", color = color.rouge,
						 flash_color = color.white, flash_end_frame = 0,}
end

function ecs.spawn_slash(kind, start_x, start_y, dx, dy, duration)
	id = idcounter.get_id("entity")
	c_identities[id] =	{name = "Slash", birth_frame = gamestate.game_frame}
	c_positions[id] =	{x = start_x, y = start_y, half_w = 6, half_h = 6}
	c_movements[id] =
	{
		kind = "projectile", dx = dx, dy = dy, dx_acc = 0, dy_acc = 0,
		projectile_data =
		{
			collides_with_map = true, collides_with_hitboxes = true,
			collision_responses =
			{
				wall = "vanish",
				void = "vanish",
				enemy = "slice"
			},
			attack =
			{
				damage = 1,
				kb = 8
			},
		},
	}
	-- c_drawables[id] =	{sprite = "bullet_23", color = color.white,
	-- 					 flash_color = color.white, flash_end_frame = 0,}
	c_timeouts[id] =	gamestate.game_frame + duration
end

function ecs.spawn_particle(kind, color, start_x, start_y, dx, dy, duration)
	id = idcounter.get_id("entity")
	c_identities[id] =	{name = "Spark", birth_frame = gamestate.game_frame}
	c_positions[id] =	{x = start_x, y = start_y, half_w = 1, half_h = 1}
	c_movements[id] =
	{
		kind = "projectile", dx = dx, dy = dy, dx_acc = 0, dy_acc = 0,
		projectile_data = {},
	}
	c_drawables[id] =	{sprite = "bullet_23", color = color,
						 flash_color = color.white, flash_end_frame = 0,}
	c_timeouts[id] =	gamestate.game_frame + duration
end

function ecs.spawn_enemy()
	-- find a spot
	local found, start_x, start_y = false, nil, nil
	while not found do
		start_x = love.math.random(1, mainmap.width * TILE_SIZE)
		start_y = love.math.random(1, mainmap.height * TILE_SIZE)
		found = not physics.map_collision_aabb({x = start_x, y = start_y, half_w = 3, half_h = 3})
	end
	id = idcounter.get_id("entity")
	c_identities[id] =	{name = "Mook", birth_frame = gamestate.game_frame}
	c_positions[id] =	{x = start_x, y = start_y, half_w = 3, half_h = 3}
	c_hitboxes[id] =	{alignment = "enemy"}
	c_controls[id] =	{
		ai = "mook",
		move_x = 0, move_y = 0,
		aim_x = 0, aim_y = 0,
		fire_pressed = false, fire_down = false,
		altfire_pressed = false, altfire_down = false,
		wake_frame = 0,
	}
	c_movements[id] =
	{
		kind = "walker", dx = 0, dy = 0, dx_acc = 0, dy_acc = 0,
		walker_data =
		{
			top_speed = 1, accel = 0.1,
		},
		knockback_data =
		{
			decel = 0.1,
		},
		projectile_data =
		{
			collides_with_map = true, collides_with_hitboxes = true,
			collision_responses =
			{
				wall = "bounce",
				void = "bounce",
				enemy = "slow"
			},
			attack =
			{
				damage = 0,
				kb_factor = 0.7,
			},
		},
	}
	c_drawables[id] =	{sprite = "player", color = color.ltblue,
						 flash_color = color.white, flash_end_frame = 0,}
	c_mortals[id] = {hp = 30, immunities = {}}
	if mymath.one_chance_in(10) then
		c_hitboxes[id].alignment = "friend"
		c_drawables[id].color = color.yellow
	end
end

return ecs
