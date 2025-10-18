

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local hrp


local animConn
local isMoving = false
local frameTime = 1/30
local playbackRate = 1
local isReplayRunning = false


local FileSystem = {}


local hasIsFolder = type(isfolder) == "function"
local hasListFiles = type(listfiles) == "function" or type(listfiles) == "userdata"
local hasReadFile = type(readfile) == "function"


local function safeIsFolder(path)
    if hasIsFolder then
        local ok, res = pcall(isfolder, path)
        if ok then return res end
    end
    return false
end

local function safeListFiles(path)
    if hasListFiles then
        local ok, res = pcall(listfiles, path)
        if ok and type(res) == "table" then
            return res
        elseif ok and type(res) == "string" then
            
            local t = {}
            for line in res:gmatch("[^\r\n]+") do table.insert(t, line) end
            return t
        end
    end
    return nil
end

local function safeReadFile(path)
    if hasReadFile then
        local ok, res = pcall(readfile, path)
        if ok then return res end
    end
    return nil
end


local FS_BASE = "WataXRecord" -- base folder (executor FS path or Workspace Folder)

function FileSystem:listFolders(base)
    base = base or FS_BASE
    
    if safeIsFolder(base) then
        local raw = safeListFiles(base)
        if raw then
            local folders = {}
            for _,p in ipairs(raw) do
                
                local ok, info = pcall(function()
                    return isfolder and isfolder(p)
                end)
                if ok and info then
                    
                    local name = p:match("([^/\\]+)$") or p
                    table.insert(folders, name)
                end
            end
            return folders
        end
    end

    
    local root = workspace:FindFirstChild(FS_BASE)
    if root and root:IsA("Folder") then
        local out = {}
        for _,child in ipairs(root:GetChildren()) do
            if child:IsA("Folder") then table.insert(out, child.Name) end
        end
        return out
    end

    return {}
end

function FileSystem:listFiles(base)
    base = base or FS_BASE
   
    if safeIsFolder(base) then
        local raw = safeListFiles(base)
        if raw then
            local out = {}
            for _,p in ipairs(raw) do
                
                local name = p:match("([^/\\]+)$") or p
                if name:lower():match("%.json$") then
                    table.insert(out, name)
                end
            end
            return out
        end
    end

    
    local root = workspace:FindFirstChild(FS_BASE)
    if root and root:IsA("Folder") then
        local out = {}
        for _,child in ipairs(root:GetChildren()) do
            if child:IsA("StringValue") and child.Name:lower():match("%.json$") then
                table.insert(out, child.Name)
            end
        end
        return out
    end

    return {}
end

function FileSystem:readFileFull(path) 
    
    local full = path
    
    if not safeReadFile(full) and safeIsFolder(FS_BASE) then
       
        local sep = "/"
        full = FS_BASE .. sep .. path
    end
    local content = safeReadFile(full)
    if content then return content end

 
    local parts = {}
    for part in string.gmatch(path, "[^/\\]+") do table.insert(parts, part) end
    local root = workspace:FindFirstChild(FS_BASE)
    if not root or not root:IsA("Folder") then return nil end

    local node = root
    for i = 1, #parts do
        local p = parts[i]
        if i == #parts then
            
            local sv = node:FindFirstChild(p)
            if sv and sv:IsA("StringValue") then
                return sv.Value
            else
                return nil
            end
        else
            node = node:FindFirstChild(p)
            if not node or not node:IsA("Folder") then return nil end
        end
    end

    return nil
end


local function joinPath(...)
    local t = {...}
    return table.concat(t, "/")
end



local function parseReplayJSON(jsonText)
    if not jsonText then return nil, "no content" end
    local ok, t = pcall(function() return HttpService:JSONDecode(jsonText) end)
    if not ok then return nil, "invalid json: "..t end
    if type(t) ~= "table" or #t == 0 then return nil, "json not a list or empty" end
    local frames = {}
    for i,entry in ipairs(t) do
        if type(entry) == "table" and entry.pos and entry.rot then
            local p = entry.pos
            local r = entry.rot
            if #p >= 3 and #r >= 3 then
                local ok2, cf = pcall(function()
                    return CFrame.new(Vector3.new(tonumber(p[1]) or 0, tonumber(p[2]) or 0, tonumber(p[3]) or 0))
                        * CFrame.Angles(tonumber(r[1]) or 0, tonumber(r[2]) or 0, tonumber(r[3]) or 0)
                end)
                if ok2 and cf then
                    table.insert(frames, cf)
                end
            end
        end
    end
    if #frames == 0 then return nil, "no valid frames parsed" end
    return frames
