local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local InsertService = game:GetService("InsertService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local SAVES_PATH = "cupcake_saves.json"
local SETTINGS_PATH = "cupcake_settings.json"
local COREUI_PATH = "cupcake_coreui.json"
local RELOAD_URL = ""
local CATALOG_PLACE_ID = 7041939546
local GITHUB_URL = "https://github.com/soynd/cupcake"
local UPDATE_DATE = "November 25, 2026"

local settings = {
	keepOnRespawn = false,
	toggleKey = "Zero",
	blur = true,
	tint = true,
	fovChange = true,
	hideUis = true,
	skipWelcome = false,
	autoloadName = "",
	uiScale = 1,
	snow = true,
	circleBtnPos = {X = 1, Y = 1, OffsetX = -54, OffsetY = -54},
	device = UserInputService.TouchEnabled and "Mobile" or "PC",
}

_G.CupcakeRunId = ((_G.CupcakeRunId or 0) + 1) % 1000000
_G.CupcakeUnloaded = false
local myRunId = _G.CupcakeRunId

local M3 = {
	Background       = Color3.fromRGB(30, 32, 36),
	Surface          = Color3.fromRGB(44, 47, 53),
	SurfaceHigh      = Color3.fromRGB(57, 61, 68),
	SurfaceHighest   = Color3.fromRGB(72, 76, 84),
	Primary          = Color3.fromRGB(250, 251, 253),
	OnPrimary        = Color3.fromRGB(20, 22, 26),
	PrimaryHover     = Color3.fromRGB(228, 231, 236),
	Accent           = Color3.fromRGB(255, 255, 255),
	OnSurface        = Color3.fromRGB(242, 244, 247),
	OnSurfaceVariant = Color3.fromRGB(174, 180, 190),
	OnSurfaceFaint   = Color3.fromRGB(132, 138, 148),
	GlassLine        = Color3.fromRGB(255, 255, 255),
	GlassTint        = Color3.fromRGB(200, 205, 212),
	GlassGradientTop = Color3.fromRGB(255, 255, 255),
	GlassGradientBot = Color3.fromRGB(210, 214, 220),
	OutlineVariant   = Color3.fromRGB(96, 102, 112),
	Backdrop         = Color3.fromRGB(110, 114, 120),
	Error            = Color3.fromRGB(255, 100, 100),
	ErrorContainer   = Color3.fromRGB(66, 36, 40),
	Success          = Color3.fromRGB(110, 210, 145),
}

local savedAvatars = {}
local currentGui = nil
local circleGuiRef = nil
local isGuiOpen = true
local startSnow, stopSnow
local showToastRef = nil
local lastAppliedAvatarData = nil
local scriptUnloaded = false
local toggleConn, respawnConn, guiCharacterConn, cameraViewportConn, cameraChangedConn

local hiddenPartOriginals = {}
local hiddenDecalOriginals = {}
local hiddenWrapOriginals = {}
local ORIG_PART_ATTR = "CupcakeOrigTransparency"
local ORIG_DECAL_ATTR = "CupcakeOrigDecalTransparency"
local ORIG_WRAP_ATTR = "CupcakeOrigWrapEnabled"
local HIDDEN_UI_ATTR = "CupcakeHiddenUi"

local function originalPartTransparency(part)
	local t = hiddenPartOriginals[part]
	if t ~= nil then return t end
	local a = part:GetAttribute(ORIG_PART_ATTR)
	if a ~= nil then return a end
	return part.Transparency
end

local function originalDecalTransparency(decal)
	local t = hiddenDecalOriginals[decal]
	if t ~= nil then return t end
	local a = decal:GetAttribute(ORIG_DECAL_ATTR)
	if a ~= nil then return a end
	return decal.Transparency
end

local function notify(title, text, dur, isError)
	local msg = tostring(title or "Cupcake")
	if text and text ~= "" then
		msg = msg .. ": " .. tostring(text)
	end
	if showToastRef then
		showToastRef(msg)
	end
end

local function hasFS()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function saveFile(name, data)
	if not hasFS() then return false end
	local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
	if ok then writefile(name, json); return true end
	return false
end

local function loadFile(name)
	if not hasFS() then return nil end
	if not isfile(name) then return nil end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(name)) end)
	if ok then return data end
	return nil
end

local function saveSettings()
	if hasFS() then saveFile(SETTINGS_PATH, settings) end
end

local function loadSettings()
	if not hasFS() then return end
	local data = loadFile(SETTINGS_PATH)
	if data then
		if data.keepOnRespawn ~= nil then
			settings.keepOnRespawn = data.keepOnRespawn
		end
		if type(data.blur) == "boolean" then
			settings.blur = data.blur
		end
		if type(data.noTint) == "boolean" then
			settings.tint = not data.noTint
		end
		if type(data.tint) == "boolean" then
			settings.tint = data.tint
		end
		if type(data.noFov) == "boolean" then
			settings.fovChange = not data.noFov
		end
		if type(data.fovChange) == "boolean" then
			settings.fovChange = data.fovChange
		end
		if type(data.noHideUis) == "boolean" then
			settings.hideUis = not data.noHideUis
		end
		if type(data.hideUis) == "boolean" then
			settings.hideUis = data.hideUis
		end
		if type(data.skipWelcome) == "boolean" then
			settings.skipWelcome = data.skipWelcome
		end
		if type(data.autoloadName) == "string" then
			settings.autoloadName = data.autoloadName
		end
		if type(data.toggleKey) == "string" then
			local okKey, kc = pcall(function() return Enum.KeyCode[data.toggleKey] end)
			if okKey and kc and kc ~= Enum.KeyCode.Unknown then
				settings.toggleKey = data.toggleKey
			end
		end
		if data.device == "Mobile" or data.device == "PC" then
			settings.device = data.device
		end
		if type(data.uiScale) == "number" then
			settings.uiScale = math.clamp(data.uiScale, 0.75, 1.25)
		end
		if type(data.snow) == "boolean" then
			settings.snow = data.snow
		end
		if data.circleBtnPos then
			settings.circleBtnPos = data.circleBtnPos
		end
	end
end

local function vec3(arr)
	return Vector3.new(arr[1], arr[2], arr[3])
end

local function deserializeColor(arr)
	return Color3.new(arr[1], arr[2], arr[3])
end

local function cupEnum(enumTable, saved)
	if type(saved) ~= "string" then return nil end
	local name = saved:match("%.([^%.]+)$") or saved
	local ok, val = pcall(function() return enumTable[name] end)
	if ok then return val end
	return nil
end

local function tableCount(t)
	local c = 0
	for _ in pairs(t) do c = c + 1 end
	return c
end

local HUMANOID_SCALE_TO_DESC = {
	BodyTypeScale = "BodyTypeScale",
	BodyDepthScale = "DepthScale",
	BodyHeightScale = "HeightScale",
	BodyProportionScale = "ProportionScale",
	BodyWidthScale = "WidthScale",
	HeadScale = "HeadScale",
}

local function formatTime()
	local t = os.date("*t")
	return string.format("%02d:%02d", t.hour, t.min)
end

local function detectDevice()
	local vp = workspace.CurrentCamera.ViewportSize
	local isTouch = UserInputService.TouchEnabled
	return isTouch and (vp.X < 900 or vp.Y < 600)
end

local function getUiScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local baseW, baseH = 520, 400
	local fit = math.min(vp.X / baseW, vp.Y / baseH) * 0.92
	local scale = math.clamp(fit, 0.5, 1.0)
	if detectDevice() then
		scale = math.min(scale, 0.78)
	end
	local userScale = tonumber(settings.uiScale) or 1

	return math.clamp(math.min(scale * userScale, fit), 0.4, 1.3)
end

local function serializePart(part)
	local d = {
		Name = part.Name,
		Size = {part.Size.X, part.Size.Y, part.Size.Z},
		Color = {part.Color.R, part.Color.G, part.Color.B},
		Material = tostring(part.Material),
		Transparency = originalPartTransparency(part),
		Reflectance = part.Reflectance,
		CastShadow = part.CastShadow,
		CanCollide = part.CanCollide,
		_class = part.ClassName,
	}
	if part:IsA("Part") and part.Shape then
		pcall(function() d.Shape = tostring(part.Shape) end)
	end
	if part:IsA("MeshPart") then
		pcall(function() d.MeshId = part.MeshId end)
		pcall(function() d.TextureID = part.TextureID end)
	end
	return d
end

local function serializeMesh(mesh)
	if mesh:IsA("SpecialMesh") then
		return {
			_class = "SpecialMesh",
			MeshType = tostring(mesh.MeshType),
			MeshId = mesh.MeshId,
			TextureId = mesh.TextureId,
			Scale = {mesh.Scale.X, mesh.Scale.Y, mesh.Scale.Z},
			Offset = {mesh.Offset.X, mesh.Offset.Y, mesh.Offset.Z},
			VertexColor = mesh.VertexColor and {mesh.VertexColor.X, mesh.VertexColor.Y, mesh.VertexColor.Z} or nil,
		}
	elseif mesh:IsA("BlockMesh") then
		return {
			_class = "BlockMesh",
			Scale = {mesh.Scale.X, mesh.Scale.Y, mesh.Scale.Z},
			Offset = {mesh.Offset.X, mesh.Offset.Y, mesh.Offset.Z},
			VertexColor = mesh.VertexColor and {mesh.VertexColor.X, mesh.VertexColor.Y, mesh.VertexColor.Z} or nil,
		}
	elseif mesh:IsA("CylinderMesh") then
		return {
			_class = "CylinderMesh",
			Scale = {mesh.Scale.X, mesh.Scale.Y, mesh.Scale.Z},
			Offset = {mesh.Offset.X, mesh.Offset.Y, mesh.Offset.Z},
		}
	end
	return nil
end

local function serializeDecal(decal)
	return {
		_class = decal.ClassName,
		Name = decal.Name,
		Texture = decal.Texture,
		Face = tostring(decal.Face),
		Transparency = originalDecalTransparency(decal),
		Color3 = {decal.Color3.R, decal.Color3.G, decal.Color3.B},
	}
end

local function serializeAttachment(att)
	return {
		_class = "Attachment",
		Name = att.Name,
		Position = {att.Position.X, att.Position.Y, att.Position.Z},
		Orientation = {att.Orientation.X, att.Orientation.Y, att.Orientation.Z},
		Axis = att.Axis and {att.Axis.X, att.Axis.Y, att.Axis.Z} or nil,
		SecondaryAxis = att.SecondaryAxis and {att.SecondaryAxis.X, att.SecondaryAxis.Y, att.SecondaryAxis.Z} or nil,
	}
end

local function serializeWeld(weld)
	local c0, c1 = weld.C0, weld.C1
	return {
		_class = weld.ClassName,
		Name = weld.Name,
		Part0Name = weld.Part0 and weld.Part0.Name or nil,
		Part1Name = weld.Part1 and weld.Part1.Name or nil,
		C0 = c0 and {c0:GetComponents()} or nil,
		C1 = c1 and {c1:GetComponents()} or nil,
	}
end

local function serializeWrapLayer(wl)
	return {_class = "WrapLayer", Name = wl.Name, Order = wl.Order, Puffiness = wl.Puffiness}
end

local function serializeWrapTarget(wt)
	local cage, import, cageId
	pcall(function() cage = wt.CageOrigin end)
	pcall(function() import = wt.ImportOrigin end)
	pcall(function() cageId = wt.CageMeshId end)
	return {
		_class = "WrapTarget",
		Name = wt.Name,
		Stiffness = wt.Stiffness,
		CageMeshId = cageId,
		CageOrigin = cage and {cage:GetComponents()} or nil,
		ImportOrigin = import and {import:GetComponents()} or nil,
	}
end

local function serializeSurfaceAppearance(sa)
	return {_class = "SurfaceAppearance", ColorMap = sa.ColorMap, MetalnessMap = sa.MetalnessMap, NormalMap = sa.NormalMap, RoughnessMap = sa.RoughnessMap}
end

local function buildMesh(parent, mdata)
	if not mdata then return nil end
	local mesh = nil
	if mdata._class == "SpecialMesh" then
		mesh = Instance.new("SpecialMesh")
		pcall(function() local t = cupEnum(Enum.MeshType, mdata.MeshType); if t then mesh.MeshType = t end end)
		if mdata.MeshId then mesh.MeshId = mdata.MeshId end
		if mdata.TextureId then mesh.TextureId = mdata.TextureId end
		if mdata.Scale then mesh.Scale = vec3(mdata.Scale) end
		if mdata.Offset then mesh.Offset = vec3(mdata.Offset) end
		if mdata.VertexColor then mesh.VertexColor = vec3(mdata.VertexColor) end
	elseif mdata._class == "BlockMesh" then
		mesh = Instance.new("BlockMesh")
		if mdata.Scale then mesh.Scale = vec3(mdata.Scale) end
		if mdata.Offset then mesh.Offset = vec3(mdata.Offset) end
		if mdata.VertexColor then mesh.VertexColor = vec3(mdata.VertexColor) end
	elseif mdata._class == "CylinderMesh" then
		mesh = Instance.new("CylinderMesh")
		if mdata.Scale then mesh.Scale = vec3(mdata.Scale) end
		if mdata.Offset then mesh.Offset = vec3(mdata.Offset) end
	end
	if mesh then mesh.Parent = parent end
	return mesh
end

local function buildDecal(parent, ddata)
	local decal = Instance.new(ddata._class == "Texture" and "Texture" or "Decal")
	decal.Name = ddata.Name or decal.Name
	decal.Texture = ddata.Texture
	if ddata.Face then pcall(function() local f = cupEnum(Enum.NormalId, ddata.Face); if f then decal.Face = f end end) end
	if ddata.Transparency ~= nil then decal.Transparency = ddata.Transparency end
	if ddata.Color3 then decal.Color3 = deserializeColor(ddata.Color3) end
	decal.Parent = parent
	return decal
end

local function cupFaceTextureValue(value)
	if type(value) == "string" and value ~= "" then return value end
	if type(value) == "number" and value > 0 then return "rbxassetid://" .. tostring(math.floor(value)) end
	return nil
end

local function cupFaceLikeName(name)
	local lower = string.lower(tostring(name or ""))
	if lower == "face" then return true end
	if lower:find("surface", 1, true) then return false end
	return lower:find("face", 1, true) ~= nil
end

local function cupIsFaceObject(obj)
	if not (obj:IsA("Decal") or obj:IsA("Texture")) then return false end
	if cupFaceLikeName(obj.Name) then return true end
	local ok, face = pcall(function() return obj.Face end)
	return ok and face == Enum.NormalId.Front
end

local function cupSavedFaceTexture(data)
	if type(data) ~= "table" then return nil end
	local direct = cupFaceTextureValue(data.face)
	if direct then return direct end
	local headData = data.parts and data.parts.Head
	local children = headData and headData.children
	if type(children) == "table" then
		for _, child in ipairs(children) do
			if (child._class == "Decal" or child._class == "Texture") and cupFaceLikeName(child.Name) then
				local texture = cupFaceTextureValue(child.Texture)
				if texture then return texture end
			end
		end
	end
	return nil
end

local function cupCollectFaces(head)
	local faces = {}
	if not head then return faces end
	for _, child in ipairs(head:GetChildren()) do
		if cupIsFaceObject(child) then table.insert(faces, child) end
	end
	return faces
end

local function cupApplyFace(head, data, clearWhenMissing)
	if not head then return nil end
	local texture = cupSavedFaceTexture(data)
	local faces = cupCollectFaces(head)
	if texture then
		local primary = faces[1]
		if primary then
			pcall(function()
				primary.Name = "face"
				primary.Texture = texture
				primary.Face = Enum.NormalId.Front
				primary.Transparency = 0
			end)
		else
			primary = Instance.new("Decal")
			primary.Name = "face"
			primary.Texture = texture
			primary.Face = Enum.NormalId.Front
			primary.Parent = head
		end
		for index = 2, #faces do
			pcall(function() faces[index]:Destroy() end)
		end
		return texture
	end
	if clearWhenMissing then
		for _, face in ipairs(faces) do
			pcall(function() face:Destroy() end)
		end
	end
	return nil
end

local sizeHoldEpoch = 0
local r6FaceGuard = nil

local function cupBumpSizeEpoch()
	sizeHoldEpoch = sizeHoldEpoch + 1
end

local function cupHoldSize(part, size, duration)
	if not part or not size then return end
	local epoch = sizeHoldEpoch
	pcall(function() part.Size = size end)
	task.spawn(function()
		local deadline = os.clock() + (duration or 1)
		while epoch == sizeHoldEpoch and os.clock() < deadline do
			task.wait(0.1)
			if part.Parent then
				pcall(function()
					if part.Size ~= size then part.Size = size end
				end)
			end
		end
	end)
end

local function stopR6FaceGuard()
	local guard = r6FaceGuard
	r6FaceGuard = nil
	if not guard then return end
	if guard.conn then pcall(function() guard.conn:Disconnect() end) end
	if guard.headConn then pcall(function() guard.headConn:Disconnect() end) end
end

local function enforceR6FaceGuard()
	local guard = r6FaceGuard
	if not guard then return end
	if myRunId ~= _G.CupcakeRunId or not guard.char or guard.char ~= player.Character or not guard.char.Parent then
		stopR6FaceGuard()
		return
	end
	local head = guard.head
	if not head or not head.Parent then
		head = guard.char:FindFirstChild("Head")
		guard.head = head
	end
	if not head then return end
	local faces = cupCollectFaces(head)
	if guard.texture then
		local primary = faces[1]
		if not primary then
			primary = Instance.new("Decal")
			primary.Name = "face"
			primary.Texture = guard.texture
			primary.Face = Enum.NormalId.Front
			primary.Parent = head
		elseif primary.Texture ~= guard.texture or primary.Transparency > 0 then
			pcall(function()
				primary.Name = "face"
				primary.Texture = guard.texture
				primary.Face = Enum.NormalId.Front
				primary.Transparency = 0
			end)
		end
		for index = 2, #faces do
			pcall(function() faces[index]:Destroy() end)
		end
	else
		for _, face in ipairs(faces) do
			if face.Transparency < 1 then
				pcall(function() face.Transparency = 1 end)
			end
		end
	end
end

local function startR6FaceGuard(char, data)
	stopR6FaceGuard()
	if scriptUnloaded or not char then return end
	local head = char:FindFirstChild("Head")
	if not head then return end
	local guard = {
		char = char,
		head = head,
		texture = cupSavedFaceTexture(data),
	}
	r6FaceGuard = guard
	enforceR6FaceGuard()
	guard.conn = head.ChildAdded:Connect(function(child)
		if child:IsA("Decal") or child:IsA("Texture") then
			task.defer(enforceR6FaceGuard)
		end
	end)
	guard.headConn = char.ChildAdded:Connect(function(child)
		if child.Name == "Head" then
			guard.head = child
			task.defer(enforceR6FaceGuard)
		end
	end)
	task.spawn(function()
		while r6FaceGuard == guard do
			task.wait(0.5)
			enforceR6FaceGuard()
		end
	end)
end

local function buildAttachment(parent, adata)
	local att = Instance.new("Attachment")
	att.Name = adata.Name
	if adata.Position then att.Position = vec3(adata.Position) end
	if adata.Orientation then att.Orientation = vec3(adata.Orientation) end
	if adata.Axis then att.Axis = vec3(adata.Axis) end
	if adata.SecondaryAxis then att.SecondaryAxis = vec3(adata.SecondaryAxis) end
	att.Parent = parent
	return att
end

local function buildWeld(parent, wdata, char)
	local weld = Instance.new(wdata._class == "Motor6D" and "Motor6D" or "Weld")
	weld.Name = wdata.Name or weld.Name
	if wdata.C0 then weld.C0 = CFrame.new(unpack(wdata.C0)) end
	if wdata.C1 then weld.C1 = CFrame.new(unpack(wdata.C1)) end
	if char and wdata.Part0Name and wdata.Part1Name then
		local p0 = char:FindFirstChild(wdata.Part0Name)
		local p1 = char:FindFirstChild(wdata.Part1Name)
		if p0 and p1 then
			weld.Part0 = p0
			weld.Part1 = p1
		end
	end
	weld.Parent = parent
	return weld
end

local function buildWrapLayer(parent, wdata)
	if not parent:IsA("MeshPart") then return nil end
	local wl = Instance.new("WrapLayer")
	wl.Name = wdata.Name or "WrapLayer"
	if wdata.Order ~= nil then wl.Order = wdata.Order end
	if wdata.Puffiness ~= nil then wl.Puffiness = wdata.Puffiness end
	local ok = pcall(function() wl.Parent = parent end)
	if not ok then wl:Destroy() return nil end
	return wl
end

local function buildWrapTarget(parent, wdata)
	if not parent:IsA("MeshPart") then return nil end

	local wt = nil
	if wdata.Name then
		local existing = parent:FindFirstChild(wdata.Name)
		if existing and existing:IsA("WrapTarget") then wt = existing end
	end
	if not wt then
		local existing = parent:FindFirstChildOfClass("WrapTarget")
		if existing then wt = existing end
	end
	if not wt then
		wt = Instance.new("WrapTarget")
		wt.Name = wdata.Name or "WrapTarget"
		local ok = pcall(function() wt.Parent = parent end)
		if not ok then wt:Destroy() return nil end
	end
	if wdata.Stiffness ~= nil then pcall(function() wt.Stiffness = wdata.Stiffness end) end
	if wdata.CageMeshId and wdata.CageMeshId ~= "" then
		pcall(function() wt.CageMeshId = wdata.CageMeshId end)
	end
	if wdata.CageOrigin then
		pcall(function() wt.CageOrigin = CFrame.new(unpack(wdata.CageOrigin)) end)
	end
	if wdata.ImportOrigin then
		pcall(function() wt.ImportOrigin = CFrame.new(unpack(wdata.ImportOrigin)) end)
	end
	return wt
end

local function buildSurfaceAppearance(parent, sdata)
	if not parent:IsA("MeshPart") then return nil end
	local sa = Instance.new("SurfaceAppearance")
	if sdata.ColorMap then sa.ColorMap = sdata.ColorMap end
	if sdata.MetalnessMap then sa.MetalnessMap = sdata.MetalnessMap end
	if sdata.NormalMap then sa.NormalMap = sdata.NormalMap end
	if sdata.RoughnessMap then sa.RoughnessMap = sdata.RoughnessMap end
	sa.Parent = parent
	return sa
end

local function sanitizeAccessoryPhysics(accessory)
	for _, part in pairs(accessory:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			part.Anchored = false
		end
	end
end

local function queueReload()
	if RELOAD_URL == "" then
		return
	end
	local q = queue_on_teleport or queueonteleport
	if type(q) ~= "function" then
		return
	end
	pcall(function()
		q('loadstring(game:HttpGet("' .. RELOAD_URL .. '"))()')
	end)
end

local function teleportToCatalog()
	local teleportService = game:GetService("TeleportService")
	pcall(function()
		player:Kick("\nTeleporting to Catalog...")
	end)
	task.wait(0.3)
	pcall(function()
		teleportService:Teleport(CATALOG_PLACE_ID, player)
	end)
end

local function isLayeredClothing(accessory)
	local handle = accessory:FindFirstChild("Handle")
	if handle and handle:FindFirstChildOfClass("WrapLayer") then return true end
	local ok, at = pcall(function() return accessory.AccessoryType end)
	if ok and at then
		local layeredTypes = {
			[Enum.AccessoryType.Shirt] = true,
			[Enum.AccessoryType.Pants] = true,
			[Enum.AccessoryType.Jacket] = true,
			[Enum.AccessoryType.Sweater] = true,
			[Enum.AccessoryType.Shorts] = true,
			[Enum.AccessoryType.LeftShoe] = true,
			[Enum.AccessoryType.RightShoe] = true,
			[Enum.AccessoryType.DressSkirt] = true,
		}
		if layeredTypes[at] then return true end
	end
	return false
end

local previewCache = {}

local function buildDescriptionInstance(descData, scales)
	local desc = Instance.new("HumanoidDescription")
	if not descData then
	else
		for prop, val in pairs(descData) do
			if prop ~= "accessories" and val ~= nil then
				pcall(function() desc[prop] = val end)
			end
		end
	end

	if scales then
		for humanoidName, descProp in pairs(HUMANOID_SCALE_TO_DESC) do
			local value = scales[humanoidName]
			if type(value) == "number" then
				pcall(function() desc[descProp] = value end)
			end
		end
	end
	if not descData then return desc end
	if descData.accessories then
		local list = {}
		for _, a in ipairs(descData.accessories) do
			if a.AssetId and a.AssetId ~= 0 then
				table.insert(list, {
					AssetId = a.AssetId,
					AccessoryType = cupEnum(Enum.AccessoryType, a.AccessoryType) or Enum.AccessoryType.Hat,
					IsLayered = a.IsLayered,
					Order = a.Order,
					Puffiness = a.Puffiness,
				})
			end
		end
		pcall(function() desc:SetAccessories(list, true) end)
	end
	return desc
end

local function freezeModelForViewport(model)
	for _, part in pairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
		end
	end
end

local function weldAccessory(character, accessory)
	local handle = accessory:FindFirstChild("Handle")
	if not handle then return end

	local existingWeld = nil
	for _, child in pairs(handle:GetChildren()) do
		if child:IsA("Weld") and child.Name == "AccessoryWeld" and child.Part0 and child.Part1 then
			existingWeld = child
			break
		end
	end

	if existingWeld then
		handle.CanCollide = false
		handle.CanTouch = false
		handle.CanQuery = false
		handle.Massless = true
		handle.Anchored = false
		return
	end

	for _, child in pairs(handle:GetChildren()) do
		if child:IsA("Weld") or child:IsA("WeldConstraint")
		   or child:IsA("Motor6D") or child:IsA("ManualWeld") then
			child:Destroy()
		end
	end

	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Anchored = false

	local handleAtt = handle:FindFirstChildOfClass("Attachment")
	if handleAtt then
		local charAtt = nil
		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("Attachment") and part.Name == handleAtt.Name
				and not part:FindFirstAncestorOfClass("Accessory") then
				charAtt = part
				break
			end
		end
		if charAtt and charAtt.Parent and charAtt.Parent:IsA("BasePart") then
			local charPart = charAtt.Parent
			local weld = Instance.new("Weld")
			weld.Name = "AccessoryWeld"
			weld.Part0 = charPart
			weld.Part1 = handle
			weld.C0 = charAtt.CFrame
			weld.C1 = handleAtt.CFrame
			weld.Parent = handle
			handle.CFrame = charPart.CFrame * charAtt.CFrame * handleAtt.CFrame:Inverse()
			return
		end
	end

	local head = character:FindFirstChild("Head")
	if head then
		local weld = Instance.new("Weld")
		weld.Name = "AccessoryWeld"
		weld.Part0 = head
		weld.Part1 = handle
		weld.C0 = CFrame.new(0, 0.5, 0)
		weld.Parent = handle
		handle.CFrame = head.CFrame * CFrame.new(0, 0.5, 0)
	end
end

local R6_BODY_PARTS = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}

local BODY_COLOR_GROUPS = {
	HeadColor = {"Head"},
	TorsoColor = {"Torso", "UpperTorso", "LowerTorso"},
	LeftArmColor = {"Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand"},
	RightArmColor = {"Right Arm", "RightUpperArm", "RightLowerArm", "RightHand"},
	LeftLegColor = {"Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"},
	RightLegColor = {"Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot"},
}

local function resolveBodyColor(avatarData, colorKey)
	if type(avatarData) ~= "table" then return nil end
	if type(avatarData.parts) == "table" then
		for _, partName in ipairs(BODY_COLOR_GROUPS[colorKey]) do
			local pdata = avatarData.parts[partName]
			if type(pdata) == "table" and pdata.Color then
				local ok, color = pcall(deserializeColor, pdata.Color)
				if ok and color then return color end
			end
		end
	end
	local colorName = type(avatarData.bodyColors) == "table" and avatarData.bodyColors[colorKey] or nil
	if colorName then
		local ok, brick = pcall(BrickColor.new, colorName)
		if ok and brick then return brick.Color end
	end
	return nil
end

local function applyBodyColors(character, avatarData)
	if not character then return end
	for colorKey, partNames in pairs(BODY_COLOR_GROUPS) do
		local color = resolveBodyColor(avatarData, colorKey)
		if color then
			for _, partName in ipairs(partNames) do
				local part = character:FindFirstChild(partName)
				if part and part:IsA("BasePart") then
					pcall(function() part.Color = color end)
				end
			end
		end
	end
end

