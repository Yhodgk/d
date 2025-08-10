-- Vox Seas Auto Farm Script
-- By shaka (discord.gg/t4aCqjX84m)

local _ENV = (getgenv or getrenv or getfenv)()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local DialogueEvent = ReplicatedStorage.BetweenSides.Remotes.Events.DialogueEvent
local CombatEvent = ReplicatedStorage.BetweenSides.Remotes.Events.CombatEvent
local ToolEvent = ReplicatedStorage.BetweenSides.Remotes.Events.ToolsEvent
local QuestsNpcs = workspace.IgnoreList.Int.NPCs.Quests
local Enemys = workspace.Playability.Enemys
local QuestsDecriptions = require(ReplicatedStorage.MainModules.Essentials.QuestDescriptions)
local EnemiesFolders = {}
local CFrameAngle = CFrame.Angles(math.rad(-90), 0, 0)

-- Environment setup
_ENV.OnFarm = false
_ENV.BringMob = false

-- Get current quest function
local function getCurrentQuest()
    local QuestsList = {}
    local CurrentQuest = nil
    local CurrentLevel = -1
    
    for _, QuestData in pairs(QuestsDecriptions) do
        if QuestData.Goal > 1 then
            table.insert(QuestsList, {
                Level = QuestData.MinLevel,
                Target = QuestData.Target,
                NpcName = QuestData.Npc,
                Id = QuestData.Id
            })
        end
    end
    
    table.sort(QuestsList, function(a, b)
        return a.Level > b.Level
    end)
    
    local function getPlayerLevel()
        local Level = 1
        local success, result = pcall(function()
            local mainUI = Player.PlayerGui:FindFirstChild("MainUI")
            if mainUI then
                local mainFrame = mainUI:FindFirstChild("MainFrame")
                if mainFrame then
                    local statsFrame = mainFrame:FindFirstChild("StastisticsFrame") or mainFrame:FindFirstChild("StatisticsFrame")
                    if statsFrame then
                        local levelBG = statsFrame:FindFirstChild("LevelBackground")
                        if levelBG then
                            local levelText = levelBG:FindFirstChild("Level")
                            if levelText and levelText.Text then
                                return tonumber(levelText.Text)
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
                    end
                end
            end
            return 1
        end)
        if success and result then
            Level = result
        end
        return Level
    end
    
    local playerLevel = getPlayerLevel()
    if playerLevel == CurrentLevel and CurrentQuest then
        return CurrentQuest
    end
    
    CurrentLevel = playerLevel
    for _, QuestData in ipairs(QuestsList) do
        if QuestData.Level <= CurrentLevel then
            CurrentQuest = QuestData
            return CurrentQuest
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
    dSpeed = 0.05,
    NoClip = false,
    AutoStats = false,
    SelectedStat = "Strength"
}

local EquippedTool = nil
local CurrentTarget = nil

-- Connection handler
local conepc = _ENV.cnn or {}
_ENV.cnn = conepc
for i = 1, #conepc do
    conepc[i]:Disconnect()
end
table.clear(conepc)

-- Character utility functions
local function isCharacterAlive(Character)
    if Character then
        local Humanoid = Character:FindFirstChildOfClass("Humanoid")
        return Humanoid and Humanoid.Health > 0
    end
    return false
end

local BodyVelocity = Instance.new("BodyVelocity")
BodyVelocity.Velocity = Vector3.zero
BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
BodyVelocity.P = 1000

if _ENV.tween_bodyvelocity then
    _ENV.tween_bodyvelocity:Destroy()
end
_ENV.tween_bodyvelocity = BodyVelocity

-- NoClip implementation
local CanCollideObjects = {}

local function trackCollidable(Object)
    if Object:IsA("BasePart") and Object.CanCollide then
        table.insert(CanCollideObjects, Object)
    end
end

