--[[
	Modelo de la banca de pesas, igual para el servidor (la que se ve cuando
	alguien entrena) y para el cliente (tu banca, que solo ves tú).
	`base` es el piso; la banca va a lo largo de su eje Z y la cabeza queda hacia +Z,
	bajo la barra.
]]

local Shared = script.Parent
local Config = require(Shared.Config)

local BancaModelo = {}

export type Banca = {
	modelo: Model,
	colchon: BasePart,
	barra: BasePart,
	reposo: CFrame, -- dónde descansa la barra
	asiento: CFrame, -- dónde va el asiento (inclinado: el personaje queda acostado)
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

function BancaModelo.Crear(nivel: number, base: CFrame): Banca
	local estilo = Config.Bancas[nivel] or Config.Bancas[1]
	local banca = Instance.new("Model")
	banca.Name = "Banca"
	local function marco(props)
		props.Color = estilo.Marco
		props.Material = estilo.MaterialMarco
		props.Reflectance = estilo.Reflejo or 0
		return parte(props, banca)
	end
	-- Asiento acolchado y patas.
	local colchon = parte({
		Name = "Colchon",
		Size = Vector3.new(1.5, 0.35, 4.2),
		CFrame = base * CFrame.new(0, 1.2, 0.4),
		Color = estilo.Asiento,
		Material = Enum.Material.Fabric,
	}, banca)
	for _, p in { { -0.55, -1.5 }, { 0.55, -1.5 }, { -0.55, 2.2 }, { 0.55, 2.2 } } do
		marco({ Name = "Pata", Size = Vector3.new(0.28, 1.05, 0.28), CFrame = base * CFrame.new(p[1], 0.52, p[2]) })
	end
	-- Soportes de la barra, a la altura de la cabeza.
	for _, x in { -1.25, 1.25 } do
		marco({ Name = "Soporte", Size = Vector3.new(0.28, 3, 0.28), CFrame = base * CFrame.new(x, 1.5, 2.05) })
	end
	-- Barra con discos (los discos van soldados a la barra y la siguen).
	local reposo = base * CFrame.new(0, 3.15, 1.75)
	local barra = marco({ Name = "Barra", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.2, 0.2, 0.2), CFrame = reposo })
	for _, x in { -1.85, 1.85 } do
		local disco = Instance.new("Part")
		disco.Name = "Disco"
		disco.Shape = Enum.PartType.Cylinder
		disco.Size = Vector3.new(0.3, 1.3, 1.3)
		disco.CFrame = reposo * CFrame.new(x, 0, 0)
		disco.Color = estilo.Discos
		disco.Material = estilo.MaterialDiscos
		disco.Reflectance = estilo.Reflejo or 0
		disco.Anchored = false
		disco.Massless = true
		disco.CanCollide = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = barra
		w.Part1 = disco
		w.Parent = disco
		disco.Parent = banca
		if estilo.Brillo then
			local destellos = Instance.new("Sparkles")
			destellos.SparkleColor = estilo.Discos
			destellos.Parent = disco
		end
	end
	if estilo.Brillo then
		local luz = Instance.new("PointLight")
		luz.Color = estilo.Marco
		luz.Range = 8
		luz.Brightness = 0.8
		luz.Parent = barra
	end
	banca.PrimaryPart = colchon
	return {
		modelo = banca,
		colchon = colchon,
		barra = barra,
		reposo = reposo,
		asiento = base * CFrame.new(0, 1.55, -0.7) * CFrame.Angles(math.rad(90), 0, 0),
	}
end

-- Dónde va la banca número `i`: en arco alrededor de la boca de la mina, mirando
-- hacia ella (dos alas, a los lados del camino de la aparición a la mina).
function BancaModelo.Lugar(i: number): CFrame?
	local C = Config.Campamento
	local n = #C.Angulos
	local lado = if i <= n then -1 else 1
	local angulo = C.Angulos[if i <= n then i else i - n]
	if not angulo then
		return nil
	end
	local a = math.rad(angulo) * lado
	local pos = C.Centro + Vector3.new(math.sin(a) * C.Radio, Config.Mapa.Suelo, -math.cos(a) * C.Radio)
	-- Los pies hacia la mina (-Z mira a la boca) y la cabeza hacia afuera.
	return CFrame.lookAt(pos, Vector3.new(C.Centro.X, pos.Y, C.Centro.Z))
end

function BancaModelo.Cantidad(): number
	return #Config.Campamento.Angulos * 2
end

return BancaModelo
