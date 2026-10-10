-- ╔══════════════════════════════════════════════════════════╗
-- ║         Krovotok | Arsenal Cheat | Injector Build       ║
-- ║     Creator: BoogaJohnyBoy  |  User: @bogteddy          ║
-- ║     Compatible: Synapse X, KRNL, Fluxus, Delta Mobile   ║
-- ╚══════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════
--  SAFE GUI ROOT (injector-safe)
-- ═══════════════════════════════════
local function getSafeGui()
    -- gethui() is the injector-safe hidden UI container
    -- falls back to CoreGui if gethui not available
    if gethui then
        return gethui()
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok then return cg end
    return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

-- destroy previous instance if re-injecting
local prev = getSafeGui():FindFirstChild("KrovotokGUI")
if prev then prev:Destroy() end

-- ═══════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local UIS            = game:GetService("UserInputService")
local Workspace      = game:GetService("Workspace")
local Camera         = Workspace.CurrentCamera
local LocalPlayer    = Players.LocalPlayer

-- ═══════════════════════════════════
--  STATE
-- ═══════════════════════════════════
local S = {
    ESP        = false,
    Chams      = false,
    Rainbow    = false,
    ShowAllies = false,
    Aimbot     = false,
    AimbotFOV  = 120,
    AimbotPart = "Head",
    AimbotWall = false,
    Hitbox     = false,
    HitboxVis  = false,
    HitboxW    = 4,
    HitboxH    = 4,
    FOVCircle  = true,
    FOVSize    = 120,
    FOVColor   = Color3.fromRGB(255,255,255),
    SilentAim  = false,
    AmmoMod    = false,
    RecoilMod  = false,
    RainbowHue = 0,
    Minimized  = false,
}

local ESPObjects  = {}
local ChamsHL     = {}
local HitboxParts = {}
local AmmoConn    = nil
local RecoilConn  = nil
local ActivePanel = "Combat"
local Connections = {}  -- all connections stored for full cleanup

-- ═══════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════
local function trackConn(c)
    table.insert(Connections, c)
    return c
end

local function isEnemy(p)
    if p == LocalPlayer then return false end
    if not S.ShowAllies then
        if p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team then
            return false
        end
    end
    return true
end

local function isAlive(p)
    local c = p.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function w2s(pos)
    local ok, sp = pcall(function()
        return Camera:WorldToViewportPoint(pos)
    end)
    if ok then
        return Vector2.new(sp.X, sp.Y), sp.Z > 0
    end
    return Vector2.new(0, 0), false
end

local function rainbow()
    S.RainbowHue = (S.RainbowHue + 0.004) % 1
    return Color3.fromHSV(S.RainbowHue, 1, 1)
end

local function getESPColor()
    if S.Rainbow then return rainbow() end
    return Color3.fromRGB(0, 120, 255)
end

-- ═══════════════════════════════════
--  DRAWING CHECK
--  (injectors expose Drawing globally)
-- ═══════════════════════════════════
local hasDrawing = (Drawing ~= nil)

local function newDraw(t, props)
    if not hasDrawing then return setmetatable({},{__index=function() return function() end end, __newindex=function() end}) end
    local d = Drawing.new(t)
    for k,v in pairs(props or {}) do
        pcall(function() d[k] = v end)
    end
    return d
end

-- ═══════════════════════════════════
--  ESP
-- ═══════════════════════════════════
local function clearESP()
    for _, t in pairs(ESPObjects) do
        for _, o in pairs(t) do
            pcall(function() o:Remove() end)
        end
    end
    ESPObjects = {}
end

local function makeESPSet()
    local box = newDraw("Square", {
        Filled    = false,
        Color     = Color3.fromRGB(0,120,255),
        Thickness = 1.5,
        Visible   = false,
    })
    local tracer = newDraw("Line", {
        Color     = Color3.fromRGB(0,120,255),
        Thickness = 1,
        Visible   = false,
    })
    local hpBg = newDraw("Square", {
        Filled  = true,
        Color   = Color3.fromRGB(20,20,20),
        Visible = false,
    })
    local hpBar = newDraw("Square", {
        Filled  = true,
        Color   = Color3.fromRGB(0,255,0),
        Visible = false,
    })
    local nameTag = newDraw("Text", {
        Size    = 13,
        Center  = true,
        Outline = true,
        Color   = Color3.fromRGB(255,255,255),
        Visible = false,
    })
    return {box=box, tracer=tracer, hpBg=hpBg, hpBar=hpBar, nameTag=nameTag}
end

