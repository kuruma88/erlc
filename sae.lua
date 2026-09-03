local genv = (type(getgenv) == "function" and getgenv()) or _G or shared or {}
if type(genv.EggStealerCleanup) == "function" then
    pcall(function() genv.EggStealerCleanup() end)
end

local Connections = {}
local Running = true

genv.EggStealerCleanup = function()
    Running = false
    for _, conn in ipairs(Connections) do
        pcall(function()
            if conn.Disconnect then conn:Disconnect()
            elseif conn.disconnect then conn:disconnect() end
        end)
    end
    Connections = {}
end

local function SafeConnect(obj, signalName, callback)
    if not obj then return end
    pcall(function()
        local sig = obj[signalName]
        if sig then
            local conn = sig:Connect(callback)
            table.insert(Connections, conn)
        end
    end)
end

local function SafeSpawn(fn, ...)
    local args = { ... }
    task.spawn(function()
        pcall(fn, unpack(args))
    end)
end

local NonUI = nil
pcall(function()
    NonUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/neaxusxgod-png/NonUI/main/NonUI.lua"))()
end)

if not NonUI then
    NonUI = genv.NonUI or _G.NonUI or shared.NonUI
end

if not NonUI then
    warn("[EggStealer] NonUI library not found.")
    return
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local CONFIG_PATH = "EggStealer_Config.json"

local SafeZoneCFrame = nil
local SpamCount = 5
local SpamDelay = 0.005
local InstantInteract = false
local EscapeKey = Enum.KeyCode.F

local PromptCache = {}

local function CFrameToTable(cf)
    if not cf then return nil end
    local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
    return { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

local function TableToCFrame(t)
    if type(t) ~= "table" or #t < 12 then return nil end
    return CFrame.new(t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8], t[9], t[10], t[11], t[12])
end

local function SaveConfig()
    local data = {
        SafeZone = CFrameToTable(SafeZoneCFrame),
        EscapeKeyName = EscapeKey and EscapeKey.Name or "F",
        InstantInteract = InstantInteract == true
    }
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not ok or not encoded then return false end
    local wOk = pcall(function()
        writefile(CONFIG_PATH, encoded)
    end)
    return wOk == true
end

local function LoadConfig()
    if not isfile or not isfile(CONFIG_PATH) then return false end
    local ok, raw = pcall(function()
        return readfile(CONFIG_PATH)
    end)
    if not ok or not raw or raw == "" then return false end

    local decodeOk, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not decodeOk or type(data) ~= "table" then return false end

    if data.SafeZone then
        local cf = TableToCFrame(data.SafeZone)
        if cf then SafeZoneCFrame = cf end
    end

    if type(data.EscapeKeyName) == "string" then
        local kc = Enum.KeyCode[data.EscapeKeyName]
        if kc then EscapeKey = kc end
    end

    if data.InstantInteract == true then
        InstantInteract = true
    end

    return true
end

local function TeleportCharacter(cf)
    if not cf then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if hrp then
        hrp.CFrame = cf
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end)
    elseif char:IsA("Model") and char.PrimaryPart then
        char:SetPrimaryPartCFrame(cf)
    end
end

local function Notify(title, text)
    SafeSpawn(function()
        if NonUI and NonUI.Notify then
            NonUI:Notify({ Title = title or "Boss", Content = text or "", Duration = 2.5 })
        end
    end)
end

local function GotoSafeZoneSpam()
    if not SafeZoneCFrame then
        Notify("Warning", "Set Safe Zone first")
        return
    end
    SafeSpawn(function()
        for i = 1, SpamCount do
            TeleportCharacter(SafeZoneCFrame)
            task.wait(SpamDelay)
        end
    end)
    Notify("Safe Zone", "Teleported")
end