local R6_ATTACH_TO_PART = {
	HatAttachment = "Head",
	HairAttachment = "Head",
	FaceFrontAttachment = "Head",
	FaceBackAttachment = "Head",
	FaceCenterAttachment = "Head",
	NeckAttachment = "Torso",
	BodyFrontAttachment = "Torso",
	BodyBackAttachment = "Torso",
	BodyLeftAttachment = "Torso",
	BodyRightAttachment = "Torso",
	WaistFrontAttachment = "Torso",
	WaistBackAttachment = "Torso",
	WaistCenterAttachment = "Torso",
	WaistLeftAttachment = "Torso",
	WaistRightAttachment = "Torso",
	RightShoulderAttachment = "Torso",
	LeftShoulderAttachment = "Torso",
	RightGripAttachment = "Right Arm",
	LeftGripAttachment = "Left Arm",
	RightHandAttachment = "Right Arm",
	LeftHandAttachment = "Left Arm",
	RightHandGripAttachment = "Right Arm",
	LeftHandGripAttachment = "Left Arm",
	RightFootAttachment = "Right Leg",
	LeftFootAttachment = "Left Leg",
	RightKneeAttachment = "Right Leg",
	LeftKneeAttachment = "Left Leg",
}

local R6_TYPE_ATTACH_PRIORITY = {
	[Enum.AccessoryType.Hat] = {"HatAttachment", "HairAttachment"},
	[Enum.AccessoryType.Hair] = {"HairAttachment", "HatAttachment"},
	[Enum.AccessoryType.Face] = {"FaceFrontAttachment", "FaceCenterAttachment", "FaceBackAttachment"},
	[Enum.AccessoryType.Neck] = {"NeckAttachment"},
	[Enum.AccessoryType.Front] = {"BodyFrontAttachment"},
	[Enum.AccessoryType.Back] = {"BodyBackAttachment"},
	[Enum.AccessoryType.Waist] = {"WaistCenterAttachment", "WaistBackAttachment", "WaistFrontAttachment", "WaistLeftAttachment", "WaistRightAttachment"},
	[Enum.AccessoryType.Shoulder] = {"LeftShoulderAttachment", "RightShoulderAttachment"},
	[Enum.AccessoryType.LeftShoe] = {"LeftFootAttachment"},
	[Enum.AccessoryType.RightShoe] = {"RightFootAttachment"},
}

local R6_TYPE_PART = {
	[Enum.AccessoryType.Hat] = "Head",
	[Enum.AccessoryType.Hair] = "Head",
	[Enum.AccessoryType.Face] = "Head",
	[Enum.AccessoryType.Neck] = "Torso",
	[Enum.AccessoryType.Shoulder] = "Torso",
	[Enum.AccessoryType.Front] = "Torso",
	[Enum.AccessoryType.Back] = "Torso",
	[Enum.AccessoryType.Waist] = "Torso",
	[Enum.AccessoryType.LeftShoe] = "Left Leg",
	[Enum.AccessoryType.RightShoe] = "Right Leg",
}

local function cupR6DefaultAttachmentCFrame(part, name)
	local size = part.Size
	local hx, hy, hz = size.X * 0.5, size.Y * 0.5, size.Z * 0.5
	if name == "HatAttachment" or name == "HairAttachment" then
		return CFrame.new(0, hy + 0.1, 0)
	elseif name == "FaceFrontAttachment" then
		return CFrame.new(0, 0, -(hz + 0.1))
	elseif name == "FaceBackAttachment" then
		return CFrame.new(0, 0, hz + 0.1)
	elseif name == "FaceCenterAttachment" then
		return CFrame.new(0, 0, 0)
	elseif name == "NeckAttachment" then
		return CFrame.new(0, hy, 0)
	elseif name == "BodyFrontAttachment" then
		return CFrame.new(0, 0, -hz)
	elseif name == "BodyBackAttachment" then
		return CFrame.new(0, 0, hz)
	elseif name == "BodyLeftAttachment" then
		return CFrame.new(-hx, 0, 0)
	elseif name == "BodyRightAttachment" then
		return CFrame.new(hx, 0, 0)
	elseif name == "WaistFrontAttachment" then
		return CFrame.new(0, -hy, -hz)
	elseif name == "WaistBackAttachment" then
		return CFrame.new(0, -hy, hz)
	elseif name == "WaistCenterAttachment" then
		return CFrame.new(0, -hy, 0)
	elseif name == "WaistLeftAttachment" then
		return CFrame.new(-hx, -hy, 0)
	elseif name == "WaistRightAttachment" then
		return CFrame.new(hx, -hy, 0)
	elseif name == "LeftShoulderAttachment" then
		return CFrame.new(-hx, hy * 0.5, 0)
	elseif name == "RightShoulderAttachment" then
		return CFrame.new(hx, hy * 0.5, 0)
	elseif name == "RightGripAttachment" or name == "RightHandAttachment" or name == "RightHandGripAttachment" then
		return CFrame.new(0, -hy, 0)
	elseif name == "LeftGripAttachment" or name == "LeftHandAttachment" or name == "LeftHandGripAttachment" then
		return CFrame.new(0, -hy, 0)
	elseif name == "RightFootAttachment" or name == "LeftFootAttachment" then
		return CFrame.new(0, -hy, 0)
	elseif name == "RightKneeAttachment" or name == "LeftKneeAttachment" then
		return CFrame.new(0, 0, -hz)
	end
	if part.Name == "Head" then
		return CFrame.new(0, hy + 0.1, 0)
	end
	return CFrame.new()
end

local R6_ATTACH_PRIORITY = {
	"HairAttachment", "HatAttachment",
	"FaceFrontAttachment", "FaceBackAttachment", "FaceCenterAttachment",
	"NeckAttachment",
	"BodyFrontAttachment", "BodyBackAttachment",
	"WaistCenterAttachment", "WaistFrontAttachment", "WaistBackAttachment",
	"WaistLeftAttachment", "WaistRightAttachment",
	"BodyLeftAttachment", "BodyRightAttachment",
	"RightGripAttachment", "LeftGripAttachment",
	"RightHandAttachment", "LeftHandAttachment",
	"RightHandGripAttachment", "LeftHandGripAttachment",
	"RightFootAttachment", "LeftFootAttachment",
	"RightKneeAttachment", "LeftKneeAttachment",
}

local function cupR6FindNamedAttachment(part, name)
	if not part or not name then return nil end
	local found = part:FindFirstChild(name)
	if found and found:IsA("Attachment") then return found end
	return nil
end

local function cupR6NameSuggestsLeft(name)
	local lower = string.lower(tostring(name or ""))
	return lower:find("left", 1, true) ~= nil
		or lower:find(" l", 1, true) ~= nil
		or lower:sub(1, 1) == "l"
end

local function cupR6NameSuggestsRight(name)
	local lower = string.lower(tostring(name or ""))
	return lower:find("right", 1, true) ~= nil
		or lower:find(" r", 1, true) ~= nil
		or lower:sub(1, 1) == "r"
end

local function cupR6GetAccessoryType(accessory)
	local ok, at = pcall(function() return accessory.AccessoryType end)
	if ok and at then return at end
	return nil
end

local function cupR6EnsureAttachmentOnPart(part, name)
	if not part or not name then return nil end
	local att = cupR6FindNamedAttachment(part, name)
	if att then return att end
	local created = Instance.new("Attachment")
	created.Name = name
	created.CFrame = cupR6DefaultAttachmentCFrame(part, name)
	created.Parent = part
	return created
end

local function cupR6RemoveWelds(handle)
	if not handle then return end
	for _, child in pairs(handle:GetChildren()) do
		if child:IsA("Weld") or child:IsA("WeldConstraint")
			or child:IsA("Motor6D") or child:IsA("AccessoryWeld") then
			pcall(function() child:Destroy() end)
		end
	end
end

local function cupR6PreferredAttachmentName(accessory)
	local at = cupR6GetAccessoryType(accessory)
	local list = at and R6_TYPE_ATTACH_PRIORITY[at] or nil
	return list and list[1] or "HatAttachment"
end

local function cupR6ChooseAttachment(accessory)
	local handle = accessory and accessory:FindFirstChild("Handle")
	if not handle then return nil end
	local sources = {}
	for _, child in pairs(handle:GetChildren()) do
		if child:IsA("Attachment") then
			sources[child.Name] = child
		end
	end

	local at = cupR6GetAccessoryType(accessory)
	if at == Enum.AccessoryType.Shoulder then
		local right = sources.RightShoulderAttachment
		local left = sources.LeftShoulderAttachment
		if right and (cupR6NameSuggestsRight(accessory.Name) or not left) then return right end
		if left then return left end
	end

	local preferred = at and R6_TYPE_ATTACH_PRIORITY[at] or nil
	if preferred then
		for _, name in ipairs(preferred) do
			if sources[name] then return sources[name] end
		end
	end

	for _, name in ipairs(R6_ATTACH_PRIORITY) do
		if sources[name] then return sources[name] end
	end

	local _, first = next(sources)
	return first
end

local function cupR6TargetForAttachment(accessory, sourceName)
	local partName = R6_ATTACH_TO_PART[sourceName]
	if partName then return sourceName, partName end
	local at = cupR6GetAccessoryType(accessory)
	local targetName = cupR6PreferredAttachmentName(accessory)
	local targetPart = at and R6_TYPE_PART[at] or "Head"
	return targetName, targetPart
end

local function cupR6WeldAccessory(character, accessory)
	local handle = accessory and accessory:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return false
	end

	local source = cupR6ChooseAttachment(accessory)
	if not source then
		source = Instance.new("Attachment")
		source.Name = cupR6PreferredAttachmentName(accessory)
		source.CFrame = CFrame.new()
		source.Parent = handle
	end

	local targetName, partName = cupR6TargetForAttachment(accessory, source.Name)
	local part = character:FindFirstChild(partName)
	if not part or not part:IsA("BasePart") then return false end
	local target = cupR6EnsureAttachmentOnPart(part, targetName)

	accessory.Parent = character
	handle.Anchored = false
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	cupR6RemoveWelds(handle)

	pcall(function()
		handle.CFrame = part.CFrame * target.CFrame * source.CFrame:Inverse()
	end)
	local weld = Instance.new("Weld")
	weld.Name = "AccessoryWeld"
	weld.Part0 = part
	weld.Part1 = handle
	weld.C0 = target.CFrame
	weld.C1 = source.CFrame
	weld.Parent = handle
	return true
end

local function cupR6ApplyCharacterMeshes(character, meshList)
	if not character then return end
	if type(meshList) ~= "table" or next(meshList) == nil then return end
	for _, obj in pairs(character:GetChildren()) do
		if obj:IsA("CharacterMesh") then
			pcall(function() obj:Destroy() end)
		end
	end
	for _, m in pairs(meshList) do
		local ok, cm = pcall(function() return Instance.new("CharacterMesh") end)
		if ok and cm then
			pcall(function()
				local bp = cupEnum(Enum.BodyPart, m.BodyPart)
				if bp then cm.BodyPart = bp end
				if m.MeshId then cm.MeshId = m.MeshId end
				if m.OverlayTextureId then cm.OverlayTextureId = m.OverlayTextureId end
				if m.BaseTextureId then cm.BaseTextureId = m.BaseTextureId end
			end)
			cm.Parent = character
		end
	end
end

local function cupCreateModelFromDescription(desc, timeout)
	local model = nil
	local done = false
	task.spawn(function()
		local ok, m = pcall(function()
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
		end)
		if ok and m then
			model = m
		end
		done = true
	end)
	local deadline = os.clock() + (timeout or 12)
	while not done and os.clock() < deadline do
		task.wait()
	end
	if not done then
		task.spawn(function()
			while not done do task.wait(0.25) end
			if model then pcall(function() model:Destroy() end) end
		end)
		return nil
	end
	return model
end

local function cupR6ApplyBodyFromDescription(character, humanoid, data)
	if not character or not humanoid then return false, nil end
	if not data or type(data.description) ~= "table" then return false, nil end
	local desc = buildDescriptionInstance(data.description)
	local model = cupCreateModelFromDescription(desc)
	if not model then
		pcall(function() desc:SetAccessories({}, true) end)
		model = cupCreateModelFromDescription(desc)
	end
	if not model then return false, nil end
	local convertedAccessories = {}
	for _, obj in pairs(model:GetChildren()) do
		if obj:IsA("Accessory") then
			local clone = nil
			pcall(function() clone = obj:Clone() end)
			if clone then
				local info = {accessory = clone, partName = nil, c0 = nil, c1 = nil, reversed = false}
				local handle = obj:FindFirstChild("Handle")
				if handle then
					for _, child in pairs(handle:GetChildren()) do
						if (child:IsA("Weld") or child:IsA("Motor6D"))
							and child.Part0 and child.Part1 then
							info.c0 = child.C0
							info.c1 = child.C1
							if child.Part1 == handle then
								info.partName = child.Part0.Name
							elseif child.Part0 == handle then
								info.partName = child.Part1.Name
								info.reversed = true
							end
							if info.partName then break end
						end
					end
				end
				table.insert(convertedAccessories, info)
			end
		end
	end
	applyBodyColors(model, data)
	local applied = false
	pcall(function()
		for _, obj in pairs(character:GetChildren()) do
			if obj:IsA("CharacterMesh") then
				pcall(function() obj:Destroy() end)
			end
		end
		for _, obj in pairs(model:GetChildren()) do
			if obj:IsA("CharacterMesh") then
				pcall(function()
					obj:Clone().Parent = character
				end)
			end
		end
		for _, partName in ipairs(R6_BODY_PARTS) do
			local live = character:FindFirstChild(partName)
			local src = model:FindFirstChild(partName)
			if live and src and live:IsA("BasePart") and src:IsA("BasePart") then
				for _, child in pairs(live:GetChildren()) do
					if child:IsA("SpecialMesh") or child:IsA("Decal") or child:IsA("Texture") then
						if not (partName == "Head" and cupIsFaceObject(child)) then
							pcall(function() child:Destroy() end)
						end
					end
				end
				for _, child in pairs(src:GetChildren()) do
					if child:IsA("SpecialMesh") or child:IsA("Decal") or child:IsA("Texture") then
						if not (partName == "Head" and cupIsFaceObject(child)) then
							pcall(function()
								child:Clone().Parent = live
							end)
						end
					end
				end
				pcall(function() live.BrickColor = src.BrickColor end)
				pcall(function() live.Material = src.Material end)
				pcall(function() live.Color = src.Color end)
				applied = true
			end
		end
		local srcHum = model:FindFirstChildOfClass("Humanoid")
		if srcHum then
			for _, name in ipairs({"BodyTypeScale", "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "BodyProportionScale", "HeadScale"}) do
				local s = srcHum:FindFirstChild(name)
				local d = humanoid:FindFirstChild(name)
				if s and d then
					pcall(function() d.Value = s.Value end)
				end
			end
		end
	end)
	pcall(function() model:Destroy() end)
	return applied, convertedAccessories
end

local function buildPreviewRig(data, forceR15)
	local sourceIsR6 = tostring(data.rigType or ""):find("R6") ~= nil
	if sourceIsR6 and data.description then
		data.description.accessories = {}
	end
	local wantsR6 = (not forceR15) and sourceIsR6
	local desc = buildDescriptionInstance(data.description, (not wantsR6) and data.scales or nil)
	local rigType = wantsR6 and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, rigType)
	end)
	if not ok or not model then return nil end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then model:Destroy() return nil end
	local isR6 = (humanoid.RigType == Enum.HumanoidRigType.R6)
	applyBodyColors(model, data)

	if not isR6 and type(data.scales) == "table" then
		for scaleName, value in pairs(data.scales) do
			local scaleObj = humanoid:FindFirstChild(scaleName)
			if scaleObj and scaleObj:IsA("NumberValue") then
				pcall(function() scaleObj.Value = value end)
			end
		end
	end
	if not isR6 then
		pcall(function() humanoid.AutomaticScalingEnabled = false end)
	end

	if not isR6 and not sourceIsR6 and data.parts then
		for partName, pdata in pairs(data.parts) do
			local existing = model:FindFirstChild(partName)
			if existing and existing:IsA("BasePart") then
				if existing:IsA("MeshPart") then
					if pdata._class == "Part" then
						pcall(function() existing.MeshId = "" end)
						pcall(function() existing.TextureID = "" end)
					else
						if pdata.MeshId and pdata.MeshId ~= "" then pcall(function() existing.MeshId = pdata.MeshId end) end
						if pdata.TextureID and pdata.TextureID ~= "" then pcall(function() existing.TextureID = pdata.TextureID end) end
					end
				end

				if pdata.Size then
					cupHoldSize(existing, vec3(pdata.Size), 1)
				end
				if pdata.Color then pcall(function() existing.Color = deserializeColor(pdata.Color) end) end
				if pdata.Material then pcall(function() local m = cupEnum(Enum.Material, pdata.Material); if m then existing.Material = m end end) end
				if pdata.Transparency ~= nil then existing.Transparency = pdata.Transparency end
				if pdata.Reflectance ~= nil then existing.Reflectance = pdata.Reflectance end
				if pdata.CastShadow ~= nil then existing.CastShadow = pdata.CastShadow end

				if pdata.children then
					if partName == "Head" then
						for _, child in pairs(existing:GetChildren()) do
							if child:IsA("Decal") or child:IsA("Texture") then
								if not cupIsFaceObject(child) then child:Destroy() end
							elseif child:IsA("DataModelMesh") then child:Destroy()
							elseif child:IsA("SurfaceAppearance") then child:Destroy() end
						end
					else
						for _, child in pairs(existing:GetChildren()) do
							if child:IsA("Decal") or child:IsA("Texture") or child:IsA("DataModelMesh") or child:IsA("SurfaceAppearance") then
								child:Destroy()
							end
						end
					end
					for _, cdata in pairs(pdata.children) do
						if cdata._class == "SpecialMesh" or cdata._class == "BlockMesh" or cdata._class == "CylinderMesh" then buildMesh(existing, cdata)
						elseif cdata._class == "Decal" or cdata._class == "Texture" then
							if not (partName == "Head" and cupFaceLikeName(cdata.Name)) then buildDecal(existing, cdata) end
						elseif cdata._class == "Attachment" then
							local att = existing:FindFirstChild(cdata.Name)
							if att and att:IsA("Attachment") then
								if cdata.Position then att.Position = vec3(cdata.Position) end
								if cdata.Orientation then att.Orientation = vec3(cdata.Orientation) end
							else buildAttachment(existing, cdata) end
						elseif (cdata._class == "Motor6D" or cdata._class == "Weld") and cdata.C0 and cdata.C1 then
							local joint = existing:FindFirstChild(cdata.Name)
							if joint and (joint:IsA("Motor6D") or joint:IsA("Weld")) then
								pcall(function()
									joint.C0 = CFrame.new(unpack(cdata.C0))
									joint.C1 = CFrame.new(unpack(cdata.C1))
								end)
							end
						elseif cdata._class == "SurfaceAppearance" then buildSurfaceAppearance(existing, cdata)
						elseif cdata._class == "WrapTarget" then buildWrapTarget(existing, cdata) end
					end
				end
			end
		end
	end

	local previewHead = model:FindFirstChild("Head")
	if previewHead then
		cupApplyFace(previewHead, data, true)
	end

	for _, obj in pairs(model:GetChildren()) do
		if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then obj:Destroy() end
	end
	if data.clothing then
		if data.clothing.shirt then
			local s = Instance.new("Shirt")
			s.ShirtTemplate = data.clothing.shirt
			s.Parent = model
		end
		if data.clothing.pants then
			local p = Instance.new("Pants")
			p.PantsTemplate = data.clothing.pants
			p.Parent = model
		end
		if data.clothing.tshirt then
			local t = Instance.new("ShirtGraphic")
			t.Graphic = data.clothing.tshirt
			t.Parent = model
		end
	end

	local liveAccessoryCount = 0
	local liveAccessoryNames = {}
	for _, obj in pairs(model:GetDescendants()) do
		if obj:IsA("Accessory") then
			liveAccessoryCount = liveAccessoryCount + 1
			liveAccessoryNames[obj.Name] = true
		end
	end
	local savedAccessoryCount = data.accessoriesManual and #data.accessoriesManual or 0

	if liveAccessoryCount < savedAccessoryCount and data.accessoriesManual then
		for _, adata in pairs(data.accessoriesManual) do
			local isLayered = false
			for _, cdata in pairs(adata.children or {}) do
				if cdata._class == "WrapLayer" then
					isLayered = true
					break
				end
			end
			if isLayered then continue end
			if liveAccessoryNames[adata.Name] then continue end

			local acc = Instance.new("Accessory")
			acc.Name = adata.Name or "Accessory"
			if adata.accessoryType then pcall(function() local t = cupEnum(Enum.AccessoryType, adata.accessoryType); if t then acc.AccessoryType = t end end) end
			if adata.handle then
				local handle
				if adata.handle.MeshId and adata.handle.MeshId ~= "" then
					handle = Instance.new("MeshPart")
					pcall(function() handle.MeshId = adata.handle.MeshId end)
					if adata.handle.TextureID then pcall(function() handle.TextureID = adata.handle.TextureID end) end
				else
					handle = Instance.new("Part")
					if adata.handle.Shape then pcall(function() local s = cupEnum(Enum.PartType, adata.handle.Shape); if s then handle.Shape = s end end) end
				end
				handle.Name = "Handle"
				local savedHandleSize = adata.handle.Size and vec3(adata.handle.Size) or Vector3.new(1,1,1)
				cupHoldSize(handle, savedHandleSize, 1)
				handle.CanCollide = false
				handle.CanTouch = false
				handle.Massless = true
				handle.Parent = acc
				if adata.handle.Color then pcall(function() handle.Color = deserializeColor(adata.handle.Color) end) end
				if adata.handle.Transparency ~= nil then handle.Transparency = adata.handle.Transparency end
				for _, cdata in pairs(adata.children or {}) do
					if cdata._class == "SpecialMesh" or cdata._class == "BlockMesh" or cdata._class == "CylinderMesh" then buildMesh(handle, cdata)
					elseif cdata._class == "Decal" or cdata._class == "Texture" then buildDecal(handle, cdata)
					elseif cdata._class == "Attachment" then buildAttachment(handle, cdata)
					elseif cdata._class == "WrapLayer" then buildWrapLayer(handle, cdata)
					elseif cdata._class == "Weld" or cdata._class == "Motor6D" then buildWeld(handle, cdata)
					elseif cdata._class == "SurfaceAppearance" then buildSurfaceAppearance(handle, cdata) end
				end
			end
			acc.Parent = model
			if isR6 then
				if not cupR6WeldAccessory(model, acc) then
					weldAccessory(model, acc)
				end
			else
				weldAccessory(model, acc)
			end
		end
	end

	freezeModelForViewport(model)
	return model
end

local function quantizeColor(c)
	return Color3.new(
		math.floor(c.R * 20 + 0.5) / 20,
		math.floor(c.G * 20 + 0.5) / 20,
		math.floor(c.B * 20 + 0.5) / 20
	)
end

local function extractAvatarColors(data)
	local seen = {}
	local colors = {}

	local function add(c)
		if not c then return end
		local q = quantizeColor(c)
		local key = math.floor(q.R * 255) .. "," .. math.floor(q.G * 255) .. "," .. math.floor(q.B * 255)
		if not seen[key] then
			seen[key] = true
			table.insert(colors, q)
		end
	end

	if data.parts then
		for _, pdata in pairs(data.parts) do
			if pdata.Color then
				add(deserializeColor(pdata.Color))
			end
		end
	end

	if data.accessoriesManual then
		for _, adata in pairs(data.accessoriesManual) do
			if adata.handle and adata.handle.Color then
				add(deserializeColor(adata.handle.Color))
			end
		end
	end

	if #colors > 8 then
		local trimmed = {}
		for i = 1, 8 do trimmed[i] = colors[i] end
		colors = trimmed
	end

	return colors
end

local function getPreviewColors(data)
	if data.previewColors and #data.previewColors > 0 then
		local colors = {}
		for _, c in ipairs(data.previewColors) do
			table.insert(colors, Color3.new(c[1], c[2], c[3]))
		end
		return colors
	end
	return extractAvatarColors(data)
end

local function loadAccessoryById(assetId)
	if not assetId or assetId == 0 then return nil end
	local ok, result = pcall(function() return InsertService:LoadAsset(assetId) end)
	if ok and result then
		local acc = result:FindFirstChildOfClass("Accessory")
		if acc then
			if isLayeredClothing(acc) and not false then
				return nil
			end
			local clone = acc:Clone()
			sanitizeAccessoryPhysics(clone)
			return clone
		end
		for _, child in pairs(result:GetChildren()) do
			if child:IsA("Accessory") then
				if isLayeredClothing(child) and not false then
					return nil
				end
				local clone = child:Clone()
				sanitizeAccessoryPhysics(clone)
				return clone
			end
		end
	end
	ok, result = pcall(function()
		local objs = game:GetObjects("rbxassetid://" .. tostring(assetId))
		return objs and objs[1]
	end)
	if ok and result then
		if result:IsA("Accessory") then
			if isLayeredClothing(result) and not false then
				return nil
			end
			local clone = result:Clone()
			sanitizeAccessoryPhysics(clone)
			return clone
		end
		if result:IsA("Model") then
			local acc = result:FindFirstChildOfClass("Accessory")
			if acc then
				if isLayeredClothing(acc) and not false then
					return nil
				end
				local clone = acc:Clone()
				sanitizeAccessoryPhysics(clone)
				return clone
			end
		end
	end
	return nil
end

