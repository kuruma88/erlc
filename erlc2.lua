-- ERLC Full ESP + Matcha UI
-- Update #21
-- Performance fix: no per-frame UI sync, lighter render loop
-- Vehicle HP from Control_Values.Health
-- Helicopter distance ESP
-- Green status dot when ESP enabled
-- Lockpick / Glass Cutter removal alerts (House / Jewelry robbery)
local Players = game:GetService("Players")
local Workspace = workspace or game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
----------------------------------------------------
-- CONFIG
----------------------------------------------------
local cfg = {
    masterEnabled = true,
    criminal = {
        enabled = true,
        color = Color3.fromRGB(255, 55, 55),
        yOffset = -5,
        fontSize = 11,
    },
    panic = {
        enabled = true,
        color = Color3.fromRGB(255, 120, 30),
        yOffset = 25,
        fontSize = 12,
    },
    deployable = {
        enabled = true,
        color = Color3.fromRGB(80, 200, 120),
        yOffset = 30,
        fontSize = 13,
    },
    bountyVehicle = {
        enabled = true,
        color = Color3.fromRGB(50, 180, 255),
        yOffset = 40,
        fontSize = 13,
    },
    stolenVehicle = {
        enabled = true,
        color = Color3.fromRGB(255, 110, 180),
        priceColor = Color3.fromRGB(255, 210, 70),
        yOffset = 40,
        fontSize = 13,
        showPrice = true,
    },
    personalVehicle = {
        enabled = true,
        color = Color3.fromRGB(100, 220, 255),
        yOffset = 40,
        fontSize = 13,
        text = "Personal Vehicle",
    },
    vehicleHealth = {
        enabled = true,
        fontSize = 12,
        showSeconds = 5,
        yOffset = 22,
    },
    helicopter = {
        enabled = true,
        color = Color3.fromRGB(255, 220, 50),
        yOffset = 40,
        fontSize = 14,
        text = "Helicopter",
        spotlightFontSize = 11,
        spotlightColor = Color3.fromRGB(255, 180, 40),
        showSpotlight = true,
        edgeMargin = 50,
    },
    robberyAlert = {
        enabled = true,
    },
    settings = {
        fontName = "SystemBold",
        dynamicSize = 0,
        maxDistance = 5000,
    }
}
local FONT_NAMES = { "UI", "System", "SystemBold", "Minecraft", "Monospace", "Pixel", "Fortnite" }
local FONT_MAP = {
    UI = Drawing.Fonts.UI,
    System = Drawing.Fonts.System,
    SystemBold = Drawing.Fonts.SystemBold,
    Minecraft = Drawing.Fonts.Minecraft,
    Monospace = Drawing.Fonts.Monospace,
    Pixel = Drawing.Fonts.Pixel,
    Fortnite = Drawing.Fonts.Fortnite,
}
local cachedFont = Drawing.Fonts.SystemBold
local function refreshFont()
    cachedFont = FONT_MAP[cfg.settings.fontName] or Drawing.Fonts.SystemBold
end
local function colToRGB(c)
    return c.R, c.G, c.B, 1
