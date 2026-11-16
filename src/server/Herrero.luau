--[[
	El herrero: NPC con delantal, barba y martillo, en su herrería (fragua con
	fuego, yunque y techo de calamina) del otro lado de la boca de la mina.
	"Hablar con el herrero" abre su menú, donde:
	  - Mejorar: paga el precio del siguiente pico (sale nuevo, con durabilidad llena)
	  - Reparar: paga según lo gastado
	  - Reparar con hierro: cada hierro de la mochila repara una parte del pico
	  - Dinamita: la vende, y más barata si le das un azufre (pólvora)
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local PlayerData = require(script.Parent.PlayerData)
local Mochila = require(script.Parent.Mochila)
local PicoService = require(script.Parent.PicoService)
local DinamitaService = require(script.Parent.DinamitaService)
local Npc = require(script.Parent.Npc)

local Herrero = {}

local NARANJA = Color3.fromRGB(255, 140, 50)
local MADERA = Color3.fromRGB(110, 76, 46)
local HIERRO = Color3.fromRGB(70, 72, 78)

local ultimaAccion: { [Player]: number } = {}

local function aviso(player: Player, texto: string, tipo: string)
	Remotes.Aviso:FireClient(player, texto, tipo)
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

-- Acciones -----------------------------------------------------------------------------

local function mejorar(player: Player, data)
	local siguiente = Config.Picos[data.NivelPico + 1]
	if not siguiente then
		aviso(player, "El herrero: \"Ese pico ya es lo mejor que sé hacer.\"", "info")
		return
	end
	if data.Dinero < siguiente.Precio then
		aviso(player, string.format("Te faltan %s para el %s.", Format.money(siguiente.Precio - data.Dinero), siguiente.Nombre), "bad")
		return
	end
	data.Dinero -= siguiente.Precio
	data.NivelPico = siguiente.Nivel
	data.DurabilidadPico = siguiente.Durabilidad
	-- Si tenía el pico en la mano, el nuevo también queda en la mano.
	local character = player.Character
	local enMano = character and character:FindFirstChild("Pico") ~= nil
	PicoService.Dar(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	local nuevo = backpack and backpack:FindFirstChild("Pico")
	if enMano and humanoid and nuevo then
		humanoid:EquipTool(nuevo :: Tool)
	end
	aviso(player, string.format("🔨 ¡Listo! Ahora tienes el %s.", siguiente.Nombre), "gold")
	task.spawn(PlayerData.Save, player)
end

local function reparar(player: Player, data)
	local pico = Config.Picos[data.NivelPico]
	local falta = pico.Durabilidad - data.DurabilidadPico
	if falta <= 0 then
		aviso(player, "El herrero: \"Tu pico está como nuevo.\"", "info")
		return
	end
	local costo = math.ceil(pico.Reparar * falta / pico.Durabilidad)
	if data.Dinero < costo then
		aviso(player, string.format("Reparar cuesta %s y tienes %s.", Format.money(costo), Format.money(data.Dinero)), "bad")
		return
	end
	data.Dinero -= costo
	data.DurabilidadPico = pico.Durabilidad
	aviso(player, string.format("🔨 Pico reparado por %s.", Format.money(costo)), "good")
end

local function repararConHierro(player: Player, data)
	local pico = Config.Picos[data.NivelPico]
	local falta = pico.Durabilidad - data.DurabilidadPico
	if falta <= 0 then
		aviso(player, "El herrero: \"Tu pico está como nuevo.\"", "info")
		return
	end
	local porHierro = math.ceil(pico.Durabilidad * Config.RepararPorHierro)
	local usados = Mochila.Sacar(player, "Hierro", math.ceil(falta / porHierro))
	if usados == 0 then
		aviso(player, "No traes hierro en la mochila. Lo hay en las Cuevas.", "bad")
		return
	end
	data.DurabilidadPico = math.min(pico.Durabilidad, data.DurabilidadPico + usados * porHierro)
	aviso(player, string.format("🔨 Usaste %d de hierro para reparar tu pico.", usados), "good")
end

local ACCIONES = {
	Mejorar = mejorar,
	Reparar = reparar,
	RepararHierro = repararConHierro,
	Dinamita = function(player, data)
		DinamitaService.Comprar(player, data, false)
	end,
	DinamitaAzufre = function(player, data)
		DinamitaService.Comprar(player, data, true)
	end,
}

local function onAccion(player: Player, accion: any)
	local hacer = ACCIONES[accion]
	local data = PlayerData.Get(player)
	if not hacer or not data then
		return
	end
	local ahora = os.clock()
	if ahora - (ultimaAccion[player] or 0) < 0.3 then
		return
	end
	ultimaAccion[player] = ahora
	hacer(player, data)
	PlayerData.Sync(player)
	PicoService.Sync(player)
end

-- Herrería ------------------------------------------------------------------------------

local function crearHerrero(): Model
	local model = Npc.Persona("El Herrero", Color3.fromRGB(78, 70, 64), Color3.fromRGB(196, 140, 100), Color3.fromRGB(60, 46, 36))
	local head = model:FindFirstChild("Head") :: BasePart
	local torso = model:FindFirstChild("UpperTorso") :: BasePart
	local lower = model:FindFirstChild("LowerTorso") :: BasePart
	local mano = model:FindFirstChild("RightHand") :: BasePart
	local hz, tz = head.Size.Z / 2, torso.Size.Z / 2
	local cuero = Color3.fromRGB(110, 70, 40)
	-- Barba y cejas.
	Npc.Pegar(head, { Name = "Barba", Size = Vector3.new(0.95, 0.55, 0.3), Color = Color3.fromRGB(70, 42, 24) }, CFrame.new(0, -0.38, -hz + 0.05))
	Npc.Pegar(head, { Name = "Cejas", Size = Vector3.new(0.8, 0.1, 0.06), Color = Color3.fromRGB(70, 42, 24) }, CFrame.new(0, 0.22, -hz - 0.02))
	-- Delantal de cuero.
	Npc.Pegar(torso, { Name = "Delantal", Size = Vector3.new(torso.Size.X * 0.8, torso.Size.Y * 0.9, 0.08), Color = cuero, Material = Enum.Material.Leather }, CFrame.new(0, -0.05, -tz - 0.03))
	Npc.Pegar(lower, { Name = "DelantalAbajo", Size = Vector3.new(lower.Size.X * 0.85, 1.4, 0.08), Color = cuero, Material = Enum.Material.Leather }, CFrame.new(0, -0.5, -lower.Size.Z / 2 - 0.05))
	-- Martillo en la mano derecha.
	Npc.Pegar(mano, { Name = "MangoMartillo", Size = Vector3.new(0.2, 1.6, 0.2), Color = MADERA, Material = Enum.Material.Wood }, CFrame.new(0, -0.6, 0))
	Npc.Pegar(mano, { Name = "Martillo", Size = Vector3.new(0.45, 0.45, 0.9), Color = HIERRO, Material = Enum.Material.Metal }, CFrame.new(0, -1.35, 0))
	return model
end

function Herrero.Build(carpeta: Instance)
	local pos = Config.Mapa.Herrero + Vector3.new(0, Config.Mapa.Suelo, 0)
	local mira = Vector3.new(0, pos.Y, pos.Z) -- mira hacia el camino
	local frente = (mira - pos).Unit
	local lateral = frente:Cross(Vector3.yAxis)
	local base = CFrame.lookAt(pos, pos + frente)
	local herreria = Instance.new("Model")
	herreria.Name = "Herreria"

	-- Yunque frente al herrero.
	local yunquePos = base * CFrame.new(0, 0, -3)
	parte({ Name = "Tronco", Size = Vector3.new(1.4, 1.6, 1.4), CFrame = yunquePos * CFrame.new(0, 0.8, 0), Color = MADERA, Material = Enum.Material.Wood }, herreria)
	parte({ Name = "PieYunque", Size = Vector3.new(0.7, 0.6, 0.9), CFrame = yunquePos * CFrame.new(0, 1.9, 0), Color = HIERRO, Material = Enum.Material.Metal }, herreria)
	local yunque = parte({ Name = "Yunque", Size = Vector3.new(1, 0.6, 2.4), CFrame = yunquePos * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, math.rad(90), 0), Color = HIERRO, Material = Enum.Material.Metal }, herreria)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hablar con el herrero"
	prompt.ObjectText = "Mejorar y reparar el pico"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = yunque
	prompt.Triggered:Connect(function(player)
		Remotes.AbrirHerrero:FireClient(player)
	end)

	-- Fragua con fuego a un costado.
	local fraguaPos = base * CFrame.new(-4.5, 0, 1.5)
	parte({ Name = "Fragua", Size = Vector3.new(3.6, 2.6, 3.2), CFrame = fraguaPos * CFrame.new(0, 1.3, 0), Color = Color3.fromRGB(120, 66, 50), Material = Enum.Material.Brick }, herreria)
	local brasas = parte({ Name = "Brasas", Size = Vector3.new(2.6, 0.3, 2.2), CFrame = fraguaPos * CFrame.new(0, 2.7, 0), Color = NARANJA, Material = Enum.Material.Neon, CanCollide = false }, herreria)
	local fuego = Instance.new("Fire")
	fuego.Size = 4
	fuego.Heat = 6
	fuego.Color = NARANJA
	fuego.Parent = brasas
	local luz = Instance.new("PointLight")
	luz.Color = NARANJA
	luz.Range = 16
	luz.Brightness = 1.6
	luz.Shadows = true
	luz.Parent = brasas
	parte({ Name = "Chimenea", Size = Vector3.new(1.4, 9, 1.4), CFrame = fraguaPos * CFrame.new(0, 7.3, 0.9), Color = Color3.fromRGB(110, 60, 46), Material = Enum.Material.Brick }, herreria)

	-- Techo de calamina sobre cuatro postes.
	for _, esquina in { { -6.5, -5 }, { 6.5, -5 }, { -6.5, 4 }, { 6.5, 4 } } do
		parte({ Name = "Poste", Size = Vector3.new(0.6, 8.5, 0.6), CFrame = base * CFrame.new(esquina[1], 4.25, esquina[2]), Color = MADERA, Material = Enum.Material.Wood }, herreria)
	end
	parte({ Name = "Techo", Size = Vector3.new(15, 0.3, 11), CFrame = base * CFrame.new(0, 8.7, -0.5) * CFrame.Angles(math.rad(8), 0, 0), Color = Color3.fromRGB(150, 150, 154), Material = Enum.Material.CorrodedMetal }, herreria)
	parte({ Name = "NieveTecho", Size = Vector3.new(14, 0.3, 6), CFrame = base * CFrame.new(0.4, 9, 1) * CFrame.Angles(math.rad(8), 0, 0), Color = Color3.fromRGB(240, 244, 250), Material = Enum.Material.Snow }, herreria)

	Npc.Cartel(yunque, "🔨 Herrero", NARANJA, 8)

	herreria.Parent = carpeta
	local npc = crearHerrero()
	npc.Parent = herreria
	Npc.Colocar(npc, pos, mira)

	Remotes.Herrero.OnServerEvent:Connect(onAccion)
	Players.PlayerRemoving:Connect(function(player)
		ultimaAccion[player] = nil
	end)
end

return Herrero
