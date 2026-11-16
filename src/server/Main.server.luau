--[[
	Punto de entrada del servidor de Fiebre Minera.
	Por ahora solo carga la configuración y avisa que arrancó; aquí se irán
	iniciando los servicios (mina, minerales, millonario, herrero, campamento).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local _ = Config -- se usará cuando haya servicios

print("[Fiebre Minera] Servidor listo")
