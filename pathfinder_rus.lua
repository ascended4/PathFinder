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
			path_limit = 2000, --милисекунды
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
		--Метатаблица эта костыль. Автор моя лень.
		--Суть в том что она нужна для того что бы записывать куда нибудь инфу о том является ли точка хламовой или нет.
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
	CheckObstacles_Path = function(self) --Возвращает true если новый препятсвий не появилось
		if self.data.path[1] then --Проверка есть ли в "path" какие либо даныне

			--Проверяем появились ли новые препятствия между My_Pos и началом маршрута path
			local ent, hit_pos, normal = self:TraceLine_ENT_TP(self.data.My_Ent, self.data.path[1])
			if ent then
				return false
			end

			--Проверяем появились ли новые препятствия между Target_Vec3 и концом маршрута path
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

			--Проверяем (нужно что-то с этим делать, слишком жирно под это говно выделять столько ресурсов)
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
	CheckObstacles_NewPath = function(self) --Возвращает true если новый препятсвий не появилось
		if self.data.new_path[1] then --Проверка есть ли в "new_path" какие либо даныне

			--Проверяем появились ли новые препятствия между My_Pos и началом маршрута path
			local ent, hit_pos, normal =  self:TraceLine_ENT_TP(self.data.My_Ent, self.data.new_path[1])
			if ent then
				return false
			end

			--Проверяем (нужно что-то с этим делать, слишком жирно под это говно выделять столько ресурсов)
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
				--log("Отрисовка линий маршрута path")
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
				--log("Отрисовка линий маршрута new_path")
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
	CheckTimeLimit = function(self)--Проверка времени таймера
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
	ResetTimeLimit = function(self) --Сбросс Таймера
		--sys.log("Сбросс Таймера")
		self:UpdateNormalLength()--Обновляем длину нормали подставляя радиус управляемого корабля
		self.data.time.path_scan = tonumber(U64ToStr(GetU64Time()))
		--sys.log("tonumber(U64ToStr(GetU64Time())) = "..tonumber(U64ToStr(GetU64Time())))
		--sys.log("self.data.time.path_scan = "..self.data.time.path_scan)
	end,
	IsForceUpdateNeeded = function(self)
		--Проверка нужно ли срочно заменять старый путь.
		--В зависимоти от дистанции между самой близкой точки полёта и управляемого корабля
		if vector3.distance(self.data.My_Pos, self:GetFlyPoint()) < 50.0 then --Если дистанция меньще 500 метров то да
			return true
		else
			return false
		end
		--П.С. Эта функция будет вызывается лишь в том случае когда времени на завершение new_path не хватает
	end,
	PathUpdate = function(self)
		self.data.path = self.data.new_path
		self:Reset_NewPath()
	end,
	TransformNormal = function(self, normal, StartPoint, hit_pos)
		--sys.log("TransformNormal("..inspect(normal)..","..inspect(StartPoint)..","..inspect(hit_pos))
		--Сокращаем нормаль до некого значения и регистрируем её
		local normal_string = round(normal.x, 1)..","..round(normal.y, 1)..","..round(normal.z, 1)
		if not self.data.normal_buffer[normal_string] then
			self.data.normal_buffer[normal_string] = {
				count = 0,
				normal = Vec3(0,0,0),
			}
		end
		self.data.normal_buffer[normal_string].count = self.data.normal_buffer[normal_string].count + 1
		--Есть 2 режима:
		--По умолчанию: Обход астероидов. нужно просто подправить длину под ширину корабля
		if self.data.normal_buffer[normal_string].count < 5 then
			--TODO: Подключить функцию по отражению через вектор луча, точку и нормаль.
			--Тогда здесь уменьшится в 2 раза количество точек и вызовов трасировки
			return vector3.NewDistance(Vec3(0,0,0), normal, self.data.normal_length+(0.1*#self.data.new_path))
		else --Обход препятсвий с прямыми углами. Включается в том случае если одна и та жа нормаль попадается уже несколько раз
			if vector3.equal(self.data.normal_buffer[normal_string].normal, Vec3(0,0,0)) then--Создаём нормаль которая будет паралельна поверхности
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
		--Получаем пересечение
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

		
		
		--Если нет пересечений, значит возвращаем nil
		if not ent then
			return
		end

		--Создаём нормаль
		--Трансформируем нормаль через функцию TransformNormal()
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
		--результат = Новая нормаль + точка пересечение
		local rv = normal+hit_pos

		--Проверяем что отражение от препятствия не вошло во внутрь другого препятствия
		local ent2, hit_pos2, normal2, material2 =  self:TraceLine(hit_pos, rv)
		if ent2 then
			-- нужно урезать нормаль
			--sys.log("hit_pos = "..inspect(hit_pos))
			--sys.log("hit_pos2 = "..inspect(hit_pos2))
			--sys.log("vector3.distance(hit_pos, hit_pos2) = "..vector3.distance(hit_pos, hit_pos2))
			rv = vector3.NewDistance(hit_pos, hit_pos2, vector3.distance(hit_pos, hit_pos2)*0.9)
		end

		--возвращаем результат
		return rv
	end,
	PathOptimazation = function(self, path, mode)
		log("Проверяем есть в маршруты прямые сокращения к кораблю.")
		--Проверяем есть в маршруты прямые сокращения к кораблю.
		--sys.log("self.data.new_path = "..inspect(self.data.new_path))
		for i = #path, 1, -1 do
			--Получаем пересечение
			log("Получаем пересечение")
			log("i(path) = "..i)
			local ent, hit_pos, normal, material =  self:TraceLine_TP_ENT(path[i], self.data.My_Ent)
			if not hit_pos then
				for j = 1, i-1 do
					table.remove(path, 1)
				end
				break
			end
		end
		--Делает полную оптимизацию путя и обозначить какие точки оптимизированы
		--Что бы уменьшить нагрузку вызовов CheckObstacles()
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
	IsPathUpdateNeeded = function(self) --Функция считает нужно ли обновлять текущий маршрут на новый
		log("Функция считает нужно ли обновлять текущий маршрут на новый")
		--Считаем всю длинну текущего маршрута
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


		--Считаем всю длинну нового маршрута
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
			return false--Если новый путь длинее старого, то путь обновлять ненужно
		else 
			return true--Если новый путь короче старого, то его нужно обновить
		end
	end,
	OnQueue = function(self)
		--Проверка: флаг "Включения"
		log("Проверка: флаг \"Включения\"")
		if not self.data.enable then
			return
		end

		--Получаем данные цели: Координаты и объект сущности если таковой есть
		if self.data.Target_Ent then
			if self.data.Target_Ent:IsDead() then
				self.data.Target_Ent = nil
			end
			self.data.Target_Vec3 = self.data.Target_Ent:GetPos()
		end
		log("Получаем данные цели: Координаты и объект сущности если таковой есть")
		log("Target_Vec3 = "..inspect(self.data.Target_Vec3)..", Target_Ent = "..inspect(self.data.Target_Ent))
		--self.data.Target_Vec3, self.data.Target_Ent = self:GetTarget()
		if not self.data.Target_Vec3 and self.data.Target_Ent then
			return
		end

		log("Получаем объект управляемого корабля")
		self.data.My_Ent = ZAI.GetMyShip()--Получаем объект управляемого корабля
		log("My_Ent = "..inspect(self.data.My_Ent))
		log("Проверка: жив ли управляемый корабль")
		if not self.data.My_Ent then--Проверка: жив ли управляемый корабль
			return
		end
		log("Получаем координаты управляемого корабля")
		self.data.My_Pos = ZAI.GetMyShip():GetPos()--Получаем координаты управляемого корабля
		log("My_Pos = "..inspect(self.data.My_Pos))

		--log("Список коллизий который должны будут игнорироватся при трасировке путей")
		--log("IgnoreList = "..inspect(IgnoreList))
		local IgnoreList = {self.data.My_Ent, self.data.Target_Ent} --Список коллизий который должны будут игнорироватся при трасировке путей
		local ent, hit_pos, normal, material = false
		if self.data.Target_Ent then
			ent, hit_pos, normal, material =  self:TraceLine_ENT_ENT(self.data.My_Ent, self.data.Target_Ent)
		else
			ent, hit_pos, normal, material =  self:TraceLine_ENT_P(self.data.My_Ent, self.data.Target_Vec3)
		end

		log("Проверяем есть ли препятсвие")
		if ent then --Проверяем есть ли препятсвие
			log("Сброс пути если появились новые препятствия")
			--Сброс пути если появились новые препятствия
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
				log("Если сканирование слишком долгое, то произвести сброс таймера и new_path")
				if #self.data.new_path > self.data.max_path then
					self:PathUpdate()
					break
				end
				if self:CheckTimeLimit() then --Если сканирование слишком долгое, то произвести сброс таймера и new_path
					log("Когда сканирование было слишком долгим есть вероятность что лучше заменить старый путь на новый хоть он и не завершен.")
					if self:IsForceUpdateNeeded() then--Когда сканирование было слишком долгим есть вероятность что лучше заменить старый путь на новый хоть он и не завершен.
						self:PathUpdate()
					end
					log("П.С. Сбросс таймера происходит внутри этой функции")
					self:Reset_NewPath()--П.С. Сбросс таймера происходит внутри этой функции
					break
				end
				--получаем точку отражения
				log("получаем точку отражения")
				local ReflectPoint = self:GetReflectPoint(i)
				log("ReflectPoint = "..inspect(ReflectPoint))

				--Если точки нету, то путь завершен и нужно 
				log("Если точки нету, то путь завершен и нужно ")
				if ReflectPoint then
					--Добавляем точку в массив new_path
					log("Добавляем точку в массив new_path")
					self:AddNewPoint(self.data.new_path, ReflectPoint)
				else
					--Массив new_path завершен
					log("Массив new_path завершен")
					NewPathCompleted = true
					break
				end
			end
			log("#self.data.new_path = "..#self.data.new_path)
			--self:RenderNewPath()
			self:PathOptimazation(self.data.path)
			if NewPathCompleted then
				log("По возможности сокращаем(оптимизируем) маршруты")
				self:PathOptimazation(self.data.new_path)--По возможности сокращаем(оптимизируем) маршруты
				log("Проверяем какой маршрут лучше")
				if self:IsPathUpdateNeeded() then--Проверяем какой маршрут лучше
					log("маршрут обновлён")
					self:PathUpdate()
				else
					log("старый маршут лучше")
					self:Reset_NewPath()
				end
			else
				self:PathOptimazation(self.data.new_path, true)
			end
		else
			log("Сбрасываем прошлые пути так как на данный момент препятствий нету")
			--Сбрасываем прошлые пути так как на данный момент препятствий нету
			self:Reset_Path()
			self:Reset_NewPath()
		end

		--log("Отрисовка путей для отладки")
		--Отрисовка путей для отладки
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