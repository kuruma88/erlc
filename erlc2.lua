-- ERLC Full ESP + NonUI + Modern Autofarms (Update #21)
-- Fixed: Full Hotwire suite (Timing Bar, Wires, Numbers Hack), TangledWires hierarchy, ATM & Lockpick
-- UI converted from INSUI → NonUI

local Players            = game:GetService("Players")
local Workspace          = workspace or game:GetService("Workspace")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local LocalPlayer        = Players.LocalPlayer
local cam                = Workspace and Workspace.CurrentCamera

----------------------------------------------------
-- LOAD NonUI
----------------------------------------------------
local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/neaxusxgod-png/NonUI/main/NonUI.lua"))() or NonUI

----------------------------------------------------
-- CONFIG
----------------------------------------------------
local cfg = {
    masterEnabled = true,

    criminal = {
        enabled  = true,
        color    = Color3.fromRGB(255, 55, 55),
        yOffset  = -5,
        fontSize = 11,
    },
    panic = {
        enabled  = true,
        color    = Color3.fromRGB(255, 120, 30),
        yOffset  = 25,
        fontSize = 12,
    },
    deployable = {
        enabled  = true,
        color    = Color3.fromRGB(80, 200, 120),
        yOffset  = 30,
        fontSize = 13,
    },
    bountyVehicle = {
        enabled  = true,
        color    = Color3.fromRGB(50, 180, 255),
        yOffset  = 40,
        fontSize = 13,
    },
    stolenVehicle = {
        enabled    = true,
        color      = Color3.fromRGB(255, 110, 180),
        priceColor = Color3.fromRGB(255, 210, 70),
        yOffset    = 40,
        fontSize   = 13,
        showPrice  = true,
    },
    personalVehicle = {
        enabled  = true,
        color    = Color3.fromRGB(100, 220, 255),
        yOffset  = 40,
        fontSize = 13,
        text     = "Personal Vehicle",
    },
    vehicleHealth = {
        enabled     = true,
        fontSize    = 12,
        showSeconds = 5,
        yOffset     = 22,
    },
    helicopter = {
        enabled           = true,
        color             = Color3.fromRGB(255, 220, 50),
        yOffset           = 40,
        fontSize          = 14,
        text              = "Helicopter",
        spotlightFontSize = 11,
        spotlightColor    = Color3.fromRGB(255, 180, 40),
        showSpotlight     = true,
        edgeMargin        = 50,
    },

    -- Autofarms
    atm      = { enabled = false, delay = 50 },
    lockpick = { enabled = false, delay = 40, tolerance = 2 },
    glasscut = { enabled = false, lead = 0 },
    hotwire  = { enabled = false, delay = 50, latency = 0, margin = 25 },

    settings = {
        fontName    = "SystemBold",
        dynamicSize = 0,
        maxDistance = 5000,
    }
}

local FONT_NAMES = { "UI", "System", "SystemBold", "Minecraft", "Monospace", "Pixel", "Fortnite" }
local FONT_MAP = {
    UI         = Drawing.Fonts.UI,
    System     = Drawing.Fonts.System,
    SystemBold = Drawing.Fonts.SystemBold,
    Minecraft  = Drawing.Fonts.Minecraft,
    Monospace  = Drawing.Fonts.Monospace,
    Pixel      = Drawing.Fonts.Pixel,
    Fortnite   = Drawing.Fonts.Fortnite,
}

local function getEspFont()
    return FONT_MAP[cfg.settings.fontName] or Drawing.Fonts.SystemBold
end

----------------------------------------------------
-- MEMORY OFFSETS & UNCACHED READING
----------------------------------------------------
local GUI_OFF = {
    Visible          = 1453, -- 0x5AD
    Text             = 3576, -- 0xDF8
    BackgroundColor3 = 1344, -- 0x540
    AbsolutePosition = 268,  -- 0x10C
    AbsoluteSize     = 276,  -- 0x114
}

local function rawAddr(inst)
    if not inst then return nil end
    local a = inst.Address
    if type(a) == "string" then return tonumber(a, 16) or tonumber(a) end
    return tonumber(a)
end

local function memRead(kind, address)
    if not address then return nil end
    local value = nil
    pcall(function() value = memory_read(kind, address) end)
    return value
end

local function memVisible(inst)
    if not inst then return false end
    local addr = rawAddr(inst)
    if addr then
        local v = memRead("byte", addr + GUI_OFF.Visible)
        if v ~= nil then return v ~= 0 end
    end
    local ok, vis = pcall(function() return inst.Visible end)
    return ok and vis == true
end

local function memAbsPos(inst)
    local pos = nil
    pcall(function() pos = inst.AbsolutePosition end)
    if pos and pos.X and pos.Y then return pos.X, pos.Y end
    local addr = rawAddr(inst)
    if addr then
        local base = addr + GUI_OFF.AbsolutePosition
        local x = memRead("float", base)
        local y = memRead("float", base + 4)
        if x and y then return x, y end
    end
    return nil, nil
end

local function memAbsSize(inst)
    local size = nil
    pcall(function() size = inst.AbsoluteSize end)
    if size and size.X and size.Y then return size.X, size.Y end
    local addr = rawAddr(inst)
    if addr then
        local base = addr + GUI_OFF.AbsoluteSize
        local x = memRead("float", base)
        local y = memRead("float", base + 4)
        if x and y then return x, y end
    end
    return nil, nil
end

local function memText(inst)
    local text = nil
    pcall(function() text = inst.Text end)
    if type(text) == "string" and text ~= "" then return text end
    local addr = rawAddr(inst)
    if addr then
        local s = memRead("string", addr + GUI_OFF.Text)
        if type(s) == "string" and s ~= "" then return s end
    end
    return text or ""
end

local function memColorRGB(inst)
    local addr = rawAddr(inst)
    if addr then
        local base = addr + GUI_OFF.BackgroundColor3
        local r = memRead("float", base)
        local g = memRead("float", base + 4)
        local b = memRead("float", base + 8)
        if r ~= nil and g ~= nil and b ~= nil then
            r, g, b = tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0
            if r > 1 or g > 1 or b > 1 then r, g, b = r / 255, g / 255, b / 255 end
            return r, g, b
        end
    end
    local cr, cg, cb
    pcall(function()
        local c = inst.BackgroundColor3
        cr, cg, cb = c.R, c.G, c.B
    end)
    if cr then
        if cr > 1 or cg > 1 or cb > 1 then cr, cg, cb = cr / 255, cg / 255, cb / 255 end
        return cr, cg, cb
    end
    return 0, 0, 0
end

local function viewportSize()
    local vp = cam and cam.ViewportSize
    if vp and vp.X and vp.X > 64 and vp.Y and vp.Y > 64 then return vp.X, vp.Y end
    return nil, nil
end

local function mouseXY()
    local m = nil
    pcall(function() m = LocalPlayer and LocalPlayer:GetMouse() end)
    if not m then return nil, nil end
    local x, y = m.X, m.Y
    if type(x) ~= "number" or type(y) ~= "number" then return nil, nil end
    return x, y
end

local function clamp(n, a, b)
    if n < a then return a end
    if n > b then return b end
    return n
end

local function findChild(parent, name)
    if not parent then return nil end
    local found = nil
    pcall(function() found = parent:FindFirstChild(name) end)
    return found
end

local function findPath(root, ...)
    local cur = root
    for i = 1, select("#", ...) do
        if not cur then return nil end
        cur = findChild(cur, select(i, ...))
    end
    return cur
end

local function getPlayerGui()
    if not LocalPlayer then return nil end
    local pg = nil
    pcall(function() pg = LocalPlayer:FindFirstChildOfClass("PlayerGui") end)
    return pg or findChild(LocalPlayer, "PlayerGui")
end

local function guiRect(inst)
    local x, y = memAbsPos(inst)
    local w, h = memAbsSize(inst)
    if not x or not y or not w or not h then return nil end
    return { x = x, y = y, w = w, h = h, cx = x + w / 2, cy = y + h / 2 }
end

local function inViewport(inst, pad)
    local rect = guiRect(inst)
    local vw, vh = viewportSize()
    if not rect or not vw then return false end
    pad = pad or 8
    return rect.y < vh - pad and (rect.y + rect.h) > pad and rect.x < vw - pad and (rect.x + rect.w) > pad
end

local function moveMouseToward(tx, ty)
    local vw, vh = viewportSize()
    if vw then
        tx = clamp(tx, 8, vw - 8)
        ty = clamp(ty, 8, vh - 8)
    end
    local mx, my = mouseXY()
    if not mx then return 999 end
    local dx = tx - mx
    local dy = ty - my
    if vw then
        dx = clamp(mx + dx, 8, vw - 8) - mx
        dy = clamp(my + dy, 8, vh - 8) - my
    end
    local dist = math.sqrt(dx * dx + dy * dy)
    local maxStep = 90
    if dist > maxStep then
        dx = dx / dist * maxStep
        dy = dy / dist * maxStep
    end
    if dist >= 0.6 then
        pcall(function() mousemoverel(dx, dy) end)
    end
    return dist
end

local function clickAtGui(inst, maxDist)
    local rect = guiRect(inst)
    if not rect then return false, 999 end
    local dist = moveMouseToward(rect.cx, rect.cy)
    if dist > (maxDist or 14) then return false, dist end
    pcall(mouse1click)
    return true, dist
end

----------------------------------------------------
-- NonUI WINDOW + TABS
----------------------------------------------------
local function notify(title, content, duration)
    Lib:Notify({
        Title    = title or "ERLC ESP",
        Content  = content or "",
        Duration = duration or 2,
    })
end

local win = Lib:CreateWindow({
    Title     = "ERLC ESP",
    Author    = "Update #21",
    Size      = { 640, 540 },
    ToggleKey = "k",
    Theme     = "Indigo",
})

-- ── Main ESP Tab ──────────────────────────────────
local tab = win:Tab({ Title = "ESP", Icon = "eye" })

tab:Section({ Title = "General" })

tab:Toggle({
    Title    = "Master Enabled",
    Value    = cfg.masterEnabled,
    Callback = function(v) cfg.masterEnabled = v end,
})

tab:Slider({
    Title    = "Max Distance",
    Default  = cfg.settings.maxDistance,
    Min      = 100,
    Max      = 10000,
    Step     = 50,
    Suffix   = " studs",
    Callback = function(v) cfg.settings.maxDistance = v end,
})

tab:Dropdown({
    Title    = "Font",
    Values   = FONT_NAMES,
    Default  = cfg.settings.fontName,
    Callback = function(v) cfg.settings.fontName = v end,
})

tab:Divider()
tab:Section({ Title = "Labels" })

tab:Toggle({
    Title    = "Criminal",
    Value    = cfg.criminal.enabled,
    Callback = function(v) cfg.criminal.enabled = v end,
})
tab:Colorpicker({
    Title    = "Criminal Color",
    Default  = cfg.criminal.color,
    Callback = function(c) cfg.criminal.color = c end,
})

tab:Toggle({
    Title    = "Panic",
    Value    = cfg.panic.enabled,
    Callback = function(v) cfg.panic.enabled = v end,
})
tab:Colorpicker({
    Title    = "Panic Color",
    Default  = cfg.panic.color,
    Callback = function(c) cfg.panic.color = c end,
})

tab:Toggle({
    Title    = "Deployables",
    Value    = cfg.deployable.enabled,
    Callback = function(v) cfg.deployable.enabled = v end,
})
tab:Colorpicker({
    Title    = "Deployable Color",
    Default  = cfg.deployable.color,
    Callback = function(c) cfg.deployable.color = c end,
})

tab:Divider()
tab:Section({ Title = "Vehicles / Heli" })

tab:Toggle({
    Title    = "Bounty Vehicles",
    Value    = cfg.bountyVehicle.enabled,
    Callback = function(v) cfg.bountyVehicle.enabled = v end,
})
tab:Colorpicker({
    Title    = "Bounty Color",
    Default  = cfg.bountyVehicle.color,
    Callback = function(c) cfg.bountyVehicle.color = c end,
})

tab:Toggle({
    Title    = "Stolen Vehicles",
    Value    = cfg.stolenVehicle.enabled,
    Callback = function(v) cfg.stolenVehicle.enabled = v end,
})
tab:Colorpicker({
    Title    = "Stolen Color",
    Default  = cfg.stolenVehicle.color,
    Callback = function(c) cfg.stolenVehicle.color = c end,
})

tab:Toggle({
    Title    = "Show Price",
    Value    = cfg.stolenVehicle.showPrice,
    Callback = function(v) cfg.stolenVehicle.showPrice = v end,
})
tab:Colorpicker({
    Title    = "Price Color",
    Default  = cfg.stolenVehicle.priceColor,
    Callback = function(c) cfg.stolenVehicle.priceColor = c end,
})

tab:Toggle({
    Title    = "Personal Vehicle",
    Value    = cfg.personalVehicle.enabled,
    Callback = function(v) cfg.personalVehicle.enabled = v end,
})
tab:Colorpicker({
    Title    = "Personal Color",
    Default  = cfg.personalVehicle.color,
    Callback = function(c) cfg.personalVehicle.color = c end,
})

tab:Toggle({
    Title    = "Vehicle Health (on damage)",
    Value    = cfg.vehicleHealth.enabled,
    Callback = function(v) cfg.vehicleHealth.enabled = v end,
})

tab:Toggle({
    Title    = "Helicopter",
    Value    = cfg.helicopter.enabled,
    Callback = function(v) cfg.helicopter.enabled = v end,
})
tab:Colorpicker({
    Title    = "Heli Color",
    Default  = cfg.helicopter.color,
    Callback = function(c) cfg.helicopter.color = c end,
})

tab:Toggle({
    Title    = "Show Spotlighted",
    Value    = cfg.helicopter.showSpotlight,
    Callback = function(v) cfg.helicopter.showSpotlight = v end,
})
tab:Colorpicker({
    Title    = "Spotlight Color",
    Default  = cfg.helicopter.spotlightColor,
    Callback = function(c) cfg.helicopter.spotlightColor = c end,
})

-- ── Autofarms Tab ─────────────────────────────────
local autoTab = win:Tab({ Title = "Autofarms", Icon = "zap" })

autoTab:Section({ Title = "Minigame Autos" })
autoTab:Paragraph({
    Title = "Info",
    Desc  = "Enable the ones you want. They run automatically when the corresponding minigame appears.",
})

autoTab:Toggle({
    Title    = "Auto ATM (Grid)",
    Value    = cfg.atm.enabled,
    Callback = function(v)
        cfg.atm.enabled = v
        notify("Autofarms", v and "ATM Hack: ON" or "ATM Hack: OFF", 2)
    end,
})

autoTab:Toggle({
    Title    = "Auto Lockpick",
    Value    = cfg.lockpick.enabled,
    Callback = function(v)
        cfg.lockpick.enabled = v
        notify("Autofarms", v and "Lockpick: ON" or "Lockpick: OFF", 2)
    end,
})

autoTab:Toggle({
    Title    = "Auto Glass Cutting",
    Value    = cfg.glasscut.enabled,
    Callback = function(v)
        cfg.glasscut.enabled = v
        notify("Autofarms", v and "Glass Cutting: ON" or "Glass Cutting: OFF", 2)
    end,
})

autoTab:Toggle({
    Title    = "Auto Hotwire & Crowbar",
    Value    = cfg.hotwire.enabled,
    Callback = function(v)
        cfg.hotwire.enabled = v
        notify("Autofarms", v and "Auto Hotwire Suite: ON" or "Auto Hotwire Suite: OFF", 2)
    end,
})

autoTab:Divider()
autoTab:Section({ Title = "Actions" })
autoTab:Button({
    Title    = "Reset Defaults",
    Callback = function()
        cfg.masterEnabled            = true
        cfg.criminal.enabled         = true
        cfg.panic.enabled            = true
        cfg.deployable.enabled       = true
        cfg.bountyVehicle.enabled    = true
        cfg.stolenVehicle.enabled    = true
        cfg.stolenVehicle.showPrice  = true
        cfg.personalVehicle.enabled  = true
        cfg.vehicleHealth.enabled    = true
        cfg.helicopter.enabled       = true
        cfg.helicopter.showSpotlight = true
        cfg.settings.maxDistance     = 5000

        cfg.atm.enabled      = false
        cfg.lockpick.enabled = false
        cfg.glasscut.enabled = false
        cfg.hotwire.enabled  = false

        notify("ERLC ESP", "Defaults restored", 2)
    end,
})

----------------------------------------------------
-- ESP LISTS & DRAWING ROUTINES
----------------------------------------------------
local criminalList       = {}
local panicList          = {}
local deployableList     = {}
local bountyList         = {}
local stolenList         = {}
local personalList       = {}
local vehicleHealthState = {}
local heliLabel          = nil
local heliSpotlightLabel = nil

local OFFSET_STUD_SCALE = 0.1
local DYNAMIC_REF_DIST  = 400

local function calcFontSize(baseSize, dist)
    baseSize = tonumber(baseSize) or 10
    local dynamic = tonumber(cfg.settings.dynamicSize) or 0
    if dynamic <= 0 then return baseSize end
    local distNorm = math.min((tonumber(dist) or 0) / DYNAMIC_REF_DIST, 1)
    local intensity = dynamic / 10
    local minScale = 1 - intensity * 0.5
    local maxScale = 1 + intensity * 0.5
    local scale = minScale + distNorm * (maxScale - minScale)
    return math.max(8, math.floor(baseSize * scale + 0.5))
end

local function applyTextStyle(label, fs)
    if not label then return end
    fs = math.max(8, math.floor(tonumber(fs) or 10))
    pcall(function()
        label.Font     = getEspFont()
        label.FontSize = fs
        label.Size     = fs
    end)
end

local function createTextEsp(size)
    local label = Drawing.new("Text")
    label.Center  = true
    label.Outline = true
    label.ZIndex  = 120
    label.Visible = false
    applyTextStyle(label, size or 12)
    return label
end

local function createCircleEsp()
    local circle = Drawing.new("Circle")
    circle.Filled       = true
    circle.NumSides     = 10
    circle.Thickness    = 1
    circle.Transparency = 0
    circle.ZIndex       = 119
    circle.Visible      = false
    return circle
end

local function removeEsp(entry)
    if not entry then return end
    if entry.Label then pcall(function() entry.Label:Remove() end) end
    if entry.PriceLabel then pcall(function() entry.PriceLabel:Remove() end) end
    if entry.Circle then pcall(function() entry.Circle:Remove() end) end
end

local function hideEntry(entry)
    if not entry then return end
    if entry.Label then entry.Label.Visible = false end
    if entry.PriceLabel then entry.PriceLabel.Visible = false end
    if entry.Circle then entry.Circle.Visible = false end
end

local function getLocalPos()
    local char = LocalPlayer and LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Position then return hrp.Position end
    if cam and cam.Position then return cam.Position end
    return nil
end

local function getRootPart(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart")
end

local function getKey(obj)
    if not obj then return nil end
    return obj.Address or tostring(obj)
end

local function getStringField(model, name)
    if not model then return nil end
    local attr = model:GetAttribute(name)
    if type(attr) == "string" and attr ~= "" then return attr end
    local child = model:FindFirstChild(name)
    if child then
        if child:IsA("StringValue") then return child.Value end
        if typeof(child.Value) == "string" then return child.Value end
        if typeof(child.Value) == "Instance" and child.Value:IsA("Player") then
            return child.Value.Name
        end
    end
    return nil
end

local function getOwnerString(model) return getStringField(model, "Owner") end
local function getDriverName(model)  return getStringField(model, "DriverName") end

local function getVehicleHealth(model)
    if not model then return nil end
    local cv = model:FindFirstChild("Control_Values")
    local healthObj = cv and cv:FindFirstChild("Health")
    if healthObj and typeof(healthObj.Value) == "number" then return healthObj.Value end
    return nil
end

local function getVehicleMaxHealth(model)
    if not model then return nil end
    local cv = model:FindFirstChild("Control_Values")
    if not cv then return nil end
    for _, name in ipairs({ "MaxHealth", "Max_Health", "maxHealth", "HealthMax", "MaxHP" }) do
        local obj = cv:FindFirstChild(name)
        if obj and typeof(obj.Value) == "number" and obj.Value > 0 then return obj.Value end
    end
    return nil
end

local function healthToColor(health, maxHealth)
    local maxH = tonumber(maxHealth) or 0
    if maxH <= 0 then maxH = 100 end
    local t = math.clamp((tonumber(health) or 0) / maxH, 0, 1)
    return Color3.new(1 - t, t, 0.12)
end

local function drawText(label, pos, text, color, yOffset, baseFontSize, dist)
    local anchorPos = Vector3.new(pos.X, pos.Y + (yOffset * OFFSET_STUD_SCALE), pos.Z)
    local sPos, onScreen = WorldToScreen(anchorPos)
    if not onScreen or not sPos then
        label.Visible = false
        return nil
    end
    local fs = calcFontSize(baseFontSize, dist)
    applyTextStyle(label, fs)
    label.Center   = true
    label.Text     = text
    label.Position = Vector2.new(sPos.X, sPos.Y)
    label.Color    = color
    label.Visible  = true
    return sPos
end

local function getHelicopterPosition()
    local folder = Workspace:FindFirstChild("Helicopter")
    local model  = folder and folder:FindFirstChild("Helicopter")
    local root   = getRootPart(model)
    if root and root.Parent then return root.Position end

    local ok, pos = pcall(function()
        local rs   = ReplicatedStorage:FindFirstChild("ReplicatedState")
        local misc = rs and rs:FindFirstChild("MiscValues")
        if not misc then return nil end
        local heliOut = misc:FindFirstChild("HeliOut")
        local heliPos = misc:FindFirstChild("HeliPosition")
        if heliOut and heliOut.Value == true and heliPos then return heliPos.Value end
        return nil
    end)
    if ok and pos then return pos end
    return nil
end

local function getHeliScreenPos(worldPos)
    local margin = cfg.helicopter.edgeMargin or 50
    local sPos, onScreen = WorldToScreen(worldPos)
    if onScreen and sPos then return Vector2.new(sPos.X, sPos.Y), true end

    if cam and cam.WorldToViewportPoint then
        local ok, sp, _, depth = pcall(function() return cam:WorldToViewportPoint(worldPos) end)
        if ok and sp then
            local viewport = cam.ViewportSize
            if depth and depth < 0 then sp = Vector3.new(viewport.X - sp.X, viewport.Y - sp.Y, depth) end
            local x = math.clamp(sp.X, margin, viewport.X - margin)
            local y = math.clamp(sp.Y, margin, viewport.Y - margin)
            return Vector2.new(x, y), false
        end
    end
    return nil, false
end

----------------------------------------------------
-- CACHE UPDATES
----------------------------------------------------
local function updateCriminalCache()
    if not cfg.masterEnabled or not cfg.criminal.enabled then
        for i = #criminalList, 1, -1 do removeEsp(criminalList[i]) table.remove(criminalList, i) end
        return
    end

    local tracked = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.UserId ~= (LocalPlayer and LocalPlayer.UserId) then
            local isWanted = player:FindFirstChild("Is_Wanted")
            local val = isWanted and isWanted.Value
            if val and (type(val) ~= "number" or val > 0) then
                local key = getKey(player)
                if key then tracked[key] = player end
            end
        end
    end

    for i = #criminalList, 1, -1 do
        local e = criminalList[i]
        local key = getKey(e.Player)
        if not key or not tracked[key] or e.Player == LocalPlayer then
            removeEsp(e)
            table.remove(criminalList, i)
        else
            tracked[key] = nil
        end
    end

    for _, player in pairs(tracked) do
        if player ~= LocalPlayer then
            table.insert(criminalList, {
                Player = player,
                Label  = createTextEsp(cfg.criminal.fontSize),
                Circle = createCircleEsp()
            })
        end
    end
end

local function updatePanicCache()
    if not cfg.masterEnabled or not cfg.panic.enabled then
        for i = #panicList, 1, -1 do removeEsp(panicList[i]) table.remove(panicList, i) end
        return
    end

    local tracked = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local activePanic = player:FindFirstChild("ActivePanic") or (char and char:FindFirstChild("ActivePanic"))
            local isPanicActive = false
            if activePanic then
                if activePanic:IsA("BoolValue") then isPanicActive = activePanic.Value == true else isPanicActive = true end
            end
            if isPanicActive then
                local key = getKey(player)
                if key then tracked[key] = player end
            end
        end
    end

    for i = #panicList, 1, -1 do
        local e = panicList[i]
        local key = getKey(e.Player)
        if not key or not tracked[key] then
            removeEsp(e)
            table.remove(panicList, i)
        else
            tracked[key] = nil
        end
    end

    for _, player in pairs(tracked) do
        table.insert(panicList, { Player = player, Label = createTextEsp(cfg.panic.fontSize) })
    end
end

local function updateDeployableCache()
    if not cfg.masterEnabled or not cfg.deployable.enabled then
        for i = #deployableList, 1, -1 do removeEsp(deployableList[i]) table.remove(deployableList, i) end
        return
    end

    local folder = Workspace:FindFirstChild("Deployables")
    local tracked = {}
    if folder then
        for _, model in ipairs(folder:GetChildren()) do
            if model:IsA("Model") or model:IsA("Folder") then
                local key = getKey(model)
                if key then tracked[key] = model end
            end
        end
    end

    for i = #deployableList, 1, -1 do
        local e = deployableList[i]
        local key = getKey(e.Model)
        if not key or not tracked[key] then
            removeEsp(e)
            table.remove(deployableList, i)
        else
            tracked[key] = nil
        end
    end

    for _, model in pairs(tracked) do
        table.insert(deployableList, { Model = model, Label = createTextEsp(cfg.deployable.fontSize) })
    end
end

local function updateBountyCache()
    if not cfg.masterEnabled or not cfg.bountyVehicle.enabled then
        for i = #bountyList, 1, -1 do removeEsp(bountyList[i]) table.remove(bountyList, i) end
        return
    end

    local folder   = Workspace:FindFirstChild("BountyVehicles")
    local vehicles = folder and folder:FindFirstChild("Vehicles")
    local tracked  = {}
    if vehicles then
        for _, model in ipairs(vehicles:GetChildren()) do
            if model:IsA("Model") or model:IsA("Folder") then
                local key = getKey(model)
                if key then tracked[key] = model end
            end
        end
    end

    for i = #bountyList, 1, -1 do
        local e = bountyList[i]
        local key = getKey(e.Model)
        if not key or not tracked[key] then
            removeEsp(e)
            table.remove(bountyList, i)
        else
            tracked[key] = nil
        end
    end

    for _, model in pairs(tracked) do
        table.insert(bountyList, { Model = model, Label = createTextEsp(cfg.bountyVehicle.fontSize) })
    end
end

local function updateStolenCache()
    if not cfg.masterEnabled or not cfg.stolenVehicle.enabled then
        for i = #stolenList, 1, -1 do removeEsp(stolenList[i]) table.remove(stolenList, i) end
        return
    end

    local vehicles = Workspace:FindFirstChild("Vehicles")
    local tracked  = {}
    if vehicles then
        for _, model in ipairs(vehicles:GetChildren()) do
            if model:IsA("Model") or model:IsA("Folder") then
                local price = model:GetAttribute("ChopShopPrice")
                if typeof(price) == "number" then
                    local key = getKey(model)
                    if key then tracked[key] = model end
                end
            end
        end
    end

    for i = #stolenList, 1, -1 do
        local e = stolenList[i]
        local key = getKey(e.Model)
        if not key or not tracked[key] then
            removeEsp(e)
            table.remove(stolenList, i)
        else
            tracked[key] = nil
        end
    end

    for _, model in pairs(tracked) do
        table.insert(stolenList, {
            Model      = model,
            Label      = createTextEsp(cfg.stolenVehicle.fontSize),
            PriceLabel = createTextEsp(11)
        })
    end
end

local function updatePersonalCache()
    if not cfg.masterEnabled or not cfg.personalVehicle.enabled then
        for i = #personalList, 1, -1 do removeEsp(personalList[i]) table.remove(personalList, i) end
        return
    end

    local myName = LocalPlayer and LocalPlayer.Name
    if not myName then return end

    local vehicles = Workspace:FindFirstChild("Vehicles")
    local tracked  = {}
    if vehicles then
        for _, model in ipairs(vehicles:GetChildren()) do
            if model:IsA("Model") or model:IsA("Folder") then
                local owner = getOwnerString(model)
                if owner and owner == myName then
                    local key = getKey(model)
                    if key then tracked[key] = model end
                end
            end
        end
    end

    for i = #personalList, 1, -1 do
        local e = personalList[i]
        local key = getKey(e.Model)
        if not key or not tracked[key] then
            removeEsp(e)
            table.remove(personalList, i)
        else
            tracked[key] = nil
        end
    end

    for _, model in pairs(tracked) do
        table.insert(personalList, { Model = model, Label = createTextEsp(cfg.personalVehicle.fontSize) })
    end
end

local function updateVehicleHealthVisual(localPos, maxDist)
    if not cfg.masterEnabled or not cfg.vehicleHealth.enabled or not localPos then
        for _, st in pairs(vehicleHealthState) do if st.label then st.label.Visible = false end end
        return
    end

    local myName = LocalPlayer and LocalPlayer.Name
    if not myName then return end

    local now      = tick()
    local seen     = {}
    local nearDist = maxDist or cfg.settings.maxDistance or 5000
    local vehicles = Workspace:FindFirstChild("Vehicles")
    if not vehicles then return end

    for _, model in ipairs(vehicles:GetChildren()) do
        if model:IsA("Model") or model:IsA("Folder") then
            local owner = getOwnerString(model)
            if owner and owner == myName then
                local key = getKey(model)
                if key then
                    local root = getRootPart(model)
                    if root and root.Parent then
                        local pos  = root.Position
                        local dist = (pos - localPos).Magnitude
                        if dist <= nearDist then
                            seen[key] = true
                            local health = getVehicleHealth(model)
                            if typeof(health) == "number" then
                                local st = vehicleHealthState[key]
                                if not st then
                                    local mh = getVehicleMaxHealth(model) or health
                                    if mh < health then mh = health end
                                    if mh <= 0 then mh = 100 end
                                    st = {
                                        lastHealth = health,
                                        maxHealth  = mh,
                                        showUntil  = 0,
                                        label      = createTextEsp(cfg.vehicleHealth.fontSize),
                                        model      = model,
                                    }
                                    vehicleHealthState[key] = st
                                end
                                st.model = model

                                local realMax = getVehicleMaxHealth(model)
                                if realMax and realMax > 0 then
                                    st.maxHealth = realMax
                                elseif health > (st.maxHealth or 0) then
                                    st.maxHealth = health
                                end

                                if health < st.lastHealth then
                                    st.showUntil = now + (cfg.vehicleHealth.showSeconds or 5)
                                end
                                st.lastHealth = health

                                if now < st.showUntil then
                                    local text = "HP: " .. tostring(math.floor(health + 0.5))
                                    local col  = healthToColor(health, st.maxHealth)
                                    drawText(st.label, pos, text, col, cfg.vehicleHealth.yOffset, cfg.vehicleHealth.fontSize, dist)
                                else
                                    st.label.Visible = false
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for key, st in pairs(vehicleHealthState) do
        if not seen[key] then
            if st.label then st.label.Visible = false end
            if not st.model or not st.model.Parent then
                if st.label then pcall(function() st.label:Remove() end) end
                vehicleHealthState[key] = nil
            end
        end
    end
end

local function updateVisuals()
    if not cfg.masterEnabled then
        for _, list in ipairs({criminalList, panicList, deployableList, bountyList, stolenList, personalList}) do
            for _, e in ipairs(list) do hideEntry(e) end
        end
        for _, st in pairs(vehicleHealthState) do if st.label then st.label.Visible = false end end
        if heliLabel then heliLabel.Visible = false end
        if heliSpotlightLabel then heliSpotlightLabel.Visible = false end
        return
    end

    local localPos = getLocalPos()
    local maxDist  = cfg.settings.maxDistance
    local myName   = LocalPlayer and LocalPlayer.Name

    for _, e in ipairs(criminalList) do
        pcall(function()
            local player = e.Player
            if not player or not player.Parent or player == LocalPlayer then hideEntry(e) return end
            local char = player.Character
            local head = char and char:FindFirstChild("Head")
            if not head then hideEntry(e) return end

            local pos  = head.Position
            local dist = localPos and (pos - localPos).Magnitude or 0
            if localPos and dist > maxDist then hideEntry(e) return end

            local sPos, onScreen = WorldToScreen(pos)
            if onScreen and sPos then
                local radius = math.clamp(380 / (dist > 0 and dist or 1), 3, 8)
                e.Circle.Position = sPos
                e.Circle.Radius   = radius
                e.Circle.Color    = cfg.criminal.color
                e.Circle.Visible  = true

                local val = player:FindFirstChild("Is_Wanted")
                local wantedVal = val and val.Value or 0
                local fs = calcFontSize(cfg.criminal.fontSize, dist)
                applyTextStyle(e.Label, fs)
                e.Label.Text     = tostring(wantedVal)
                e.Label.Color    = cfg.criminal.color
                e.Label.Position = Vector2.new(sPos.X, sPos.Y + radius + 4)
                e.Label.Visible  = true
            else
                hideEntry(e)
            end
        end)
    end

    for _, e in ipairs(panicList) do
        pcall(function()
            local player = e.Player
            if not player or not player.Parent or player == LocalPlayer then hideEntry(e) return end
            local char = player.Character
            local head = char and char:FindFirstChild("Head")
            if not head then hideEntry(e) return end
            local pos  = head.Position
            local dist = localPos and (pos - localPos).Magnitude or 0
            if localPos and dist > maxDist then hideEntry(e) return end
            drawText(e.Label, pos, "*PANIC*", cfg.panic.color, cfg.panic.yOffset, cfg.panic.fontSize, dist)
        end)
    end

    for _, e in ipairs(deployableList) do
        pcall(function()
            local model = e.Model
            if not model or not model.Parent then hideEntry(e) return end
            local root = getRootPart(model)
            if not root then hideEntry(e) return end
            local pos  = root.Position
            local dist = localPos and (pos - localPos).Magnitude or 0
            if localPos and dist > maxDist then hideEntry(e) return end
            drawText(e.Label, pos, model.Name, cfg.deployable.color, cfg.deployable.yOffset, cfg.deployable.fontSize, dist)
        end)
    end

    for _, e in ipairs(bountyList) do
        pcall(function()
            local model = e.Model
            if not model or not model.Parent then hideEntry(e) return end
            local root = getRootPart(model)
            if not root then hideEntry(e) return end
            local pos  = root.Position
            local dist = localPos and (pos - localPos).Magnitude or 0
            if localPos and dist > maxDist then hideEntry(e) return end
            drawText(e.Label, pos, model.Name, cfg.bountyVehicle.color, cfg.bountyVehicle.yOffset, cfg.bountyVehicle.fontSize, dist)
        end)
    end

    for _, e in ipairs(stolenList) do
        pcall(function()
            local model = e.Model
            if not model or not model.Parent then hideEntry(e) return end
            local root = getRootPart(model)
            if not root then hideEntry(e) return end
            local pos  = root.Position
            local dist = localPos and (pos - localPos).Magnitude or 0
            if localPos and dist > maxDist then hideEntry(e) return end

            local sPos = drawText(e.Label, pos, "*Stolen Vehicle*", cfg.stolenVehicle.color, cfg.stolenVehicle.yOffset, cfg.stolenVehicle.fontSize, dist)
            if sPos and cfg.stolenVehicle.showPrice then
                local price = model:GetAttribute("ChopShopPrice") or 0
                local fs = calcFontSize(11, dist)
                applyTextStyle(e.PriceLabel, fs)
                e.PriceLabel.Text     = "$" .. tostring(price)
                e.PriceLabel.Color    = cfg.stolenVehicle.priceColor
                e.PriceLabel.Position = Vector2.new(sPos.X, sPos.Y + 16)
                e.PriceLabel.Visible  = true
            else
                e.PriceLabel.Visible = false
            end
        end)
    end

    for _, e in ipairs(personalList) do
        pcall(function()
            local model = e.Model
            if not model or not model.Parent then hideEntry(e) return end
            local driver = getDriverName(model)
            if myName and driver and driver == myName then hideEntry(e) return end
            local root = getRootPart(model)
            if not root then hideEntry(e) return end
            local pos  = root.Position
            local dist = localPos and (pos - localPos).Magnitude or 0
            if localPos and dist > maxDist then hideEntry(e) return end
            drawText(e.Label, pos, cfg.personalVehicle.text, cfg.personalVehicle.color, cfg.personalVehicle.yOffset, cfg.personalVehicle.fontSize, dist)
        end)
    end

    pcall(function() updateVehicleHealthVisual(localPos, maxDist) end)

    -- Helicopter
    if cfg.helicopter.enabled then
        if not heliLabel then
            heliLabel = createTextEsp(cfg.helicopter.fontSize)
            heliLabel.Color = cfg.helicopter.color
        end
        if not heliSpotlightLabel then
            heliSpotlightLabel = createTextEsp(cfg.helicopter.spotlightFontSize)
            heliSpotlightLabel.Color = cfg.helicopter.spotlightColor
        end

        local heliPos = getHelicopterPosition()
        if heliPos then
            local dist = localPos and (heliPos - localPos).Magnitude or 0
            local screenPos = getHeliScreenPos(heliPos)
            if screenPos then
                local fs = calcFontSize(cfg.helicopter.fontSize, dist)
                applyTextStyle(heliLabel, fs)
                heliLabel.Text     = cfg.helicopter.text
                heliLabel.Color    = cfg.helicopter.color
                heliLabel.Position = screenPos
                heliLabel.Visible  = true

                if cfg.helicopter.showSpotlight then
                    local spotlightNames = {}
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer then
                            local lastLoc = player:FindFirstChild("LastLocation")
                            local spotlighted = lastLoc and lastLoc:FindFirstChild("Spotlighted")
                            if spotlighted and spotlighted.Value == true then table.insert(spotlightNames, player.Name) end
                        end
                    end
                    if #spotlightNames > 0 then
                        local text = "Spotlighted: " .. table.concat(spotlightNames, ", ")
                        local sfs = calcFontSize(cfg.helicopter.spotlightFontSize, dist)
                        applyTextStyle(heliSpotlightLabel, sfs)
                        heliSpotlightLabel.Text     = text
                        heliSpotlightLabel.Color    = cfg.helicopter.spotlightColor
                        heliSpotlightLabel.Position = Vector2.new(screenPos.X, screenPos.Y + 16)
                        heliSpotlightLabel.Visible  = true
                    else
                        heliSpotlightLabel.Visible = false
                    end
                else
                    heliSpotlightLabel.Visible = false
                end
            else
                heliLabel.Visible = false
                heliSpotlightLabel.Visible = false
            end
        else
            heliLabel.Visible = false
            heliSpotlightLabel.Visible = false
        end
    else
        if heliLabel then heliLabel.Visible = false end
        if heliSpotlightLabel then heliSpotlightLabel.Visible = false end
    end
end

----------------------------------------------------
-- 1. ATM HACK (MODERN GRID SOLVER)
----------------------------------------------------
local function looksLikeCode(text)
    if type(text) ~= "string" then return nil end
    local s = text:gsub("%s+", "")
    if #s < 2 or #s > 6 or not s:match("^%w+$") then return nil end
    return s:upper()
end

local function gatherCodeNodes(root, depth, out, limit)
    if not root or depth > 5 or #out >= limit then return end
    pcall(function()
        for _, child in ipairs(root:GetChildren()) do
            if #out >= limit then break end
            local key = looksLikeCode(memText(child))
            if key then table.insert(out, { inst = child, key = key }) end
            gatherCodeNodes(child, depth + 1, out, limit)
        end
    end)
end

local function findCodeGrid(hacking)
    local candidates = {}
    gatherCodeNodes(hacking, 0, candidates, 300)
    local groups, bestGroup, bestCount = {}, nil, 0
    for _, c in ipairs(candidates) do
        local x, y = memAbsPos(c.inst)
        local sx, sy = memAbsSize(c.inst)
        if x and y and sx and sy and sx > 0 and sy > 0 then
            c.cx = x + sx / 2
            c.cy = y + sy / 2
            local sig = string.format("%d:%d", math.floor(sx / 3), math.floor(sy / 3))
            local g = groups[sig]
            if not g then g = {} groups[sig] = g end
            table.insert(g, c)
            if #g > bestCount then bestGroup, bestCount = g, #g end
        end
    end
    if not bestGroup or bestCount < 6 then return {} end
    return bestGroup
end

local function findLitIndex(nodes)
    local best, bestIdx, sum, count = nil, nil, 0, 0
    for i, n in ipairs(nodes) do
        local r, g, b = memColorRGB(n.inst)
        if r then
            local bright = r + g + b
            sum = sum + bright
            count = count + 1
            if not best or bright > best then best, bestIdx = bright, i end
        end
    end
    if not bestIdx or count < 2 then return nil end
    local avg = sum / count
    if best < avg * 1.12 or (best - avg) < 0.05 then return nil end
    return bestIdx
end

local atmState = {
    session = nil,
    nodes = {},
    nodesAt = 0,
    litIndex = nil,
    litSince = 0,
    stepTime = 0.12,
    succ = {},
    clickedRound = false,
    lastClick = 0,
    lastCode = "",
}

local function stepAtm()
    if not cfg.atm.enabled then return end
    local pg = getPlayerGui()
    local menus = pg and findChild(pg, "GameMenus")
    local atmUi = menus and findChild(menus, "ATM")
    local hacking = atmUi and findChild(atmUi, "Hacking")
    if not hacking or memVisible(hacking) == false then
        atmState.session = nil
        atmState.nodes = {}
        return
    end

    local sessionId = tostring(hacking.Address or hacking)
    if atmState.session ~= sessionId then
        atmState.session = sessionId
        atmState.nodes = {}
        atmState.litIndex = nil
        atmState.clickedRound = false
        atmState.lastCode = ""
    end

    local selecting = findChild(hacking, "SelectingCode")
    local now = os.clock()
    if #atmState.nodes == 0 or now - atmState.nodesAt > 0.25 then
        atmState.nodes = findCodeGrid(hacking)
        atmState.nodesAt = now
    end

    local nodes = atmState.nodes
    if #nodes == 0 then return end

    local target = looksLikeCode(selecting and memText(selecting) or nil)
    if not target then return end

    if target ~= atmState.lastCode then
        atmState.lastCode = target
        atmState.clickedRound = false
    end

    local goal = nil
    for i = 1, #nodes do
        if looksLikeCode(memText(nodes[i].inst)) == target or nodes[i].key == target then
            goal = nodes[i]
            break
        end
    end
    if not goal then return end

    local gx, gy = memAbsPos(goal.inst)
    local gsx, gsy = memAbsSize(goal.inst)
    if not gx or not gy or not gsx then return end

    local dist = moveMouseToward(gx + gsx / 2, gy + (gsy or 18) / 2)
    local onCell = dist <= math.max((gsx or 20) * 0.35, 10)

    local lit = findLitIndex(nodes)
    if lit and lit ~= atmState.litIndex then
        local prev = atmState.litIndex
        if prev then
            atmState.succ[prev] = lit
            local delta = now - atmState.litSince
            if delta > 0.01 and delta < 1 then atmState.stepTime = atmState.stepTime * 0.6 + delta * 0.4 end
        end
        atmState.litIndex = lit
        atmState.litSince = now
    end

    if not onCell then return end

    local liveKey = lit and looksLikeCode(memText(nodes[lit].inst)) or nil
    if atmState.clickedRound then
        local cycleTime = math.max(atmState.stepTime * #nodes + 0.3, 0.6)
        if now - atmState.lastClick <= cycleTime then return end
        atmState.clickedRound = false
    end

    local delay = math.max((tonumber(cfg.atm.delay) or 50) / 1000, 0.03)
    if now - atmState.lastClick < delay then return end

    local ready = liveKey == target
    if ready then
        pcall(mouse1click)
        atmState.lastClick = now
        atmState.clickedRound = true
    end
end

----------------------------------------------------
-- 2. LOCKPICK
----------------------------------------------------
local lockpickState = { pin = 1, session = nil, lastClick = 0, pinY = nil, pinT = 0, vel = 0 }

local function pinOverlapsLine(pin, line, pad)
    local pinC = findChild(pin, "Center") or pin
    local lineC = findChild(line, "Center") or line
    local _, py = memAbsPos(pinC)
    local _, ly = memAbsPos(lineC)
    local _, ph = memAbsSize(pin)
    local _, lh = memAbsSize(line)
    if not py or not ly or not ph or not lh then
        local pr, lr = guiRect(pin), guiRect(line)
        if not pr or not lr then return false end
        pad = pad or 0
        return (pr.y + pad) < (lr.y + lr.h) and lr.y < (pr.y + pr.h - pad)
    end
    pad = pad or 0
    local pTop, pBot = py - ph / 2 + pad, py + ph / 2 - pad
    local lTop, lBot = ly - lh / 2, ly + lh / 2
    return pTop <= lBot and lTop <= pBot
end

local function stepLockpick()
    if not cfg.lockpick.enabled then return end
    local pg = getPlayerGui()
    local menus = pg and findChild(pg, "GameMenus")
    local ui = menus and findChild(menus, "Lockpick")
    if not ui or memVisible(ui) == false then
        lockpickState.session = nil
        lockpickState.pin = 1
        return
    end

    local pick = findChild(ui, "Pick")
    local line = pick and findChild(pick, "RedLine")
    if not pick or not line or not inViewport(pick, 8) then return end

    local sessionId = tostring(pick.Address or pick)
    if lockpickState.session ~= sessionId then
        lockpickState.session = sessionId
        lockpickState.pin = 1
        lockpickState.pinY = nil
        lockpickState.vel = 0
    end
    if lockpickState.pin > 6 then return end

    local pin = findChild(pick, tostring(lockpickState.pin))
    if not pin then return end

    local now = os.clock()
    local delay = math.max((tonumber(cfg.lockpick.delay) or 40) / 1000, 0.03)
    if now - lockpickState.lastClick < delay then return end

    local pad = math.max(tonumber(cfg.lockpick.tolerance) or 2, 0)
    if pinOverlapsLine(pin, line, pad) then
        pcall(mouse1click)
        lockpickState.lastClick = now
        lockpickState.pin = lockpickState.pin + 1
        lockpickState.pinY = nil
        lockpickState.vel = 0
    end
end

----------------------------------------------------
-- 3. GLASS CUTTING
----------------------------------------------------
local glassState = { lastX = nil, lastY = nil, lastT = 0, velX = 0, velY = 0 }

local function stepGlassCut()
    if not cfg.glasscut.enabled then return end
    local pg = getPlayerGui()
    local menus = pg and findChild(pg, "GameMenus")
    local cut = menus and findChild(menus, "GlassCutting")
    if not cut or memVisible(cut) == false then
        glassState.lastX, glassState.lastY = nil, nil
        return
    end

    local box = findChild(cut, "GreenBox")
    if not box then return end

    local vw, vh = viewportSize()
    local x, y = memAbsPos(box)
    local sx, sy = memAbsSize(box)
    if not x or not y or not sx or not sy or sx < 4 or sy < 4 then return end

    local cx, cy = x + sx / 2, y + sy / 2
    local now = os.clock()
    if glassState.lastX and glassState.lastT > 0 then
        local dt = now - glassState.lastT
        if dt > 0 and dt < 0.2 then
            glassState.velX = glassState.velX * 0.4 + ((cx - glassState.lastX) / dt) * 0.6
            glassState.velY = glassState.velY * 0.4 + ((cy - glassState.lastY) / dt) * 0.6
        end
    end
    glassState.lastX, glassState.lastY, glassState.lastT = cx, cy, now

    local lead = math.max((tonumber(cfg.glasscut.lead) or 0) / 1000, 0)
    local tx, ty = cx + glassState.velX * lead, cy + glassState.velY * lead
    moveMouseToward(tx, ty)
end

----------------------------------------------------
-- 4. HOTWIRE & CROWBAR SUITE (BAR, WIRES & NUMBERS)
----------------------------------------------------

-- A. Timing Bar
local crowBarState = { barX = nil, barT = 0, vel = 0, frameDt = nil, lastClick = 0 }

local function stepCrowbarBar(menus, now)
    local crow = findChild(menus, "Crowbar")
    local main = findChild(crow, "Main")
    local gameF = findChild(main, "Game")
    local bar = findChild(gameF, "Indicator")
    local zone = findChild(gameF, "Target")
    if not bar or not zone or memVisible(crow) ~= true or memVisible(main) == false then return false end

    local barRect = guiRect(bar)
    local zoneRect = guiRect(zone)
    if not barRect or not zoneRect or zoneRect.w < 4 or not inViewport(zone, 20) then return false end

    local prevX, prevT = crowBarState.barX, crowBarState.barT
    crowBarState.barX, crowBarState.barT = barRect.cx, now
    if prevX and prevT > 0 then
        local dt = now - prevT
        if dt > 0 and dt < 0.25 then
            crowBarState.frameDt = dt
            local v = (barRect.cx - prevX) / dt
            if crowBarState.vel ~= 0 and v ~= 0 and (v > 0) ~= (crowBarState.vel > 0) then
                crowBarState.vel = v
            else
                crowBarState.vel = crowBarState.vel * 0.5 + v * 0.5
            end
        else
            crowBarState.vel = 0
        end
    end

    if math.abs(crowBarState.vel) < 5 then return true end

    local latency = math.max((tonumber(cfg.hotwire.latency) or 50) / 1000, 0)
    local frameDt = math.min(crowBarState.frameDt or (1 / 60), 0.05)
    local marginPct = math.min(math.max(tonumber(cfg.hotwire.margin) or 25, 0), 45) / 100
    local inset = zoneRect.w * marginPct / 2
    local fromX = barRect.cx + crowBarState.vel * latency
    local toX = fromX + crowBarState.vel * frameDt
    local lo, hi = math.min(fromX, toX), math.max(fromX, toX)

    local delay = math.max((tonumber(cfg.hotwire.delay) or 50) / 1000, 0.05)
    if now - crowBarState.lastClick >= delay then
        if lo <= zoneRect.x + zoneRect.w - inset and hi >= zoneRect.x + inset then
            pcall(mouse1click)
            crowBarState.lastClick = now
        end
    end
    return true
end

-- B. Numbers Hack
local numHackState = {
    session = nil,
    seq = {},
    lastDigit = nil,
    lastDigitAt = 0,
    lastVisible = false,
    hiddenSince = 0,
    shownAt = 0,
    seenDigit = nil,
    seenCount = 0,
    playing = false,
    playIndex = 1,
    lastClick = 0,
    goClicked = false,
}

local function parseDigit(text)
    if type(text) ~= "string" then return nil end
    local d = tonumber(text:match("(%d)"))
    if d and d >= 1 and d <= 6 then return tostring(d) end
    return nil
end

local function stepNumbersHack(menus, now)
    local root = findChild(menus, "NumbersHack")
    if not root or memVisible(root) == false then
        numHackState.session = nil
        return false
    end

    local sessionId = tostring(root.Address or root)
    if numHackState.session ~= sessionId then
        numHackState.session = sessionId
        numHackState.seq = {}
        numHackState.playing = false
        numHackState.playIndex = 1
        numHackState.lastDigit = nil
        numHackState.goClicked = false
    end

    local screen = findPath(root, "Background", "ScreenBase", "ScreenUIBase")
    local main = findChild(screen, "MainScreen")
    local startF = findChild(main, "Start")
    local goBtn = findChild(startF, "GO")
    local currentImg = findChild(main, "CurrentNumber")
    local current = findChild(currentImg, "Number") or currentImg
    local buttons = findChild(screen, "NumberButtons")

    if startF and memVisible(startF) == true and goBtn and not numHackState.goClicked then
        if select(1, clickAtGui(goBtn, 18)) then
            numHackState.goClicked = true
            numHackState.lastClick = now
            numHackState.seq = {}
        end
        return true
    end

    if numHackState.playing then
        local digit = numHackState.seq[numHackState.playIndex]
        if not digit then
            numHackState.playing = false
            numHackState.seq = {}
            numHackState.playIndex = 1
            return true
        end
        local btn = buttons and findChild(buttons, digit)
        if not btn then return true end

        local delay = 0.16
        if now - numHackState.lastClick >= delay then
            if select(1, clickAtGui(btn, 14)) then
                numHackState.lastClick = now
                numHackState.playIndex = numHackState.playIndex + 1
            end
        end
        return true
    end

    local shown = memVisible(currentImg)
    if shown == true then
        if not numHackState.lastVisible then
            numHackState.shownAt = now
            numHackState.seenDigit = nil
            numHackState.seenCount = 0
        end
        numHackState.lastVisible = true
        numHackState.hiddenSince = 0
        local digit = parseDigit(memText(current))
        if digit then
            if digit == numHackState.seenDigit then
                numHackState.seenCount = numHackState.seenCount + 1
            else
                numHackState.seenDigit = digit
                numHackState.seenCount = 1
            end
            local stable = (now - (numHackState.shownAt or 0)) >= 0.12 and numHackState.seenCount >= 2
            local gapOk = (now - (numHackState.lastDigitAt or 0)) >= 0.38
            if stable and gapOk and digit ~= numHackState.lastDigit and #numHackState.seq < 6 then
                table.insert(numHackState.seq, digit)
                numHackState.lastDigit = digit
                numHackState.lastDigitAt = now
            end
        end
    else
        if numHackState.lastVisible then numHackState.hiddenSince = now end
        numHackState.lastVisible = false
        numHackState.seenDigit = nil
        numHackState.seenCount = 0
    end

    local hiddenLongEnough = numHackState.hiddenSince > 0 and (now - numHackState.hiddenSince) >= 0.3
    local lastAged = (now - (numHackState.lastDigitAt or 0)) >= 0.45
    if #numHackState.seq >= 6 and shown == false and hiddenLongEnough and lastAged then
        numHackState.playing = true
        numHackState.playIndex = 1
    end
    return true
end

-- C. Wire Pairing (Connect Wires Solver)
local WIRE_COLORS = { "Blue", "Green", "Red", "Yellow" }
local wireState = { session = nil, phase = "aim", held = false, lastDone = 0, releasedAt = 0, nearSince = 0, currentColor = nil, done = {} }

local function wireSide(name)
    if type(name) ~= "string" then return nil, nil end
    return name:match("^(%a+)Wire([LR])$")
end

local function findActiveTangleFolder(ui)
    local folder = findChild(ui, "TangledWires")
    if not folder then return nil end
    local best, bestArea = nil, 0
    pcall(function()
        for _, child in ipairs(folder:GetChildren()) do
            if memVisible(child) ~= false then
                local w, h = memAbsSize(child)
                if w and h and w > 40 and h > 40 then
                    local area = w * h
                    if area > bestArea then
                        best, bestArea = child, area
                    end
                end
            end
        end
    end)
    return best or folder
end

local function findWireDropTarget(ui, pair)
    local tangle = findActiveTangleFolder(ui)
    if not tangle then return nil end

    local wireName = pair.right:GetAttribute("WireName")
        or pair.rightDrag:GetAttribute("WireName")
        or (pair.rightDrag:FindFirstChild("Contact") and pair.rightDrag.Contact:GetAttribute("WireName"))
        or pair.left:GetAttribute("WireName")

    if wireName then
        local wire = findChild(tangle, wireName)
        local contact = wire and (findChild(wire, "Contact") or wire)
        if contact and guiRect(contact) then return contact end
    end

    pcall(function()
        for _, child in ipairs(tangle:GetDescendants()) do
            if wireName and child.Name == wireName then
                local contact = findChild(child, "Contact") or child
                if contact and guiRect(contact) then
                    return contact
                end
            end
        end
    end)

    return nil
end

local function isWireConnected(ui, pair)
    local ok, c = pcall(function() return pair.leftDrag:GetAttribute("Connected") or pair.left:GetAttribute("Connected") end)
    if ok and c == true then return true end

    local lights = findChild(ui, "WireLights")
    local light = lights and findChild(lights, pair.color .. "Light")
    local base = light and findChild(light, "Base")
    local inner = base and (findChild(base, "InnerCircle") or base)
    local lightDot = inner and (findChild(inner, "Light") or inner)
    if lightDot then
        local r, g, b = memColorRGB(lightDot)
        return r > 0.8 and g > 0.8 and b > 0.8
    end
    return false
end

local function stepConnectWires(menus, now)
    local ui = findChild(menus, "ConnectWires")
    if not ui or memVisible(ui) ~= true then
        if wireState.held then pcall(mouse1release) end
        wireState.session = nil
        wireState.held = false
        wireState.phase = "aim"
        wireState.done = {}
        return false
    end

    if not wireState.session then
        wireState.session = tostring(now)
        wireState.phase = "aim"
        wireState.done = {}
    end

    local lefts, rights = {}, {}
    for _, child in ipairs(ui:GetChildren()) do
        local color, side = wireSide(child.Name)
        if color and guiRect(child) then
            local drag = findChild(child, "Drag") or child
            if side == "L" then lefts[color] = { frame = child, drag = drag }
            else rights[color] = { frame = child, drag = drag } end
        end
    end

    local pair = nil
    for _, col in ipairs(WIRE_COLORS) do
        if lefts[col] and rights[col] then
            local p = { color = col, left = lefts[col].frame, right = rights[col].frame, leftDrag = lefts[col].drag, rightDrag = rights[col].drag }
            if isWireConnected(ui, p) then
                wireState.done[col] = true
            elseif not wireState.done[col] then
                pair = p
                break
            end
        end
    end

    if not pair then
        if wireState.held then pcall(mouse1release) wireState.held = false end
        return true
    end

    local dropInst = findWireDropTarget(ui, pair)
    local grab = guiRect(pair.leftDrag) or guiRect(pair.left)
    local drop = guiRect(dropInst)

    if not grab or not drop then return true end
    local aimX, aimY = drop.x + drop.w * 0.5, drop.y

    if wireState.phase == "aim" then
        local dist = moveMouseToward(grab.cx, grab.cy)
        if dist <= 10 then
            pcall(mouse1press)
            wireState.held = true
            wireState.phase = "hold"
            wireState.lastDone = now
        end
        return true
    end

    if wireState.phase == "hold" then
        if now - wireState.lastDone >= 0.05 then wireState.phase = "drag" end
        return true
    end

    local dist = moveMouseToward(aimX, aimY)
    if dist <= 10 then
        pcall(mouse1release)
        wireState.held = false
        wireState.phase = "aim"
        wireState.lastDone = now
        task.wait(0.1)
    end
    return true
end

----------------------------------------------------
-- AUTOFARM RUNNER THREADS
----------------------------------------------------
task.spawn(function()
    while true do
        pcall(stepAtm)
        pcall(stepLockpick)
        task.wait(0.01)
    end
end)

if RunService then
    RunService.RenderStepped:Connect(function()
        pcall(stepGlassCut)
    end)
end

task.spawn(function()
    while true do
        local ok, menus = pcall(function()
            local pg = getPlayerGui()
            return pg and findChild(pg, "GameMenus")
        end)
        if ok and menus and cfg.hotwire.enabled then
            local now = os.clock()
            if memVisible(findChild(menus, "NumbersHack")) == true then
                pcall(stepNumbersHack, menus, now)
            elseif memVisible(findChild(menus, "ConnectWires")) == true then
                pcall(stepConnectWires, menus, now)
            else
                pcall(stepCrowbarBar, menus, now)
            end
        end
        task.wait(0.01)
    end
end)

----------------------------------------------------
-- ESP BACKGROUND THREADS
----------------------------------------------------
task.spawn(function()
    while true do
        pcall(updateCriminalCache)
        pcall(updatePanicCache)
        pcall(updateDeployableCache)
        pcall(updateBountyCache)
        pcall(updateStolenCache)
        pcall(updatePersonalCache)
        task.wait(0.5)
    end
end)

task.spawn(function()
    while true do
        pcall(updateVisuals)
        task.wait()
    end
end)

-- Alt key toggle for Master ESP
local lastAltState = false
task.spawn(function()
    while true do
        if iskeypressed then
            local altPressed = iskeypressed(0x12)
            if altPressed and not lastAltState then
                local newState = not cfg.masterEnabled
                cfg.masterEnabled = newState
                notify("ERLC ESP", newState and "ESP: ON" or "ESP: OFF", 2)
            end
            lastAltState = altPressed
        end
        task.wait(0.05)
    end
end)

notify("ERLC ESP", "Full ESP & Autos Ready — Update #21 (NonUI)", 3)
print("ERLC Full ESP + Hotwire Suite loaded successfully (NonUI)!")
