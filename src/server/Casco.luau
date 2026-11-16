--[[
	Casco minero: casco amarillo en la cabeza con una lámpara al frente.
	La lámpara alumbra hacia donde mira el personaje (SpotLight) y deja una luz
	suave alrededor (PointLight). Todos ven el casco y la luz de los demás.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Casco = {}

local AMARILLO = Color3.fromRGB(240, 186, 36)

local function pieza(head: BasePart, props: { [string]: any }, offset: CFrame): Part
	local p = Instance.new("Part")
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.CFrame = head.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = head
	w.Part1 = p
	w.Parent = p
	return p
end

function Casco.Poner(character: Model)
	local head = character:WaitForChild("Head", 10) :: BasePart?
	if not head or character:FindFirstChild("Casco") then
		return
	end
	local s = head.Size
	local ancho = math.max(s.X, s.Z) * 1.08
	local tope = s.Y / 2

	local casco = Instance.new("Model")
	casco.Name = "Casco"

	-- Domo: una esfera achatada que asoma sobre la cabeza.
	local domo = pieza(head, {
		Name = "Domo",
		Size = Vector3.new(ancho, ancho * 0.62, ancho),
		Color = AMARILLO,
		Material = Enum.Material.SmoothPlastic,
	}, CFrame.new(0, tope - 0.02, 0))
	local malla = Instance.new("SpecialMesh")
	malla.MeshType = Enum.MeshType.Sphere
	malla.Parent = domo
	domo.Parent = casco

	-- Ala del casco.
	pieza(head, {
		Name = "Ala",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, ancho * 1.14, ancho * 1.14),
		Color = AMARILLO,
		Material = Enum.Material.SmoothPlastic,
	}, CFrame.new(0, tope - 0.08, 0) * CFrame.Angles(0, 0, math.rad(90))).Parent = casco

	-- Lámpara al frente: el cilindro mira hacia adelante (-Z de la cabeza).
	local frente = -(ancho / 2) * 0.92
	local base = pieza(head, {
		Name = "BaseLampara",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.18, 0.42, 0.42),
		Color = Color3.fromRGB(40, 40, 44),
		Material = Enum.Material.Metal,
	}, CFrame.new(0, tope + 0.08, frente) * CFrame.Angles(0, math.rad(90), 0))
	base.Parent = casco
	local foco = pieza(head, {
		Name = "Foco",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.06, 0.32, 0.32),
		Color = Config.Lampara.Color,
		Material = Enum.Material.Neon,
	}, CFrame.new(0, tope + 0.08, frente - 0.11) * CFrame.Angles(0, math.rad(90), 0))
	foco.Parent = casco

	-- Con el giro de 90°, la cara Right (+X) del foco apunta hacia adelante.
	local haz = Instance.new("SpotLight")
	haz.Name = "Haz"
	haz.Face = Enum.NormalId.Right
	haz.Angle = Config.Lampara.Angulo
	haz.Range = Config.Lampara.Alcance
	haz.Brightness = Config.Lampara.Brillo
	haz.Color = Config.Lampara.Color
	haz.Shadows = true
	haz.Parent = foco

	local cerca = Instance.new("PointLight")
	cerca.Name = "Cerca"
	cerca.Range = Config.Lampara.AlcanceCerca
	cerca.Brightness = Config.Lampara.BrilloCerca
	cerca.Color = Config.Lampara.Color
	cerca.Shadows = true
	cerca.Parent = foco

	casco.Parent = character
end

return Casco
