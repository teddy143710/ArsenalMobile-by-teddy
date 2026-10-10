-- ╔══════════════════════════════════════════════════════════╗
-- ║         Krovotok | Arsenal | Mobile Executor Build      ║
-- ║     Creator: BoogaJohnyBoy  |  User: @bogteddy          ║
-- ╚══════════════════════════════════════════════════════════╝

-- SAFE START
local ok, err = pcall(function()

-- ═══════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local Camera       = workspace.CurrentCamera
local LP           = Players.LocalPlayer

-- ═══════════════════════════════════
--  SAFE GUI PARENT
-- ═══════════════════════════════════
local function getParent()
    if typeof(gethui) == "function" then
        return gethui()
    end
    local s, r = pcall(function() return game:GetService("CoreGui") end)
    if s then return r end
    return LP:WaitForChild("PlayerGui")
end

local SafeParent = getParent()

-- destroy old instance on re-inject
local old = SafeParent:FindFirstChild("KrovotokGUI")
if old then old:Destroy() end

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
    SilentAim  = false,
    AmmoMod    = false,
    RecoilMod  = false,
    RainbowHue = 0,
}

local ESPObjects  = {}
local ChamsHL     = {}
local HitboxParts = {}
local Connections = {}
local AmmoConn    = nil
local RecoilConn  = nil
local ActivePanel = "Combat"

-- ═══════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════
local function tc(c) table.insert(Connections, c) return c end

local function isEnemy(p)
    if p == LP then return false end
    if not S.ShowAllies then
        if p.Team and LP.Team and p.Team == LP.Team then
            return false
        end
    end
    return true
end

local function isAlive(p)
    local c = p.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h ~= nil and h.Health > 0
end

local function w2s(pos)
    local s2, sp = pcall(function()
        return Camera:WorldToViewportPoint(pos)
    end)
    if s2 then
        return Vector2.new(sp.X, sp.Y), sp.Z > 0
    end
    return Vector2.new(0,0), false
end

local function getRainbow()
    S.RainbowHue = (S.RainbowHue + 0.004) % 1
    return Color3.fromHSV(S.RainbowHue, 1, 1)
end

local function espColor()
    if S.Rainbow then return getRainbow() end
    return Color3.fromRGB(0, 120, 255)
end

-- ═══════════════════════════════════
--  DRAWING WRAPPER
-- ═══════════════════════════════════
local hasDrawing = (typeof(Drawing) == "table" or typeof(Drawing) == "userdata")

local Dummy = {}
Dummy.__index = function() return function() end end
Dummy.__newindex = function() end

local function newDraw(t, props)
    if not hasDrawing then
        return setmetatable({}, Dummy)
    end
    local ok2, d = pcall(function() return Drawing.new(t) end)
    if not ok2 then return setmetatable({}, Dummy) end
    if props then
        for k, v in pairs(props) do
            pcall(function() d[k] = v end)
        end
    end
    return d
end

local function removeDraw(d)
    pcall(function() d:Remove() end)
end

-- ═══════════════════════════════════
--  ESP
-- ═══════════════════════════════════
local function clearESP()
    for _, t in pairs(ESPObjects) do
        for _, o in pairs(t) do removeDraw(o) end
    end
    ESPObjects = {}
end

local function makeESPSet()
    return {
        box = newDraw("Square", {
            Filled = false,
            Color = Color3.fromRGB(0,120,255),
            Thickness = 1.5,
            Visible = false,
        }),
        tracer = newDraw("Line", {
            Color = Color3.fromRGB(0,120,255),
            Thickness = 1,
            Visible = false,
        }),
        hpBg = newDraw("Square", {
            Filled = true,
            Color = Color3.fromRGB(20,20,20),
            Visible = false,
        }),
        hpBar = newDraw("Square", {
            Filled = true,
            Color = Color3.fromRGB(0,255,0),
            Visible = false,
        }),
        nameTag = newDraw("Text", {
            Size = 13,
            Center = true,
            Outline = true,
            Color = Color3.fromRGB(255,255,255),
            Visible = false,
        }),
    }
end

local function hideESPSet(t)
    for _, o in pairs(t) do
        pcall(function() o.Visible = false end)
    end
end