local function removeCollidable(BasePart)
    local index = table.find(CanCollideObjects, BasePart)
    if index then
        table.remove(CanCollideObjects, index)
    end
end

local function setupCharacter(Character)
    table.clear(CanCollideObjects)
    for _, Object in Character:GetDescendants() do
        trackCollidable(Object)
    end
    Character.DescendantAdded:Connect(trackCollidable)
    Character.DescendantRemoving:Connect(removeCollidable)
end

table.insert(conepc, Player.CharacterAdded:Connect(setupCharacter))
if Player.Character then
    task.spawn(setupCharacter, Player.Character)
end

local function updateNoClip(Character)
    if _ENV.OnFarm then
        for i = 1, #CanCollideObjects do
            CanCollideObjects[i].CanCollide = false
        end
    elseif Character.PrimaryPart and not Character.PrimaryPart.CanCollide then
        for i = 1, #CanCollideObjects do
            CanCollideObjects[i].CanCollide = true
        end
    end
end

local function updateBodyVelocity(Character)
    local BasePart = Character:FindFirstChild("UpperTorso") or Character.PrimaryPart
    local Humanoid = Character:FindFirstChild("Humanoid")
    local BodyVelocity = _ENV.tween_bodyvelocity
    
    if _ENV.OnFarm and BasePart and Humanoid and Humanoid.Health > 0 then
        if BodyVelocity.Parent ~= BasePart then
            BodyVelocity.Parent = BasePart
        end
    elseif BodyVelocity.Parent then
        BodyVelocity.Parent = nil
    end
    
    if BodyVelocity.Velocity ~= Vector3.zero and (not Humanoid or not Humanoid.SeatPart or not _ENV.OnFarm) then
        BodyVelocity.Velocity = Vector3.zero
    end
end

table.insert(conepc, RunService.Stepped:Connect(function()
    local Character = Player.Character
    if isCharacterAlive(Character) then
        updateBodyVelocity(Character)
        updateNoClip(Character)
    end
end))

-- Tween management
local TweenCreator = {}
TweenCreator.__index = TweenCreator

local tweens = {}
local EasingStyle = Enum.EasingStyle.Linear

function TweenCreator.new(obj, time, prop, value)
    local self = setmetatable({}, TweenCreator)
    self.tween = TweenService:Create(obj, TweenInfo.new(time, EasingStyle), {
        [prop] = value
    })
    self.tween:Play()
    self.value = value
    self.object = obj
    if tweens[obj] then
        tweens[obj]:destroy()
    end
    tweens[obj] = self
    return self
end

function TweenCreator:destroy()
    self.tween:Pause()
    self.tween:Destroy()
    tweens[self.object] = nil
    setmetatable(self, nil)
end

function TweenCreator:stopTween(obj)
    if obj and tweens[obj] then
        tweens[obj]:destroy()
    end
end

local function stopTweenIfNeeded()
    if not BodyVelocity.Parent and isCharacterAlive(Player.Character) then
        TweenCreator:stopTween(Player.Character:FindFirstChild("HumanoidRootPart"))
    end
end

local lastCFrame = nil
local lastTeleport = 0

