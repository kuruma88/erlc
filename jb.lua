local Lib = UI or UILib
local settings = {
    ma_mode = 0,
    ma_range = 5000,
    ma_scan_delay = 2,
    ma_max_markers = 16,
    ma_enemies_only = true,
    ma_include_bots = true,
    ma_deep_scan = false,
    ma_esp = true,
    ma_corner_boxes = true,
    ma_names = true,
    ma_name_size = 13,
    ma_health = true,
    ma_snaplines = false,
    ma_snap_mode = 0,
    ma_fill_box = false,
    ma_offscreen = true,
    ma_distance_fade = false,
    ma_esp_fps = 20,
    ma_size_smooth = 2,
    ma_box_thickness = 1,
    ma_arrow_size = 16,
    ma_aimbot = false,
    ma_aim_hold_rmb = true,
    ma_aim_part = 0,
    ma_aim_origin = 0,
    ma_aim_fov = 160,
    ma_aim_smooth = 8,
    ma_aim_max_step = 35,
    ma_aim_scan_fps = 20,
    ma_aim_overlay_fps = 20,
    ma_aim_pred_xz = 0,
    ma_aim_pred_y = 0,
    ma_aim_fov_ring = true,
    ma_aim_sight_marker = true,
    ma_keys_enabled = true
}

local Players = game:GetService("Players")
local Workspace = game.Workspace or game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TAB = "ESP + Aimbot"
local RUN_ID = tostring(math.random(100000, 999999))
_G.MatchaEspAimbotRunId = RUN_ID

local modes = {"All", "Players", "Bots"}
local snapModes = {"Bottom", "Center", "Crosshair"}
local aimParts = {"Head", "Root", "Center"}
local aimOrigins = {"Crosshair", "Mouse"}

local cache = {}
local markers = {}
local targetMotion = {}
local keyPrev = {}
local lastRefreshAt = 0

local aim = {
    fovLines = {},
    sightDot = nil,
    bestTarget = nil,
    bestScreen = nil,
    bestAt = 0
}

local perf = {
    espAt = 0,
    aimOverlayAt = 0
}

local function alive()
    return _G.MatchaEspAimbotRunId == RUN_ID
end

local function safe(fn, fallback)
    local ok, res = pcall(fn)
    if ok and res ~= nil then return res end
    return fallback
end

local function log(msg)
    print("[ESP + Aimbot] " .. tostring(msg))
    if notify then
        pcall(function()
            notify(tostring(msg), "ESP + Aimbot", 3)
        end)
    end
end

local function gv(id, fallback)
    local value = safe(function()
        if Lib and Lib.GetValue then
            return Lib.GetValue(id)
        end

        return nil
    end, nil)

    if value ~= nil then return value end
    if settings[id] ~= nil then return settings[id] end
    return fallback
end

local function sv(id, value)
    settings[id] = value

    pcall(function()
        if Lib and Lib.SetValue then
            Lib.SetValue(id, value)
        end
    end)
end

local function now()
    local t = safe(function() return tick() end, nil)
    if type(t) == "number" then return t end

    t = safe(function() return time() end, nil)
    if type(t) == "number" then return t end

    t = safe(function() return os.clock() end, nil)
    if type(t) == "number" then return t end

    return 0
end

local function combo(id, list)
    local idx = gv(id, 0)
    if type(idx) ~= "number" then idx = 0 end
    return list[idx + 1] or list[1]
end

local function clamp(n, lo, hi)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

local function round(n)
    if n >= 0 then
        return math.floor(n + 0.5)
    end

    return math.ceil(n - 0.5)
end

local function lerp(a, b, t)
    return a + ((b - a) * t)
end

local function fpsInterval(id, fallback)
    local fps = gv(id, fallback)
    if type(fps) ~= "number" then fps = fallback end
    fps = clamp(fps, 1, 300)
    return 1 / fps
end

local function shouldRun(key, interval)
    local t = now()
    if t <= 0 then return true end

    local last = perf[key] or 0
    if t - last < interval then return false end

    perf[key] = t
    return true
end

local function nameOf(o)
    return tostring(safe(function() return o.Name end, ""))
end

local function fullName(o)
    return tostring(safe(function() return o:GetFullName() end, nameOf(o)))
end

local function children(o)
    return safe(function() return o:GetChildren() end, {})
end

local function descendants(o)
    return safe(function() return o:GetDescendants() end, {})
end

local function find(o, n)
    return safe(function() return o:FindFirstChild(n) end, nil)
end

local function parentOf(o)
    return safe(function() return o.Parent end, nil)
end

local function classOf(o)
    return tostring(safe(function() return o.ClassName end, ""))
