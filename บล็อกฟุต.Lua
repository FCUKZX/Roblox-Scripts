if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- รอตัวละครกับข้อมูลผู้เล่นให้พร้อมก่อน
repeat task.wait() until LocalPlayer.Character and LocalPlayer:FindFirstChild("Data")

-- หา remote แบบไม่ error ถ้าหาไม่เจอ
local modules = ReplicatedStorage:WaitForChild("Modules", 10)
local netModules = modules and modules:WaitForChild("Net", 10)
local attackRemote = netModules and netModules:WaitForChild("RE/RegisterAttack", 10)
local hitRemote = netModules and netModules:WaitForChild("RE/RegisterHit", 10)
if not attackRemote or not hitRemote then
    warn("[AutoFarm] หา remote โจมตีไม่เจอ")
end

-- ตัวแปรเก็บข้อมูลเควสและมอนสเตอร์
local MON = ""
local QUEST_Description = ""
local QUESTPOS = CFrame.new()
local MONPOS = CFrame.new()
local QUEST_NAME = ""
local QUEST_NUMBER = 1
local SPAWNPOINT = ""

-- ตัวแปรของบอส (ว่างไว้ถ้าจุดฟาร์มนั้นไม่มีบอส)
local BOSS = ""
local QUEST_BOSS_Description = ""
local QUEST_BOSSPOS = CFrame.new()
local BOSSPOS = CFrame.new()
local QUEST_BOSS = 1
local CAN_BOSS = false -- เลเวลถึง BossLevel แล้วหรือยัง

-- ==========================================
-- 1. ตารางจุดฟาร์ม (เรียงจาก MinLevel ต่ำ -> สูง)
-- ==========================================
local FarmSpots = {
    {
        MinLevel = 1,
        MON = "Bandit",
        QUEST_Description = "Bandits",
        QUESTPOS = CFrame.new(1052.17, 14.74, 1554.03),
        MONPOS = CFrame.new(1170.05, 14.52, 1625.02),
        QUEST_NAME = "BanditQuest1",
        QUEST_NUMBER = 1,
        SPAWNPOINT = "Default",
    },
    {
        MinLevel = 15,
        MON = "Gorilla",
        QUEST_Description = "Gorillas",
        QUESTPOS = CFrame.new(-1682.09, 50.07, 176.33),
        MONPOS = CFrame.new(-1337.41, 13.90, -547.83),
        QUEST_NUMBER = 2,

        BossLevel = 20,
        BOSS = "The Gorilla King",
        QUEST_BOSS_Description = "Gorilla King",
        QUEST_BOSSPOS = CFrame.new(-1682.09, 50.07, 176.33),
        BOSSPOS = CFrame.new(-1273.50, 13.90, -520.82),
        QUEST_BOSS = 3,

        QUEST_NAME = "JungleQuest",
        SPAWNPOINT = "Jungle",
    },
}

local function checklevel()
    local levelData = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Level")
    if not levelData then return end

    local level = levelData.Value

    -- เริ่มที่จุดแรก แล้วทับด้วยจุดที่เลเวลถึง สุดท้ายได้จุดที่ MinLevel สูงสุดที่ถึง
    local chosen = FarmSpots[1]
    for _, spot in ipairs(FarmSpots) do
        if level >= spot.MinLevel then
            chosen = spot
        end
    end

    MON = chosen.MON
    QUEST_Description = chosen.QUEST_Description
    QUESTPOS = chosen.QUESTPOS
    MONPOS = chosen.MONPOS
    QUEST_NAME = chosen.QUEST_NAME
    QUEST_NUMBER = chosen.QUEST_NUMBER
    SPAWNPOINT = chosen.SPAWNPOINT

    -- ข้อมูลบอส (ถ้าจุดนี้ไม่มีบอส BOSS จะเป็น "" แล้วระบบบอสจะไม่ทำงาน)
    BOSS = chosen.BOSS or ""
    QUEST_BOSS_Description = chosen.QUEST_BOSS_Description or ""
    QUEST_BOSSPOS = chosen.QUEST_BOSSPOS or chosen.QUESTPOS
    BOSSPOS = chosen.BOSSPOS or chosen.MONPOS
    QUEST_BOSS = chosen.QUEST_BOSS or 1

    -- เลเวลต้องถึง BossLevel ถึงจะรับเควสบอสและตีบอสได้ (ไม่ใส่ = ไม่จำกัด)
    CAN_BOSS = level >= (chosen.BossLevel or 0)
