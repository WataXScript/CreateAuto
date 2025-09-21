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
local frameTime = 1/30 -- 30 FPS
local currentFileName = "Replay.json"
local replayFolder = "Wataxrecord"
local selectedReplayFile = nil

if not isfolder(replayFolder) then
    makefolder(replayFolder)
end

-- RECORD
local function startRecord()
    if isRecording then return end
    records = {}
    isRecording = true
    recordBtn.Text = "⏹ Stop Record"

    task.spawn(function()
        while isRecording do
            if hrp then
                table.insert(records, { pos = hrp.CFrame })
            end
            task.wait(frameTime)
        end
    end)
end

local function stopRecord()
    if not isRecording then return end
    isRecording = false
    recordBtn.Text = "⏺ Start Record"
end

-- SAVE
local function saveRecordToFolder(folderName)
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
    if not isfolder(replayFolder.."/"..folderName) then
        makefolder(replayFolder.."/"..folderName)
    end
    writefile(replayFolder.."/"..folderName.."/"..name, HttpService:JSONEncode(saveData))
    print("✅ Replay saved to", replayFolder.."/"..folderName.."/"..name)
end

-- GUI
local gui = Instance.new("ScreenGui", game.CoreGui)

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 220, 0, 180)
frame.Position = UDim2.new(0, 20, 0.5, -90)
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

-- BUTTON: Start/Stop Record
recordBtn = makeBtn("recordBtn", "⏺ Start Record", 50, function()
    if isRecording then
        stopRecord()
    else
        startRecord()
    end
end)

-- BUTTON: Save Replay (choose folder)
makeBtn(nil, "💾 Save Replay", 90, function()
    local folderGui = Instance.new("Frame", gui)
    folderGui.Size = UDim2.new(0, 250, 0, 300)
    folderGui.Position = UDim2.new(0, 250, 0.5, -150)
    folderGui.BackgroundColor3 = Color3.fromRGB(50,50,50)
    folderGui.Active = true
    folderGui.Draggable = true
    Instance.new("UICorner", folderGui).CornerRadius = UDim.new(0,10)

    local closeBtn = Instance.new("TextButton", folderGui)
    closeBtn.Size = UDim2.new(0, 50, 0, 25)
    closeBtn.Position = UDim2.new(1, -55, 0, 5)
    closeBtn.Text = "X"
    closeBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
    closeBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,4)
    closeBtn.MouseButton1Click:Connect(function()
        folderGui:Destroy()
    end)

    local yPos = 40
    for _, path in ipairs(listfiles(replayFolder)) do
        if isfolder(path) then
            local fname = path:split("/")[#path:split("/")]
            local fbtn = Instance.new("TextButton", folderGui)
            fbtn.Size = UDim2.new(1, -20, 0, 30)
            fbtn.Position = UDim2.new(0, 10, 0, yPos)
            fbtn.Text = fname
            fbtn.BackgroundColor3 = Color3.fromRGB(70,70,70)
            fbtn.TextColor3 = Color3.new(1,1,1)
            Instance.new("UICorner", fbtn).CornerRadius = UDim.new(0,6)

            fbtn.MouseButton1Click:Connect(function()
                saveRecordToFolder(fname)
                folderGui:Destroy()
            end)

            yPos = yPos + 40
        end
    end

    -- tombol create folder
    local createBtn = Instance.new("TextButton", folderGui)
    createBtn.Size = UDim2.new(1, -20, 0, 30)
    createBtn.Position = UDim2.new(0, 10, 0, yPos)
    createBtn.Text = "+ Create Folder"
    createBtn.BackgroundColor3 = Color3.fromRGB(0,200,100)
    createBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", createBtn).CornerRadius = UDim.new(0,6)

    createBtn.MouseButton1Click:Connect(function()
        local newName = "Folder"..tostring(math.random(1000,9999))
        makefolder(replayFolder.."/"..newName)
        folderGui:Destroy()
    end)
end, Color3.fromRGB(0,200,100))

-- =========================================================
-- LOAD REPLAY LIST (explorer)
-- =========================================================
local replayFrame
local currentFolder = replayFolder

local function loadReplayList(path)
    if replayFrame then replayFrame:Destroy() end
    replayFrame = Instance.new("Frame", gui)
    replayFrame.Size = UDim2.new(0, 280, 0, 340)
    replayFrame.Position = UDim2.new(0, 250, 0.5, -170)
    replayFrame.BackgroundColor3 = Color3.fromRGB(50,50,50)
    replayFrame.Active = true
    replayFrame.Draggable = true
    Instance.new("UICorner", replayFrame).CornerRadius = UDim.new(0, 10)

    currentFolder = path or replayFolder

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

    if currentFolder ~= replayFolder then
        local backBtn = Instance.new("TextButton", replayFrame)
        backBtn.Size = UDim2.new(1, -20, 0, 30)
        backBtn.Position = UDim2.new(0, 10, 0, 35)
        backBtn.Text = "⬅️ .. (Back)"
        backBtn.BackgroundColor3 = Color3.fromRGB(100,100,100)
        backBtn.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", backBtn).CornerRadius = UDim.new(0,6)
        backBtn.MouseButton1Click:Connect(function()
            local parentPath = table.concat(currentFolder:split("/"), "/", 1, #currentFolder:split("/")-1)
            if parentPath == "" then parentPath = replayFolder end
            loadReplayList(parentPath)
        end)
    end

    local yPos = (currentFolder == replayFolder) and 35 or 75

    for _, path in ipairs(listfiles(currentFolder)) do
        local name = path:split("/")[#path:split("/")]

        local itemBtn = Instance.new("TextButton", replayFrame)
        itemBtn.Size = UDim2.new(1, -80, 0, 30)
        itemBtn.Position = UDim2.new(0, 10, 0, yPos)
        itemBtn.Text = name
        itemBtn.BackgroundColor3 = Color3.fromRGB(70,70,70)
        itemBtn.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", itemBtn).CornerRadius = UDim.new(0,6)

        local delBtn = Instance.new("TextButton", replayFrame)
        delBtn.Size = UDim2.new(0, 60, 0, 30)
        delBtn.Position = UDim2.new(1, -70, 0, yPos)
        delBtn.Text = "DEL"
        delBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
        delBtn.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0,6)

        if isfolder(path) then
            itemBtn.Text = "📁 "..name
            itemBtn.MouseButton1Click:Connect(function()
                loadReplayList(path)
            end)
            delBtn.MouseButton1Click:Connect(function()
                delfolder(path)
                loadReplayList(currentFolder)
            end)
        else
            itemBtn.Text = "📄 "..name
            itemBtn.MouseButton1Click:Connect(function()
                selectedReplayFile = path
                for _, c in ipairs(replayFrame:GetChildren()) do
                    if c:IsA("TextButton") and c ~= closeBtn then
                        c.BackgroundColor3 = Color3.fromRGB(70,70,70)
                    end
                end
                itemBtn.BackgroundColor3 = Color3.fromRGB(0,170,255)
            end)
            delBtn.MouseButton1Click:Connect(function()
                delfile(path)
                loadReplayList(currentFolder)
            end)
        end

        yPos = yPos + 40
    end
end

-- BUTTON: Load Replay List
makeBtn(nil, "📂 Load Replay List", 130, function()
    loadReplayList(replayFolder)
end, Color3.fromRGB(255,170,0))