end

local function pos(o)
    if not o then return nil end
    return safe(function() return o.Position end, nil)
end

local function isVector3(v)
    return type(safe(function() return v.X end, nil)) == "number"
        and type(safe(function() return v.Y end, nil)) == "number"
        and type(safe(function() return v.Z end, nil)) == "number"
end

local function dist(a, b)
    if not a or not b then return 999999999 end
    local x, y, z = a.X - b.X, a.Y - b.Y, a.Z - b.Z
    return math.sqrt(x * x + y * y + z * z)
end

local function offsetY(v, y)
    return Vector3.new(v.X, v.Y + y, v.Z)
end

local function localPlayer()
    return safe(function() return Players.LocalPlayer end, nil)
end

local function localName()
    return nameOf(localPlayer())
end

local function currentCamera()
    return safe(function() return Workspace.CurrentCamera end, nil) or find(Workspace, "Camera")
end

local function cameraPosition()
    local cam = currentCamera()
    return pos(cam) or safe(function() return cam.CFrame.Position end, nil)
end

local function rootOf(model)
    if not model then return nil end
    return find(model, "HumanoidRootPart")
        or find(model, "RootPart")
        or find(model, "Torso")
        or find(model, "UpperTorso")
        or find(model, "Head")
end

local function isCharacterModel(model)
    return model and find(model, "Humanoid") and rootOf(model) ~= nil
end

local function teamConfig()
    local server = find(ReplicatedStorage, "Server")
    return find(server, "TeamPlayersConfig")
end

local function playerByName(playerName)
    for _, player in ipairs(safe(function() return Players:GetPlayers() end, {})) do
        if nameOf(player) == playerName then return player end
    end

    return nil
end

local function playerNames()
    local out = {}

    for _, player in ipairs(safe(function() return Players:GetPlayers() end, {})) do
        out[nameOf(player)] = true
    end

    return out
end

local function teamForName(playerName)
    if playerName == "" then return nil end

    local cfg = teamConfig()
    if cfg then
        for _, teamFolder in ipairs(children(cfg)) do
            if find(teamFolder, playerName) then
                return nameOf(teamFolder)
            end
        end
    end

    local player = playerByName(playerName)
    local team = safe(function() return player.Team end, nil)
    local teamName = nameOf(team)
    if teamName ~= "" then return teamName end

    return nil
end

local function characterFromContainer(container, playerName)
    if not container or playerName == "" then return nil end

    local direct = find(container, playerName)
    if isCharacterModel(direct) then return direct end

    return nil
end

local function myCharacter()
    local player = localPlayer()
    local char = safe(function() return player.Character end, nil)

    if isCharacterModel(char) then return char end

    local selfName = localName()
    local found = characterFromContainer(Workspace, selfName)
    if found then return found end

    local mapCache = find(Workspace, "Map_Cache")
    found = characterFromContainer(mapCache, selfName)
    if found then return found end

    local chars = find(Workspace, "Characters")
    found = characterFromContainer(chars, selfName)
    if found then return found end

    return nil
end

local function myRoot()
    return rootOf(myCharacter())
end

local function scanOrigin()
    local root = myRoot()
    local p = pos(root)
    if p then return p end

    p = cameraPosition()
    if p then return p end

    return nil
end

local function healthOf(model)
    local hum = find(model, "Humanoid")
    if not hum then return nil, nil end
    return safe(function() return hum.Health end, nil), safe(function() return hum.MaxHealth end, nil)
end

local function validHealth(hp, maxHp)
    return type(hp) == "number" and type(maxHp) == "number" and maxHp > 1
end

local function targetKind(model, knownPlayers)
    local n = nameOf(model)
    if knownPlayers[n] then return "Player" end

    local parentName = string.lower(nameOf(parentOf(model)))
    local lowerName = string.lower(n)
    if parentName == "bots" or string.find(lowerName, "bot") or string.find(lowerName, "dummy") then
        return "Bot"
    end

    return "Player"
end

local function acceptsMode(kind)
    local mode = combo("ma_mode", modes)
    return mode == "All"
        or (mode == "Players" and kind == "Player")
        or (mode == "Bots" and kind == "Bot")
end

local function baseColor(t)
    if t.kind == "Bot" then
        return Color3.fromRGB(255, 220, 60)
    end

    if t.team == "Blue" then
        return Color3.fromRGB(80, 165, 255)
    elseif t.team == "Red" then
        return Color3.fromRGB(255, 75, 75)
    end

    return Color3.fromRGB(255, 90, 90)
end

