--[[
	Punto de entrada del cliente de Fiebre Minera: arranca el HUD, los golpes
	del pico, la dinamita, el menú del herrero y el ambiente (nevada arriba,
	oscuridad en la mina).
]]

local Hud = require(script.Parent.Hud)
local PicoCliente = require(script.Parent.PicoCliente)
local DinamitaCliente = require(script.Parent.DinamitaCliente)
local HerreroMenu = require(script.Parent.HerreroMenu)
local Ambiente = require(script.Parent.Ambiente)

Hud.Start()
PicoCliente.Start()
DinamitaCliente.Start()
HerreroMenu.Start()
Ambiente.Start()

print("[Fiebre Minera] Cliente listo")
