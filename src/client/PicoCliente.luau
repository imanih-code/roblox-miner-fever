--[[
	Golpes de pico en el cliente: con el pico en la mano, cada clic (o toque)
	busca dónde apunta el mouse dentro del alcance, anima el golpe y le pide al
	servidor que pique ahí. Las chispas y el sonido llegan con Remotes.Golpe
	para todos los que estén cerca.
	Gancho de prueba en Studio: workspace:SetAttribute("PruebaPicar", Vector3)
	pica hacia ese punto como si fuera un clic.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PicoCliente = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local SONIDO_GOLPE = "rbxasset://sounds/action_jump_land.mp3"

local ultimo = 0

local function filtro(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignorar = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignorar, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignorar
	return params
end

-- Lanza el golpe hacia un rayo (origen, dirección larga).
local function golpear(origen: Vector3, direccion: Vector3)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local pico = character and character:FindFirstChild("Pico")
	if not head or not pico then
		return
	end
	local nivel = player:GetAttribute("NivelPico") or 1
	local cadencia = (Config.Picos[nivel] or Config.Picos[1]).Cadencia
	local ahora = os.clock()
	if ahora - ultimo < cadencia then
		return
	end
	ultimo = ahora

	-- Animación de golpe (la del Animate por defecto).
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = pico
	Debris:AddItem(anim, 0.5)

	local hit = workspace:Raycast(origen, direccion, filtro())
	if not hit or (hit.Position - head.Position).Magnitude > Config.Alcance then
		return
	end
	local pieza = nil
	if hit.Instance:GetAttribute("Mineral") then
		pieza = hit.Instance
	elseif hit.Instance ~= workspace.Terrain then
		return
	end
	-- Un poco hacia adentro de la superficie para caer en el vóxel sólido.
	local punto = hit.Position - hit.Normal * 0.5
	Remotes.Picar:FireServer(punto, pieza)
end

local function onActivated()
	local camera = workspace.CurrentCamera
	local rayo = camera:ScreenPointToRay(mouse.X, mouse.Y)
	golpear(rayo.Origin, rayo.Direction * 200)
end

-- Chispas de piedra y sonido en el punto del golpe.
local function efecto(punto: Vector3, color: Color3)
	local camera = workspace.CurrentCamera
	if (camera.CFrame.Position - punto).Magnitude > 90 then
		return
	end
	local ancla = Instance.new("Part")
	ancla.Anchored = true
	ancla.CanCollide = false
	ancla.CanQuery = false
	ancla.Transparency = 1
	ancla.Size = Vector3.one * 0.2
	ancla.Position = punto
	ancla.Parent = workspace
	local sonido = Instance.new("Sound")
	sonido.SoundId = SONIDO_GOLPE
	sonido.PlaybackSpeed = 1.5 + math.random() * 0.3
	sonido.Volume = 0.7
	sonido.RollOffMaxDistance = 80
	sonido.Parent = ancla
	sonido:Play()
	for _ = 1, 5 do
		local trozo = Instance.new("Part")
		trozo.Size = Vector3.one * (0.25 + math.random() * 0.3)
		trozo.Color = color
		trozo.Material = Enum.Material.Slate
		trozo.CanCollide = false
		trozo.CanQuery = false
		trozo.CFrame = CFrame.new(punto) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		trozo.AssemblyLinearVelocity = Vector3.new(math.random(-12, 12), math.random(6, 16), math.random(-12, 12))
		trozo.Parent = workspace
		Debris:AddItem(trozo, 0.8)
	end
	Debris:AddItem(ancla, 1.5)
end

local function conectarPico(tool: Instance)
	if tool:IsA("Tool") and tool.Name == "Pico" and not tool:GetAttribute("Conectado") then
		tool:SetAttribute("Conectado", true)
		tool.Activated:Connect(onActivated)
	end
end

function PicoCliente.Start()
	local function onCharacter(character: Model)
		character.ChildAdded:Connect(conectarPico)
		for _, c in character:GetChildren() do
			conectarPico(c)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
	Remotes.Golpe.OnClientEvent:Connect(efecto)

	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("PruebaPicar"):Connect(function()
			local objetivo = workspace:GetAttribute("PruebaPicar")
			local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
			if typeof(objetivo) == "Vector3" and head then
				ultimo = 0
				golpear(head.Position, (objetivo - head.Position).Unit * Config.Alcance)
			end
		end)
	end
end

return PicoCliente
