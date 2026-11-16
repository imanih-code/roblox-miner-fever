--[[
	RemoteEvents del juego. El servidor los crea; el cliente los espera.
	  Aviso  (s -> c)  texto y tipo ("good", "bad", "info", "gold") de un aviso
	  Picar  (c -> s)  picando (manteniendo el clic): punto, normal y pieza (mineral o
	                   pedrusco; nil si es roca). Sin argumentos: dejó de picar.
	  Progreso (s -> c) cuánto lleva picado tu objetivo (0 a 1) y si ya se rompió
	  Golpe  (s -> c)  un golpe de pico: punto y color, para las chispas y el sonido
	  AbrirHerrero (s -> c)  abrir el menú del herrero
	  Herrero      (c -> s)  en el menú del herrero: "Mejorar", "Reparar", "RepararHierro",
	                         "Dinamita" o "DinamitaAzufre"
	  Dinamita     (c -> s)  poner un cartucho encendido en ese punto
	  Explosion    (s -> c)  explotó una dinamita: punto, para sacudir la cámara
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Aviso",
	"Picar",
	"Golpe",
	"Progreso",
	"AbrirHerrero",
	"Herrero",
	"Dinamita",
	"Explosion",
}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local Remotes = {}
for _, name in NAMES do
	Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