local function renderESP()
    for _, t in pairs(ESPObjects) do
        hideESPSet(t)
    end

    if not S.ESP then return end

    local vp  = Camera.ViewportSize
    local col = espColor()

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and isEnemy(p) and isAlive(p) then
            local char = p.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                local hum  = char:FindFirstChildOfClass("Humanoid")
                if root and hum then
                    local okBB, cf, sz = pcall(function()
                        return char:GetBoundingBox()
                    end)
                    if okBB then
                        local hw = sz.X/2
                        local hh = sz.Y/2
                        local hd = sz.Z/2
                        local offs = {
                            Vector3.new( hw, hh, hd),
                            Vector3.new(-hw, hh, hd),
                            Vector3.new( hw,-hh, hd),
                            Vector3.new(-hw,-hh, hd),
                            Vector3.new( hw, hh,-hd),
                            Vector3.new(-hw, hh,-hd),
                            Vector3.new( hw,-hh,-hd),
                            Vector3.new(-hw,-hh,-hd),
                        }
                        local minX =  math.huge
                        local minY =  math.huge
                        local maxX = -math.huge
                        local maxY = -math.huge
                        local anyVis = false

                        for i = 1, #offs do
                            local wp = cf * CFrame.new(offs[i])
                            local sp, vis = w2s(wp.Position)
                            if vis then
                                anyVis = true
                                if sp.X < minX then minX = sp.X end
                                if sp.Y < minY then minY = sp.Y end
                                if sp.X > maxX then maxX = sp.X end
                                if sp.Y > maxY then maxY = sp.Y end
                            end
                        end

                        if anyVis then
                            minX = math.clamp(minX, 0, vp.X)
                            minY = math.clamp(minY, 0, vp.Y)
                            maxX = math.clamp(maxX, 0, vp.X)
                            maxY = math.clamp(maxY, 0, vp.Y)
                            local bw = maxX - minX
                            local bh = maxY - minY

                            if bw >= 2 and bh >= 2 then
                                if not ESPObjects[p] then
                                    ESPObjects[p] = makeESPSet()
                                end
                                local t = ESPObjects[p]

                                pcall(function()
                                    t.box.Position = Vector2.new(minX, minY)
                                    t.box.Size     = Vector2.new(bw, bh)
                                    t.box.Color    = col
                                    t.box.Visible  = true
                                end)

                                pcall(function()
                                    t.tracer.From    = Vector2.new(vp.X/2, vp.Y)
                                    t.tracer.To      = Vector2.new(minX+bw/2, maxY)
                                    t.tracer.Color   = col
                                    t.tracer.Visible = true
                                end)

                                local hp    = math.clamp(hum.Health, 0, hum.MaxHealth)
                                local hpPct = hum.MaxHealth > 0 and (hp/hum.MaxHealth) or 0
                                local barH  = bh * hpPct
                                local hpCol = Color3.fromRGB(
                                    math.floor(255*(1-hpPct)),
                                    math.floor(255*hpPct),
                                    0
                                )

                                pcall(function()
                                    t.hpBg.Position = Vector2.new(minX-6, minY)
                                    t.hpBg.Size     = Vector2.new(4, bh)
                                    t.hpBg.Visible  = true
                                end)

                                pcall(function()
                                    t.hpBar.Position = Vector2.new(minX-6, minY+(bh-barH))
                                    t.hpBar.Size     = Vector2.new(4, barH)
                                    t.hpBar.Color    = hpCol
                                    t.hpBar.Visible  = true
                                end)

                                pcall(function()
                                    t.nameTag.Text     = p.DisplayName
                                    t.nameTag.Position = Vector2.new(minX+bw/2, minY-16)
                                    t.nameTag.Visible  = true
                                end)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ═══════════════════════════════════
--  CHAMS
-- ═══════════════════════════════════
local function clearChams()
    for _, hl in pairs(ChamsHL) do
        pcall(function() hl:Destroy() end)
    end
    ChamsHL = {}
end

local function applyChams()
    clearChams()
    if not S.Chams then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and isEnemy(p) and p.Character then
            local hl = Instance.new("SelectionBox")
            hl.Name                = "KrvChams"
            hl.Adornee             = p.Character
            hl.Color3              = Color3.fromRGB(255,50,50)
            hl.SurfaceColor3       = Color3.fromRGB(255,50,50)
            hl.SurfaceTransparency = 0.45
            hl.LineThickness       = 0.06
            hl.Parent              = workspace
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
        if p ~= LP and isEnemy(p) and p.Character then
            local char = p.Character
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local hb = Instance.new("Part")
                hb.Name         = "KrvHB"
                hb.Size         = Vector3.new(S.HitboxW, S.HitboxH, S.HitboxW)
                hb.Transparency = S.HitboxVis and 0.4 or 1
                hb.CanCollide   = false
                hb.Anchored     = false
                hb.CastShadow   = false
                hb.Color        = Color3.fromRGB(255,0,0)
                hb.Material     = Enum.Material.Neon
                local w         = Instance.new("WeldConstraint")
                w.Part0         = hb
                w.Part1         = root
                w.Parent        = hb
                hb.Parent       = char
                table.insert(HitboxParts, hb)
            end
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
        fovCircle.Visible  = S.FOVCircle
    end)
end

-- ═══════════════════════════════════
--  AIMBOT
-- ═══════════════════════════════════
local function getTarget()
    local vp   = Camera.ViewportSize
    local cx   = vp.X/2
    local cy   = vp.Y/2
    local best = nil
    local bestD= math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and isEnemy(p) and isAlive(p) then
            local char = p.Character
            if char then
                local part = char:FindFirstChild(S.AimbotPart)
                          or char:FindFirstChild("HumanoidRootPart")
                if part then
                    local wallOk = true
                    if not S.AimbotWall then
                        local origin = Camera.CFrame.Position
                        local dir    = (part.Position - origin).Unit * 2000
                        local ray    = Ray.new(origin, dir)
                        local hit    = workspace:FindPartOnRayWithIgnoreList(
                            ray, {LP.Character, Camera}
                        )
                        if hit and not char:IsAncestorOf(hit) then
                            wallOk = false
                        end
                    end
                    if wallOk then
                        local sp, vis = w2s(part.Position)
                        if vis then
                            local d = (Vector2.new(cx,cy)-sp).Magnitude
                            if d < S.AimbotFOV and d < bestD then
                                bestD = d
                                best  = part
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function runAimbot()
    if not S.Aimbot then return end
    local t = getTarget()
    if not t then return end
    local dir = (t.Position - Camera.CFrame.Position).Unit
    Camera.CFrame = CFrame.new(Camera.CFrame.Position,
                               Camera.CFrame.Position + dir)
