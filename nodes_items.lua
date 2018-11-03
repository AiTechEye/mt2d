minetest.register_node("mt2d:blocking", {
	description = "blocking",
	drawtype="airlike",
	pointable=false,
	mt2d=true,
	groups={blockingsky=1},
	after_destruct = function(pos, oldnode)
		local m=minetest.get_meta(pos)
		if m:get_int("reset")==0 then
			minetest.after(1, function(pos)
				minetest.set_node(pos,{name="mt2d:blocking"})
				m:set_int("reset",1)
				minetest.get_node_timer(pos):start(1)
			end,pos)
		end
	end,
	on_timer = function (pos, elapsed)
		minetest.get_meta(pos):set_int("reset",0)
	end,
})

minetest.register_lbm({
	name = "mt2d:blockingfix",
	nodenames = {"mt2d:blocking"},
	--run_at_every_load=true,
	action = function(pos, node)
		for x=-1,1,2 do
		for y=-1,1,2 do
			local p={x=pos.x+x,y=pos.y+y,z=pos.z}
			if minetest.get_node(p).name~="mt2d:blocking" then
				minetest.set_node(p, node)
			end
		end
		end
	end,
})

minetest.register_node("mt2d:blocking_stone", {
	description = "blocking stone",
	mt2d=true,
	groups={blockingsky=1},
	tiles={"default_stone.png^[colorize:#00000055"},
	drawtype = "liquid",
	liquidtype = "source",
	liquid_range = 0,
	liquid_alternative_flowing = "mt2d:blocking_stone",
	liquid_alternative_source = "mt2d:blocking_stone",
	on_blast = function(pos, intensity)
		minetest.registered_nodes["mt2d:blocking_stone"].after_destruct(pos)
	end,
	after_destruct = function(pos, oldnode)
		local m=minetest.get_meta(pos)
		if m:get_int("reset")==0 then
			minetest.after(1, function(pos)
				minetest.set_node(pos,{name="mt2d:blocking_stone"})
				m:set_int("reset",1)
				minetest.get_node_timer(pos):start(1)
			end,pos)
		end
	end,
	on_timer = function (pos, elapsed)
		minetest.get_meta(pos):set_int("reset",0)
	end,
})

minetest.register_node("mt2d:blocking_sky", {
	description = "blocking sky",
	mt2d=true,
	groups={blockingsky=1},
	tiles={"default_cloud.png^[colorize:#9ee7ffff"},
	drawtype = "liquid",
	liquidtype = "source",
	liquid_range = 0,
	liquid_alternative_flowing = "mt2d:blocking_sky",
	liquid_alternative_source = "mt2d:blocking_sky",
	on_blast = function(pos, intensity)
		minetest.registered_nodes["mt2d:blocking_sky"].after_destruct(pos)
	end,
	after_destruct = function(pos, oldnode)
		local m=minetest.get_meta(pos)
		if m:get_int("reset")==0 then
			minetest.after(1, function(pos)
				minetest.set_node(pos,{name="mt2d:blocking_sky"})
				m:set_int("reset",1)
				minetest.get_node_timer(pos):start(1)
			end,pos)
		end
	end,
	on_timer = function (pos, elapsed)
		minetest.get_meta(pos):set_int("reset",0)
	end,
})

mt2d.registry_door=function(name,description,texture,groups,locked,sound_open,sound_close,sounds,replace)

minetest.register_node("mt2d:door_" .. name .. "_a",{
	description = description,
	groups = groups,
	drawtype="nodebox",
	paramtype="light",
	paramtype2 = "facedir",
	tiles = {texture},
	drop=replace,
	sounds=sounds,
	mt2d=true,
	node_box = {
		type="fixed",
		fixed={0.4,-0.5,0,0.5,1.5,0}
	},
	selection_box={
		type="fixed",
		fixed={-0.5,-0.5,0,0.5,1.5,0}
	},
	collision_box={
		type="fixed",
		fixed={0.4,-0.5,-0.5,0.5,1.5,0.5}
	},
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		local meta=minetest.get_meta(pos)
		local owner=meta:get_string("owner")
		if owner~="" and owner~=player:get_player_name() then
			return
		end
		minetest.swap_node(pos, {name="mt2d:door_" .. name .. "_b"})
		meta:set_int("p",meta:get_int("p"))
		meta:set_string("owner",owner)
		minetest.sound_play(sound_open,{pos=pos,gain=0.3,max_hear_distance=10})
	end,
	after_place_node = function(pos, placer)
		local pname=placer:get_player_name()
		local ob=mt2d.user[pname]
		local meta=minetest.get_meta(pos)

		if locked then
			meta:set_string("owner",pname)
		end

		if ob and ob.object and ob.object:get_pos().x<pos.x then
			minetest.swap_node(pos, {name="mt2d:door_" .. name .. "_a", param2=0})
		else
			minetest.swap_node(pos, {name="mt2d:door_" .. name .. "_a", param2=2})
			meta:set_int("p",2)
		end
	end,
})

