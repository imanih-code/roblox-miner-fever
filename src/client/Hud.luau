--[[
	HUD de Fiebre Minera: dinero, mochila, pico y profundidad (arriba a la
	izquierda) y avisos (toasts) arriba al centro.
	El estado llega como atributos del jugador: Dinero, MochilaUsada,
	MochilaMax, NombrePico, Durabilidad y DurabilidadMax (el pico), Dinamita,
	Fuerza y TituloFuerza.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Hud = {}

local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(28, 24, 22)
local TEXT = Color3.fromRGB(250, 244, 236)
local ORO = Color3.fromRGB(255, 200, 60)
local GOOD = Color3.fromRGB(110, 220, 130)
local BAD = Color3.fromRGB(255, 110, 110)
local INFO = Color3.fromRGB(150, 200, 255)

local KIND_COLORS = { good = GOOD, bad = BAD, info = INFO, gold = ORO }

local TITLE_FONT = Enum.Font.FredokaOne
local BODY_FONT = Enum.Font.GothamBold

-- Utilidades ---------------------------------------------------------------------

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function frame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = BODY_FONT
	l.TextColor3 = TEXT
	l.TextSize = 16
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextStrokeTransparency = 0.6
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

-- Para los menús (herrero, etc.): mismas piezas y colores que el HUD.
Hud.corner = corner
Hud.stroke = stroke
Hud.frame = frame
Hud.text = text
Hud.Colors = { PANEL = PANEL, TEXT = TEXT, ORO = ORO, GOOD = GOOD, BAD = BAD, INFO = INFO }
Hud.TITLE_FONT = TITLE_FONT

-- Construcción ---------------------------------------------------------------------

local gui: ScreenGui
local dineroLabel: TextLabel
local mochilaLabel: TextLabel
local mochilaStroke: UIStroke
local picoLabel: TextLabel
local picoStroke: UIStroke
local fuerzaLabel: TextLabel
local dinamitaChip: Frame
local dinamitaLabel: TextLabel
local profundidadChip: Frame
local profundidadLabel: TextLabel
local toastHolder: Frame

local function chip(parent: Instance, order: number, color: Color3): (Frame, TextLabel, UIStroke)
	local f = frame(parent, {
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		LayoutOrder = order,
	})
	corner(f, 15)
	local s = stroke(f, color, 1.5)
	s.Transparency = 0.3
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = f
	local l = text(f, {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = color,
	})
	return f, l, s
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10 -- los avisos se ven encima de los menús
	gui.Parent = player:WaitForChild("PlayerGui")

	local columna = frame(gui, {
		Name = "Estado",
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(260, 200),
		BackgroundTransparency = 1,
	})
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = columna

	local dinero = frame(columna, {
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.1,
		LayoutOrder = 1,
	})
	corner(dinero, 14)
	stroke(dinero, ORO, 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = dinero
	dineroLabel = text(dinero, {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = TITLE_FONT,
		TextSize = 28,
		TextColor3 = ORO,
	})

	local _, l1, s1 = chip(columna, 2, TEXT)
	mochilaLabel, mochilaStroke = l1, s1
	local _, l2, s2 = chip(columna, 3, Color3.fromRGB(230, 190, 140))
	picoLabel, picoStroke = l2, s2
	local f4, l4 = chip(columna, 4, Color3.fromRGB(255, 120, 100))
	dinamitaChip, dinamitaLabel = f4, l4
	local _, l5 = chip(columna, 5, Color3.fromRGB(255, 170, 90))
	fuerzaLabel = l5
	local f3, l3 = chip(columna, 6, INFO)
	profundidadChip, profundidadLabel = f3, l3

	toastHolder = frame(gui, {
		Name = "Avisos",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(560, 300),
		BackgroundTransparency = 1,
	})
	local tlayout = Instance.new("UIListLayout")
	tlayout.Padding = UDim.new(0, 6)
	tlayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tlayout.SortOrder = Enum.SortOrder.LayoutOrder
	tlayout.Parent = toastHolder
end

-- Actualización ----------------------------------------------------------------------

local function num(name: string): number
	return player:GetAttribute(name) or 0
end

local function refresh()
	dineroLabel.Text = "💰 " .. Format.money(num("Dinero"))
	local usada, max = num("MochilaUsada"), num("MochilaMax")
	mochilaLabel.Text = string.format("🎒 Mochila %d/%d", usada, max)
	local llena = max > 0 and usada >= max
	mochilaLabel.TextColor3 = if llena then BAD else TEXT
	mochilaStroke.Color = if llena then BAD else TEXT
	local dur, durMax = num("Durabilidad"), num("DurabilidadMax")
	local gastado = durMax > 0 and dur <= durMax * Config.DurabilidadBaja
	picoLabel.Text = string.format("⛏ %s · %d/%d", player:GetAttribute("NombrePico") or "Sin pico", dur, durMax)
	picoLabel.TextColor3 = if gastado then BAD else Color3.fromRGB(230, 190, 140)
	picoStroke.Color = picoLabel.TextColor3
	local dinamita = num("Dinamita")
	dinamitaChip.Visible = dinamita > 0
	dinamitaLabel.Text = string.format("🧨 Dinamita x%d", dinamita)
	fuerzaLabel.Text = string.format("💪 Fuerza %d · %s", num("Fuerza"), player:GetAttribute("TituloFuerza") or "Novato")
end

local function refreshProfundidad()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local y = root and root.Position.Y or 0
	local metros = math.floor(-y / 2) -- 1 metro = 2 studs, más o menos
	profundidadChip.Visible = y < -3
	if profundidadChip.Visible then
		local capa = "Mina"
		for _, c in Config.Capas do
			if y <= c.Arriba and y > c.Abajo then
				capa = c.Nombre
			end
		end
		profundidadLabel.Text = string.format("⬇ %d m · %s", metros, capa)
	end
end

local toastOrder = 0

function Hud.Toast(message: string, kind: string?)
	if not toastHolder then
		return
	end
	toastOrder += 1
	local color = KIND_COLORS[kind or "info"] or INFO
	local t = frame(toastHolder, {
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.08,
		LayoutOrder = toastOrder,
	})
	corner(t, 17)
	local s = stroke(t, color, 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = t
	local l = text(t, {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = message,
	})
	local items = {}
	for _, c in toastHolder:GetChildren() do
		if c:IsA("Frame") then
			table.insert(items, c)
		end
	end
	if #items > 5 then
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		items[1]:Destroy()
	end
	task.delay(3.4, function()
		if not t.Parent then
			return
		end
		local info = TweenInfo.new(0.4)
		TweenService:Create(t, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(l, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(s, info, { Transparency = 1 }):Play()
		task.wait(0.45)
		t:Destroy()
	end)
end

function Hud.Start()
	build()
	refresh()
	player.AttributeChanged:Connect(refresh)
	Remotes.Aviso.OnClientEvent:Connect(Hud.Toast)
	local acumulado = 0
	RunService.Heartbeat:Connect(function(dt)
		acumulado += dt
		if acumulado >= 0.25 then
			acumulado = 0
			refreshProfundidad()
		end
	end)
end

return Hud