local function renderESP()
    -- hide everything first
    for _, t in pairs(ESPObjects) do
        for _, o in pairs(t) do
            pcall(function() o.Visible = false end)
        end
    end

    if not S.ESP then return end

    local vp  = Camera.ViewportSize
    local col = getESPColor()

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not isEnemy(p)   then continue end
        if not isAlive(p)   then continue end

        local char = p.Character
        if not char then continue end

        local root = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then continue end

        -- bounding box corners
        local ok, cf, sz = pcall(function()
            return char:GetBoundingBox()
        end)
        if not ok then continue end

        local hw, hh, hd = sz.X/2, sz.Y/2, sz.Z/2
        local offsets = {
            Vector3.new( hw,  hh,  hd), Vector3.new(-hw,  hh,  hd),
            Vector3.new( hw, -hh,  hd), Vector3.new(-hw, -hh,  hd),
            Vector3.new( hw,  hh, -hd), Vector3.new(-hw,  hh, -hd),
            Vector3.new( hw, -hh, -hd), Vector3.new(-hw, -hh, -hd),
        }

        local minX, minY = math.huge,  math.huge
        local maxX, maxY = -math.huge, -math.huge
        local anyVis = false

        for _, off in ipairs(offsets) do
            local worldPos = cf * CFrame.new(off)
            local sp, vis  = w2s(worldPos.Position)
            if vis then
                anyVis = true
                if sp.X < minX then minX = sp.X end
                if sp.Y < minY then minY = sp.Y end
                if sp.X > maxX then maxX = sp.X end
                if sp.Y > maxY then maxY = sp.Y end
            end
        end

        if not anyVis then continue end

        minX = math.clamp(minX, 0, vp.X)
        minY = math.clamp(minY, 0, vp.Y)
        maxX = math.clamp(maxX, 0, vp.X)
        maxY = math.clamp(maxY, 0, vp.Y)

        local bw = maxX - minX
        local bh = maxY - minY
        if bw < 2 or bh < 2 then continue end

        -- lazy-create drawing objects
        if not ESPObjects[p] then
            ESPObjects[p] = makeESPSet()
        end
        local t = ESPObjects[p]

        -- box
        t.box.Position = Vector2.new(minX, minY)
        t.box.Size     = Vector2.new(bw, bh)
        t.box.Color    = col
        t.box.Visible  = true

        -- tracer from screen bottom-center
        t.tracer.From    = Vector2.new(vp.X/2, vp.Y)
        t.tracer.To      = Vector2.new(minX + bw/2, maxY)
        t.tracer.Color   = col
        t.tracer.Visible = true

        -- hp bar (left side, vertical)
        local hp    = math.clamp(hum.Health, 0, hum.MaxHealth)
        local hpPct = (hum.MaxHealth > 0) and (hp / hum.MaxHealth) or 0
        local barH  = bh * hpPct
        local hpCol = Color3.fromRGB(
            math.floor(255 * (1 - hpPct)),
            math.floor(255 * hpPct),
            0
        )

        t.hpBg.Position = Vector2.new(minX - 6, minY)
        t.hpBg.Size     = Vector2.new(4, bh)
        t.hpBg.Visible  = true

        t.hpBar.Position = Vector2.new(minX - 6, minY + (bh - barH))
        t.hpBar.Size     = Vector2.new(4, barH)
        t.hpBar.Color    = hpCol
        t.hpBar.Visible  = true

        -- name
        t.nameTag.Text     = p.DisplayName
        t.nameTag.Position = Vector2.new(minX + bw/2, minY - 16)
        t.nameTag.Visible  = true
    end
end

-- ═══════════════════════════════════
--  CHAMS (SelectionBox — works in injector)
-- ═══════════════════════════════════
local function clearChams()
    for p, hl in pairs(ChamsHL) do
        pcall(function() hl:Destroy() end)
    end
    ChamsHL = {}
end

local function applyChams()
    clearChams()
    if not S.Chams then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isEnemy(p) and p.Character then
            local hl = Instance.new("SelectionBox")
            hl.Name                = "KrvChams"
            hl.Adornee             = p.Character
            hl.Color3              = Color3.fromRGB(255, 50, 50)
            hl.SurfaceColor3       = Color3.fromRGB(255, 50, 50)
            hl.SurfaceTransparency = 0.45
            hl.LineThickness       = 0.06
            hl.Parent              = Workspace
            ChamsHL[p]             = hl
        end
    end
end

-- ═══════════════════════════════════
--  HITBOX
-- ═══════════════════════════════════
local function clearHitboxes()
    for _, v in pairs(HitboxParts) do
        pcall(function() v:Destroy() end)
    end
    HitboxParts = {}
end

local function applyHitboxes()
    clearHitboxes()
    if not S.Hitbox then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isEnemy(p) and p.Character then
            local char = p.Character
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then continue end
            local hb = Instance.new("Part")
            hb.Name          = "KrvHitbox"
            hb.Size          = Vector3.new(S.HitboxW, S.HitboxH, S.HitboxW)
            hb.Transparency  = S.HitboxVis and 0.4 or 1
            hb.CanCollide    = false
            hb.Anchored      = false
            hb.CastShadow    = false
            hb.Color         = Color3.fromRGB(255, 0, 0)
            hb.Material      = Enum.Material.Neon
            local weld       = Instance.new("WeldConstraint")
            weld.Part0       = hb
            weld.Part1       = root
            weld.Parent      = hb
            hb.Parent        = char
            table.insert(HitboxParts, hb)
        end
    end
end

-- ═══════════════════════════════════
--  FOV CIRCLE
-- ═══════════════════════════════════
local fovCircle = newDraw("Circle", {
    Thickness = 1.5,
    Filled    = false,
    Color     = Color3.fromRGB(255,255,255),
    NumSides  = 64,
    Visible   = false,
})

local function updateFOV()
    local vp = Camera.ViewportSize
    pcall(function()
        fovCircle.Position = Vector2.new(vp.X/2, vp.Y/2)
        fovCircle.Radius   = S.FOVSize
        fovCircle.Color    = S.FOVColor
        fovCircle.Visible  = S.FOVCircle
    end)
end

-- ═══════════════════════════════════
--  AIMBOT
-- ═══════════════════════════════════
local function getAimTarget()
    local vp   = Camera.ViewportSize
    local cx   = vp.X / 2
    local cy   = vp.Y / 2
    local best, bestDist = nil, math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not isEnemy(p)   then continue end
        if not isAlive(p)   then continue end

        local char = p.Character
        if not char then continue end

        local part = char:FindFirstChild(S.AimbotPart)
                  or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end

        -- wall check
        if not S.AimbotWall then
            local origin = Camera.CFrame.Position
            local dir    = (part.Position - origin).Unit * 2000
            local ray    = Ray.new(origin, dir)
            local ignore = {LocalPlayer.Character, Camera}
            local hit    = Workspace:FindPartOnRayWithIgnoreList(ray, ignore)
            if hit and not char:IsAncestorOf(hit) then continue end
        end

        local sp, vis = w2s(part.Position)
        if not vis then continue end

        local dist = (Vector2.new(cx, cy) - sp).Magnitude
        if dist < S.AimbotFOV and dist < bestDist then
            bestDist = dist
            best     = part
        end
    end
    return best
