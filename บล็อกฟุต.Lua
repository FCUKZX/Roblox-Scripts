-- ============================================================
--  AUTO FARM HUB
--  ตัวควบคุมหลัก + ฟังก์ชันสำเร็จรูป
--
--  วิธีควบคุมระหว่างรัน (พิมพ์ใน executor):
--    _G.AutoConfig.Farm = false        -- ปิดฟาร์ม
--    _G.AutoHub.Disable("Gacha")       -- ปิดระบบสุ่มผล
--    _G.AutoHub.Enable("Gacha")        -- เปิดกลับ
--    _G.AutoHub.Toggle("Boss")         -- สลับเปิด/ปิด
--    _G.AutoHub.Pause() / Resume()     -- พักทุกระบบ / เริ่มต่อ
--    _G.AutoHub.Status()               -- ดูสถานะทุกระบบ
--    _G.AutoHub.Stop()                 -- หยุดทั้งหมด
--    _G.AutoHub.Util.StoreAllFruits()  -- เรียกฟังก์ชันสำเร็จรูปเองได้
-- ============================================================
if not game:IsLoaded() then game.Loaded:Wait() end

-- กันรันซ้ำ: ถ้ารันสคริปต์นี้อีกรอบ ให้หยุดตัวเก่าก่อน
if _G.AutoHub and type(_G.AutoHub.Stop) == "function" then
    pcall(_G.AutoHub.Stop)
end

if game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("TeamSelection") then
    local args = {"SetTeam2","Pirates"}
    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack(args))
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
repeat task.wait() until LocalPlayer.Character and LocalPlayer:FindFirstChild("Data")

-- ============================================================
-- 1. CONFIG (_G.AutoConfig) แก้ค่าสดระหว่างรันได้ทันที
--    ตั้ง _G.AutoConfig = {...} ก่อนรันสคริปต์ก็ได้ ค่าที่ไม่ใส่จะใช้ค่าเริ่มต้น
-- ============================================================
local Defaults = {
    -- เปิด/ปิดแต่ละระบบ (ชื่อตรงกับชื่อ Task)
    Farm = true,
    Boss = true,
    Stats = true,
    Haki = true,
    BuyHaki = true,
    Equip = true,
    Gacha = true,
    StoreFruit = true,

    -- การเคลื่อนที่
    TeleportRange = 30,     -- ใกล้กว่านี้ = วาร์ป
    MidRange = 100,         -- TeleportRange..MidRange = บินด้วย MidSpeed
    MidSpeed = 300,
    FarSpeed = 250,         -- ไกลกว่า MidRange
    HoverHeight = 10,       -- ลอยเหนือมอนธรรมดา
    BossHoverHeight = 15,   -- ลอยเหนือบอส

    -- การโจมตี
    AttackRange = 20,
    BossAttackRange = 30,

    -- อัพ Stats
    StatName = "Melee",
    StatMax = 2300,

    -- ถืออาวุธ (ค่า ToolTip ของอาวุธ)
    EquipTip = "Melee",

    -- ซื้อของ
    HakiPrice = 25000,
    GachaMinLevel = 50,

    -- ชื่อผลที่ไม่เข้ากฎ "X Fruit" -> "X-X" ใส่ที่นี่ เช่น ["Some Fruit"] = "Real-Name"
    FruitNameOverrides = {},

    -- ความถี่ที่ตัวควบคุมหลักเช็คสถานะ (วินาที)
    ControllerInterval = 0.25,
}

_G.AutoConfig = _G.AutoConfig or {}
for k, v in pairs(Defaults) do
    if _G.AutoConfig[k] == nil then
        _G.AutoConfig[k] = v
    end
end
local Cfg = _G.AutoConfig

-- ============================================================
-- 2. HUB
-- ============================================================
local Hub = {
    Running = true,
    Paused = false,
    Tasks = {},
    State = {},
    Move = { target = nil },
}
_G.AutoHub = Hub
local State = Hub.State

-- remote โจมตี
local modules = ReplicatedStorage:WaitForChild("Modules", 10)
local netModules = modules and modules:WaitForChild("Net", 10)
local attackRemote = netModules and netModules:WaitForChild("RE/RegisterAttack", 10)
local hitRemote = netModules and netModules:WaitForChild("RE/RegisterHit", 10)
if not attackRemote or not hitRemote then
    warn("[AutoHub] หา remote โจมตีไม่เจอ")
end

-- ============================================================
-- 3. ฟังก์ชันสำเร็จรูป (Hub.Util) เอาไปเรียกใช้เองได้
-- ============================================================
local U = {}
Hub.Util = U

