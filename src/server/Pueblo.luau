--[[
	Pueblo minero del valle: casitas de techo de calamina con nieve encima,
	ventanas encendidas y humo en algunas chimeneas, más montones de nieve.
	Es decoración: las tiendas de cada jugador vendrán después.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Pueblo = {}

local Terrain = workspace.Terrain

local PAREDES = {
	{ Color3.fromRGB(150, 146, 138), Enum.Material.Concrete },
	{ Color3.fromRGB(96, 122, 150), Enum.Material.Concrete },
	{ Color3.fromRGB(150, 92, 64), Enum.Material.Brick },
	{ Color3.fromRGB(104, 122, 92), Enum.Material.Concrete },
	{ Color3.fromRGB(186, 174, 146), Enum.Material.Plaster },
	{ Color3.fromRGB(120, 84, 60), Enum.Material.WoodPlanks },
}
local TECHOS = {
	Color3.fromRGB(158, 160, 164),
	Color3.fromRGB(132, 104, 84),
	Color3.fromRGB(120, 126, 132),
}

-- Lugar (x, z) de cada casita. Se dejan libres el camino de la aparición a la
-- mina y el puesto del millonario.
local LUGARES = {
	{ -34, -58 },
	{ -50, -40 },
	{ -36, -22 },
	{ -56, -12 },
	{ -38, 4 },
	{ -62, 14 },
	{ -72, -30 },
	{ 46, -52 },
	{ 62, -34 },
	{ 44, -22 },
	{ 66, -8 },
	{ 50, 22 },
	{ -18, -70 },
	{ 20, -66 },
}

local function parte(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function casita(rng: Random, x: number, z: number, parent: Instance)
	local suelo = Config.Mapa.Suelo
	local w, d, h = rng:NextNumber(9, 13), rng:NextNumber(8, 11), rng:NextNumber(6.5, 8.5)
	local base = Vector3.new(x, suelo, z)
	-- El frente (-Z) mira al centro del campamento, con un poco de desorden.
	local giro = CFrame.lookAt(base, Vector3.new(0, suelo, -12)) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0)
	local casa = Instance.new("Model")
	casa.Name = "Casita"

	local pared = PAREDES[rng:NextInteger(1, #PAREDES)]
	parte({
		Name = "Paredes",
		Size = Vector3.new(w, h, d),
		CFrame = giro * CFrame.new(0, h / 2 - 0.5, 0),
		Color = pared[1],
		Material = pared[2],
	}, casa)

	-- Techo de calamina inclinado hacia atrás, con nieve encima.
	local techo = giro * CFrame.new(0, h - 0.2, 0) * CFrame.Angles(math.rad(-9), 0, 0)
	parte({
		Name = "Calamina",
		Size = Vector3.new(w + 1.4, 0.3, d + 1.6),
		CFrame = techo,
		Color = TECHOS[rng:NextInteger(1, #TECHOS)],
		Material = Enum.Material.CorrodedMetal,
	}, casa)
	parte({
		Name = "NieveTecho",
		Size = Vector3.new(w + 0.6, 0.35, (d + 1.2) * rng:NextNumber(0.4, 0.8)),
		CFrame = techo * CFrame.new(rng:NextNumber(-0.4, 0.4), 0.3, rng:NextNumber(-0.6, 0.6)),
		Color = Color3.fromRGB(240, 244, 250),
		Material = Enum.Material.Snow,
	}, casa)

	-- Puerta y ventana en el frente.
	parte({
		Name = "Puerta",
		Size = Vector3.new(2, 3.8, 0.2),
		CFrame = giro * CFrame.new(-w / 4, 1.4, -d / 2 - 0.1),
		Color = Color3.fromRGB(70, 50, 36),
		Material = Enum.Material.Wood,
	}, casa)
	local prendida = rng:NextNumber() < 0.6
	local ventana = parte({
		Name = "Ventana",
		Size = Vector3.new(2, 1.5, 0.15),
		CFrame = giro * CFrame.new(w / 4, h * 0.55, -d / 2 - 0.08),
		Color = if prendida then Color3.fromRGB(255, 196, 120) else Color3.fromRGB(60, 70, 84),
		Material = if prendida then Enum.Material.Neon else Enum.Material.Glass,
	}, casa)
	if prendida then
		local luz = Instance.new("PointLight")
		luz.Color = Color3.fromRGB(255, 190, 110)
		luz.Range = 9
		luz.Brightness = 0.6
		luz.Parent = ventana
	end

	-- Chimenea de lata; algunas echan humo.
	if rng:NextNumber() < 0.5 then
		local tubo = parte({
			Name = "Chimenea",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.4, 0.6, 0.6),
			CFrame = giro * CFrame.new(w / 3, h + 1, d / 4) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(60, 60, 64),
			Material = Enum.Material.Metal,
		}, casa)
		local humo = Instance.new("Smoke")
		humo.Color = Color3.fromRGB(200, 200, 205)
		humo.Opacity = 0.12
		humo.RiseVelocity = 4
		humo.Size = 2
		humo.Parent = tubo
	end

	casa.Parent = parent

	-- Montón de nieve al costado.
	if rng:NextNumber() < 0.7 then
		local lado = if rng:NextNumber() < 0.5 then -1 else 1
		local monton = (giro * CFrame.new(lado * (w / 2 + 2.5), 0, rng:NextNumber(-2, 2))).Position
		Terrain:FillBall(Vector3.new(monton.X, -0.5, monton.Z), rng:NextNumber(2.5, 4), Enum.Material.Snow)
	end
end

function Pueblo.Build(carpeta: Instance)
	local pueblo = Instance.new("Folder")
	pueblo.Name = "Pueblo"
	local rng = Random.new(7) -- mismo pueblo en cada servidor
	for _, lugar in LUGARES do
		casita(rng, lugar[1], lugar[2], pueblo)
	end
	pueblo.Parent = carpeta
end

return Pueblo
