--[[
	Fuerza: mientras estás acostado en tu banca ganas experiencia cada segundo
	(según el nivel de la banca) y subes de nivel (tope en Config.Fuerza.Maximo).
	Solo sirve para los minerales: los picas más rápido (ver PicoService).
	Anti-AFK mientras entrenas:
	  - Bono: cada tanto aparece un botón opcional que da varios segundos extra.
	  - Cansancio: cada pocos minutos sale un botón; si no le das clic a tiempo,
	    te bajas de la banca.
	Se ve: título sobre la cabeza (Novato … Titán) y tablero de los más fuertes.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Campamento = require(script.Parent.Campamento)

local Fuerza = {}

local F = Config.Fuerza

type Evento = { id: number, vence: number }
type Estado = { proxBono: number, proxCansancio: number, bono: Evento?, cansancio: Evento?, entrenaba: boolean }

local estados: { [Player]: Estado } = {}
local siguienteId = 0
local rng = Random.new()

local tableroLista: Frame

-- Experiencia para subir del nivel `nivel` al siguiente.
function Fuerza.XPNecesaria(nivel: number): number
	return math.floor(F.XPBase * F.Crecimiento ^ nivel)
end

function Fuerza.Titulo(nivel: number): string
	local titulo = F.Titulos[1].Nombre
	for _, t in F.Titulos do
		if nivel >= t.Desde then
			titulo = t.Nombre
		end
	end
	return titulo
end

-- Título sobre la cabeza: "Picador · 12".
local function ponerTitulo(player: Player)
	local data = PlayerData.Get(player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not data or not head then
		return
	end
	local gui = head:FindFirstChild("TituloFuerza") :: BillboardGui?
	if not gui then
		local nuevo = Instance.new("BillboardGui")
		nuevo.Name = "TituloFuerza"
		nuevo.Size = UDim2.fromOffset(150, 22)
		nuevo.StudsOffset = Vector3.new(0, 3.4, 0)
		nuevo.MaxDistance = 60
		local l = Instance.new("TextLabel")
		l.Name = "Texto"
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBold
		l.TextScaled = true
		l.TextColor3 = Color3.fromRGB(255, 200, 120)
		l.TextStrokeTransparency = 0.4
		l.Parent = nuevo
		nuevo.Parent = head
		gui = nuevo
	end
	((gui :: BillboardGui):FindFirstChild("Texto") :: TextLabel).Text =
		string.format("💪 %s · %d", Fuerza.Titulo(data.Fuerza), data.Fuerza)
end

function Fuerza.Sync(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	player:SetAttribute("Fuerza", data.Fuerza)
	player:SetAttribute("FuerzaXP", math.floor(data.FuerzaXP))
	player:SetAttribute("FuerzaSig", if data.Fuerza >= F.Maximo then 0 else Fuerza.XPNecesaria(data.Fuerza))
	player:SetAttribute("TituloFuerza", Fuerza.Titulo(data.Fuerza))
	ponerTitulo(player)
end

-- Suma experiencia y sube los niveles que alcance.
function Fuerza.Sumar(player: Player, xp: number)
	local data = PlayerData.Get(player)
	if not data or data.Fuerza >= F.Maximo then
		return
	end
	data.FuerzaXP += xp
	local subio = false
	local tituloAntes = Fuerza.Titulo(data.Fuerza)
	while data.Fuerza < F.Maximo and data.FuerzaXP >= Fuerza.XPNecesaria(data.Fuerza) do
		data.FuerzaXP -= Fuerza.XPNecesaria(data.Fuerza)
		data.Fuerza += 1
		subio = true
	end
	if data.Fuerza >= F.Maximo then
		data.FuerzaXP = 0
	end
	if subio then
		Remotes.Aviso:FireClient(
			player,
			string.format("💪 ¡Fuerza %d! Picas minerales %d %% más rápido.", data.Fuerza, math.floor(data.Fuerza * F.BonoMineral * 100 + 0.5)),
			"gold"
		)
		local titulo = Fuerza.Titulo(data.Fuerza)
		if titulo ~= tituloAntes then
			Remotes.Aviso:FireAllClients(string.format("⭐ %s ahora es %s", player.DisplayName, titulo), "gold")
		end
	end
	Fuerza.Sync(player)
end

-- Eventos de la banca (bono y cansancio) ---------------------------------------------------

local function nuevoId(): number
	siguienteId += 1
	return siguienteId
end

local function terminar(player: Player, e: Evento?)
	if e then
		Remotes.FuerzaEvento:FireClient(player, "Fin", e.id)
	end
end

local function reiniciarTiempos(estado: Estado, ahora: number)
	estado.proxBono = ahora + rng:NextNumber(F.Bono.CadaMin, F.Bono.CadaMax)
	estado.proxCansancio = ahora + rng:NextNumber(F.Cansancio.CadaMin, F.Cansancio.CadaMax)
end

local function onClic(player: Player, id: any)
	local estado = estados[player]
	if not estado or type(id) ~= "number" then
		return
	end
	local ahora = os.clock()
	local bono, cansancio = estado.bono, estado.cansancio
	if bono and bono.id == id and ahora <= bono.vence then
		estado.bono = nil
		terminar(player, bono)
		local data = PlayerData.Get(player)
		local porSegundo = Config.Bancas[data and data.NivelBanca or 1].PorSegundo
		Fuerza.Sumar(player, porSegundo * F.Bono.Segundos)
		Remotes.Aviso:FireClient(player, string.format("💪 ¡Bonus! +%d de experiencia", porSegundo * F.Bono.Segundos), "good")
	elseif cansancio and cansancio.id == id and ahora <= cansancio.vence then
		estado.cansancio = nil
		terminar(player, cansancio)
		Remotes.Aviso:FireClient(player, "¡Bien! Sigues entrenando.", "good")
	end
end

-- Cada segundo: experiencia para los que entrenan y sus eventos.
local function cadaSegundo()
	local ahora = os.clock()
	for player, estado in estados do
		local data = PlayerData.Get(player)
		local entrena = data ~= nil and Campamento.Entrenando(player)
		if entrena and not estado.entrenaba then
			reiniciarTiempos(estado, ahora)
		elseif not entrena and estado.entrenaba then
			terminar(player, estado.bono)
			terminar(player, estado.cansancio)
			estado.bono, estado.cansancio = nil, nil
		end
		estado.entrenaba = entrena
		player:SetAttribute("Entrenando", entrena)
		if entrena and data then
			Fuerza.Sumar(player, Config.Bancas[data.NivelBanca].PorSegundo)
			-- Bono opcional.
			if estado.bono and ahora > estado.bono.vence then
				terminar(player, estado.bono)
				estado.bono = nil
			elseif not estado.bono and ahora >= estado.proxBono then
				estado.bono = { id = nuevoId(), vence = ahora + F.Bono.Dura }
				estado.proxBono = ahora + rng:NextNumber(F.Bono.CadaMin, F.Bono.CadaMax)
				Remotes.FuerzaEvento:FireClient(player, "Bono", estado.bono.id, F.Bono.Dura)
			end
			-- Cansancio: si vence sin clic, se baja.
			if estado.cansancio and ahora > estado.cansancio.vence then
				terminar(player, estado.cansancio)
				estado.cansancio = nil
				Campamento.Bajar(player)
				Remotes.Aviso:FireClient(player, "Te cansaste y te bajaste de la banca. Vuelve cuando quieras.", "bad")
			elseif not estado.cansancio and ahora >= estado.proxCansancio then
				estado.cansancio = { id = nuevoId(), vence = ahora + F.Cansancio.Plazo }
				estado.proxCansancio = ahora + rng:NextNumber(F.Cansancio.CadaMin, F.Cansancio.CadaMax)
				Remotes.FuerzaEvento:FireClient(player, "Cansancio", estado.cansancio.id, F.Cansancio.Plazo)
			end
		end
	end
end

-- Tablero de los más fuertes ----------------------------------------------------------

local function crearTablero(carpeta: Instance)
	local pos = Config.Campamento.Tablero + Vector3.new(0, Config.Mapa.Suelo, 0)
	local poste = Instance.new("Model")
	poste.Name = "TableroFuerza"
	local tabla = Instance.new("Part")
	tabla.Name = "Tabla"
	tabla.Anchored = true
	tabla.Size = Vector3.new(0.4, 7, 12)
	-- Delgada en x: su cara derecha (+x) mira hacia la aparición.
	tabla.CFrame = CFrame.new(pos + Vector3.new(0, 5.5, 0))
	tabla.Color = Color3.fromRGB(70, 48, 30)
	tabla.Material = Enum.Material.WoodPlanks
	tabla.Parent = poste
	for _, dz in { -5.3, 5.3 } do
		local pata = Instance.new("Part")
		pata.Anchored = true
		pata.Size = Vector3.new(0.5, 9, 0.5)
		pata.CFrame = CFrame.new(pos + Vector3.new(0, 4.5, dz))
		pata.Color = Color3.fromRGB(96, 68, 44)
		pata.Material = Enum.Material.Wood
		pata.Parent = poste
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = tabla
	local titulo = Instance.new("TextLabel")
	titulo.Size = UDim2.new(1, 0, 0.18, 0)
	titulo.BackgroundTransparency = 1
	titulo.Font = Enum.Font.FredokaOne
	titulo.TextScaled = true
	titulo.TextColor3 = Color3.fromRGB(255, 200, 80)
	titulo.Text = "Los más fuertes"
	titulo.Parent = gui
	tableroLista = Instance.new("Frame")
	tableroLista.Position = UDim2.fromScale(0.05, 0.2)
	tableroLista.Size = UDim2.fromScale(0.9, 0.78)
	tableroLista.BackgroundTransparency = 1
	tableroLista.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tableroLista
	poste.Parent = carpeta
end

local function actualizarTablero()
	if not tableroLista then
		return
	end
	local lista = {}
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player)
		if data then
			table.insert(lista, { nombre = player.DisplayName, fuerza = data.Fuerza, xp = data.FuerzaXP })
		end
	end
	table.sort(lista, function(a, b)
		if a.fuerza ~= b.fuerza then
			return a.fuerza > b.fuerza
		end
		return a.xp > b.xp
	end)
	tableroLista:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tableroLista
	for i = 1, math.min(8, #lista) do
		local fila = lista[i]
		local l = Instance.new("TextLabel")
		l.LayoutOrder = i
		l.Size = UDim2.new(1, 0, 0.125, 0)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBold
		l.TextScaled = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = if i == 1 then Color3.fromRGB(255, 214, 90) else Color3.fromRGB(240, 232, 220)
		l.Text = string.format("%d. %s · %d", i, fila.nombre, fila.fuerza)
		l.Parent = tableroLista
	end
end

-- Inicio ---------------------------------------------------------------------------------

function Fuerza.Agregar(player: Player)
	estados[player] = { proxBono = 0, proxCansancio = 0, entrenaba = false }
	Fuerza.Sync(player)
end

function Fuerza.Init(carpeta: Instance)
	crearTablero(carpeta)
	Remotes.FuerzaClic.OnServerEvent:Connect(onClic)
	Players.PlayerRemoving:Connect(function(player)
		estados[player] = nil
	end)
	task.spawn(function()
		local vueltas = 0
		while true do
			task.wait(1)
			cadaSegundo()
			vueltas += 1
			if vueltas % 3 == 0 then
				actualizarTablero()
			end
		end
	end)
	-- Ganchos de prueba en Studio:
	--   workspace:SetAttribute("DarFuerzaXP", 500)
	--   workspace:SetAttribute("ForzarEventosBanca", true)  (bono y cansancio ya)
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("ForzarEventosBanca"):Connect(function()
			if workspace:GetAttribute("ForzarEventosBanca") then
				workspace:SetAttribute("ForzarEventosBanca", nil)
				for _, estado in estados do
					estado.proxBono, estado.proxCansancio = 0, 0
				end
			end
		end)
		workspace:GetAttributeChangedSignal("DarFuerzaXP"):Connect(function()
			local xp = workspace:GetAttribute("DarFuerzaXP")
			if type(xp) == "number" and xp > 0 then
				workspace:SetAttribute("DarFuerzaXP", nil)
				for _, player in Players:GetPlayers() do
					Fuerza.Sumar(player, xp)
				end
			end
		end)
	end
end

Fuerza.PonerTitulo = ponerTitulo

return Fuerza
