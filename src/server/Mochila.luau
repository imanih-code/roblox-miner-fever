--[[
	Mochila de cada jugador: minerales chicos que lleva encima (no se guarda).
	El cliente la ve con los atributos del jugador:
	  MochilaUsada, MochilaMax y "Mochila_<id>" por mineral.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Mochila = {}

local contenidos: { [Player]: { [string]: number } } = {}

local function total(c: { [string]: number }): number
	local n = 0
	for _, cantidad in c do
		n += cantidad
	end
	return n
end

local function sync(player: Player)
	local c = contenidos[player] or {}
	player:SetAttribute("MochilaUsada", total(c))
	player:SetAttribute("MochilaMax", Mochila.Capacidad(player))
	for id in Config.Minerales do
		player:SetAttribute("Mochila_" .. id, c[id] or 0)
	end
end

function Mochila.Crear(player: Player)
	contenidos[player] = {}
	sync(player)
end

function Mochila.Capacidad(_player: Player): number
	return Config.MochilaInicial
end

function Mochila.Llena(player: Player): boolean
	return total(contenidos[player] or {}) >= Mochila.Capacidad(player)
end

-- Agrega un mineral. Devuelve false si no cabe.
function Mochila.Agregar(player: Player, id: string): boolean
	local c = contenidos[player]
	if not c or Mochila.Llena(player) then
		return false
	end
	c[id] = (c[id] or 0) + 1
	sync(player)
	return true
end

-- Saca todo y devuelve lo que había: { [id] = cantidad }.
function Mochila.Vaciar(player: Player): { [string]: number }
	local c = contenidos[player] or {}
	contenidos[player] = {}
	sync(player)
	return c
end

function Mochila.Usada(player: Player): number
	return total(contenidos[player] or {})
end

function Mochila.Quitar(player: Player)
	contenidos[player] = nil
end

return Mochila
