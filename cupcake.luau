
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
local RELOAD_URL = ""
local CATALOG_PLACE_ID = 7041939546

local settings = {
	keepOnRespawn = false,
	circleBtnPos = {X = 1, Y = 1, OffsetX = -54, OffsetY = -54},
	device = UserInputService.TouchEnabled and "Mobile" or "PC",
}


_G.CupcakeRunId = ((_G.CupcakeRunId or 0) + 1) % 1000000
local myRunId = _G.CupcakeRunId

local M3 = {
	Background       = Color3.fromRGB(15, 16, 20),
	Surface          = Color3.fromRGB(24, 26, 31),
	SurfaceHigh      = Color3.fromRGB(33, 36, 42),
	SurfaceHighest   = Color3.fromRGB(46, 50, 58),
	Primary          = Color3.fromRGB(250, 250, 252),
	OnPrimary        = Color3.fromRGB(20, 21, 26),
	PrimaryHover     = Color3.fromRGB(226, 228, 234),
	Accent           = Color3.fromRGB(126, 156, 255),
	OnSurface        = Color3.fromRGB(241, 242, 246),
	OnSurfaceVariant = Color3.fromRGB(150, 155, 166),
	OnSurfaceFaint   = Color3.fromRGB(104, 109, 121),
	GlassLine        = Color3.fromRGB(255, 255, 255),
	GlassTint        = Color3.fromRGB(180, 195, 220),
	GlassGradientTop = Color3.fromRGB(255, 255, 255),
	GlassGradientBot = Color3.fromRGB(200, 210, 230),
	OutlineVariant   = Color3.fromRGB(72, 77, 89),
	Backdrop         = Color3.fromRGB(104, 107, 115),
	Error            = Color3.fromRGB(255, 96, 96),
	ErrorContainer   = Color3.fromRGB(64, 34, 38),
	Success          = Color3.fromRGB(98, 205, 132),
}

local savedAvatars = {}
local currentGui = nil
local circleGuiRef = nil
local isGuiOpen = true
local showToastRef = nil
local lastAppliedAvatarData = nil

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
		if data.device == "Mobile" or data.device == "PC" then
			settings.device = data.device
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
    local scale = math.min(vp.X / baseW, vp.Y / baseH) * 0.92
    if detectDevice() then
        scale = math.min(scale, 0.78)
    end
    return math.clamp(scale, 0.5, 1.0)
end

