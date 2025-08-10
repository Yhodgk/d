-- Vox Seas Auto Farm Script (Improved Version)
-- By shaka (discord.gg/t4aCqjX84m)

local _ENV = (getgenv or getrenv or getfenv)()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local DialogueEvent = ReplicatedStorage:WaitForChild("BetweenSides"):WaitForChild("Remotes"):WaitForChild("Events"):WaitForChild("DialogueEvent")
local CombatEvent = ReplicatedStorage:WaitForChild("BetweenSides"):WaitForChild("Remotes"):WaitForChild("Events"):WaitForChild("CombatEvent")
local ToolEvent = ReplicatedStorage:WaitForChild("BetweenSides"):WaitForChild("Remotes"):WaitForChild("Events"):WaitForChild("ToolsEvent")
local StatsEvent = ReplicatedStorage:WaitForChild("BetweenSides"):WaitForChild("Remotes"):WaitForChild("Events"):WaitForChild("StatsEvent")
local QuestsNpcs = workspace:WaitForChild("IgnoreList"):WaitForChild("Int"):WaitForChild("NPCs"):WaitForChild("Quests")
local Enemys = workspace:WaitForChild("Playability"):WaitForChild("Enemys")
local QuestsDecriptions = require(ReplicatedStorage:WaitForChild("MainModules"):WaitForChild("Essentials"):WaitForChild("QuestDescriptions"))
local EnemiesFolders = {}
local CFrameAngle = CFrame.Angles(math.rad(-90), 0, 0)

-- Environment setup
_ENV.OnFarm = false
_ENV.BringMob = false

-- Connection management
local activeConnections = {}
local function addConnection(connection)
    table.insert(activeConnections, connection)
end

local function disconnectAllConnections()
    for _, conn in ipairs(activeConnections) do
        if typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    table.clear(activeConnections)
end

-- Character utility functions
local function isCharacterAlive(character)
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

-- Safe remote call function
local function safeFireRemote(remote, ...)
    if not remote or not remote:IsA("RemoteEvent") then return false end
    
    local args = {...}
    local success, result = pcall(function()
        remote:FireServer(unpack(args))
    end)
    
    return success
end

-- Get current quest function
local function getCurrentQuest()
    local questsList = {}
    local currentQuest = nil
    local currentLevel = -1
    
    for _, questData in pairs(QuestsDecriptions) do
        if questData.Goal > 1 then
            table.insert(questsList, {
                Level = questData.MinLevel,
                Target = questData.Target,
                NpcName = questData.Npc,
                Id = questData.Id
            })
        end
    end
    
    table.sort(questsList, function(a, b)
        return a.Level > b.Level
    end)
    
    local function getPlayerLevel()
        local level = 1
        local success, result = pcall(function()
            local mainUI = Player.PlayerGui:FindFirstChild("MainUI")
            if not mainUI then return 1 end
            
            local mainFrame = mainUI:FindFirstChild("MainFrame")
            if not mainFrame then return 1 end
            
            local statsFrame = mainFrame:FindFirstChild("StastisticsFrame") or mainFrame:FindFirstChild("StatisticsFrame")
            if not statsFrame then return 1 end
            
            local levelBG = statsFrame:FindFirstChild("LevelBackground")
            if levelBG then
                local levelText = levelBG:FindFirstChild("Level")
                if levelText and levelText.Text then
                    return tonumber(levelText.Text) or 1
                end
            end
            
            for _, child in pairs(statsFrame:GetDescendants()) do
                if child:IsA("TextLabel") and child.Text:match("^%d+$") then
                    local num = tonumber(child.Text)
                    if num and num >= 1 and num <= 2000 then
                        return num
                    end
                end
            end
            
            return 1
        end)
        
        return success and result or 1
    end
    
    local playerLevel = getPlayerLevel()
    if playerLevel == currentLevel and currentQuest then
        return currentQuest
    end
    
    currentLevel = playerLevel
    for _, questData in ipairs(questsList) do
        if questData.Level <= currentLevel then
            currentQuest = questData
            return currentQuest
        end
    end
    return nil
end

-- Settings
local Settings = {
    ClickV2 = false,
    TweenSpeed = 270,
    SelectedTool = "CombatType",
    BringMobDistance = 35,
    FarmDelay = 0.05,
    NoClip = false,
    AutoStats = false,
    SelectedStat = "Strength"
}

local EquippedTool = nil
local CurrentTarget = nil