end

-- ==========================================
-- 2. ฟังก์ชัน Fast Attack (ตีทุกตัวที่ชื่อตรงในระยะ)
-- ==========================================
local function fastAttack(targetName, maxDistance)
    if not attackRemote or not hitRemote then return end

    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end

    local playerPos = character.HumanoidRootPart.Position

    for _, enemy in ipairs(Workspace.Enemies:GetChildren()) do
        if enemy.Name == targetName then
            local humanoid = enemy:FindFirstChildOfClass("Humanoid")
            local hitPart = enemy:FindFirstChild("RightHand") or enemy:FindFirstChild("UpperTorso") or enemy:FindFirstChild("HumanoidRootPart")

            if humanoid and humanoid.Health > 0 and hitPart then
                local distance = (playerPos - hitPart.Position).Magnitude
                if distance <= maxDistance then
                    pcall(function()
                        attackRemote:FireServer(0.5)
                        hitRemote:FireServer(hitPart, {})
                    end)
                end
            end
        end
    end
end

-- ==========================================
-- 3. เช็คว่าบอสเกิดอยู่ไหม
-- ==========================================
local function findBoss()
    if BOSS == "" or not CAN_BOSS then return nil end
    local boss = Workspace.Enemies:FindFirstChild(BOSS)
    local hum = boss and boss:FindFirstChildOfClass("Humanoid")
    local root = boss and boss:FindFirstChild("HumanoidRootPart")
    if hum and hum.Health > 0 and root then
        return boss
    end
    return nil
end

-- ==========================================
-- 4. ระบบเคลื่อนที่แบบสมูท (ขยับทุกเฟรมตามเป้าหมายจริง)
-- ==========================================
local TELEPORT_RANGE = 30     -- ใกล้กว่านี้ = วาร์ปไปเลย
local MID_RANGE = 100          -- ระหว่าง TELEPORT_RANGE ถึงค่านี้ = บินด้วย MID_SPEED
local MID_SPEED = 300          -- ความเร็วตอนระยะกลาง
local FAR_SPEED = 250          -- ความเร็วตอนไกลกว่า MID_RANGE
local HOVER_HEIGHT = 10        -- ลอยเหนือมอนธรรมดากี่หน่วย
local BOSS_HOVER_HEIGHT = 15   -- ลอยเหนือบอสกี่หน่วย

local moveTarget = nil         -- {part=, offset=} ตามชิ้นส่วน หรือ {pos=} จุดตายตัว
local currentEnemy = nil       -- มอนที่กำลังล็อกอยู่

local function getTargetPosition()
    if not moveTarget then return nil end
    if moveTarget.part then
        if not moveTarget.part.Parent then return nil end
        return moveTarget.part.Position + moveTarget.offset
    end
    return moveTarget.pos
end

RunService.Heartbeat:Connect(function(dt)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local targetPos = getTargetPosition()
    if not root or not targetPos then return end

    local current = root.Position
    local offset = targetPos - current
    local dist = offset.Magnitude

    local newPos
    if dist <= TELEPORT_RANGE then
        -- ใกล้ (<= 50): วาร์ปไปที่เป้าเลย
        newPos = targetPos
    elseif dist <= MID_RANGE then
        -- ระยะกลาง (50-120): บินความเร็ว 300
        newPos = current + offset.Unit * math.min(dist, MID_SPEED * dt)
    else
        -- ไกล (> 120): บินความเร็ว 250
        newPos = current + offset.Unit * math.min(dist, FAR_SPEED * dt)
    end

    root.CFrame = CFrame.new(newPos) * root.CFrame.Rotation
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end)

-- ==========================================
-- ระบบถือของ
-- ==========================================
local function equipItemAutomatically(player, toolName)
	local character = player.Character
	local backpack = player and player:FindFirstChild("Backpack")
	
	if character and backpack then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local tool = backpack:FindFirstChild(toolName)
		
		if humanoid and tool then
			humanoid:EquipTool(tool) -- คำสั่งหลักในการบังคับถือ
		end
	end