-- Teleport function
local function teleportToPosition(TargetCFrame)
    while not Player.Character or not isCharacterAlive(Player.Character) do
        task.wait(1)
        if not _ENV.OnFarm then
            return false
        end
    end
    
    if not Player.Character or not Player.Character.PrimaryPart then
        return false
    end
    
    if (tick() - lastTeleport) <= 0.3 and lastCFrame == TargetCFrame then
        return false
    end
    
    local Character = Player.Character
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    local PrimaryPart = Character.PrimaryPart
    
    if not Humanoid or not PrimaryPart then
        return false
    end
    
    if Humanoid.Sit then
        Humanoid.Sit = false
        task.wait(0.1)
        return false
    end
    
    lastTeleport = tick()
    lastCFrame = TargetCFrame
    _ENV.OnFarm = true
    
    local teleportPosition = TargetCFrame.Position
    local currentPosition = PrimaryPart.Position
    local Distance = (currentPosition - teleportPosition).Magnitude
    
    if Distance < 20 then
        PrimaryPart.CFrame = TargetCFrame
        TweenCreator:stopTween(PrimaryPart)
        return true
    end
    
    TweenCreator:stopTween(PrimaryPart)
    local tween = TweenCreator.new(PrimaryPart, Distance / Settings.TweenSpeed, "CFrame", TargetCFrame)
    
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not isCharacterAlive(Character) or not _ENV.OnFarm then
            TweenCreator:stopTween(PrimaryPart)
            if connection then
                connection:Disconnect()
            end
        end
    end)
    
    coroutine.wrap(function()
        while tween.tween.PlaybackState == Enum.PlaybackState.Playing do
            task.wait()
        end
        if connection then
            connection:Disconnect()
        end
    end)()
    
    return true
end

table.insert(conepc, BodyVelocity:GetPropertyChangedSignal("Parent"):Connect(stopTweenIfNeeded))

-- Attack functions
local function attackWithTool()
    if not isCharacterAlive(Player.Character) then
        return
    end
    
    local Tool = Player.Character:FindFirstChildOfClass("Tool")
    if not Tool then
        return
    end
    
    pcall(function()
        Tool:Activate()
        local Handle = Tool:FindFirstChild("Handle")
        if Handle then
            if Handle:FindFirstChild("Cooldown") then
                Handle.Cooldown.Value = 0
            end
            if Handle:FindFirstChild("AttackCooldown") then
                Handle.AttackCooldown.Value = 0
            end
            if Handle:FindFirstChild("Debounce") then
                Handle.Debounce.Value = false
            end
            local Sound = Handle:FindFirstChildOfClass("Sound")
            if Sound then
                Sound:Play()
            end
        end
        ToolEvent:FireServer("Effects", 1)
        ToolEvent:FireServer("Activate", 1)
        
        if Settings.ClickV2 then
            for i = 1, 3 do
                Tool:Activate()
                task.wait(0.01)
            end
        end
    end)
end

local function dealDamage(Enemies)
    CombatEvent:FireServer("DealDamage", {
        CallTime = workspace:GetServerTimeNow(),
        DelayTime = 0,
        Combo = 1,
        Results = Enemies,
        Damage = math.random(50, 150),
        CriticalHit = math.random(1, 10) <= 3
    })
end

-- Enemy utilities
local function getEnemiesInFolder(Folder, EnemyName)
    local foundEnemies = {}
    for _, Enemy in pairs(Folder:GetChildren()) do
        if Enemy and Enemy.Parent then
            local enemyName = Enemy:GetAttribute("OriginalName") or Enemy:GetAttribute("EnemyName") or Enemy.Name
            if enemyName == EnemyName or string.find(enemyName, EnemyName) then
                local Humanoid = Enemy:FindFirstChild("Humanoid")
                local HumanoidRootPart = Enemy:FindFirstChild("HumanoidRootPart")
                if Humanoid and HumanoidRootPart and Humanoid.Health > 0 then
                    local isReady = true
                    if Enemy:GetAttribute("Respawned") ~= nil then
                        isReady = Enemy:GetAttribute("Respawned")
                    end
                    if Enemy:GetAttribute("Ready") ~= nil then
                        isReady = isReady and Enemy:GetAttribute("Ready")
                    end
                    if isReady then
                        table.insert(foundEnemies, Enemy)
                    end
                end
            end
        end
    end
    return foundEnemies
end