local function PatchAllSmartPrompts()
    for _, c in ipairs(Workspace:GetChildren()) do
        if c.Name == "SmartPromptPart" then
            for _, p in ipairs(c:GetChildren()) do
                if p.ClassName == "ProximityPrompt" then
                    if not PromptCache[p] then
                        PromptCache[p] = {
                            HoldDuration = p.HoldDuration,
                            MaxActivationDistance = p.MaxActivationDistance,
                            RequiresLineOfSight = p.RequiresLineOfSight
                        }
                    end

                    local addr = p.Address
                    if addr and type(addr) == "number" and addr > 0x10000 and memory_write then
                        pcall(function()
                            memory_write("float", addr + 0x120, 0.0)
                            memory_write("float", addr + 0x128, 25.0)
                        end)
                    end

                    pcall(function()
                        p.HoldDuration = 0.0
                        p.MaxActivationDistance = 25.0
                        p.RequiresLineOfSight = false
                    end)
                end
            end
        end
    end
end

local function RestoreAllSmartPrompts()
    for p, orig in pairs(PromptCache) do
        if p and p.Parent then
            pcall(function()
                p.HoldDuration = orig.HoldDuration
                p.MaxActivationDistance = orig.MaxActivationDistance
                p.RequiresLineOfSight = orig.RequiresLineOfSight
            end)

            local addr = p.Address
            if addr and type(addr) == "number" and addr > 0x10000 and memory_write then
                pcall(function()
                    memory_write("float", addr + 0x120, orig.HoldDuration or 0.5)
                    memory_write("float", addr + 0x128, orig.MaxActivationDistance or 10)
                end)
            end
        end
    end
    PromptCache = {}
end

LoadConfig()

task.spawn(function()
    while Running do
        if InstantInteract == true then
            PatchAllSmartPrompts()
        end
        task.wait(2.0)
    end
end)

if UserInputService then
    SafeConnect(UserInputService, "InputBegan", function(input, gpe)
        if not gpe and input.KeyCode == EscapeKey then
            GotoSafeZoneSpam()
        end
    end)
end

local Window = NonUI:CreateWindow({
    Title = "Steal an egg",
    Author = "Where is the boss",
    Folder = "",
    Theme = "Dark",
    Size = { 500, 340 },
    OpenButton = { Title = "1", Draggable = true }
})

local MainSection = Window:Section({ Title = "Real or Cake" })
local MainTab = MainSection:Tab({ Title = "Bosses Ignore Player", Icon = "shield" })

MainTab:Button({
    Title = "Set Safe Zone",
    Desc = "Saves your current position as the escape point (kept after rejoin).",
    Icon = "map-pin",
    Callback = function()
        local char = LocalPlayer.Character
        local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
        if hrp then
            SafeZoneCFrame = hrp.CFrame
            SaveConfig()
            Notify("Saved", "Safe zone saved locally")
        else
            Notify("Error", "Character not found.")
        end
    end
})

MainTab:Keybind({
    Title = "Escape",
    Desc = "Teleports you back to the saved safe zone (key is saved).",
    Default = EscapeKey,
    Callback = function(key)
        if typeof(key) == "EnumItem" then
            EscapeKey = key
        elseif type(key) == "string" and Enum.KeyCode[key] then
            EscapeKey = Enum.KeyCode[key]
        end
        SaveConfig()
        GotoSafeZoneSpam()
    end
})

MainTab:Toggle({
    Title = "Instant Interact",
    Desc = "Makes egg prompts instant (no hold) and longer range. Off restores normal prompts.",
    Default = InstantInteract,
    Callback = function(state)
        InstantInteract = (state == true)
        SaveConfig()
        if InstantInteract then
            PatchAllSmartPrompts()
            Notify("Instant Interact", "ON")
        else
            RestoreAllSmartPrompts()
            Notify("Instant Interact", "OFF")
        end
    end
})

MainTab:Button({
    Title = "Re-Patch Prompts",
    Desc = "Force-applies instant interact to all prompts again (only works while Instant Interact is on).",
    Icon = "refresh-cw",
    Callback = function()
        if InstantInteract then
            PatchAllSmartPrompts()
            Notify("Memory", "Prompts patched")
        else
            Notify("Warning", "Turn Instant Interact ON first")
        end
    end
})

if SafeZoneCFrame then
    Notify("Config", "Loaded saved safe zone + keybind")
else
    Notify("Ready", "No saved safe zone yet")
end