end

-- ═══════════════════════════════════
--  SILENT AIM
-- ═══════════════════════════════════
local OrigSizes = {}

local function applySilentAim()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and isEnemy(p) and p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            if root then
                if not OrigSizes[p] then OrigSizes[p] = root.Size end
                root.Size = Vector3.new(8,8,8)
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
    if AmmoConn then AmmoConn:Disconnect() AmmoConn = nil end
    if not S.AmmoMod then return end
    AmmoConn = RunService.Heartbeat:Connect(function()
        local char = LP.Character
        if not char then return end
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                for _, d in ipairs(tool:GetDescendants()) do
                    local n = string.lower(d.Name)
                    if (d:IsA("IntValue") or d:IsA("NumberValue")) then
                        if n=="ammo" or n=="reserve" or n=="mag" or n=="bullets" then
                            d.Value = 999
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
    if RecoilConn then RecoilConn:Disconnect() RecoilConn = nil end
    if not S.RecoilMod then return end
    lastCF = Camera.CFrame
    RecoilConn = RunService.RenderStepped:Connect(function()
        if not S.RecoilMod then return end
        local cur     = Camera.CFrame
        local _,ry,_  = cur:ToEulerAnglesYXZ()
        local ox,_,oz = lastCF:ToEulerAnglesXYZ()
        Camera.CFrame = CFrame.fromEulerAnglesYXZ(ox,ry,oz)
                      + cur.Position
                      - CFrame.fromEulerAnglesYXZ(ox,ry,oz).Position
        lastCF = Camera.CFrame
    end)
end

-- ═══════════════════════════════════
--  PLAYER TRACKING
-- ═══════════════════════════════════
local function onCharAdded()
    task.wait(1)
    clearESP()
    if S.Chams  then applyChams()    end
    if S.Hitbox then applyHitboxes() end
end

tc(LP.CharacterAdded:Connect(onCharAdded))

for _, p in ipairs(Players:GetPlayers()) do
    tc(p.CharacterAdded:Connect(onCharAdded))
end
tc(Players.PlayerAdded:Connect(function(p)
    tc(p.CharacterAdded:Connect(onCharAdded))
end))
tc(Players.PlayerRemoving:Connect(function(p)
    if ESPObjects[p] then
        for _, o in pairs(ESPObjects[p]) do removeDraw(o) end
        ESPObjects[p] = nil
    end
    if ChamsHL[p] then
        pcall(function() ChamsHL[p]:Destroy() end)
        ChamsHL[p] = nil
    end
end))

-- ═══════════════════════════════════════════════════
--  GUI CONSTANTS
-- ═══════════════════════════════════════════════════
local BG_DARK = Color3.fromRGB(8,10,22)
local BG_MID  = Color3.fromRGB(14,18,40)
local ACCENT  = Color3.fromRGB(0,110,255)
local ACCENT2 = Color3.fromRGB(0,55,170)
local WHITE   = Color3.fromRGB(255,255,255)
local GREY    = Color3.fromRGB(90,100,130)
local REDC    = Color3.fromRGB(200,35,35)

-- ═══════════════════════════════════
--  SCREENGUI
-- ═══════════════════════════════════
local SG = Instance.new("ScreenGui")
SG.Name           = "KrovotokGUI"
SG.ResetOnSpawn   = false
SG.IgnoreGuiInset = true
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent         = SafeParent

-- ═══════════════════════════════════
--  BALL (minimized)
-- ═══════════════════════════════════
local Ball = Instance.new("ImageButton")
Ball.Name            = "KrvBall"
Ball.Size            = UDim2.new(0,80,0,80)
Ball.Position        = UDim2.new(0.5,-40,0.8,-40)
Ball.BackgroundColor3= WHITE
Ball.BorderSizePixel = 0
Ball.Visible         = false
Ball.ZIndex          = 20
Ball.Parent          = SG
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1,0)
    c.Parent = Ball
end
do
    local s = Instance.new("UIStroke")
    s.Color = ACCENT
    s.Thickness = 2
    s.Parent = Ball
end
do
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,1,0)
    l.BackgroundTransparency = 1
    l.Text = "Krovotok"
    l.TextColor3 = Color3.fromRGB(0,0,0)
    l.TextScaled = true
    l.Font = Enum.Font.GothamBold
    l.ZIndex = 21
    l.Parent = Ball
end