end

local function runAimbot()
    if not S.Aimbot then return end
    local target = getAimTarget()
    if not target then return end
    local dir = (target.Position - Camera.CFrame.Position).Unit
    Camera.CFrame = CFrame.new(Camera.CFrame.Position,
                               Camera.CFrame.Position + dir)
end

-- ═══════════════════════════════════
--  SILENT AIM
-- ═══════════════════════════════════
local OrigSizes = {}

local function applySilentAim()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isEnemy(p) and p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            if root then
                if not OrigSizes[p] then
                    OrigSizes[p] = root.Size
                end
                root.Size = Vector3.new(8, 8, 8)
            end
        end
    end
end

local function revertSilentAim()
    for p, sz in pairs(OrigSizes) do
        if p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            if root then root.Size = sz end
        end
    end
    OrigSizes = {}
end

-- ═══════════════════════════════════
--  AMMO MOD
-- ═══════════════════════════════════
local function startAmmoMod()
    if AmmoConn then AmmoConn:Disconnect() end
    if not S.AmmoMod then return end
    AmmoConn = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                -- direct children
                for _, child in ipairs(tool:GetDescendants()) do
                    local n = child.Name:lower()
                    if child:IsA("IntValue") or child:IsA("NumberValue") then
                        if n == "ammo" or n == "reserve" or n == "mag" or n == "bullets" then
                            child.Value = 999
                        end
                    end
                end
            end
        end
    end)
end

-- ═══════════════════════════════════
--  RECOIL MOD
-- ═══════════════════════════════════
local lastCF = Camera.CFrame

local function startRecoilMod()
    if RecoilConn then RecoilConn:Disconnect() end
    if not S.RecoilMod then return end
    lastCF = Camera.CFrame
    RecoilConn = RunService.RenderStepped:Connect(function()
        if not S.RecoilMod then return end
        local cur    = Camera.CFrame
        local _, ry, _ = cur:ToEulerAnglesYXZ()
        local ox, _, oz = lastCF:ToEulerAnglesXYZ()
        Camera.CFrame = CFrame.fromEulerAnglesYXZ(ox, ry, oz)
                      + cur.Position
                      - CFrame.fromEulerAnglesYXZ(ox, ry, oz).Position
        lastCF = Camera.CFrame
    end)
end

-- ═══════════════════════════════════
--  TEAM CHANGE / RESPAWN TRACKING
-- ═══════════════════════════════════
local function onCharAdded()
    task.wait(1)
    clearESP()
    if S.Chams  then applyChams()    end
    if S.Hitbox then applyHitboxes() end
end

trackConn(LocalPlayer.CharacterAdded:Connect(onCharAdded))

for _, p in ipairs(Players:GetPlayers()) do
    trackConn(p.CharacterAdded:Connect(onCharAdded))
end
trackConn(Players.PlayerAdded:Connect(function(p)
    trackConn(p.CharacterAdded:Connect(onCharAdded))
end))
trackConn(Players.PlayerRemoving:Connect(function(p)
    if ESPObjects[p] then
        for _, o in pairs(ESPObjects[p]) do
            pcall(function() o:Remove() end)
        end
        ESPObjects[p] = nil
    end
    if ChamsHL[p] then
        pcall(function() ChamsHL[p]:Destroy() end)
        ChamsHL[p] = nil
    end
end))

-- ═══════════════════════════════════════════════════════
--  GUI
-- ═══════════════════════════════════════════════════════
local SafeParent  = getSafeGui()

local BG_DARK  = Color3.fromRGB(8,  10, 22)
local BG_MID   = Color3.fromRGB(14, 18, 40)
local ACCENT   = Color3.fromRGB(0,  110, 255)
local ACCENT2  = Color3.fromRGB(0,  55,  170)
local WHITE    = Color3.fromRGB(255,255,255)
local GREY     = Color3.fromRGB(90, 100, 130)
local RED_COL  = Color3.fromRGB(200,35, 35)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name              = "KrovotokGUI"
ScreenGui.ResetOnSpawn      = false
ScreenGui.IgnoreGuiInset    = true
ScreenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent            = SafeParent

-- ─────────────────────────────────────────────────────
--  FLOATING BALL
-- ─────────────────────────────────────────────────────
local Ball = Instance.new("ImageButton")
Ball.Name            = "KrvBall"
Ball.Size            = UDim2.new(0, 80, 0, 80)
Ball.Position        = UDim2.new(0.5, -40, 0.8, -40)
Ball.BackgroundColor3= WHITE
Ball.BorderSizePixel = 0
Ball.Visible         = false
Ball.ZIndex          = 20
Ball.Parent          = ScreenGui

Instance.new("UICorner", Ball).CornerRadius = UDim.new(1, 0)

local BallShadow = Instance.new("UIStroke")
BallShadow.Color     = ACCENT
BallShadow.Thickness = 2
BallShadow.Parent    = Ball

