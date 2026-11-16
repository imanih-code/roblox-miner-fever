--[[
	Picado en el cliente: con el pico en la mano, mientras mantienes el clic (o el
	dedo) se busca a qué apuntas dentro del alcance y se le avisa al servidor unas
	5 veces por segundo; al soltar, se le avisa que dejaste de picar. El servidor
	decide el avance (ver PicoService) y lo devuelve con Remotes.Progreso para la
	barra. El objetivo queda anclado mientras mantienes el clic y la mira pasa
	cerca de él (al achicarse, su superficie se aleja y el rayo podría caer en otro
	trozo); se suelta al apuntar claramente a otro lado o cuando se rompe.
	El brazo hace el golpe una vez por Cadencia. Las chispas y el sonido llegan con
	Remotes.Golpe para todos los que estén cerca.
	Gancho de prueba en Studio: workspace:SetAttribute("PruebaPicar", Vector3)
	pica sin parar hacia ese punto; ponlo en nil para soltar.
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

local apretado = false -- clic (o dedo) mantenido con el pico en la mano
local forzado: Vector3? = nil -- gancho de prueba
local claveActual: any = nil

-- Objetivo fijado mientras mantienes el clic (ver cadaCuadro).
type Anclado = { clave: any, punto: Vector3, normal: Vector3, pieza: BasePart?, centro: Vector3, radio: number }
local anclado: Anclado? = nil
local ultimoEnvio = 0
local ultimoGolpe = 0

-- Barra de progreso sobre lo que picas.
local ancla: Part
local barraGui: BillboardGui
local relleno: Frame

local function filtro(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignorar = { workspace.CurrentCamera }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignorar, p.Character)
		end
	end
	local pepitas = workspace:FindFirstChild("Pepitas")
	if pepitas then
		table.insert(ignorar, pepitas)
	end
	params.FilterDescendantsInstances = ignorar
	return params
end

local function crearBarra()
	ancla = Instance.new("Part")
	ancla.Name = "BarraPicado"
	ancla.Anchored = true
	ancla.CanCollide = false
	ancla.CanQuery = false
	ancla.CanTouch = false
	ancla.Transparency = 1
	ancla.Size = Vector3.one * 0.2
	ancla.Parent = workspace.CurrentCamera
	barraGui = Instance.new("BillboardGui")
	barraGui.Size = UDim2.fromOffset(90, 12)
	barraGui.AlwaysOnTop = true
	barraGui.Enabled = false
	barraGui.Adornee = ancla
	barraGui.Parent = ancla
	local fondo = Instance.new("Frame")
	fondo.Size = UDim2.fromScale(1, 1)
	fondo.BackgroundColor3 = Color3.fromRGB(24, 20, 18)
	fondo.BackgroundTransparency = 0.25
	fondo.BorderSizePixel = 0
	fondo.Parent = barraGui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = fondo
	relleno = Instance.new("Frame")
	relleno.Size = UDim2.fromScale(0, 1)
	relleno.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	relleno.BorderSizePixel = 0
	relleno.Parent = fondo
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(0, 6)
	c2.Parent = relleno
end

local function soltar()
	anclado = nil
	if claveActual ~= nil then
		claveActual = nil
		Remotes.Picar:FireServer()
	end
	barraGui.Enabled = false
end

-- Rayo de la mira: origen y dirección (unitaria). Con el gancho de prueba sale de la cabeza.
local function rayoMira(): (Vector3, Vector3)
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if forzado and head then
		return head.Position, (forzado - head.Position).Unit
	end
	local rayo = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
	return rayo.Origin, rayo.Direction.Unit
end

-- Distancia de un punto a la semirrecta (o, d).
local function distanciaAlRayo(p: Vector3, o: Vector3, d: Vector3): number
	local t = math.max(0, (p - o):Dot(d))
	return (o + d * t - p).Magnitude
end

-- Lo que hay frente al pico: (resultado del rayo, pieza o nil) o nil si no se puede picar.
local function apuntado(): (RaycastResult?, BasePart?)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil, nil
	end
	local origen, dir = rayoMira()
	local hit = workspace:Raycast(origen, dir * (if forzado then Config.Alcance + 1 else 200), filtro())
	if not hit or (hit.Position - head.Position).Magnitude > Config.Alcance then
		return nil, nil
	end
	local inst = hit.Instance
	if inst:GetAttribute("Mineral") or inst:GetAttribute("Pedrusco") then
		return hit, inst :: BasePart
	elseif inst == workspace.Terrain then
		return hit, nil
	end
	return nil, nil
end

local function claveDe(hit: RaycastResult, pieza: BasePart?): any
	if pieza then
		return pieza
	end
	local p = hit.Position - hit.Normal * 2
	return string.format("%d,%d,%d", math.floor(p.X / 4), math.floor(p.Y / 4), math.floor(p.Z / 4))
end

local function animarGolpe(pico: Instance)
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = pico
	Debris:AddItem(anim, 0.5)
end

local function cadaCuadro()
	local character = player.Character
	local pico = character and character:FindFirstChild("Pico")
	if not pico or not (apretado or forzado) then
		soltar()
		return
	end
	local ahora = os.clock()
	local nivel = player:GetAttribute("NivelPico") or 1
	local cadencia = (Config.Picos[nivel] or Config.Picos[1]).Cadencia
	if ahora - ultimoGolpe >= cadencia then
		ultimoGolpe = ahora
		animarGolpe(pico)
	end
	if ahora - ultimoEnvio < 0.08 then
		return
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	-- El objetivo anclado sigue mientras la mira pase cerca de él, aunque su
	-- superficie se aleje al achicarse.
	if anclado then
		local o, d = rayoMira()
		local sigue = (not anclado.pieza or anclado.pieza.Parent ~= nil)
			and distanciaAlRayo(anclado.centro, o, d) <= anclado.radio
			and (anclado.centro - head.Position).Magnitude <= Config.Alcance + 4
		if not sigue then
			anclado = nil
		end
	end
	if not anclado then
		local hit, pieza = apuntado()
		if not hit then
			soltar()
			return
		end
		local centro, radio
		if pieza then
			centro = pieza.Position
			radio = math.max(pieza.Size.X, pieza.Size.Y, pieza.Size.Z) / 2 + 1.5
		else
			local p = hit.Position - hit.Normal * 2
			centro = Vector3.new(math.floor(p.X / 4), math.floor(p.Y / 4), math.floor(p.Z / 4)) * 4 + Vector3.one * 2
			radio = 4.5
		end
		anclado = {
			clave = claveDe(hit, pieza),
			punto = hit.Position,
			normal = hit.Normal,
			pieza = pieza,
			centro = centro,
			radio = radio,
		}
	end
	local a = anclado :: Anclado
	if a.clave ~= claveActual or ahora - ultimoEnvio > 0.2 then
		if a.clave ~= claveActual then
			relleno.Size = UDim2.fromScale(0, 1)
		end
		claveActual = a.clave
		ultimoEnvio = ahora
		-- Siempre el punto y la normal del primer toque: así el servidor sigue en el mismo trozo.
		Remotes.Picar:FireServer(a.punto, a.normal, a.pieza)
		ancla.Position = if a.pieza
			then a.pieza.Position + Vector3.new(0, a.pieza.Size.Y / 2 + 1, 0)
			else a.punto + a.normal * 1.5
	end
end

-- Chispas de piedra y sonido en el punto del golpe.
local function efecto(punto: Vector3, color: Color3)
	local camera = workspace.CurrentCamera
	if (camera.CFrame.Position - punto).Magnitude > 90 then
		return
	end
	local a = Instance.new("Part")
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.Transparency = 1
	a.Size = Vector3.one * 0.2
	a.Position = punto
	a.Parent = workspace
	local sonido = Instance.new("Sound")
	sonido.SoundId = SONIDO_GOLPE
	sonido.PlaybackSpeed = 1.5 + math.random() * 0.3
	sonido.Volume = 0.7
	sonido.RollOffMaxDistance = 80
	sonido.Parent = a
	sonido:Play()
	for _ = 1, 4 do
		local trozo = Instance.new("Part")
		trozo.Size = Vector3.one * (0.2 + math.random() * 0.25)
		trozo.Color = color
		trozo.Material = Enum.Material.Slate
		trozo.CanCollide = false
		trozo.CanQuery = false
		trozo.CanTouch = false
		trozo.CFrame = CFrame.new(punto) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		trozo.AssemblyLinearVelocity = Vector3.new(math.random(-10, 10), math.random(5, 14), math.random(-10, 10))
		trozo.Parent = workspace
		Debris:AddItem(trozo, 0.7)
	end
	Debris:AddItem(a, 1.5)
end

local function conectarPico(tool: Instance)
	if tool:IsA("Tool") and tool.Name == "Pico" and not tool:GetAttribute("Conectado") then
		tool:SetAttribute("Conectado", true)
		tool.Activated:Connect(function()
			apretado = true
		end)
		tool.Deactivated:Connect(function()
			apretado = false
		end)
		tool.Unequipped:Connect(function()
			apretado = false
		end)
	end
end

function PicoCliente.Start()
	crearBarra()
	local function onCharacter(character: Model)
		apretado = false
		character.ChildAdded:Connect(conectarPico)
		for _, c in character:GetChildren() do
			conectarPico(c)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
	RunService.Heartbeat:Connect(cadaCuadro)
	Remotes.Golpe.OnClientEvent:Connect(efecto)
	Remotes.Progreso.OnClientEvent:Connect(function(progreso: number, roto: boolean?)
		if roto then
			-- Se rompió: se suelta el ancla y se toma lo siguiente que apuntes.
			anclado = nil
			claveActual = nil
			relleno.Size = UDim2.fromScale(0, 1)
			barraGui.Enabled = false
		elseif claveActual ~= nil then
			barraGui.Enabled = true
			relleno.Size = UDim2.fromScale(progreso, 1)
		end
	end)

	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("PruebaPicar"):Connect(function()
			local objetivo = workspace:GetAttribute("PruebaPicar")
			forzado = if typeof(objetivo) == "Vector3" then objetivo else nil
		end)
	end
end

return PicoCliente
