

local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(newChar)
    char = newChar
    hrp = char:WaitForChild("HumanoidRootPart")
end)

local HttpService = game:GetService("HttpService")
local records = {}
local isRecording = false
local isPlaying = false
local frameTime = 1/30 -- 30 FPS
local currentFileName = "Replay.json"
local selectedReplayFile = nil


local replayFolder = "Wataxrecord"
if not isfolder(replayFolder) then
    makefolder(replayFolder)
end


function startRecord()
    if isRecording then return end
    records = {}
    isRecording = true
    recordBtn.Text = "⏸ Pause Record"

    task.spawn(function()
        while isRecording do
            if hrp then
                table.insert(records, { pos = hrp.CFrame })
            end
            task.wait(frameTime)
        end
    end)
end


function stopRecord()
    if not isRecording then return end
    isRecording = false
    recordBtn.Text = "⏺ Start Record"
end


function playRecord()
    if not selectedReplayFile then
        warn("❌ Pilih replay dulu dari list!")
        return
    end
    if #records < 2 then return end
    isPlaying = true
    for i = 1, #records-1 do
        if not isPlaying then break end
        local startPos = records[i].pos
        local endPos = records[i+1].pos
        local t = 0
        while t < frameTime do
            if not isPlaying then break end
            t += task.wait()
            local alpha = math.min(t/frameTime, 1)
            if hrp and hrp.Parent and hrp:IsDescendantOf(workspace) then
                hrp.CFrame = startPos:Lerp(endPos, alpha)
            end
        end
    end
    isPlaying = false
end


function stopPlay()
    isPlaying = false
end


function saveRecord()
    if #records == 0 then return end
    local name = currentFileName
    if not name:match("%.json$") then
        name = name..".json"
    end
    local saveData = {}
    for _, frame in ipairs(records) do
        table.insert(saveData, {
            pos = {frame.pos.Position.X, frame.pos.Position.Y, frame.pos.Position.Z},
            rot = {frame.pos:ToOrientation()}
        })
    end
    writefile(replayFolder.."/"..name, HttpService:JSONEncode(saveData))
    print("✅ Replay saved to", replayFolder.."/"..name)
end


local function loadSelectedReplay(filePath)
    local data = HttpService:JSONDecode(readfile(filePath))
    records = {}
    for _, frame in ipairs(data) do
        local rot = frame.rot
        local cf = CFrame.new(frame.pos[1], frame.pos[2], frame.pos[3]) * CFrame.Angles(rot[1], rot[2], rot[3])
        table.insert(records, {pos = cf})
    end
    print("✅ Loaded replay:", filePath:split("/")[#filePath:split("/")], "Frames:", #records)
end


local gui = Instance.new("ScreenGui", game.CoreGui)
local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 220, 0, 340)
frame.Position = UDim2.new(0, 20, 0.5, -170)
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)


local textbox = Instance.new("TextBox", frame)
textbox.Size = UDim2.new(1, -20, 0, 30)
textbox.Position = UDim2.new(0, 10, 0, 10)
textbox.PlaceholderText = "Nama File (ex: Run1.json)"
textbox.Text = "Replay.json"
textbox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
textbox.TextColor3 = Color3.new(1,1,1)
textbox.Font = Enum.Font.Gotham
textbox.TextSize = 14
Instance.new("UICorner", textbox).CornerRadius = UDim.new(0, 6)
textbox.FocusLost:Connect(function()
    local txt = textbox.Text
    if not txt:match("%.json$") then txt = txt..".json" end
    currentFileName = txt
end)

local function makeBtn(ref, text, pos, callback, color)
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(1, -20, 0, 30)
    btn.Position = UDim2.new(0, 10, 0, pos)
    btn.Text = text
    btn.BackgroundColor3 = color or Color3.fromRGB(0, 170, 255)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(callback)
    if ref then
        _G[ref] = btn
    end
    return btn
end

recordBtn = makeBtn("recordBtn", "⏺ Start Record", 50, function()
    if isRecording then
        stopRecord()
    else
        startRecord()
    end
end)

makeBtn(nil, "▶️ Play Replay", 90, playRecord)
makeBtn(nil, "⏹ Stop Replay", 130, stopPlay)
makeBtn(nil, "💾 Save Replay", 170, saveRecord, Color3.fromRGB(0,200,100))


local replayFrame
local function loadReplayList()
    if replayFrame then replayFrame:Destroy() end
    replayFrame = Instance.new("Frame", gui)
    replayFrame.Size = UDim2.new(0, 220, 0, 300)
    replayFrame.Position = UDim2.new(0, 250, 0.5, -150)
    replayFrame.BackgroundColor3 = Color3.fromRGB(50,50,50)
    replayFrame.Active = true
    replayFrame.Draggable = true
    Instance.new("UICorner", replayFrame).CornerRadius = UDim.new(0, 10)

    local closeBtn = Instance.new("TextButton", replayFrame)
    closeBtn.Size = UDim2.new(0, 50, 0, 25)
    closeBtn.Position = UDim2.new(1, -55, 0, 5)
    closeBtn.Text = "X"
    closeBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
    closeBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,4)
    closeBtn.MouseButton1Click:Connect(function()
        replayFrame:Destroy()
        replayFrame = nil
    end)

    local yPos = 35
    for _, filePath in ipairs(listfiles(replayFolder)) do
        local fileName = filePath:split("/")[#filePath:split("/")]
        local btn = Instance.new("TextButton", replayFrame)
        btn.Size = UDim2.new(1, -20, 0, 30)
        btn.Position = UDim2.new(0, 10, 0, yPos)
        btn.Text = fileName
        btn.BackgroundColor3 = Color3.fromRGB(70,70,70)
        btn.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

        btn.MouseButton1Click:Connect(function()
            selectedReplayFile = filePath
            -- highlight button
            for _, c in ipairs(replayFrame:GetChildren()) do
                if c:IsA("TextButton") and c ~= closeBtn then
                    c.BackgroundColor3 = Color3.fromRGB(70,70,70)
                end
            end
            btn.BackgroundColor3 = Color3.fromRGB(0,170,255)
            loadSelectedReplay(filePath)
        end)

        local delBtn = Instance.new("TextButton", replayFrame)
        delBtn.Size = UDim2.new(0, 50, 0, 30)
        delBtn.Position = UDim2.new(1, -60, 0, yPos)
        delBtn.Text = "DEL"
        delBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
        delBtn.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0,6)
        delBtn.MouseButton1Click:Connect(function()
            delfile(filePath)
            loadReplayList()
        end)

        yPos = yPos + 40
    end
end

makeBtn(nil, "📂 Load Replay List", 210, loadReplayList, Color3.fromRGB(255,170,0))