local BallLabel = Instance.new("TextLabel")
BallLabel.Size               = UDim2.new(1, 0, 1, 0)
BallLabel.BackgroundTransparency = 1
BallLabel.Text               = "Krovotok"
BallLabel.TextColor3         = Color3.fromRGB(0, 0, 0)
BallLabel.TextScaled         = true
BallLabel.Font               = Enum.Font.GothamBold
BallLabel.ZIndex             = 21
BallLabel.Parent             = Ball

-- drag ball — touch
do
    local dragging   = false
    local dragTouchId= nil
    local dragStart  = Vector2.new()
    local startPos   = UDim2.new()

    Ball.TouchStarted:Connect(function(touch, _)
        if dragging then return end
        dragging    = true
        dragTouchId = touch.TouchId
        dragStart   = Vector2.new(touch.Position.X, touch.Position.Y)
        startPos    = Ball.Position
    end)
    Ball.TouchMoved:Connect(function(touch, _)
        if not dragging then return end
        local delta = Vector2.new(touch.Position.X, touch.Position.Y) - dragStart
        Ball.Position = UDim2.new(
            startPos.X.Scale,  startPos.X.Offset + delta.X,
            startPos.Y.Scale,  startPos.Y.Offset + delta.Y
        )
    end)
    Ball.TouchEnded:Connect(function(_, _)
        dragging = false
    end)
end

-- ─────────────────────────────────────────────────────
--  MAIN WINDOW — 35% wide, centered
-- ─────────────────────────────────────────────────────
local Win = Instance.new("Frame")
Win.Name              = "MainWin"
Win.AnchorPoint       = Vector2.new(0.5, 0.5)
Win.Size              = UDim2.new(0.35, 0, 0.72, 0)
Win.Position          = UDim2.new(0.5,  0, 0.5,  0)
Win.BackgroundColor3  = BG_DARK
Win.BorderSizePixel   = 0
Win.ClipsDescendants  = true
Win.ZIndex            = 2
Win.Parent            = ScreenGui

Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 10)

local WinStroke = Instance.new("UIStroke")
WinStroke.Color     = ACCENT2
WinStroke.Thickness = 1
WinStroke.Parent    = Win

-- ─────────────────────────────────────────────────────
--  TITLE BAR
-- ─────────────────────────────────────────────────────
local TBar = Instance.new("Frame")
TBar.Size             = UDim2.new(1, 0, 0, 40)
TBar.BackgroundColor3 = BG_MID
TBar.BorderSizePixel  = 0
TBar.ZIndex           = 3
TBar.Parent           = Win

Instance.new("UICorner", TBar).CornerRadius = UDim.new(0, 10)

-- patch bottom corners of title bar
local TBarPatch = Instance.new("Frame")
TBarPatch.Size             = UDim2.new(1, 0, 0, 10)
TBarPatch.Position         = UDim2.new(0, 0, 1, -10)
TBarPatch.BackgroundColor3 = BG_MID
TBarPatch.BorderSizePixel  = 0
TBarPatch.ZIndex           = 3
TBarPatch.Parent           = TBar

local TTitle = Instance.new("TextLabel")
TTitle.Size              = UDim2.new(1, -90, 1, 0)
TTitle.Position          = UDim2.new(0, 10, 0, 0)
TTitle.BackgroundTransparency = 1
TTitle.Text              = "KROVOTOK"
TTitle.TextColor3        = WHITE
TTitle.Font              = Enum.Font.GothamBold
TTitle.TextSize          = 14
TTitle.TextXAlignment    = Enum.TextXAlignment.Left
TTitle.ZIndex            = 4
TTitle.Parent            = TBar

local function makeTitleBtn(xOffset, bgColor, label, fontSize)
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, 28, 0, 28)
    btn.Position         = UDim2.new(1, xOffset, 0, 6)
    btn.BackgroundColor3 = bgColor
    btn.Text             = label
    btn.TextColor3       = WHITE
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = fontSize or 14
    btn.BorderSizePixel  = 0
    btn.ZIndex           = 4
    btn.Parent           = TBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local BtnClose = makeTitleBtn(-32, RED_COL,  "✕", 13)
local BtnMin   = makeTitleBtn(-64, ACCENT2,  "−", 18)

-- ─────────────────────────────────────────────────────
--  CONFIRM POPUP
-- ─────────────────────────────────────────────────────
local Popup = Instance.new("Frame")
Popup.Name            = "KrvPopup"
Popup.AnchorPoint     = Vector2.new(0.5, 0.5)
Popup.Size            = UDim2.new(0.6, 0, 0, 120)
Popup.Position        = UDim2.new(0.5, 0, 0.5, 0)
Popup.BackgroundColor3= BG_MID
Popup.BorderSizePixel = 0
Popup.Visible         = false
Popup.ZIndex          = 50
Popup.Parent          = ScreenGui

Instance.new("UICorner", Popup).CornerRadius = UDim.new(0, 12)

local PopupStroke = Instance.new("UIStroke")
PopupStroke.Color     = RED_COL
PopupStroke.Thickness = 1.5
PopupStroke.Parent    = Popup

local PopupText = Instance.new("TextLabel")
PopupText.Size              = UDim2.new(1, -16, 0, 56)
PopupText.Position          = UDim2.new(0, 8, 0, 8)
PopupText.BackgroundTransparency = 1
PopupText.Text              = "Вы уверены, что хотите\nзакрыть чит полностью?"
PopupText.TextColor3        = WHITE
PopupText.Font              = Enum.Font.Gotham
PopupText.TextSize          = 13
PopupText.TextWrapped        = true
PopupText.TextYAlignment    = Enum.TextYAlignment.Center
PopupText.ZIndex            = 51
PopupText.Parent            = Popup

