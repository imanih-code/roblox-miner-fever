--[[
	Punto de entrada del cliente de Fiebre Minera: arranca el HUD, los golpes
	del pico y la oscuridad de la mina.
]]

local Hud = require(script.Parent.Hud)
local PicoCliente = require(script.Parent.PicoCliente)
local Oscuridad = require(script.Parent.Oscuridad)

Hud.Start()
PicoCliente.Start()
Oscuridad.Start()

print("[Fiebre Minera] Cliente listo")
