--[[
	El pico: lo crea, lo da a cada personaje y lleva el picado continuo.
	Mientras mantienes el clic, el cliente dice a qué apunta (unas 5 veces por
	segundo) y el servidor avanza el picado de ese objetivo:
	  - roca: un trozo (el vóxel apuntado y sus 6 vecinos) que se va achicando a
	    la vista hasta romperse; abre la roca y revela los minerales de al lado
	  - mineral: se achica y al romperse suelta una pepita (ver Pepitas)
	  - pedrusco (de una dinamita): se achica y se rompe
	Si nadie lo sigue picando, el objetivo vuelve a estar entero. Si varios pican
	el mismo, se rompe más rápido. Cada golpe (una vez por Cadencia) gasta 1 de
	durabilidad; con 0 el pico ya no pica.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Vetas = require(script.Parent.Vetas)
local Pepitas = require(script.Parent.Pepitas)

local PicoService = {}

local Terrain = workspace.Terrain
local carpetaMinerales: Folder

local ultimoMensaje: { [Player]: number } = {}
local ultimoAviso: { [Player]: number } = {}

local function aviso(player: Player, texto: string, tipo: string?)
	Remotes.Aviso:FireClient(player, texto, tipo or "info")
end

-- Aviso que no se repite más de una vez cada 2 segundos (golpes seguidos a roca dura).
local function avisoLento(player: Player, texto: string)
	local ahora = os.clock()
	if ahora - (ultimoAviso[player] or 0) >= 2 then
		ultimoAviso[player] = ahora
		aviso(player, texto, "bad")
	end
end

local function picoDe(player: Player)
	local data = PlayerData.Get(player)
	return Config.Picos[data and data.NivelPico or 1]
end

-- Herramienta ---------------------------------------------------------------------

local function crearPico(pico): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Pico"
	tool.ToolTip = pico.Nombre
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -1.4, 0) -- se agarra cerca de la punta del mango

	local mango = Instance.new("Part")
	mango.Name = "Handle"
	mango.Size = Vector3.new(0.35, 4.2, 0.35)
	mango.Color = Color3.fromRGB(120, 84, 52)
	mango.Material = Enum.Material.Wood
	mango.CanCollide = false
	mango.Massless = true
	mango.Parent = tool

	-- La cabeza tiene el color y el material de su nivel (la skin del pico).
	local cabeza = Instance.new("Part")
	cabeza.Name = "Cabeza"
	cabeza.Size = Vector3.new(0.45, 0.5, 3.2)
	cabeza.Color = pico.Color
	cabeza.Material = pico.Material
	cabeza.CanCollide = false
	cabeza.Massless = true
	cabeza.CFrame = mango.CFrame * CFrame.new(0, 1.9, 0)
	cabeza.Parent = tool
	if pico.Brillo then
		local destellos = Instance.new("Sparkles")
		destellos.SparkleColor = pico.Color
		destellos.Parent = cabeza
		local luz = Instance.new("PointLight")
		luz.Color = pico.Color
		luz.Range = 6
		luz.Brightness = 0.8
		luz.Parent = cabeza
	end
	for _, z in { -1.75, 1.75 } do
		local punta = Instance.new("WedgePart")
		punta.Name = "Punta"
		punta.Size = Vector3.new(0.35, 0.45, 0.6)
		punta.Color = pico.Color
		punta.Material = pico.Material
		punta.CanCollide = false
		punta.Massless = true
		-- La cuña apunta hacia afuera y un poco hacia abajo.
		punta.CFrame = cabeza.CFrame * CFrame.new(0, -0.1, z) * CFrame.Angles(math.rad(if z > 0 then 180 else 0), 0, 0)
		punta.Parent = tool
		local w = Instance.new("WeldConstraint")
		w.Part0 = cabeza
		w.Part1 = punta
		w.Parent = punta
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = mango
	weld.Part1 = cabeza
	weld.Parent = cabeza
	return tool
end

-- Pone el pico del nivel actual en la mochila del jugador (quita el anterior).
function PicoService.Dar(player: Player)
	local pico = picoDe(player)
	for _, lugar in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if lugar then
			local viejo = lugar:FindFirstChild("Pico")
			if viejo and viejo:IsA("Tool") then
				viejo:Destroy()
			end
		end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		crearPico(pico).Parent = backpack
	end
	PicoService.Sync(player)
end

-- Muestra el pico en los atributos del jugador (HUD y menú del herrero).
function PicoService.Sync(player: Player)
	local data = PlayerData.Get(player)
	local pico = picoDe(player)
	player:SetAttribute("NivelPico", pico.Nivel)
	player:SetAttribute("NombrePico", pico.Nombre)
	player:SetAttribute("Durabilidad", data and data.DurabilidadPico or pico.Durabilidad)
	player:SetAttribute("DurabilidadMax", pico.Durabilidad)
end

-- Gasta un punto de durabilidad por golpe que sirvió.
local function gastar(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local max = picoDe(player).Durabilidad
	data.DurabilidadPico = math.max(0, data.DurabilidadPico - 1)
	player:SetAttribute("Durabilidad", data.DurabilidadPico)
	if data.DurabilidadPico == 0 then
		aviso(player, "💥 ¡Se rompió tu pico! Llévalo con el herrero para repararlo.", "bad")
	elseif data.DurabilidadPico == math.floor(max * Config.DurabilidadBaja) then
		aviso(player, "Tu pico está muy gastado: repáralo pronto con el herrero.", "bad")
	end
end

-- Golpes ----------------------------------------------------------------------------

local MINA_MIN, MINA_MAX = Config.Mapa.MinaMin, Config.Mapa.MinaMax

local function dentroDeMina(p: Vector3): boolean
	return p.X > MINA_MIN.X
		and p.X < MINA_MAX.X
		and p.Y > MINA_MIN.Y
		and p.Y < MINA_MAX.Y
		and p.Z > MINA_MIN.Z
		and p.Z < MINA_MAX.Z
end

PicoService.DentroDeMina = dentroDeMina

-- Pedrusco suelto (de una dinamita): se rompe a golpes con cualquier pico.
local function esPedrusco(pieza: BasePart): boolean
	local carpeta = pieza.Parent
	return pieza:GetAttribute("Pedrusco") == true
		and carpeta ~= nil
		and carpeta.Name == "Pedruscos"
		and carpeta.Parent == workspace
end


-- Picado continuo -------------------------------------------------------------------------

local P = Config.Picado

-- Lo que alguien está picando: un trozo de roca, un mineral o un pedrusco.
type Objetivo = {
	tipo: string, -- "roca" | "mineral" | "pedrusco"
	clave: any, -- texto "x,y,z" para roca; la parte para mineral y pedrusco
	dureza: number,
	progreso: number, -- 0 a 1
	ultimo: number, -- última vez que alguien lo picó
	tocado: boolean, -- lo picaron en este paso
	centro: Vector3,
	color: Color3,
	-- roca
	region: Region3?,
	lista: { Vector3 }?, -- índices (x, y, z) de los vóxeles del trozo en la región
	originales: { number }?, -- ocupación original de cada vóxel de la lista
	-- mineral y pedrusco
	parte: BasePart?,
	tamano: Vector3?,
}

local objetivos: { [any]: Objetivo } = {}
-- Lo que pica cada jugador ahora: clave del objetivo y cuándo avisó el cliente.
local trabajo: { [Player]: { clave: any, ultimo: number, acumulado: number } } = {}

local VECINOS = {
	Vector3.new(0, 0, 0),
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, -1, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
}

local function celdaDe(p: Vector3): Vector3
	return Vector3.new(math.floor(p.X / 4), math.floor(p.Y / 4), math.floor(p.Z / 4))
end

local function materialCelda(c: Vector3): Enum.Material
	local p = c * 4 + Vector3.one * 2
	local mats = Terrain:ReadVoxels(Region3.new(p, p):ExpandToGrid(4), 4)
	return mats[1][1][1]
end

local function minando(clave: any): number
	local n = 0
	for _, t in trabajo do
		if t.clave == clave then
			n += 1
		end
	end
	return n
end

-- Escribe la ocupación de los vóxeles del trozo según `factor` (1 = entero, 0 = roto).
-- Lee el terreno actual para no rellenar lo que otro ya rompió.
local function escribirRoca(o: Objetivo, factor: number)
	local region = o.region :: Region3
	local mats, occs = Terrain:ReadVoxels(region, 4)
	for i, idx in o.lista :: { Vector3 } do
		local x, y, z = idx.X, idx.Y, idx.Z
		if mats[x][y][z] ~= Enum.Material.Air then
			if factor <= 0 then
				mats[x][y][z] = Enum.Material.Air
				occs[x][y][z] = 0
			else
				occs[x][y][z] = (o.originales :: { number })[i] * factor
			end
		end
	end
	Terrain:WriteVoxels(region, 4, mats, occs)
end

local function verse(o: Objetivo)
	local f = 1 - math.clamp(o.progreso, 0, 1) * P.Achique
	if o.tipo == "roca" then
		escribirRoca(o, f)
	elseif o.parte and o.parte.Parent then
		o.parte.Size = (o.tamano :: Vector3) * (0.5 + 0.5 * f)
	end
end

-- Vuelve a dejarlo entero (nadie lo siguió picando).
local function restaurar(clave: any)
	local o = objetivos[clave]
	if not o then
		return
	end
	objetivos[clave] = nil
	o.progreso = 0
	verse(o)
end

local function soltarTrabajo(player: Player)
	local t = trabajo[player]
	trabajo[player] = nil
	if t and objetivos[t.clave] and minando(t.clave) == 0 then
		restaurar(t.clave)
	end
end

local function romper(clave: any)
	local o = objetivos[clave]
	objetivos[clave] = nil
	if not o then
		return
	end
	for player, t in trabajo do
		if t.clave == clave then
			trabajo[player] = nil
			Remotes.Progreso:FireClient(player, 1, true) -- se rompió: el cliente suelta el ancla
		end
	end
	if o.tipo == "roca" then
		escribirRoca(o, 0)
		Vetas.Revelar(o.centro, 8)
	elseif o.parte then
		local id = o.parte:GetAttribute("Mineral")
		local pos = o.parte.Position
		o.parte:Destroy()
		if o.tipo == "mineral" and type(id) == "string" then
			Pepitas.Soltar(id, pos)
		end
	end
end

-- Busca (o crea) el objetivo al que apunta el jugador. Devuelve nil si no se puede picar.
local function buscarObjetivo(player: Player, punto: Vector3, normal: Vector3, pieza: Instance?, nivel: number): Objetivo?
	if pieza and pieza:IsA("BasePart") then
		local esMineral = pieza:IsDescendantOf(carpetaMinerales) and pieza:GetAttribute("Mineral") ~= nil
		if not esMineral and not esPedrusco(pieza) then
			return nil
		end
		if objetivos[pieza] then
			return objetivos[pieza]
		end
		local dureza = Config.Dinamita.DurezaPedrusco
		if esMineral then
			local info = Config.Minerales[pieza:GetAttribute("Mineral")]
			if not info then
				return nil
			end
			if info.NivelPico > nivel then
				avisoLento(player, string.format("%s: necesitas un pico de %s.", info.Nombre, Config.NivelesPico[info.NivelPico]))
				return nil
			end
			dureza = info.Dureza
		end
		local o: Objetivo = {
			tipo = if esMineral then "mineral" else "pedrusco",
			clave = pieza,
			dureza = dureza,
			progreso = 0,
			ultimo = os.clock(),
			tocado = false,
			centro = pieza.Position,
			color = pieza.Color,
			parte = pieza,
			tamano = pieza.Size,
		}
		objetivos[pieza] = o
		return o
	end

	-- Roca: el primer vóxel sólido detrás del punto (la superficie del terreno
	-- se dibuja un poco por delante de sus vóxeles).
	local celda: Vector3? = nil
	local mat = Enum.Material.Air
	for _, d in { 0.5, 2, 3.5 } do
		local c = celdaDe(punto - normal * d)
		local m = materialCelda(c)
		if m ~= Enum.Material.Air and m ~= Enum.Material.Water then
			celda, mat = c, m
			break
		end
	end
	if not celda then
		return nil
	end
	local clave = string.format("%d,%d,%d", celda.X, celda.Y, celda.Z)
	if objetivos[clave] then
		return objetivos[clave]
	end
	local centro = celda * 4 + Vector3.one * 2
	local roca = if dentroDeMina(centro) then Config.Rocas[mat] else nil
	if mat == Config.RocaImposible then
		avisoLento(player, "Roca imposible: ningún pico la rompe. Rodéala.")
		return nil
	elseif not roca then
		avisoLento(player, "Aquí no se puede picar.")
		return nil
	elseif roca.Nivel > nivel then
		avisoLento(player, string.format("%s: necesitas un pico de %s.", roca.Nombre, Config.NivelesPico[roca.Nivel]))
		return nil
	end
	-- Región de 3×3×3 vóxeles alrededor; el trozo son el centro y sus 6 vecinos
	-- que este pico puede romper.
	local min = (celda - Vector3.one) * 4
	local region = Region3.new(min, min + Vector3.one * 12)
	local mats, occs = Terrain:ReadVoxels(region, 4)
	local lista, originales = {}, {}
	for _, v in VECINOS do
		local idx = v + Vector3.new(2, 2, 2)
		local m = mats[idx.X][idx.Y][idx.Z]
		local r = Config.Rocas[m]
		if r and r.Nivel <= nivel and dentroDeMina(centro + v * 4) and occs[idx.X][idx.Y][idx.Z] > 0 then
			table.insert(lista, idx)
			table.insert(originales, occs[idx.X][idx.Y][idx.Z])
		end
	end
	local o: Objetivo = {
		tipo = "roca",
		clave = clave,
		dureza = roca.Dureza,
		progreso = 0,
		ultimo = os.clock(),
		tocado = false,
		centro = centro,
		color = Terrain:GetMaterialColor(mat),
		region = region,
		lista = lista,
		originales = originales,
	}
	objetivos[clave] = o
	return o
end

-- El cliente dice a qué apunta mientras mantiene el clic (o nil: soltó).
local function onPicar(player: Player, punto: any, normal: any, pieza: any)
	if punto == nil then
		soltarTrabajo(player)
		return
	end
	if typeof(punto) ~= "Vector3" or typeof(normal) ~= "Vector3" then
		return
	end
	if pieza ~= nil and typeof(pieza) ~= "Instance" then
		return
	end
	-- No más de 20 mensajes por segundo.
	local ahora = os.clock()
	if ahora - (ultimoMensaje[player] or 0) < 0.05 then
		return
	end
	ultimoMensaje[player] = ahora

	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local data = PlayerData.Get(player)
	if not head or not humanoid or humanoid.Health <= 0 or not data or not character:FindFirstChild("Pico") then
		soltarTrabajo(player)
		return
	end
	if data.DurabilidadPico <= 0 then
		avisoLento(player, "Tu pico está roto: llévalo con el herrero para repararlo.")
		soltarTrabajo(player)
		return
	end
	if (punto - head.Position).Magnitude > Config.Alcance + 3 then
		return
	end
	local o = buscarObjetivo(player, punto, normal.Unit, pieza, picoDe(player).Nivel)
	local t = trabajo[player]
	if not o then
		soltarTrabajo(player)
		return
	end
	if t and t.clave ~= o.clave then
		soltarTrabajo(player)
		t = nil
	end
	if t then
		t.ultimo = ahora
	else
		trabajo[player] = { clave = o.clave, ultimo = ahora, acumulado = 0 }
	end
end

local function paso(dt: number)
	local ahora = os.clock()
	for player, t in trabajo do
		local o = objetivos[t.clave]
		local data = PlayerData.Get(player)
		local character = player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		if
			not o
			or not data
			or not head
			or ahora - t.ultimo > P.OlvidarTras
			or data.DurabilidadPico <= 0
			or not character:FindFirstChild("Pico")
			or (o.parte and not o.parte.Parent)
			or (o.centro - head.Position).Magnitude > Config.Alcance + 6
		then
			soltarTrabajo(player)
		else
			local pico = picoDe(player)
			-- La Fuerza solo ayuda con los minerales, no con la roca.
			local fuerza = if o.tipo == "mineral" then 1 + Config.Fuerza.BonoMineral * data.Fuerza else 1
			o.progreso += pico.Poder * fuerza * dt / pico.Cadencia / o.dureza
			o.ultimo = ahora
			o.tocado = true
			-- Un golpe cada Cadencia: gasta durabilidad y suenan las chispas.
			t.acumulado += dt
			if t.acumulado >= pico.Cadencia then
				t.acumulado -= pico.Cadencia
				gastar(player)
				Remotes.Golpe:FireAllClients(if o.parte then o.parte.Position else o.centro, o.color)
			end
			Remotes.Progreso:FireClient(player, math.clamp(o.progreso, 0, 1))
		end
	end
	for clave, o in objetivos do
		if o.tocado then
			o.tocado = false
			if o.progreso >= 1 then
				romper(clave)
			else
				verse(o)
			end
		elseif ahora - o.ultimo > P.OlvidarTras then
			restaurar(clave)
		end
	end
end

-- Una explosión cambió el terreno: olvida los trozos de esa zona sin restaurarlos.
function PicoService.Invalidar(centro: Vector3, radio: number)
	for clave, o in objetivos do
		if o.tipo == "roca" and (o.centro - centro).Magnitude <= radio + 8 then
			objetivos[clave] = nil
			for player, t in trabajo do
				if t.clave == clave then
					trabajo[player] = nil
				end
			end
		end
	end
end

function PicoService.Init(minerales: Folder)
	carpetaMinerales = minerales
	Remotes.Picar.OnServerEvent:Connect(onPicar)
	local acumulado = 0
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		acumulado += dt
		if acumulado >= P.Paso then
			paso(acumulado)
			acumulado = 0
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		soltarTrabajo(player)
		ultimoMensaje[player] = nil
		ultimoAviso[player] = nil
	end)
end

return PicoService
