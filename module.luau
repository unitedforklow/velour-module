-- ============================================================
-- https://raw.githubusercontent.com/unitedforklow/velour-module/refs/heads/main/module.luau
-- ============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

local ESP = {}

-- ════════════════════════════════════════════════════════════
-- CONFIG
-- ════════════════════════════════════════════════════════════

ESP.Config = {
    -- ── ESP ─────────────────────────────────────────────────
    Enabled       = true,
    ShowName      = true,
    ShowTeamName  = true,
    ShowDistance  = true,
    ShowHealthBar = true,
    ShowBox       = true,
    TextSize      = 14,
    TextFont      = 2,
    BoxThickness  = 1,
    BoxFilled     = false,
    BarWidth      = 4,
    BarOffsetX    = 5,
    LabelOffsetY  = -4,
    TeamOffsetY   = 2,
    DistOffsetY   = 4,
    MaxRenderDist = 500,

    -- ── LEGIT ────────────────────────────────────────────────
    AimbotEnabled = false,
    FOVEnabled    = false,                     -- show FOV
    FOVRadius     = 90,                        -- radius in pixels
    AutoFire      = false,
    VisibleCheck  = true,
    StickyAim     = false,                     -- hold target not in fov
    Smooth        = 6,                         -- 1 = instant, 20 = smooth

    AimKeybind    = Enum.KeyCode.RightControl, -- activation button
    AimMethod     = "Hold",                    -- "Hold" | "Toggle"
    AimPart       = "Head",                    -- "Head"|"HumanoidRootPart"|"Torso"|"LeftArm"|"RightArm"

    -- Prediction
    BulletDrop    = false,
    PingOffset    = 0,
}

-- ════════════════════════════════════════════════════════════
-- ── ESP ─────────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════

local drawings = {}
local espConn  = nil

local function project(worldPos)
    local s, onScreen = Camera:WorldToViewportPoint(worldPos)
    return Vector2.new(s.X, s.Y), s.Z, onScreen
end

local function getTeamColor(player)
    return player.Team and player.Team.TeamColor.Color or Color3.new(1, 1, 1)
end

local function getTeamName(player)
    return player.Team and player.Team.Name or "Neutral"
end

local function makeText(zindex, size)
    local t        = Drawing.new("Text")
    t.Visible      = false
    t.Font         = ESP.Config.TextFont
    t.Size         = size or ESP.Config.TextSize
    t.Center       = true
    t.Outline      = true
    t.OutlineColor = Color3.new(0, 0, 0)
    t.ZIndex       = zindex
    return t
end

local function createDrawings(player)
    drawings[player] = {
        label     = makeText(5),
        teamLabel = makeText(5, ESP.Config.TextSize - 2),
        distLabel = makeText(5, ESP.Config.TextSize - 2),
        bar = (function()
            local l = Drawing.new("Line")
            l.Visible   = false
            l.Thickness = ESP.Config.BarWidth
            l.ZIndex    = 4
            return l
        end)(),
        box = (function()
            local b = Drawing.new("Square")
            b.Visible   = false
            b.Filled    = ESP.Config.BoxFilled
            b.Thickness = ESP.Config.BoxThickness
            b.ZIndex    = 3
            return b
        end)(),
    }
end

local function removeDrawings(player)
    local d = drawings[player]
    if not d then return end
    for _, obj in pairs(d) do obj:Remove() end
    drawings[player] = nil
end

local function hideAll(d)
    for _, obj in pairs(d) do obj.Visible = false end
end

