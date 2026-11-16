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
	-- Núcleo (x, z): valle, cresta y cerro de la mina, con roca imposible debajo.
	SueloMin = Vector2.new(-192, -192),
	SueloMax = Vector2.new(192, 320),
	-- Todo el mundo que se ve (afuera del núcleo solo es paisaje).
	MundoMin = Vector2.new(-896, -896),
	MundoMax = Vector2.new(896, 1024),
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

	-- Bajo esta altura (y) se deja de ver la nevada (la mina es oscura por la luz, ver MapaBuilder).
	AlturaOscuridad = -8,
}

-- Cerros de la superficie (alta montaña helada). Solo se ven: no se pican.
-- Las distancias son sobre una elipse más corta hacia el norte (z se estira × 1.6).
Config.Montanas = {
	RadioValle = 90, -- valle plano alrededor del campamento
	RadioCresta = 165, -- cresta que rodea el valle (se puede trepar)
	AltoCresta = 42,
	AnchoCresta = 40,
	RadioMuro = 185, -- pared invisible: hasta aquí se puede caminar
	HondoMeseta = 18, -- afuera de la cresta el terreno baja a una meseta
	RadioLejos = 380, -- desde aquí sube la cordillera lejana (solo se ve)
	AltoLejos = 320,
	AcantiladoZ = 24, -- desde aquí sube el cerro de la mina, al norte
	AlturaAcantilado = 75,
	AlturaCumbre = 85, -- cumbre con glaciar encima de la mina
	NieveDesde = 30, -- más arriba de esto, nieve (salvo en paredes muy empinadas)
	GlaciarDesde = 115, -- y más arriba, hielo de glaciar
}

-- Rocas -------------------------------------------------------------------------
-- Nivel de pico que hace falta para romper cada material del terreno.
-- Lo que no está en la tabla (pasto, basalto) no se puede picar.
-- Dureza: vida de un trozo de esa roca. Un pico le quita su Poder en cada golpe
-- (ver Config.Picos), así que con madera la piedra tarda 4 golpes (2 s).
Config.Rocas = {
	[Enum.Material.Rock] = { Nombre = "Piedra", Nivel = 1, Dureza = 4 },
	[Enum.Material.Ground] = { Nombre = "Tierra", Nivel = 1, Dureza = 3 },
	[Enum.Material.Slate] = { Nombre = "Roca dura", Nivel = 2, Dureza = 8 },
}

-- Picado continuo (manteniendo el clic) ---------------------------------------------
Config.Picado = {
	-- Si nadie pica un trozo o mineral por este tiempo, vuelve a estar entero.
	OlvidarTras = 0.5,
	-- Cada cuánto el servidor avanza el picado y actualiza el terreno.
	Paso = 0.1,
	-- Lo más que se achica un trozo antes de romperse (0.8 = queda al 20 %).
	Achique = 0.8,
}

-- Pepitas: lo que suelta un mineral al romperse; se recogen al tocarlas.
Config.Pepitas = {
	Tamano = 1.4,
	Duran = 180, -- segundos en el suelo antes de desaparecer
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

-- Dureza: vida de la pieza (golpes con pico de madera). NivelPico: pico mínimo.
Config.Minerales = {
	Carbon = {
		Nombre = "Carbón",
		Rareza = 1,
		Valor = 4,
		Dureza = 3,
		NivelPico = 1,
		Color = Color3.fromRGB(38, 36, 40),
		Material = Enum.Material.Slate,
	},
	Cobre = {
		Nombre = "Cobre",
		Rareza = 2,
		Valor = 10,
		Dureza = 4,
		NivelPico = 1,
		Color = Color3.fromRGB(214, 120, 64),
		Material = Enum.Material.Metal,
	},
	Hierro = {
		Nombre = "Hierro",
		Rareza = 1,
		Valor = 18,
		Dureza = 6,
		NivelPico = 2,
		Color = Color3.fromRGB(176, 150, 132),
		Material = Enum.Material.Metal,
	},
	Azufre = {
		Nombre = "Azufre",
		Rareza = 2,
		Valor = 14,
		Dureza = 5,
		NivelPico = 2,
		Color = Color3.fromRGB(232, 214, 64),
		Material = Enum.Material.SmoothPlastic,
	},
	Plata = {
		Nombre = "Plata",
		Rareza = 3,
		Valor = 45,
		Dureza = 8,
		NivelPico = 2,
		Color = Color3.fromRGB(222, 228, 240),
		Material = Enum.Material.Metal,
		Brillo = true,
	},
}

-- Pico ------------------------------------------------------------------------------
-- Cadencia: segundos entre golpes (manteniendo el clic). Poder: lo que le quita a la
-- dureza de un trozo o mineral en cada golpe. Durabilidad: golpes que aguanta.
-- Precio: lo que cobra el herrero por mejorarlo a ese nivel (el de madera es el inicial).
-- Reparar: lo que cuesta repararlo entero (si le falta la mitad, cobra la mitad).
Config.Picos = {
	{
		Nombre = "Pico de madera",
		Nivel = 1,
		Cadencia = 0.5,
		Poder = 1,
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
		Poder = 1.5,
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
		Poder = 2.2,
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
		Poder = 3,
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
		Poder = 4.2,
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
	Pedruscos = 8, -- escombro: piedras sueltas que salen volando
	DurezaPedrusco = 2, -- vida de un pedrusco (golpes con pico de madera)
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
