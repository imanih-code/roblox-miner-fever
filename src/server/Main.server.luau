--[[
	Punto de entrada del servidor de Fiebre Minera: construye el mapa y la mina,
	pone al millonario y al herrero, arranca el pico y maneja entradas, salidas y
	reapariciones de jugadores (a cada personaje le pone casco con lámpara y pico).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
require(Shared.Remotes) -- crea los RemoteEvents antes de que los pida el cliente

local PlayerData = require(script.Parent.PlayerData)
local MapaBuilder = require(script.Parent.MapaBuilder)
local Mochila = require(script.Parent.Mochila)
local PicoService = require(script.Parent.PicoService)
local Millonario = require(script.Parent.Millonario)
local Casco = require(script.Parent.Casco)
local Herrero = require(script.Parent.Herrero)
local DinamitaService = require(script.Parent.DinamitaService)
local Pepitas = require(script.Parent.Pepitas)

Players.RespawnTime = Config.TiempoReaparicion

local mapa = MapaBuilder.Build()
Millonario.Build(mapa.mapa)
Herrero.Build(mapa.mapa)
Pepitas.Init()
PicoService.Init(mapa.minerales)
DinamitaService.Init()

local function onCharacter(player: Player, character: Model)
	task.spawn(Casco.Poner, character)
	-- En este orden, para que el pico quede en la ranura 1 y la dinamita en la 2.
	task.defer(PicoService.Dar, player)
	task.defer(DinamitaService.Sync, player)
end

local function onPlayerAdded(player: Player)
	PlayerData.Load(player)
	if not player.Parent then
		PlayerData.Release(player)
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local dinero = Instance.new("IntValue")
	dinero.Name = "Dinero"
	dinero.Parent = leaderstats
	leaderstats.Parent = player

	PlayerData.Sync(player)
	PicoService.Sync(player)
	player:SetAttribute("Dinamita", PlayerData.Get(player).Dinamita)
	Mochila.Crear(player)

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	PlayerData.Save(player)
	PlayerData.Release(player)
	Mochila.Liberar(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

task.spawn(function()
	while true do
		task.wait(Config.AutoguardadoCada)
		for player in PlayerData.All() do
			task.spawn(PlayerData.Save, player)
		end
	end
end)

game:BindToClose(function()
	local pendientes = 0
	for player in PlayerData.All() do
		pendientes += 1
		task.spawn(function()
			PlayerData.Save(player)
			pendientes -= 1
		end)
	end
	local limite = os.clock() + 20
	while pendientes > 0 and os.clock() < limite do
		task.wait(0.2)
	end
end)

-- Ganchos de prueba en Studio (barra de comandos con el juego corriendo):
--   workspace:SetAttribute("DarDinero", 500)
--   workspace:SetAttribute("PonerDurabilidad", 3)   (durabilidad del pico de todos)
if RunService:IsStudio() then
	workspace:GetAttributeChangedSignal("PonerDurabilidad"):Connect(function()
		local valor = workspace:GetAttribute("PonerDurabilidad")
		if type(valor) == "number" and valor >= 0 then
			workspace:SetAttribute("PonerDurabilidad", nil)
			for _, player in Players:GetPlayers() do
				local data = PlayerData.Get(player)
				if data then
					data.DurabilidadPico = math.min(math.floor(valor), Config.Picos[data.NivelPico].Durabilidad)
					PicoService.Sync(player)
				end
			end
		end
	end)
	workspace:GetAttributeChangedSignal("DarDinero"):Connect(function()
		local cantidad = workspace:GetAttribute("DarDinero")
		if type(cantidad) == "number" and cantidad > 0 then
			workspace:SetAttribute("DarDinero", 0)
			for _, player in Players:GetPlayers() do
				local data = PlayerData.Get(player)
				if data then
					data.Dinero += cantidad
					PlayerData.Sync(player)
				end
			end
		end
	end)
end

print("[Fiebre Minera] Servidor listo")
