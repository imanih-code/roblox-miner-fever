--[[
	Balance de Fiebre Minera. Todo lo que se ajusta en pruebas vive aquí.

	Bucle: sales del campamento -> entras a la mina -> picas para abrir camino y
	buscar vetas -> los minerales chicos van a la mochila -> se los vendes al
	millonario en la salida -> con el dinero mejoras el pico, compras dinamita y
	mejoras tu banca de pesas (Fuerza).

	El diseño completo está en DISENO.md.
]]

local Config = {}

Config.DataStoreName = "FiebreMinera_v1"
Config.DineroInicial = 0
Config.AutoguardadoCada = 90 -- segundos
Config.TiempoReaparicion = 3

-- Mapa ------------------------------------------------------------------------
-- Coordenadas múltiplos de 4 (el tamaño de un vóxel de terreno). Las alturas
-- son las del relleno del terreno; la superficie que se ve queda `Suelo` studs
-- más arriba (el terreno lleno hasta y = 0 se ve con el pasto en y = 2), así que
-- todo lo que se pone encima (aparición, millonario, marco de la mina) se sube eso.
Config.Mapa = {
	Suelo = 2,
	-- Todo el mapa (x, z): valle del campamento rodeado de cerros helados.
	SueloMin = Vector2.new(-256, -192),
	SueloMax = Vector2.new(256, 320),
	-- Zona excavable de la mina, bajo tierra. Afuera de ella todo es roca imposible.
	MinaMin = Vector3.new(-80, -96, 40),
	MinaMax = Vector3.new(80, -4, 200),
	FondoBasalto = -112, -- hasta dónde llega la roca imposible

	Aparicion = Vector3.new(0, 0, -30), -- campamento
	BocaZ = 27, -- marco de madera en la cara del acantilado (se entra a nivel del valle)
	Entrada = Vector3.new(0, 0, 34), -- ya dentro del cerro, aquí empieza a bajar la rampa hacia +z
	FondoRampa = Vector3.new(0, -18, 62), -- donde termina la rampa y empieza la galería
	Millonario = Vector3.new(20, 0, 10),

	-- Bajo esta altura (y) se apaga el sol y solo alumbra tu lámpara.
	AlturaOscuridad = -8,
}

-- Cerros de la superficie (alta montaña helada). Solo se ven: no se pican.
Config.Montanas = {
	RadioValle = 90, -- valle plano alrededor del campamento
	AlturaBorde = 150, -- cerros del borde del mapa
	AcantiladoZ = 24, -- desde aquí sube el cerro de la mina, al norte
	AlturaAcantilado = 75,
	AlturaCumbre = 85, -- cumbre con glaciar encima de la mina
	NieveDesde = 30, -- más arriba de esto, nieve (salvo en paredes muy empinadas)
	GlaciarDesde = 115, -- y más arriba, hielo de glaciar
}

-- Rocas -------------------------------------------------------------------------
-- Nivel de pico que hace falta para romper cada material del terreno.
-- Lo que no está en la tabla (pasto, basalto) no se puede picar.
Config.Rocas = {
	[Enum.Material.Rock] = { Nombre = "Piedra", Nivel = 1 },
	[Enum.Material.Ground] = { Nombre = "Tierra", Nivel = 1 },
	[Enum.Material.Slate] = { Nombre = "Roca dura", Nivel = 2 },
}
Config.RocaImposible = Enum.Material.Basalt

-- Capas de la mina, de arriba hacia abajo (y de arriba, y de abajo).
-- Minerales: id -> peso para elegir qué sale en cada veta.
Config.Capas = {
	{
		Nombre = "Superficie",
		Arriba = -4,
		Abajo = -48,
		Material = Enum.Material.Rock,
		Vetas = 140,
		Minerales = { Carbon = 60, Cobre = 40 },
	},
	{
		Nombre = "Cuevas",
		Arriba = -48,
		Abajo = -96,
		Material = Enum.Material.Slate,
		Vetas = 110,
		Minerales = { Hierro = 45, Azufre = 35, Plata = 20 },
	},
}

