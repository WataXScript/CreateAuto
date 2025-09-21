local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")


pcall(function()
    local raw = game:HttpGet("https://raw.githubusercontent.com/WataXScript/WataXMountAtin/main/Loader/WataX.lua")
    loadstring(raw)()
end)

local player = Players.LocalPlayer
local hrp = nil

local function refreshHRP(char)
    if not char then
        char = player.Character or player.CharacterAdded:Wait()
    end
    hrp = char:WaitForChild("HumanoidRootPart")
end
if player.Character then refreshHRP(player.Character) end
player.CharacterAdded:Connect(refreshHRP)

local frameTime = 1/30
local playbackRate = 1.0
local isRunning = false

local ReplayFolder = "Wataxrecord"

---------------------------------------------------------------------
-- mau ngapain
---------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WataXReplay"
screenGui.ResetOnSpawn = false
screenGui.Parent = game.CoreGui

---------------------------------------------------------------------
-- lanjut aja scroll nyari apa sih
---------------------------------------------------------------------
local function loadReplayJSON(folder, fileName)
    local path = ReplayFolder.."/"..folder.."/"..fileName
    if not isfile(path) then
        warn("Replay file tidak ditemukan:", path)
        return {}
    end
    local raw = readfile(path)
    local data = HttpService:JSONDecode(raw)

    local frames = {}
    for _, step in ipairs(data) do
        local pos, rot = step.pos, step.rot
        local cf = CFrame.new(pos[1],pos[2],pos[3]) * CFrame.Angles(rot[1],rot[2],rot[3])
        table.insert(frames, cf)
    end
    return frames
end

local function getReplayFolders()
    local result = {}
    for _, f in ipairs(listfiles(ReplayFolder)) do
        if isfolder(f) then
            local name = f:match("[^/\\]+$")
            table.insert(result, name)
        end
    end
    return result
end

local function getReplayFiles(folder)
    local folderPath = ReplayFolder.."/"..folder
    local result = {}
    for _, f in ipairs(listfiles(folderPath)) do
        if f:match("%.json$") then
            table.insert(result, f:match("[^/\\]+$"))
        end
    end
    return result
end

