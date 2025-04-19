local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Config via _G
local config = _G.Config or {}

local aimbotFOV = config.aimbotFOV or 70
local aimlockSmoothness = config.aimlockSmoothness or 1
local crosshairType = config.crosshairType or "Cross"
local crosshairColor = config.crosshairColor or Color3.fromRGB(255, 255, 255)
local crosshairOpacity = config.crosshairOpacity or 0
local crosshairSize = config.crosshairSize or 4
local crosshairThickness = config.crosshairThickness or 2
local fovColor = config.fovColor or Color3.fromRGB(0, 200, 255)
local fovTransparency = config.fovTransparency or 0.3
local fovFilled = config.fovFilled or false
local defaultBoxColor = config.defaultBoxColor or Color3.fromRGB(255, 105, 180)
local lockedBoxColor = config.lockedBoxColor or Color3.fromRGB(0, 255, 120)
local boxTransparency = config.boxTransparency or 0.5
local boxFilled = config.boxFilled or false

-- State
local boxes = {}
local targetPlayer = nil
local connections = {}
local running = true
local aimbotEnabled = true

-- FOV Circle
local fovCircle = Drawing.new("Circle")
fovCircle.Color = fovColor
fovCircle.Thickness = 2
fovCircle.NumSides = 20
fovCircle.Radius = aimbotFOV
fovCircle.Filled = fovFilled
fovCircle.Transparency = fovTransparency
fovCircle.Visible = true

-- Crosshair
local crosshair = {
    line1 = Drawing.new("Line"),
    line2 = Drawing.new("Line"),
    circle = Drawing.new("Circle"),
    dot = Drawing.new("Square")
}

local function initializeCrosshair()
    crosshair.line1.Thickness = crosshairThickness
    crosshair.line1.Color = crosshairColor
    crosshair.line1.Visible = true

    crosshair.line2.Thickness = crosshairThickness
    crosshair.line2.Color = crosshairColor
    crosshair.line2.Visible = true

    crosshair.circle.Thickness = crosshairThickness
    crosshair.circle.Color = crosshairColor
    crosshair.circle.Visible = false
    crosshair.circle.Filled = false
    crosshair.circle.NumSides = 50

    crosshair.dot.Thickness = crosshairThickness
    crosshair.dot.Color = crosshairColor
    crosshair.dot.Visible = false
    crosshair.dot.Filled = true
end

local function updateCrosshair()
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    if crosshairType == "Dot" then
        crosshair.dot.Size = Vector2.new(crosshairSize, crosshairSize)
        crosshair.dot.Position = screenCenter - Vector2.new(crosshairSize / 2, crosshairSize / 2)
        crosshair.dot.Visible = true
        crosshair.line1.Visible = false
        crosshair.line2.Visible = false
        crosshair.circle.Visible = false
    elseif crosshairType == "Circle" then
        crosshair.circle.Radius = crosshairSize
        crosshair.circle.Position = screenCenter
        crosshair.circle.Visible = true
        crosshair.line1.Visible = false
        crosshair.line2.Visible = false
        crosshair.dot.Visible = false
    elseif crosshairType == "Cross" then
        crosshair.line1.From = screenCenter - Vector2.new(crosshairSize, 0)
        crosshair.line1.To = screenCenter + Vector2.new(crosshairSize, 0)
        crosshair.line1.Visible = true

        crosshair.line2.From = screenCenter - Vector2.new(0, crosshairSize)
        crosshair.line2.To = screenCenter + Vector2.new(0, crosshairSize)
        crosshair.line2.Visible = true

        crosshair.circle.Visible = false
        crosshair.dot.Visible = false
    end
end

local function createBox()
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = defaultBoxColor
    box.Thickness = 2
    box.Transparency = boxTransparency
    box.Filled = boxFilled
    return box
end

local function updateBox(player)
    if not boxes[player] then
        boxes[player] = createBox()
    end
    local box = boxes[player]
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local rootPart = character.HumanoidRootPart
        local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
        if onScreen then
            local scale = (Camera.CFrame.Position - rootPart.Position).Magnitude / 50
            local boxSize = Vector2.new(30 / scale, 60 / scale)
            box.Size = boxSize
            box.Position = Vector2.new(pos.X - boxSize.X / 2, pos.Y - boxSize.Y / 2)
            box.Color = targetPlayer == player and lockedBoxColor or defaultBoxColor
            box.Visible = true
        else
            box.Visible = false
        end
    else
        box.Visible = false
    end
end

local function getPlayerHead(character)
    local head = character:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head end
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and part.Name:lower():find("head") then return part end
    end
    local top
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and (not top or part.Position.Y > top.Position.Y) then
            top = part
        end
    end
    return top
end

local function getClosestPlayer()
    local closestPlayer
    local shortestDistance = math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local head = getPlayerHead(player.Character)
            if head then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                    if dist <= aimbotFOV and dist < shortestDistance then
                        closestPlayer = player
                        shortestDistance = dist
                    end
                end
            end
        end
    end
    return closestPlayer
end

-- Inputs
table.insert(connections, UserInputService.InputBegan:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.MouseButton2 and not gpe and aimbotEnabled then
        targetPlayer = getClosestPlayer()
    elseif input.KeyCode == Enum.KeyCode.Delete then
        running = false
    elseif input.KeyCode == Enum.KeyCode.Equals then
        aimbotEnabled = not aimbotEnabled
        targetPlayer = nil
        print("Aimbot " .. (aimbotEnabled and "Enabled" or "Disabled"))
    end
end))

table.insert(connections, UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        targetPlayer = nil
    end
end))

table.insert(connections, Players.PlayerRemoving:Connect(function(player)
    if boxes[player] then
        boxes[player]:Remove()
        boxes[player] = nil
    end
end))

-- Main loop
table.insert(connections, RunService.RenderStepped:Connect(function()
    if not running then
        fovCircle:Remove()
        for _, conn in ipairs(connections) do conn:Disconnect() end
        for _, box in pairs(boxes) do box:Remove() end
        return
    end

    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    fovCircle.Position = screenCenter
    fovCircle.Visible = true
    updateCrosshair()

    if aimbotEnabled and targetPlayer and targetPlayer.Character then
        local head = getPlayerHead(targetPlayer.Character)
        if head then
            local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
            local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
            if onScreen and dist <= aimbotFOV then
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, head.Position), aimlockSmoothness)
            else
                targetPlayer = nil
            end
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            updateBox(player)
        end
    end
end))

initializeCrosshair()
