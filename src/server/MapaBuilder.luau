--[[
	Construye el mapa al arrancar el servidor (alta montaña helada):
	  - un valle de tierra y nieve para el campamento, rodeado de cerros
	  - al norte, el cerro de la mina: acantilado de roca con nieve y glaciar arriba
	  - bajo tierra, la mina: capas por profundidad y manchas de roca imposible
	  - la rampa baja desde el valle y entra al acantilado por un marco de madera
	  - cielo frío, punto de aparición y fogata
	Solo se pica dentro de la zona de la mina (ver PicoService); los cerros se ven.
	Quita la Baseplate y el SpawnLocation de la plantilla.
]]

local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Vetas = require(script.Parent.Vetas)
local Pueblo = require(script.Parent.Pueblo)

local MapaBuilder = {}

local Terrain = workspace.Terrain
local M = Config.Mapa
local C = Config.Montanas

local MADERA = Color3.fromRGB(110, 76, 46)
local FAROL = Color3.fromRGB(255, 170, 70)

local function bloque(minV: Vector3, maxV: Vector3, material: Enum.Material)
	Terrain:FillBlock(CFrame.new((minV + maxV) / 2), maxV - minV, material)
end

local function parte(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function farol(pos: Vector3, parent: Instance)
	local f = parte({
		Name = "Farol",
		Size = Vector3.new(0.7, 1, 0.7),
		Position = pos,
		Color = FAROL,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, parent)
	local luz = Instance.new("PointLight")
	luz.Color = FAROL
	luz.Range = 12
	luz.Brightness = 0.9
	luz.Shadows = true
	luz.Parent = f
	return f
end

local function suave(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Altura del terreno (sobre el suelo del valle) en cada punto del mundo:
--   valle plano -> cresta que se puede trepar (la pared invisible está encima)
--   -> afuera, una meseta más baja -> a lo lejos, la cordillera.
-- Al norte está el cerro de la mina, con su acantilado y el glaciar.
function MapaBuilder.Altura(x: number, z: number): number
	-- El valle es una elipse, más corta hacia el norte.
	local zz = if z > 0 then z * 1.6 else z
	local d = math.sqrt(x * x + zz * zz)
	-- Cresta alrededor del valle.
	local h = C.AltoCresta * math.exp(-((d - C.RadioCresta) / C.AnchoCresta) ^ 2) * suave((d - C.RadioValle) / 30)
	-- Afuera: meseta más baja con lomas suaves.
	local afuera = suave((d - C.RadioCresta - 30) / 70)
	h += afuera * (math.noise(x / 70, z / 70, 4.4) * 10 - C.HondoMeseta)
	-- Lejos: la cordillera.
	local cordillera = 1 - math.abs(math.noise(x / 260, z / 260, 8.8))
	h += suave((d - C.RadioLejos) / 320) * C.AltoLejos * (0.4 + 0.6 * cordillera * cordillera)
	-- Cerro de la mina al norte: acantilado y cumbre con glaciar.
	if z > C.AcantiladoZ then
		local subida = suave((z - C.AcantiladoZ) / 24)
		local ancho = suave(1 - (math.abs(x) - 70) / 60)
		local cumbre = math.exp(-((x - 10) ^ 2 + (z - 150) ^ 2) / (2 * 75 ^ 2)) * C.AlturaCumbre
		h = math.max(h, subida * ancho * (C.AlturaAcantilado + cumbre))
	end
	-- Crestas y picos: solo en los cerros; el valle y la meseta quedan lisos.
	-- Junto a la boca de la mina el acantilado queda liso, para que la rampa
	-- siempre entre bajo techo de roca.
	local boca = suave((math.sqrt(x * x + (z - 40) ^ 2) - 16) / 22)
	-- La cresta del valle va más lisa (para ver el paisaje por encima); el cerro
	-- de la mina y la cordillera, con todos sus picos.
	local enCresta = math.exp(-((d - C.RadioCresta) / (C.AnchoCresta * 1.5)) ^ 2)
	local deMina = if z > C.AcantiladoZ then suave(1 - (math.abs(x) - 70) / 60) else 0
	local rugosidad = 1 - 0.7 * enCresta * (1 - deMina)
	local cerro = math.clamp(h / 25, 0, 1) * boca * rugosidad
	local cresta = 1 - math.abs(math.noise(x / 70, z / 70, 2.1))
	local cresta2 = 1 - math.abs(math.noise(x / 26, z / 26, 6.3))
	local ruido = math.noise(x / 90, z / 90, 1.7)
	h += (cresta * cresta * 50 + cresta2 * cresta2 * 14 + ruido * 18 - 24) * cerro
	return h
end

-- Material de la superficie según la altura y la pendiente.
local function materialArriba(x: number, z: number, h: number, pendiente: number): Enum.Material
	if h < 2 then
		-- Suelo del valle y de la meseta: tierra con manchas de nieve.
		local n = math.noise(x / 24, z / 24, 9.1) + math.noise(x / 9, z / 9, 2.4) * 0.3
		return if n > 0.15 then Enum.Material.Snow else Enum.Material.Ground
	end
	-- En las paredes empinadas la nieve no se queda: roca desnuda.
	if pendiente > 1.8 then
		return Enum.Material.Rock
	end
	if h > C.GlaciarDesde + math.noise(x / 40, z / 40, 5.5) * 12 then
		return Enum.Material.Glacier
	end
	if h > C.NieveDesde + math.noise(x / 50, z / 50, 3.3) * 16 then
		return Enum.Material.Snow
	end
	return Enum.Material.Rock
end

-- Escribe todo el terreno de la superficie en trozos de 64 × 64 studs.
-- En el núcleo (valle y mina) se llena desde y = -4; afuera, donde nadie llega,
-- solo una cáscara bajo la superficie, para que sea liviano.
local function cerros()
	local TROZO = 64
	local n = TROZO // 4
	local W = M
	local inicio = os.clock()
	for cx = W.MundoMin.X, W.MundoMax.X - 1, TROZO do
		for cz = W.MundoMin.Y, W.MundoMax.Y - 1, TROZO do
			local nucleo = cx >= M.SueloMin.X and cx < M.SueloMax.X and cz >= M.SueloMin.Y and cz < M.SueloMax.Y
			-- Alturas con un borde de una celda, para medir la pendiente.
			local alt = {}
			for i = 0, n + 1 do
				alt[i] = {}
				for k = 0, n + 1 do
					local h = MapaBuilder.Altura(cx + (i - 0.5) * 4, cz + (k - 0.5) * 4)
					alt[i][k] = if nucleo then math.max(h, 0) else h
				end
			end
			local bajo = table.create(n)
			local yMin, yMax = math.huge, -math.huge
			for i = 1, n do
				bajo[i] = table.create(n)
				for k = 1, n do
					local h = alt[i][k]
					local b = if nucleo
						then -4
						else math.min(h, alt[i - 1][k], alt[i + 1][k], alt[i][k - 1], alt[i][k + 1]) - 8
					bajo[i][k] = b
					yMin = math.min(yMin, b)
					yMax = math.max(yMax, h)
				end
			end
			local Y0 = math.floor(yMin / 4) * 4
			local ny = math.ceil((yMax - Y0) / 4) + 1
			local mats, occs = table.create(n), table.create(n)
			for i = 1, n do
				mats[i], occs[i] = table.create(ny), table.create(ny)
				for j = 1, ny do
					mats[i][j], occs[i][j] = table.create(n), table.create(n)
				end
				local x = cx + (i - 0.5) * 4
				for k = 1, n do
					local z = cz + (k - 0.5) * 4
					local h = alt[i][k]
					local pendiente = math.max(
						math.abs(alt[i + 1][k] - h),
						math.abs(alt[i - 1][k] - h),
						math.abs(alt[i][k + 1] - h),
						math.abs(alt[i][k - 1] - h)
					) / 4
					local arriba = materialArriba(x, z, h, pendiente)
					local b = bajo[i][k]
					for j = 1, ny do
						local base = Y0 + (j - 1) * 4 -- piso de la celda
						local lleno = math.clamp((h - base) / 4, 0, 1)
						if nucleo and base == -4 then
							lleno = 1 -- el suelo del valle (y el techo de la mina) siempre lleno
						elseif base + 4 <= b then
							lleno = 0 -- debajo de la cáscara: vacío
						end
						if lleno < 0.05 then
							mats[i][j][k], occs[i][j][k] = Enum.Material.Air, 0
						else
							mats[i][j][k] = if h - base < 6 then arriba else Enum.Material.Rock
							occs[i][j][k] = lleno
						end
					end
				end
			end
			local region = Region3.new(Vector3.new(cx, Y0, cz), Vector3.new(cx + TROZO, Y0 + ny * 4, cz + TROZO))
			Terrain:WriteVoxels(region, 4, mats, occs)
			if os.clock() - inicio > 0.05 then
				task.wait()
				inicio = os.clock()
			end
		end
	end
end

-- Pared invisible sobre la cresta: se ve el mundo de afuera, pero no se sale.
local function muro(carpeta: Instance)
	local pared = Instance.new("Folder")
	pared.Name = "ParedInvisible"
	local LADOS = 96
	local function punto(i: number): Vector3
		local a = i / LADOS * math.pi * 2
		local x, z = math.cos(a) * C.RadioMuro, math.sin(a) * C.RadioMuro
		if z > 0 then
			z /= 1.6 -- la misma elipse que el valle
		end
		return Vector3.new(x, 0, z)
	end
	for i = 0, LADOS - 1 do
		local a, b = punto(i), punto(i + 1)
		local p = Instance.new("Part")
		p.Name = "Pared"
		p.Anchored = true
		p.CanCollide = true
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(4, 800, (b - a).Magnitude + 2)
		p.CFrame = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 400, 0), (b + a) / 2 + (b - a) + Vector3.new(0, 400, 0))
		p.Parent = pared
	end
	pared.Parent = carpeta
end

local function terreno()
	Terrain:Clear()
	Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(112, 110, 108))
	Terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(96, 84, 72))
	Terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(236, 242, 248))
	Terrain:SetMaterialColor(Enum.Material.Glacier, Color3.fromRGB(170, 214, 240))
	Terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(72, 76, 86))
	Terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(30, 30, 34))
	local sMin, sMax = M.SueloMin, M.SueloMax
	-- Roca imposible bajo todo el mapa.
	bloque(Vector3.new(sMin.X, M.FondoBasalto, sMin.Y), Vector3.new(sMax.X, -4, sMax.Y), Config.RocaImposible)
	task.wait()
	-- Capas de la mina.
	for _, capa in Config.Capas do
		bloque(
			Vector3.new(M.MinaMin.X, capa.Abajo, M.MinaMin.Z),
			Vector3.new(M.MinaMax.X, capa.Arriba, M.MinaMax.Z),
			capa.Material
		)
	end
	task.wait()
	-- Manchas de roca imposible.
	local rng = Random.new()
	local rMin, rMax = Config.RadioManchaBasalto[1], Config.RadioManchaBasalto[2]
	for _ = 1, Config.ManchasBasalto do
		local centro = Vector3.new(
			rng:NextNumber(M.MinaMin.X, M.MinaMax.X),
			rng:NextNumber(M.MinaMin.Y + 6, M.MinaMax.Y - 10),
			rng:NextNumber(M.MinaMin.Z + 30, M.MinaMax.Z)
		)
		Terrain:FillBall(centro, rng:NextNumber(rMin, rMax), Config.RocaImposible)
	end
	task.wait()
	-- Suelo del valle y cerros encima.
	cerros()
