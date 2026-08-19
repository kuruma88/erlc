-- ERLC Full ESP + Auto Minigames + Matcha UI -- Update #18 (Crowbar integrated)
local Players = game:GetService("Players")
local Workspace = workspace or game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

----------------------------------------------------
-- CONFIG
----------------------------------------------------
local cfg = {
    masterEnabled = true,
    criminal = { enabled = true, color = Color3.fromRGB(255, 55, 55), yOffset = -5, fontSize = 11 },
    panic = { enabled = true, color = Color3.fromRGB(255, 120, 30), yOffset = 25, fontSize = 12 },
    deployable = { enabled = true, color = Color3.fromRGB(80, 200, 120), yOffset = 30, fontSize = 13 },
    bountyVehicle = { enabled = true, color = Color3.fromRGB(50, 180, 255), yOffset = 40, fontSize = 13 },
    stolenVehicle = { enabled = true, color = Color3.fromRGB(255, 110, 180), priceColor = Color3.fromRGB(255, 210, 70), yOffset = 40, fontSize = 13, showPrice = true },
    personalVehicle = { enabled = true, color = Color3.fromRGB(100, 220, 255), yOffset = 40, fontSize = 13, text = "Personal Vehicle" },
    vehicleHealth = { enabled = true, fontSize = 12, showSeconds = 5, yOffset = 22 },
    helicopter = { enabled = true, color = Color3.fromRGB(255, 220, 50), yOffset = 40, fontSize = 14, text = "Helicopter", spotlightFontSize = 11, spotlightColor = Color3.fromRGB(255, 180, 40), showSpotlight = true, edgeMargin = 50 },
    settings = { fontName = "SystemBold", dynamicSize = 0, maxDistance = 5000 },
    auto = {
        atm = false,
        lockpick = false,
        glass = false,
        crowbar = false,
    },
    crowbar = {
        delay = 50,
        latency = 0,
        margin = 25,
        aimCenter = false,
        clickWithMenu = false,
        debug = false,
        status = "Off",
    },
}

local FONT_NAMES = { "UI", "System", "SystemBold", "Minecraft", "Monospace", "Pixel", "Fortnite" }
local FONT_MAP = {
    UI = Drawing.Fonts.UI, System = Drawing.Fonts.System, SystemBold = Drawing.Fonts.SystemBold,
    Minecraft = Drawing.Fonts.Minecraft, Monospace = Drawing.Fonts.Monospace, Pixel = Drawing.Fonts.Pixel, Fortnite = Drawing.Fonts.Fortnite
}
local function getEspFont() return FONT_MAP[cfg.settings.fontName] or Drawing.Fonts.SystemBold end
local function colToRGB(c) return c.R, c.G, c.B, 1 end

----------------------------------------------------
-- FETCH OFFSETS (Centralized for Autos)
----------------------------------------------------
local ver = getrbxversion()
if not ver or ver == "" then error("Cannot detect Roblox version for memory offsets.") end
local body = httpget("https://offsets.imtheo.lol/" .. ver .. "/offsetshex.json")
if body == "" then error("Failed to fetch offsets for " .. ver) end
local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
if not ok or not data or not data.Offsets then error("Bad offsets payload") end
local O = {}
for cat, fields in pairs(data.Offsets) do
    for k, v in pairs(fields) do
        local n = tonumber(v)
        if n then O[cat .. "." .. k] = n end
    end
end
local OFF_BG = O["GuiObject.BackgroundColor3"] or 0x540
local OFF_VIS = O["GuiObject.Visible"] or 0x5ad
local OFF_POS = O["GuiBase2D.AbsolutePosition"] or 0x10c
local OFF_SIZE = O["GuiBase2D.AbsoluteSize"] or 0x114
local OFF_TEXT = O["TextLabel.Text"] or 0xdf8 -- fallback; may need adjustment per version

local function mread(kind, addr)
    local a, b = pcall(memory_read, kind, addr)
    return a and b or nil
end
local function visible(inst)
    if not inst or not inst.Address then return false end
    local v = mread("byte", inst.Address + OFF_VIS)
    if v ~= nil then return v ~= 0 end
    local ok, vis = pcall(function() return inst.Visible end)
    return ok and vis == true
end
local function rect(inst)
    if not inst or not inst.Address then return nil end
    local x = mread("float", inst.Address + OFF_POS)
    local y = mread("float", inst.Address + OFF_POS + 4)
    local w = mread("float", inst.Address + OFF_SIZE)
    local h = mread("float", inst.Address + OFF_SIZE + 4)
    if x and y and w and h then return x, y, w, h end
    local ok, p = pcall(function() return inst.AbsolutePosition end)
    local ok2, s = pcall(function() return inst.AbsoluteSize end)
    if ok and ok2 and p and s then return p.X, p.Y, s.X, s.Y end
    return nil
end
local function memText(inst)
    if not inst then return nil end
    local ok, t = pcall(function() return inst.Text end)
    if ok and type(t) == "string" and t ~= "" then return t end
    if inst.Address then
        local s = mread("string", inst.Address + OFF_TEXT)
        if type(s) == "string" and s ~= "" then return s end
    end
    return nil