local PopupNo = Instance.new("TextButton")
PopupNo.Size             = UDim2.new(0.44, 0, 0, 30)
PopupNo.Position         = UDim2.new(0.03, 0, 1, -38)
PopupNo.BackgroundColor3 = ACCENT2
PopupNo.Text             = "Отмена"
PopupNo.TextColor3       = WHITE
PopupNo.Font             = Enum.Font.GothamBold
PopupNo.TextSize         = 12
PopupNo.BorderSizePixel  = 0
PopupNo.ZIndex           = 51
PopupNo.Parent           = Popup
Instance.new("UICorner", PopupNo).CornerRadius = UDim.new(0, 6)

local PopupYes = Instance.new("TextButton")
PopupYes.Size             = UDim2.new(0.44, 0, 0, 30)
PopupYes.Position         = UDim2.new(0.52, 0, 1, -38)
PopupYes.BackgroundColor3 = RED_COL
PopupYes.Text             = "Да, закрыть"
PopupYes.TextColor3       = WHITE
PopupYes.Font             = Enum.Font.GothamBold
PopupYes.TextSize         = 12
PopupYes.BorderSizePixel  = 0
PopupYes.ZIndex           = 51
PopupYes.Parent           = Popup
Instance.new("UICorner", PopupYes).CornerRadius = UDim.new(0, 6)

-- ─────────────────────────────────────────────────────
--  BODY
-- ─────────────────────────────────────────────────────
local Body = Instance.new("Frame")
Body.Size                = UDim2.new(1, 0, 1, -40)
Body.Position            = UDim2.new(0, 0, 0, 40)
Body.BackgroundTransparency = 1
Body.ZIndex              = 3
Body.Parent              = Win

-- LEFT PANEL
local Left = Instance.new("Frame")
Left.Size             = UDim2.new(0.37, 0, 1, 0)
Left.BackgroundColor3 = BG_MID
Left.BorderSizePixel  = 0
Left.ZIndex           = 3
Left.Parent           = Body

-- ─── BACON NOOB ───
local BaconRoot = Instance.new("Frame")
BaconRoot.Size             = UDim2.new(0.78, 0, 0, 72)
BaconRoot.Position         = UDim2.new(0.11, 0, 0, 6)
BaconRoot.BackgroundTransparency = 1
BaconRoot.ZIndex           = 4
BaconRoot.Parent           = Left

-- head
local BHead = Instance.new("Frame")
BHead.Size             = UDim2.new(0.55, 0, 0.38, 0)
BHead.Position         = UDim2.new(0.22, 0, 0.02, 0)
BHead.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
BHead.BorderSizePixel  = 0
BHead.ZIndex           = 5
BHead.Parent           = BaconRoot

-- hair stripe
local BHair = Instance.new("Frame")
BHair.Size             = UDim2.new(0.65, 0, 0.2, 0)
BHair.Position         = UDim2.new(0.175, 0, -0.12, 0)
BHair.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
BHair.BorderSizePixel  = 0
BHair.ZIndex           = 6
BHair.Parent           = BHead
Instance.new("UICorner", BHair).CornerRadius = UDim.new(0, 3)

-- eyes
for _, xPct in ipairs({0.18, 0.60}) do
    local eye = Instance.new("Frame")
    eye.Size             = UDim2.new(0.16, 0, 0.18, 0)
    eye.Position         = UDim2.new(xPct, 0, 0.35, 0)
    eye.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    eye.BorderSizePixel  = 0
    eye.ZIndex           = 7
    eye.Parent           = BHead
end

-- smile
local BSmile = Instance.new("Frame")
BSmile.Size             = UDim2.new(0.48, 0, 0.08, 0)
BSmile.Position         = UDim2.new(0.26, 0, 0.66, 0)
BSmile.BackgroundColor3 = Color3.fromRGB(160, 70, 0)
BSmile.BorderSizePixel  = 0
BSmile.ZIndex           = 7
BSmile.Parent           = BHead

-- body
local BBody = Instance.new("Frame")
BBody.Size             = UDim2.new(0.48, 0, 0.42, 0)
BBody.Position         = UDim2.new(0.26, 0, 0.42, 0)
BBody.BackgroundColor3 = Color3.fromRGB(0, 100, 255)
BBody.BorderSizePixel  = 0
BBody.ZIndex           = 5
BBody.Parent           = BaconRoot

-- legs
for _, xPct in ipairs({0.24, 0.52}) do
    local leg = Instance.new("Frame")
    leg.Size             = UDim2.new(0.22, 0, 0.22, 0)
    leg.Position         = UDim2.new(xPct, 0, 0.82, 0)
    leg.BackgroundColor3 = Color3.fromRGB(40, 40, 120)
    leg.BorderSizePixel  = 0
    leg.ZIndex           = 5
    leg.Parent           = BaconRoot
end

-- arms
for _, xPct in ipairs({0.04, 0.72}) do
    local arm = Instance.new("Frame")
    arm.Size             = UDim2.new(0.18, 0, 0.32, 0)
    arm.Position         = UDim2.new(xPct, 0, 0.44, 0)
    arm.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
    arm.BorderSizePixel  = 0
    arm.ZIndex           = 5
    arm.Parent           = BaconRoot
end

-- username label
local UserLbl = Instance.new("TextLabel")
UserLbl.Size              = UDim2.new(1, 0, 0, 16)
UserLbl.Position          = UDim2.new(0, 0, 0, 80)
UserLbl.BackgroundTransparency = 1
UserLbl.Text              = "@bogteddy"
UserLbl.TextColor3        = GREY
UserLbl.Font              = Enum.Font.Gotham
UserLbl.TextSize          = 9
UserLbl.ZIndex            = 4
UserLbl.Parent            = Left