function U.Root()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

function U.Humanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

function U.IsAlive()
    local h = U.Humanoid()
    return h ~= nil and h.Health > 0 and U.Root() ~= nil
end

-- อ่านค่า Value ของลูกแบบปลอดภัย
function U.Value(parent, name)
    local o = parent and parent:FindFirstChild(name)
    return o and o.Value
end

function U.Level()
    return U.Value(LocalPlayer:FindFirstChild("Data"), "Level") or 0
end

function U.Beli()
    return U.Value(LocalPlayer:FindFirstChild("Data"), "Beli") or 0
end

-- เรียก CommF_ แบบปลอดภัย คืนค่า ok, result
function U.CommF(...)
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local commF = remotes and remotes:FindFirstChild("CommF_")
    if not commF then return false, "หา CommF_ ไม่เจอ" end
    return pcall(commF.InvokeServer, commF, ...)
end

-- หา instance ที่อยู่ใน nil (ใช้กับ StoreFruit)
function U.GetNil(name, class)
    if not getnilinstances then return nil end
    for _, v in next, getnilinstances() do
        if v.ClassName == class and v.Name == name then
            return v
        end
    end
    return nil
end

-- ---------- เควส ----------
function U.QuestFrame()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    return gui and gui:FindFirstChild("TrackedQuestFrame")
end

function U.QuestText()
    local frame = U.QuestFrame()
    local inner = frame and frame:FindFirstChild("Frame")
    local desc = inner and inner:FindFirstChild("description")
    return desc and desc.Text
end

-- ---------- มอนสเตอร์ ----------
function U.FindAliveEnemy(name)
    local enemies = Workspace:FindFirstChild("Enemies")
    local m = enemies and enemies:FindFirstChild(name)
    local hum = m and m:FindFirstChildOfClass("Humanoid")
    local root = m and m:FindFirstChild("HumanoidRootPart")
    if hum and hum.Health > 0 and root then
        return m
    end
    return nil
end

function U.NearestEnemy(name, fromPos)
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return nil end

    local best, bestDist = nil, math.huge
    for _, v in ipairs(enemies:GetChildren()) do
        if v.Name == name then
            local hum = v:FindFirstChildOfClass("Humanoid")
            local root = v:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and root then
                local d = (fromPos - root.Position).Magnitude
                if d < bestDist then
                    best, bestDist = v, d
                end
            end
        end
    end
    return best
end

-- ตีทุกตัวที่ชื่อตรงและอยู่ในระยะ
function U.Attack(name, maxDistance)
    if not attackRemote or not hitRemote then return end
    local root = U.Root()
    local enemies = Workspace:FindFirstChild("Enemies")
    if not root or not enemies then return end

    for _, enemy in ipairs(enemies:GetChildren()) do
        if enemy.Name == name then
            local hum = enemy:FindFirstChildOfClass("Humanoid")
            local hitPart = enemy:FindFirstChild("RightHand")
                or enemy:FindFirstChild("UpperTorso")
                or enemy:FindFirstChild("HumanoidRootPart")

            if hum and hum.Health > 0 and hitPart then
                if (root.Position - hitPart.Position).Magnitude <= maxDistance then
                    pcall(function()
                        attackRemote:FireServer(0.5)
                        hitRemote:FireServer(hitPart, {})
                    end)
                end
            end
        end
    end
end

-- ---------- ถือของ ----------
function U.Equip(toolTip)
    local hum = U.Humanoid()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not hum or not bp then return false end

    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and t.ToolTip == toolTip then
            hum:EquipTool(t)
            return true
        end
    end
    return false
end

-- ---------- Stats ----------
function U.AddPoint(statName, amount)
    return U.CommF("AddPoint", statName, amount or 1)
end

