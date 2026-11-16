--[[
	Dinamita: se compra con el herrero, se carga en el inventario (se guarda) y
	se usa con la herramienta "Dinamita": el cliente dice dónde ponerla, el
	servidor deja un cartucho encendido y a los segundos explota:
	  - borra la roca de la mina en un radio (menos la roca imposible); los
	    minerales quedan a la vista
	  - empuja a los mineros cercanos (no los mata)
	  - suelta pedruscos con física que pueden tapar túneles; se rompen con el
	    pico y se limpian solos después de un rato
	Solo se puede usar dentro de la mina.
]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local PlayerData = require(script.Parent.PlayerData)
local Mochila = require(script.Parent.Mochila)
local PicoService = require(script.Parent.PicoService)

local DinamitaService = {}

local D = Config.Dinamita
local Terrain = workspace.Terrain
local ROJO = Color3.fromRGB(196, 40, 36)
local SONIDO_EXPLOSION = "rbxasset://sounds/impact_explosion_03.mp3"

local carpetaPedruscos: Folder
local ultimoUso: { [Player]: number } = {}

local function aviso(player: Player, texto: string, tipo: string)
	Remotes.Aviso:FireClient(player, texto, tipo)
end

-- Herramienta ------------------------------------------------------------------------

local function cartucho(parent: Instance?): Part
	local p = Instance.new("Part")
	p.Name = "Handle"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(1.3, 0.45, 0.45)
	p.Color = ROJO
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.Massless = true
	local mecha = Instance.new("Part")
	mecha.Name = "Mecha"
	mecha.Size = Vector3.new(0.4, 0.08, 0.08)
	mecha.Color = Color3.fromRGB(60, 50, 40)
	mecha.CanCollide = false
	mecha.CanQuery = false
	mecha.Massless = true
	mecha.CFrame = p.CFrame * CFrame.new(0.82, 0, 0)
	local w = Instance.new("WeldConstraint")
	w.Part0 = p
	w.Part1 = mecha
	w.Parent = mecha
	mecha.Parent = p
	p.Parent = parent
	return p
end

local function crearHerramienta(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Dinamita"
	tool.CanBeDropped = false
	tool.Grip = CFrame.Angles(0, 0, math.rad(90))
	cartucho(tool)
	return tool
end

-- Pone la herramienta si tiene dinamita (y la quita si no) y actualiza el atributo.
function DinamitaService.Sync(player: Player)
	local data = PlayerData.Get(player)
	local n = data and data.Dinamita or 0
	player:SetAttribute("Dinamita", n)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = (backpack and backpack:FindFirstChild("Dinamita"))
		or (player.Character and player.Character:FindFirstChild("Dinamita"))
	if n > 0 and not tool and backpack and player.Character then
		tool = crearHerramienta()
		tool.Parent = backpack
	elseif n <= 0 and tool then
		tool:Destroy()
		tool = nil
	end
	if tool then
		(tool :: Tool).ToolTip = string.format("Dinamita (%d)", n)
	end
end

-- Compra (desde el menú del herrero) ---------------------------------------------------

function DinamitaService.Comprar(player: Player, data, conAzufre: boolean)
	if data.Dinamita >= D.Maximo then
		aviso(player, string.format("Ya cargas el máximo de dinamita (%d).", D.Maximo), "bad")
		return
	end
	local precio = if conAzufre then D.PrecioConAzufre else D.Precio
	if data.Dinero < precio then
		aviso(player, string.format("La dinamita cuesta %s y tienes %s.", Format.money(precio), Format.money(data.Dinero)), "bad")
		return
	end
	if conAzufre and Mochila.Sacar(player, "Azufre", 1) == 0 then
		aviso(player, "No traes azufre en la mochila. Lo hay en las Cuevas.", "bad")
		return
	end
	data.Dinero -= precio
	data.Dinamita += 1
	aviso(player, string.format("🧨 Compraste dinamita (tienes %d).", data.Dinamita), "good")
	DinamitaService.Sync(player)
end

-- Explosión ----------------------------------------------------------------------------

-- Borra la roca en una esfera, con el borde suave. Respeta la roca imposible y
-- todo lo que está fuera de la mina.
local function hueco(centro: Vector3, r: number)
	local region = Region3.new(centro - Vector3.one * (r + 4), centro + Vector3.one * (r + 4)):ExpandToGrid(4)
	local mats, occs = Terrain:ReadVoxels(region, 4)
	local origen = region.CFrame.Position - region.Size / 2
	local tam = mats.Size
	for x = 1, tam.X do
		for y = 1, tam.Y do
			for z = 1, tam.Z do
				local mat = mats[x][y][z]
				if mat ~= Enum.Material.Air and mat ~= Config.RocaImposible then
					local c = origen + Vector3.new(x - 0.5, y - 0.5, z - 0.5) * 4
					local dist = (c - centro).Magnitude
					if dist <= r + 2 and PicoService.DentroDeMina(c) then
						local queda = math.clamp((dist - (r - 2)) / 4, 0, 1)
						if queda < occs[x][y][z] then
							occs[x][y][z] = queda
							if queda <= 0.05 then
								mats[x][y][z] = Enum.Material.Air
								occs[x][y][z] = 0
							end
						end
					end
				end
			end
		end
	end
	Terrain:WriteVoxels(region, 4, mats, occs)
end

local function limpiarSobrantes()
	local lista = carpetaPedruscos:GetChildren()
	local sobran = #lista - D.MaxPedruscos
	if sobran > 0 then
		table.sort(lista, function(a, b)
			return (a:GetAttribute("Creado") or 0) < (b:GetAttribute("Creado") or 0)
		end)
		for i = 1, sobran do
			lista[i]:Destroy()
		end
	end
end

local function pedruscos(centro: Vector3)
	local rng = Random.new()
	for _ = 1, D.Pedruscos do
		local dir = rng:NextUnitVector()
		local t = rng:NextNumber(2.4, 4)
		local p = Instance.new("Part")
		p.Name = "Pedrusco"
		p.Size = Vector3.new(t, t * rng:NextNumber(0.75, 1), t * rng:NextNumber(0.8, 1.1))
		p.Color = Color3.fromRGB(rng:NextInteger(92, 120), rng:NextInteger(88, 112), rng:NextInteger(84, 104))
		p.Material = Enum.Material.Slate
		p.CFrame = CFrame.new(centro + dir * rng:NextNumber(1, 4)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		p.CustomPhysicalProperties = PhysicalProperties.new(3, 0.8, 0.1)
		p.AssemblyLinearVelocity = dir * rng:NextNumber(25, 45) + Vector3.new(0, 15, 0)
		p:SetAttribute("Pedrusco", true)
		p:SetAttribute("Golpes", D.GolpesPedrusco)
		p:SetAttribute("Creado", os.clock())
		p.Parent = carpetaPedruscos
		Debris:AddItem(p, D.PedruscosDuran)
	end
	limpiarSobrantes()
end

local function explotar(centro: Vector3)
	hueco(centro, D.Radio)
	local boom = Instance.new("Explosion")
	boom.Position = centro
	boom.BlastRadius = D.Radio + 4
	boom.BlastPressure = 60000
	boom.DestroyJointRadiusPercent = 0 -- empuja, pero no mata
	boom.ExplosionType = Enum.ExplosionType.NoCraters -- el hueco lo hacemos nosotros
	boom.Parent = workspace
	pedruscos(centro)
	local ancla = Instance.new("Part")
	ancla.Anchored = true
	ancla.CanCollide = false
	ancla.CanQuery = false
	ancla.Transparency = 1
	ancla.Position = centro
	ancla.Parent = workspace
	local sonido = Instance.new("Sound")
	sonido.SoundId = SONIDO_EXPLOSION
	sonido.Volume = 1.5
	sonido.RollOffMaxDistance = 220
	sonido.Parent = ancla
	sonido:Play()
	Debris:AddItem(ancla, 4)
	Remotes.Explosion:FireAllClients(centro)
end

local function onPoner(player: Player, punto: any)
	if typeof(punto) ~= "Vector3" then
		return
	end
	local data = PlayerData.Get(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not data or not head or not character:FindFirstChild("Dinamita") then
		return
	end
	local ahora = os.clock()
	if ahora - (ultimoUso[player] or 0) < 1 then
		return
	end
	if data.Dinamita <= 0 then
		return
	end
	if (punto - head.Position).Magnitude > D.Alcance + 3 then
		return
	end
	if not PicoService.DentroDeMina(punto) and not PicoService.DentroDeMina(head.Position) then
		aviso(player, "La dinamita solo se usa dentro de la mina.", "bad")
		return
	end
	ultimoUso[player] = ahora
	data.Dinamita -= 1
	DinamitaService.Sync(player)

	-- Cartucho encendido en el suelo, con chispas en la mecha.
	local c = cartucho(nil)
	c.Name = "DinamitaEncendida"
	c.Anchored = true
	c.CanQuery = false
	c.CFrame = CFrame.new(punto + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.random() * 6, 0)
	local chispas = Instance.new("Sparkles")
	chispas.SparkleColor = Color3.fromRGB(255, 180, 60)
	chispas.Parent = c:FindFirstChild("Mecha")
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(255, 150, 60)
	luz.Range = 10
	luz.Brightness = 1.5
	luz.Parent = c
	c.Parent = workspace
	task.delay(D.Mecha, function()
		c:Destroy()
		explotar(punto)
	end)
end

function DinamitaService.Init()
	carpetaPedruscos = Instance.new("Folder")
	carpetaPedruscos.Name = "Pedruscos"
	carpetaPedruscos.Parent = workspace
	Remotes.Dinamita.OnServerEvent:Connect(onPoner)
	Players.PlayerRemoving:Connect(function(player)
		ultimoUso[player] = nil
	end)
end

function DinamitaService.Carpeta(): Folder
	return carpetaPedruscos
end

return DinamitaService
