--[[
	Punto de entrada del cliente de Fiebre Minera.
	Por ahora solo carga la configuración y avisa que arrancó; aquí se irán
	iniciando el HUD, el picado, la lámpara y los menús.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local _ = Config -- se usará cuando haya HUD y herramientas

print("[Fiebre Minera] Cliente listo")