-- BodyVelocity setup
local tweenBodyVelocity = Instance.new("BodyVelocity")
tweenBodyVelocity.Velocity = Vector3.zero
tweenBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
tweenBodyVelocity.P = 1000

if _ENV.tween_bodyvelocity then
    _ENV.tween_bodyvelocity:Destroy()
end
_ENV.tween_bodyvelocity = tweenBodyVelocity

-- NoClip implementation
local collidableObjects = {}

local function trackCollidable(object)
    if object:IsA("BasePart") and object.CanCollide then
        table.insert(collidableObjects, object)
    end
end

local function removeCollidable(basePart)
    local index = table.find(collidableObjects, basePart)
    if index then
        table.remove(collidableObjects, index)
    end
end

local function setupCharacter(character)
    table.clear(collidableObjects)
    for _, object in character:GetDescendants() do
        trackCollidable(object)
    end
    
    addConnection(character.DescendantAdded:Connect(trackCollidable))
    addConnection(character.DescendantRemoving:Connect(removeCollidable))
end

if Player.Character then
    setupCharacter(Player.Character)
end
addConnection(Player.CharacterAdded:Connect(setupCharacter))

local function updateNoClip(character)
    if _ENV.OnFarm then
        for _, obj in ipairs(collidableObjects) do
            if obj:IsA("BasePart") then
                obj.CanCollide = false
            end
        end
    else
        for _, obj in ipairs(collidableObjects) do
            if obj:IsA("BasePart") and not obj.CanCollide then
                obj.CanCollide = true
            end
        end
    end
end

local function updateBodyVelocity(character)
    local basePart = character:FindFirstChild("UpperTorso") or character.PrimaryPart
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if _ENV.OnFarm and basePart and humanoid and humanoid.Health > 0 then
        if tweenBodyVelocity.Parent ~= basePart then
            tweenBodyVelocity.Parent = basePart
        end
    elseif tweenBodyVelocity.Parent then
        tweenBodyVelocity.Parent = nil
    end
    
    if tweenBodyVelocity.Velocity ~= Vector3.zero and (not humanoid or not humanoid.SeatPart or not _ENV.OnFarm) then
        tweenBodyVelocity.Velocity = Vector3.zero
    end
end

addConnection(RunService.Stepped:Connect(function()
    local character = Player.Character
    if isCharacterAlive(character) then
        updateBodyVelocity(character)
        updateNoClip(character)
    end
end))

-- Tween management
local TweenManager = {}
TweenManager.ActiveTweens = {}

function TweenManager:CreateTween(obj, time, prop, value)
    self:CancelTween(obj)
    
    local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(obj, tweenInfo, {[prop] = value})
    
    tween:Play()
    self.ActiveTweens[obj] = tween
    
    local connection
    connection = tween.Completed:Connect(function()
        self.ActiveTweens[obj] = nil
        if connection then
            connection:Disconnect()
        end
    end)
    
    return tween
end

function TweenManager:CancelTween(obj)
    if self.ActiveTweens[obj] then
        self.ActiveTweens[obj]:Cancel()
        self.ActiveTweens[obj] = nil
    end
end

local lastCFrame = nil
local lastTeleport = 0

-- Teleport function
local function teleportToPosition(targetCFrame)
    while not Player.Character or not isCharacterAlive(Player.Character) do
        task.wait(1)
        if not _ENV.OnFarm then
            return false
        end
    end
    
    if not Player.Character or not Player.Character.PrimaryPart then
        return false
    end
    
    if (tick() - lastTeleport) <= 0.3 and lastCFrame == targetCFrame then
        return false
    end
    
    local character = Player.Character
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local primaryPart = character.PrimaryPart
    
    if not humanoid or not primaryPart then
        return false
    end
    
    if humanoid.Sit then
        humanoid.Sit = false
        task.wait(0.1)
        return false
    end
    
    lastTeleport = tick()
    lastCFrame = targetCFrame
    _ENV.OnFarm = true
    
    local teleportPosition = targetCFrame.Position
    local currentPosition = primaryPart.Position
    local distance = (currentPosition - teleportPosition).Magnitude
    
    if distance < 20 then
        primaryPart.CFrame = targetCFrame
        TweenManager:CancelTween(primaryPart)
        return true
    end
    
    TweenManager:CancelTween(primaryPart)
    TweenManager:CreateTween(primaryPart, distance / Settings.TweenSpeed, "CFrame", targetCFrame)
    return true
end

