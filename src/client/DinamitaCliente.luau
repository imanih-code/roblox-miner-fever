--[[
	Dinamita en el cliente: con la herramienta "Dinamita" en la mano, cada clic
	(o toque) pone un cartucho donde apuntas (o a tus pies si apuntas lejos).
	Cuando explota una cerca, la cámara se sacude.
	Gancho de prueba en Studio: workspace:SetAttribute("PruebaDinamita", Vector3)
	pone la dinamita en ese punto como si fuera un clic.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DinamitaCliente = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local D = Config.Dinamita

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

local function poner(origen: Vector3, direccion: Vector3)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not head or not root or not character:FindFirstChild("Dinamita") then
		return
	end
	local hit = workspace:Raycast(origen, direccion, filtro())
	local punto: Vector3
	if hit and (hit.Position - head.Position).Magnitude <= D.Alcance then
		punto = hit.Position + hit.Normal * 0.3
	else
		-- Apuntas lejos: la deja en el suelo, frente a ti.
		local frente = root.Position + root.CFrame.LookVector * 3
		local suelo = workspace:Raycast(frente, Vector3.new(0, -12, 0), filtro())
		punto = if suelo then suelo.Position + Vector3.new(0, 0.3, 0) else frente
	end
	Remotes.Dinamita:FireServer(punto)
end

local function onActivated()
	local camera = workspace.CurrentCamera
	local rayo = camera:ScreenPointToRay(mouse.X, mouse.Y)
	poner(rayo.Origin, rayo.Direction * 200)
end

-- Sacudida de cámara según qué tan cerca fue la explosión.
local function sacudir(centro: Vector3)
	local camera = workspace.CurrentCamera
	local dist = (camera.CFrame.Position - centro).Magnitude
	local fuerza = math.clamp(1 - dist / 60, 0, 1) * 0.9
	if fuerza <= 0 then
		return
	end
	local fin = os.clock() + 0.5
	-- Justo después de que la cámara se acomoda en cada cuadro.
	RunService:UnbindFromRenderStep("SacudidaDinamita")
	RunService:BindToRenderStep("SacudidaDinamita", Enum.RenderPriority.Camera.Value + 1, function()
		local queda = fin - os.clock()
		if queda <= 0 then
			RunService:UnbindFromRenderStep("SacudidaDinamita")
			return
		end
		local f = fuerza * queda / 0.5
		camera.CFrame *= CFrame.new((math.random() - 0.5) * f, (math.random() - 0.5) * f, 0)
	end)
end

local function conectar(tool: Instance)
	if tool:IsA("Tool") and tool.Name == "Dinamita" and not tool:GetAttribute("Conectado") then
		tool:SetAttribute("Conectado", true)
		tool.Activated:Connect(onActivated)
	end
end

function DinamitaCliente.Start()
	local function onCharacter(character: Model)
		character.ChildAdded:Connect(conectar)
		for _, c in character:GetChildren() do
			conectar(c)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
	Remotes.Explosion.OnClientEvent:Connect(sacudir)

	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("PruebaDinamita"):Connect(function()
			local objetivo = workspace:GetAttribute("PruebaDinamita")
			local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
			if typeof(objetivo) == "Vector3" and head then
				poner(head.Position, (objetivo - head.Position).Unit * D.Alcance)
			end
		end)
	end
end

return DinamitaCliente