local function healthColor(ratio)
    ratio = clamp(ratio, 0, 1)
    return Color3.fromRGB(math.floor(255 * (1 - ratio)), math.floor(255 * ratio), 45)
end

local function addTarget(out, seen, model, rootPos, knownPlayers, localTeam)
    if not isCharacterModel(model) then return end

    local modelName = nameOf(model)
    if modelName == "" or modelName == localName() then return end

    local root = rootOf(model)
    local rootPosition = pos(root)
    if not rootPosition then return end

    local path = fullName(model)
    if seen[path] then return end
    seen[path] = true

    local hp, maxHp = healthOf(model)
    if validHealth(hp, maxHp) and hp <= 0 then return end

    local kind = targetKind(model, knownPlayers)
    if kind == "Bot" and gv("ma_include_bots", true) ~= true then return end
    if not acceptsMode(kind) then return end

    local team = teamForName(modelName)
    if gv("ma_enemies_only", true) == true and team and localTeam and team == localTeam then
        return
    end

    local range = gv("ma_range", 5000)
    if type(range) ~= "number" then range = 5000 end

    local d = dist(rootPos, rootPosition)
    if d > range then return end

    table.insert(out, {
        kind = kind,
        name = modelName,
        model = model,
        part = root,
        head = find(model, "Head") or root,
        position = rootPosition,
        distance = d,
        health = hp,
        maxHealth = maxHp,
        team = team,
        path = path
    })
end

local function scanContainer(out, seen, container, rootPos, knownPlayers, localTeam)
    if not container then return end

    for _, obj in ipairs(children(container)) do
        if isCharacterModel(obj) then
            addTarget(out, seen, obj, rootPos, knownPlayers, localTeam)
        end
    end
end

local function scanCharactersFolder(out, seen, rootPos, knownPlayers, localTeam)
    local folder = find(Workspace, "Characters")
    if not folder then return end

    for _, obj in ipairs(children(folder)) do
        if isCharacterModel(obj) then
            addTarget(out, seen, obj, rootPos, knownPlayers, localTeam)
        else
            for _, child in ipairs(children(obj)) do
                if isCharacterModel(child) then
                    addTarget(out, seen, child, rootPos, knownPlayers, localTeam)
                else
                    for _, nested in ipairs(children(child)) do
                        if isCharacterModel(nested) then
                            addTarget(out, seen, nested, rootPos, knownPlayers, localTeam)
                        end
                    end
                end
            end
        end
    end
end

local function deepScanFallback(out, seen, rootPos, knownPlayers, localTeam)
    if gv("ma_deep_scan", false) ~= true then return end

    for _, obj in ipairs(descendants(Workspace)) do
        if classOf(obj) == "Humanoid" or nameOf(obj) == "Humanoid" then
            addTarget(out, seen, parentOf(obj), rootPos, knownPlayers, localTeam)
        end
    end
end

local function refreshTargets()
    lastRefreshAt = now()

    local rootPos = scanOrigin()
    if not rootPos then
        cache = {}
        return "No scan origin"
    end

    local out = {}
    local seen = {}
    local knownPlayers = playerNames()
    local localTeam = teamForName(localName())

    scanContainer(out, seen, Workspace, rootPos, knownPlayers, localTeam)
    scanContainer(out, seen, find(Workspace, "Map_Cache"), rootPos, knownPlayers, localTeam)
    scanContainer(out, seen, find(Workspace, "Bots"), rootPos, knownPlayers, localTeam)
    scanCharactersFolder(out, seen, rootPos, knownPlayers, localTeam)

    if #out == 0 then
        deepScanFallback(out, seen, rootPos, knownPlayers, localTeam)
    end

    table.sort(out, function(a, b)
        return a.distance < b.distance
    end)

    cache = out
    aim.bestTarget = nil
    aim.bestScreen = nil

    return nil
end

local function viewport()
    return safe(function()
        return currentCamera().ViewportSize
    end, Vector2.new(1920, 1080))
end

local function newLine()
    local l
    pcall(function()
        l = Drawing.new("Line")
        l.Visible = false
        l.Thickness = 1
        l.Transparency = 1
    end)
    return l
end

local function newSquare(filled)
    local s
    pcall(function()
        s = Drawing.new("Square")
        s.Visible = false
        s.Filled = filled == true
        s.Thickness = 1
        s.Transparency = 1
    end)
    return s
end

local function newText()
    local t
    pcall(function()
        t = Drawing.new("Text")
        t.Visible = false
        t.Center = true
        t.Outline = true
        t.Size = 13
        t.Transparency = 1
    end)
    return t
end

