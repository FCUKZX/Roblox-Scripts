-- =====================================================================
--  Pex Hub Lobby : สุ่มกล่อง Basic Crate (สคริปต์หน้าลอบบี้)
--  ถูกเรียกจาก CameramanTD.lua อัตโนมัติ เมื่อไม่เจอ UI ในเกมและ PlaceId ตรงกับลอบบี้
--  ใส่จำนวนกล่อง -> กดสุ่ม | ทุก 10 กล่อง = 900 Coins, เศษกล่องละ 100 Coins
--  สุ่มทีละ 10 กล่อง จนเหลือเศษหลักหน่วยแล้วสุ่มทีละ 1 กล่อง จนครบจำนวน
-- =====================================================================
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local CRATE_NAME = "Basic Crate"
local PRICE_ONE, PRICE_TEN = 100, 900
local PEX_URL = "https://raw.githubusercontent.com/FCUKZX/Roblox-Scripts/refs/heads/main/PexUI.lua"

local genv = (getgenv and getgenv()) or _G
if type(genv.__PexLobby) == "function" then pcall(genv.__PexLobby) end

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request
    or (fluxus and fluxus.request)

local alive, running = true, false
local conns = {}

local function fmt(n)
    local txt = string.format("%.0f", tonumber(n) or 0)
    local sign, digits = txt:match("^(-?)(%d+)$")
    if not digits then return txt end
    digits = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return sign .. digits
end

-- ---------- เงิน ----------
-- อ่านจากข้อความ เช่น "1,250" / "1.2K"
local SUF = { K = 1e3, M = 1e6, B = 1e9, T = 1e12 }
local function getCoins()
    local ok, txt = pcall(function()
        return pg.HUD.Currencies.Money.CurrencyFrame.AmountLabel.Text
    end)
    if not ok or type(txt) ~= "string" then return nil end
    txt = txt:gsub("<[^>]+>", ""):gsub(",", ""):gsub("%s", "")
    local num, suf = txt:match("(%d+%.?%d*)([KkMmBbTt]?)")
    local n = tonumber(num)
    if not n then return nil end
    if suf ~= "" then n = n * (SUF[suf:upper()] or 1) end
    return n
end

