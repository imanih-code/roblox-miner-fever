--[[
	El pico: lo crea, lo da a cada personaje y valida cada golpe.
	El cliente dice dónde pegó (y si fue en una pieza de mineral); el servidor
	revisa distancia, cadencia y nivel del pico, y entonces:
	  - roca: borra los vóxeles que el pico puede romper dentro de un radio
	  - mineral: le quita un golpe; al llegar a 0 se suelta y va a la mochila
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Mochila = require(script.Parent.Mochila)

local PicoService = {}

local Terrain = workspace.Terrain
local carpetaMinerales: Folder

local ultimoGolpe: { [Player]: number } = {}
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

	local cabeza = Instance.new("Part")
	cabeza.Name = "Cabeza"
	cabeza.Size = Vector3.new(0.45, 0.5, 3.2)
	cabeza.Color = pico.Color
	cabeza.Material = Enum.Material.Wood
	cabeza.CanCollide = false
	cabeza.Massless = true
	cabeza.CFrame = mango.CFrame * CFrame.new(0, 1.9, 0)
	cabeza.Parent = tool
	for _, z in { -1.75, 1.75 } do
		local punta = Instance.new("WedgePart")
		punta.Name = "Punta"
		punta.Size = Vector3.new(0.35, 0.45, 0.6)
		punta.Color = pico.Color
		punta.Material = Enum.Material.Wood
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
	player:SetAttribute("NivelPico", pico.Nivel)
	player:SetAttribute("NombrePico", pico.Nombre)
end

-- Golpes ----------------------------------------------------------------------------

local function picarRoca(player: Player, punto: Vector3, nivel: number): boolean
	local r = Config.RadioPicado
	local region = Region3.new(punto - Vector3.one * r, punto + Vector3.one * r):ExpandToGrid(4)
	local mats, occs = Terrain:ReadVoxels(region, 4)
	local origen = region.CFrame.Position - region.Size / 2
	local tam = mats.Size
	local rotos = 0
	local bloqueo: Enum.Material? = nil
	local distBloqueo = math.huge
	for x = 1, tam.X do
		for y = 1, tam.Y do
			for z = 1, tam.Z do
				local mat = mats[x][y][z]
				if mat ~= Enum.Material.Air and mat ~= Enum.Material.Water then
					local centro = origen + Vector3.new(x - 0.5, y - 0.5, z - 0.5) * 4
					local dist = (centro - punto).Magnitude
					if dist <= r then
						local roca = Config.Rocas[mat]
						if roca and roca.Nivel <= nivel then
							mats[x][y][z] = Enum.Material.Air
							occs[x][y][z] = 0
							rotos += 1
						elseif dist < distBloqueo then
							bloqueo = mat
							distBloqueo = dist
						end
					end
				end
			end
		end
	end
	if rotos > 0 then
		Terrain:WriteVoxels(region, 4, mats, occs)
		return true
	end
	if bloqueo == Config.RocaImposible then
		avisoLento(player, "Roca imposible: ningún pico la rompe. Rodéala.")
	elseif bloqueo and Config.Rocas[bloqueo] then
		local roca = Config.Rocas[bloqueo]
		avisoLento(player, string.format("%s: necesitas un pico de %s.", roca.Nombre, Config.NivelesPico[roca.Nivel]))
	elseif bloqueo then
		avisoLento(player, "Aquí no se puede picar.")
	end
	return false
end

local function golpearMineral(player: Player, pieza: BasePart, nivel: number): boolean
	local id = pieza:GetAttribute("Mineral")
	local info = Config.Minerales[id]
	if not info then
		return false
	end
	if info.NivelPico > nivel then
		avisoLento(player, string.format("%s: necesitas un pico de %s.", info.Nombre, Config.NivelesPico[info.NivelPico]))
		return false
	end
	if Mochila.Llena(player) then
		avisoLento(player, "Mochila llena: ve a venderle al millonario.")
		return false
	end
	local golpes = (pieza:GetAttribute("Golpes") or info.Golpes) - 1
	if golpes > 0 then
		pieza:SetAttribute("Golpes", golpes)
		return true
	end
	local veta = pieza.Parent
	pieza:Destroy()
	if veta and veta:IsA("Model") and not veta:FindFirstChildWhichIsA("BasePart") then
		veta:Destroy()
	end
	Mochila.Agregar(player, id)
	aviso(
		player,
		string.format("+1 %s  (mochila %d/%d)", info.Nombre, Mochila.Usada(player), Mochila.Capacidad(player)),
		"good"
	)
	if info.Rareza >= Config.AvisarDesdeRareza then
		local rareza = Config.Rarezas[info.Rareza].Nombre
		Remotes.Aviso:FireAllClients(string.format("⭐ %s sacó %s (%s)", player.DisplayName, info.Nombre, rareza), "gold")
	end
	return true
end

local function onPicar(player: Player, punto: any, pieza: any)
	if typeof(punto) ~= "Vector3" then
		return
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid or humanoid.Health <= 0 then
		return
	end
	-- Hay que tener el pico en la mano.
	if not character:FindFirstChild("Pico") then
		return
	end
	local pico = picoDe(player)
	local ahora = os.clock()
	if ahora - (ultimoGolpe[player] or 0) < pico.Cadencia * 0.8 then
		return
	end
	ultimoGolpe[player] = ahora

	local ok = false
	local color: Color3
	if typeof(pieza) == "Instance" and pieza:IsA("BasePart") and pieza:IsDescendantOf(carpetaMinerales) then
		if (pieza.Position - head.Position).Magnitude > Config.Alcance + 4 then
			return
		end
		color = pieza.Color
		ok = golpearMineral(player, pieza, pico.Nivel)
		punto = pieza.Position
	else
		if (punto - head.Position).Magnitude > Config.Alcance + 3 then
			return
		end
		local mats = Terrain:ReadVoxels(Region3.new(punto, punto):ExpandToGrid(4), 4)
		color = Terrain:GetMaterialColor(mats[1][1][1] ~= Enum.Material.Air and mats[1][1][1] or Enum.Material.Rock)
		ok = picarRoca(player, punto, pico.Nivel)
	end
	if ok then
		Remotes.Golpe:FireAllClients(punto, color)
	end
end

function PicoService.Init(minerales: Folder)
	carpetaMinerales = minerales
	Remotes.Picar.OnServerEvent:Connect(onPicar)
	Players.PlayerRemoving:Connect(function(player)
		ultimoGolpe[player] = nil
		ultimoAviso[player] = nil
	end)
end

return PicoService
