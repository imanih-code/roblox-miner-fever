--[[
	Ayudas para armar NPC con piezas: una persona R15 de colores, piezas
	decorativas pegadas al cuerpo (sombreros, barbas, delantales) y colocarla
	parada en el suelo con la animación de respirar.
]]

local Players = game:GetService("Players")

local Npc = {}

local IDLE_ANIM = "rbxassetid://507766388"

Npc.PIEL = Color3.fromRGB(234, 184, 146)

-- Pega una pieza decorativa a una parte del cuerpo.
function Npc.Pegar(cuerpo: BasePart, props: { [string]: any }, offset: CFrame): Part
	local p = Instance.new("Part")
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.CFrame = cuerpo.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = cuerpo
	w.Part1 = p
	w.Parent = p
	p.Parent = cuerpo.Parent
	return p
end

-- Persona R15 con la ropa (cuerpo) de un color y la piel de otro.
function Npc.Persona(nombre: string, ropa: Color3, piel: Color3, piernas: Color3?): Model
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = piel
	desc.TorsoColor = ropa
	desc.LeftArmColor = ropa
	desc.RightArmColor = ropa
	desc.LeftLegColor = piernas or ropa
	desc.RightLegColor = piernas or ropa
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = nombre
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayName = nombre
	return model
end

-- Coloca el modelo parado en el suelo, mirando hacia `mira`.
function Npc.Colocar(model: Model, pos: Vector3, mira: Vector3)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	local cf, size = model:GetBoundingBox()
	local alto = root.Position.Y - (cf.Position.Y - size.Y / 2)
	local destino = Vector3.new(pos.X, pos.Y + alto, pos.Z)
	model:PivotTo(CFrame.lookAt(destino, Vector3.new(mira.X, destino.Y, mira.Z)))
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local anim = Instance.new("Animation")
	anim.AnimationId = IDLE_ANIM
	local track = (animator :: Animator):LoadAnimation(anim)
	track.Looped = true
	track:Play()
end

-- Letrero flotante sobre una parte.
function Npc.Cartel(sobre: BasePart, texto: string, color: Color3, altura: number)
	local cartel = Instance.new("BillboardGui")
	cartel.Size = UDim2.fromOffset(260, 60)
	cartel.StudsOffset = Vector3.new(0, altura, 0)
	cartel.MaxDistance = 120
	cartel.Adornee = sobre
	cartel.Parent = sobre
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.3
	l.Text = texto
	l.Parent = cartel
	return cartel
end

return Npc