-- Attack functions
local function attackWithTool()
    if not isCharacterAlive(Player.Character) then
        return
    end
    
    local tool = Player.Character:FindFirstChildOfClass("Tool")
    if not tool then
        return
    end
    
    pcall(function()
        tool:Activate()
        local handle = tool:FindFirstChild("Handle")
        if handle then
            if handle:FindFirstChild("Cooldown") then
                handle.Cooldown.Value = 0
            end
            if handle:FindFirstChild("AttackCooldown") then
                handle.AttackCooldown.Value = 0
            end
            if handle:FindFirstChild("Debounce") then
                handle.Debounce.Value = false
            end
            local sound = handle:FindFirstChildOfClass("Sound")
            if sound then
                sound:Play()
            end
        end
        
        safeFireRemote(ToolEvent, "Effects", 1)
        safeFireRemote(ToolEvent, "Activate", 1)
        
        if Settings.ClickV2 then
            for i = 1, 3 do
                tool:Activate()
                task.wait(0.01)
            end
        end
    end)
end

local function dealDamage(enemies)
    safeFireRemote(CombatEvent, "DealDamage", {
        CallTime = workspace:GetServerTimeNow(),
        DelayTime = 0,
        Combo = 1,
        Results = enemies,
        Damage = math.random(50, 150),
        CriticalHit = math.random(1, 10) <= 3
    })
end

-- Enemy utilities
local function getEnemiesInFolder(folder, enemyName)
    local foundEnemies = {}
    for _, enemy in pairs(folder:GetChildren()) do
        if enemy and enemy.Parent then
            local nameAttribute = enemy:GetAttribute("OriginalName") 
                or enemy:GetAttribute("EnemyName") 
                or enemy.Name
            
            if nameAttribute == enemyName or string.find(nameAttribute, enemyName) then
                local humanoid = enemy:FindFirstChild("Humanoid")
                local rootPart = enemy:FindFirstChild("HumanoidRootPart")
                
                if humanoid and rootPart and humanoid.Health > 0 then
                    local isReady = true
                    if enemy:GetAttribute("Respawned") ~= nil then
                        isReady = enemy:GetAttribute("Respawned")
                    end
                    if enemy:GetAttribute("Ready") ~= nil then
                        isReady = isReady and enemy:GetAttribute("Ready")
                    end
                    if isReady then
                        table.insert(foundEnemies, enemy)
                    end
                end
            end
        end
    end
    return foundEnemies
end

local function getAllEnemies(enemyName)
    local allEnemies = {}
    local enemyFolder = EnemiesFolders[enemyName]
    
    if enemyFolder and enemyFolder.Parent then
        local enemies = getEnemiesInFolder(enemyFolder, enemyName)
        for _, enemy in ipairs(enemies) do
            table.insert(allEnemies, enemy)
        end
    else
        if Enemys and Enemys.Parent then
            for _, island in ipairs(Enemys:GetChildren()) do
                if island and island.Parent then
                    local enemies = getEnemiesInFolder(island, enemyName)
                    if #enemies > 0 then
                        EnemiesFolders[enemyName] = island
                        for _, enemy in ipairs(enemies) do
                            table.insert(allEnemies, enemy)
                        end
                    end
                end
            end
        end
    end
    return allEnemies
end

local function getClosestEnemy(enemyName)
    local allEnemies = getAllEnemies(enemyName)
    if #allEnemies == 0 then
        return nil
    end
    
    local closestEnemy = nil
    local shortestDistance = math.huge
    
    for _, enemy in ipairs(allEnemies) do
        if enemy and enemy.Parent then
            local rootPart = enemy:FindFirstChild("HumanoidRootPart")
            local humanoid = enemy:FindFirstChild("Humanoid")
            
            if rootPart and humanoid and humanoid.Health > 0 then
                local distance = Player:DistanceFromCharacter(rootPart.Position)
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestEnemy = enemy
                end
            end
        end
    end
    
    return closestEnemy
end

