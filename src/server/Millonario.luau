--[[
	El millonario: NPC de traje, sombrero de copa y cadena de oro, con dos
	guardaespaldas, en su puesto junto a la boca de la mina. Le vendes todo lo
	que traes en la mochila con el aviso "Vender minerales".
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local PlayerData = require(script.Parent.PlayerData)
local Mochila = require(script.Parent.Mochila)
local Npc = require(script.Parent.Npc)

local Millonario = {}

local ORO = Color3.fromRGB(255, 196, 40)
local PIEL = Npc.PIEL
local pegar, persona, colocar = Npc.Pegar, Npc.Persona, Npc.Colocar

local function crearMillonario(): Model
	local model = persona("El Millonario", Color3.fromRGB(34, 32, 48), PIEL)
	local head = model:FindFirstChild("Head") :: BasePart
	local torso = model:FindFirstChild("UpperTorso") :: BasePart
	local hy, hz = head.Size.Y / 2, head.Size.Z / 2
	-- Sombrero de copa.
	local copa = CFrame.Angles(0, 0, math.rad(90))
	pegar(head, { Name = "Copa", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, 1.15, 1.15), Color = Color3.fromRGB(20, 20, 24) }, CFrame.new(0, hy + 0.6, 0) * copa)
	pegar(head, { Name = "Ala", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 1.9, 1.9), Color = Color3.fromRGB(20, 20, 24) }, CFrame.new(0, hy + 0.02, 0) * copa)
	pegar(head, { Name = "Cinta", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22, 1.18, 1.18), Color = ORO, Material = Enum.Material.Metal }, CFrame.new(0, hy + 0.2, 0) * copa)
	-- Bigote.
	pegar(head, { Name = "Bigote", Size = Vector3.new(0.7, 0.14, 0.1), Color = Color3.fromRGB(60, 40, 28) }, CFrame.new(0, -0.22, -hz - 0.02))
	-- Camisa blanca, corbata roja y cadena de oro.
	local tz = torso.Size.Z / 2
	pegar(torso, { Name = "Camisa", Size = Vector3.new(0.55, 1.3, 0.05), Color = Color3.fromRGB(245, 245, 245) }, CFrame.new(0, 0.2, -tz - 0.01))
	pegar(torso, { Name = "Corbata", Size = Vector3.new(0.2, 1, 0.06), Color = Color3.fromRGB(190, 30, 40) }, CFrame.new(0, 0.2, -tz - 0.04))
	for _, lado in { -1, 1 } do
		pegar(torso, { Name = "Cadena", Size = Vector3.new(0.12, 1.1, 0.06), Color = ORO, Material = Enum.Material.Neon }, CFrame.new(lado * 0.42, 0.25, -tz - 0.07) * CFrame.Angles(0, 0, math.rad(lado * 28)))
	end
	pegar(torso, { Name = "Medalla", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.55, 0.55), Color = ORO, Material = Enum.Material.Neon }, CFrame.new(0, -0.3, -tz - 0.09) * CFrame.Angles(0, math.rad(90), 0))
	return model
end

local function crearGuardia(n: number): Model
	local model = persona("Guardaespaldas", Color3.fromRGB(16, 16, 18), if n == 1 then PIEL else Color3.fromRGB(150, 100, 70))
	local head = model:FindFirstChild("Head") :: BasePart
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	pegar(head, { Name = "Lentes", Size = Vector3.new(1, 0.24, 0.08), Color = Color3.fromRGB(8, 8, 10), Material = Enum.Material.Glass }, CFrame.new(0, 0.12, -head.Size.Z / 2 - 0.03))
	return model
end

local function vender(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local contenido = Mochila.Vaciar(player)
	local total, partes = 0, {}
	for id, cantidad in contenido do
		local info = Config.Minerales[id]
		if info and cantidad > 0 then
			total += info.Valor * cantidad
			table.insert(partes, string.format("%d %s", cantidad, info.Nombre))
		end
	end
	if total <= 0 then
		Remotes.Aviso:FireClient(player, "El millonario: \"¿Y mis minerales? ¡A la mina!\"", "info")
		return
	end
	data.Dinero += total
	data.TotalGanado += total
	PlayerData.Sync(player)
	Remotes.Aviso:FireClient(
		player,
		string.format("💰 Vendiste %s: +%s", table.concat(partes, ", "), Format.money(total)),
		"gold"
	)
end

function Millonario.Build(carpeta: Instance)
	local pos = Config.Mapa.Millonario + Vector3.new(0, Config.Mapa.Suelo, 0)
	local mira = Vector3.new(0, pos.Y, pos.Z) -- mira hacia el camino
	local puesto = Instance.new("Model")
	puesto.Name = "PuestoMillonario"

	-- Mostrador con borde de oro.
	local frente = (mira - pos).Unit
	local mostradorPos = pos + frente * 3.5
	local mostrador = Instance.new("Part")
	mostrador.Name = "Mostrador"
	mostrador.Anchored = true
	mostrador.Size = Vector3.new(7, 3.4, 1.6)
	mostrador.CFrame = CFrame.lookAt(mostradorPos + Vector3.new(0, 1.7, 0), mostradorPos + frente + Vector3.new(0, 1.7, 0))
	mostrador.Color = Color3.fromRGB(96, 40, 30)
	mostrador.Material = Enum.Material.Wood
	mostrador.Parent = puesto
	local borde = Instance.new("Part")
	borde.Name = "Borde"
	borde.Anchored = true
	borde.Size = Vector3.new(7.3, 0.25, 1.9)
	borde.CFrame = mostrador.CFrame * CFrame.new(0, 1.8, 0)
	borde.Color = ORO
	borde.Material = Enum.Material.Metal
	borde.Parent = puesto

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Vender minerales"
	prompt.ObjectText = "El Millonario"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = mostrador
	prompt.Triggered:Connect(vender)

	-- Letrero sobre el puesto.
	Npc.Cartel(mostrador, "💰 Compro minerales", ORO, 8)

	puesto.Parent = carpeta

	local npc = crearMillonario()
	npc.Parent = puesto
	colocar(npc, pos, mira)
	local lateral = frente:Cross(Vector3.yAxis)
	for i, lado in { -1, 1 } do
		local guardia = crearGuardia(i)
		guardia.Parent = puesto
		local gp = pos + lateral * lado * 5.5 - frente * 0.5
		colocar(guardia, gp, gp + frente)
	end
end

Millonario.Vender = vender

return Millonario
