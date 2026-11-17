--[[
	Datos persistentes de cada jugador en DataStore.
	Si DataStore no está disponible (por ejemplo en Studio sin "Enable Studio
	Access to API Services"), el juego funciona con datos de sesión y no guarda,
	para no pisar datos reales con datos vacíos.
	La mochila no se guarda: lo que no vendiste se pierde al salir.
]]

local DataStoreService = game:GetService("DataStoreService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local PlayerData = {}

local profiles: { [Player]: any } = {}
local canSave: { [Player]: boolean } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStore no disponible: " .. tostring(result))
	end
end

local function defaults()
	return {
		Dinero = Config.DineroInicial,
		NivelPico = 1,
		DurabilidadPico = Config.Picos[1].Durabilidad,
		Dinamita = 0,
		Fuerza = 0, -- nivel
		FuerzaXP = 0, -- experiencia hacia el siguiente nivel
		NivelBanca = 1,
		TotalGanado = 0,
		UltimaVez = 0,
	}
end

local function merge(saved: any)
	local data = defaults()
	if type(saved) ~= "table" then
		return data
	end
	for key, value in data do
		if type(saved[key]) == type(value) then
			data[key] = saved[key]
		end
	end
	data.NivelPico = math.clamp(math.floor(data.NivelPico), 1, #Config.Picos)
	local max = Config.Picos[data.NivelPico].Durabilidad
	if type(saved.DurabilidadPico) ~= "number" then
		data.DurabilidadPico = max -- guardado viejo, sin durabilidad: pico nuevo
	end
	data.DurabilidadPico = math.clamp(math.floor(data.DurabilidadPico), 0, max)
	data.Dinamita = math.clamp(math.floor(data.Dinamita), 0, Config.Dinamita.Maximo)
	data.Fuerza = math.clamp(math.floor(data.Fuerza), 0, Config.Fuerza.Maximo)
	data.FuerzaXP = math.max(0, data.FuerzaXP)
	data.NivelBanca = math.clamp(math.floor(data.NivelBanca), 1, #Config.Bancas)
	return data
end

local function key(player: Player): string
	return "p_" .. player.UserId
end

function PlayerData.Load(player: Player)
	local data = defaults()
	local loaded = false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return (store :: DataStore):GetAsync(key(player))
			end)
			if ok then
				loaded = true
				data = merge(result)
				break
			end
			warn(string.format("[PlayerData] Error al cargar %s (intento %d): %s", player.Name, attempt, tostring(result)))
			if attempt < 3 then
				task.wait(1)
			end
		end
	end
	if not loaded then
		warn("[PlayerData] Jugando sin guardado para " .. player.Name)
	end
	canSave[player] = loaded
	profiles[player] = data
	return data
end

function PlayerData.Get(player: Player)
	return profiles[player]
end

function PlayerData.Save(player: Player)
	local data = profiles[player]
	if not data or not canSave[player] or not store then
		return
	end
	data.UltimaVez = os.time()
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(key(player), data)
	end)
	if not ok then
		warn("[PlayerData] Error al guardar " .. player.Name .. ": " .. tostring(err))
	end
end

-- Muestra el dinero en el atributo "Dinero" (HUD) y en leaderstats.
function PlayerData.Sync(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	player:SetAttribute("Dinero", data.Dinero)
	local stats = player:FindFirstChild("leaderstats")
	local dinero = stats and stats:FindFirstChild("Dinero") :: IntValue?
	if dinero then
		dinero.Value = data.Dinero
	end
end

function PlayerData.Release(player: Player)
	profiles[player] = nil
	canSave[player] = nil
end

function PlayerData.All()
	return profiles
end

return PlayerData