end
local function memColorRGB(inst)
    if not inst or not inst.Address then return nil end
    local r = mread("float", inst.Address + OFF_BG)
    local g = mread("float", inst.Address + OFF_BG + 4)
    local b = mread("float", inst.Address + OFF_BG + 8)
    if r and g and b then
        if r > 1 or g > 1 or b > 1 then r, g, b = r / 255, g / 255, b / 255 end
        return r, g, b
    end
    local ok, c = pcall(function() return inst.BackgroundColor3 end)
    if ok and c then return c.R, c.G, c.B end
    return nil
end

----------------------------------------------------
-- SMALL HELPERS
----------------------------------------------------
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
local function viewportSize()
    local cam = Workspace and Workspace.CurrentCamera
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
local function windowFocused()
    local ok, active = pcall(function() return isrbxactive() end)
    if not ok then return true end
    return active
end
local function guiRect(inst)
    local x, y, w, h = rect(inst)
    if not x or not y or not w or not h then return nil end
    return { x = x, y = y, w = w, h = h, cx = x + w / 2, cy = y + h / 2 }
end
local function inViewport(inst, pad)
    local r = guiRect(inst)
    local vw, vh = viewportSize()
    if not r or not vw then return false end
    pad = pad or 8
    return r.y < vh - pad and (r.y + r.h) > pad and r.x < vw - pad and (r.x + r.w) > pad
end
local function uiShowing(inst)
    if not inst then return false end
    if visible(inst) == false then return false end
    local w, h = select(3, rect(inst))
    if not w or w < 40 or not h or h < 40 then return false end
    local vw, vh = viewportSize()
    local x, y = select(1, rect(inst))
    if vw and y then
        if y >= vh - 8 or (y + h) <= 8 then return false end
    end
    if vw and x then
        if x >= vw - 8 or (x + w) <= 8 then return false end
    end
    return true
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
    local r = guiRect(inst)
    if not r then return false, 999 end
    local dist = moveMouseToward(r.cx, r.cy)
    if dist > (maxDist or 12) then return false, dist end
    pcall(mouse1click)
    return true, dist
end

----------------------------------------------------
-- MATCHA UI
----------------------------------------------------
UI.AddTab("ERLC ESP", function(tab)
    local left = tab:Section("ESP", "Left")
    left:Toggle("esp_master", "Master Enabled", cfg.masterEnabled, function(v) cfg.masterEnabled = v end)
    left:SliderInt("esp_maxdist", "Max Distance", 100, 10000, cfg.settings.maxDistance, function(v) cfg.settings.maxDistance = v end)
    left:Combo("esp_font", "Font", FONT_NAMES, 2, function(idx, text) cfg.settings.fontName = text end)
    left:Spacing()
    left:Toggle("esp_criminal", "Criminal", cfg.criminal.enabled, function(v) cfg.criminal.enabled = v end)
    left:ColorPicker("esp_criminal_col", colToRGB(cfg.criminal.color), function(c) cfg.criminal.color = c end)
    left:Toggle("esp_panic", "Panic", cfg.panic.enabled, function(v) cfg.panic.enabled = v end)
    left:ColorPicker("esp_panic_col", colToRGB(cfg.panic.color), function(c) cfg.panic.color = c end)
    left:Toggle("esp_deploy", "Deployables", cfg.deployable.enabled, function(v) cfg.deployable.enabled = v end)
    left:ColorPicker("esp_deploy_col", colToRGB(cfg.deployable.color), function(c) cfg.deployable.color = c end)

    local right = tab:Section("Vehicles / Heli", "Right")
    right:Toggle("esp_bounty", "Bounty Vehicles", cfg.bountyVehicle.enabled, function(v) cfg.bountyVehicle.enabled = v end)
    right:ColorPicker("esp_bounty_col", colToRGB(cfg.bountyVehicle.color), function(c) cfg.bountyVehicle.color = c end)
    right:Toggle("esp_stolen", "Stolen Vehicles", cfg.stolenVehicle.enabled, function(v) cfg.stolenVehicle.enabled = v end)
    right:ColorPicker("esp_stolen_col", colToRGB(cfg.stolenVehicle.color), function(c) cfg.stolenVehicle.color = c end)
    right:Toggle("esp_stolen_price", "Show Price", cfg.stolenVehicle.showPrice, function(v) cfg.stolenVehicle.showPrice = v end)
    right:ColorPicker("esp_stolen_pricecol", colToRGB(cfg.stolenVehicle.priceColor), function(c) cfg.stolenVehicle.priceColor = c end)
    right:Toggle("esp_personal", "Personal Vehicle", cfg.personalVehicle.enabled, function(v) cfg.personalVehicle.enabled = v end)
    right:ColorPicker("esp_personal_col", colToRGB(cfg.personalVehicle.color), function(c) cfg.personalVehicle.color = c end)
    right:Toggle("esp_vhealth", "Vehicle Health", cfg.vehicleHealth.enabled, function(v) cfg.vehicleHealth.enabled = v end)
    right:Toggle("esp_heli", "Helicopter", cfg.helicopter.enabled, function(v) cfg.helicopter.enabled = v end)
    right:ColorPicker("esp_heli_col", colToRGB(cfg.helicopter.color), function(c) cfg.helicopter.color = c end)
    right:Toggle("esp_heli_spotlight", "Show Spotlighted", cfg.helicopter.showSpotlight, function(v) cfg.helicopter.showSpotlight = v end)
    right:ColorPicker("esp_heli_spotcol", colToRGB(cfg.helicopter.spotlightColor), function(c) cfg.helicopter.spotlightColor = c end)
    right:Spacing()
    right:Button("Reset Defaults", function()
        UI.SetValue("esp_master", true)
        if notify then notify("Defaults restored", "ERLC ESP", 2) end
    end)
end)