local function getAllEnemies(EnemyName)
    local AllEnemies = {}
    local EnemyFolder = EnemiesFolders[EnemyName]
    
    if EnemyFolder and EnemyFolder.Parent then
        local enemies = getEnemiesInFolder(EnemyFolder, EnemyName)
        for _, enemy in ipairs(enemies) do
            table.insert(AllEnemies, enemy)
        end
    else
        if Enemys and Enemys.Parent then
            local Islands = Enemys:GetChildren()
            for i = 1, #Islands do
                local Island = Islands[i]
                if Island and Island.Parent then
                    local enemies = getEnemiesInFolder(Island, EnemyName)
                    if #enemies > 0 then
                        EnemiesFolders[EnemyName] = Island
                        for _, enemy in ipairs(enemies) do
                            table.insert(AllEnemies, enemy)
                        end
                    end
                end
            end
        end
    end
    return AllEnemies
end

local function getClosestEnemy(EnemyName)
    local AllEnemies = getAllEnemies(EnemyName)
    if #AllEnemies == 0 then
        return nil
    end
    
    local ClosestEnemy = nil
    local ShortestDistance = math.huge
    
    for i, Enemy in ipairs(AllEnemies) do
        if Enemy and Enemy.Parent then
            local RootPart = Enemy:FindFirstChild("HumanoidRootPart")
            local Humanoid = Enemy:FindFirstChild("Humanoid")
            if RootPart and Humanoid and Humanoid.Health > 0 then
                local Distance = Player:DistanceFromCharacter(RootPart.Position)
                if Distance < ShortestDistance then
                    ShortestDistance = Distance
                    ClosestEnemy = Enemy
                end
            end
        end
    end
    
    return ClosestEnemy
end

local function bringEnemies(EnemyName, TargetPosition)
    if not _ENV.BringMob then
        return 0
    end
    
    local AllEnemies = getAllEnemies(EnemyName)
    local BroughtCount = 0
    
    if #AllEnemies == 0 then
        return 0
    end
    
    for i, Enemy in ipairs(AllEnemies) do
        if Enemy and Enemy.Parent then
            local RootPart = Enemy:FindFirstChild("HumanoidRootPart")
            local Humanoid = Enemy:FindFirstChild("Humanoid")
            if RootPart and Humanoid and Humanoid.Health > 0 then
                if not RootPart:FindFirstChild("BodyVelocity") then
                    local BV = Instance.new("BodyVelocity")
                    BV.Velocity = Vector3.zero
                    BV.MaxForce = Vector3.one * math.huge
                    BV.P = 1000
                    BV.Parent = RootPart
                end
                RootPart.CanCollide = false
                RootPart.CFrame = TargetPosition
                BroughtCount = BroughtCount + 1
            end
        end
    end
    
    if BroughtCount > 0 then
        pcall(sethiddenproperty, Player, "SimulationRadius", math.huge)
    end
    
    return BroughtCount
end

-- Tool management
local function isSelectedTool(Tool)
    return Tool:GetAttribute(Settings.SelectedTool)
end

local function equipCombatTool(Activate)
    if not isCharacterAlive(Player.Character) then
        return
    end
    
    if EquippedTool and isSelectedTool(EquippedTool) then
        if Activate then
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
    
    local Equipped = Player.Character:FindFirstChildOfClass("Tool")
    if Equipped and isSelectedTool(Equipped) then
        EquippedTool = Equipped
        return
    end
    
    for _, Tool in Player.Backpack:GetChildren() do
        if Tool:IsA("Tool") and isSelectedTool(Tool) then
            EquippedTool = Tool
            Player.Character.Humanoid:EquipTool(Tool)
            return
        end
    end
end

-- Quest utilities
local function isQuestActive(EnemyName)
    local success, result = pcall(function()
        local QuestFrame = Player.PlayerGui.MainUI.MainFrame.CurrentQuest
        if not QuestFrame.Visible then
            return false
        end
        
        local questText = nil
        local goalElement = QuestFrame:FindFirstChild("Goal")
        if goalElement and goalElement.Text then
            questText = goalElement.Text
        end
        
        if not questText then
            for _, child in pairs(QuestFrame:GetDescendants()) do
                if child:IsA("TextLabel") and child.Text and child.Text ~= "" then
                    if string.find(child.Text, "Defeat") or string.find(child.Text, "/") then
                        questText = child.Text
                        break
                    end
                end
            end
        end
        
        if questText then
            local hasTargetQuest = string.find(questText, EnemyName)
            return hasTargetQuest ~= nil
        else
            return false
        end
    end)
    
    if success then
        return result
    else
        return false
    end
