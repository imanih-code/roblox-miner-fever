--[[
	RemoteEvents del juego. El servidor los crea; el cliente los espera.
	  Aviso  (s -> c)  texto y tipo ("good", "bad", "info", "gold") de un aviso
	  Picar  (c -> s)  golpe de pico: punto donde pegó y la pieza de mineral (o nil si es roca)
	  Golpe  (s -> c)  el golpe sirvió: punto y color, para las chispas y el sonido
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Aviso",
	"Picar",
	"Golpe",
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
