--[[
	Fuerza en el cliente:
	  - Tu banca: la dibuja este cliente en tu lugar (solo la ves tú), con un
	    letrero "Tu banca". Si la tocas, le pides al servidor entrenar; mientras
	    entrenas, la tuya se esconde y se ve la del servidor (la ven todos).
	  - Panel abajo mientras entrenas: banca, Fuerza por segundo, barra de
	    experiencia y botón para mejorar la banca.
	  - Botones de la banca en un lugar al azar de la pantalla: el de bonus (opcional)
	    y el de cansancio (si no le das a tiempo, te bajas de la banca).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)
local BancaModelo = require(Shared.BancaModelo)

local Hud = require(script.Parent.Hud)

local FuerzaCliente = {}

local player = Players.LocalPlayer
local C = Hud.Colors
local NARANJA = Color3.fromRGB(255, 170, 90)

local gui: ScreenGui
local panel: Frame
local panelTexto: TextLabel
local panelBarra: Frame
local botonMejorar: TextButton
local botones: { [number]: GuiObject } = {}

local function num(nombre: string): number
	return player:GetAttribute(nombre) or 0
end

-- Tu banca (local) ----------------------------------------------------------------------

local miBanca: Model? = nil
local miLugar: CFrame? = nil
local armada = true -- se rearma al alejarte, para no volver a subirte al levantarte
local ultimoToque = 0

local function bancaDelServidor(): Instance?
	local mapa = workspace:FindFirstChild("Mapa")
	local bancas = mapa and mapa:FindFirstChild("Bancas")
	return bancas and bancas:FindFirstChild("Banca_" .. player.UserId)
end

local function alTocar(otra: BasePart)
	local character = player.Character
	if not character or not otra:IsDescendantOf(character) then
		return
	end
	local ahora = os.clock()
	if not armada or ahora - ultimoToque < 1 or bancaDelServidor() then
		return
	end
	ultimoToque = ahora
	Remotes.Banca:FireServer("Entrenar")
end

local function dibujarBanca()
	if miBanca then
		miBanca:Destroy()
		miBanca = nil
	end
	local lugar = player:GetAttribute("BancaLugar")
	miLugar = if type(lugar) == "number" then BancaModelo.Lugar(lugar) else nil
	if not miLugar then
		return
	end
	local b = BancaModelo.Crear(math.max(1, num("NivelBanca")), miLugar)
	b.modelo.Name = "MiBanca"
	for _, p in b.modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanTouch = true
			p.Touched:Connect(alTocar)
		end
	end
	-- Letrero para encontrarla.
	local cartel = Instance.new("BillboardGui")
	cartel.Size = UDim2.fromOffset(140, 30)
	cartel.StudsOffset = Vector3.new(0, 4.5, 0)
	cartel.MaxDistance = 140
	cartel.Adornee = b.colchon
	cartel.Parent = b.modelo
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = NARANJA
	l.TextStrokeTransparency = 0.3
	l.Text = "💪 Tu banca"
	l.Parent = cartel
	miBanca = b.modelo
	b.modelo.Parent = if bancaDelServidor() then nil else workspace
end

-- Cada cuadro: la local se esconde mientras está la del servidor, y se rearma el
-- toque cuando te alejas.
local function cadaCuadro()
	if not miBanca or not miLugar then
		return
	end
	local delServidor = bancaDelServidor() ~= nil
	local quiere = if delServidor then nil else workspace
	if miBanca.Parent ~= quiere then
		miBanca.Parent = quiere
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if delServidor then
		armada = false
	elseif root and (root.Position - miLugar.Position).Magnitude > 7 then
		armada = true
	end
end

-- Panel de entrenamiento ------------------------------------------------------------------

local function refrescarPanel()
	panel.Visible = player:GetAttribute("Entrenando") == true
	if not panel.Visible then
		return
	end
	local nivel = math.max(1, num("NivelBanca"))
	local banca = Config.Bancas[nivel]
	local sig = num("FuerzaSig")
	panelTexto.Text = if sig > 0
		then string.format("%s · +%s Fuerza/s · salta para levantarte", banca.Nombre, tostring(banca.PorSegundo))
		else string.format("%s · ¡Fuerza al máximo!", banca.Nombre)
	panelBarra.Size = UDim2.fromScale(if sig > 0 then math.clamp(num("FuerzaXP") / sig, 0, 1) else 1, 1)
	local siguiente = Config.Bancas[nivel + 1]
	botonMejorar.Visible = siguiente ~= nil
	if siguiente then
		local alcanza = num("Dinero") >= siguiente.Precio
		botonMejorar.Text = string.format("Mejorar banca\n%s", Format.money(siguiente.Precio))
		botonMejorar.BackgroundColor3 = if alcanza then Color3.fromRGB(70, 150, 90) else Color3.fromRGB(70, 66, 62)
		botonMejorar.TextColor3 = if alcanza then C.TEXT else Color3.fromRGB(170, 164, 158)
	end
end

local function crearPanel()
	panel = Hud.frame(gui, {
		Name = "Entrenando",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.fromOffset(540, 60),
		BackgroundColor3 = C.PANEL,
		BackgroundTransparency = 0.1,
		Visible = false,
	})
	Hud.corner(panel, 14)
	Hud.stroke(panel, NARANJA, 2)
	panelTexto = Hud.text(panel, {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -150, 0, 22),
		TextSize = 15,
	})
	local fondo = Hud.frame(panel, {
		Position = UDim2.fromOffset(14, 36),
		Size = UDim2.new(1, -150, 0, 10),
		BackgroundColor3 = Color3.fromRGB(40, 34, 30),
	})
	Hud.corner(fondo, 5)
	panelBarra = Hud.frame(fondo, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = NARANJA })
	Hud.corner(panelBarra, 5)
	botonMejorar = Instance.new("TextButton")
	botonMejorar.Name = "Mejorar"
	botonMejorar.AnchorPoint = Vector2.new(1, 0.5)
	botonMejorar.Position = UDim2.new(1, -10, 0.5, 0)
	botonMejorar.Size = UDim2.fromOffset(118, 44)
	botonMejorar.Font = Enum.Font.GothamBold
	botonMejorar.TextSize = 14
	botonMejorar.Parent = panel
	Hud.corner(botonMejorar, 10)
	botonMejorar.Activated:Connect(function()
		Remotes.Banca:FireServer("Mejorar")
	end)
