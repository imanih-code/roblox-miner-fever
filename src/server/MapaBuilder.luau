--[[
	Construye el mapa al arrancar el servidor:
	  - suelo de pasto del campamento (no se pica) sobre roca imposible
	  - la mina: bloque de terreno con capas por profundidad y manchas de basalto
	  - la boca de la mina con su rampa y una galería de inicio, con faroles
	  - el punto de aparición y una fogata en el campamento
	Quita la Baseplate y el SpawnLocation de la plantilla.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Vetas = require(script.Parent.Vetas)

local MapaBuilder = {}

local Terrain = workspace.Terrain
local M = Config.Mapa

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

local function terreno()
	-- El pasto alto (Terrain.Decoration) no se puede apagar desde un script:
	-- se apaga en Studio, en las propiedades de Terrain, y se guarda con el lugar.
	Terrain:Clear()
	local sMin, sMax = M.SueloMin, M.SueloMax
	-- Roca imposible bajo todo el mapa y pasto encima.
	bloque(Vector3.new(sMin.X, M.FondoBasalto, sMin.Y), Vector3.new(sMax.X, -4, sMax.Y), Config.RocaImposible)
	bloque(Vector3.new(sMin.X, -4, sMin.Y), Vector3.new(sMax.X, 0, sMax.Y), Enum.Material.Grass)
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
end

-- Rampa desde la boca hasta la galería de inicio.
local function entrada(carpeta: Folder)
	local a, b = M.Entrada, M.FondoRampa
	local largo = (b - a).Magnitude
	local alto = 12
	local cf = CFrame.lookAt((a + b) / 2, b)
	Terrain:FillBlock(cf * CFrame.new(0, alto / 2, 0), Vector3.new(10, alto, largo + 6), Enum.Material.Air)
	-- Galería de inicio: un cuarto amplio para empezar a picar.
	local galeria = Vector3.new(b.X, b.Y + 6, b.Z + 10)
	Terrain:FillBlock(CFrame.new(galeria), Vector3.new(24, 12, 20), Enum.Material.Air)

	-- Marco de madera en la boca.
	local marco = Instance.new("Model")
	marco.Name = "BocaMina"
	for _, x in { -5.6, 5.6 } do
		parte({
			Name = "Poste",
			Size = Vector3.new(1.2, 10, 1.2),
			Position = a + Vector3.new(x, 5, 0),
			Color = MADERA,
			Material = Enum.Material.Wood,
		}, marco)
	end
	parte({
		Name = "Viga",
		Size = Vector3.new(13.6, 1.2, 1.4),
		Position = a + Vector3.new(0, 10.4, 0),
		Color = MADERA,
		Material = Enum.Material.Wood,
	}, marco)
	local letrero = parte({
		Name = "Letrero",
		Size = Vector3.new(10, 2.6, 0.4),
		Position = a + Vector3.new(0, 12.4, 0),
		Color = Color3.fromRGB(70, 48, 30),
		Material = Enum.Material.Wood,
	}, marco)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
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
	farol(a + Vector3.new(-5.6, 8.6, -1), marco)
	farol(a + Vector3.new(5.6, 8.6, -1), marco)
	marco.Parent = carpeta

	-- Faroles en la pared de la rampa y en la galería.
	local luces = Instance.new("Folder")
	luces.Name = "Faroles"
	for _, t in { 0.35, 0.7 } do
		local p = a:Lerp(b, t)
		farol(p + Vector3.new(-4.2, 5, 0), luces)
	end
	farol(galeria + Vector3.new(-10.5, 0, -8), luces)
	farol(galeria + Vector3.new(10.5, 0, -8), luces)
	luces.Parent = carpeta
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

	terreno()
	entrada(mapa)
	campamento(mapa)

	local minerales = Instance.new("Folder")
	minerales.Name = "Minerales"
	minerales.Parent = workspace
	local total = Vetas.Generar(minerales)
	print(string.format("[Fiebre Minera] Mina lista con %d piezas de mineral", total))

	return { mapa = mapa, minerales = minerales }
end

return MapaBuilder