local function CaptureAvatarData(targetChar)
	local char = targetChar or player.Character
	if not char then return nil end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local descOk, desc = pcall(function() return humanoid:GetAppliedDescription() end)
	if not descOk then desc = nil end

	local data = {version = 3, timestamp = os.time(), rigType = tostring(humanoid.RigType)}

	if desc then
		data.description = {}
		local props = {"Head", "LeftArm", "LeftLeg", "RightArm", "RightLeg", "Torso", "Face", "Shirt", "Pants", "GraphicTShirt", "BodyTypeScale", "DepthScale", "HeightScale", "ProportionScale", "WidthScale", "HeadScale", "IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "SwimAnimation"}
		for _, prop in ipairs(props) do
			pcall(function() data.description[prop] = desc[prop] end)
		end

		for humanoidName, descProp in pairs(HUMANOID_SCALE_TO_DESC) do
			local scaleObj = humanoid:FindFirstChild(humanoidName)
			if scaleObj and scaleObj:IsA("NumberValue") then
				data.description[descProp] = scaleObj.Value
			end
		end
		pcall(function()
			local accs = desc:GetAccessories(true)
			data.description.accessories = {}
			local seenAssetIds = {}
			for _, acc in ipairs(accs) do
				if not (acc.AssetId and acc.AssetId ~= 0 and seenAssetIds[acc.AssetId]) then
					if acc.AssetId and acc.AssetId ~= 0 then seenAssetIds[acc.AssetId] = true end
					local s = {AssetId = acc.AssetId, AccessoryType = acc.AccessoryType and tostring(acc.AccessoryType) or nil, IsLayered = acc.IsLayered, Order = acc.Order, Puffiness = acc.Puffiness, AttachmentPoint = acc.AttachmentPoint}
					if typeof(acc.Position) == "Vector3" then s.Position = {acc.Position.X, acc.Position.Y, acc.Position.Z} end
					if typeof(acc.Rotation) == "Vector3" then s.Rotation = {acc.Rotation.X, acc.Rotation.Y, acc.Rotation.Z} end
					if typeof(acc.Scale) == "Vector3" then s.Scale = {acc.Scale.X, acc.Scale.Y, acc.Scale.Z} end
					table.insert(data.description.accessories, s)
				end
			end
		end)
	end

	if humanoid.RigType == Enum.HumanoidRigType.R6 and data.description then
		data.description.accessories = {}
	end

	data.parts = {}
	for _, part in pairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			local isInAccessory = false
			local parent = part.Parent
			while parent do
				if parent:IsA("Accessory") then isInAccessory = true; break end
				parent = parent.Parent
			end
			if isInAccessory then continue end
			local pdata = serializePart(part)
			pdata.children = {}
			for _, child in pairs(part:GetChildren()) do
				if child:IsA("DataModelMesh") then table.insert(pdata.children, serializeMesh(child))
				elseif child:IsA("Decal") or child:IsA("Texture") then
					if not (part.Name == "Head" and cupIsFaceObject(child)) then
						table.insert(pdata.children, serializeDecal(child))
					end
				elseif child:IsA("Attachment") then table.insert(pdata.children, serializeAttachment(child))
				elseif child:IsA("SurfaceAppearance") then table.insert(pdata.children, serializeSurfaceAppearance(child))
				elseif child:IsA("WrapTarget") then table.insert(pdata.children, serializeWrapTarget(child))
				elseif child:IsA("Weld") or child:IsA("Motor6D") then
					if child.Part0 and child.Part0.Parent == char and child.Part1 and child.Part1.Parent == char then
						table.insert(pdata.children, serializeWeld(child))
					end
				end
			end
			data.parts[part.Name] = pdata
		end
	end

	data.accessoriesManual = {}
	local seenAccessoryNames = {}
	for _, acc in pairs(char:GetDescendants()) do
		if acc:IsA("Accessory") then
			if seenAccessoryNames[acc.Name] then continue end
			seenAccessoryNames[acc.Name] = true
			local adata = {Name = acc.Name, accessoryType = nil, handle = nil, children = {}}
			pcall(function() adata.accessoryType = tostring(acc.AccessoryType) end)
			local handle = acc:FindFirstChild("Handle")
			if handle then
				adata.handle = serializePart(handle)
				for _, child in pairs(handle:GetChildren()) do
					if child:IsA("DataModelMesh") then table.insert(adata.children, serializeMesh(child))
					elseif child:IsA("Decal") or child:IsA("Texture") then table.insert(adata.children, serializeDecal(child))
					elseif child:IsA("Attachment") then table.insert(adata.children, serializeAttachment(child))
					elseif child:IsA("WrapLayer") then table.insert(adata.children, serializeWrapLayer(child))
					elseif child:IsA("Weld") or child:IsA("Motor6D") then table.insert(adata.children, serializeWeld(child))
					elseif child:IsA("SurfaceAppearance") then table.insert(adata.children, serializeSurfaceAppearance(child))
					end
				end
			end
			table.insert(data.accessoriesManual, adata)
		end
	end

	data.clothing = {}
	for _, obj in pairs(char:GetChildren()) do
		if obj:IsA("Shirt") then data.clothing.shirt = obj.ShirtTemplate
		elseif obj:IsA("Pants") then data.clothing.pants = obj.PantsTemplate
		elseif obj:IsA("ShirtGraphic") then data.clothing.tshirt = obj.Graphic end
	end

	local head = char:FindFirstChild("Head")
	if head then
		local face = nil
		local named = head:FindFirstChild("face")
		if named and named:IsA("Decal") and named.Transparency < 1 then
			face = named
		else
			for _, child in ipairs(head:GetChildren()) do
				if cupIsFaceObject(child) and child.Transparency < 1 then
					face = child
					break
				end
			end
		end
		if face then data.face = face.Texture end
	end

	data.animations = {}
	local animate = char:FindFirstChild("Animate")
	if animate then
		local function getAnimPath(animObj)
			local pathParts = {}
			local current = animObj
			while current and current ~= animate do
				table.insert(pathParts, 1, current.Name)
				current = current.Parent
			end
			return table.concat(pathParts, "/")
		end
		for _, obj in pairs(animate:GetDescendants()) do
			if obj:IsA("Animation") then
				local path = getAnimPath(obj)
				data.animations[path] = obj.AnimationId
			end
		end
	end

	local bc = char:FindFirstChild("Body Colors")
	if bc then
		data.bodyColors = {}
		local function gc(prop)
			local ok, val = pcall(function() return bc[prop] end)
			return ok and val and val.Name or nil
		end
		data.bodyColors.HeadColor = gc("HeadColor")
		data.bodyColors.TorsoColor = gc("TorsoColor")
		data.bodyColors.LeftArmColor = gc("LeftArmColor")
		data.bodyColors.LeftLegColor = gc("LeftLegColor")
		data.bodyColors.RightArmColor = gc("RightArmColor")
		data.bodyColors.RightLegColor = gc("RightLegColor")
	end

	data.characterMeshes = {}
	for _, obj in pairs(char:GetChildren()) do
		if obj:IsA("CharacterMesh") then
			local m = {}
			pcall(function() m.BodyPart = tostring(obj.BodyPart) end)
			pcall(function() m.MeshId = obj.MeshId end)
			pcall(function() m.OverlayTextureId = obj.OverlayTextureId end)
			pcall(function() m.BaseTextureId = obj.BaseTextureId end)
			table.insert(data.characterMeshes, m)
		end
	end

	data.scales = {}
	for _, name in ipairs({"BodyDepthScale","BodyHeightScale","BodyWidthScale","BodyTypeScale","BodyProportionScale","HeadScale"}) do
		local obj = humanoid:FindFirstChild(name)
		if obj then data.scales[name] = obj.Value end
	end

	data.walkSpeed = humanoid.WalkSpeed
	data.jumpPower = humanoid.JumpPower

	return data
end

local follower = nil
local applyingFollower = false
local r15UsingFollower = false

local R15_BODY_PARTS = {
	Head = true, UpperTorso = true, LowerTorso = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

local function stashTransparency(d, map, attr)
	local t = map[d]
	if t ~= nil then return t end
	t = d:GetAttribute(attr)
	if t == nil then
		t = d.Transparency
		pcall(function() d:SetAttribute(attr, t) end)
	end
	map[d] = t
	return t
end

local function stashWrapEnabled(d)
	local v = hiddenWrapOriginals[d]
	if v ~= nil then return v end
	v = d:GetAttribute(ORIG_WRAP_ATTR)
	if v == nil then
		v = d.Enabled
		pcall(function() d:SetAttribute(ORIG_WRAP_ATTR, v) end)
	end
	hiddenWrapOriginals[d] = v
	return v
end

local function hideInstance(d)
	if d:FindFirstAncestorOfClass("Tool") then return end
	if d:IsA("BasePart") then
		stashTransparency(d, hiddenPartOriginals, ORIG_PART_ATTR)
		pcall(function()
			d.Transparency = 1
			d.LocalTransparencyModifier = 1
		end)
	elseif d:IsA("Decal") or d:IsA("Texture") then
		stashTransparency(d, hiddenDecalOriginals, ORIG_DECAL_ATTR)
		pcall(function() d.Transparency = 1 end)
	elseif d:IsA("WrapLayer") then
		stashWrapEnabled(d)
		pcall(function() d.Enabled = false end)
	end
end

local function unhideInstance(d)
	local isPart = d:IsA("BasePart")
	local map = isPart and hiddenPartOriginals or hiddenDecalOriginals
	local attr = isPart and ORIG_PART_ATTR or ORIG_DECAL_ATTR
	local t = map[d]
	if t == nil then t = d:GetAttribute(attr) end
	if t ~= nil then
		pcall(function() d.Transparency = t end)
		pcall(function() d:SetAttribute(attr, nil) end)
	end
	map[d] = nil
	if isPart then
		pcall(function() d.LocalTransparencyModifier = 0 end)
	end
end

local function unhideWrapLayer(d)
	local v = hiddenWrapOriginals[d]
	if v == nil then v = d:GetAttribute(ORIG_WRAP_ATTR) end
	if v ~= nil then
		pcall(function() d.Enabled = v end)
		pcall(function() d:SetAttribute(ORIG_WRAP_ATTR, nil) end)
	end
	hiddenWrapOriginals[d] = nil
end

local function recoverHiddenAvatar(char)
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		local isPart = d:IsA("BasePart")
		local isDecal = d:IsA("Decal") or d:IsA("Texture")
		local isWrap = d:IsA("WrapLayer")
		if isPart or isDecal then
			local attr = isPart and ORIG_PART_ATTR or ORIG_DECAL_ATTR
			local orig = d:GetAttribute(attr)
			if orig ~= nil then
				pcall(function() d.Transparency = orig end)
				pcall(function() d:SetAttribute(attr, nil) end)
			end
			if isPart then
				pcall(function() d.LocalTransparencyModifier = 0 end)
			end
		elseif isWrap then
			local orig = d:GetAttribute(ORIG_WRAP_ATTR)
			if orig ~= nil then
				pcall(function() d.Enabled = orig end)
				pcall(function() d:SetAttribute(ORIG_WRAP_ATTR, nil) end)
			end
		end
	end
end

local function clearFollower()
	local f = follower
	follower = nil
	r15UsingFollower = false
	if f and f.conn then pcall(function() f.conn:Disconnect() end) end
	if f and f.descConn then pcall(function() f.descConn:Disconnect() end) end
	for d in pairs(hiddenPartOriginals) do unhideInstance(d) end
	for d in pairs(hiddenDecalOriginals) do unhideInstance(d) end
	for d in pairs(hiddenWrapOriginals) do unhideWrapLayer(d) end
	if f then pcall(function() f.model:Destroy() end) end
end

local function isAnimatedJoint(obj)
	return obj:IsA("Motor6D") or obj:IsA("AnimationConstraint")
end

local function animationPath(animate, animObj)
	if not animate or not animObj then return nil end
	local pathParts = {}
	local current = animObj
	while current and current ~= animate do
		table.insert(pathParts, 1, current.Name)
		current = current.Parent
	end
	if current ~= animate then return nil end
	return table.concat(pathParts, "/")
end

local FOOT_NAMES = {"LeftFoot", "RightFoot", "Left Leg", "Right Leg"}

local function collectFeet(character)
	local feet = {}
	if not character then return feet end
	for _, footName in ipairs(FOOT_NAMES) do
		local foot = character:FindFirstChild(footName)
		if foot and foot:IsA("BasePart") then
			table.insert(feet, foot)
		end
	end
	return feet
end

local function footBottomYFromParts(feet)
	local lowest = math.huge
	for _, foot in ipairs(feet) do
		if foot.Parent then
			local cf = foot.CFrame
			local size = foot.Size
			local _, y, _, _, _, _, r10, r11, r12 = cf:GetComponents()
			local bottom = y - (math.abs(r10) * size.X + math.abs(r11) * size.Y + math.abs(r12) * size.Z) * 0.5
			if bottom < lowest then lowest = bottom end
		end
	end
	return lowest
end

local function applyFollower(char, humanoid, data)
	if applyingFollower then return false end
	applyingFollower = true
	clearFollower()

	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "CupcakeFollower" then
			pcall(function() obj:Destroy() end)
		end
	end

	local built, model = pcall(buildPreviewRig, data, true)
	if not built or not model then
		applyingFollower = false
		return false
	end
	if player.Character ~= char or not char.Parent then
		pcall(function() model:Destroy() end)
		applyingFollower = false
		return false
	end

	local cloneHum = model:FindFirstChildOfClass("Humanoid")
	local cloneRoot = model:FindFirstChild("HumanoidRootPart")
	local realRoot = char:FindFirstChild("HumanoidRootPart")
	if not cloneRoot or not realRoot then
		model:Destroy()
		applyingFollower = false
		return false
	end

	model.Name = "CupcakeFollower"

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Accessory") then
			pcall(function() weldAccessory(model, d) end)
		elseif d:IsA("WrapLayer") then
			pcall(function() d.Enabled = true end)
		end
	end

	local wrapTargetCount, wrapCageCount, wrapLayerCount = 0, 0, 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("WrapTarget") then
			wrapTargetCount = wrapTargetCount + 1
			local cage = nil
			pcall(function() cage = d.CageMeshId end)
			if cage and cage ~= "" then wrapCageCount = wrapCageCount + 1 end
		elseif d:IsA("WrapLayer") then
			wrapLayerCount = wrapLayerCount + 1
		end
	end
	print(string.format(
		"[Cupcake] R15 clothing: %d wrap targets (%d with cages), %d wrap layers",
		wrapTargetCount, wrapCageCount, wrapLayerCount
	))

	if cloneHum then
		pcall(function() cloneHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
		pcall(function() cloneHum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff end)
		pcall(function() cloneHum.NameDisplayDistance = 0 end)
		pcall(function() cloneHum.HealthDisplayDistance = 0 end)
		pcall(function() cloneHum.EvaluateStateMachine = false end)
		pcall(function() cloneHum.AutoRotate = false end)
		pcall(function() cloneHum.BreakJointsOnDeath = false end)
		pcall(function() cloneHum.RequiresNeck = false end)
		pcall(function() cloneHum.MaxHealth = 1e9 end)
		pcall(function() cloneHum.Health = 1e9 end)
		local decoyAnimate = model:FindFirstChild("Animate")
		if decoyAnimate then pcall(function() decoyAnimate:Destroy() end) end
		local animator = cloneHum:FindFirstChildOfClass("Animator")
		if not animator and type(data.animations) == "table" and next(data.animations) ~= nil then
			animator = Instance.new("Animator")
			animator.Parent = cloneHum
		end
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				pcall(function() track:Stop(0) end)
			end
		end
	end

	local visibleCore = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and R15_BODY_PARTS[d.Name] and d.Transparency < 1 then
			visibleCore = visibleCore + 1
		end
	end
	if visibleCore == 0 then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and R15_BODY_PARTS[d.Name] then
				d.Transparency = 0
			end
		end
	end

	model.PrimaryPart = cloneRoot
	local pivotDelta = realRoot.CFrame * cloneRoot.CFrame:Inverse()
	local decoyParts = {}
	local allParts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(allParts, d)
			d.Anchored = true
		end
	end
	for _, d in ipairs(allParts) do
		pcall(function() d.CFrame = pivotDelta * d.CFrame end)
	end
	for _, d in ipairs(allParts) do
		table.insert(decoyParts, d)
		d.Anchored = not d:FindFirstAncestorOfClass("Accessory")
		d.CanCollide = false
		d.CanTouch = false
		d.CanQuery = false
		d.Massless = true
		pcall(function() d.LocalTransparencyModifier = 0 end)
	end

	pcall(function()
		local physics = game:GetService("PhysicsService")
		pcall(function() physics:RegisterCollisionGroup("CupcakeDecoy") end)
		local groups = {Default = true}
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then groups[d.CollisionGroup] = true end
		end
		for g in pairs(groups) do
			pcall(function() physics:CollisionGroupSetCollidable("CupcakeDecoy", g, false) end)
		end
		for _, p in ipairs(decoyParts) do
			pcall(function() p.CollisionGroup = "CupcakeDecoy" end)
		end
	end)

	local cloneDrop
	local decoyFeet = collectFeet(model)
	local realFeet = collectFeet(char)
	local decoyFootBottom = footBottomYFromParts(decoyFeet)
	if decoyFootBottom < math.huge then
		cloneDrop = cloneRoot.Position.Y - decoyFootBottom
	elseif cloneHum then
		cloneDrop = cloneHum.HipHeight + cloneRoot.Size.Y / 2
	else
		cloneDrop = realRoot.Size.Y / 2
	end
	local realDrop
	local realFootBottom = footBottomYFromParts(realFeet)
	if realFootBottom < math.huge then
		realDrop = realRoot.Position.Y - realFootBottom
	else
		realDrop = humanoid.HipHeight + realRoot.Size.Y / 2
	end
	local dropOffset = cloneDrop - realDrop
	print(string.format(
		"[Cupcake] R15 height: hip=%.3f realDrop=%.3f decoyDrop=%.3f offset=%.3f realFootY=%.3f",
		humanoid.HipHeight, realDrop, cloneDrop, dropOffset,
		realRoot.Position.Y - realDrop
	))

	local realJoints = {}
	for _, d in ipairs(char:GetDescendants()) do
		if isAnimatedJoint(d) and d.Part1 and not d:FindFirstAncestorOfClass("Accessory") then
			local existing = realJoints[d.Part1.Name]

			if not existing or d:IsA("AnimationConstraint") then
				realJoints[d.Part1.Name] = d
			end
		end
	end

	local decoyJoints = {}
	for _, d in ipairs(model:GetDescendants()) do
		if isAnimatedJoint(d) and d.Part0 and d.Part1
			and d.Part0:IsDescendantOf(model) and d.Part1:IsDescendantOf(model)
			and not d:FindFirstAncestorOfClass("Accessory") then
			table.insert(decoyJoints, d)
		end
	end

	local byPart0, byPart1 = {}, {}
	for _, j in ipairs(decoyJoints) do
		byPart0[j.Part0] = byPart0[j.Part0] or {}
		table.insert(byPart0[j.Part0], j)
		byPart1[j.Part1] = byPart1[j.Part1] or {}
		table.insert(byPart1[j.Part1], j)
	end
	local links = {}
	local placed = {[cloneRoot] = true}
	local queue = {cloneRoot}
	local qi = 1
	while qi <= #queue do
		local parent = queue[qi]
		qi = qi + 1
		local candidates = {}
		for _, j in ipairs(byPart0[parent] or {}) do
			table.insert(candidates, {joint = j, child = j.Part1, reversed = false})
		end
		for _, j in ipairs(byPart1[parent] or {}) do
			table.insert(candidates, {joint = j, child = j.Part0, reversed = true})
		end
		for _, c in ipairs(candidates) do
			local child = c.child
			if child and not placed[child] then
				placed[child] = true
				table.insert(queue, child)
				local real = realJoints[child.Name]
				if real then
					local pre, post
					if c.reversed then
						pre = c.joint.C1
						post = c.joint.C0:Inverse()
					else
						pre = c.joint.C0
						post = c.joint.C1:Inverse()
					end
					table.insert(links, {
						parent = parent,
						child = child,
						pre = pre,
						post = post,
						real = real,
						reversed = c.reversed,
						jointClass = c.joint.ClassName,
					})
				end
			end
		end
	end
	if #links == 0 then
		pcall(function() model:Destroy() end)
		applyingFollower = false
		warn("[Cupcake] R15 decoy aborted: no animation joints matched this game's rig")
		return false
	end

	local head = model:FindFirstChild("Head")
	local visibleParts = {}
	local visibleDecals = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			visibleParts[d] = d.Transparency
		elseif d:IsA("Decal") or d:IsA("Texture") then
			visibleDecals[d] = d.Transparency
		end
	end

	local state = {
		char = char, model = model, root = cloneRoot, realRoot = realRoot,
		dropOffset = dropOffset, links = links, humanoid = cloneHum,
		parts = decoyParts, decoyFeet = decoyFeet, realFeet = realFeet,
		head = head, visibleParts = visibleParts, visibleDecals = visibleDecals,
		realHumanoid = humanoid, animate = char:FindFirstChild("Animate"),
		savedAnims = ((not tostring(data.rigType or ""):find("R6")) and type(data.animations) == "table" and next(data.animations) ~= nil)
			and data.animations or nil,
		decoyAnimator = cloneHum and cloneHum:FindFirstChildOfClass("Animator") or nil,
		animTracks = {}, animActive = false,
		conn = nil, descConn = nil, dropReady = false, stillSince = nil, spawnedAt = os.clock(), settleAt = nil, settleDone = false,
		firstPersonHidden = false, hideAt = 0, maintAt = 0,
	}
	follower = state

	cloneRoot.CFrame = realRoot.CFrame + Vector3.new(0, dropOffset, 0)
	for _, l in ipairs(links) do
		local real = l.real
		if real and real.Parent then
			local t = real.Transform
			if l.reversed then t = t:Inverse() end
			l.child.CFrame = l.parent.CFrame * l.pre * t * l.post
		else
			l.child.CFrame = l.parent.CFrame * l.pre * l.post
		end
	end
	model.Parent = workspace

	if cloneHum then
		pcall(function() cloneHum:SetStateEnabled(Enum.HumanoidStateType.Physics, true) end)
		pcall(function() cloneHum:ChangeState(Enum.HumanoidStateType.Physics) end)
	end

	if state.savedAnims and state.decoyAnimator then
		for _, p in ipairs(state.parts) do
			if p ~= cloneRoot and not p:FindFirstAncestorOfClass("Accessory") then
				pcall(function() p.Anchored = false end)
			end
		end
	end

	for _, d in ipairs(char:GetDescendants()) do hideInstance(d) end
	state.descConn = char.DescendantAdded:Connect(function(d)
		if follower ~= state then return end
		hideInstance(d)
		if d:IsA("Model") or d:IsA("Accessory") then
			for _, c in ipairs(d:GetDescendants()) do hideInstance(c) end
		end
	end)

	local function stopAnimEntry(entry)
		if not entry then return end
		pcall(function() entry.track:Stop(0.1) end)
		pcall(function() entry.anim:Destroy() end)
	end

	local function syncDecoyAnimations(f)
		if not f.savedAnims or not f.decoyAnimator then return false end
		local realAnimator = f.realHumanoid and f.realHumanoid:FindFirstChildOfClass("Animator")
		if not realAnimator then return false end

		local realTracks = realAnimator:GetPlayingAnimationTracks()
		local playing = {}
		local active = 0

		for _, realTrack in ipairs(realTracks) do
			local source = realTrack.Animation
			if source then
				playing[realTrack] = true
				local path = animationPath(f.animate, source)
				local id = path and f.savedAnims[path] or nil
				if type(id) ~= "string" or id == "" then id = source.AnimationId end

				local entry = f.animTracks[realTrack]
				if entry and entry.id ~= id then
					stopAnimEntry(entry)
					f.animTracks[realTrack] = nil
					entry = nil
				end

				if not entry then
					local sourceAnim = Instance.new("Animation")
					sourceAnim.Name = "CupcakeAnim"
					sourceAnim.AnimationId = id
					sourceAnim.Parent = f.model

					local decoyTrack
					local loaded = pcall(function()
						decoyTrack = f.decoyAnimator:LoadAnimation(sourceAnim)
					end)
					if loaded and decoyTrack then
						entry = {track = decoyTrack, anim = sourceAnim, id = id, speed = realTrack.Speed}
						f.animTracks[realTrack] = entry
						pcall(function() decoyTrack.Looped = true end)
						pcall(function() decoyTrack.Priority = realTrack.Priority end)
						pcall(function() decoyTrack:Play(0, 1, realTrack.Speed) end)
					else
						pcall(function() sourceAnim:Destroy() end)
					end
				end

				if entry then
					active = active + 1
					pcall(function()
						if not entry.track.IsPlaying then
							entry.track:Play(0, 1, realTrack.Speed)
						end
						if math.abs(entry.speed - realTrack.Speed) > 0.01 then
							entry.speed = realTrack.Speed
							entry.track:AdjustSpeed(realTrack.Speed)
						end
						entry.track:AdjustWeight(realTrack.WeightCurrent, 0)
					end)
				end
			end
		end

		for realTrack, entry in pairs(f.animTracks) do
			if not playing[realTrack] then
				stopAnimEntry(entry)
				f.animTracks[realTrack] = nil
			end
		end

		return active > 0
	end

	local function step()
		local f = follower
		if not f then return end
		if myRunId ~= _G.CupcakeRunId
			or player.Character ~= f.char
			or not f.char.Parent
			or not f.model.Parent then
			clearFollower()
			return
		end

		local now = os.clock()

		if now - f.hideAt > 0.25 then
			f.hideAt = now
			for part in pairs(hiddenPartOriginals) do
				if part.Parent then
					if part.Transparency ~= 1 then part.Transparency = 1 end
					if part.LocalTransparencyModifier ~= 1 then part.LocalTransparencyModifier = 1 end
				else
					hiddenPartOriginals[part] = nil
				end
			end
			for decal in pairs(hiddenDecalOriginals) do
				if decal.Parent then
					if decal.Transparency ~= 1 then decal.Transparency = 1 end
				else
					hiddenDecalOriginals[decal] = nil
				end
			end
		end

		if now - f.maintAt > 0.5 then
			f.maintAt = now
			if f.humanoid and f.humanoid.Parent then
				if f.humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
					pcall(function() f.humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
				end
			end
			for _, p in ipairs(f.parts) do
				if p.Parent then
					if p:FindFirstAncestorOfClass("Accessory") then
						if p.Anchored then p.Anchored = false end
					elseif p == f.root then
						if not p.Anchored then p.Anchored = true end
					elseif f.savedAnims and f.decoyAnimator then
						if p.Anchored then p.Anchored = false end
					elseif not p.Anchored then
						p.Anchored = true
					end
					if p.CanCollide then p.CanCollide = false end
					if p.CanTouch then p.CanTouch = false end
					if p.CanQuery then p.CanQuery = false end
				end
			end
		end

		if not (f.realRoot and f.realRoot.Parent) then return end

		if syncDecoyAnimations(f) then f.animActive = true end
		local animDriving = f.animActive

		if f.dropReady then
			local grounded = false
			local moving = true
			if f.realHumanoid and f.realHumanoid.Parent then
				grounded = f.realHumanoid.FloorMaterial ~= Enum.Material.Air
				moving = f.realHumanoid.MoveDirection.Magnitude >= 0.05
			end
			local still = grounded and not moving
			local loadCheck = false
			if not f.settleDone and (now - f.spawnedAt) >= 1 then
				if grounded then
					f.settleAt = f.settleAt or now
					if now - f.settleAt <= 1.5 then
						loadCheck = true
					else
						f.settleDone = true
					end
				else
					f.settleAt = nil
				end
			end
			if still then
				f.stillSince = f.stillSince or now
			else
				f.stillSince = nil
			end
			if loadCheck or (still and now - f.stillSince >= 1) then
				local decoyFoot = footBottomYFromParts(f.decoyFeet)
				local realFoot = footBottomYFromParts(f.realFeet)
				if decoyFoot < math.huge and realFoot < math.huge then
					local target = (f.root.Position.Y - decoyFoot) - (f.realRoot.Position.Y - realFoot)
					local delta = target - f.dropOffset
					if math.abs(delta) > 0.01 then
						f.dropOffset = f.dropOffset + delta * 0.5
					end
				end
			end
		end
		f.dropReady = true

		f.root.CFrame = f.realRoot.CFrame + Vector3.new(0, f.dropOffset, 0)
		if not animDriving then
			for _, l in ipairs(f.links) do
				local real = l.real
				if real and real.Parent then
					local t = real.Transform
					if l.reversed then t = t:Inverse() end
					l.child.CFrame = l.parent.CFrame * l.pre * t * l.post
				else
					l.child.CFrame = l.parent.CFrame * l.pre * l.post
				end
			end
		end

		local cam = workspace.CurrentCamera
		local h = f.head
		if cam then
			local close = false
			if h and h.Parent then
				close = (cam.CFrame.Position - h.Position).Magnitude < 2
			end
			local realHead = f.char and f.char:FindFirstChild("Head")
			if not close and realHead and realHead:IsA("BasePart") then
				close = (cam.CFrame.Position - realHead.Position).Magnitude < 2
			end
			if close ~= f.firstPersonHidden then
				f.firstPersonHidden = close
				for p, t in pairs(f.visibleParts) do
					if p.Parent then
						pcall(function()
							p.Transparency = close and 1 or t
							p.LocalTransparencyModifier = close and 1 or 0
						end)
					end
				end
				for d, t in pairs(f.visibleDecals) do
					if d.Parent then
						pcall(function() d.Transparency = close and 1 or t end)
					end
				end
			end
		end
	end

	local signal = RunService.PreRender or RunService.RenderStepped or RunService.Heartbeat
	state.conn = signal:Connect(step)
	r15UsingFollower = true
	applyingFollower = false
	local realKind = links[1] and links[1].real.ClassName or "none"
	local decoyKind = links[1] and links[1].jointClass or "none"
	local poseMode = (state.savedAnims and state.decoyAnimator) and "local animations" or "FK pose"
	print("[Cupcake] R15 decoy ready (" .. tostring(#links) .. " joint links, " .. realKind .. " -> " .. decoyKind .. ", " .. poseMode .. ")")
	return true
end

local ORIG_ANIM_ATTR = "CupcakeOrigAnimationId"

local function restartAnimate(char, animate)
	local wasDisabled = false
	pcall(function() wasDisabled = animate.Disabled end)
	if wasDisabled then return false end
	pcall(function() animate.Disabled = true end)
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			local anim = track.Animation
			if anim and anim:IsDescendantOf(animate) then
				pcall(function() track:Stop(0) end)
			end
		end
	end
	task.wait()
	pcall(function() animate.Disabled = false end)
	return true
end

local function restoreOriginalAnimations(char)
	if not char then return end
	local animate = char:FindFirstChild("Animate")
	if not animate then return end
	local restored = 0
	for _, obj in pairs(animate:GetDescendants()) do
		if obj:IsA("Animation") then
			local orig = obj:GetAttribute(ORIG_ANIM_ATTR)
			if orig ~= nil then
				if obj.AnimationId ~= orig then
					pcall(function() obj.AnimationId = orig end)
				end
				pcall(function() obj:SetAttribute(ORIG_ANIM_ATTR, nil) end)
				restored = restored + 1
			end
		end
	end
	if restored > 0 then
		restartAnimate(char, animate)
	end
end

local function cupAccessoryHasWeld(accessory)
	local handle = accessory and accessory:FindFirstChild("Handle")
	if not handle then return false end
	for _, child in pairs(handle:GetChildren()) do
		if (child:IsA("Weld") or child:IsA("WeldConstraint") or child:IsA("Motor6D"))
			and child.Part0 and child.Part1 then
			return true
		end
	end
	return false
end

local function LoadAvatarFromData(data)
	if not data then return end
	stopR6FaceGuard()
	cupBumpSizeEpoch()

	local sourceIsR6 = tostring(data.rigType or ""):find("R6") ~= nil
	if sourceIsR6 and data.description then
		data.description.accessories = {}
	elseif data.description and data.description.accessories then
		local seenAssetIds = {}
		local deduped = {}
		for _, accInfo in ipairs(data.description.accessories) do
			if not (accInfo.AssetId and accInfo.AssetId ~= 0 and seenAssetIds[accInfo.AssetId]) then
				if accInfo.AssetId and accInfo.AssetId ~= 0 then seenAssetIds[accInfo.AssetId] = true end
				table.insert(deduped, accInfo)
			end
		end
		data.description.accessories = deduped
	end
	if data.accessoriesManual then
		local seenNames = {}
		local deduped = {}
		for _, adata in pairs(data.accessoriesManual) do
			if not seenNames[adata.Name] then
				seenNames[adata.Name] = true
				table.insert(deduped, adata)
			end
		end
		data.accessoriesManual = deduped
	end

	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local isR6 = (humanoid.RigType == Enum.HumanoidRigType.R6)
	local sameRig = sourceIsR6 == isR6
	local r6BodyNote = ""

	if follower then clearFollower() end
	recoverHiddenAvatar(char)

	if not isR6 then
		local called, result = pcall(applyFollower, char, humanoid, data)
		if called and result then
			return
		end

		if called and result == false and applyingFollower then return end
		warn("[Cupcake] R15 decoy failed: " .. tostring(result))
		if follower then pcall(clearFollower) end
		applyingFollower = false
		r15UsingFollower = false
		notify("Cupcake", "Could not build the R15 decoy - fit was not applied.", 5, true)
		return
	end

	if data.bodyColors then
		local bc = char:FindFirstChild("Body Colors") or Instance.new("BodyColors")
		bc.Name = "Body Colors"
		for prop, colorName in pairs(data.bodyColors) do
			if colorName then
				pcall(function() bc[prop] = BrickColor.new(colorName) end)
			end
		end
		bc.Parent = char
	end

	if data.scales then
		for scaleName, value in pairs(data.scales) do
			local scaleObj = humanoid:FindFirstChild(scaleName)
			if scaleObj and scaleObj:IsA("NumberValue") then
				scaleObj.Value = value
			end
		end
	end

	local layeredNames = {
		Shirt = true, Pants = true, Jacket = true, Sweater = true,
		Shorts = true, LeftShoe = true, RightShoe = true, DressSkirt = true
	}
	local descAppliedAssets = {}
	local descLayeredAccs = {}

	if not isR6 and data.description then
		pcall(function()
			local desc = humanoid:FindFirstChildOfClass("HumanoidDescription")
			if not desc then
				desc = Instance.new("HumanoidDescription")
				desc.Parent = humanoid
			end
			for _, prop in ipairs({"BodyTypeScale","BodyDepthScale","BodyHeightScale","BodyProportionScale","BodyWidthScale","HeadScale"}) do
				if data.description[prop] ~= nil then
					pcall(function() desc[prop] = data.description[prop] end)
				end
			end
			if data.bodyColors then
				pcall(function()
					if data.bodyColors.HeadColor then desc.HeadColor = BrickColor.new(data.bodyColors.HeadColor).Number end
					if data.bodyColors.TorsoColor then desc.TorsoColor = BrickColor.new(data.bodyColors.TorsoColor).Number end
					if data.bodyColors.LeftArmColor then desc.LeftArmColor = BrickColor.new(data.bodyColors.LeftArmColor).Number end
					if data.bodyColors.LeftLegColor then desc.LeftLegColor = BrickColor.new(data.bodyColors.LeftLegColor).Number end
					if data.bodyColors.RightArmColor then desc.RightArmColor = BrickColor.new(data.bodyColors.RightArmColor).Number end
					if data.bodyColors.RightLegColor then desc.RightLegColor = BrickColor.new(data.bodyColors.RightLegColor).Number end
				end)
			end

			local root = char:FindFirstChild("HumanoidRootPart")
			local oldHipHeight = humanoid.HipHeight
			local oldCFrame = root and root.CFrame
			local beforeAppliedAccs = {}

			local ok = pcall(function() humanoid:ApplyDescriptionSync(desc) end)
			if not ok then
				pcall(function() humanoid:ApplyDescription(desc) end)
			end

			task.wait()

			if root and oldCFrame then
				local heightDiff = humanoid.HipHeight - oldHipHeight
				if math.abs(heightDiff) > 0.01 then
					root.CFrame = oldCFrame + Vector3.new(0, heightDiff, 0)
				end
			end
			pcall(function()
				if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
					humanoid:ChangeState(Enum.HumanoidStateType.Landed)
				end
			end)
		end)
	end

	local convertedR6Accessories = nil
	local convertedR6Slots = {}
	if isR6 and data.description then
		pcall(function()
			local applied, accs = cupR6ApplyBodyFromDescription(char, humanoid, data)
			if applied then
				r6BodyNote = "bodymodel"
			end
			if not sourceIsR6 and accs then
				convertedR6Accessories = accs
			end
		end)
	end

	if isR6 then
		applyBodyColors(char, data)
	end

	if data.parts and sameRig then
		for partName, pdata in pairs(data.parts) do
			local existing = char:FindFirstChild(partName)
			if existing and existing:IsA("BasePart") then
				if pdata.Size and partName ~= "HumanoidRootPart" then
					cupHoldSize(existing, vec3(pdata.Size), 1)
				end
				if existing:IsA("MeshPart") then
					if pdata._class == "Part" then
						pcall(function() existing.MeshId = "" end)
						pcall(function() existing.TextureID = "" end)
					else
						if pdata.MeshId and pdata.MeshId ~= "" then pcall(function() existing.MeshId = pdata.MeshId end) end
						if pdata.TextureID and pdata.TextureID ~= "" then pcall(function() existing.TextureID = pdata.TextureID end) end
					end
				end
				if pdata.Color then pcall(function() existing.Color = deserializeColor(pdata.Color) end) end
				if pdata.Material then pcall(function() local m = cupEnum(Enum.Material, pdata.Material); if m then existing.Material = m end end) end
				if pdata.Transparency ~= nil then existing.Transparency = pdata.Transparency end
				if pdata.Reflectance ~= nil then existing.Reflectance = pdata.Reflectance end
				if pdata.CastShadow ~= nil then existing.CastShadow = pdata.CastShadow end

				if pdata.children then
					if partName == "Head" then
						for _, child in pairs(existing:GetChildren()) do
							if child:IsA("Decal") or child:IsA("Texture") then
								if not cupIsFaceObject(child) then child:Destroy() end
							elseif child:IsA("DataModelMesh") then child:Destroy()
							elseif child:IsA("SurfaceAppearance") then child:Destroy() end
						end
					else
						for _, child in pairs(existing:GetChildren()) do
							if child:IsA("Decal") or child:IsA("Texture") or child:IsA("DataModelMesh") or child:IsA("SurfaceAppearance") then
								child:Destroy()
							end
						end
					end
					for _, cdata in pairs(pdata.children) do
						if cdata._class == "SpecialMesh" or cdata._class == "BlockMesh" or cdata._class == "CylinderMesh" then buildMesh(existing, cdata)
						elseif cdata._class == "Decal" or cdata._class == "Texture" then
							if not (partName == "Head" and cupFaceLikeName(cdata.Name)) then buildDecal(existing, cdata) end
						elseif cdata._class == "Attachment" then
							local att = existing:FindFirstChild(cdata.Name)
							if att and att:IsA("Attachment") then
								if cdata.Position then att.Position = vec3(cdata.Position) end
								if cdata.Orientation then att.Orientation = vec3(cdata.Orientation) end
							else buildAttachment(existing, cdata) end
						elseif (cdata._class == "Motor6D" or cdata._class == "Weld") and cdata.C0 and cdata.C1 then
							local joint = existing:FindFirstChild(cdata.Name)
							if joint and (joint:IsA("Motor6D") or joint:IsA("Weld")) then
								pcall(function()
									joint.C0 = CFrame.new(unpack(cdata.C0))
									joint.C1 = CFrame.new(unpack(cdata.C1))
								end)
							end
						elseif cdata._class == "SurfaceAppearance" then buildSurfaceAppearance(existing, cdata)
						elseif cdata._class == "WrapTarget" then buildWrapTarget(existing, cdata) end
					end
				end
			end
		end
	end

	if isR6 and sameRig then
		cupR6ApplyCharacterMeshes(char, data.characterMeshes)
		if type(data.characterMeshes) == "table" and next(data.characterMeshes) ~= nil then
			r6BodyNote = r6BodyNote .. (r6BodyNote ~= "" and "+" or "") .. "savedMeshes(" .. #data.characterMeshes .. ")"
		end
	end

	local appliedHead = char:FindFirstChild("Head")
	if appliedHead then
		cupApplyFace(appliedHead, data, true)
	end

	for _, obj in pairs(char:GetDescendants()) do
		if obj:IsA("Accessory") then
			local preserve = false and descLayeredAccs[obj]
			if not preserve then obj:Destroy() end
		end
	end
	task.wait(0.1)

	local loadedCount = 0
	local failedCount = 0
	local blockedCount = 0
	local loadedMeshes = {}
	local loadedNames = {}

	if isR6 and convertedR6Accessories and #convertedR6Accessories > 0 then
		for _, info in ipairs(convertedR6Accessories) do
			local acc = info.accessory
			if acc and not acc.Parent and not isLayeredClothing(acc) then
				local slotKey = tostring(acc.AccessoryType)
				convertedR6Slots[slotKey] = (convertedR6Slots[slotKey] or 0) + 1
				local handle = acc:FindFirstChild("Handle")
				if handle then
					if handle:IsA("MeshPart") and handle.MeshId ~= "" then
						loadedMeshes[handle.MeshId] = true
					end
					for _, child in pairs(handle:GetChildren()) do
						if child:IsA("SpecialMesh") and child.MeshId ~= "" then
							loadedMeshes[child.MeshId] = true
						end
					end
				end
				loadedNames[acc.Name] = true
				local welded = false
				local target = info.partName and char:FindFirstChild(info.partName)
				if handle and target and target:IsA("BasePart") and info.c0 and info.c1 then
					acc.Parent = char
					handle.Anchored = false
					handle.CanCollide = false
					handle.CanTouch = false
					handle.CanQuery = false
					handle.Massless = true
					cupR6RemoveWelds(handle)
					local weld = Instance.new("Weld")
					weld.Name = "AccessoryWeld"
					if info.reversed then
						weld.Part0 = handle
						weld.Part1 = target
					else
						weld.Part0 = target
						weld.Part1 = handle
					end
					weld.C0 = info.c0
					weld.C1 = info.c1
					weld.Parent = handle
					welded = true
				end
				if not welded and cupR6WeldAccessory(char, acc) then welded = true end
				if not welded then
					acc.Parent = char
					weldAccessory(char, acc)
				end
				loadedCount = loadedCount + 1
				task.wait(0.03)
			end
		end
	end

	if not isR6 and data.description and data.description.accessories then
		for _, accInfo in ipairs(data.description.accessories) do
			local assetId = accInfo.AssetId
			if assetId and assetId ~= 0 then
				if descAppliedAssets and descAppliedAssets[assetId] then
					continue
				end
				if not false and (accInfo.IsLayered or (accInfo.AccessoryType and layeredNames[accInfo.AccessoryType])) then
					continue
				end
				local accessory = loadAccessoryById(assetId)
				if accessory then
					if accInfo.AccessoryType then
						pcall(function() local t = cupEnum(Enum.AccessoryType, accInfo.AccessoryType); if t then accessory.AccessoryType = t end end)
					end
					local h = accessory:FindFirstChild("Handle")
					if h and h:IsA("MeshPart") then loadedMeshes[h.MeshId] = true end
					loadedNames[accessory.Name] = true
					if not (not isR6 and pcall(function() humanoid:AddAccessory(accessory) end)) then
						accessory.Parent = char
					end
					local isAccLayered = isLayeredClothing(accessory)
					if not isAccLayered then
						if isR6 then
							if not cupR6WeldAccessory(char, accessory) then
								weldAccessory(char, accessory)
							end
						else
							weldAccessory(char, accessory)
						end
					end
					loadedCount = loadedCount + 1
					task.wait(0.05)
				else failedCount = failedCount + 1 end
			end
		end
	end

	if data.accessoriesManual and (isR6 or loadedCount == 0 or failedCount > 0) then
		for _, adata in pairs(data.accessoriesManual) do
			local isLayered = false
			for _, cdata in pairs(adata.children or {}) do
				if cdata._class == "WrapLayer" then
					isLayered = true
					break
				end
			end
			if isLayered then
				continue
			end

			local slotKey = adata.accessoryType or "Enum.AccessoryType.Unknown"
			if convertedR6Slots[slotKey] and convertedR6Slots[slotKey] > 0 then
				convertedR6Slots[slotKey] = convertedR6Slots[slotKey] - 1
				continue
			end
			if loadedNames[adata.Name] then
				continue
			end
			if adata.handle and adata.handle.MeshId and adata.handle.MeshId ~= "" and loadedMeshes[adata.handle.MeshId] then
				continue
			end

			local acc = Instance.new("Accessory")
			acc.Name = adata.Name or "Accessory"
			if adata.accessoryType then pcall(function() local t = cupEnum(Enum.AccessoryType, adata.accessoryType); if t then acc.AccessoryType = t end end) end
			local engineScale = isR6 and not sourceIsR6
			if adata.handle then
				local handle
				if adata.handle.MeshId and adata.handle.MeshId ~= "" then
					handle = Instance.new("MeshPart")
					pcall(function() handle.MeshId = adata.handle.MeshId end)
					if adata.handle.TextureID then pcall(function() handle.TextureID = adata.handle.TextureID end) end
				else
					handle = Instance.new("Part")
					if adata.handle.Shape then pcall(function() local s = cupEnum(Enum.PartType, adata.handle.Shape); if s then handle.Shape = s end end) end
				end
				handle.Name = "Handle"
				local savedHandleSize = adata.handle.Size and vec3(adata.handle.Size) or Vector3.new(1,1,1)
				if engineScale then
					pcall(function() handle.Size = savedHandleSize end)
				else
					cupHoldSize(handle, savedHandleSize, 1)
				end
				handle.CanCollide = false
				handle.CanTouch = false
				handle.Massless = true
				handle.Parent = acc
				if adata.handle.Color then pcall(function() handle.Color = deserializeColor(adata.handle.Color) end) end
				if adata.handle.Transparency ~= nil then handle.Transparency = adata.handle.Transparency end
				for _, cdata in pairs(adata.children or {}) do
					if cdata._class == "SpecialMesh" or cdata._class == "BlockMesh" or cdata._class == "CylinderMesh" then buildMesh(handle, cdata)
					elseif cdata._class == "Decal" or cdata._class == "Texture" then buildDecal(handle, cdata)
					elseif cdata._class == "Attachment" then buildAttachment(handle, cdata)
					elseif cdata._class == "WrapLayer" then buildWrapLayer(handle, cdata)
					elseif cdata._class == "Weld" or cdata._class == "Motor6D" then buildWeld(handle, cdata)
					elseif cdata._class == "SurfaceAppearance" then buildSurfaceAppearance(handle, cdata) end
				end
			end
			local engineAdded = false
			if engineScale then
				local ok = pcall(function() humanoid:AddAccessory(acc) end)
				engineAdded = ok and acc.Parent == char and cupAccessoryHasWeld(acc)
			end
			if not engineAdded then
				if not (not isR6 and pcall(function() humanoid:AddAccessory(acc) end)) then
					acc.Parent = char
				end
				if not isLayered then
					if isR6 then
						if not cupR6WeldAccessory(char, acc) then
							weldAccessory(char, acc)
						end
					else
						weldAccessory(char, acc)
					end
				end
			end
			loadedCount = loadedCount + 1
			task.wait(0.03)
		end
	end

	for _, obj in pairs(char:GetChildren()) do
		if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then obj:Destroy() end
	end
	if data.clothing then
		if data.clothing.shirt then
			local s = Instance.new("Shirt")
			s.ShirtTemplate = data.clothing.shirt
			s.Parent = char
		end
		if data.clothing.pants then
			local p = Instance.new("Pants")
			p.PantsTemplate = data.clothing.pants
			p.Parent = char
		end
		if data.clothing.tshirt then
			local t = Instance.new("ShirtGraphic")
			t.Graphic = data.clothing.tshirt
			t.Parent = char
		end
	end

	if data.walkSpeed then humanoid.WalkSpeed = data.walkSpeed end
	if data.jumpPower then humanoid.JumpPower = data.jumpPower end
	if isR6 then
		startR6FaceGuard(char, data)
	end
end

local function SaveAvatarWithName(name, targetChar, quiet)
	local data = CaptureAvatarData(targetChar)
	if not data then return false end
	data.savedName = name
	data.savedTime = formatTime()
	savedAvatars[name] = data
	if hasFS() then saveFile(SAVES_PATH, savedAvatars) end
	return true
end

local function DeleteAvatar(name)
	savedAvatars[name] = nil
	if hasFS() then saveFile(SAVES_PATH, savedAvatars) end
end

local function cupShowFollowerForCapture(f)
	if not f or not f.firstPersonHidden then return false end
	f.firstPersonHidden = false
	for p, t in pairs(f.visibleParts) do
		if p.Parent then
			pcall(function()
				p.Transparency = t
				p.LocalTransparencyModifier = 0
			end)
		end
	end
	for d, t in pairs(f.visibleDecals) do
		if d.Parent then
			pcall(function() d.Transparency = t end)
		end
	end
	return true
end

local function cupRestoreFollowerAfterCapture(f, hidden)
	if not hidden or not f then return end
	f.firstPersonHidden = true
	for p in pairs(f.visibleParts) do
		if p.Parent then
			pcall(function()
				p.Transparency = 1
				p.LocalTransparencyModifier = 1
			end)
		end
	end
	for d in pairs(f.visibleDecals) do
		if d.Parent then
			pcall(function() d.Transparency = 1 end)
		end
	end
end

local function CaptureLoadedAvatarData()
	local f = follower
	if r15UsingFollower and f and f.model and f.model.Parent then
		local hidden = cupShowFollowerForCapture(f)
		local data = CaptureAvatarData(f.model)
		cupRestoreFollowerAfterCapture(f, hidden)
		return data
	end
	return CaptureAvatarData(player.Character)
end

local function UpdateAvatar(name)
	local existing = savedAvatars[name]
	if not existing then return false end
	local data = CaptureLoadedAvatarData()
	if not data then return false end
	if (not data.animations or next(data.animations) == nil) and existing.animations then
		data.animations = existing.animations
	end
	data.savedName = name
	data.savedTime = formatTime()
	savedAvatars[name] = data
	if lastAppliedAvatarData == existing then
		lastAppliedAvatarData = data
	end
	if hasFS() then saveFile(SAVES_PATH, savedAvatars) end
	return true
end

local function LoadAvatarByName(name)
	local data = savedAvatars[name]
	if not data and hasFS() then
		savedAvatars = loadFile(SAVES_PATH) or {}
		data = savedAvatars[name]
	end
	if data then
		lastAppliedAvatarData = data
		LoadAvatarFromData(data)
		if hasFS() then saveFile(SAVES_PATH, savedAvatars) end
	end
end

local function corner(radius, parent)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(color, thickness, parent, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function tween(obj, props, time, style, dir)
	TweenService:Create(obj, TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props):Play()
end

local function frost(parent, radius)
	corner(radius or 16, parent)

	local grad = Instance.new("UIGradient")
	grad.Name = "GlassGrad"
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(226, 229, 234)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(192, 197, 205)),
	})
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.65),
		NumberSequenceKeypoint.new(0.4, 0.75),
		NumberSequenceKeypoint.new(1, 0.85),
	})
	grad.Rotation = 15
	grad.Parent = parent

	return nil
end

local animatedGradients = {}

local function animateGradient(parent, colors, transparency, speed, phase)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(colors)
	if transparency then
		grad.Transparency = NumberSequence.new(transparency)
	end
	grad.Parent = parent
	table.insert(animatedGradients, {
		grad = grad,
		speed = speed or 1.2,
		phase = phase or 0,
	})
	return grad
end

local function gradientLine(parent, size, position, zIndex, speed, phase)
	local line = Instance.new("Frame")
	line.Name = "GradientLine"
	line.Size = size
	line.Position = position
	line.BackgroundColor3 = M3.Accent
	line.BackgroundTransparency = 0
	line.BorderSizePixel = 0
	line.ZIndex = zIndex or 4
	line.Parent = parent
	corner(1, line)
	animateGradient(
		line,
		{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 124, 132)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 124, 132)),
		},
		{
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 0.05),
			NumberSequenceKeypoint.new(0.55, 0.05),
			NumberSequenceKeypoint.new(1, 1),
		},
		speed or 1.4,
		phase or 0
	)
	return line