end
----------------------------------------------------
-- MATCHA UI
----------------------------------------------------
UI.AddTab("ERLC ESP", function(tab)
    local left = tab:Section("ESP", "Left")
    left:Toggle("esp_master", "Master Enabled", cfg.masterEnabled, function(v)
        cfg.masterEnabled = v
    end)
    left:SliderInt("esp_maxdist", "Max Distance", 100, 10000, cfg.settings.maxDistance, function(v)
        cfg.settings.maxDistance = v
    end)
    left:Combo("esp_font", "Font", FONT_NAMES, 2, function(idx, text)
        cfg.settings.fontName = text
        refreshFont()
    end)
    left:Spacing()
    left:Toggle("esp_criminal", "Criminal", cfg.criminal.enabled, function(v)
        cfg.criminal.enabled = v
    end)
    left:ColorPicker("esp_criminal_col", colToRGB(cfg.criminal.color), function(c)
        cfg.criminal.color = c
    end)
    left:Toggle("esp_panic", "Panic", cfg.panic.enabled, function(v)
        cfg.panic.enabled = v
    end)
    left:ColorPicker("esp_panic_col", colToRGB(cfg.panic.color), function(c)
        cfg.panic.color = c
    end)
    left:Toggle("esp_deploy", "Deployables", cfg.deployable.enabled, function(v)
        cfg.deployable.enabled = v
    end)
    left:ColorPicker("esp_deploy_col", colToRGB(cfg.deployable.color), function(c)
        cfg.deployable.color = c
    end)
    left:Toggle("esp_robbery", "Robbery Tool Alerts", cfg.robberyAlert.enabled, function(v)
        cfg.robberyAlert.enabled = v
    end)
    local right = tab:Section("Vehicles / Heli", "Right")
    right:Toggle("esp_bounty", "Bounty Vehicles", cfg.bountyVehicle.enabled, function(v)
        cfg.bountyVehicle.enabled = v
    end)
    right:ColorPicker("esp_bounty_col", colToRGB(cfg.bountyVehicle.color), function(c)
        cfg.bountyVehicle.color = c
    end)
    right:Toggle("esp_stolen", "Stolen Vehicles", cfg.stolenVehicle.enabled, function(v)
        cfg.stolenVehicle.enabled = v
    end)
    right:ColorPicker("esp_stolen_col", colToRGB(cfg.stolenVehicle.color), function(c)
        cfg.stolenVehicle.color = c
    end)
    right:Toggle("esp_stolen_price", "Show Price", cfg.stolenVehicle.showPrice, function(v)
        cfg.stolenVehicle.showPrice = v
    end)
    right:ColorPicker("esp_stolen_pricecol", colToRGB(cfg.stolenVehicle.priceColor), function(c)
        cfg.stolenVehicle.priceColor = c
    end)
    right:Toggle("esp_personal", "Personal Vehicle", cfg.personalVehicle.enabled, function(v)
        cfg.personalVehicle.enabled = v
    end)
    right:ColorPicker("esp_personal_col", colToRGB(cfg.personalVehicle.color), function(c)
        cfg.personalVehicle.color = c
    end)
    right:Toggle("esp_vhealth", "Vehicle Health (on damage)", cfg.vehicleHealth.enabled, function(v)
        cfg.vehicleHealth.enabled = v
    end)
    right:Toggle("esp_heli", "Helicopter", cfg.helicopter.enabled, function(v)
        cfg.helicopter.enabled = v
    end)
    right:ColorPicker("esp_heli_col", colToRGB(cfg.helicopter.color), function(c)
        cfg.helicopter.color = c
    end)
    right:Toggle("esp_heli_spotlight", "Show Spotlighted", cfg.helicopter.showSpotlight, function(v)
        cfg.helicopter.showSpotlight = v
    end)
    right:ColorPicker("esp_heli_spotcol", colToRGB(cfg.helicopter.spotlightColor), function(c)
        cfg.helicopter.spotlightColor = c
    end)
    right:Spacing()
    right:Button("Reset Defaults", function()
        UI.SetValue("esp_master", true)
        UI.SetValue("esp_criminal", true)
        UI.SetValue("esp_panic", true)
        UI.SetValue("esp_deploy", true)
        UI.SetValue("esp_robbery", true)
        UI.SetValue("esp_bounty", true)
        UI.SetValue("esp_stolen", true)
        UI.SetValue("esp_stolen_price", true)
        UI.SetValue("esp_personal", true)
        UI.SetValue("esp_vhealth", true)
        UI.SetValue("esp_heli", true)
        UI.SetValue("esp_heli_spotlight", true)
        UI.SetValue("esp_maxdist", 5000)
        cfg.masterEnabled = true
        cfg.robberyAlert.enabled = true
        if notify then notify("Defaults restored", "ERLC ESP", 2) end
    end)
end)
-- UI callbacks already write into cfg; this is only a light fallback sync (NOT per-frame)
local function syncFromUI()
    local function g(id, fallback)
        local v = UI.GetValue(id)
        if v == nil then return fallback end
        return v
    end
    cfg.masterEnabled = g("esp_master", cfg.masterEnabled)
    cfg.criminal.enabled = g("esp_criminal", cfg.criminal.enabled)
    cfg.panic.enabled = g("esp_panic", cfg.panic.enabled)
    cfg.deployable.enabled = g("esp_deploy", cfg.deployable.enabled)
    cfg.robberyAlert.enabled = g("esp_robbery", cfg.robberyAlert.enabled)
    cfg.bountyVehicle.enabled = g("esp_bounty", cfg.bountyVehicle.enabled)
    cfg.stolenVehicle.enabled = g("esp_stolen", cfg.stolenVehicle.enabled)
    cfg.stolenVehicle.showPrice = g("esp_stolen_price", cfg.stolenVehicle.showPrice)
    cfg.personalVehicle.enabled = g("esp_personal", cfg.personalVehicle.enabled)
    cfg.vehicleHealth.enabled = g("esp_vhealth", cfg.vehicleHealth.enabled)
    cfg.helicopter.enabled = g("esp_heli", cfg.helicopter.enabled)
    cfg.helicopter.showSpotlight = g("esp_heli_spotlight", cfg.helicopter.showSpotlight)
    cfg.settings.maxDistance = g("esp_maxdist", cfg.settings.maxDistance)
    local fontIdx = g("esp_font", 2)
    if type(fontIdx) == "number" and FONT_NAMES[fontIdx + 1] then
        cfg.settings.fontName = FONT_NAMES[fontIdx + 1]
        refreshFont()
    end
