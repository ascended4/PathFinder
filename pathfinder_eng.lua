local self = {}
local log = function(text)
	if ZAI.PathFinder.data.log_enable then
		SystemLog(text)
	else
		if ZAI.PathFinder.data.last_frame_time then
			local FinishTime = tonumber(U64ToStr(GetU64Time()))
			if (FinishTime - ZAI.PathFinder.data.last_frame_time) > 20000 then
				ZAI.PathFinder.data.log_enable = true
			end
		end
	end
end
ZAI.PathFinder = {
	data = {
		log_enable = false,
		last_frame_time = nil,
		enable = true,
		path = {},
		max_path = 200,
		--My_Ent = Entities[0],
		--My_Pos = Vec3( 0, 0, 0 ),
		Target_Vec3 = Vec3( -167.2069, -148.2849, 751.2449 ), -- or Entities[]
		Target_Vec3_r = Vec3( -167.2069, -148.2849, 751.2449 ),
		--Target_Ent = Entities[0],
		time = {
			path_scan = 0,
			path_limit = 2000, --miliseconds
		},
		new_path = {},
		render_path = true,
		render_new_path = false,
		normal_buffer = {},
		normal_length = 10,
	},
	GetEntityRadius = function(self, ent)
		local n1,n2,n3,n4,n5,n6 = GetEntityLocalBound(ent)
		n1 = math.abs(n1)
		n2 = math.abs(n2)
		n3 = math.abs(n3)
		n4 = math.abs(n4)
		n5 = math.abs(n5)
		n6 = math.abs(n6)
		return math.max(n1,n2,n3,n4,n5,n6)
	end,
	GetPath = function(self)
		return self.data.path
	end,
	GetFlyPoint = function(self)
		if not self.data.path[1] then
			if self.data.new_path[1] then
				return self.data.new_path[1].GetVec3()
			elseif self.data.Target_Ent then
				return self.data.Target_Ent:GetPos()
			else
				return self.data.Target_Vec3
			end
		else
			return self.data.path[1].GetVec3()
		end
	end,
	GetTarget = function(self)
		if not self.data.Target_Vec3 and not self.data.Target_Ent then
			return Vec3(0,0,0)
		elseif self.data.Target_Ent then
			return self.data.Target_Ent:GetPos(), self.data.Target_Ent
		elseif self.data.Target_Vc3 then
			return self.data.Target_Vec3
		end
	end,
	Reset_Path = function(self)
		self.data.path = {}
	end,
	Reset_NewPath = function(self)
		self.data.new_path = {}
		self.data.normal_buffer = {}
		self:ResetTimeLimit()
	end,
	AddNewPoint = function(self, path, point)
		--Metatable is a crutch. The author is my laziness.
		--The bottom line is that it is needed in order to record somewhere the information about whether the point is trash or not.
		local sub = function(a, b)
			if type(a) == "table" and type(b) == "userdata" then
				return a.GetVec3() - b
			elseif type(a) == "userdata" and type == "table" then
				return a - b.GetVec3()
			else
				return a.GetVec3() - b.GetVec3() 
			end
		end
		table.insert(path, #path+1, setmetatable({TruePoint = false, GetVec3 = function() return point end}, {__index = point, __sub = sub}))
	end,
	UpdateNormalLength = function(self)
		self.data.normal_length = self:GetEntityRadius(self.data.My_Ent)*2
	end,
	CheckObstacles_Path = function(self) --Returns "true" if no new obstacles have appeared
		if self.data.path[1] then --Checking if there is any data in "path"

			--Check if there are new obstacles between My_Pos and the beginning of the self.data.path
			local ent, hit_pos, normal = self:TraceLine_ENT_TP(self.data.My_Ent, self.data.path[1])
			if ent then
				return false
			end

			--Check if there are new obstacles between Target_Vec3 and the beginning of the self.data.path
			--if self.data.Tartet_Ent then
			--	ent, hit_pos, normal =  self:TraceLine_ENT_TP(self.data.Tartet_Ent, self.data.path[#self.data.path])
			--else
			--	sys.log("self.data.Tartet_Vec3 = "..inspect(self.data.Tartet_Vec3))
			--	sys.log("self.data.path[#self.data.path] = "..inspect(self.data.path[#self.data.path]))
			--	ent, hit_pos, normal =  self:TraceLine_P_TP(self.data.Tartet_Vec3, self.data.path[#self.data.path])
			--end
			--if ent then
			--	return false
			--end

			--check if there is obstacle on "path"
			--I need to do something with it, it’s too bold to allocate so many resources for this shit
			for i = 2, #self.data.path do
				ent, hit_pos, normal = self:TraceLine_TP_TP(self.data.path[i-1], self.data.path[i])
				if ent then
					return false
				end
			end
			return true
		else
			return true
		end
	end,
	CheckObstacles_NewPath = function(self) --Returns "true" if no new obstacles have appeared
		if self.data.new_path[1] then --Checking if there is any data in "new_path"

			--Check if there are new obstacles between My_Pos and the beginning of the self.data.new_path
			local ent, hit_pos, normal =  self:TraceLine_ENT_TP(self.data.My_Ent, self.data.new_path[1])
			if ent then
				return false
			end

			--check if there is obstacle on "new_path"
			--I need to do something with it, it’s too bold to allocate so many resources for this shit
			for i = 2, #self.data.new_path do
				ent, hit_pos, normal = self:TraceLine_TP_TP(self.data.new_path[i-1], self.data.new_path[i])
				if ent then
					return false
				end
			end
			return true
		else
			return true
		end
	end,
	TraceLine = function(self, p1,p2)
		--log("TraceLine ("..inspect(p1)..","..inspect(p2))
		return TraceLine(p1, p2, false)
	end,
	TraceLine_TP_TP = function(self, table_p1, table_p2)
		--log("TraceLine ("..inspect(table_p1)..","..inspect(table_p2))
		return self:TraceLine(table_p1.GetVec3(), table_p2.GetVec3())
	end,
	TraceLine_TP_P = function(self, table_p1, p2)
		--log("TraceLine ("..inspect(table_p1)..","..inspect(table_p2))
		return self:TraceLine(table_p1.GetVec3(), p2)
	end,
	TraceLine_P_TP = function(self, p1, table_p2)
		--log("TraceLine ("..inspect(table_p1)..","..inspect(table_p2))
		return self:TraceLine(p1, table_p2.GetVec3())
	end,
	TraceLine_P_ENT = function(self, p1, ent2)
		--log("TraceLine ("..inspect(table_p1)..","..inspect(ent2))
		local ent2_radius = self:GetEntityRadius(ent2)
		local p1_dis_ent2 = vector3.distance(p1, ent2:GetPos())
		if p1_dis_ent2 < ent2_radius then
			return
		end
		local new_p2 = vector3.NewDistance(ent2:GetPos(), p1, ent2_radius)
		return self:TraceLine(p1, new_p2)
	end,
	TraceLine_TP_ENT = function(self, p1, ent2)
		--log("TraceLine ("..inspect(p1)..","..inspect(ent2))
		return self:TraceLine_P_ENT(p1.GetVec3(), ent2)
	end,
	TraceLine_ENT_P = function(self, ent1, p2)
		--log("TraceLine_ENT_P ("..inspect(ent1)..","..inspect(p2))
		--log(" ent1:GetPos() = "..inspect(ent1:GetPos()))
		local ent1_radius = self:GetEntityRadius(ent1)
		--sys.log("ent1_radius = "..ent1_radius)
		local ent1_dis_p2 = vector3.distance(ent1:GetPos(), p2)
		--sys.log("ent1_dis_p2 = "..ent1_dis_p2)
		if ent1_dis_p2 < ent1_radius then
			return
		end
		local new_p1 = vector3.NewDistance(ent1:GetPos(), p2, ent1_radius)
		--sys.log("new_p1 = "..inspect(new_p1))
		--sys.log("self:TraceLine(new_p1, p2) = "..inspect(self:TraceLine(new_p1, p2)))
		local ent, hit_pos, normal, material = self:TraceLine(new_p1, p2)
		return ent, hit_pos, normal, material, new_1
	end,
	TraceLine_ENT_TP = function(self, ent1, table_p2)
		--log("TraceLine ("..inspect(table_p1)..","..inspect(ent2))
		return self:TraceLine_ENT_P( ent1, table_p2.GetVec3())
	end,
	TraceLine_ENT_ENT = function(self, ent1, ent2)
		local ent1_radius = self:GetEntityRadius(ent1) +1
		local ent2_radius = self:GetEntityRadius(ent2) +1

		local ent1_dis_ent2 = vector3.distance(ent1:GetPos(), ent2:GetPos())
		local new_p1 = vector3.NewDistance(ent1:GetPos(), ent2:GetPos(), ent1_radius)
		local new_p2 = vector3.NewDistance(ent2:GetPos(), ent1:GetPos(), ent2_radius)
		local ent, hit_pos, normal, material = self:TraceLine(new_p1, new_p2)
		return ent, hit_pos, normal, material, new_p1
	end,
	RenderCurrentPath = function(self)
		if not self.data.render_path then
			return
		end
		if not self.data.Target_Vec3 or not self.data.My_Pos then
			return
		end
		if #self.data.path == 0 and self.data.Target_Vec3 and self.data.My_Pos then
			DrawDebugLine(self.data.Target_Vec3, self.data.My_Pos, 255)
		else
			DrawDebugLine(self.data.My_Pos, self.data.path[1].GetVec3(), 255)
			local max_render = 0
			if #self.data.path < 100 then
				max_render = #self.data.path
			else
				max_render = 100
			end
			for i = 2, max_render do
				--log("Drawing route lines 'path'")
				DrawDebugLine(self.data.path[i-1].GetVec3(), self.data.path[i].GetVec3(), 255)
			end
			for i = 1, max_render do 
				DrawDebugSphere(self.data.path[i].GetVec3(), 1, 1834767, true, true)
			end
			for i = 1, #self.data.path do
				--local cor_x, cor_y, off_screen = _G.ProjectPointToScreen(self.data.path[i], Vec2(0,0), Vec2(1920, 1080))
				--Reactor.AddText2({font = 3, x = cor_x, y = cor_y, text = ""..i, name = "point_"..i,  color = dec("ffffffff"), flag = 513})
			end
			DrawDebugLine(self.data.Target_Vec3, self.data.path[#self.data.path].GetVec3(), 255)
		end
		local cor_x, cor_y, off_screen = _G.ProjectPointToScreen(self.data.Target_Vec3, Vec2(0,0), Vec2(1920, 1080))
		Reactor.AddText2({font = 3, x = cor_x, y = cor_y, text = "Target", name = "Target22",  color = dec("ff00ff00"), flag = 513})
		local cor_x, cor_y, off_screen = _G.ProjectPointToScreen(self.data.My_Pos, Vec2(0,0), Vec2(1920, 1080))
		Reactor.AddText2({font = 3, x = cor_x, y = cor_y, text = "Start", name = "Start22",  color = dec("ff00ff00"), flag = 513})
	end,
	RenderNewPath = function(self)
		if not self.data.render_new_path then
			return
		end
		if not self.data.Target_Vec3 or not self.data.My_Pos then
			return
		end
		if #self.data.new_path == 0 then
			DrawDebugLine(self.data.Target_Vec3, self.data.My_Pos, 255)
		else
			DrawDebugLine(self.data.My_Pos, self.data.new_path[1].GetVec3(), 255)
			local max_render = 0
			if #self.data.new_path < 50 then
				max_render = #self.data.new_path
			else
				max_render = 50
			end
			for i = 2, max_render do
				--log("Drawing route lines 'new_path'")
				DrawDebugLine(self.data.new_path[i-1].GetVec3(), self.data.new_path[i].GetVec3(), 255)
			end
			for i = 1, max_render do 
				DrawDebugSphere(self.data.new_path[i].GetVec3(), 1, 1834767, true, true)
			end
			for i = 1, #self.data.new_path do
				--local cor_x, cor_y, off_screen = _G.ProjectPointToScreen(self.data.new_path[i], Vec2(0,0), Vec2(1920, 1080))
				--Reactor.AddText2({font = 3, x = cor_x, y = cor_y, text = ""..i, name = "point_"..i,  color = dec("ffffffff"), flag = 513})
			end
			DrawDebugLine(self.data.Target_Vec3, self.data.new_path[#self.data.new_path].GetVec3(), 255)
		end
		local cor_x, cor_y, off_screen = _G.ProjectPointToScreen(self.data.Target_Vec3, Vec2(0,0), Vec2(1920, 1080))
		Reactor.AddText2({font = 3, x = cor_x, y = cor_y, text = "Target", name = "Target22",  color = dec("ff00ff00"), flag = 513})
		local cor_x, cor_y, off_screen = _G.ProjectPointToScreen(self.data.My_Pos, Vec2(0,0), Vec2(1920, 1080))
		Reactor.AddText2({font = 3, x = cor_x, y = cor_y, text = "Start", name = "Start22",  color = dec("ff00ff00"), flag = 513})
	end,
	CheckTimeLimit = function(self)--Checking the Timer
		local FinishTime = tonumber(U64ToStr(GetU64Time()))
		--sys.log("FinishTime = "..FinishTime)
		--sys.log("self.data.time.path_limit = "..self.data.time.path_limit)
		--sys.log("FinishTime - self.data.time.path_limit = "..(FinishTime - self.data.time.path_limit))
		--sys.log("self.data.time.path_scan = "..self.data.time.path_scan)
		if (FinishTime - self.data.time.path_limit) < self.data.time.path_scan then
			return false
		else
			return true
		end
	end,
	ResetTimeLimit = function(self) --Reset Timer
		--sys.log("Reset Timer")
		self:UpdateNormalLength()--Update the normal length by substituting the radius of the controlled ship
		self.data.time.path_scan = tonumber(U64ToStr(GetU64Time()))
		--sys.log("tonumber(U64ToStr(GetU64Time())) = "..tonumber(U64ToStr(GetU64Time())))
		--sys.log("self.data.time.path_scan = "..self.data.time.path_scan)
	end,
	IsForceUpdateNeeded = function(self)
		--Checking whether it is urgent to replace the old path
		--Depending on the distance between the closest flight point and the controlled ship
		if vector3.distance(self.data.My_Pos, self:GetFlyPoint()) < 50.0 then --If the distance is less than 500 meters then yes
			return true
		else
			return false
		end
		--P.S. This function will only be called if there is not enough time to complete new_path
	end,
	PathUpdate = function(self)
		self.data.path = self.data.new_path
		self:Reset_NewPath()
	end,
	TransformNormal = function(self, normal, StartPoint, hit_pos)
		--sys.log("TransformNormal("..inspect(normal)..","..inspect(StartPoint)..","..inspect(hit_pos))
		--reduce the normal to a certain value and register it
		local normal_string = round(normal.x, 1)..","..round(normal.y, 1)..","..round(normal.z, 1)
		if not self.data.normal_buffer[normal_string] then
			self.data.normal_buffer[normal_string] = {
				count = 0,
				normal = Vec3(0,0,0),
			}
		end
		self.data.normal_buffer[normal_string].count = self.data.normal_buffer[normal_string].count + 1
		--Есть 2 режима:
		--Default: Asteroid avoidance. you just need to adjust the length to the width of the ship
		if self.data.normal_buffer[normal_string].count < 5 then
			--TODO: Connect the reflection function via the ray vector, point and normal.
			--Then here the number of points and trace calls will decrease by 2 times
			return vector3.NewDistance(Vec3(0,0,0), normal, self.data.normal_length+(0.1*#self.data.new_path))
		else --Obstacle avoidance with right angles. Turns on if the same normal has already been encountered several times
			if vector3.equal(self.data.normal_buffer[normal_string].normal, Vec3(0,0,0)) then--Create a normal that will be parallel to the surface
				local I = StartPoint - hit_pos
				I = -I
				local point_A = hit_pos + normal*10
				local point_B = hit_pos + I*10
				local point_C = hit_pos
				local angle_BAC = vector3.GetAngle(point_A, point_B, point_C)
				local dis_CA = vector3.distance(point_C, point_A)
				local dis_AD = dis_CA/math.cos(math.rad(angle_BAC))
				local point_D = vector3.NewDistance(point_A,point_B, dis_AD)
				self.data.normal_buffer[normal_string].normal = point_D - hit_pos
			end
			local rv_normal = vector3.NewDistance(Vec3(0,0,0), self.data.normal_buffer[normal_string].normal, self.data.normal_length+4*(self.data.normal_buffer[normal_string].count-5))
			if true then
				local point_N = hit_pos+normal
				local angle_NHS = vector3.GetAngle(hit_pos, point_N, StartPoint)
				local dis_HA = self.data.normal_length/math.cos(math.rad(angle_NHS))
				local point_antireflect = vector3.NewDistance(hit_pos, StartPoint, dis_HA)
				local dis_NA = vector3.distance(point_N, point_antireflect)
				local rv_normal = vector3.NewDistance(Vec3(0,0,0), self.data.normal_buffer[normal_string].normal, dis_NA+self.data.normal_length+1*(self.data.normal_buffer[normal_string].count-5))
				--sys.log("rv_normal = "..inspect(rv_normal))
				--sys.log("point_antireflect = "..inspect(point_antireflect))
				return rv_normal, point_antireflect
			end
			if false then
				local point_N = hit_pos+normal
				local angle_NHS = vector3.GetAngle(hit_pos, StartPoint, point_N)
				local dis_HA = self.data.normal_length/math.cos(math.rad(angle_NHS))
				sys.log("self.data.normal_length = "..self.data.normal_length)
				sys.log("angle_NHS = "..math.rad(angle_NHS))
				sys.log("dis_HA = "..dis_HA)
				local point_antireflect = vector3.NewDistance(hit_pos, StartPoint, dis_HA)
				--local dis_NA = vector3.distance(point_N, point_antireflect)
				--local rv_normal = vector3.NewDistance(Vec3(0,0,0), self.data.normal_buffer[normal_string].normal, dis_NA+self.data.normal_length+4*(self.data.normal_buffer[normal_string].count-5))
				--sys.log("rv_normal = "..inspect(rv_normal))
				--sys.log("point_antireflect = "..inspect(point_antireflect))
				return rv_normal, point_antireflect
			end
			return rv_normal
		end
	end,
	GetReflectPoint = function(self, array_i)
		local StartPoint = Vec3(0,0,0)
		local ent = false
		local hit_pos = false
		local normal = false
		local material = false
		--We get the intersection
		if array_i == 1 then
			if self.data.Target_Ent then
				ent, hit_pos, normal, material, StartPoint =  self:TraceLine_ENT_ENT(self.data.My_Ent, self.data.Target_Ent)
			else
				--sys.log("self.data.Target_Vec3 = "..inspect(self.data.Target_Vec3))
				ent, hit_pos, normal, material, StartPoint =  self:TraceLine_ENT_P(self.data.My_Ent, self.data.Target_Vec3)
			end
			--sys.log("ARARA")
		else
			--sys.log("URARA i = "..array_i)
			StartPoint = self.data.new_path[array_i-1].GetVec3()
			if self.data.Target_Ent then
				ent, hit_pos, normal, material =  self:TraceLine_TP_ENT(self.data.new_path[array_i-1], self.data.Target_Ent)
			else
				ent, hit_pos, normal, material =  self:TraceLine_TP_P(self.data.new_path[array_i-1], self.data.Target_Vec3)
			end
		end

		
		
		--If there are no intersections, then return 'nil'
		if not ent then
			return
		end

		--Create a normal
		--Transforming the normal through the TransformNormal() function
		--sys.log("ent = "..inspect(ent))
		--sys.log("hit_pos = "..inspect(hit_pos))
		--sys.log("normal = "..inspect(normal))
		--sys.log("material = "..inspect(material))
		--sys.log("StartPoint = "..inspect(StartPoint))
		local normal, AlterStartPoint = self:TransformNormal(normal, StartPoint, hit_pos)
		if AlterStartPoint then
			--sys.log("hit_pos = "..inspect(hit_pos))
			--sys.log("AlterStartPoint = "..inspect(AlterStartPoint))
			hit_pos = AlterStartPoint
		end
		--result = new normal + point of intersection
		local rv = normal+hit_pos

		--We check that the reflection from the obstacle did not enter the inside of another obstacle
		local ent2, hit_pos2, normal2, material2 =  self:TraceLine(hit_pos, rv)
		if ent2 then
			-- need to cut the normal
			--sys.log("hit_pos = "..inspect(hit_pos))
			--sys.log("hit_pos2 = "..inspect(hit_pos2))
			--sys.log("vector3.distance(hit_pos, hit_pos2) = "..vector3.distance(hit_pos, hit_pos2))
			rv = vector3.NewDistance(hit_pos, hit_pos2, vector3.distance(hit_pos, hit_pos2)*0.9)
		end

		--return result
		return rv
	end,
	PathOptimazation = function(self, path, mode)
		log("We check whether there are direct shortcuts to the ship in the routes.")
		--We check whether there are direct shortcuts to the ship in the routes.
		--sys.log("self.data.new_path = "..inspect(self.data.new_path))
		for i = #path, 1, -1 do
			--We get the intersection
			log("We get the intersection")
			log("i(path) = "..i)
			local ent, hit_pos, normal, material =  self:TraceLine_TP_ENT(path[i], self.data.My_Ent)
			if not hit_pos then
				for j = 1, i-1 do
					table.remove(path, 1)
				end
				break
			end
		end
		--Makes a full path optimization and indicate which points are optimized
		--To reduce the load of CheckObstacles() calls
		--[[
		local i = 1
		while i < #path do
			log("i(while) = "..i)
			if not path[i].TruePoint then 
				for j = #path, 1, -1 do
					local ent, hit_pos, normal, material =  self:TraceLine_TP_TP(path[i], path[j])
					if not ent then
						
						for k = 1, j-i do
							table.remove(path, i+1)
						end
						break
					end
				end
				if not mode then
					path[i].TruePoint = true
				end
			end
			i = i + 1
		end
		]]
	end,
	IsPathUpdateNeeded = function(self) --The function considers whether it is necessary to update the current route with a new one
		log("The function considers whether it is necessary to update the current route with a new one")
		--Count the entire length of the current route
		--sys.log("self.data.path = "..inspect(self.data.path))
		--sys.log("self.data.new_path = "..inspect(self.data.new_path))
		--sys.log("self.data.path = "..tostring(self.data.path))
		--sys.log("self.data.new_path = "..tostring(self.data.new_path))
		if #self.data.path == 0 then
			return true
		end
		local path_dis = vector3.distance(self.data.My_Pos, self.data.path[1])
		for i = 1, #self.data.path-1 do
			path_dis = path_dis + vector3.distance(self.data.path[i], self.data.path[i+1])
		end
		path_dis = path_dis + vector3.distance(self.data.Target_Vec3, self.data.path[#self.data.path])


		--Calculate the entire length of the new route
		if #self.data.new_path == 0 then
			return false
		end
		local new_path_dis = vector3.distance(self.data.My_Pos, self.data.new_path[1])
		for i = 1, #self.data.new_path-1 do
			new_path_dis = new_path_dis + vector3.distance(self.data.new_path[i], self.data.new_path[i+1])
		end
		new_path_dis = new_path_dis + vector3.distance(self.data.Target_Vec3, self.data.new_path[#self.data.new_path])
		log("new_path_dis = "..new_path_dis)
		log("path_dis = "..path_dis)
		if new_path_dis > path_dis then 
			return false--If the new path is longer than the old one, then the path does not need to be updated.
		else 
			return true--If the new path is shorter than the old one, then it needs to be updated.
		end
	end,
	OnQueue = function(self)
		--Check: "Enable" flag
		log("Check: \"Enable\" flag")
		if not self.data.enable then
			return
		end

		--Get target data: Coordinates and entity object, if any
		if self.data.Target_Ent then
			if self.data.Target_Ent:IsDead() then
				self.data.Target_Ent = nil
			end
			self.data.Target_Vec3 = self.data.Target_Ent:GetPos()
		end
		log("Get target data: Coordinates and entity object, if any")
		log("Target_Vec3 = "..inspect(self.data.Target_Vec3)..", Target_Ent = "..inspect(self.data.Target_Ent))
		--self.data.Target_Vec3, self.data.Target_Ent = self:GetTarget()
		if not self.data.Target_Vec3 and self.data.Target_Ent then
			return
		end

		log("Get the object of the controlled ship")
		self.data.My_Ent = ZAI.GetMyShip()--Get the object of the controlled ship
		log("My_Ent = "..inspect(self.data.My_Ent))
		log("Checking if the controlled ship is alive")
		if not self.data.My_Ent then--Checking if the controlled ship is alive
			return
		end
		log("Getting the coordinates of the controlled ship")
		self.data.My_Pos = ZAI.GetMyShip():GetPos()--Getting the coordinates of the controlled ship
		log("My_Pos = "..inspect(self.data.My_Pos))

		--log("List of collisions that should be ignored in path tracing")
		--log("IgnoreList = "..inspect(IgnoreList))
		local IgnoreList = {self.data.My_Ent, self.data.Target_Ent} --List of collisions that should be ignored in path tracing
		local ent, hit_pos, normal, material = false
		if self.data.Target_Ent then
			ent, hit_pos, normal, material =  self:TraceLine_ENT_ENT(self.data.My_Ent, self.data.Target_Ent)
		else
			ent, hit_pos, normal, material =  self:TraceLine_ENT_P(self.data.My_Ent, self.data.Target_Vec3)
		end

		log("Check if there are obstacles")
		if ent then --Check if there are obstacles
			log("Reset the path if there are new obstacles")
			--Reset the path if there are new obstacles
			if not self:CheckObstacles_Path() then
				log("CheckObstacles_Path")
				self:Reset_Path()
			end
			if not self:CheckObstacles_NewPath() then
				log("CheckObstacles_NewPath")
				self:Reset_NewPath()
			end
			local NewPathCompleted = false
			for i = #self.data.new_path+1, #self.data.new_path+10 do
				log("If the scan is too long, then reset the 'timer' and 'new_path'")
				if #self.data.new_path > self.data.max_path then
					self:PathUpdate()
					break
				end
				if self:CheckTimeLimit() then --If the scan is too long, then reset the timer and new_path
					log("When the scan has been too long, chances are it's better to replace the old path with the new one even though it's not complete.")
					if self:IsForceUpdateNeeded() then--When the scan has been too long, chances are it's better to replace the old path with the new one even though it's not complete.
						self:PathUpdate()
					end
					log("П.С. Сбросс таймера происходит внутри этой функции")
					self:Reset_NewPath()--P.S. Resetting the timer happens inside this function
					break
				end
				--get a reflection point
				log("get a reflection point")
				local ReflectPoint = self:GetReflectPoint(i)
				log("ReflectPoint = "..inspect(ReflectPoint))

				if ReflectPoint then
					--Adding a point to the new_path array
					log("Adding a point to the new_path array")
					self:AddNewPoint(self.data.new_path, ReflectPoint)
				else
					--Массив new_path завершен
					log("new_path array completed")
					NewPathCompleted = true
					break
				end
			end
			log("#self.data.new_path = "..#self.data.new_path)
			--self:RenderNewPath()
			self:PathOptimazation(self.data.path)
			if NewPathCompleted then
				log("We reduce (optimize) routes as much as possible")
				self:PathOptimazation(self.data.new_path)--We reduce (optimize) routes as much as possible
				log("Checking which route is best")
				if self:IsPathUpdateNeeded() then--Checking which route is best
					log("route updated")
					self:PathUpdate()
				else
					log("the old route is better")
					self:Reset_NewPath()
				end
			else
				self:PathOptimazation(self.data.new_path, true)
			end
		else
			log("We reset the past paths, since at the moment there are no obstacles")
			--We reset the past paths, since at the moment there are no obstacles
			self:Reset_Path()
			self:Reset_NewPath()
		end

		--log("Отрисовка путей для отладки")
		--Drawing paths for debugging
		if self.data.render_path then
			--self:RenderCurrentPath()
		end
		if self.data.render_new_path then
			--self:RenderNewPath()
		end
	end,
	SetTarget_Vec3 = function(self, point)
		self.data.Target_Vec3 = point
	end,
	SetTarget_Ent = function(self, ent)
		self.data.Target_Ent = ent
	end,
}