local function bringEnemies(enemyName, targetPosition)
    if not _ENV.BringMob then
        return 0
    end
    
    local allEnemies = getAllEnemies(enemyName)
    local broughtCount = 0
    
    if #allEnemies == 0 then
        return 0
    end
    
    for _, enemy in ipairs(allEnemies) do
        if enemy and enemy.Parent then
            local rootPart = enemy:FindFirstChild("HumanoidRootPart")
            local humanoid = enemy:FindFirstChild("Humanoid")
            
            if rootPart and humanoid and humanoid.Health > 0 then
                -- Create new BodyVelocity for each NPC
                local velocity = rootPart:FindFirstChild("MobVelocity") or Instance.new("BodyVelocity")
                velocity.Name = "MobVelocity"
                velocity.Velocity = Vector3.zero
                velocity.MaxForce = Vector3.new(4000, 4000, 4000)
                velocity.P = 1000
                velocity.Parent = rootPart
                
                rootPart.CanCollide = false
                rootPart.CFrame = targetPosition
                broughtCount = broughtCount + 1
                
                -- Auto-destroy after delay
                task.delay(5, function()
                    if velocity and velocity.Parent then
                        velocity:Destroy()
                    end
                end)
            end
        end
    end
    
    if broughtCount > 0 then
        pcall(sethiddenproperty, Player, "SimulationRadius", math.huge)
    end
    
    return broughtCount
end

-- Tool management
local function isSelectedTool(tool)
    return tool:GetAttribute(Settings.SelectedTool)
end

local function equipCombatTool(shouldActivate)
    if not isCharacterAlive(Player.Character) then
        return
    end
    
    if EquippedTool and isSelectedTool(EquippedTool) then
        if shouldActivate then
            if Settings.ClickV2 then
                attackWithTool()
            else
                EquippedTool:Activate()
            end
        end
        
        if EquippedTool.Parent == Player.Backpack then
            Player.Character.Humanoid:EquipTool(EquippedTool)
        elseif EquippedTool.Parent ~= Player.Character then
            EquippedTool = nil
        end
        return
    end
    
    local equipped = Player.Character:FindFirstChildOfClass("Tool")
    if equipped and isSelectedTool(equipped) then
        EquippedTool = equipped
        return
    end
    
    for _, tool in Player.Backpack:GetChildren() do
        if tool:IsA("Tool") and isSelectedTool(tool) then
            EquippedTool = tool
            Player.Character.Humanoid:EquipTool(tool)
            return
        end
    end
end

-- Quest utilities
local function isQuestActive(enemyName)
    local success, result = pcall(function()
        local mainUI = Player.PlayerGui:FindFirstChild("MainUI")
        if not mainUI then return false end
        
        local mainFrame = mainUI:FindFirstChild("MainFrame")
        if not mainFrame then return false end
        
        local questFrame = mainFrame:FindFirstChild("CurrentQuest")
        if not questFrame or not questFrame.Visible then
            return false
        end
        
        local questText = nil
        local goalElement = questFrame:FindFirstChild("Goal")
        if goalElement and goalElement.Text then
            questText = goalElement.Text
        end
        
        if not questText then
            for _, child in pairs(questFrame:GetDescendants()) do
                if child:IsA("TextLabel") and child.Text and child.Text ~= "" then
                    if string.find(child.Text, "Defeat") or string.find(child.Text, "/") then
                        questText = child.Text
                        break
                    end
                end
            end
        end
        
        if questText then
            return string.find(questText, enemyName) ~= nil
        end
        return false
    end)
    
    return success and result
end

local function acceptQuest(questName, questId)
    local npc = QuestsNpcs:FindFirstChild(questName, true)
    if not npc then return end
    
    local rootPart = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
    if rootPart then
        safeFireRemote(DialogueEvent, "Quests", {
            ["NpcName"] = questName,
            ["QuestName"] = questId
        })
        teleportToPosition(rootPart.CFrame * CFrame.new(0, 0, 15))
        task.wait(2)
    end
end

-- GUI Setup
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Idk Hub - Vox Seas",
    SubTitle = "by shaka",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftShift
})

local Tabs = {
    Disc = Window:AddTab({Title = "We", Icon = "rbxassetid://5013032505"}),
    Main = Window:AddTab({Title = "Main", Icon = "rbxassetid://131580529707278"}),
    Misc = Window:AddTab({Title = "Misc", Icon = "rbxassetid://139867952423882"}),
    SettingsTab = Window:AddTab({Title = "Settings", Icon = "rbxassetid://113400358595552"})
}

-- Discord Tab
Tabs.Disc:AddSection("About We")
Tabs.Disc:AddButton({
    Title = "DISCORD SERVER",
    Description = "Be notified of updates, click to copy",
    Callback = function() setclipboard("https://discord.gg/t4aCqjX84m") end
})
Tabs.Disc:AddButton({
    Title = "YOUTUBE SHAKA - ROBLOX SCRIPTS",
    Description = "Click to copy link",
    Callback = function() setclipboard("https://www.youtube.com/@shakascripts") end
})

