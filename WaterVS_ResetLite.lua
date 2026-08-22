if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local lp = Players.LocalPlayer
local PlayerGui = lp:WaitForChild("PlayerGui")

local RESET_MAX_DURATION = 0.05
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local resetCooldown = false
local resetThread = nil
local currentCharacter = nil
local resetSuccessful = false
local stopResetSequence = false
local cameraLocked = false
local lockedCameraCFrame = nil

local function ResetPlayer()
    if resetCooldown then return end
    resetCooldown = true
    resetSuccessful = false
    stopResetSequence = false
    cameraLocked = false

    local character = lp.Character
    if not character then resetCooldown = false return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then resetCooldown = false return end

    local camera = workspace.CurrentCamera
    if camera then
        lockedCameraCFrame = camera.CFrame
        cameraLocked = true
        camera.CFrame = lockedCameraCFrame
    end

    currentCharacter = character
    local isRespawning = false

    resetThread = task.spawn(function()
        local attempts = 0
        local maxAttempts = 40
        local originalHipHeight = humanoid.HipHeight

        while character and character.Parent and humanoid and humanoid.Health > 0 and not isRespawning and not stopResetSequence do
            if lp.Character ~= character then
                isRespawning = true
                break
            end

            pcall(function()
                humanoid.HipHeight = 1e30
                humanoid.AutoRotate = true

                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    rootPart.CanCollide = false
                end

                for _, part in ipairs(character:GetChildren()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = false
                    end
                end
            end)

            if not character or not character.Parent or not humanoid or humanoid.Health <= 0 or lp.Character ~= character then
                resetSuccessful = true
                break
            end

            attempts = attempts + 1
            if attempts >= maxAttempts then break end
            task.wait(RESET_MAX_DURATION)
        end

        if not resetSuccessful then
            if character and character.Parent and humanoid and humanoid.Health > 0 and not isRespawning then
                pcall(function()
                    humanoid.Health = 0
                end)
                task.wait(0.1)
                if not character.Parent or humanoid.Health <= 0 then
                    resetSuccessful = true
                end
            end
        end

        if not resetSuccessful and character and character.Parent and humanoid then
            pcall(function()
                humanoid.HipHeight = originalHipHeight
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    rootPart.CanCollide = true
                end
                for _, part in ipairs(character:GetChildren()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end)
        end

        cameraLocked = false
        resetCooldown = false
        resetThread = nil
        currentCharacter = nil
        stopResetSequence = false
    end)
end

local function StopResetSequence()
    stopResetSequence = true
    if resetThread then
        task.cancel(resetThread)
        resetThread = nil
    end
    resetCooldown = false
    currentCharacter = nil
    cameraLocked = false

    local character = lp.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            pcall(function()
                humanoid.HipHeight = 2
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    rootPart.CanCollide = true
                end
                for _, part in ipairs(character:GetChildren()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end)
        end
    end
end

lp.CharacterAdded:Connect(function()
    StopResetSequence()
    resetCooldown = false
    currentCharacter = nil
    resetSuccessful = false
    stopResetSequence = false
    cameraLocked = false
end)

task.spawn(function()
    local camera = workspace.CurrentCamera
    while true do
        task.wait(0.016)
        if cameraLocked and lockedCameraCFrame and camera then
            camera.CFrame = lockedCameraCFrame
        end
    end
end)

-- ===================== WATER.VS UI =====================
local CYAN        = Color3.fromRGB(0, 210, 255)
local CYAN_DARK   = Color3.fromRGB(0, 140, 190)
local CYAN_DEEP   = Color3.fromRGB(0, 90, 140)
local NAVY        = Color3.fromRGB(6, 16, 28)
local NAVY2       = Color3.fromRGB(10, 28, 44)
local WHITE       = Color3.fromRGB(230, 248, 255)

local existing = PlayerGui:FindFirstChild("WaterVS_Reset")
if existing then existing:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "WaterVS_Reset"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local PANEL_W = isMobile and 160 or 180
local PANEL_H = isMobile and 60 or 66

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position = UDim2.new(0.5, -PANEL_W/2, 0.8, 0)
panel.BackgroundColor3 = NAVY
panel.BorderSizePixel = 0
panel.Active = true
panel.ClipsDescendants = true
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Thickness = 1.5
stroke.Color = CYAN
stroke.Parent = panel

-- subtle title mark
local brand = Instance.new("TextLabel")
brand.Size = UDim2.new(1, 0, 0, 12)
brand.Position = UDim2.new(0, 0, 0, 2)
brand.BackgroundTransparency = 1
brand.Text = "Water.vs"
brand.Font = Enum.Font.GothamBold
brand.TextSize = 9
brand.TextColor3 = CYAN
brand.TextTransparency = 0.25
brand.Parent = panel

local button = Instance.new("TextButton")
button.Size = UDim2.new(1, -20, 1, -22)
button.Position = UDim2.new(0, 10, 0, 14)
button.BackgroundColor3 = CYAN_DEEP
button.BorderSizePixel = 0
button.Text = "RESET"
button.Font = Enum.Font.GothamBold
button.TextSize = isMobile and 18 or 20
button.TextColor3 = WHITE
button.AutoButtonColor = false
button.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = button

button.MouseEnter:Connect(function()
    TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = CYAN_DARK}):Play()
end)
button.MouseLeave:Connect(function()
    TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = CYAN_DEEP}):Play()
end)

button.MouseButton1Click:Connect(function()
    TweenService:Create(button, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(0, 60, 100)}):Play()
    task.delay(0.08, function()
        TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = CYAN_DEEP}):Play()
    end)
    ResetPlayer()
end)

-- drag
local dragging = false
local dragStart = nil
local startPos = nil

panel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = panel.Position
    end
end)

panel.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - dragStart
    panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end)

-- WATER DRIP ANIMATION
task.spawn(function()
    while panel and panel.Parent do
        local abs = panel.AbsoluteSize
        if abs.X > 20 and abs.Y > 20 then
            for _ = 1, math.random(1, 2) do
                local size = math.random(2, 5)
                local drop = Instance.new("Frame")
                drop.Name = "WaterDrip"
                drop.Size = UDim2.fromOffset(size, size + math.random(1, 5))
                drop.BackgroundColor3 = CYAN
                drop.BackgroundTransparency = 0.25
                drop.BorderSizePixel = 0
                drop.ZIndex = 50
                drop.Parent = panel
                local c = Instance.new("UICorner")
                c.CornerRadius = UDim.new(1, 0)
                c.Parent = drop
                local startX = math.random(6, math.max(8, abs.X - 8))
                drop.Position = UDim2.fromOffset(startX, -size)
                local duration = math.random(12, 22) / 10
                local tw = TweenService:Create(drop, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = UDim2.fromOffset(startX + math.random(-4, 4), abs.Y + size + 6),
                    BackgroundTransparency = 0.9,
                    Size = UDim2.fromOffset(math.max(1, size - 1), size + math.random(6, 12))
                })
                tw:Play()
                tw.Completed:Connect(function()
                    if drop and drop.Parent then drop:Destroy() end
                end)
            end
        end
        task.wait(math.random(7, 14) / 10)
    end
end)

_G.FrameResetLite = {
    Reset = ResetPlayer,
    Stop = StopResetSequence,
}

print("[Water.vs] Reset Lite loaded")