-- ball drag
do
    local drag = false
    local ds   = Vector2.new()
    local sp   = UDim2.new()
    Ball.TouchStarted:Connect(function(t)
        drag = true
        ds   = Vector2.new(t.Position.X, t.Position.Y)
        sp   = Ball.Position
    end)
    Ball.TouchMoved:Connect(function(t)
        if not drag then return end
        local d = Vector2.new(t.Position.X, t.Position.Y) - ds
        Ball.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X,
                                   sp.Y.Scale, sp.Y.Offset+d.Y)
    end)
    Ball.TouchEnded:Connect(function() drag = false end)
    Ball.MouseButton1Click:Connect(function() drag = false end)
end

-- ═══════════════════════════════════
--  MAIN WINDOW
-- ═══════════════════════════════════
local Win = Instance.new("Frame")
Win.Name             = "MainWin"
Win.AnchorPoint      = Vector2.new(0.5,0.5)
Win.Size             = UDim2.new(0.35,0,0.72,0)
Win.Position         = UDim2.new(0.5,0,0.5,0)
Win.BackgroundColor3 = BG_DARK
Win.BorderSizePixel  = 0
Win.ClipsDescendants = true
Win.ZIndex           = 2
Win.Parent           = SG
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0,10)
    c.Parent = Win
end
do
    local s = Instance.new("UIStroke")
    s.Color = ACCENT2
    s.Thickness = 1
    s.Parent = Win
end

-- ═══════════════════════════════════
--  TITLE BAR
-- ═══════════════════════════════════
local TBar = Instance.new("Frame")
TBar.Size             = UDim2.new(1,0,0,40)
TBar.BackgroundColor3 = BG_MID
TBar.BorderSizePixel  = 0
TBar.ZIndex           = 3
TBar.Parent           = Win
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0,10)
    c.Parent = TBar
end
do
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1,0,0,12)
    f.Position         = UDim2.new(0,0,1,-12)
    f.BackgroundColor3 = BG_MID
    f.BorderSizePixel  = 0
    f.ZIndex           = 3
    f.Parent           = TBar
end
do
    local l = Instance.new("TextLabel")
    l.Size             = UDim2.new(1,-90,1,0)
    l.Position         = UDim2.new(0,10,0,0)
    l.BackgroundTransparency = 1
    l.Text             = "KROVOTOK"
    l.TextColor3       = WHITE
    l.Font             = Enum.Font.GothamBold
    l.TextSize         = 14
    l.TextXAlignment   = Enum.TextXAlignment.Left
    l.ZIndex           = 4
    l.Parent           = TBar
end

local function mkTBtn(xOff, bg, txt, ts)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0,28,0,28)
    b.Position         = UDim2.new(1,xOff,0,6)
    b.BackgroundColor3 = bg
    b.Text             = txt
    b.TextColor3       = WHITE
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = ts or 14
    b.BorderSizePixel  = 0
    b.ZIndex           = 4
    b.Parent           = TBar
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0,6)
    c.Parent = b
    return b
end

local BtnClose = mkTBtn(-32, REDC,   "X",  13)
local BtnMin   = mkTBtn(-64, ACCENT2,"-",  18)

-- ═══════════════════════════════════
--  POPUP
-- ═══════════════════════════════════
local Popup = Instance.new("Frame")
Popup.Name             = "KrvPopup"
Popup.AnchorPoint      = Vector2.new(0.5,0.5)
Popup.Size             = UDim2.new(0.6,0,0,120)
Popup.Position         = UDim2.new(0.5,0,0.5,0)
Popup.BackgroundColor3 = BG_MID
Popup.BorderSizePixel  = 0
Popup.Visible          = false
Popup.ZIndex           = 50
Popup.Parent           = SG
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0,12)
    c.Parent = Popup
end
do
    local s = Instance.new("UIStroke")
    s.Color = REDC
    s.Thickness = 1.5
    s.Parent = Popup
end
do
    local l = Instance.new("TextLabel")
    l.Size             = UDim2.new(1,-16,0,60)
    l.Position         = UDim2.new(0,8,0,6)
    l.BackgroundTransparency = 1
    l.Text             = "Вы уверены, что хотите\nзакрыть чит полностью?"
    l.TextColor3       = WHITE
    l.Font             = Enum.Font.Gotham
    l.TextSize         = 13
    l.TextWrapped      = true
    l.TextYAlignment   = Enum.TextYAlignment.Center
    l.ZIndex           = 51
    l.Parent           = Popup
end

local function mkPopBtn(xPct, bg, txt)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0.44,0,0,30)
    b.Position         = UDim2.new(xPct,0,1,-38)
    b.BackgroundColor3 = bg
    b.Text             = txt
    b.TextColor3       = WHITE
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = 12
    b.BorderSizePixel  = 0
    b.ZIndex           = 51
    b.Parent           = Popup
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0,6)
    c.Parent = b
    return b
end

local PopNo  = mkPopBtn(0.03, ACCENT2, "Отмена")
local PopYes = mkPopBtn(0.52, REDC,    "Да, закрыть")

-- ═══════════════════════════════════
--  BODY
-- ═══════════════════════════════════
local Body = Instance.new("Frame")
Body.Size                = UDim2.new(1,0,1,-40)
Body.Position            = UDim2.new(0,0,0,40)
Body.BackgroundTransparency = 1
Body.ZIndex              = 3
Body.Parent              = Win

