repeat task.wait() until game:IsLoaded()

local S = {
	Players           = game:GetService("Players"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	RunService        = game:GetService("RunService"),
	UserInputService  = game:GetService("UserInputService"),
	TweenService      = game:GetService("TweenService"),
}

local Packages    = S.ReplicatedStorage:WaitForChild("Packages")
local Datas       = S.ReplicatedStorage:WaitForChild("Datas")
local AnimalsData = require(Datas:WaitForChild("Animals"))
S.LocalPlayer     = S.Players.LocalPlayer
local plots       = workspace:WaitForChild("Plots")

local function getWaterLogo()
	local LOGO = "WaterVS_logo.png"
	local asset = ""
	for _, p in ipairs({LOGO, "Workspace/"..LOGO, "workspace/"..LOGO}) do
		pcall(function()
			if asset == "" and getcustomasset and isfile and isfile(p) then
				asset = getcustomasset(p)
			end
		end)
		if asset ~= "" then break end
	end
	return asset
end
local WATER_LOGO = getWaterLogo()

local CONFIG = {
	AUTO_STEAL_ENABLED = true,
	HOLD_MIN = 1.3,
	HOLD_MAX = 2.6,
	ENTRY_DELAY = 0.3,
	COOLDOWN = 0.05,
	STEAL_RANGE = 10,
	PRIME_RANGE = 80,
}

-- SYNCHRONIZER
local syncRemotes = (function()
	local folder = Packages:WaitForChild("Synchronizer")
	return {
		channelFolder = folder:WaitForChild("Channel"),
		routeRemote   = folder:WaitForChild("CommunicationRoute"),
		requestData   = folder:FindFirstChild("RequestData"),
	}
end)()

local plotAnimalSync = { caches = {}, connections = {} }

local function splitSyncPath(path)
	if typeof(path) == "table" then return path end
	local out = {}
	for part in string.gmatch(tostring(path), "[^%.]+") do
		table.insert(out, tonumber(part) or part)
	end
	return out
end

local function resolveSyncPath(path, root)
	local current, parent, key = root, nil, nil
	for _, part in ipairs(splitSyncPath(path)) do
		parent = current; key = part
		current = current and current[part] or nil
	end
	return current, parent, key
end

local function applyPlotSyncDiff(channelName, packet)
	local cache = plotAnimalSync.caches[channelName]
	if typeof(cache) ~= "table" then return end
	local path, action, a, b = packet[1], packet[2], packet[3], packet[4]
	local current, parent, key = resolveSyncPath(path, cache)
	if action == "Changed" then
		if parent ~= nil then parent[key] = a end
	elseif action == "ArrayInsert" then
		if current ~= nil then table.insert(current, b, a) end
	elseif action == "ArrayRemoved" then
		if current ~= nil then table.remove(current, b) end
	elseif action == "DictionaryInsert" then
		if current ~= nil then current[b] = a end
	elseif action == "DictionaryRemoved" then
		if current ~= nil then current[b] = nil end
	end
end

local function attachPlotChannel(remote)
	if plotAnimalSync.connections[remote] then return end
	local channelName = tostring(remote.Name)
	if not plots:FindFirstChild(channelName) then return end
	if syncRemotes.requestData and plotAnimalSync.caches[channelName] == nil then
		local ok, data = pcall(function()
			return syncRemotes.requestData:InvokeServer(channelName)
		end)
		plotAnimalSync.caches[channelName] = (ok and typeof(data) == "table") and data or {}
	elseif plotAnimalSync.caches[channelName] == nil then
		plotAnimalSync.caches[channelName] = {}
	end
	plotAnimalSync.connections[remote] = remote.OnClientEvent:Connect(function(queue)
		for _, packet in ipairs(queue) do
			applyPlotSyncDiff(channelName, packet)
		end
	end)
end

local function detachPlotChannel(channelName)
	for remote, conn in pairs(plotAnimalSync.connections) do
		if tostring(remote.Name) == tostring(channelName) then
			conn:Disconnect()
			plotAnimalSync.connections[remote] = nil
			plotAnimalSync.caches[tostring(channelName)] = nil
			break
		end
	end
end

for _, child in ipairs(syncRemotes.channelFolder:GetChildren()) do
	if child:IsA("RemoteEvent") then attachPlotChannel(child) end
end
syncRemotes.channelFolder.ChildAdded:Connect(function(child)
	if child:IsA("RemoteEvent") then attachPlotChannel(child) end
end)
syncRemotes.routeRemote.OnClientEvent:Connect(function(actions)
	for _, action in ipairs(actions) do
		local kind, channelName = action[1], tostring(action[2])
		if not plots:FindFirstChild(channelName) then continue end
		if kind == "ListenerAdded" then
			local remote = syncRemotes.channelFolder:FindFirstChild(channelName)
			if remote and remote:IsA("RemoteEvent") then attachPlotChannel(remote) end
		elseif kind == "ListenerRemoved" then
			detachPlotChannel(channelName)
		end
	end
end)

local function getPlotChannelData(plotName)
	return plotAnimalSync.caches[plotName]
end

-- STEAL ENGINE
local allAnimalsCache    = {}
local PromptMemoryCache  = {}
local InternalStealCache = {}
local stealConnection    = nil

local StealState = {
	active = false,
	startTime = 0,
	phase = "idle",
	label = "",
	lastResult = "",
	lastResultTime = 0,
	totalSteals = 0,
	failedSteals = 0,
}

local function getHRP()
	local char = S.LocalPlayer.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
end

local function getPlotOwner(plot)
	local sign  = plot:FindFirstChild("PlotSign")
	local frame = sign and sign:FindFirstChild("SurfaceGui") and sign.SurfaceGui:FindFirstChild("Frame")
	local label = frame and frame:FindFirstChild("TextLabel")
	if not label or label.Text == "Empty Base" then return nil end
	return label.Text:gsub("'s [Bb]ase$", ""):gsub("%s+$", "")
end

local function isMyBaseAnimal(animalData)
	if not animalData or not animalData.plot then return false end
	local plot = plots:FindFirstChild(animalData.plot)
	if not plot then return false end
	return getPlotOwner(plot) == S.LocalPlayer.DisplayName
end

local function findProximityPromptForAnimal(animalData)
	if not animalData then return nil end
	local cached = PromptMemoryCache[animalData.uid]
	if cached and cached.Parent then return cached end
	local plot    = plots:FindFirstChild(animalData.plot); if not plot then return nil end
	local podiums = plot:FindFirstChild("AnimalPodiums"); if not podiums then return nil end
	local podium  = podiums:FindFirstChild(animalData.slot); if not podium then return nil end
	local base    = podium:FindFirstChild("Base"); if not base then return nil end
	local spawn   = base:FindFirstChild("Spawn"); if not spawn then return nil end
	local attach  = spawn:FindFirstChild("PromptAttachment"); if not attach then return nil end
	for _, p in ipairs(attach:GetChildren()) do
		if p:IsA("ProximityPrompt") then
			PromptMemoryCache[animalData.uid] = p
			return p
		end
	end
	return nil
end

local function getAnimalPosition(animalData)
	local plot    = plots:FindFirstChild(animalData.plot); if not plot then return nil end
	local podiums = plot:FindFirstChild("AnimalPodiums"); if not podiums then return nil end
	local podium  = podiums:FindFirstChild(animalData.slot); if not podium then return nil end
	return podium:GetPivot().Position
end

local function distToAnimal(animalData)
	local hrp = getHRP(); if not hrp then return math.huge end
	local pos = getAnimalPosition(animalData); if not pos then return math.huge end
	return (hrp.Position - pos).Magnitude
end

local function pickClosest()
	local hrp = getHRP(); if not hrp then return nil end
	local best, bestDist = nil, math.huge
	for _, animalData in ipairs(allAnimalsCache) do
		if isMyBaseAnimal(animalData) then continue end
		local pos = getAnimalPosition(animalData); if not pos then continue end
		local dist = (hrp.Position - pos).Magnitude
		if dist > CONFIG.PRIME_RANGE then continue end
		if dist < bestDist then
			bestDist = dist
			best = animalData
		end
	end
	return best
end

local function buildStealCallbacks(prompt)
	if InternalStealCache[prompt] then return end
	local data = { holdCallbacks = {}, triggerCallbacks = {}, ready = true }
	if getconnections then
		local ok1, conns1 = pcall(getconnections, prompt.PromptButtonHoldBegan)
		if ok1 and type(conns1) == "table" then
			for _, conn in ipairs(conns1) do
				if type(conn.Function) == "function" then
					table.insert(data.holdCallbacks, conn.Function)
				end
			end
		end
		local ok2, conns2 = pcall(getconnections, prompt.Triggered)
		if ok2 and type(conns2) == "table" then
			for _, conn in ipairs(conns2) do
				if type(conn.Function) == "function" then
					table.insert(data.triggerCallbacks, conn.Function)
				end
			end
		end
	end
	if (#data.holdCallbacks > 0) or (#data.triggerCallbacks > 0) then
		InternalStealCache[prompt] = data
	end
end

local function executeStealAsync(prompt, animalData)
	local data = InternalStealCache[prompt]
	if not data or not data.ready then return false end
	data.ready = false
	local label = animalData.name or "Animal"
	StealState.active = true
	StealState.startTime = tick()
	StealState.phase = "holding"
	StealState.label = label

	task.spawn(function()
		for _, fn in ipairs(data.holdCallbacks) do
			task.spawn(fn)
		end
		task.wait(CONFIG.HOLD_MIN)
		StealState.phase = "waitingRange"
		local alreadyInRange = distToAnimal(animalData) <= CONFIG.STEAL_RANGE
		local fired = false
		while true do
			local elapsed = tick() - StealState.startTime
			if elapsed > CONFIG.HOLD_MAX then break end
			if not prompt.Parent then break end
			if distToAnimal(animalData) <= CONFIG.STEAL_RANGE then
				if not alreadyInRange then
					task.wait(CONFIG.ENTRY_DELAY)
				end
				for _, fn in ipairs(data.triggerCallbacks) do
					task.spawn(fn)
				end
				fired = true
				break
			end
			task.wait()
		end
		if fired then
			StealState.totalSteals = StealState.totalSteals + 1
			StealState.lastResult = "Stole " .. label
		else
			StealState.failedSteals = StealState.failedSteals + 1
			StealState.lastResult = "Missed: " .. label
		end
		StealState.active = false
		StealState.phase = "idle"
		StealState.lastResultTime = tick()
		task.wait(CONFIG.COOLDOWN)
		data.ready = true
	end)
	return true
end

local function attemptSteal(prompt, animalData)
	if not prompt or not prompt.Parent then return false end
	buildStealCallbacks(prompt)
	if not InternalStealCache[prompt] then return false end
	return executeStealAsync(prompt, animalData)
end

local function scanAllPlots()
	local newCache = {}
	for _, plot in ipairs(plots:GetChildren()) do
		local cache = getPlotChannelData(plot.Name)
		if not cache then continue end
		local animalList = cache.AnimalList
		if typeof(animalList) ~= "table" then continue end
		for slot, animalData in pairs(animalList) do
			if type(animalData) == "table" then
				local animalName = animalData.Index
				local animalInfo = AnimalsData[animalName]
				if not animalInfo then continue end
				table.insert(newCache, {
					name = animalInfo.DisplayName or animalName,
					plot = plot.Name,
					slot = tostring(slot),
					uid  = plot.Name .. "_" .. tostring(slot),
				})
			end
		end
	end
	allAnimalsCache = newCache
	return #allAnimalsCache
end

local function startAutoSteal()
	if stealConnection then return end
	stealConnection = S.RunService.Heartbeat:Connect(function()
		if not CONFIG.AUTO_STEAL_ENABLED then return end
		if StealState.active then return end
		local target = pickClosest()
		if not target then return end
		local prompt = PromptMemoryCache[target.uid]
		if not prompt or not prompt.Parent then
			prompt = findProximityPromptForAnimal(target)
		end
		if prompt then
			attemptSteal(prompt, target)
		end
	end)
end

local function stopAutoSteal()
	if not stealConnection then return end
	stealConnection:Disconnect()
	stealConnection = nil
end

-- ============================================================
-- PREMIUM WATER.VS UI
-- ============================================================
local function createUI()
	local existing = S.LocalPlayer.PlayerGui:FindFirstChild("WaterVS_AutoGrabGui")
	if existing then existing:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WaterVS_AutoGrabGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 999
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = S.LocalPlayer:WaitForChild("PlayerGui")

	local TS = S.TweenService

	local C = {
		bg        = Color3.fromRGB(5, 12, 22),
		bgSoft    = Color3.fromRGB(10, 22, 38),
		panel     = Color3.fromRGB(8, 18, 32),
		cyan      = Color3.fromRGB(0, 210, 255),
		cyanSoft  = Color3.fromRGB(0, 170, 220),
		cyanGlow  = Color3.fromRGB(120, 240, 255),
		white     = Color3.fromRGB(240, 250, 255),
		dim       = Color3.fromRGB(120, 170, 195),
		muted     = Color3.fromRGB(70, 110, 140),
		orange    = Color3.fromRGB(255, 180, 60),
		green     = Color3.fromRGB(60, 230, 140),
		red       = Color3.fromRGB(255, 100, 110),
	}

	local function corner(p, r)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r)
		c.Parent = p
		return c
	end
	local function stroke(p, col, thick, alpha)
		local s = Instance.new("UIStroke")
		s.Color = col or C.cyan
		s.Thickness = thick or 1.2
		s.Transparency = alpha or 0.45
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = p
		return s
	end
	local function tw(obj, info, props)
		return TS:Create(obj, info, props)
	end

	local function makeDraggable(frame, handle)
		handle = handle or frame
		local dragging, dragStart, startPos
		handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = frame.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)
		S.UserInputService.InputChanged:Connect(function(input)
			if not dragging then return end
			if input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch then
				local delta = input.Position - dragStart
				frame.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y
				)
			end
		end)
	end

	-- MAIN CARD
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1.12, 0)
	card.Size = UDim2.new(0, 360, 0, 158)
	card.BackgroundColor3 = C.bg
	card.BackgroundTransparency = 0.02
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Parent = screenGui
	corner(card, 16)
	local cardStroke = stroke(card, C.cyan, 1.6, 0.35)

	-- soft vertical gradient
	local bgGrad = Instance.new("UIGradient", card)
	bgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 24, 42)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(5, 14, 26)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 10, 18)),
	})
	bgGrad.Rotation = 90

	-- logo bg (very faded)
	if WATER_LOGO ~= "" then
		local logoBg = Instance.new("ImageLabel", card)
		logoBg.Name = "LogoBg"
		logoBg.Size = UDim2.new(1, 0, 1, 0)
		logoBg.BackgroundTransparency = 1
		logoBg.Image = WATER_LOGO
		logoBg.ImageTransparency = 0.88
		logoBg.ScaleType = Enum.ScaleType.Crop
		logoBg.ZIndex = 0
	end

	-- top accent line
	local topLine = Instance.new("Frame", card)
	topLine.Size = UDim2.new(1, 0, 0, 2)
	topLine.BackgroundColor3 = C.cyan
	topLine.BackgroundTransparency = 0.25
	topLine.BorderSizePixel = 0
	topLine.ZIndex = 5
	local topGrad = Instance.new("UIGradient", topLine)
	topGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0),
		NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 1),
	})

	-- drag area
	local dragHandle = Instance.new("Frame", card)
	dragHandle.Size = UDim2.new(1, 0, 0, 52)
	dragHandle.BackgroundTransparency = 1
	dragHandle.ZIndex = 12
	makeDraggable(card, dragHandle)

	-- ICON
	local iconWrap = Instance.new("Frame", card)
	iconWrap.Size = UDim2.new(0, 36, 0, 36)
	iconWrap.Position = UDim2.new(0, 14, 0, 12)
	iconWrap.BackgroundColor3 = C.bgSoft
	iconWrap.BorderSizePixel = 0
	iconWrap.ZIndex = 6
	corner(iconWrap, 10)
	stroke(iconWrap, C.cyan, 1, 0.4)

	if WATER_LOGO ~= "" then
		local iconImg = Instance.new("ImageLabel", iconWrap)
		iconImg.Size = UDim2.new(1, -6, 1, -6)
		iconImg.Position = UDim2.new(0, 3, 0, 3)
		iconImg.BackgroundTransparency = 1
		iconImg.Image = WATER_LOGO
		iconImg.ScaleType = Enum.ScaleType.Fit
		iconImg.ZIndex = 7
	else
		local iconTxt = Instance.new("TextLabel", iconWrap)
		iconTxt.Size = UDim2.new(1, 0, 1, 0)
		iconTxt.BackgroundTransparency = 1
		iconTxt.Text = "W"
		iconTxt.TextColor3 = C.cyan
		iconTxt.TextSize = 18
		iconTxt.Font = Enum.Font.GothamBlack
		iconTxt.ZIndex = 7
	end

	-- TITLE
	local titleLabel = Instance.new("TextLabel", card)
	titleLabel.Size = UDim2.new(0, 220, 0, 20)
	titleLabel.Position = UDim2.new(0, 58, 0, 12)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Water.vs Auto Grab"
	titleLabel.TextColor3 = C.white
	titleLabel.TextSize = 15
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 6

	local subLabel = Instance.new("TextLabel", card)
	subLabel.Size = UDim2.new(0, 220, 0, 14)
	subLabel.Position = UDim2.new(0, 58, 0, 32)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = "Steal Engine"
	subLabel.TextColor3 = C.cyanSoft
	subLabel.TextSize = 11
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.ZIndex = 6

	-- TOGGLE
	local toggleTrack = Instance.new("TextButton", card)
	toggleTrack.Size = UDim2.new(0, 46, 0, 26)
	toggleTrack.Position = UDim2.new(1, -60, 0, 16)
	toggleTrack.BackgroundColor3 = C.cyan
	toggleTrack.BorderSizePixel = 0
	toggleTrack.ZIndex = 8
	toggleTrack.Text = ""
	toggleTrack.AutoButtonColor = false
	corner(toggleTrack, 13)

	local toggleThumb = Instance.new("Frame", toggleTrack)
	toggleThumb.Size = UDim2.new(0, 20, 0, 20)
	toggleThumb.Position = UDim2.new(0, 23, 0, 3)
	toggleThumb.BackgroundColor3 = C.white
	toggleThumb.BorderSizePixel = 0
	toggleThumb.ZIndex = 9
	corner(toggleThumb, 10)

	local function animateToggle(on)
		tw(toggleTrack, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			BackgroundColor3 = on and C.cyan or Color3.fromRGB(40, 55, 70)
		}):Play()
		tw(toggleThumb, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, on and 23 or 3, 0, 3)
		}):Play()
	end

	toggleTrack.MouseButton1Click:Connect(function()
		CONFIG.AUTO_STEAL_ENABLED = not CONFIG.AUTO_STEAL_ENABLED
		animateToggle(CONFIG.AUTO_STEAL_ENABLED)
		if CONFIG.AUTO_STEAL_ENABLED then
			startAutoSteal()
		else
			stopAutoSteal()
		end
	end)

	-- divider
	local div = Instance.new("Frame", card)
	div.Size = UDim2.new(1, -28, 0, 1)
	div.Position = UDim2.new(0, 14, 0, 54)
	div.BackgroundColor3 = C.cyan
	div.BackgroundTransparency = 0.75
	div.BorderSizePixel = 0
	div.ZIndex = 3
	local divGrad = Instance.new("UIGradient", div)
	divGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0),
		NumberSequenceKeypoint.new(0.85, 0),
		NumberSequenceKeypoint.new(1, 1),
	})

	-- status row
	local statusDot = Instance.new("Frame", card)
	statusDot.Size = UDim2.new(0, 8, 0, 8)
	statusDot.Position = UDim2.new(0, 16, 0, 68)
	statusDot.BackgroundColor3 = C.cyan
	statusDot.BorderSizePixel = 0
	statusDot.ZIndex = 6
	corner(statusDot, 4)

	local statusTxt = Instance.new("TextLabel", card)
	statusTxt.Size = UDim2.new(0, 160, 0, 16)
	statusTxt.Position = UDim2.new(0, 30, 0, 64)
	statusTxt.BackgroundTransparency = 1
	statusTxt.Text = "Scanning"
	statusTxt.TextColor3 = C.white
	statusTxt.TextSize = 12
	statusTxt.Font = Enum.Font.GothamMedium
	statusTxt.TextXAlignment = Enum.TextXAlignment.Left
	statusTxt.ZIndex = 6

	-- targets badge
	local countBadge = Instance.new("Frame", card)
	countBadge.Size = UDim2.new(0, 92, 0, 22)
	countBadge.Position = UDim2.new(1, -106, 0, 62)
	countBadge.BackgroundColor3 = C.bgSoft
	countBadge.BorderSizePixel = 0
	countBadge.ZIndex = 6
	corner(countBadge, 8)
	stroke(countBadge, C.cyan, 1, 0.7)

	local countTxt = Instance.new("TextLabel", countBadge)
	countTxt.Size = UDim2.new(1, 0, 1, 0)
	countTxt.BackgroundTransparency = 1
	countTxt.Text = "0 targets"
	countTxt.TextColor3 = C.dim
	countTxt.TextSize = 11
	countTxt.Font = Enum.Font.GothamMedium
	countTxt.ZIndex = 7

	-- progress bar
	local barBg = Instance.new("Frame", card)
	barBg.Size = UDim2.new(1, -28, 0, 10)
	barBg.Position = UDim2.new(0, 14, 0, 94)
	barBg.BackgroundColor3 = Color3.fromRGB(4, 12, 20)
	barBg.BorderSizePixel = 0
	barBg.ZIndex = 4
	barBg.ClipsDescendants = true
	corner(barBg, 5)
	stroke(barBg, Color3.fromRGB(20, 80, 110), 1, 0.5)

	local barFill = Instance.new("Frame", barBg)
	barFill.Size = UDim2.new(0, 0, 1, -2)
	barFill.Position = UDim2.new(0, 1, 0, 1)
	barFill.BackgroundColor3 = C.cyan
	barFill.BorderSizePixel = 0
	barFill.ZIndex = 5
	corner(barFill, 4)

	local fillGrad = Instance.new("UIGradient", barFill)
	fillGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.cyanSoft),
		ColorSequenceKeypoint.new(0.5, C.cyanGlow),
		ColorSequenceKeypoint.new(1, C.cyan),
	})

	-- result + steals
	local resultTxt = Instance.new("TextLabel", card)
	resultTxt.Size = UDim2.new(0.55, -14, 0, 16)
	resultTxt.Position = UDim2.new(0, 14, 0, 114)
	resultTxt.BackgroundTransparency = 1
	resultTxt.Text = ""
	resultTxt.TextColor3 = C.green
	resultTxt.TextSize = 11
	resultTxt.Font = Enum.Font.GothamMedium
	resultTxt.TextXAlignment = Enum.TextXAlignment.Left
	resultTxt.TextTruncate = Enum.TextTruncate.AtEnd
	resultTxt.ZIndex = 6

	local stealCountTxt = Instance.new("TextLabel", card)
	stealCountTxt.Size = UDim2.new(0.4, -10, 0, 16)
	stealCountTxt.Position = UDim2.new(0.58, 0, 0, 114)
	stealCountTxt.BackgroundTransparency = 1
	stealCountTxt.Text = "STEALS  0"
	stealCountTxt.TextColor3 = C.dim
	stealCountTxt.TextSize = 11
	stealCountTxt.Font = Enum.Font.GothamBold
	stealCountTxt.TextXAlignment = Enum.TextXAlignment.Right
	stealCountTxt.ZIndex = 6

	-- footer
	local creditTxt = Instance.new("TextLabel", card)
	creditTxt.Size = UDim2.new(1, -20, 0, 14)
	creditTxt.Position = UDim2.new(0, 10, 1, -20)
	creditTxt.BackgroundTransparency = 1
	creditTxt.Text = "Water.vs  ·  discord.gg/VyRHBRfB24"
	creditTxt.TextColor3 = C.muted
	creditTxt.TextSize = 10
	creditTxt.Font = Enum.Font.Gotham
	creditTxt.ZIndex = 6

	-- border breathe
	task.spawn(function()
		while cardStroke and cardStroke.Parent do
			tw(cardStroke, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.6}):Play()
			task.wait(1.6)
			tw(cardStroke, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.2}):Play()
			task.wait(1.6)
		end
	end)

	-- UI driver
	local prevFill = 0
	local prevDotColor = C.cyan
	local prevFillColor = C.cyan
	local dotPulse = 0

	S.RunService.RenderStepped:Connect(function(dt)
		local on = CONFIG.AUTO_STEAL_ENABLED
		local active = StealState.active
		local recent = StealState.lastResultTime > 0 and (tick() - StealState.lastResultTime) < 1.5
		local success = recent and string.find(StealState.lastResult, "Stole") ~= nil

		local targetFill = active
			and math.clamp((tick() - StealState.startTime) / CONFIG.HOLD_MAX, 0, 1)
			or (recent and 1 or 0)
		local speed = active and 10 or (recent and 0 or 18)
		prevFill = prevFill + (targetFill - prevFill) * math.min(dt * speed, 1)
		barFill.Size = UDim2.new(prevFill, 0, 1, -2)

		local tfc = active
			and (StealState.phase == "waitingRange" and C.orange or C.cyan)
			or (recent and (success and C.green or C.red) or C.cyan)
		prevFillColor = prevFillColor:Lerp(tfc, math.min(dt * 9, 1))
		barFill.BackgroundColor3 = prevFillColor

		local dotColor, statusStr
		if active then
			dotPulse = dotPulse + dt * 4
			local pulse = 0.5 + 0.5 * math.sin(dotPulse)
			dotColor = C.cyan:Lerp(C.cyanGlow, pulse)
			local pct = math.clamp((tick() - StealState.startTime) / CONFIG.HOLD_MAX, 0, 1)
			if StealState.phase == "waitingRange" then
				statusStr = string.format("Approaching  %.0f%%", pct * 100)
			else
				statusStr = string.format("Stealing  %.0f%%", pct * 100)
			end
		elseif recent then
			dotColor = success and C.green or C.red
			statusStr = success and ("Got " .. StealState.label) or "Missed window"
		elseif on then
			dotColor = C.cyan
			statusStr = "Scanning"
		else
			dotColor = C.muted
			statusStr = "Disabled"
		end

		prevDotColor = prevDotColor:Lerp(dotColor, math.min(dt * 10, 1))
		statusDot.BackgroundColor3 = prevDotColor
		statusTxt.Text = statusStr
		statusTxt.TextColor3 = active and C.white
			or (recent and (success and C.green or C.red) or C.white)

		countTxt.Text = tostring(#allAnimalsCache) .. " targets"
		stealCountTxt.Text = "STEALS  " .. StealState.totalSteals

		if recent then
			resultTxt.Text = StealState.lastResult
			resultTxt.TextColor3 = success and C.green or C.red
		elseif not active then
			resultTxt.Text = ""
		end
	end)

	-- slide in
	task.delay(0.05, function()
		tw(card, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.93, 0)
		}):Play()
	end)

	-- drips
	task.spawn(function()
		task.wait(1)
		while card and card.Parent do
			local abs = card.AbsoluteSize
			if abs.X > 40 then
				local size = math.random(3, 5)
				local drop = Instance.new("Frame")
				drop.Size = UDim2.fromOffset(size, size + math.random(2, 5))
				drop.BackgroundColor3 = C.cyan
				drop.BackgroundTransparency = 0.25
				drop.BorderSizePixel = 0
				drop.ZIndex = 40
				drop.Parent = card
				corner(drop, 99)
				local sx = math.random(12, math.max(16, abs.X - 12))
				drop.Position = UDim2.fromOffset(sx, -size)
				local anim = tw(drop, TweenInfo.new(math.random(16, 26)/10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.fromOffset(sx + math.random(-4, 4), abs.Y + 8),
					BackgroundTransparency = 0.92,
				})
				anim:Play()
				anim.Completed:Connect(function() if drop then drop:Destroy() end end)
			end
			task.wait(math.random(8, 15)/10)
		end
	end)
end

-- BOOT
task.spawn(function()
	while task.wait(5) do
		scanAllPlots()
	end
end)

createUI()
scanAllPlots()
if CONFIG.AUTO_STEAL_ENABLED then
	startAutoSteal()
end

print("[Water.vs] Auto Grab loaded")