-- Main Tab
Tabs.Main:AddSection("Auto Farm")
Tabs.Main:AddToggle("AutoFarm", {
    Title = "Auto Farm With Quests",
    Default = false,
    Callback = function(value)
        _ENV.OnFarm = value
        if value then
            task.spawn(function()
                while task.wait(Settings.FarmDelay) and _ENV.OnFarm do
                    if not isCharacterAlive(Player.Character) then
                        repeat task.wait(0.5) until isCharacterAlive(Player.Character)
                        task.wait(0.2)
                        continue
                    end
                    
                    local currentQuest = getCurrentQuest()
                    if not currentQuest then
                        task.wait(1)
                        continue
                    end
                    
                    if not isQuestActive(currentQuest.Target) then
                        acceptQuest(currentQuest.NpcName, currentQuest.Id)
                        task.wait(1)
                        continue
                    end
                    
                    local enemy = getClosestEnemy(currentQuest.Target)
                    if not enemy then
                        task.wait(1)
                        continue
                    end
                    
                    CurrentTarget = enemy
                    local rootPart = enemy:FindFirstChild("HumanoidRootPart")
                    local humanoid = enemy:FindFirstChild("Humanoid")
                    
                    if rootPart and humanoid and humanoid.Health > 0 then
                        if _ENV.BringMob then
                            bringEnemies(currentQuest.Target, rootPart.CFrame)
                        end
                        
                        local targetCFrame = rootPart.CFrame * CFrame.new(0, 7.5, 0) * CFrameAngle
                        if not teleportToPosition(targetCFrame) then
                            if Player.Character and Player.Character.PrimaryPart then
                                Player.Character.PrimaryPart.CFrame = targetCFrame
                            end
                        end
                        
                        task.wait(0.1)
                        equipCombatTool(true)
                        
                        local allQuestEnemies = getAllEnemies(currentQuest.Target)
                        if #allQuestEnemies > 0 then
                            dealDamage(allQuestEnemies)
                        end
                    end
                end
            end)
        end
    end
})

Tabs.Main:AddToggle("BringMob", {
    Title = "Bring Mob (Current Quest)",
    Default = false,
    Callback = function(value) _ENV.BringMob = value end
})

Tabs.Main:AddSection("Tools")
local ToolDropdown = Tabs.Main:AddDropdown("ToolDropdown", {
    Title = "Select Tool",
    Values = {},
    Multi = false,
    Default = nil
})

local ToolToggle = Tabs.Main:AddToggle("ToolToggle", {
    Title = "Auto Equip Tool",
    Default = false
})

local isEquipping = false
local function equipSelectedTool()
    if not ToolToggle.Value or isEquipping then return end
    isEquipping = true
    
    local selectedTool = ToolDropdown.Value
    if selectedTool then
        local tool = Player.Backpack:FindFirstChild(selectedTool)
        if tool and Player.Character and Player.Character:FindFirstChild("Humanoid") then
            pcall(function()
                Player.Character.Humanoid:EquipTool(tool)
            end)
        end
    end
    isEquipping = false
end

addConnection(Player.CharacterAdded:Connect(function(character)
    character:WaitForChild("Humanoid")
    if ToolToggle.Value then
        task.wait(1)
        equipSelectedTool()
    end
end))

ToolToggle:OnChanged(function(value)
    if value then
        addConnection(RunService.Heartbeat:Connect(function()
            if ToolToggle.Value then
                equipSelectedTool()
            end
        end))
    else
        if Player.Character then
            local currentTool = Player.Character:FindFirstChildOfClass("Tool")
            if currentTool then
                currentTool.Parent = Player.Backpack
            end
        end
    end
end)