end

-- ==========================================
-- 5. ลูปออโต้ฟาร์ม (ลูปนี้แค่ "ตัดสินใจ" ส่วนขยับให้ Heartbeat ทำ)
-- ==========================================
task.spawn(function()
    while task.wait() do
        local ok, err = pcall(function()
            local character = LocalPlayer.Character
            if not character or not character:FindFirstChild("HumanoidRootPart") then return end
            local rootPart = character.HumanoidRootPart

            checklevel()

            -- ป้องกันกรณีข้อมูลจุดฟาร์มยังว่าง (ไม่ให้บินไปจุด 0,0,0)
            if MONPOS == CFrame.new() or QUESTPOS == CFrame.new() then return end

            -- เลือกโหมด: ถ้าบอสเกิดอยู่ -> โหมดบอส ไม่งั้นฟาร์มปกติ
            local boss = findBoss()
            local bossMode = boss ~= nil

            local activeDesc      = bossMode and QUEST_BOSS_Description or QUEST_Description
            local activeQuestPos  = bossMode and QUEST_BOSSPOS or QUESTPOS
            local activeQuestNum  = bossMode and QUEST_BOSS or QUEST_NUMBER
            local targetName      = bossMode and BOSS or MON
            local hoverHeight     = bossMode and BOSS_HOVER_HEIGHT or HOVER_HEIGHT
            local attackRange     = bossMode and 30 or 20

            -- ถ้าเปลี่ยนโหมด ให้เลิกล็อกเป้าเดิม
            if currentEnemy and currentEnemy.Name ~= targetName then
                currentEnemy = nil
            end

            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            local trackedQuestFrame = playerGui and playerGui:FindFirstChild("TrackedQuestFrame")

            -- ยกเลิกเควสหากไม่ตรงกับโหมดปัจจุบัน (เช่น บอสเกิดแล้วต้องเปลี่ยนไปเควสบอส)
            if trackedQuestFrame then
                local descFrame = trackedQuestFrame:FindFirstChild("Frame") and trackedQuestFrame.Frame:FindFirstChild("description")
                if descFrame and not string.find(descFrame.Text, activeDesc) then
                    ReplicatedStorage.Remotes.CommF_:InvokeServer("AbandonQuest")
                end
            end

            -- กรณีที่ 1: ยังไม่มีเควส -> บินไปรับเควส
            if not playerGui:FindFirstChild("TrackedQuestFrame") then
                currentEnemy = nil
                moveTarget = { pos = activeQuestPos.Position }

                if (rootPart.Position - activeQuestPos.Position).Magnitude < 8 then
                    ReplicatedStorage.Remotes.CommF_:InvokeServer("StartQuest", QUEST_NAME, activeQuestNum)
                    task.wait(0.5)
                end

            -- กรณีที่ 2: มีเควสแล้ว -> ตามมอน/บอส
            else
                -- ถ้าเป้าที่ล็อกอยู่ตายหรือหายไป ค่อยหาตัวใหม่ (ไม่สลับเป้ากลางคัน)
                if currentEnemy then
                    local hum = currentEnemy:FindFirstChildOfClass("Humanoid")
                    if not currentEnemy.Parent or not hum or hum.Health <= 0 then
                        currentEnemy = nil
                    end
                end

                if not currentEnemy then
                    if bossMode then
                        currentEnemy = boss
                    else
                        local shortest = math.huge
                        for _, v in ipairs(Workspace.Enemies:GetChildren()) do
                            if v.Name == targetName then
                                local humanoid = v:FindFirstChildOfClass("Humanoid")
                                local enemyRoot = v:FindFirstChild("HumanoidRootPart")
                                if humanoid and humanoid.Health > 0 and enemyRoot then
                                    local dist = (rootPart.Position - enemyRoot.Position).Magnitude
                                    if dist < shortest then
                                        shortest = dist
                                        currentEnemy = v
                                    end
                                end
                            end
                        end
                    end
                end

                if currentEnemy then
                    local enemyRoot = currentEnemy:FindFirstChild("HumanoidRootPart")
                    if enemyRoot then
                        moveTarget = { part = enemyRoot, offset = Vector3.new(0, hoverHeight, 0) }
                        fastAttack(targetName, attackRange) -- เช็คระยะในตัวอยู่แล้ว
                    end
                else
                    -- ไม่มีเป้า -> ไปรอที่ MONPOS
                    moveTarget = { pos = MONPOS.Position + Vector3.new(0, HOVER_HEIGHT, 0) }
                end
            end
        end)
        if not ok then warn("[AutoFarm]", err) end
    end
end)

