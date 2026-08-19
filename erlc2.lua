-- ERLC Full ESP + Matcha UI + Autofarms
-- Update #18 — Vehicle HP + ATM / Lockpick / Glass Cutting

local Players            = game:GetService("Players")
local Workspace          = workspace or game:GetService("Workspace")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local HttpService        = game:GetService("HttpService")
local LocalPlayer        = Players.LocalPlayer

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
        enabled          = true,
        color            = Color3.fromRGB(255, 220, 50),
        yOffset          = 40,
        fontSize         = 14,
        text             = "Helicopter",
        spotlightFontSize= 11,
        spotlightColor   = Color3.fromRGB(255, 180, 40),
        showSpotlight    = true,
        edgeMargin       = 50,
    },

    -- Autofarms
    atm        = { enabled = false },
    lockpick   = { enabled = false },
    glasscut   = { enabled = false },

    settings = {
        fontName     = "SystemBold",
        dynamicSize  = 0,
        maxDistance  = 5000,
    }
}

local FONT_NAMES = { "UI", "System", "SystemBold", "Minecraft", "Monospace", "Pixel", "Fortnite" }
local FONT_MAP = {
    UI          = Drawing.Fonts.UI,
    System      = Drawing.Fonts.System,
    SystemBold  = Drawing.Fonts.SystemBold,
    Minecraft   = Drawing.Fonts.Minecraft,
    Monospace   = Drawing.Fonts.Monospace,
    Pixel       = Drawing.Fonts.Pixel,
    Fortnite    = Drawing.Fonts.Fortnite,
}

local function getEspFont()
    return FONT_MAP[cfg.settings.fontName] or Drawing.Fonts.SystemBold
end

local function colToRGB(c)
    return c.R, c.G, c.B, 1
end