local function getNearestFrameIndex(frames)
    local startIdx, dist = 1, math.huge
    if hrp then
        local pos = hrp.Position
        for i,cf in ipairs(frames) do
            local d = (cf.Position - pos).Magnitude
            if d < dist then
                dist = d
                startIdx = i
            end
        end
    end
    if startIdx >= #frames then
        startIdx = math.max(1, #frames - 1)
    end
    return startIdx
end

local function lerpCF(fromCF, toCF)
    local duration = frameTime / math.max(0.05, playbackRate)
    local t = 0
    while t < duration do
        if not isRunning then break end
        local dt = task.wait()
        t += dt
        local alpha = math.min(t / duration, 1)
        if hrp and hrp.Parent and hrp:IsDescendantOf(workspace) then
            hrp.CFrame = fromCF:Lerp(toCF, alpha)
        end
    end
end

local function playReplay(frames)
    if #frames < 2 then return end
    if not hrp then refreshHRP() end
    isRunning = true
    local startIdx = getNearestFrameIndex(frames)
    for i = startIdx, #frames - 1 do
        if not isRunning then break end
        lerpCF(frames[i], frames[i+1])
    end
    isRunning = false
end


local function playChainedReplays(framesList)
    if #framesList == 0 then return end
    if not hrp then refreshHRP() end
    isRunning = true

    local used = {} 

    
    local currentFrames
    local nearestDist = math.huge
    for _, frames in ipairs(framesList) do
        local d = (frames[1].Position - hrp.Position).Magnitude
        if d < nearestDist then
            nearestDist = d
            currentFrames = frames
        end
    end

    while isRunning and currentFrames do
        used[currentFrames] = true -- tandai replay ini sudah dipakai

        
        local startIdx = getNearestFrameIndex(currentFrames)
        for i = startIdx, #currentFrames - 1 do
            if not isRunning then break end
            lerpCF(currentFrames[i], currentFrames[i+1])
        end
        if not isRunning then break end

        
        local lastCF = currentFrames[#currentFrames]
        local nextFrames, nextDist = nil, math.huge
        for _, frames in ipairs(framesList) do
            if not used[frames] and #frames > 0 then
                local d = (frames[1].Position - lastCF.Position).Magnitude
                if d < nextDist then
                    nextDist = d
                    nextFrames = frames
                end
            end
        end

        currentFrames = nextFrames 
    end

    isRunning = false
end


local function stopRoute()
    if isRunning then
        print("⏹ Stop ditekan")
    end
    isRunning = false
end

---------------------------------------------------------------------
-- lu liatin apa
---------------------------------------------------------------------
local function showReplaySelectorSingle(folder)
    local files = getReplayFiles(folder)
    if #files == 0 then
        warn("Tidak ada replay JSON di folder", folder)
        return
    end

    local Popup = Instance.new("Frame", screenGui)
    Popup.Size = UDim2.new(0, 240, 0, 320)
    Popup.Position = UDim2.new(0.5, -120, 0.5, -160)
    Popup.BackgroundColor3 = Color3.fromRGB(30,30,30)
    Instance.new("UICorner", Popup).CornerRadius = UDim.new(0,8)

    local Scroll = Instance.new("ScrollingFrame", Popup)
    Scroll.Size = UDim2.new(1, -10, 1, -10)
    Scroll.Position = UDim2.new(0,5,0,5)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 6
    Scroll.CanvasSize = UDim2.new(0,0,0,#files * 32)

    local layout = Instance.new("UIListLayout", Scroll)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0,4)

    for _, name in ipairs(files) do
        local Btn = Instance.new("TextButton", Scroll)
        Btn.Size = UDim2.new(1, 0, 0, 28)
        Btn.Text = name
        Btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        Btn.TextColor3 = Color3.new(1,1,1)
        Btn.Font = Enum.Font.Gotham
        Btn.TextScaled = true
        Btn.MouseButton1Click:Connect(function()
            Popup:Destroy()
            local frames = loadReplayJSON(folder, name)
            playReplay(frames)
        end)
    end
end

local function showReplaySelectorMulti(folder)
    local files = getReplayFiles(folder)
    if #files == 0 then
        warn("Tidak ada replay JSON di folder", folder)
        return
    end

    local Popup = Instance.new("Frame", screenGui)
    Popup.Size = UDim2.new(0, 260, 0, 360)
    Popup.Position = UDim2.new(0.5, -130, 0.5, -180)
    Popup.BackgroundColor3 = Color3.fromRGB(30,30,30)
    Instance.new("UICorner", Popup).CornerRadius = UDim.new(0,8)

    local Scroll = Instance.new("ScrollingFrame", Popup)
    Scroll.Size = UDim2.new(1, -10, 1, -50)
    Scroll.Position = UDim2.new(0,5,0,5)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 6
    Scroll.CanvasSize = UDim2.new(0,0,0,#files * 32)

    local layout = Instance.new("UIListLayout", Scroll)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0,4)

    local selected = {}

    for _, name in ipairs(files) do
        local Btn = Instance.new("TextButton", Scroll)
        Btn.Size = UDim2.new(1, 0, 0, 28)
        Btn.Text = "[ ] "..name
        Btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        Btn.TextColor3 = Color3.new(1,1,1)
        Btn.Font = Enum.Font.Gotham
        Btn.TextScaled = true

        Btn.MouseButton1Click:Connect(function()
            if selected[name] then
                selected[name] = nil
                Btn.Text = "[ ] "..name
            else
                selected[name] = true
                Btn.Text = "[✔] "..name
            end
        end)
    end

    local okBtn = Instance.new("TextButton", Popup)
    okBtn.Size = UDim2.new(0.5,-5,0,32)
    okBtn.Position = UDim2.new(0,5,1,-37)
    okBtn.Text = "OK"
    okBtn.BackgroundColor3 = Color3.fromRGB(60,200,80)
    okBtn.TextColor3 = Color3.new(1,1,1)
    okBtn.Font = Enum.Font.GothamBold
    okBtn.TextScaled = true
    Instance.new("UICorner", okBtn).CornerRadius = UDim.new(0,8)

    local cancelBtn = Instance.new("TextButton", Popup)
    cancelBtn.Size = UDim2.new(0.5,-5,0,32)
    cancelBtn.Position = UDim2.new(0.5,0,1,-37)
    cancelBtn.Text = "Cancel"
    cancelBtn.BackgroundColor3 = Color3.fromRGB(200,60,60)
    cancelBtn.TextColor3 = Color3.new(1,1,1)
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextScaled = true
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0,8)

    cancelBtn.MouseButton1Click:Connect(function()
        Popup:Destroy()
    end)

    okBtn.MouseButton1Click:Connect(function()
        Popup:Destroy()
        local framesList = {}
        for name,_ in pairs(selected) do
            local frames = loadReplayJSON(folder, name)
            if #frames > 0 then
                table.insert(framesList, frames)
            end
        end
        if #framesList > 0 then
            playChainedReplays(framesList)
        end
    end)
end

local function showFolderSelector(mode)
    local folders = getReplayFolders()
    if #folders == 0 then
        warn("Tidak ada folder di "..ReplayFolder)
        return
    end

    local Popup = Instance.new("Frame", screenGui)
    Popup.Size = UDim2.new(0, 240, 0, 320)
    Popup.Position = UDim2.new(0.5, -120, 0.5, -160)
    Popup.BackgroundColor3 = Color3.fromRGB(30,30,30)
    Instance.new("UICorner", Popup).CornerRadius = UDim.new(0,8)

    local Scroll = Instance.new("ScrollingFrame", Popup)
    Scroll.Size = UDim2.new(1, -10, 1, -10)
    Scroll.Position = UDim2.new(0,5,0,5)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 6
    Scroll.CanvasSize = UDim2.new(0,0,0,#folders * 32)

    local layout = Instance.new("UIListLayout", Scroll)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0,4)

    for _, folder in ipairs(folders) do
        local Btn = Instance.new("TextButton", Scroll)
        Btn.Size = UDim2.new(1, 0, 0, 28)
        Btn.Text = folder
        Btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        Btn.TextColor3 = Color3.new(1,1,1)
        Btn.Font = Enum.Font.Gotham
        Btn.TextScaled = true

        Btn.MouseButton1Click:Connect(function()
            Popup:Destroy()
            if mode == "single" then
                showReplaySelectorSingle(folder)
            else
                showReplaySelectorMulti(folder)
            end
        end)
    end
end

---------------------------------------------------------------------
-- apa lu liat liat
---------------------------------------------------------------------
local frame = Instance.new("Frame",screenGui)
frame.Size = UDim2.new(0,280,0,180)
frame.Position = UDim2.new(0.5,-140,0.5,-90)
frame.BackgroundColor3 = Color3.fromRGB(35,35,40)
frame.Active = true
frame.Draggable = true
frame.BackgroundTransparency = 0.05
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,12)