local function marker(i)
    if markers[i] then return markers[i] end

    local m = {
        w = nil,
        h = nil,
        corners = {},
        arrow = {},
        snap = newLine(),
        fill = newSquare(true),
        hpBack = newSquare(true),
        hpFill = newSquare(true),
        nameText = newText()
    }

    for j = 1, 8 do m.corners[j] = newLine() end
    for j = 1, 3 do m.arrow[j] = newLine() end

    markers[i] = m
    return m
end

local function setLine(l, x1, y1, x2, y2, color, thickness, transparency, visible)
    if not l then return end

    pcall(function()
        l.From = Vector2.new(x1, y1)
        l.To = Vector2.new(x2, y2)
        l.Color = color
        l.Thickness = thickness
        l.Transparency = transparency or 1
        l.Visible = visible == true
    end)
end

local function setSquare(s, x, y, w, h, color, transparency, visible)
    if not s then return end

    pcall(function()
        s.Position = Vector2.new(x, y)
        s.Size = Vector2.new(w, h)
        s.Color = color
        s.Transparency = transparency or 1
        s.Visible = visible == true
    end)
end

local function setText(t, text, x, y, color, size, transparency, visible)
    if not t then return end

    pcall(function()
        t.Text = tostring(text or "")
        t.Position = Vector2.new(x, y)
        t.Color = color
        t.Size = size
        t.Center = true
        t.Outline = true
        t.Transparency = transparency or 1
        t.Visible = visible == true
    end)
end

local function hideBoxParts(m)
    if not m then return end
    for _, l in ipairs(m.corners) do pcall(function() l.Visible = false end) end
    pcall(function() if m.snap then m.snap.Visible = false end end)
    pcall(function() if m.fill then m.fill.Visible = false end end)
    pcall(function() if m.hpBack then m.hpBack.Visible = false end end)
    pcall(function() if m.hpFill then m.hpFill.Visible = false end end)
    pcall(function() if m.nameText then m.nameText.Visible = false end end)
end

local function hideArrowParts(m)
    if not m then return end
    for _, l in ipairs(m.arrow) do pcall(function() l.Visible = false end) end
end

local function hideMarker(m)
    hideBoxParts(m)
    hideArrowParts(m)
end

local function hideMarkers()
    for _, m in ipairs(markers) do hideMarker(m) end
end

local function fadeFor(t)
    if gv("ma_distance_fade", false) ~= true then return 1 end

    local range = gv("ma_range", 5000)
    if type(range) ~= "number" then range = 5000 end

    local f = 1 - ((t.distance or 0) / range) * 0.55
    return clamp(f, 0.35, 1)
end

local function drawCorners(m, x, y, w, h, color, thickness, trans, visible)
    local c = clamp(w * 0.45, 6, 18)

    setLine(m.corners[1], x, y, x + c, y, color, thickness, trans, visible)
    setLine(m.corners[2], x, y, x, y + c, color, thickness, trans, visible)
    setLine(m.corners[3], x + w - c, y, x + w, y, color, thickness, trans, visible)
    setLine(m.corners[4], x + w, y, x + w, y + c, color, thickness, trans, visible)
    setLine(m.corners[5], x, y + h, x + c, y + h, color, thickness, trans, visible)
    setLine(m.corners[6], x, y + h - c, x, y + h, color, thickness, trans, visible)
    setLine(m.corners[7], x + w - c, y + h, x + w, y + h, color, thickness, trans, visible)
    setLine(m.corners[8], x + w, y + h - c, x + w, y + h, color, thickness, trans, visible)
end

local function drawHealth(m, x, y, h, t, visible)
    if not validHealth(t.health, t.maxHealth) then
        setSquare(m.hpBack, 0, 0, 0, 0, Color3.fromRGB(0, 0, 0), 0, false)
        setSquare(m.hpFill, 0, 0, 0, 0, Color3.fromRGB(0, 0, 0), 0, false)
        return
    end

    local ratio = clamp(t.health / t.maxHealth, 0, 1)
    local barW = 3
    local barX = x - 7
    local fillH = h * ratio
    local fillY = y + (h - fillH)

    setSquare(m.hpBack, barX, y, barW, h, Color3.fromRGB(0, 0, 0), 0.85, visible)
    setSquare(m.hpFill, barX, fillY, barW, fillH, healthColor(ratio), 1, visible)
end