-- ---------- Anti-AFK ----------
conns[#conns + 1] = lp.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- ---------- โหลด PexUI ----------
local PEX
do
    local src
    local okGet, res = pcall(function() return game:HttpGet(PEX_URL) end)
    if okGet and type(res) == "string" and #res > 0 then src = res end
    if not src and httpRequest then
        local ok2, r = pcall(httpRequest, { Url = PEX_URL, Method = "GET" })
        if ok2 and r and type(r.Body) == "string" and #r.Body > 0 then src = r.Body end
    end
    local fn = src and loadstring(src)
    local okRun, lib = false, nil
    if fn then okRun, lib = pcall(fn) end
    if okRun and type(lib) == "table" and type(lib.CreateWindow) == "function" then PEX = lib end
end
if not PEX then
    warn("[PexLobby] โหลดหน้าต่างไม่สำเร็จ")
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    return
end
local PT = PEX.Theme

local function shutdown()
    alive = false
    running = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    genv.__PexLobby = nil
end
genv.__PexLobby = shutdown

local win = PEX:CreateWindow({
    Title = "Pex Hub", Subtitle = "Lobby", Icon = "package", Name = "PexHubLobby",
    OnClose = shutdown,
})
local function notify(text, color, icon, dur)
    pcall(function() win:Notify({ Text = tostring(text), Color = color, Duration = dur or 3, Icon = icon }) end)
end

local tab = win:AddTab({ Name = "Crate", Category = "Lobby", Icon = "package", Color = PT.Accent })
local sel = tab:Section({ Title = "สุ่มกล่อง (Basic Crate)", Desc = "ใส่จำนวนกล่อง แล้วกดสุ่ม (ทีละ 10 เศษทีละ 1) | 1 กล่อง = 100 Coins | ทุก 10 กล่อง คิดชุดละ 900 (ลด 10%)", Icon = "gift", Color = PT.Orange })
local lblCoins = sel:Label({ Text = "Coins: -", TextSize = 13, Color = PT.Text })
local countBox = sel:Input({ Title = "จำนวนที่จะสุ่ม (กล่อง)", Default = "10", Placeholder = "เช่น 10, 50, 7" })
local lblCalc = sel:Label({ Text = "-", TextSize = 12, Color = PT.Text })
local lblInfo = sel:Label({ Text = "พร้อมสุ่ม", TextSize = 12, Color = PT.Text })

local function getCount()
    local n = tonumber(countBox and countBox.Text) or 1
    return math.clamp(math.floor(n), 1, 9999)
end

-- ราคา: ทุก 10 กล่อง = 900 / เศษที่เหลือกล่องละ 100
local function calcCost(n)
    local packs, single = math.floor(n / 10), n % 10
    return packs * PRICE_TEN + single * PRICE_ONE, packs, single
end

local function setInfo(t) lblInfo.Text = t end

-- ---------- ระดับความหายาก (อ่านจาก SummonBoardUI) + แจ้งเตือนเมื่อสุ่มได้ ----------
local ALERT_SOUND = "rbxasset://sounds/electronicpingshort.wav"   -- เปลี่ยนเป็นเสียงอื่นได้ เช่น "rbxassetid://เลขไอดี"
local SoundService = game:GetService("SoundService")

local RARITY = { order = {}, byName = {}, lastScan = 0 }   -- byName[ชื่อยูนิต(ตัวเล็ก)] = ระดับ
local selected = {}        -- ระดับที่เลือกให้แจ้งเตือน
local notifyOn = true
local syncToggles          -- ประกาศไว้ก่อน (สร้างปุ่มเลือกระดับ)

local function cleanText(t)
    local x = tostring(t or ""):gsub("<[^>]+>", "")
    x = x:gsub("^%s+", ""):gsub("%s+$", "")
    return x:lower()
end

-- ชื่อโฟลเดอร์ระดับ เช่น Units1.Epic.UnitFrame.UnitName -> ระดับ = "Epic"
local function scanRarity()
    RARITY.lastScan = os.clock()
    local list = pg:FindFirstChild("SummonBoardUI")
    list = list and list:FindFirstChild("SummonHolder")
    list = list and list:FindFirstChild("MainFrame")
    list = list and list:FindFirstChild("UnitList")
    if not list then return false end
    local known = {}
    for _, r in ipairs(RARITY.order) do known[r] = true end
    for _, d in ipairs(list:GetDescendants()) do
        if d.Name == "UnitName" and (d:IsA("TextLabel") or d:IsA("TextButton")) then
            local a = d
            while a.Parent and a.Parent ~= list and not a.Parent.Name:match("^Units%d*$") do a = a.Parent end
            if a.Parent and a.Parent.Name:match("^Units%d*$") then
                local r = a.Name
                RARITY.byName[cleanText(d.Text)] = r
                if not known[r] then known[r] = true RARITY.order[#RARITY.order + 1] = r end
            end
        end
    end
    return #RARITY.order > 0
end

local function playAlert()
    task.spawn(function()
        pcall(function()
            local snd = Instance.new("Sound")
            snd.SoundId = ALERT_SOUND
            snd.Volume = 2
            snd.Parent = SoundService
            for _ = 1, 3 do snd:Play() task.wait(0.4) end
            task.wait(1.5)
            snd:Destroy()
        end)
    end)
end

-- ตรวจผลสุ่ม: ชื่อยูนิตตรงกับ UnitName ที่ระดับไหน ถ้าเป็นระดับที่เลือกไว้ -> แจ้งเตือน + เสียง
local function handleResults(res)
    if not notifyOn or next(selected) == nil or type(res) ~= "table" then return end
    local list = res
    if res.Name == nil and type(res[1]) == "table" and res[1].Name == nil and type(res[1][1]) == "table" then list = res[1] end
    local hits, order = {}, {}
    for _, e in ipairs(list) do
        local nm = type(e) == "table" and e.Name
        if type(nm) == "string" then
            local key = cleanText(nm)
            local r = RARITY.byName[key]
            if not r and os.clock() - RARITY.lastScan > 5 then
                scanRarity()
                if syncToggles then pcall(syncToggles) end
                r = RARITY.byName[key]
            end
            if r and selected[r] then
                if not hits[r] then hits[r] = {} order[#order + 1] = r end
                table.insert(hits[r], nm)
            end
        end
    end
    if #order == 0 then return end
    for _, r in ipairs(order) do
        notify("🎉 สุ่มได้ระดับ " .. r .. ": " .. table.concat(hits[r], ", "), PT.Good, "trophy", 6)
    end
    playAlert()
end

local function summon(count)
    local rf = RS:FindFirstChild("ModuleLoader")
    rf = rf and rf:FindFirstChild("Shared")
    rf = rf and rf:FindFirstChild("Network")
    rf = rf and rf:FindFirstChild("RemoteFunction")
    rf = rf and rf:FindFirstChild("SummonTowers")
    if not rf then return false, "ระบบสุ่มใช้ไม่ได้ในตอนนี้" end
    return pcall(function() return rf:InvokeServer(CRATE_NAME, count) end)
end

-- สุ่ม 1 ครั้ง (count = 10 หรือ 1) คืนค่า true ถ้าสำเร็จ
local function summonOnce(count, cost)
    local coins = getCoins()
    if not coins then return false, "อ่านเงินไม่ได้", true end
    if coins < cost then
        return false, string.format("เงินไม่พอ (มี %s ต้องใช้ %s)", fmt(coins), fmt(cost)), true
    end
    local ok, res = summon(count)
    local replied = ok and res ~= nil and res ~= false
    local dropped = false
    local t0 = os.clock()
    -- เซิร์ฟเวอร์ตอบแล้ว = ไปต่อทันที / ไม่ตอบ = รอดูเงินลดสูงสุด 2.5 วิ
    while ok and not replied and os.clock() - t0 < 2.5 do
        local now = getCoins()
        if now and now <= coins - cost * 0.5 then dropped = true break end
        task.wait(0.1)
    end
    if ok and (dropped or replied) then return true, nil, false, res end
    return false, tostring(res), false
end

local function roll()
    if running then notify("กำลังสุ่มอยู่ รอให้เสร็จก่อน", PT.Warn, "hourglass") return end
    local n = getCount()
    local cost = calcCost(n)
    local coins = getCoins()
    if not coins then notify("อ่านเงินไม่ได้", PT.Warn, "x") return end
    if coins < cost then
        local msg = string.format("เงินไม่พอ สุ่ม %d กล่องต้องใช้ %s (มี %s ขาดอีก %s)", n, fmt(cost), fmt(coins), fmt(cost - coins))
        setInfo(msg)
        notify(msg, PT.Warn, "x")
        return
    end

    running = true
    task.spawn(function()
        -- สุ่มทีละ 10 กล่อง (900) จนเหลือเศษ แล้วสุ่มทีละ 1 กล่อง (100) จนครบจำนวน
        local opened, spent, stopMsg, fails = 0, 0, nil, 0
        while alive and opened < n do
            local count = (n - opened >= 10) and 10 or 1
            local price = (count == 10) and PRICE_TEN or PRICE_ONE
            setInfo(string.format("กำลังสุ่ม... %d/%d กล่อง", opened, n))
            local ok, err, fatal, res = summonOnce(count, price)
            if ok then
                fails = 0
                opened = opened + count
                spent = spent + price
                handleResults(res)
            else
                fails = fails + 1
                if fatal or fails >= 3 then
                    stopMsg = fatal and err or ("สุ่มไม่สำเร็จติดกัน 3 ครั้ง (" .. tostring(err) .. ")")
                    break
                end
            end
        end
        running = false
        local msg = stopMsg and string.format("หยุด: %s | สุ่มได้ %d/%d กล่อง", stopMsg, opened, n)
            or string.format("สุ่มเสร็จ %d กล่อง (ใช้ %s Coins)", opened, fmt(spent))
        setInfo(msg)
        notify(msg, stopMsg and PT.Warn or PT.Good, stopMsg and "x" or "trophy")
    end)
end

-- ใส่จำนวนให้พอดีกับเงินทั้งหมด (ชุด 10 = 900 ก่อน แล้วเศษกล่องละ 100)
local function fitMax()
    local coins = getCoins()
    if not coins then notify("อ่านเงินไม่ได้", PT.Warn, "x") return end
    local packs = math.floor(coins / PRICE_TEN)
    local single = math.floor((coins - packs * PRICE_TEN) / PRICE_ONE)
    local n = packs * 10 + single
    if n < 1 then notify("เงินไม่พอสุ่มแม้แต่ 1 กล่อง", PT.Warn, "x") return end
    countBox.Text = tostring(n)
    notify(string.format("ตั้งจำนวน %d กล่อง (ใช้ %s Coins)", n, fmt((calcCost(n)))), PT.Good, "check")
end

sel:Action({ Text = "💰 ใส่จำนวนพอดีกับเงินทั้งหมด", Icon = "coins", Color = PT.Blue, Callback = fitMax })
sel:Action({ Text = "🎲 สุ่มเลย", Icon = "boxes", Color = PT.Purple, Callback = roll })

-- ---------- สุ่มต่อเนื่องจนกว่า Coin จะหมด ----------
local autoOn, autoRunning = false, false
local autoTog

local function flipAutoOff()
    autoOn = false
    if autoTog then
        for _, fn in ipairs({ "Set", "SetValue", "SetState" }) do
            local ok = pcall(function()
                if type(autoTog[fn]) == "function" then autoTog[fn](autoTog, false) else error("x") end
            end)
            if ok then break end
        end
    end
end

local function startAuto()
    if autoRunning then return end   -- ลูปเดิมยังทำงานอยู่ และจะทำต่อเพราะ autoOn เป็น true แล้ว
    if running then
        notify("กำลังสุ่มอยู่ รอให้เสร็จก่อน", PT.Warn, "hourglass")
        flipAutoOff()
        return
    end
    autoRunning, running = true, true
    task.spawn(function()
        local opened, spent, stopMsg, fails = 0, 0, nil, 0
        while alive and autoOn do
            local coins = getCoins()
            if not coins then stopMsg = "อ่านเงินไม่ได้" break end
            local count, price
            if coins >= PRICE_TEN then count, price = 10, PRICE_TEN
            elseif coins >= PRICE_ONE then count, price = 1, PRICE_ONE
            else stopMsg = "Coin หมดแล้ว" break end
            setInfo(string.format("สุ่มต่อเนื่อง... สุ่มแล้ว %d กล่อง", opened))
            local ok, err, fatal, res = summonOnce(count, price)
            if ok then
                fails = 0
                opened = opened + count
                spent = spent + price
                handleResults(res)
            else
                fails = fails + 1
                if fatal or fails >= 3 then
                    stopMsg = fatal and err or ("สุ่มไม่สำเร็จติดกัน 3 ครั้ง (" .. tostring(err) .. ")")
                    break
                end
                task.wait(0.3)
            end
        end
        local byUser = alive and not stopMsg   -- ผู้ใช้ปิดปุ่มเอง
        autoRunning, running = false, false
        if stopMsg then flipAutoOff() end
        local msg = string.format("สุ่มต่อเนื่อง%s | สุ่มได้ %d กล่อง (ใช้ %s Coins)",
            stopMsg and (" หยุด: " .. stopMsg) or (byUser and " หยุดแล้ว" or " จบ"), opened, fmt(spent))
        setInfo(msg)
        notify(msg, stopMsg == "Coin หมดแล้ว" and PT.Good or PT.Warn, stopMsg == "Coin หมดแล้ว" and "trophy" or "x", 5)
    end)
end

autoTog = sel:Toggle({
    Title = "สุ่มต่อเนื่องจนกว่า Coin จะหมด",
    Desc = "เปิด = สุ่มทีละ 10 (เศษทีละ 1) ไปเรื่อยๆ จน Coin ไม่พอ | ปิดเมื่อไหร่ก็หยุดทันที",
    Default = false,
    Callback = function(v)
        autoOn = v and true or false
        if autoOn then startAuto() end
    end,
})

-- ---------- แจ้งเตือนเมื่อสุ่มได้ระดับที่เลือก ----------
local sNotif = tab:Section({ Title = "แจ้งเตือนเมื่อสุ่มได้", Desc = "เลือกระดับที่ต้องการ ถ้าสุ่มได้ยูนิตระดับนั้นจะมีแจ้งเตือน + เสียง", Icon = "bell", Color = PT.Purple })
local lblRar = sNotif:Label({ Text = "กำลังหาระดับ...", TextSize = 12, Color = PT.Text })
sNotif:Toggle({
    Title = "เปิดแจ้งเตือน (มีเสียง)",
    Default = true,
    Callback = function(v) notifyOn = v and true or false end,
})
local created = {}
syncToggles = function()
    for _, r in ipairs(RARITY.order) do
        if not created[r] then
            created[r] = true
            sNotif:Toggle({
                Title = "ระดับ " .. r,
                Default = false,
                Callback = function(v) selected[r] = v and true or nil end,
            })
        end
    end
    lblRar.Text = (#RARITY.order > 0) and ("พบ " .. #RARITY.order .. " ระดับ: " .. table.concat(RARITY.order, ", "))
        or "ยังไม่พบระดับ (เปิดหน้า Summon ในเกมหนึ่งครั้ง แล้วกดสแกนใหม่)"
end
sNotif:Action({
    Text = "สแกนระดับใหม่", Icon = "refresh-cw", Color = PT.Blue,
    Callback = function()
        scanRarity()
        syncToggles()
        notify(#RARITY.order > 0 and ("พบ " .. #RARITY.order .. " ระดับ") or "ยังไม่พบระดับ", #RARITY.order > 0 and PT.Good or PT.Warn, "refresh-cw")
    end,
})
task.spawn(function()
    local t0 = os.clock()
    repeat
        scanRarity()
        if #RARITY.order > 0 then break end
        task.wait(1)
    until not alive or os.clock() - t0 > 20
    if alive then syncToggles() end
end)

task.spawn(function()
    while alive do
        local c = getCoins()
        local n = getCount()
        local cost, packs, single = calcCost(n)
        lblCoins.Text = "Coins: " .. (c and fmt(c) or "-")
        lblCalc.Text = string.format("สุ่ม %d กล่อง = %d ชุด x%s + %d กล่อง x%s | รวม %s Coins",
            n, packs, fmt(PRICE_TEN), single, fmt(PRICE_ONE), fmt(cost))
        task.wait(0.5)
    end
end)
notify("โหมดลอบบี้: กดปุ่มสุ่มได้เลย", PT.Good, "package")
