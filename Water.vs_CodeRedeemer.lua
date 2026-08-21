local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local getupvalues = (debug and debug.getupvalues) or getupvalues
local getconns    = getconnections or (debug and debug.getconnections)
local setupv      = (debug and debug.setupvalue) or setupvalue

local function isOurGui(instance)
    local p = instance
    for _ = 1, 10 do
        if not p then break end
        if p.Name == "WaterVSRedeemerGui" then return true end
        p = p.Parent
    end
    return false
end

local function findAllTextBoxes(pg)
    local boxes = {}
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "WaterVSRedeemerGui" then
            for _, d in ipairs(gui:GetDescendants()) do
                if d:IsA("TextBox") and not isOurGui(d) then
                    boxes[#boxes+1] = d
                end
            end
        end
    end
    return boxes
end

local function isVisibleChain(inst)
    local current = inst
    while current do
        if current:IsA("GuiObject") then
            if not current.Visible then return false end
        end
        if current:IsA("ScreenGui") then
            if not current.Enabled then return false end
            return true
        end
        current = current.Parent
    end
    return true
end

local function findCodeButtons(pg)
    local btns = {}
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "WaterVSRedeemerGui" then
            for _, d in ipairs(gui:GetDescendants()) do
                if (d:IsA("TextButton") or d:IsA("ImageButton")) and not isOurGui(d) then
                    local n  = d.Name:lower()
                    local pn = (d.Parent and d.Parent.Name or ""):lower()
                    if (n:find("code") or n:find("redeem") or pn:find("code") or pn:find("redeem"))
                        and isVisibleChain(d) then
                        btns[#btns+1] = d
                    end
                end
            end
        end
    end
    return btns
end

local function clickButton(btn)
    if not btn then return false end
    local methods = {}
    
    methods[#methods+1] = function() btn.MouseButton1Click:Fire() end
    methods[#methods+1] = function() btn.Activated:Fire() end
    
    if typeof(firesignal) == "function" then
        methods[#methods+1] = function() firesignal(btn.MouseButton1Click) end
        methods[#methods+1] = function() firesignal(btn.Activated) end
    end
    
    if typeof(getconns) == "function" then
        methods[#methods+1] = function()
            local ok, cs = pcall(getconns, btn.MouseButton1Click)
            if ok and type(cs) == "table" then
                for _, c in ipairs(cs) do pcall(function() c:Fire() end) end
            end
            local ok2, cs2 = pcall(getconns, btn.Activated)
            if ok2 and type(cs2) == "table" then
                for _, c in ipairs(cs2) do pcall(function() c:Fire() end) end
            end
        end
    end
    
    if typeof(fireclick) == "function" then
        methods[#methods+1] = function() fireclick(btn) end
    end
    
    local anyOk = false
    for _, fn in ipairs(methods) do
        local ok = pcall(fn)
        anyOk = anyOk or ok
    end
    return anyOk
end

local function writeCodeToBox(box, code)
    if not box then return false end
    pcall(function()
        box.Text = code
    end)
    return box.Text == code
end

local function fireBoxFocusLost(box)
    if not box then return false end
    local anyFired = false
    
    if typeof(firesignal) == "function" then
        local ok = pcall(firesignal, box.FocusLost, true)
        anyFired = anyFired or ok
    end
    
    if typeof(getconns) == "function" then
        local ok, cs = pcall(getconns, box.FocusLost)
        if ok and type(cs) == "table" then
            for _, c in ipairs(cs) do
                local fn
                pcall(function() fn = c.Function end)
                if fn and typeof(getupvalues) == "function" and typeof(setupv) == "function" then
                    local uOk, ups = pcall(getupvalues, fn)
                    if uOk and type(ups) == "table" then
                        for i, v in pairs(ups) do
                            if type(v) == "boolean" and v == true then
                                pcall(setupv, fn, i, false)
                            end
                        end
                    end
                end
                local fOk = pcall(function()
                    if c.Enabled ~= false then c:Fire(true) end
                end)
                anyFired = anyFired or fOk
            end
        end
    end
    
    return anyFired
end

local function typeAndSubmitCode(code)
    if not LP then return false, "no LP" end
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return false, "no PlayerGui" end

    local codesGui = pg:FindFirstChild("Codes")
    if codesGui then
        if codesGui:IsA("ScreenGui") then
            codesGui.Enabled = true
        end
        local codesFrame = codesGui:FindFirstChild("Codes") or codesGui
        if codesFrame then
            if codesFrame:IsA("GuiObject") then
                codesFrame.Visible = true
            end
            local cur = codesFrame
            while cur and cur ~= codesGui do
                if cur:IsA("GuiObject") then cur.Visible = true end
                cur = cur.Parent
            end

            local box = nil
            for _, d in ipairs(codesFrame:GetDescendants()) do
                if d:IsA("TextBox") and not isOurGui(d) then
                    box = d
                    break
                end
            end

            local submitBtn = nil
            for _, d in ipairs(codesFrame:GetDescendants()) do
                if (d:IsA("TextButton") or d:IsA("ImageButton")) and not isOurGui(d) then
                    local n = d.Name:lower()
                    local txt = ""
                    pcall(function() txt = d.Text:lower() end)
                    if n:find("submit") or txt:find("submit") or n:find("redeem") or txt:find("redeem") or n:find("claim") or txt:find("confirm") or n:find("enter") then
                        submitBtn = d
                        break
                    end
                end
            end
            if not submitBtn then
                for _, d in ipairs(codesFrame:GetDescendants()) do
                    if (d:IsA("TextButton") or d:IsA("ImageButton")) and not isOurGui(d) then
                        local n = d.Name:lower()
                        if not n:find("close") and not n:find("x") and not n:find("toggle") then
                            submitBtn = d
                            break
                        end
                    end
                end
            end

            if box then
                writeCodeToBox(box, code)
                task.wait(0.05)
                if submitBtn then
                    clickButton(submitBtn)
                end
                fireBoxFocusLost(box)
                return true, "submitted via PlayerGui.Codes.Codes"
            end
        end
    end

    local function tryOpenPanel()
        local btns = findCodeButtons(pg)
        for _, btn in ipairs(btns) do
            clickButton(btn)
            task.wait(0.05)
        end
        return #btns > 0
    end

    tryOpenPanel()
    task.wait(0.3)

    local box = nil
    local deadline = tick() + 3
    while tick() < deadline do
        local allBoxes = findAllTextBoxes(pg)
        for _, d in ipairs(allBoxes) do
            if isVisibleChain(d) then
                local n   = d.Name:lower()
                local pn  = (d.Parent and d.Parent.Name or ""):lower()
                if n:find("code") or pn:find("code") or n:find("redeem") or pn:find("redeem") or n:find("input") or pn:find("input") or n:find("textbox") or n:find("enter") then
                    box = d
                    break
                end
            end
        end
        if not box then
            for _, d in ipairs(allBoxes) do
                if isVisibleChain(d) then box = d; break end
            end
        end
        if box then break end
        task.wait(0.1)
    end

    if not box then return false, "no codebox visible" end

    writeCodeToBox(box, code)
    task.wait(0.05)

    local redeemBtn = nil
    local searchNames = {"submit","redeem","claim","confirm","enter","send","apply","ok","use","go","check"}
    local p = box.Parent
    for _ = 1, 8 do
        if not p then break end
        for _, d in ipairs(p:GetDescendants()) do
            if (d:IsA("TextButton") or d:IsA("ImageButton")) and not isOurGui(d) and d ~= box then
                local n = d.Name:lower()
                local txt = ""
                pcall(function() txt = d.Text:lower() end)
                for _, sn in ipairs(searchNames) do
                    if n:find(sn) or txt:find(sn) then
                        if isVisibleChain(d) then
                            redeemBtn = d
                            break
                        end
                    end
                end
                if redeemBtn then break end
            end
        end
        if redeemBtn then break end
        p = p.Parent
    end

    if redeemBtn then
        clickButton(redeemBtn)
    end

    fireBoxFocusLost(box)

    return true, "fallback methods used"
end

local function resolveNotifyRemote()
    if _G.PhiNotifyRemote then return _G.PhiNotifyRemote end
    local Net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net")
    local getinfo = debug and (debug.getinfo or debug.info)
    if getgc and getinfo and getconnections then
        for _, d in ipairs(Net:GetDescendants()) do
            if d:IsA("RemoteEvent") then
                local ok, cs = pcall(getconnections, d.OnClientEvent)
                if ok then
                    for _, c in ipairs(cs) do
                        local f, fn = pcall(function() return c.Function end)
                        if f and type(fn) == "function" then
                            local i, info = pcall(getinfo, fn)
                            if i and tostring(info.short_src or info.source or ""):find("NotificationController", 1, true) then
                                return d
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local notifyRemote = resolveNotifyRemote()
if not notifyRemote then
    warn("[Water.vs] Notification remote not found - announcements won't be captured.")
end

if PlayerGui:FindFirstChild("WaterVSRedeemerGui") then
    PlayerGui.WaterVSRedeemerGui:Destroy()
end

local CYAN = Color3.fromRGB(0, 220, 255)
local CYAN_DIM = Color3.fromRGB(0, 160, 210)
local CYAN_GLOW = Color3.fromRGB(80, 240, 255)
local BG = Color3.fromRGB(4, 12, 20)
local BG2 = Color3.fromRGB(8, 18, 30)
local CARD = Color3.fromRGB(12, 24, 38)
local TEXT = Color3.fromRGB(240, 250, 255)
local TEXT_DIM = Color3.fromRGB(140, 180, 200)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WaterVSRedeemerGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 120
screenGui.IgnoreGuiInset = true
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(screenGui) end
end)
if not pcall(function()
    if gethui then screenGui.Parent = gethui() else error("no gethui") end
end) then
    screenGui.Parent = PlayerGui
end

-- Compact mobile-friendly size
local PANEL_W, PANEL_H = 260, 188
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
mainFrame.Position = UDim2.new(0.5, -PANEL_W/2, 0.55, -PANEL_H/2)
mainFrame.BackgroundColor3 = BG
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Active = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16)

do
    local s = Instance.new("UIStroke")
    s.Color = CYAN
    s.Thickness = 1.6
    s.Transparency = 0.25
    s.Parent = mainFrame
    local outer = Instance.new("UIStroke")
    outer.Color = CYAN_DIM
    outer.Thickness = 3.5
    outer.Transparency = 0.78
    outer.Parent = mainFrame
end

-- Soft gradient
do
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 22, 36)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 8, 14)),
    })
    g.Rotation = 120
    g.Parent = mainFrame
end

-- Cyan rain layer
local rainLayer = Instance.new("Frame")
rainLayer.Name = "CyanRain"
rainLayer.BackgroundTransparency = 1
rainLayer.Size = UDim2.fromScale(1, 1)
rainLayer.ClipsDescendants = true
rainLayer.ZIndex = 1
rainLayer.Active = false
rainLayer.Parent = mainFrame
Instance.new("UICorner", rainLayer).CornerRadius = UDim.new(0, 16)

task.spawn(function()
    while rainLayer and rainLayer.Parent do
        for _ = 1, 2 do
            if not rainLayer.Parent then break end
            local drop = Instance.new("Frame")
            drop.BackgroundColor3 = CYAN
            drop.BackgroundTransparency = 0.4
            drop.BorderSizePixel = 0
            drop.Size = UDim2.new(0, math.random(1, 2), 0, math.random(10, 22))
            drop.Position = UDim2.new(math.random() * 0.98, 0, -0.1, 0)
            drop.ZIndex = 1
            drop.Active = false
            drop.Parent = rainLayer
            Instance.new("UICorner", drop).CornerRadius = UDim.new(1, 0)
            local dur = 0.65 + math.random() * 0.85
            local tw = TweenService:Create(drop, TweenInfo.new(dur, Enum.EasingStyle.Linear), {
                Position = UDim2.new(drop.Position.X.Scale, 0, 1.08, 0),
                BackgroundTransparency = 0.92,
            })
            tw:Play()
            tw.Completed:Connect(function() if drop then drop:Destroy() end end)
        end
        task.wait(0.1)
    end
end)

-- Content root above rain
local content = Instance.new("Frame")
content.Name = "Content"
content.BackgroundTransparency = 1
content.Size = UDim2.fromScale(1, 1)
content.ZIndex = 5
content.Parent = mainFrame

-- Header
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, -16, 0, 36)
topBar.Position = UDim2.new(0, 8, 0, 8)
topBar.BackgroundColor3 = BG2
topBar.BackgroundTransparency = 0.15
topBar.BorderSizePixel = 0
topBar.ZIndex = 6
topBar.Parent = content
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)
do
    local s = Instance.new("UIStroke")
    s.Color = CYAN
    s.Thickness = 1
    s.Transparency = 0.55
    s.Parent = topBar