end

local function acceptQuest(QuestName, QuestId)
    local Npc = QuestsNpcs:FindFirstChild(QuestName, true)
    if not Npc then return end
    
    local RootPart = Npc.PrimaryPart or Npc:FindFirstChild("HumanoidRootPart")
    if RootPart then
        DialogueEvent:FireServer("Quests", {
            ["NpcName"] = QuestName,
            ["QuestName"] = QuestId
        })
        teleportToPosition(RootPart.CFrame * CFrame.new(0, 0, 15))
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
    Disc = Window:AddTab({
        Title = "We",
        Icon = "rbxassetid://5013032505"
    }),
    Main = Window:AddTab({
        Title = "Main",
        Icon = "rbxassetid://131580529707278"
    }),
    Misc = Window:AddTab({
        Title = "Misc",
        Icon = "rbxassetid://139867952423882"
    }),
    SettingsTab = Window:AddTab({
        Title = "Settings",
        Icon = "rbxassetid://113400358595552"
    })
}

Tabs.Disc:AddSection("About We")
Tabs.Disc:AddButton({
    Title = "DISCORD SERVER",
    Description = "Be notified of updates, click to copy",
    Callback = function()
        setclipboard("https://discord.gg/t4aCqjX84m")
    end
})
Tabs.Disc:AddButton({
    Title = "YOUTUBE SHAKA - ROBLOX SCRIPTS",
    Description = "Click to copy link",
    Callback = function()
        setclipboard("https://www.youtube.com/@shakascripts")
    end
})