-- divider
local Div = Instance.new("Frame")
Div.Size             = UDim2.new(0.86, 0, 0, 1)
Div.Position         = UDim2.new(0.07, 0, 0, 100)
Div.BackgroundColor3 = ACCENT2
Div.BorderSizePixel  = 0
Div.ZIndex           = 4
Div.Parent           = Left

-- NAV SCROLL
local NavScroll = Instance.new("ScrollingFrame")
NavScroll.Size                = UDim2.new(1, 0, 1, -104)
NavScroll.Position            = UDim2.new(0, 0, 0, 104)
NavScroll.BackgroundTransparency = 1
NavScroll.ScrollBarThickness  = 0
NavScroll.CanvasSize          = UDim2.new(0, 0, 0, 0)
NavScroll.ZIndex              = 4
NavScroll.Parent              = Left

local NavList = Instance.new("UIListLayout")
NavList.Padding             = UDim.new(0, 3)
NavList.FillDirection       = Enum.FillDirection.Vertical
NavList.HorizontalAlignment = Enum.HorizontalAlignment.Center
NavList.Parent              = NavScroll

NavList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    NavScroll.CanvasSize = UDim2.new(0, 0, 0, NavList.AbsoluteContentSize.Y + 6)
end)

local NavDefs = {
    { key="Combat",   icon="⚔",  label="Combat"   },
    { key="ESP",      icon="👁",  label="ESP"      },
    { key="Aimbot",   icon="🎯",  label="Aimbot"   },
    { key="Hitbox",   icon="📦",  label="Hitbox"   },
    { key="FOV",      icon="🔵",  label="FOV"      },
    { key="Settings", icon="⚙",  label="Settings" },
}

local NavBtns = {}
for _, nd in ipairs(NavDefs) do
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0.92, 0, 0, 34)
    btn.BackgroundColor3 = BG_DARK
    btn.Text             = nd.icon .. "  " .. nd.label
    btn.TextColor3       = WHITE
    btn.Font             = Enum.Font.Gotham
    btn.TextSize         = 11
    btn.TextXAlignment   = Enum.TextXAlignment.Left
    btn.BorderSizePixel  = 0
    btn.ZIndex           = 5
    btn.Parent           = NavScroll
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.Parent = btn
    NavBtns[nd.key] = btn
end

-- RIGHT PANEL
local Right = Instance.new("ScrollingFrame")
Right.Size                = UDim2.new(0.63, 0, 1, 0)
Right.Position            = UDim2.new(0.37, 0, 0, 0)
Right.BackgroundColor3    = BG_DARK
Right.BorderSizePixel     = 0
Right.ScrollBarThickness  = 2
Right.ScrollBarImageColor3= ACCENT
Right.CanvasSize          = UDim2.new(0, 0, 0, 0)
Right.ZIndex              = 3
Right.Parent              = Body

local RightList = Instance.new("UIListLayout")
RightList.Padding             = UDim.new(0, 4)
RightList.FillDirection       = Enum.FillDirection.Vertical
RightList.HorizontalAlignment = Enum.HorizontalAlignment.Center
RightList.Parent              = Right

RightList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Right.CanvasSize = UDim2.new(0, 0, 0, RightList.AbsoluteContentSize.Y + 10)
end)

-- ═══════════════════════════════════
--  WIDGET FACTORIES
-- ═══════════════════════════════════
local PanelWidgets = {}

local function clearRight()
    for _, w in ipairs(PanelWidgets) do
        pcall(function() w:Destroy() end)
    end
    PanelWidgets = {}
end

local function pw(w)
    table.insert(PanelWidgets, w)
    return w
end

local function mkSection(txt)
    local l = Instance.new("TextLabel")
    l.Size              = UDim2.new(0.9, 0, 0, 22)
    l.BackgroundTransparency = 1
    l.Text              = txt
    l.TextColor3        = ACCENT
    l.Font              = Enum.Font.GothamBold
    l.TextSize          = 11
    l.TextXAlignment    = Enum.TextXAlignment.Left
    l.ZIndex            = 4
    l.Parent            = Right
    return pw(l)
end

local function mkSpacer(h)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(0.9, 0, 0, h or 5)
    f.BackgroundTransparency = 1
    f.ZIndex           = 4
    f.Parent           = Right
    return pw(f)
end

local function mkNote(txt)
    local l = Instance.new("TextLabel")
    l.Size              = UDim2.new(0.9, 0, 0, 16)
    l.BackgroundTransparency = 1
    l.Text              = txt
    l.TextColor3        = GREY
    l.Font              = Enum.Font.Gotham
    l.TextSize          = 9
    l.TextXAlignment    = Enum.TextXAlignment.Left
    l.ZIndex            = 4
    l.Parent            = Right
    return pw(l)
end

