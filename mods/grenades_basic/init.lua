local function remove_flora(pos, radius)
	local pos1 = vector.subtract(pos, radius)
	local pos2 = vector.add(pos, radius)

	for _, p in ipairs(minetest.find_nodes_in_area(pos1, pos2, "group:flora")) do
		if vector.distance(pos, p) <= radius then
			minetest.remove_node(p)
		end
	end
end

grenades.register_grenade("grenades_basic:frag", {
	description = "Frag grenade (Kills anyone near blast)",
	image = "grenades_frag.png",
	on_explode = function(pos, name)
		if not name or not pos then
			return
		end

		local player = minetest.get_player_by_name(name)

		local radius = 6

		minetest.add_particlespawner({
			amount = 20,
			time = 0.5,
			minpos = vector.subtract(pos, radius),
			maxpos = vector.add(pos, radius),
			minvel = {x = 0, y = 5, z = 0},
			maxvel = {x = 0, y = 7, z = 0},
			minacc = {x = 0, y = 1, z = 0},
			maxacc = {x = 0, y = 1, z = 0},
			minexptime = 0.3,
			maxexptime = 0.6,
			minsize = 7,
			maxsize = 10,
			collisiondetection = true,
			collision_removal = false,
			vertical = false,
			texture = "grenades_smoke.png",
		})

		minetest.add_particle({
			pos = pos,
			velocity = {x=0, y=0, z=0},
			acceleration = {x=0, y=0, z=0},
			expirationtime = 0.3,
			size = 15,
			collisiondetection = false,
			collision_removal = false,
			object_collision = false,
			vertical = false,
			texture = "grenades_boom.png",
			glow = 10
		})

		minetest.sound_play("grenades_explode", {
			pos = pos,
			gain = 1.0,
			max_hear_distance = 64,
		})

		remove_flora(pos, radius/2)

		for _, v in ipairs(minetest.get_objects_inside_radius(pos, radius)) do
			local hit = minetest.raycast(pos, v:get_pos(), true, true):next()

			if hit and v:is_player() and v:get_hp() > 0 and hit.type == "object" and hit.ref:is_player() and
			hit.ref:get_player_name() == v:get_player_name() then
				v:punch(player, 2, {damage_groups = {grenade = 1, fleshy = 90 * 0.707106 ^ vector.distance(pos, v:get_pos())}}, nil)
			end
		end
	end,
})

-- Flashbang Grenade

local flash_huds = {}
local flash_sounds = {}

grenades.register_grenade("grenades_basic:flashbang", {
	description = "Flashbang grenade (Blinds all who look at blast)",
	image = "grenades_flashbang.png",
	clock = 1,
	on_explode = function(pos)
		minetest.sound_play("grenades_glasslike_break", {
			pos = pos,
			gain = 1.0,
			max_hear_distance = 32,
		})
		minetest.sound_play("grenades_explode", {
			pos = pos,
			gain = .2,
			pitch = 3,
			max_hear_distance = 32,
		})
		for _, v in ipairs(minetest.get_objects_inside_radius(pos, 20)) do
			local hit = minetest.raycast(pos, v:get_pos(), true, true):next()

			if hit and v:is_player() and v:get_hp() > 0 and hit.type == "object" and
			hit.ref:is_player() and hit.ref:get_player_name() == v:get_player_name() then
				local playerdir = vector.round(v:get_look_dir())
				local grenadedir = vector.round(vector.direction(v:get_pos(), pos))
				local pname = v:get_player_name()

				if math.acos(playerdir.x*grenadedir.x + playerdir.y*grenadedir.y + playerdir.z*grenadedir.z) <= math.pi/4 or vector.distance(v:get_pos(), pos) < 3 then
					if flash_sounds[pname] then
						minetest.sound_stop(flash_sounds[pname])
						flash_sounds[pname] = nil
					end
					if flash_huds[pname] then
						for id, data in pairs(flash_huds[pname]) do
							minetest.get_player_by_name(pname):hud_remove(data)
						end
					end
					flash_huds[pname] = {}
					flash_sounds[pname] = minetest.sound_play("grenades_tinnitus", {
						player = v,
						gain = 1.0,
					})
					for i = 0, 5, 1 do
						local key = v:hud_add({
							hud_elem_type = "image",
							position = {x = 0, y = 0},
							name = "flashbang hud "..pname,
							scale = {x = -200, y = -200},
							text = "grenades_white.png^[opacity:"..tostring(255 - (i * 20)),
							alignment = {x = 0, y = 0},
							offset = {x = 0, y = 0}
						})

						flash_huds[pname][i+1] = key

						minetest.after(2 * i, function(id)
							if minetest.get_player_by_name(pname) then
								if flash_huds[pname] ~= id then return end
								minetest.get_player_by_name(pname):hud_remove(key)
								if flash_huds[pname] then
									table.remove(flash_huds[pname], 1)
								end

								if i == 5 then
									flash_huds[pname] = nil
								end
							end
						end, flash_huds[pname])
					end
				end

			end
		end
	end,
})

minetest.register_on_dieplayer(function(player)
	local name = player:get_player_name()

	if flash_huds[name] then
		for _, v in ipairs(flash_huds[name]) do
			player:hud_remove(v)
		end

		flash_huds[name] = nil
	end
end)

grenades.register_grenade("grenades_basic:smoke", {
	description = "Smoke grenade (Generates smoke around blast site)",
	image = "grenades_smoke_grenade.png",
	on_explode = function(pos)
		minetest.sound_play("grenades_glasslike_break", {
			pos = pos,
			gain = 1.0,
			max_hear_distance = 32,
		})

		local hiss = minetest.sound_play("grenades_hiss", {
			pos = pos,
			gain = 1.0,
			loop = true,
			max_hear_distance = 32,
		})

		minetest.after(40, minetest.sound_stop, hiss)

		for i = 0, 5, 1 do
			minetest.add_particlespawner({
				amount = 40,
				time = 45,
				minpos = vector.subtract(pos, 2),
				maxpos = vector.add(pos, 2),
				minvel = {x = 0, y = 2, z = 0},
				maxvel = {x = 0, y = 3, z = 0},
				minacc = {x = 1, y = 0.2, z = 1},
				maxacc = {x = 1, y = 0.2, z = 1},
				minexptime = 1,
				maxexptime = 1,
				minsize = 125,
				maxsize = 140,
				collisiondetection = false,
				collision_removal = false,
				vertical = false,
				texture = "grenades_smoke.png",
			})
		end
	end,
	particle = {
		image = "grenades_smoke.png",
		life = 1,
		size = 4,
		glow = 0,
		interval = 5,
	}
})

dofile(minetest.get_modpath("grenades_basic").."/crafts.lua")