end

local logo = Instance.new("Frame")
logo.Size = UDim2.new(0, 22, 0, 22)
logo.Position = UDim2.new(0, 8, 0.5, -11)
logo.BackgroundColor3 = CYAN
logo.BorderSizePixel = 0
logo.ZIndex = 7
logo.Parent = topBar
Instance.new("UICorner", logo).CornerRadius = UDim.new(0, 7)
do
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 240, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 140, 220)),
    })
    g.Rotation = 135
    g.Parent = logo
end
local logoTxt = Instance.new("TextLabel")
logoTxt.Size = UDim2.fromScale(1, 1)
logoTxt.BackgroundTransparency = 1
logoTxt.Text = "W"
logoTxt.TextColor3 = Color3.fromRGB(255, 255, 255)
logoTxt.Font = Enum.Font.GothamBlack
logoTxt.TextSize = 12
logoTxt.ZIndex = 8
logoTxt.Parent = logo

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -90, 0, 16)
titleLabel.Position = UDim2.new(0, 36, 0, 4)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.Text = "Water.vs"
titleLabel.TextColor3 = TEXT
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 7
titleLabel.Parent = topBar

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, -90, 0, 12)
subLabel.Position = UDim2.new(0, 36, 0, 20)
subLabel.BackgroundTransparency = 1
subLabel.Font = Enum.Font.Gotham
subLabel.Text = "CODE REDEEMER"
subLabel.TextColor3 = CYAN
subLabel.TextSize = 9
subLabel.TextXAlignment = Enum.TextXAlignment.Left
subLabel.ZIndex = 7
subLabel.Parent = topBar