end
----------------------------------------------------
-- LISTS
----------------------------------------------------
local criminalList = {}
local panicList = {}
local deployableList = {}
local bountyList = {}
local stolenList = {}
local personalList = {}
local vehicleHealthState = {}
local heliLabel = nil
local heliSpotlightLabel = nil
local statusDot = nil
local robberyToolState = {}
----------------------------------------------------
-- HELPERS
----------------------------------------------------
local OFFSET_STUD_SCALE = 0.1
local DYNAMIC_REF_DIST = 400

local function calcFontSize(baseSize, dist)
    baseSize = tonumber(baseSize) or 10
    local dynamic = cfg.settings.dynamicSize or 0
    if dynamic <= 0 then return baseSize end
    local distNorm = math.min((tonumber(dist) or 0) / DYNAMIC_REF_DIST, 1)
    local intensity = dynamic / 10
    local minScale = 1 - intensity * 0.5
    local maxScale = 1 + intensity * 0.5
    local scale = minScale + distNorm * (maxScale - minScale)
    return math.max(8, math.floor(baseSize * scale + 0.5))
end

-- Only touch Font/FontSize when value actually changes
local function applyTextStyle(label, fs)
    if not label then return end
    fs = math.max(8, math.floor(tonumber(fs) or 10))
    if label._fs ~= fs then
        label._fs = fs
        pcall(function()
            label.Font = cachedFont
            label.FontSize = fs
            label.Size = fs
        end)
    end
end

local function createTextEsp(size)
    local label = Drawing.new("Text")
    label.Center = true
    label.Outline = true
    label.ZIndex = 120
    label.Visible = false
    label._fs = -1
    applyTextStyle(label, size or 12)
    return label
end

local function createCircleEsp()
    local circle = Drawing.new("Circle")
    circle.Filled = true
    circle.NumSides = 10
    circle.Thickness = 1
    circle.Transparency = 0
    circle.ZIndex = 119
    circle.Visible = false
    return circle
end

local function ensureStatusDot()
    if statusDot then return statusDot end
    local dot = Drawing.new("Circle")
    dot.Filled = true
    dot.NumSides = 12
    dot.Thickness = 1
    dot.Transparency = 0
    dot.Radius = 4
    dot.Color = Color3.fromRGB(60, 255, 90)
    dot.ZIndex = 200
    dot.Visible = false
    statusDot = dot
    return statusDot
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
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position end
    local cam = Workspace.CurrentCamera
    if cam then return cam.Position end
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

local function getOwnerString(model)
    return getStringField(model, "Owner")
end

local function getDriverName(model)
    return getStringField(model, "DriverName")
end

local function getVehicleHealth(model)
    if not model then return nil end
    local cv = model:FindFirstChild("Control_Values")
    local healthObj = cv and cv:FindFirstChild("Health")
    if healthObj and typeof(healthObj.Value) == "number" then
        return healthObj.Value
    end
    return nil
end

local function getVehicleMaxHealth(model)
    if not model then return nil end
    local cv = model:FindFirstChild("Control_Values")
    if not cv then return nil end
    for _, name in ipairs({ "MaxHealth", "Max_Health", "maxHealth", "HealthMax", "MaxHP" }) do
        local obj = cv:FindFirstChild(name)
        if obj and typeof(obj.Value) == "number" and obj.Value > 0 then
            return obj.Value
        end
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
    label.Text = text
    label.Position = Vector2.new(sPos.X, sPos.Y)
    label.Color = color
    label.Visible = true
    return sPos
