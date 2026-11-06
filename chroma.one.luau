--[[
    Chroma.one
    Client-side player highlights, ESP, aim assist, lock-on, silent aim,
    ragebot, wallbang targeting, an ACS 2.0.1 damage bridge, local skins,
    and an amber-inspired black and purple two-column menu with a UFO logo
    and spaceship launcher.

    Right Shift or Right Control toggles the menu. The launcher stays
    visible at all times. No HTTP loader or external UI library is used.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    local deadline = os.clock() + 20
    repeat
        task.wait(0.1)
        LocalPlayer = Players.LocalPlayer
    until LocalPlayer ~= nil or os.clock() >= deadline
end

if not LocalPlayer then
    warn("[Chroma.one] LocalPlayer was not available. Join a game and execute again.")
    return
end

local function getGuiParent()
    local ok, playerGui = pcall(function()
        return LocalPlayer:FindFirstChildOfClass("PlayerGui")
            or LocalPlayer:WaitForChild("PlayerGui", 8)
    end)
    if ok and playerGui then
        return playerGui
    end

    if type(gethui) == "function" then
        local okHidden, hidden = pcall(gethui)
        if okHidden and hidden then
            return hidden
        end
    end

    local okCore, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if okCore and coreGui then
        return coreGui
    end

    return nil
end

local function showFatalError(message)
    local text = tostring(message or "Unknown error")
    warn("[Chroma.one] " .. text)

    local parent = getGuiParent()
    if not parent then
        return
    end

    local ok = pcall(function()
        local old = parent:FindFirstChild("ChromaOneError")
        if old then
            old:Destroy()
        end

        local gui = Instance.new("ScreenGui")
        gui.Name = "ChromaOneError"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 1000000
        gui.Parent = parent

        local frame = Instance.new("Frame")
        frame.Name = "ErrorWindow"
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.Position = UDim2.new(0.5, 0, 0.5, 0)
        frame.Size = UDim2.new(0, 500, 0, 230)
        frame.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
        frame.BorderSizePixel = 0
        frame.Parent = gui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 3)
        corner.Parent = frame

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 255, 255)
        stroke.Transparency = 0.2
        stroke.Parent = frame

        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Position = UDim2.new(0, 20, 0, 14)
        title.Size = UDim2.new(1, -40, 0, 24)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 16
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Text = "Chroma.one failed to load"
        title.Parent = frame

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Position = UDim2.new(0, 20, 0, 46)
        label.Size = UDim2.new(1, -40, 0, 108)
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 11
        label.TextColor3 = Color3.fromRGB(220, 220, 224)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Top
        label.TextWrapped = true
        label.Text = text
        label.Parent = frame

        local dismiss = Instance.new("TextButton")
        dismiss.Position = UDim2.new(1, -108, 1, -46)
        dismiss.Size = UDim2.new(0, 88, 0, 30)
        dismiss.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        dismiss.AutoButtonColor = false
        dismiss.BorderSizePixel = 0
        dismiss.Font = Enum.Font.GothamBold
        dismiss.TextSize = 10
        dismiss.TextColor3 = Color3.fromRGB(8, 8, 10)
        dismiss.Text = "Dismiss"
        dismiss.Parent = frame

        local dismissCorner = Instance.new("UICorner")
        dismissCorner.CornerRadius = UDim.new(0, 2)
        dismissCorner.Parent = dismiss

        dismiss.MouseButton1Click:Connect(function()
            gui:Destroy()
        end)

        if type(setclipboard) == "function" then
            local copy = Instance.new("TextButton")
            copy.Position = UDim2.new(1, -206, 1, -46)
            copy.Size = UDim2.new(0, 88, 0, 30)
            copy.BackgroundColor3 = Color3.fromRGB(23, 23, 26)
            copy.AutoButtonColor = false
            copy.BorderSizePixel = 0
            copy.Font = Enum.Font.GothamBold
            copy.TextSize = 10
            copy.TextColor3 = Color3.fromRGB(240, 240, 242)
            copy.Text = "Copy error"
            copy.Parent = frame

            local copyCorner = Instance.new("UICorner")
            copyCorner.CornerRadius = UDim.new(0, 2)
            copyCorner.Parent = copy

            copy.MouseButton1Click:Connect(function()
                pcall(setclipboard, text)
                copy.Text = "Copied"
            end)
        end
    end)

    if not ok then
        warn("[Chroma.one] Could not draw the error window.")
    end
end

