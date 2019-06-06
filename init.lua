mt2d={
	timer=0,
	user3d={},	--3d users
	user={},		--users data
	attach={},	--attached objects (pushing them)
	playeranim={
		stand={x=1,y=39,speed=30},
		walk={x=41,y=61,speed=30},
		mine={x=65,y=75,speed=30},
		hugwalk={x=80,y=99,speed=30},
		lay={x=113,y=123,speed=0},
		sit={x=101,y=111,speed=0},
	},
}

dofile(minetest.get_modpath("mt2d") .. "/nodes_items.lua")
dofile(minetest.get_modpath("mt2d") .. "/entities.lua")

minetest.register_privilege("leave2d", {
	description = "Leave Dimension",
	give_to_singleplayer= false,
})
minetest.register_on_mods_loaded(function()
--minetest.after(0.1, function()
	minetest.registered_entities["__builtin:item"].on_activate2=minetest.registered_entities["__builtin:item"].on_activate
	minetest.registered_entities["__builtin:item"].on_activate=function(self, staticdata,time)
		minetest.registered_entities["__builtin:item"].on_activate2(self, staticdata,time)
			minetest.after(0, function(self)
				if self and self.object then
					self.object:set_properties({
						automatic_rotate=0,
						collisionbox={-0.2,-0.2,0,0.2,0.2,0},
					})
					local pos=self.object:get_pos()
					self.object:set_pos({x=pos.x,y=pos.y,z=0})
				end
			end,self)
		return self
	end
	for i, v in pairs(minetest.registered_items) do
		if not v.range or v.range<8 then
			minetest.override_item(i, {range=8})
		end
	end
	for i, v in pairs(minetest.registered_nodes) do
		if v.drawtype~="airlike" and not v.mt2d and v.tiles then

			local inventory_image=v.inventory_image
			local walkable=v.walkable
			local tiles=v.tiles

			if string.find(v.name,"fence") and tiles[1] then
				inventory_image="mt2d_fence.png^" .. tiles[1] .. "^mt2d_fence.png^[makealpha:0,255,0"
				tiles[1]=inventory_image
				walkable=false
			end

			if #tiles==6 then
				tiles={
					tiles[1],
					tiles[2],
					tiles[3],
					tiles[4],
					tiles[6],
					tiles[5],
				}
				if inventory_image=="" then
					inventory_image=tiles[5]
				end
			end
			if inventory_image=="" then
				if tiles[1] and tiles[1].name and tiles[1].animation then
					tiles = nil
				elseif tiles[1] and type(tiles[1].name)=="string" then
					inventory_image=tiles[1].name

				elseif tiles[3] and type(tiles[3].name)=="string" then
					inventory_image=tiles[3].name

					if minetest.get_item_group(v.name,"soil") > 0 then
						tiles={inventory_image}
					end
				elseif type(tiles[#tiles])=="string" then
					inventory_image=tiles[#tiles]
				end
			end

			minetest.override_item(i, {
				tiles=tiles,
				walkable=walkable,
				inventory_image=inventory_image,
				paramtype="light",
				paramtype2="none",
				drawtype="nodebox",
				node_box = {
					type = "fixed",
					fixed = {{-0.5, -0.5, 0, 0.5, 0.5, 0}},
				},
				selection_box = {
					type = "fixed",
					fixed = {{-0.5, -0.5, -0.5, 0.5, 0.5, 0}},
				},
				collision_box = {
					type = "fixed",
					fixed = {{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}},
				},
			})
		end
	end
	if sethome then
	sethome.go=function(name)
		local pos=sethome.get(name)
		if pos and mt2d.user[name] then
			pos.z=0
			pos.y=pos.y+1
			mt2d.user[name].object:set_pos(pos)
			mt2d.user[name].cam:set_pos(pos)
			return true
		elseif not pos then
			return false
		else
			minetest.chat_send_player(name,"You can't go home in 3D mode")
			return true
		end
	end
	end
end)

mt2d.new_player=function(player)
	local pos=player:get_pos()
	pos={x=pos.x,y=pos.y,z=0}
	for i=0,100,1 do
		local n=minetest.registered_nodes[minetest.get_node({x=pos.x, y=pos.y+i, z=0}).name]
		if n and not n.walkable then
			pos.y=pos.y+i
			break
		end
	end
	player:set_pos(pos)
	local id=math.random(1,9999)
	local cam=minetest.add_entity({x=pos.x,y=pos.y,z=pos.z+5}, "mt2d:cam")
	cam:get_luaentity().user=player
	cam:get_luaentity().username=player:get_player_name()
	cam:get_luaentity().id=id
	mt2d.user[player:get_player_name()]={id=id,cam=cam,texture="character.png"}
	player:set_attach(cam, "",{x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
	player:hud_set_flags({wielditem=false})
	player:set_nametag_attributes({color={a=0,r=255,g=255,b=255}})
	player:set_properties({textures={"mt2d_air.png"}})
end
	
mt2d.to_3dplayer=function(player)
	local name=player:get_player_name()
	if mt2d.user3d[name] then
		return
	end

	player:set_nametag_attributes({color={a=255,r=255,g=255,b=255}})
	player:set_properties({textures={mt2d.user[name].texture}})
	player:hud_set_flags({wielditem=true})
	player:set_detach()
	mt2d.user[name]=nil
	mt2d.user3d[name]={timeout=false,player=player}
end

minetest.register_globalstep(function(dtime)
	for name, a in pairs(mt2d.attach) do
		if not (mt2d.user[name] or mt2d.user[name].id==a.id) or not (a.ob1:get_pos() and a.ob2:get_pos()) then
			minetest.after(0, function(name)
				mt2d.attach[name]=nil
			end,name)
			break
		end

		local pos1=a.ob1:get_pos()
		local pos2=a.ob2:get_pos()
		a.ob2:set_velocity({x=((pos1.x-pos2.x)+a.pos.x)*10,y=((pos1.y-pos2.y)+a.pos.y)*10,z=((pos1.z-pos2.z)+a.pos.z)*10})


		local user

		if a.ob1:get_luaentity() and a.ob1:get_luaentity().user then
			user=a.ob1:get_luaentity().user
		elseif a.ob2:get_luaentity() and a.ob2:get_luaentity().user then
			user=a.ob2:get_luaentity().user
		elseif a.ob1:is_player() then
			user=a.ob1
		elseif a.ob2:is_player() then
			user=a.ob2
		end

		if user then
			local yaw=user:get_look_yaw()
			local pitch=user:get_look_pitch()
			local tyaw=math.abs(yaw-4.71)
			local tpitch=math.abs(pitch)
			local npointable=not mt2d.pointable(pos2,user)
			if tyaw>0.5 or (npointable and tyaw>0.2) then
				user:set_look_yaw(3.14+((yaw-4.71)*0.99))
			elseif tpitch>0.5 or (npointable and tpitch>0.2) then
				user:set_look_pitch((pitch*0.99)*-1)
			end
		end
	end

	mt2d.timer=mt2d.timer+dtime
	if mt2d.timer<2 then return end
	mt2d.timer=0
	for name, u in pairs(mt2d.user3d) do
		if u.player:get_player_control().aux1 then
			mt2d.new_player(u.player)
			mt2d.user3d[name].timeout=true
			minetest.after(2, function(name)
				mt2d.user3d[name]=nil
			end,name)
		end
	end
end)

minetest.register_on_joinplayer(function(player)
	local pos=player:get_pos()
	player:set_pos({x=pos.x,y=pos.y,z=0})
	minetest.after(2, function(player)
		mt2d.new_player(player)
	end,player)
end)

minetest.register_on_respawnplayer(function(player)
	minetest.after(0, function(player)
		local pos=player:get_pos()
		player:set_pos({x=pos.x,y=pos.y,z=5})
	end,player)
	minetest.after(1, function(player)
		mt2d.new_player(player)
	end,player)
end)

minetest.register_on_dieplayer(function(player)
	player:set_detach()
	minetest.after(0.1, function(player)
		local bones_pos=minetest.find_node_near(player:get_pos(), 2, {"bones:bones"})
		if bones_pos then
			local bones=minetest.get_node(bones_pos)
			local name=player:get_player_name()
			for i, replace_pos in pairs(mt2d.get_nodes_radius(bones_pos,15)) do
				local replace=minetest.get_node(replace_pos).name
				if (minetest.registered_nodes[replace] and minetest.registered_nodes[replace].buildable_to) then
					minetest.set_node(replace_pos,bones)
					minetest.get_meta(replace_pos):from_table(minetest.get_meta(bones_pos):to_table())
					minetest.set_node(bones_pos,{name="air"})
					return
				end
			end
			local replace_pos={x=bones_pos.x,y=bones_pos.y,z=0}
			local replace=minetest.get_node(replace_pos).name

			if minetest.is_protected(replace_pos, name)==false and
			(minetest.get_item_group(replace,"stone")>0
			or minetest.get_item_group(replace,"soil")>0
			or minetest.get_item_group(replace,"sand")>0) then
				minetest.set_node(replace_pos,bones)
				minetest.get_meta(replace_pos):from_table(minetest.get_meta(bones_pos):to_table())
				minetest.get_meta(replace_pos):get_inventory():add_item("main",{name=replace})
				minetest.set_node(bones_pos,{name="air"})
				return
			end

		end
	end,player)
end)

minetest.register_on_leaveplayer(function(player)
	player:set_detach()
	mt2d.user[player:get_player_name()]=nil
	mt2d.user3d[player:get_player_name()]=nil
end)

mt2d.pointable=function(p1,user)
	local dir=user:get_look_dir()
	local p2=user:get_pos()
	p2={x=p2.x+(dir.x*5),y=p2.y+1.6+(dir.y*5),z=p2.z+(dir.z*5)}
	p1.y=p1.y+0.6
	local v = {x = p1.x - p2.x, y = p1.y - p2.y, z = p1.z - p2.z}
	local amount = (v.x ^ 2 + v.y ^ 2 + v.z ^ 2) ^ 0.5
	local d=math.sqrt((p1.x-p2.x)*(p1.x-p2.x) + (p1.y-p2.y)*(p1.y-p2.y) + (p1.z-p2.z)*(p1.z-p2.z))
	v.x = (v.x  / amount)*-1
	v.y = (v.y  / amount)*-1
	v.z = (v.z  / amount)*-1
	local hit
	for i=1,d,0.5 do
		local node=minetest.get_node({x=p1.x+(v.x*i),y=p1.y+(v.y*i),z=p1.z+(v.z*i)})
		if hit and minetest.registered_nodes[node.name] and minetest.registered_nodes[node.name].walkable then
			return false
		end
		hit=true
	end
	return true
end

mt2d.player_anim=function(self,typ)
	if typ==self.anim then
		return
	end
	self.anim=typ
	self.ob:set_animation({x=mt2d.playeranim[typ].x, y=mt2d.playeranim[typ].y, },mt2d.playeranim[typ].speed,0)

	if self.user and self.user:get_wielded_item()~=self.wielditem then
		self.wielditem=self.user:get_wielded_item():get_name()
		local t="mt2d_air.png"

		local def1=minetest.registered_items[self.wielditem]

		if def1 and def1.inventory_image and def1.inventory_image~="" then
			t=def1.inventory_image
		elseif def1 and def1.tiles and type(def1.tiles[1])=="string" then
			t=def1.tiles[1]
		end
		self.ob:set_properties({textures={t,mt2d.user[self.username].texture}})
	end
	return self
end

minetest.register_on_generated(function(minp, maxp, seed)
	local air=minetest.get_content_id("air")
	local blocking=minetest.get_content_id("mt2d:blocking")
	local sky=minetest.get_content_id("mt2d:blocking_sky")
	local stone=minetest.get_content_id("mt2d:blocking_stone")
	local vox = minetest.get_voxel_manip()
	local min, max = vox:read_from_map(minp, maxp)
	local area = VoxelArea:new({MinEdge = min, MaxEdge = max})
	local data = vox:get_data()
	for z = minp.z, maxp.z do
	for y = minp.y, maxp.y do
	for x = minp.x, maxp.x do
		if z==-1 and y>0 then
			data[area:index(x,y,z)]=sky
		elseif z==-1 and y<1 then
			data[area:index(x,y,z)]=stone
		elseif z==1 or z==5 then
			data[area:index(x,y,z)]=blocking
		elseif z~=0 then
			data[area:index(x,y,z)]=air

		end
	end
	end
	end
	vox:set_data(data)
	vox:write_to_map()
	vox:update_map()
	vox:update_liquids()
end)

mt2d.punch=function(ob1,ob2,hp)
	if not (ob1 and ob2) then
		return
	end
	hp=hp or 1
	if ob1:is_player() then
		ob1:set_hp(ob1:get_hp()-hp)
	else
		ob1:punch(ob2,1,{full_punch_interval=1,damage_groups={fleshy=hp}})
	end	
end

minetest.spawn_item=function(pos, item)
	local e=minetest.add_entity(pos, "__builtin:item")
	if e then
		e:get_luaentity():set_item(ItemStack(item):to_string())
		minetest.after(0, function(e)
			local self=e:get_luaentity()
			if self and self.dropped_by and mt2d.user[self.dropped_by] then
				local ob=mt2d.user[self.dropped_by].object
				local yaw=math.floor(ob:get_yaw()*10)*0.1
				local v={x=0,y=0,z=0}
				local p=ob:get_pos()

				if yaw==4.7 then
					v.x=2
				elseif yaw==1.5 then
					v.x=-2
				else
					v.x=0
				end

				e:set_pos({x=pos.x+(v.x/2),y=pos.y-0.5,z=0})
				e:set_velocity({x=v.x,y=0,z=0})

			end
		end,e)

		minetest.after(10, function(e)
			if e and e:get_luaentity() then
				local node=minetest.registered_nodes[minetest.get_node(e:get_pos()).name]
				if node and node.damage_per_second>0 then
					e:remove()
				end
			end
		end,e)
	end
	return e
end

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
	local ppos=placer:get_pos()

	if pos.x==math.floor(ppos.x+0.5) and (pos.y==math.floor(ppos.y) or pos.y==math.floor(ppos.y+1)) then
		minetest.set_node(pos,oldnode)
		return true
	end
	for x=-1,1,1 do
	for y=-1,1,1 do
		if x+y~=0 and minetest.get_node({x=pos.x+x,y=pos.y+y,z=0}).name~="air" then
			return
		end
	end
	end
	minetest.set_node(pos,oldnode)
	return true
end)

mt2d.get_nodes_radius=function(pos,rad)
	rad=rad or 2
	local nodes={}
	local p
	for r=0,rad,1.5 do
	for a=-r,r,0.5 do
		p={	x=pos.x+(math.cos(a)*r)*0.5,
			y=pos.y+(math.sin(a)*r)*0.5,
			z=0
		}
		nodes[minetest.pos_to_string(p)]=p
	end
	end
	return nodes
end

mt2d.set_attach=function(name,object,object_to_attach,pos)
	pos=pos or {}
	pos={x=pos.x or 0,y=pos.y or 0,z=pos.z or 0}
	mt2d.attach[name]={
		name=name,
		id=mt2d.user[name].id,
		ob1=object,
		ob2=object_to_attach,
		pos=pos or {x=0,y=0,z=0}
	}
end

mt2d.get_attach=function(name)
	return mt2d.attach[name]
end

mt2d.set_detach=function(name)
	if mt2d.attach[name] then
		mt2d.attach[name]=nil
	end
end

mt2d.path_iremove=function(path,index)
	path[minetest.pos_to_string(path[index])]=nil
	table.remove(path,index)
	return path
end

mt2d.path=function(pos,l,dir,group)
	local c={}
	local lastpos={x=math.floor(pos.x),y=math.floor(pos.y),z=0}
	for i=dir,l*dir,dir do
		c,lastpos=mt2d.path_add(dir,c,lastpos,group)
		if not lastpos then
			break
		end
	end
	return c
end

mt2d.path_add=function(d,c,lp,group)
	for i, r in pairs({{x=0,y=0},{x=d,y=0},{x=0,y=1},{x=0,y=-1},{x=-d,y=0}}) do
		local p={x=lp.x+r.x,y=lp.y+r.y,z=0}
		local ps=minetest.pos_to_string(p)
		if not c[ps] and minetest.get_item_group(minetest.get_node(p).name,group)>0 then
			c[ps]=p
			table.insert(c,p)
			return c,p
		end
	end
	return c
end