end

local function getHelicopterPosition()
    local folder = Workspace:FindFirstChild("Helicopter")
    local model = folder and folder:FindFirstChild("Helicopter")
    local root = getRootPart(model)
    if root and root.Parent then
        return root.Position
    end
    local ok, pos = pcall(function()
        local rs = ReplicatedStorage:FindFirstChild("ReplicatedState")
        local misc = rs and rs:FindFirstChild("MiscValues")
        if not misc then return nil end
        local heliOut = misc:FindFirstChild("HeliOut")
        local heliPos = misc:FindFirstChild("HeliPosition")
        if heliOut and heliOut.Value == true and heliPos then
            return heliPos.Value
        end
        return nil
    end)
    if ok and pos then return pos end
    return nil
end

local function getHeliScreenPos(worldPos)
    local margin = cfg.helicopter.edgeMargin or 50
    local sPos, onScreen = WorldToScreen(worldPos)
    if onScreen and sPos then
        return Vector2.new(sPos.X, sPos.Y), true
    end
    -- Edge clamp only when off-screen; avoid WorldToViewportPoint when possible
    local cam = Workspace.CurrentCamera
    if not cam then return nil, false end
    local viewport = cam.ViewportSize
    local ok, sp, _, depth = pcall(function()
        return cam:WorldToViewportPoint(worldPos)
    end)
    if not ok or not sp then return nil, false end
    if depth and depth < 0 then
        sp = Vector3.new(viewport.X - sp.X, viewport.Y - sp.Y, depth)
    end
    local x = math.clamp(sp.X, margin, viewport.X - margin)
    local y = math.clamp(sp.Y, margin, viewport.Y - margin)
    return Vector2.new(x, y), false
end
----------------------------------------------------
-- ROBBERY TOOL ALERTS
----------------------------------------------------
local function containerHasTool(container, toolName)
    if not container then return false end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Tool") and child.Name == toolName then
            return true
        end
    end
    return false
end

local function playerHasTool(player, toolName)
    if not player then return false end
    return containerHasTool(player:FindFirstChild("Backpack"), toolName)
        or containerHasTool(player.Character, toolName)
end

local function updateRobberyToolAlerts()
    if not cfg.masterEnabled or not cfg.robberyAlert.enabled then
        return
    end
    local seen = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local uid = player.UserId
        if uid then
            seen[uid] = true
            local hasLockpick = playerHasTool(player, "Lockpick")
            local hasGlassCutter = playerHasTool(player, "Glass Cutter")
            local prev = robberyToolState[uid]
            if prev then
                if prev.lockpick and not hasLockpick and notify then
                    notify(player.Name .. " lost Lockpick", "Potential House Robbery", 5)
                end
                if prev.glassCutter and not hasGlassCutter and notify then
                    notify(player.Name .. " lost Glass Cutter", "Potential Jewelry Robbery", 5)
                end
            end
            robberyToolState[uid] = {
                lockpick = hasLockpick,
                glassCutter = hasGlassCutter,
            }
        end
    end
    for uid in pairs(robberyToolState) do
        if not seen[uid] then
            robberyToolState[uid] = nil
        end
    end
end
----------------------------------------------------
-- CACHE (slow path — 0.5s)
----------------------------------------------------
local function updateCriminalCache()
    if not cfg.masterEnabled or not cfg.criminal.enabled then
        for i = #criminalList, 1, -1 do
            removeEsp(criminalList[i])
            table.remove(criminalList, i)
        end
        return
    end
    local tracked = {}
    local myUid = LocalPlayer and LocalPlayer.UserId
    for _, player in ipairs(Players:GetPlayers()) do
        if player.UserId ~= myUid then
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
        if not key or not tracked[key] then
            removeEsp(e)
            table.remove(criminalList, i)
        else
            tracked[key] = nil
        end
    end
    for _, player in pairs(tracked) do
        table.insert(criminalList, {
            Player = player,
            Label = createTextEsp(cfg.criminal.fontSize),
            Circle = createCircleEsp()
        })
    end
end