local statusDot = Instance.new("TextButton")
statusDot.Name = "StatusDot"
statusDot.Size = UDim2.new(0, 28, 0, 28)
statusDot.Position = UDim2.new(1, -32, 0.5, -14)
statusDot.BackgroundColor3 = CARD
statusDot.BorderSizePixel = 0
statusDot.Text = "✕"
statusDot.TextColor3 = TEXT_DIM
statusDot.TextSize = 12
statusDot.Font = Enum.Font.GothamBold
statusDot.AutoButtonColor = false
statusDot.ZIndex = 8
statusDot.Parent = topBar
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(0, 8)

local function styleBtn(btn, primary)
    btn.BackgroundColor3 = primary and CYAN or CARD
    btn.BackgroundTransparency = primary and 0.05 or 0.1
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = primary and Color3.fromRGB(5, 20, 30) or TEXT
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    local s = Instance.new("UIStroke")
    s.Color = CYAN
    s.Thickness = 1
    s.Transparency = primary and 0.35 or 0.6
    s.Parent = btn
end

-- START SCAN
local scanButton = Instance.new("TextButton")
scanButton.Name = "ScanButton"
scanButton.Size = UDim2.new(1, -16, 0, 28)
scanButton.Position = UDim2.new(0, 8, 0, 50)
scanButton.Text = "START SCAN"
scanButton.TextSize = 11
scanButton.ZIndex = 6
scanButton.Parent = content
styleBtn(scanButton, true)

