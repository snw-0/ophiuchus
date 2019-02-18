local PhysicsSystem = tiny.processingSystem(class "PhysicsSystem")

PhysicsSystem.filter = tiny.requireAll("pos", "vel")

local dx_goal, dy_goal
local hit_x, hit_y, hit_time, nx, ny, other_pos
COARSE_GRID_SIZE = 64
local other_pos_coarse = {half_h = COARSE_GRID_SIZE, half_w = COARSE_GRID_SIZE}
local hit_list = {}
local already_applied_hits = {}
local already_applied = false

function PhysicsSystem:preProcess(dt)
	already_applied_hits = {}
end

function PhysicsSystem:process(e, dt)
	if e.controls and e.walker then
		dx_goal = e.controls.move_x
		dy_goal = e.controls.move_y

		if (e.collides and e.collides.map) and (math.abs(dx_goal) + math.abs(dy_goal) == 1) then
			-- alter the controls based on adjacent walls
			-- test one pixel in the relevant direction
			hit_list = {}
			collision.map_collision_aabb_sweep(e.pos, dx_goal, dy_goal, hit_list)
			-- sort by impact time
			table.sort(hit_list, function(hit_1, hit_2) return hit_1.time < hit_2.time end)

			if #hit_list >= 1 and hit_list[1].object.kind == "wall" then
				if dx_goal == 0 then
					if dy_goal == 1 and hit_list[1].ny < -0.01 then
						-- south
						dx_goal = mymath.sign(hit_list[1].nx)
					elseif dy_goal == -1 and hit_list[1].ny > 0.01 then
						-- north
						dx_goal = mymath.sign(hit_list[1].nx)
					end
				elseif dx_goal == 1 and dy_goal == 0 and hit_list[1].nx < -0.01 then
					-- east
					dy_goal = mymath.sign(hit_list[1].ny)
				elseif dy_goal == 0 and hit_list[1].nx > 0.01 then -- dx_goal == -1 here
					-- west
					dy_goal = mymath.sign(hit_list[1].ny)
				end
			end
		end

		dx_goal = dx_goal * e.walker.top_speed
		dy_goal = dy_goal * e.walker.top_speed

		-- xxx use abs_subtract?
		if e.vel.dx >= dx_goal then
			e.vel.dx = math.max(dx_goal, e.vel.dx - e.walker.accel)
		else
			e.vel.dx = math.min(dx_goal, e.vel.dx + e.walker.accel)
		end

		if e.vel.dy >= dy_goal then
			e.vel.dy = math.max(dy_goal, e.vel.dy - e.walker.accel)
		else
			e.vel.dy = math.min(dy_goal, e.vel.dy + e.walker.accel)
		end
	end

	-- calculate how far to move this frame
	-- cut off the fractional part; we'll re-add it next frame
	e.vel.dx_acc = e.vel.dx_acc + e.vel.dx
	e.vel.dy_acc = e.vel.dy_acc + e.vel.dy
	idx, idy = mymath.abs_floor(e.vel.dx_acc), mymath.abs_floor(e.vel.dy_acc)
	e.vel.dx_acc = e.vel.dx_acc - idx
	e.vel.dy_acc = e.vel.dy_acc - idy

	if e.collides then
		PhysicsSystem:move_with_collision(e, idx, idy, self.entities, 0, dt)
	else
		e.pos.x = e.pos.x + idx
		e.pos.y = e.pos.y + idy
	end
end