local function drawOffscreenArrow(m, screen, color, trans)
    if not screen then return false end

    local vp = viewport()
    local cx = vp.X / 2
    local cy = vp.Y / 2
    local margin = 28
    local dx = screen.X - cx
    local dy = screen.Y - cy
    local len = math.sqrt(dx * dx + dy * dy)

    if len < 1 then return false end

    local ux = dx / len
    local uy = dy / len
    local limitX = cx - margin
    local limitY = cy - margin
    local scaleX = 999999
    local scaleY = 999999

    if math.abs(dx) > 0.01 then scaleX = limitX / math.abs(dx) end
    if math.abs(dy) > 0.01 then scaleY = limitY / math.abs(dy) end

    local scale = math.min(scaleX, scaleY)
    local tipX = cx + dx * scale
    local tipY = cy + dy * scale
    local size = gv("ma_arrow_size", 16)
    if type(size) ~= "number" then size = 16 end

    local px = -uy
    local py = ux
    local backX = tipX - ux * size
    local backY = tipY - uy * size
    local leftX = backX + px * size * 0.45
    local leftY = backY + py * size * 0.45
    local rightX = backX - px * size * 0.45
    local rightY = backY - py * size * 0.45

    setLine(m.arrow[1], tipX, tipY, leftX, leftY, color, 2, trans, true)
    setLine(m.arrow[2], tipX, tipY, rightX, rightY, color, 2, trans, true)
    setLine(m.arrow[3], leftX, leftY, rightX, rightY, color, 1, trans * 0.8, true)

    return true
end

local function snapStart()
    local vp = viewport()
    local mode = combo("ma_snap_mode", snapModes)

    if mode == "Center" or mode == "Crosshair" then
        return vp.X / 2, vp.Y / 2
    end

    return vp.X / 2, vp.Y
end

local function updateEsp()
    if gv("ma_esp", true) ~= true then
        hideMarkers()
        return
    end

    if not shouldRun("espAt", fpsInterval("ma_esp_fps", 20)) then
        return
    end

    local max = gv("ma_max_markers", 16)
    if type(max) ~= "number" then max = 16 end

    local sizeSmooth = gv("ma_size_smooth", 3)
    if type(sizeSmooth) ~= "number" then sizeSmooth = 3 end

    local alpha = 1 / clamp(sizeSmooth, 1, 10)
    local thickness = gv("ma_box_thickness", 1)
    if type(thickness) ~= "number" then thickness = 1 end

    local shown = 0

    for _, t in ipairs(cache) do
        if shown >= max then break end

        local rootPos = pos(t.part)
        local headPos = pos(t.head or t.part)

        if rootPos and headPos then
            local topWorld = offsetY(headPos, 2.2)
            local bottomWorld = offsetY(rootPos, -3.2)

            local okTop, topScreen, topVisible = pcall(function()
                return WorldToScreen(topWorld)
            end)

            local okBottom, bottomScreen, bottomVisible = pcall(function()
                return WorldToScreen(bottomWorld)
            end)

            local color = baseColor(t)
            local trans = fadeFor(t)

            if okTop and okBottom and topVisible and bottomVisible and topScreen and bottomScreen then
                local boxH = math.abs(bottomScreen.Y - topScreen.Y)
                boxH = clamp(boxH, 18, 220)

                local boxW = clamp(boxH * 0.45, 10, 90)
                local centerX = (topScreen.X + bottomScreen.X) / 2

                shown = shown + 1

                local m = marker(shown)
                if m then
                    hideArrowParts(m)

                    if not m.w then
                        m.w = boxW
                        m.h = boxH
                    else
                        m.w = lerp(m.w, boxW, alpha)
                        m.h = lerp(m.h, boxH, alpha)
                    end

                    local x = centerX - m.w / 2
                    local y = topScreen.Y
                    local cornerVisible = gv("ma_corner_boxes", true) == true
                    local hpVisible = gv("ma_health", true) == true
                    local nameVisible = gv("ma_names", true) == true
                    local snapVisible = gv("ma_snaplines", false) == true
                    local fillVisible = gv("ma_fill_box", false) == true

                    drawCorners(m, x, y, m.w, m.h, color, thickness, trans, cornerVisible)
                    setSquare(m.fill, x, y, m.w, m.h, color, 0.16, fillVisible)
                    drawHealth(m, x, y, m.h, t, hpVisible)

                    local nameSize = gv("ma_name_size", 13)
                    if type(nameSize) ~= "number" then nameSize = 13 end
                    nameSize = clamp(nameSize, 9, 22)
                    setText(m.nameText, t.name, x + (m.w / 2), clamp(y - nameSize - 4, 2, 99999), color, nameSize, trans, nameVisible)

                    if snapVisible then
                        local sx, sy = snapStart()
                        setLine(m.snap, sx, sy, x + (m.w / 2), y + m.h, color, thickness, trans, true)
                    else
                        setLine(m.snap, 0, 0, 0, 0, color, 1, 0, false)
                    end
                end
            elseif gv("ma_offscreen", true) == true then
                local okScreen, screen = pcall(function()
                    return WorldToScreen(rootPos)
                end)

                if okScreen and screen then
                    shown = shown + 1
                    local m = marker(shown)

                    if m then
                        hideBoxParts(m)
                        drawOffscreenArrow(m, screen, color, trans)
                    end
                end
            end
        end
    end

    for i = shown + 1, #markers do
        hideMarker(markers[i])
        markers[i].w = nil
        markers[i].h = nil
    end