end



local function refreshHRP(char)
    if not char then char = player.Character or player.CharacterAdded:Wait() end
    hrp = char:WaitForChild("HumanoidRootPart")
end

player.CharacterAdded:Connect(refreshHRP)
if player.Character then refreshHRP(player.Character) end

local function stopMovement()
    isMoving = false
end
local function startMovement()
    isMoving = true
end

local function getCurrentHeight()
    local char = player.Character or player.CharacterAdded:Wait()
    local humanoid = char:WaitForChild("Humanoid")
    return humanoid.HipHeight + (char:FindFirstChild("Head") and char.Head.Size.Y or 2)
end




local function setupMovement(char)
    task.spawn(function()
        if not char then
            char = player.Character or player.CharacterAdded:Wait()
        end
        local humanoid = char:WaitForChild("Humanoid", 5)
        local root = char:WaitForChild("HumanoidRootPart", 5)
        if not humanoid or not root then return end

        
        humanoid.Died:Connect(function()
            print("[WataX] Karakter mati, replay otomatis berhenti.")
            isReplayRunning = false
            stopMovement()
            if toggleBtn and toggleBtn.Parent then
                toggleBtn.Text = "▶ Start"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(70,200,120)
            end
        end)

        if animConn then animConn:Disconnect() end
        local lastPos = root.Position
        local jumpCooldown = false

        animConn = RunService.RenderStepped:Connect(function()
            if not isMoving then return end

            
            if not hrp or not hrp.Parent or not hrp:IsDescendantOf(workspace) then
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    root = hrp
                else
                    return
                end
            end

            if not humanoid or humanoid.Health <= 0 then return end

            local direction = root.Position - lastPos
            local dist = direction.Magnitude

            if dist > 0.01 then
                humanoid:Move(direction.Unit * math.clamp(dist * 5, 0, 1), false)
            else
                humanoid:Move(Vector3.zero, false)
            end

            local deltaY = root.Position.Y - lastPos.Y
            if deltaY > 0.9 and not jumpCooldown then
                humanoid.Jump = true
                jumpCooldown = true
                task.delay(0.4, function()
                    jumpCooldown = false
                end)
            end

            lastPos = root.Position
        end)
    end)
end

player.CharacterAdded:Connect(function(char)
    refreshHRP(char)
    setupMovement(char)
end)

if player.Character then
    refreshHRP(player.Character)
    setupMovement(player.Character)
end

local function lerpCF(fromCF,toCF)
    local duration = frameTime/math.max(0.05,playbackRate)
    local t = 0
    while t < duration do
        if not isReplayRunning then break end
        local dt = task.wait()
        t += dt
        local alpha = math.min(t/duration,1)
        if hrp and hrp.Parent and hrp:IsDescendantOf(workspace) then
            hrp.CFrame = fromCF:Lerp(toCF,alpha)
        end
    end
end

local function getNearestFrameIndex(frames)
    local startIdx, dist = 1, math.huge
    if hrp then
        local pos = hrp.Position
        for i,cf in ipairs(frames) do
            local d = (cf.Position - pos).Magnitude
            if d < dist then dist=d startIdx=i end
        end
    end
    if startIdx >= #frames then startIdx = math.max(1,#frames-1) end
    return startIdx
end

local routes = {} -- will hold { {"name", frames_table} }

local function getNearestRoute()
    local nearestIdx, dist = 1, math.huge
    if hrp then
        local pos = hrp.Position
        for i,data in ipairs(routes) do
            for _,cf in ipairs(data[2]) do
                local d = (cf.Position - pos).Magnitude
                if d < dist then dist=d nearestIdx=i end
            end
        end
    end
    return nearestIdx
end

