-- 🎥 Replay Path Recorder + Rollback (Merged Full Version)
-- By WataX + mod (merged per request)

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

-- Anti-kedut thresholds
local moveThreshold = 0.1
local angleThreshold = 0.01

local function isSignificantChange(lastCF, newCF)
    if not lastCF then return true end
    local dist = (lastCF.Position - newCF.Position).Magnitude
    if dist > moveThreshold then return true end
    local _, _, lastYaw = lastCF:ToOrientation()
    local _, _, newYaw = newCF:ToOrientation()
    if math.abs(newYaw - lastYaw) > angleThreshold then return true end
    return false
end

-- =============== RECORD / PAUSE / ROLLBACK LOGIC ===============
local lastRollbackPos = nil
local lastAction = nil
local selectedRollbackIndex = nil
local rollbackGui = nil

function startRecord()
    if isRecording then return end
    records = records or {}
    isRecording = true
    lastAction = "recording"
    if recordBtn then recordBtn.Text = "⏸ Pause Record" end

    -- push current pos as starting frame to ensure there's at least one frame
    if hrp then
        table.insert(records, { pos = hrp.CFrame })
        if not lastRollbackPos then lastRollbackPos = hrp.CFrame end
    end

    task.spawn(function()
        while isRecording do
            if hrp then
                local lastFrame = records[#records] and records[#records].pos
                local newCF = hrp.CFrame
                if isSignificantChange(lastFrame, newCF) then
                    table.insert(records, { pos = newCF })
                end
            end
            task.wait(frameTime)
        end
    end)
end

local function destroyRollbackGui()
    if rollbackGui and rollbackGui.Parent then
        rollbackGui:Destroy()
    end
    rollbackGui = nil
    selectedRollbackIndex = nil
end

local function showRollbackUI()
    -- ensure previous destroyed
    destroyRollbackGui()

    rollbackGui = Instance.new("ScreenGui")
    rollbackGui.ResetOnSpawn = false
    rollbackGui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame", rollbackGui)
    frame.Size = UDim2.new(0, 250, 0, 400)
    frame.Position = UDim2.new(0.5, -125, 0.5, -200) -- center
    frame.BackgroundColor3 = Color3.fromRGB(35,35,35)
    frame.Active = true
    frame.Draggable = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,10)

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1,0,0,30)
    title.Position = UDim2.new(0,0,0,10)
    title.Text = "Pilih Detik Rollback"
    title.TextColor3 = Color3.new(1,1,1)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.Gotham
    title.TextSize = 16

    -- preview label (shows which second is previewed)
    local previewLabel = Instance.new("TextLabel", frame)
    previewLabel.Size = UDim2.new(1, -20, 0, 24)
    previewLabel.Position = UDim2.new(0, 10, 0, 40)
    previewLabel.BackgroundTransparency = 1
    previewLabel.TextColor3 = Color3.new(1,1,1)
    previewLabel.Text = "Preview: - detik"
    previewLabel.Font = Enum.Font.Gotham
    previewLabel.TextSize = 14
    previewLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- create 1..6 sec buttons
    for i = 1, 6 do
        local btn = Instance.new("TextButton", frame)
        btn.Size = UDim2.new(0.8, 0, 0, 30)
        btn.Position = UDim2.new(0.1, 0, 0, 70 + i * 32)
        btn.Text = tostring(i) .. " detik"
        btn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
        btn.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

        btn.MouseButton1Click:Connect(function()
            selectedRollbackIndex = i
            previewLabel.Text = "Preview: " .. tostring(i) .. " detik"
            -- calculate frames to remove and preview pos
            if #records >= 1 then
                local framesToRemove = math.floor(i / frameTime)
                framesToRemove = math.min(framesToRemove, #records - 1) -- keep at least 1 frame if possible
                local targetIndex = math.max(1, #records - framesToRemove)
                local rollbackPos = records[targetIndex] and records[targetIndex].pos or hrp.CFrame
                -- preview teleport (temporary) to show user
                if hrp and rollbackPos then
                    pcall(function() hrp.CFrame = rollbackPos end)
                end
            end
        end)
    end

    local confirmBtn = Instance.new("TextButton", frame)
    confirmBtn.Size = UDim2.new(0.8, 0, 0, 30)
    confirmBtn.Position = UDim2.new(0.1, 0, 0, 70 + 8 * 32)
    confirmBtn.Text = "✅ Confirm Rollback"
    confirmBtn.BackgroundColor3 = Color3.fromRGB(0,200,100)
    confirmBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0,6)

    local cancelBtn = Instance.new("TextButton", frame)
    cancelBtn.Size = UDim2.new(0.8, 0, 0, 30)
    cancelBtn.Position = UDim2.new(0.1, 0, 0, 70 + 9 * 32 + 6)
    cancelBtn.Text = "✖ Cancel"
    cancelBtn.BackgroundColor3 = Color3.fromRGB(200,100,100)
    cancelBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0,6)

    confirmBtn.MouseButton1Click:Connect(function()
        if not selectedRollbackIndex or #records < 1 then return end
        -- real rollback: calculate frames to remove
        local framesToRemove = math.floor(selectedRollbackIndex / frameTime)
        framesToRemove = math.min(framesToRemove, #records - 1) -- keep at least 1 frame if possible
        local targetIndex = math.max(1, #records - framesToRemove)
        local rollbackPos = records[targetIndex] and records[targetIndex].pos or hrp.CFrame

        -- teleport player to rollback pos (final)
        if hrp and rollbackPos then
            pcall(function() hrp.CFrame = rollbackPos end)
        end

        -- remove the frames that represent the rolled-back time
        for i = 1, framesToRemove do
            table.remove(records)
        end

        lastRollbackPos = rollbackPos
        destroyRollbackGui()
        print("⏪ Rollback "..tostring(selectedRollbackIndex).." detik berhasil!")
    end)

    cancelBtn.MouseButton1Click:Connect(function()
        -- Cancel: we should NOT keep preview teleport; attempt to restore to last recorded pos (last frame)
        local lastPos = records[#records] and records[#records].pos
        if hrp and lastPos then
            pcall(function() hrp.CFrame = lastPos end)
        end
        destroyRollbackGui()
    end)
end

function pauseRecord()
    if not isRecording then return end
    isRecording = false
    lastAction = "paused"
    if recordBtn then recordBtn.Text = "⏺ Start Record" end
    -- show rollback ui after pause
    showRollbackUI()
end

-- =============== SAVE TO FOLDER (ke-compat) ===============
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

-- convenience save (default folder root)
local function saveRecord()
    if #records==0 then return end
    local name = currentFileName
    if not name:match("%.json$") then name = name..".json" end
    local saveData = {}
    for _,f in ipairs(records) do
        table.insert(saveData,{
            pos = {f.pos.Position.X,f.pos.Position.Y,f.pos.Position.Z},
            rot = {f.pos:ToOrientation()}
        })
    end
    writefile(replayFolder.."/"..name, HttpService:JSONEncode(saveData))
    print("💾 Replay saved:",replayFolder.."/"..name)
end

-- =============== GUI (MAIN + Folder List) ===============
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
textbox.Text = currentFileName
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

-- recordBtn: Start <-> Pause (shows rollback UI on pause)
recordBtn = makeBtn("recordBtn", "⏺ Start Record", 50, function()
    if isRecording then
        pauseRecord()
    else
        startRecord()
    end
end)


-- folder-save popup (select folder or create)
makeBtn(nil, "💾 Save To Folder", 90, function()
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

    local scroll = Instance.new("ScrollingFrame", folderGui)
    scroll.Size = UDim2.new(1, -20, 1, -50)
    scroll.Position = UDim2.new(0, 10, 0, 40)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 6
    scroll.CanvasSize = UDim2.new(0,0,0,0)

    local layout = Instance.new("UIListLayout", scroll)
    layout.Padding = UDim.new(0,10)
    layout.SortOrder = Enum.SortOrder.Name
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y + 10)
    end)

    for _, path in ipairs(listfiles(replayFolder)) do
        if isfolder(path) then
            local fname = path:split("/")[#path:split("/")]
            local fbtn = Instance.new("TextButton", scroll)
            fbtn.Size = UDim2.new(1, -10, 0, 30)
            fbtn.Text = fname
            fbtn.BackgroundColor3 = Color3.fromRGB(70,70,70)
            fbtn.TextColor3 = Color3.new(1,1,1)
            Instance.new("UICorner", fbtn).CornerRadius = UDim.new(0,6)

            fbtn.MouseButton1Click:Connect(function()
                saveRecordToFolder(fname)
                folderGui:Destroy()
            end)
        end
    end

    local createBtn = Instance.new("TextButton", scroll)
    createBtn.Size = UDim2.new(1, -10, 0, 30)
    createBtn.Text = "+ Create Folder"
    createBtn.BackgroundColor3 = Color3.fromRGB(0,200,100)
    createBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", createBtn).CornerRadius = UDim.new(0,6)

    createBtn.MouseButton1Click:Connect(function()
        local newName = "Folder"..tostring(math.random(1000,9999))
        makefolder(replayFolder.."/"..newName)
        folderGui:Destroy()
    end)
end, Color3.fromRGB(255,170,0))

-- =============== REPLAY LIST (load / delete) ===============
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

    local scroll = Instance.new("ScrollingFrame", replayFrame)
    scroll.Size = UDim2.new(1, -20, 1, -50)
    scroll.Position = UDim2.new(0, 10, 0, 40)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 6
    scroll.CanvasSize = UDim2.new(0,0,0,0)

    local layout = Instance.new("UIListLayout", scroll)
    layout.Padding = UDim.new(0,10)
    layout.SortOrder = Enum.SortOrder.Name
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y + 10)
    end)

    if currentFolder ~= replayFolder then
        local backBtn = Instance.new("TextButton", scroll)
        backBtn.Size = UDim2.new(1, -10, 0, 30)
        backBtn.Text = "⬅️ .. (Back)"
        backBtn.BackgroundColor3 = Color3.fromRGB(100,100,100)
        backBtn.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", backBtn).CornerRadius = UDim.new(0,6)
        backBtn.MouseButton1Click:Connect(function()
            local parts = currentFolder:split("/")
            local parentPath = table.concat(parts, "/", 1, #parts-1)
            if parentPath == "" then parentPath = replayFolder end
            loadReplayList(parentPath)
        end)
    end

    for _, path in ipairs(listfiles(currentFolder)) do
        local name = path:split("/")[#path:split("/")]

        local container = Instance.new("Frame", scroll)
        container.Size = UDim2.new(1, -10, 0, 30)
        container.BackgroundTransparency = 1

        local itemBtn = Instance.new("TextButton", container)
        itemBtn.Size = UDim2.new(1, -70, 1, 0)
        itemBtn.Text = name
        itemBtn.BackgroundColor3 = Color3.fromRGB(70,70,70)
        itemBtn.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", itemBtn).CornerRadius = UDim.new(0,6)

        local delBtn = Instance.new("TextButton", container)
        delBtn.Size = UDim2.new(0, 60, 1, 0)
        delBtn.Position = UDim2.new(1, -60, 0, 0)
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
                -- highlight selection
                for _, c in ipairs(scroll:GetChildren()) do
                    if c:IsA("Frame") then
                        local btn = c:FindFirstChildWhichIsA("TextButton")
                        if btn then
                            btn.BackgroundColor3 = Color3.fromRGB(70,70,70)
                        end
                    end
                end
                itemBtn.BackgroundColor3 = Color3.fromRGB(0,170,255)
            end)
            delBtn.MouseButton1Click:Connect(function()
                delfile(path)
                loadReplayList(currentFolder)
            end)
        end
    end
end

makeBtn(nil, "📂 Load Replay List", 130, function()
    loadReplayList(replayFolder)
end, Color3.fromRGB(255,170,0))