-- LEFT
local Left = Instance.new("Frame")
Left.Size             = UDim2.new(0.37,0,1,0)
Left.BackgroundColor3 = BG_MID
Left.BorderSizePixel  = 0
Left.ZIndex           = 3
Left.Parent           = Body

-- BACON
local BR = Instance.new("Frame")
BR.Size             = UDim2.new(0.78,0,0,72)
BR.Position         = UDim2.new(0.11,0,0,6)
BR.BackgroundTransparency = 1
BR.ZIndex           = 4
BR.Parent           = Left

local function mkPart(parent, size, pos, col, zidx, radius)
    local f = Instance.new("Frame")
    f.Size             = size
    f.Position         = pos
    f.BackgroundColor3 = col
    f.BorderSizePixel  = 0
    f.ZIndex           = zidx or 5
    f.Parent           = parent
    if radius then
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, radius)
        c.Parent = f
    end
    return f
end

-- head
local BHead = mkPart(BR,
    UDim2.new(0.55,0,0.38,0),
    UDim2.new(0.22,0,0.02,0),
    Color3.fromRGB(255,200,100), 5)
-- hair
mkPart(BHead,
    UDim2.new(0.65,0,0.22,0),
    UDim2.new(0.175,0,-0.14,0),
    Color3.fromRGB(180,0,0), 6, 3)
-- eyes
mkPart(BHead, UDim2.new(0.16,0,0.18,0), UDim2.new(0.18,0,0.35,0), Color3.fromRGB(0,0,0), 7)
mkPart(BHead, UDim2.new(0.16,0,0.18,0), UDim2.new(0.60,0,0.35,0), Color3.fromRGB(0,0,0), 7)
-- mouth
mkPart(BHead, UDim2.new(0.48,0,0.08,0), UDim2.new(0.26,0,0.66,0), Color3.fromRGB(160,70,0), 7)
-- body
mkPart(BR, UDim2.new(0.48,0,0.42,0), UDim2.new(0.26,0,0.42,0), Color3.fromRGB(0,100,255), 5)
-- legs
mkPart(BR, UDim2.new(0.22,0,0.22,0), UDim2.new(0.24,0,0.82,0), Color3.fromRGB(40,40,120), 5)
mkPart(BR, UDim2.new(0.22,0,0.22,0), UDim2.new(0.52,0,0.82,0), Color3.fromRGB(40,40,120), 5)
-- arms
mkPart(BR, UDim2.new(0.18,0,0.32,0), UDim2.new(0.04,0,0.44,0), Color3.fromRGB(255,200,100), 5)
mkPart(BR, UDim2.new(0.18,0,0.32,0), UDim2.new(0.72,0,0.44,0), Color3.fromRGB(255,200,100), 5)

-- username
do
    local l = Instance.new("TextLabel")
    l.Size             = UDim2.new(1,0,0,16)
    l.Position         = UDim2.new(0,0,0,80)
    l.BackgroundTransparency = 1
    l.Text             = "@bogteddy"
    l.TextColor3       = GREY
    l.Font             = Enum.Font.Gotham
    l.TextSize         = 9
    l.ZIndex           = 4
    l.Parent           = Left
end

-- divider
do
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(0.86,0,0,1)
    f.Position         = UDim2.new(0.07,0,0,100)
    f.BackgroundColor3 = ACCENT2
    f.BorderSizePixel  = 0
    f.ZIndex           = 4
    f.Parent           = Left
end

-- NAV SCROLL
local NavScroll = Instance.new("ScrollingFrame")
NavScroll.Size               = UDim2.new(1,0,1,-104)
NavScroll.Position           = UDim2.new(0,0,0,104)
NavScroll.BackgroundTransparency = 1
NavScroll.ScrollBarThickness = 0
NavScroll.CanvasSize         = UDim2.new(0,0,0,0)
NavScroll.ZIndex             = 4
NavScroll.Parent             = Left

local NavList = Instance.new("UIListLayout")
NavList.Padding             = UDim.new(0,3)
NavList.FillDirection       = Enum.FillDirection.Vertical
NavList.HorizontalAlignment = Enum.HorizontalAlignment.Center
NavList.Parent              = NavScroll

NavList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    NavScroll.CanvasSize = UDim2.new(0,0,0,NavList.AbsoluteContentSize.Y+6)
end)

local NavDefs = {
    {key="Combat",   icon="* ", label="Combat"  },
    {key="ESP",      icon="@ ", label="ESP"     },
    {key="Aimbot",   icon="# ", label="Aimbot"  },
    {key="Hitbox",   icon="$ ", label="Hitbox"  },
    {key="FOV",      icon="O ", label="FOV"     },
    {key="Settings", icon="= ", label="Settings"},
}