local function runRoute()
    if #routes==0 then return end
    if not hrp then refreshHRP() end
    isReplayRunning = true
    startMovement()
    local idx = getNearestRoute()
    local frames = routes[idx][2]
    if #frames<2 then isReplayRunning=false return end
    local startIdx = getNearestFrameIndex(frames)
    for i=startIdx,#frames-1 do
        if not isReplayRunning then break end
        lerpCF(frames[i],frames[i+1])
    end
    isReplayRunning=false
    stopMovement()
end

local function stopRoute()
    isReplayRunning=false
    stopMovement()
end


pcall(function()
    local old = game.CoreGui:FindFirstChild("WataXReplayUI")
    if old then old:Destroy() end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name="WataXReplayUI"
screenGui.Parent=game.CoreGui
screenGui.DisplayOrder = 9999

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 150)
frame.Position = UDim2.new(0.05,0,0.7,0)
frame.BackgroundColor3 = Color3.fromRGB(50,30,70)
frame.BackgroundTransparency = 0.3
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,16)

local glow = Instance.new("UIStroke")
glow.Parent = frame
glow.Color = Color3.fromRGB(180,120,255)
glow.Thickness = 2
glow.Transparency = 0.4

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(0.75,0,0,28)
title.Position = UDim2.new(0.05,0,0,4)
title.Text = "WataX Script"
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.BackgroundTransparency = 0.3
title.BackgroundColor3 = Color3.fromRGB(70,40,120)
Instance.new("UICorner", title).CornerRadius = UDim.new(0,12)

local hue = 0
RunService.RenderStepped:Connect(function()
    hue = (hue + 0.5) % 360
    title.TextColor3 = Color3.fromHSV(hue/360,1,1)
end)

local closeBtn = Instance.new("TextButton", frame)
closeBtn.Size = UDim2.new(0,28,0,28)
closeBtn.Position = UDim2.new(0.78,0,0,4)
closeBtn.Text = "✖"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextScaled = true
closeBtn.BackgroundColor3 = Color3.fromRGB(180,60,60)
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,10)

local closeGlow = Instance.new("UIStroke")
closeGlow.Parent = closeBtn
closeGlow.Color = Color3.fromRGB(255,0,100)
closeGlow.Thickness = 2
closeGlow.Transparency = 0.6

closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeGlow, TweenInfo.new(0.2), {Transparency=0.1, Thickness=4}):Play()
end)
closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeGlow, TweenInfo.new(0.2), {Transparency=0.6, Thickness=2}):Play()
end)
closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)


toggleBtn = Instance.new("TextButton", frame)
toggleBtn.Size = UDim2.new(0.8,0,0.25,0)
toggleBtn.Position = UDim2.new(0.1,0,0.35,0)
toggleBtn.Text = "▶ Start"
toggleBtn.TextScaled = true
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.BackgroundColor3 = Color3.fromRGB(70,200,120)
toggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0,14)

local toggleGlow = Instance.new("UIStroke")
toggleGlow.Parent = toggleBtn
toggleGlow.Color = Color3.fromRGB(0,255,255)
toggleGlow.Thickness = 2
toggleGlow.Transparency = 0.5

toggleBtn.MouseEnter:Connect(function()
    TweenService:Create(toggleGlow, TweenInfo.new(0.2), {Transparency=0.1, Thickness=4}):Play()
end)
toggleBtn.MouseLeave:Connect(function()
    TweenService:Create(toggleGlow, TweenInfo.new(0.2), {Transparency=0.5, Thickness=2}):Play()
end)

local isRunning = false
local selectedReplayPath = nil
local selectedReplayName = nil


local speedLabel = Instance.new("TextLabel", frame)
speedLabel.Size = UDim2.new(0.35,0,0.18,0)
speedLabel.Position = UDim2.new(0.325,0,0.72,0)
speedLabel.BackgroundTransparency = 1
speedLabel.TextColor3 = Color3.fromRGB(180,180,255)
speedLabel.Font = Enum.Font.GothamBold
speedLabel.TextScaled = true
speedLabel.Text = playbackRate.."x"