local function serializePart(part)
    local d = {
        Name = part.Name,
        Size = {part.Size.X, part.Size.Y, part.Size.Z},
        Color = {part.Color.R, part.Color.G, part.Color.B},
        Material = tostring(part.Material),
        Transparency = part.Transparency,
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
        Transparency = decal.Transparency,
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
    return {_class = "WrapTarget", Name = wt.Name, Stiffness = wt.Stiffness}
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
    local wt = Instance.new("WrapTarget")
    wt.Name = wdata.Name or "WrapTarget"
    if wdata.Stiffness ~= nil then wt.Stiffness = wdata.Stiffness end
    local ok = pcall(function() wt.Parent = parent end)
    if not ok then wt:Destroy() return nil end
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

local function applyHipHeight(value)
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.HipHeight = math.clamp(value, 0, 50)
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

local function buildDescriptionInstance(descData)
    local desc = Instance.new("HumanoidDescription")
    if not descData then return desc end
    for prop, val in pairs(descData) do
        if prop ~= "accessories" and val ~= nil then
            pcall(function() desc[prop] = val end)
        end
    end
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
            if part:IsA("Attachment") and part.Name == handleAtt.Name then
                charAtt = part
                break
            end
        end
        if charAtt then
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

local R6_SHOULDER_CFRAMES = {
    RightShoulderAttachment = CFrame.new(1, 0.5, 0),
    LeftShoulderAttachment = CFrame.new(-1, 0.5, 0),
}

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

local function cupR6FindCharacterAttachment(character, name)
    if not character or not name then return nil, nil end
    local partName = R6_ATTACH_TO_PART[name]
    if partName then
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            local att = cupR6FindNamedAttachment(part, name)
            if att then return att, part end
        end
    end
    for _, part in pairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            local att = cupR6FindNamedAttachment(part, name)
            if att then return att, part end
        end
    end
    return nil, nil
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

local function cupR6EnsureAttachment(character, name)
    if not character or not name then return nil end
    local att, _ = cupR6FindCharacterAttachment(character, name)
    if att then return att end
    local shoulderCF = R6_SHOULDER_CFRAMES[name]
    if not shoulderCF then return nil end
    local partName = R6_ATTACH_TO_PART[name]
    local part = partName and character:FindFirstChild(partName) or nil
    if not part or not part:IsA("BasePart") then return nil end
    local created = Instance.new("Attachment")
    created.Name = name
    created.CFrame = shoulderCF
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

local function cupR6ChooseAttachment(accessory, character)
    local handle = accessory and accessory:FindFirstChild("Handle")
    if not handle then return nil, nil, nil end
    local sources = {}
    for _, child in pairs(handle:GetChildren()) do
        if child:IsA("Attachment") then
            sources[child.Name] = child
        end
    end
    if next(sources) == nil then return nil, nil, nil end

    local candidates = {}
    for name, source in pairs(sources) do
        local target, part = cupR6FindCharacterAttachment(character, name)
        if target and part then
            candidates[name] = {source = source, target = target, part = part}
        end
    end

    if cupR6GetAccessoryType(accessory) == Enum.AccessoryType.Shoulder
        or candidates.RightShoulderAttachment or candidates.LeftShoulderAttachment then
        local right = candidates.RightShoulderAttachment
        if right and (cupR6NameSuggestsRight(accessory.Name) or not candidates.LeftShoulderAttachment) then
            return right.source, right.target, right.part
        end
        local left = candidates.LeftShoulderAttachment
        if left and (cupR6NameSuggestsLeft(accessory.Name) or not candidates.RightShoulderAttachment) then
            return left.source, left.target, left.part
        end
    end

    for _, name in ipairs(R6_ATTACH_PRIORITY) do
        local hit = candidates[name]
        if hit then
            return hit.source, hit.target, hit.part
        end
    end
    return nil, nil, nil
end

local function cupR6WeldAccessory(character, accessory)
    local handle = accessory and accessory:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then
        return false
    end
    local source, target, part = cupR6ChooseAttachment(accessory, character)
    if not source then
        for name, src in pairs((function()
            local t = {}
            for _, child in pairs(handle:GetChildren()) do
                if child:IsA("Attachment") then t[child.Name] = child end
            end
            return t
        end)()) do
            target = cupR6EnsureAttachment(character, name)
            if target then
                source = src
                part = target.Parent
                break
            end
        end
    end
    if not source or not target or not part then
        return false
    end

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

local function cupR6ApplyBodyFromDescription(character, humanoid, data)
    if not character or not humanoid then return false end
    if not data or type(data.description) ~= "table" then return false end
    local desc = buildDescriptionInstance(data.description)
    pcall(function() desc:SetAccessories({}, true) end)
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
    local deadline = os.clock() + 12
    while not done and os.clock() < deadline do
        task.wait()
    end
    if not done or not model then return false end
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
                        if not (partName == "Head" and child.Name == "face") then
                            pcall(function() child:Destroy() end)
                        end
                    end
                end
                for _, child in pairs(src:GetChildren()) do
                    if child:IsA("SpecialMesh") or child:IsA("Decal") or child:IsA("Texture") then
                        if not (partName == "Head" and child.Name == "face") then
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
    return applied
end

local function buildPreviewRig(data)
    local desc = buildDescriptionInstance(data.description)
    local rigType = (tostring(data.rigType or ""):find("R6") ~= nil) and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15
    local ok, model = pcall(function()
        return Players:CreateHumanoidModelFromDescription(desc, rigType)
    end)
    if not ok or not model then return nil end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then model:Destroy() return nil end
    local isR6 = (humanoid.RigType == Enum.HumanoidRigType.R6)

    if not isR6 and data.parts then
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
                if pdata.Color then pcall(function() existing.Color = deserializeColor(pdata.Color) end) end
                if pdata.Material then pcall(function() local m = cupEnum(Enum.Material, pdata.Material); if m then existing.Material = m end end) end
                if pdata.Transparency ~= nil then existing.Transparency = pdata.Transparency end
                if pdata.Reflectance ~= nil then existing.Reflectance = pdata.Reflectance end
                if pdata.CastShadow ~= nil then existing.CastShadow = pdata.CastShadow end

                if pdata.children then
                    if partName == "Head" then
                        for _, child in pairs(existing:GetChildren()) do
                            if child:IsA("Decal") and child.Name ~= "face" then child:Destroy()
                            elseif child:IsA("Texture") then child:Destroy()
                            elseif child:IsA("DataModelMesh") then child:Destroy()
                            elseif child:IsA("SurfaceAppearance") then child:Destroy()
                            elseif child:IsA("WrapTarget") then child:Destroy() end
                        end
                    else
                        for _, child in pairs(existing:GetChildren()) do
                            if child:IsA("Decal") or child:IsA("Texture") or child:IsA("DataModelMesh") or child:IsA("SurfaceAppearance") or child:IsA("WrapTarget") then
                                child:Destroy()
                            end
                        end
                    end
                    for _, cdata in pairs(pdata.children) do
                        if cdata._class == "SpecialMesh" or cdata._class == "BlockMesh" or cdata._class == "CylinderMesh" then buildMesh(existing, cdata)
                        elseif cdata._class == "Decal" or cdata._class == "Texture" then
                            if not (partName == "Head" and cdata.Name == "face") then buildDecal(existing, cdata) end
                        elseif cdata._class == "Attachment" then
                            local att = existing:FindFirstChild(cdata.Name)
                            if att and att:IsA("Attachment") then
                                if cdata.Position then att.Position = vec3(cdata.Position) end
                                if cdata.Orientation then att.Orientation = vec3(cdata.Orientation) end
                            else buildAttachment(existing, cdata) end
                        elseif cdata._class == "SurfaceAppearance" then buildSurfaceAppearance(existing, cdata)
                        elseif cdata._class == "WrapTarget" then buildWrapTarget(existing, cdata) end
                    end
                end
            end
        end
    end

    if data.face then
        local head = model:FindFirstChild("Head")
        if head then
            for _, child in pairs(head:GetChildren()) do
                if child:IsA("Decal") and child.Name == "face" then child:Destroy() end
            end
            local face = Instance.new("Decal")
            face.Name = "face"
            face.Texture = data.face
            face.Face = Enum.NormalId.Front
            face.Parent = head
        end
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
                handle.Size = adata.handle.Size and vec3(adata.handle.Size) or Vector3.new(1,1,1)
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
            weldAccessory(model, acc)
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
        local props = {"Head", "LeftArm", "LeftLeg", "RightArm", "RightLeg", "Torso", "Face", "Shirt", "Pants", "GraphicTShirt", "HeadColor", "LeftArmColor", "LeftLegColor", "RightArmColor", "RightLegColor", "TorsoColor", "BodyTypeScale", "BodyDepthScale", "BodyHeightScale", "BodyProportionScale", "BodyWidthScale", "HeadScale", "IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "SwimAnimation"}
        for _, prop in ipairs(props) do
            pcall(function() data.description[prop] = desc[prop] end)
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
                elseif child:IsA("Decal") or child:IsA("Texture") then table.insert(pdata.children, serializeDecal(child))
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
        local face = head:FindFirstChild("face")
        if face and face:IsA("Decal") then data.face = face.Texture end
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

local function LoadAvatarFromData(data)
    if not data then return end

    if data.description and data.description.accessories then
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
    local r6BodyNote = ""

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

    if isR6 and data.description then
        pcall(function()
            if cupR6ApplyBodyFromDescription(char, humanoid, data) then
                r6BodyNote = "bodymodel"
            end
        end)
    end

    if data.parts then
        for partName, pdata in pairs(data.parts) do
            local existing = char:FindFirstChild(partName)
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
                if pdata.Color then pcall(function() existing.Color = deserializeColor(pdata.Color) end) end
                if pdata.Material then pcall(function() local m = cupEnum(Enum.Material, pdata.Material); if m then existing.Material = m end end) end
                if pdata.Transparency ~= nil then existing.Transparency = pdata.Transparency end
                if pdata.Reflectance ~= nil then existing.Reflectance = pdata.Reflectance end
                if pdata.CastShadow ~= nil then existing.CastShadow = pdata.CastShadow end

                if pdata.children then
                    if partName == "Head" then
                        for _, child in pairs(existing:GetChildren()) do
                            if child:IsA("Decal") and child.Name ~= "face" then child:Destroy()
                            elseif child:IsA("Texture") then child:Destroy()
                            elseif child:IsA("DataModelMesh") then child:Destroy()
                            elseif child:IsA("SurfaceAppearance") then child:Destroy()
                            elseif child:IsA("WrapTarget") then child:Destroy() end
                        end
                    else
                        for _, child in pairs(existing:GetChildren()) do
                            if child:IsA("Decal") or child:IsA("Texture") or child:IsA("DataModelMesh") or child:IsA("SurfaceAppearance") or child:IsA("WrapTarget") then
                                child:Destroy()
                            end
                        end
                    end
                    for _, cdata in pairs(pdata.children) do
                        if cdata._class == "SpecialMesh" or cdata._class == "BlockMesh" or cdata._class == "CylinderMesh" then buildMesh(existing, cdata)
                        elseif cdata._class == "Decal" or cdata._class == "Texture" then
                            if not (partName == "Head" and cdata.Name == "face") then buildDecal(existing, cdata) end
                        elseif cdata._class == "Attachment" then
                            local att = existing:FindFirstChild(cdata.Name)
                            if att and att:IsA("Attachment") then
                                if cdata.Position then att.Position = vec3(cdata.Position) end
                                if cdata.Orientation then att.Orientation = vec3(cdata.Orientation) end
                            else buildAttachment(existing, cdata) end
                        elseif cdata._class == "SurfaceAppearance" then buildSurfaceAppearance(existing, cdata)
                        elseif cdata._class == "WrapTarget" then buildWrapTarget(existing, cdata) end
                    end
                end
            end
        end
    end

    if isR6 then
        cupR6ApplyCharacterMeshes(char, data.characterMeshes)
        if type(data.characterMeshes) == "table" and next(data.characterMeshes) ~= nil then
            r6BodyNote = r6BodyNote .. (r6BodyNote ~= "" and "+" or "") .. "savedMeshes(" .. #data.characterMeshes .. ")"
        end
    end

    if data.face then
        local head = char:FindFirstChild("Head")
        if head then
            for _, child in pairs(head:GetChildren()) do
                if child:IsA("Decal") and child.Name == "face" then child:Destroy() end
            end
            local face = Instance.new("Decal")
            face.Name = "face"
            face.Texture = data.face
            face.Face = Enum.NormalId.Front
            face.Parent = head
        end
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

    if data.description and data.description.accessories then
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
                    accessory.Parent = char
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

    if data.accessoriesManual and (loadedCount == 0 or failedCount > 0) then
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

            if loadedNames[adata.Name] then
                continue
            end
            if adata.handle and adata.handle.MeshId and adata.handle.MeshId ~= "" and loadedMeshes[adata.handle.MeshId] then
                continue
            end

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
                handle.Size = adata.handle.Size and vec3(adata.handle.Size) or Vector3.new(1,1,1)
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
            acc.Parent = char
            if not isLayered then
                if isR6 then
                    if not cupR6WeldAccessory(char, acc) then
                        weldAccessory(char, acc)
                    end
                else
                    weldAccessory(char, acc)
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

    if not isR6 and data.animations and tableCount(data.animations) > 0 then
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
            local applied = 0
            for _, obj in pairs(animate:GetDescendants()) do
                if obj:IsA("Animation") then
                    local path = getAnimPath(obj)
                    if data.animations[path] then
                        obj.AnimationId = data.animations[path]
                        applied = applied + 1
                    end
                end
            end
        end
    end

    if data.walkSpeed then humanoid.WalkSpeed = data.walkSpeed end
    if data.jumpPower then humanoid.JumpPower = data.jumpPower end
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
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 230, 245)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 195, 220)),
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