local function refreshTools()
    local tools = {}
    if Player and Player:FindFirstChild("Backpack") then
        for _, tool in ipairs(Player.Backpack:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(tools, tool.Name)
            end
        end
    end
    ToolDropdown:SetValues(tools)
    if #tools > 0 then
        ToolDropdown:SetValue(tools[1])
    end
end

Tabs.Main:AddButton({
    Title = "Refresh Tools",
    Callback = refreshTools
})

task.spawn(function()
    task.wait(2)
    refreshTools()
end)

Tabs.Main:AddSection("Auto Stats")
local StatDropdown = Tabs.Main:AddDropdown("StatDropdown", {
    Title = "Select Stat to Upgrade",
    Values = {"Strength", "Defense", "Sword", "Gun", "DevilFruit"},
    Multi = false,
    Default = "Strength",
    Callback = function(value) Settings.SelectedStat = value end
})

local lastStatUpdate = 0
Tabs.Main:AddToggle("AutoStatsToggle", {
    Title = "Auto Stats Selected",
    Default = false,
    Callback = function(value)
        Settings.AutoStats = value
        if value then
            addConnection(RunService.Heartbeat:Connect(function()
                if not Settings.AutoStats then return end
                
                -- Update every 0.5 seconds
                if os.clock() - lastStatUpdate >= 0.5 then
                    local statData = {
                        Defense = Settings.SelectedStat == "Defense" and 1 or 0,
                        Sword = Settings.SelectedStat == "Sword" and 1 or 0,
                        Gun = Settings.SelectedStat == "Gun" and 1 or 0,
                        Strength = Settings.SelectedStat == "Strength" and 1 or 0,
                        DevilFruit = Settings.SelectedStat == "DevilFruit" and 1 or 0
                    }
                    
                    safeFireRemote(StatsEvent, "UpgradeStat", statData)
                    lastStatUpdate = os.clock()
                end
            end))
        end
    end
})

-- Misc Tab
Tabs.Misc:AddSection("Teleports")
local islands = {}
local map = workspace:FindFirstChild("Map")
if map then
    for _, island in ipairs(map:GetChildren()) do
        if island:FindFirstChild("Base") then
            table.insert(islands, island.Name)
        end
    end
end

local IslandDropdown = Tabs.Misc:AddDropdown("IslandDropdown", {
    Title = "Select Island",
    Values = islands,
    Multi = false,
    Default = islands[1] or nil
})

Tabs.Misc:AddButton({
    Title = "Teleport to Island",
    Callback = function()
        local selectedIsland = IslandDropdown.Value
        if selectedIsland and map then
            local island = map:FindFirstChild(selectedIsland)
            if island then
                local basePart = island:FindFirstChild("Base") 
                    or island:FindFirstChild("Platform")
                    or island:FindFirstChildWhichIsA("BasePart")
                
                if basePart then
                    local targetPosition = basePart.Position + Vector3.new(0, 5, 0)
                    if Player.Character and Player.Character.PrimaryPart then
                        Player.Character:MoveTo(targetPosition)
                    end
                end
            end
        end
    end
})

Tabs.Misc:AddSection("Others")
local touchConnection = nil
local function fireTouch(part)
    if not part:IsA("BasePart") then return end
    
    for _, ti in ipairs(part:GetChildren()) do
        if ti:IsA("TouchTransmitter") then
            for _, myPart in ipairs(Player.Character:GetDescendants()) do
                if myPart:IsA("BasePart") then
                    firetouchinterest(myPart, part, 0)
                    task.wait()
                    firetouchinterest(myPart, part, 1)
                end
            end
        end
    end
end

Tabs.Misc:AddToggle("FireTouchToggle", {
    Title = "Auto Collect Chests and Fruits",
    Default = false,
    Callback = function(value)
        if value then
            if touchConnection then
                touchConnection:Disconnect()
            end
            touchConnection = workspace.DescendantAdded:Connect(fireTouch)
        elseif touchConnection then
            touchConnection:Disconnect()
            touchConnection = nil
        end
    end
})

local isStoringFruits = false
local function storeFruits()
    while isStoringFruits do
        safeFireRemote(ToolEvent, "StoreFruit")
        task.wait(0.5 + math.random() * 0.5) -- Random delay
    end
end

Tabs.Misc:AddToggle("AutoStoreToggle", {
    Title = "Auto Store Fruits",
    Default = false,
    Callback = function(value)
        isStoringFruits = value
        if value then
            task.spawn(storeFruits)
        end
    end
})

-- Settings
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:BuildInterfaceSection(Tabs.SettingsTab)
SaveManager:BuildConfigSection(Tabs.SettingsTab)

Window:SelectTab(1)

-- Cleanup on script termination
addConnection(game:GetService("UserInputService").WindowFocused:Connect(function()
    if not isStoringFruits then return end
    isStoringFruits = false
end))

addConnection(Player:GetPropertyChangedSignal("Character"):Connect(function()
    if touchConnection then
        touchConnection:Disconnect()
        touchConnection = nil
    end
end))

-- Final cleanup
game:GetService("Players").PlayerRemoving:Connect(disconnectAllConnections)