end

-- Entrada: un tramo plano a nivel del valle hasta la cara del acantilado (con
-- el marco de madera) y, ya dentro del cerro, la rampa que baja a la galería.
local function entrada(carpeta: Folder)
	local a, b = M.Entrada, M.FondoRampa
	local alto = 12
	local plano = Vector3.new(a.X, alto / 2, (M.BocaZ - 12 + a.Z + 2) / 2)
	Terrain:FillBlock(CFrame.new(plano), Vector3.new(12, alto, a.Z + 2 - (M.BocaZ - 12)), Enum.Material.Air)
	local largo = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	Terrain:FillBlock(cf * CFrame.new(0, alto / 2, 0), Vector3.new(12, alto, largo + 6), Enum.Material.Air)
	-- Galería de inicio: un cuarto amplio para empezar a picar.
	local galeria = Vector3.new(b.X, b.Y + 6, b.Z + 10)
	Terrain:FillBlock(CFrame.new(galeria), Vector3.new(24, 12, 20), Enum.Material.Air)

	-- Marco de madera en la cara del acantilado, a nivel del valle.
	local piso = Vector3.new(a.X, M.Suelo, M.BocaZ)
	local marco = Instance.new("Model")
	marco.Name = "BocaMina"
	for _, x in { -5.2, 5.2 } do
		parte({
			Name = "Poste",
			Size = Vector3.new(1.2, 12, 1.2),
			Position = piso + Vector3.new(x, 5, 0),
			Color = MADERA,
			Material = Enum.Material.Wood,
		}, marco)
	end
	parte({
		Name = "Viga",
		Size = Vector3.new(12.8, 1.2, 1.4),
		Position = piso + Vector3.new(0, 10.6, 0),
		Color = MADERA,
		Material = Enum.Material.Wood,
	}, marco)
	local letrero = parte({
		Name = "Letrero",
		Size = Vector3.new(10, 2.6, 0.4),
		Position = piso + Vector3.new(0, 12.6, -1.2),
		Color = Color3.fromRGB(70, 48, 30),
		Material = Enum.Material.Wood,
	}, marco)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0 -- el texto se ve aunque esté a la sombra
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = letrero
	local texto = Instance.new("TextLabel")
	texto.Size = UDim2.fromScale(1, 1)
	texto.BackgroundTransparency = 1
	texto.Text = "⛏ MINA ⛏"
	texto.Font = Enum.Font.FredokaOne
	texto.TextScaled = true
	texto.TextColor3 = Color3.fromRGB(255, 214, 120)
	texto.Parent = gui
	farol(piso + Vector3.new(-5.2, 8.6, -1), marco)
	farol(piso + Vector3.new(5.2, 8.6, -1), marco)
	marco.Parent = carpeta

	-- Faroles en la pared de la rampa y en la galería.
	local luces = Instance.new("Folder")
	luces.Name = "Faroles"
	for _, f in { 0.62, 0.88 } do
		local p = a:Lerp(b, f)
		farol(p + Vector3.new(-4.2, 5, 0), luces)
	end
	farol(galeria + Vector3.new(-10.5, 0, -8), luces)
	farol(galeria + Vector3.new(10.5, 0, -8), luces)
	luces.Parent = carpeta