local NavBtns = {}
for _, nd in ipairs(NavDefs) do
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0.92,0,0,34)
    b.BackgroundColor3 = BG_DARK
    b.Text             = nd.icon .. nd.label
    b.TextColor3       = WHITE
    b.Font             = Enum.Font.Gotham
    b.TextSize         = 11
    b.TextXAlignment   = Enum.TextXAlignment.Left
    b.BorderSizePixel  = 0
    b.ZIndex           = 5
    b.Parent           = NavScroll
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0,6)
        c.Parent = b
    end
    do
        local p2 = Instance.new("UIPadding")
        p2.PaddingLeft = UDim.new(0,8)
        p2.Parent = b
    end
    NavBtns[nd.key] = b
end

-- RIGHT SCROLL
local Right = Instance.new("ScrollingFrame")
Right.Size               = UDim2.new(0.63,0,1,0)
Right.Position           = UDim2.new(0.37,0,0,0)
Right.BackgroundColor3   = BG_DARK
Right.BorderSizePixel    = 0
Right.ScrollBarThickness = 2
Right.ScrollBarImageColor3 = ACCENT
Right.CanvasSize         = UDim2.new(0,0,0,0)
Right.ZIndex             = 3
Right.Parent             = Body

local RList = Instance.new("UIListLayout")
RList.Padding             = UDim.new(0,4)
RList.FillDirection       = Enum.FillDirection.Vertical
RList.HorizontalAlignment = Enum.HorizontalAlignment.Center
RList.Parent              = Right

RList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Right.CanvasSize = UDim2.new(0,0,0,RList.AbsoluteContentSize.Y+10)
end)

-- ═══════════════════════════════════
--  WIDGET FACTORIES
-- ═══════════════════════════════════
local PW = {}
local function pw(w) table.insert(PW,w) return w end
local function clearRight()
    for _, w in ipairs(PW) do pcall(function() w:Destroy() end) end
    PW = {}
end

local function mkSec(txt)
    local l = Instance.new("TextLabel")
    l.Size             = UDim2.new(0.9,0,0,22)
    l.BackgroundTransparency = 1
    l.Text             = txt
    l.TextColor3       = ACCENT
    l.Font             = Enum.Font.GothamBold
    l.TextSize         = 11
    l.TextXAlignment   = Enum.TextXAlignment.Left
    l.ZIndex           = 4
    l.Parent           = Right
    return pw(l)
end

local function mkSp(h)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(0.9,0,0,h or 5)
    f.BackgroundTransparency = 1
    f.ZIndex           = 4
    f.Parent           = Right
    return pw(f)
end

local function mkNote(txt)
    local l = Instance.new("TextLabel")
    l.Size             = UDim2.new(0.9,0,0,16)
    l.BackgroundTransparency = 1
    l.Text             = txt
    l.TextColor3       = GREY
    l.Font             = Enum.Font.Gotham
    l.TextSize         = 9
    l.TextXAlignment   = Enum.TextXAlignment.Left
    l.ZIndex           = 4
    l.Parent           = Right
    return pw(l)
end

local function mkToggle(lbl, key, cb)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(0.92,0,0,33)
    row.BackgroundColor3 = BG_MID
    row.BorderSizePixel  = 0
    row.ZIndex           = 4
    row.Parent           = Right
    do local c = Instance.new("UICorner") c.CornerRadius=UDim.new(0,6) c.Parent=row end
    pw(row)

    local tl = Instance.new("TextLabel")
    tl.Size             = UDim2.new(0.68,0,1,0)
    tl.Position         = UDim2.new(0,8,0,0)
    tl.BackgroundTransparency = 1
    tl.Text             = lbl
    tl.TextColor3       = WHITE
    tl.Font             = Enum.Font.Gotham
    tl.TextSize         = 11
    tl.TextXAlignment   = Enum.TextXAlignment.Left
    tl.ZIndex           = 5
    tl.Parent           = row

    local tbg = Instance.new("Frame")
    tbg.Size             = UDim2.new(0,36,0,18)
    tbg.Position         = UDim2.new(1,-44,0.5,-9)
    tbg.BackgroundColor3 = GREY
    tbg.BorderSizePixel  = 0
    tbg.ZIndex           = 5
    tbg.Parent           = row
    do local c = Instance.new("UICorner") c.CornerRadius=UDim.new(1,0) c.Parent=tbg end

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.new(0,14,0,14)
    knob.Position         = UDim2.new(0,2,0,2)
    knob.BackgroundColor3 = WHITE
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 6
    knob.Parent           = tbg
    do local c = Instance.new("UICorner") c.CornerRadius=UDim.new(1,0) c.Parent=knob end

    local hit = Instance.new("TextButton")
    hit.Size               = UDim2.new(1,0,1,0)
    hit.BackgroundTransparency = 1
    hit.Text               = ""
    hit.ZIndex             = 7
    hit.Parent             = row

    local function refresh()
        local on = S[key]
        TweenService:Create(tbg,  TweenInfo.new(0.13),
            {BackgroundColor3 = on and ACCENT or GREY}):Play()
        TweenService:Create(knob, TweenInfo.new(0.13),
            {Position = on and UDim2.new(0,20,0,2) or UDim2.new(0,2,0,2)}):Play()
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

