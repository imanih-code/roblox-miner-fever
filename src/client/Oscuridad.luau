--[[
	Oscuridad de la mina: cuando bajas de Config.Mapa.AlturaOscuridad se apaga
	la luz del cielo (solo en tu pantalla) y solo alumbran las lámparas y los
	faroles. Al salir vuelve la luz de día.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Oscuridad = {}

local player = Players.LocalPlayer

local OSCURO = {
	Ambient = Color3.fromRGB(0, 0, 0),
	OutdoorAmbient = Color3.fromRGB(6, 6, 8),
	Brightness = 0,
	EnvironmentDiffuseScale = 0,
	EnvironmentSpecularScale = 0,
	ExposureCompensation = 0.3,
}

local dia: { [string]: any } = {}
local dentro = false

local function cambiar(valores: { [string]: any })
	TweenService:Create(Lighting, TweenInfo.new(0.8), valores):Play()
end

function Oscuridad.Start()
	for k in OSCURO do
		dia[k] = (Lighting :: any)[k]
	end
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local abajo = root.Position.Y < Config.Mapa.AlturaOscuridad
		if abajo ~= dentro then
			dentro = abajo
			cambiar(if abajo then OSCURO else dia)
		end
	end)
end

return Oscuridad