UI.AddTab("Auto Minigames", function(tab)
    local autos = tab:Section("Robbery Autos", "Left")
    autos:Toggle("auto_atm", "Auto ATM", cfg.auto.atm, function(v) cfg.auto.atm = v end)
    autos:Toggle("auto_lockpick", "Auto Lockpick", cfg.auto.lockpick, function(v) cfg.auto.lockpick = v end)
    autos:Toggle("auto_glass", "Auto Glass Cutting", cfg.auto.glass, function(v) cfg.auto.glass = v end)
    autos:Toggle("auto_crowbar", "Auto Crowbar", cfg.auto.crowbar, function(v)
        cfg.auto.crowbar = v
        if not v then
            cfg.crowbar.status = "Off"
        end
    end)

    local crow = tab:Section("Crowbar Settings", "Right")
    crow:SliderInt("crow_delay", "Click Delay (ms)", 50, 400, cfg.crowbar.delay, function(v) cfg.crowbar.delay = v end)
    crow:SliderInt("crow_latency", "Input Latency (ms)", 0, 200, cfg.crowbar.latency, function(v) cfg.crowbar.latency = v end)
    crow:SliderInt("crow_margin", "Safe Margin (%)", 0, 45, cfg.crowbar.margin, function(v) cfg.crowbar.margin = v end)
    crow:Toggle("crow_aimcenter", "Aim Center", cfg.crowbar.aimCenter, function(v) cfg.crowbar.aimCenter = v end)
    crow:Toggle("crow_clickmenu", "Click With Menu Open", cfg.crowbar.clickWithMenu, function(v) cfg.crowbar.clickWithMenu = v end)
    crow:Toggle("crow_debug", "Debug Boxes", cfg.crowbar.debug, function(v) cfg.crowbar.debug = v end)
end)

local function syncFromUI()
    local function g(id, fallback)
        local v = UI.GetValue(id)
        if v == nil then return fallback end
        return v
    end
    cfg.masterEnabled = g("esp_master", cfg.masterEnabled)
    cfg.auto.atm = g("auto_atm", cfg.auto.atm)
    cfg.auto.lockpick = g("auto_lockpick", cfg.auto.lockpick)
    cfg.auto.glass = g("auto_glass", cfg.auto.glass)
    cfg.auto.crowbar = g("auto_crowbar", cfg.auto.crowbar)
    cfg.crowbar.delay = g("crow_delay", cfg.crowbar.delay)
    cfg.crowbar.latency = g("crow_latency", cfg.crowbar.latency)
    cfg.crowbar.margin = g("crow_margin", cfg.crowbar.margin)
    cfg.crowbar.aimCenter = g("crow_aimcenter", cfg.crowbar.aimCenter)
    cfg.crowbar.clickWithMenu = g("crow_clickmenu", cfg.crowbar.clickWithMenu)
    cfg.crowbar.debug = g("crow_debug", cfg.crowbar.debug)
end

----------------------------------------------------
-- ESP HELPERS (placeholder – keep your original implementations)
----------------------------------------------------
-- Put your original createTextEsp / drawText / getRootPart / updateCriminalCache /
-- updatePanicCache / updateDeployableCache / updateVehicleCaches / updateHelicopter /
-- and the RenderStepped / Heartbeat drawing loops here exactly as they were.