local function setWorldBlur(enabled)
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
	local cam = workspace.CurrentCamera
	if not cam then return end
	originalFov = cam.FieldOfView
	tween(cam, {FieldOfView = target}, 0.35, Enum.EasingStyle.Quart)
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

local savedMouseBehavior = nil
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
	savedMouseBehavior = UserInputService.MouseBehavior
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	enforceMouseUnlock()
end
local function lockMouseBack()
	releaseMouseUnlock()
	if savedMouseBehavior then
		UserInputService.MouseBehavior = savedMouseBehavior
		savedMouseBehavior = nil
	end
end

local hiddenUis = {}
local function hideOtherUis()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return end
	for _, gui in pairs(pg:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Enabled and not gui:GetAttribute("CupcakeOwned") then
			hiddenUis[gui] = true
			pcall(function() gui.Enabled = false end)
		end
	end
end
local function restoreHiddenUis()
	for gui in pairs(hiddenUis) do
		pcall(function() gui.Enabled = true end)
	end
	table.clear(hiddenUis)
end

local function toggleGui()
	if not currentGui then return end
	local mf = currentGui:FindFirstChild("MainWindow")
	if not mf then return end
	if mf.Visible then
		isGuiOpen = false
		lockMouseBack()
		restoreHiddenUis()
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
		tween(mf, {Position = target + UDim2.new(0, 0, 0, 12)}, 0.14, Enum.EasingStyle.Quad)
		task.delay(0.15, function()
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
		hideOtherUis()
		local bdOpen = currentGui:FindFirstChild("Backdrop")
		if bdOpen then
			bdOpen.Visible = true
			tween(bdOpen, {BackgroundTransparency = 0.45}, 0.2)
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

local function makeGui()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return nil end

	local old = pg:FindFirstChild("CupcakeGui")
	if old then old:Destroy() end

	local refreshGrid, showToast, openModal, closeModal, openOptionsMenu
	local openHeightModal, closeHeightModal
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
	backdrop.BackgroundColor3 = Color3.fromRGB(10, 15, 30)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 1
	backdrop.Visible = false
	backdrop.Parent = sg
	local backdropGrad = Instance.new("UIGradient")
	backdropGrad.Rotation = 90
	backdropGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 24, 48)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 9, 20)),
	})
	backdropGrad.Parent = backdrop

	local mf = Instance.new("Frame")
	mf.Name = "MainWindow"
	mf.Size = UDim2.new(0, 520, 0, 400)
	mf.Position = UDim2.new(0.5, -260, 0.5, -200)
	mf.BackgroundColor3 = M3.Surface
	mf.BackgroundTransparency = 0.75
	mf.BorderSizePixel = 0
	mf.ZIndex = 2
	mf.Parent = sg
	corner(16, mf)
	stroke(M3.GlassLine, 1, mf, 0.88)
	frost(mf, 16)

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
			if obj:IsA("GuiButton") then
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
		uiScale.Scale = getUiScale()
	end
	local function bindCamera()
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
		end
		refreshScale()
	end
	bindCamera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)

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
	circleBtn.Position = UDim2.new(savedPos.X, savedPos.OffsetX, savedPos.Y, savedPos.OffsetY)
	circleBtn.BackgroundColor3 = M3.Surface
	circleBtn.BackgroundTransparency = 0.65
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
	frost(circleBtn, 21)

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

	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 48)
	titleBar.BackgroundTransparency = 1
	titleBar.ZIndex = 3
	titleBar.Parent = mf

	local titleStrip = Instance.new("Frame")
	titleStrip.Name = "TitleStrip"
	titleStrip.Size = UDim2.new(1, -36, 0, 2)
	titleStrip.Position = UDim2.new(0, 18, 0, 46)
	titleStrip.BackgroundColor3 = M3.Accent
	titleStrip.BackgroundTransparency = 0.35
	titleStrip.BorderSizePixel = 0
	titleStrip.ZIndex = 4
	titleStrip.Parent = titleBar
	corner(1, titleStrip)

	local logoDot = Instance.new("Frame")
	logoDot.Name = "LogoDot"
	logoDot.Size = UDim2.new(0, 10, 0, 10)
	logoDot.Position = UDim2.new(0, 18, 0, 19)
	logoDot.BackgroundColor3 = M3.Accent
	logoDot.BorderSizePixel = 0
	logoDot.ZIndex = 4
	logoDot.Parent = titleBar
	corner(5, logoDot)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(0, 140, 1, 0)
	titleLabel.Position = UDim2.new(0, 38, 0, 0)
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
			while catalogSpinning do
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
		pcall(function()
			game:GetService("TeleportService"):Teleport(CATALOG_PLACE_ID, player)
		end)
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

	local settingsPage = Instance.new("Frame")
	settingsPage.Name = "SettingsPage"
	settingsPage.Size = UDim2.new(1, 0, 1, 0)
	settingsPage.BackgroundTransparency = 1
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

	selectTab = function(page, index, instant)
		avatarsPage.Visible = (page == "avatars")
		settingsPage.Visible = (page == "settings")
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

	local settingsRow = Instance.new("Frame")
	settingsRow.Name = "Row_KeepOnRespawn"
	settingsRow.Size = UDim2.new(1, -8, 0, 48)
	settingsRow.Position = UDim2.new(0, 4, 0, 6)
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
	deviceRow.Position = UDim2.new(0, 4, 0, 60)
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

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.Size = UDim2.new(1, -8, 0, 28)
	footer.Position = UDim2.new(0, 4, 1, -36)
	footer.BackgroundTransparency = 1
	footer.ZIndex = 2
	footer.Parent = settingsPage

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

		local rigTag = tostring(data.rigType or ""):find("R6") and "R6" or "R15"
		local rigBadge = Instance.new("TextLabel")
		rigBadge.Name = "RigBadge"
		rigBadge.Size = UDim2.new(0, 36, 0, 20)
		rigBadge.Position = UDim2.new(1, -84, 0.5, -10)
		rigBadge.BackgroundColor3 = rigTag == "R6" and M3.Accent or M3.Success
		rigBadge.BackgroundTransparency = 0.35
		rigBadge.BorderSizePixel = 0
		rigBadge.Text = rigTag
		rigBadge.TextColor3 = M3.OnPrimary
		rigBadge.TextSize = 11
		rigBadge.Font = Enum.Font.GothamBold
		rigBadge.ZIndex = 6
		rigBadge.Parent = card
		corner(6, rigBadge)

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
			if child:IsA("Frame") or (child:IsA("TextLabel") and child.Name == "EmptyHint") or (child:IsA("TextButton") and child.Name == "AddCard") then child:Destroy() end
		end

		local names = {}
		for name in pairs(savedAvatars) do table.insert(names, name) end
		table.sort(names, function(a, b) return a:lower() < b:lower() end)

		for i, name in ipairs(names) do
			createAvatarGridCard(name, savedAvatars[name], i)
		end
		createAddCard(#names + 1)
	end

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
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			mf.Position = UDim2.new(winStart.X.Scale, winStart.X.Offset + delta.X, winStart.Y.Scale, winStart.Y.Offset + delta.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	local function animateSheetOpen(overlay, box, extras)
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
		tween(box, {BackgroundTransparency = 0.5, Position = finalPos}, 0.2, Enum.EasingStyle.Quart)
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
	modal.BackgroundColor3 = Color3.new(0, 0, 0)
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
	modalBox.BackgroundTransparency = 0.7
	modalBox.BorderSizePixel = 0
	modalBox.ZIndex = 101
	modalBox.ClipsDescendants = true
	modalBox.Parent = modal
	corner(14, modalBox)
	local modalBoxStroke = stroke(M3.GlassLine, 1, modalBox, 0.86)
	frost(modalBox, 14)

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
			if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
		end
		local others = 0
		for _, plr in pairs(Players:GetPlayers()) do
			if plr ~= player then
				others = others + 1
				local row = Instance.new("TextButton")
				row.Name = "PlayerRow_" .. plr.Name
				row.Size = UDim2.new(1, 0, 0, 34)
				row.BackgroundColor3 = M3.SurfaceHighest
				row.BackgroundTransparency = 0.6
				row.Text = (plr.DisplayName ~= plr.Name) and (plr.DisplayName .. "  @" .. plr.Name) or plr.Name
				row.TextColor3 = M3.OnSurface
				row.TextSize = 12
				row.Font = Enum.Font.GothamMedium
				row.AutoButtonColor = false
				row.ZIndex = 103
				row.Parent = playerList
				corner(9, row)
				local baseText = row.Text
				row.MouseEnter:Connect(function() tween(row, {BackgroundTransparency = 0.45}, 0.1) end)
				row.MouseLeave:Connect(function() tween(row, {BackgroundTransparency = 0.6}, 0.15) end)
				row.MouseButton1Click:Connect(function()
					if selectedCopyPlayers[plr] then
						selectedCopyPlayers[plr] = nil
						row.BackgroundColor3 = M3.SurfaceHighest
						row.TextColor3 = M3.OnSurface
						row.Text = baseText
					else
						selectedCopyPlayers[plr] = true
						row.BackgroundColor3 = M3.Accent
						row.TextColor3 = M3.OnPrimary
						row.Text = "✓ " .. baseText
					end
					updateCopySaveBtn()
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
			if hasFS() then saveFile(SAVES_PATH, savedAvatars) end
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
	optionsMenu.Size = UDim2.new(0, 140, 0, 118)
	optionsMenu.BackgroundColor3 = M3.Surface
	optionsMenu.BackgroundTransparency = 0.6
	optionsMenu.BorderSizePixel = 0
	optionsMenu.Visible = false
	optionsMenu.ZIndex = 200
	optionsMenu.Parent = mf
	optionsMenu.ClipsDescendants = true
	corner(12, optionsMenu)
	stroke(M3.GlassLine, 1, optionsMenu, 0.86)
	frost(optionsMenu, 12)

	local optionsMenuPad = Instance.new("UIPadding")
	optionsMenuPad.PaddingTop = UDim.new(0, 6)
	optionsMenuPad.PaddingBottom = UDim.new(0, 6)
	optionsMenuPad.PaddingLeft = UDim.new(0, 6)
	optionsMenuPad.PaddingRight = UDim.new(0, 6)
	optionsMenuPad.Parent = optionsMenu

	local optionsMenuBg = Instance.new("TextButton")
	optionsMenuBg.Name = "OptionsMenuBg"
	optionsMenuBg.Size = UDim2.new(1, 0, 1, 0)
	optionsMenuBg.BackgroundTransparency = 1
	optionsMenuBg.Text = ""
	optionsMenuBg.ZIndex = 150
	optionsMenuBg.Visible = false
	optionsMenuBg.Parent = mf

	local function closeOptionsMenu()
		optionsMenu.Visible = false
		optionsMenuBg.Visible = false
		if resetDeleteConfirm then resetDeleteConfirm() end
	end
	optionsMenuBg.MouseButton1Click:Connect(closeOptionsMenu)

	local optionsMenuLayout = Instance.new("UIListLayout")
	optionsMenuLayout.Padding = UDim.new(0, 2)
	optionsMenuLayout.SortOrder = Enum.SortOrder.LayoutOrder
	optionsMenuLayout.Parent = optionsMenu

	local optionsMenuTarget = nil

	local function makeMenuOption(text, color, order)
		local btn = Instance.new("TextButton")
		btn.Name = "Opt_" .. text
		btn.Size = UDim2.new(1, 0, 0, 34)
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
		stroke(M3.GlassLine, 1, btn, 0.92)

		local btnPad = Instance.new("UIPadding")
		btnPad.PaddingLeft = UDim.new(0, 10)
		btnPad.Parent = btn

		btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = M3.SurfaceHigh, BackgroundTransparency = 0}, 0.1) end)
		btn.MouseLeave:Connect(function() tween(btn, {BackgroundTransparency = 1}, 0.15) end)
		return btn
	end

	local btnMenuRename = makeMenuOption("Rename", M3.OnSurface, 1)
	local btnMenuHeight = makeMenuOption("Height", M3.OnSurface, 2)
	local btnMenuDelete = makeMenuOption("Delete", M3.Error, 3)

	btnMenuRename.MouseButton1Click:Connect(function()
		closeOptionsMenu()
		if optionsMenuTarget then
			openModal("rename", optionsMenuTarget)
		end
	end)

	btnMenuHeight.MouseButton1Click:Connect(function()
		closeOptionsMenu()
		if openHeightModal then openHeightModal() end
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
		closeOptionsMenu()
		DeleteAvatar(optionsMenuTarget)
		refreshGrid()
	end)

	openOptionsMenu = function(name, anchorBtn)
		optionsMenuTarget = name
		local absPos = anchorBtn.AbsolutePosition
		local mfPos = mf.AbsolutePosition
		local x = math.clamp(absPos.X - mfPos.X, 8, mf.AbsoluteSize.X - 148)
		local y = math.clamp((absPos.Y - mfPos.Y) + anchorBtn.AbsoluteSize.Y + 4, 8, mf.AbsoluteSize.Y - 126)
		optionsMenu.Position = UDim2.new(0, x, 0, y)
		optionsMenu.Visible = true
		optionsMenuBg.Visible = true
	end

	local heightModal = Instance.new("Frame")
	heightModal.Name = "HeightModal"
	heightModal.Size = UDim2.new(1, 0, 1, 0)
	heightModal.BackgroundColor3 = Color3.new(0, 0, 0)
	heightModal.BackgroundTransparency = 0.45
	heightModal.BorderSizePixel = 0
	heightModal.ZIndex = 100
	heightModal.Visible = false
	heightModal.Parent = mf

	local heightBgBtn = Instance.new("TextButton")
	heightBgBtn.Name = "HeightBgBtn"
	heightBgBtn.Size = UDim2.new(1, 0, 1, 0)
	heightBgBtn.BackgroundTransparency = 1
	heightBgBtn.Text = ""
	heightBgBtn.ZIndex = 100
	heightBgBtn.Parent = heightModal

	local heightBox = Instance.new("Frame")
	heightBox.Name = "HeightBox"
	heightBox.Size = UDim2.new(0, 300, 0, 176)
	heightBox.Position = UDim2.new(0.5, -150, 0.5, -88)
	heightBox.BackgroundColor3 = M3.Surface
	heightBox.BackgroundTransparency = 0.7
	heightBox.BorderSizePixel = 0
	heightBox.ZIndex = 101
	heightBox.ClipsDescendants = true
	heightBox.Parent = heightModal
	corner(14, heightBox)
	local heightBoxStroke = stroke(M3.GlassLine, 1, heightBox, 0.86)
	frost(heightBox, 14)

	local heightBlocker = Instance.new("TextButton")
	heightBlocker.Name = "Blocker"
	heightBlocker.Size = UDim2.new(1, 0, 1, 0)
	heightBlocker.BackgroundTransparency = 1
	heightBlocker.Text = ""
	heightBlocker.ZIndex = 101
	heightBlocker.Parent = heightBox
	heightBlocker.MouseButton1Click:Connect(function() end)

	local heightTitle = Instance.new("TextLabel")
	heightTitle.Name = "Title"
	heightTitle.Size = UDim2.new(1, -40, 0, 24)
	heightTitle.Position = UDim2.new(0, 20, 0, 16)
	heightTitle.BackgroundTransparency = 1
	heightTitle.Text = "Height"
	heightTitle.TextColor3 = M3.OnSurface
	heightTitle.TextSize = 15
	heightTitle.Font = Enum.Font.GothamBold
	heightTitle.TextXAlignment = Enum.TextXAlignment.Left
	heightTitle.ZIndex = 102
	heightTitle.Parent = heightBox

	local heightLabel = Instance.new("TextLabel")
	heightLabel.Name = "HeightLabel"
	heightLabel.Size = UDim2.new(1, -40, 0, 14)
	heightLabel.Position = UDim2.new(0, 20, 0, 48)
	heightLabel.BackgroundTransparency = 1
	heightLabel.Text = "Hip Height (studs)"
	heightLabel.TextColor3 = M3.OnSurfaceFaint
	heightLabel.TextSize = 10
	heightLabel.Font = Enum.Font.Gotham
	heightLabel.TextXAlignment = Enum.TextXAlignment.Left
	heightLabel.ZIndex = 102
	heightLabel.Parent = heightBox

	local heightInputWrap = Instance.new("Frame")
	heightInputWrap.Name = "HeightInputWrap"
	heightInputWrap.Size = UDim2.new(1, -40, 0, 38)
	heightInputWrap.Position = UDim2.new(0, 20, 0, 68)
	heightInputWrap.BackgroundColor3 = M3.Background
	heightInputWrap.BackgroundTransparency = 0.2
	heightInputWrap.BorderSizePixel = 0
	heightInputWrap.ZIndex = 102
	heightInputWrap.Parent = heightBox
	corner(9, heightInputWrap)
	local heightInputStroke = stroke(M3.OutlineVariant, 1, heightInputWrap, 0.5)

	local heightInput = Instance.new("TextBox")
	heightInput.Name = "HeightInput"
	heightInput.Size = UDim2.new(1, -20, 1, 0)
	heightInput.Position = UDim2.new(0, 10, 0, 0)
	heightInput.BackgroundTransparency = 1
	heightInput.Text = "2"
	heightInput.PlaceholderText = "e.g. 2"
	heightInput.TextColor3 = M3.OnSurface
	heightInput.PlaceholderColor3 = M3.OnSurfaceFaint
	heightInput.TextSize = 13
	heightInput.Font = Enum.Font.Gotham
	heightInput.TextXAlignment = Enum.TextXAlignment.Left
	heightInput.ClearTextOnFocus = false
	heightInput.ZIndex = 103
	heightInput.Parent = heightInputWrap

	heightInput.Focused:Connect(function() tween(heightInputStroke, {Color = M3.Accent, Transparency = 0}, 0.1) end)
	heightInput.FocusLost:Connect(function() tween(heightInputStroke, {Color = M3.OutlineVariant, Transparency = 0.5}, 0.15) end)

	local btnCloseHeight = Instance.new("TextButton")
	btnCloseHeight.Name = "BtnClose"
	btnCloseHeight.Size = UDim2.new(0, 120, 0, 40)
	btnCloseHeight.Position = UDim2.new(0, 20, 1, -54)
	btnCloseHeight.BackgroundColor3 = M3.SurfaceHigh
	btnCloseHeight.BorderSizePixel = 0
	btnCloseHeight.Text = "Close"
	btnCloseHeight.TextColor3 = M3.OnSurface
	btnCloseHeight.TextSize = 13
	btnCloseHeight.Font = Enum.Font.GothamMedium
	btnCloseHeight.AutoButtonColor = false
	btnCloseHeight.ZIndex = 102
	btnCloseHeight.Parent = heightBox
	corner(12, btnCloseHeight)
	stroke(M3.GlassLine, 1, btnCloseHeight, 0.9)
	btnCloseHeight.MouseEnter:Connect(function() tween(btnCloseHeight, {BackgroundColor3 = M3.SurfaceHighest}, 0.1) end)
	btnCloseHeight.MouseLeave:Connect(function() tween(btnCloseHeight, {BackgroundColor3 = M3.SurfaceHigh}, 0.15) end)

	local btnApplyHeight = Instance.new("TextButton")
	btnApplyHeight.Name = "BtnApply"
	btnApplyHeight.Size = UDim2.new(0, 120, 0, 40)
	btnApplyHeight.Position = UDim2.new(1, -140, 1, -54)
	btnApplyHeight.BackgroundColor3 = M3.Primary
	btnApplyHeight.BorderSizePixel = 0
	btnApplyHeight.Text = "Apply"
	btnApplyHeight.TextColor3 = M3.OnPrimary
	btnApplyHeight.TextSize = 13
	btnApplyHeight.Font = Enum.Font.GothamBold
	btnApplyHeight.AutoButtonColor = false
	btnApplyHeight.ZIndex = 102
	btnApplyHeight.Parent = heightBox
	corner(12, btnApplyHeight)
	stroke(M3.Primary, 1, btnApplyHeight, 0.6)
	btnApplyHeight.MouseEnter:Connect(function() tween(btnApplyHeight, {BackgroundColor3 = M3.PrimaryHover}, 0.1) end)
	btnApplyHeight.MouseLeave:Connect(function() tween(btnApplyHeight, {BackgroundColor3 = M3.Primary}, 0.15) end)

	local function animateHeightOpen()
		animateSheetOpen(heightModal, heightBox, {{Obj = heightBoxStroke, Prop = "Stroke", To = 0.9}})
	end

	openHeightModal = function()
		local char = player.Character
		local currentHip = 2
		if char then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if humanoid then currentHip = humanoid.HipHeight end
		end
		heightInput.Text = tostring(math.floor(currentHip * 100 + 0.5) / 100)
		heightModal.Visible = true
		animateHeightOpen()
		heightInput:CaptureFocus()
	end
	closeHeightModal = function()
		heightModal.Visible = false
	end

	heightBgBtn.MouseButton1Click:Connect(closeHeightModal)
	btnCloseHeight.MouseButton1Click:Connect(closeHeightModal)

	local function applyHeightFromInput()
		local n = tonumber(heightInput.Text)
		if not n then
			heightInput:CaptureFocus()
			return
		end
		n = math.clamp(n, 0, 50)
		applyHipHeight(n)
		closeHeightModal()
	end

	btnApplyHeight.MouseButton1Click:Connect(applyHeightFromInput)
	heightInput.FocusLost:Connect(function(enterPressed)
		if enterPressed then applyHeightFromInput() end
	end)

	selectTab("avatars", 0, true)
	refreshGrid()
	sg.Parent = pg
	currentGui = sg
	hookClicks(sg)
	hookClicks(circleGui)
	return sg
end

local function isAnyTextBoxFocused()
	for _, obj in pairs(player:GetDescendants()) do
		if obj:IsA("TextBox") and obj:IsFocused() then return true end
	end
	return false
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if isAnyTextBoxFocused() then return end
	local key = input.KeyCode
	if key == Enum.KeyCode.Zero or key == Enum.KeyCode.KeypadZero then
		toggleGui()
	end
end)

loadSettings()

if hasFS() then
	savedAvatars = loadFile(SAVES_PATH) or {}
end
makeGui()

if isGuiOpen then
	unlockMouse()
	hideOtherUis()
	local bdInit = currentGui and currentGui:FindFirstChild("Backdrop")
	if bdInit then
		bdInit.Visible = true
		bdInit.BackgroundTransparency = 0.45
	end
end
if isGuiOpen then setWorldBlur(true) end
if isGuiOpen then setFov(MENU_FOV) end

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

player.CharacterAdded:Connect(reapplyOnRespawn)