end

-- Luz fría de puna: sol bajo, cielo nublado y bruma.
-- La mina queda oscura sola: Ambient (la luz de los lugares tapados del cielo) es
-- negro y la luz del entorno está apagada, así que bajo la roca solo alumbran las
-- lámparas y los faroles. El cielo y el valle no cambian nunca.
local function cielo()
	Lighting.ClockTime = 15.2
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.new(0, 0, 0)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 152, 172)
	Lighting.ColorShift_Top = Color3.fromRGB(205, 220, 240)
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.ExposureCompensation = 0
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atm.Density = 0.36
	atm.Offset = 0.12
	atm.Color = Color3.fromRGB(205, 216, 230)
	atm.Decay = Color3.fromRGB(118, 134, 160)
	atm.Glare = 0.15
	atm.Haze = 1.6
	atm.Parent = Lighting
	local nubes = Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	nubes.Cover = 0.72
	nubes.Density = 0.55
	nubes.Color = Color3.fromRGB(232, 236, 242)
	nubes.Parent = Terrain
end

local function campamento(carpeta: Folder)
	for _, d in workspace:GetChildren() do
		if d:IsA("SpawnLocation") or (d.Name == "Baseplate" and d:IsA("BasePart")) then
			d:Destroy()
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Aparicion"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(10, 1, 10)
	-- Girado para que al aparecer mires hacia la mina (+z).
	spawn.CFrame = CFrame.new(M.Aparicion + Vector3.new(0, M.Suelo + 0.5, 0)) * CFrame.Angles(0, math.pi, 0)
	spawn.Color = MADERA
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Duration = 0
	spawn.Parent = carpeta

	-- Fogata entre el campamento y la mina.
	local fogata = Instance.new("Model")
	fogata.Name = "Fogata"
	local centro = M.Aparicion + Vector3.new(0, M.Suelo, 14)
	for i = 0, 3 do
		local tronco = parte({
			Name = "Tronco",
			Size = Vector3.new(0.8, 0.8, 4),
			Color = MADERA,
			Material = Enum.Material.Wood,
		}, fogata)
		tronco.CFrame = CFrame.new(centro + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, i * math.pi / 4, 0)
	end
	local brasa = parte({
		Name = "Brasa",
		Size = Vector3.new(1.6, 0.4, 1.6),
		Position = centro + Vector3.new(0, 0.9, 0),
		Color = FAROL,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, fogata)
	local fuego = Instance.new("Fire")
	fuego.Size = 5
	fuego.Heat = 8
	fuego.Parent = brasa
	local luz = Instance.new("PointLight")
	luz.Color = FAROL
	luz.Range = 18
	luz.Brightness = 1.5
	luz.Parent = brasa
	fogata.Parent = carpeta
end

-- Devuelve las carpetas del mapa: { mapa, minerales }.
function MapaBuilder.Build()
	local mapa = Instance.new("Folder")
	mapa.Name = "Mapa"
	mapa.Parent = workspace

	cielo()
	terreno()
	entrada(mapa)
	campamento(mapa)
	muro(mapa)
	Pueblo.Build(mapa)

	local minerales = Instance.new("Folder")
	minerales.Name = "Minerales"
	minerales.Parent = workspace
	local total = Vetas.Generar(minerales)
	local visibles = Vetas.RevelarTodo()
	print(string.format("[Fiebre Minera] Mina lista con %d piezas de mineral (%d a la vista)", total, visibles))

	return { mapa = mapa, minerales = minerales }
end

return MapaBuilder