local speedDown = Instance.new("TextButton", frame)
speedDown.Size = UDim2.new(0.2,0,0.18,0)
speedDown.Position = UDim2.new(0.05,0,0.72,0)
speedDown.Text = "-"
speedDown.Font = Enum.Font.GothamBold
speedDown.TextScaled = true
speedDown.BackgroundColor3 = Color3.fromRGB(100,100,100)
speedDown.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", speedDown).CornerRadius = UDim.new(0,6)
speedDown.MouseButton1Click:Connect(function()
    playbackRate = math.max(0.25, playbackRate-0.25)
    speedLabel.Text = playbackRate.."x"
end)

local speedUp = Instance.new("TextButton", frame)
speedUp.Size = UDim2.new(0.2,0,0.18,0)
speedUp.Position = UDim2.new(0.75,0,0.72,0)
speedUp.Text = "+"
speedUp.Font = Enum.Font.GothamBold
speedUp.TextScaled = true
speedUp.BackgroundColor3 = Color3.fromRGB(100,100,150)
speedUp.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", speedUp).CornerRadius = UDim.new(0,6)
speedUp.MouseButton1Click:Connect(function()
    playbackRate = math.min(3, playbackRate+0.25)
    speedLabel.Text = playbackRate.."x"
end)


local selectedLabel = Instance.new("TextLabel", frame)
selectedLabel.Size = UDim2.new(0.9,0,0,22)
selectedLabel.Position = UDim2.new(0.05,0,0.12,0)
selectedLabel.BackgroundTransparency = 1
selectedLabel.Font = Enum.Font.GothamBold
selectedLabel.TextScaled = false
selectedLabel.Text = "Selected: -"
selectedLabel.TextColor3 = Color3.fromRGB(220,220,255)