-- ---------- ผลไม้ ----------
function U.GetFruitTools()
    local list = {}
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and string.find(t.Name, "Fruit") then
                list[#list + 1] = t
            end
        end
    end
    return list
end

-- "Sand Fruit" -> "Sand-Sand"
function U.FruitInternalName(toolName)
    local override = Cfg.FruitNameOverrides and Cfg.FruitNameOverrides[toolName]
    if override then return override end

    local base = string.gsub(toolName, "%s*Fruit$", "")
    base = string.gsub(base, " ", "-")
    return base .. "-" .. base
end

-- เก็บผล 1 ลูก คืน ok, result, ชื่อที่ส่งไป
function U.StoreFruit(tool)
    local internal = U.FruitInternalName(tool.Name)
    local target = U.GetNil(tool.Name, "Tool") or tool
    local ok, result = U.CommF("StoreFruit", internal, target)
    return ok, result, internal
end

function U.StoreAllFruits()
    for _, tool in ipairs(U.GetFruitTools()) do
        local ok, result, internal = U.StoreFruit(tool)
        print("[StoreFruit]", tool.Name, "->", internal, ok, result)
        task.wait(0.3)
    end
end

-- ============================================================
-- 4. ตารางจุดฟาร์ม (เรียงจาก MinLevel ต่ำ -> สูง)
-- ============================================================
Hub.FarmSpots = {
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

-- เลือกจุดที่ MinLevel สูงสุดที่เลเวลถึง (เกินทุกจุด = จุดสุดท้าย)
function Hub.GetSpot(level)
    local chosen = Hub.FarmSpots[1]
    for _, spot in ipairs(Hub.FarmSpots) do
        if level >= spot.MinLevel then
            chosen = spot
        end
    end
    return chosen
end

-- ============================================================
-- 5. ระบบเคลื่อนที่ (Heartbeat) วาร์ป / บิน 300 / บิน 250
-- ============================================================
function Hub.MoveTo(pos)
    Hub.Move.target = { pos = pos }
end

function Hub.Follow(part, offset)
    Hub.Move.target = { part = part, offset = offset }
end

function Hub.StopMove()
    Hub.Move.target = nil
end

local function getTargetPosition()
    local t = Hub.Move.target
    if not t then return nil end
    if t.part then
        if not t.part.Parent then return nil end
        return t.part.Position + t.offset
    end
    return t.pos
end

local heartbeatConn = RunService.Heartbeat:Connect(function(dt)
    if not Hub.Running then return end

    local root = U.Root()
    local targetPos = getTargetPosition()
    if not root or not targetPos then return end

    local current = root.Position
    local offset = targetPos - current
    local dist = offset.Magnitude

    local newPos
    if dist <= Cfg.TeleportRange then
        newPos = targetPos
    elseif dist <= Cfg.MidRange then
        newPos = current + offset.Unit * math.min(dist, Cfg.MidSpeed * dt)
    else
        newPos = current + offset.Unit * math.min(dist, Cfg.FarSpeed * dt)
    end

    root.CFrame = CFrame.new(newPos) * root.CFrame.Rotation
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end)

-- ============================================================
-- 6. ตัวควบคุมหลัก + ระบบ Task
--    Task แต่ละตัวมี when(state) บอกว่า "ตอนนี้ควรทำงานไหม"
--    ตัวควบคุมหลักจะเช็คทุก ControllerInterval แล้วเปิด/ปิด Task ให้เอง
-- ============================================================
function Hub.AddTask(def)
    local t = {
        name = def.name,
        flag = def.flag or def.name,
        interval = def.interval or 0.1,
        when = def.when,
        run = def.run,
        onDisable = def.onDisable,
        active = false,
        errStreak = 0,
        totalErrors = 0,
        suspendedUntil = 0,
    }
    Hub.Tasks[t.name] = t

    task.spawn(function()
        while Hub.Running do
            if t.active then
                local ok, err = pcall(t.run, State, Cfg)
                if ok then
                    t.errStreak = 0
                else
                    t.errStreak = t.errStreak + 1
                    t.totalErrors = t.totalErrors + 1
                    if t.errStreak == 1 then
                        warn("[AutoHub] " .. t.name .. " error:", err)
                    end
                    -- error ติดกัน 5 ครั้ง -> พักงาน 10 วินาที กันสแปม
                    if t.errStreak >= 5 then
                        t.suspendedUntil = os.clock() + 10
                        t.errStreak = 0
                        warn("[AutoHub] " .. t.name .. " พักงาน 10 วิ เพราะ error ติดกัน")
                    end
                end
                task.wait(t.interval)
            else
                task.wait(0.2)
            end
        end
    end)
end

local function refreshState()
    local char = LocalPlayer.Character
    local data = LocalPlayer:FindFirstChild("Data")
    local stats = data and data:FindFirstChild("Stats")
    local stat = stats and stats:FindFirstChild(Cfg.StatName)

    State.alive = U.IsAlive()
    State.ready = data ~= nil
    State.level = U.Value(data, "Level") or 0
    State.beli = U.Value(data, "Beli") or 0
    State.points = U.Value(data, "Points") or 0
    State.statLevel = (stat and U.Value(stat, "Level")) or math.huge
    State.holdingTool = char ~= nil and char:FindFirstChildOfClass("Tool") ~= nil
    State.hasBuso = char ~= nil and char:FindFirstChild("HasBuso") ~= nil
    State.ownsHaki = LocalPlayer:FindFirstChild("BusoColor") ~= nil
    State.fruitCount = #U.GetFruitTools()
end

task.spawn(function()
    while Hub.Running do
        pcall(refreshState)

        for _, t in pairs(Hub.Tasks) do
            local want = (not Hub.Paused)
                and Cfg[t.flag] == true
                and os.clock() >= t.suspendedUntil

            if want then
                local ok, res = pcall(t.when, State, Cfg)
                want = ok and res == true
            end

            if t.active and not want and t.onDisable then
                pcall(t.onDisable)
            end
            t.active = want
        end

        task.wait(Cfg.ControllerInterval)
    end
end)

-- ============================================================
-- 7. TASKS
-- ============================================================

-- ---------- ออโต้ฟาร์ม + บอส ----------
local currentTarget = nil -- มอน/บอสที่กำลังล็อกอยู่

local function farmStep(s)
    local root = U.Root()
    if not root then return end

    local spot = Hub.GetSpot(s.level)
    if not spot then return end

    -- บอสเกิดและเลเวลถึง BossLevel -> โหมดบอส
    local boss = nil
    if Cfg.Boss and spot.BOSS and s.level >= (spot.BossLevel or 0) then
        boss = U.FindAliveEnemy(spot.BOSS)
    end
    local bossMode = boss ~= nil

    local desc = bossMode and (spot.QUEST_BOSS_Description or "") or spot.QUEST_Description
    local questPos = bossMode and (spot.QUEST_BOSSPOS or spot.QUESTPOS) or spot.QUESTPOS
    local questNum = bossMode and (spot.QUEST_BOSS or 1) or spot.QUEST_NUMBER
    local targetName = bossMode and spot.BOSS or spot.MON
    local hover = bossMode and Cfg.BossHoverHeight or Cfg.HoverHeight
    local range = bossMode and Cfg.BossAttackRange or Cfg.AttackRange

    -- เปลี่ยนโหมด -> เลิกล็อกเป้าเดิม
    if currentTarget and currentTarget.Name ~= targetName then
        currentTarget = nil
    end

    -- เควสที่ถืออยู่ไม่ตรงโหมด -> ยกเลิก
    local questText = U.QuestText()
    if questText and not string.find(questText, desc, 1, true) then
        U.CommF("AbandonQuest")
    end

    -- ยังไม่มีเควส -> บินไปรับ
    if not U.QuestFrame() then
        currentTarget = nil
        Hub.MoveTo(questPos.Position)

        if (root.Position - questPos.Position).Magnitude < 8 then
            U.CommF("StartQuest", spot.QUEST_NAME, questNum)
            task.wait(0.5)
        end
        return
    end

    -- เป้าที่ล็อกอยู่ตายหรือหายไป -> หาใหม่
    if currentTarget then
        local hum = currentTarget:FindFirstChildOfClass("Humanoid")
        if not currentTarget.Parent or not hum or hum.Health <= 0 then
            currentTarget = nil
        end
    end

    if not currentTarget then
        if bossMode then
            currentTarget = boss
        else
            currentTarget = U.NearestEnemy(targetName, root.Position)
        end
    end

    if currentTarget then
        local enemyRoot = currentTarget:FindFirstChild("HumanoidRootPart")
        if enemyRoot then
            Hub.Follow(enemyRoot, Vector3.new(0, hover, 0))
            U.Attack(targetName, range)
        end
    else
        -- ไม่มีเป้า -> ไปรอที่ MONPOS
        Hub.MoveTo(spot.MONPOS.Position + Vector3.new(0, Cfg.HoverHeight, 0))
    end
end

Hub.AddTask({
    name = "Farm",
    interval = 0, -- ทุกเฟรม
    when = function(s)
        return s.alive and s.ready and #Hub.FarmSpots > 0
    end,
    run = farmStep,
    onDisable = function()
        currentTarget = nil
        Hub.StopMove()
    end,
})

-- ---------- ออโต้อัพ Stats (ทำงานเมื่อมีแต้มและยังไม่ถึงเพดาน) ----------
Hub.AddTask({
    name = "Stats",
    interval = 0.2,
    when = function(s)
        return s.alive and s.points >= 1 and s.statLevel < Cfg.StatMax
    end,
    run = function()
        U.AddPoint(Cfg.StatName, 1)
    end,
})

-- ---------- ออโต้เปิดฮาคิ (ทำงานเมื่อยังไม่ติดฮาคิ) ----------
Hub.AddTask({
    name = "Haki",
    interval = 1,
    when = function(s)
        return s.alive and not s.hasBuso
    end,
    run = function()
        U.CommF("Buso")
    end,
})

-- ---------- ออโต้ซื้อฮาคิ (ทำงานเมื่อยังไม่มีและเงินพอ) ----------
Hub.AddTask({
    name = "BuyHaki",
    interval = 1,
    when = function(s)
        return s.alive and not s.ownsHaki and s.beli >= Cfg.HakiPrice
    end,
    run = function()
        U.CommF("BuyHaki", "Buso")
    end,
})

-- ---------- ออโต้ถืออาวุธ (ทำงานเมื่อมือว่าง) ----------
Hub.AddTask({
    name = "Equip",
    interval = 0.2,
    when = function(s)
        return s.alive and not s.holdingTool
    end,
    run = function()
        U.Equip(Cfg.EquipTip)
    end,
})

-- ---------- ออโต้สุ่มผล (ทำงานเมื่อเลเวลถึงเกณฑ์) ----------
local function getGachaRF()
    local m = ReplicatedStorage:FindFirstChild("Modules")
    local net = m and m:FindFirstChild("Net")
    return net and net:FindFirstChild("RF/GachaNetworkRF")
end

Hub.AddTask({
    name = "Gacha",
    interval = 5,
    when = function(s)
        return s.alive and s.level >= Cfg.GachaMinLevel
    end,
    run = function()
        local rf = getGachaRF()
        if not rf then return end

        local response = rf:InvokeServer({
            BoxName = "ZiolesGacha",
            Context = "Check",
            SpokeNPC = "Blox Fruit Gacha",
        })

        if type(response) == "table" and response.Price and response.Level then
            local canAfford = response.Price.Current >= response.Price.Value
            local levelOk = response.Level.Value >= Cfg.GachaMinLevel and response.Level.RequirementMet == true

            if canAfford and levelOk then
                rf:InvokeServer({
                    Context = "Purchase",
                    BoxName = "ZiolesGacha",
                })
            end
        end
    end,
})

-- ---------- ออโต้เก็บผลเข้ากระเป๋า (ทำงานเมื่อมีผลใน Backpack) ----------
local fruitCooldown = {} -- ชื่อผล -> เวลาที่จะลองใหม่ (กันสแปมตอนเก็บไม่สำเร็จ)

Hub.AddTask({
    name = "StoreFruit",
    interval = 2,
    when = function(s)
        return s.alive and s.fruitCount > 0
    end,
    run = function()
        for _, tool in ipairs(U.GetFruitTools()) do
            local name = tool.Name
            local retryAt = fruitCooldown[name]

            if not retryAt or os.clock() >= retryAt then
                local ok, result, internal = U.StoreFruit(tool)
                task.wait(0.5)

                -- ถ้าผลยังอยู่ในกระเป๋า = เก็บไม่สำเร็จ ให้พัก 30 วิแล้วค่อยลองใหม่
                if tool.Parent then
                    fruitCooldown[name] = os.clock() + 30
                    warn("[StoreFruit] เก็บไม่สำเร็จ:", name, "->", internal, ok, result)
                else
                    fruitCooldown[name] = nil
                    print("[StoreFruit] เก็บแล้ว:", name)
                end
            end
        end
    end,
})

-- ============================================================
-- 8. ฟังก์ชันควบคุม (Hub API)
-- ============================================================
function Hub.Enable(name)
    Cfg[name] = true
end

function Hub.Disable(name)
    Cfg[name] = false
end

function Hub.Toggle(name)
    Cfg[name] = not Cfg[name]
    return Cfg[name]
end

function Hub.Set(key, value)
    Cfg[key] = value
end

function Hub.Pause()
    Hub.Paused = true
end

function Hub.Resume()
    Hub.Paused = false
end

function Hub.Status()
    print("=== AutoHub === paused:", Hub.Paused, "| level:", State.level, "| alive:", State.alive)
    for name, t in pairs(Hub.Tasks) do
        print(" ", name, "| เปิดใน config:", Cfg[t.flag], "| ทำงานอยู่:", t.active, "| error รวม:", t.totalErrors)
    end
end

function Hub.Stop()
    Hub.Running = false
    if heartbeatConn then heartbeatConn:Disconnect() end
    Hub.Move.target = nil
    if _G.AutoHub == Hub then _G.AutoHub = nil end
    print("[AutoHub] หยุดทำงานแล้ว")
end

print("[AutoHub] เริ่มทำงาน | พิมพ์ _G.AutoHub.Status() เพื่อดูสถานะ")