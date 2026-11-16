--[[
	Punto de entrada del servidor de Fiebre Minera: construye el mapa y la mina,
	pone al millonario, arranca el pico y maneja entradas, salidas y
	reapariciones de jugadores (lámpara y pico en cada personaje).
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

Players.RespawnTime = Config.TiempoReaparicion

local mapa = MapaBuilder.Build()
Millonario.Build(mapa.mapa)
PicoService.Init(mapa.minerales)

-- La lámpara: una luz cálida en la cabeza que ven todos.
local function ponerLampara(character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head then
		return
	end
	local luz = Instance.new("PointLight")
	luz.Name = "Lampara"
	luz.Range = Config.Lampara.Alcance
	luz.Brightness = Config.Lampara.Brillo
	luz.Color = Config.Lampara.Color
	luz.Shadows = true
	luz.Parent = head
end

local function onCharacter(player: Player, character: Model)
	task.spawn(ponerLampara, character)
	task.defer(PicoService.Dar, player)
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
	Mochila.Quitar(player)
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
if RunService:IsStudio() then
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