end

local function setWorldBlur(enabled)
	if settings.blur == false then enabled = false end
	local blur = Lighting:FindFirstChild("CupcakeBlur")
	if enabled then
		if not blur then
			blur = Instance.new("BlurEffect")
			blur.Name = "CupcakeBlur"
			blur.Size = 0
			blur.Parent = Lighting
		end
		tween(blur, {Size = 24}, 0.35)
	else
		if blur then
			tween(blur, {Size = 0}, 0.25)
			task.delay(0.3, function()
				pcall(function() blur:Destroy() end)
			end)
		end
	end
end

local DEFAULT_FOV = 70
local MENU_FOV = 55
local originalFov = DEFAULT_FOV

local function setFov(target)
	if not settings.fovChange then return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	originalFov = cam.FieldOfView
	tween(cam, {FieldOfView = target}, 0.35, Enum.EasingStyle.Quart)
end

local function restoreFov()
	local cam = workspace.CurrentCamera
	if not cam then return end
	tween(cam, {FieldOfView = originalFov}, 0.35, Enum.EasingStyle.Quart)
end

local function menuTintTransparency()
	return settings.tint and 0.45 or 1
end

local function makeToggleSwitch(parent, initialValue, onChanged)
	local track = Instance.new("Frame")
	track.Name = "ToggleTrack"
	track.Size = UDim2.new(0, 42, 0, 24)
	track.BackgroundColor3 = initialValue and M3.Primary or M3.SurfaceHighest
	track.BorderSizePixel = 0
	track.ZIndex = 103
	track.Parent = parent
	corner(12, track)
	stroke(M3.GlassLine, 1, track, 0.85)

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.Position = initialValue and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
	knob.BackgroundColor3 = initialValue and M3.OnPrimary or M3.OnSurfaceVariant
	knob.BorderSizePixel = 0
	knob.ZIndex = 104
	knob.Parent = track
	corner(9, knob)

	local btn = Instance.new("TextButton")
	btn.Name = "ToggleBtn"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 12
	btn.ZIndex = 105
	btn.Parent = track

	local value = initialValue
	btn.MouseButton1Click:Connect(function()
		value = not value
		tween(track, {BackgroundColor3 = value and M3.Primary or M3.SurfaceHighest}, 0.18)
		tween(knob, {
			Position = value and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
			BackgroundColor3 = value and M3.OnPrimary or M3.OnSurfaceVariant,
		}, 0.18, Enum.EasingStyle.Quart)
		if onChanged then onChanged(value) end
	end)

	return track
end

local function updateCircle()
	if not circleGuiRef then return end
	circleGuiRef.Enabled = (not isGuiOpen) and (settings.device == "Mobile")
end

local mouseUnlockBound = false
local function enforceMouseUnlock()
	if mouseUnlockBound then return end
	mouseUnlockBound = true
	pcall(function()
		RunService:BindToRenderStep("CupcakeMouseUnlock", Enum.RenderPriority.Last.Value, function()
			if isGuiOpen then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
		end)
	end)
end
local function releaseMouseUnlock()
	if not mouseUnlockBound then return end
	mouseUnlockBound = false
	pcall(function() RunService:UnbindFromRenderStep("CupcakeMouseUnlock") end)
end
local function unlockMouse()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	enforceMouseUnlock()
end
local function lockMouseBack()
	releaseMouseUnlock()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

local hiddenUis = {}
local coreGuiOriginals = nil

local function coreGuiTypes()
	local types = {}
	for _, t in ipairs(Enum.CoreGuiType:GetEnumItems()) do
		if t ~= Enum.CoreGuiType.All then
			table.insert(types, t)
		end
	end
	return types
end

local function applyCoreGuiStates(states)
	if type(states) ~= "table" or not next(states) then return end
	for _, t in ipairs(coreGuiTypes()) do
		local v = states[t.Name]
		if type(v) == "boolean" then
			pcall(function() StarterGui:SetCoreGuiEnabled(t, v) end)
		end
	end
	pcall(function()
		local tcs = game:GetService("TextChatService")
		if tcs.ChatWindowConfiguration and type(states.ChatWindow) == "boolean" then
			tcs.ChatWindowConfiguration.Enabled = states.ChatWindow
		end
		if tcs.ChatInputBarConfiguration and type(states.ChatInputBar) == "boolean" then
			tcs.ChatInputBarConfiguration.Enabled = states.ChatInputBar
		end
	end)
end

local function hideCoreGuis()
	if coreGuiOriginals then return end
	local states = {}
	for _, t in ipairs(coreGuiTypes()) do
		local ok, enabled = pcall(function() return StarterGui:GetCoreGuiEnabled(t) end)
		if ok and type(enabled) == "boolean" then
			states[t.Name] = enabled
			pcall(function() StarterGui:SetCoreGuiEnabled(t, false) end)
		end
	end
	pcall(function()
		local tcs = game:GetService("TextChatService")
		if tcs.ChatWindowConfiguration then
			states.ChatWindow = tcs.ChatWindowConfiguration.Enabled
			tcs.ChatWindowConfiguration.Enabled = false
		end
		if tcs.ChatInputBarConfiguration then
			states.ChatInputBar = tcs.ChatInputBarConfiguration.Enabled
			tcs.ChatInputBarConfiguration.Enabled = false
		end
	end)
	pcall(function() StarterGui:SetCore("TopbarEnabled", false) end)
	coreGuiOriginals = states
	saveFile(COREUI_PATH, states)
end

local function restoreCoreGuis()
	local states = coreGuiOriginals
	if type(states) ~= "table" then
		local saved = loadFile(COREUI_PATH)
		if type(saved) == "table" and next(saved) then
			states = saved
		end
	end
	if type(states) == "table" then
		applyCoreGuiStates(states)
		pcall(function() StarterGui:SetCore("TopbarEnabled", true) end)
	end
	coreGuiOriginals = nil
	if hasFS() then saveFile(COREUI_PATH, {}) end
end

local function hideOtherUis()
	if not settings.hideUis then return end
	local pg = player:FindFirstChild("PlayerGui")
	if pg then
		for _, gui in pairs(pg:GetChildren()) do
			if gui:IsA("ScreenGui") and gui.Enabled and not gui:GetAttribute("CupcakeOwned") then
				hiddenUis[gui] = true
				pcall(function() gui:SetAttribute(HIDDEN_UI_ATTR, true) end)
				pcall(function() gui.Enabled = false end)
			end
		end
	end
	hideCoreGuis()
end
local function restoreHiddenUis()
	for gui in pairs(hiddenUis) do
		pcall(function() gui.Enabled = true end)
		pcall(function() gui:SetAttribute(HIDDEN_UI_ATTR, nil) end)
	end
	table.clear(hiddenUis)
	restoreCoreGuis()
end
local function recoverHiddenUis()
	local pg = player:FindFirstChild("PlayerGui")
	if pg then
		for _, gui in pairs(pg:GetChildren()) do
			if gui:IsA("ScreenGui") and gui:GetAttribute(HIDDEN_UI_ATTR) and not gui:GetAttribute("CupcakeOwned") then
				pcall(function() gui.Enabled = true end)
				pcall(function() gui:SetAttribute(HIDDEN_UI_ATTR, nil) end)
			end
		end
	end
	local saved = loadFile(COREUI_PATH)
	if saved and next(saved) then
		applyCoreGuiStates(saved)
		pcall(function() StarterGui:SetCore("TopbarEnabled", true) end)
		if hasFS() then saveFile(COREUI_PATH, {}) end
	end
end

local supersededConn
supersededConn = RunService.Heartbeat:Connect(function()
	if myRunId == _G.CupcakeRunId then return end
	if supersededConn then supersededConn:Disconnect() end

	local pg = player:FindFirstChild("PlayerGui")
	local activeGui = pg and pg:FindFirstChild("CupcakeGui")
	if activeGui and activeGui ~= currentGui then
		if currentGui then
			pcall(function() currentGui:Destroy() end)
			currentGui = nil
		end
		return
	end

	pcall(restoreHiddenUis)
	pcall(releaseMouseUnlock)
	if stopSnow then pcall(stopSnow) end
	if _G.CupcakeUiAnimConnection then
		pcall(function() _G.CupcakeUiAnimConnection:Disconnect() end)
		_G.CupcakeUiAnimConnection = nil
	end
	pcall(function() setWorldBlur(false) end)
	pcall(function() setFov(DEFAULT_FOV) end)
	if currentGui then
		pcall(function() currentGui:Destroy() end)
		currentGui = nil
	end
end)

