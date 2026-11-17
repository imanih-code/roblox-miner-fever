--[[
	Campamento: cada jugador tiene un lugar para su banca de pesas, en arco
	alrededor de la boca de la mina (ver BancaModelo.Lugar). Sin tiendas: nada
	tapa la vista.
	  - Tu banca la dibuja tu propio cliente (solo la ves tú).
	  - Al tocarla, el cliente pide entrenar: el servidor pone la banca de verdad
	    (la ven todos), te acuesta y la barra sube y baja. Al levantarte, desaparece.
	  - Mejorar la banca (desde el panel de entrenamiento) cambia la skin y da más
	    Fuerza por segundo.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)
local BancaModelo = require(Shared.BancaModelo)

local PlayerData = require(script.Parent.PlayerData)

local Campamento = {}

type EnUso = { modelo: Model, asiento: Seat, tween: Tween? }

local duenos: { [number]: Player } = {} -- lugar -> jugador
local lugarDe: { [Player]: number } = {}
local enUso: { [Player]: EnUso } = {}
local ultimoPedido: { [Player]: number } = {}
local carpeta: Folder

local function aviso(player: Player, texto: string, tipo: string)
	Remotes.Aviso:FireClient(player, texto, tipo)
end

local function quitarBanca(player: Player)
	local u = enUso[player]
	enUso[player] = nil
	if u then
		if u.tween then
			u.tween:Cancel()
		end
		u.modelo:Destroy()
	end
end

-- Pone la banca de verdad (la ven todos) y acuesta al jugador en ella.
local function ponerBanca(player: Player, humanoid: Humanoid)
	local data = PlayerData.Get(player)
	local lugar = lugarDe[player]
	local cf = lugar and BancaModelo.Lugar(lugar)
	if not data or not cf then
		return
	end
	quitarBanca(player)
	local b = BancaModelo.Crear(data.NivelBanca, cf)
	b.modelo.Name = "Banca_" .. player.UserId
	-- Asiento invisible, inclinado: el personaje queda acostado boca arriba.
	local asiento = Instance.new("Seat")
	asiento.Name = "Asiento"
	asiento.Anchored = true
	asiento.CanTouch = false
	asiento.CanCollide = false
	asiento.Transparency = 1
	asiento.Size = Vector3.new(1.4, 0.2, 1.4)
	asiento.CFrame = b.asiento
	asiento.Parent = b.modelo
	b.modelo.Parent = carpeta
	-- La barra sube y baja.
	local info = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(b.barra, info, { CFrame = b.reposo * CFrame.new(0, -0.8, 0) })
	tween:Play()
	local u: EnUso = { modelo = b.modelo, asiento = asiento, tween = tween }
	enUso[player] = u
	asiento:GetPropertyChangedSignal("Occupant"):Connect(function()
		if asiento.Occupant == nil then
			task.delay(0.2, function()
				if enUso[player] == u and asiento.Occupant == nil then
					quitarBanca(player)
				end
			end)
		end
	end)
	asiento:Sit(humanoid)
end

local function entrenar(player: Player)
	local lugar = lugarDe[player]
	local cf = lugar and BancaModelo.Lugar(lugar)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not cf or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	if Campamento.Entrenando(player) then
		return
	end
	-- Hay que estar junto a tu banca.
	if (root.Position - cf.Position).Magnitude > 10 then
		return
	end
	ponerBanca(player, humanoid)
end

function Campamento.Mejorar(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local siguiente = Config.Bancas[data.NivelBanca + 1]
	if not siguiente then
		return
	end
	if data.Dinero < siguiente.Precio then
		aviso(player, string.format("Te faltan %s para la %s.", Format.money(siguiente.Precio - data.Dinero), siguiente.Nombre), "bad")
		return
	end
	data.Dinero -= siguiente.Precio
	data.NivelBanca += 1
	PlayerData.Sync(player)
	player:SetAttribute("NivelBanca", data.NivelBanca)
	-- Si estaba entrenando, la banca nueva aparece con él acostado.
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and Campamento.Entrenando(player) then
		local u = enUso[player] :: EnUso
		local soldadura = u.asiento:FindFirstChild("SeatWeld")
		if soldadura then
			soldadura:Destroy()
		end
		ponerBanca(player, humanoid)
	end
	aviso(player, string.format("💪 ¡Ahora tienes la %s! (+%s Fuerza/s)", siguiente.Nombre, tostring(siguiente.PorSegundo)), "gold")
	task.spawn(PlayerData.Save, player)
end

local function onBanca(player: Player, accion: any)
	local ahora = os.clock()
	if accion ~= "Levantarse" and ahora - (ultimoPedido[player] or 0) < 0.8 then
		return
	end
	ultimoPedido[player] = ahora
	if accion == "Entrenar" then
		entrenar(player)
	elseif accion == "Levantarse" then
		Campamento.Bajar(player)
	elseif accion == "Mejorar" then
		Campamento.Mejorar(player)
	end
end

-- Jugadores -----------------------------------------------------------------------------

function Campamento.Asignar(player: Player)
	for i = 1, BancaModelo.Cantidad() do
		if not duenos[i] then
			duenos[i] = player
			lugarDe[player] = i
			local data = PlayerData.Get(player)
			player:SetAttribute("NivelBanca", data and data.NivelBanca or 1)
			player:SetAttribute("BancaLugar", i) -- el cliente dibuja su banca aquí
			return
		end
	end
end

function Campamento.Liberar(player: Player)
	quitarBanca(player)
	local i = lugarDe[player]
	lugarDe[player] = nil
	ultimoPedido[player] = nil
	if i then
		duenos[i] = nil
	end
end

-- ¿Está acostado en su banca?
function Campamento.Entrenando(player: Player): boolean
	local u = enUso[player]
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return u ~= nil and humanoid ~= nil and u.asiento.Occupant == humanoid
end

-- Lo baja de la banca (saltó o se cansó) y la banca desaparece.
function Campamento.Bajar(player: Player)
	local u = enUso[player]
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if u then
		local soldadura = u.asiento:FindFirstChild("SeatWeld")
		if soldadura then
			soldadura:Destroy()
		end
		quitarBanca(player)
	end
	if humanoid then
		humanoid.Sit = false
		humanoid.Jump = true
	end
end

function Campamento.Build(destino: Instance)
	carpeta = Instance.new("Folder")
	carpeta.Name = "Bancas"
	carpeta.Parent = destino
	Remotes.Banca.OnServerEvent:Connect(onBanca)
	Players.PlayerRemoving:Connect(Campamento.Liberar)
end

return Campamento