local function mkSlider(lbl, key, mn, mx, step, cb)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(0.92,0,0,48)
    row.BackgroundColor3 = BG_MID
    row.BorderSizePixel  = 0
    row.ZIndex           = 4
    row.Parent           = Right
    do local c = Instance.new("UICorner") c.CornerRadius=UDim.new(0,6) c.Parent=row end
    pw(row)

    local tl = Instance.new("TextLabel")
    tl.Size             = UDim2.new(0.62,0,0,20)
    tl.Position         = UDim2.new(0,8,0,4)
    tl.BackgroundTransparency = 1
    tl.Text             = lbl
    tl.TextColor3       = WHITE
    tl.Font             = Enum.Font.Gotham
    tl.TextSize         = 10
    tl.TextXAlignment   = Enum.TextXAlignment.Left
    tl.ZIndex           = 5
    tl.Parent           = row

    local vl = Instance.new("TextLabel")
    vl.Size             = UDim2.new(0.3,0,0,20)
    vl.Position         = UDim2.new(0.68,0,0,4)
    vl.BackgroundTransparency = 1
    vl.Text             = tostring(S[key])
    vl.TextColor3       = ACCENT
    vl.Font             = Enum.Font.GothamBold
    vl.TextSize         = 10
    vl.TextXAlignment   = Enum.TextXAlignment.Right
    vl.ZIndex           = 5
    vl.Parent           = row

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1,-16,0,5)
    track.Position         = UDim2.new(0,8,0,32)
    track.BackgroundColor3 = GREY
    track.BorderSizePixel  = 0
    track.ZIndex           = 5
    track.Parent           = row
    do local c = Instance.new("UICorner") c.CornerRadius=UDim.new(1,0) c.Parent=track end

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new(0,0,1,0)
    fill.BackgroundColor3 = ACCENT
    fill.BorderSizePixel  = 0
    fill.ZIndex           = 6
    fill.Parent           = track
    do local c = Instance.new("UICorner") c.CornerRadius=UDim.new(1,0) c.Parent=fill end

    local handle = Instance.new("Frame")
    handle.Size             = UDim2.new(0,13,0,13)
    handle.AnchorPoint      = Vector2.new(0.5,0.5)
    handle.Position         = UDim2.new(0,0,0.5,0)
    handle.BackgroundColor3 = WHITE
    handle.BorderSizePixel  = 0
    handle.ZIndex           = 7
    handle.Parent           = track
    do local c = Instance.new("UICorner") c.CornerRadius=UDim.new(1,0) c.Parent=handle end

    local function setPct(pct)
        pct = math.clamp(pct,0,1)
        local val = math.floor((mn+(mx-mn)*pct)/step+0.5)*step
        val = math.clamp(val,mn,mx)
        S[key] = val
        vl.Text = tostring(val)
        fill.Size = UDim2.new(pct,0,1,0)
        handle.Position = UDim2.new(pct,0,0.5,0)
        if cb then cb(val) end
    end

    setPct((S[key]-mn)/(mx-mn))

    local drag2 = false
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then drag2 = true end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then drag2 = false end
    end)
    UIS.InputChanged:Connect(function(inp)
        if drag2 and inp.UserInputType == Enum.UserInputType.Touch then
            local abs = track.AbsolutePosition
            local w2  = track.AbsoluteSize.X
            setPct((inp.Position.X - abs.X) / w2)
        end
    end)

    return row
end

