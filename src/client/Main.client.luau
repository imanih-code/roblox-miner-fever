--[[
	Punto de entrada del cliente de Fiebre Minera: arranca el HUD, los golpes
	del pico y el ambiente (nevada arriba, oscuridad en la mina).
]]

local Hud = require(script.Parent.Hud)
local PicoCliente = require(script.Parent.PicoCliente)
local Ambiente = require(script.Parent.Ambiente)

Hud.Start()
PicoCliente.Start()
Ambiente.Start()

print("[Fiebre Minera] Cliente listo")
