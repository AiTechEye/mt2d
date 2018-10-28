mt2d={
	user={},
	playeranim={
		stand={x=1,y=39,speed=30},
		walk={x=41,y=61,speed=30},
		mine={x=65,y=75,speed=30},
		hugwalk={x=80,y=99,speed=30},
		lay={x=113,y=123,speed=0},
		sit={x=101,y=111,speed=0},
	},
}

minetest.after(0.1, function()
	for i, v in pairs(minetest.registered_items) do
		if not v.ragne or v.ragne<6 then
			minetest.override_item(i, {range=6})
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
	mt2d.user[player:get_player_name()]={id=id,cam=cam}
	player:set_attach(cam, "",{x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
end

minetest.register_on_joinplayer(function(player)
	local pos=player:get_pos()
	player:set_pos({x=pos.x,y=pos.y,z=0})
	minetest.after(1, function(player)
		mt2d.new_player(player)
	end,player)
end)

minetest.register_on_respawnplayer(function(player)
	local pos=player:get_pos()
	player:set_pos({x=pos.x,y=pos.y,z=0})
	minetest.after(1, function(player)
		mt2d.new_player(player)
	end,player)
end)

minetest.register_on_dieplayer(function(player)
	player:set_detach()
end)

minetest.register_entity("mt2d:cam",{
	hp_max = 99999,
	collisionbox = {0,0,0,0,0,0},
	visual =  "sprite",
	textures ={"mt2d_air.png"},
	on_activate=function(self, staticdata)
		self.dmgtimer=0
		if 1 then return end
		if staticdata~="" then
			self.username=staticdata
		elseif aliveai_mindcontroller.usersname then
			self.username=aliveai_mindcontroller.usersname
			aliveai_mindcontroller.usersname=nil
		end
		local e=aliveai_mindcontroller.users[self.username]
		if not (self.username and e ) then
			self.object:remove()
			return self
		end
		if minetest.check_player_privs(self.username, {fly=true})==false then
			self.object:set_acceleration({x=0,y=-10,z =0})
			self.object:set_velocity({x=0,y=-3,z =0})
		end

		self.object:set_animation({ x=1, y=39, },30,0)
		self.object:set_properties({
			mesh=aliveai.character_model,
			textures=e.texture,
			nametag=self.username,
			nametag_color="#FFFFFF"
		})
		return self
	end,
	get_staticdata = function(self)
		return self.username
	end,
	on_step=function(self, dtime)
		if self.start>0 then
			self.start=self.start-dtime
			return self
		elseif not (self.user and mt2d.user[self.username] and mt2d.user[self.username].id==self.id ) then
			self.object:remove()
			return self
		elseif not (self.ob and self.ob:get_luaentity()) then
			local pos=self.object:get_pos()
			local rndlook={4.71,1.57}
			self.ob=minetest.add_entity({x=pos.x,y=pos.y+1,z=pos.z-5}, "mt2d:player")
			self.ob:set_acceleration({x=0,y=-20,z =0})
			self.ob:set_yaw(rndlook[math.random(1,2)])
			self.ob:get_luaentity().user=self.user

			self.ob:get_luaentity().id=self.id
			self.ob:get_luaentity().username=self.username

			self.user_pos={x=0,y=0,z=0}
			mt2d.user[self.username].object=self.ob
		end

		local pos=self.object:get_pos()
		local pos2=self.ob:get_pos()
		local key=self.user:get_player_control()

		local v=self.ob:get_velocity()
		local node=minetest.registered_nodes[minetest.get_node(pos2).name] 

		if node and node.damage_per_second>0 then
			self.dmgtimer=self.dmgtimer+dtime
			if self.dmgtimer>1 then
				self.dmgtimer=0
				mt2d.punch(self.user,self.ob,node.damage_per_second)
			end
		end

		if node and node.liquid_viscosity>0 then
			if v.y<-0.1 then
				v={x = v.x*0.9, y =v.y*0.9, z =v.z*0.9}
			end
			if not self.in_liquid then
				self.fallingfrom=nil
				self.ob:set_acceleration({x=0,y=0,z =0})
				self.in_liquid=true
			end
		elseif self.in_liquid then
			self.ob:set_acceleration({x=0,y=-20,z =0})
			self.in_liquid=nil
		elseif v.y<0 and not self.fallingfrom then
			self.fallingfrom=pos.y
		elseif self.fallingfrom and v.y==0 then
			local from=math.floor(self.fallingfrom+0.5)
			local hit=math.floor(pos.y+0.5)
			local d=from-hit
			self.fallingfrom=nil

			if d>=10 then
				mt2d.punch(self.ob,self.ob,d)
			end
		end


		if self.ob:get_luaentity().dead then
			return self
		elseif key.up and  (v.y==0 or self.in_liquid) then
			v.y=8
		elseif key.RMB or key.LMB then
			mt2d.player_anim(self,"mine")
		end

		if key.left then
			v.x=4
			mt2d.player_anim(self,"walk")
			self.ob:set_yaw(4.71)
		elseif key.right then
			v.x=-4
			mt2d.player_anim(self,"walk")
			self.ob:set_yaw(1.57)
		--elseif key.jump then
		--	self.user:set_detach()
		--	mt2d.user[self.username].id=math.random(1,9999)
		--	return
		else
			mt2d.player_anim(self,"stand")
			v={x=0,y=v.y,z=0}
		end

		if self.in_liquid then
			v.x=v.x/2
			v.y=v.y/2
			if key.down then
				v.y=-2
			end
		end

		self.ob:set_velocity(v)
		self.object:set_velocity({x=((pos2.x-pos.x)*10)+self.user_pos.x,y=(-0.5+(pos2.y-pos.y))*10,z=(5-(pos.z-pos2.z))*10})
		local yaw=self.user:get_look_yaw()
		local pitch=self.user:get_look_pitch()

		local tyaw=math.abs(yaw-4.71)
		local tpitch=math.abs(pitch)
		local npointable=not mt2d.pointable(pos2,self.user)

		if tyaw>0.5 or (npointable and tyaw>0.2) then
			self.user:set_look_yaw(3.14+((yaw-4.71)*0.9))

		elseif tpitch>0.5 or (npointable and tpitch>0.2) then
			self.user:set_look_pitch((pitch*0.9)*-1)
		end
		return self
	end,
	start=1,
	type="npc",
})



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
	return self
end

minetest.register_entity("mt2d:player",{
	hp_max = 20,
	physical = true,
	collisionbox = {-0.35,-1,-0.35,0.35,0.8,0.35},
	visual =  "mesh",
	mesh = "mt2d_character.b3d",
	textures = {"character.png"},
	spritediv = {x=1, y=1},
	is_visible = true,
	makes_footstep_sound = true,
	on_punch=function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		if not (puncher:is_player() and puncher:get_player_name(puncher)==self.username) and tool_capabilities and tool_capabilities.damage_groups and tool_capabilities.damage_groups.fleshy then
			self.user:set_hp(self.user:get_hp()-tool_capabilities.damage_groups.fleshy)
		end
		return self
	end,
	on_step=function(self, dtime)
		if self.start>0 then
			self.start=self.start-dtime
			return self
		elseif not (mt2d.user[self.username] and mt2d.user[self.username].id==self.id) then
			self.object:remove()
			return self
		elseif self.user:get_hp()<=0 then
			self.ob=self.object
			self.ob:get_luaentity().dead=true
			mt2d.player_anim(self,"lay")
		end
	end,
	id=0,
	username="",
	start=1,
	type="npc",
	team="Sam",
	time=0,
})

minetest.register_node("mt2d:blocking", {
	description = "blocking",
	drawtype="airlike",
	paramtype="light",
	pointable=false,
	after_destruct = function(pos, oldnode)
		minetest.set_node(pos,oldnode)
	end,
})

local paths={
{0.2,"bubble.png^[colorize:#0000ffff"},
{0.2,"bubble.png^[colorize:#ffff00ff"},
{0.3,"bubble.png^[colorize:#00ff00ff"}}

for i=1,3,1 do
minetest.register_entity("mt2d:path" .. i,{
	hp_max = 1,
	physical = false,
	weight = 0,
	collisionbox = {-0.1,-0.1,-0.1, 0.1,0.1,0.1},
	visual = "sprite",
	visual_size = {x=paths[i][1], y=paths[i][1]},
	textures = {paths[i][2]}, 
	colors = {}, 
	spritediv = {x=1, y=1},
	initial_sprite_basepos = {x=0, y=0},
	is_visible = true,
	makes_footstep_sound = false,
	automatic_rotate = false,
	is_falling=0,
	on_step = function(self, dtime)
		self.timer=self.timer-dtime
		if self.timer<0 then
			self.object:remove()
		end
	end,
	timer=0.1,
})
end
paths=nil




minetest.register_on_generated(function(minp, maxp, seed)
	local air=minetest.get_content_id("air")
	local blocking=minetest.get_content_id("mt2d:blocking")
	local vox = minetest.get_voxel_manip()
	local min, max = vox:read_from_map(minp, maxp)
	local area = VoxelArea:new({MinEdge = min, MaxEdge = max})
	local data = vox:get_data()
	for z = minp.z, maxp.z do
	for y = minp.y, maxp.y do
	for x = minp.x, maxp.x do
		if z==1 or z==-1 or z==5 then
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
	elseif ob1:get_luaentity() and ob1:get_luaentity().itemstring then
		ob:remove() return
	else
		ob1:punch(ob2,1,{full_punch_interval=1,damage_groups={fleshy=hp}})
	end	
end