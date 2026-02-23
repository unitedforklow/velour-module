-- ============================================================
-- https://raw.githubusercontent.com/unitedforklow/velour-module/refs/heads/main/module.luau
-- ============================================================

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UserInputService= game:GetService("UserInputService")
local Camera          = workspace.CurrentCamera
local LocalPlayer     = Players.LocalPlayer

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
    -- Aimbot
    AimbotEnabled   = false,
    AutoFire        = false,
    VisibleCheck    = true,
    FOVRadius       = 90,
    Smooth          = 6,  -- (from 1 instant to 20 really smooth)

    -- Prediction
    BulletDrop      = false,  -- gravity comps
    PingOffset      = 0,      -- milliseconds
}

-- ════════════════════════════════════════════════════════════
-- ── ESP ────────────────────────────────────────
-- ════════════════════════════════════════════════════════════

local drawings   = {}
local espConn    = nil

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
            d.bar.Visible  = true
            d.bar.Thickness = cfg.BarWidth
            d.bar.From     = Vector2.new(barX, boxBottom)
            d.bar.To       = Vector2.new(barX, boxBottom - boxHeight * ratio)
            d.bar.Color    = Color3.new(1 - ratio, ratio, 0)
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

local legitConn   = nil
local mouseDown   = false

local function getClosestTarget()
    local cfg        = ESP.Config
    local vp         = Camera.ViewportSize
    local screenCenter = Vector2.new(vp.X / 2, vp.Y / 2)

    local bestPlayer  = nil
    local bestDist    = math.huge
    local bestHeadPos = nil

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        local sameTeam = (LocalPlayer.Team ~= nil)
                      and (player.Team == LocalPlayer.Team)
        if sameTeam then continue end

        local char = player.Character
        local head = char and char:FindFirstChild("Head")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")

        if not (head and hum) then continue end
        if hum.Health <= 0    then continue end

        local screenPos, depth, onScreen =
            Camera:WorldToViewportPoint(head.Position)

        if not onScreen or depth <= 0 then continue end

        local screenVec  = Vector2.new(screenPos.X, screenPos.Y)
        local distPixels = (screenVec - screenCenter).Magnitude

        if distPixels > cfg.FOVRadius then continue end

        if cfg.VisibleCheck then
            local origin    = Camera.CFrame.Position
            local direction = head.Position - origin

            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude

            local chars = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character then
                    table.insert(chars, p.Character)
                end
            end
            rayParams.FilterDescendantsInstances = chars

            local result = workspace:Raycast(origin, direction, rayParams)
            if result then continue end
        end

        if distPixels < bestDist then
            bestDist    = distPixels
            bestPlayer  = player
            bestHeadPos = head.Position
        end
    end

    return bestPlayer, bestHeadPos
end

local function smoothAim(targetWorldPos)
    local cfg      = ESP.Config
    local origin   = Camera.CFrame.Position

    -- BulletDrop
    local aimPos = targetWorldPos
    if cfg.BulletDrop then
        local dist   = (targetWorldPos - origin).Magnitude
        local offset = dist * dist * 0.002
        aimPos = targetWorldPos + Vector3.new(0, offset, 0)
    end

    -- PingOffset ms → secs → dots on velocity.
    if cfg.PingOffset > 0 then
        local char     = nil
        local rootPart = nil
        -- rootpart
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character and p.Character:FindFirstChild("Head") then
                local h = p.Character.Head
                if h.Position == targetWorldPos or
                   (h.Position - targetWorldPos).Magnitude < 2 then
                    rootPart = p.Character:FindFirstChild("HumanoidRootPart")
                    break
                end
            end
        end
        if rootPart then
            local pingSeconds = cfg.PingOffset / 1000
            local velocity    = rootPart.AssemblyLinearVelocity
            aimPos = aimPos + velocity * pingSeconds
        end
    end

    local targetCFrame = CFrame.lookAt(origin, aimPos)
    local factor       = math.clamp(1 / cfg.Smooth, 0.05, 1)
    Camera.CFrame      = Camera.CFrame:Lerp(targetCFrame, factor)
end

local function legitimLoop()
    local cfg = ESP.Config
    if not cfg.AimbotEnabled then return end

    local _, headPos = getClosestTarget()
    if not headPos then return end

    smoothAim(headPos)

    if cfg.AutoFire and not mouseDown then
        if mouse1click then
            mouse1click()
        end
    end
end

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        mouseDown = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        mouseDown = false
    end
end)

-- ════════════════════════════════════════════════════════════
-- PUBLIC
-- ════════════════════════════════════════════════════════════

function ESP:Start()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then createDrawings(player) end
    end
    Players.PlayerAdded:Connect(function(p)
        if p ~= LocalPlayer then createDrawings(p) end
    end)
    Players.PlayerRemoving:Connect(removeDrawings)

    -- ESP render
    espConn = RunService.RenderStepped:Connect(render)

    -- Legit engine
    legitConn = RunService.RenderStepped:Connect(legitimLoop)
end

function ESP:Stop()
    if espConn   then espConn:Disconnect();   espConn   = nil end
    if legitConn then legitConn:Disconnect(); legitConn = nil end
    for player in pairs(drawings) do removeDrawings(player) end
end

return ESP
