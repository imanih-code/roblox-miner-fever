--[[
	Ambiente en tu pantalla:
	  - Arriba nieva: un emisor de copos que sigue a la cámara.
	  - Al bajar de Config.Mapa.AlturaOscuridad se apaga la luz del cielo y la
	    bruma, y solo alumbran las lámparas y los faroles. Al salir vuelve el día.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Ambiente = {}

local player = Players.LocalPlayer

local OSCURO = {
	Ambient = Color3.fromRGB(0, 0, 0),
	OutdoorAmbient = Color3.fromRGB(6, 6, 8),
	Brightness = 0,
	EnvironmentDiffuseScale = 0,
	EnvironmentSpecularScale = 0,
	ExposureCompensation = 0.3,
}
local OSCURO_BRUMA = { Density = 0, Haze = 0, Glare = 0 }

local dia: { [string]: any } = {}
local diaBruma: { [string]: any } = {}
local dentro = false
local nevada: ParticleEmitter

local function cambiar(objeto: Instance?, valores: { [string]: any })
	if objeto and next(valores) then
		TweenService:Create(objeto, TweenInfo.new(0.8), valores):Play()
	end
end

-- Guarda la luz de día justo antes de oscurecer (el servidor la pone al arrancar).
local function guardarDia(bruma: Atmosphere?)
	for k in OSCURO do
		dia[k] = (Lighting :: any)[k]
	end
	table.clear(diaBruma)
	if bruma then
		for k in OSCURO_BRUMA do
			diaBruma[k] = (bruma :: any)[k]
		end
	end
end

local function crearNevada()
	local nube = Instance.new("Part")
	nube.Name = "Nevada"
	nube.Anchored = true
	nube.CanCollide = false
	nube.CanQuery = false
	nube.CanTouch = false
	nube.Transparency = 1
	nube.Size = Vector3.new(140, 1, 140)
	nube.Parent = workspace.CurrentCamera
	local e = Instance.new("ParticleEmitter")
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Rate = 260
	e.Lifetime = NumberRange.new(5, 7)
	e.Speed = NumberRange.new(7, 11)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Acceleration = Vector3.new(3, -1, 1.5) -- viento
	e.Size = NumberSequence.new(0.22)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.15),
		NumberSequenceKeypoint.new(0.85, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Color = ColorSequence.new(Color3.fromRGB(245, 248, 255))
	e.LightEmission = 0.2
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Parent = nube
	return nube, e
end

function Ambiente.Start()
	local nube
	nube, nevada = crearNevada()
	RunService.RenderStepped:Connect(function()
		local camara = workspace.CurrentCamera
		nube.CFrame = CFrame.new(camara.CFrame.Position + Vector3.new(0, 35, 0))

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local abajo = root.Position.Y < Config.Mapa.AlturaOscuridad
		if abajo ~= dentro then
			dentro = abajo
			nevada.Enabled = not abajo
			local bruma = Lighting:FindFirstChildOfClass("Atmosphere")
			if abajo then
				guardarDia(bruma)
				cambiar(Lighting, OSCURO)
				cambiar(bruma, OSCURO_BRUMA)
			else
				cambiar(Lighting, dia)
				cambiar(bruma, diaBruma)
			end
		end
	end)
end

return Ambiente