-- MODE
local modeButton = Instance.new("TextButton")
modeButton.Name = "ModeButton"
modeButton.Size = UDim2.new(1, -16, 0, 26)
modeButton.Position = UDim2.new(0, 8, 0, 84)
modeButton.Text = "MODE: 3 GLOBAL MESSAGES"
modeButton.TextSize = 9
modeButton.ZIndex = 6
modeButton.Parent = content
styleBtn(modeButton, false)

-- Preview + Redeem row
local previewBox = Instance.new("TextBox")
previewBox.Name = "PreviewBox"
previewBox.Size = UDim2.new(1, -90, 0, 28)
previewBox.Position = UDim2.new(0, 8, 0, 116)
previewBox.BackgroundColor3 = CARD
previewBox.BackgroundTransparency = 0.1
previewBox.BorderSizePixel = 0
previewBox.PlaceholderText = "Captured code..."
previewBox.PlaceholderColor3 = TEXT_DIM
previewBox.Text = ""
previewBox.TextColor3 = TEXT
previewBox.ClearTextOnFocus = false
previewBox.Font = Enum.Font.GothamBold
previewBox.TextSize = 11
previewBox.TextXAlignment = Enum.TextXAlignment.Left
previewBox.ZIndex = 6
previewBox.Parent = content
Instance.new("UICorner", previewBox).CornerRadius = UDim.new(0, 10)
do
    local s = Instance.new("UIStroke")
    s.Color = CYAN
    s.Thickness = 1
    s.Transparency = 0.6
    s.Parent = previewBox