local function mkToggle(label, key, cb)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(0.92, 0, 0, 33)
    row.BackgroundColor3 = BG_MID
    row.BorderSizePixel  = 0
    row.ZIndex           = 4
    row.Parent           = Right
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    pw(row)

    local lbl = Instance.new("TextLabel")
    lbl.Size              = UDim2.new(0.68, 0, 1, 0)
    lbl.Position          = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text              = label
    lbl.TextColor3        = WHITE
    lbl.Font              = Enum.Font.Gotham
    lbl.TextSize          = 11
    lbl.TextXAlignment    = Enum.TextXAlignment.Left
    lbl.ZIndex            = 5
    lbl.Parent            = row

    local tbg = Instance.new("Frame")
    tbg.Size             = UDim2.new(0, 36, 0, 18)
    tbg.Position         = UDim2.new(1, -44, 0.5, -9)
    tbg.BackgroundColor3 = GREY
    tbg.BorderSizePixel  = 0
    tbg.ZIndex           = 5
    tbg.Parent           = row
    Instance.new("UICorner", tbg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.new(0, 14, 0, 14)
    knob.Position         = UDim2.new(0, 2, 0, 2)
    knob.BackgroundColor3 = WHITE
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 6
    knob.Parent           = tbg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local hit = Instance.new("TextButton")
    hit.Size               = UDim2.new(1, 0, 1, 0)
    hit.BackgroundTransparency = 1
    hit.Text               = ""
    hit.ZIndex             = 7
    hit.Parent             = row

    local function refresh()
        local on = S[key]
        TweenService:Create(tbg,  TweenInfo.new(0.13), {BackgroundColor3 = on and ACCENT or GREY}):Play()
        TweenService:Create(knob, TweenInfo.new(0.13), {Position = on and UDim2.new(0,20,0,2) or UDim2.new(0,2,0,2)}):Play()
    end

    local function toggle()
        S[key] = not S[key]
        refresh()
        if cb then cb(S[key]) end
    end

    hit.MouseButton1Click:Connect(toggle)
    hit.TouchTap:Connect(toggle)
    refresh()
    return row
end

local function mkSlider(label, key, mn, mx, step, cb)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(0.92, 0, 0, 48)
    row.BackgroundColor3 = BG_MID
    row.BorderSizePixel  = 0
    row.ZIndex           = 4
    row.Parent           = Right
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    pw(row)

    local lbl = Instance.new("TextLabel")
    lbl.Size              = UDim2.new(0.62, 0, 0, 20)
    lbl.Position          = UDim2.new(0, 8, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text              = label
    lbl.TextColor3        = WHITE
    lbl.Font              = Enum.Font.Gotham
    lbl.TextSize          = 10
    lbl.TextXAlignment    = Enum.TextXAlignment.Left
    lbl.ZIndex            = 5
    lbl.Parent            = row

    local valL = Instance.new("TextLabel")
    valL.Size              = UDim2.new(0.3, 0, 0, 20)
    valL.Position          = UDim2.new(0.68, 0, 0, 4)
    valL.BackgroundTransparency = 1
    valL.Text              = tostring(S[key])
    valL.TextColor3        = ACCENT
    valL.Font              = Enum.Font.GothamBold
    valL.TextSize          = 10
    valL.TextXAlignment    = Enum.TextXAlignment.Right
    valL.ZIndex            = 5
    valL.Parent            = row

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1, -16, 0, 5)
    track.Position         = UDim2.new(0, 8, 0, 32)
    track.BackgroundColor3 = GREY
    track.BorderSizePixel  = 0
    track.ZIndex           = 5
    track.Parent           = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = ACCENT
    fill.BorderSizePixel  = 0
    fill.ZIndex           = 6
    fill.Parent           = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local handle = Instance.new("Frame")
    handle.Size             = UDim2.new(0, 13, 0, 13)
    handle.AnchorPoint      = Vector2.new(0.5, 0.5)
    handle.Position         = UDim2.new(0, 0, 0.5, 0)
    handle.BackgroundColor3 = WHITE
    handle.BorderSizePixel  = 0
    handle.ZIndex           = 7
    handle.Parent           = track
    Instance.new("UICorner", handle).CornerRadius = UDim.new(1, 0)

    local function setPct(pct)
        pct = math.clamp(pct, 0, 1)
        local raw = mn + (mx - mn) * pct
        local val = math.floor(raw / step + 0.5) * step
        val = math.clamp(val, mn, mx)
        S[key]      = val
        valL.Text   = tostring(val)
        fill.Size   = UDim2.new(pct, 0, 1, 0)
        handle.Position = UDim2.new(pct, 0, 0.5, 0)
        if cb then cb(val) end
    end

    setPct((S[key] - mn) / (mx - mn))

    local dragging = false
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.Touch then
            local abs = track.AbsolutePosition
            local w   = track.AbsoluteSize.X
            setPct((inp.Position.X - abs.X) / w)
        end
    end)

    return row
end

local function mkPartBtn(label, key, val, refresh)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(0.92, 0, 0, 28)
    row.BackgroundColor3 = (S[key] == val) and ACCENT or BG_MID
    row.BorderSizePixel  = 0
    row.ZIndex           = 4
    row.Parent           = Right
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    pw(row)

    local lbl = Instance.new("TextLabel")
    lbl.Size              = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text              = label
    lbl.TextColor3        = WHITE
    lbl.Font              = Enum.Font.Gotham
    lbl.TextSize          = 11
    lbl.ZIndex            = 5
    lbl.Parent            = row

    local btn = Instance.new("TextButton")
    btn.Size               = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text               = ""
    btn.ZIndex             = 6
    btn.Parent             = row

    local function act()
        S[key] = val
        refresh()
    end
    btn.MouseButton1Click:Connect(act)
    btn.TouchTap:Connect(act)
    return row
end