local function toggleGui(force)
	if myRunId ~= _G.CupcakeRunId then return end
	if not currentGui then return end
	local loading = currentGui:FindFirstChild("LoadingScreen")
	if loading and loading.Visible and not force then return end
	local mf = currentGui:FindFirstChild("MainWindow")
	if not mf then return end
	if mf.Visible then
		isGuiOpen = false
		lockMouseBack()
		if stopSnow then stopSnow() end
		restoreHiddenUis()
		local apClose = mf:FindFirstChild("AutoloadPopup")
		if apClose then apClose.Visible = false end
		local apBgClose = mf:FindFirstChild("AutoloadBg")
		if apBgClose then apBgClose.Visible = false end
		local bdClose = currentGui:FindFirstChild("Backdrop")
		if bdClose then
			tween(bdClose, {BackgroundTransparency = 1}, 0.15)
			task.delay(0.16, function()
				if not isGuiOpen then bdClose.Visible = false end
			end)
		end
		setWorldBlur(false)
		setFov(DEFAULT_FOV)
		local target = mf.Position
		tween(mf, {Position = target + UDim2.new(0, 0, 0, 14)}, 0.18, Enum.EasingStyle.Quart)
		task.delay(0.19, function()
			if not isGuiOpen then
				mf.Visible = false
				mf.Position = target
			end
		end)
		updateCircle()
	else
		isGuiOpen = true
		mf.Visible = true
		unlockMouse()
		if startSnow and settings.snow then startSnow() end
		hideOtherUis()
		local bdOpen = currentGui:FindFirstChild("Backdrop")
		if bdOpen then
			bdOpen.Visible = true
			tween(bdOpen, {BackgroundTransparency = menuTintTransparency()}, 0.2)
		end
		setWorldBlur(true)
		setFov(MENU_FOV)
		local target = mf.Position
		mf.Position = target + UDim2.new(0, 0, 0, 14)
		tween(mf, {Position = target}, 0.22, Enum.EasingStyle.Quart)
		updateCircle()
	end
end

local function paintChip(chip, colors)
	for _, child in pairs(chip:GetChildren()) do
		if child.Name == "Fill" then child:Destroy() end
	end
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BorderSizePixel = 0
	fill.ZIndex = 4
	fill.ClipsDescendants = true
	corner(8, fill)
	fill.Parent = chip
	if #colors == 0 then
		fill.BackgroundColor3 = M3.SurfaceHighest
	elseif #colors == 1 then
		fill.BackgroundColor3 = colors[1]
	else
		fill.BackgroundColor3 = colors[1]
		local n = #colors
		local kps = {}
		for i, c in ipairs(colors) do
			table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (n - 1), c))
		end
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(kps)
		g.Rotation = 45
		g.Parent = fill
	end
end

local originalAvatarData = nil
local resettingAvatar = false

local rebindCallback = nil
local KEY_DISPLAY = {
	Zero = "0", One = "1", Two = "2", Three = "3", Four = "4",
	Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9",
	KeypadZero = "Num 0", KeypadOne = "Num 1", KeypadTwo = "Num 2", KeypadThree = "Num 3",
	KeypadFour = "Num 4", KeypadFive = "Num 5", KeypadSix = "Num 6", KeypadSeven = "Num 7",
	KeypadEight = "Num 8", KeypadNine = "Num 9",
	LeftBracket = "[", RightBracket = "]", BackSlash = "\\", Semicolon = ";",
	Quote = "'", Comma = ",", Period = ".", Slash = "/", Minus = "-", Equals = "=",
	Backquote = "`", Return = "Enter",
}
local function keyDisplayName(name)
	return KEY_DISPLAY[name] or tostring(name)
end

local function resetToOriginal()
	if resettingAvatar or not originalAvatarData then return end
	resettingAvatar = true
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.RigType == Enum.HumanoidRigType.R15 and r15UsingFollower then
		lastAppliedAvatarData = nil
		clearFollower()
		pcall(restoreOriginalAnimations, char)
	else
		lastAppliedAvatarData = originalAvatarData
		pcall(LoadAvatarFromData, originalAvatarData)
	end
	resettingAvatar = false
end

local function unloadScript()
	if scriptUnloaded then return end
	scriptUnloaded = true
	myRunId = nil
	isGuiOpen = false
	pcall(stopR6FaceGuard)

	if supersededConn then
		pcall(function() supersededConn:Disconnect() end)
		supersededConn = nil
	end
	if toggleConn then
		pcall(function() toggleConn:Disconnect() end)
		toggleConn = nil
	end
	if respawnConn then
		pcall(function() respawnConn:Disconnect() end)
		respawnConn = nil
	end
	if guiCharacterConn then
		pcall(function() guiCharacterConn:Disconnect() end)
		guiCharacterConn = nil
	end
	if cameraViewportConn then
		pcall(function() cameraViewportConn:Disconnect() end)
		cameraViewportConn = nil
	end
	if cameraChangedConn then
		pcall(function() cameraChangedConn:Disconnect() end)
		cameraChangedConn = nil
	end
	if _G.CupcakeUiAnimConnection then
		pcall(function() _G.CupcakeUiAnimConnection:Disconnect() end)
		_G.CupcakeUiAnimConnection = nil
	end
	if stopSnow then pcall(stopSnow) end
	if _G.CupcakeSnowConnection then
		pcall(function() _G.CupcakeSnowConnection:Disconnect() end)
		_G.CupcakeSnowConnection = nil
	end

	local char = player.Character
	if char then
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if follower then pcall(clearFollower) end
		pcall(recoverHiddenAvatar, char)
		if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 and lastAppliedAvatarData and originalAvatarData then
			pcall(LoadAvatarFromData, originalAvatarData)
		end
		pcall(restoreOriginalAnimations, char)
	end

	pcall(releaseMouseUnlock)
	pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
	pcall(restoreHiddenUis)
	pcall(function() setWorldBlur(false) end)
	pcall(function() setFov(DEFAULT_FOV) end)

	if currentGui then
		pcall(function() currentGui:Destroy() end)
		currentGui = nil
	end
	if circleGuiRef then
		pcall(function() circleGuiRef:Destroy() end)
		circleGuiRef = nil
	end

	local pg = player:FindFirstChild("PlayerGui")
	if pg then
		for _, gui in ipairs(pg:GetChildren()) do
			if gui.Name == "CupcakeGui" or gui.Name == "CupcakeCircleGui" then
				pcall(function() gui:Destroy() end)
			end
		end
	end
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "CupcakeFollower" then
			pcall(function() obj:Destroy() end)
		end
	end
	_G.CupcakeUnloaded = true
end