end
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.Parent = previewBox

local redeemButton = Instance.new("TextButton")
redeemButton.Name = "RedeemButton"
redeemButton.Size = UDim2.new(0, 70, 0, 28)
redeemButton.Position = UDim2.new(1, -78, 0, 116)
redeemButton.Text = "REDEEM"
redeemButton.TextSize = 10
redeemButton.ZIndex = 6
redeemButton.Parent = content
styleBtn(redeemButton, true)

-- Bottom row: delay + set
local bottomRow = Instance.new("Frame")
bottomRow.Name = "BottomRow"
bottomRow.Size = UDim2.new(1, -16, 0, 28)
bottomRow.Position = UDim2.new(0, 8, 0, 150)
bottomRow.BackgroundTransparency = 1
bottomRow.ZIndex = 6
bottomRow.Parent = content

local delayLabel = Instance.new("TextLabel")
delayLabel.Size = UDim2.new(0, 42, 1, 0)
delayLabel.Position = UDim2.new(0, 2, 0, 0)
delayLabel.BackgroundTransparency = 1
delayLabel.Font = Enum.Font.GothamBold
delayLabel.Text = "Delay"
delayLabel.TextColor3 = TEXT_DIM
delayLabel.TextSize = 10
delayLabel.TextXAlignment = Enum.TextXAlignment.Left
delayLabel.ZIndex = 7
delayLabel.Parent = bottomRow

local delayBox = Instance.new("TextBox")
delayBox.Name = "DelayBox"
delayBox.Size = UDim2.new(0, 48, 1, 0)
delayBox.Position = UDim2.new(0, 46, 0, 0)
delayBox.BackgroundColor3 = CARD
delayBox.BackgroundTransparency = 0.1
delayBox.BorderSizePixel = 0
delayBox.Text = "0.5"
delayBox.TextColor3 = TEXT
delayBox.Font = Enum.Font.GothamBold
delayBox.TextSize = 11
delayBox.TextXAlignment = Enum.TextXAlignment.Center
delayBox.ClearTextOnFocus = false
delayBox.ZIndex = 7
delayBox.Parent = bottomRow
Instance.new("UICorner", delayBox).CornerRadius = UDim.new(0, 8)
do
    local s = Instance.new("UIStroke")
    s.Color = CYAN
    s.Thickness = 1
    s.Transparency = 0.6
    s.Parent = delayBox
end

local setButton = Instance.new("TextButton")
setButton.Name = "SetButton"
setButton.Size = UDim2.new(0, 56, 1, 0)
setButton.Position = UDim2.new(1, -56, 0, 0)
setButton.Text = "SET"
setButton.TextSize = 10
setButton.ZIndex = 7
setButton.Parent = bottomRow
styleBtn(setButton, false)

-- Hover
local function applyHoverEffect(button, isPrimary)
    local offT = isPrimary and 0.05 or 0.1
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15), {
            BackgroundTransparency = 0,
            BackgroundColor3 = isPrimary and CYAN_GLOW or Color3.fromRGB(16, 32, 48),
        }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15), {
            BackgroundTransparency = offT,
            BackgroundColor3 = isPrimary and CYAN or CARD,
        }):Play()
    end)
end
applyHoverEffect(scanButton, true)
applyHoverEffect(modeButton, false)
applyHoverEffect(setButton, false)
applyHoverEffect(redeemButton, true)