-- ═══════════════════════════════════
--  PANEL BUILDER
-- ═══════════════════════════════════
local function buildPanel(key)
    clearRight()
    ActivePanel = key

    for k, b in pairs(NavBtns) do
        b.BackgroundColor3 = (k == key) and ACCENT or BG_DARK
    end

    if key == "Combat" then
        mkSection("  COMBAT")
        mkSpacer()
        mkToggle("⬜  Silent Aim",  "SilentAim", nil)
        mkToggle("⬜  Ammo Mod",    "AmmoMod",   function() startAmmoMod()   end)
        mkToggle("⬜  Recoil Mod",  "RecoilMod", function() startRecoilMod() end)
        mkSpacer(8)
        mkNote("  BoogaJohnyBoy  |  @bogteddy")

    elseif key == "ESP" then
        mkSection("  ESP")
        mkSpacer()
        mkToggle("⬜  Box ESP",      "ESP",       nil)
        mkToggle("⬜  Chams",        "Chams",     function() applyChams() end)
        mkToggle("⬜  Rainbow",      "Rainbow",   nil)
        mkToggle("⬜  Show Allies",  "ShowAllies",nil)
        mkSpacer(6)
        mkNote("  Boxes · tracers · HP bar · names")
        mkNote("  Chams = highlight through walls")
        mkNote("  Rainbow = cycles color per frame")

    elseif key == "Aimbot" then
        mkSection("  AIMBOT")
        mkSpacer()
        mkToggle("⬜  Aimbot",         "Aimbot",    nil)
        mkToggle("⬜  Through Walls",  "AimbotWall",nil)
        mkSlider("FOV Radius", "AimbotFOV", 20, 400, 5, nil)
        mkSpacer(6)
        mkSection("  TARGET PART")
        local parts = {
            {"Head",            "Head"},
            {"Upper Torso",     "UpperTorso"},
            {"Lower Torso",     "LowerTorso"},
            {"Root (center)",   "HumanoidRootPart"},
        }
        for _, pd in ipairs(parts) do
            mkPartBtn(pd[1], "AimbotPart", pd[2], function()
                buildPanel("Aimbot")
            end)
        end

    elseif key == "Hitbox" then
        mkSection("  HITBOX")
        mkSpacer()
        mkToggle("⬜  Expand Hitboxes", "Hitbox",    function() applyHitboxes() end)
        mkToggle("⬜  Show Hitboxes",   "HitboxVis", function() applyHitboxes() end)
        mkSlider("Width",  "HitboxW", 1, 20, 0.5, function() applyHitboxes() end)
        mkSlider("Height", "HitboxH", 1, 20, 0.5, function() applyHitboxes() end)
        mkSpacer(6)
        mkNote("  Expanded boxes = easier to hit")
        mkNote("  Red glow when Show is on")

    elseif key == "FOV" then
        mkSection("  FOV CIRCLE")
        mkSpacer()
        mkToggle("⬜  Show FOV",  "FOVCircle", function() updateFOV() end)
        mkSlider("Radius", "FOVSize", 20, 400, 5, function() updateFOV() end)
        mkSpacer(6)
        mkNote("  Circle always at screen center")
        mkNote("  Aimbot only locks inside FOV")
        mkNote("  High aim = head | Mid = body | Low = legs")

    elseif key == "Settings" then
        mkSection("  SETTINGS")
        mkSpacer()
        mkSlider("FOV Size",      "FOVSize",   20, 400, 5,   function() updateFOV() end)
        mkSlider("Aimbot FOV",    "AimbotFOV", 20, 400, 5,   nil)
        mkSlider("Hitbox Width",  "HitboxW",   1,  20,  0.5, function() applyHitboxes() end)
        mkSlider("Hitbox Height", "HitboxH",   1,  20,  0.5, function() applyHitboxes() end)
        mkSpacer(8)
        mkNote("  Krovotok v1.0")
        mkNote("  Creator: BoogaJohnyBoy")
        mkNote("  User: @bogteddy")
    end
end

-- wire nav
for _, nd in ipairs(NavDefs) do
    local k   = nd.key
    local btn = NavBtns[k]
    btn.MouseButton1Click:Connect(function() buildPanel(k) end)
    btn.TouchTap:Connect(function()          buildPanel(k) end)
end

buildPanel("Combat")

-- ═══════════════════════════════════
--  CLOSE / MINIMIZE
-- ═══════════════════════════════════
local function shutdownAll()
    -- disable everything
    S.ESP = false; S.Chams = false; S.Aimbot = false
    S.Hitbox = false; S.SilentAim = false
    S.AmmoMod = false; S.RecoilMod = false
    S.FOVCircle = false

    clearESP()
    clearChams()
    clearHitboxes()
    revertSilentAim()

    if AmmoConn   then AmmoConn:Disconnect()   end
    if RecoilConn then RecoilConn:Disconnect() end
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end

    pcall(function() fovCircle:Remove() end)
    pcall(function() ScreenGui:Destroy() end)
end

local function connectBtn(btn, fn)
    btn.MouseButton1Click:Connect(fn)
    btn.TouchTap:Connect(fn)
end

connectBtn(BtnClose, function() Popup.Visible = true end)
connectBtn(PopupNo,  function() Popup.Visible = false end)
connectBtn(PopupYes, shutdownAll)

connectBtn(BtnMin, function()
    Win.Visible  = false
    Ball.Visible = true
end)
connectBtn(Ball, function()
    Ball.Visible = false
    Win.Visible  = true
end)

-- ═══════════════════════════════════
--  MAIN RENDER LOOP
-- ═══════════════════════════════════
trackConn(RunService.RenderStepped:Connect(function()
    renderESP()
    runAimbot()
    updateFOV()

    if S.SilentAim then applySilentAim() end

    -- rainbow chams live update
    if S.Chams and S.Rainbow then
        local c = rainbow()
        for _, hl in pairs(ChamsHL) do
            pcall(function()
                hl.Color3        = c
                hl.SurfaceColor3 = c
            end)
        end
    end

    -- auto-reapply chams if new enemy char appeared without HL
    if S.Chams then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and isEnemy(p) and p.Character and not ChamsHL[p] then
                applyChams()
                break
            end
        end
    end
end))

print("[Krovotok] injected — BoogaJohnyBoy | @bogteddy")