----------------------------------------------------
-- MATCHA UI
----------------------------------------------------
UI.AddTab("ERLC ESP", function(tab)
    ------------------------------------------------
    -- Left column: ESP
    ------------------------------------------------
    local left = tab:Section("ESP", "Left")

    left:Toggle("esp_master", "Master Enabled", cfg.masterEnabled, function(v)
        cfg.masterEnabled = v
    end)
    left:SliderInt("esp_maxdist", "Max Distance", 100, 10000, cfg.settings.maxDistance, function(v)
        cfg.settings.maxDistance = v
    end)
    left:Combo("esp_font", "Font", FONT_NAMES, 2, function(idx, text)
        cfg.settings.fontName = text
    end)

    left:Spacing()

    left:Toggle("esp_criminal", "Criminal", cfg.criminal.enabled, function(v) cfg.criminal.enabled = v end)
    left:ColorPicker("esp_criminal_col", colToRGB(cfg.criminal.color), function(c) cfg.criminal.color = c end)

    left:Toggle("esp_panic", "Panic", cfg.panic.enabled, function(v) cfg.panic.enabled = v end)
    left:ColorPicker("esp_panic_col", colToRGB(cfg.panic.color), function(c) cfg.panic.color = c end)

    left:Toggle("esp_deploy", "Deployables", cfg.deployable.enabled, function(v) cfg.deployable.enabled = v end)
    left:ColorPicker("esp_deploy_col", colToRGB(cfg.deployable.color), function(c) cfg.deployable.color = c end)

    ------------------------------------------------
    -- Right column: Vehicles / Heli
    ------------------------------------------------
    local right = tab:Section("Vehicles / Heli", "Right")

    right:Toggle("esp_bounty", "Bounty Vehicles", cfg.bountyVehicle.enabled, function(v) cfg.bountyVehicle.enabled = v end)
    right:ColorPicker("esp_bounty_col", colToRGB(cfg.bountyVehicle.color), function(c) cfg.bountyVehicle.color = c end)

    right:Toggle("esp_stolen", "Stolen Vehicles", cfg.stolenVehicle.enabled, function(v) cfg.stolenVehicle.enabled = v end)
    right:ColorPicker("esp_stolen_col", colToRGB(cfg.stolenVehicle.color), function(c) cfg.stolenVehicle.color = c end)
    right:Toggle("esp_stolen_price", "Show Price", cfg.stolenVehicle.showPrice, function(v) cfg.stolenVehicle.showPrice = v end)
    right:ColorPicker("esp_stolen_pricecol", colToRGB(cfg.stolenVehicle.priceColor), function(c) cfg.stolenVehicle.priceColor = c end)

    right:Toggle("esp_personal", "Personal Vehicle", cfg.personalVehicle.enabled, function(v) cfg.personalVehicle.enabled = v end)
    right:ColorPicker("esp_personal_col", colToRGB(cfg.personalVehicle.color), function(c) cfg.personalVehicle.color = c end)

    right:Toggle("esp_vhealth", "Vehicle Health (on damage)", cfg.vehicleHealth.enabled, function(v) cfg.vehicleHealth.enabled = v end)

    right:Toggle("esp_heli", "Helicopter", cfg.helicopter.enabled, function(v) cfg.helicopter.enabled = v end)
    right:ColorPicker("esp_heli_col", colToRGB(cfg.helicopter.color), function(c) cfg.helicopter.color = c end)
    right:Toggle("esp_heli_spotlight", "Show Spotlighted", cfg.helicopter.showSpotlight, function(v) cfg.helicopter.showSpotlight = v end)
    right:ColorPicker("esp_heli_spotcol", colToRGB(cfg.helicopter.spotlightColor), function(c) cfg.helicopter.spotlightColor = c end)

    right:Spacing()
    right:Button("Reset Defaults", function()
        UI.SetValue("esp_master", true)
        UI.SetValue("esp_criminal", true)
        UI.SetValue("esp_panic", true)
        UI.SetValue("esp_deploy", true)
        UI.SetValue("esp_bounty", true)
        UI.SetValue("esp_stolen", true)
        UI.SetValue("esp_stolen_price", true)
        UI.SetValue("esp_personal", true)
        UI.SetValue("esp_vhealth", true)
        UI.SetValue("esp_heli", true)
        UI.SetValue("esp_heli_spotlight", true)
        UI.SetValue("esp_maxdist", 5000)

        UI.SetValue("auto_atm", false)
        UI.SetValue("auto_lockpick", false)
        UI.SetValue("auto_glass", false)

        cfg.masterEnabled = true
        cfg.atm.enabled = false
        cfg.lockpick.enabled = false
        cfg.glasscut.enabled = false

        if notify then notify("Defaults restored", "ERLC ESP", 2) end
    end)

    ------------------------------------------------
    -- Autofarms (clearly on Right, under vehicles)
    ------------------------------------------------
    local auto = tab:Section("Autofarms", "Right")

    auto:Text("Minigame Autos")
    auto:Tip("Enable the ones you want. They activate automatically when the minigame appears.")

    auto:Toggle("auto_atm", "ATM Hack", cfg.atm.enabled, function(v)
        cfg.atm.enabled = v
        if notify then
            notify(v and "ATM Hack: ON" or "ATM Hack: OFF", "Autofarms", 2)
        end
    end)

    auto:Toggle("auto_lockpick", "Lockpick", cfg.lockpick.enabled, function(v)
        cfg.lockpick.enabled = v
        if notify then
            notify(v and "Lockpick: ON" or "Lockpick: OFF", "Autofarms", 2)
        end
    end)

    auto:Toggle("auto_glass", "Glass Cutting", cfg.glasscut.enabled, function(v)
        cfg.glasscut.enabled = v
        if notify then
            notify(v and "Glass Cutting: ON" or "Glass Cutting: OFF", "Autofarms", 2)
        end
    end)
end)

----------------------------------------------------
-- SHARED OFFSET LOADER (used by all autofarms)
----------------------------------------------------
local OFFSETS = nil
local function loadOffsets()
    if OFFSETS then return OFFSETS end

    local ver = getrbxversion and getrbxversion() or ""
    if ver == "" then
        warn("Autofarms: cannot detect Roblox version")
        return nil
    end

    local body = httpget("https://offsets.imtheo.lol/" .. ver .. "/offsetshex.json")
    if body == "" then
        warn("Autofarms: failed to fetch offsets for " .. ver)
        return nil
    end

    local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
    if not ok or not data or not data.Offsets then
        warn("Autofarms: bad offsets payload")
        return nil
    end

    local O = {}
    for cat, fields in pairs(data.Offsets) do
        for k, v in pairs(fields) do
            local n = tonumber(v)
            if n then O[cat .. "." .. k] = n end
        end
    end

    OFFSETS = {
        OFF_BG   = O["GuiObject.BackgroundColor3"] or 0x540,
        OFF_TXC  = O["GuiObject.TextColor3"] or 0xea8,
        OFF_TEXT = O["GuiObject.Text"] or 0xdf8,
        OFF_VIS  = O["GuiObject.Visible"] or 0x5ad,
        OFF_POS  = O["GuiBase2D.AbsolutePosition"] or 0x10c,
        OFF_SIZE = O["GuiBase2D.AbsoluteSize"] or 0x114,
        ver      = ver,
    }

    print("Autofarms: offsets loaded for " .. ver)
    return OFFSETS