local function createFileBrowser()
    
    local modal = Instance.new("Frame", screenGui)
    modal.Size = UDim2.new(0, 520, 0, 360)
    modal.Position = UDim2.new(0.5, -260, 0.5, -180)
    modal.BackgroundColor3 = Color3.fromRGB(30,30,40)
    modal.BorderSizePixel = 0
    modal.Active = true
    modal.Draggable = true
    Instance.new("UICorner", modal).CornerRadius = UDim.new(0,14)

    local header = Instance.new("TextLabel", modal)
    header.Size = UDim2.new(1, -10, 0, 36)
    header.Position = UDim2.new(0,5,0,6)
    header.BackgroundTransparency = 1
    header.Font = Enum.Font.GothamBold
    header.Text = "Select Replay - "..FS_BASE
    header.TextColor3 = Color3.fromRGB(230,230,255)
    header.TextScaled = true

    
    local folderFrame = Instance.new("Frame", modal)
    folderFrame.Size = UDim2.new(0.35, -10, 0.78, 0)
    folderFrame.Position = UDim2.new(0,8,0,52)
    folderFrame.BackgroundTransparency = 0.15
    folderFrame.BackgroundColor3 = Color3.fromRGB(20,20,30)
    Instance.new("UICorner", folderFrame).CornerRadius = UDim.new(0,10)

    local folderLabel = Instance.new("TextLabel", folderFrame)
    folderLabel.Size = UDim2.new(1, -12, 0, 24)
    folderLabel.Position = UDim2.new(0,6,0,6)
    folderLabel.BackgroundTransparency = 1
    folderLabel.Font = Enum.Font.GothamBold
    folderLabel.Text = "Folders"
    folderLabel.TextColor3 = Color3.fromRGB(200,200,255)
    folderLabel.TextScaled = true

    local folderCanvas = Instance.new("ScrollingFrame", folderFrame)
    folderCanvas.Size = UDim2.new(1, -12, 1, -36)
    folderCanvas.Position = UDim2.new(0,6,0,36)
    folderCanvas.CanvasSize = UDim2.new(0,0,0,0)
    folderCanvas.ScrollBarThickness = 6
    folderCanvas.BackgroundTransparency = 1
    folderCanvas.AutomaticCanvasSize = Enum.AutomaticSize.Y
    folderCanvas.ClipsDescendants = true
    folderCanvas.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

    local folderListLayout = Instance.new("UIListLayout", folderCanvas)
    folderListLayout.Padding = UDim.new(0,6)

    
    local fileFrame = Instance.new("Frame", modal)
    fileFrame.Size = UDim2.new(0.6, -18, 0.78, 0)
    fileFrame.Position = UDim2.new(0.37, 10, 0, 52)
    fileFrame.BackgroundTransparency = 0.15
    fileFrame.BackgroundColor3 = Color3.fromRGB(20,20,30)
    Instance.new("UICorner", fileFrame).CornerRadius = UDim.new(0,10)

    local fileLabel = Instance.new("TextLabel", fileFrame)
    fileLabel.Size = UDim2.new(1, -12, 0, 24)
    fileLabel.Position = UDim2.new(0,6,0,6)
    fileLabel.BackgroundTransparency = 1
    fileLabel.Font = Enum.Font.GothamBold
    fileLabel.Text = "Files"
    fileLabel.TextColor3 = Color3.fromRGB(200,200,255)
    fileLabel.TextScaled = true

    local fileCanvas = Instance.new("ScrollingFrame", fileFrame)
    fileCanvas.Size = UDim2.new(1, -12, 1, -36)
    fileCanvas.Position = UDim2.new(0,6,0,36)
    fileCanvas.CanvasSize = UDim2.new(0,0,0,0)
    fileCanvas.ScrollBarThickness = 6
    fileCanvas.BackgroundTransparency = 1
    fileCanvas.AutomaticCanvasSize = Enum.AutomaticSize.Y
    fileCanvas.ClipsDescendants = true

    local fileListLayout = Instance.new("UIListLayout", fileCanvas)
    fileListLayout.Padding = UDim.new(0,6)

    -- bottom action buttons
    local btnConfirm = Instance.new("TextButton", modal)
    btnConfirm.Size = UDim2.new(0.28,0,0,34)
    btnConfirm.Position = UDim2.new(0.6, 10, 0.84, 0)
    btnConfirm.Text = "Select"
    btnConfirm.Font = Enum.Font.GothamBold
    btnConfirm.TextScaled = true
    Instance.new("UICorner", btnConfirm).CornerRadius = UDim.new(0,8)
    btnConfirm.BackgroundColor3 = Color3.fromRGB(70,200,120)

    local btnCancel = Instance.new("TextButton", modal)
    btnCancel.Size = UDim2.new(0.28,0,0,34)
    btnCancel.Position = UDim2.new(0.3, 10, 0.84, 0)
    btnCancel.Text = "Cancel"
    btnCancel.Font = Enum.Font.GothamBold
    btnCancel.TextScaled = true
    Instance.new("UICorner", btnCancel).CornerRadius = UDim.new(0,8)
    btnCancel.BackgroundColor3 = Color3.fromRGB(180,80,80)

    local currentFolder = nil
    local selectedFileBtn = nil
    local selectedFileNameLocal = nil

    local function clearFileSelection()
        if selectedFileBtn then
            selectedFileBtn.BackgroundColor3 = Color3.fromRGB(60,60,80)
            selectedFileBtn = nil
            selectedFileNameLocal = nil
        end
    end

    local function fillFilesForFolder(folderName)
        
        for _,c in ipairs(fileCanvas:GetChildren()) do
            if not c:IsA("UIListLayout") then c:Destroy() end
        end
        selectedFileBtn = nil
        selectedFileNameLocal = nil
        currentFolder = folderName

        local base = folderName and joinPath(folderName) or ""
        local files = {}
        
        if safeIsFolder(joinPath(FS_BASE, folderName or "")) then
            local raw = safeListFiles(joinPath(FS_BASE, folderName or ""))
            if raw then
                for _,p in ipairs(raw) do
                    local name = p:match("([^/\\]+)$") or p
                    if name:lower():match("%.json$") then table.insert(files, name) end
                end
            end
        else
            
            local root = workspace:FindFirstChild(FS_BASE)
            if root and root:IsA("Folder") then
                local node = root
                if folderName and folderName ~= "" then
                    node = root:FindFirstChild(folderName)
                end
                if node and node:IsA("Folder") then
                    for _,child in ipairs(node:GetChildren()) do
                        if child:IsA("StringValue") and child.Name:lower():match("%.json$") then
                            table.insert(files, child.Name)
                        end
                    end
                end
            end
        end

        table.sort(files)
        for _,fname in ipairs(files) do
            local btn = Instance.new("TextButton", fileCanvas)
            btn.Size = UDim2.new(1, -12, 0, 30)
            btn.BackgroundColor3 = Color3.fromRGB(60,60,80)
            btn.TextColor3 = Color3.fromRGB(230,230,255)
            btn.Font = Enum.Font.Gotham
            btn.TextScaled = false
            btn.Text = fname
            btn.AutoButtonColor = true
            btn.MouseButton1Click:Connect(function()
                if selectedFileBtn then selectedFileBtn.BackgroundColor3 = Color3.fromRGB(60,60,80) end
                selectedFileBtn = btn
                selectedFileNameLocal = fname
                btn.BackgroundColor3 = Color3.fromRGB(70,140,220)
            end)
        end
        
    end

    local function fillFolderList()
        for _,c in ipairs(folderCanvas:GetChildren()) do
            if not c:IsA("UIListLayout") then c:Destroy() end
        end

        
        local rootBtn = Instance.new("TextButton", folderCanvas)
        rootBtn.Size = UDim2.new(1, -12, 0, 28)
        rootBtn.BackgroundColor3 = Color3.fromRGB(60,60,80)
        rootBtn.Font = Enum.Font.Gotham
        rootBtn.TextColor3 = Color3.fromRGB(230,230,255)
        rootBtn.Text = "[ Root ]"
        rootBtn.MouseButton1Click:Connect(function()
            for _,b in ipairs(folderCanvas:GetChildren()) do
                if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(60,60,80) end
            end
            rootBtn.BackgroundColor3 = Color3.fromRGB(80,80,120)
            fillFilesForFolder("") -- base
        end)

        local folders = FileSystem:listFolders(FS_BASE)
        table.sort(folders)
        for _,fname in ipairs(folders) do
            local btn = Instance.new("TextButton", folderCanvas)
            btn.Size = UDim2.new(1, -12, 0, 28)
            btn.BackgroundColor3 = Color3.fromRGB(60,60,80)
            btn.Font = Enum.Font.Gotham
            btn.TextColor3 = Color3.fromRGB(230,230,255)
            btn.Text = fname
            btn.AutoButtonColor = true
            btn.MouseButton1Click:Connect(function()
                for _,b in ipairs(folderCanvas:GetChildren()) do
                    if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(60,60,80) end
                end
                btn.BackgroundColor3 = Color3.fromRGB(80,80,120)
                fillFilesForFolder(fname)
            end)
        end
    end

    fillFolderList()
    
    fillFilesForFolder("")

    btnCancel.MouseButton1Click:Connect(function()
        modal:Destroy()
    end)

    btnConfirm.MouseButton1Click:Connect(function()
        if not selectedFileNameLocal then
            
            btnConfirm.BackgroundColor3 = Color3.fromRGB(200,100,100)
            task.delay(0.25, function() btnConfirm.BackgroundColor3 = Color3.fromRGB(70,200,120) end)
            return
        end
        
        local finalPath = selectedFileNameLocal
        if currentFolder and currentFolder ~= "" then
            finalPath = joinPath(currentFolder, selectedFileNameLocal)
        end
        
        selectedReplayPath = finalPath
        selectedReplayName = selectedFileNameLocal
        selectedLabel.Text = "Selected: "..tostring(selectedReplayPath)
        modal:Destroy()
    end)

    return modal
end


toggleBtn.MouseButton1Click:Connect(function()
    if not isRunning then
        if not selectedReplayPath then
            createFileBrowser()
            return
        end
        
        local content = FileSystem:readFileFull(selectedReplayPath)
        if not content then
            warn("[WataX] Gagal membaca file: "..tostring(selectedReplayPath))
            
            createFileBrowser()
            return
        end
        local frames, err = parseReplayJSON(content)
        if not frames then
            warn("[WataX] Parse error: "..tostring(err))
           
            createFileBrowser()
            return
        end

        
       routes = { { selectedReplayName or "replay", frames } }


        isRunning = true
        toggleBtn.Text = "■ Stop"
        task.spawn(function() runRoute() end)
    else
        isRunning = false
        toggleBtn.Text = "▶ Start"
        stopRoute()
    end
end)


toggleBtn.MouseButton2Click:Connect(function()
    createFileBrowser()
end)


selectedLabel.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        createFileBrowser()
    end
end)

print("[WataX] Replay UI ready. Click Start to choose a replay if none selected.")