end

local function aimOrigin()
    local vp = viewport()
    local mode = combo("ma_aim_origin", aimOrigins)

    if mode == "Mouse" then
        local mouse = safe(function()
            return localPlayer():GetMouse()
        end, nil)

        local x = safe(function() return mouse.X end, nil)
        local y = safe(function() return mouse.Y end, nil)

        if type(x) == "number" and type(y) == "number" then
            return x, y
        end
    end

    return vp.X / 2, vp.Y / 2
end

local function velocityOf(t, p)
    if not t or not p then return nil end

    local part = t.part or t.head
    local v = safe(function() return part.AssemblyLinearVelocity end, nil)
    if not isVector3(v) then v = safe(function() return part.Velocity end, nil) end

    local stamp = now()
    local path = tostring(t.path or fullName(part))
    local state = targetMotion[path]

    if isVector3(v) then
        targetMotion[path] = {position = p, at = stamp, velocity = v}
        return v
    end

    if state and state.position and state.at and stamp > state.at then
        local dt = clamp(stamp - state.at, 0.001, 1)
        v = Vector3.new(
            (p.X - state.position.X) / dt,
            (p.Y - state.position.Y) / dt,
            (p.Z - state.position.Z) / dt
        )
    elseif state then
        v = state.velocity
    end

    targetMotion[path] = {position = p, at = stamp, velocity = v}
    return v
end

local function predictedAimPoint(t, p)
    if not p then return nil end

    local xzMs = gv("ma_aim_pred_xz", 0)
    local yMs = gv("ma_aim_pred_y", 0)

    if type(xzMs) ~= "number" then xzMs = 0 end
    if type(yMs) ~= "number" then yMs = 0 end

    xzMs = clamp(xzMs, 0, 300)
    yMs = clamp(yMs, 0, 300)

    if xzMs <= 0 and yMs <= 0 then return p end

    local v = velocityOf(t, p)
    if not isVector3(v) then return p end

    local xzTime = xzMs / 1000
    local yTime = yMs / 1000

    return Vector3.new(
        p.X + (v.X * xzTime),
        p.Y + (v.Y * yTime),
        p.Z + (v.Z * xzTime)
    )
end

local function aimPoint(t)
    if not t then return nil end

    local partMode = combo("ma_aim_part", aimParts)
    local p = nil

    if partMode == "Head" then
        p = pos(t.head) or pos(t.part)
    elseif partMode == "Center" then
        p = pos(t.part)
        if p then p = offsetY(p, 1.4) else p = pos(t.head) end
    else
        p = pos(t.part) or pos(t.head)
    end

    return predictedAimPoint(t, p)
end

local function screenForAim(t)
    local p = aimPoint(t)
    if not p then return nil, false end

    local ok, screen, visible = pcall(function()
        return WorldToScreen(p)
    end)

    if ok and screen and visible == true then
        return screen, true
    end

    return screen, false
end

local function aimScreenDistance(screen)
    local ox, oy = aimOrigin()
    local dx = screen.X - ox
    local dy = screen.Y - oy

    return math.sqrt(dx * dx + dy * dy), dx, dy
end

local function useCachedAimTarget(fov)
    local t = aim.bestTarget
    if not t then return nil, nil, nil end

    local screen, visible = screenForAim(t)
    if not screen or not visible then return nil, nil, nil end

    local d = aimScreenDistance(screen)
    if d > fov then return nil, nil, nil end

    aim.bestScreen = screen
    return t, screen, d
end

local function bestAimTarget(force)
    local fov = gv("ma_aim_fov", 160)
    if type(fov) ~= "number" then fov = 160 end

    if force ~= true then
        local cached, cachedScreen, cachedDist = useCachedAimTarget(fov)
        if cached then return cached, cachedScreen, cachedDist end

        local t = now()
        if t > 0 and (t - (aim.bestAt or 0)) < fpsInterval("ma_aim_scan_fps", 20) then
            return nil, nil, 999999999
        end
    end

    aim.bestAt = now()

    local best = nil
    local bestScreen = nil
    local bestDist = 999999999

    for _, t in ipairs(cache) do
        local screen, visible = screenForAim(t)

        if screen and visible then
            local d = aimScreenDistance(screen)

            if d <= fov and d < bestDist then
                best = t
                bestScreen = screen
                bestDist = d
            end
        end
    end

    aim.bestTarget = best
    aim.bestScreen = bestScreen

    return best, bestScreen, bestDist