end

local function mread(kind, addr)
    local a, b = pcall(memory_read, kind, addr)
    return a and b or nil
end

----------------------------------------------------
-- LISTS + HELPERS (ESP)
----------------------------------------------------
local criminalList      = {}
local panicList         = {}
local deployableList    = {}
local bountyList        = {}
local stolenList        = {}
local personalList      = {}
local vehicleHealthState = {}
local heliLabel         = nil
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
    circle.Filled      = true
    circle.NumSides    = 10
    circle.Thickness   = 1
    circle.Transparency= 0
    circle.ZIndex      = 119
    circle.Visible     = false
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
    local cam = Workspace.CurrentCamera
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

    local cam = Workspace.CurrentCamera
    if cam and cam.WorldToViewportPoint then
        local ok, sp, _, depth = pcall(function()
            return cam:WorldToViewportPoint(worldPos)
        end)
        if ok and sp then
            local viewport = cam.ViewportSize
            if depth and depth < 0 then
                sp = Vector3.new(viewport.X - sp.X, viewport.Y - sp.Y, depth)
            end
            local x = math.clamp(sp.X, margin, viewport.X - margin)
            local y = math.clamp(sp.Y, margin, viewport.Y - margin)
            return Vector2.new(x, y), false
        end
    end
    return nil, false
end