statusDot.MouseButton1Click:Connect(function() screenGui:Destroy() end)

-- Drag (mobile + PC) — header / whole panel
local dragging, dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

local function beginDrag(input)
    dragging = true
    dragStart = input.Position
    startPos = mainFrame.Position
    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            dragging = false
        end
    end)
end

mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        beginDrag(input)
    end
end)
mainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

local scanning = false
local buffer = {}
local mode = 3
local delay = 0.5

local function updateDelay()
    local val = tonumber(delayBox.Text)
    if val and val >= 0.05 then
        delay = val
        print("[Water.vs] Delay set to:", delay)
    else
        delayBox.Text = tostring(delay)
    end
end

delayBox.FocusLost:Connect(function(enter)
    if enter then updateDelay() end
end)

delayBox:GetPropertyChangedSignal("Text"):Connect(function()
    local val = tonumber(delayBox.Text)
    if val and val >= 0.05 then
        delay = val
    end
end)

setButton.MouseButton1Click:Connect(updateDelay)

local function isValidCode(msg)
    return msg:match("^[A-Za-z0-9]+$") ~= nil
end

local function updatePreview()
    if #buffer == 0 then
        previewBox.Text = ""
        return
    end
    local count = math.min(#buffer, mode)
    local combined = table.concat(buffer, "", 1, count)
    previewBox.Text = combined
end

local function processBuffer()
    if not scanning then return end
    while #buffer >= mode do
        local combined = table.concat(buffer, "", 1, mode)
        buffer = {}
        updatePreview()
        typeAndSubmitCode(combined)
        print("[Water.vs] Auto-redeemed: " .. combined)
        task.wait(delay)
    end
    updatePreview()
end

local function onAnnouncement(txt)
    if not scanning or not txt or txt == "" then return end
    local msg = txt:match("^%s*(.-)%s*$")
    if msg and #msg > 0 and isValidCode(msg) then
        table.insert(buffer, msg)
        updatePreview()
        if #buffer >= mode then
            task.spawn(processBuffer)
        end
        print("[Water.vs] Captured: " .. msg .. " (buffer: " .. #buffer .. ")")
    end
end

local function toggleScan()
    scanning = not scanning
    if scanning then
        scanButton.Text = "SCANNING..."
        scanButton.BackgroundColor3 = Color3.fromRGB(0, 200, 160)
        scanButton.BackgroundTransparency = 0.05
        statusDot.BackgroundColor3 = Color3.fromRGB(0, 220, 140)
        statusDot.Text = "●"
        statusDot.TextColor3 = Color3.fromRGB(5, 30, 20)
        buffer = {}
        updatePreview()
        print("[Water.vs] Scanning started.")
    else
        scanButton.Text = "START SCAN"
        scanButton.BackgroundColor3 = CYAN
        scanButton.BackgroundTransparency = 0.05
        statusDot.BackgroundColor3 = CARD
        statusDot.Text = "✕"
        statusDot.TextColor3 = TEXT_DIM
        buffer = {}
        updatePreview()
        print("[Water.vs] Scanning stopped.")
    end
end

scanButton.MouseButton1Click:Connect(toggleScan)

modeButton.MouseButton1Click:Connect(function()
    mode = (mode % 4) + 1
    modeButton.Text = "MODE: " .. mode .. " GLOBAL MESSAGE" .. (mode > 1 and "S" or "")
    updatePreview()
    if scanning and #buffer >= mode then
        task.spawn(processBuffer)
    end
end)

local function manualRedeem()
    local code = previewBox.Text
    if code and code ~= "" then
        typeAndSubmitCode(code)
        print("[Water.vs] Manually redeemed: " .. code)
        buffer = {}
        updatePreview()
    end
end

redeemButton.MouseButton1Click:Connect(manualRedeem)

previewBox.FocusLost:Connect(function(enter)
    if enter then manualRedeem() end
end)

if notifyRemote then
    notifyRemote.OnClientEvent:Connect(function(txt, ...)
        onAnnouncement(txt)
    end)
else
    warn("[Water.vs] No notify remote - announcements not captured.")
end

print("[Water.vs] Code Redeemer ready. Tap START SCAN.")
