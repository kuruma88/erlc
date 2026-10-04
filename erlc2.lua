-- ERLC Full ESP + NonUI + Autofarms (Update #22 - performance build)
-- * Collector/renderer split: all instance lookups run at 2-7 Hz, the per-frame renderer only reads cached parts
-- * Drawing pool + change-only property writes (no per-frame Font/Size/Color/Text spam)
-- * Single RenderStepped connection, idle autofarm loop sleeps when nothing is enabled
-- * Roblox update fix: GUI memory offsets shifted by -16 (Visible/AbsolutePosition/AbsoluteSize/BackgroundColor3),
--   AbsoluteSize property now reads 0 so memory is read first, offsets auto-calibrate on load
-- * ConnectWires: wire buttons now live under "ConnectWires LS.Wires" (handled)

local Players            = game:GetService("Players")
local Workspace          = workspace or game:GetService("Workspace")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local LocalPlayer        = Players.LocalPlayer
local cam                = Workspace and Workspace.CurrentCamera

local floor, sqrt, abs, max, min = math.floor, math.sqrt, math.abs, math.max, math.min

----------------------------------------------------
-- RE-EXECUTE CLEANUP + SAFE RUNNER
----------------------------------------------------
if _G.__ERLC_ESP then pcall(_G.__ERLC_ESP.stop) end

local ALIVE = true
local allDrawings = {}
local conns = {}

_G.__ERLC_ESP = {
    stop = function()
        ALIVE = false
        for _, c in ipairs(conns) do
            pcall(function() c:Disconnect() end)
        end
        for d in pairs(allDrawings) do
            pcall(function() d.Visible = false; d:Remove() end)
        end
        allDrawings = {}
    end
}

local lastErr = {}
local function safe(name, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        local msg = tostring(err)
        if lastErr[name] ~= msg then
            lastErr[name] = msg
            local out = (type(warn) == "function") and warn or print
            pcall(out, "[ERLC] " .. name .. ": " .. msg)
        end
    end
end

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
        espRate     = 0, -- 0 = every frame, otherwise max ESP redraws per second
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

local fontVer = 0
local function getEspFont()
    return FONT_MAP[cfg.settings.fontName] or Drawing.Fonts.SystemBold
end

----------------------------------------------------
-- MEMORY OFFSETS & UNCACHED READING
----------------------------------------------------
-- Defaults for Roblox version-02c37bc51a384b8f (verified live). calibrate() re-derives them after future updates.
local GUI_OFF = {
    Visible          = 1437,
    Text             = 3568, -- short strings only (property read is used first)
    BackgroundColor3 = 1328,
    AbsolutePosition = 252,
    AbsoluteSize     = 260,
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

-- NOTE: the AbsoluteSize property currently returns 0x0 for every GuiObject, so memory is read first.
local function memAbsSize(inst)
    local addr = rawAddr(inst)
    if addr then
        local base = addr + GUI_OFF.AbsoluteSize
        local x = memRead("float", base)
        local y = memRead("float", base + 4)
        if x and y and (x > 0 or y > 0) then return x, y end
    end
    local size = nil
    pcall(function() size = inst.AbsoluteSize end)
    if size and size.X and size.Y and (size.X > 0 or size.Y > 0) then return size.X, size.Y end
    if addr then
        local x = memRead("float", addr + GUI_OFF.AbsoluteSize)
        local y = memRead("float", addr + GUI_OFF.AbsoluteSize + 4)
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

-- Cached GameMenus lookup (was re-resolved every 10 ms before)
local menusRef, menusAt = nil, -10
local function getMenus()
    local now = os.clock()
    if menusRef and now - menusAt < 3 then return menusRef end
    local pg = getPlayerGui()
    menusRef = pg and findChild(pg, "GameMenus") or nil
    menusAt = now
    return menusRef
end

-- Re-derives the GUI offsets from a visible element whose AbsolutePosition the API can still read.
-- Visible = pos + 1185, BackgroundColor3 = pos + 1076, AbsoluteSize = pos + 8 (relations held across the last update).
local function calibrate()
    local pg = getPlayerGui()
    local gg = pg and findChild(pg, "GameGui")
    if not gg then return false, "GameGui not found" end
    local sample = nil
    local px, py = nil, nil
    local function consider(inst)
        if sample then return end
        local p = nil
        pcall(function() p = inst.AbsolutePosition end)
        if p and p.X and p.Y and p.X > 1 and p.Y > 1 and abs(p.X - p.Y) > 2 then
            sample, px, py = inst, p.X, p.Y
        end
    end
    pcall(function()
        for _, c in ipairs(gg:GetChildren()) do
            consider(c)
            if sample then break end
            for _, c2 in ipairs(c:GetChildren()) do
                consider(c2)
                if sample then break end
            end
            if sample then break end
        end
    end)
    if not sample then return false, "no positioned GUI element found" end
    local base = rawAddr(sample)
    if not base then return false, "no address" end
    for off = 128, 512, 4 do
        local x = memRead("float", base + off)
        local y = memRead("float", base + off + 4)
        if x and y and abs(x - px) < 0.6 and abs(y - py) < 0.6 then
            GUI_OFF.AbsolutePosition = off
            GUI_OFF.AbsoluteSize     = off + 8
            GUI_OFF.Visible          = off + 1185
            GUI_OFF.BackgroundColor3 = off + 1076
            return true, off
        end
    end
    return false, "position pair not found in memory"
end
pcall(calibrate)

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
    local dist = sqrt(dx * dx + dy * dy)
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
    Author    = "Update #22",
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

tab:Slider({
    Title    = "ESP Update Rate (0 = every frame)",
    Default  = cfg.settings.espRate,
    Min      = 0,
    Max      = 240,
    Step     = 5,
    Suffix   = " fps",
    Callback = function(v) cfg.settings.espRate = v end,
})

tab:Dropdown({
    Title    = "Font",
    Values   = FONT_NAMES,
    Default  = cfg.settings.fontName,
    Callback = function(v) cfg.settings.fontName = v; fontVer = fontVer + 1 end,
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
    Title    = "Recalibrate GUI Offsets",
    Callback = function()
        local ok, info = calibrate()
        notify("ERLC ESP", ok and ("Offsets calibrated (pos @" .. tostring(info) .. ")") or ("Calibration failed: " .. tostring(info)), 3)
    end,
})
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
        cfg.settings.espRate         = 0

        cfg.atm.enabled      = false
        cfg.lockpick.enabled = false
        cfg.glasscut.enabled = false
        cfg.hotwire.enabled  = false

        notify("ERLC ESP", "Defaults restored", 2)
    end,
})

----------------------------------------------------
-- DRAWING POOL + CHANGE-ONLY LABELS
----------------------------------------------------
local OFFSET_STUD_SCALE = 0.1

local textFree, circleFree = {}, {}

local function acquireText()
    local d = table.remove(textFree)
    if d then return d end
    d = Drawing.new("Text")
    d.Center  = true
    d.Outline = true
    d.ZIndex  = 120
    d.Visible = false
    allDrawings[d] = true
    return d
end

local function acquireCircle()
    local d = table.remove(circleFree)
    if d then return d end
    d = Drawing.new("Circle")
    d.Filled       = true
    d.NumSides     = 10
    d.Thickness    = 1
    d.Transparency = 0
    d.ZIndex       = 119
    d.Visible      = false
    allDrawings[d] = true
    return d
end

local function newLabel()
    return { d = acquireText(), vis = false, text = nil, fs = -1, fv = -1, r = -1, g = -1, b = -1, x = -1, y = -1 }
end

local function freeLabel(l)
    if l and l.d then
        l.d.Visible = false
        textFree[#textFree + 1] = l.d
        l.d = nil
        l.vis = false
    end
end

local function showLabel(l, text, color, fs, x, y)
    local d = l.d
    if not d then return end
    fs = max(8, floor(tonumber(fs) or 10))
    if l.fs ~= fs or l.fv ~= fontVer then
        pcall(function() d.Size = fs end)
        pcall(function() d.Font = getEspFont() end)
        pcall(function() d.FontSize = fs end)
        l.fs, l.fv = fs, fontVer
    end
    if l.text ~= text then d.Text = text; l.text = text end
    local r, g, b = color.R, color.G, color.B
    if l.r ~= r or l.g ~= g or l.b ~= b then
        d.Color = color
        l.r, l.g, l.b = r, g, b
    end
    if l.x ~= x or l.y ~= y then
        d.Position = Vector2.new(x, y)
        l.x, l.y = x, y
    end
    if not l.vis then d.Visible = true; l.vis = true end
end

local function hideLabel(l)
    if l and l.vis and l.d then
        l.d.Visible = false
        l.vis = false
    end
end

local function newCircle()
    return { d = acquireCircle(), vis = false, rad = -1, r = -1, g = -1, b = -1, x = -1, y = -1 }
end

local function freeCircle(c)
    if c and c.d then
        c.d.Visible = false
        circleFree[#circleFree + 1] = c.d
        c.d = nil
        c.vis = false
    end
end

local function showCircle(c, x, y, radius, color)
    local d = c.d
    if not d then return end
    if c.rad ~= radius then d.Radius = radius; c.rad = radius end
    local r, g, b = color.R, color.G, color.B
    if c.r ~= r or c.g ~= g or c.b ~= b then
        d.Color = color
        c.r, c.g, c.b = r, g, b
    end
    if c.x ~= x or c.y ~= y then
        d.Position = Vector2.new(x, y)
        c.x, c.y = x, y
    end
    if not c.vis then d.Visible = true; c.vis = true end
end

local function hideCircle(c)
    if c and c.vis and c.d then
        c.d.Visible = false
        c.vis = false
    end
end

local function getLbl(e, field)
    local l = e[field]
    if not l then
        l = newLabel()
        e[field] = l
    end
    return l
end

local function getCirc(e)
    local c = e.circle
    if not c then
        c = newCircle()
        e.circle = c
    end
    return c
end

local function freeEntry(e)
    if e.label then freeLabel(e.label); e.label = nil end
    if e.price then freeLabel(e.price); e.price = nil end
    if e.hpLabel then freeLabel(e.hpLabel); e.hpLabel = nil end
    if e.circle then freeCircle(e.circle); e.circle = nil end
end

local function hideField(e, field)
    local l = e[field]
    if l then hideLabel(l) end
end

local function hideAll(arr, field)
    for i = 1, #arr do hideField(arr[i], field) end
end

-- Category = persistent entry map + flat array rebuilt by the collector
local function newCat() return { map = {}, arr = {}, mark = 0 } end

local crimCat, panicCat, deployCat, bountyCat, stolenCat, ownCat =
    newCat(), newCat(), newCat(), newCat(), newCat(), newCat()

local function beginCat(cat) cat.mark = cat.mark + 1 end

local function touch(cat, key)
    local e = cat.map[key]
    if not e then
        e = {}
        cat.map[key] = e
    end
    e.mark = cat.mark
    return e
end

local function endCat(cat)
    local arr = {}
    for k, e in pairs(cat.map) do
        if e.mark ~= cat.mark then
            freeEntry(e)
            cat.map[k] = nil
        else
            arr[#arr + 1] = e
        end
    end
    cat.arr = arr
end

local function clearCat(cat)
    if next(cat.map) == nil then return end
    for _, e in pairs(cat.map) do freeEntry(e) end
    cat.map = {}
    cat.arr = {}
end

----------------------------------------------------
-- SMALL GAME HELPERS
----------------------------------------------------
local function getRootPart(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart")
end

local function getStringField(model, name)
    if not model then return nil end
    local attr = model:GetAttribute(name)
    if type(attr) == "string" and attr ~= "" then return attr end
    local child = model:FindFirstChild(name)
    if child then
        local v = child.Value
        if type(v) == "string" then return v end
        if typeof(v) == "Instance" and v.ClassName == "Player" then return v.Name end
    end
    return nil
end

local function getVehicleMaxHealth(model)
    if not model then return nil end
    local cv = model:FindFirstChild("Control_Values")
    if not cv then return nil end
    for _, name in ipairs({ "MaxHealth", "Max_Health", "maxHealth", "HealthMax", "MaxHP" }) do
        local obj = cv:FindFirstChild(name)
        if obj and type(obj.Value) == "number" and obj.Value > 0 then return obj.Value end
    end
    return nil
end

local function healthToColor(health, maxHealth)
    local maxH = tonumber(maxHealth) or 0
    if maxH <= 0 then maxH = 100 end
    local t = clamp((tonumber(health) or 0) / maxH, 0, 1)
    return Color3.new(1 - t, t, 0.12)
end

local function calcFontSize(baseSize, dist)
    baseSize = tonumber(baseSize) or 10
    local dynamic = tonumber(cfg.settings.dynamicSize) or 0
    if dynamic <= 0 then return baseSize end
    local distNorm = min((tonumber(dist) or 0) / 400, 1)
    local intensity = dynamic / 10
    local minScale = 1 - intensity * 0.5
    local maxScale = 1 + intensity * 0.5
    local scale = minScale + distNorm * (maxScale - minScale)
    return max(8, floor(baseSize * scale + 0.5))
end

----------------------------------------------------
-- COLLECTORS (slow, do all instance lookups)
----------------------------------------------------
local myName, myId = LocalPlayer and LocalPlayer.Name, LocalPlayer and LocalPlayer.UserId
local localRoot = nil
local spotText = nil
local heliPart, heliOutObj, heliPosObj = nil, nil, nil

local function collectPlayers(master)
    local critOn  = master and cfg.criminal.enabled
    local panicOn = master and cfg.panic.enabled
    local spotOn  = master and cfg.helicopter.enabled and cfg.helicopter.showSpotlight

    if critOn then beginCat(crimCat) else clearCat(crimCat) end
    if panicOn then beginCat(panicCat) else clearCat(panicCat) end
    if not (critOn or panicOn or spotOn) then spotText = nil return end

    local names = nil
    for _, p in ipairs(Players:GetPlayers()) do
        local uid = p.UserId
        if uid ~= myId then
            local char = p.Character
            local head = nil

            if critOn then
                local iw = p:FindFirstChild("Is_Wanted")
                local val = iw and iw.Value
                if val and (type(val) ~= "number" or val > 0) then
                    head = char and char:FindFirstChild("Head")
                    local e = touch(crimCat, uid)
                    e.part = head
                    e.text = tostring(val)
                end
            end

            if panicOn then
                local ap = p:FindFirstChild("ActivePanic") or (char and char:FindFirstChild("ActivePanic"))
                if ap then
                    local active = true
                    if ap.ClassName == "BoolValue" then active = ap.Value == true end
                    if active then
                        head = head or (char and char:FindFirstChild("Head"))
                        local e = touch(panicCat, uid)
                        e.part = head
                        e.text = "*PANIC*"
                    end
                end
            end

            if spotOn then
                local ll = p:FindFirstChild("LastLocation")
                local s = ll and ll:FindFirstChild("Spotlighted")
                if s and s.Value == true then
                    names = names or {}
                    names[#names + 1] = p.Name
                end
            end
        end
    end

    if critOn then endCat(crimCat) end
    if panicOn then endCat(panicCat) end
    spotText = names and ("Spotlighted: " .. table.concat(names, ", ")) or nil
end

local function collectModels(cat, on, parent, textOverride)
    if not on then clearCat(cat) return end
    beginCat(cat)
    if parent then
        for _, m in ipairs(parent:GetChildren()) do
            local cn = m.ClassName
            if cn == "Model" or cn == "Folder" then
                local e = touch(cat, m.Address or tostring(m))
                e.part = getRootPart(m)
                e.text = textOverride or m.Name
            end
        end
    end
    endCat(cat)
end

local function collectVehicles(master)
    local stolenOn = master and cfg.stolenVehicle.enabled
    local ownOn    = master and (cfg.personalVehicle.enabled or cfg.vehicleHealth.enabled)

    if stolenOn then beginCat(stolenCat) else clearCat(stolenCat) end
    if ownOn then beginCat(ownCat) else clearCat(ownCat) end
    if not (stolenOn or ownOn) then return end

    local vehicles = Workspace:FindFirstChild("Vehicles")
    if vehicles then
        for _, m in ipairs(vehicles:GetChildren()) do
            local cn = m.ClassName
            if cn == "Model" or cn == "Folder" then
                if stolenOn then
                    local price = m:GetAttribute("ChopShopPrice")
                    if type(price) == "number" then
                        local e = touch(stolenCat, m.Address or tostring(m))
                        e.part = getRootPart(m)
                        e.text = "*Stolen Vehicle*"
                        e.priceText = "$" .. tostring(price)
                    end
                end
                if ownOn and myName and getStringField(m, "Owner") == myName then
                    local e = touch(ownCat, m.Address or tostring(m))
                    e.part = getRootPart(m)
                    e.text = cfg.personalVehicle.text
                    local driver = getStringField(m, "DriverName")
                    e.hidden = (driver ~= nil and driver == myName)
                    local cv = m:FindFirstChild("Control_Values")
                    e.healthObj = cv and cv:FindFirstChild("Health") or nil
                    e.realMax = getVehicleMaxHealth(m)
                end
            end
        end
    end

    if stolenOn then endCat(stolenCat) end
    if ownOn then endCat(ownCat) end
end

local function collectHeli(master)
    if not (master and cfg.helicopter.enabled) then
        heliPart, heliOutObj, heliPosObj = nil, nil, nil
        return
    end
    local folder = Workspace:FindFirstChild("Helicopter")
    local model  = folder and folder:FindFirstChild("Helicopter")
    heliPart = model and getRootPart(model) or nil
    if heliPart then
        heliOutObj, heliPosObj = nil, nil
    else
        local rs   = ReplicatedStorage:FindFirstChild("ReplicatedState")
        local misc = rs and rs:FindFirstChild("MiscValues")
        heliOutObj = misc and misc:FindFirstChild("HeliOut") or nil
        heliPosObj = misc and misc:FindFirstChild("HeliPosition") or nil
    end
end

local function collectSlow()
    local master = cfg.masterEnabled
    cam = Workspace.CurrentCamera or cam
    local char = LocalPlayer and LocalPlayer.Character
    localRoot = char and char:FindFirstChild("HumanoidRootPart") or nil
    myName = LocalPlayer and LocalPlayer.Name
    myId = LocalPlayer and LocalPlayer.UserId

    safe("players", collectPlayers, master)
    safe("deployables", collectModels, deployCat, master and cfg.deployable.enabled, Workspace:FindFirstChild("Deployables"), nil)
    local bf = Workspace:FindFirstChild("BountyVehicles")
    safe("bounty", collectModels, bountyCat, master and cfg.bountyVehicle.enabled, bf and bf:FindFirstChild("Vehicles"), nil)
    safe("vehicles", collectVehicles, master)
    safe("heli", collectHeli, master)
end

-- Fast tick (own vehicles only): health reads for the damage popup
local function tickHealth()
    if not cfg.masterEnabled or not cfg.vehicleHealth.enabled then return end
    local now = os.clock()
    local arr = ownCat.arr
    for i = 1, #arr do
        local e = arr[i]
        local ho = e.healthObj
        local h = ho and ho.Value
        if type(h) == "number" then
            if e.lastHealth == nil then
                e.lastHealth = h
                e.maxHealth = e.realMax or h
                e.showUntil = 0
            end
            if e.realMax then
                e.maxHealth = e.realMax
            elseif h > e.maxHealth then
                e.maxHealth = h
            end
            if h < e.lastHealth then
                e.showUntil = now + (cfg.vehicleHealth.showSeconds or 5)
            end
            e.lastHealth = h
            e.hp = h
        end
    end
end

----------------------------------------------------
-- RENDERER (fast, reads cached parts only)
----------------------------------------------------
local heliLbl, heliSpotLbl = nil, nil
local shown = { crim = false, panic = false, deploy = false, bounty = false, stolen = false, personal = false, hp = false, heli = false }
local hiddenAll = false

local function hideEverything()
    for _, cat in ipairs({ crimCat, panicCat, deployCat, bountyCat, stolenCat, ownCat }) do
        for _, e in ipairs(cat.arr) do
            hideField(e, "label"); hideField(e, "price"); hideField(e, "hpLabel")
            hideCircle(e.circle)
        end
    end
    hideLabel(heliLbl); hideLabel(heliSpotLbl)
    for k in pairs(shown) do shown[k] = false end
end

-- Generic text category. Returns nothing; hides entries it can't place.
local function drawTextCat(arr, c, lx, ly, lz, hasL, maxD, after)
    for i = 1, #arr do
        local e = arr[i]
        local part = e.part
        local ok = false
        if part and not e.hidden and part.Parent then
            local pos = part.Position
            local px, py, pz = pos.X, pos.Y, pos.Z
            local dist = 0
            if hasL then
                local dx, dy, dz = px - lx, py - ly, pz - lz
                dist = sqrt(dx * dx + dy * dy + dz * dz)
            end
            if dist <= maxD then
                local s, on = WorldToScreen(Vector3.new(px, py + c.yOffset * OFFSET_STUD_SCALE, pz))
                if on and s then
                    local sx, sy = floor(s.X + 0.5), floor(s.Y + 0.5)
                    showLabel(getLbl(e, "label"), e.text or "", c.color, calcFontSize(c.fontSize, dist), sx, sy)
                    ok = true
                    if after then after(e, sx, sy, dist) end
                end
            end
        end
        if not ok then
            hideField(e, "label")
            if after then hideField(e, "price") end
        end
    end
end

local function stolenAfter(e, sx, sy, dist)
    local sv = cfg.stolenVehicle
    if sv.showPrice then
        showLabel(getLbl(e, "price"), e.priceText or "", sv.priceColor, calcFontSize(11, dist), sx, sy + 16)
    else
        hideField(e, "price")
    end
end

local function drawCriminals(lx, ly, lz, hasL, maxD)
    local arr = crimCat.arr
    local c = cfg.criminal
    for i = 1, #arr do
        local e = arr[i]
        local part = e.part
        local ok = false
        if part and part.Parent then
            local pos = part.Position
            local dist = 0
            if hasL then
                local dx, dy, dz = pos.X - lx, pos.Y - ly, pos.Z - lz
                dist = sqrt(dx * dx + dy * dy + dz * dz)
            end
            if dist <= maxD then
                local s, on = WorldToScreen(pos)
                if on and s then
                    local radius = clamp(380 / (dist > 0 and dist or 1), 3, 8)
                    local sx, sy = floor(s.X + 0.5), floor(s.Y + 0.5)
                    showCircle(getCirc(e), sx, sy, radius, c.color)
                    showLabel(getLbl(e, "label"), e.text or "", c.color, calcFontSize(c.fontSize, dist), sx, floor(sy + radius + 4))
                    ok = true
                end
            end
        end
        if not ok then
            hideField(e, "label")
            hideCircle(e.circle)
        end
    end
end

local function drawHealth(lx, ly, lz, hasL, maxD, now)
    local arr = ownCat.arr
    local c = cfg.vehicleHealth
    for i = 1, #arr do
        local e = arr[i]
        local part = e.part
        local ok = false
        if part and e.hp and now < (e.showUntil or 0) and part.Parent then
            local pos = part.Position
            local px, py, pz = pos.X, pos.Y, pos.Z
            local dist = 0
            if hasL then
                local dx, dy, dz = px - lx, py - ly, pz - lz
                dist = sqrt(dx * dx + dy * dy + dz * dz)
            end
            if dist <= maxD then
                local s, on = WorldToScreen(Vector3.new(px, py + c.yOffset * OFFSET_STUD_SCALE, pz))
                if on and s then
                    local col = healthToColor(e.hp, e.maxHealth)
                    showLabel(getLbl(e, "hpLabel"), "HP: " .. tostring(floor(e.hp + 0.5)), col, calcFontSize(c.fontSize, dist), floor(s.X + 0.5), floor(s.Y + 0.5))
                    ok = true
                end
            end
        end
        if not ok then hideField(e, "hpLabel") end
    end
end

local function drawHeli(lx, ly, lz, hasL)
    local h = cfg.helicopter
    local pos = nil
    if heliPart and heliPart.Parent then
        pos = heliPart.Position
    elseif heliOutObj and heliPosObj and heliOutObj.Value == true then
        pos = heliPosObj.Value
    end

    if not heliLbl then heliLbl = newLabel() end
    if not heliSpotLbl then heliSpotLbl = newLabel() end

    local placed = false
    if pos then
        local s, on = WorldToScreen(pos)
        if on and s then
            local dist = 0
            if hasL then
                local dx, dy, dz = pos.X - lx, pos.Y - ly, pos.Z - lz
                dist = sqrt(dx * dx + dy * dy + dz * dz)
            end
            local sx, sy = floor(s.X + 0.5), floor(s.Y + 0.5)
            showLabel(heliLbl, h.text, h.color, calcFontSize(h.fontSize, dist), sx, sy)
            placed = true
            if h.showSpotlight and spotText then
                showLabel(heliSpotLbl, spotText, h.spotlightColor, calcFontSize(h.spotlightFontSize, dist), sx, sy + 16)
            else
                hideLabel(heliSpotLbl)
            end
        end
    end
    if not placed then
        hideLabel(heliLbl)
        hideLabel(heliSpotLbl)
    end
end

local function drawAll()
    if not cfg.masterEnabled then
        if not hiddenAll then hideEverything(); hiddenAll = true end
        return
    end
    hiddenAll = false

    local lx, ly, lz, hasL = 0, 0, 0, false
    local lr = localRoot
    local lp = nil
    if lr and lr.Parent then
        lp = lr.Position
    elseif cam then
        lp = cam.Position
    end
    if lp then lx, ly, lz, hasL = lp.X, lp.Y, lp.Z, true end
    local maxD = cfg.settings.maxDistance
    local now = os.clock()

    if cfg.criminal.enabled then
        drawCriminals(lx, ly, lz, hasL, maxD); shown.crim = true
    elseif shown.crim then
        for _, e in ipairs(crimCat.arr) do hideField(e, "label"); hideCircle(e.circle) end
        shown.crim = false
    end

    if cfg.panic.enabled then
        drawTextCat(panicCat.arr, cfg.panic, lx, ly, lz, hasL, maxD, nil); shown.panic = true
    elseif shown.panic then
        hideAll(panicCat.arr, "label"); shown.panic = false
    end

    if cfg.deployable.enabled then
        drawTextCat(deployCat.arr, cfg.deployable, lx, ly, lz, hasL, maxD, nil); shown.deploy = true
    elseif shown.deploy then
        hideAll(deployCat.arr, "label"); shown.deploy = false
    end

    if cfg.bountyVehicle.enabled then
        drawTextCat(bountyCat.arr, cfg.bountyVehicle, lx, ly, lz, hasL, maxD, nil); shown.bounty = true
    elseif shown.bounty then
        hideAll(bountyCat.arr, "label"); shown.bounty = false
    end

    if cfg.stolenVehicle.enabled then
        drawTextCat(stolenCat.arr, cfg.stolenVehicle, lx, ly, lz, hasL, maxD, stolenAfter); shown.stolen = true
    elseif shown.stolen then
        hideAll(stolenCat.arr, "label"); hideAll(stolenCat.arr, "price"); shown.stolen = false
    end

    if cfg.personalVehicle.enabled then
        drawTextCat(ownCat.arr, cfg.personalVehicle, lx, ly, lz, hasL, maxD, nil); shown.personal = true
    elseif shown.personal then
        hideAll(ownCat.arr, "label"); shown.personal = false
    end

    if cfg.vehicleHealth.enabled then
        drawHealth(lx, ly, lz, hasL, maxD, now); shown.hp = true
    elseif shown.hp then
        hideAll(ownCat.arr, "hpLabel"); shown.hp = false
    end

    if cfg.helicopter.enabled then
        drawHeli(lx, ly, lz, hasL); shown.heli = true
    elseif shown.heli then
        hideLabel(heliLbl); hideLabel(heliSpotLbl); shown.heli = false
    end
end

----------------------------------------------------
-- 1. ATM HACK
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
            local sig = string.format("%d:%d", floor(sx / 3), floor(sy / 3))
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

local function stepAtm(menus)
    local atmUi = findChild(menus, "ATM")
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
    local onCell = dist <= max((gsx or 20) * 0.35, 10)

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
        local cycleTime = max(atmState.stepTime * #nodes + 0.3, 0.6)
        if now - atmState.lastClick <= cycleTime then return end
        atmState.clickedRound = false
    end

    local delay = max((tonumber(cfg.atm.delay) or 50) / 1000, 0.03)
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

local function stepLockpick(menus)
    local ui = findChild(menus, "Lockpick")
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
    local delay = max((tonumber(cfg.lockpick.delay) or 40) / 1000, 0.03)
    if now - lockpickState.lastClick < delay then return end

    local pad = max(tonumber(cfg.lockpick.tolerance) or 2, 0)
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
    local menus = getMenus()
    local cut = menus and findChild(menus, "GlassCutting")
    if not cut or memVisible(cut) == false then
        glassState.lastX, glassState.lastY = nil, nil
        return
    end

    local box = findChild(cut, "GreenBox")
    if not box then return end

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

    local lead = max((tonumber(cfg.glasscut.lead) or 0) / 1000, 0)
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

    if abs(crowBarState.vel) < 5 then return true end

    local latency = max((tonumber(cfg.hotwire.latency) or 50) / 1000, 0)
    local frameDt = min(crowBarState.frameDt or (1 / 60), 0.05)
    local marginPct = min(max(tonumber(cfg.hotwire.margin) or 25, 0), 45) / 100
    local inset = zoneRect.w * marginPct / 2
    local fromX = barRect.cx + crowBarState.vel * latency
    local toX = fromX + crowBarState.vel * frameDt
    local lo, hi = min(fromX, toX), max(fromX, toX)

    local delay = max((tonumber(cfg.hotwire.delay) or 50) / 1000, 0.05)
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

    local shownNow = memVisible(currentImg)
    if shownNow == true then
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
    if #numHackState.seq >= 6 and shownNow == false and hiddenLongEnough and lastAged then
        numHackState.playing = true
        numHackState.playIndex = 1
    end
    return true
end

-- C. Wire Pairing (Connect Wires Solver)
local WIRE_COLORS = { "Blue", "Green", "Red", "Yellow" }
local wireState = { session = nil, phase = "aim", held = false, lastDone = 0, releasedAt = 0, nearSince = 0, currentColor = nil, done = {} }

local function resetWires()
    if wireState.held then pcall(mouse1release) end
    wireState.session = nil
    wireState.held = false
    wireState.phase = "aim"
    wireState.done = {}
end

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

-- Wire buttons are direct children of the UI at runtime, but sit under "ConnectWires LS.Wires" in the static tree
local function collectWireButtons(ui, lefts, rights)
    local function scan(container)
        if not container then return end
        for _, child in ipairs(container:GetChildren()) do
            local color, side = wireSide(child.Name)
            if color and guiRect(child) then
                local drag = findChild(child, "Drag") or child
                if side == "L" then lefts[color] = { frame = child, drag = drag }
                else rights[color] = { frame = child, drag = drag } end
            end
        end
    end
    scan(ui)
    if next(lefts) == nil and next(rights) == nil then
        local ls = findChild(ui, "ConnectWires LS")
        scan(ls and findChild(ls, "Wires"))
    end
end

local function stepConnectWires(menus, now)
    local ui = findChild(menus, "ConnectWires")
    if not ui or memVisible(ui) ~= true then
        resetWires()
        return false
    end

    if not wireState.session then
        wireState.session = tostring(now)
        wireState.phase = "aim"
        wireState.done = {}
    end

    local lefts, rights = {}, {}
    collectWireButtons(ui, lefts, rights)

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

local function stepHotwire(menus, now)
    if memVisible(findChild(menus, "NumbersHack")) == true then
        stepNumbersHack(menus, now)
    elseif memVisible(findChild(menus, "ConnectWires")) == true then
        stepConnectWires(menus, now)
    else
        if wireState.session then resetWires() end
        stepCrowbarBar(menus, now)
    end
end

----------------------------------------------------
-- THREADS
----------------------------------------------------
-- Autofarm dispatcher: sleeps 0.25s when nothing is enabled
task.spawn(function()
    while ALIVE do
        if cfg.atm.enabled or cfg.lockpick.enabled or cfg.hotwire.enabled then
            local menus = getMenus()
            if menus then
                if cfg.atm.enabled then safe("atm", stepAtm, menus) end
                if cfg.lockpick.enabled then safe("lockpick", stepLockpick, menus) end
                if cfg.hotwire.enabled then safe("hotwire", stepHotwire, menus, os.clock()) end
            end
            task.wait(0.01)
        else
            task.wait(0.25)
        end
    end
end)

-- Collector: instance lookups at 2 Hz
task.spawn(function()
    while ALIVE do
        safe("collect", collectSlow)
        task.wait(0.5)
    end
end)

-- Health reads at ~7 Hz (own vehicles only)
task.spawn(function()
    while ALIVE do
        safe("health", tickHealth)
        task.wait(0.15)
    end
end)

-- Single render connection: glass cutting (every frame) + ESP (optionally rate limited)
local espAcc = 0
if RunService then
    conns[#conns + 1] = RunService.RenderStepped:Connect(function(dt)
        if not ALIVE then return end
        if cfg.glasscut.enabled then safe("glasscut", stepGlassCut) end
        local rate = cfg.settings.espRate
        if rate and rate > 0 then
            espAcc = espAcc + (dt or 0)
            if espAcc < 1 / rate then return end
            espAcc = 0
        end
        safe("esp", drawAll)
    end)
end

-- Alt key toggle for Master ESP
local lastAltState = false
task.spawn(function()
    while ALIVE do
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

notify("ERLC ESP", "Full ESP & Autos Ready — Update #22 (performance build)", 3)
print("ERLC Full ESP + Hotwire Suite loaded successfully (NonUI)!")
