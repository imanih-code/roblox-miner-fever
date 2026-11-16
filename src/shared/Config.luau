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
	Herrero = Vector3.new(-20, 0, 10),

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
-- Cadencia: segundos entre golpes. Durabilidad: golpes que aguanta antes de romperse.
-- Precio: lo que cobra el herrero por mejorarlo a ese nivel (el de madera es el inicial).
-- Reparar: lo que cuesta repararlo entero (si le falta la mitad, cobra la mitad).
Config.Picos = {
	{
		Nombre = "Pico de madera",
		Nivel = 1,
		Cadencia = 0.5,
		Durabilidad = 150,
		Precio = 0,
		Reparar = 15,
		Color = Color3.fromRGB(150, 104, 62),
		Material = Enum.Material.Wood,
	},
	{
		Nombre = "Pico de piedra",
		Nivel = 2,
		Cadencia = 0.42,
		Durabilidad = 300,
		Precio = 150,
		Reparar = 40,
		Color = Color3.fromRGB(128, 128, 132),
		Material = Enum.Material.Slate,
	},
	{
		Nombre = "Pico de hierro",
		Nivel = 3,
		Cadencia = 0.35,
		Durabilidad = 550,
		Precio = 600,
		Reparar = 120,
		Color = Color3.fromRGB(200, 204, 212),
		Material = Enum.Material.Metal,
	},
	{
		Nombre = "Pico de oro",
		Nivel = 4,
		Cadencia = 0.29,
		Durabilidad = 900,
		Precio = 2000,
		Reparar = 300,
		Color = Color3.fromRGB(255, 196, 40),
		Material = Enum.Material.Metal,
	},
	{
		Nombre = "Pico de diamante",
		Nivel = 5,
		Cadencia = 0.24,
		Durabilidad = 1500,
		Precio = 6000,
		Reparar = 700,
		Color = Color3.fromRGB(110, 230, 255),
		Material = Enum.Material.Glass,
		Brillo = true,
	},
}
-- Cada hierro de la mochila repara esta parte del pico (0.35 = 35 %).
Config.RepararPorHierro = 0.35
-- Con esta parte de durabilidad o menos, el HUD la pone en rojo y avisa.
Config.DurabilidadBaja = 0.2
-- Nombre de cada nivel de pico, para los avisos ("necesitas un pico de piedra").
Config.NivelesPico = { "madera", "piedra", "hierro", "oro", "diamante" }
Config.Alcance = 12 -- studs desde la cabeza hasta donde pegas
Config.RadioPicado = 4.6 -- radio de roca que borra cada golpe

-- Dinamita ------------------------------------------------------------------------------
-- Se compra con el herrero; abre un hueco grande en cualquier roca de la mina menos la
-- roca imposible y suelta pedruscos que pueden tapar túneles.
Config.Dinamita = {
	Precio = 40,
	PrecioConAzufre = 15, -- más 1 azufre de la mochila
	Maximo = 10, -- cartuchos que puedes cargar
	Alcance = 14, -- qué tan lejos la puedes poner
	Mecha = 3, -- segundos hasta que explota
	Radio = 9, -- radio del hueco
	Pedruscos = 6, -- piedras sueltas que salen volando
	GolpesPedrusco = 2, -- golpes de pico para romper un pedrusco
	PedruscosDuran = 60, -- segundos hasta que se limpian solos
	MaxPedruscos = 80, -- en todo el servidor; se borran los más viejos
}

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