local function render()
    if not ESP.Config.Enabled then
        for _, d in pairs(drawings) do hideAll(d) end
        return
    end

    local cfg       = ESP.Config
    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local localPos  = localRoot and localRoot.Position

    for player, d in pairs(drawings) do
        local character = player.Character
        local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
        local rootPart  = character and character:FindFirstChild("HumanoidRootPart")
        local head      = character and character:FindFirstChild("Head")

        if not (humanoid and rootPart and head) then hideAll(d); continue end

        local sameTeam = (LocalPlayer.Team ~= nil) and (player.Team == LocalPlayer.Team)
        if sameTeam then hideAll(d); continue end

        local rootPos              = rootPart.Position
        local topScr, depth, onTop = project(rootPos + Vector3.new(0,  3.5, 0))
        local botScr, _,     onBot = project(rootPos + Vector3.new(0, -3.0, 0))

        if not (onTop and onBot) or depth <= 0 or depth > cfg.MaxRenderDist then
            hideAll(d); continue
        end

        local boxTop    = topScr.Y
        local boxBottom = botScr.Y
        local boxHeight = boxBottom - boxTop
        local boxWidth  = boxHeight * 0.65
        local boxLeft   = topScr.X - boxWidth / 2
        local color     = getTeamColor(player)

        if cfg.ShowBox then
            d.box.Visible   = true
            d.box.Position  = Vector2.new(boxLeft, boxTop)
            d.box.Size      = Vector2.new(boxWidth, boxHeight)
            d.box.Color     = color
            d.box.Filled    = cfg.BoxFilled
            d.box.Thickness = cfg.BoxThickness
        else
            d.box.Visible = false
        end

        local namePosY = boxTop - cfg.TextSize + cfg.LabelOffsetY
        if cfg.ShowName then
            d.label.Visible  = true
            d.label.Size     = cfg.TextSize
            d.label.Position = Vector2.new(topScr.X, namePosY)
            d.label.Text     = player.Name
            d.label.Color    = color
        else
            d.label.Visible = false
        end

        if cfg.ShowTeamName then
            d.teamLabel.Visible  = true
            d.teamLabel.Size     = cfg.TextSize - 2
            d.teamLabel.Position = Vector2.new(topScr.X, namePosY + cfg.TextSize + cfg.TeamOffsetY)
            d.teamLabel.Text     = "[" .. getTeamName(player) .. "]"
            d.teamLabel.Color    = color
        else
            d.teamLabel.Visible = false
        end

        if cfg.ShowHealthBar then
            local ratio   = humanoid.MaxHealth > 0
                            and math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) or 0
            local barX    = boxLeft + boxWidth + cfg.BarOffsetX
            d.bar.Visible   = true
            d.bar.Thickness = cfg.BarWidth
            d.bar.From      = Vector2.new(barX, boxBottom)
            d.bar.To        = Vector2.new(barX, boxBottom - boxHeight * ratio)
            d.bar.Color     = Color3.new(1 - ratio, ratio, 0)
        else
            d.bar.Visible = false
        end

        if cfg.ShowDistance and localPos then
            local dist = math.floor((rootPos - localPos).Magnitude)
            d.distLabel.Visible  = true
            d.distLabel.Size     = cfg.TextSize - 2
            d.distLabel.Position = Vector2.new(topScr.X, boxBottom + cfg.DistOffsetY)
            d.distLabel.Text     = dist .. "m"
            d.distLabel.Color    = color
        else
            d.distLabel.Visible = false
        end
    end
end

-- ════════════════════════════════════════════════════════════
-- ── LEGIT ENGINE ─────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════

local legitConn  = nil
local mouseDown  = false

local aimActive     = false   -- активен ли прямо сейчас
local toggleState   = false   -- текущий Toggle-статус
local stickyTarget  = nil     -- залипшая цель (Player)
local stickyPos     = nil     -- последняя позиция залипшей цели

local fovCircle = Drawing.new("Circle")
fovCircle.Visible      = false
fovCircle.Filled       = false
fovCircle.Color        = Color3.fromRGB(255, 255, 255)
fovCircle.Thickness    = 1
fovCircle.Transparency = 0.6
fovCircle.NumSides     = 64
fovCircle.ZIndex       = 10

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end

    -- LMB для AutoFire
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        mouseDown = true
    end

    -- Keybind
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode ~= ESP.Config.AimKeybind then return end
    if not ESP.Config.AimbotEnabled then return end

    if ESP.Config.AimMethod == "Hold" then
        aimActive = true

    elseif ESP.Config.AimMethod == "Toggle" then
        toggleState = not toggleState
        aimActive   = toggleState
        if not aimActive then
            stickyTarget = nil
            stickyPos    = nil
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        mouseDown = false
    end

    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode ~= ESP.Config.AimKeybind then return end

    if ESP.Config.AimMethod == "Hold" then
        aimActive    = false
        stickyTarget = nil
        stickyPos    = nil
    end
end)

local PART_FALLBACKS = {
    Torso    = { "UpperTorso",    "LowerTorso",  "Torso"     },
    LeftArm  = { "LeftUpperArm",  "Left Arm"                 },
    RightArm = { "RightUpperArm", "Right Arm"                },
}

local function getPartPosition(character)
    local partName = ESP.Config.AimPart or "Head"
    local part     = character:FindFirstChild(partName)

    if not part then
        local fallbacks = PART_FALLBACKS[partName]
        if fallbacks then
            for _, name in ipairs(fallbacks) do
                part = character:FindFirstChild(name)
                if part then break end
            end
        end
    end

    if not part then
        part = character:FindFirstChild("HumanoidRootPart")
    end

    return part and part.Position or nil
end