end

local function hideAimFov()
    for _, l in ipairs(aim.fovLines) do
        pcall(function() l.Visible = false end)
    end
end

local function hideAimSight()
    pcall(function()
        if aim.sightDot then aim.sightDot.Visible = false end
    end)
end

local function aimFovLine(i)
    if aim.fovLines[i] then return aim.fovLines[i] end
    aim.fovLines[i] = newLine()
    return aim.fovLines[i]
end

local function drawAimFov()
    if gv("ma_aim_fov_ring", true) ~= true or gv("ma_aimbot", false) ~= true then
        hideAimFov()
        return
    end

    local fov = gv("ma_aim_fov", 160)
    if type(fov) ~= "number" then fov = 160 end

    local ox, oy = aimOrigin()
    local segments = 24
    local color = Color3.fromRGB(120, 220, 255)

    for i = 1, segments do
        local a1 = ((i - 1) / segments) * math.pi * 2
        local a2 = (i / segments) * math.pi * 2
        local x1 = ox + math.cos(a1) * fov
        local y1 = oy + math.sin(a1) * fov
        local x2 = ox + math.cos(a2) * fov
        local y2 = oy + math.sin(a2) * fov

        setLine(aimFovLine(i), x1, y1, x2, y2, color, 1, 0.75, true)
    end

    for i = segments + 1, #aim.fovLines do
        pcall(function() aim.fovLines[i].Visible = false end)
    end
end

local function drawAimSight()
    if gv("ma_aim_sight_marker", true) ~= true or gv("ma_aimbot", false) ~= true then
        hideAimSight()
        return
    end

    if not aim.sightDot then aim.sightDot = newSquare(true) end

    local ox, oy = aimOrigin()
    setSquare(aim.sightDot, ox - 3, oy - 3, 6, 6, Color3.fromRGB(255, 255, 255), 1, true)
end

local function drawAimOverlay()
    if gv("ma_aimbot", false) ~= true then
        hideAimFov()
        hideAimSight()
        return
    end

    drawAimFov()
    drawAimSight()
end

local function aimStep(delta, smooth, maxStep)
    local value = clamp(delta / smooth, -maxStep, maxStep)

    if math.abs(delta) > 1 and math.abs(value) < 1 then
        if delta > 0 then return 1 end
        return -1
    end

    return round(value)
end

local function aimActive()
    if gv("ma_aimbot", false) ~= true then return false end

    if isrbxactive and safe(function() return isrbxactive() end, false) ~= true then
        return false
    end

    if gv("ma_aim_hold_rmb", true) == true then
        if not ismouse2pressed then return false end
        if safe(function() return ismouse2pressed() end, false) ~= true then return false end
    end

    return true
end

local function updateAimbot()
    if shouldRun("aimOverlayAt", fpsInterval("ma_aim_overlay_fps", 20)) then
        drawAimOverlay()
    end

    if not aimActive() or not mousemoverel then return end

    if #cache == 0 then
        local t = now()
        if t <= 0 or t - lastRefreshAt > 0.75 then
            refreshTargets()
        end

        if #cache == 0 then return end
    end

    local _, screen = bestAimTarget()
    if not screen then return end

    local _, dx, dy = aimScreenDistance(screen)
    local smooth = gv("ma_aim_smooth", 8)
    local maxStep = gv("ma_aim_max_step", 35)

    if type(smooth) ~= "number" then smooth = 8 end
    if type(maxStep) ~= "number" then maxStep = 35 end

    smooth = clamp(smooth, 1, 30)
    maxStep = clamp(maxStep, 1, 120)

    local moveX = aimStep(dx, smooth, maxStep)
    local moveY = aimStep(dy, smooth, maxStep)

    if moveX ~= 0 or moveY ~= 0 then
        pcall(function() mousemoverel(moveX, moveY) end)
    end
end

local function keyPressed(id, code)
    if gv("ma_keys_enabled", true) ~= true or not iskeypressed then
        keyPrev[id] = false
        return false
    end

    local down = safe(function()
        return iskeypressed(code)
    end, false) == true

    local fired = down and not keyPrev[id]
    keyPrev[id] = down

    return fired
end