local function makeGui()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return nil end

	if _G.CupcakeUiAnimConnection then
		pcall(function() _G.CupcakeUiAnimConnection:Disconnect() end)
		_G.CupcakeUiAnimConnection = nil
	end
	table.clear(animatedGradients)

	if _G.CupcakeSnowConnection then
		pcall(function() _G.CupcakeSnowConnection:Disconnect() end)
		_G.CupcakeSnowConnection = nil
	end

	local oldGui = pg:FindFirstChild("CupcakeGui")

	local refreshGrid, showToast, openModal, closeModal, openOptionsMenu
	local resetDeleteConfirm
	local setModalTab, copyPlayerAvatar, populatePlayerList
	local selectTab

	local sg = Instance.new("ScreenGui")
	sg.Name = "CupcakeGui"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 100000
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg:SetAttribute("CupcakeOwned", true)

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(24, 26, 30)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 0
	backdrop.Visible = false
	backdrop.Parent = sg
	local backdropGrad = Instance.new("UIGradient")
	backdropGrad.Rotation = 90
	backdropGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 41, 47)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 20, 24)),
	})
	backdropGrad.Parent = backdrop

	local mf = Instance.new("Frame")
	mf.Name = "MainWindow"
	mf.AnchorPoint = Vector2.new(0.5, 0.5)
	mf.Size = UDim2.new(0, 520, 0, 400)
	mf.Position = UDim2.new(0.5, 0, 0.5, 0)
	mf.BackgroundColor3 = M3.Surface
	mf.BackgroundTransparency = 0
	mf.BorderSizePixel = 0
	mf.ZIndex = 2
	mf.Parent = sg
	corner(16, mf)
	stroke(M3.GlassLine, 1, mf, 0.88)

	local panelBg = Instance.new("Frame")
	panelBg.Name = "PanelBackground"
	panelBg.Size = UDim2.new(1, 0, 1, 0)
	panelBg.BackgroundColor3 = M3.Background
	panelBg.BackgroundTransparency = 0
	panelBg.BorderSizePixel = 0
	panelBg.ZIndex = 1
	panelBg.Parent = mf
	corner(16, panelBg)
	local panelBgGrad = Instance.new("UIGradient")
	panelBgGrad.Rotation = 135
	panelBgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(64, 68, 76)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(45, 48, 54)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(31, 33, 38)),
	})
	panelBgGrad.Parent = panelBg

	local clickSound = Instance.new("Sound")
	clickSound.SoundId = "rbxassetid://178104975"
	clickSound.Volume = 0.6
	clickSound.Parent = sg

	local function playClick()
		pcall(function()
			clickSound.PlaybackSpeed = 0.9 + math.random() * 0.25
			clickSound:Play()
		end)
	end

	local function hookClicks(g)
		for _, obj in pairs(g:GetDescendants()) do
			if obj:IsA("GuiButton") and obj.Name ~= "Blocker" then
				obj.MouseButton1Click:Connect(function()
					playClick()
				end)
			end
		end
	end

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale.Scale = getUiScale()
	uiScale.Parent = mf

	local function refreshScale()
		if scriptUnloaded or not uiScale.Parent then return end
		uiScale.Scale = getUiScale()
	end
	local function bindCamera()
		if scriptUnloaded then return end
		local cam = workspace.CurrentCamera
		if cameraViewportConn then
			pcall(function() cameraViewportConn:Disconnect() end)
			cameraViewportConn = nil
		end
		if cam then
			cameraViewportConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
		end
		refreshScale()
	end
	bindCamera()
	cameraChangedConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)

	local oldCircleGui = pg:FindFirstChild("CupcakeCircleGui")
	if oldCircleGui then oldCircleGui:Destroy() end

	local circleGui = Instance.new("ScreenGui")
	circleGui.Name = "CupcakeCircleGui"
	circleGui.ResetOnSpawn = false
	circleGui.IgnoreGuiInset = true
	circleGui.DisplayOrder = 99999
	circleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	circleGui:SetAttribute("CupcakeOwned", true)
	circleGui.Enabled = false
	circleGui.Parent = pg
	circleGuiRef = circleGui

	local circleBtn = Instance.new("TextButton")
	circleBtn.Name = "CircleToggleBtn"
	circleBtn.Size = UDim2.new(0, 42, 0, 42)
	local savedPos = settings.circleBtnPos or {X = 1, Y = 1, OffsetX = -54, OffsetY = -54}
	circleBtn.Position = UDim2.new(
		tonumber(savedPos.X) or 1,
		tonumber(savedPos.OffsetX) or -54,
		tonumber(savedPos.Y) or 1,
		tonumber(savedPos.OffsetY) or -54
	)
	circleBtn.BackgroundColor3 = M3.SurfaceHigh
	circleBtn.BackgroundTransparency = 0
	circleBtn.BorderSizePixel = 0
	circleBtn.Text = "C"
	circleBtn.TextColor3 = M3.OnSurface
	circleBtn.TextSize = 17
	circleBtn.Font = Enum.Font.GothamBold
	circleBtn.AutoButtonColor = false
	circleBtn.ZIndex = 10
	circleBtn.Parent = circleGui
	local circleCorner = Instance.new("UICorner")
	circleCorner.CornerRadius = UDim.new(1, 0)
	circleCorner.Parent = circleBtn
	local circleStroke = stroke(M3.GlassLine, 1, circleBtn, 0.82)

	local circleDragging = false
	local circleDragStart, circleBtnStartPos
	local circleDragDist = 0

	circleBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			circleDragging = true
			circleDragDist = 0
			circleDragStart = input.Position
			circleBtnStartPos = circleBtn.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if scriptUnloaded then return end
		if circleDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - circleDragStart
			circleDragDist = math.abs(delta.X) + math.abs(delta.Y)
			local vp = workspace.CurrentCamera.ViewportSize
			local newX = math.clamp(circleBtnStartPos.X.Offset + delta.X, 4, vp.X - 46)
			local newY = math.clamp(circleBtnStartPos.Y.Offset + delta.Y, 4, vp.Y - 46)
			circleBtn.Position = UDim2.new(0, newX, 0, newY)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if scriptUnloaded then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if circleDragging then
				circleDragging = false
				settings.circleBtnPos = {
					X = 0, Y = 0,
					OffsetX = circleBtn.Position.X.Offset,
					OffsetY = circleBtn.Position.Y.Offset,
				}
				saveSettings()
				if circleDragDist < 10 then
					toggleGui()
				end
			end
		end
	end)

	circleBtn.MouseEnter:Connect(function()
		if not circleDragging then
			tween(circleBtn, {Size = UDim2.new(0, 46, 0, 46)}, 0.12)
			tween(circleStroke, {Transparency = 0.55}, 0.12)
		end
	end)
	circleBtn.MouseLeave:Connect(function()
		tween(circleBtn, {Size = UDim2.new(0, 42, 0, 42)}, 0.12)
		tween(circleStroke, {Transparency = 0.85}, 0.12)
	end)

	local oldSnow = pg:FindFirstChild("CupcakeSnowGui")
	if oldSnow then oldSnow:Destroy() end

	local snowLayer = Instance.new("Frame")
	snowLayer.Name = "SnowLayer"
	snowLayer.Size = UDim2.new(1, 0, 1, 0)
	snowLayer.BackgroundTransparency = 1
	snowLayer.BorderSizePixel = 0
	snowLayer.ZIndex = 1
	snowLayer.Visible = false
	snowLayer.Parent = sg

	local flakes = {}
	local snowConn = nil

	for i = 1, 90 do
		local f = Instance.new("Frame")
		f.Name = "Snowflake"
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.new(0, 3, 0, 3)
		f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		f.BackgroundTransparency = 0.25
		f.BorderSizePixel = 0
		f.Active = false
		f.ZIndex = 1
		f.Parent = snowLayer
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = f
		flakes[i] = {
			frame = f,
			x = 0, y = 0,
			vx = 0, vy = 0,
			size = 3,
			drift = 0,
			driftSpeed = 1,
		}
	end

	local function resetFlake(fl, vp, spread)
		fl.size = math.random(2, 5)
		fl.frame.Size = UDim2.new(0, fl.size, 0, fl.size)
		fl.frame.BackgroundTransparency = 0.15 + math.random() * 0.35
		fl.x = math.random() * vp.X
		if spread then
			fl.y = math.random() * vp.Y - vp.Y * 0.15
		else
			fl.y = -math.random() * vp.Y * 0.35
		end
		fl.vx = (math.random() - 0.5) * 18
		fl.vy = math.random(35, 85)
		fl.drift = math.random() * math.pi * 2
		fl.driftSpeed = math.random(50, 120) / 100
		fl.frame.Position = UDim2.new(0, fl.x, 0, fl.y)
	end

	local function resetSnow()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local vp = cam.ViewportSize
		for _, fl in ipairs(flakes) do
			resetFlake(fl, vp, true)
		end
	end

	startSnow = function()
		if not settings.snow then return end
		snowLayer.Visible = true
		resetSnow()
		if snowConn then return end
		snowConn = RunService.RenderStepped:Connect(function(dt)
			if not isGuiOpen or not settings.snow then return end
			local cam = workspace.CurrentCamera
			if not cam then return end
			local vp = cam.ViewportSize
			for _, fl in ipairs(flakes) do
				fl.drift = fl.drift + fl.driftSpeed * dt
				fl.x = fl.x + (fl.vx + math.sin(fl.drift) * 14) * dt
				fl.y = fl.y + fl.vy * dt
				if fl.x < -10 then
					fl.x = vp.X + 10
				elseif fl.x > vp.X + 10 then
					fl.x = -10
				end
				if fl.y > vp.Y + 20 then
					resetFlake(fl, vp, false)
				end
				fl.frame.Position = UDim2.new(0, fl.x, 0, fl.y)
			end
		end)
		_G.CupcakeSnowConnection = snowConn
	end

	stopSnow = function()
		snowLayer.Visible = false
		if snowConn then
			snowConn:Disconnect()
			snowConn = nil
		end
		_G.CupcakeSnowConnection = nil
	end

	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 48)
	titleBar.BackgroundTransparency = 1
	titleBar.ZIndex = 3
	titleBar.Parent = mf

	gradientLine(titleBar, UDim2.new(1, -36, 0, 2), UDim2.new(0, 18, 0, 46), 4, 1.6, 0)

	local resetBtn = Instance.new("TextButton")
	resetBtn.Name = "ResetBtn"
	resetBtn.Size = UDim2.new(0, 28, 0, 28)
	resetBtn.Position = UDim2.new(0, 10, 0, 10)
	resetBtn.BackgroundColor3 = M3.SurfaceHighest
	resetBtn.BackgroundTransparency = 1
	resetBtn.BorderSizePixel = 0
	resetBtn.Text = ""
	resetBtn.AutoButtonColor = false
	resetBtn.ZIndex = 4
	resetBtn.Parent = titleBar
	corner(14, resetBtn)

	local resetIcon = Instance.new("Frame")
	resetIcon.Name = "ResetIcon"
	resetIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	resetIcon.Size = UDim2.new(0, 20, 0, 20)
	resetIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
	resetIcon.BackgroundTransparency = 1
	resetIcon.ZIndex = 5
	resetIcon.Parent = resetBtn

	local iconPieces = {}
	local function iconPiece(cx, cy, w, h, rot)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.new(0, w, 0, h)
		f.Position = UDim2.new(0, cx, 0, cy)
		f.Rotation = rot or 0
		f.BackgroundColor3 = M3.Accent
		f.BorderSizePixel = 0
		f.ZIndex = 5
		f.Parent = resetIcon
		corner(math.ceil(math.min(w, h) / 2), f)
		table.insert(iconPieces, f)
		return f
	end

	do
		local cx, cy, radius = 10, 10, 7

		local phi = -10
		while phi <= 280 do
			local r = math.rad(phi)
			iconPiece(cx + radius * math.cos(r), cy + radius * math.sin(r), 2.6, 2.6)
			phi = phi + 10
		end

		local endAngle = math.rad(280)
		local tipX = cx + radius * math.cos(endAngle) + 2.5 * math.cos(endAngle + math.pi / 2)
		local tipY = cy + radius * math.sin(endAngle) + 2.5 * math.sin(endAngle + math.pi / 2)
		local tangent = 280 + 90
		local armLen = 5.5
		for _, off in ipairs({140, -140}) do
			local a = math.rad(tangent + off)
			local mx = tipX + math.cos(a) * armLen / 2
			local my = tipY + math.sin(a) * armLen / 2
			iconPiece(mx, my, armLen, 2.2, tangent + off)
		end
	end

	local function tintIcon(color, time)
		for _, f in ipairs(iconPieces) do
			tween(f, {BackgroundColor3 = color}, time or 0.12)
		end
	end

	local resetHover = false
	resetBtn.MouseEnter:Connect(function()
		tween(resetBtn, {BackgroundTransparency = 0.25}, 0.12)
		tintIcon(M3.OnSurface)
		if resetHover then return end
		resetHover = true
		task.spawn(function()
			while resetHover and resetIcon.Parent do
				local dt = task.wait()
				resetIcon.Rotation = (resetIcon.Rotation + dt * 360) % 360
			end
		end)
	end)
	resetBtn.MouseLeave:Connect(function()
		resetHover = false
		tween(resetBtn, {BackgroundTransparency = 1}, 0.15)
		tintIcon(M3.Accent, 0.15)
		local rot = resetIcon.Rotation
		if rot > 180 then rot = rot - 360 end
		resetIcon.Rotation = rot
		tween(resetIcon, {Rotation = 0}, 0.25)
	end)
	resetBtn.MouseButton1Click:Connect(function()
		if resettingAvatar then return end
		tintIcon(M3.Success, 0.1)
		task.spawn(function()
			resetToOriginal()
			task.wait(0.2)
			tintIcon(resetHover and M3.OnSurface or M3.Accent, 0.3)
		end)
	end)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(0, 140, 1, 0)
	titleLabel.Position = UDim2.new(0, 44, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Cupcake"
	titleLabel.TextColor3 = M3.OnSurface
	titleLabel.TextSize = 16
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 4
	titleLabel.Parent = titleBar

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 28, 0, 28)
	closeBtn.Position = UDim2.new(1, -40, 0, 10)
	closeBtn.BackgroundColor3 = M3.SurfaceHighest
	closeBtn.BackgroundTransparency = 1
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "×"
	closeBtn.TextColor3 = M3.OnSurfaceVariant
	closeBtn.TextSize = 17
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.AutoButtonColor = false
	closeBtn.ZIndex = 4
	closeBtn.Parent = titleBar
	corner(14, closeBtn)
	closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, {BackgroundTransparency = 0.25, TextColor3 = M3.OnSurface}, 0.12)
	end)
	closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, {BackgroundTransparency = 1, TextColor3 = M3.OnSurfaceVariant}, 0.12)
	end)
	closeBtn.MouseButton1Click:Connect(function()
		toggleGui()
	end)

	local catalogBtn = Instance.new("TextButton")
	catalogBtn.Name = "CatalogBtn"
	catalogBtn.Size = UDim2.new(0, 28, 0, 28)
	catalogBtn.Position = UDim2.new(1, -76, 0, 10)
	catalogBtn.BackgroundColor3 = M3.SurfaceHighest
	catalogBtn.BackgroundTransparency = 1
	catalogBtn.BorderSizePixel = 0
	catalogBtn.Text = ""
	catalogBtn.AutoButtonColor = false
	catalogBtn.ZIndex = 4
	catalogBtn.Parent = titleBar
	corner(8, catalogBtn)

	local catalogIcon = Instance.new("ImageLabel")
	catalogIcon.Name = "CatalogIcon"
	catalogIcon.Size = UDim2.new(1, -6, 1, -6)
	catalogIcon.Position = UDim2.new(0, 3, 0, 3)
	catalogIcon.BackgroundTransparency = 1
	catalogIcon.Image = "rbxthumb://type=GameIcon&id=2711375305&w=150&h=150"
	catalogIcon.ZIndex = 5
	catalogIcon.Parent = catalogBtn
	corner(7, catalogIcon)

	local catalogSpinning = false
	catalogBtn.MouseEnter:Connect(function()
		tween(catalogBtn, {BackgroundTransparency = 0.25}, 0.12)
		if catalogSpinning then return end
		catalogSpinning = true
		task.spawn(function()
			while catalogSpinning and catalogIcon.Parent do
				catalogIcon.Rotation = (catalogIcon.Rotation + 6) % 360
				task.wait()
			end
		end)
	end)
	catalogBtn.MouseLeave:Connect(function()
		catalogSpinning = false
		tween(catalogBtn, {BackgroundTransparency = 1}, 0.15)
		tween(catalogIcon, {Rotation = 0}, 0.2)
	end)

	local joinBox = Instance.new("Frame")
	joinBox.Name = "JoinBox"
	joinBox.Size = UDim2.new(0, 280, 0, 176)
	joinBox.Position = UDim2.new(0.5, -140, 0.5, -88)
	joinBox.BackgroundColor3 = M3.Surface
	joinBox.BackgroundTransparency = 0.4
	joinBox.BorderSizePixel = 0
	joinBox.Visible = false
	joinBox.ZIndex = 300
	joinBox.Parent = mf
	corner(14, joinBox)
	stroke(M3.GlassLine, 1, joinBox, 0.86)
	frost(joinBox, 14)

	local joinIcon = Instance.new("ImageLabel")
	joinIcon.Name = "JoinIcon"
	joinIcon.Size = UDim2.new(0, 44, 0, 44)
	joinIcon.Position = UDim2.new(0, 16, 0, 14)
	joinIcon.BackgroundTransparency = 1
	joinIcon.Image = "rbxthumb://type=GameIcon&id=2711375305&w=150&h=150"
	joinIcon.ZIndex = 301
	joinIcon.Parent = joinBox
	corner(12, joinIcon)

	local joinTitle = Instance.new("TextLabel")
	joinTitle.Name = "JoinTitle"
	joinTitle.Size = UDim2.new(1, -88, 0, 24)
	joinTitle.Position = UDim2.new(0, 72, 0, 14)
	joinTitle.BackgroundTransparency = 1
	joinTitle.Text = "Visit Catalog Avatar?"
	joinTitle.TextColor3 = M3.OnSurface
	joinTitle.TextSize = 15
	joinTitle.Font = Enum.Font.GothamBold
	joinTitle.TextXAlignment = Enum.TextXAlignment.Center
	joinTitle.ZIndex = 301
	joinTitle.Parent = joinBox

	local joinSub = Instance.new("TextLabel")
	joinSub.Name = "JoinSub"
	joinSub.Size = UDim2.new(1, -88, 0, 34)
	joinSub.Position = UDim2.new(0, 72, 0, 40)
	joinSub.BackgroundTransparency = 1
	joinSub.Text = "We'll teleport you there. Your saves come with you."
	joinSub.TextWrapped = true
	joinSub.TextColor3 = M3.OnSurfaceVariant
	joinSub.TextSize = 12
	joinSub.Font = Enum.Font.Gotham
	joinSub.TextXAlignment = Enum.TextXAlignment.Center
	joinSub.ZIndex = 301
	joinSub.Parent = joinBox

	local joinYes = Instance.new("TextButton")
	joinYes.Name = "JoinYes"
	joinYes.Size = UDim2.new(0, 104, 0, 38)
	joinYes.Position = UDim2.new(0, 18, 1, -52)
	joinYes.BackgroundColor3 = M3.Primary
	joinYes.BorderSizePixel = 0
	joinYes.Text = "Let's go"
	joinYes.TextColor3 = M3.OnPrimary
	joinYes.TextSize = 13
	joinYes.Font = Enum.Font.GothamBold
	joinYes.AutoButtonColor = false
	joinYes.ZIndex = 301
	joinYes.Parent = joinBox
	corner(10, joinYes)
	stroke(M3.Primary, 1, joinYes, 0.6)

	local joinNo = Instance.new("TextButton")
	joinNo.Name = "JoinNo"
	joinNo.Size = UDim2.new(0, 104, 0, 38)
	joinNo.Position = UDim2.new(1, -122, 1, -52)
	joinNo.BackgroundColor3 = M3.SurfaceHigh
	joinNo.BorderSizePixel = 0
	joinNo.Text = "Stay"
	joinNo.TextColor3 = M3.OnSurface
	joinNo.TextSize = 13
	joinNo.Font = Enum.Font.GothamBold
	joinNo.AutoButtonColor = false
	joinNo.ZIndex = 301
	joinNo.Parent = joinBox
	corner(10, joinNo)
	stroke(M3.GlassLine, 1, joinNo, 0.9)

	joinYes.MouseEnter:Connect(function() tween(joinYes, {BackgroundColor3 = M3.PrimaryHover}, 0.1) end)
	joinYes.MouseLeave:Connect(function() tween(joinYes, {BackgroundColor3 = M3.Primary}, 0.15) end)
	joinNo.MouseEnter:Connect(function() tween(joinNo, {BackgroundColor3 = M3.SurfaceHighest}, 0.1) end)
	joinNo.MouseLeave:Connect(function() tween(joinNo, {BackgroundColor3 = M3.SurfaceHigh}, 0.15) end)
	joinYes.MouseButton1Click:Connect(function()
		joinBox.Visible = false
		queueReload()
		teleportToCatalog()
	end)
	joinNo.MouseButton1Click:Connect(function()
		joinBox.Visible = false
	end)
	catalogBtn.MouseButton1Click:Connect(function()
		joinBox.Visible = true
	end)

	local segControl = Instance.new("Frame")
	segControl.Name = "SegmentedControl"
	segControl.Size = UDim2.new(0, 200, 0, 34)
	segControl.Position = UDim2.new(0, 150, 0, 7)
	segControl.BackgroundColor3 = M3.Background
	segControl.BackgroundTransparency = 0.55
	segControl.BorderSizePixel = 0
	segControl.ZIndex = 3
	segControl.Parent = titleBar
	corner(10, segControl)
	stroke(M3.GlassLine, 1, segControl, 0.9)
	frost(segControl, 10)

	local segButtons = {}
	local segIndicator = Instance.new("Frame")
	segIndicator.Name = "Indicator"
	segIndicator.Size = UDim2.new(0.5, -6, 1, -6)
	segIndicator.Position = UDim2.new(0, 3, 0, 3)
	segIndicator.BackgroundColor3 = M3.Primary
	segIndicator.BorderSizePixel = 0
	segIndicator.ZIndex = 4
	segIndicator.Parent = segControl
	corner(8, segIndicator)
	animateGradient(
		segIndicator,
		{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(206, 210, 217)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		},
		nil,
		1.1,
		1.7
	)

	local function makeSeg(label, index)
		local btn = Instance.new("TextButton")
		btn.Name = "Seg_" .. label
		btn.Size = UDim2.new(0.5, 0, 1, 0)
		btn.Position = UDim2.new(index / 2, 0, 0, 0)
		btn.BackgroundTransparency = 1
		btn.Text = label
		btn.TextColor3 = index == 0 and M3.OnPrimary or M3.OnSurfaceVariant
		btn.TextSize = 12
		btn.Font = Enum.Font.GothamBold
		btn.AutoButtonColor = false
		btn.ZIndex = 5
		btn.Parent = segControl

		btn.MouseButton1Click:Connect(function()
			selectTab(label:lower(), index)
		end)
		segButtons[index + 1] = btn
		return btn
	end

	makeSeg("Avatars", 0)
	makeSeg("Settings", 1)

	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.new(1, -24, 1, -68)
	contentArea.Position = UDim2.new(0, 12, 0, 56)
	contentArea.BackgroundTransparency = 1
	contentArea.ClipsDescendants = true
	contentArea.ZIndex = 2
	contentArea.Parent = mf

	local avatarsPage = Instance.new("Frame")
	avatarsPage.Name = "AvatarsPage"
	avatarsPage.Size = UDim2.new(1, 0, 1, 0)
	avatarsPage.BackgroundTransparency = 1
	avatarsPage.ZIndex = 2
	avatarsPage.Parent = contentArea

	local settingsPage = Instance.new("ScrollingFrame")
	settingsPage.Name = "SettingsPage"
	settingsPage.Size = UDim2.new(1, 0, 1, 0)
	settingsPage.BackgroundTransparency = 1
	settingsPage.BorderSizePixel = 0
	settingsPage.ScrollBarThickness = 3
	settingsPage.ScrollBarImageColor3 = M3.Accent
	settingsPage.ScrollBarImageTransparency = 0.3
	settingsPage.CanvasSize = UDim2.new(0, 0, 0, 652)
	settingsPage.ScrollingDirection = Enum.ScrollingDirection.Y
	settingsPage.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	settingsPage.Visible = false
	settingsPage.ZIndex = 2
	settingsPage.Parent = contentArea

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.Size = UDim2.new(1, 0, 1, 0)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 3
	grid.ScrollBarImageColor3 = M3.Accent
	grid.ScrollBarImageTransparency = 0.3
	grid.CanvasSize = UDim2.new(0, 0, 0, 0)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	grid.ZIndex = 2
	grid.Parent = avatarsPage

	local gridLayout = Instance.new("UIListLayout")
	gridLayout.Padding = UDim.new(0, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.Parent = grid

	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingTop = UDim.new(0, 4)
	gridPad.PaddingBottom = UDim.new(0, 4)
	gridPad.Parent = grid

	local closeAutoloadPopup = function() end

	selectTab = function(page, index, instant)
		closeAutoloadPopup()
		local showAvatars = page == "avatars"
		local incoming = showAvatars and avatarsPage or settingsPage
		avatarsPage.Visible = showAvatars
		settingsPage.Visible = not showAvatars
		incoming.Position = UDim2.new(0, 0, 0, 0)
		if not instant then
			incoming.Position = UDim2.new(0, showAvatars and -10 or 10, 0, 0)
			tween(incoming, {Position = UDim2.new(0, 0, 0, 0)}, 0.2, Enum.EasingStyle.Quart)
		end
		local pos = UDim2.new(index * 0.5, 3, 0, 3)
		if instant then
			segIndicator.Position = pos
		else
			tween(segIndicator, {Position = pos}, 0.22, Enum.EasingStyle.Quart)
		end
		for i, btn in pairs(segButtons) do
			local active = ((i == 1 and page == "avatars") or (i == 2 and page == "settings"))
			btn.TextColor3 = active and M3.OnPrimary or M3.OnSurfaceVariant
		end
	end

	local autoloadRow = Instance.new("Frame")
	autoloadRow.Name = "Row_Autoload"
	autoloadRow.Size = UDim2.new(1, -8, 0, 48)
	autoloadRow.Position = UDim2.new(0, 4, 0, 6)
	autoloadRow.BackgroundColor3 = M3.Surface
	autoloadRow.BackgroundTransparency = 0.55
	autoloadRow.BorderSizePixel = 0
	autoloadRow.ZIndex = 2
	autoloadRow.Parent = settingsPage
	corner(12, autoloadRow)
	stroke(M3.GlassLine, 1, autoloadRow, 0.9)
	frost(autoloadRow, 12)

	local autoloadLabel = Instance.new("TextLabel")
	autoloadLabel.Name = "Label"
	autoloadLabel.Size = UDim2.new(1, -210, 0, 16)
	autoloadLabel.Position = UDim2.new(0, 14, 0, 7)
	autoloadLabel.BackgroundTransparency = 1
	autoloadLabel.Text = "Autoload on execute"
	autoloadLabel.TextColor3 = M3.OnSurface
	autoloadLabel.TextSize = 13
	autoloadLabel.Font = Enum.Font.GothamMedium
	autoloadLabel.TextXAlignment = Enum.TextXAlignment.Left
	autoloadLabel.ZIndex = 3
	autoloadLabel.Parent = autoloadRow

	local autoloadHint = Instance.new("TextLabel")
	autoloadHint.Name = "Hint"
	autoloadHint.Size = UDim2.new(1, -210, 0, 14)
	autoloadHint.Position = UDim2.new(0, 14, 0, 25)
	autoloadHint.BackgroundTransparency = 1
	autoloadHint.Text = "Load a saved fit when the script runs"
	autoloadHint.TextColor3 = M3.OnSurfaceFaint
	autoloadHint.TextSize = 10
	autoloadHint.Font = Enum.Font.Gotham
	autoloadHint.TextXAlignment = Enum.TextXAlignment.Left
	autoloadHint.ZIndex = 3
	autoloadHint.Parent = autoloadRow

	local autoloadBtn = Instance.new("TextButton")
	autoloadBtn.Name = "AutoloadBtn"
	autoloadBtn.Size = UDim2.new(0, 160, 0, 28)
	autoloadBtn.Position = UDim2.new(1, -174, 0.5, -14)
	autoloadBtn.BackgroundColor3 = M3.Background
	autoloadBtn.BackgroundTransparency = 0.3
	autoloadBtn.BorderSizePixel = 0
	autoloadBtn.Text = "None"
	autoloadBtn.TextColor3 = M3.OnSurface
	autoloadBtn.TextSize = 11
	autoloadBtn.Font = Enum.Font.GothamBold
	autoloadBtn.TextTruncate = Enum.TextTruncate.AtEnd
	autoloadBtn.AutoButtonColor = false
	autoloadBtn.ZIndex = 10
	autoloadBtn.Parent = autoloadRow
	corner(8, autoloadBtn)
	local autoloadBtnStroke = stroke(M3.GlassLine, 1, autoloadBtn, 0.85)

	autoloadBtn.MouseEnter:Connect(function() tween(autoloadBtnStroke, {Transparency = 0.5}, 0.1) end)
	autoloadBtn.MouseLeave:Connect(function() tween(autoloadBtnStroke, {Transparency = 0.85}, 0.15) end)

	local autoloadPopup = Instance.new("Frame")
	autoloadPopup.Name = "AutoloadPopup"
	autoloadPopup.Size = UDim2.new(0, 220, 0, 140)
	autoloadPopup.BackgroundColor3 = M3.Surface
	autoloadPopup.BackgroundTransparency = 0
	autoloadPopup.BorderSizePixel = 0
	autoloadPopup.Visible = false
	autoloadPopup.ZIndex = 250
	autoloadPopup.Parent = mf
	corner(12, autoloadPopup)
	stroke(M3.GlassLine, 1, autoloadPopup, 0.8)

	local autoloadBg = Instance.new("TextButton")
	autoloadBg.Name = "AutoloadBg"
	autoloadBg.Size = UDim2.new(1, 0, 1, 0)
	autoloadBg.BackgroundTransparency = 1
	autoloadBg.Text = ""
	autoloadBg.AutoButtonColor = false
	autoloadBg.Visible = false
	autoloadBg.ZIndex = 249
	autoloadBg.Parent = mf

	local autoloadScroll = Instance.new("ScrollingFrame")
	autoloadScroll.Name = "List"
	autoloadScroll.Size = UDim2.new(1, -8, 1, -8)
	autoloadScroll.Position = UDim2.new(0, 4, 0, 4)
	autoloadScroll.BackgroundTransparency = 1
	autoloadScroll.BorderSizePixel = 0
	autoloadScroll.ScrollBarThickness = 2
	autoloadScroll.ScrollBarImageColor3 = M3.Accent
	autoloadScroll.ScrollBarImageTransparency = 0.4
	autoloadScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	autoloadScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	autoloadScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	autoloadScroll.ZIndex = 251
	autoloadScroll.Parent = autoloadPopup

	local autoloadLayout = Instance.new("UIListLayout")
	autoloadLayout.Padding = UDim.new(0, 2)
	autoloadLayout.SortOrder = Enum.SortOrder.LayoutOrder
	autoloadLayout.Parent = autoloadScroll

	local function refreshAutoloadLabel()
		local current = settings.autoloadName
		if current == "" or not savedAvatars[current] then
			autoloadBtn.Text = "None"
		else
			autoloadBtn.Text = current
		end
	end
	refreshAutoloadLabel()

	closeAutoloadPopup = function()
		autoloadPopup.Visible = false
		autoloadBg.Visible = false
	end

	local function openAutoloadPopup()
		for _, child in pairs(autoloadScroll:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end

		local names = {}
		for name in pairs(savedAvatars) do
			table.insert(names, name)
		end
		table.sort(names, function(a, b) return a:lower() < b:lower() end)

		local function addOption(label, value, order)
			local btn = Instance.new("TextButton")
			btn.Name = "Autoload_" .. label
			btn.Size = UDim2.new(1, -4, 0, 28)
			btn.BackgroundColor3 = M3.SurfaceHighest
			btn.BackgroundTransparency = 1
			btn.Text = label
			btn.TextColor3 = settings.autoloadName == value and M3.Accent or M3.OnSurface
			btn.TextSize = 11
			btn.Font = Enum.Font.GothamMedium
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.TextTruncate = Enum.TextTruncate.AtEnd
			btn.AutoButtonColor = false
			btn.ZIndex = 252
			btn.LayoutOrder = order
			btn.Parent = autoloadScroll
			corner(7, btn)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 10)
			pad.PaddingRight = UDim.new(0, 10)
			pad.Parent = btn
			local btnStroke = stroke(M3.GlassLine, 1, btn, 1)
			btn.MouseEnter:Connect(function()
				tween(btn, {BackgroundTransparency = 0.72}, 0.1)
				tween(btnStroke, {Transparency = 0.9}, 0.1)
			end)
			btn.MouseLeave:Connect(function()
				tween(btn, {BackgroundTransparency = 1}, 0.15)
				tween(btnStroke, {Transparency = 1}, 0.15)
			end)
			btn.MouseButton1Click:Connect(function()
				settings.autoloadName = value
				saveSettings()
				refreshAutoloadLabel()
				closeAutoloadPopup()
			end)
		end

		addOption("None", "", 1)
		for i, name in ipairs(names) do
			addOption(name, name, i + 1)
		end

		local optionCount = #names + 1
		local height = math.min(200, 8 + optionCount * 30)
		autoloadPopup.Size = UDim2.new(0, 220, 0, height)
		autoloadScroll.CanvasSize = UDim2.new(0, 0, 0, optionCount * 30 + 4)

		local absPos = autoloadBtn.AbsolutePosition
		local mfPos = mf.AbsolutePosition
		local scale = math.max(uiScale.Scale, 0.01)
		local localW = mf.Size.X.Offset
		local localH = mf.Size.Y.Offset
		local btnW = autoloadBtn.AbsoluteSize.X / scale
		local btnH = autoloadBtn.AbsoluteSize.Y / scale
		local x = math.clamp((absPos.X - mfPos.X) / scale + btnW - 220, 8, localW - 228)
		local y = math.clamp((absPos.Y - mfPos.Y) / scale + btnH + 4, 8, localH - height - 8)
		autoloadPopup.Position = UDim2.new(0, x, 0, y)
		autoloadPopup.Visible = true
		autoloadBg.Visible = true
	end

	autoloadBtn.MouseButton1Click:Connect(function()
		if autoloadPopup.Visible then
			closeAutoloadPopup()
		else
			openAutoloadPopup()
		end
	end)
	autoloadBg.MouseButton1Click:Connect(closeAutoloadPopup)

	local settingsRow = Instance.new("Frame")
	settingsRow.Name = "Row_KeepOnRespawn"
	settingsRow.Size = UDim2.new(1, -8, 0, 48)
	settingsRow.Position = UDim2.new(0, 4, 0, 60)
	settingsRow.BackgroundColor3 = M3.Surface
	settingsRow.BackgroundTransparency = 0.55
	settingsRow.BorderSizePixel = 0
	settingsRow.ZIndex = 2
	settingsRow.Parent = settingsPage
	corner(12, settingsRow)
	stroke(M3.GlassLine, 1, settingsRow, 0.9)
	frost(settingsRow, 12)

	local settingsRowLabel = Instance.new("TextLabel")
	settingsRowLabel.Name = "Label"
	settingsRowLabel.Size = UDim2.new(1, -80, 1, 0)
	settingsRowLabel.Position = UDim2.new(0, 14, 0, 0)
	settingsRowLabel.BackgroundTransparency = 1
	settingsRowLabel.Text = "Keep avatar on respawn"
	settingsRowLabel.TextColor3 = M3.OnSurface
	settingsRowLabel.TextSize = 13
	settingsRowLabel.Font = Enum.Font.GothamMedium
	settingsRowLabel.TextXAlignment = Enum.TextXAlignment.Left
	settingsRowLabel.TextYAlignment = Enum.TextYAlignment.Center
	settingsRowLabel.ZIndex = 3
	settingsRowLabel.Parent = settingsRow

	local keepOnRespawnToggle = makeToggleSwitch(settingsRow, settings.keepOnRespawn, function(newValue)
		settings.keepOnRespawn = newValue
		saveSettings()
	end)
	keepOnRespawnToggle.Position = UDim2.new(1, -58, 0.5, -12)

	local deviceRow = Instance.new("Frame")
	deviceRow.Name = "Row_Device"
	deviceRow.Size = UDim2.new(1, -8, 0, 48)
	deviceRow.Position = UDim2.new(0, 4, 0, 114)
	deviceRow.BackgroundColor3 = M3.Surface
	deviceRow.BackgroundTransparency = 0.55
	deviceRow.BorderSizePixel = 0
	deviceRow.ZIndex = 2
	deviceRow.Parent = settingsPage
	corner(12, deviceRow)
	stroke(M3.GlassLine, 1, deviceRow, 0.9)
	frost(deviceRow, 12)

	local deviceRowLabel = Instance.new("TextLabel")
	deviceRowLabel.Name = "Label"
	deviceRowLabel.Size = UDim2.new(1, -170, 1, 0)
	deviceRowLabel.Position = UDim2.new(0, 14, 0, 0)
	deviceRowLabel.BackgroundTransparency = 1
	deviceRowLabel.Text = "Device"
	deviceRowLabel.TextColor3 = M3.OnSurface
	deviceRowLabel.TextSize = 13
	deviceRowLabel.Font = Enum.Font.GothamMedium
	deviceRowLabel.TextXAlignment = Enum.TextXAlignment.Left
	deviceRowLabel.TextYAlignment = Enum.TextYAlignment.Center
	deviceRowLabel.ZIndex = 3
	deviceRowLabel.Parent = deviceRow

	local devSeg = Instance.new("Frame")
	devSeg.Name = "DevSeg"
	devSeg.Size = UDim2.new(0, 150, 0, 28)
	devSeg.Position = UDim2.new(1, -166, 0.5, -14)
	devSeg.BackgroundColor3 = M3.Background
	devSeg.BackgroundTransparency = 0.55
	devSeg.BorderSizePixel = 0
	devSeg.ZIndex = 10
	devSeg.Parent = deviceRow
	corner(8, devSeg)
	stroke(M3.GlassLine, 1, devSeg, 0.9)
	frost(devSeg, 8)

	local devInd = Instance.new("Frame")
	devInd.Name = "DevInd"
	devInd.Size = UDim2.new(0.5, -4, 1, -4)
	devInd.Position = settings.device == "Mobile" and UDim2.new(0, 2, 0, 2) or UDim2.new(0.5, 2, 0, 2)
	devInd.BackgroundColor3 = M3.Primary
	devInd.BorderSizePixel = 0
	devInd.ZIndex = 4
	devInd.Parent = devSeg
	corner(6, devInd)

	local devMobile = Instance.new("TextButton")
	devMobile.Name = "DevMobile"
	devMobile.Size = UDim2.new(0.5, 0, 1, 0)
	devMobile.BackgroundTransparency = 1
	devMobile.Text = "Mobile"
	devMobile.TextColor3 = settings.device == "Mobile" and M3.OnPrimary or M3.OnSurfaceVariant
	devMobile.TextSize = 11
	devMobile.Font = Enum.Font.GothamBold
	devMobile.AutoButtonColor = false
	devMobile.ZIndex = 5
	devMobile.Parent = devSeg

	local devPc = Instance.new("TextButton")
	devPc.Name = "DevPc"
	devPc.Size = UDim2.new(0.5, 0, 1, 0)
	devPc.Position = UDim2.new(0.5, 0, 0, 0)
	devPc.BackgroundTransparency = 1
	devPc.Text = "PC"
	devPc.TextColor3 = settings.device == "PC" and M3.OnPrimary or M3.OnSurfaceVariant
	devPc.TextSize = 11
	devPc.Font = Enum.Font.GothamBold
	devPc.AutoButtonColor = false
	devPc.ZIndex = 5
	devPc.Parent = devSeg

	local function refreshDevColors()
		devMobile.TextColor3 = settings.device == "Mobile" and M3.OnPrimary or M3.OnSurfaceVariant
		devPc.TextColor3 = settings.device == "PC" and M3.OnPrimary or M3.OnSurfaceVariant
	end
	local function setDevIndicator(isMobile)
		tween(devInd, {Position = isMobile and UDim2.new(0, 2, 0, 2) or UDim2.new(0.5, 2, 0, 2)}, 0.18, Enum.EasingStyle.Quart)
	end

	devMobile.MouseButton1Click:Connect(function()
		settings.device = "Mobile"
		saveSettings()
		setDevIndicator(true)
		refreshDevColors()
		updateCircle()
	end)
	devPc.MouseButton1Click:Connect(function()
		settings.device = "PC"
		saveSettings()
		setDevIndicator(false)
		refreshDevColors()
		updateCircle()
	end)

	local keyRow = Instance.new("Frame")
	keyRow.Name = "Row_ToggleKey"
	keyRow.Size = UDim2.new(1, -8, 0, 48)
	keyRow.Position = UDim2.new(0, 4, 0, 168)
	keyRow.BackgroundColor3 = M3.Surface
	keyRow.BackgroundTransparency = 0.55
	keyRow.BorderSizePixel = 0
	keyRow.ZIndex = 2
	keyRow.Parent = settingsPage
	corner(12, keyRow)
	stroke(M3.GlassLine, 1, keyRow, 0.9)
	frost(keyRow, 12)

	local keyRowLabel = Instance.new("TextLabel")
	keyRowLabel.Name = "Label"
	keyRowLabel.Size = UDim2.new(1, -150, 1, 0)
	keyRowLabel.Position = UDim2.new(0, 14, 0, 0)
	keyRowLabel.BackgroundTransparency = 1
	keyRowLabel.Text = "Open / close key"
	keyRowLabel.TextColor3 = M3.OnSurface
	keyRowLabel.TextSize = 13
	keyRowLabel.Font = Enum.Font.GothamMedium
	keyRowLabel.TextXAlignment = Enum.TextXAlignment.Left
	keyRowLabel.TextYAlignment = Enum.TextYAlignment.Center
	keyRowLabel.ZIndex = 3
	keyRowLabel.Parent = keyRow

	local keyBtn = Instance.new("TextButton")
	keyBtn.Name = "KeyBtn"
	keyBtn.Size = UDim2.new(0, 120, 0, 28)
	keyBtn.Position = UDim2.new(1, -136, 0.5, -14)
	keyBtn.BackgroundColor3 = M3.Background
	keyBtn.BackgroundTransparency = 0.3
	keyBtn.BorderSizePixel = 0
	keyBtn.Text = keyDisplayName(settings.toggleKey)
	keyBtn.TextColor3 = M3.OnSurface
	keyBtn.TextSize = 12
	keyBtn.Font = Enum.Font.GothamBold
	keyBtn.AutoButtonColor = false
	keyBtn.ZIndex = 10
	keyBtn.Parent = keyRow
	corner(8, keyBtn)
	local keyBtnStroke = stroke(M3.GlassLine, 1, keyBtn, 0.85)

	keyBtn.MouseEnter:Connect(function() tween(keyBtnStroke, {Transparency = 0.5}, 0.1) end)
	keyBtn.MouseLeave:Connect(function()
		if not rebindCallback then tween(keyBtnStroke, {Transparency = 0.85}, 0.15) end
	end)

	local function finishRebind()
		rebindCallback = nil
		keyBtn.Text = keyDisplayName(settings.toggleKey)
		keyBtn.TextColor3 = M3.OnSurface
		tween(keyBtnStroke, {Color = M3.GlassLine, Transparency = 0.85}, 0.15)
	end

	keyBtn.MouseButton1Click:Connect(function()
		if rebindCallback then
			finishRebind()
			return
		end
		keyBtn.Text = "Press a key..."
		keyBtn.TextColor3 = M3.Accent
		tween(keyBtnStroke, {Color = M3.Accent, Transparency = 0.2}, 0.1)
		rebindCallback = function(keyCode)
			if keyCode ~= Enum.KeyCode.Escape and keyCode ~= Enum.KeyCode.Unknown then
				settings.toggleKey = keyCode.Name
				saveSettings()
			end
			finishRebind()
		end
	end)

	local blurRow = Instance.new("Frame")
	blurRow.Name = "Row_Blur"
	blurRow.Size = UDim2.new(1, -8, 0, 48)
	blurRow.Position = UDim2.new(0, 4, 0, 222)
	blurRow.BackgroundColor3 = M3.Surface
	blurRow.BackgroundTransparency = 0.55
	blurRow.BorderSizePixel = 0
	blurRow.ZIndex = 2
	blurRow.Parent = settingsPage
	corner(12, blurRow)
	stroke(M3.GlassLine, 1, blurRow, 0.9)
	frost(blurRow, 12)

	local blurRowLabel = Instance.new("TextLabel")
	blurRowLabel.Name = "Label"
	blurRowLabel.Size = UDim2.new(1, -80, 1, 0)
	blurRowLabel.Position = UDim2.new(0, 14, 0, 0)
	blurRowLabel.BackgroundTransparency = 1
	blurRowLabel.Text = "Background blur"
	blurRowLabel.TextColor3 = M3.OnSurface
	blurRowLabel.TextSize = 13
	blurRowLabel.Font = Enum.Font.GothamMedium
	blurRowLabel.TextXAlignment = Enum.TextXAlignment.Left
	blurRowLabel.TextYAlignment = Enum.TextYAlignment.Center
	blurRowLabel.ZIndex = 3
	blurRowLabel.Parent = blurRow

	local blurToggle = makeToggleSwitch(blurRow, settings.blur ~= false, function(newValue)
		settings.blur = newValue
		saveSettings()
		setWorldBlur(isGuiOpen)
	end)
	blurToggle.Position = UDim2.new(1, -58, 0.5, -12)

	local function makeSettingToggleRow(rowName, labelText, y, initialValue, onChanged)
		local row = Instance.new("Frame")
		row.Name = rowName
		row.Size = UDim2.new(1, -8, 0, 48)
		row.Position = UDim2.new(0, 4, 0, y)
		row.BackgroundColor3 = M3.Surface
		row.BackgroundTransparency = 0.55
		row.BorderSizePixel = 0
		row.ZIndex = 2
		row.Parent = settingsPage
		corner(12, row)
		stroke(M3.GlassLine, 1, row, 0.9)
		frost(row, 12)

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, -80, 1, 0)
		label.Position = UDim2.new(0, 14, 0, 0)
		label.BackgroundTransparency = 1
		label.Text = labelText
		label.TextColor3 = M3.OnSurface
		label.TextSize = 13
		label.Font = Enum.Font.GothamMedium
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.ZIndex = 3
		label.Parent = row

		local toggle = makeToggleSwitch(row, initialValue, onChanged)
		toggle.Position = UDim2.new(1, -58, 0.5, -12)
		return row, toggle
	end

	makeSettingToggleRow("Row_Tint", "Tint", 276, settings.tint, function(newValue)
		settings.tint = newValue
		saveSettings()
		local bd = currentGui and currentGui:FindFirstChild("Backdrop")
		if bd and isGuiOpen then
			tween(bd, {BackgroundTransparency = menuTintTransparency()}, 0.2)
		end
	end)

	makeSettingToggleRow("Row_FovChange", "FOV change", 330, settings.fovChange, function(newValue)
		settings.fovChange = newValue
		saveSettings()
		if isGuiOpen then
			if newValue then
				setFov(MENU_FOV)
			else
				restoreFov()
			end
		end
	end)

	makeSettingToggleRow("Row_HideUis", "Hide other UIs", 384, settings.hideUis, function(newValue)
		settings.hideUis = newValue
		saveSettings()
		if isGuiOpen then
			if newValue then
				hideOtherUis()
			else
				restoreHiddenUis()
			end
		end
	end)

	makeSettingToggleRow("Row_SkipWelcome", "Skip welcome screen", 438, settings.skipWelcome, function(newValue)
		settings.skipWelcome = newValue
		saveSettings()
	end)

	local SCALE_MIN, SCALE_MAX = 0.75, 1.25
	local scaleRow = Instance.new("Frame")
	scaleRow.Name = "Row_MenuSize"
	scaleRow.Size = UDim2.new(1, -8, 0, 48)
	scaleRow.Position = UDim2.new(0, 4, 0, 492)
	scaleRow.BackgroundColor3 = M3.Surface
	scaleRow.BackgroundTransparency = 0.55
	scaleRow.BorderSizePixel = 0
	scaleRow.ZIndex = 2
	scaleRow.Parent = settingsPage
	corner(12, scaleRow)
	stroke(M3.GlassLine, 1, scaleRow, 0.9)
	frost(scaleRow, 12)

	local scaleRowLabel = Instance.new("TextLabel")
	scaleRowLabel.Name = "Label"
	scaleRowLabel.Size = UDim2.new(1, -220, 1, 0)
	scaleRowLabel.Position = UDim2.new(0, 14, 0, 0)
	scaleRowLabel.BackgroundTransparency = 1
	scaleRowLabel.Text = "Menu size"
	scaleRowLabel.TextColor3 = M3.OnSurface
	scaleRowLabel.TextSize = 13
	scaleRowLabel.Font = Enum.Font.GothamMedium
	scaleRowLabel.TextXAlignment = Enum.TextXAlignment.Left
	scaleRowLabel.TextYAlignment = Enum.TextYAlignment.Center
	scaleRowLabel.ZIndex = 3
	scaleRowLabel.Parent = scaleRow

	local scalePct = Instance.new("TextLabel")
	scalePct.Name = "ScalePct"
	scalePct.Size = UDim2.new(0, 44, 0, 18)
	scalePct.Position = UDim2.new(1, -196, 0.5, -9)
	scalePct.BackgroundTransparency = 1
	scalePct.Text = "100%"
	scalePct.TextColor3 = M3.OnSurfaceVariant
	scalePct.TextSize = 11
	scalePct.Font = Enum.Font.Gotham
	scalePct.TextXAlignment = Enum.TextXAlignment.Right
	scalePct.TextYAlignment = Enum.TextYAlignment.Center
	scalePct.ZIndex = 3
	scalePct.Parent = scaleRow

	local scaleHit = Instance.new("TextButton")
	scaleHit.Name = "ScaleHit"
	scaleHit.Size = UDim2.new(0, 132, 0, 28)
	scaleHit.Position = UDim2.new(1, -146, 0.5, -14)
	scaleHit.BackgroundTransparency = 1
	scaleHit.Text = ""
	scaleHit.AutoButtonColor = false
	scaleHit.ZIndex = 10
	scaleHit.Parent = scaleRow

	local scaleTrack = Instance.new("Frame")
	scaleTrack.Name = "Track"
	scaleTrack.Size = UDim2.new(0, 120, 0, 6)
	scaleTrack.Position = UDim2.new(0, 6, 0.5, -3)
	scaleTrack.BackgroundColor3 = M3.Background
	scaleTrack.BackgroundTransparency = 0.2
	scaleTrack.BorderSizePixel = 0
	scaleTrack.ZIndex = 11
	scaleTrack.Parent = scaleHit
	corner(3, scaleTrack)

	local scaleFill = Instance.new("Frame")
	scaleFill.Name = "Fill"
	scaleFill.Size = UDim2.new(0, 0, 1, 0)
	scaleFill.BackgroundColor3 = M3.Accent
	scaleFill.BorderSizePixel = 0
	scaleFill.ZIndex = 12
	scaleFill.Parent = scaleTrack
	corner(3, scaleFill)

	local scaleKnob = Instance.new("Frame")
	scaleKnob.Name = "Knob"
	scaleKnob.AnchorPoint = Vector2.new(0.5, 0.5)
	scaleKnob.Size = UDim2.new(0, 16, 0, 16)
	scaleKnob.Position = UDim2.new(0, 8, 0.5, 0)
	scaleKnob.BackgroundColor3 = M3.OnSurface
	scaleKnob.BorderSizePixel = 0
	scaleKnob.ZIndex = 13
	scaleKnob.Parent = scaleTrack
	corner(8, scaleKnob)

	local function updateScaleUi()
		local t = (settings.uiScale - SCALE_MIN) / (SCALE_MAX - SCALE_MIN)
		local x = 8 + t * 104
		scaleFill.Size = UDim2.new(0, x, 1, 0)
		scaleKnob.Position = UDim2.new(0, x, 0.5, 0)
		scalePct.Text = tostring(math.floor(settings.uiScale * 100 + 0.5)) .. "%"
	end
	updateScaleUi()

	local scaleDragging = false
	local scaleDragTrackX, scaleDragTrackW = 0, 1
	local function applyScaleAt(absX, trackX, trackW)
		local rel = math.clamp((absX - trackX) / math.max(trackW, 1), 0, 1)
		settings.uiScale = SCALE_MIN + rel * (SCALE_MAX - SCALE_MIN)
		updateScaleUi()
		refreshScale()
	end
	scaleHit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			scaleDragging = true
			scaleDragTrackX = scaleTrack.AbsolutePosition.X
			scaleDragTrackW = scaleTrack.AbsoluteSize.X
			applyScaleAt(input.Position.X, scaleDragTrackX, scaleDragTrackW)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if scriptUnloaded then return end
		if scaleDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			applyScaleAt(input.Position.X, scaleDragTrackX, scaleDragTrackW)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if scriptUnloaded then return end
		if scaleDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			scaleDragging = false
			saveSettings()
		end
	end)

	local snowRow = Instance.new("Frame")
	snowRow.Name = "Row_EnableSnow"
	snowRow.Size = UDim2.new(1, -8, 0, 48)
	snowRow.Position = UDim2.new(0, 4, 0, 546)
	snowRow.BackgroundColor3 = M3.Surface
	snowRow.BackgroundTransparency = 0.55
	snowRow.BorderSizePixel = 0
	snowRow.ZIndex = 2
	snowRow.Parent = settingsPage
	corner(12, snowRow)
	stroke(M3.GlassLine, 1, snowRow, 0.9)
	frost(snowRow, 12)

	local snowRowLabel = Instance.new("TextLabel")
	snowRowLabel.Name = "Label"
	snowRowLabel.Size = UDim2.new(1, -80, 1, 0)
	snowRowLabel.Position = UDim2.new(0, 14, 0, 0)
	snowRowLabel.BackgroundTransparency = 1
	snowRowLabel.Text = "Enable snow"
	snowRowLabel.TextColor3 = M3.OnSurface
	snowRowLabel.TextSize = 13
	snowRowLabel.Font = Enum.Font.GothamMedium
	snowRowLabel.TextXAlignment = Enum.TextXAlignment.Left
	snowRowLabel.TextYAlignment = Enum.TextYAlignment.Center
	snowRowLabel.ZIndex = 3
	snowRowLabel.Parent = snowRow

	local snowToggle = makeToggleSwitch(snowRow, settings.snow ~= false, function(newValue)
		settings.snow = newValue
		saveSettings()
		if isGuiOpen then
			if newValue then
				if startSnow then startSnow() end
			else
				if stopSnow then stopSnow() end
			end
		end
	end)
	snowToggle.Position = UDim2.new(1, -58, 0.5, -12)

	local unloadRow = Instance.new("Frame")
	unloadRow.Name = "Row_Unload"
	unloadRow.Size = UDim2.new(1, -8, 0, 48)
	unloadRow.Position = UDim2.new(0, 4, 0, 600)
	unloadRow.BackgroundColor3 = M3.Surface
	unloadRow.BackgroundTransparency = 0.55
	unloadRow.BorderSizePixel = 0
	unloadRow.ZIndex = 2
	unloadRow.Parent = settingsPage
	corner(12, unloadRow)
	stroke(M3.GlassLine, 1, unloadRow, 0.9)
	frost(unloadRow, 12)

	local unloadLabel = Instance.new("TextLabel")
	unloadLabel.Name = "Label"
	unloadLabel.Size = UDim2.new(1, -110, 0, 16)
	unloadLabel.Position = UDim2.new(0, 14, 0, 7)
	unloadLabel.BackgroundTransparency = 1
	unloadLabel.Text = "Unload script"
	unloadLabel.TextColor3 = M3.OnSurface
	unloadLabel.TextSize = 13
	unloadLabel.Font = Enum.Font.GothamMedium
	unloadLabel.TextXAlignment = Enum.TextXAlignment.Left
	unloadLabel.ZIndex = 3
	unloadLabel.Parent = unloadRow

	local unloadHint = Instance.new("TextLabel")
	unloadHint.Name = "Hint"
	unloadHint.Size = UDim2.new(1, -110, 0, 14)
	unloadHint.Position = UDim2.new(0, 14, 0, 25)
	unloadHint.BackgroundTransparency = 1
	unloadHint.Text = "Close Cupcake and restore your avatar"
	unloadHint.TextColor3 = M3.OnSurfaceFaint
	unloadHint.TextSize = 10
	unloadHint.Font = Enum.Font.Gotham
	unloadHint.TextXAlignment = Enum.TextXAlignment.Left
	unloadHint.ZIndex = 3
	unloadHint.Parent = unloadRow

	local unloadBtn = Instance.new("TextButton")
	unloadBtn.Name = "Unload"
	unloadBtn.Size = UDim2.new(0, 78, 0, 26)
	unloadBtn.Position = UDim2.new(1, -92, 0.5, -13)
	unloadBtn.BackgroundColor3 = M3.ErrorContainer
	unloadBtn.BackgroundTransparency = 1
	unloadBtn.BorderSizePixel = 0
	unloadBtn.Text = "Unload"
	unloadBtn.TextColor3 = M3.Error
	unloadBtn.TextSize = 11
	unloadBtn.Font = Enum.Font.GothamBold
	unloadBtn.AutoButtonColor = false
	unloadBtn.ZIndex = 3
	unloadBtn.Parent = unloadRow
	corner(8, unloadBtn)
	local unloadStroke = stroke(M3.Error, 1, unloadBtn, 0.55)

	unloadBtn.MouseEnter:Connect(function()
		tween(unloadBtn, {BackgroundTransparency = 0.75}, 0.12)
		tween(unloadBtn, {TextColor3 = M3.Accent}, 0.12)
		tween(unloadStroke, {Transparency = 0.15}, 0.12)
	end)
	unloadBtn.MouseLeave:Connect(function()
		tween(unloadBtn, {BackgroundTransparency = 1}, 0.15)
		tween(unloadBtn, {TextColor3 = M3.Error}, 0.15)
		tween(unloadStroke, {Transparency = 0.55}, 0.15)
	end)
	unloadBtn.MouseButton1Click:Connect(function()
		unloadScript()
	end)

	local function createAvatarGridCard(name, data, order)
		local card = Instance.new("Frame")
		card.Name = "AvatarCard_" .. name
		card.Size = UDim2.new(1, -8, 0, 60)
		card.BackgroundColor3 = M3.Surface
		card.BackgroundTransparency = 0.6
		card.BorderSizePixel = 0
		card.LayoutOrder = order
		card.ZIndex = 2
		card.Parent = grid
		card.ClipsDescendants = true
		corner(12, card)
		local cardStroke = stroke(M3.GlassLine, 1, card, 0.9)
		frost(card, 12)

		local cardAccent = Instance.new("Frame")
		cardAccent.Name = "CardAccent"
		cardAccent.Size = UDim2.new(0, 3, 0, 30)
		cardAccent.Position = UDim2.new(0, 0, 0.5, -15)
		cardAccent.BackgroundColor3 = M3.Accent
		cardAccent.BackgroundTransparency = 0.5
		cardAccent.BorderSizePixel = 0
		cardAccent.ZIndex = 3
		cardAccent.Parent = card
		corner(2, cardAccent)

		card.MouseEnter:Connect(function()
			tween(card, {BackgroundColor3 = M3.SurfaceHigh, BackgroundTransparency = 0.45}, 0.12)
			tween(cardStroke, {Color = M3.Accent, Transparency = 0.55}, 0.12)
			tween(cardAccent, {BackgroundTransparency = 0.05}, 0.12)
		end)
		card.MouseLeave:Connect(function()
			tween(card, {BackgroundColor3 = M3.Surface, BackgroundTransparency = 0.6}, 0.15)
			tween(cardStroke, {Color = M3.GlassLine, Transparency = 0.9}, 0.15)
			tween(cardAccent, {BackgroundTransparency = 0.5}, 0.15)
		end)

		local chip = Instance.new("Frame")
		chip.Name = "Chip"
		chip.Size = UDim2.new(0, 28, 0, 28)
		chip.Position = UDim2.new(0, 12, 0.5, -14)
		chip.BackgroundColor3 = M3.SurfaceHighest
		chip.BorderSizePixel = 0
		chip.ZIndex = 3
		chip.ClipsDescendants = true
		chip.Parent = card
		corner(8, chip)
		stroke(M3.GlassLine, 1, chip, 0.9)

		local okChip, chipColors = pcall(function()
			local cols = getPreviewColors(data)
			if #cols == 0 then cols = extractAvatarColors(data) end
			return cols
		end)
		if okChip and chipColors then
			paintChip(chip, chipColors)
		end

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.Size = UDim2.new(1, -108, 0, 22)
		nameLabel.Position = UDim2.new(0, 52, 0, 8)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = name
		nameLabel.TextColor3 = M3.OnSurface
		nameLabel.TextSize = 14
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextYAlignment = Enum.TextYAlignment.Center
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.ZIndex = 3
		nameLabel.Parent = card

		local wearHint = Instance.new("TextLabel")
		wearHint.Name = "WearHint"
		wearHint.Size = UDim2.new(1, -108, 0, 16)
		wearHint.Position = UDim2.new(0, 52, 0, 32)
		wearHint.BackgroundTransparency = 1
		wearHint.Text = "Tap to wear"
		wearHint.TextColor3 = M3.OnSurfaceFaint
		wearHint.TextSize = 11
		wearHint.Font = Enum.Font.Gotham
		wearHint.TextXAlignment = Enum.TextXAlignment.Left
		wearHint.TextYAlignment = Enum.TextYAlignment.Center
		wearHint.ZIndex = 3
		wearHint.Parent = card

		local moreBtn = Instance.new("TextButton")
		moreBtn.Name = "MoreBtn"
		moreBtn.Size = UDim2.new(0, 30, 0, 30)
		moreBtn.Position = UDim2.new(1, -42, 0.5, -15)
		moreBtn.BackgroundColor3 = M3.SurfaceHighest
		moreBtn.BackgroundTransparency = 1
		moreBtn.BorderSizePixel = 0
		moreBtn.Text = "···"
		moreBtn.TextColor3 = M3.OnSurfaceVariant
		moreBtn.TextSize = 14
		moreBtn.Font = Enum.Font.GothamBold
		moreBtn.AutoButtonColor = false
		moreBtn.ZIndex = 6
		moreBtn.Parent = card
		corner(10, moreBtn)
		moreBtn.MouseEnter:Connect(function()
			tween(moreBtn, {BackgroundTransparency = 0.15, TextColor3 = M3.OnSurface}, 0.1)
		end)
		moreBtn.MouseLeave:Connect(function()
			tween(moreBtn, {BackgroundTransparency = 1, TextColor3 = M3.OnSurfaceVariant}, 0.15)
		end)
		moreBtn.MouseButton1Click:Connect(function()
			openOptionsMenu(name, moreBtn)
		end)

		local cardButton = Instance.new("TextButton")
		cardButton.Name = "CardButton"
		cardButton.Size = UDim2.new(1, -52, 1, 0)
		cardButton.BackgroundTransparency = 1
		cardButton.Text = ""
		cardButton.AutoButtonColor = false
		cardButton.ZIndex = 2
		cardButton.Parent = card
		cardButton.MouseButton1Click:Connect(function()
			LoadAvatarByName(name)
		end)

		return card
	end

	local function createAddCard(order)
		local card = Instance.new("TextButton")
		card.Name = "AddCard"
		card.Size = UDim2.new(1, -8, 0, 48)
		card.BackgroundColor3 = M3.Surface
		card.BackgroundTransparency = 0.7
		card.BorderSizePixel = 0
		card.Text = ""
		card.AutoButtonColor = false
		card.LayoutOrder = order
		card.ZIndex = 2
		card.Parent = grid
		card.ClipsDescendants = true
		corner(12, card)
		local dashStroke = stroke(M3.GlassLine, 1, card, 0.9)
		frost(card, 12)

		local plus = Instance.new("TextLabel")
		plus.Size = UDim2.new(1, -16, 1, 0)
		plus.Position = UDim2.new(0, 16, 0, 0)
		plus.BackgroundTransparency = 1
		plus.Text = "+  Save current avatar"
		plus.TextColor3 = M3.OnSurfaceVariant
		plus.TextSize = 13
		plus.Font = Enum.Font.GothamBold
		plus.TextXAlignment = Enum.TextXAlignment.Left
		plus.TextYAlignment = Enum.TextYAlignment.Center
		plus.ZIndex = 3
		plus.Parent = card

		card.MouseEnter:Connect(function()
			tween(card, {BackgroundTransparency = 0.55}, 0.12)
			tween(dashStroke, {Color = M3.Accent, Transparency = 0.55}, 0.12)
			tween(plus, {TextColor3 = M3.OnSurface}, 0.12)
		end)
		card.MouseLeave:Connect(function()
			tween(card, {BackgroundTransparency = 0.7}, 0.15)
			tween(dashStroke, {Color = M3.GlassLine, Transparency = 0.9}, 0.15)
			tween(plus, {TextColor3 = M3.OnSurfaceVariant}, 0.15)
		end)
		card.MouseButton1Click:Connect(function() openModal("save") end)
		return card
	end

	refreshGrid = function()
		for _, child in pairs(grid:GetChildren()) do
			if child:IsA("Frame") or (child:IsA("TextButton") and child.Name == "AddCard") then child:Destroy() end
		end

		local names = {}
		for name in pairs(savedAvatars) do
			table.insert(names, name)
		end
		table.sort(names, function(a, b) return a:lower() < b:lower() end)
		for i, name in ipairs(names) do
			createAvatarGridCard(name, savedAvatars[name], i)
		end
		createAddCard(#names + 1)
	end

	guiCharacterConn = player.CharacterAdded:Connect(function()
		task.wait(1)
		if scriptUnloaded then return end
		if currentGui == sg then refreshGrid() end
	end)

	local dragging = false
	local dragStart, winStart
	local function beginDrag(input)
		dragging = true
		dragStart = input.Position
		winStart = mf.Position
	end
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag(input)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if scriptUnloaded then return end
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			mf.Position = UDim2.new(winStart.X.Scale, winStart.X.Offset + delta.X, winStart.Y.Scale, winStart.Y.Offset + delta.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if scriptUnloaded then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	local function animateSheetOpen(overlay, box, extras)
		local finalTransparency = box.BackgroundTransparency
		overlay.BackgroundTransparency = 1
		box.BackgroundTransparency = 1
		local finalPos = box.Position
		box.Position = finalPos + UDim2.new(0, 0, 0, -14)
		for _, el in ipairs(extras or {}) do
			if el.Prop == "Stroke" then el.Obj.Transparency = 1
			elseif el.Prop == "Text" then el.Obj.TextTransparency = 1
			elseif el.Prop == "Bg" then el.Obj.BackgroundTransparency = 1 end
		end
		tween(overlay, {BackgroundTransparency = 0.45}, 0.16)
		tween(box, {BackgroundTransparency = finalTransparency, Position = finalPos}, 0.2, Enum.EasingStyle.Quart)
		task.delay(0.05, function()
			for _, el in ipairs(extras or {}) do
				if el.Prop == "Stroke" then tween(el.Obj, {Transparency = el.To}, 0.16)
				elseif el.Prop == "Text" then tween(el.Obj, {TextTransparency = el.To}, 0.16)
				elseif el.Prop == "Bg" then tween(el.Obj, {BackgroundTransparency = el.To}, 0.16) end
			end
		end)
	end

	local modal = Instance.new("Frame")
	modal.Name = "Modal"
	modal.Size = UDim2.new(1, 0, 1, 0)
	modal.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
	modal.BackgroundTransparency = 0.45
	modal.BorderSizePixel = 0
	modal.ZIndex = 100
	modal.Visible = false
	modal.Parent = mf

	local modalBgBtn = Instance.new("TextButton")
	modalBgBtn.Name = "ModalBgBtn"
	modalBgBtn.Size = UDim2.new(1, 0, 1, 0)
	modalBgBtn.BackgroundTransparency = 1
	modalBgBtn.Text = ""
	modalBgBtn.ZIndex = 100
	modalBgBtn.Parent = modal

	local modalBox = Instance.new("Frame")
	modalBox.Name = "ModalBox"
	modalBox.Size = UDim2.new(0, 300, 0, 286)
	modalBox.Position = UDim2.new(0.5, -150, 0.5, -143)
	modalBox.BackgroundColor3 = M3.Surface
	modalBox.BackgroundTransparency = 0.06
	modalBox.BorderSizePixel = 0
	modalBox.ZIndex = 101
	modalBox.ClipsDescendants = true
	modalBox.Parent = modal
	corner(14, modalBox)
	local modalBoxStroke = stroke(M3.GlassLine, 1, modalBox, 0.74)

	local modalGrad = Instance.new("UIGradient")
	modalGrad.Name = "ModalGrad"
	modalGrad.Rotation = 90
	modalGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(68, 72, 80)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 53, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(36, 38, 44)),
	})
	modalGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.02),
		NumberSequenceKeypoint.new(1, 0.3),
	})
	modalGrad.Parent = modalBox

	local modalBoxBlocker = Instance.new("TextButton")
	modalBoxBlocker.Name = "Blocker"
	modalBoxBlocker.Size = UDim2.new(1, 0, 1, 0)
	modalBoxBlocker.BackgroundTransparency = 1
	modalBoxBlocker.Text = ""
	modalBoxBlocker.ZIndex = 101
	modalBoxBlocker.Parent = modalBox
	modalBoxBlocker.MouseButton1Click:Connect(function() end)
	local modalTitle = Instance.new("TextLabel")
	modalTitle.Name = "Title"
	modalTitle.Size = UDim2.new(1, -40, 0, 24)
	modalTitle.Position = UDim2.new(0, 20, 0, 16)
	modalTitle.BackgroundTransparency = 1
	modalTitle.Text = "New avatar"
	modalTitle.TextColor3 = M3.OnSurface
	modalTitle.TextSize = 15
	modalTitle.Font = Enum.Font.GothamBold
	modalTitle.TextXAlignment = Enum.TextXAlignment.Left
	modalTitle.ZIndex = 102
	modalTitle.Parent = modalBox

	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -40, 0, 32)
	tabBar.Position = UDim2.new(0, 20, 0, 48)
	tabBar.BackgroundColor3 = M3.Background
	tabBar.BackgroundTransparency = 0.55
	tabBar.BorderSizePixel = 0
	tabBar.ZIndex = 102
	tabBar.Parent = modalBox
	corner(9, tabBar)

	local tabIndicator = Instance.new("Frame")
	tabIndicator.Name = "Indicator"
	tabIndicator.Size = UDim2.new(0.5, -4, 1, -4)
	tabIndicator.Position = UDim2.new(0, 2, 0, 2)
	tabIndicator.BackgroundColor3 = M3.Primary
	tabIndicator.BorderSizePixel = 0
	tabIndicator.ZIndex = 102
	tabIndicator.Parent = tabBar
	corner(7, tabIndicator)
	animateGradient(
		tabIndicator,
		{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(206, 210, 217)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		},
		nil,
		1.1,
		0.4
	)
	local modalGradientLine = gradientLine(modalBox, UDim2.new(1, -40, 0, 1), UDim2.new(0, 20, 0, 82), 102, 1.5, 0.9)

	local btnTabSave = Instance.new("TextButton")
	btnTabSave.Name = "TabSave"
	btnTabSave.Size = UDim2.new(0.5, 0, 1, 0)
	btnTabSave.BackgroundTransparency = 1
	btnTabSave.Text = "Save"
	btnTabSave.TextColor3 = M3.OnPrimary
	btnTabSave.TextSize = 12
	btnTabSave.Font = Enum.Font.GothamBold
	btnTabSave.AutoButtonColor = false
	btnTabSave.ZIndex = 103
	btnTabSave.Parent = tabBar

	local btnTabCopy = Instance.new("TextButton")
	btnTabCopy.Name = "TabCopy"
	btnTabCopy.Size = UDim2.new(0.5, 0, 1, 0)
	btnTabCopy.Position = UDim2.new(0.5, 0, 0, 0)
	btnTabCopy.BackgroundTransparency = 1
	btnTabCopy.Text = "Copy"
	btnTabCopy.TextColor3 = M3.OnSurfaceVariant
	btnTabCopy.TextSize = 12
	btnTabCopy.Font = Enum.Font.GothamBold
	btnTabCopy.AutoButtonColor = false
	btnTabCopy.ZIndex = 103
	btnTabCopy.Parent = tabBar

	local inputWrap = Instance.new("Frame")
	inputWrap.Name = "InputWrap"
	inputWrap.Size = UDim2.new(1, -40, 0, 38)
	inputWrap.Position = UDim2.new(0, 20, 0, 94)
	inputWrap.BackgroundColor3 = M3.Background
	inputWrap.BackgroundTransparency = 0.55
	inputWrap.BorderSizePixel = 0
	inputWrap.ZIndex = 102
	inputWrap.Parent = modalBox
	corner(9, inputWrap)
	local inputStroke = stroke(M3.OutlineVariant, 1, inputWrap, 0.5)

	local modalInput = Instance.new("TextBox")
	modalInput.Name = "Input"
	modalInput.Size = UDim2.new(1, -20, 1, 0)
	modalInput.Position = UDim2.new(0, 10, 0, 0)
	modalInput.BackgroundTransparency = 1
	modalInput.Text = ""
	modalInput.PlaceholderText = "Avatar name..."
	modalInput.TextColor3 = M3.OnSurface
	modalInput.PlaceholderColor3 = M3.OnSurfaceFaint
	modalInput.TextSize = 12
	modalInput.Font = Enum.Font.Gotham
	modalInput.TextXAlignment = Enum.TextXAlignment.Left
	modalInput.ClearTextOnFocus = false
	modalInput.ZIndex = 103
	modalInput.Parent = inputWrap

	modalInput.Focused:Connect(function() tween(inputStroke, {Color = M3.Accent, Transparency = 0}, 0.1) end)
	modalInput.FocusLost:Connect(function()
		tween(inputStroke, {Color = M3.OutlineVariant, Transparency = 0.5}, 0.15)
	end)

	local playerList = Instance.new("ScrollingFrame")
	playerList.Name = "PlayerList"
	playerList.Size = UDim2.new(1, -40, 0, 118)
	playerList.Position = UDim2.new(0, 20, 0, 94)
	playerList.BackgroundTransparency = 1
	playerList.BorderSizePixel = 0
	playerList.ScrollBarThickness = 3
	playerList.ScrollBarImageColor3 = M3.Accent
	playerList.ScrollBarImageTransparency = 0.3
	playerList.CanvasSize = UDim2.new(0, 0, 0, 0)
	playerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	playerList.Visible = false
	playerList.ZIndex = 102
	playerList.Parent = modalBox

	local playerListLayout = Instance.new("UIListLayout")
	playerListLayout.Padding = UDim.new(0, 6)
	playerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	playerListLayout.Parent = playerList

	local btnCancelModal = Instance.new("TextButton")
	btnCancelModal.Name = "BtnCancel"
	btnCancelModal.Size = UDim2.new(0, 120, 0, 40)
	btnCancelModal.Position = UDim2.new(0, 20, 1, -54)
	btnCancelModal.BackgroundColor3 = M3.SurfaceHigh
	btnCancelModal.BorderSizePixel = 0
	btnCancelModal.Text = "Cancel"
	btnCancelModal.TextColor3 = M3.OnSurface
	btnCancelModal.TextSize = 13
	btnCancelModal.Font = Enum.Font.GothamMedium
	btnCancelModal.AutoButtonColor = false
	btnCancelModal.ZIndex = 102
	btnCancelModal.Parent = modalBox
	corner(12, btnCancelModal)
	stroke(M3.GlassLine, 1, btnCancelModal, 0.9)

	local btnSaveModal = Instance.new("TextButton")
	btnSaveModal.Name = "BtnSave"
	btnSaveModal.Size = UDim2.new(0, 120, 0, 40)
	btnSaveModal.Position = UDim2.new(1, -140, 1, -54)
	btnSaveModal.BackgroundColor3 = M3.Primary
	btnSaveModal.BorderSizePixel = 0
	btnSaveModal.Text = "Save"
	btnSaveModal.TextColor3 = M3.OnPrimary
	btnSaveModal.TextSize = 13
	btnSaveModal.Font = Enum.Font.GothamBold
	btnSaveModal.AutoButtonColor = false
	btnSaveModal.ZIndex = 102
	btnSaveModal.Parent = modalBox
	corner(12, btnSaveModal)
	stroke(M3.Primary, 1, btnSaveModal, 0.6)

	btnCancelModal.MouseEnter:Connect(function() tween(btnCancelModal, {BackgroundColor3 = M3.SurfaceHighest}, 0.1) end)
	btnCancelModal.MouseLeave:Connect(function() tween(btnCancelModal, {BackgroundColor3 = M3.SurfaceHigh}, 0.15) end)
	btnSaveModal.MouseEnter:Connect(function() tween(btnSaveModal, {BackgroundColor3 = M3.PrimaryHover}, 0.1) end)
	btnSaveModal.MouseLeave:Connect(function() tween(btnSaveModal, {BackgroundColor3 = M3.Primary}, 0.15) end)
	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.Size = UDim2.new(0, 230, 0, 38)
	toast.Position = UDim2.new(0.5, -115, 1, -8)
	toast.BackgroundColor3 = M3.Surface
	toast.BackgroundTransparency = 0.72
	toast.BorderSizePixel = 0
	toast.ZIndex = 60
	toast.Visible = false
	toast.Parent = mf
	corner(12, toast)
	stroke(M3.GlassLine, 1, toast, 0.88)
	frost(toast, 12)

	local toastLabel = Instance.new("TextLabel")
	toastLabel.Name = "Label"
	toastLabel.Size = UDim2.new(1, -20, 1, 0)
	toastLabel.Position = UDim2.new(0, 10, 0, 0)
	toastLabel.BackgroundTransparency = 1
	toastLabel.Text = ""
	toastLabel.TextColor3 = M3.OnSurface
	toastLabel.TextSize = 11
	toastLabel.Font = Enum.Font.GothamMedium
	toastLabel.TextWrapped = true
	toastLabel.ZIndex = 61
	toastLabel.Parent = toast

	local toastConn = nil
	showToast = function(msg)
	end
	showToastRef = showToast

	local modalMode = "save"
	local modalRenameTarget = nil

	local function animateModalOpen()
		animateSheetOpen(modal, modalBox, {{Obj = modalBoxStroke, Prop = "Stroke", To = 0.9}})
	end

	copyPlayerAvatar = function(plr)
		local char = plr.Character
		if not char then return end
		local baseName, name, n = plr.Name, plr.Name, 1
		while savedAvatars[name] do
			n = n + 1
			name = baseName .. " (" .. n .. ")"
		end
		if SaveAvatarWithName(name, char) then
			refreshGrid()
			closeModal()
		end
	end

	local selectedCopyPlayers = {}
	local function updateCopySaveBtn()
		local n = 0
		for _ in pairs(selectedCopyPlayers) do n = n + 1 end
		btnSaveModal.Text = n > 0 and ("Save (" .. n .. ")") or "Save"
	end
	local function saveSelectedPlayers()
		local total = 0
		for _ in pairs(selectedCopyPlayers) do total = total + 1 end
		if total == 0 then return end
		local done = 0
		for plr in pairs(selectedCopyPlayers) do
			local char = plr.Character
			if char then
				local baseName, name, n = plr.Name, plr.Name, 1
				while savedAvatars[name] do
					n = n + 1
					name = baseName .. " (" .. n .. ")"
				end
				if SaveAvatarWithName(name, char, true) then
					done = done + 1
				end
				task.wait(0.1)
			end
		end
		selectedCopyPlayers = {}
		refreshGrid()
		closeModal()
	end

	populatePlayerList = function()
		for _, c in pairs(playerList:GetChildren()) do
			if c:IsA("TextButton") or c:IsA("TextLabel") or c:IsA("Frame") then c:Destroy() end
		end
		local others = 0
		for _, plr in pairs(Players:GetPlayers()) do
			if plr ~= player then
				others = others + 1
				local row = Instance.new("TextButton")
				row.Name = "PlayerRow_" .. plr.Name
				row.Size = UDim2.new(1, 0, 0, 44)
				row.BackgroundColor3 = M3.SurfaceHigh
				row.BackgroundTransparency = 0.4
				row.Text = ""
				row.AutoButtonColor = false
				row.ZIndex = 103
				row.Parent = playerList
				corner(10, row)
				local rowStroke = stroke(M3.GlassLine, 1, row, 0.9)

				local thumb = Instance.new("ImageLabel")
				thumb.Name = "Headshot"
				thumb.Size = UDim2.new(0, 30, 0, 30)
				thumb.Position = UDim2.new(0, 7, 0.5, -15)
				thumb.BackgroundColor3 = M3.SurfaceHighest
				thumb.BorderSizePixel = 0
				thumb.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(plr.UserId) .. "&w=150&h=150"
				thumb.ZIndex = 104
				thumb.Parent = row
				corner(15, thumb)
				stroke(M3.GlassLine, 1, thumb, 0.82)

				local nameLabel = Instance.new("TextLabel")
				nameLabel.Name = "Name"
				nameLabel.Size = UDim2.new(1, -92, 0, 18)
				nameLabel.Position = UDim2.new(0, 45, 0, 5)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Text = plr.DisplayName
				nameLabel.TextColor3 = M3.OnSurface
				nameLabel.TextSize = 12
				nameLabel.Font = Enum.Font.GothamMedium
				nameLabel.TextXAlignment = Enum.TextXAlignment.Left
				nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
				nameLabel.ZIndex = 104
				nameLabel.Parent = row

				local userLabel = Instance.new("TextLabel")
				userLabel.Name = "Username"
				userLabel.Size = UDim2.new(1, -92, 0, 14)
				userLabel.Position = UDim2.new(0, 45, 0, 23)
				userLabel.BackgroundTransparency = 1
				userLabel.Text = "@" .. plr.Name
				userLabel.TextColor3 = M3.OnSurfaceFaint
				userLabel.TextSize = 10
				userLabel.Font = Enum.Font.Gotham
				userLabel.TextXAlignment = Enum.TextXAlignment.Left
				userLabel.ZIndex = 104
				userLabel.Parent = row

				local check = Instance.new("TextLabel")
				check.Name = "Check"
				check.Size = UDim2.new(0, 20, 1, 0)
				check.Position = UDim2.new(1, -28, 0, 0)
				check.BackgroundTransparency = 1
				check.Text = "✓"
				check.TextColor3 = M3.OnPrimary
				check.TextSize = 14
				check.Font = Enum.Font.GothamBold
				check.Visible = false
				check.ZIndex = 104
				check.Parent = row

				local selected = false
				local function applySelected(state)
					selected = state
					if state then
						selectedCopyPlayers[plr] = true
						tween(row, {BackgroundColor3 = M3.Accent, BackgroundTransparency = 0}, 0.12)
						tween(rowStroke, {Color = M3.Accent, Transparency = 0.3}, 0.12)
						tween(nameLabel, {TextColor3 = M3.OnPrimary}, 0.12)
						tween(userLabel, {TextColor3 = Color3.fromRGB(86, 90, 98)}, 0.12)
						check.Visible = true
					else
						selectedCopyPlayers[plr] = nil
						tween(row, {BackgroundColor3 = M3.SurfaceHigh, BackgroundTransparency = 0.4}, 0.15)
						tween(rowStroke, {Color = M3.GlassLine, Transparency = 0.9}, 0.15)
						tween(nameLabel, {TextColor3 = M3.OnSurface}, 0.15)
						tween(userLabel, {TextColor3 = M3.OnSurfaceFaint}, 0.15)
						check.Visible = false
					end
					updateCopySaveBtn()
				end

				row.MouseEnter:Connect(function()
					if selected then return end
					tween(row, {BackgroundTransparency = 0.22}, 0.1)
				end)
				row.MouseLeave:Connect(function()
					if selected then return end
					tween(row, {BackgroundTransparency = 0.4}, 0.15)
				end)
				row.MouseButton1Click:Connect(function()
					applySelected(not selected)
				end)
			end
		end
		if others == 0 then
			local empty = Instance.new("TextLabel")
			empty.Name = "EmptyLabel"
			empty.Size = UDim2.new(1, 0, 0, 60)
			empty.BackgroundTransparency = 1
			empty.Text = "No other players here"
			empty.TextColor3 = M3.OnSurfaceFaint
			empty.TextSize = 11
			empty.Font = Enum.Font.Gotham
			empty.ZIndex = 103
			empty.Parent = playerList
		end
	end

	setModalTab = function(tab)
		if tab == "save" then
			tween(tabIndicator, {Position = UDim2.new(0, 2, 0, 2)}, 0.14)
			btnTabSave.TextColor3 = M3.OnPrimary
			btnTabCopy.TextColor3 = M3.OnSurfaceVariant
			inputWrap.Visible = true
			playerList.Visible = false
			btnSaveModal.Visible = true
			selectedCopyPlayers = {}
			updateCopySaveBtn()
		else
			tween(tabIndicator, {Position = UDim2.new(0.5, 2, 0, 2)}, 0.14)
			btnTabCopy.TextColor3 = M3.OnPrimary
			btnTabSave.TextColor3 = M3.OnSurfaceVariant
			inputWrap.Visible = false
			playerList.Visible = true
			btnSaveModal.Visible = true
			selectedCopyPlayers = {}
			populatePlayerList()
			updateCopySaveBtn()
		end
	end

	btnTabSave.MouseButton1Click:Connect(function() setModalTab("save") end)
	btnTabCopy.MouseButton1Click:Connect(function() setModalTab("copy") end)
	openModal = function(mode, prefillName)
		modalMode = mode or "save"
		modalRenameTarget = prefillName
		if modalMode == "rename" then
			modalTitle.Text = "Rename avatar"
			tabBar.Visible = false
			modalGradientLine.Visible = false
			inputWrap.Position = UDim2.new(0, 20, 0, 52)
			inputWrap.Visible = true
			playerList.Visible = false
			btnSaveModal.Visible = true
			btnSaveModal.Text = "Rename"
			modalBox.Size = UDim2.new(0, 300, 0, 156)
			modalBox.Position = UDim2.new(0.5, -150, 0.5, -78)
			modalInput.Text = prefillName or ""
		else
			modalTitle.Text = "New avatar"
			tabBar.Visible = true
			modalGradientLine.Visible = true
			inputWrap.Position = UDim2.new(0, 20, 0, 94)
			btnSaveModal.Text = "Save"
			modalBox.Size = UDim2.new(0, 300, 0, 286)
			modalBox.Position = UDim2.new(0.5, -150, 0.5, -143)
			modalInput.Text = ""
			setModalTab("save")
		end
		modal.Visible = true
		animateModalOpen()
		if modalMode ~= "rename" then modalInput:CaptureFocus() end
	end

	closeModal = function()
		modal.Visible = false
	end

	btnCancelModal.MouseButton1Click:Connect(closeModal)
	modalBgBtn.MouseButton1Click:Connect(closeModal)

	local function attemptSave()
		if playerList.Visible and modalMode ~= "rename" then
			saveSelectedPlayers()
			return
		end
		local name = modalInput.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if name == "" then
			modalInput:CaptureFocus()
			return
		end

		if modalMode == "rename" then
			local oldName = modalRenameTarget
			if name == oldName then
				closeModal()
				return
			end
			if savedAvatars[name] then
				modalInput:CaptureFocus()
				return
			end
			local data = savedAvatars[oldName]
			if not data then
				closeModal()
				return
			end
			savedAvatars[oldName] = nil
			data.savedName = name
			savedAvatars[name] = data
			if settings.autoloadName == oldName then
				settings.autoloadName = name
				saveSettings()
			end
			if hasFS() then saveFile(SAVES_PATH, savedAvatars) end
			refreshAutoloadLabel()
			refreshGrid()
			closeModal()
			return
		end

		if savedAvatars[name] then
			modalInput:CaptureFocus()
			return
		end
		if SaveAvatarWithName(name) then
			refreshGrid()
			closeModal()
		end
	end

	btnSaveModal.MouseButton1Click:Connect(attemptSave)
	modalInput.FocusLost:Connect(function(enterPressed)
		if enterPressed then attemptSave() end
	end)

	local optionsMenu = Instance.new("Frame")
	optionsMenu.Name = "OptionsMenu"
	optionsMenu.Size = UDim2.new(0, 148, 0, 120)
	optionsMenu.BackgroundColor3 = M3.Surface
	optionsMenu.BackgroundTransparency = 0
	optionsMenu.BorderSizePixel = 0
	optionsMenu.Visible = false
	optionsMenu.ZIndex = 200
	optionsMenu.Parent = mf
	optionsMenu.ClipsDescendants = true
	corner(12, optionsMenu)
	stroke(M3.GlassLine, 1, optionsMenu, 0.8)

	local optionsGrad = Instance.new("UIGradient")
	optionsGrad.Name = "MenuGrad"
	optionsGrad.Rotation = 90
	optionsGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(66, 70, 78)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(48, 51, 58)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(36, 38, 44)),
	})
	optionsGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.02),
		NumberSequenceKeypoint.new(1, 0.18),
	})
	optionsGrad.Parent = optionsMenu

	local optionsScale = Instance.new("UIScale")
	optionsScale.Name = "AnimScale"
	optionsScale.Parent = optionsMenu

	local optionsMenuPad = Instance.new("UIPadding")
	optionsMenuPad.PaddingTop = UDim.new(0, 7)
	optionsMenuPad.PaddingBottom = UDim.new(0, 7)
	optionsMenuPad.PaddingLeft = UDim.new(0, 6)
	optionsMenuPad.PaddingRight = UDim.new(0, 6)
	optionsMenuPad.Parent = optionsMenu

	local optionsMenuBg = Instance.new("TextButton")
	optionsMenuBg.Name = "OptionsMenuBg"
	optionsMenuBg.Size = UDim2.new(1, 0, 1, 0)
	optionsMenuBg.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
	optionsMenuBg.BackgroundTransparency = 0.82
	optionsMenuBg.Text = ""
	optionsMenuBg.AutoButtonColor = false
	optionsMenuBg.ZIndex = 150
	optionsMenuBg.Visible = false
	optionsMenuBg.Parent = mf

	local optionsMenuToken = 0
	local optionsScaleTween = nil
	local function animateOptionsScale(target, time)
		if optionsScaleTween then optionsScaleTween:Cancel() end
		optionsScaleTween = TweenService:Create(
			optionsScale,
			TweenInfo.new(time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{Scale = target}
		)
		optionsScaleTween:Play()
	end

	local function closeOptionsMenu(instant)
		optionsMenuToken = optionsMenuToken + 1
		local token = optionsMenuToken
		optionsMenuBg.Visible = false
		if resetDeleteConfirm then resetDeleteConfirm() end
		if instant then
			if optionsScaleTween then optionsScaleTween:Cancel() end
			optionsMenu.Visible = false
			optionsMenu.BackgroundTransparency = 0
			optionsScale.Scale = 1
			return
		end
		animateOptionsScale(0.92, 0.12)
		tween(optionsMenu, {BackgroundTransparency = 0.3}, 0.12)
		task.delay(0.13, function()
			if token == optionsMenuToken then
				optionsMenu.Visible = false
				optionsMenu.BackgroundTransparency = 0
				optionsScale.Scale = 1
			end
		end)
	end
	optionsMenuBg.MouseButton1Click:Connect(function()
		closeOptionsMenu()
	end)

	local optionsMenuLayout = Instance.new("UIListLayout")
	optionsMenuLayout.Padding = UDim.new(0, 2)
	optionsMenuLayout.SortOrder = Enum.SortOrder.LayoutOrder
	optionsMenuLayout.Parent = optionsMenu

	local optionsMenuTarget = nil

	local function makeMenuOption(text, color, order)
		local btn = Instance.new("TextButton")
		btn.Name = "Opt_" .. text
		btn.Size = UDim2.new(1, 0, 0, 34)
		btn.BackgroundColor3 = M3.SurfaceHighest
		btn.BackgroundTransparency = 1
		btn.Text = text
		btn.TextColor3 = color
		btn.TextSize = 12
		btn.Font = Enum.Font.GothamMedium
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.AutoButtonColor = false
		btn.ZIndex = 201
		btn.LayoutOrder = order
		btn.Parent = optionsMenu
		corner(8, btn)
		local btnStroke = stroke(M3.GlassLine, 1, btn, 1)

		local btnPad = Instance.new("UIPadding")
		btnPad.PaddingLeft = UDim.new(0, 12)
		btnPad.Parent = btn

		btn.MouseEnter:Connect(function()
			tween(btn, {BackgroundTransparency = 0.72}, 0.1)
			tween(btnStroke, {Transparency = 0.88}, 0.1)
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, {BackgroundTransparency = 1}, 0.15)
			tween(btnStroke, {Transparency = 1}, 0.15)
		end)
		return btn
	end

	local btnMenuUpdate = makeMenuOption("Update", M3.OnSurface, 1)
	local btnMenuRename = makeMenuOption("Rename", M3.OnSurface, 2)
	local btnMenuDelete = makeMenuOption("Delete", M3.Error, 3)

	btnMenuUpdate.MouseButton1Click:Connect(function()
		if not optionsMenuTarget then return end
		local target = optionsMenuTarget
		closeOptionsMenu(true)
		if UpdateAvatar(target) then
			refreshGrid()
		end
	end)

	btnMenuRename.MouseButton1Click:Connect(function()
		closeOptionsMenu(true)
		if optionsMenuTarget then
			openModal("rename", optionsMenuTarget)
		end
	end)

	local deleteConfirmTarget = nil
	local deleteConfirmTimer = nil
	resetDeleteConfirm = function()
		deleteConfirmTarget = nil
		if deleteConfirmTimer then
			task.cancel(deleteConfirmTimer)
			deleteConfirmTimer = nil
		end
		btnMenuDelete.Text = "Delete"
		btnMenuDelete.TextColor3 = M3.Error
	end

	btnMenuDelete.MouseButton1Click:Connect(function()
		if not optionsMenuTarget then return end
		if deleteConfirmTarget ~= optionsMenuTarget then
			deleteConfirmTarget = optionsMenuTarget
			btnMenuDelete.Text = "Confirm?"
			btnMenuDelete.TextColor3 = Color3.fromRGB(255, 150, 150)
			if deleteConfirmTimer then task.cancel(deleteConfirmTimer) end
			deleteConfirmTimer = task.delay(2.5, resetDeleteConfirm)
			return
		end
		resetDeleteConfirm()
		closeOptionsMenu(true)
		local deletedName = optionsMenuTarget
		DeleteAvatar(deletedName)
		if settings.autoloadName == deletedName then
			settings.autoloadName = ""
			saveSettings()
		end
		refreshAutoloadLabel()
		refreshGrid()
	end)

	openOptionsMenu = function(name, anchorBtn)
		optionsMenuTarget = name
		local menuHeight = 120
		optionsMenu.Size = UDim2.new(0, 148, 0, menuHeight)

		local absPos = anchorBtn.AbsolutePosition
		local mfPos = mf.AbsolutePosition
		local scale = math.max(uiScale.Scale, 0.01)
		local localW = mf.Size.X.Offset
		local localH = mf.Size.Y.Offset
		local anchorX = (absPos.X - mfPos.X) / scale
		local anchorY = (absPos.Y - mfPos.Y) / scale
		local anchorH = anchorBtn.AbsoluteSize.Y / scale
		local x = math.clamp(anchorX, 8, localW - 156)
		local y = math.clamp(anchorY + anchorH + 4, 8, localH - menuHeight - 8)
		optionsMenu.Position = UDim2.new(0, x, 0, y)
		optionsMenuToken = optionsMenuToken + 1
		optionsMenu.Visible = true
		optionsMenu.BackgroundTransparency = 0.28
		tween(optionsMenu, {BackgroundTransparency = 0}, 0.16)
		optionsMenuBg.Visible = true
		optionsScale.Scale = 0.92
		animateOptionsScale(1, 0.18)
	end

	local loading = Instance.new("CanvasGroup")
	loading.Name = "LoadingScreen"
	loading.Size = UDim2.new(1, 0, 1, 0)
	loading.BackgroundColor3 = M3.Background
	loading.BackgroundTransparency = 0
	loading.BorderSizePixel = 0
	loading.GroupTransparency = 0
	loading.Active = true
	loading.ZIndex = 900
	loading.Parent = sg

	local loadingGrad = Instance.new("UIGradient")
	loadingGrad.Rotation = 135
	loadingGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(148, 152, 160)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(106, 110, 118)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(66, 70, 78)),
	})
	loadingGrad.Parent = loading
	table.insert(animatedGradients, {
		grad = loadingGrad,
		speed = 0.5,
		phase = 0,
	})

	local loadingBlocker = Instance.new("TextButton")
	loadingBlocker.Name = "Blocker"
	loadingBlocker.Size = UDim2.new(1, 0, 1, 0)
	loadingBlocker.BackgroundTransparency = 1
	loadingBlocker.BorderSizePixel = 0
	loadingBlocker.Text = ""
	loadingBlocker.AutoButtonColor = false
	loadingBlocker.ZIndex = 901
	loadingBlocker.Parent = loading

	local loadingTitle = Instance.new("TextLabel")
	loadingTitle.Name = "Title"
	loadingTitle.AnchorPoint = Vector2.new(0.5, 0.5)
	loadingTitle.Size = UDim2.new(1, 0, 0, 64)
	loadingTitle.Position = UDim2.new(0.5, 0, 0.5, -72)
	loadingTitle.BackgroundTransparency = 1
	loadingTitle.Text = "cupcake"
	loadingTitle.TextColor3 = M3.Accent
	loadingTitle.TextSize = 52
	loadingTitle.Font = Enum.Font.GothamBlack
	loadingTitle.TextScaled = true
	loadingTitle.ZIndex = 903
	loadingTitle.Parent = loading

	local loadingTitleStroke = Instance.new("UIStroke")
	loadingTitleStroke.Color = Color3.fromRGB(20, 22, 26)
	loadingTitleStroke.Thickness = 2
	loadingTitleStroke.Transparency = 0.35
	loadingTitleStroke.Parent = loadingTitle

	local loadingTitleSize = Instance.new("UITextSizeConstraint")
	loadingTitleSize.MaxTextSize = 52
	loadingTitleSize.MinTextSize = 18
	loadingTitleSize.Parent = loadingTitle

	local buttonRow = Instance.new("Frame")
	buttonRow.Name = "Buttons"
	buttonRow.AnchorPoint = Vector2.new(0.5, 0.5)
	buttonRow.Size = UDim2.new(0, 280, 0, 40)
	buttonRow.Position = UDim2.new(0.5, 0, 0.5, -6)
	buttonRow.BackgroundTransparency = 1
	buttonRow.ZIndex = 903
	buttonRow.Parent = loading

	local loadBtn = Instance.new("TextButton")
	loadBtn.Name = "Load"
	loadBtn.Size = UDim2.new(0, 134, 1, 0)
	loadBtn.Position = UDim2.new(0, 0, 0, 0)
	loadBtn.BackgroundColor3 = M3.Primary
	loadBtn.BorderSizePixel = 0
	loadBtn.Text = "Load"
	loadBtn.TextColor3 = M3.OnPrimary
	loadBtn.TextSize = 14
	loadBtn.Font = Enum.Font.GothamBold
	loadBtn.AutoButtonColor = false
	loadBtn.ZIndex = 904
	loadBtn.Parent = buttonRow
	corner(10, loadBtn)
	stroke(M3.GlassLine, 1, loadBtn, 0.55)

	local exitBtn = Instance.new("TextButton")
	exitBtn.Name = "Exit"
	exitBtn.Size = UDim2.new(0, 134, 1, 0)
	exitBtn.Position = UDim2.new(1, -134, 0, 0)
	exitBtn.BackgroundColor3 = M3.SurfaceHigh
	exitBtn.BorderSizePixel = 0
	exitBtn.Text = "Exit"
	exitBtn.TextColor3 = M3.OnSurface
	exitBtn.TextSize = 14
	exitBtn.Font = Enum.Font.GothamBold
	exitBtn.AutoButtonColor = false
	exitBtn.ZIndex = 904
	exitBtn.Parent = buttonRow
	corner(10, exitBtn)
	stroke(M3.GlassLine, 1, exitBtn, 0.85)

	loadBtn.MouseEnter:Connect(function() tween(loadBtn, {BackgroundColor3 = M3.PrimaryHover}, 0.12) end)
	loadBtn.MouseLeave:Connect(function() tween(loadBtn, {BackgroundColor3 = M3.Primary}, 0.15) end)
	exitBtn.MouseEnter:Connect(function() tween(exitBtn, {BackgroundColor3 = M3.SurfaceHighest}, 0.12) end)
	exitBtn.MouseLeave:Connect(function() tween(exitBtn, {BackgroundColor3 = M3.SurfaceHigh}, 0.15) end)

	local loadingFooter = Instance.new("TextLabel")
	loadingFooter.Name = "Footer"
	loadingFooter.AnchorPoint = Vector2.new(0.5, 0.5)
	loadingFooter.Size = UDim2.new(1, 0, 0, 18)
	loadingFooter.Position = UDim2.new(0.5, 0, 0.5, 42)
	loadingFooter.BackgroundTransparency = 1
	loadingFooter.Text = "Update date: " .. UPDATE_DATE
	loadingFooter.TextColor3 = M3.OnSurface
	loadingFooter.TextSize = 11
	loadingFooter.Font = Enum.Font.Gotham
	loadingFooter.ZIndex = 903
	loadingFooter.Parent = loading

	local linkBox = Instance.new("TextBox")
	linkBox.Name = "Link"
	linkBox.AnchorPoint = Vector2.new(0.5, 0.5)
	linkBox.Size = UDim2.new(0, 300, 0, 32)
	linkBox.Position = UDim2.new(0.5, 0, 0.5, 78)
	linkBox.BackgroundColor3 = M3.Surface
	linkBox.BorderSizePixel = 0
	linkBox.Text = GITHUB_URL
	linkBox.TextColor3 = M3.OnSurface
	linkBox.TextSize = 12
	linkBox.Font = Enum.Font.Gotham
	linkBox.TextXAlignment = Enum.TextXAlignment.Center
	linkBox.ClearTextOnFocus = false
	linkBox.TextEditable = true
	linkBox.ZIndex = 904
	linkBox.Parent = loading
	corner(8, linkBox)
	stroke(M3.GlassLine, 1, linkBox, 0.82)
	linkBox.Focused:Connect(function()
		task.defer(function()
			linkBox.SelectionStart = 1
			linkBox.CursorPosition = #GITHUB_URL + 1
		end)
	end)
	linkBox.FocusLost:Connect(function()
		linkBox.Text = GITHUB_URL
	end)

	local loadingClosing = false
	local function closeLoading()
		if loadingClosing then return end
		loadingClosing = true
		tween(loading, {GroupTransparency = 1}, 0.28)
		task.delay(0.3, function()
			if loading.Parent then
				loading.Visible = false
				loading.GroupTransparency = 0
			end
		end)
	end

	loadBtn.MouseButton1Click:Connect(function()
		isGuiOpen = true
		if currentGui then
			local main = currentGui:FindFirstChild("MainWindow")
			if main then main.Visible = true end
			local bd = currentGui:FindFirstChild("Backdrop")
			if bd then
				bd.Visible = true
				bd.BackgroundTransparency = menuTintTransparency()
			end
		end
		unlockMouse()
		hideOtherUis()
		setWorldBlur(true)
		setFov(MENU_FOV)
		if settings.snow then pcall(startSnow) end
		updateCircle()
		closeLoading()
	end)

	exitBtn.MouseButton1Click:Connect(function()
		unloadScript()
	end)

	if settings.skipWelcome then
		loading.Visible = false
		loading.GroupTransparency = 0
	end

	pcall(function() selectTab("avatars", 0, true) end)
	sg.Parent = pg
	currentGui = sg
	if oldGui then oldGui:Destroy() end
	pcall(refreshGrid)
	hookClicks(sg)
	hookClicks(circleGui)

	local uiAnimConn = RunService.RenderStepped:Connect(function()
		if not isGuiOpen then return end
		local t = os.clock()
		for _, item in ipairs(animatedGradients) do
			item.grad.Offset = Vector2.new(math.sin(t * item.speed + item.phase) * 0.55, 0)
		end
	end)
	_G.CupcakeUiAnimConnection = uiAnimConn

	return sg