local function updatePanicCache()
    if not cfg.masterEnabled or not cfg.panic.enabled then
        for i = #panicList, 1, -1 do
            removeEsp(panicList[i])
            table.remove(panicList, i)
        end
        return
    end
    local tracked = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local activePanic = player:FindFirstChild("ActivePanic") or (char and char:FindFirstChild("ActivePanic"))
            local isPanicActive = false
            if activePanic then
                if activePanic:IsA("BoolValue") then
                    isPanicActive = activePanic.Value == true
                else
                    isPanicActive = true
                end
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
        table.insert(panicList, {
            Player = player,
            Label = createTextEsp(cfg.panic.fontSize)
        })
    end
end

local function updateDeployableCache()
    if not cfg.masterEnabled or not cfg.deployable.enabled then
        for i = #deployableList, 1, -1 do
            removeEsp(deployableList[i])
            table.remove(deployableList, i)
        end
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
        table.insert(deployableList, {
            Model = model,
            Label = createTextEsp(cfg.deployable.fontSize)
        })
    end
end

local function updateBountyCache()
    if not cfg.masterEnabled or not cfg.bountyVehicle.enabled then
        for i = #bountyList, 1, -1 do
            removeEsp(bountyList[i])
            table.remove(bountyList, i)
        end
        return
    end
    local folder = Workspace:FindFirstChild("BountyVehicles")
    local vehicles = folder and folder:FindFirstChild("Vehicles")
    local tracked = {}
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
        table.insert(bountyList, {
            Model = model,
            Label = createTextEsp(cfg.bountyVehicle.fontSize)
        })
    end
end

local function updateStolenCache()
    if not cfg.masterEnabled or not cfg.stolenVehicle.enabled then
        for i = #stolenList, 1, -1 do
            removeEsp(stolenList[i])
            table.remove(stolenList, i)
        end
        return
    end
    local vehicles = Workspace:FindFirstChild("Vehicles")
    local tracked = {}
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
            Model = model,
            Label = createTextEsp(cfg.stolenVehicle.fontSize),
            PriceLabel = createTextEsp(11)
        })
    end
end

local function updatePersonalCache()
    if not cfg.masterEnabled or not cfg.personalVehicle.enabled then
        for i = #personalList, 1, -1 do
            removeEsp(personalList[i])
            table.remove(personalList, i)
        end
        return
    end
    local myName = LocalPlayer and LocalPlayer.Name
    if not myName then return end
    local vehicles = Workspace:FindFirstChild("Vehicles")
    local tracked = {}
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
        table.insert(personalList, {
            Model = model,
            Label = createTextEsp(cfg.personalVehicle.fontSize)
        })
    end