function PhysicsSystem:move_with_collision(e, idx, idy, entity_list, tries, dt)
	if tries > 5 then
		error()
	end

	hit_list = {}

	if e.collides.map then
		-- get map hits
		collision.map_collision_aabb_sweep(e.pos, idx, idy, hit_list)
	end

	if e.collides.entity_filter then
		for _, other_e in pairs(entity_list) do
			if other_e.collides and e.collides.entity_filter(other_e) then
				other_pos_coarse.x, other_pos_coarse.y = other_e.pos.x, other_e.pos.y
				-- first check if we're anywhere near it, then actually do the sweep. XXX useful or not?
				if collision.collision_aabb_aabb(e.pos, other_pos_coarse) then
					hit = collision.collision_aabb_sweep(e.pos, other_e.pos, idx, idy)
					if hit then
						hit.object = {kind = "entity", entity = other_e}
						hit_list[#hit_list + 1] = hit
					end
				end
			end
		end
	end

	if #hit_list == 0 then
		-- didn't hit anything; just fly free, man
		e.pos.x = e.pos.x + idx
		e.pos.y = e.pos.y + idy
	else
		-- sort by impact time
		table.sort(hit_list, function(hit_1, hit_2) return hit_1.time < hit_2.time end)
		local reaction = "pass"

		for _, v in ipairs(hit_list) do
			hit = v
			if hit.object.kind == "entity" then
				already_applied = false
				for i,v in ipairs(already_applied_hits) do
					if v[1] == hit.object.entity.id and v[2] == e.id then
						-- we already did this one
						already_applied = true
						break
					end
				end

				reaction = e.collides.collide_with_entity(hit, already_applied)
				if not already_applied then
					table.insert(already_applied_hits, {e.id, hit.object.entity.id})
					hit.object.entity.collides.get_collided_with(e, hit)
				end
			else
				reaction = e.collides.collide_with_map(hit)
			end

			if reaction ~= "pass" then
				-- we hit something solid, so ignore later collisions
				e.pos.x = hit.x
				e.pos.y = hit.y
				break
			end
		end

		if reaction == "pass" then
			-- we passed through everything
			e.pos.x = e.pos.x + idx
			e.pos.y = e.pos.y + idy
		elseif reaction == "stick" then
			-- stop dead
			e.vel.dx = 0
			e.vel.dy = 0
			e.vel.dx_acc = 0
			e.vel.dy_acc = 0
		elseif reaction == "slide" then
			-- slide along the surface we hit
			local dot = e.vel.dx * hit.ny - e.vel.dy * hit.nx

			e.vel.dx = dot * hit.ny
			e.vel.dy = dot * (-hit.nx)

			dot = e.vel.dx_acc * hit.ny - e.vel.dy_acc * hit.nx

			e.vel.dx_acc = dot * hit.ny
			e.vel.dy_acc = dot * (-hit.nx)

			if hit.time < 1 then
				-- try continuing our movement along the new vector
				e.vel.dx_acc = e.vel.dx_acc + e.vel.dx * (1 - hit.time)
				e.vel.dy_acc = e.vel.dy_acc + e.vel.dy * (1 - hit.time)
				idx, idy = mymath.abs_floor(e.vel.dx_acc), mymath.abs_floor(e.vel.dy_acc)
				e.vel.dx_acc = e.vel.dx_acc - idx
				e.vel.dy_acc = e.vel.dy_acc - idy

				PhysicsSystem:move_with_collision(e, idx, idy, entity_list, tries + 1, dt)
			end
		elseif reaction == "bounce" then
			local dot = e.vel.dy * hit.ny + e.vel.dx * hit.nx

			e.vel.dx = (e.vel.dx - 2 * dot * hit.nx) -- * self.bounce_restitution
			e.vel.dy = (e.vel.dy - 2 * dot * hit.ny) -- * self.bounce_restitution

			if hit.time < 1 then
				-- try continuing our movement along the new vector
				e.vel.dx_acc = e.vel.dx * (1 - hit.time)
				e.vel.dy_acc = e.vel.dy * (1 - hit.time)
				idx, idy = mymath.abs_floor(e.vel.dx_acc), mymath.abs_floor(e.vel.dy_acc)
				e.vel.dx_acc = e.vel.dx_acc - idx
				e.vel.dy_acc = e.vel.dy_acc - idy

				PhysicsSystem:move_with_collision(e, idx, idy, entity_list, tries + 1, dt)
			else
				e.vel.dx_acc = 0
				e.vel.dy_acc = 0
			end
		elseif reaction == "vanish" then
			tiny.removeEntity(world, e)
		-- elseif reaction == "end" then
			-- do nothing
		end
		-- if m_hit[1] == "block" and mainmap:block_at(m_hit[2], m_hit[3]) == "void" then
		-- 	-- oob
		-- 	movement.collision_responses.vanish(k)
		-- elseif e.vel.collision_response then
		-- 	-- react to the collision
		-- 	idx, idy = mymath.normalize(idx, idy)
		-- 	movement.collision_responses[e.vel.collision_response](k, mov, m_hit, m_hit_x, m_hit_y, idx, idy, m_nx, m_ny)
		-- end
	end
end

return PhysicsSystem