end

local function isAnyTextBoxFocused()
	for _, obj in pairs(player:GetDescendants()) do
		if obj:IsA("TextBox") and obj:IsFocused() then return true end
	end
	return false
end

toggleConn = UserInputService.InputBegan:Connect(function(input, gp)
	if myRunId ~= _G.CupcakeRunId then return end

	if rebindCallback then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local cb = rebindCallback
			rebindCallback = nil
			cb(input.KeyCode)
		end
		return
	end
	if gp then return end
	if isAnyTextBoxFocused() then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	local key = input.KeyCode
	local wanted = settings.toggleKey
	if key.Name == wanted
		or (wanted == "Zero" and key == Enum.KeyCode.KeypadZero) then
		toggleGui()
	end
end)

loadSettings()

if hasFS() then
	savedAvatars = loadFile(SAVES_PATH) or {}
end

recoverHiddenUis()

do
	if not player.Character then
		pcall(function() player.CharacterAdded:Wait() end)
	end
	local char = player.Character
	if char then
		pcall(function() char:WaitForChild("Humanoid", 10) end)
		pcall(function() recoverHiddenAvatar(char) end)
		pcall(function() restoreOriginalAnimations(char) end)
	end
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "CupcakeFollower" then
			pcall(function() obj:Destroy() end)
		end
	end
	if char then
		originalAvatarData = CaptureAvatarData(char)
	end
end

recoverHiddenUis()
makeGui()

if settings.autoloadName ~= "" then
	local autoloadData = savedAvatars[settings.autoloadName]
	if autoloadData then
		lastAppliedAvatarData = autoloadData
		pcall(LoadAvatarFromData, autoloadData)
	end
end

if isGuiOpen and currentGui then
	unlockMouse()
	hideOtherUis()
	local bdInit = currentGui:FindFirstChild("Backdrop")
	if bdInit then
		bdInit.Visible = true
		bdInit.BackgroundTransparency = menuTintTransparency()
	end
	setWorldBlur(true)
	setFov(MENU_FOV)
	if startSnow and settings.snow then pcall(startSnow) end
	updateCircle()
end

local function reapplyOnRespawn(char)
	if myRunId ~= _G.CupcakeRunId then return end
	if not settings.keepOnRespawn or not lastAppliedAvatarData then return end

	local humanoid = char:WaitForChild("Humanoid", 10)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then
		return
	end

	task.wait(1)

	local dataToApply = lastAppliedAvatarData
	pcall(function()
		LoadAvatarFromData(dataToApply)
	end)
end

respawnConn = player.CharacterAdded:Connect(reapplyOnRespawn)
print("github test2")