----------------------------------------------------
-- CACHE UPDATES (ESP)
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
            local activePanic = player:FindFirstChild("ActivePanic")
                or (char and char:FindFirstChild("ActivePanic"))
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
            Label  = createTextEsp(cfg.panic.fontSize)
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
        for i = #personalList, 1, -1 do
            removeEsp(personalList[i])
            table.remove(personalList, i)
        end
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
    if not cfg.masterEnabled or not cfg.vehicleHealth.enabled then
        for _, st in pairs(vehicleHealthState) do
            if st.label then st.label.Visible = false end
        end
        return
    end
    if not localPos then
        for _, st in pairs(vehicleHealthState) do
            if st.label then st.label.Visible = false end
        end
        return
    end

    local myName = LocalPlayer and LocalPlayer.Name
    if not myName then return end

    local now     = tick()
    local seen    = {}
    local nearDist= maxDist or cfg.settings.maxDistance or 5000
    local vehicles= Workspace:FindFirstChild("Vehicles")
    if not vehicles then
        for key, st in pairs(vehicleHealthState) do
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
                                if not st.maxHealth or st.maxHealth <= 0 then
                                    st.maxHealth = math.max(health, 100)
                                end

                                if health < st.lastHealth then
                                    st.showUntil = now + (cfg.vehicleHealth.showSeconds or 5)
                                end
                                st.lastHealth = health

                                if now < st.showUntil then
                                    local text = "HP: " .. tostring(math.floor(health + 0.5))
                                    local col  = healthToColor(health, st.maxHealth)
                                    drawText(st.label, pos, text, col,
                                        cfg.vehicleHealth.yOffset,
                                        cfg.vehicleHealth.fontSize, dist)
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
-- VISUAL LOOP (ESP)
----------------------------------------------------
local function updateVisuals()
    syncFromUI()

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
    local maxDist  = cfg.settings.maxDistance
    local myName   = LocalPlayer and LocalPlayer.Name

    for _, e in ipairs(criminalList) do
        pcall(function()
            local player = e.Player
            if not player or not player.Parent or player == LocalPlayer then
                hideEntry(e) return
            end
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
            if not player or not player.Parent or player == LocalPlayer then
                hideEntry(e) return
            end
            local char = player.Character
            local head = char and char:FindFirstChild("Head")
            if not head then hideEntry(e) return end

            local pos  = head.Position
            local dist = localPos and (pos - localPos).Magnitude or 0
            if localPos and dist > maxDist then hideEntry(e) return end

            drawText(e.Label, pos, "*PANIC*", cfg.panic.color,
                cfg.panic.yOffset, cfg.panic.fontSize, dist)
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

            drawText(e.Label, pos, model.Name, cfg.deployable.color,
                cfg.deployable.yOffset, cfg.deployable.fontSize, dist)
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

            drawText(e.Label, pos, model.Name, cfg.bountyVehicle.color,
                cfg.bountyVehicle.yOffset, cfg.bountyVehicle.fontSize, dist)
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

            local sPos = drawText(e.Label, pos, "*Stolen Vehicle*",
                cfg.stolenVehicle.color, cfg.stolenVehicle.yOffset,
                cfg.stolenVehicle.fontSize, dist)

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
            if myName and driver and driver == myName then
                hideEntry(e) return
            end
            local root = getRootPart(model)
            if not root then hideEntry(e) return end

            local pos  = root.Position
            local dist = localPos and (pos - localPos).Magnitude or 0
            if localPos and dist > maxDist then hideEntry(e) return end

            drawText(e.Label, pos, cfg.personalVehicle.text,
                cfg.personalVehicle.color, cfg.personalVehicle.yOffset,
                cfg.personalVehicle.fontSize, dist)
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
                            if spotlighted and spotlighted.Value == true then
                                table.insert(spotlightNames, player.Name)
                            end
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
-- ATM HACK
----------------------------------------------------
_G.ATM_HACK_INSTANCE = (_G.ATM_HACK_INSTANCE or 0) + 1
local atmMyId = _G.ATM_HACK_INSTANCE

task.spawn(function()
    local off = loadOffsets()
    if not off then
        print("ATM: offsets failed")
        return
    end

    local OFF_BG   = off.OFF_BG
    local OFF_VIS  = off.OFF_VIS
    local OFF_POS  = off.OFF_POS
    local OFF_SIZE = off.OFF_SIZE

    local function visible(inst)
        local v = mread("byte", inst.Address + OFF_VIS)
        if v ~= nil then return v == 1 end
        return false
    end

    local function centerOf(inst)
        local x = mread("float", inst.Address + OFF_POS)
        local y = mread("float", inst.Address + OFF_POS + 4)
        local w = mread("float", inst.Address + OFF_SIZE)
        local h = mread("float", inst.Address + OFF_SIZE + 4)
        if not x or not y or not w or not h then
            local p = inst.AbsolutePosition
            local s = inst.AbsoluteSize
            x, y, w, h = p.X, p.Y, s.X, s.Y
        end
        return x + w / 2, y + h / 2
    end

    local function waitFor(parent, name, timeout)
        local t = tick()
        while atmMyId == _G.ATM_HACK_INSTANCE do
            local c = parent:FindFirstChild(name)
            if c then return c end
            if tick() - t > timeout then return nil end
            task.wait(0.3)
        end
    end

    local pg    = waitFor(LocalPlayer, "PlayerGui", 30)
    local menus = pg and waitFor(pg, "GameMenus", 30)
    local atm   = menus and waitFor(menus, "ATM", 600)
    if not atm then
        print("ATM: GUI NOT FOUND")
        return
    end

    local hacking = waitFor(atm, "Hacking", 30)
    if not hacking then
        print("ATM: Hacking frame not found")
        return
    end

    local cycle    = hacking:FindFirstChild("CycleFrame")
    local clickBtn = hacking:FindFirstChild("ClickButton")

    local cycleOrder, cycleIdx = {}, {}
    local lastIdx = 0
    local clickCX, clickCY

    local function refreshCycle()
        cycleOrder, cycleIdx = {}, {}
        for _, listName in ipairs({ "List1", "List2", "List3", "List4" }) do
            local lf = cycle and cycle:FindFirstChild(listName)
            if lf then
                for _, c in ipairs(lf:GetChildren()) do
                    if c:IsA("TextLabel") then
                        cycleOrder[#cycleOrder + 1] = c
                        cycleIdx[c.Address] = #cycleOrder
                    end
                end
            end
        end
    end

    local function freshClickPos()
        local x = mread("float", clickBtn.Address + OFF_POS)
        local y = mread("float", clickBtn.Address + OFF_POS + 4)
        local w = mread("float", clickBtn.Address + OFF_SIZE)
        local h = mread("float", clickBtn.Address + OFF_SIZE + 4)
        if not x or not y or not w or not h then
            local p = clickBtn.AbsolutePosition
            local s = clickBtn.AbsoluteSize
            x, y, w, h = p.X, p.Y, s.X, s.Y
        end
        return x + w / 2, y + h / 2
    end

    local function findHighlight()
        local n = #cycleOrder
        if n == 0 then return nil end
        for step = 1, n do
            local idx = ((lastIdx + step - 1) % n) + 1
            local lbl = cycleOrder[idx]
            local r = mread("float", lbl.Address + OFF_BG)
            local g = mread("float", lbl.Address + OFF_BG + 4)
            local b = mread("float", lbl.Address + OFF_BG + 8)
            if r and g and b and (r + g + b) > 0.01 then
                lastIdx = idx
                return idx, lbl
            end
        end
        return nil
    end

    local function isHighlighted(idx)
        local lbl = cycleOrder[idx]
        if not lbl then return false end
        local r = mread("float", lbl.Address + OFF_BG)
        local g = mread("float", lbl.Address + OFF_BG + 4)
        local b = mread("float", lbl.Address + OFF_BG + 8)
        return r and g and b and (r + g + b) > 0.01
    end

    print("ATM: ready")

    while atmMyId == _G.ATM_HACK_INSTANCE do
        -- Wait until the feature is enabled
        while atmMyId == _G.ATM_HACK_INSTANCE and not cfg.atm.enabled do
            task.wait(0.4)
        end
        if atmMyId ~= _G.ATM_HACK_INSTANCE then return end

        -- Wait for the hacking screen to appear
        while atmMyId == _G.ATM_HACK_INSTANCE and cfg.atm.enabled and not visible(hacking) do
            task.wait(0.2)
        end
        if atmMyId ~= _G.ATM_HACK_INSTANCE or not cfg.atm.enabled then continue end

        print("ATM: HACKING ACTIVE")
        if notify then notify("ATM Hack Active", "Autofarms", 2) end

        -- Read the 5 target codes
        local targets = {}
        local tFill = tick()
        while atmMyId == _G.ATM_HACK_INSTANCE and cfg.atm.enabled and tick() - tFill < 10 do
            targets = {}
            for i = 1, 5 do
                local lbl = hacking:FindFirstChild("HexCode" .. i)
                local t = lbl and lbl.Text
                if t then t = t:gsub("%s", "") end
                if not t or #t == 0 or t:find("-") then break end
                targets[#targets + 1] = t
            end
            if #targets == 5 then break end
            task.wait(0.1)
        end

        if #targets < 5 then
            print("ATM: could not read code")
            while atmMyId == _G.ATM_HACK_INSTANCE and visible(hacking) do task.wait(0.5) end
            continue
        end

        refreshCycle()
        lastIdx = 0

        local tCycle = tick()
        while atmMyId == _G.ATM_HACK_INSTANCE and #cycleOrder == 0 and tick() - tCycle < 10 do
            refreshCycle()
            task.wait(0.2)
        end
        if #cycleOrder == 0 then
            print("ATM: cycle empty")
            while atmMyId == _G.ATM_HACK_INSTANCE and visible(hacking) do task.wait(0.5) end
            continue
        end

        print("ATM: selecting " .. table.concat(targets, " "))

        local okAll = true
        for i = 1, 5 do
            if not cfg.atm.enabled or atmMyId ~= _G.ATM_HACK_INSTANCE then
                okAll = false
                break
            end

            local target = targets[i]
            local tIdx = nil
            for j = 1, #cycleOrder do
                if cycleOrder[j].Text == target then
                    tIdx = j
                    break
                end
            end

            if not tIdx then
                print("ATM: target not in cycle: " .. target)
                okAll = false
                break
            end

            local clicked = false
            local t0 = tick()
            while atmMyId == _G.ATM_HACK_INSTANCE and cfg.atm.enabled and tick() - t0 < 45 do
                local idx = findHighlight()
                if idx == tIdx then
                    local ok = true
                    for k = 1, 3 do
                        if not isHighlighted(tIdx) then ok = false break end
                    end
                    if ok then
                        clickCX, clickCY = freshClickPos()
                        mousemoveabs(clickCX, clickCY)
                        task.wait(0.02)
                        mouse1click()
                        clicked = true
                        print("ATM: clicked " .. target)
                        break
                    end
                end
                task.wait(0.002)
            end

            if not clicked then
                print("ATM: round " .. i .. " timed out")
                okAll = false
                break
            end
        end

        if okAll then
            print("ATM: COMPLETE")
            if notify then notify("ATM Hack Complete", "Autofarms", 2) end
        end

        while atmMyId == _G.ATM_HACK_INSTANCE and visible(hacking) do
            task.wait(0.5)
        end
    end
end)

----------------------------------------------------
-- LOCKPICK
----------------------------------------------------
_G.LOCKPICK_INSTANCE = (_G.LOCKPICK_INSTANCE or 0) + 1
local lockMyId = _G.LOCKPICK_INSTANCE

task.spawn(function()
    local off = loadOffsets()
    if not off then
        print("Lockpick: offsets failed")
        return
    end

    local OFF_VIS  = off.OFF_VIS
    local OFF_POS  = off.OFF_POS
    local OFF_SIZE = off.OFF_SIZE

    local function rect(inst)
        local x = mread("float", inst.Address + OFF_POS)
        local y = mread("float", inst.Address + OFF_POS + 4)
        local w = mread("float", inst.Address + OFF_SIZE)
        local h = mread("float", inst.Address + OFF_SIZE + 4)
        if x and y and w and h then return x, y, w, h end
        local p = inst.AbsolutePosition
        local s = inst.AbsoluteSize
        return p.X, p.Y, s.X, s.Y
    end

    local function visible(inst)
        local v = mread("byte", inst.Address + OFF_VIS)
        if v ~= nil then return v == 1 end
        return false
    end

    -- Wait for GUI once
    local gui = nil
    local t = tick()
    while lockMyId == _G.LOCKPICK_INSTANCE and tick() - t < 600 do
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local gm = pg and pg:FindFirstChild("GameMenus")
        local g  = gm and gm:FindFirstChild("Lockpick")
        if g and g:FindFirstChild("Pick") then
            gui = g
            break
        end
        task.wait(0.3)
    end
    if not gui then
        print("Lockpick: GUI NOT FOUND")
        return
    end

    print("Lockpick: ready")

    while lockMyId == _G.LOCKPICK_INSTANCE do
        while lockMyId == _G.LOCKPICK_INSTANCE and not cfg.lockpick.enabled do
            task.wait(0.4)
        end
        if lockMyId ~= _G.LOCKPICK_INSTANCE then return end

        while lockMyId == _G.LOCKPICK_INSTANCE and cfg.lockpick.enabled and not visible(gui) do
            task.wait(0.2)
        end
        if lockMyId ~= _G.LOCKPICK_INSTANCE or not cfg.lockpick.enabled then continue end

        print("Lockpick: ACTIVE")
        if notify then notify("Lockpick Active", "Autofarms", 2) end

        -- small grace
        local tGrace = tick()
        while lockMyId == _G.LOCKPICK_INSTANCE and cfg.lockpick.enabled and tick() - tGrace < 1.5 do
            task.wait(0.1)
        end

        local pick    = gui:FindFirstChild("Pick")
        local redLine = pick and pick:FindFirstChild("RedLine")
        if not pick or not redLine then
            print("Lockpick: elements missing")
            while lockMyId == _G.LOCKPICK_INSTANCE and visible(gui) do task.wait(0.5) end
            continue
        end

        local okAll = true
        for round = 1, 6 do
            if not cfg.lockpick.enabled or lockMyId ~= _G.LOCKPICK_INSTANCE then
                okAll = false
                break
            end

            local piece = pick:FindFirstChild(tostring(round))
            if not piece then
                print("Lockpick: piece " .. round .. " missing")
                okAll = false
                break
            end

            local clicked = false
            local tR = tick()
            local prevCy, prevT = nil, nil
            local vel = 0

            while lockMyId == _G.LOCKPICK_INSTANCE and cfg.lockpick.enabled and tick() - tR < 20 do
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
                        clicked = true
                        print("Lockpick: clicked piece " .. round)
                        break
                    end

                    if math.abs(vel) > 10 then
                        local tToC = dist / vel
                        if tToC >= 0.006 and tToC <= 0.014 then
                            mouse1click()
                            clicked = true
                            print("Lockpick: predicted click piece " .. round)
                            break
                        end
                    end
                end
                task.wait(0.002)
            end

            if not clicked then
                print("Lockpick: round " .. round .. " MISSED")
                okAll = false
                break
            end
            task.wait(0.25)
        end

        if okAll then
            print("Lockpick: COMPLETE")
            if notify then notify("Lockpick Complete", "Autofarms", 2) end
        end

        while lockMyId == _G.LOCKPICK_INSTANCE and visible(gui) do
            task.wait(0.5)
        end
    end
end)

----------------------------------------------------
-- GLASS CUTTING
----------------------------------------------------
_G.GLASS_CUT_INSTANCE = (_G.GLASS_CUT_INSTANCE or 0) + 1
local glassMyId = _G.GLASS_CUT_INSTANCE

task.spawn(function()
    local off = loadOffsets()
    if not off then
        print("GlassCut: offsets failed")
        return
    end

    local OFF_VIS  = off.OFF_VIS
    local OFF_POS  = off.OFF_POS
    local OFF_SIZE = off.OFF_SIZE

    local function rect(inst)
        local x = mread("float", inst.Address + OFF_POS)
        local y = mread("float", inst.Address + OFF_POS + 4)
        local w = mread("float", inst.Address + OFF_SIZE)
        local h = mread("float", inst.Address + OFF_SIZE + 4)
        if x and y and w and h then return x, y, w, h end
        local p = inst.AbsolutePosition
        local s = inst.AbsoluteSize
        return p.X, p.Y, s.X, s.Y
    end

    local function visible(inst)
        local v = mread("byte", inst.Address + OFF_VIS)
        if v ~= nil then return v == 1 end
        return false
    end

    local gui = nil
    local t = tick()
    while glassMyId == _G.GLASS_CUT_INSTANCE and tick() - t < 600 do
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local gm = pg and pg:FindFirstChild("GameMenus")
        local g  = gm and gm:FindFirstChild("GlassCutting")
        if g then
            gui = g
            break
        end
        task.wait(0.3)
    end
    if not gui then
        print("GlassCut: GUI NOT FOUND")
        return
    end

    local grey = gui:FindFirstChild("GreyCircle")
    local box  = gui:FindFirstChild("GreenBox")
    if not grey or not box then
        print("GlassCut: elements missing")
        return
    end

    print("GlassCut: ready")

    while glassMyId == _G.GLASS_CUT_INSTANCE do
        while glassMyId == _G.GLASS_CUT_INSTANCE and not cfg.glasscut.enabled do
            task.wait(0.4)
        end
        if glassMyId ~= _G.GLASS_CUT_INSTANCE then return end

        while glassMyId == _G.GLASS_CUT_INSTANCE and cfg.glasscut.enabled and not visible(gui) do
            task.wait(0.2)
        end
        if glassMyId ~= _G.GLASS_CUT_INSTANCE or not cfg.glasscut.enabled then continue end

        print("GlassCut: ACTIVE")
        if notify then notify("Glass Cutting Active", "Autofarms", 2) end

        local started = false
        local moving  = false
        local prevBx, prevBy = nil, nil
        local tEnd = tick()

        while glassMyId == _G.GLASS_CUT_INSTANCE and cfg.glasscut.enabled
            and visible(gui) and tick() - tEnd < 120 do

            local cx, cy, cw, ch = rect(grey)
            local bx, by, bw, bh = rect(box)

            if bx and by and bw and bh then
                local bcx, bcy = bx + bw / 2, by + bh / 2

                if not moving and prevBx and prevBy then
                    local d = math.abs(bx - prevBx) + math.abs(by - prevBy)
                    if d > 1 then
                        moving = true
                        print("GlassCut: box moving, tracking")
                    end
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
                started = true
            end
            task.wait(0.012)
        end

        print("GlassCut:
