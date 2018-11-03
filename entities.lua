minetest.register_entity("mt2d:cam",{
	hp_max = 99999,
	collisionbox = {0,0,0,0,0,0},
	visual =  "sprite",
	textures ={"mt2d_air.png"},
	on_activate=function(self, staticdata)
		self.timer=0
		self.dmgtimer=0
		self.breath=11
		self.user_pos={x=0,y=0,z=0}
		self.powersaving={dir=0,x=0,y=0,timer=0,timeout=0.1,time=0,count=5}
		return self
	end,
	on_step=function(self, dtime)
		if self.powersaving.timeout>0 then
			self.powersaving.timeout=self.powersaving.timeout-dtime

			return self
		elseif not (self.user and mt2d.user[self.username] and mt2d.user[self.username].id==self.id ) then
			self.object:remove()
			return self
		elseif not (self.ob and self.ob:get_luaentity()) then
			local pos=self.object:get_pos()
			self.ob=minetest.add_entity({x=pos.x,y=pos.y+1,z=pos.z-5}, "mt2d:player")

			self.ob:get_luaentity().user=self.user
			self.ob:get_luaentity().id=self.id
			self.ob:get_luaentity().username=self.username

			self.fly=minetest.check_player_privs(self.username, {fly=true})
			self.noclip=minetest.check_player_privs(self.username, {noclip=true})

			self.ob:set_properties({
				textures={"mt2d_air.png",mt2d.user[self.username].texture},
				nametag=self.username,
				nametag_color="#FFFFFF"
			})

			self.user:set_properties({
				textures="mt2d_air.png",
				nametag="",
			})

			mt2d.user[self.username].object=self.ob
		end

		local pos=self.object:get_pos()
		local pos2=self.ob:get_pos()
		local key=self.user:get_player_control()

		local v=self.ob:get_velocity()
		if not pos2 then
			local user=self.user
			self.object:remove()
			user:set_hp(0)
			return
		end
		local node=minetest.registered_nodes[minetest.get_node({x=pos2.x,y=pos2.y-1,z=0}).name]
		local node2=minetest.registered_nodes[minetest.get_node({x=pos2.x,y=pos2.y+1,z=0}).name]

		if not (node and node2) then return end

		if node.damage_per_second>0 then
			self.dmgtimer=self.dmgtimer+dtime
			if self.dmgtimer>1 then
				self.dmgtimer=0
				mt2d.punch(self.user,self.ob,node.damage_per_second)
			end
		end
--breath
		if node2.drowning>0 then
			self.breath=self.breath-dtime
			self.user:set_breath(self.breath)
			if self.breath<=0 then
				self.breath=0
				self.dmgtimer=self.dmgtimer+dtime
				if self.dmgtimer>1 then
					self.dmgtimer=0
					mt2d.punch(self.user,self.ob,1)
				end
			end
		elseif self.breath<11 then
			self.breath=self.breath+dtime
			self.user:set_breath(self.breath)
		end
--physics
		if node.liquid_viscosity>0 or node.climbable then
			if v.y<-0.1 then
				v={x = v.x*0.99, y =v.y*0.99, z =v.z*0.99}
			end
			if not self.floating then
				self.fallingfrom=nil
				self.ob:set_acceleration({x=0,y=0,z=0})
				self.floating=true
			end
		elseif self.floating then
			self.ob:set_acceleration({x=0,y=-20,z =0})
			self.floating=nil
		elseif v.y<0 and not self.fallingfrom then
			self.fallingfrom=pos.y
		elseif self.fallingfrom and v.y==0 then
			local from=math.floor(self.fallingfrom+0.5)
			local hit=math.floor(pos.y+0.5)
			local d=from-hit
			self.fallingfrom=nil
			if minetest.get_node({x=pos2.x,y=pos2.y-2,z=0}).name~="ignore" and d>=10 then
				mt2d.punch(self.ob,self.ob,d)
			end
		end
--input & anim
		if self.ob:get_luaentity().dead then
			return self
		elseif self.laying then
			v={x=0,y=0,z=0}
			self.ob:set_acceleration({x=0,y=0,z=0})
			mt2d.player_anim(self,"lay")
			if key.up or key.left or key.right or self.wakeup then
				self.laying=nil
				self.wakeup=nil
				self.ob:set_acceleration({x=0,y=-20,z=0})
			end
		elseif key.up and (v.y==0 or self.floating) then
			v.y=8
		elseif key.left then
			v.x=4
			mt2d.player_anim(self,"walk")
			self.ob:set_yaw(4.71)
		elseif key.right then
			v.x=-4
			mt2d.player_anim(self,"walk")
			self.ob:set_yaw(1.57)
		elseif key.RMB or key.LMB then
			mt2d.player_anim(self,"mine")
			v.x=0
		elseif key.aux1 and 	minetest.check_player_privs(self.username, {leave2d=true}) then
			mt2d.to_3dplayer(self.user)
			return
		else
			mt2d.player_anim(self,"stand")
			v={x=0,y=v.y,z=0}
		end

		if self.floating then
			v.x=v.x/2
			v.y=v.y/2
			if key.down then
				v.y=-2
			end
		end

		if self.fly and key.sneak then
			self.ob:set_acceleration({x=0,y=0,z=0})
			if key.up then
				v.y=8
			elseif key.down then
				v.y=-8
			else
				v.y=0
			end
			self.flying=true
			if self.noclip and not self.noclip_enabled then
				v={x=0.1,y=8,z=0}
				self.noclip_enabled=true
				self.ob:set_properties({physical=false})
			end
			v.x=v.x*2
			self.fallingfrom=nil
		elseif self.noclip_enabled or self.flying then
			self.noclip_enabled=nil
			self.flying=nil
			self.ob:set_properties({physical=true})
			self.ob:set_acceleration({x=0,y=-20,z=0})
		elseif key.sneak and v.x~=0 then
			v.x=v.x/4
		end
--movment
		self.ob:set_velocity(v)

		if self.powersaving.time==0 then
			self.object:set_velocity({x=((pos2.x-pos.x)*10)+self.user_pos.x,y=(-0.5+(pos2.y-pos.y))*10,z=(5-(pos.z-pos2.z))*10})
		else
			self.object:set_velocity({x=((pos2.x-pos.x))+self.user_pos.x,y=(-0.5+(pos2.y-pos.y)),z=(5-(pos.z-pos2.z))})
		end

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

		if self.powersaving.dir~=tyaw+tpitch or self.powersaving.x~=v.x or self.powersaving.y~=v.y then
			self.powersaving={
				dir=tyaw+tpitch,
				x=v.x,
				y=v.y,
				timer=0,
				time=0,
				count=5,
				timeout=0
			}
		else
			self.powersaving.timer=self.powersaving.timer+dtime*2	
			if self.powersaving.timer>self.powersaving.count and self.powersaving.time<2 then
				self.powersaving.count=1
				self.powersaving.timer=0
				self.powersaving.time=self.powersaving.time+0.1
				self.powersaving.timeout=self.powersaving.time
			end
		end
		self.powersaving.timeout=self.powersaving.time
		return self
	end,
	start=0.1,
	type="npc",
})

minetest.register_entity("mt2d:player",{
	hp_max = 20,
	physical = true,
	collisionbox = {-0.35,-1,-0,0.35,0.8,0},
	visual =  "mesh",
	mesh = "mt2d_character.b3d",
	textures = {"mt2d_air.png","mt2d_air.png"},
	is_visible = true,
	makes_footstep_sound = true,
	on_activate=function(self, staticdata)
		local rndlook={4.71,1.57}
		self.object:set_yaw(rndlook[math.random(1,2)])
		self.object:set_acceleration({x=0,y=-20,z =0})
		return self
	end,
	on_punch=function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		if not self.user then
			self.object:remove()
		elseif not (puncher:is_player() and puncher:get_player_name(puncher)==self.username) and tool_capabilities and tool_capabilities.damage_groups and tool_capabilities.damage_groups.fleshy then
			self.user:set_hp(self.user:get_hp()-tool_capabilities.damage_groups.fleshy)
		end
		return self
	end,
	on_step=function(self, dtime)
		self.timer=self.timer+dtime
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
		elseif self.timer>3 then
			self.timer=0
			if not self.user:get_attach() then
				mt2d.new_player(self.user)
				return
			end
		end
	end,
	id=0,
	username="",
	start=0.1,
	type="npc",
	team="Sam",
	timer=0,
})