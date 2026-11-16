--[[
	Menú del herrero: muestra tu pico (velocidad y durabilidad) y tres botones:
	mejorar al siguiente pico, reparar con dinero y reparar con hierro.
	Se abre con Remotes.AbrirHerrero y se cierra con la X o al alejarte.
	Todo se lee de los atributos del jugador; el servidor decide si se puede.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Hud = require(script.Parent.Hud)

local HerreroMenu = {}

local player = Players.LocalPlayer
local C = Hud.Colors
local NARANJA = Color3.fromRGB(255, 150, 60)
local APAGADO = Color3.fromRGB(70, 66, 62)

local gui: ScreenGui
local nombreLabel: TextLabel
local muestra: Frame
local statsLabel: TextLabel
local barra: Frame
local botones: { [string]: TextButton } = {}

local function num(name: string): number
	return player:GetAttribute(name) or 0
end

local function velocidad(pico): string
	return string.format("%.1f golpes/s", 1 / pico.Cadencia)
end

-- Qué abre un pico nuevo: rocas y minerales que pide justo ese nivel.
local function abre(pico): string
	local cosas = {}
	for _, roca in Config.Rocas do
		if roca.Nivel == pico.Nivel then
			table.insert(cosas, string.lower(roca.Nombre))
		end
	end
	for _, mineral in Config.Minerales do
		if mineral.NivelPico == pico.Nivel then
			table.insert(cosas, mineral.Nombre)
		end
	end
	if #cosas == 0 then
		return ""
	end
	return " · rompe " .. table.concat(cosas, ", ")
end

local function boton(parent: Instance, accion: string, order: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = accion
	b.Size = UDim2.new(1, 0, 0, 54)
	b.BackgroundColor3 = NARANJA
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextColor3 = C.TEXT
	b.TextWrapped = true
	b.RichText = true
	b.LayoutOrder = order
	b.Parent = parent
	Hud.corner(b, 12)
	b.Activated:Connect(function()
		if b:GetAttribute("Activo") then
			Remotes.Herrero:FireServer(accion)
		end
	end)
	botones[accion] = b
	return b
end

local function estado(b: TextButton, activo: boolean, color: Color3, texto: string)
	b:SetAttribute("Activo", activo)
	b.BackgroundColor3 = if activo then color else APAGADO
	b.AutoButtonColor = activo
	b.TextColor3 = if activo then C.TEXT else Color3.fromRGB(170, 164, 158)
	b.Text = texto
end

local function refresh()
	if not gui or not gui.Enabled then
		return
	end
	local nivel = math.max(1, num("NivelPico"))
	local pico = Config.Picos[nivel]
	local dinero = num("Dinero")
	local dur, max = num("Durabilidad"), pico.Durabilidad

	nombreLabel.Text = pico.Nombre
	muestra.BackgroundColor3 = pico.Color
	statsLabel.Text = string.format("%s · durabilidad %d/%d", velocidad(pico), dur, max)
	barra.Size = UDim2.fromScale(math.clamp(dur / max, 0, 1), 1)
	barra.BackgroundColor3 = if dur <= max * Config.DurabilidadBaja then C.BAD else C.GOOD

	local siguiente = Config.Picos[nivel + 1]
	if siguiente then
		estado(
			botones.Mejorar,
			dinero >= siguiente.Precio,
			NARANJA,
			string.format(
				"Mejorar a %s · %s\n<font size=\"13\">%s · durabilidad %d%s</font>",
				siguiente.Nombre,
				Format.money(siguiente.Precio),
				velocidad(siguiente),
				siguiente.Durabilidad,
				abre(siguiente)
			)
		)
	else
		estado(botones.Mejorar, false, NARANJA, "Ya tienes el mejor pico")
	end

	local falta = max - dur
	if falta <= 0 then
		estado(botones.Reparar, false, C.GOOD, "Tu pico está como nuevo")
		estado(botones.RepararHierro, false, C.INFO, "Reparar con hierro")
	else
		local costo = math.ceil(pico.Reparar * falta / max)
		estado(botones.Reparar, dinero >= costo, Color3.fromRGB(70, 150, 90), "Reparar · " .. Format.money(costo))
		local hierro = num("Mochila_Hierro")
		estado(
			botones.RepararHierro,
			hierro > 0,
			Color3.fromRGB(80, 120, 170),
			string.format(
				"Reparar con hierro (tienes %d)\n<font size=\"13\">cada hierro repara %d %%</font>",
				hierro,
				math.floor(Config.RepararPorHierro * 100)
			)
		)
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Herrero"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Hud.frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.PANEL,
		BackgroundTransparency = 0.04,
	})
	Hud.corner(panel, 18)
	Hud.stroke(panel, NARANJA, 2)
	local pad = Instance.new("UIPadding")
	for _, k in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(pad :: any)[k] = UDim.new(0, 16)
	end
	pad.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	-- Título y botón de cerrar.
	local titulo = Hud.frame(panel, { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 1 })
	Hud.text(titulo, {
		Size = UDim2.fromScale(1, 1),
		Font = Hud.TITLE_FONT,
		TextSize = 26,
		TextColor3 = NARANJA,
		Text = "🔨 El Herrero",
	})
	local cerrar = Instance.new("TextButton")
	cerrar.AnchorPoint = Vector2.new(1, 0)
	cerrar.Position = UDim2.fromScale(1, 0)
	cerrar.Size = UDim2.fromOffset(34, 34)
	cerrar.BackgroundColor3 = Color3.fromRGB(80, 60, 56)
	cerrar.Text = "X" -- el símbolo ✕ no se ve en Roblox
	cerrar.Font = Enum.Font.GothamBold
	cerrar.TextSize = 18
	cerrar.TextColor3 = C.TEXT
	cerrar.Parent = titulo
	Hud.corner(cerrar, 17)
	cerrar.Activated:Connect(HerreroMenu.Cerrar)

	-- Tarjeta del pico actual.
	local tarjeta = Hud.frame(panel, {
		Size = UDim2.new(1, 0, 0, 74),
		BackgroundColor3 = Color3.fromRGB(46, 40, 36),
		LayoutOrder = 2,
	})
	Hud.corner(tarjeta, 12)
	muestra = Hud.frame(tarjeta, {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(50, 50),
	})
	Hud.corner(muestra, 10)
	Hud.text(muestra, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 28,
		Text = "⛏",
	})
	nombreLabel = Hud.text(tarjeta, {
		Position = UDim2.fromOffset(74, 10),
		Size = UDim2.new(1, -86, 0, 22),
		TextSize = 19,
	})
	statsLabel = Hud.text(tarjeta, {
		Position = UDim2.fromOffset(74, 32),
		Size = UDim2.new(1, -86, 0, 18),
		TextSize = 14,
		TextColor3 = Color3.fromRGB(210, 200, 190),
	})
	local fondoBarra = Hud.frame(tarjeta, {
		Position = UDim2.fromOffset(74, 54),
		Size = UDim2.new(1, -90, 0, 8),
		BackgroundColor3 = Color3.fromRGB(30, 26, 24),
	})
	Hud.corner(fondoBarra, 4)
	barra = Hud.frame(fondoBarra, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.GOOD })
	Hud.corner(barra, 4)

	boton(panel, "Mejorar", 3)
	boton(panel, "Reparar", 4)
	boton(panel, "RepararHierro", 5)
end

function HerreroMenu.Abrir()
	gui.Enabled = true
	refresh()
end

function HerreroMenu.Cerrar()
	gui.Enabled = false
end

function HerreroMenu.Start()
	build()
	Remotes.AbrirHerrero.OnClientEvent:Connect(HerreroMenu.Abrir)
	player.AttributeChanged:Connect(refresh)
	-- Se cierra solo si te alejas del herrero.
	local lugar = Config.Mapa.Herrero
	RunService.Heartbeat:Connect(function()
		if not gui.Enabled then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(lugar.X, 0, lugar.Z)).Magnitude > 18 then
			HerreroMenu.Cerrar()
		end
	end)
end

return HerreroMenu
