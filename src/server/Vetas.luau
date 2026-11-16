--[[
	Vetas de minerales, con protección contra xray: las piezas solo existen como
	datos en el servidor hasta que la roca a su alrededor se abre (picando o con
	dinamita). Recién ahí se crea la parte en workspace.Minerales, así que un
	cliente no puede saber dónde hay minerales mirando a través de la roca.

	Cada pieza visible es una parte con el atributo "Mineral" (id de
	Config.Minerales). Se pica manteniendo el clic (ver PicoService).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Vetas = {}

local Terrain = workspace.Terrain
local CELDA = 16 -- tamaño de las celdas para buscar piezas cerca de un punto

type Pieza = { id: string, cf: CFrame, tam: Vector3, brillo: boolean, visible: boolean }

local piezas: { Pieza } = {}
local celdas: { [string]: { Pieza } } = {}
local carpeta: Folder

local function clave(x: number, y: number, z: number): string
	return x .. "," .. y .. "," .. z
end

local function celdaDe(p: Vector3): (number, number, number)
	return math.floor(p.X / CELDA), math.floor(p.Y / CELDA), math.floor(p.Z / CELDA)
end

-- Material del terreno en el vóxel que contiene un punto.
local function materialEn(p: Vector3): Enum.Material
	local mats = Terrain:ReadVoxels(Region3.new(p, p):ExpandToGrid(4), 4)
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

-- La pieza tiene aire (o roca a medio picar) alrededor: ya se ve.
local function expuesta(pz: Pieza): boolean
	local r = math.max(pz.tam.X, pz.tam.Y, pz.tam.Z) / 2 + 2.5
	local pos = pz.cf.Position
	local region = Region3.new(pos - Vector3.one * r, pos + Vector3.one * r):ExpandToGrid(4)
	local _, occs = Terrain:ReadVoxels(region, 4)
	local tam = occs.Size
	for x = 1, tam.X do
		for y = 1, tam.Y do
			for z = 1, tam.Z do
				if occs[x][y][z] < 0.5 then
					return true
				end
			end
		end
	end
	return false
end

local function mostrar(pz: Pieza)
	pz.visible = true
	local info = Config.Minerales[pz.id]
	local p = Instance.new("Part")
	p.Name = pz.id
	p.Anchored = true
	p.CanCollide = true
	p.CastShadow = false
	p.Size = pz.tam
	p.CFrame = pz.cf
	p.Color = info.Color
	p.Material = info.Material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Mineral", pz.id)
	if pz.brillo then
		local luz = Instance.new("PointLight")
		luz.Color = info.Color
		luz.Range = 8
		luz.Brightness = 0.8
		luz.Parent = p
	end
	p.Parent = carpeta
end

-- Crea los datos de todas las vetas (no las muestra). Devuelve cuántas piezas hay.
function Vetas.Generar(destino: Folder): number
	carpeta = destino
	carpeta:ClearAllChildren()
	table.clear(piezas)
	table.clear(celdas)
	local rng = Random.new()
	local m = Config.Mapa
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
				for n = 1, rng:NextInteger(3, 6) do
					local offset = rng:NextUnitVector() * rng:NextNumber(0, 2.6)
					local giro = CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
					local t = rng:NextNumber(1.5, 2.4)
					local pz: Pieza = {
						id = id,
						cf = CFrame.new(centro + offset) * giro,
						tam = Vector3.new(t, t * 0.8, t),
						brillo = info.Brillo == true and n == 1,
						visible = false,
					}
					table.insert(piezas, pz)
					local k = clave(celdaDe(pz.cf.Position))
					celdas[k] = celdas[k] or {}
					table.insert(celdas[k], pz)
				end
			end
			if i % 40 == 0 then
				task.wait()
			end
		end
	end
	return #piezas
end

-- Muestra las piezas que quedaron a la vista cerca de un punto (después de picar
-- o de una explosión).
function Vetas.Revelar(centro: Vector3, radio: number)
	local alcance = radio + 4
	local x0, y0, z0 = celdaDe(centro - Vector3.one * alcance)
	local x1, y1, z1 = celdaDe(centro + Vector3.one * alcance)
	for x = x0, x1 do
		for y = y0, y1 do
			for z = z0, z1 do
				local lista = celdas[clave(x, y, z)]
				if lista then
					for _, pz in lista do
						if not pz.visible and (pz.cf.Position - centro).Magnitude <= alcance and expuesta(pz) then
							mostrar(pz)
						end
					end
				end
			end
		end
	end
end

-- Al construir la mina: muestra las que ya se ven desde la rampa y la galería.
function Vetas.RevelarTodo(): number
	local n = 0
	for i, pz in piezas do
		if not pz.visible and expuesta(pz) then
			mostrar(pz)
			n += 1
		end
		if i % 150 == 0 then
			task.wait()
		end
	end
	return n
end

return Vetas