----------------------------------------------------
-- AUTO ATM (unchanged from your script)
----------------------------------------------------
task.spawn(function()
    local function readText(inst) return inst.Text end
    while true do
        if not cfg.auto.atm then task.wait(1); continue end
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local menus = pg and pg:FindFirstChild("GameMenus")
        local atm = menus and menus:FindFirstChild("ATM")
        local hacking = atm and atm:FindFirstChild("Hacking")
        if not hacking or not visible(hacking) then
            task.wait(0.5)
            continue
        end
        local targets = {}
        local tFill = tick()
        while cfg.auto.atm and tick() - tFill < 10 do
            targets = {}
            for i = 1, 5 do
                local lbl = hacking:FindFirstChild("HexCode" .. i)
                local t = lbl and readText(lbl)
                if t then t = t:gsub("%s", "") end
                if not t or #t == 0 or t:find("-") then break end
                targets[#targets + 1] = t
            end
            if #targets == 5 then break end
            task.wait(0.1)
        end
        if #targets < 5 then continue end
        local cycle = hacking:FindFirstChild("CycleFrame")
        local clickBtn = hacking:FindFirstChild("ClickButton")
        local cycleOrder = {}
        for _, listName in ipairs({ "List1", "List2", "List3", "List4" }) do
            local lf = cycle and cycle:FindFirstChild(listName)
            if lf then
                for _, c in ipairs(lf:GetChildren()) do
                    if c:IsA("TextLabel") then cycleOrder[#cycleOrder + 1] = c end
                end
            end
        end
        if #cycleOrder == 0 then continue end
        local clickCX, clickCY
        local px, py, pw, ph = rect(clickBtn)
        if px then clickCX, clickCY = px + pw / 2, py + ph / 2 end
        for i = 1, 5 do
            if not cfg.auto.atm then break end
            local target = targets[i]
            local tIdx = nil
            for j = 1, #cycleOrder do
                if readText(cycleOrder[j]) == target then tIdx = j break end
            end
            if not tIdx then break end
            local t0 = tick()
            while cfg.auto.atm and tick() - t0 < 45 do
                local lbl = cycleOrder[tIdx]
                local r = mread("float", lbl.Address + OFF_BG)
                local g = mread("float", lbl.Address + OFF_BG + 4)
                local b = mread("float", lbl.Address + OFF_BG + 8)
                if r and g and b and (r + g + b) > 0.01 then
                    if clickCX then mousemoveabs(clickCX, clickCY) end
                    task.wait(0.02)
                    mouse1click()
                    break
                end
                task.wait(0.002)
            end
        end
        while cfg.auto.atm and visible(hacking) do task.wait(0.5) end
    end
end)

----------------------------------------------------
-- AUTO LOCKPICK (unchanged from your script)
----------------------------------------------------
task.spawn(function()
    while true do
        if not cfg.auto.lockpick then task.wait(1); continue end
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local gm = pg and pg:FindFirstChild("GameMenus")
        local gui = gm and gm:FindFirstChild("Lockpick")
        if not gui or not visible(gui) then
            task.wait(0.5)
            continue
        end
        local pick = gui:FindFirstChild("Pick")
        local redLine = pick and pick:FindFirstChild("RedLine")
        if not pick or not redLine then continue end
        for round = 1, 6 do
            if not cfg.auto.lockpick then break end
            local piece = pick:FindFirstChild(tostring(round))
            if not piece then break end
            local tR = tick()
            local prevCy, prevT = nil, nil
            local vel = 0
            while cfg.auto.lockpick and tick() - tR < 20 do
                local px, py, pw, ph = rect(piece)
                local rx, ry, rw, rh = rect(redLine)
                local now = tick()
                if py and ph and ry and rh then
                    local cy = py + ph / 2
                    local rc = ry + rh / 2
                    if prevCy and prevT then
                        local dt = now - prevT
                        if dt > 0.001 then
                            vel = vel * 0.7 + ((cy - prevCy) / dt) * 0.3
                        end
                    end
                    prevCy, prevT = cy, now
                    local dist = rc - cy
                    if math.abs(dist) <= 3 then
                        mouse1click()
                        break
                    end
                    if math.abs(vel) > 10 then
                        local tToC = dist / vel
                        if tToC >= 0.006 and tToC <= 0.014 then
                            mouse1click()
                            break
                        end
                    end
                end
                task.wait(0.002)
            end
            task.wait(0.3)
        end
        while cfg.auto.lockpick and visible(gui) do task.wait(0.5) end
    end
end)

----------------------------------------------------
-- AUTO GLASS CUTTING (unchanged from your script)
----------------------------------------------------
task.spawn(function()
    while true do
        if not cfg.auto.glass then task.wait(1); continue end
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local gm = pg and pg:FindFirstChild("GameMenus")
        local gui = gm and gm:FindFirstChild("GlassCutting")
        if not gui or not visible(gui) then
            task.wait(0.5)
            continue
        end
        local grey = gui:FindFirstChild("GreyCircle")
        local box = gui:FindFirstChild("GreenBox")
        if not grey or not box then continue end
        local moving = false
        local prevBx, prevBy = nil, nil
        local tEnd = tick()
        while cfg.auto.glass and visible(gui) and tick() - tEnd < 120 do
            local cx, cy, cw, ch = rect(grey)
            local bx, by, bw, bh = rect(box)
            if bx and by and bw and bh then
                local bcx, bcy = bx + bw / 2, by + bh / 2
                if not moving and prevBx and prevBy then
                    local d = math.abs(bx - prevBx) + math.abs(by - prevBy)
                    if d > 1 then moving = true end
                end
                prevBx, prevBy = bx, by
                if moving then
                    if cx and cy and cw and ch then
                        local ccx, ccy = cx + cw / 2, cy + ch / 2
                        local dx, dy = bcx - ccx, bcy - ccy
                        local mag = math.sqrt(dx * dx + dy * dy)
                        if mag > 1 then
                            local R = math.min(300, cw * 0.48)
                            mousemoveabs(ccx + dx / mag * R, ccy + dy / mag * R)
                        end
                    end
                else
                    mousemoveabs(bcx, bcy)
                end
            end
            task.wait(0.012)
        end
        while cfg.auto.glass and visible(gui) do task.wait(0.5) end
    end
end)

----------------------------------------------------
-- AUTO CROWBAR (ported + adapted)
----------------------------------------------------
local crowDebugBar = Drawing.new("Square")
crowDebugBar.Filled = false
crowDebugBar.Thickness = 2
crowDebugBar.Color = Color3.fromRGB(255, 80, 80)
crowDebugBar.ZIndex = 211
crowDebugBar.Visible = false

local crowDebugZone = Drawing.new("Square")
crowDebugZone.Filled = false
crowDebugZone.Thickness = 2
crowDebugZone.Color = Color3.fromRGB(80, 255, 120)
crowDebugZone.ZIndex = 211
crowDebugZone.Visible = false

local function hideCrowDebug()
    crowDebugBar.Visible = false
    crowDebugZone.Visible = false
end

local crowBarState = {
    barX = nil,
    barT = 0,
    vel = 0,
    frameDt = nil,
    staticSince = nil,
    lastClick = 0,
    hits = 0,
}

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
    startWasOpen = false,
    rounds = 0,
}

local wireState = {
    session = nil,
    index = 1,
    phase = "aim",
    held = false,
    lastDone = 0,
    releasedAt = 0,
    nearSince = 0,
    currentColor = nil,
    done = {},
}

local function resetNumHack(status)
    numHackState.session = nil
    numHackState.seq = {}
    numHackState.lastDigit = nil
    numHackState.lastDigitAt = 0
    numHackState.lastVisible = false
    numHackState.hiddenSince = 0
    numHackState.shownAt = 0
    numHackState.seenDigit = nil
    numHackState.seenCount = 0
    numHackState.playing = false
    numHackState.playIndex = 1
    numHackState.goClicked = false
    numHackState.startWasOpen = false
    numHackState.rounds = 0
    if status then cfg.crowbar.status = status end
end

local function resetWires(status)
    if wireState.held then
        pcall(mouse1release)
    end
    wireState.session = nil
    wireState.index = 1
    wireState.phase = "aim"
    wireState.held = false
    wireState.releasedAt = 0
    wireState.nearSince = 0
    wireState.currentColor = nil
    wireState.done = {}
    if status then cfg.crowbar.status = status end
end

local function resetCrowbar(status)
    crowBarState.barX = nil
    crowBarState.vel = 0
    crowBarState.staticSince = nil
    hideCrowDebug()
    resetNumHack()
    resetWires()
    cfg.crowbar.status = status or "Waiting"
end

local function crowbarBlocked()
    if not windowFocused() then return "No Focus" end
    -- optional menu-open check can be added if you expose a menuOpen() helper
    return nil
end

local function parseDigit(text)
    if type(text) ~= "string" then return nil end
    local d = tonumber(text:match("(%d)"))
    if d and d >= 1 and d <= 6 then return tostring(d) end
    return nil
end

local function trackCrowBar(r, now)
    local prevX, prevT = crowBarState.barX, crowBarState.barT
    crowBarState.barX, crowBarState.barT = r.cx, now
    if not prevX or prevT <= 0 then
        crowBarState.vel = 0
        return
    end
    local dt = now - prevT
    if dt <= 0 or dt > 0.25 then
        crowBarState.vel = 0
        return
    end
    crowBarState.frameDt = dt
    local v = (r.cx - prevX) / dt
    if crowBarState.vel ~= 0 and v ~= 0 and (v > 0) ~= (crowBarState.vel > 0) then
        crowBarState.vel = v
    else
        crowBarState.vel = crowBarState.vel * 0.5 + v * 0.5
    end
end

local function stepCrowbarBar(menus, now)
    local crow = findChild(menus, "Crowbar")
    local main = findChild(crow, "Main")
    local gameF = findChild(main, "Game")
    local bar = findChild(gameF, "Indicator")
    local zone = findChild(gameF, "Target")
    if not bar or not zone then return false end
    if visible(crow) ~= true or visible(main) == false then return false end
    local barRect = guiRect(bar)
    local zoneRect = guiRect(zone)
    if not barRect or not zoneRect or zoneRect.w < 4 then return false end
    if not inViewport(zone, 20) then return false end

    if cfg.crowbar.debug then
        crowDebugBar.Position = Vector2.new(barRect.x, barRect.y)
        crowDebugBar.Size = Vector2.new(barRect.w, barRect.h)
        crowDebugBar.Visible = true
        crowDebugZone.Position = Vector2.new(zoneRect.x, zoneRect.y)
        crowDebugZone.Size = Vector2.new(zoneRect.w, zoneRect.h)
        crowDebugZone.Visible = true
    else
        hideCrowDebug()
    end

    trackCrowBar(barRect, now)
    if math.abs(crowBarState.vel) < 5 then
        crowBarState.staticSince = crowBarState.staticSince or now
        if visible(crow) ~= true and now - crowBarState.staticSince > 0.45 then
            hideCrowDebug()
            return false
        end
        cfg.crowbar.status = "Timing: wait"
        return true
    end
    crowBarState.staticSince = nil

    local latency = math.max((tonumber(cfg.crowbar.latency) or 70) / 1000, 0)
    local frameDt = math.min(crowBarState.frameDt or (1 / 60), 0.05)
    local marginPct = math.min(math.max(tonumber(cfg.crowbar.margin) or 25, 0), 45) / 100
    local inset = zoneRect.w * marginPct / 2
    local fromX = barRect.cx + crowBarState.vel * latency
    local toX = fromX + crowBarState.vel * frameDt
    local lo, hi = math.min(fromX, toX), math.max(fromX, toX)
    local ready
    if cfg.crowbar.aimCenter then
        local tol = math.max(zoneRect.w * 0.15, 2)
        ready = lo <= zoneRect.cx + tol and hi >= zoneRect.cx - tol
    else
        ready = lo <= zoneRect.x + zoneRect.w - inset and hi >= zoneRect.x + inset
    end
    cfg.crowbar.status = string.format("Timing %.0fpx/s", crowBarState.vel)
    local delay = math.max((tonumber(cfg.crowbar.delay) or 140) / 1000, 0.05)
    if now - crowBarState.lastClick < delay then
        cfg.crowbar.status = "Timing cooldown"
        return true
    end
    local blocked = crowbarBlocked()
    if blocked then
        cfg.crowbar.status = blocked
        return true
    end
    if ready then
        pcall(mouse1click)
        crowBarState.lastClick = now
        crowBarState.hits = crowBarState.hits + 1
        cfg.crowbar.status = string.format("Timing hit %d", crowBarState.hits)
    end
    return true
end

local function numbersShowing(root)
    if not root then return false end
    return visible(root) == true
end

local function startOverlayOpen(startF, goBtn)
    if not startF then return false end
    local vis = visible(startF)
    if vis == true then return true end
    if vis == false then return false end
    if numHackState.goClicked then return false end
    return goBtn and inViewport(goBtn, 4)
end

local function stepNumbersHack(menus, now)
    local root = findChild(menus, "NumbersHack")
    if visible(root) == false then
        if numHackState.session then resetNumHack() end
        return false
    end
    if not numbersShowing(root) then return false end
    hideCrowDebug()
    local sessionId = tostring(root.Address or root)
    if numHackState.session ~= sessionId then
        resetNumHack()
        numHackState.session = sessionId
    end
    local screen = findPath(root, "Background", "ScreenBase", "ScreenUIBase")
    local main = findChild(screen, "MainScreen")
    local startF = findChild(main, "Start")
    local goBtn = findChild(startF, "GO")
    local currentImg = findChild(main, "CurrentNumber")
    local current = findChild(currentImg, "Number") or currentImg
    local buttons = findChild(screen, "NumberButtons")
    local blocked = crowbarBlocked()
    local startOpen = startOverlayOpen(startF, goBtn)
    if startOpen then
        if not numHackState.startWasOpen then
            numHackState.goClicked = false
            numHackState.seq = {}
            numHackState.playing = false
            numHackState.playIndex = 1
            numHackState.lastDigit = nil
            numHackState.lastVisible = false
            numHackState.hiddenSince = 0
            numHackState.shownAt = 0
            numHackState.seenDigit = nil
            numHackState.seenCount = 0
            numHackState.rounds = 0
        end
        numHackState.startWasOpen = true
        if not numHackState.goClicked then
            if blocked then
                cfg.crowbar.status = blocked
                return true
            end
            local ok = select(1, clickAtGui(goBtn, 18))
            if ok then
                numHackState.goClicked = true
                numHackState.lastClick = now
                numHackState.seq = {}
                numHackState.lastDigit = nil
                numHackState.lastVisible = false
                numHackState.hiddenSince = 0
                numHackState.shownAt = 0
                numHackState.seenDigit = nil
                numHackState.seenCount = 0
                cfg.crowbar.status = "Numbers: GO"
            else
                cfg.crowbar.status = "Numbers: aim GO"
            end
        else
            cfg.crowbar.status = "Numbers: GO"
        end
        return true
    end
    numHackState.startWasOpen = false
    if numHackState.playing then
        if blocked then
            cfg.crowbar.status = blocked
            return true
        end
        local digit = numHackState.seq[numHackState.playIndex]
        if not digit then
            numHackState.playing = false
            numHackState.seq = {}
            numHackState.playIndex = 1
            numHackState.lastDigit = nil
            numHackState.lastVisible = false
            numHackState.hiddenSince = 0
            numHackState.shownAt = 0
            numHackState.seenDigit = nil
            numHackState.seenCount = 0
            numHackState.rounds = numHackState.rounds + 1
            cfg.crowbar.status = string.format("Numbers round %d done", numHackState.rounds)
            return true
        end
        local btn = buttons and findChild(buttons, digit)
        if not btn then
            cfg.crowbar.status = "Numbers: missing " .. digit
            return true
        end
        local delay = math.max((tonumber(cfg.crowbar.delay) or 140) / 1000, 0.2)
        if now - numHackState.lastClick < delay then
            cfg.crowbar.status = string.format("Numbers play %s (%d/%d)", digit, numHackState.playIndex, #numHackState.seq)
            return true
        end
        local ok = select(1, clickAtGui(btn, 14))
        if ok then
            numHackState.lastClick = now
            numHackState.playIndex = numHackState.playIndex + 1
            cfg.crowbar.status = string.format("Numbers click %s", digit)
        else
            cfg.crowbar.status = string.format("Numbers aim %s", digit)
        end
        return true
    end
    local shown = visible(currentImg)
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
        if numHackState.lastVisible then
            numHackState.hiddenSince = now
        end
        numHackState.lastVisible = false
        numHackState.seenDigit = nil
        numHackState.seenCount = 0
    end
    local seq = numHackState.seq
    if #seq > 0 then
        cfg.crowbar.status = "Numbers mem " .. table.concat(seq, "")
    else
        cfg.crowbar.status = "Numbers: watch"
    end
    local hiddenLongEnough = numHackState.hiddenSince > 0 and (now - numHackState.hiddenSince) >= 0.3
    local lastAged = (now - (numHackState.lastDigitAt or 0)) >= 0.45
    if #seq >= 6 and shown == false and hiddenLongEnough and lastAged then
        numHackState.playing = true
        numHackState.playIndex = 1
        cfg.crowbar.status = "Numbers replay " .. table.concat(seq, "")
    end
    return true
end

local WIRE_COLORS = { "Blue", "Green", "Red", "Yellow" }

local function wireSide(name)
    if type(name) ~= "string" then return nil, nil end
    return name:match("^(%a+)Wire([LR])$")
end

local function attrStr(inst, key)
    if not inst then return nil end
    local value = nil
    pcall(function() value = inst:GetAttribute(key) end)
    if type(value) == "string" and value ~= "" then return value end
    return nil
end

local function attrTrue(inst, key)
    if not inst then return false end
    local value = nil
    pcall(function() value = inst:GetAttribute(key) end)
    return value == true
end

local function guiOverlapGame(a, b)
    local ar, br = guiRect(a), guiRect(b)
    if not ar or not br then return false end
    local aTop, aBot = ar.y - ar.h / 2, ar.y + ar.h / 2
    local bTop, bBot = br.y - br.h / 2, br.y + br.h / 2
    return ar.x <= br.x + br.w and br.x <= ar.x + ar.w and bTop <= aBot and aTop <= bBot
end

local function collectWirePairs(ui)
    local lefts, rights = {}, {}
    pcall(function()
        for _, child in ipairs(ui:GetChildren()) do
            local color, side = wireSide(child.Name)
            if color then
                local r = guiRect(child)
                if r and r.w > 4 and r.h > 4 then
                    local drag = findChild(child, "Drag") or child
                    local entry = { frame = child, drag = drag }
                    if side == "L" then
                        lefts[color] = entry
                    else
                        rights[color] = entry
                    end
                end
            end
        end
    end)
    local list = {}
    for i = 1, #WIRE_COLORS do
        local color = WIRE_COLORS[i]
        if lefts[color] and rights[color] then
            table.insert(list, {
                color = color,
                left = lefts[color].frame,
                right = rights[color].frame,
                leftDrag = lefts[color].drag,
                rightDrag = rights[color].drag,
            })
        end
    end
    return list
end

local function visibleTangle(ui)
    local folder = findChild(ui, "TangledWires")
    if not folder then return nil end
    local best, bestArea = nil, 0
    pcall(function()
        for _, child in ipairs(folder:GetChildren()) do
            if visible(child) == true then
                local w, h = select(3, rect(child))
                if w and h and w > 40 and h > 40 then
                    local area = w * h
                    if area > bestArea then
                        best, bestArea = child, area
                    end
                end
            end
        end
    end)
    return best
end

local function wireDropTarget(ui, pair)
    local tangle = visibleTangle(ui)
    if not tangle then return nil, nil end
    local wireName = attrStr(pair.right, "WireName")
        or attrStr(pair.rightDrag, "WireName")
        or attrStr(findChild(pair.rightDrag, "Contact"), "WireName")
    if wireName then
        local wire = findChild(tangle, wireName)
        local contact = wire and findChild(wire, "Contact")
        if contact and guiRect(contact) then
            return contact, tangle
        end
    end
    return nil, tangle
end

local function wireLightOn(ui, color)
    local lights = findChild(ui, "WireLights")
    local light = findChild(lights, color .. "Light")
    local inner = findPath(light, "Base", "InnerCircle", "Light")
        or findPath(light, "Base", "InnerCircle")
    local r, g, b = memColorRGB(inner)
    return r ~= nil and r > 0.8 and g > 0.8 and b > 0.8
end

local function wireConnected(ui, pair)
    if attrTrue(pair.leftDrag, "Connected") or attrTrue(pair.left, "Connected") then
        return true
    end
    return wireLightOn(ui, pair.color)
end

local function wiresShowing(ui)
    if not ui then return false end
    if visible(ui) ~= true then return false end
    local renamed = 0
    pcall(function()
        for _, child in ipairs(ui:GetChildren()) do
            if wireSide(child.Name) then
                renamed = renamed + 1
            end
        end
    end)
    if renamed >= 4 then return true end
    return visibleTangle(ui) ~= nil
end

local function stepConnectWires(menus, now)
    local ui = findChild(menus, "ConnectWires")
    if not wiresShowing(ui) then
        if wireState.session then resetWires() end
        return false
    end
    hideCrowDebug()
    if not wireState.session then
        resetWires()
        wireState.session = tostring(now)
        wireState.phase = "aim"
    end
    local list = collectWirePairs(ui)
    if #list == 0 then
        cfg.crowbar.status = "Wires: scanning"
        return true
    end
    local pair = nil
    for i = 1, #list do
        local p = list[i]
        if wireConnected(ui, p) then
            wireState.done[p.color] = true
        elseif not wireState.done[p.color] then
            pair = p
            break
        end
    end
    if not pair then
        cfg.crowbar.status = "Wires done"
        if wireState.held then
            pcall(mouse1release)
            wireState.held = false
            wireState.phase = "aim"
        end
        return true
    end
    if wireState.currentColor and wireState.currentColor ~= pair.color then
        if wireState.held then
            pcall(mouse1release)
            wireState.held = false
        end
        wireState.phase = "aim"
        wireState.nearSince = 0
    end
    wireState.currentColor = pair.color
    local blocked = crowbarBlocked()
    if blocked then
        if wireState.held then
            pcall(mouse1release)
            wireState.held = false
            wireState.phase = "aim"
        end
        cfg.crowbar.status = blocked
        return true
    end
    local delay = math.max((tonumber(cfg.crowbar.delay) or 140) / 1000, 0.12)
    if wireState.phase == "check" then
        if wireConnected(ui, pair) then
            wireState.done[pair.color] = true
            wireState.phase = "aim"
            wireState.lastDone = now
            cfg.crowbar.status = string.format("Wires %s ok", pair.color)
            return true
        end
        if now - (wireState.releasedAt or 0) < 0.18 then
            cfg.crowbar.status = string.format("Wires check %s", pair.color)
            return true
        end
        wireState.phase = "aim"
        wireState.nearSince = 0
    end
    if now - wireState.lastDone < delay and wireState.phase == "aim" then
        cfg.crowbar.status = "Wires cooldown"
        return true
    end
    local grab = guiRect(pair.left) or guiRect(pair.leftDrag)
    local dropInst, tangle = wireDropTarget(ui, pair)
    local drop = guiRect(dropInst)
    if not grab or not drop then
        cfg.crowbar.status = "Wires: " .. pair.color
        return true
    end
    local aimX, aimY = drop.x + drop.w * 0.5, drop.y
    if wireState.phase == "aim" then
        local dist = moveMouseToward(grab.cx, grab.cy)
        cfg.crowbar.status = string.format("Wires grab %s", pair.color)
        if dist <= 8 then
            pcall(mouse1press)
            wireState.held = true
            wireState.phase = "hold"
            wireState.lastDone = now
            wireState.nearSince = 0
        end
        return true
    end
    if wireState.phase == "hold" then
        if now - wireState.lastDone < 0.08 then
            cfg.crowbar.status = string.format("Wires hold %s", pair.color)
            return true
        end
        wireState.phase = "drag"
    end
    local dist = moveMouseToward(aimX, aimY)
    local dragContact = findChild(pair.leftDrag, "Contact") or findChild(pair.left, "Contact")
    local onTarget = dragContact and guiOverlapGame(dragContact, dropInst)
    if not onTarget and dist <= 6 then
        onTarget = true
        if dragContact then
            onTarget = guiOverlapGame(dragContact, dropInst)
        end
    end
    local wrong = false
    if tangle and dragContact and not onTarget then
        pcall(function()
            for _, wire in ipairs(tangle:GetChildren()) do
                local contact = findChild(wire, "Contact")
                if contact and contact ~= dropInst and guiOverlapGame(dragContact, contact) then
                    wrong = true
                    break
                end
            end
        end)
    end
    if wrong then
        cfg.crowbar.status = string.format("Wires avoid %s", pair.color)
        return true
    end
    cfg.crowbar.status = string.format("Wires drop %s", pair.color)
    if onTarget then
        pcall(mouse1release)
        wireState.held = false
        wireState.phase = "check"
        wireState.releasedAt = now
        wireState.nearSince = 0
        cfg.crowbar.status = string.format("Wires check %s", pair.color)
        return true
    end
    if dist <= 8 then
        wireState.nearSince = wireState.nearSince > 0 and wireState.nearSince or now
        if now - wireState.nearSince > 0.45 then
            pcall(mouse1release)
            wireState.held = false
            wireState.phase = "aim"
            wireState.nearSince = 0
            wireState.lastDone = now
            cfg.crowbar.status = string.format("Wires retry %s", pair.color)
        end
    else
        wireState.nearSince = 0
    end
    return true
end

local function stepCrowbar()
    if not cfg.auto.crowbar then
        if cfg.crowbar.status ~= "Off" then
            resetCrowbar("Off")
        end
        return
    end
    local pg = getPlayerGui()
    local menus = pg and findChild(pg, "GameMenus")
    if not menus then
        cfg.crowbar.status = "Use crowbar on a car"
        return
    end
    local now = os.clock()
    local numbersUi = findChild(menus, "NumbersHack")
    local wiresUi = findChild(menus, "ConnectWires")
    if visible(numbersUi) == true then
        if wireState.held then
            pcall(mouse1release)
            wireState.held = false
            wireState.phase = "aim"
        end
        hideCrowDebug()
        stepNumbersHack(menus, now)
        return
    end
    if visible(wiresUi) == true then
        hideCrowDebug()
        stepConnectWires(menus, now)
        return
    end
    if stepCrowbarBar(menus, now) then
        return
    end
    hideCrowDebug()
    if numHackState.session then resetNumHack() end
    if wireState.session or wireState.held then resetWires() end
    cfg.crowbar.status = "Use crowbar on a car"
end

task.spawn(function()
    while true do
        pcall(stepCrowbar)
        task.wait()
    end
end)

----------------------------------------------------
-- THREADS (Original ESP Loops)
----------------------------------------------------
task.spawn(function()
    while true do
        pcall(syncFromUI)
        -- Add your pcall(updateCache) functions here
        task.wait(0.5)
    end
end)

task.spawn(function()
    while true do
        -- Add your pcall(updateVisuals) function here
        task.wait()
    end
end)

if notify then
    notify("ERLC Full ESP + Autos loaded\nUpdate #18 (Crowbar + Wires)", "ERLC Scripts", 3)
end
print("ERLC Full ESP + Autos loaded (Crowbar integrated)")