local function handleKeys()
    if keyPressed("esp", 0x56) then
        sv("ma_esp", not (gv("ma_esp", true) == true))
        log("ESP " .. tostring(gv("ma_esp", true) and "enabled" or "disabled"))
    end

    if keyPressed("aim", 0x46) then
        local nextValue = not (gv("ma_aimbot", false) == true)
        sv("ma_aimbot", nextValue)

        if nextValue and not mousemoverel then
            log("Aimbot enabled, but mousemoverel is missing")
        else
            log("Aimbot " .. tostring(nextValue and "enabled" or "disabled"))
        end
    end
end

pcall(function()
    Lib.RemoveTab(TAB)
end)

Lib.AddTab(TAB, function(tab)
    local targets = tab:Section("Targets", "Left")

    targets:Combo("ma_mode", "Mode", modes, 0)
    targets:SliderInt("ma_range", "Range", 100, 10000, 5000)
    targets:SliderInt("ma_scan_delay", "Scan Delay", 1, 5, 2)
    targets:SliderInt("ma_max_markers", "Max Markers", 4, 40, 16)
    targets:Toggle("ma_enemies_only", "Enemies Only", true)
    targets:Toggle("ma_include_bots", "Include Bots", true)
    targets:Toggle("ma_deep_scan", "Deep Scan Fallback", false)

    targets:Button("Refresh Targets", function()
        local err = refreshTargets()
        if err then
            log(err)
        else
            log("Targets found: " .. tostring(#cache))
        end
    end)

    local visual = tab:Section("ESP", "Right")

    visual:Toggle("ma_esp", "ESP Enabled", true)
    visual:Toggle("ma_corner_boxes", "Corner Boxes", true)
    visual:Toggle("ma_names", "Names", true)
    visual:SliderInt("ma_name_size", "Name Size", 9, 22, 13)
    visual:Toggle("ma_health", "Health Bar", true)
    visual:Toggle("ma_snaplines", "Snaplines", false)
    visual:Combo("ma_snap_mode", "Snap Mode", snapModes, 0)
    visual:Toggle("ma_fill_box", "Soft Fill", false)
    visual:Toggle("ma_offscreen", "Offscreen Arrows", true)
    visual:Toggle("ma_distance_fade", "Distance Fade", false)
    visual:SliderInt("ma_esp_fps", "ESP FPS", 5, 300, 20)
    visual:SliderInt("ma_size_smooth", "Size Smooth", 1, 10, 2)
    visual:SliderInt("ma_box_thickness", "Box Line", 1, 4, 1)
    visual:SliderInt("ma_arrow_size", "Arrow Size", 8, 28, 16)

    local aimSec = tab:Section("Aimbot", "Left")

    aimSec:Toggle("ma_aimbot", "Aimbot Enabled", false)
    aimSec:Toggle("ma_aim_hold_rmb", "Hold RMB", true)
    aimSec:Combo("ma_aim_part", "Aim Part", aimParts, 0)
    aimSec:Combo("ma_aim_origin", "Aim Origin", aimOrigins, 0)
    aimSec:SliderInt("ma_aim_fov", "Aim FOV", 25, 500, 160)
    aimSec:SliderInt("ma_aim_smooth", "Aim Smooth", 1, 30, 8)
    aimSec:SliderInt("ma_aim_max_step", "Aim Max Step", 1, 80, 35)
    aimSec:SliderInt("ma_aim_scan_fps", "Aim Scan FPS", 5, 300, 20)
    aimSec:SliderInt("ma_aim_overlay_fps", "Overlay FPS", 5, 60, 20)
    aimSec:SliderInt("ma_aim_pred_xz", "Prediction XZ ms", 0, 300, 0)
    aimSec:SliderInt("ma_aim_pred_y", "Prediction Y ms", 0, 300, 0)
    aimSec:Toggle("ma_aim_fov_ring", "FOV Ring", true)
    aimSec:Toggle("ma_aim_sight_marker", "Aim Marker", true)

    local keys = tab:Section("Keys", "Right")

    keys:Text("V toggles ESP | F toggles Aimbot")
    keys:Toggle("ma_keys_enabled", "Hotkeys Enabled", true)
end)

local spawnFn = task and task.spawn or spawn

spawnFn(function()
    log("Loaded ESP + Aimbot")
    refreshTargets()

    local scanClock = 0

    while alive() do
        wait(0.016)

        handleKeys()
        scanClock = scanClock + 0.016

        local delay = gv("ma_scan_delay", 2)
        if type(delay) ~= "number" then delay = 2 end
        delay = clamp(delay, 1, 5)

        if scanClock >= delay then
            scanClock = 0
            refreshTargets()
        end

        updateEsp()
        updateAimbot()
    end

    hideMarkers()
    hideAimFov()
    hideAimSight()
end)