local function getTarget()
    local cfg          = ESP.Config
    local vp           = Camera.ViewportSize
    local screenCenter = Vector2.new(vp.X / 2, vp.Y / 2)

    if cfg.StickyAim and stickyTarget then
        local char    = stickyTarget.Character
        local hum     = char and char:FindFirstChildOfClass("Humanoid")
        local partPos = char and getPartPosition(char)

        if hum and hum.Health > 0 and partPos then
            stickyPos = partPos
            return stickyTarget, partPos
        else
            stickyTarget = nil
            stickyPos    = nil
        end
    end

    local bestPlayer = nil
    local bestDist   = math.huge
    local bestPos    = nil

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        -- Team filter
        if LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team then
            continue
        end

        local char    = player.Character
        local hum     = char and char:FindFirstChildOfClass("Humanoid")
        local partPos = char and getPartPosition(char)

        if not (char and hum and partPos) then continue end
        if hum.Health <= 0              then continue end

        -- Proj
        local sp, depth, onScreen = Camera:WorldToViewportPoint(partPos)
        if not onScreen or depth <= 0 then continue end

        local distPixels = (Vector2.new(sp.X, sp.Y) - screenCenter).Magnitude
        if distPixels > cfg.FOVRadius then continue end

        -- VisibleCheck
        if cfg.VisibleCheck then
            local origin = Camera.CFrame.Position
            local dir    = partPos - origin

            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Exclude
            local chars = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character then table.insert(chars, p.Character) end
            end
            rp.FilterDescendantsInstances = chars

            if workspace:Raycast(origin, dir, rp) then continue end
        end

        if distPixels < bestDist then
            bestDist   = distPixels
            bestPlayer = player
            bestPos    = partPos
        end
    end

    -- StickyAim
    if bestPlayer and cfg.StickyAim then
        stickyTarget = bestPlayer
        stickyPos    = bestPos
    end

    return bestPlayer, bestPos
end

local function smoothAim(targetPos)
    local cfg    = ESP.Config
    local origin = Camera.CFrame.Position
    local aimPos = targetPos

    -- BulletDrop
    if cfg.BulletDrop then
        local dist = (targetPos - origin).Magnitude
        aimPos = targetPos + Vector3.new(0, dist * dist * 0.002, 0)
    end

    -- PingOffset
    if cfg.PingOffset > 0 then
        for _, p in ipairs(Players:GetPlayers()) do
            local char = p.Character
            if not char then continue end
            local part = char:FindFirstChild(cfg.AimPart or "Head")
                      or char:FindFirstChild("HumanoidRootPart")
            if part and (part.Position - targetPos).Magnitude < 3 then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    aimPos = aimPos + root.AssemblyLinearVelocity * (cfg.PingOffset / 1000)
                end
                break
            end
        end
    end

    local factor = math.clamp(1 / cfg.Smooth, 0.05, 1)
    Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(origin, aimPos), factor)
end

local function legitimLoop()
    local cfg = ESP.Config

    -- ── FOV circle ─────────────────────────────────────────
    if cfg.FOVEnabled then
        local vp           = Camera.ViewportSize
        fovCircle.Visible  = true
        fovCircle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
        fovCircle.Radius   = cfg.FOVRadius
        -- Цвет: фиолетовый при активном аиме, белый в покое
        fovCircle.Color        = aimActive
            and Color3.fromRGB(169, 144, 255)
            or  Color3.fromRGB(220, 220, 220)
        fovCircle.Transparency = aimActive and 0.25 or 0.6
    else
        fovCircle.Visible = false
    end

    -- ── Aimbot ─────────────────────────────────────────────
    if not cfg.AimbotEnabled or not aimActive then return end

    local _, partPos = getTarget()
    if not partPos then return end

    smoothAim(partPos)

    if cfg.AutoFire and not mouseDown then
        if mouse1click then mouse1click() end
    end
end

-- ════════════════════════════════════════════════════════════
-- PUBLIC API
-- ════════════════════════════════════════════════════════════

function ESP:Start()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then createDrawings(player) end
    end
    Players.PlayerAdded:Connect(function(p)
        if p ~= LocalPlayer then createDrawings(p) end
    end)
    Players.PlayerRemoving:Connect(removeDrawings)

    espConn   = RunService.RenderStepped:Connect(render)
    legitConn = RunService.RenderStepped:Connect(legitimLoop)
end

function ESP:Stop()
    if espConn   then espConn:Disconnect();   espConn   = nil end
    if legitConn then legitConn:Disconnect(); legitConn = nil end
    for player in pairs(drawings) do removeDrawings(player) end
    fovCircle.Visible = false
end

return ESP
