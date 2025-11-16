-- 📁 File Manager for MT RECORD Folder - Rename & Delete Files
-- By WataX + Mod - Simplified Version

local player = game.Players.LocalPlayer
local RECORD_FOLDER = "MT RECORD"

-- Safe file helpers
local function safeIsFolder(name)
    if type(isfolder) == "function" then
        local ok, result = pcall(isfolder, name)
        return ok and result
    end
    return false
end

local function safeListFiles(name)
    if type(listfiles) == "function" then
        local ok, result = pcall(listfiles, name)
        return ok and type(result) == "table" and result or {}
    end
    return {}
end

local function safeDeleteFile(path)
    if type(delfile) == "function" then
        local ok, err = pcall(delfile, path)
        return ok, err
    end
    return false, "delfile tidak tersedia"
end

local function safeWriteFile(path, data)
    if type(writefile) == "function" then
        pcall(writefile, path, data)
    end
end

local function safeReadFile(path)
    if type(readfile) == "function" then
        local ok, result = pcall(readfile, path)
        return ok and result or nil
    end
    return nil
end

-- File Operations
local function listReplayFiles()
    local files = safeListFiles(RECORD_FOLDER)
    local out = {}
    for _, f in ipairs(files) do
        if f:match("%.lua$") then
            table.insert(out, {
                fullPath = f,
                name = f:match("([^/\\]+)$")
            })
        end
    end
    return out
end

local function renameFile(oldPath, newName)
    if not oldPath or not newName then return false, "Parameter tidak valid" end
    
    if not newName:match("%.lua$") then newName = newName .. ".lua" end
    local newPath = RECORD_FOLDER .. "/" .. newName
    
    -- Check if file already exists
    local files = listReplayFiles()
    for _, file in ipairs(files) do
        if file.name:lower() == newName:lower() then
            return false, "File sudah ada!"
        end
    end
    
    local content = safeReadFile(oldPath)
    if not content then return false, "Gagal membaca file" end
    
    safeWriteFile(newPath, content)
    local success, err = safeDeleteFile(oldPath)
    if not success then
        pcall(safeDeleteFile, newPath)
        return false, "Gagal hapus file lama: " .. tostring(err)
    end
    
    return true, "File berhasil direname!"
end

local function deleteFile(filePath)
    if not filePath then return false, "File path tidak valid" end
    local success, err = safeDeleteFile(filePath)
    if success then
        return true, "File berhasil dihapus!"
    else
        return false, "Gagal menghapus: " .. tostring(err)
    end
end

-- GUI - Simplified
local gui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
gui.ResetOnSpawn = false
gui.Name = "SimpleFileManager"

local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 300, 0, 350)
main.Position = UDim2.new(0.5, -150, 0.5, -175)
main.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
main.Active = true
main.Draggable = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

-- Title bar with close button
local titleBar = Instance.new("Frame", main)
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", titleBar)
title.Size = UDim2.new(0.8, 0, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.Text = "📁 MT RECORD Manager"
title.TextColor3 = Color3.new(1, 1, 1)
title.BackgroundTransparency = 1
title.Font = Enum.Font.Gotham
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 25, 0, 25)
closeBtn.Position = UDim2.new(1, -30, 0, 2)
closeBtn.Text = "X"
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.Gotham
closeBtn.TextSize = 12
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

-- Status
local statusLabel = Instance.new("TextLabel", main)
statusLabel.Size = UDim2.new(1, -20, 0, 25)
statusLabel.Position = UDim2.new(0, 10, 0, 40)
statusLabel.Text = "Pilih file"
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextWrapped = true
Instance.new("UICorner", statusLabel).CornerRadius = UDim.new(0, 4)

-- File list
local scrollFrame = Instance.new("ScrollingFrame", main)
scrollFrame.Size = UDim2.new(1, -20, 0, 180)
scrollFrame.Position = UDim2.new(0, 10, 0, 75)
scrollFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
scrollFrame.BorderSizePixel = 0
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", scrollFrame).CornerRadius = UDim.new(0, 6)

local layout = Instance.new("UIListLayout", scrollFrame)
layout.Padding = UDim.new(0, 3)

-- Rename section
local renameBox = Instance.new("TextBox", main)
renameBox.Size = UDim2.new(0.65, -5, 0, 30)
renameBox.Position = UDim2.new(0, 10, 0, 265)
renameBox.PlaceholderText = "Nama baru..."
renameBox.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
renameBox.TextColor3 = Color3.new(1, 1, 1)
renameBox.Font = Enum.Font.Gotham
renameBox.TextSize = 11
Instance.new("UICorner", renameBox).CornerRadius = UDim.new(0, 4)

-- Buttons
local renameBtn = Instance.new("TextButton", main)
renameBtn.Size = UDim2.new(0.3, -5, 0, 30)
renameBtn.Position = UDim2.new(0.7, 0, 0, 265)
renameBtn.Text = "✏️ Rename"
renameBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
renameBtn.TextColor3 = Color3.new(1, 1, 1)
renameBtn.Font = Enum.Font.Gotham
renameBtn.TextSize = 11
Instance.new("UICorner", renameBtn).CornerRadius = UDim.new(0, 4)