local function boot()
    local CONFIG_FILE = "ChromaOne_config.json"
    local COLOR_DEFS = {
        { key = "visible", label = "Visible highlight", color = Color3.fromRGB(0, 255, 170) },
        { key = "hidden", label = "Hidden highlight", color = Color3.fromRGB(255, 58, 120) },
        { key = "aimFov", label = "Aim FOV", color = Color3.fromRGB(138, 110, 255) },
        { key = "lockFov", label = "Lock FOV", color = Color3.fromRGB(255, 196, 96) },
        { key = "rageFov", label = "Rage FOV", color = Color3.fromRGB(255, 92, 180) },
        { key = "espBox", label = "ESP box", color = Color3.fromRGB(0, 255, 170) },
        { key = "espTracer", label = "ESP tracer", color = Color3.fromRGB(0, 200, 255) },
        { key = "bulletTracer", label = "Bullet tracer", color = Color3.fromRGB(255, 255, 255) },
        { key = "espName", label = "ESP name", color = Color3.fromRGB(245, 245, 247) },
        { key = "espHealth", label = "ESP health", color = Color3.fromRGB(90, 255, 140) },
        { key = "espTool", label = "ESP tool name", color = Color3.fromRGB(203, 196, 214) },
        { key = "espTeam", label = "ESP team", color = Color3.fromRGB(180, 160, 255) },
        { key = "espSkeleton", label = "ESP skeleton", color = Color3.fromRGB(255, 255, 255) },
        { key = "espChams", label = "ESP chams", color = Color3.fromRGB(255, 61, 127) },
        { key = "espVisible", label = "ESP visible", color = Color3.fromRGB(0, 255, 120) },
        { key = "espHidden", label = "ESP hidden", color = Color3.fromRGB(255, 45, 85) },
        { key = "espArmor", label = "ESP armor", color = Color3.fromRGB(80, 170, 255) },
        { key = "espLoot", label = "ESP loot", color = Color3.fromRGB(255, 205, 60) },
        { key = "armsSkin", label = "Arms skin", color = Color3.fromRGB(255, 255, 255) },
        { key = "gunSkin", label = "Gun skin", color = Color3.fromRGB(30, 30, 34) },
    }
    local COLOR_DEF_BY_KEY = {}
    for _, definition in ipairs(COLOR_DEFS) do
        COLOR_DEF_BY_KEY[definition.key] = definition
    end

    local MATERIAL_NAMES = {
        "Plastic",
        "SmoothPlastic",
        "Neon",
        "Glass",
        "ForceField",
        "Metal",
        "Wood",
        "Marble",
        "Granite",
        "Ice",
        "Slate",
        "Concrete",
        "Brick",
        "DiamondPlate",
        "Foil",
        "Fabric",
        "Grass",
        "Sand",
        "Pebble",
        "Cobblestone",
    }
    local MATERIAL_SET = {}
    for _, name in ipairs(MATERIAL_NAMES) do
        MATERIAL_SET[name] = true
    end

    local ARM_NAMES = {
        Head = false,
        ["Left Arm"] = true,
        ["Right Arm"] = true,
        LeftUpperArm = true,
        RightUpperArm = true,
        LeftLowerArm = true,
        RightLowerArm = true,
        LeftHand = true,
        RightHand = true,
    }

    local PART_CATEGORIES = {
        {
            name = "Head",
            parts = { "Head" },
        },
        {
            name = "Torso",
            parts = { "UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart" },
        },
        {
            name = "Arms",
            parts = {
                "LeftUpperArm",
                "RightUpperArm",
                "LeftLowerArm",
                "RightLowerArm",
                "LeftHand",
                "RightHand",
                "Left Arm",
                "Right Arm",
            },
        },
        {
            name = "Legs",
            parts = {
                "LeftUpperLeg",
                "RightUpperLeg",
                "LeftLowerLeg",
                "RightLowerLeg",
                "LeftFoot",
                "RightFoot",
                "Left Leg",
                "Right Leg",
            },
        },
    }

    local NUMERIC_LIMITS = {
        fillTransparency = { 0, 1 },
        scanInterval = { 0.05, 1 },
        maxVisibilityDistance = { 100, 5000 },
        visibilityBudget = { 8, 400 },
        aimFov = { 5, 180 },
        aimMaxDistance = { 20, 3000 },
        aimSpeed = { 1, 100 },
        silentMaxDistance = { 20, 5000 },
        espMaxDistance = { 20, 5000 },
        espLootMaxDistance = { 20, 3000 },
        espBoxThickness = { 1, 8 },
        espTracerThickness = { 1, 8 },
        espBulletThickness = { 1, 8 },
        espSkeletonThickness = { 1, 6 },
        fovValue = { 50, 120 },
        lockFov = { 2, 120 },
        lockDistance = { 20, 5000 },
        lockSmoothness = { 0, 100 },
        silentFov = { 1, 360 },
        silentPrediction = { 0, 0.5 },
        rageFov = { 1, 360 },
        rageMaxDistance = { 20, 5000 },
        rageSmoothness = { 0, 100 },
        ragePrediction = { 0, 0.5 },
        rageFireDelay = { 0.03, 1 },
    }

    local function makeDefaults()
        local colors = {}
        for _, definition in ipairs(COLOR_DEFS) do
            colors[definition.key] = definition.color
        end

        return {
            highlightsEnabled = true,
            teamCheck = true,
            showKeys = true,
            fillTransparency = 0.55,
            seeThroughWalls = true,
            scanInterval = 0.18,
            maxVisibilityDistance = 1200,
            visibilityBudget = 90,

            aimEnabled = true,
            aimAlways = false,
            aimVisibleOnly = true,
            aimFov = 60,
            aimMaxDistance = 500,
            aimSpeed = 30,
            fovCircle = true,

            silentAim = false,
            silentRequireFov = false,
            silentVisibleOnly = true,
            silentWallbang = true,
            silentFov = 180,
            silentPrediction = 0.05,
            silentMaxDistance = 1000,
            silentParts = { Head = true, Torso = true, Arms = false, Legs = false },

            espEnabled = true,
            espBox = true,
            espName = true,
            espToolName = true,
            espDistance = true,
            espHealth = true,
            espArmor = true,
            espTeam = true,
            espSkeleton = true,
            espChams = false,
            espVisCheck = false,
            espLoot = true,
            espTargetOnly = false,
            espLockedOnly = false,
            espTracer = true,
            espBulletTracer = true,
            espMaxDistance = 1000,
            espLootMaxDistance = 350,
            espBoxThickness = 1,
            espTracerThickness = 1,
            espBulletThickness = 2,
            espSkeletonThickness = 1,
            espBoxStyle = "2d",
            espTracerStyle = "bottom",
            fovEnabled = false,
            fovValue = 70,

            lockEnabled = true,
            lockMode = "hold",
            lockFov = 35,
            lockDistance = 400,
            lockSmoothness = 35,
            lockVisibleOnly = false,
            lockShowFov = true,
            lockParts = { Head = true, Torso = true, Arms = false, Legs = false },

            rageEnabled = false,
            rageHold = false,
            rageVisibleOnly = true,
            rageWallbang = true,
            rageAutoFire = false,
            rageShowFov = true,
            rageFov = 180,
            rageMaxDistance = 1000,
            rageSmoothness = 100,
            ragePrediction = 0.05,
            rageFireDelay = 0.12,
            rageParts = { Head = true, Torso = true, Arms = false, Legs = false },

            armsSkinEnabled = false,
            armsForceVisible = false,
            armsMaterial = "Plastic",
            gunSkinEnabled = false,
            gunMaterial = "Plastic",

            colors = colors,
        }
    end

    local Config = makeDefaults()

    local function colorToHex(color)
        return string.format(
            "#%02X%02X%02X",
            math.floor(math.clamp(color.R, 0, 1) * 255 + 0.5),
            math.floor(math.clamp(color.G, 0, 1) * 255 + 0.5),
            math.floor(math.clamp(color.B, 0, 1) * 255 + 0.5)
        )
    end

    local function hexToColor(value)
        if type(value) ~= "string" then
            return nil
        end
        local red, green, blue = value:match("^#?(%x%x)(%x%x)(%x%x)$")
        if not red then
            return nil
        end
        return Color3.fromRGB(tonumber(red, 16), tonumber(green, 16), tonumber(blue, 16))
    end

    local function getMaterialByName(name)
        if MATERIAL_SET[name] ~= true then
            return nil
        end
        local ok, material = pcall(function()
            return Enum.Material[name]
        end)
        if ok then
            return material
        end
        return nil
    end

    local Theme = {
        bg = Color3.fromRGB(8, 5, 11),
        bg2 = Color3.fromRGB(15, 10, 20),
        top = Color3.fromRGB(10, 6, 13),
        side = Color3.fromRGB(12, 8, 16),
        card = Color3.fromRGB(17, 12, 22),
        card2 = Color3.fromRGB(26, 18, 34),
        card3 = Color3.fromRGB(43, 29, 55),
        line = Color3.fromRGB(61, 40, 73),
        text = Color3.fromRGB(238, 232, 243),
        muted = Color3.fromRGB(145, 128, 156),
        white = Color3.fromRGB(255, 255, 255),
        black = Color3.fromRGB(4, 3, 6),
        accent = Color3.fromRGB(255, 61, 127),
        accent2 = Color3.fromRGB(255, 120, 174),
        accentDim = Color3.fromRGB(116, 34, 68),
    }
    local FONT = Enum.Font.Gotham
    local FONT_BOLD = Enum.Font.GothamBold

    local UI: { [string]: any } = {}
    local highlightFolder
    local selectedColorKey = "visible"
    local highlights = {}
    local visibilityState = {}
    local watchedPlayers = {}
    local characterPartsCache = setmetatable({}, { __mode = "k" })
    local espObjects = {}
    local lootScanClock = -math.huge
    local originalPartProps = setmetatable({}, { __mode = "k" })
    local localCharacterWatched = nil

    local updateStats
    local notify
    local setMenuOpen
    local showPage
    local refreshColorTargets
    local refreshColorEditor
    local refreshAllControls
    local updateESP
    local updateLock
    local refreshLockStatus
    local lockStatusLabel
    local updateSilentStatus
    local lockTarget = nil
    local lockPart = nil

    local DEFAULT_TEAM_COLORS = {
        [BrickColor.new("White").Number] = true,
        [BrickColor.new("Medium stone grey").Number] = true,
    }

    local function isTeammate(player)
        if player == LocalPlayer then
            return true
        end
        if not Config.teamCheck then
            return false
        end

        local localTeam = LocalPlayer.Team
        if localTeam ~= nil then
            return player.Team == localTeam
        end

        if player.Team == nil then
            local localColor = LocalPlayer.TeamColor
            if not DEFAULT_TEAM_COLORS[localColor.Number] then
                return player.TeamColor == localColor
            end
        end

        return false
    end

    local function isEligible(player)
        return player ~= LocalPlayer
            and player.Parent == Players
            and not isTeammate(player)
    end

    local function removeHighlight(player)
        local highlight = highlights[player]
        if highlight then
            highlight:Destroy()
            highlights[player] = nil
        end
        visibilityState[player] = nil
    end

    local function applyHighlightStyle(player, isVisible)
        local highlight = highlights[player]
        if not highlight then
            return
        end

        local character = player.Character
        local chams = Config.espEnabled and Config.espChams
        local chamColor = Config.colors.espChams
        if Config.espVisCheck then
            chamColor = isVisible and Config.colors.espVisible or Config.colors.espHidden
        end
        local color = chams
            and chamColor
            or (isVisible and Config.colors.visible or Config.colors.hidden)

        highlight.Adornee = character
        highlight.FillColor = color
        highlight.OutlineColor = color
        highlight.FillTransparency = chams and 0.42 or Config.fillTransparency
        highlight.OutlineTransparency = chams and 0.12 or 0
        highlight.DepthMode = (chams or Config.seeThroughWalls)
            and Enum.HighlightDepthMode.AlwaysOnTop
            or Enum.HighlightDepthMode.Occluded
        highlight.Enabled = (Config.highlightsEnabled or chams)
            and character ~= nil
            and character.Parent ~= nil

        visibilityState[player] = isVisible
    end

    local function ensureHighlight(player)
        if not isEligible(player) then
            removeHighlight(player)
            return nil
        end

        local highlight = highlights[player]
        if not highlight or not highlight.Parent then
            highlight = Instance.new("Highlight")
            highlight.Name = "Chroma_" .. tostring(player.UserId)
            highlight.Parent = highlightFolder
            highlights[player] = highlight
        end

        applyHighlightStyle(player, visibilityState[player] == true)
        return highlight
    end

    local function restyleAll()
        for player in pairs(highlights) do
            applyHighlightStyle(player, visibilityState[player] == true)
        end
    end

    for _, folderName in ipairs({ "ChromaOne", "ChromaOneHighlights" }) do
        local oldFolder = Workspace:FindFirstChild(folderName)
        if oldFolder then
            oldFolder:Destroy()
        end
    end

    highlightFolder = Instance.new("Folder")
    highlightFolder.Name = "ChromaOne"
    highlightFolder.Parent = Workspace

    local function watchPlayer(player)
        if watchedPlayers[player] then
            return
        end
        watchedPlayers[player] = true

        player.CharacterAdded:Connect(function(character)
            characterPartsCache[character] = nil
            visibilityState[player] = nil
            task.defer(function()
                if isEligible(player) then
                    ensureHighlight(player)
                end
                if updateStats then
                    updateStats()
                end
            end)
        end)

        player.CharacterRemoving:Connect(function(character)
            characterPartsCache[character] = nil
            local highlight = highlights[player]
            if highlight then
                highlight.Adornee = nil
                highlight.Enabled = false
            end
            visibilityState[player] = nil
        end)

        local function handleTeamChange()
            visibilityState[player] = nil
            if isEligible(player) then
                ensureHighlight(player)
            else
                removeHighlight(player)
            end
            if updateStats then
                updateStats()
            end
        end

        player:GetPropertyChangedSignal("Team"):Connect(handleTeamChange)
        player:GetPropertyChangedSignal("TeamColor"):Connect(handleTeamChange)
    end

    local function refreshAllHighlights()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                watchPlayer(player)
            end
            if isEligible(player) then
                ensureHighlight(player)
            else
                removeHighlight(player)
            end
        end
    end

    -- Visibility detection ---------------------------------------------------

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.IgnoreWater = true

    local raycastBypass = 0
    local rawWorkspaceRaycast = Workspace.Raycast

    local function updateRaycastFilter()
        local filter = { highlightFolder }
        if LocalPlayer.Character then
            filter[#filter + 1] = LocalPlayer.Character
        end
        raycastParams.FilterDescendantsInstances = filter
    end

    -- Chroma's own visibility checks must never be redirected by the shot hook.
    local function rawRaycast(origin, direction, params)
        local previous = raycastBypass
        raycastBypass = previous + 1

        local ok, result = pcall(
            rawWorkspaceRaycast,
            Workspace,
            origin,
            direction,
            params or raycastParams
        )
        if not ok then
            ok, result = pcall(function()
                return Workspace:Raycast(origin, direction, params or raycastParams)
            end)
        end

        raycastBypass = previous
        if ok then
            return result
        end
        return nil
    end

    local PART_PRIORITY = {
        Head = 1,
        UpperTorso = 2,
        HumanoidRootPart = 3,
        LowerTorso = 4,
        Torso = 5,
        LeftUpperArm = 6,
        RightUpperArm = 7,
        LeftUpperLeg = 8,
        RightUpperLeg = 9,
    }

    local function getCharacterParts(character)
        local cached = characterPartsCache[character]
        if cached then
            return cached
        end

        local parts = {}
        for _, descendant in ipairs(character:GetDescendants()) do
            if descendant:IsA("BasePart") then
                local transparency = descendant.Transparency or 0
                local localTransparency = descendant.LocalTransparencyModifier or 0
                if transparency < 0.95 and localTransparency < 0.95 then
                    parts[#parts + 1] = descendant
                end
            end
        end

        table.sort(parts, function(a, b)
            local priorityA = PART_PRIORITY[a.Name] or 50
            local priorityB = PART_PRIORITY[b.Name] or 50
            if priorityA == priorityB then
                return a.Name < b.Name
            end
            return priorityA < priorityB
        end)

        characterPartsCache[character] = parts
        return parts
    end

    local function castFromScreen(camera, character, screenX, screenY, maxDistance)
        local ray = camera:ViewportPointToRay(screenX, screenY)
        local result = rawRaycast(
            ray.Origin,
            ray.Direction * maxDistance,
            raycastParams
        )
        return result ~= nil and result.Instance:IsDescendantOf(character)
    end

    local function isPartVisible(part, character, camera, distance, viewport, budget)
        local rayLength = distance + part.Size.Magnitude + 20
        local centerPoint, centerOnScreen = camera:WorldToViewportPoint(part.Position)

        if centerOnScreen and centerPoint.Z > 0 then
            if budget <= 0 then
                return false, budget
            end
            budget -= 1
            if castFromScreen(camera, character, centerPoint.X, centerPoint.Y, rayLength) then
                return true, budget
            end
        end

        local half = part.Size * 0.5
        local partCFrame = part.CFrame
        local minX, minY = math.huge, math.huge
        local maxX, maxY = -math.huge, -math.huge
        local hasCorner = false

        for _, xSign in ipairs({ -1, 1 }) do
            for _, ySign in ipairs({ -1, 1 }) do
                for _, zSign in ipairs({ -1, 1 }) do
                    local worldCorner = partCFrame:PointToWorldSpace(
                        Vector3.new(half.X * xSign, half.Y * ySign, half.Z * zSign)
                    )
                    local screenPoint = camera:WorldToViewportPoint(worldCorner)
                    if screenPoint.Z > 0 then
                        hasCorner = true
                        minX = math.min(minX, screenPoint.X)
                        minY = math.min(minY, screenPoint.Y)
                        maxX = math.max(maxX, screenPoint.X)
                        maxY = math.max(maxY, screenPoint.Y)
                    end
                end
            end
        end

        if not hasCorner then
            return false, budget
        end

        minX = math.clamp(minX, 0, viewport.X - 1)
        minY = math.clamp(minY, 0, viewport.Y - 1)
        maxX = math.clamp(maxX, 0, viewport.X - 1)
        maxY = math.clamp(maxY, 0, viewport.Y - 1)

        if maxX <= minX then
            maxX = math.min(viewport.X - 1, minX + 1)
        end
        if maxY <= minY then
            maxY = math.min(viewport.Y - 1, minY + 1)
        end

        local samples = 2
        if part.Name == "Head" or part.Name == "UpperTorso" or part.Name == "Torso" then
            samples = 3
        end

        for column = 0, samples - 1 do
            local screenX = minX + ((column + 0.5) / samples) * (maxX - minX)
            for row = 0, samples - 1 do
                if budget <= 0 then
                    return false, budget
                end
                budget -= 1
                local screenY = minY + ((row + 0.5) / samples) * (maxY - minY)
                if castFromScreen(camera, character, screenX, screenY, rayLength) then
                    return true, budget
                end
            end
        end

        return false, budget
    end

    local function isPlayerVisible(player, camera)
        local character = player.Character
        if not character or not character.Parent then
            return false
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health <= 0 then
            return false
        end

        local parts = getCharacterParts(character)
        if #parts == 0 then
            return false
        end

        local cameraPosition = camera.CFrame.Position
        local viewport = camera.ViewportSize
        if viewport.X < 2 or viewport.Y < 2 then
            return false
        end
        local budget = Config.visibilityBudget

        for _, part in ipairs(parts) do
            local distance = (part.Position - cameraPosition).Magnitude
            if distance <= Config.maxVisibilityDistance then
                local visible
                visible, budget = isPartVisible(
                    part,
                    character,
                    camera,
                    distance,
                    viewport,
                    budget
                )
                if visible then
                    return true
                end
                if budget <= 0 then
                    return false
                end
            end
        end

        return false
    end

    local scanClock = 0

    RunService.Heartbeat:Connect(function(deltaTime)
        scanClock += deltaTime
        if scanClock < Config.scanInterval then
            return
        end
        scanClock = 0

        local visCheckOnly = Config.espEnabled and Config.espVisCheck

        if not Config.highlightsEnabled and not visCheckOnly then
            for _, highlight in pairs(highlights) do
                highlight.Enabled = false
            end
            return
        end

        local camera = Workspace.CurrentCamera
        if not camera then
            return
        end

        updateRaycastFilter()

        if not Config.highlightsEnabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    watchPlayer(player)
                    if isEligible(player) then
                        visibilityState[player] = isPlayerVisible(player, camera)
                    else
                        removeHighlight(player)
                    end
                end
            end
            if updateStats then
                updateStats()
            end
            return
        end

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                watchPlayer(player)
                if isEligible(player) then
                    local character = player.Character
                    local playerVisible = character ~= nil and isPlayerVisible(player, camera)
                    local highlight = highlights[player]

                    if not highlight then
                        highlight = ensureHighlight(player)
                    end

                    if highlight then
                        if visibilityState[player] ~= playerVisible then
                            applyHighlightStyle(player, playerVisible)
                        else
                            if highlight.Adornee ~= character then
                                highlight.Adornee = character
                            end
                            highlight.Enabled = character ~= nil and character.Parent ~= nil
                        end
                    end
                else
                    removeHighlight(player)
                end
            end
        end

        if updateStats then
            updateStats()
        end
    end)

    -- Aim assist -------------------------------------------------------------

    local AIM_PART_NAMES = {
        "Head",
        "UpperTorso",
        "LowerTorso",
        "Torso",
        "HumanoidRootPart",
        "LeftUpperArm",
        "RightUpperArm",
        "Left Arm",
        "Right Arm",
    }

    local aimTarget = nil
    local aimPartName = nil
    local aimScanClock = 0

    local function canSeeWorldPoint(camera, character, worldPoint)
        local origin = camera.CFrame.Position
        local direction = worldPoint - origin
        if direction.Magnitude < 0.1 then
            return false
        end

        local result = rawRaycast(origin, direction, raycastParams)
        return result ~= nil and result.Instance:IsDescendantOf(character)
    end

    local function getAimPoint(camera, character, fallbackPart)
        for _, partName in ipairs(AIM_PART_NAMES) do
            local part = character:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                if not Config.aimVisibleOnly
                    or canSeeWorldPoint(camera, character, part.Position) then
                    return part.Position, partName
                end
            end
        end

        if fallbackPart and fallbackPart:IsA("BasePart") then
            if not Config.aimVisibleOnly
                or canSeeWorldPoint(camera, character, fallbackPart.Position) then
                return fallbackPart.Position, fallbackPart.Name
            end
        end

        return nil, nil
    end

    local function findAimTarget(camera)
        updateRaycastFilter()

        local cameraPosition = camera.CFrame.Position
        local lookVector = camera.CFrame.LookVector
        local halfFov = math.clamp(Config.aimFov, 1, 179) * 0.5
        local bestPlayer = nil
        local bestPartName = nil
        local bestScore = math.huge

        for _, player in ipairs(Players:GetPlayers()) do
            if isEligible(player) then
                local character = player.Character
                if character and character.Parent then
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        local anchor = character:FindFirstChild("Head")
                            or character:FindFirstChild("HumanoidRootPart")
                            or character:FindFirstChildWhichIsA("BasePart", true)

                        if anchor and anchor:IsA("BasePart") then
                            local offset = anchor.Position - cameraPosition
                            local distance = offset.Magnitude

                            if distance > 0.1 and distance <= Config.aimMaxDistance then
                                local angle = math.deg(
                                    math.acos(
                                        math.clamp(lookVector:Dot(offset.Unit), -1, 1)
                                    )
                                )

                                if angle <= halfFov then
                                    local aimPoint, partName = getAimPoint(
                                        camera,
                                        character,
                                        anchor
                                    )
                                    if aimPoint then
                                        local score = angle * 100
                                            + (aimPoint - cameraPosition).Magnitude
                                        if score < bestScore then
                                            bestScore = score
                                            bestPlayer = player
                                            bestPartName = partName
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        return bestPlayer, bestPartName
    end

    local function updateAim(deltaTime)
        if not Config.aimEnabled then
            return
        end

        if UserInputService:GetFocusedTextBox() ~= nil then
            return
        end

        local holding = Config.aimAlways
            or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)

        if not holding then
            aimTarget = nil
            aimPartName = nil
            return
        end

        if aimTarget and not isEligible(aimTarget) then
            aimTarget = nil
            aimPartName = nil
        end

        local camera = Workspace.CurrentCamera
        if not camera then
            return
        end

        aimScanClock += deltaTime
        if aimScanClock >= 0.1
            or aimTarget == nil
            or aimTarget.Parent ~= Players then
            aimScanClock = 0
            aimTarget, aimPartName = findAimTarget(camera)
        end

        if not aimTarget then
            return
        end

        local character = aimTarget.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not character
            or not character.Parent
            or not humanoid
            or humanoid.Health <= 0 then
            aimTarget = nil
            return
        end

        local part = aimPartName and character:FindFirstChild(aimPartName)
        if not part or not part:IsA("BasePart") then
            aimTarget = nil
            return
        end

        if Config.aimVisibleOnly
            and not canSeeWorldPoint(camera, character, part.Position) then
            aimTarget = nil
            aimPartName = nil
            return
        end

        local cameraPosition = camera.CFrame.Position
        local targetPosition = part.Position
        if (targetPosition - cameraPosition).Magnitude < 0.1 then
            return
        end

        local desired = CFrame.lookAt(cameraPosition, targetPosition)
        local alpha = math.clamp((Config.aimSpeed / 100) * deltaTime * 60, 0, 1)
        camera.CFrame = camera.CFrame:Lerp(desired, alpha)
    end

    -- Rage bot ---------------------------------------------------------------

    local rageTarget = nil
    local ragePartName = nil
    local rageScanClock = 0
    local rageNextFire = 0

    local mouse1clickFn = mouse1click
    if type(mouse1clickFn) ~= "function" and type(getgenv) == "function" then
        local okEnv, env = pcall(getgenv)
        if okEnv and type(env) == "table" then
            mouse1clickFn = env.mouse1click
        end
    end

    local function getRageParts(character)
        local parts = {}
        for _, category in ipairs(PART_CATEGORIES) do
            if Config.rageParts[category.name] then
                for _, partName in ipairs(category.parts) do
                    local part = character:FindFirstChild(partName)
                    if part and part:IsA("BasePart") then
                        parts[#parts + 1] = part
                        break
                    end
                end
            end
        end
        if #parts == 0 then
            local fallback = character:FindFirstChild("HumanoidRootPart")
                or character:FindFirstChildWhichIsA("BasePart", true)
            if fallback and fallback:IsA("BasePart") then
                parts[1] = fallback
            end
        end
        return parts
    end

    local function predictRagePoint(part)
        if Config.ragePrediction and Config.ragePrediction > 0 then
            local ok, point = pcall(function()
                return part.Position + part.AssemblyLinearVelocity * Config.ragePrediction
            end)
            if ok and point then
                return point
            end
        end
        return part.Position
    end

    local function findRageTarget(camera)
        updateRaycastFilter()

        local cameraPosition = camera.CFrame.Position
        local lookVector = camera.CFrame.LookVector
        local halfFov = math.clamp(Config.rageFov or 180, 1, 360) * 0.5
        local bestPlayer = nil
        local bestPartName = nil
        local bestPoint = nil
        local bestScore = math.huge

        for _, player in ipairs(Players:GetPlayers()) do
            if isEligible(player) then
                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if character
                    and character.Parent
                    and humanoid
                    and humanoid.Health > 0 then
                    for _, part in ipairs(getRageParts(character)) do
                        local point = predictRagePoint(part)
                        local offset = point - cameraPosition
                        local distance = offset.Magnitude

                        if distance > 0.1 and distance <= Config.rageMaxDistance then
                            local angle = math.deg(
                                math.acos(
                                    math.clamp(lookVector:Dot(offset.Unit), -1, 1)
                                )
                            )

                            if angle <= halfFov then
                                local visible = true
                                if Config.rageVisibleOnly and not Config.rageWallbang then
                                    visible = canSeeWorldPoint(
                                        camera,
                                        character,
                                        part.Position
                                    )
                                end

                                if visible then
                                    local score = angle * 2 + distance * 0.05
                                    if score < bestScore then
                                        bestScore = score
                                        bestPlayer = player
                                        bestPartName = part.Name
                                        bestPoint = point
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        return bestPlayer, bestPartName, bestPoint
    end

    local function refreshRageStatus()
        if not UI.rageStatusLabel then
            return
        end

        if not Config.rageEnabled then
            UI.rageStatusLabel.Text = "disabled"
            UI.rageStatusLabel.TextColor3 = Theme.muted
        elseif rageTarget
            and ragePartName
            and rageTarget.Parent == Players then
            local displayName = rageTarget.DisplayName or rageTarget.Name
            UI.rageStatusLabel.Text = "locked · " .. displayName .. " · " .. ragePartName
            UI.rageStatusLabel.TextColor3 = Theme.accent
        else
            UI.rageStatusLabel.Text = "searching"
            UI.rageStatusLabel.TextColor3 = Theme.muted
        end
    end

    local function updateRage(deltaTime)
        if not Config.rageEnabled then
            rageTarget = nil
            ragePartName = nil
            refreshRageStatus()
            return false
        end

        if UserInputService:GetFocusedTextBox() ~= nil then
            return false
        end

        if Config.rageHold
            and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            rageTarget = nil
            ragePartName = nil
            refreshRageStatus()
            return false
        end

        local camera = Workspace.CurrentCamera
        if not camera then
            return false
        end

        if rageTarget and not isEligible(rageTarget) then
            rageTarget = nil
            ragePartName = nil
        end

        rageScanClock += deltaTime
        if rageScanClock >= 0.08
            or rageTarget == nil
            or rageTarget.Parent ~= Players then
            rageScanClock = 0
            rageTarget, ragePartName = findRageTarget(camera)
        end

        if not rageTarget or not ragePartName then
            refreshRageStatus()
            return false
        end

        local character = rageTarget.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not character
            or not character.Parent
            or not humanoid
            or humanoid.Health <= 0 then
            rageTarget = nil
            ragePartName = nil
            refreshRageStatus()
            return false
        end

        local part = character:FindFirstChild(ragePartName)
        if not part or not part:IsA("BasePart") then
            rageTarget = nil
            ragePartName = nil
            refreshRageStatus()
            return false
        end

        if Config.rageVisibleOnly and not Config.rageWallbang then
            if not canSeeWorldPoint(camera, character, part.Position) then
                rageTarget = nil
                ragePartName = nil
                refreshRageStatus()
                return false
            end
        end

        local point = predictRagePoint(part)
        local direction = point - camera.CFrame.Position
        if direction.Magnitude > 0.01 then
            local desired = CFrame.lookAt(camera.CFrame.Position, point)
            local alpha = math.clamp((Config.rageSmoothness or 100) / 100, 0.08, 1)
            camera.CFrame = camera.CFrame:Lerp(desired, alpha)
        end

        refreshRageStatus()

        if Config.rageAutoFire and type(mouse1clickFn) == "function" then
            local now = os.clock()
            if now >= rageNextFire then
                rageNextFire = now + math.clamp(Config.rageFireDelay or 0.12, 0.03, 1)
                pcall(mouse1clickFn)
            end
        end

        return true
    end

    -- Silent aim -------------------------------------------------------------

    local silentCachePart = nil
    local silentCachePoint = nil
    local silentCacheTime = 0
    local silentHookMode = "none"
    local silentResolving = false

    local function getSilentParts(character)
        local parts = {}

        for _, category in ipairs(PART_CATEGORIES) do
            if Config.silentParts[category.name] then
                for _, partName in ipairs(category.parts) do
                    local part = character:FindFirstChild(partName)
                    if part and part:IsA("BasePart") then
                        parts[#parts + 1] = part
                        break
                    end
                end
            end
        end

        if #parts == 0 then
            local fallback = character:FindFirstChild("HumanoidRootPart")
                or character:FindFirstChildWhichIsA("BasePart", true)
            if fallback and fallback:IsA("BasePart") then
                parts[1] = fallback
            end
        end

        return parts
    end

    local function predictPartPoint(part, seconds)
        if seconds and seconds > 0 then
            local ok, point = pcall(function()
                return part.Position + part.AssemblyLinearVelocity * seconds
            end)
            if ok and point then
                return point
            end
        end
        return part.Position
    end

    local function getSilentTarget()
        if not Config.silentAim then
            return nil, nil
        end

        local now = os.clock()
        if now < silentCacheTime + 0.08 then
            return silentCachePart, silentCachePoint
        end

        silentCacheTime = now
        silentCachePart = nil
        silentCachePoint = nil

        local camera = Workspace.CurrentCamera
        if not camera then
            return nil, nil
        end

        updateRaycastFilter()

        local cameraPosition = camera.CFrame.Position
        local lookVector = camera.CFrame.LookVector
        local fovLimit = Config.silentRequireFov
            and math.clamp(Config.silentFov or 180, 1, 360) * 0.5
            or 180
        local bestScore = math.huge

        for _, player in ipairs(Players:GetPlayers()) do
            if isEligible(player) then
                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if character
                    and character.Parent
                    and humanoid
                    and humanoid.Health > 0 then
                    for _, part in ipairs(getSilentParts(character)) do
                        local aimPoint = predictPartPoint(part, Config.silentPrediction)
                        local offset = aimPoint - cameraPosition
                        local distance = offset.Magnitude

                        if distance > 0.1 and distance <= Config.silentMaxDistance then
                            local angle = math.deg(
                                math.acos(
                                    math.clamp(lookVector:Dot(offset.Unit), -1, 1)
                                )
                            )

                            if angle <= fovLimit then
                                local visible = true
                                if Config.silentVisibleOnly
                                    and not Config.silentWallbang then
                                    visible = canSeeWorldPoint(
                                        camera,
                                        character,
                                        part.Position
                                    )
                                end

                                if visible then
                                    local score = angle * 2 + distance * 0.05
                                    if score < bestScore then
                                        bestScore = score
                                        silentCachePart = part
                                        silentCachePoint = aimPoint
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        return silentCachePart, silentCachePoint
    end

    local function safeSilentTarget()
        if silentResolving then
            return nil, nil
        end
        silentResolving = true
        local ok, part, point = pcall(getSilentTarget)
        silentResolving = false
        if not ok then
            return nil, nil
        end
        return part, point
    end

    local mouse = nil
    do
        local okMouse, mouseResult = pcall(function()
            return LocalPlayer:GetMouse()
        end)
        if okMouse and mouseResult then
            mouse = mouseResult
        end
    end

    local hookFunction = hookfunction
    local hookMetamethod = hookmetamethod
    local getRawMetatable = getrawmetatable
    local setReadonlyFn = setreadonly
    local newCClosure = newcclosure
    local getNamecallmethod = getnamecallmethod

    if type(getgenv) == "function" then
        local okEnv, env = pcall(getgenv)
        if okEnv and type(env) == "table" then
            hookFunction = hookFunction or env.hookfunction
            hookMetamethod = hookMetamethod or env.hookmetamethod
            getRawMetatable = getRawMetatable or env.getrawmetatable
            setReadonlyFn = setReadonlyFn or env.setreadonly
            newCClosure = newCClosure or env.newcclosure
            getNamecallmethod = getNamecallmethod or env.getnamecallmethod
        end
    end

    if type(newCClosure) ~= "function" then
        newCClosure = function(fn)
            return fn
        end
    end

    local silentAvailable = false
    local silentHooksInstalled = false
    local silentHooksAttempted = false
    local installedHooks = {}

    local function resolveSilentPoint()
        local part, point = safeSilentTarget()
        if part and point then
            return part, point
        end
        return nil, nil
    end

    -- Workspace ray interception ------------------------------------------------

    local function resolveShotTarget()
        if Config.silentAim then
            local part, point = safeSilentTarget()
            if part and point and part.Parent then
                return part, point, Config.silentWallbang == true
            end
        end

        if Config.rageEnabled and rageTarget and ragePartName then
            local character = rageTarget.Character
            local part = character and character:FindFirstChild(ragePartName)
            if part and part:IsA("BasePart") then
                return part, part.Position, Config.rageWallbang == true
            end
        end

        return nil, nil, false
    end

    -- ACS bridge ---------------------------------------------------------------

    local ACS_ATTACHMENTS = {
        ZoomValue = 70,
        Zoom2Value = 70,
        AimRM = 1,
        SpreadRM = 1,
        DamageMod = 1,
        minDamageMod = 1,
        MinRecoilPower = 1,
        MaxRecoilPower = 1,
        RecoilPowerStepAmount = 1,
        MinSpread = 1,
        MaxSpread = 1,
        AimInaccuracyStepAmount = 1,
        AimInaccuracyDecrease = 1,
        WalkMult = 1,
        adsTime = 1,
        MuzzleVelocity = 1,
        camRecoilMod = {
            RecoilTilt = 1,
            RecoilUp = 1,
            RecoilLeft = 1,
            RecoilRight = 1,
        },
        gunRecoilMod = {
            RecoilUp = 1,
            RecoilTilt = 1,
            RecoilLeft = 1,
            RecoilRight = 1,
        },
    }

    local ACS = {
        events = nil,
        damage = nil,
        access = nil,
        shoot = nil,
        atirar = nil,
        token = nil,
        tokenTime = 0,
        nextRefresh = 0,
        lastInject = 0,
    }

    local function refreshACS()
        local now = os.clock()
        if now < ACS.nextRefresh then
            return ACS.damage ~= nil
        end
        ACS.nextRefresh = now + 1

        local okReplicated, replicated = pcall(function()
            return game:GetService("ReplicatedStorage")
        end)
        if not okReplicated or not replicated then
            return false
        end

        local engine = replicated:FindFirstChild("ACS_Engine")
        local events = engine and engine:FindFirstChild("Events")
        if not events then
            ACS.events = nil
            ACS.damage = nil
            ACS.access = nil
            ACS.shoot = nil
            ACS.atirar = nil
            return false
        end

        ACS.events = events
        ACS.damage = events:FindFirstChild("Damage")
        ACS.access = events:FindFirstChild("AcessId")
            or events:FindFirstChild("AccessId")
        ACS.atirar = events:FindFirstChild("Atirar")

        local weaponFolder = events:FindFirstChild("Weapon")
        ACS.shoot = weaponFolder and weaponFolder:FindFirstChild("Shoot") or nil
        if not ACS.shoot then
            ACS.shoot = events:FindFirstChild("Shoot")
        end

        return ACS.damage ~= nil
    end

    local function getACSEquipped()
        local character = LocalPlayer.Character
        if not character then
            return nil, nil
        end
        local tool = character:FindFirstChildWhichIsA("Tool")
        if not tool then
            return nil, nil
        end
        local settings = tool:FindFirstChild("ACS_Settings")
        if not settings then
            return nil, nil
        end
        local ok, cfg = pcall(require, settings)
        if not ok or type(cfg) ~= "table" then
            return nil, nil
        end
        return tool, cfg
    end

    local function getHumanoidFromPart(part)
        local node = part
        for _ = 1, 8 do
            if not node then
                return nil, nil
            end
            local humanoid = node:FindFirstChildOfClass("Humanoid")
            if humanoid then
                return humanoid, node
            end
            node = node.Parent
        end
        return nil, nil
    end

    local function acsHitZone(partName)
        local lower = string.lower(partName or "")
        if lower == "head"
            or lower == "top"
            or lower == "headset"
            or lower == "olho"
            or lower == "face"
            or lower == "numero" then
            return 1
        end
        if lower == "torso"
            or lower == "uppertorso"
            or lower == "lowertorso"
            or lower == "humanoidrootpart"
            or lower == "chest"
            or lower == "waist"
            or string.find(lower, "arm", 1, true) then
            return 2
        end
        return 3
    end

    local function getACSToken()
        local now = os.clock()
        if ACS.token and now - ACS.tokenTime < 30 then
            return ACS.token
        end
        refreshACS()
        if not ACS.access then
            return nil
        end
        local ok, sessionId = pcall(
            ACS.access.InvokeServer,
            ACS.access,
            LocalPlayer.UserId
        )
        if not ok or sessionId == nil then
            return nil
        end
        ACS.token = tostring(sessionId) .. "-" .. tostring(LocalPlayer.UserId)
        ACS.tokenTime = now
        return ACS.token
    end

    local function isACSShotRemote(object)
        if not object then
            return false
        end
        if object == ACS.shoot or object == ACS.atirar then
            return true
        end
        refreshACS()
        return object == ACS.shoot or object == ACS.atirar
    end

    local function injectACSDamage()
        local now = os.clock()
        if now - ACS.lastInject < 0.025 then
            return
        end

        local part, point, wallbang = resolveShotTarget()
        if not (part and point and part.Parent) then
            return
        end

        local camera = Workspace.CurrentCamera
        if not camera then
            return
        end

        local humanoid, character = getHumanoidFromPart(part)
        if not humanoid or humanoid.Health <= 0 then
            return
        end

        local visible = canSeeWorldPoint(camera, character, point)
        if not wallbang and not visible then
            return
        end
        if visible and wallbang then
            -- When the camera is already lined up with a visible target,
            -- the native ACS trace will register the shot by itself.
            -- Injecting here as well would apply the same hit twice.
            local look = camera.CFrame.LookVector
            local toTarget = point - camera.CFrame.Position
            if toTarget.Magnitude > 0.1
                and look:Dot(toTarget.Unit) >= 0.999 then
                return
            end
        end

        local tool, cfg = getACSEquipped()
        if not tool or not cfg then
            return
        end

        refreshACS()
        if not ACS.damage then
            return
        end

        ACS.lastInject = now

        local root = LocalPlayer.Character
            and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local origin = root and root.Position or camera.CFrame.Position
        local distance = (point - origin).Magnitude
        local hitZone = acsHitZone(part.Name)

        task.spawn(function()
            local token = getACSToken()
            if not token then
                return
            end
            local ok = pcall(function()
                ACS.damage:InvokeServer(
                    tool,
                    humanoid,
                    distance,
                    hitZone,
                    cfg,
                    ACS_ATTACHMENTS,
                    nil,
                    nil,
                    token
                )
            end)
            if not ok then
                ACS.token = nil
            end
        end)
    end

    local function tryACSShot()
        if not Config.silentAim and not Config.rageEnabled then
            return
        end
        if not refreshACS() then
            return
        end
        injectACSDamage()
    end

    local function shotRayContext(origin, direction)
        local camera = Workspace.CurrentCamera
        local character = LocalPlayer.Character
        if not camera or not character or not direction then
            return nil, nil, false
        end

        local tool = character:FindFirstChildWhichIsA("Tool")
        if not tool then
            return nil, nil, false
        end

        local okLength, length = pcall(function()
            return direction.Magnitude
        end)
        if not okLength or length < 6 then
            return nil, nil, false
        end

        local originNearCamera = false
        local okOrigin, originDistance = pcall(function()
            return (origin - camera.CFrame.Position).Magnitude
        end)
        if okOrigin and originDistance <= 18 then
            originNearCamera = true
        end

        if not originNearCamera then
            local handle = tool:FindFirstChild("Handle")
            local okHandle, handleDistance = pcall(function()
                return handle and (origin - handle.Position).Magnitude or math.huge
            end)
            if not okHandle or handleDistance > 12 then
                return nil, nil, false
            end
        end

        local okLook, alignment = pcall(function()
            return direction.Unit:Dot(camera.CFrame.LookVector)
        end)
        if not okLook or alignment < 0.35 then
            return nil, nil, false
        end

        local part, point, wallbang = resolveShotTarget()
        if not part or not point or not part.Parent then
            return nil, nil, false
        end

        local okTarget, targetDistance = pcall(function()
            return (point - origin).Magnitude
        end)
        if not okTarget or targetDistance < 1 or targetDistance > length + 8 then
            return nil, nil, false
        end

        return part, point, wallbang == true
    end

    local function hitBelongsTo(result, part)
        if not result or not result.Instance or not part then
            return false
        end
        if result.Instance == part then
            return true
        end
        local parent = part.Parent
        return parent ~= nil and result.Instance:IsDescendantOf(parent)
    end

    local function interceptCast(origin, direction, params)
        local part, point, wallbang = shotRayContext(origin, direction)
        if not part then
            return nil, nil, nil
        end

        local direct = rawRaycast(origin, point - origin, params)
        if hitBelongsTo(direct, part) then
            return part, point, direct
        end

        if not wallbang then
            return nil, nil, nil
        end

        local unit = (point - origin).Unit
        for _, back in ipairs({ 0.75, 1.5, 3, 6, 10 }) do
            for _, forward in ipairs({ 2, 4, 8, 14, 24 }) do
                local result = rawRaycast(point - unit * back, unit * forward, params)
                if hitBelongsTo(result, part) then
                    return part, point, result
                end
            end
        end

        return part, point, nil
    end

    local function interceptLegacy(origin, direction)
        local part, point, wallbang = shotRayContext(origin, direction)
        if not part then
            return nil
        end

        local direct = rawRaycast(origin, point - origin, raycastParams)
        if hitBelongsTo(direct, part) then
            return part, point, direct.Normal, direct.Material
        end

        if wallbang then
            return part, point, Vector3.new(0, 1, 0), part.Material
        end

        return nil
    end

    local function targetScreenPoint(point)
        local camera = Workspace.CurrentCamera
        if not camera or not point then
            return nil
        end
        local ok, screen = pcall(function()
            return camera:WorldToViewportPoint(point)
        end)
        if ok and screen and screen.Z and screen.Z > 0 then
            return screen.X, screen.Y
        end
        return nil
    end

    local function spoofMouseKey(key)
        local part, point = resolveSilentPoint()
        if not part or not point then
            return false, nil
        end

        if key == "Hit" then
            local camera = Workspace.CurrentCamera
            local origin = camera and camera.CFrame.Position or point
            local direction = point - origin
            if direction.Magnitude > 0.01 then
                return true, CFrame.lookAt(point, point + direction.Unit)
            end
            return true, CFrame.new(point)
        elseif key == "Target" then
            return true, part
        elseif key == "UnitRay" and Ray ~= nil then
            local camera = Workspace.CurrentCamera
            local origin = camera and camera.CFrame.Position or point
            local direction = point - origin
            if direction.Magnitude > 0.01 then
                return true, Ray.new(origin, direction.Unit)
            end
        elseif key == "X" or key == "Y" then
            local screenX, screenY = targetScreenPoint(point)
            if screenX then
                return true, (key == "X" and screenX or screenY)
            end
        elseif key == "Origin" then
            local camera = Workspace.CurrentCamera
            if camera then
                return true, camera.CFrame.Position
            end
        end

        return false, nil
    end

    local function spoofMouseLocation()
        local _, point = resolveSilentPoint()
        local screenX, screenY = targetScreenPoint(point)
        if screenX then
            return Vector2.new(screenX, screenY)
        end
        return nil
    end

    local rawMouseIndex = nil
    local rawCameraIndex = nil
    local rawViewportPointToRay = nil
    local rawScreenPointToRay = nil
    local rawGetMouseLocation = nil
    local oldNamecall = nil

    do
        local camera = Workspace.CurrentCamera
        if camera then
            rawViewportPointToRay = camera.ViewportPointToRay
            rawScreenPointToRay = camera.ScreenPointToRay
        end
        rawGetMouseLocation = UserInputService.GetMouseLocation
    end

    local function spoofRay(self, x, y, depth)
        local _, point = resolveSilentPoint()
        if point and self and self.CFrame then
            local origin = self.CFrame.Position
            local direction = point - origin
            if direction.Magnitude > 0.01 then
                return Ray.new(origin, direction.Unit)
            end
        end

        if self and self == Workspace.CurrentCamera then
            if rawViewportPointToRay then
                return rawViewportPointToRay(self, x, y, depth)
            elseif rawScreenPointToRay then
                return rawScreenPointToRay(self, x, y, depth)
            end
        end

        return Ray.new(
            self and self.CFrame and self.CFrame.Position or Vector3.new(0, 0, 0),
            Vector3.new(0, 0, -1)
        )
    end

    local function installIndex(object, replacement)
        if type(hookMetamethod) == "function" then
            local ok, original = pcall(hookMetamethod, object, "__index", newCClosure(replacement))
            if ok and type(original) == "function" then
                return original
            end
        end

        if type(getRawMetatable) == "function" and type(setReadonlyFn) == "function" then
            local okMeta, metatable = pcall(getRawMetatable, object)
            if okMeta and type(metatable) == "table" then
                local original = metatable.__index
                pcall(setReadonlyFn, metatable, false)
                local okSet = pcall(function()
                    metatable.__index = newCClosure(replacement)
                end)
                pcall(setReadonlyFn, metatable, true)
                if okSet then
                    return original
                end
            end
        end

        return nil
    end

    local function mouseIndex(self, key)
        if self == mouse and Config.silentAim then
            local handled, value = spoofMouseKey(key)
            if handled then
                return value
            end
        end
        if rawMouseIndex then
            return rawMouseIndex(self, key)
        end
        return nil
    end

    local function cameraIndex(self, key)
        if self == Workspace.CurrentCamera
            and (key == "ViewportPointToRay" or key == "ScreenPointToRay")
            and Config.silentAim then
            return function(_, x, y, depth)
                return spoofRay(self, x, y, depth)
            end
        end
        if rawCameraIndex then
            return rawCameraIndex(self, key)
        end
        return nil
    end

    local function installSilentHooks()
        if silentHooksInstalled then
            return true
        end
        if silentHooksAttempted then
            return false
        end
        silentHooksAttempted = true

        local shared = _G
        if type(getgenv) == "function" then
            local okEnv, env = pcall(getgenv)
            if okEnv and type(env) == "table" then
                shared = env
            end
        end

        local generation = (shared.ChromaOneSilentGeneration or 0) + 1
        shared.ChromaOneSilentGeneration = generation

        local function active()
            return shared.ChromaOneSilentGeneration == generation
        end

        local guardedMouseIndex = function(self, key)
            if not active() then
                return rawMouseIndex and rawMouseIndex(self, key) or nil
            end
            return mouseIndex(self, key)
        end
        local guardedCameraIndex = function(self, key)
            if not active() then
                return rawCameraIndex and rawCameraIndex(self, key) or nil
            end
            return cameraIndex(self, key)
        end
        local camera = Workspace.CurrentCamera

        local sameInstanceMeta = false
        if type(getRawMetatable) == "function" then
            local okMouseMeta, mouseMeta = pcall(getRawMetatable, mouse)
            local okGameMeta, gameMeta = pcall(getRawMetatable, game)
            sameInstanceMeta = okMouseMeta
                and okGameMeta
                and type(mouseMeta) == "table"
                and type(gameMeta) == "table"
                and mouseMeta == gameMeta
        end

        if camera and not sameInstanceMeta then
            rawCameraIndex = installIndex(camera, guardedCameraIndex)
            if rawCameraIndex then
                installedHooks[#installedHooks + 1] = "camera"
            end
        end

        if mouse and not sameInstanceMeta then
            rawMouseIndex = installIndex(mouse, guardedMouseIndex)
            if rawMouseIndex then
                installedHooks[#installedHooks + 1] = "mouse"
            end
        end

        if camera and type(hookFunction) == "function" then
            if type(rawGetMouseLocation) == "function" then
                local ok = pcall(
                    hookFunction,
                    rawGetMouseLocation,
                    newCClosure(function(self)
                        local spoofed = spoofMouseLocation()
                        if spoofed then
                            return spoofed
                        end
                        return rawGetMouseLocation(self)
                    end)
                )
                if ok then
                    installedHooks[#installedHooks + 1] = "mouse-location"
                    rawGetMouseLocation = nil
                end
            end

            if type(rawViewportPointToRay) == "function" then
                local ok = pcall(
                    hookFunction,
                    rawViewportPointToRay,
                    newCClosure(function(self, x, y, depth)
                        return spoofRay(self, x, y, depth)
                    end)
                )
                if ok then
                    installedHooks[#installedHooks + 1] = "viewport-ray"
                    rawViewportPointToRay = nil
                end
            end
            if type(rawScreenPointToRay) == "function" then
                local ok = pcall(
                    hookFunction,
                    rawScreenPointToRay,
                    newCClosure(function(self, x, y, depth)
                        return spoofRay(self, x, y, depth)
                    end)
                )
                if ok then
                    installedHooks[#installedHooks + 1] = "screen-ray"
                    rawScreenPointToRay = nil
                end
            end
        end

        if type(hookMetamethod) == "function"
            and type(getNamecallmethod) == "function"
            and oldNamecall == nil then
            local ok, original = pcall(
                hookMetamethod,
                game,
                "__namecall",
                newCClosure(function(self, ...)
                    if oldNamecall == nil then
                        return nil
                    end
                    if not active() then
                        return oldNamecall(self, ...)
                    end

                    local okMethod, method = pcall(getNamecallmethod)
                    if not okMethod or type(method) ~= "string" then
                        return oldNamecall(self, ...)
                    end

                    local lower = string.lower(method)

                    if self ~= Workspace then
                        if (lower == "fireserver" or lower == "invokeserver")
                            and isACSShotRemote(self) then
                            local results = table.pack(oldNamecall(self, ...))
                            pcall(tryACSShot)
                            return table.unpack(results, 1, results.n)
                        end
                        return oldNamecall(self, ...)
                    end

                    if raycastBypass > 0 then
                        return oldNamecall(self, ...)
                    end

                    if lower == "raycast" then
                        local args = table.pack(...)
                        local origin, direction, params = args[1], args[2], args[3]
                        if origin and direction then
                            local part, point, result = interceptCast(
                                origin,
                                direction,
                                params
                            )
                            if result then
                                return result
                            end

                            local wallbang = (
                                Config.silentAim and Config.silentWallbang
                            ) or (
                                Config.rageEnabled and Config.rageWallbang
                            )
                            if part and point and wallbang then
                                local okDistance, distance = pcall(function()
                                    return (point - origin).Magnitude
                                end)
                                return {
                                    Instance = part,
                                    Position = point,
                                    Normal = Vector3.new(0, 1, 0),
                                    Material = part.Material,
                                    Distance = okDistance and distance or 0,
                                }
                            end
                        end
                        return oldNamecall(self, table.unpack(args, 1, args.n))
                    end

                    if lower == "findpartonray"
                        or lower == "findpartonraywithignorelist"
                        or lower == "findpartonraywithwhitelist" then
                        local args = table.pack(...)
                        local origin, direction = args[1], args[2]
                        if origin and direction then
                            local part, point, normal, material = interceptLegacy(
                                origin,
                                direction
                            )
                            if part then
                                return part, point, normal, material
                            end
                        end
                        return oldNamecall(self, table.unpack(args, 1, args.n))
                    end

                    return oldNamecall(self, ...)
                end)
            )
            if ok and type(original) == "function" then
                oldNamecall = original
                installedHooks[#installedHooks + 1] = "raycast"
            end
        end

        if #installedHooks > 0 then
            silentAvailable = true
            silentHooksInstalled = true
            silentHookMode = table.concat(installedHooks, " + ")
            return true
        end

        silentAvailable = false
        silentHookMode = "none"
        warn("[Chroma.one] Silent aim hook failed. Try a different executor.")
        return false
    end

    silentAvailable = type(hookFunction) == "function"
        or type(hookMetamethod) == "function"
        or (type(getRawMetatable) == "function" and type(setReadonlyFn) == "function")

    -- Local skins ------------------------------------------------------------

    local function savePart(part)
        if originalPartProps[part] then
            return originalPartProps[part]
        end
        local original = {
            Color = part.Color,
            Material = part.Material,
            LocalTransparencyModifier = part.LocalTransparencyModifier or 0,
        }
        originalPartProps[part] = original
        return original
    end

    local function restorePart(part)
        local original = originalPartProps[part]
        if not original then
            return
        end
        pcall(function()
            part.Color = original.Color
            part.Material = original.Material
            part.LocalTransparencyModifier = original.LocalTransparencyModifier
        end)
        originalPartProps[part] = nil
    end

    local function applyArmPart(part)
        local skin = Config.armsSkinEnabled
        local force = Config.armsForceVisible
        if not skin and not force then
            restorePart(part)
            return
        end

        local original = savePart(part)
        if skin then
            part.Color = Config.colors.armsSkin
            local material = getMaterialByName(Config.armsMaterial)
            if material then
                part.Material = material
            end
        else
            part.Color = original.Color
            part.Material = original.Material
        end

        if force then
            part.LocalTransparencyModifier = 0
        else
            part.LocalTransparencyModifier = original.LocalTransparencyModifier
        end
    end

    local function applyGunPart(part)
        if not Config.gunSkinEnabled then
            restorePart(part)
            return
        end

        savePart(part)
        part.Color = Config.colors.gunSkin
        local material = getMaterialByName(Config.gunMaterial)
        if material then
            part.Material = material
        end
    end

    local function applySkins()
        local character = LocalPlayer.Character
        if not character then
            return
        end

        local descendants = character:GetDescendants()
        for _, descendant in ipairs(descendants) do
            if descendant:IsA("BasePart") and ARM_NAMES[descendant.Name] then
                pcall(applyArmPart, descendant)
            end
        end

        for _, descendant in ipairs(descendants) do
            if descendant:IsA("Tool") then
                for _, toolPart in ipairs(descendant:GetDescendants()) do
                    if toolPart:IsA("BasePart") then
                        pcall(applyGunPart, toolPart)
                    end
                end
            end
        end
    end

    local function restoreCharacterSkins(character)
        if not character then
            return
        end
        for _, descendant in ipairs(character:GetDescendants()) do
            if descendant:IsA("BasePart") then
                restorePart(descendant)
            end
        end
    end

    local function watchLocalCharacter(character)
        if not character or localCharacterWatched == character then
            return
        end
        localCharacterWatched = character

        character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                task.defer(applySkins)
            end
        end)

        character.ChildRemoved:Connect(function(child)
            for _, descendant in ipairs(child:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    restorePart(descendant)
                end
            end
            task.defer(applySkins)
        end)

        task.defer(applySkins)
    end

    LocalPlayer.CharacterAdded:Connect(function(character)
        watchLocalCharacter(character)
        task.defer(applySkins)
    end)

    LocalPlayer.CharacterRemoving:Connect(function(character)
        restoreCharacterSkins(character)
        localCharacterWatched = nil
    end)

    if LocalPlayer.Character then
        watchLocalCharacter(LocalPlayer.Character)
    end

    -- Interface helpers -----------------------------------------------------

    UI = {}
    local Controls: { any } = {}
    local orders = {}
    local sectionBodies: { [Instance]: any } = {}

    local function make(className, properties, parent)
        local object = Instance.new(className)
        for property, value in pairs(properties or {}) do
            object[property] = value
        end
        if parent then
            object.Parent = parent
        end
        return object
    end

    local function corner(object, radius)
        local item = Instance.new("UICorner")
        item.CornerRadius = UDim.new(0, radius or 2)
        item.Parent = object
        return item
    end

    local function round(object)
        local item = Instance.new("UICorner")
        item.CornerRadius = UDim.new(1, 0)
        item.Parent = object
        return item
    end

    local function stroke(object, color, transparency)
        local item = Instance.new("UIStroke")
        item.Color = color or Theme.line
        item.Transparency = transparency or 0.45
        item.Parent = object
        return item
    end

    local function label(parent, text, properties)
        local settings = {
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Theme.text,
            Font = FONT,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
        }
        for property, value in pairs(properties or {}) do
            settings[property] = value
        end
        return make("TextLabel", settings, parent)
    end

    local function add(parent, child)
        local body = sectionBodies[parent]
        if body then
            parent = body
        end
        local order = (orders[parent] or 0) + 1
        orders[parent] = order
        child.LayoutOrder = order
        child.Parent = parent
        return child
    end

    local function hover(button, normalColor, hoverColor)
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = hoverColor
        end)
        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = normalColor
        end)
    end

    local function registerControl(refresh)
        Controls[#Controls + 1] = refresh
    end

    refreshAllControls = function()
        for _, refresh in ipairs(Controls) do
            pcall(refresh)
        end
    end

    local function button(parent, text, size, position, primary, callback, options)
        options = options or {}
        local normalColor = primary and Theme.accent or Theme.card
        local hoverColor = primary and Theme.accent2 or Theme.card2
        local item = make("TextButton", {
            Name = options.name or ("Button_" .. text),
            Size = size,
            Position = position,
            BackgroundColor3 = normalColor,
            BackgroundTransparency = primary and 0 or 0.3,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Text = string.lower(text),
            Font = FONT_BOLD,
            TextSize = options.textSize or 10,
            TextColor3 = primary and Theme.black or Theme.text,
            ZIndex = options.zIndex,
        }, parent)
        corner(item, 1)
        local itemStroke = stroke(
            item,
            primary and Theme.accent or Theme.line,
            primary and 0.2 or 0.7
        )
        hover(item, normalColor, hoverColor)
        item.MouseButton1Click:Connect(function()
            if options.keepStroke then
                itemStroke.Transparency = 0.15
            end
            callback()
        end)
        return item
    end

    local function toggleRow(parent, titleText, description, getter, setter, options)
        options = options or {}
        local row = make("TextButton", {
            Name = options.name or ("Toggle_" .. titleText),
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundColor3 = Theme.card2,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Text = "",
        })
        add(parent, row)

        local box = make("Frame", {
            Name = "Checkbox",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.new(0, 12, 0, 12),
            BackgroundColor3 = Theme.card2,
            BackgroundTransparency = options.disabled and 0.55 or 0.25,
            BorderSizePixel = 0,
            ZIndex = 2,
        }, row)
        corner(box, 2)
        local boxStroke = stroke(box, Theme.line, 0.2)
        boxStroke.Thickness = 1

        local titleLabel = label(row, titleText, {
            Position = UDim2.new(0, 20, 0, 0),
            Size = UDim2.new(1, options.keyHint and -66 or -20, 1, 0),
            Font = FONT,
            TextSize = 9.5,
            TextColor3 = options.disabled and Theme.muted or Theme.text,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 2,
        })

        if options.keyHint then
            label(row, options.keyHint, {
                Position = UDim2.new(1, -44, 0, 0),
                Size = UDim2.new(0, 36, 1, 0),
                Font = FONT,
                TextSize = 8.5,
                TextColor3 = Theme.muted,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 2,
            })
        end

        local active = getter() == true
        local previousFooter = nil

        local function paint()
            box.BackgroundColor3 = active and Theme.accent or Theme.card2
            box.BackgroundTransparency = options.disabled and 0.55
                or (active and 0 or 0.25)
            boxStroke.Color = active and Theme.accent or Theme.line
            boxStroke.Transparency = active and 0.1 or 0.35
        end

        paint()

        if options.disabled then
            row.MouseButton1Click:Connect(function()
                if notify then
                    notify(options.disabledText or "This option is unavailable.")
                end
            end)
            return row
        end

        row.MouseButton1Click:Connect(function()
            active = not active
            paint()
            setter(active)
        end)

        row.MouseEnter:Connect(function()
            row.BackgroundTransparency = 0.82
            if description and UI.footerStatus then
                previousFooter = UI.footerStatus.Text
                UI.footerStatus.Text = string.lower(description)
            end
        end)

        row.MouseLeave:Connect(function()
            row.BackgroundTransparency = 1
            if previousFooter and UI.footerStatus then
                UI.footerStatus.Text = previousFooter
                previousFooter = nil
            end
        end)

        registerControl(function()
            active = getter() == true
            paint()
        end)

        return row
    end

    local function slider(parent, titleText, minimum, maximum, step, getter, setter, suffix, compact)
        local row = make("Frame", {
            Name = "Slider_" .. titleText,
            Size = UDim2.new(1, 0, 0, 31),
            BackgroundColor3 = Theme.card,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        })
        add(parent, row)

        label(row, titleText, {
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, -56, 0, 13),
            TextSize = 9.5,
            TextColor3 = Theme.text,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })

        local valueLabel = label(row, "", {
            Position = UDim2.new(1, -52, 0, 0),
            Size = UDim2.new(0, 52, 0, 13),
            TextXAlignment = Enum.TextXAlignment.Right,
            Font = FONT,
            TextSize = 9,
            TextColor3 = Theme.muted,
        })

        local track = make("TextButton", {
            Position = UDim2.new(0, 0, 0, 17),
            Size = UDim2.new(1, 0, 0, 9),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
        }, row)

        local rail = make("Frame", {
            Position = UDim2.new(0, 0, 0.5, -1),
            Size = UDim2.new(1, 0, 0, 3),
            BackgroundColor3 = Theme.card3,
            BorderSizePixel = 0,
        }, track)
        corner(rail, 1)

        local fill = make("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = Theme.accent,
            BorderSizePixel = 0,
        }, rail)
        corner(fill, 1)

        local knob = make("Frame", {
            Size = UDim2.new(0, 6, 0, 6),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            BackgroundColor3 = Theme.accent2,
            BorderSizePixel = 0,
        }, rail)
        round(knob)

        local value = math.clamp(tonumber(getter()) or minimum, minimum, maximum)
        local dragging = false

        local function formatValue()
            if step < 1 then
                return string.format("%.2f", value) .. (suffix or "")
            end
            return tostring(math.floor(value + 0.5)) .. (suffix or "")
        end

        local function paint()
            local fraction = (value - minimum) / math.max(maximum - minimum, 0.0001)
            fill.Size = UDim2.new(fraction, 0, 1, 0)
            knob.Position = UDim2.new(fraction, 0, 0.5, 0)
            valueLabel.Text = formatValue()
        end

        local function commit(newValue, fire)
            value = math.clamp(
                math.floor(newValue / step + 0.5) * step,
                minimum,
                maximum
            )
            paint()
            if fire then
                setter(value)
            end
        end

        local function setFromX(x)
            local fraction = math.clamp(
                (x - track.AbsolutePosition.X)
                    / math.max(track.AbsoluteSize.X, 1),
                0,
                1
            )
            commit(minimum + fraction * (maximum - minimum), true)
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                setFromX(input.Position.X)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if not dragging then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                setFromX(input.Position.X)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        paint()
        registerControl(function()
            commit(tonumber(getter()) or minimum, false)
        end)

        return {
            set = function(newValue)
                commit(newValue, false)
            end,
            get = function()
                return value
            end,
            row = row,
        }
    end

    local function selectRow(parent, titleText, options, getter, setter, config)
        config = config or {}
        local holder = make("Frame", {
            Name = config.name or ("Select_" .. titleText),
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1,
        })
        add(parent, holder)

        label(holder, titleText, {
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 0, 11),
            TextSize = 8,
            TextColor3 = Theme.muted,
        })

        local box = make("TextButton", {
            Name = "SelectBox",
            Position = UDim2.new(0, 0, 0, 13),
            Size = UDim2.new(1, 0, 0, 21),
            BackgroundColor3 = Theme.card2,
            BackgroundTransparency = 0.15,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Text = "",
        }, holder)
        corner(box, 1)
        local boxStroke = stroke(box, Theme.line, 0.35)

        local valueLabel = label(box, "", {
            Position = UDim2.new(0, 8, 0, 0),
            Size = UDim2.new(1, -30, 1, 0),
            Font = FONT,
            TextSize = 9.5,
            TextColor3 = Theme.text,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        label(box, "+", {
            Position = UDim2.new(1, -20, 0, 0),
            Size = UDim2.new(0, 12, 1, 0),
            Font = FONT_BOLD,
            TextSize = 11,
            TextColor3 = Theme.accent,
            TextXAlignment = Enum.TextXAlignment.Center,
        })

        local function paint()
            local current = getter()
            local display = current
            for _, option in ipairs(options) do
                if option == current then
                    display = option
                    break
                end
            end
            valueLabel.Text = string.lower(tostring(display or options[1] or ""))
        end

        box.MouseButton1Click:Connect(function()
            local current = getter()
            local nextIndex = 1
            for index, option in ipairs(options) do
                if option == current then
                    nextIndex = index % #options + 1
                    break
                end
            end
            setter(options[nextIndex])
            paint()
        end)

        box.MouseEnter:Connect(function()
            boxStroke.Color = Theme.accent
            boxStroke.Transparency = 0.25
        end)

        box.MouseLeave:Connect(function()
            boxStroke.Color = Theme.line
            boxStroke.Transparency = 0.35
        end)

        paint()
        registerControl(paint)
        return box
    end

    local function textInput(parent, titleText, placeholder, getter, setter, options)
        options = options or {}
        local inputName = options.name or ("Input_" .. titleText)
        local holder = make("Frame", {
            Name = inputName .. "Holder",
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundTransparency = 1,
        })
        add(parent, holder)

        label(holder, titleText, {
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 0, 11),
            TextSize = 8,
            TextColor3 = Theme.muted,
        })

        local box = make("TextBox", {
            Name = inputName,
            Position = UDim2.new(0, 0, 0, 14),
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundColor3 = Theme.card2,
            BackgroundTransparency = 0.12,
            BorderSizePixel = 0,
            Text = "",
            PlaceholderText = placeholder or "",
            PlaceholderColor3 = Theme.muted,
            Font = FONT,
            TextSize = 9.5,
            TextColor3 = Theme.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
        }, holder)
        corner(box, 1)
        local boxStroke = stroke(box, Theme.line, 0.35)
        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 8)
        padding.PaddingRight = UDim.new(0, 8)
        padding.Parent = box

        local function paint()
            if UserInputService:GetFocusedTextBox() ~= box then
                box.Text = tostring(getter() or "")
            end
        end

        local function commit()
            setter(box.Text)
            paint()
        end

        if box.FocusGained then
            box.FocusGained:Connect(function()
                box.TextColor3 = Theme.white
                boxStroke.Color = Theme.accent
                boxStroke.Transparency = 0.25
            end)
        end

        if box.FocusLost then
            box.FocusLost:Connect(function()
                box.TextColor3 = Theme.text
                boxStroke.Color = Theme.line
                boxStroke.Transparency = 0.35
                commit()
            end)
        end

        paint()
        registerControl(paint)
        return box
    end

    local function partChips(parent, getParts, onChange, prefix)
        local row = make("Frame", {
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
        })
        add(parent, row)

        local names = { "Head", "Torso", "Arms", "Legs" }
        local widthScale = 0.235
        local gap = 0.02
        local chipButtons = {}

        local function update()
            local parts = getParts()
            for name, item in pairs(chipButtons) do
                local active = parts[name] == true
                item.button.BackgroundColor3 = active and Theme.accent or Theme.card2
                item.button.BackgroundTransparency = active and 0 or 0.35
                item.button.TextColor3 = active and Theme.black or Theme.muted
                item.stroke.Color = active and Theme.accent or Theme.line
                item.stroke.Transparency = active and 0.1 or 0.65
            end
        end

        for index, name in ipairs(names) do
            local chip = make("TextButton", {
                Name = prefix .. "Part_" .. name,
                Position = UDim2.new((index - 1) * (widthScale + gap), 0, 0, 1),
                Size = UDim2.new(widthScale, 0, 0, 20),
                BackgroundColor3 = Theme.card2,
                BackgroundTransparency = 0.35,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                Text = string.lower(name),
                Font = FONT_BOLD,
                TextSize = 9.5,
                TextColor3 = Theme.muted,
            }, row)
            corner(chip, 1)
            local chipStroke = stroke(chip, Theme.line, 0.65)

            chip.MouseButton1Click:Connect(function()
                local parts = getParts()
                local activeCount = 0
                for _, selected in pairs(parts) do
                    if selected then
                        activeCount += 1
                    end
                end

                if parts[name] and activeCount <= 1 then
                    if notify then
                        notify("Keep at least one body part selected.")
                    end
                    return
                end

                parts[name] = not parts[name]
                silentCacheTime = 0
                update()
                if onChange then
                    onChange()
                end
            end)

            chipButtons[name] = {
                button = chip,
                stroke = chipStroke,
            }
        end

        update()
        registerControl(update)

        local targetLabel = label(parent, "hitpart · head + torso", {
            Size = UDim2.new(1, 0, 0, 14),
            TextSize = 9,
            TextColor3 = Theme.muted,
        })
        targetLabel.Name = prefix .. "PartsLabel"
        add(parent, targetLabel)

        local function refreshLabel()
            local parts = getParts()
            local namesList = {}
            for _, name in ipairs(names) do
                if parts[name] then
                    namesList[#namesList + 1] = string.lower(name)
                end
            end
            targetLabel.Text = "hitpart · "
                .. (#namesList > 0 and table.concat(namesList, " + ") or "none")
        end

        refreshLabel()
        registerControl(refreshLabel)
        return targetLabel
    end

    local function materialGrid(parent, prefix, getter, setter)
        local rows = math.ceil(#MATERIAL_NAMES / 4)
        local grid = make("Frame", {
            Size = UDim2.new(1, 0, 0, rows * 24 - 4),
            BackgroundTransparency = 1,
        })
        add(parent, grid)

        local chips = {}

        local function paint()
            local selected = getter()
            for name, record in pairs(chips) do
                local active = name == selected
                record.button.BackgroundColor3 = active and Theme.accent or Theme.card2
                record.button.BackgroundTransparency = active and 0 or 0.35
                record.button.TextColor3 = active and Theme.black or Theme.muted
                record.stroke.Color = active and Theme.accent or Theme.line
                record.stroke.Transparency = active and 0.1 or 0.65
            end
        end

        for index, materialName in ipairs(MATERIAL_NAMES) do
            local column = (index - 1) % 4
            local rowIndex = math.floor((index - 1) / 4)
            local chip = make("TextButton", {
                Name = "Material_" .. prefix .. "_" .. materialName,
                Position = UDim2.new(column * 0.255, 0, rowIndex * 24, 0),
                Size = UDim2.new(0.235, 0, 0, 20),
                BackgroundColor3 = Theme.card2,
                BackgroundTransparency = 0.35,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                Text = string.lower(materialName),
                Font = FONT_BOLD,
                TextSize = 8.5,
                TextColor3 = Theme.muted,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, grid)
            corner(chip, 1)
            local chipStroke = stroke(chip, Theme.line, 0.65)

            chip.MouseButton1Click:Connect(function()
                setter(materialName)
                paint()
                if notify then
                    notify(prefix .. " material: " .. materialName)
                end
                if applySkins then
                    applySkins()
                end
            end)
            chips[materialName] = {
                button = chip,
                stroke = chipStroke,
            }
        end

        paint()
        registerControl(paint)
        return grid
    end

    local function buildSpaceship(parent, size)
        local ship = make("Frame", {
            Size = UDim2.new(0, size, 0, size),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, parent)
        local scale = size / 40
        local function part(color, px, py, width, height, rotation)
            local object = make("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, px * scale, 0, py * scale),
                Size = UDim2.new(0, width * scale, 0, height * scale),
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                Rotation = rotation or 0,
            }, ship)
            corner(object, 1)
            return object
        end

        part(Theme.muted, 20, 34, 1.5, 3, 0)
        part(Theme.white, 17.5, 33.5, 1.5, 2.5, 0)
        part(Theme.white, 22.5, 33.5, 1.5, 2.5, 0)

        part(Theme.white, 14.2, 27.5, 3, 10, -28)
        part(Theme.white, 25.8, 27.5, 3, 10, 28)
        part(Theme.white, 20, 21, 7, 18, 0)
        part(Theme.white, 20, 10.5, 8, 8, 45)

        local canopy = part(Theme.black, 20, 16.5, 4.6, 4.6, 0)
        round(canopy)

        local porthole = part(Theme.black, 20, 25.5, 2.4, 2.4, 0)
        round(porthole)
        return ship
    end

    local function buildUFO(parent, size)
        local ship = make("Frame", {
            Name = "UFOLogo",
            Size = UDim2.new(0, size, 0, size),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, parent)
        local scale = size / 40

        local function piece(color, px, py, width, height, transparency, rotation)
            local object = make("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, px * scale, 0, py * scale),
                Size = UDim2.new(0, width * scale, 0, height * scale),
                BackgroundColor3 = color,
                BackgroundTransparency = transparency or 0,
                BorderSizePixel = 0,
                Rotation = rotation or 0,
            }, ship)
            corner(object, 1)
            return object
        end

        local beam = make("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0, 20 * scale, 0, 38 * scale),
            Size = UDim2.new(0, 13 * scale, 0, 17 * scale),
            BackgroundColor3 = Color3.fromRGB(96, 255, 158),
            BackgroundTransparency = 0.78,
            BorderSizePixel = 0,
        }, ship)
        corner(beam, 1)
        local beamGradient = Instance.new("UIGradient")
        beamGradient.Rotation = 90
        beamGradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.55),
            NumberSequenceKeypoint.new(1, 1),
        })
        beamGradient.Parent = beam

        piece(Color3.fromRGB(74, 255, 150), 20, 22, 32, 10, 0.9)
        piece(Color3.fromRGB(24, 38, 78), 20, 20, 34, 9, 0)
        piece(Color3.fromRGB(53, 76, 138), 20, 17, 24, 3, 0.1)
        piece(Color3.fromRGB(10, 17, 36), 20, 24, 17, 5, 0)
        piece(Color3.fromRGB(42, 208, 158), 20, 12, 16, 13, 0)

        local domeShine = piece(Color3.fromRGB(215, 255, 246), 17.2, 9, 6, 3, 0.4)
        domeShine.Rotation = -18

        for _, x in ipairs({ 8.5, 20, 31.5 }) do
            local light = piece(Color3.fromRGB(88, 255, 142), x, 21, 4, 4, 0)
            local lightStroke = stroke(light, Color3.fromRGB(160, 255, 190), 0.35)
            lightStroke.Thickness = 1
        end

        piece(Color3.fromRGB(150, 255, 180), 20, 5.5, 1.2, 4, 0.1)
        return ship
    end

    local function removeOldInterface()
        local parent = getGuiParent()
        if not parent then
            error("No PlayerGui or CoreGui container is available.")
        end

        local old = parent:FindFirstChild("ChromaOneUI")
        if old then
            old:Destroy()
        end

        local oldError = parent:FindFirstChild("ChromaOneError")
        if oldError then
            oldError:Destroy()
        end

        if type(gethui) == "function" then
            local okHidden, hidden = pcall(gethui)
            if okHidden and hidden and hidden ~= parent then
                local okFind, hiddenOld = pcall(function()
                    return hidden:FindFirstChild("ChromaOneUI")
                end)
                if okFind and hiddenOld then
                    hiddenOld:Destroy()
                end
            end
        end

        return parent
    end

    local parentGui = removeOldInterface()

    UI.gui = make("ScreenGui", {
        Name = "ChromaOneUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999999,
        Enabled = true,
    }, parentGui)

    UI.espFolder = make("Frame", {
        Name = "ESPFolder",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = 2,
    }, UI.gui)

    UI.bulletLayer = make("Frame", {
        Name = "BulletLayer",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = 6,
    }, UI.gui)

    -- FOV circles -----------------------------------------------------------

    UI.fovCircle = make("Frame", {
        Name = "FovCircle",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 220, 0, 220),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 1,
    }, UI.gui)
    round(UI.fovCircle)

    UI.fovStroke = Instance.new("UIStroke")
    UI.fovStroke.Color = Config.colors.aimFov
    UI.fovStroke.Thickness = 1.5
    UI.fovStroke.Transparency = 0.1
    UI.fovStroke.Parent = UI.fovCircle

    UI.lockFovCircle = make("Frame", {
        Name = "LockFovCircle",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 160, 0, 160),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 1,
    }, UI.gui)
    round(UI.lockFovCircle)

    UI.lockFovStroke = Instance.new("UIStroke")
    UI.lockFovStroke.Color = Config.colors.lockFov
    UI.lockFovStroke.Thickness = 1.5
    UI.lockFovStroke.Transparency = 0.1
    UI.lockFovStroke.Parent = UI.lockFovCircle

    UI.rageFovCircle = make("Frame", {
        Name = "RageFovCircle",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 220, 0, 220),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 1,
    }, UI.gui)
    round(UI.rageFovCircle)

    UI.rageFovStroke = Instance.new("UIStroke")
    UI.rageFovStroke.Color = Config.colors.rageFov
    UI.rageFovStroke.Thickness = 1.5
    UI.rageFovStroke.Transparency = 0.1
    UI.rageFovStroke.Parent = UI.rageFovCircle

    -- Window -----------------------------------------------------------------

    UI.windowRoot = make("Frame", {
        Name = "WindowRoot",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 620, 0, 430),
        BackgroundTransparency = 1,
        ZIndex = 10,
    }, UI.gui)

    UI.windowScale = Instance.new("UIScale")
    UI.windowScale.Scale = 1
    UI.windowScale.Parent = UI.windowRoot

    UI.outerGlow = make("Frame", {
        Name = "OuterGlow",
        Position = UDim2.new(0, -7, 0, -7),
        Size = UDim2.new(1, 14, 1, 14),
        BackgroundColor3 = Theme.accent,
        BackgroundTransparency = 0.93,
        BorderSizePixel = 0,
        ZIndex = 0,
    }, UI.windowRoot)
    corner(UI.outerGlow, 10)

    UI.glow = make("Frame", {
        Name = "Glow",
        Position = UDim2.new(0, -4, 0, -4),
        Size = UDim2.new(1, 8, 1, 8),
        BackgroundColor3 = Theme.accent,
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
        ZIndex = 0,
    }, UI.windowRoot)
    corner(UI.glow, 8)

    UI.shadow = make("Frame", {
        Name = "Shadow",
        Position = UDim2.new(0, 6, 0, 10),
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        ZIndex = 1,
    }, UI.windowRoot)
    corner(UI.shadow, 6)

    UI.main = make("Frame", {
        Name = "Window",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.bg,
        BackgroundTransparency = 0.03,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 2,
    }, UI.windowRoot)
    corner(UI.main, 6)
    local mainGradient = Instance.new("UIGradient")
    mainGradient.Color = ColorSequence.new(
        Color3.fromRGB(24, 14, 31),
        Color3.fromRGB(5, 3, 8)
    )
    mainGradient.Rotation = 90
    mainGradient.Parent = UI.main
    UI.mainStroke = stroke(UI.main, Theme.accent, 0.3)
    UI.mainStroke.Thickness = 1

    local profileName = "player"
    local profileId = "0"
    pcall(function()
        profileName = LocalPlayer.DisplayName or LocalPlayer.Name or "player"
        profileId = tostring(LocalPlayer.UserId or 0)
    end)

    local dateText = "internal build"
    pcall(function()
        dateText = os.date("%b %d, %Y  |  %H:%M")
    end)

    UI.topbar = make("Frame", {
        Name = "Topbar",
        Size = UDim2.new(1, 0, 0, 62),
        BackgroundColor3 = Theme.top,
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, UI.main)

    local topbarGradient = Instance.new("UIGradient")
    topbarGradient.Color = ColorSequence.new(
        Color3.fromRGB(20, 10, 25),
        Color3.fromRGB(7, 4, 10)
    )
    topbarGradient.Rotation = 90
    topbarGradient.Parent = UI.topbar

    UI.topLogo = make("Frame", {
        Name = "TopLogo",
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(0, 32, 0, 32),
        BackgroundColor3 = Theme.black,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, UI.topbar)
    corner(UI.topLogo, 4)
    stroke(UI.topLogo, Theme.accent, 0.55)
    buildUFO(UI.topLogo, 32)

    label(UI.topbar, "chroma.one", {
        Name = "BrandTag",
        Position = UDim2.new(0, 53, 0, 7),
        Size = UDim2.new(0, 160, 0, 12),
        Font = FONT_BOLD,
        TextSize = 8,
        TextColor3 = Theme.accent2,
        ZIndex = 4,
    })

    label(UI.topbar, string.lower(dateText), {
        Name = "BrandDate",
        Position = UDim2.new(0, 53, 0, 19),
        Size = UDim2.new(0, 170, 0, 12),
        TextSize = 7,
        TextColor3 = Theme.muted,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    })

    UI.wordmark = label(UI.topbar, "Chroma.one", {
        Name = "Wordmark",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 5),
        Size = UDim2.new(0, 230, 0, 25),
        Font = FONT_BOLD,
        TextSize = 16,
        TextColor3 = Theme.accent2,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 4,
    })
    local wordmarkStroke = stroke(UI.wordmark, Theme.accent, 0.4)
    wordmarkStroke.Thickness = 1

    local wordmarkGradient = Instance.new("UIGradient")
    wordmarkGradient.Color = ColorSequence.new(
        Color3.fromRGB(255, 197, 226),
        Theme.accent
    )
    wordmarkGradient.Rotation = 90
    wordmarkGradient.Parent = UI.wordmark

    UI.profileLabel = label(UI.topbar, string.lower(profileName), {
        Name = "ProfileName",
        Position = UDim2.new(1, -188, 0, 8),
        Size = UDim2.new(0, 176, 0, 12),
        TextSize = 8.5,
        Font = FONT_BOLD,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    })

    UI.profileIdLabel = label(UI.topbar, "uid " .. profileId, {
        Name = "ProfileId",
        Position = UDim2.new(1, -188, 0, 20),
        Size = UDim2.new(0, 176, 0, 12),
        TextSize = 7,
        TextColor3 = Theme.muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 4,
    })

    UI.tabbar = make("Frame", {
        Name = "Tabbar",
        Position = UDim2.new(0, 0, 0, 37),
        Size = UDim2.new(1, 0, 0, 25),
        BackgroundColor3 = Theme.bg2,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, UI.topbar)

    make("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Theme.line,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, UI.tabbar)

    make("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.accent,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, UI.topbar)

    -- Content -----------------------------------------------------------------

    UI.content = make("Frame", {
        Name = "Content",
        Position = UDim2.new(0, 0, 0, 62),
        Size = UDim2.new(1, 0, 1, -62),
        BackgroundTransparency = 1,
        ZIndex = 3,
    }, UI.main)

    UI.pageHolder = make("Frame", {
        Name = "PageHolder",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
    }, UI.content)

    UI.footer = make("Frame", {
        Name = "Footer",
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        Visible = false,
        BorderSizePixel = 0,
    }, UI.content)

    UI.footerStatus = label(UI.footer, "Loading...", {
        Name = "FooterStatus",
        Size = UDim2.new(1, 0, 0, 0),
        TextSize = 1,
        TextTransparency = 1,
        TextColor3 = Theme.muted,
    })

    -- Keybinds overlay -------------------------------------------------------

    UI.keysPanel = make("Frame", {
        Name = "KeysPanel",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 14),
        Size = UDim2.new(0, 146, 0, 100),
        BackgroundColor3 = Theme.black,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Visible = true,
        ZIndex = 40,
    }, UI.gui)
    corner(UI.keysPanel, 3)
    stroke(UI.keysPanel, Theme.accent, 0.55)

    label(UI.keysPanel, "keybinds:", {
        Position = UDim2.new(0, 9, 0, 6),
        Size = UDim2.new(1, -18, 0, 12),
        TextSize = 8.5,
        TextColor3 = Theme.text,
    })

    local keyRows = {
        { "ragebot", "[t]" },
        { "silent", "[v]" },
        { "aim", "[rmb]" },
        { "lock", "[e]" },
        { "menu", "[rshift]" },
    }
    for index, row in ipairs(keyRows) do
        label(UI.keysPanel, row[1], {
            Position = UDim2.new(0, 9, 0, 19 + (index - 1) * 15),
            Size = UDim2.new(0.55, 0, 0, 13),
            TextSize = 8.5,
            TextColor3 = Theme.muted,
        })
        label(UI.keysPanel, row[2], {
            Position = UDim2.new(0.55, 0, 0, 19 + (index - 1) * 15),
            Size = UDim2.new(0.45, -9, 0, 13),
            TextSize = 8.5,
            TextColor3 = Theme.text,
            TextXAlignment = Enum.TextXAlignment.Right,
        })
    end

    -- Launcher ---------------------------------------------------------------

    UI.launcher = make("Frame", {
        Name = "Launcher",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 18, 1, -18),
        Size = UDim2.new(0, 52, 0, 52),
        BackgroundColor3 = Theme.black,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Visible = true,
        ZIndex = 20,
    }, UI.gui)
    corner(UI.launcher, 2)
    stroke(UI.launcher, Theme.accent, 0.25)

    UI.launcherScale = Instance.new("UIScale")
    UI.launcherScale.Scale = 1
    UI.launcherScale.Parent = UI.launcher

    UI.logoBadge = make("Frame", {
        Name = "LogoBadge",
        Size = UDim2.new(0, 44, 0, 44),
        Position = UDim2.new(0, 4, 0, 4),
        BackgroundColor3 = Theme.black,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ZIndex = 20,
    }, UI.launcher)
    corner(UI.logoBadge, 1)
    stroke(UI.logoBadge, Theme.white, 0.15)
    buildSpaceship(UI.logoBadge, 40)

    UI.launcherButton = make("TextButton", {
        Name = "LauncherButton",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 21,
    }, UI.launcher)

    UI.launcherButton.MouseEnter:Connect(function()
        TweenService:Create(
            UI.launcherScale,
            TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Scale = 1.08 }
        ):Play()
    end)

    UI.launcherButton.MouseLeave:Connect(function()
        TweenService:Create(
            UI.launcherScale,
            TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Scale = 1 }
        ):Play()
    end)

    UI.launcherButton.MouseButton1Click:Connect(function()
        if setMenuOpen then
            setMenuOpen(not UI.menuOpen)
        end
    end)

    -- Toast ------------------------------------------------------------------

    UI.toast = make("Frame", {
        Name = "Toast",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, -60),
        Size = UDim2.new(0, 340, 0, 44),
        BackgroundColor3 = Theme.card,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 30,
    }, UI.gui)
    corner(UI.toast, 4)
    stroke(UI.toast, Theme.accent, 0.45)

    UI.toastAccent = make("Frame", {
        Size = UDim2.new(0, 2, 1, -14),
        Position = UDim2.new(0, 10, 0, 7),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel = 0,
    }, UI.toast)

    UI.toastLabel = label(UI.toast, "", {
        Position = UDim2.new(0, 21, 0, 0),
        Size = UDim2.new(1, -29, 1, 0),
        Font = FONT_BOLD,
        TextSize = 10,
    })

    UI.toastToken = 0

    notify = function(text)
        UI.toastToken += 1
        local token = UI.toastToken
        UI.toastLabel.Text = tostring(text)
        UI.toast.Visible = true
        UI.toast.Position = UDim2.new(0.5, 0, 0, -60)

        TweenService:Create(
            UI.toast,
            TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Position = UDim2.new(0.5, 0, 0, 16) }
        ):Play()

        task.delay(3, function()
            if token ~= UI.toastToken then
                return
            end

            local hideTween = TweenService:Create(
                UI.toast,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Position = UDim2.new(0.5, 0, 0, -60) }
            )
            hideTween:Play()
            hideTween.Completed:Connect(function()
                if token == UI.toastToken then
                    UI.toast.Visible = false
                end
            end)
        end)
    end

    -- Lock marker ------------------------------------------------------------

    UI.lockMarker = make("Frame", {
        Name = "LockMarker",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 38, 0, 38),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 7,
    }, UI.gui)
    UI.lockMarkerStroke = stroke(UI.lockMarker, Theme.accent, 0.05)
    UI.lockMarkerStroke.Thickness = 1.5

    local bracketOffsets = {
        { 0, 0, 12, 1.5 },
        { 0, 0, 1.5, 12 },
        { 1, 0, 12, 1.5 },
        { 1, 0, 1.5, 12 },
        { 0, 1, 12, 1.5 },
        { 0, 1, 1.5, 12 },
        { 1, 1, 12, 1.5 },
        { 1, 1, 1.5, 12 },
    }
    for _, piece in ipairs(bracketOffsets) do
        make("Frame", {
            AnchorPoint = Vector2.new(piece[1], piece[2]),
            Position = UDim2.new(piece[1], 0, piece[2], 0),
            Size = UDim2.new(0, piece[3], 0, piece[4]),
            BackgroundColor3 = Theme.accent,
            BorderSizePixel = 0,
        }, UI.lockMarker)
    end

    UI.lockDot = make("Frame", {
        Size = UDim2.new(0, 4, 0, 4),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel = 0,
    }, UI.lockMarker)
    round(UI.lockDot)

    -- Menu state -------------------------------------------------------------

    UI.menuOpen = true
    setMenuOpen = function(open)
        UI.menuOpen = open == true
        UI.windowRoot.Visible = UI.menuOpen
        UI.launcher.Visible = true
    end

    setMenuOpen(true)

    local function fitWindow()
        local camera = Workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
        local width = math.max(viewport.X, 320)
        local height = math.max(viewport.Y, 240)
        local scale = math.min(1, (width - 28) / 620, (height - 96) / 430)
        UI.windowScale.Scale = math.clamp(scale, 0.45, 1)
    end

    fitWindow()

    local function watchCamera()
        fitWindow()
        local camera = Workspace.CurrentCamera
        if camera then
            camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitWindow)
        end
    end

    watchCamera()
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)

    local function resetInterface()
        UI.windowRoot.Position = UDim2.new(0.5, 0, 0.5, 0)
        UI.windowScale.Scale = 1
        setMenuOpen(true)
        notify("Menu recentered and scale reset.")
    end

    local function setConfigStatus(message)
        if UI.configStatusLabel then
            UI.configStatusLabel.Text = tostring(message)
        end
    end

    local function onColorChanged(key)
        if key == "visible" or key == "hidden" or key == "espChams" then
            restyleAll()
        elseif key == "armsSkin" or key == "gunSkin" then
            applySkins()
        elseif key == "aimFov" then
            UI.fovStroke.Color = Config.colors.aimFov
        elseif key == "lockFov" then
            UI.lockFovStroke.Color = Config.colors.lockFov
        elseif key == "rageFov" then
            UI.rageFovStroke.Color = Config.colors.rageFov
        end

        if updateESP then
            updateESP()
        end
        if refreshAllControls then
            refreshAllControls()
        end
        if refreshColorTargets then
            refreshColorTargets()
        end
    end

    local function selectColorTarget(key)
        if COLOR_DEF_BY_KEY[key] == nil then
            return
        end
        selectedColorKey = key
        if refreshColorTargets then
            refreshColorTargets()
        end
        if refreshColorEditor then
            refreshColorEditor()
        end
        if showPage then
            showPage("Settings")
        end
    end

    -- Pages ------------------------------------------------------------------

    local pages = {}
    local tabButtons = {}
    local activeTab = nil
    local lockKeyDown = false
    local lockToggleActive = false
    local saveConfig
    local loadConfig
    local resetDefaults

    local function createPage(name)
        local page = make("Frame", {
            Name = "Page_" .. name,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
        }, UI.pageHolder)

        pages[name] = page
        return page
    end

    local function makePageColumns(page)
        local function column(name, position, leftPad, rightPad)
            local scroll = make("ScrollingFrame", {
                Name = name,
                Position = position,
                Size = UDim2.new(0.5, -3, 1, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = Theme.line,
                ScrollBarImageTransparency = 0.55,
                ClipsDescendants = true,
            }, page)

            local padding = Instance.new("UIPadding")
            padding.PaddingLeft = UDim.new(0, leftPad)
            padding.PaddingRight = UDim.new(0, rightPad)
            padding.PaddingTop = UDim.new(0, 7)
            padding.PaddingBottom = UDim.new(0, 10)
            padding.Parent = scroll

            local layout = Instance.new("UIListLayout")
            layout.Padding = UDim.new(0, 4)
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.Parent = scroll

            return scroll
        end

        return column("Column_Left", UDim2.new(0, 0, 0, 0), 8, 3),
            column("Column_Right", UDim2.new(0.5, 3, 0, 0), 3, 8)
    end

    local function pageTitle(page, title, subtitle)
        local header = make("Frame", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
        })
        add(page, header)

        label(header, string.lower(title), {
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(0.32, 0, 1, 0),
            Font = FONT_BOLD,
            TextSize = 9.5,
            TextColor3 = Theme.muted,
        })

        make("Frame", {
            Position = UDim2.new(0.34, 0, 0.5, 0),
            Size = UDim2.new(0.66, 0, 0, 1),
            BackgroundColor3 = Theme.line,
            BackgroundTransparency = 0.55,
            BorderSizePixel = 0,
        }, header)
    end

    local function section(page, text)
        sectionBodies[page] = nil

        local group = make("Frame", {
            Name = "Section_" .. text,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.card,
            BackgroundTransparency = 0.25,
            BorderSizePixel = 0,
            ClipsDescendants = false,
        })
        corner(group, 1)
        local groupStroke = stroke(group, Theme.line, 0.5)
        groupStroke.Thickness = 1
        add(page, group)

        local groupLayout = Instance.new("UIListLayout")
        groupLayout.SortOrder = Enum.SortOrder.LayoutOrder
        groupLayout.Padding = UDim.new(0, 0)
        groupLayout.Parent = group

        local header = make("Frame", {
            Size = UDim2.new(1, 0, 0, 19),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
        }, group)

        label(header, string.upper(string.sub(text, 1, 1)) .. string.sub(text, 2), {
            Position = UDim2.new(0, 8, 0, 1),
            Size = UDim2.new(1, -16, 0, 15),
            TextXAlignment = Enum.TextXAlignment.Left,
            Font = FONT_BOLD,
            TextSize = 8.5,
            TextColor3 = Theme.text,
            ZIndex = 3,
        })

        make("Frame", {
            Position = UDim2.new(0, 8, 1, -1),
            Size = UDim2.new(1, -16, 0, 1),
            BackgroundColor3 = Theme.line,
            BackgroundTransparency = 0.4,
            BorderSizePixel = 0,
            ZIndex = 2,
        }, header)

        local body = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 2,
        }, group)

        local bodyPadding = Instance.new("UIPadding")
        bodyPadding.PaddingLeft = UDim.new(0, 8)
        bodyPadding.PaddingRight = UDim.new(0, 8)
        bodyPadding.PaddingTop = UDim.new(0, 2)
        bodyPadding.PaddingBottom = UDim.new(0, 7)
        bodyPadding.Parent = body

        local bodyLayout = Instance.new("UIListLayout")
        bodyLayout.Padding = UDim.new(0, 3)
        bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
        bodyLayout.Parent = body

        sectionBodies[page] = body
        return body
    end

    local function note(page, text)
        return add(page, label(page, text, {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextSize = 8.5,
            TextColor3 = Theme.muted,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
        }))
    end

    local function statCard(parent, positionScale, titleText)
        local card = make("Frame", {
            Size = UDim2.new(0.32, 0, 0, 44),
            Position = UDim2.new(positionScale, 0, 0, 0),
            BackgroundColor3 = Theme.card,
            BackgroundTransparency = 0.25,
            BorderSizePixel = 0,
        }, parent)
        corner(card, 1)
        stroke(card, Theme.line, 0.65)

        label(card, titleText, {
            Position = UDim2.new(0, 10, 0, 6),
            Size = UDim2.new(1, -18, 0, 12),
            Font = FONT_BOLD,
            TextSize = 8,
            TextColor3 = Theme.muted,
        })

        return label(card, "0", {
            Position = UDim2.new(0, 10, 0, 18),
            Size = UDim2.new(1, -18, 0, 20),
            Font = FONT_BOLD,
            TextSize = 16,
            TextColor3 = Theme.text,
        })
    end

    local function colorShortcut(parent, titleText, key, description)
        local card = make("TextButton", {
            Name = "ColorShortcut_" .. key,
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = Theme.card,
            BackgroundTransparency = 0.25,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Text = "",
        })
        corner(card, 1)
        local cardStroke = stroke(card, Theme.line, 0.65)
        add(parent, card)

        label(card, titleText, {
            Position = UDim2.new(0, 9, 0, 3),
            Size = UDim2.new(1, -52, 0, 12),
            Font = FONT,
            TextSize = 9,
        })

        local detail = label(card, description or "", {
            Position = UDim2.new(0, 9, 0, 16),
            Size = UDim2.new(1, -52, 0, 10),
            TextSize = 7,
            TextColor3 = Theme.muted,
        })

        local swatch = make("Frame", {
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(1, -25, 0.5, -8),
            BackgroundColor3 = Config.colors[key],
            BorderSizePixel = 0,
        }, card)
        corner(swatch, 1)
        stroke(swatch, Theme.line, 0.2)

        card.MouseButton1Click:Connect(function()
            selectColorTarget(key)
            notify(titleText .. " selected in Settings.")
        end)

        registerControl(function()
            local color = Config.colors[key]
            swatch.BackgroundColor3 = color
            detail.Text = (description and (string.lower(description) .. " · ") or "")
                .. colorToHex(color)
            cardStroke.Color = selectedColorKey == key and Theme.accent or Theme.line
            cardStroke.Transparency = selectedColorKey == key and 0.25 or 0.65
        end)

        return card
    end

    local function statusCard(parent, titleText, initialText, name)
        local card = make("Frame", {
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = Theme.card,
            BackgroundTransparency = 0.25,
            BorderSizePixel = 0,
        })
        add(parent, card)
        corner(card, 1)
        stroke(card, Theme.line, 0.6)

        label(card, string.lower(titleText), {
            Position = UDim2.new(0, 9, 0, 5),
            Size = UDim2.new(1, -18, 0, 12),
            Font = FONT_BOLD,
            TextSize = 7.5,
            TextColor3 = Theme.muted,
        })

        local value = label(card, initialText or "", {
            Name = name,
            Position = UDim2.new(0, 9, 0, 18),
            Size = UDim2.new(1, -18, 0, 17),
            Font = FONT_BOLD,
            TextSize = 9.5,
            TextColor3 = Theme.muted,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        return value
    end

    local function buildPagesAndTabs()
    local aimbotPage = createPage("Aimbot")
    local aimbotLeft, aimbotRight = makePageColumns(aimbotPage)

    local visualPage = createPage("Visual")
    local visualLeft, visualRight = makePageColumns(visualPage)

    local settingsPage = createPage("Settings")
    local settingsLeft, settingsRight = makePageColumns(settingsPage)

    -- Players page -----------------------------------------------------------

    local playersPage = createPage("Players")
    local playersLeft, playersRight = makePageColumns(playersPage)

    local statsRow = make("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 1,
    })
    add(playersLeft, statsRow)

    UI.selectedStat = statCard(statsRow, 0, "Highlighted")
    UI.availableStat = statCard(statsRow, 0.34, "Eligible")
    UI.teamStat = statCard(statsRow, 0.68, "Team check")

    section(playersLeft, "Highlighting")

    toggleRow(
        playersLeft,
        "Enable highlights",
        "Master switch for all auto highlights.",
        function()
            return Config.highlightsEnabled
        end,
        function(value)
            Config.highlightsEnabled = value
            if value then
                refreshAllHighlights()
                restyleAll()
            else
                for _, highlight in pairs(highlights) do
                    highlight.Enabled = false
                end
            end
            if updateStats then
                updateStats()
            end
        end,
        { name = "Toggle_Highlights" }
    )

    toggleRow(
        playersLeft,
        "Team check",
        "Skip players on your team. Off highlights everyone else.",
        function()
            return Config.teamCheck
        end,
        function(value)
            Config.teamCheck = value
            refreshAllHighlights()
            refreshAllControls()
            if updateStats then
                updateStats()
            end
            notify(value and "Team check enabled." or "Team check disabled — all players eligible.")
        end,
        { name = "Toggle_TeamCheck" }
    )

    note(
        playersLeft,
        "Every eligible player is highlighted automatically; no manual selection."
    )

    section(playersRight, "Visuals")

    toggleRow(
        playersRight,
        "See through walls",
        "Keep highlight outlines visible through geometry.",
        function()
            return Config.seeThroughWalls
        end,
        function(value)
            Config.seeThroughWalls = value
            restyleAll()
        end,
        { name = "Toggle_SeeThrough" }
    )

    slider(
        playersRight,
        "Fill transparency",
        0,
        100,
        5,
        function()
            return Config.fillTransparency * 100
        end,
        function(value)
            Config.fillTransparency = math.clamp(value / 100, 0, 1)
            restyleAll()
        end,
        "%"
    )

    note(
        playersRight,
        "Highlights and ESP both follow the team check and are applied to players as they join or respawn. Any visible sliver switches the highlight to the visible color."
    )

    -- Visual page ------------------------------------------------------------

    local espLeft, espRight = visualLeft, visualRight

    section(espLeft, "general")

    toggleRow(espLeft, "Enable ESP", "Master switch for all screen-space ESP.", function()
        return Config.espEnabled
    end, function(value)
        Config.espEnabled = value
        restyleAll()
        if not value and updateESP then
            updateESP()
        end
        if updateStats then
            updateStats()
        end
    end, { name = "Toggle_ESP" })

    toggleRow(espLeft, "Box", "Projected bounding-box rectangle.", function()
        return Config.espBox
    end, function(value)
        Config.espBox = value
    end, { name = "Toggle_ESPBox" })

    selectRow(espLeft, "Box style", { "2d", "3d", "corners", "filled" }, function()
        return Config.espBoxStyle or "2d"
    end, function(value)
        Config.espBoxStyle = value
    end, { name = "Select_ESPBoxStyle" })

    toggleRow(espLeft, "Name", "Player name above the box.", function()
        return Config.espName
    end, function(value)
        Config.espName = value
    end, { name = "Toggle_ESPName" })

    toggleRow(espLeft, "Distance", "Distance label above the box.", function()
        return Config.espDistance
    end, function(value)
        Config.espDistance = value
    end, { name = "Toggle_ESPDistance" })

    toggleRow(espLeft, "Health bar", "Vertical health bar beside the box.", function()
        return Config.espHealth
    end, function(value)
        Config.espHealth = value
    end, { name = "Toggle_ESPHealth" })

    toggleRow(espLeft, "Armor bar", "Blue armor bar beside the health bar when the target has armor.", function()
        return Config.espArmor
    end, function(value)
        Config.espArmor = value
    end, { name = "Toggle_ESPArmor" })

    toggleRow(espLeft, "Tool name", "Shows the target's equipped Tool under their name.", function()
        return Config.espToolName
    end, function(value)
        Config.espToolName = value
    end, { name = "Toggle_ESPToolName" })

    toggleRow(espLeft, "Team label", "Shows the target's team under their name.", function()
        return Config.espTeam
    end, function(value)
        Config.espTeam = value
    end, { name = "Toggle_ESPTeam" })

    toggleRow(espLeft, "Skeleton", "Bone lines between the target's R6 or R15 joints.", function()
        return Config.espSkeleton
    end, function(value)
        Config.espSkeleton = value
    end, { name = "Toggle_ESPSkeleton" })

    toggleRow(espLeft, "Chams", "Always-on-top fill highlight around the target.", function()
        return Config.espChams
    end, function(value)
        Config.espChams = value
        restyleAll()
    end, { name = "Toggle_ESPChams" })

    toggleRow(espLeft, "Snap lines", "Line from the screen edge to the target.", function()
        return Config.espTracer
    end, function(value)
        Config.espTracer = value
    end, { name = "Toggle_ESPTracer" })

    selectRow(espLeft, "Snapline origin", { "bottom", "top", "center" }, function()
        return Config.espTracerStyle or "bottom"
    end, function(value)
        Config.espTracerStyle = value
    end, { name = "Select_ESPTracerStyle" })

    toggleRow(espLeft, "Bullet tracer", "Short fading line from your muzzle on MouseButton1.", function()
        return Config.espBulletTracer
    end, function(value)
        Config.espBulletTracer = value
    end, { name = "Toggle_ESPBullet" })

    toggleRow(espLeft, "Target only ESP", "Only render the player currently held by aim, lock, rage, or silent aim.", function()
        return Config.espTargetOnly
    end, function(value)
        Config.espTargetOnly = value
        if value then
            Config.espLockedOnly = false
        end
    end, { name = "Toggle_ESPTargetOnly" })

    toggleRow(espLeft, "Locked ESP", "Only render the current lock-on target.", function()
        return Config.espLockedOnly
    end, function(value)
        Config.espLockedOnly = value
        if value then
            Config.espTargetOnly = false
        end
    end, { name = "Toggle_ESPLockedOnly" })

    section(espRight, "visibility")

    toggleRow(espRight, "Visibility check", "Tints ESP and chams green when visible, red behind cover.", function()
        return Config.espVisCheck
    end, function(value)
        Config.espVisCheck = value
        for _, player in ipairs(Players:GetPlayers()) do
            visibilityState[player] = nil
        end
        restyleAll()
        if updateESP then
            updateESP()
        end
    end, { name = "Toggle_ESPVisCheck" })

    colorShortcut(espRight, "Visible color", "espVisible", "Edit in Settings")
    colorShortcut(espRight, "Behind wall color", "espHidden", "Edit in Settings")

    section(espRight, "loot")

    toggleRow(espRight, "Loot / item ESP", "Labels dropped weapons, chests, ammo, armor, and objectives.", function()
        return Config.espLoot
    end, function(value)
        Config.espLoot = value
        if value then
            lootScanClock = -math.huge
        end
        if updateESP then
            updateESP()
        end
    end, { name = "Toggle_ESPLoot" })

    slider(espRight, "Loot distance", 50, 2000, 25, function()
        return Config.espLootMaxDistance
    end, function(value)
        Config.espLootMaxDistance = value
    end, " studs")

    colorShortcut(espRight, "Loot color", "espLoot", "Edit in Settings")

    section(espRight, "camera")

    toggleRow(espRight, "FOV changer", "Overrides the camera field of view while enabled.", function()
        return Config.fovEnabled
    end, function(value)
        Config.fovEnabled = value
    end, { name = "Toggle_FovChanger" })

    slider(espRight, "Camera FOV", 50, 120, 1, function()
        return Config.fovValue
    end, function(value)
        Config.fovValue = value
    end, "°")

    section(espRight, "tuning")

    slider(espRight, "Max distance", 50, 3000, 50, function()
        return Config.espMaxDistance
    end, function(value)
        Config.espMaxDistance = value
    end, " studs")

    slider(espRight, "Box thickness", 1, 8, 1, function()
        return Config.espBoxThickness
    end, function(value)
        Config.espBoxThickness = value
    end, "px")

    slider(espRight, "Tracer thickness", 1, 8, 1, function()
        return Config.espTracerThickness
    end, function(value)
        Config.espTracerThickness = value
    end, "px")

    slider(espRight, "Bullet tracer thickness", 1, 8, 1, function()
        return Config.espBulletThickness
    end, function(value)
        Config.espBulletThickness = value
    end, "px")

    slider(espRight, "Skeleton thickness", 1, 6, 1, function()
        return Config.espSkeletonThickness
    end, function(value)
        Config.espSkeletonThickness = value
    end, "px")

    colorShortcut(espRight, "Box color", "espBox", "Edit in Settings")
    colorShortcut(espRight, "Name color", "espName", "Edit in Settings")
    colorShortcut(espRight, "Snapline color", "espTracer", "Edit in Settings")
    colorShortcut(espRight, "Skeleton color", "espSkeleton", "Edit in Settings")
    colorShortcut(espRight, "Chams color", "espChams", "Edit in Settings")
    colorShortcut(espRight, "Team color", "espTeam", "Edit in Settings")
    colorShortcut(espRight, "Armor color", "espArmor", "Edit in Settings")

    note(espRight, "ESP runs in the render step for every eligible player. R6 and R15 rigs use the model bounding box, so missing limbs or tools do not break the box. 3D boxes draw all twelve projected cube edges. Visibility check tints boxes, names, snaplines, skeletons, and chams. Loot ESP scans dropped tools and named containers on a slow timer.")

    -- Aimbot page ------------------------------------------------------------

    local rageLeft, rageRight = aimbotLeft, aimbotRight

    UI.rageStatusLabel = statusCard(
        rageLeft,
        "rage status",
        "disabled",
        "RageStatus"
    )

    section(rageLeft, "general")

    toggleRow(rageLeft, "Enable ragebot", "Snaps the camera to the nearest target for every shot.", function()
        return Config.rageEnabled
    end, function(value)
        Config.rageEnabled = value
        if value and not silentHooksInstalled then
            installSilentHooks()
        end
        if not value then
            rageTarget = nil
            ragePartName = nil
        end
        refreshRageStatus()
        updateSilentStatus()
        if updateStats then
            updateStats()
        end
        notify(value and "Ragebot enabled." or "Ragebot disabled.")
    end, { name = "Toggle_Rage", keyHint = "[T]" })

    toggleRow(rageLeft, "Hold mouse", "Only run while left or right mouse is held.", function()
        return Config.rageHold
    end, function(value)
        Config.rageHold = value
        rageTarget = nil
        ragePartName = nil
        refreshRageStatus()
    end, { name = "Toggle_RageHold" })

    toggleRow(rageLeft, "Auto fire", "Clicks for you when a target is locked.", function()
        return Config.rageAutoFire
    end, function(value)
        Config.rageAutoFire = value
    end, { name = "Toggle_RageAutoFire" })

    toggleRow(rageLeft, "Show FOV circle", "Outline-only circle for the rage cone.", function()
        return Config.rageShowFov
    end, function(value)
        Config.rageShowFov = value
    end, { name = "Toggle_RageFov" })

    toggleRow(rageLeft, "Visible targets only", "Skip targets fully blocked by geometry.", function()
        return Config.rageVisibleOnly
    end, function(value)
        Config.rageVisibleOnly = value
        rageTarget = nil
        ragePartName = nil
    end, { name = "Toggle_RageVisible" })

    toggleRow(rageLeft, "Wallbang", "Ignore line of sight when picking a target.", function()
        return Config.rageWallbang
    end, function(value)
        Config.rageWallbang = value
        rageTarget = nil
        ragePartName = nil
    end, { name = "Toggle_RageWallbang" })

    colorShortcut(rageLeft, "Rage FOV color", "rageFov", "Edit in Settings")

    note(rageLeft, "Ragebot overrides legit aim assist while it has a target. With ragebot wallbang on, Chroma also intercepts Workspace shot rays. Server-side validation can still reject the hit.")

    section(rageRight, "scanning")

    slider(rageRight, "Rage FOV", 1, 360, 1, function()
        return Config.rageFov
    end, function(value)
        Config.rageFov = value
    end, "°")

    slider(rageRight, "Max distance", 50, 2000, 50, function()
        return Config.rageMaxDistance
    end, function(value)
        Config.rageMaxDistance = value
    end, " studs")

    slider(rageRight, "Smoothness", 1, 100, 1, function()
        return Config.rageSmoothness
    end, function(value)
        Config.rageSmoothness = value
    end, "%")

    slider(rageRight, "Prediction", 0, 0.5, 0.01, function()
        return Config.ragePrediction
    end, function(value)
        Config.ragePrediction = value
    end, "s")

    slider(rageRight, "Fire delay", 0.03, 1, 0.01, function()
        return Config.rageFireDelay
    end, function(value)
        Config.rageFireDelay = value
    end, "s")

    section(rageRight, "hitpart")

    partChips(rageRight, function()
        return Config.rageParts
    end, function()
        rageTarget = nil
        ragePartName = nil
    end, "Rage")

    refreshRageStatus()

    -- Aim assist section -----------------------------------------------------

    local aimLeft, aimRight = aimbotLeft, aimbotRight

    section(aimLeft, "general")

    toggleRow(aimLeft, "Enable aim assist", "Hold right mouse to pull the camera toward a target.", function()
        return Config.aimEnabled
    end, function(value)
        Config.aimEnabled = value
        if not value then
            aimTarget = nil
            aimPartName = nil
        end
        if updateStats then
            updateStats()
        end
    end, { name = "Toggle_Aim", keyHint = "[RMB]" })

    toggleRow(aimLeft, "Always aim", "Keep aiming without holding right mouse.", function()
        return Config.aimAlways
    end, function(value)
        Config.aimAlways = value
    end, { name = "Toggle_AimAlways" })

    toggleRow(aimLeft, "Visible enemies only", "Skip targets fully blocked by geometry.", function()
        return Config.aimVisibleOnly
    end, function(value)
        Config.aimVisibleOnly = value
        aimTarget = nil
        aimPartName = nil
    end, { name = "Toggle_AimVisible" })

    toggleRow(aimLeft, "Show FOV circle", "Outline-only circle for the aim cone.", function()
        return Config.fovCircle
    end, function(value)
        Config.fovCircle = value
    end, { name = "Toggle_AimFov" })

    colorShortcut(aimLeft, "Aim FOV color", "aimFov", "Edit in Settings")

    section(aimRight, "scanning")

    slider(aimRight, "Aim FOV", 10, 180, 5, function()
        return Config.aimFov
    end, function(value)
        Config.aimFov = value
    end, "°")

    slider(aimRight, "Aim distance", 50, 1000, 25, function()
        return Config.aimMaxDistance
    end, function(value)
        Config.aimMaxDistance = value
    end, " studs")

    slider(aimRight, "Aim speed", 5, 100, 5, function()
        return Config.aimSpeed
    end, function(value)
        Config.aimSpeed = value
    end, "%")

    note(aimRight, "Aim assist is a smooth camera pull. It is skipped while a TextBox is focused and while lock-on or the ragebot has a target.")

    -- Lock-on section --------------------------------------------------------

    local lockLeft, lockRight = aimbotLeft, aimbotRight

    lockStatusLabel = statusCard(
        lockLeft,
        "lock status",
        "searching",
        "LockStatus"
    )
    UI.lockStatusLabel = lockStatusLabel

    section(lockLeft, "general")

    toggleRow(lockLeft, "Enable lock-on", "Locks the camera onto a target's chosen body part.", function()
        return Config.lockEnabled
    end, function(value)
        Config.lockEnabled = value
        if not value then
            lockTarget = nil
            lockPart = nil
        end
        if refreshLockStatus then
            refreshLockStatus()
        end
        if updateStats then
            updateStats()
        end
    end, { name = "Toggle_Lock", keyHint = "[E]" })

    toggleRow(lockLeft, "Toggle E", "On: press E to toggle lock. Off: hold E to lock.", function()
        return Config.lockMode == "toggle"
    end, function(value)
        Config.lockMode = value and "toggle" or "hold"
        lockKeyDown = false
        lockToggleActive = false
        lockTarget = nil
        lockPart = nil
        notify(value and "Lock mode: toggle E." or "Lock mode: hold E.")
    end, { name = "Toggle_LockMode" })

    toggleRow(lockLeft, "Visible targets only", "Only lock players that can actually be seen.", function()
        return Config.lockVisibleOnly
    end, function(value)
        Config.lockVisibleOnly = value
        lockTarget = nil
        lockPart = nil
    end, { name = "Toggle_LockVisible" })

    toggleRow(lockLeft, "Show lock FOV circle", "Outline-only circle in the lock color.", function()
        return Config.lockShowFov
    end, function(value)
        Config.lockShowFov = value
    end, { name = "Toggle_LockFov" })

    colorShortcut(lockLeft, "Lock FOV color", "lockFov", "Edit in Settings")

    section(lockRight, "scanning")

    slider(lockRight, "Lock FOV", 5, 90, 5, function()
        return Config.lockFov
    end, function(value)
        Config.lockFov = value
    end, "°")

    slider(lockRight, "Lock distance", 50, 1000, 25, function()
        return Config.lockDistance
    end, function(value)
        Config.lockDistance = value
    end, " studs")

    slider(lockRight, "Lock smoothness", 0, 100, 5, function()
        return Config.lockSmoothness
    end, function(value)
        Config.lockSmoothness = value
    end, "%")

    section(lockRight, "hitpart")

    UI.lockPartsLabel = partChips(lockRight, function()
        return Config.lockParts
    end, function()
        lockTarget = nil
        lockPart = nil
    end, "Lock")

    note(lockRight, "Lock-on smoothly rotates the camera toward the selected part of the nearest target inside the lock cone. It is skipped while a TextBox is focused.")

    -- Silent page ------------------------------------------------------------

    updateSilentStatus = function()
        if not UI.silentStatusLabel then
            return
        end

        local names = {}
        for _, name in ipairs({ "Head", "Torso", "Arms", "Legs" }) do
            if Config.silentParts[name] then
                names[#names + 1] = name
            end
        end
        local targetText = #names > 0 and table.concat(names, " + ") or "None"

        local acsReady = false
        local okACS, acsResult = pcall(refreshACS)
        if okACS then
            acsReady = acsResult == true
        end
        local acsSuffix = acsReady and " · acs" or ""

        if not silentAvailable then
            UI.silentStatusLabel.Text = "unavailable · executor hook support missing"
            UI.silentStatusLabel.TextColor3 = Theme.muted
        elseif Config.silentAim then
            UI.silentStatusLabel.Text = "active · targeting " .. targetText .. acsSuffix
            UI.silentStatusLabel.TextColor3 = Theme.accent
        elseif Config.rageEnabled and acsReady then
            UI.silentStatusLabel.Text = "rage · acs damage bridge"
            UI.silentStatusLabel.TextColor3 = Theme.accent
        else
            UI.silentStatusLabel.Text = "ready · targeting " .. targetText .. acsSuffix
            UI.silentStatusLabel.TextColor3 = Theme.muted
        end

        if UI.silentHookLabel then
            UI.silentHookLabel.Text = "hooks · " .. silentHookMode
                .. (acsReady and " + acs" or "")
        end
    end

    local silentPage = createPage("Silent")
    local silentLeft, silentRight = makePageColumns(silentPage)

    UI.silentStatusLabel = statusCard(
        silentLeft,
        "silent status",
        "",
        "SilentStatus"
    )

    UI.silentHookLabel = label(silentLeft, "hooks · " .. silentHookMode, {
        Name = "SilentHooks",
        Size = UDim2.new(1, 0, 0, 12),
        TextSize = 7.5,
        TextColor3 = Theme.muted,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    section(silentLeft, "general")

    toggleRow(
        silentLeft,
        "Enable silent aim",
        "Your camera stays put; shots are redirected to the target.",
        function()
            return Config.silentAim
        end,
        function(value)
            if value and not silentHooksInstalled then
                if not installSilentHooks() then
                    Config.silentAim = false
                    refreshAllControls()
                    notify("Silent aim hooks are not supported by this executor.")
                    return
                end
            end
            Config.silentAim = value
            silentCacheTime = 0
            if not value then
                silentCachePart = nil
            end
            updateSilentStatus()
            if updateStats then
                updateStats()
            end
            notify(value and "Silent aim enabled." or "Silent aim disabled.")
        end,
        {
            name = "Toggle_Silent",
            disabled = not silentAvailable,
            disabledText = "This executor does not expose hookmetamethod, so silent aim cannot run.",
            keyHint = "[V]",
        }
    )

    toggleRow(silentLeft, "Only inside FOV", "Limit targets to the silent aim FOV cone.", function()
        return Config.silentRequireFov
    end, function(value)
        Config.silentRequireFov = value
        silentCacheTime = 0
    end, { name = "Toggle_SilentFov" })

    toggleRow(silentLeft, "Wallbang", "Intercept shot rays and pass them through geometry toward the target.", function()
        return Config.silentWallbang
    end, function(value)
        Config.silentWallbang = value
        silentCacheTime = 0
        updateSilentStatus()
    end, { name = "Toggle_SilentWallbang" })

    toggleRow(silentLeft, "Visible targets only", "Skip players fully behind walls.", function()
        return Config.silentVisibleOnly
    end, function(value)
        Config.silentVisibleOnly = value
        silentCacheTime = 0
        updateSilentStatus()
    end, { name = "Toggle_SilentVisible" })

    note(silentLeft, "Silent aim rewrites mouse, camera, and Workspace raycasts without moving your view. Wallbang prefers a real target hit cast from just behind the target, so client raycast weapons register through geometry. On ACS games, the shot remote also injects a validated Damage call, so hits register even when the server ignores the redirected trace.")

    section(silentRight, "scanning")

    slider(silentRight, "Silent FOV", 10, 360, 5, function()
        return Config.silentFov
    end, function(value)
        Config.silentFov = value
        silentCacheTime = 0
    end, "°")

    slider(silentRight, "Max distance", 50, 2000, 50, function()
        return Config.silentMaxDistance
    end, function(value)
        Config.silentMaxDistance = value
        silentCacheTime = 0
    end, " studs")

    slider(silentRight, "Prediction", 0, 0.5, 0.01, function()
        return Config.silentPrediction
    end, function(value)
        Config.silentPrediction = value
        silentCacheTime = 0
    end, "s")

    section(silentRight, "hitpart")

    partChips(silentRight, function()
        return Config.silentParts
    end, function()
        updateSilentStatus()
    end, "Silent")

    updateSilentStatus()

    -- Skins page -------------------------------------------------------------

    -- Skins page -------------------------------------------------------------

    local skinsPage = createPage("Skins")
    local skinsLeft, skinsRight = makePageColumns(skinsPage)

    section(skinsLeft, "arms")

    toggleRow(skinsLeft, "Enable arms skin", "Recolor your R6/R15 arm parts.", function()
        return Config.armsSkinEnabled
    end, function(value)
        Config.armsSkinEnabled = value
        applySkins()
    end, { name = "Toggle_ArmsSkin" })

    toggleRow(skinsLeft, "Force arms visible", "Sets LocalTransparencyModifier to 0 on arms.", function()
        return Config.armsForceVisible
    end, function(value)
        Config.armsForceVisible = value
        applySkins()
    end, { name = "Toggle_ArmsVisible" })

    colorShortcut(skinsLeft, "Arms skin color", "armsSkin", "Separate color target")

    materialGrid(skinsLeft, "Arms", function()
        return Config.armsMaterial
    end, function(value)
        Config.armsMaterial = value
    end)

    section(skinsRight, "gun")

    toggleRow(skinsRight, "Enable gun skin", "Recolor BaseParts of the equipped Tool.", function()
        return Config.gunSkinEnabled
    end, function(value)
        Config.gunSkinEnabled = value
        applySkins()
    end, { name = "Toggle_GunSkin" })

    colorShortcut(skinsRight, "Gun skin color", "gunSkin", "Separate color target")

    materialGrid(skinsRight, "Gun", function()
        return Config.gunMaterial
    end, function(value)
        Config.gunMaterial = value
    end)

    note(skinsRight, "Arm colors and gun colors are stored separately. Material chips use Enum.Material names safely and apply only to your own character.")

    -- Settings: colors --------------------------------------------------------

    local colorsLeft, colorsRight = settingsLeft, settingsRight

    section(colorsLeft, "targets")

    UI.colorCards = {}

    for _, definition in ipairs(COLOR_DEFS) do
        local card = make("TextButton", {
            Name = "ColorTarget_" .. definition.key,
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = Theme.card,
            BackgroundTransparency = 0.25,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Text = "",
        })
        add(colorsLeft, card)
        corner(card, 1)
        local cardStroke = stroke(card, Theme.line, 0.65)

        local nameLabel = label(card, string.lower(definition.label), {
            Position = UDim2.new(0, 9, 0, 3),
            Size = UDim2.new(1, -42, 0, 11),
            Font = FONT,
            TextSize = 8.5,
        })

        local hexLabel = label(card, "", {
            Position = UDim2.new(0, 9, 0, 14),
            Size = UDim2.new(1, -42, 0, 10),
            TextSize = 7,
            TextColor3 = Theme.muted,
        })

        local swatch = make("Frame", {
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(1, -25, 0.5, -8),
            BackgroundColor3 = definition.color,
            BorderSizePixel = 0,
        }, card)
        corner(swatch, 1)
        stroke(swatch, Theme.line, 0.2)

        card.MouseButton1Click:Connect(function()
            selectColorTarget(definition.key)
        end)

        UI.colorCards[definition.key] = {
            button = card,
            name = nameLabel,
            hex = hexLabel,
            swatch = swatch,
            stroke = cardStroke,
        }
    end

    refreshColorTargets = function()
        for key, record in pairs(UI.colorCards) do
            local color = Config.colors[key]
            if color then
                record.swatch.BackgroundColor3 = color
                record.hex.Text = colorToHex(color)
                local active = selectedColorKey == key
                record.button.BackgroundColor3 = active and Theme.card2 or Theme.card
                record.stroke.Color = active and Theme.accent or Theme.line
                record.stroke.Transparency = active and 0.2 or 0.65
                record.name.TextColor3 = active and Theme.white or Theme.text
            end
        end
    end

    section(colorsRight, "quick presets")

    local presetColors = {
        Color3.fromRGB(255, 255, 255),
        Color3.fromRGB(5, 5, 6),
        Color3.fromRGB(255, 59, 107),
        Color3.fromRGB(0, 255, 170),
        Color3.fromRGB(69, 163, 255),
        Color3.fromRGB(255, 209, 102),
        Color3.fromRGB(179, 136, 255),
        Color3.fromRGB(0, 229, 255),
    }

    local presetRow = make("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
    })
    add(colorsRight, presetRow)

    for index, presetColor in ipairs(presetColors) do
        local preset = make("TextButton", {
            Name = "ColorPreset_" .. index,
            Position = UDim2.new(0, (index - 1) * 23, 0, 2),
            Size = UDim2.new(0, 18, 0, 18),
            BackgroundColor3 = presetColor,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Text = "",
        }, presetRow)
        corner(preset, 1)
        stroke(preset, presetColor == Color3.fromRGB(5, 5, 6) and Theme.line or Theme.white, 0.45)

        preset.MouseButton1Click:Connect(function()
            Config.colors[selectedColorKey] = presetColor
            onColorChanged(selectedColorKey)
            notify("Applied " .. colorToHex(presetColor) .. " to " .. COLOR_DEF_BY_KEY[selectedColorKey].label .. ".")
        end)
    end

    section(colorsRight, "RGB editor")

    local editorHeader = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = Theme.card,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
    })
    add(colorsRight, editorHeader)
    corner(editorHeader, 1)
    stroke(editorHeader, Theme.line, 0.65)

    UI.colorEditorTitle = label(editorHeader, "editing", {
        Position = UDim2.new(0, 10, 0, 4),
        Size = UDim2.new(1, -50, 0, 14),
        Font = FONT_BOLD,
        TextSize = 9,
    })

    UI.colorEditorHex = label(editorHeader, "#FFFFFF", {
        Position = UDim2.new(0, 10, 0, 20),
        Size = UDim2.new(1, -50, 0, 11),
        TextSize = 7.5,
        TextColor3 = Theme.muted,
    })

    UI.colorEditorSwatch = make("Frame", {
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -34, 0, 7),
        BackgroundColor3 = Config.colors[selectedColorKey],
        BorderSizePixel = 0,
    }, editorHeader)
    corner(UI.colorEditorSwatch, 1)
    stroke(UI.colorEditorSwatch, Theme.accent, 0.45)

    local function currentColor()
        return Config.colors[selectedColorKey] or Config.colors.visible
    end

    local function colorChannel(color, channel)
        if channel == "R" then
            return math.floor(color.R * 255 + 0.5)
        elseif channel == "G" then
            return math.floor(color.G * 255 + 0.5)
        end
        return math.floor(color.B * 255 + 0.5)
    end

    local function setColorChannel(channel, value)
        local color = currentColor()
        local red = colorChannel(color, "R")
        local green = colorChannel(color, "G")
        local blue = colorChannel(color, "B")
        if channel == "R" then
            red = math.floor(value + 0.5)
        elseif channel == "G" then
            green = math.floor(value + 0.5)
        else
            blue = math.floor(value + 0.5)
        end
        Config.colors[selectedColorKey] = Color3.fromRGB(red, green, blue)
        onColorChanged(selectedColorKey)
    end

    local hexInput = textInput(
        colorsRight,
        "Hex color",
        "#FF3D7F",
        function()
            return colorToHex(currentColor())
        end,
        function(text)
            local color = hexToColor(text)
            if not color then
                notify("Invalid hex color. Use #RRGGBB.")
                return
            end
            Config.colors[selectedColorKey] = color
            onColorChanged(selectedColorKey)
            refreshColorTargets()
            refreshColorEditor()
            notify(
                "Applied "
                    .. colorToHex(color)
                    .. " to "
                    .. COLOR_DEF_BY_KEY[selectedColorKey].label
                    .. "."
            )
        end,
        { name = "Input_ColorHex" }
    )

    local colorButtonRow = make("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
    })
    add(colorsRight, colorButtonRow)

    button(colorButtonRow, "Copy hex", UDim2.new(0.485, 0, 1, 0), UDim2.new(0, 0, 0, 0), false, function()
        local hex = colorToHex(currentColor())
        if type(setclipboard) == "function" then
            pcall(setclipboard, hex)
            notify("Copied " .. hex .. " to the clipboard.")
        else
            notify("Clipboard API is unavailable.")
        end
    end, { name = "CopyColorHex", textSize = 8.5 })

    button(colorButtonRow, "Reset color", UDim2.new(0.485, 0, 1, 0), UDim2.new(0.515, 0, 0, 0), false, function()
        local definition = COLOR_DEF_BY_KEY[selectedColorKey]
        if definition then
            Config.colors[selectedColorKey] = definition.color
            onColorChanged(selectedColorKey)
            refreshColorTargets()
            refreshColorEditor()
            notify("Reset " .. definition.label .. " to its default color.")
        end
    end, { name = "ResetColor", textSize = 8.5 })

    local redSlider = slider(colorsRight, "Red", 0, 255, 1, function()
        return colorChannel(currentColor(), "R")
    end, function(value)
        setColorChannel("R", value)
    end, "", true)

    local greenSlider = slider(colorsRight, "Green", 0, 255, 1, function()
        return colorChannel(currentColor(), "G")
    end, function(value)
        setColorChannel("G", value)
    end, "", true)

    local blueSlider = slider(colorsRight, "Blue", 0, 255, 1, function()
        return colorChannel(currentColor(), "B")
    end, function(value)
        setColorChannel("B", value)
    end, "", true)

    refreshColorEditor = function()
        if not UI.colorEditorTitle then
            return
        end
        local definition = COLOR_DEF_BY_KEY[selectedColorKey] or COLOR_DEF_BY_KEY.visible
        local color = currentColor()
        UI.colorEditorTitle.Text = "Editing " .. definition.label
        UI.colorEditorHex.Text = colorToHex(color)
        UI.colorEditorSwatch.BackgroundColor3 = color
        if hexInput and UserInputService:GetFocusedTextBox() ~= hexInput then
            hexInput.Text = colorToHex(color)
        end
        redSlider.set(colorChannel(color, "R"))
        greenSlider.set(colorChannel(color, "G"))
        blueSlider.set(colorChannel(color, "B"))
    end

    registerControl(refreshColorEditor)
    refreshColorTargets()
    refreshColorEditor()

    note(colorsRight, "Click a target card, type an exact hex code, drag the RGB sliders, or choose a preset. Copy and reset buttons are included. Every color change applies immediately.")

    -- Settings: config --------------------------------------------------------

    local configLeft, configRight = settingsLeft, settingsRight

    section(configLeft, "file")

    UI.configStatusLabel = statusCard(
        configLeft,
        "config status",
        "checking file api...",
        "ConfigStatus"
    )

    local configButtonRow = make("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
    })
    add(configLeft, configButtonRow)

    button(configButtonRow, "Save config", UDim2.new(0.485, 0, 1, 0), UDim2.new(0, 0, 0, 0), true, function()
        if saveConfig then
            saveConfig()
        end
    end, { name = "SaveConfig", textSize = 8.5 })

    button(configButtonRow, "Load config", UDim2.new(0.485, 0, 1, 0), UDim2.new(0.515, 0, 0, 0), false, function()
        if loadConfig then
            loadConfig(true)
        end
    end, { name = "LoadConfig", textSize = 8.5 })

    local resetButtonRow = make("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
    })
    add(configLeft, resetButtonRow)

    button(resetButtonRow, "Reset defaults", UDim2.new(0.485, 0, 1, 0), UDim2.new(0, 0, 0, 0), false, function()
        if resetDefaults then
            resetDefaults()
        end
    end, { name = "ResetDefaults", textSize = 8.5 })

    button(resetButtonRow, "Reset UI", UDim2.new(0.485, 0, 1, 0), UDim2.new(0.515, 0, 0, 0), false, function()
        resetInterface()
    end, { name = "ResetUI", textSize = 8.5 })

    note(configLeft, "Auto-loads on startup when a file API exists. Colors are stored as hex strings; toggles, sliders, body parts, and materials keep their exact values.")

    section(configRight, "interface")

    toggleRow(configRight, "Show keybinds panel", "Top-right key reference overlay.", function()
        return Config.showKeys ~= false
    end, function(value)
        Config.showKeys = value
        if UI.keysPanel then
            UI.keysPanel.Visible = value
        end
    end, { name = "Toggle_KeysPanel" })

    registerControl(function()
        if UI.keysPanel then
            UI.keysPanel.Visible = Config.showKeys ~= false
        end
    end)

    note(configRight, "Right Shift or Right Control toggles the menu. T toggles the ragebot and V toggles silent aim. Right mouse holds aim assist, E holds lock-on.")

    section(configRight, "details")

    note(configRight, "Chroma.one keeps highlights, ESP, legit aim, silent aim, lock-on, ragebot, skins, and colors in one shared config file.")

    -- Amber-style top tabs ----------------------------------------------------

    local TAB_ITEMS = {
        { page = "Aimbot", label = "Aimbot" },
        { page = "Silent", label = "Silent" },
        { page = "Visual", label = "Visual" },
        { page = "Skins", label = "Skins" },
        { page = "Players", label = "Players" },
        { page = "Settings", label = "Settings" },
    }

    local tabWidth = 1 / #TAB_ITEMS

    local function createTab(name, labelText, index)
        local tab = make("TextButton", {
            Name = "Tab_" .. name,
            Position = UDim2.new((index - 1) * tabWidth, 0, 0, 0),
            Size = UDim2.new(tabWidth, 0, 1, 0),
            BackgroundColor3 = Theme.card2,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Text = "",
            ZIndex = 5,
        }, UI.tabbar)

        local textLabel = label(tab, labelText, {
            Position = UDim2.new(0, 0, 0, -1),
            Size = UDim2.new(1, 0, 1, 0),
            Font = FONT,
            TextSize = 9,
            TextColor3 = Theme.muted,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 6,
        })

        local bar = make("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, 0),
            Size = UDim2.new(0, 26, 0, 2),
            BackgroundColor3 = Theme.accent,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 7,
        }, tab)

        if index < #TAB_ITEMS then
            make("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.new(0, 1, 0, 13),
                BackgroundColor3 = Theme.line,
                BackgroundTransparency = 0.62,
                BorderSizePixel = 0,
                ZIndex = 6,
            }, tab)
        end

        tabButtons[name] = {
            button = tab,
            text = textLabel,
            bar = bar,
            kind = "top",
        }

        tab.MouseButton1Click:Connect(function()
            showPage(name)
        end)

        tab.MouseEnter:Connect(function()
            if activeTab ~= name then
                tab.BackgroundTransparency = 0.8
            end
        end)

        tab.MouseLeave:Connect(function()
            if activeTab ~= name then
                tab.BackgroundTransparency = 1
            end
        end)
    end

    for index, item in ipairs(TAB_ITEMS) do
        createTab(item.page, item.label, index)
    end

    showPage = function(name)
        if not pages[name] then
            return
        end
        activeTab = name

        for pageName, page in pairs(pages) do
            page.Visible = pageName == name
        end

        for tabName, item in pairs(tabButtons) do
            local active = tabName == name
            item.button.BackgroundColor3 = active and Theme.card or Theme.card2
            item.button.BackgroundTransparency = active and 0.55 or 1
            item.text.TextColor3 = active and Theme.white or Theme.muted
            item.text.Font = active and FONT_BOLD or FONT
            item.bar.Visible = active
        end
    end

    showPage("Aimbot")
    end

    buildPagesAndTabs()

    -- Runtime -----------------------------------------------------------------

    local function runRuntime()
    -- ESP --------------------------------------------------------------------

    local function ensureESP(player)
        local record = espObjects[player]
        if record and record.root.Parent then
            return record
        end

        local root = make("Frame", {
            Name = "ESP_" .. player.Name,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ClipsDescendants = false,
            Visible = false,
            ZIndex = 2,
        }, UI.espFolder)

        local box = make("Frame", {
            Name = "ESP_Box_" .. player.Name,
            BackgroundColor3 = Config.colors.espBox,
            BackgroundTransparency = 0.9,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 2,
        }, root)

        local boxStroke = stroke(box, Config.colors.espBox, 0.05)
        boxStroke.Thickness = Config.espBoxThickness

        local corners = {}
        for index = 1, 4 do
            local horizontal = make("Frame", {
                Name = "ESP_CornerH_" .. player.Name .. "_" .. index,
                BackgroundColor3 = Config.colors.espBox,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 2,
            }, root)

            local vertical = make("Frame", {
                Name = "ESP_CornerV_" .. player.Name .. "_" .. index,
                BackgroundColor3 = Config.colors.espBox,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 2,
            }, root)

            corners[index] = { horizontal = horizontal, vertical = vertical }
        end

        local nameLabel = label(root, "", {
            Name = "ESP_Name_" .. player.Name,
            BackgroundTransparency = 1,
            TextColor3 = Config.colors.espName,
            Font = FONT_BOLD,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            Visible = false,
            ZIndex = 3,
        })

        local distanceLabel = label(root, "", {
            Name = "ESP_Distance_" .. player.Name,
            BackgroundTransparency = 1,
            TextColor3 = Config.colors.espName,
            Font = FONT_BOLD,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextYAlignment = Enum.TextYAlignment.Center,
            Visible = false,
            ZIndex = 3,
        })

        local healthBack = make("Frame", {
            Name = "ESP_HealthBack_" .. player.Name,
            BackgroundColor3 = Color3.fromRGB(15, 15, 17),
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 3,
        }, root)
        corner(healthBack, 1)

        local healthFill = make("Frame", {
            Name = "ESP_HealthFill_" .. player.Name,
            BackgroundColor3 = Config.colors.espHealth,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Visible = true,
            ZIndex = 3,
        }, healthBack)
        corner(healthFill, 1)

        local armorBack = make("Frame", {
            Name = "ESP_ArmorBack_" .. player.Name,
            BackgroundColor3 = Color3.fromRGB(15, 15, 17),
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 3,
        }, root)
        corner(armorBack, 1)

        local armorFill = make("Frame", {
            Name = "ESP_ArmorFill_" .. player.Name,
            BackgroundColor3 = Config.colors.espArmor,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Visible = true,
            ZIndex = 3,
        }, armorBack)
        corner(armorFill, 1)

        local tracer = make("Frame", {
            Name = "ESP_Tracer_" .. player.Name,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 1, 0),
            Size = UDim2.new(0, 1, 0, 1),
            BackgroundColor3 = Config.colors.espTracer,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 2,
        }, root)

        local toolLabel = label(root, "", {
            Name = "ESP_Tool_" .. player.Name,
            BackgroundTransparency = 1,
            TextColor3 = Config.colors.espTool,
            Font = FONT,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            Visible = false,
            ZIndex = 3,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })

        local teamLabel = label(root, "", {
            Name = "ESP_Team_" .. player.Name,
            BackgroundTransparency = 1,
            TextColor3 = Config.colors.espTeam,
            Font = FONT,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            Visible = false,
            ZIndex = 3,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })

        local boxLines = {}
        for index = 1, 12 do
            boxLines[index] = make("Frame", {
                Name = "ESP_Box3D_" .. player.Name .. "_" .. index,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.new(0, 1, 0, 1),
                BackgroundColor3 = Config.colors.espBox,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 2,
            }, root)
        end

        local skeletonLines = {}
        for index = 1, 16 do
            skeletonLines[index] = make("Frame", {
                Name = "ESP_Bone_" .. player.Name .. "_" .. index,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.new(0, 1, 0, 1),
                BackgroundColor3 = Config.colors.espSkeleton,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 2,
            }, root)
        end

        record = {
            root = root,
            box = box,
            boxStroke = boxStroke,
            nameLabel = nameLabel,
            toolLabel = toolLabel,
            teamLabel = teamLabel,
            distanceLabel = distanceLabel,
            healthBack = healthBack,
            healthFill = healthFill,
            armorBack = armorBack,
            armorFill = armorFill,
            tracer = tracer,
            skeletonLines = skeletonLines,
            boxLines = boxLines,
            corners = corners,
        }
        espObjects[player] = record
        return record
    end

    local function removeESP(player)
        local record = espObjects[player]
        if record then
            record.root:Destroy()
            espObjects[player] = nil
        end
    end

    local function playerFromPart(part)
        if not part then
            return nil
        end
        local node = part
        for _ = 1, 8 do
            local player = Players:GetPlayerFromCharacter(node)
            if player then
                return player
            end
            node = node.Parent
            if not node or node == Workspace then
                break
            end
        end
        return nil
    end

    local function getESPFocusPlayer()
        local part = lockPart
        if not (part and part.Parent) and rageTarget and ragePartName then
            local character = rageTarget.Character
            part = character and character:FindFirstChild(ragePartName)
        end
        if not (part and part.Parent) and aimTarget and aimPartName then
            local character = aimTarget.Character
            part = character and character:FindFirstChild(aimPartName)
        end
        if not (part and part.Parent) and Config.silentAim then
            part = getSilentTarget()
        end
        return playerFromPart(part)
    end

    local R15_BONES = {
        { "Head", "UpperTorso" },
        { "UpperTorso", "LowerTorso" },
        { "UpperTorso", "LeftUpperArm" },
        { "LeftUpperArm", "LeftLowerArm" },
        { "LeftLowerArm", "LeftHand" },
        { "UpperTorso", "RightUpperArm" },
        { "RightUpperArm", "RightLowerArm" },
        { "RightLowerArm", "RightHand" },
        { "LowerTorso", "LeftUpperLeg" },
        { "LeftUpperLeg", "LeftLowerLeg" },
        { "LeftLowerLeg", "LeftFoot" },
        { "LowerTorso", "RightUpperLeg" },
        { "RightUpperLeg", "RightLowerLeg" },
        { "RightLowerLeg", "RightFoot" },
    }

    local R6_BONES = {
        { "Head", "Torso" },
        { "Torso", "Left Arm" },
        { "Torso", "Right Arm" },
        { "Torso", "Left Leg" },
        { "Torso", "Right Leg" },
    }

    local function updateSkeleton(record, character, camera, color)
        for _, line in ipairs(record.skeletonLines or {}) do
            line.Visible = false
        end
        if not Config.espSkeleton then
            return
        end
        color = color or Config.colors.espSkeleton

        local bones = character:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
        local used = 0
        for _, pair in ipairs(bones) do
            local first = character:FindFirstChild(pair[1])
            local second = character:FindFirstChild(pair[2])
            if first and second
                and first:IsA("BasePart")
                and second:IsA("BasePart") then
                local startPoint = camera:WorldToViewportPoint(first.Position)
                local endPoint = camera:WorldToViewportPoint(second.Position)
                if startPoint.Z > 0 and endPoint.Z > 0 then
                    local deltaX = endPoint.X - startPoint.X
                    local deltaY = endPoint.Y - startPoint.Y
                    local length = math.sqrt(deltaX * deltaX + deltaY * deltaY)
                    used += 1
                    local line = record.skeletonLines[used]
                    if line then
                        line.Position = UDim2.new(
                            0,
                            (startPoint.X + endPoint.X) * 0.5,
                            0,
                            (startPoint.Y + endPoint.Y) * 0.5
                        )
                        line.Size = UDim2.new(
                            0,
                            math.max(length, 1),
                            0,
                            Config.espSkeletonThickness
                        )
                        line.Rotation = math.deg(math.atan2(deltaY, deltaX))
                        line.BackgroundColor3 = color
                        line.Visible = true
                    end
                end
            end
        end
    end

    local BOX3D_EDGES = {
        { 1, 5 },
        { 2, 6 },
        { 3, 7 },
        { 4, 8 },
        { 1, 3 },
        { 2, 4 },
        { 5, 7 },
        { 6, 8 },
        { 1, 2 },
        { 3, 4 },
        { 5, 6 },
        { 7, 8 },
    }

    local function updateBox3D(record, screenCorners, color, thickness)
        for _, line in ipairs(record.boxLines or {}) do
            line.Visible = false
        end

        local style = Config.espBoxStyle or "2d"
        if not Config.espBox or style ~= "3d" then
            return
        end

        for index, edge in ipairs(BOX3D_EDGES) do
            local first = screenCorners[edge[1]]
            local second = screenCorners[edge[2]]
            local line = record.boxLines[index]
            if first and second and line then
                local deltaX = second.X - first.X
                local deltaY = second.Y - first.Y
                local length = math.sqrt(deltaX * deltaX + deltaY * deltaY)
                if length > 1 then
                    line.Position = UDim2.new(
                        0,
                        (first.X + second.X) * 0.5,
                        0,
                        (first.Y + second.Y) * 0.5
                    )
                    line.Size = UDim2.new(0, length, 0, math.max(thickness, 1))
                    line.Rotation = math.deg(math.atan2(deltaY, deltaX))
                    line.BackgroundColor3 = color
                    line.Visible = true
                end
            end
        end
    end

    local ARMOR_NAMES = {
        "Armor",
        "ACS_Armor",
        "Shield",
        "ArmorValue",
        "CurrentArmor",
    }

    local MAX_ARMOR_NAMES = {
        "MaxArmor",
        "ACS_MaxArmor",
        "MaxShield",
        "MaxArmorValue",
    }

    local function readObjectNumber(object, names)
        if not object then
            return nil
        end

        for _, name in ipairs(names) do
            local okAttribute, value = pcall(function()
                local method = object.GetAttribute
                if type(method) == "function" then
                    return method(object, name)
                end
                return nil
            end)
            if okAttribute and type(value) == "number" then
                return value
            end
        end

        for _, name in ipairs(names) do
            local okChild, child = pcall(function()
                return object:FindFirstChild(name)
            end)
            if okChild and child then
                local okValue, value = pcall(function()
                    return child.Value
                end)
                if okValue and type(value) == "number" then
                    return value
                end
            end
        end

        return nil
    end

    local function getArmorFraction(character, humanoid, player)
        local armor = readObjectNumber(humanoid, ARMOR_NAMES)
            or readObjectNumber(character, ARMOR_NAMES)
            or readObjectNumber(player, ARMOR_NAMES)
        if not armor or armor <= 0 then
            return 0, false
        end

        local maximum = readObjectNumber(humanoid, MAX_ARMOR_NAMES)
            or readObjectNumber(character, MAX_ARMOR_NAMES)
            or readObjectNumber(player, MAX_ARMOR_NAMES)
        if not maximum or maximum <= 0 then
            maximum = 100
        end

        return math.clamp(armor / maximum, 0, 1), true
    end

    local function getTeamName(player)
        local team = player.Team
        if type(team) == "string" then
            return team
        end
        if team then
            local ok, name = pcall(function()
                return team.Name
            end)
            if ok and type(name) == "string" then
                return name
            end
        end
        return nil
    end

    local LOOT_KEYWORDS = {
        "chest",
        "crate",
        "loot",
        "supply",
        "ammo",
        "medkit",
        "weapon",
        "rifle",
        "pistol",
        "shotgun",
        "smg",
        "grenade",
        "armor",
        "vest",
        "helmet",
        "cash",
        "money",
        "gold",
        "resource",
        "objective",
        "pickup",
        "collect",
        "vault",
        "briefcase",
        "backpack",
    }

    local LOOT_SCAN_INTERVAL = 1.5
    local LOOT_MAX_OBJECTS = 28
    local lootObjects = {}
    local lootNameCounter = 0

    local function lootNameMatches(name)
        local lower = string.lower(tostring(name))
        for _, keyword in ipairs(LOOT_KEYWORDS) do
            if string.find(lower, keyword, 1, true) then
                return true
            end
        end
        return false
    end

    local function isInsideCharacter(instance)
        local node = instance
        for _ = 1, 10 do
            if not node or node == Workspace then
                return false
            end
            if node.ClassName == "Player" then
                return true
            end
            local ok, player = pcall(function()
                return Players:GetPlayerFromCharacter(node)
            end)
            if ok and player then
                return true
            end
            node = node.Parent
        end
        return false
    end

    local function getLootBounds(instance)
        if not instance or not instance.Parent then
            return nil
        end

        local ok, boxCFrame, boxSize = pcall(function()
            if instance:IsA("BasePart") then
                return instance.CFrame, instance.Size
            end
            return instance:GetBoundingBox()
        end)
        if ok and boxCFrame and boxSize and boxSize.Magnitude > 0.01 then
            return boxCFrame, boxSize
        end

        local okPart, part = pcall(function()
            return instance:FindFirstChildWhichIsA("BasePart", true)
        end)
        if okPart and part then
            return part.CFrame, part.Size
        end

        return nil
    end

    local function ensureLoot(instance)
        local record = lootObjects[instance]
        if record and record.root.Parent then
            return record
        end

        lootNameCounter += 1
        local root = make("Frame", {
            Name = "ESP_LootRoot_" .. lootNameCounter,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ClipsDescendants = false,
            Visible = false,
            ZIndex = 2,
        }, UI.espFolder)

        local box = make("Frame", {
            Name = "ESP_LootBox_" .. lootNameCounter,
            BackgroundColor3 = Config.colors.espLoot,
            BackgroundTransparency = 0.9,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 2,
        }, root)
        local boxStroke = stroke(box, Config.colors.espLoot, 0.1)

        local text = label(root, "", {
            Name = "ESP_LootLabel_" .. lootNameCounter,
            BackgroundTransparency = 1,
            TextColor3 = Config.colors.espLoot,
            Font = FONT_BOLD,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            Visible = false,
            ZIndex = 3,
        })

        record = {
            root = root,
            box = box,
            boxStroke = boxStroke,
            label = text,
        }
        lootObjects[instance] = record
        return record
    end

    local function scanLoot()
        local camera = Workspace.CurrentCamera
        if not camera or not Config.espEnabled or not Config.espLoot then
            return
        end

        local cameraPosition = camera.CFrame.Position
        local scored = {}
        local claimed = {}

        local okDescendants, descendants = pcall(function()
            return Workspace:GetDescendants()
        end)
        if not okDescendants or type(descendants) ~= "table" then
            descendants = {}
        end

        for _, item in ipairs(descendants) do
            local classIsTool = item:IsA("Tool")
            local classIsPart = item:IsA("BasePart")
            local classIsModel = item:IsA("Model")
            local eligibleClass = classIsTool
                or ((classIsPart or classIsModel) and lootNameMatches(item.Name))
            if eligibleClass and not isInsideCharacter(item) then
                local covered = false
                local ancestor = item.Parent
                for _ = 1, 8 do
                    if not ancestor or ancestor == Workspace then
                        break
                    end
                    if claimed[ancestor] then
                        covered = true
                        break
                    end
                    ancestor = ancestor.Parent
                end

                if not covered then
                    local boxCFrame = getLootBounds(item)
                    if boxCFrame then
                        local distance = (boxCFrame.Position - cameraPosition).Magnitude
                        if distance <= Config.espLootMaxDistance then
                            claimed[item] = true
                            scored[#scored + 1] = {
                                instance = item,
                                distance = distance,
                            }
                        end
                    end
                end
            end
        end

        table.sort(scored, function(a, b)
            return a.distance < b.distance
        end)

        local current = {}
        local limit = math.min(#scored, LOOT_MAX_OBJECTS)
        for index = 1, limit do
            local entry = scored[index]
            current[entry.instance] = true
            ensureLoot(entry.instance)
        end

        for instance, record in pairs(lootObjects) do
            if not current[instance] then
                record.root:Destroy()
                lootObjects[instance] = nil
            end
        end
    end

    local function updateLootESP(camera, viewport)
        if not Config.espEnabled or not Config.espLoot then
            for _, record in pairs(lootObjects) do
                record.root.Visible = false
            end
            return
        end

        local cameraPosition = camera.CFrame.Position
        local cameraLook = camera.CFrame.LookVector

        for instance, record in pairs(lootObjects) do
            local boxCFrame, boxSize = getLootBounds(instance)
            local shown = false

            if boxCFrame and boxSize and instance.Parent then
                local distance = (boxCFrame.Position - cameraPosition).Magnitude
                local offset = boxCFrame.Position - cameraPosition
                local facing = distance > 0.1
                    and cameraLook:Dot(offset.Unit) > -0.15
                    or false

                if distance <= Config.espLootMaxDistance and facing then
                    local minX, minY = math.huge, math.huge
                    local maxX, maxY = -math.huge, -math.huge
                    local hasCorner = false
                    local half = boxSize * 0.5

                    for _, xSign in ipairs({ -1, 1 }) do
                        for _, ySign in ipairs({ -1, 1 }) do
                            for _, zSign in ipairs({ -1, 1 }) do
                                local cornerPoint = boxCFrame:PointToWorldSpace(
                                    Vector3.new(
                                        half.X * xSign,
                                        half.Y * ySign,
                                        half.Z * zSign
                                    )
                                )
                                local screenPoint = camera:WorldToViewportPoint(cornerPoint)
                                if screenPoint.Z > 0 then
                                    hasCorner = true
                                    minX = math.min(minX, screenPoint.X)
                                    minY = math.min(minY, screenPoint.Y)
                                    maxX = math.max(maxX, screenPoint.X)
                                    maxY = math.max(maxY, screenPoint.Y)
                                end
                            end
                        end
                    end

                    if hasCorner
                        and maxX >= 0
                        and maxY >= 0
                        and minX <= viewport.X
                        and minY <= viewport.Y then
                        minX = math.clamp(minX, 0, viewport.X - 1)
                        minY = math.clamp(minY, 0, viewport.Y - 1)
                        maxX = math.clamp(maxX, 0, viewport.X - 1)
                        maxY = math.clamp(maxY, 0, viewport.Y - 1)

                        local width = math.max(maxX - minX, 3)
                        local height = math.max(maxY - minY, 3)
                        local labelY = math.max(minY - 12, 0)

                        record.root.Visible = true
                        record.box.Position = UDim2.new(0, minX, 0, minY)
                        record.box.Size = UDim2.new(0, width, 0, height)
                        record.box.BackgroundColor3 = Config.colors.espLoot
                        record.box.BackgroundTransparency = 0.9
                        record.box.Visible = true
                        record.boxStroke.Color = Config.colors.espLoot
                        record.boxStroke.Thickness = 1
                        record.boxStroke.Transparency = 0.08

                        record.label.Position = UDim2.new(
                            0,
                            math.clamp(minX, 0, math.max(viewport.X - 160, 0)),
                            0,
                            labelY
                        )
                        record.label.Size = UDim2.new(0, 160, 0, 12)
                        record.label.Text = string.format(
                            "%s  %dm",
                            instance.Name,
                            math.floor(distance + 0.5)
                        )
                        record.label.TextColor3 = Config.colors.espLoot
                        record.label.Visible = true
                        shown = true
                    end
                end
            end

            if not shown then
                record.root.Visible = false
            end
        end
    end

    local function hideLootESP()
        for _, record in pairs(lootObjects) do
            record.root.Visible = false
        end
    end

    updateESP = function()
        if not Config.espEnabled then
            for _, record in pairs(espObjects) do
                record.root.Visible = false
            end
            hideLootESP()
            return
        end

        local camera = Workspace.CurrentCamera
        if not camera then
            for _, record in pairs(espObjects) do
                record.root.Visible = false
            end
            hideLootESP()
            return
        end

        local viewport = camera.ViewportSize
        if not viewport or viewport.X < 2 or viewport.Y < 2 then
            return
        end

        for player in pairs(espObjects) do
            if not isEligible(player) then
                removeESP(player)
            end
        end

        local cameraPosition = camera.CFrame.Position
        local filterActive = Config.espTargetOnly == true
            or Config.espLockedOnly == true
        local focusPlayer = filterActive and getESPFocusPlayer() or nil

        for _, player in ipairs(Players:GetPlayers()) do
            if isEligible(player)
                and (not filterActive or player == focusPlayer) then
                local record = ensureESP(player)
                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                local shown = false

                if character and character.Parent and humanoid and humanoid.Health > 0 then
                    local ok, boxCFrame, boxSize = pcall(function()
                        return character:GetBoundingBox()
                    end)

                    if ok and boxCFrame and boxSize and boxSize.Magnitude > 0.01 then
                        local distance = (boxCFrame.Position - cameraPosition).Magnitude
                        if distance <= Config.espMaxDistance then
                            local minX, minY = math.huge, math.huge
                            local maxX, maxY = -math.huge, -math.huge
                            local hasCorner = false
                            local half = boxSize * 0.5
                            local screenCorners = {}
                            local cornerIndex = 0

                            for _, xSign in ipairs({ -1, 1 }) do
                                for _, ySign in ipairs({ -1, 1 }) do
                                    for _, zSign in ipairs({ -1, 1 }) do
                                        cornerIndex += 1
                                        local cornerPoint = boxCFrame:PointToWorldSpace(
                                            Vector3.new(
                                                half.X * xSign,
                                                half.Y * ySign,
                                                half.Z * zSign
                                            )
                                        )
                                        local screenPoint = camera:WorldToViewportPoint(cornerPoint)
                                        if screenPoint.Z > 0 then
                                            hasCorner = true
                                            screenCorners[cornerIndex] = screenPoint
                                            minX = math.min(minX, screenPoint.X)
                                            minY = math.min(minY, screenPoint.Y)
                                            maxX = math.max(maxX, screenPoint.X)
                                            maxY = math.max(maxY, screenPoint.Y)
                                        end
                                    end
                                end
                            end

                            if hasCorner
                                and maxX >= 0
                                and maxY >= 0
                                and minX <= viewport.X
                                and minY <= viewport.Y then
                                minX = math.clamp(minX, 0, viewport.X - 1)
                                minY = math.clamp(minY, 0, viewport.Y - 1)
                                maxX = math.clamp(maxX, 0, viewport.X - 1)
                                maxY = math.clamp(maxY, 0, viewport.Y - 1)

                                local width = math.max(maxX - minX, 2)
                                local height = math.max(maxY - minY, 2)
                                local displayName = player.DisplayName or player.Name
                                local health = 1
                                if humanoid.MaxHealth and humanoid.MaxHealth > 0 then
                                    health = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                                end
                                local armor, hasArmor = getArmorFraction(
                                    character,
                                    humanoid,
                                    player
                                )

                                local visibilityColor = nil
                                if Config.espVisCheck then
                                    visibilityColor = visibilityState[player] == true
                                        and Config.colors.espVisible
                                        or Config.colors.espHidden
                                end
                                local boxColor = visibilityColor or Config.colors.espBox
                                local nameColor = visibilityColor or Config.colors.espName
                                local tracerColor = visibilityColor or Config.colors.espTracer
                                local skeletonColor = visibilityColor or Config.colors.espSkeleton

                                record.root.Visible = true
                                shown = true

                                local boxStyle = Config.espBoxStyle or "2d"
                                record.box.Position = UDim2.new(0, minX, 0, minY)
                                record.box.Size = UDim2.new(0, width, 0, height)
                                record.box.BackgroundColor3 = boxColor
                                record.box.BackgroundTransparency = boxStyle == "filled"
                                    and 0.62 or 0.9
                                record.box.Visible = Config.espBox
                                    and boxStyle ~= "corners"
                                    and boxStyle ~= "3d"
                                record.boxStroke.Color = boxColor
                                record.boxStroke.Thickness = Config.espBoxThickness
                                record.boxStroke.Transparency = boxStyle == "filled"
                                    and 0.02 or 0.08

                                local cornerThickness = Config.espBoxThickness
                                local cornerArm = math.clamp(
                                    math.min(width, height) * 0.22,
                                    6,
                                    14
                                )
                                local cornerLayout = {
                                    { minX, minY, minX, minY },
                                    { maxX - cornerArm, minY, maxX - cornerThickness, minY },
                                    { minX, maxY - cornerThickness, minX, maxY - cornerArm },
                                    {
                                        maxX - cornerArm,
                                        maxY - cornerThickness,
                                        maxX - cornerThickness,
                                        maxY - cornerArm,
                                    },
                                }
                                for index, piece in ipairs(record.corners or {}) do
                                    local layout = cornerLayout[index]
                                    piece.horizontal.Position = UDim2.new(0, layout[1], 0, layout[2])
                                    piece.horizontal.Size = UDim2.new(
                                        0,
                                        cornerArm,
                                        0,
                                        cornerThickness
                                    )
                                    piece.vertical.Position = UDim2.new(0, layout[3], 0, layout[4])
                                    piece.vertical.Size = UDim2.new(
                                        0,
                                        cornerThickness,
                                        0,
                                        cornerArm
                                    )
                                    piece.horizontal.BackgroundColor3 = boxColor
                                    piece.vertical.BackgroundColor3 = boxColor
                                    piece.horizontal.Visible = Config.espBox and boxStyle == "corners"
                                    piece.vertical.Visible = Config.espBox and boxStyle == "corners"
                                end

                                updateBox3D(
                                    record,
                                    screenCorners,
                                    boxColor,
                                    Config.espBoxThickness
                                )

                                local tool = character:FindFirstChildWhichIsA("Tool")
                                local showTool = Config.espToolName == true and tool ~= nil
                                local teamName = getTeamName(player)
                                local showTeam = Config.espTeam == true and teamName ~= nil
                                local labelWidth = math.max(width, 92)
                                local labelX = math.clamp(
                                    minX,
                                    0,
                                    math.max(viewport.X - labelWidth, 0)
                                )
                                local labelRows = 0
                                if Config.espName then
                                    labelRows += 1
                                end
                                if showTool then
                                    labelRows += 1
                                end
                                if showTeam then
                                    labelRows += 1
                                end
                                local labelY = math.max(
                                    minY - math.max(labelRows, 1) * 13 - 2,
                                    0
                                )
                                local nameY = labelY
                                local toolY = nameY + (Config.espName and 13 or 0)
                                local teamY = toolY + (showTool and 13 or 0)
                                local nameWidth = labelWidth
                                local distanceX = labelX
                                local distanceWidth = labelWidth

                                if Config.espName and Config.espDistance then
                                    nameWidth = labelWidth * 0.62
                                    distanceX = labelX + labelWidth * 0.62
                                    distanceWidth = labelWidth * 0.38
                                end

                                record.nameLabel.Position = UDim2.new(0, labelX, 0, nameY)
                                record.nameLabel.Size = UDim2.new(0, nameWidth, 0, 13)
                                record.nameLabel.Text = displayName
                                record.nameLabel.TextColor3 = nameColor
                                record.nameLabel.Visible = Config.espName

                                record.toolLabel.Position = UDim2.new(0, labelX, 0, toolY)
                                record.toolLabel.Size = UDim2.new(0, labelWidth, 0, 13)
                                record.toolLabel.Text = tool and tool.Name or ""
                                record.toolLabel.TextColor3 = Config.colors.espTool
                                record.toolLabel.Visible = showTool

                                record.teamLabel.Position = UDim2.new(0, labelX, 0, teamY)
                                record.teamLabel.Size = UDim2.new(0, labelWidth, 0, 13)
                                record.teamLabel.Text = teamName or ""
                                record.teamLabel.TextColor3 = Config.colors.espTeam
                                record.teamLabel.Visible = showTeam

                                record.distanceLabel.Position = UDim2.new(0, distanceX, 0, nameY)
                                record.distanceLabel.Size = UDim2.new(0, distanceWidth, 0, 13)
                                record.distanceLabel.Text = tostring(math.floor(distance + 0.5)) .. "m"
                                record.distanceLabel.TextColor3 = nameColor
                                record.distanceLabel.Visible = Config.espDistance

                                local stackRight = minX + width + 13 <= viewport.X
                                local healthX = stackRight
                                    and (minX + width + 4)
                                    or math.max(minX - 16, 0)
                                local armorX = stackRight
                                    and (minX + width + 10)
                                    or math.max(minX - 8, 0)
                                record.healthBack.Position = UDim2.new(0, healthX, 0, minY)
                                record.healthBack.Size = UDim2.new(0, 4, 0, height)
                                record.healthBack.Visible = Config.espHealth
                                record.healthFill.BackgroundColor3 = Config.colors.espHealth
                                record.healthFill.Size = UDim2.new(1, 0, health, 0)
                                record.healthFill.Position = UDim2.new(0, 0, 1 - health, 0)

                                record.armorBack.Position = UDim2.new(0, armorX, 0, minY)
                                record.armorBack.Size = UDim2.new(0, 4, 0, height)
                                record.armorBack.Visible = Config.espArmor and hasArmor
                                record.armorFill.BackgroundColor3 = Config.colors.espArmor
                                record.armorFill.Size = UDim2.new(1, 0, armor, 0)
                                record.armorFill.Position = UDim2.new(0, 0, 1 - armor, 0)

                                if Config.espTracer then
                                    local tracerStyle = Config.espTracerStyle or "bottom"
                                    local originX = viewport.X * 0.5
                                    local originY = viewport.Y
                                    local targetX = minX + width * 0.5
                                    local targetY = minY + height

                                    if tracerStyle == "top" then
                                        originY = 0
                                        targetY = minY
                                    elseif tracerStyle == "center" then
                                        originY = viewport.Y * 0.5
                                        targetY = minY + height * 0.5
                                    end

                                    local deltaX = targetX - originX
                                    local deltaY = targetY - originY
                                    local length = math.sqrt(deltaX * deltaX + deltaY * deltaY)
                                    local tracerThickness = Config.espTracerThickness

                                    if length > 2 then
                                        record.tracer.Visible = true
                                        record.tracer.Position = UDim2.new(
                                            0,
                                            (originX + targetX) * 0.5,
                                            0,
                                            (originY + targetY) * 0.5
                                        )
                                        record.tracer.Size = UDim2.new(0, length, 0, tracerThickness)
                                        record.tracer.Rotation = math.deg(
                                            math.atan2(deltaY, deltaX)
                                        )
                                        record.tracer.BackgroundColor3 = tracerColor
                                    else
                                        record.tracer.Visible = false
                                    end
                                else
                                    record.tracer.Visible = false
                                end
                            end
                        end
                    end
                end

                if character and humanoid and humanoid.Health > 0 then
                    local skeletonColor = nil
                    if Config.espVisCheck then
                        skeletonColor = visibilityState[player] == true
                            and Config.colors.espVisible
                            or Config.colors.espHidden
                    end
                    updateSkeleton(record, character, camera, skeletonColor)
                end

                if not shown then
                    record.root.Visible = false
                end
            else
                local record = espObjects[player]
                if record then
                    record.root.Visible = false
                end
            end
        end

        if Config.espLoot then
            local now = os.clock()
            if now >= lootScanClock + LOOT_SCAN_INTERVAL then
                lootScanClock = now
                scanLoot()
            end
        end
        updateLootESP(camera, viewport)
    end

    -- Bullet tracer ----------------------------------------------------------

    local function castGetMouseHit()
        if not mouse then
            return nil
        end
        local ok, hit = pcall(function()
            return mouse.Hit
        end)
        if ok and hit and hit.Position then
            return hit.Position
        end
        return nil
    end

    local function getMuzzlePosition()
        local character = LocalPlayer.Character
        if character then
            local tool = character:FindFirstChildWhichIsA("Tool", true)
            if tool then
                local handle = tool:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then
                    return handle.Position
                end
                local firstPart = tool:FindFirstChildWhichIsA("BasePart", true)
                if firstPart then
                    return firstPart.Position
                end
            end

            for _, partName in ipairs({
                "RightHand",
                "Right Arm",
                "RightUpperArm",
                "LeftHand",
                "Left Arm",
                "LeftUpperArm",
            }) do
                local part = character:FindFirstChild(partName)
                if part and part:IsA("BasePart") then
                    return part.Position
                end
            end
        end

        local camera = Workspace.CurrentCamera
        if camera then
            return camera.CFrame.Position + camera.CFrame.LookVector * 2
        end
        return nil
    end

    local function getShotPosition()
        if lockTarget and lockPart and lockPart.Parent and lockTarget.Parent == Players then
            return lockPart.Position
        end

        if aimTarget and aimPartName then
            local character = aimTarget.Character
            local part = character and character:FindFirstChild(aimPartName)
            if part and part:IsA("BasePart") then
                return part.Position
            end
        end

        if Config.silentAim then
            local silentPart = getSilentTarget()
            if silentPart then
                return silentPart.Position
            end
        end

        local hit = castGetMouseHit()
        if hit then
            return hit
        end

        local camera = Workspace.CurrentCamera
        if camera then
            return camera.CFrame.Position + camera.CFrame.LookVector * 100
        end
        return nil
    end

    local function spawnBulletTracer()
        if not Config.espEnabled or not Config.espBulletTracer then
            return
        end

        local camera = Workspace.CurrentCamera
        if not camera then
            return
        end

        local muzzle = getMuzzlePosition()
        local shot = getShotPosition()
        if not muzzle or not shot then
            return
        end

        local muzzlePoint = camera:WorldToViewportPoint(muzzle)
        local shotPoint = camera:WorldToViewportPoint(shot)
        if muzzlePoint.Z <= 0 or shotPoint.Z <= 0 then
            return
        end

        local deltaX = shotPoint.X - muzzlePoint.X
        local deltaY = shotPoint.Y - muzzlePoint.Y
        local length = math.sqrt(deltaX * deltaX + deltaY * deltaY)
        if length < 2 then
            return
        end

        local line = make("Frame", {
            Name = "BulletTracer",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(
                0,
                (muzzlePoint.X + shotPoint.X) * 0.5,
                0,
                (muzzlePoint.Y + shotPoint.Y) * 0.5
            ),
            Size = UDim2.new(0, length, 0, Config.espBulletThickness),
            BackgroundColor3 = Config.colors.bulletTracer,
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            Rotation = math.deg(math.atan2(deltaY, deltaX)),
            Visible = true,
            ZIndex = 6,
        }, UI.bulletLayer)

        TweenService:Create(
            line,
            TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 }
        ):Play()

        task.delay(0.32, function()
            if line.Parent then
                line:Destroy()
            end
        end)
    end

    -- Lock-on ---------------------------------------------------------------

    local function isLockInputActive()
        if not Config.lockEnabled then
            return false
        end
        if UserInputService:GetFocusedTextBox() ~= nil then
            return false
        end
        if Config.lockMode == "toggle" then
            return lockToggleActive
        end
        return lockKeyDown
    end

    local function getLockPart(character)
        for _, category in ipairs(PART_CATEGORIES) do
            if Config.lockParts[category.name] then
                for _, partName in ipairs(category.parts) do
                    local part = character:FindFirstChild(partName)
                    if part and part:IsA("BasePart") then
                        return part
                    end
                end
            end
        end
        return nil
    end

    local function findLockTarget(camera)
        updateRaycastFilter()

        local cameraPosition = camera.CFrame.Position
        local lookVector = camera.CFrame.LookVector
        local halfFov = math.clamp(Config.lockFov, 1, 120) * 0.5
        local bestPlayer = nil
        local bestPart = nil
        local bestScore = math.huge

        for _, player in ipairs(Players:GetPlayers()) do
            if isEligible(player) then
                local character = player.Character
                if character and character.Parent then
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        local part = getLockPart(character)
                        if part then
                            local offset = part.Position - cameraPosition
                            local distance = offset.Magnitude
                            if distance > 0.1 and distance <= Config.lockDistance then
                                local angle = math.deg(
                                    math.acos(
                                        math.clamp(lookVector:Dot(offset.Unit), -1, 1)
                                    )
                                )
                                if angle <= halfFov then
                                    local visible = true
                                    if Config.lockVisibleOnly then
                                        visible = canSeeWorldPoint(camera, character, part.Position)
                                    end
                                    if visible then
                                        local score = distance + angle * 2
                                        if score < bestScore then
                                            bestScore = score
                                            bestPlayer = player
                                            bestPart = part
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        return bestPlayer, bestPart
    end

    local lockScanClock = 0

    refreshLockStatus = function()
        if not UI.lockStatusLabel then
            return
        end

        if lockTarget and lockPart and lockTarget.Parent == Players then
            local displayName = lockTarget.DisplayName or lockTarget.Name
            UI.lockStatusLabel.Text = "LOCKED: " .. displayName .. " · " .. lockPart.Name
            UI.lockStatusLabel.TextColor3 = Theme.accent
        else
            UI.lockStatusLabel.Text = "searching"
            UI.lockStatusLabel.TextColor3 = Theme.muted
        end
        if updateStats then
            updateStats()
        end
    end

    updateLock = function(deltaTime)
        if not isLockInputActive() then
            if lockTarget or lockPart then
                lockTarget = nil
                lockPart = nil
                refreshLockStatus()
            end
            UI.lockMarker.Visible = false
            return false
        end

        local camera = Workspace.CurrentCamera
        if not camera then
            UI.lockMarker.Visible = false
            return false
        end

        lockScanClock += deltaTime

        if lockTarget and lockPart then
            local character = lockTarget.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if not character
                or not humanoid
                or humanoid.Health <= 0
                or not lockPart.Parent then
                lockTarget = nil
                lockPart = nil
            end
        end

        if not lockTarget or lockScanClock >= 0.08 then
            lockScanClock = 0
            local nextTarget, nextPart = findLockTarget(camera)
            lockTarget = nextTarget
            lockPart = nextPart
            refreshLockStatus()
        end

        if not lockTarget or not lockPart then
            UI.lockMarker.Visible = false
            return false
        end

        local desired = CFrame.lookAt(camera.CFrame.Position, lockPart.Position)
        local speed = math.clamp((100 - Config.lockSmoothness) * 0.15 + 2, 1, 30)
        local alpha = math.clamp(speed * deltaTime, 0.01, 1)
        camera.CFrame = camera.CFrame:Lerp(desired, alpha)

        local screenPoint = camera:WorldToViewportPoint(lockPart.Position)
        if screenPoint.Z > 0 then
            UI.lockMarker.Visible = true
            UI.lockMarker.Position = UDim2.new(0, screenPoint.X, 0, screenPoint.Y)
        else
            UI.lockMarker.Visible = false
        end

        return true
    end

    -- FOV circles and footer ------------------------------------------------

    local fovOriginal = nil

    local function applyFovChanger()
        local camera = Workspace.CurrentCamera
        if not camera then
            return
        end

        if Config.fovEnabled then
            if not fovOriginal then
                fovOriginal = camera.FieldOfView or 70
            end
            if camera.FieldOfView ~= Config.fovValue then
                pcall(function()
                    camera.FieldOfView = Config.fovValue
                end)
            end
        elseif fovOriginal then
            pcall(function()
                camera.FieldOfView = fovOriginal
            end)
            fovOriginal = nil
        end
    end

    local function updateFovCircles()
        local camera = Workspace.CurrentCamera
        if not camera then
            UI.fovCircle.Visible = false
            UI.lockFovCircle.Visible = false
            UI.rageFovCircle.Visible = false
            return
        end

        local viewport = camera.ViewportSize
        local cameraFov = math.clamp(camera.FieldOfView or 70, 1, 120)

        if Config.fovCircle then
            local aimFov = math.clamp(Config.aimFov, 1, 179)
            local radius = (
                math.tan(math.rad(aimFov * 0.5))
                    / math.tan(math.rad(cameraFov * 0.5))
            ) * (viewport.Y * 0.5)
            radius = math.clamp(radius, 6, math.min(viewport.X, viewport.Y) * 0.8)
            UI.fovCircle.Visible = true
            UI.fovCircle.Size = UDim2.new(0, radius * 2, 0, radius * 2)
            UI.fovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
            UI.fovStroke.Color = Config.colors.aimFov
        else
            UI.fovCircle.Visible = false
        end

        if Config.lockEnabled and Config.lockShowFov then
            local lockFov = math.clamp(Config.lockFov, 1, 120)
            local lockRadius = (
                math.tan(math.rad(lockFov * 0.5))
                    / math.tan(math.rad(cameraFov * 0.5))
            ) * (viewport.Y * 0.5)
            lockRadius = math.clamp(
                lockRadius,
                4,
                math.min(viewport.X, viewport.Y) * 0.8
            )
            UI.lockFovCircle.Visible = true
            UI.lockFovCircle.Size = UDim2.new(0, lockRadius * 2, 0, lockRadius * 2)
            UI.lockFovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
            UI.lockFovStroke.Color = Config.colors.lockFov
        else
            UI.lockFovCircle.Visible = false
        end

        if Config.rageEnabled and Config.rageShowFov then
            local rageFov = math.clamp(Config.rageFov, 1, 360)
            local rageRadius = (
                math.tan(math.rad(math.min(rageFov, 179) * 0.5))
                    / math.tan(math.rad(cameraFov * 0.5))
            ) * (viewport.Y * 0.5)
            rageRadius = math.clamp(
                rageRadius,
                4,
                math.min(viewport.X, viewport.Y) * 0.8
            )
            UI.rageFovCircle.Visible = true
            UI.rageFovCircle.Size = UDim2.new(0, rageRadius * 2, 0, rageRadius * 2)
            UI.rageFovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
            UI.rageFovStroke.Color = Config.colors.rageFov
        else
            UI.rageFovCircle.Visible = false
        end
    end

    local function updateFooter()
        local lockState = Config.lockEnabled and "ON" or "OFF"
        local rageState = Config.rageEnabled and "ON" or "OFF"
        UI.footerStatus.Text = string.format(
            "hl %s  ·  esp %s  ·  aim %s  ·  rage %s  ·  lock %s  ·  silent %s",
            Config.highlightsEnabled and "ON" or "OFF",
            Config.espEnabled and "ON" or "OFF",
            Config.aimEnabled and "ON" or "OFF",
            rageState,
            lockState,
            (Config.silentAim and silentAvailable) and "ON" or "OFF"
        )
    end

    updateStats = function()
        local eligibleCount = 0
        for _, player in ipairs(Players:GetPlayers()) do
            if isEligible(player) then
                eligibleCount += 1
            end
        end

        local highlightedCount = 0
        for player, highlight in pairs(highlights) do
            if isEligible(player) and highlight.Enabled then
                highlightedCount += 1
            end
        end

        if UI.selectedStat then
            UI.selectedStat.Text = tostring(highlightedCount)
        end
        if UI.availableStat then
            UI.availableStat.Text = tostring(eligibleCount)
        end
        if UI.teamStat then
            UI.teamStat.Text = Config.teamCheck and "ON" or "OFF"
            UI.teamStat.TextColor3 = Config.teamCheck and Theme.accent or Theme.muted
        end
        if UI.chipText and UI.chipDot then
            local active = Config.highlightsEnabled
            UI.chipText.Text = active and "live" or "paused"
            UI.chipText.TextColor3 = active and Theme.accent or Theme.muted
            UI.chipDot.BackgroundColor3 = active and Theme.accent or Theme.muted
            UI.statusChipStroke.Color = active and Theme.accent or Theme.muted
        end
        updateFooter()
        updateSilentStatus()
    end

    -- Config file ------------------------------------------------------------

    local function serializeConfig()
        local data = {}
        for key, value in pairs(Config) do
            if key ~= "colors" then
                if type(value) == "table" then
                    local copy = {}
                    for partName, partValue in pairs(value) do
                        if type(partValue) == "boolean" then
                            copy[partName] = partValue
                        end
                    end
                    data[key] = copy
                elseif type(value) == "number"
                    or type(value) == "boolean"
                    or type(value) == "string" then
                    data[key] = value
                end
            end
        end

        data.colors = {}
        for _, definition in ipairs(COLOR_DEFS) do
            data.colors[definition.key] = colorToHex(
                Config.colors[definition.key] or definition.color
            )
        end
        data.version = 2
        return data
    end

    local function applySerialized(data)
        if type(data) ~= "table" then
            return false, "Config file did not contain a JSON object."
        end

        for key, defaultValue in pairs(Config) do
            if key ~= "colors" then
                local incoming = data[key]
                if type(defaultValue) == "boolean" and type(incoming) == "boolean" then
                    Config[key] = incoming
                elseif type(defaultValue) == "number" and type(incoming) == "number" then
                    local limits = NUMERIC_LIMITS[key]
                    if limits then
                        Config[key] = math.clamp(incoming, limits[1], limits[2])
                    else
                        Config[key] = incoming
                    end
                elseif type(defaultValue) == "string" and type(incoming) == "string" then
                    if key == "lockMode" then
                        if incoming == "hold" or incoming == "toggle" then
                            Config[key] = incoming
                        end
                    elseif key == "armsMaterial" or key == "gunMaterial" then
                        if MATERIAL_SET[incoming] then
                            Config[key] = incoming
                        end
                    else
                        Config[key] = incoming
                    end
                elseif type(defaultValue) == "table" and type(incoming) == "table" then
                    for partName, partValue in pairs(defaultValue) do
                        if type(incoming[partName]) == "boolean" then
                            defaultValue[partName] = incoming[partName]
                        end
                    end
                end
            end
        end

        local function ensurePart(tbl)
            local any = false
            for _, value in pairs(tbl) do
                if value then
                    any = true
                end
            end
            if not any then
                tbl.Head = true
            end
        end
        ensurePart(Config.lockParts)
        ensurePart(Config.silentParts)
        ensurePart(Config.rageParts)

        if Config.silentAim and not installSilentHooks() then
            Config.silentAim = false
        end
        if Config.rageEnabled and not silentHooksInstalled then
            installSilentHooks()
        end

        if Config.espBoxStyle ~= "2d"
            and Config.espBoxStyle ~= "3d"
            and Config.espBoxStyle ~= "corners"
            and Config.espBoxStyle ~= "filled" then
            Config.espBoxStyle = "2d"
        end
        if Config.espTracerStyle ~= "bottom"
            and Config.espTracerStyle ~= "top"
            and Config.espTracerStyle ~= "center" then
            Config.espTracerStyle = "bottom"
        end

        if type(data.colors) == "table" then
            for _, definition in ipairs(COLOR_DEFS) do
                local parsed = hexToColor(data.colors[definition.key])
                if parsed then
                    Config.colors[definition.key] = parsed
                end
            end
        end

        return true
    end

    local hasFileApi = type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"

    saveConfig = function()
        if not hasFileApi then
            setConfigStatus("File API unavailable — save/load disabled.")
            notify("Executor has no file API; config was not saved.")
            return
        end

        local okEncode, encoded = pcall(
            HttpService.JSONEncode,
            HttpService,
            serializeConfig()
        )
        if not okEncode or type(encoded) ~= "string" then
            setConfigStatus("Save failed while encoding JSON.")
            notify("Could not encode the config.")
            return
        end

        local okWrite, writeError = pcall(writefile, CONFIG_FILE, encoded)
        if not okWrite then
            setConfigStatus("Save failed: " .. tostring(writeError))
            notify("Could not write the config file.")
            return
        end

        setConfigStatus("Saved " .. CONFIG_FILE)
        notify("Config saved to " .. CONFIG_FILE .. ".")
    end

    loadConfig = function(manual)
        if not hasFileApi then
            setConfigStatus("File API unavailable — save/load disabled.")
            if manual then
                notify("Executor has no file API; config cannot be loaded.")
            end
            return false
        end

        local okExists, exists = pcall(isfile, CONFIG_FILE)
        if not okExists then
            setConfigStatus("Could not query " .. CONFIG_FILE .. ".")
            return false
        end
        if not exists then
            setConfigStatus("No saved config found — defaults active.")
            if manual then
                notify("No saved config file was found.")
            end
            return false
        end

        local okRead, contents = pcall(readfile, CONFIG_FILE)
        if not okRead or type(contents) ~= "string" then
            setConfigStatus("Could not read " .. CONFIG_FILE .. ".")
            return false
        end

        local okDecode, data = pcall(HttpService.JSONDecode, HttpService, contents)
        if not okDecode then
            setConfigStatus("Config JSON could not be decoded.")
            return false
        end

        local okApply, applyError = applySerialized(data)
        if not okApply then
            setConfigStatus(tostring(applyError))
            return false
        end

        lockTarget = nil
        lockPart = nil
        lockKeyDown = false
        lockToggleActive = false
        aimTarget = nil
        aimPartName = nil
        rageTarget = nil
        ragePartName = nil
        silentCacheTime = 0
        silentCachePart = nil
        silentCachePoint = nil

        refreshAllControls()
        refreshAllHighlights()
        refreshColorTargets()
        refreshLockStatus()
        refreshRageStatus()
        updateSilentStatus()
        restyleAll()
        applySkins()
        updateESP()
        updateStats()
        setConfigStatus("Loaded " .. CONFIG_FILE)
        if manual then
            notify("Config loaded from " .. CONFIG_FILE .. ".")
        end
        return true
    end

    resetDefaults = function()
        Config = makeDefaults()
        selectedColorKey = "visible"
        lockTarget = nil
        lockPart = nil
        lockKeyDown = false
        lockToggleActive = false
        aimTarget = nil
        aimPartName = nil
        rageTarget = nil
        ragePartName = nil
        silentCacheTime = 0
        silentCachePart = nil
        silentCachePoint = nil

        refreshAllControls()
        refreshColorTargets()
        refreshLockStatus()
        refreshRageStatus()
        updateSilentStatus()
        refreshColorEditor()
        refreshAllHighlights()
        restyleAll()
        applySkins()
        updateESP()
        updateStats()
        setConfigStatus("Defaults restored — file unchanged.")
        notify("All settings reset to defaults.")
    end

    -- Input ------------------------------------------------------------------

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.KeyCode == Enum.KeyCode.RightShift
            or input.KeyCode == Enum.KeyCode.RightControl then
            if UserInputService:GetFocusedTextBox() ~= nil then
                return
            end
            setMenuOpen(not UI.menuOpen)
            return
        end

        if input.KeyCode == Enum.KeyCode.T then
            if UserInputService:GetFocusedTextBox() ~= nil then
                return
            end
            Config.rageEnabled = not Config.rageEnabled
            if Config.rageEnabled and not silentHooksInstalled then
                installSilentHooks()
            end
            if not Config.rageEnabled then
                rageTarget = nil
                ragePartName = nil
            end
            refreshAllControls()
            refreshRageStatus()
            updateSilentStatus()
            if updateStats then
                updateStats()
            end
            notify(Config.rageEnabled and "Ragebot enabled [T]." or "Ragebot disabled [T].")
            return
        end

        if input.KeyCode == Enum.KeyCode.V then
            if UserInputService:GetFocusedTextBox() ~= nil then
                return
            end
            if not silentAvailable then
                notify("Silent aim needs executor hook support.")
                return
            end
            if not Config.silentAim
                and not silentHooksInstalled
                and not installSilentHooks() then
                notify("Silent aim hooks are not supported by this executor.")
                return
            end
            Config.silentAim = not Config.silentAim
            silentCacheTime = 0
            if not Config.silentAim then
                silentCachePart = nil
            end
            refreshAllControls()
            updateSilentStatus()
            if updateStats then
                updateStats()
            end
            notify(Config.silentAim and "Silent aim enabled [V]." or "Silent aim disabled [V].")
            return
        end

        if input.KeyCode == Enum.KeyCode.E then
            if UserInputService:GetFocusedTextBox() ~= nil then
                return
            end
            if not Config.lockEnabled then
                return
            end

            if Config.lockMode == "toggle" then
                lockToggleActive = not lockToggleActive
                lockKeyDown = false
                if lockToggleActive then
                    notify("Lock-on armed.")
                else
                    lockTarget = nil
                    lockPart = nil
                    refreshLockStatus()
                    notify("Lock-on disarmed.")
                end
            else
                lockKeyDown = true
            end
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1
            and not gameProcessed then
            spawnBulletTracer()
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.E then
            lockKeyDown = false
        end
    end)

    local draggingWindow = false
    local dragStart = nil
    local dragOrigin = nil

    UI.topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingWindow = true
            dragStart = input.Position
            dragOrigin = UI.windowRoot.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not draggingWindow or not dragStart or not dragOrigin then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            local camera = Workspace.CurrentCamera
            local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
            local limitX = math.max(viewport.X * 0.5 - 60, 0)
            local limitY = math.max(viewport.Y * 0.5 - 60, 0)
            local newX = math.clamp(
                dragOrigin.X.Offset + delta.X,
                -limitX,
                limitX
            )
            local newY = math.clamp(
                dragOrigin.Y.Offset + delta.Y,
                -limitY,
                limitY
            )
            UI.windowRoot.Position = UDim2.new(0.5, newX, 0.5, newY)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingWindow = false
        end
    end)

    -- Render loop ------------------------------------------------------------

    for _, renderName in ipairs({
        "ChromaOneAim",
        "ChromaOneAimAssist",
        "ChromaOneRender",
    }) do
        pcall(function()
            RunService:UnbindFromRenderStep(renderName)
        end)
    end

    pcall(function()
        RunService:BindToRenderStep(
            "ChromaOneRender",
            Enum.RenderPriority.Camera.Value + 1,
            function(deltaTime)
                local locking = isLockInputActive()
                updateLock(deltaTime)
                if not locking then
                    local raging = updateRage(deltaTime)
                    if not raging then
                        updateAim(deltaTime)
                    end
                end
                applyFovChanger()
                updateFovCircles()
                updateESP()
            end
        )
    end)

    -- Players and startup ----------------------------------------------------

    Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then
            watchPlayer(player)
            task.defer(function()
                if isEligible(player) then
                    ensureHighlight(player)
                end
                updateStats()
            end)
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        watchedPlayers[player] = nil
        removeHighlight(player)
        removeESP(player)
        if lockTarget == player then
            lockTarget = nil
            lockPart = nil
            refreshLockStatus()
        end
        if aimTarget == player then
            aimTarget = nil
            aimPartName = nil
        end
        task.defer(updateStats)
    end)

    LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
        refreshAllHighlights()
        updateStats()
    end)

    LocalPlayer:GetPropertyChangedSignal("TeamColor"):Connect(function()
        refreshAllHighlights()
        updateStats()
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            watchPlayer(player)
        end
    end

    refreshAllHighlights()
    refreshAllControls()
    refreshColorTargets()
    refreshColorEditor()
    applySkins()

    if hasFileApi then
        local okExists, exists = pcall(isfile, CONFIG_FILE)
        if okExists and exists then
            loadConfig(false)
        else
            setConfigStatus("No saved config yet — defaults active.")
        end
    else
        setConfigStatus("File API unavailable — save/load disabled.")
    end

    refreshAllHighlights()
    restyleAll()
    updateStats()
    refreshLockStatus()
    updateSilentStatus()
    updateESP()

    notify("Chroma.one ready  ·  Right Shift / RightControl")

    local debugEnv = type(_G) == "table" and _G or {}
    if type(getgenv) == "function" then
        local okEnv, env = pcall(getgenv)
        if okEnv and type(env) == "table" then
            debugEnv = env
        end
    end
    pcall(function()
        debugEnv.ChromaOneDebug = {
            version = "2.2",
            getConfig = function()
                return Config
            end,
            getSelectedColorKey = function()
                return selectedColorKey
            end,
            getLockTarget = function()
                return lockTarget, lockPart
            end,
            getMuzzlePosition = getMuzzlePosition,
            getSilentHookMode = function()
                return silentHookMode, silentAvailable
            end,
            getACS = function()
                refreshACS()
                return {
                    found = ACS.damage ~= nil,
                    damage = ACS.damage,
                    access = ACS.access,
                    shoot = ACS.shoot,
                    atirar = ACS.atirar,
                    token = ACS.token,
                }
            end,
            setMenuOpen = setMenuOpen,
        }
    end)

    print("[Chroma.one] Loaded. Right Shift or RightControl toggles the menu.")
    end

    runRuntime()
end

local ok, err = xpcall(boot, function(message)
    if debug and debug.traceback then
        return debug.traceback(tostring(message), 2)
    end
    return tostring(message)
end)

if not ok then
    showFatalError(err)
end