-- ==========================================
-- 6. ออโต้อัพ Stats
-- ==========================================
task.spawn(function()
    while task.wait(0.2) do
        pcall(function()
            local data = LocalPlayer.Data
            local stats = data.Stats
            local stat_points = data.Points

            if stat_points.Value >= 1 then
                local melee = stats.Melee.Level

                if melee.Value < 2300 then
                    local args = {"AddPoint", "Melee", 1}
                    ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack(args))
                end
            end
        end)
    end
end)

-- ==========================================
-- 7. ออโต้เปิดฮาคิ
-- ==========================================
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            if not LocalPlayer.Character:FindFirstChild("HasBuso") then
                local args = {"Buso"}
                game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack(args))
            end
        end)
    end
end)

-- ==========================================
-- 8. ออโต้ซื้อของ
-- ==========================================
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local data = LocalPlayer.Data
            local beli = data.Beli

            --ซื้อฮาคิ
            if not LocalPlayer:FindFirstChild("BusoColor") and beli.Value >= 25000 then
                local args = {"BuyHaki","Buso"}
                game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack(args))
            end
        end)
    end
end)

-- ==========================================
-- 9. ออโต้ถือของ
-- ==========================================
task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            local player = game:GetService("Players").LocalPlayer
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local backpack = player:FindFirstChild("Backpack")
            
            -- เช็กว่ามีกระเป๋าและตัวละครพร้อมใช้งานไหม (และตอนนี้ไม่ได้ถือของอะไรอยู่)
            if backpack and humanoid and not character:FindFirstChildOfClass("Tool") then
                for _, v in ipairs(backpack:GetChildren()) do
                    if v:IsA("Tool") and v.ToolTip == "Melee" then
                        humanoid:EquipTool(v)
                        break
                    end
                end
            end
        end)
    end
end)

-- ==========================================
-- 10. ออโต้สุ่มผล/เก็บผลเข้ากระเป๋า
-- ==========================================
local function getNil(name, class)
    for _, v in next, getnilinstances() do
        if v.ClassName == class and v.Name == name then
            return v
        end
    end
end

task.spawn(function()
    while task.wait(10) do
        pcall(function()
            local player = game:GetService("Players").LocalPlayer
            local character = player.Character
            local backpack = player:FindFirstChild("Backpack")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")

            -- [ส่วนที่ 1: ระบบออโต้สุ่มผล]
            local argsCheck = {[1] = {["BoxName"] = "ZiolesGacha", ["Context"] = "Check", ["SpokeNPC"] = "Blox Fruit Gacha"}}
            local success, response = pcall(function()
                return game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/GachaNetworkRF"):InvokeServer(unpack(argsCheck))
            end)
            
            if success and type(response) == "table" and response.Price then
                local beli = response.Price.Current
                local Fruit_price = response.Price.Value
                if beli >= Fruit_price and response.Level.Value >= 50 and response.Level.RequirementMet == true then
                    local argsPurchase = {[1] = {["Context"] = "Purchase", ["BoxName"] = "ZiolesGacha"}}
                    game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/GachaNetworkRF"):InvokeServer(unpack(argsPurchase))
                end
            end

            -- มีปัญหารอแก้ปรับปรุง [ส่วนที่ 2: ระบบออโต้เก็บผล (Store Fruit)]
            if backpack then
                for _, v in ipairs(backpack:GetChildren()) do
                    if v:IsA("Tool") and string.find(v.Name, "Fruit") then
                        local formatName = string.gsub(v.Name, " ", "-")
                        local toolObj = getNil(v.Name, "Tool") or v 
                        local argsStore = {
                            [1] = "StoreFruit",
                            [2] = formatName, 
                            [3] = toolObj
                        }
                        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack(argsStore))
                    end
                end
            end
        end)
    end
end)
