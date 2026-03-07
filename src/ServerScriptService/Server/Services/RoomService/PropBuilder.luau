--!strict
local ThresholdConfig = require(game:GetService("ReplicatedStorage").Shared.ThresholdConfig)

local PropBuilder = {}

local function createPart(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildTable(parent: Instance, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Table"

	local top = createPart(model, "Top", Vector3.new(4, 0.3, 2.5), position + Vector3.new(0, 3, 0), Color3.fromRGB(90, 60, 30), Enum.Material.Wood)
	-- 4 legs
	for _, offset in { Vector3.new(-1.7, 1.5, -1), Vector3.new(1.7, 1.5, -1), Vector3.new(-1.7, 1.5, 1), Vector3.new(1.7, 1.5, 1) } do
		local leg = Instance.new("Part")
		leg.Anchored = true
		leg.Name = "Leg"
		leg.Shape = Enum.PartType.Cylinder
		leg.Size = Vector3.new(3, 0.3, 0.3)
		leg.CFrame = CFrame.new(position + offset) * CFrame.Angles(0, 0, math.rad(90))
		leg.Color = Color3.fromRGB(70, 45, 20)
		leg.Material = Enum.Material.Wood
		leg.Parent = model
	end

	model.PrimaryPart = top
	model.Parent = parent
	return model
end

local function buildChair(parent: Instance, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Chair"

	local seat = createPart(model, "Seat", Vector3.new(2, 0.2, 2), position + Vector3.new(0, 2, 0), Color3.fromRGB(80, 55, 25), Enum.Material.Wood)
	createPart(model, "Back", Vector3.new(2, 2, 0.2), position + Vector3.new(0, 3, -1), Color3.fromRGB(80, 55, 25), Enum.Material.Wood)
	for _, offset in { Vector3.new(-0.8, 1, -0.8), Vector3.new(0.8, 1, -0.8), Vector3.new(-0.8, 1, 0.8), Vector3.new(0.8, 1, 0.8) } do
		createPart(model, "Leg", Vector3.new(0.2, 2, 0.2), position + offset, Color3.fromRGB(70, 45, 20), Enum.Material.Wood)
	end

	model.PrimaryPart = seat
	model.Parent = parent
	return model
end

local function buildCabinet(parent: Instance, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Cabinet"

	local body = createPart(model, "Body", Vector3.new(3, 5, 2), position + Vector3.new(0, 2.5, 0), Color3.fromRGB(65, 50, 35), Enum.Material.Wood)

	local door = createPart(model, "Door", Vector3.new(2.8, 4.8, 0.2), position + Vector3.new(0, 2.5, 1.1), Color3.fromRGB(75, 55, 38), Enum.Material.Wood)

	-- Make searchable
	local interactable = Instance.new("BoolValue")
	interactable.Name = "Interactable"
	interactable.Parent = door

	local interactType = Instance.new("StringValue")
	interactType.Name = "InteractType"
	interactType.Value = "Search"
	interactType.Parent = door

	-- Hideable tag (for Shadow entity counterplay)
	local hideable = Instance.new("BoolValue")
	hideable.Name = "Hideable"
	hideable.Parent = model

	model.PrimaryPart = body
	model.Parent = parent
	return model
end

local function buildShelf(parent: Instance, position: Vector3): Part
	local shelf = createPart(parent, "Shelf", Vector3.new(4, 0.3, 1.5), position + Vector3.new(0, 4, 0), Color3.fromRGB(85, 60, 35), Enum.Material.Wood)
	return shelf
end

local function buildDesk(parent: Instance, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Desk"

	local top = createPart(model, "Top", Vector3.new(5, 0.3, 3), position + Vector3.new(0, 3, 0), Color3.fromRGB(95, 65, 35), Enum.Material.Wood)
	-- Side panel
	createPart(model, "SidePanel", Vector3.new(0.3, 3, 3), position + Vector3.new(-2.35, 1.5, 0), Color3.fromRGB(85, 58, 30), Enum.Material.Wood)
	-- Legs on open side
	createPart(model, "Leg1", Vector3.new(0.3, 3, 0.3), position + Vector3.new(2.35, 1.5, -1.3), Color3.fromRGB(85, 58, 30), Enum.Material.Wood)
	createPart(model, "Leg2", Vector3.new(0.3, 3, 0.3), position + Vector3.new(2.35, 1.5, 1.3), Color3.fromRGB(85, 58, 30), Enum.Material.Wood)

	model.PrimaryPart = top
	model.Parent = parent
	return model
end

local function buildBed(parent: Instance, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Bed"

	-- Frame
	createPart(model, "Frame", Vector3.new(4, 1, 6), position + Vector3.new(0, 0.5, 0), Color3.fromRGB(70, 50, 30), Enum.Material.Wood)
	-- Mattress
	local mattress = createPart(model, "Mattress", Vector3.new(3.6, 0.6, 5.6), position + Vector3.new(0, 1.3, 0), Color3.fromRGB(180, 170, 160), Enum.Material.Fabric)
	-- Headboard
	createPart(model, "Headboard", Vector3.new(4, 3, 0.3), position + Vector3.new(0, 1.5, -3), Color3.fromRGB(65, 45, 25), Enum.Material.Wood)

	-- Hideable
	local hideable = Instance.new("BoolValue")
	hideable.Name = "Hideable"
	hideable.Parent = model

	model.PrimaryPart = mattress
	model.Parent = parent
	return model
end

local function buildCrate(parent: Instance, position: Vector3, rng: Random): Part
	local size = rng:NextNumber() * 2 + 1.5
	local crate = createPart(parent, "Crate", Vector3.new(size, size, size), position + Vector3.new(0, size / 2, 0), Color3.fromRGB(110, 85, 55), Enum.Material.Wood)
	return crate
end

local function buildPipes(parent: Instance, position: Vector3, length: number): Part
	local pipe = Instance.new("Part")
	pipe.Anchored = true
	pipe.Name = "Pipe"
	pipe.Shape = Enum.PartType.Cylinder
	pipe.Size = Vector3.new(length, 0.5, 0.5)
	pipe.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	pipe.Color = Color3.fromRGB(100, 100, 105)
	pipe.Material = Enum.Material.Metal
	pipe.Parent = parent
	return pipe
end

type PropPlacer = (parent: Instance, position: Vector3, rng: Random) -> ()

local propBuilders: { { name: string, sizeX: number, sizeZ: number, build: (parent: Instance, position: Vector3, rng: Random) -> () } } = {
	{ name = "Table", sizeX = 4, sizeZ = 2.5, build = function(p, pos, _) buildTable(p, pos) end },
	{ name = "Chair", sizeX = 2, sizeZ = 2, build = function(p, pos, _) buildChair(p, pos) end },
	{ name = "Cabinet", sizeX = 3, sizeZ = 2, build = function(p, pos, _) buildCabinet(p, pos) end },
	{ name = "Desk", sizeX = 5, sizeZ = 3, build = function(p, pos, _) buildDesk(p, pos) end },
	{ name = "Bed", sizeX = 4, sizeZ = 6, build = function(p, pos, _) buildBed(p, pos) end },
	{ name = "Crate", sizeX = 3, sizeZ = 3, build = function(p, pos, r) buildCrate(p, pos, r) end },
}

function PropBuilder.populateRoom(folder: Folder, sizeX: number, sizeZ: number, origin: Vector3, rng: Random): ()
	local propCount = rng:NextInteger(ThresholdConfig.MinProps, ThresholdConfig.MaxProps)
	local padding = ThresholdConfig.PropPadding
	local margin = 4
	local placed: { { x: number, z: number, sx: number, sz: number } } = {}

	-- Add pipes along ceiling
	local pipeCount = rng:NextInteger(0, 2)
	for _ = 1, pipeCount do
		local pz = rng:NextNumber() * (sizeZ - 4) + 2
		buildPipes(folder, origin + Vector3.new(sizeX / 2, ThresholdConfig.RoomHeight - 0.5, pz), sizeX - 2)
	end

	-- Add shelves on walls
	local shelfCount = rng:NextInteger(0, 3)
	for _ = 1, shelfCount do
		local side = rng:NextInteger(0, 1)
		local sz = rng:NextNumber() * (sizeZ - 6) + 3
		local sx = if side == 0 then 2 else sizeX - 2
		buildShelf(folder, origin + Vector3.new(sx, 0, sz))
	end

	for _ = 1, propCount do
		local builder = propBuilders[rng:NextInteger(1, #propBuilders)]
		local attempts = 0
		local placedProp = false

		while attempts < 10 and not placedProp do
			attempts += 1
			local px = rng:NextNumber() * (sizeX - margin * 2 - builder.sizeX) + margin
			local pz = rng:NextNumber() * (sizeZ - margin * 2 - builder.sizeZ) + margin

			-- Collision check
			local overlaps = false
			for _, existing in placed do
				if math.abs(px - existing.x) < (builder.sizeX + existing.sx) / 2 + padding
					and math.abs(pz - existing.z) < (builder.sizeZ + existing.sz) / 2 + padding then
					overlaps = true
					break
				end
			end

			if not overlaps then
				builder.build(folder, origin + Vector3.new(px, 0, pz), rng)
				table.insert(placed, { x = px, z = pz, sx = builder.sizeX, sz = builder.sizeZ })
				placedProp = true
			end
		end
	end
end

function PropBuilder.populateSafeRoom(folder: Folder, sizeX: number, sizeZ: number, origin: Vector3): ()
	-- Safe room: well-lit, a couple tables, benches
	buildTable(folder, origin + Vector3.new(sizeX / 2, 0, sizeZ / 2))
	buildChair(folder, origin + Vector3.new(sizeX / 2 - 3, 0, sizeZ / 2))
	buildChair(folder, origin + Vector3.new(sizeX / 2 + 3, 0, sizeZ / 2))

	-- Bright warm light
	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 40
	light.Color = Color3.fromRGB(255, 230, 180)

	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = origin + Vector3.new(sizeX / 2, ThresholdConfig.RoomHeight - 1, sizeZ / 2)
	anchor.Name = "SafeLight"
	light.Parent = anchor
	anchor.Parent = folder
end

return PropBuilder
