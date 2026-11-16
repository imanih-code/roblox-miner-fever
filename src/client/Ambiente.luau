--[[
	Ambiente en tu pantalla: arriba nieva (un emisor de copos que sigue a la
	cámara); bajo tierra la nieve se apaga.
	La oscuridad de la mina no se hace aquí: sale sola de la luz que pone el
	servidor (ver MapaBuilder: Ambient negro y sin luz del entorno), así que el
	cielo nunca cambia.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Ambiente = {}

local player = Players.LocalPlayer

local function crearNevada(): (Part, ParticleEmitter)
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
	local nube, nevada = crearNevada()
	local limite = Config.Mapa.AlturaOscuridad
	RunService.RenderStepped:Connect(function()
		local camara = workspace.CurrentCamera
		nube.CFrame = CFrame.new(camara.CFrame.Position + Vector3.new(0, 35, 0))
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			-- Con un margen, para que no se prenda y apague en el borde.
			local y = root.Position.Y
			if nevada.Enabled and y < limite - 2 then
				nevada.Enabled = false
			elseif not nevada.Enabled and y > limite + 2 then
				nevada.Enabled = true
			end
		end
	end)
end

return Ambiente