-- ═══════════════════════════════════
--  PANEL BUILDER
-- ═══════════════════════════════════
local function buildPanel(key)
    clearRight()
    ActivePanel = key
    for k, b in pairs(NavBtns) do
        b.BackgroundColor3 = (k==key) and ACCENT or BG_DARK
    end

    if key == "Combat" then
        mkSec("  COMBAT")
        mkSp()
        mkToggle("Silent Aim",  "SilentAim", nil)
        mkToggle("Ammo Mod",    "AmmoMod",   function() startAmmoMod()   end)
        mkToggle("Recoil Mod",  "RecoilMod", function() startRecoilMod() end)
        mkSp(8)
        mkNote("  BoogaJohnyBoy  |  @bogteddy")

    elseif key == "ESP" then
        mkSec("  ESP")
        mkSp()
        mkToggle("Box ESP",     "ESP",       nil)
        mkToggle("Chams",       "Chams",     function() applyChams()    end)
        mkToggle("Rainbow",     "Rainbow",   nil)
        mkToggle("Show Allies", "ShowAllies",nil)
        mkSp(6)
        mkNote("  Boxes + tracers + HP + names")
        mkNote("  Chams = see through walls")
        mkNote("  Rainbow = color cycle")

    elseif key == "Aimbot" then
        mkSec("  AIMBOT")
        mkSp()
        mkToggle("Aimbot",        "Aimbot",    nil)
        mkToggle("Through Walls", "AimbotWall",nil)
        mkSlider("FOV Radius","AimbotFOV",20,400,5,nil)
        mkSp(6)
        mkSec("  TARGET PART")
        local parts = {
            {"Head",          "Head"},
            {"Upper Torso",   "UpperTorso"},
            {"Lower Torso",   "LowerTorso"},
            {"Root",          "HumanoidRootPart"},
        }
        for _, pd in ipairs(parts) do
            local row = Instance.new("Frame")
            row.Size             = UDim2.new(0.92,0,0,28)
            row.BackgroundColor3 = (S.AimbotPart==pd[2]) and ACCENT or BG_MID
            row.BorderSizePixel  = 0
            row.ZIndex           = 4
            row.Parent           = Right
            do local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,6) c.Parent=row end
            pw(row)
            local rl = Instance.new("TextLabel")
            rl.Size             = UDim2.new(1,0,1,0)
            rl.BackgroundTransparency = 1
            rl.Text             = pd[1]
            rl.TextColor3       = WHITE
            rl.Font             = Enum.Font.Gotham
            rl.TextSize         = 11
            rl.ZIndex           = 5
            rl.Parent           = row
            local rb = Instance.new("TextButton")
            rb.Size               = UDim2.new(1,0,1,0)
            rb.BackgroundTransparency = 1
            rb.Text               = ""
            rb.ZIndex             = 6
            rb.Parent             = row
            local pv = pd[2]
            local function selectPart()
                S.AimbotPart = pv
                buildPanel("Aimbot")
            end
            rb.MouseButton1Click:Connect(selectPart)
            rb.TouchTap:Connect(selectPart)
        end

    elseif key == "Hitbox" then
        mkSec("  HITBOX")
        mkSp()
        mkToggle("Expand Hitboxes","Hitbox",    function() applyHitboxes() end)
        mkToggle("Show Hitboxes",  "HitboxVis", function() applyHitboxes() end)
        mkSlider("Width",  "HitboxW",1,20,0.5,  function() applyHitboxes() end)
        mkSlider("Height", "HitboxH",1,20,0.5,  function() applyHitboxes() end)
        mkSp(6)
        mkNote("  Bigger boxes = easier to hit")
        mkNote("  Show = red glow visible")

    elseif key == "FOV" then
        mkSec("  FOV CIRCLE")
        mkSp()
        mkToggle("Show FOV","FOVCircle",function() updateFOV() end)
        mkSlider("Radius","FOVSize",20,400,5,function() updateFOV() end)
        mkSp(6)
        mkNote("  Always at screen center")
        mkNote("  Aimbot locks only inside FOV")
        mkNote("  High=head  Mid=body  Low=legs")

    elseif key == "Settings" then
        mkSec("  SETTINGS")
        mkSp()
        mkSlider("FOV Size",     "FOVSize",  20,400,5,  function() updateFOV()       end)
        mkSlider("Aimbot FOV",   "AimbotFOV",20,400,5,  nil)
        mkSlider("Hitbox Width", "HitboxW",  1, 20, 0.5,function() applyHitboxes()   end)
        mkSlider("Hitbox Height","HitboxH",  1, 20, 0.5,function() applyHitboxes()   end)
        mkSp(8)
        mkNote("  Krovotok v1.0")
        mkNote("  Creator: BoogaJohnyBoy")
        mkNote("  @bogteddy")
    end
end

-- wire nav
for _, nd in ipairs(NavDefs) do
    local k = nd.key
    local b = NavBtns[k]
    b.MouseButton1Click:Connect(function() buildPanel(k) end)
    b.TouchTap:Connect(function()          buildPanel(k) end)
end

buildPanel("Combat")

-- ═══════════════════════════════════
--  CLOSE / MINIMIZE
-- ═══════════════════════════════════
local function shutdownAll()
    S.ESP=false S.Chams=false S.Aimbot=false
    S.Hitbox=false S.SilentAim=false
    S.AmmoMod=false S.RecoilMod=false
    S.FOVCircle=false

    clearESP()
    clearChams()
    clearHitboxes()
    revertSilentAim()

    if AmmoConn   then AmmoConn:Disconnect()   end
    if RecoilConn then RecoilConn:Disconnect() end
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end

    pcall(function() fovCircle:Remove() end)
    pcall(function() SG:Destroy() end)
end

local function cb(btn, fn)
    btn.MouseButton1Click:Connect(fn)
    btn.TouchTap:Connect(fn)
end

cb(BtnClose, function() Popup.Visible = true  end)
cb(PopNo,    function() Popup.Visible = false end)
cb(PopYes,   shutdownAll)
cb(BtnMin,   function() Win.Visible=false Ball.Visible=true  end)
cb(Ball,     function() Ball.Visible=false Win.Visible=true  end)

-- ═══════════════════════════════════
--  RENDER LOOP
-- ═══════════════════════════════════
tc(RunService.RenderStepped:Connect(function()
    renderESP()
    runAimbot()
    updateFOV()
    if S.SilentAim then applySilentAim() end
    if S.Chams and S.Rainbow then
        local rc = getRainbow()
        for _, hl in pairs(ChamsHL) do
            pcall(function()
                hl.Color3        = rc
                hl.SurfaceColor3 = rc
            end)
        end
    end
    if S.Chams then
        for _, p in ipairs(Players:GetPlayers()) do
            if p~=LP and isEnemy(p) and p.Character and not ChamsHL[p] then
                applyChams()
                break
            end
        end
    end
end))

print("[Krovotok] loaded OK - BoogaJohnyBoy | @bogteddy")

end) -- end pcall

if not ok then
    print("[Krovotok] ERROR: " .. tostring(err))
end
