--[[
	Vetas de minerales: piezas incrustadas en la roca de cada capa.
	Cada pieza es una parte con el atributo "Mineral" (id de Config.Minerales) y
	"Golpes" (los que le faltan para soltarse). Se crean al construir la mina
	y se podrán regenerar con el derrumbe.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Vetas = {}

local Terrain = workspace.Terrain

-- Material del terreno en el vóxel que contiene un punto.
local function materialEn(p: Vector3): Enum.Material
	local region = Region3.new(p, p):ExpandToGrid(4)
	local mats = Terrain:ReadVoxels(region, 4)
	return mats[1][1][1]
end

local function elegir(rng: Random, pesos: { [string]: number }): string
	local total = 0
	for _, peso in pesos do
		total += peso
	end
	local tiro = rng:NextNumber() * total
	for id, peso in pesos do
		tiro -= peso
		if tiro <= 0 then
			return id
		end
	end
	return next(pesos) :: string
end

local function pieza(id: string, cf: CFrame, tam: number): BasePart
	local info = Config.Minerales[id]
	local p = Instance.new("Part")
	p.Name = id
	p.Anchored = true
	p.CanCollide = true
	p.CastShadow = false
	p.Size = Vector3.new(tam, tam * 0.8, tam)
	p.CFrame = cf
	p.Color = info.Color
	p.Material = info.Material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Mineral", id)
	p:SetAttribute("Golpes", info.Golpes)
	return p
end

-- Llena la carpeta con vetas nuevas en todas las capas.
function Vetas.Generar(carpeta: Folder)
	carpeta:ClearAllChildren()
	local rng = Random.new()
	local m = Config.Mapa
	local total = 0
	for _, capa in Config.Capas do
		for i = 1, capa.Vetas do
			local centro = Vector3.new(
				rng:NextNumber(m.MinaMin.X + 4, m.MinaMax.X - 4),
				rng:NextNumber(capa.Abajo + 3, capa.Arriba - 3),
				rng:NextNumber(m.MinaMin.Z + 4, m.MinaMax.Z - 4)
			)
			-- Solo dentro de roca de la capa (no en basalto ni en el hueco de la entrada).
			if materialEn(centro) == capa.Material then
				local id = elegir(rng, capa.Minerales)
				local info = Config.Minerales[id]
				local veta = Instance.new("Model")
				veta.Name = "Veta" .. id
				for _ = 1, rng:NextInteger(3, 6) do
					local offset = rng:NextUnitVector() * rng:NextNumber(0, 2.6)
					local giro = CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
					local p = pieza(id, CFrame.new(centro + offset) * giro, rng:NextNumber(1.5, 2.4))
					p.Parent = veta
					total += 1
				end
				if info.Brillo then
					local luz = Instance.new("PointLight")
					luz.Color = info.Color
					luz.Range = 8
					luz.Brightness = 0.8
					luz.Parent = veta:FindFirstChildWhichIsA("BasePart")
				end
				veta.Parent = carpeta
			end
			if i % 40 == 0 then
				task.wait()
			end
		end
	end
	return total
end

return Vetas