-- Manchas de roca imposible dentro de la mina (obligan a rodear).
Config.ManchasBasalto = 16
Config.RadioManchaBasalto = { 6, 11 }

-- Minerales -----------------------------------------------------------------------
-- Rareza: 1 Común, 2 Poco común, 3 Raro, 4 Épico, 5 Legendario, 6 Mítico.
-- Desde Raro el servidor avisa a todos.
Config.Rarezas = {
	{ Nombre = "Común", Color = Color3.fromRGB(200, 200, 200) },
	{ Nombre = "Poco común", Color = Color3.fromRGB(110, 210, 120) },
	{ Nombre = "Raro", Color = Color3.fromRGB(90, 160, 255) },
	{ Nombre = "Épico", Color = Color3.fromRGB(190, 110, 255) },
	{ Nombre = "Legendario", Color = Color3.fromRGB(255, 190, 60) },
	{ Nombre = "Mítico", Color = Color3.fromRGB(255, 90, 140) },
}
Config.AvisarDesdeRareza = 3

-- Golpes: golpes de pico para soltarlo. NivelPico: pico mínimo.
Config.Minerales = {
	Carbon = {
		Nombre = "Carbón",
		Rareza = 1,
		Valor = 4,
		Golpes = 2,
		NivelPico = 1,
		Color = Color3.fromRGB(38, 36, 40),
		Material = Enum.Material.Slate,
	},
	Cobre = {
		Nombre = "Cobre",
		Rareza = 2,
		Valor = 10,
		Golpes = 3,
		NivelPico = 1,
		Color = Color3.fromRGB(214, 120, 64),
		Material = Enum.Material.Metal,
	},
	Hierro = {
		Nombre = "Hierro",
		Rareza = 1,
		Valor = 18,
		Golpes = 3,
		NivelPico = 2,
		Color = Color3.fromRGB(176, 150, 132),
		Material = Enum.Material.Metal,
	},
	Azufre = {
		Nombre = "Azufre",
		Rareza = 2,
		Valor = 14,
		Golpes = 2,
		NivelPico = 2,
		Color = Color3.fromRGB(232, 214, 64),
		Material = Enum.Material.SmoothPlastic,
	},
	Plata = {
		Nombre = "Plata",
		Rareza = 3,
		Valor = 45,
		Golpes = 4,
		NivelPico = 2,
		Color = Color3.fromRGB(222, 228, 240),
		Material = Enum.Material.Metal,
		Brillo = true,
	},
}

-- Pico ------------------------------------------------------------------------------
Config.Picos = {
	{
		Nombre = "Pico de madera",
		Nivel = 1,
		Cadencia = 0.5, -- segundos entre golpes
		Color = Color3.fromRGB(150, 104, 62),
	},
	-- Siguientes niveles (piedra, hierro, oro, diamante) cuando exista el herrero.
}
-- Nombre de cada nivel de pico, para los avisos ("necesitas un pico de piedra").
Config.NivelesPico = { "madera", "piedra", "hierro", "oro", "diamante" }
Config.Alcance = 12 -- studs desde la cabeza hasta donde pegas
Config.RadioPicado = 4.6 -- radio de roca que borra cada golpe

-- Mochila -----------------------------------------------------------------------------
Config.MochilaInicial = 12 -- minerales chicos que caben

-- Lámpara del casco ---------------------------------------------------------------------
Config.Lampara = {
	-- Haz hacia adelante.
	Alcance = 32,
	Angulo = 70,
	Brillo = 2.2,
	-- Luz suave alrededor del minero.
	AlcanceCerca = 10,
	BrilloCerca = 0.5,
	Color = Color3.fromRGB(255, 226, 170),
}

return Config