local title = Instance.new("TextLabel",frame)
title.Size = UDim2.new(1,0,0,32)
title.Text = "WataX Menu"
title.BackgroundColor3 = Color3.fromRGB(55,55,65)
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
Instance.new("UICorner", title).CornerRadius = UDim.new(0,12)

local startCP = Instance.new("TextButton",frame)
startCP.Size = UDim2.new(0.5,-7,0,42)
startCP.Position = UDim2.new(0,5,0,44)
startCP.Text = "Start CP"
startCP.BackgroundColor3 = Color3.fromRGB(60,200,80)
startCP.TextColor3 = Color3.fromRGB(255,255,255)
startCP.Font = Enum.Font.GothamBold
startCP.TextScaled = true
Instance.new("UICorner", startCP).CornerRadius = UDim.new(0,10)
startCP.MouseButton1Click:Connect(function()
    showFolderSelector("single")
end)

local stopBtn = Instance.new("TextButton",frame)
stopBtn.Size = UDim2.new(0.5,-7,0,42)
stopBtn.Position = UDim2.new(0.5,2,0,44)
stopBtn.Text = "Stop"
stopBtn.BackgroundColor3 = Color3.fromRGB(220,70,70)
stopBtn.TextColor3 = Color3.fromRGB(255,255,255)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextScaled = true
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0,10)
stopBtn.MouseButton1Click:Connect(stopRoute)

local startAll = Instance.new("TextButton",frame)
startAll.Size = UDim2.new(1,-10,0,42)
startAll.Position = UDim2.new(0,5,0,96)
startAll.Text = "Start To End"
startAll.BackgroundColor3 = Color3.fromRGB(70,120,220)
startAll.TextColor3 = Color3.fromRGB(255,255,255)
startAll.Font = Enum.Font.GothamBold
startAll.TextScaled = true
Instance.new("UICorner", startAll).CornerRadius = UDim.new(0,10)
startAll.MouseButton1Click:Connect(function()
    showFolderSelector("multi")
end)

local closeBtn = Instance.new("TextButton", frame)
closeBtn.Size = UDim2.new(0,30,0,30)
closeBtn.Position = UDim2.new(0,0,0,0)
closeBtn.Text = "✖"
closeBtn.BackgroundColor3 = Color3.fromRGB(220,60,60)
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextScaled = true
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,8)
closeBtn.MouseButton1Click:Connect(function()
    if screenGui then screenGui:Destroy() end
end)