local deleteBtn = Instance.new("TextButton", main)
deleteBtn.Size = UDim2.new(0.45, -10, 0, 30)
deleteBtn.Position = UDim2.new(0.025, 0, 0, 305)
deleteBtn.Text = "🗑️ Hapus"
deleteBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
deleteBtn.TextColor3 = Color3.new(1, 1, 1)
deleteBtn.Font = Enum.Font.Gotham
deleteBtn.TextSize = 12
Instance.new("UICorner", deleteBtn).CornerRadius = UDim.new(0, 6)

local refreshBtn = Instance.new("TextButton", main)
refreshBtn.Size = UDim2.new(0.45, -10, 0, 30)
refreshBtn.Position = UDim2.new(0.525, 0, 0, 305)
refreshBtn.Text = "🔄 Refresh"
refreshBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
refreshBtn.TextColor3 = Color3.new(1, 1, 1)
refreshBtn.Font = Enum.Font.Gotham
refreshBtn.TextSize = 12
Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 6)

-- Variables
local selectedFile = nil
local fileButtons = {}
local deleteConfirming = false

-- Update file list
local function updateFileList()
    for _, btn in ipairs(fileButtons) do btn:Destroy() end
    fileButtons = {}
    
    local files = listReplayFiles()
    
    if #files == 0 then
        local noFiles = Instance.new("TextLabel", scrollFrame)
        noFiles.Size = UDim2.new(1, -10, 0, 30)
        noFiles.Position = UDim2.new(0, 5, 0, 5)
        noFiles.Text = "Tidak ada file .lua"
        noFiles.TextColor3 = Color3.new(0.8, 0.8, 0.8)
        noFiles.BackgroundTransparency = 1
        noFiles.Font = Enum.Font.Gotham
        noFiles.TextSize = 11
        table.insert(fileButtons, noFiles)
    else
        for i, file in ipairs(files) do
            local btn = Instance.new("TextButton", scrollFrame)
            btn.Size = UDim2.new(1, -10, 0, 28)
            btn.Position = UDim2.new(0, 5, 0, (i-1)*31)
            btn.Text = file.name
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            btn.TextColor3 = Color3.new(1, 1, 1)
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 10
            btn.TextWrapped = true
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
            
            btn.MouseButton1Click:Connect(function()
                for _, otherBtn in ipairs(fileButtons) do
                    if otherBtn:IsA("TextButton") then
                        otherBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                    end
                end
                btn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
                selectedFile = file
                statusLabel.Text = "Selected: " .. file.name
                renameBox.Text = file.name:gsub("%.lua$", "")
                deleteConfirming = false
                deleteBtn.Text = "🗑️ Hapus"
                deleteBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            end)
            
            table.insert(fileButtons, btn)
        end
    end
    
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #files * 31)
end

-- Button functionalities
renameBtn.MouseButton1Click:Connect(function()
    if not selectedFile then
        statusLabel.Text = "Pilih file dulu!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local newName = renameBox.Text
    if newName == "" or newName == selectedFile.name then
        statusLabel.Text = "Nama harus berbeda!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local success, message = renameFile(selectedFile.fullPath, newName)
    statusLabel.Text = message
    statusLabel.TextColor3 = success and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
    
    if success then
        updateFileList()
        selectedFile = nil
        renameBox.Text = ""
    end
end)

deleteBtn.MouseButton1Click:Connect(function()
    if not selectedFile then
        statusLabel.Text = "Pilih file dulu!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    if not deleteConfirming then
        -- First click - confirmation
        deleteConfirming = true
        deleteBtn.Text = "✅ KONFIRMASI"
        deleteBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
        statusLabel.Text = "Klik Hapus lagi untuk konfirmasi hapus: " .. selectedFile.name
        statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        
        -- Reset confirmation after 3 seconds
        task.delay(3, function()
            if deleteConfirming then
                deleteConfirming = false
                deleteBtn.Text = "🗑️ Hapus"
                deleteBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                statusLabel.Text = "Pilih file untuk dikelola"
                statusLabel.TextColor3 = Color3.new(1, 1, 1)
            end
        end)
    else
        -- Second click - actually delete
        deleteConfirming = false
        deleteBtn.Text = "🗑️ Hapus"
        deleteBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        
        local success, message = deleteFile(selectedFile.fullPath)
        statusLabel.Text = message
        statusLabel.TextColor3 = success and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
        
        if success then
            updateFileList()
            selectedFile = nil
            renameBox.Text = ""
        end
    end
end)

refreshBtn.MouseButton1Click:Connect(function()
    updateFileList()
    deleteConfirming = false
    deleteBtn.Text = "🗑️ Hapus"
    deleteBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    statusLabel.Text = "List diperbarui"
    statusLabel.TextColor3 = Color3.new(1, 1, 1)
end)

-- Initialize
if safeIsFolder(RECORD_FOLDER) then
    updateFileList()
else
    statusLabel.Text = "Folder MT RECORD tidak ditemukan!"
    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
end

print("📁 Simple File Manager loaded!")