minetest.register_node("mt2d:door_" .. name .. "_b",{
	description = description,
	drop=replace,
	groups = groups,
	drawtype="nodebox",
	paramtype="light",
	paramtype2 = "facedir",
	tiles = {texture},
	sounds=sounds,
	mt2d=true,
	walkable=false,
	node_box = {
		type="fixed",
		fixed={-0.5,-0.5,-0.1,0.5,1.5,-0.1}
	},
	on_rightclick = function(pos,node,player)
		local meta=minetest.get_meta(pos)
		local owner=meta:get_string("owner")
		if owner~="" and owner~=player:get_player_name() then
			return
		end
		minetest.swap_node(pos, {name="mt2d:door_" .. name .. "_a",param2=meta:get_int("p")})
		meta:set_int("p",meta:get_int("p"))
		meta:set_string("owner",owner)
		minetest.sound_play(sound_close,{pos=pos,gain=0.3,max_hear_distance=10})
	end
})

	minetest.after(0.1, function(name,replace)
		minetest.registered_items[replace].on_place=function(itemstack, user, pointed_thing)

			if not pointed_thing.above or pointed_thing.above.z~=0 then
				return itemstack
			end

			local pos=pointed_thing.above
			pointed_thing.above={x=pos.x,y=pos.y,z=0}

			local def=minetest.registered_nodes[minetest.get_node(pointed_thing.above).name]

			if minetest.is_protected(pointed_thing.above,user:get_player_name()) or not def or def.buildable_to==false or minetest.get_node({x=pos.x,y=pos.y+1,z=0}).name~="air" then
				return itemstack
			else
				itemstack:take_item()
			end
			minetest.registered_items["mt2d:door_" .. name .. "_a"].after_place_node(pointed_thing.above,user)
			return itemstack
		end
	end,name,replace)


end

mt2d.registry_door(
	"wood",
	"Wooden door",
	"default_wood.png",
	{choppy = 2, oddly_breakable_by_hand = 2,not_in_creative_inventory=1},
	false,
	"doors_door_open",
	"doors_door_close",
	default.node_sound_wood_defaults(),
	"doors:door_wood"
)

mt2d.registry_door(
	"glass",
	"Glass door",
	"default_glass.png",
	{ckracky=2, oddly_breakable_by_hand = 2,not_in_creative_inventory=1},
	false,
	"doors_glass_door_open",
	"doors_glass_door_close",
	default.node_sound_glass_defaults(),
	"doors:door_glass"
)

mt2d.registry_door(
	"steel",
	"Steel door",
	"default_steel_block.png",
	{cracky=1,not_in_creative_inventory=1},
	true,
	"doors_steel_door_open",
	"doors_steel_door_close",
	default.node_sound_metal_defaults(),
	"doors:door_steel"
)

mt2d.registry_door(
	"obsidian_glass",
	"Obsidian glass door",
	"default_obsidian_glass.png",
	{cracky= 1,not_in_creative_inventory=1},
	false,
	"doors_glass_door_open",
	"doors_glass_door_close",
	default.node_sound_glass_defaults(),
	"doors:door_obsidian_glass"
)

for i, t in pairs({{"bed","Bed"},{"fancy_bed","Fancy bed"}}) do
minetest.register_node("mt2d:" .. t[1],{
	description = t[1],
	groups = {choppy = 2, oddly_breakable_by_hand = 2,not_in_creative_inventory=1},
	drawtype="nodebox",
	paramtype="light",
	tiles = {"mt2d_" .. t[1] ..".png"},
	sounds=default.node_sound_wood_defaults(),
	mt2d=true,
	walkable=false,
	node_box = {
		type="fixed",
		fixed={-0.5,-0.5,0,1.5,0.25,0}
	},
	on_rightclick = function(pos,node,player)
		local name=player:get_player_name()
		if not mt2d.user[name] and mt2d.user[name].object then
			return
		end
		mt2d.user[name].object:set_pos({x=pos.x+0.5,y=pos.y+1.2,z=0})
		mt2d.user[name].cam:get_luaentity().laying=true
		minetest.get_node_timer(pos):start(10)
	end,
	on_timer = function (pos, elapsed)
		local time=minetest.get_timeofday()
		local time_is=time<0.2 or time>0.8
		local lay

		for _, ob in ipairs(minetest.get_objects_inside_radius(pos, 2)) do
			local en=ob:get_luaentity()
			if en and en.username and mt2d.user[en.username] and mt2d.user[en.username].cam and mt2d.user[en.username].cam:get_luaentity().laying then
				lay=true
				break
			end
		end

		if not lay then
			return false
		elseif not time_is then
			return true
		end

		for i, u in pairs(mt2d.user) do
			if u.cam and u.cam:get_luaentity() then
				if not u.cam:get_luaentity().laying then
					return true
				end
			end
		end
		minetest.set_timeofday(0.23)
		for i, u in pairs(mt2d.user) do
			if u.cam and u.cam:get_luaentity() and u.cam:get_luaentity().laying then
				u.cam:get_luaentity().wakeup=true
			end
		end
	end
})
	minetest.after(0.1, function()
		minetest.registered_nodes["beds:" .. t[1]].on_place=function(itemstack, user, pointed_thing)
			local pos=pointed_thing.above
			if not pos or minetest.get_node({x=pos.x-1,y=pos.y,z=0}).name~="air" then return false end
			minetest.set_node(pos,{name="mt2d:" .. t[1]})
		end
	end)
end