end
----------------------------------------------------
-- VEHICLE HEALTH
----------------------------------------------------
local function updateVehicleHealthVisual(localPos, maxDist)
    if not cfg.masterEnabled or not cfg.vehicleHealth.enabled or not localPos then
        for _, st in pairs(vehicleHealthState) do
            if st.label then st.label.Visible = false end
        end
        return
    end
    local myName = LocalPlayer and LocalPlayer.Name
    if not myName then return end
    local now = tick()
    local seen = {}
    local nearDist = maxDist or cfg.settings.maxDistance or 5000
    local vehicles = Workspace:FindFirstChild("Vehicles")
    if not vehicles then
        for _, st in pairs(vehicleHealthState) do
            if st.label then st.label.Visible = false end
        end
        return
    end
    for _, model in ipairs(vehicles:GetChildren()) do
        if model:IsA("Model") or model:IsA("Folder") then
            local owner = getOwnerString(model)
            if owner and owner == myName then
                local key = getKey(model)
                if key then
                    local root = getRootPart(model)
                    if root and root.Parent then
                        local pos = root.Position
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
                                        maxHealth = mh,
                                        showUntil = 0,
                                        label = createTextEsp(cfg.vehicleHealth.fontSize),
                                        model = model,
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
                                if not st.maxHealth or st.maxHealth <= 0 then
                                    st.maxHealth = math.max(health, 100)
                                end
                                if health < st.lastHealth then
                                    st.showUntil = now + (cfg.vehicleHealth.showSeconds or 5)
                                end
                                st.lastHealth = health
                                if now < st.showUntil then
                                    local text = "HP: " .. tostring(math.floor(health + 0.5))
                                    local col = healthToColor(health, st.maxHealth)
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
----------------------------------------------------
-- VISUAL LOOP (fast path — no UI sync)
----------------------------------------------------
local function updateVisuals()
    -- Status dot
    local dot = ensureStatusDot()
    if cfg.masterEnabled then
        local cam = Workspace.CurrentCamera
        local vp = cam and cam.ViewportSize
        dot.Position = Vector2.new(vp and (vp.X * 0.5) or 960, 12)
        dot.Visible = true
    else
        dot.Visible = false
    end

    if not cfg.masterEnabled then
        for _, list in ipairs({criminalList, panicList, deployableList, bountyList, stolenList, personalList}) do
            for _, e in ipairs(list) do hideEntry(e) end
        end
        for _, st in pairs(vehicleHealthState) do
            if st.label then st.label.Visible = false end
        end
        if heliLabel then heliLabel.Visible = false end
        if heliSpotlightLabel then heliSpotlightLabel.Visible = false end
        return
    end

    local localPos = getLocalPos()
    local maxDist = cfg.settings.maxDistance
    local myName = LocalPlayer and LocalPlayer.Name

    -- Criminals
    for _, e in ipairs(criminalList) do
        local player = e.Player
        if not player or not player.Parent or player == LocalPlayer then
            hideEntry(e)
        else
            local char = player.Character
            local head = char and char:FindFirstChild("Head")
            if not head then
                hideEntry(e)
            else
                local pos = head.Position
                local dist = localPos and (pos - localPos).Magnitude or 0
                if localPos and dist > maxDist then
                    hideEntry(e)
                else
                    local sPos, onScreen = WorldToScreen(pos)
                    if onScreen and sPos then
                        local radius = math.clamp(380 / (dist > 0 and dist or 1), 3, 8)
                        e.Circle.Position = sPos
                        e.Circle.Radius = radius
                        e.Circle.Color = cfg.criminal.color
                        e.Circle.Visible = true
                        local val = player:FindFirstChild("Is_Wanted")
                        local wantedVal = val and val.Value or 0
                        applyTextStyle(e.Label, calcFontSize(cfg.criminal.fontSize, dist))
                        e.Label.Text = tostring(wantedVal)
                        e.Label.Color = cfg.criminal.color
                        e.Label.Position = Vector2.new(sPos.X, sPos.Y + radius + 4)
                        e.Label.Visible = true
                    else
                        hideEntry(e)
                    end
                end
            end
        end
    end

    -- Panic
    for _, e in ipairs(panicList) do
        local player = e.Player
        if not player or not player.Parent or player == LocalPlayer then
            hideEntry(e)
        else
            local char = player.Character
            local head = char and char:FindFirstChild("Head")
            if not head then
                hideEntry(e)
            else
                local pos = head.Position
                local dist = localPos and (pos - localPos).Magnitude or 0
                if localPos and dist > maxDist then
                    hideEntry(e)
                else
                    drawText(e.Label, pos, "*PANIC*", cfg.panic.color, cfg.panic.yOffset, cfg.panic.fontSize, dist)
                end
            end
        end
    end

    -- Deployables
    for _, e in ipairs(deployableList) do
        local model = e.Model
        if not model or not model.Parent then
            hideEntry(e)
        else
            local root = getRootPart(model)
            if not root then
                hideEntry(e)
            else
                local pos = root.Position
                local dist = localPos and (pos - localPos).Magnitude or 0
                if localPos and dist > maxDist then
                    hideEntry(e)
                else
                    drawText(e.Label, pos, model.Name, cfg.deployable.color, cfg.deployable.yOffset, cfg.deployable.fontSize, dist)
                end
            end
        end
    end

    -- Bounty
    for _, e in ipairs(bountyList) do
        local model = e.Model
        if not model or not model.Parent then
            hideEntry(e)
        else
            local root = getRootPart(model)
            if not root then
                hideEntry(e)
            else
                local pos = root.Position
                local dist = localPos and (pos - localPos).Magnitude or 0
                if localPos and dist > maxDist then
                    hideEntry(e)
                else
                    drawText(e.Label, pos, model.Name, cfg.bountyVehicle.color, cfg.bountyVehicle.yOffset, cfg.bountyVehicle.fontSize, dist)
                end
            end
        end
    end

    -- Stolen
    for _, e in ipairs(stolenList) do
        local model = e.Model
        if not model or not model.Parent then
            hideEntry(e)
        else
            local root = getRootPart(model)
            if not root then
                hideEntry(e)
            else
                local pos = root.Position
                local dist = localPos and (pos - localPos).Magnitude or 0
                if localPos and dist > maxDist then
                    hideEntry(e)
                else
                    local sPos = drawText(e.Label, pos, "*Stolen Vehicle*", cfg.stolenVehicle.color, cfg.stolenVehicle.yOffset, cfg.stolenVehicle.fontSize, dist)
                    if sPos and cfg.stolenVehicle.showPrice then
                        local price = model:GetAttribute("ChopShopPrice") or 0
                        applyTextStyle(e.PriceLabel, calcFontSize(11, dist))
                        e.PriceLabel.Text = "$" .. tostring(price)
                        e.PriceLabel.Color = cfg.stolenVehicle.priceColor
                        e.PriceLabel.Position = Vector2.new(sPos.X, sPos.Y + 16)
                        e.PriceLabel.Visible = true
                    else
                        e.PriceLabel.Visible = false
                    end
                end
            end
        end
    end

    -- Personal
    for _, e in ipairs(personalList) do
        local model = e.Model
        if not model or not model.Parent then
            hideEntry(e)
        else
            local driver = getDriverName(model)
            if myName and driver and driver == myName then
                hideEntry(e)
            else
                local root = getRootPart(model)
                if not root then
                    hideEntry(e)
                else
                    local pos = root.Position
                    local dist = localPos and (pos - localPos).Magnitude or 0
                    if localPos and dist > maxDist then
                        hideEntry(e)
                    else
                        drawText(e.Label, pos, cfg.personalVehicle.text, cfg.personalVehicle.color, cfg.personalVehicle.yOffset, cfg.personalVehicle.fontSize, dist)
                    end
                end
            end
        end
    end

    updateVehicleHealthVisual(localPos, maxDist)

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
                applyTextStyle(heliLabel, calcFontSize(cfg.helicopter.fontSize, dist))
                heliLabel.Text = cfg.helicopter.text .. " [" .. math.floor(dist + 0.5) .. "m]"
                heliLabel.Color = cfg.helicopter.color
                heliLabel.Position = screenPos
                heliLabel.Visible = true
                if cfg.helicopter.showSpotlight then
                    local names = nil
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer then
                            local lastLoc = player:FindFirstChild("LastLocation")
                            local spotlighted = lastLoc and lastLoc:FindFirstChild("Spotlighted")
                            if spotlighted and spotlighted.Value == true then
                                if not names then names = {} end
                                names[#names + 1] = player.Name
                            end
                        end
                    end
                    if names and #names > 0 then
                        applyTextStyle(heliSpotlightLabel, calcFontSize(cfg.helicopter.spotlightFontSize, dist))
                        heliSpotlightLabel.Text = "Spotlighted: " .. table.concat(names, ", ")
                        heliSpotlightLabel.Color = cfg.helicopter.spotlightColor
                        heliSpotlightLabel.Position = Vector2.new(screenPos.X, screenPos.Y + 16)
                        heliSpotlightLabel.Visible = true
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
-- THREADS
----------------------------------------------------
-- Slow path: caches + UI sync + robbery alerts (0.5s)
task.spawn(function()
    while true do
        pcall(syncFromUI)
        pcall(updateCriminalCache)
        pcall(updatePanicCache)
        pcall(updateDeployableCache)
        pcall(updateBountyCache)
        pcall(updateStolenCache)
        pcall(updatePersonalCache)
        pcall(updateRobberyToolAlerts)
        task.wait(0.5)
    end
end)

-- Fast path: drawing only (no UI sync, no heavy scans)
task.spawn(function()
    while true do
        pcall(updateVisuals)
        task.wait()
    end
end)

local lastAltState = false
task.spawn(function()
    while true do
        if iskeypressed then
            local altPressed = iskeypressed(0x12)
            if altPressed and not lastAltState then
                local newState = not cfg.masterEnabled
                cfg.masterEnabled = newState
                pcall(function()
                    UI.SetValue("esp_master", newState)
                end)
                if notify then
                    notify(newState and "ESP: ON" or "ESP: OFF", "ERLC ESP", 2)
                end
            end
            lastAltState = altPressed
        end
        task.wait(0.05)
    end
end)

refreshFont()
if notify then
    notify("ERLC ESP loaded\nUpdate #21 (perf)", "ERLC ESP", 3)
end