end

-- Botones de bono y cansancio ---------------------------------------------------------------

-- Botón en un lugar al azar; se encoge una barra con el tiempo que queda.
local function mostrarBoton(tipo: string, id: number, segundos: number)
	local esBono = tipo == "Bono"
	local b = Instance.new("TextButton")
	b.Name = tipo
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.fromScale(math.random(18, 82) / 100, math.random(25, 70) / 100)
	b.Size = if esBono then UDim2.fromOffset(120, 54) else UDim2.fromOffset(220, 70)
	b.BackgroundColor3 = if esBono then Color3.fromRGB(255, 190, 60) else Color3.fromRGB(210, 70, 60)
	b.Font = Enum.Font.FredokaOne
	b.TextSize = if esBono then 24 else 22
	b.TextColor3 = C.TEXT
	b.Text = if esBono then "💪 ¡Bonus!" else "¡Sigue entrenando!"
	b.ZIndex = 5
	b.Parent = gui
	Hud.corner(b, 14)
	Hud.stroke(b, Color3.fromRGB(255, 255, 255), 2)
	local tiempo = Hud.frame(b, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -5),
		Size = UDim2.new(1, -20, 0, 5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 6,
	})
	TweenService:Create(tiempo, TweenInfo.new(segundos, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 5) }):Play()
	b.Activated:Connect(function()
		Remotes.FuerzaClic:FireServer(id)
	end)
	botones[id] = b
	task.delay(segundos + 1, function()
		if botones[id] == b then
			botones[id] = nil
			b:Destroy()
		end
	end)
end

local function onEvento(tipo: string, id: number, segundos: number?)
	if tipo == "Fin" then
		local b = botones[id]
		botones[id] = nil
		if b then
			b:Destroy()
		end
	else
		mostrarBoton(tipo, id, segundos or 5)
	end
end

function FuerzaCliente.Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "Fuerza"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")
	crearPanel()
	player.AttributeChanged:Connect(function(nombre)
		if nombre == "BancaLugar" or nombre == "NivelBanca" then
			dibujarBanca()
		end
		refrescarPanel()
	end)
	Remotes.FuerzaEvento.OnClientEvent:Connect(onEvento)
	task.spawn(function()
		workspace:WaitForChild("Mapa"):WaitForChild("Bancas")
		dibujarBanca()
	end)
	RunService.Heartbeat:Connect(cadaCuadro)
	-- Saltar mientras entrenas: el servidor te baja y quita la banca.
	game:GetService("UserInputService").JumpRequest:Connect(function()
		if player:GetAttribute("Entrenando") then
			Remotes.Banca:FireServer("Levantarse")
		end
	end)
end

return FuerzaCliente