-- Main Tab
Tabs.Main:AddSection("Auto Farm")
Tabs.Main:AddToggle("AutoFarm", {
    Title = "Auto Farm With Quests",
    Default = false,
    Callback = function(Value)
        _ENV.OnFarm = Value
        if Value then
            task.spawn(function()
                while task.wait(Settings.dSpeed) and _ENV.OnFarm do
                    if not isCharacterAlive(Player.Character) then
                        repeat task.wait(0.5) until isCharacterAlive(Player.Character)
                        task.wait(0.2)
                        continue
                    end
                    
                    local CurrentQuest = getCurrentQuest()
                    if not CurrentQuest then
                        continue
                    end
                    
                    if not isQuestActive(CurrentQuest.Target) then
                        acceptQuest(CurrentQuest.NpcName, CurrentQuest.Id)
                        continue
                    end
                    
                    local Enemy = getClosestEnemy(CurrentQuest.Target)
                    if not Enemy then
                        continue
                    end
                    
                    CurrentTarget = Enemy
                    local HumanoidRootPart = Enemy:FindFirstChild("HumanoidRootPart")
                    local Humanoid = Enemy:FindFirstChild("Humanoid")
                    
                    if HumanoidRootPart and Humanoid and Humanoid.Health > 0 then
                        if _ENV.BringMob then
                            bringEnemies(CurrentQuest.Target, HumanoidRootPart.CFrame)
                        end
                        
                        local targetCFrame = HumanoidRootPart.CFrame * CFrame.new(0, 7.5, 0) * CFrameAngle
                        if not teleportToPosition(targetCFrame) then
                            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                                Player.Character.HumanoidRootPart.CFrame = targetCFrame
                            end
                        end
                        
                        task.wait(0)
                        equipCombatTool(true)
                        
                        local AllQuestEnemies = getAllEnemies(CurrentQuest.Target)
                        if #AllQuestEnemies > 0 then
                            dealDamage(AllQuestEnemies)
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
    Callback = function(Value)
        _ENV.BringMob = Value
    end
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

local equipping = false
local function equipSelectedTool()
    if not ToolToggle.Value then return end
    if equipping then return end
    
    equipping = true
    local selectedTool = ToolDropdown.Value
    if selectedTool then
        local tool = Player.Backpack:FindFirstChild(selectedTool)
        if tool and Player.Character and Player.Character:FindFirstChild("Humanoid") then
            pcall(function()
                Player.Character.Humanoid:EquipTool(tool)
            end)
        end
    end
    equipping = false
end

Player.CharacterAdded:Connect(function(character)
    character:WaitForChild("Humanoid")
    if ToolToggle.Value then
        task.wait(1)
        equipSelectedTool()
    end
end)

ToolToggle:OnChanged(function(Value)
    if Value then
        coroutine.wrap(function()
            while ToolToggle.Value do
                equipSelectedTool()
                task.wait(0.1)
            end
        end)()
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

local RefreshButton = Tabs.Main:AddButton({
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
    Callback = function(Value)
        Settings.SelectedStat = Value
    end
})

Tabs.Main:AddToggle("AutoStatsToggle", {
    Title = "Auto Stats Selected",
    Default = false,
    Callback = function(Value)
        Settings.AutoStats = Value
        if Value then
            coroutine.wrap(function()
                while Settings.AutoStats do
                    local remote = ReplicatedStorage.BetweenSides.Remotes.Events.StatsEvent
                    if remote then
                        local args = {
                            "UpgradeStat",
                            {
                                Defense = Settings.SelectedStat == "Defense" and 1 or 0,
                                Sword = Settings.SelectedStat == "Sword" and 1 or 0,
                                Gun = Settings.SelectedStat == "Gun" and 1 or 0,
                                Strength = Settings.SelectedStat == "Strength" and 1 or 0,
                                DevilFruit = Settings.SelectedStat == "DevilFruit" and 1 or 0
                            }
                        }
                        pcall(function()
                            remote:FireServer(unpack(args))
                        end)
                    end
                    task.wait(0.1)
                end
            end)()
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
            if island and island:FindFirstChild("Base") then
                local base = island.Base
                local targetPosition = base:FindFirstChild("HumanoidRootPart") and base.HumanoidRootPart.Position or base.WorldPivot.Position + Vector3.new(0, 5, 0)
                if Player.Character and Player.Character.PrimaryPart then
                    Player.Character:MoveTo(targetPosition)
                end
            end
        end
    end
})

Tabs.Misc:AddSection("Others")
local char = Player.Character or Player.CharacterAdded:Wait()
local fireTouchEnabled = false

local function fireTouch(part)
    if not fireTouchEnabled or not part:IsA("BasePart") then return end
    for _, ti in ipairs(part:GetChildren()) do
        if ti:IsA("TouchTransmitter") then
            for _, myPart in ipairs(char:GetDescendants()) do
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
    Title = "Auto Chest And Fruit Spawned",
    Default = false,
    Callback = function(value)
        fireTouchEnabled = value
        if value then
            for _, v in ipairs(workspace:GetDescendants()) do
                fireTouch(v)
            end
            workspace.DescendantAdded:Connect(fireTouch)
        else
            workspace.DescendantAdded:Disconnect()
        end
    end
})

local isRunning = false
local function storeFruit()
    while isRunning do
        local fruitArgs = {"StoreFruit"}
        game:GetService("ReplicatedStorage"):WaitForChild("BetweenSides"):WaitForChild("Remotes"):WaitForChild("Events"):WaitForChild("ToolsEvent"):FireServer(unpack(fruitArgs))
        task.wait(0.25)
    end
end

Tabs.Misc:AddToggle("AutoStoreToggle", {
    Title = "Auto Store Fruits",
    Default = false,
    Callback = function(value)
        isRunning = value
        if value then
            coroutine.wrap(storeFruit)()
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
