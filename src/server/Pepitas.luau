--[[
	Pepitas: lo que suelta un mineral al romperse. Caen con física y brillan un
	poco para verlas en la oscuridad. Se recogen tocándolas con el cuerpo (van a
	la mochila); cualquiera las puede recoger. Desaparecen después de un rato.
	Si alguien recoge uno raro, el servidor avisa a todos.
]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Mochila = require(script.Parent.Mochila)

local Pepitas = {}

local carpeta: Folder
local ultimoAvisoLlena: { [Player]: number } = {}

local function recoger(pepita: BasePart, player: Player)
	if pepita:GetAttribute("Recogida") then
		return
	end
	local id = pepita:GetAttribute("Mineral")
	local info = Config.Minerales[id]
	if not info then
		return
	end
	if not Mochila.Agregar(player, id) then
		local ahora = os.clock()
		if ahora - (ultimoAvisoLlena[player] or 0) > 3 then
			ultimoAvisoLlena[player] = ahora
			Remotes.Aviso:FireClient(player, "Mochila llena: ve a venderle al millonario.", "bad")
		end
		return
	end
	pepita:SetAttribute("Recogida", true)
	pepita:Destroy()
	Remotes.Aviso:FireClient(
		player,
		string.format("+1 %s  (mochila %d/%d)", info.Nombre, Mochila.Usada(player), Mochila.Capacidad(player)),
		"good"
	)
	if info.Rareza >= Config.AvisarDesdeRareza then
		local rareza = Config.Rarezas[info.Rareza].Nombre
		Remotes.Aviso:FireAllClients(string.format("⭐ %s sacó %s (%s)", player.DisplayName, info.Nombre, rareza), "gold")
	end
end

-- Suelta una pepita del mineral `id` en `pos`.
function Pepitas.Soltar(id: string, pos: Vector3)
	local info = Config.Minerales[id]
	if not info then
		return
	end
	local t = Config.Pepitas.Tamano
	local p = Instance.new("Part")
	p.Name = "Pepita" .. id
	p.Size = Vector3.new(t, t * 0.8, t)
	p.Color = info.Color
	p.Material = info.Material
	p.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
	p.AssemblyLinearVelocity = Vector3.new(math.random(-4, 4), 10, math.random(-4, 4))
	p.CustomPhysicalProperties = PhysicalProperties.new(2, 0.6, 0.2)
	p:SetAttribute("Mineral", id)
	local luz = Instance.new("PointLight")
	luz.Color = info.Color
	luz.Range = if info.Brillo then 8 else 4
	luz.Brightness = if info.Brillo then 1.2 else 0.6
	luz.Parent = p
	if info.Rareza >= Config.AvisarDesdeRareza then
		local destellos = Instance.new("Sparkles")
		destellos.SparkleColor = info.Color
		destellos.Parent = p
	end
	p.Touched:Connect(function(otra)
		local character = otra.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if player and humanoid and humanoid.Health > 0 then
			recoger(p, player)
		end
	end)
	p.Parent = carpeta
	p:SetNetworkOwner(nil) -- la física la lleva el servidor
	Debris:AddItem(p, Config.Pepitas.Duran)
end

function Pepitas.Init()
	carpeta = Instance.new("Folder")
	carpeta.Name = "Pepitas"
	carpeta.Parent = workspace
	Players.PlayerRemoving:Connect(function(player)
		ultimoAvisoLlena[player] = nil
	end)
end

return Pepitas