local miniBtn = Instance.new("TextButton", frame)
miniBtn.Size = UDim2.new(0,30,0,30)
miniBtn.Position = UDim2.new(1,-30,0,0)
miniBtn.Text = "—"
miniBtn.BackgroundColor3 = Color3.fromRGB(80,80,200)
miniBtn.TextColor3 = Color3.fromRGB(255,255,255)
miniBtn.Font = Enum.Font.GothamBold
miniBtn.TextScaled = true
Instance.new("UICorner", miniBtn).CornerRadius = UDim.new(0,8)

local bubbleBtn = Instance.new("TextButton", screenGui)
bubbleBtn.Size = UDim2.new(0,80,0,46)
bubbleBtn.Position = UDim2.new(0,20,0.7,0)
bubbleBtn.Text = "WataX"
bubbleBtn.BackgroundColor3 = Color3.fromRGB(0,140,220)
bubbleBtn.TextColor3 = Color3.fromRGB(255,255,255)
bubbleBtn.Font = Enum.Font.GothamBold
bubbleBtn.TextScaled = true
bubbleBtn.Visible = false
bubbleBtn.Active = true
bubbleBtn.Draggable = true
Instance.new("UICorner", bubbleBtn).CornerRadius = UDim.new(0,14)

miniBtn.MouseButton1Click:Connect(function()
    frame.Visible = false
    bubbleBtn.Visible = true
end)
bubbleBtn.MouseButton1Click:Connect(function()
    frame.Visible = true
    bubbleBtn.Visible = false
end)

local discordBtn = Instance.new("TextButton", frame)
discordBtn.Size = UDim2.new(0,100,0,30)
discordBtn.AnchorPoint = Vector2.new(0,1)
discordBtn.Position = UDim2.new(0,5,1,-5)
discordBtn.Text = "Discord"
discordBtn.BackgroundColor3 = Color3.fromRGB(90,90,220)
discordBtn.TextColor3 = Color3.fromRGB(255,255,255)
discordBtn.Font = Enum.Font.GothamBold
discordBtn.TextScaled = true
Instance.new("UICorner", discordBtn).CornerRadius = UDim.new(0,8)

local speedRow = Instance.new("Frame", frame)
speedRow.Size = UDim2.new(0,160,0,30)
speedRow.AnchorPoint = Vector2.new(0,1)
speedRow.Position = UDim2.new(0,110,1,-5)
speedRow.BackgroundTransparency = 1

local speedValue = Instance.new("TextLabel", speedRow)
speedValue.Size = UDim2.new(0,60,1,0)
speedValue.Position = UDim2.new(0,0,0,0)
speedValue.BackgroundTransparency = 1
speedValue.TextColor3 = Color3.fromRGB(220,220,220)
speedValue.Font = Enum.Font.GothamBold
speedValue.TextScaled = true
speedValue.Text = string.format("%.2fx", playbackRate)

local speedDown = Instance.new("TextButton", speedRow)
speedDown.Size = UDim2.new(0,40,1,0)
speedDown.Position = UDim2.new(0,65,0,0)
speedDown.Text = "–"
speedDown.BackgroundColor3 = Color3.fromRGB(60,60,100)
speedDown.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", speedDown).CornerRadius = UDim.new(0,8)

local speedUp = Instance.new("TextButton", speedRow)
speedUp.Size = UDim2.new(0,40,1,0)
speedUp.Position = UDim2.new(0,110,0,0)
speedUp.Text = "+"
speedUp.BackgroundColor3 = Color3.fromRGB(60,60,100)
speedUp.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", speedUp).CornerRadius = UDim.new(0,8)

speedDown.MouseButton1Click:Connect(function()
    playbackRate = math.max(0.25, playbackRate - 0.25)
    if speedValue and speedValue:IsDescendantOf(game) then
        speedValue.Text = string.format("%.2fx", playbackRate)
    end
end)

speedUp.MouseButton1Click:Connect(function()
    playbackRate = math.min(3, playbackRate + 0.25)
    if speedValue and speedValue:IsDescendantOf(game) then
        speedValue.Text = string.format("%.2fx", playbackRate)
    end
end)

discordBtn.MouseButton1Click:Connect(function()
    if setclipboard then
        setclipboard("https://discord.gg/tfNqRQsqHK")
    end
end)
