-- =====================================================================
--  Pex Hub Lobby : สุ่มกล่อง Basic Crate (สคริปต์หน้าลอบบี้)
--  ถูกเรียกจาก CameramanTD.lua อัตโนมัติ เมื่อไม่เจอ UI ในเกมและ PlaceId ตรงกับลอบบี้
--  ใส่จำนวนกล่อง -> กดสุ่ม | ทุก 10 กล่อง = 900 Coins, เศษกล่องละ 100 Coins
--  สุ่มทีละ 10 กล่อง จนเหลือเศษหลักหน่วยแล้วสุ่มทีละ 1 กล่อง จนครบจำนวน
--  + ซ่อนชื่อตัวเอง / ซ่อนตัวละคร NOOB (แท็บ Crate > ความเป็นส่วนตัว) ใช้ไฟล์ตั้งค่าเดียวกับ CameramanTD
--  + ออโต้สุ่มตัวแบบกำหนดตัว (แท็บ Auto Summon) อยู่ท้ายไฟล์
-- =====================================================================
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
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

-- ---------- ตัวบันทึก (ใช้ไฟล์เดียวกับสคริปต์ในเกม CameramanTD) ----------
-- อ่าน/เขียนไฟล์เดียวกัน: เขียนเฉพาะค่าของเราแล้วเก็บค่าอื่นในไฟล์ไว้เหมือนเดิม
local SETTINGS_FILE = "PexSkibidiTD_Settings.json"
local CFG = { HIDE_NAME = false, NOOB_MODE = false }
local function readSettings()
    local ok, data = pcall(function()
        if isfile and readfile and isfile(SETTINGS_FILE) then
            return HttpService:JSONDecode(readfile(SETTINGS_FILE))
        end
    end)
    return (ok and type(data) == "table") and data or {}
end
do
    local data = readSettings()
    for k in pairs(CFG) do
        if type(data[k]) == "boolean" then CFG[k] = data[k] end
    end
end
local function saveSettings()
    if not writefile then return end
    pcall(function()
        local data = readSettings()   -- อ่านใหม่ทุกครั้ง กันทับค่าที่สคริปต์เกมเพิ่งเซฟ
        if data.CFG_VERSION == nil then data.CFG_VERSION = 1 end
        for k, v in pairs(CFG) do data[k] = v end
        writefile(SETTINGS_FILE, HttpService:JSONEncode(data))
    end)
end

-- ---------- ซ่อนชื่อตัวเอง / ซ่อนตัวละคร (NOOB) ----------
-- ชื่อบัญชี + ชื่อที่แสดงของเรา ที่โผล่ในข้อความตรงไหนก็ตาม -> เปลี่ยนเป็น "ถูกซ่อน" (เฉพาะฝั่งเครื่องเรา)
-- ปิดสวิตช์ / ปิดสคริปต์ = คืนข้อความเดิม
local PRIV = { on = false, conns = {}, noobOn = false, noobConns = {} }
do
    local HIDDEN_TEXT = "ชื่อถูกซ่อน"
    local weak = function() return setmetatable({}, { __mode = "k" }) end
    PRIV.hooked, PRIV.orig, PRIV.last = weak(), weak(), weak()

    local function scrub(str)
        local out = str
        for _, nm in ipairs(PRIV.names or {}) do
            local low, lowN = out:lower(), nm:lower()
            local init, parts, hit = 1, {}, false
            while true do
                local a, b = low:find(lowN, init, true)
                if not a then break end
                parts[#parts + 1] = out:sub(init, a - 1)
                parts[#parts + 1] = HIDDEN_TEXT
                init, hit = b + 1, true
            end
            if hit then
                parts[#parts + 1] = out:sub(init)
                out = table.concat(parts)
            end
        end
        return out
    end

    local function hookText(o)
        if PRIV.hooked[o] then return end
        local function fix()
            if not PRIV.on then return end
            local t = o.Text
            if t == "" then return end
            local n = scrub(t)
            if n ~= t then
                PRIV.orig[o], PRIV.last[o] = t, n   -- t = ข้อความจากเกม (ล่าสุด)
                o.Text = n
            end
        end
        PRIV.hooked[o] = o:GetPropertyChangedSignal("Text"):Connect(fix)
        fix()
    end

    local function isTextObj(o)
        local c = o.ClassName
        return c == "TextLabel" or c == "TextButton"   -- ไม่แตะ TextBox (ช่องพิมพ์)
    end

    local function scanRoot(root)
        local ok, list = pcall(function() return root:GetDescendants() end)
        if not ok then return end
        for i, d in ipairs(list) do
            if not (alive and PRIV.on) then return end
            if isTextObj(d) then pcall(hookText, d) end
            if i % 300 == 0 then task.wait() end
        end
    end

    local function hideHumanoidName(ch)
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if hum and PRIV.on then pcall(function() hum.DisplayName = HIDDEN_TEXT end) end
    end

    function PRIV.set(on)
        on = on and true or false
        if on == PRIV.on then return end
        PRIV.on = on
        if on then
            local names, seen = {}, {}
            for _, n in ipairs({ lp.Name, lp.DisplayName }) do
                if type(n) == "string" and #n >= 3 and not seen[n:lower()] then
                    seen[n:lower()] = true
                    names[#names + 1] = n
                end
            end
            table.sort(names, function(a, b) return #a > #b end)   -- ชื่อยาวก่อน
            PRIV.names = names

            local roots = { pg, game:GetService("Workspace") }
            local okC, core = pcall(function() return game:GetService("CoreGui") end)
            if okC and core then roots[#roots + 1] = core end
            for _, root in ipairs(roots) do
                local okS, conn = pcall(function()
                    return root.DescendantAdded:Connect(function(d)
                        if PRIV.on and isTextObj(d) then pcall(hookText, d) end
                    end)
                end)
                if okS and conn then PRIV.conns[#PRIV.conns + 1] = conn end
                task.spawn(scanRoot, root)
            end
            PRIV.conns[#PRIV.conns + 1] = lp.CharacterAdded:Connect(function(ch)
                for _, w in ipairs({ 0.2, 1, 3 }) do
                    task.delay(w, function() if alive then hideHumanoidName(ch) end end)
                end
            end)
            hideHumanoidName(lp.Character)
        else
            for _, c in ipairs(PRIV.conns) do pcall(function() c:Disconnect() end) end
            PRIV.conns = {}
            for _, c in pairs(PRIV.hooked) do pcall(function() c:Disconnect() end) end
            for o, orig in pairs(PRIV.orig) do
                pcall(function()
                    if o.Parent and o.Text == PRIV.last[o] then o.Text = orig end
                end)
            end
            PRIV.hooked, PRIV.orig, PRIV.last = weak(), weak(), weak()
            local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.DisplayName = lp.DisplayName end) end
        end
    end
-- ---------- 2) ซ่อนตัวละคร (NOOB) ----------
local NOOB = {
    head  = BrickColor.new("Bright yellow").Color,
    torso = BrickColor.new("Bright blue").Color,
    arm   = BrickColor.new("Bright yellow").Color,
    leg   = BrickColor.new("Bright green").Color,
}

local function noobColor(partName)
    if partName == "Head" then return NOOB.head end
    if partName == "Torso" or partName == "UpperTorso" or partName == "LowerTorso" then return NOOB.torso end
    if partName:find("Arm") or partName:find("Hand") then return NOOB.arm end
    if partName:find("Leg") or partName:find("Foot") then return NOOB.leg end
    return nil
end

local function isAppearance(d)
    local c = d.ClassName
    return d:IsA("Accessory") or c == "Shirt" or c == "Pants" or c == "ShirtGraphic"
        or c == "CharacterMesh" or c == "SurfaceAppearance"
end

local function parkAppearance(nb, d)
    pcall(function()
        nb.removed[#nb.removed + 1] = { d, d.Parent }
        d.Parent = nil
    end)
end

local function noobify(ch)
    if not (PRIV.noobOn and ch and ch.Parent) then return end
    local nb = PRIV.nb
    if not nb or nb.ch ~= ch then
        nb = { ch = ch, removed = {}, colors = {}, tex = {} }
        PRIV.nb = nb
    end
    -- ถอดเสื้อ/กางเกง/หมวก/ผิวพิเศษ (เก็บไว้ คืนได้)
    for _, d in ipairs(ch:GetDescendants()) do
        if isAppearance(d) then parkAppearance(nb, d) end
    end
    -- สีผิวผ่าน BodyColors
    local bc = ch:FindFirstChildOfClass("BodyColors")
    if not bc then
        bc = Instance.new("BodyColors")
        bc.Parent = ch
        nb.bcNew = bc
    elseif not nb.bcOrig then
        nb.bcOrig = {
            bc, bc.HeadColor3, bc.TorsoColor3,
            bc.LeftArmColor3, bc.RightArmColor3, bc.LeftLegColor3, bc.RightLegColor3,
        }
    end
    pcall(function()
        bc.HeadColor3, bc.TorsoColor3 = NOOB.head, NOOB.torso
        bc.LeftArmColor3, bc.RightArmColor3 = NOOB.arm, NOOB.arm
        bc.LeftLegColor3, bc.RightLegColor3 = NOOB.leg, NOOB.leg
    end)
    -- ทาสีที่ชิ้นส่วนตรงๆ ด้วย (เผื่อเกมไม่ใช้ BodyColors) + ล้างลายของ MeshPart
    for _, part in ipairs(ch:GetChildren()) do
        if part:IsA("BasePart") then
            local col = noobColor(part.Name)
            if col then
                if nb.colors[part] == nil then nb.colors[part] = part.Color end
                pcall(function() part.Color = col end)
                if part:IsA("MeshPart") and part.TextureID ~= "" then
                    if nb.tex[part] == nil then nb.tex[part] = part.TextureID end
                    pcall(function() part.TextureID = "" end)
                end
            end
        end
    end
end

local function noobStart(ch)
    if not ch then return end
    PRIV.nb = nil
    noobify(ch)
    -- เกมมักโหลดชุดตัวละครตามหลัง -> ทำซ้ำช่วงแรก + ดักของที่โผล่มาใหม่
    for _, w in ipairs({ 0.3, 1, 2.5, 5 }) do
        task.delay(w, function() if alive and PRIV.noobOn and lp.Character == ch then noobify(ch) end end)
    end
    PRIV.noobConns[#PRIV.noobConns + 1] = ch.DescendantAdded:Connect(function(d)
        if not (PRIV.noobOn and PRIV.nb and PRIV.nb.ch == ch) then return end
        if isAppearance(d) then
            task.defer(function() if PRIV.nb and PRIV.nb.ch == ch then parkAppearance(PRIV.nb, d) end end)
        end
    end)
end

function PRIV.noobSet(on)
    on = on and true or false
    if on == PRIV.noobOn then return end
    PRIV.noobOn = on
    if on then
        PRIV.noobConns[#PRIV.noobConns + 1] = lp.CharacterAdded:Connect(function(ch)
            task.wait(0.1)
            if alive and PRIV.noobOn then noobStart(ch) end
        end)
        noobStart(lp.Character)
    else
        for _, c in ipairs(PRIV.noobConns) do pcall(function() c:Disconnect() end) end
        PRIV.noobConns = {}
        local nb = PRIV.nb
        PRIV.nb = nil
        if not nb then return end
        for part, col in pairs(nb.colors) do pcall(function() if part.Parent then part.Color = col end end) end
        for part, tex in pairs(nb.tex) do pcall(function() if part.Parent then part.TextureID = tex end end) end
        if nb.bcOrig then
            local o = nb.bcOrig
            pcall(function()
                local bc = o[1]
                bc.HeadColor3, bc.TorsoColor3 = o[2], o[3]
                bc.LeftArmColor3, bc.RightArmColor3 = o[4], o[5]
                bc.LeftLegColor3, bc.RightLegColor3 = o[6], o[7]
            end)
        end
        if nb.bcNew then pcall(function() nb.bcNew:Destroy() end) end
        for _, r in ipairs(nb.removed) do
            pcall(function()
                if r[2] and r[2].Parent then r[1].Parent = r[2] end
            end)
        end
    end
end

end

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
    pcall(PRIV.set, false)       -- คืนชื่อที่ซ่อนไว้
    pcall(PRIV.noobSet, false)   -- คืนหน้าตาตัวละคร
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
local syncToggles          -- ประกาศไว้ก่อน (อัปเดตรายการระดับใน Dropdown)

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

sel:Action({ Text = "ใส่จำนวนพอดีกับเงินทั้งหมด", Icon = "coins", Color = PT.Blue, Callback = fitMax })
sel:Action({ Text = "สุ่มเลย", Icon = "boxes", Color = PT.Purple, Callback = roll })

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
-- เลือกระดับแบบ Dropdown (เลือกได้หลายระดับ) กดหัวเพื่อเปิด/ปิดรายการ
local rarDrop = sNotif:Dropdown({
    Title = "ระดับที่ต้องการแจ้งเตือน",
    Desc = "เลือกได้หลายระดับ",
    Options = {},
    Multi = true,
    Default = {},
    Placeholder = "ยังไม่พบระดับ",
    Callback = function(list)
        selected = {}
        for _, r in ipairs(list or {}) do selected[r] = true end
    end,
})
local shownN = -1
syncToggles = function()
    if #RARITY.order ~= shownN then
        shownN = #RARITY.order
        local opts = {}
        for i, r in ipairs(RARITY.order) do opts[i] = r end
        rarDrop.Refresh(opts, true)   -- เก็บระดับที่เลือกไว้เดิม
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

-- ---------- ความเป็นส่วนตัว ----------
local sPriv = tab:Section({ Title = "ความเป็นส่วนตัว", Desc = "ซ่อนชื่อและหน้าตาของตัวเอง (เห็นเฉพาะในเครื่องเรา)", Icon = "shield-check", Color = PT.Pink })
sPriv:Toggle({
    Title = "ซ่อนชื่อตัวเอง",
    Desc = "เปิด = ชื่อบัญชีและชื่อที่แสดงของเราจะถูกซ่อน",
    Default = CFG.HIDE_NAME,
    Callback = function(v)
        CFG.HIDE_NAME = v and true or false
        saveSettings()
        PRIV.set(v)
    end,
})
sPriv:Toggle({
    Title = "ซ่อนตัวละคร (เป็น NOOB)",
    Desc = "เปิด = เปลี่ยนหน้าตาเราเป็น NOOB",
    Default = CFG.NOOB_MODE,
    Callback = function(v)
        CFG.NOOB_MODE = v and true or false
        saveSettings()
        PRIV.noobSet(v)
    end,
})
-- ค่าที่จำไว้ (จากไฟล์เดียวกับในเกม) -> เปิดให้เลยตอนเข้า
if CFG.HIDE_NAME then task.spawn(function() pcall(PRIV.set, true) end) end
if CFG.NOOB_MODE then task.spawn(function() pcall(PRIV.noobSet, true) end) end

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

-- =====================================================================
--  AUTO SUMMON แบบกำหนดตัว  (วางต่อท้ายไฟล์ CameramanLobby.lua ได้เลย ไม่ต้องแก้ส่วนอื่น)
--  ลำดับ: เช็กเงิน + เช็กว่าตู้มีตัวที่เลือก -> เดินไปจุดสุ่ม -> สุ่มจนเงินหมด
--         -> เดินไปลิฟต์ที่เป็นด่านที่เลือก (ลิฟต์ว่างเท่านั้น) -> กด Ready -> เกมเล่นต่อเอง
--  ตู้รีเซ็ตทุกครึ่งชั่วโมงตามนาฬิกาโลก (นาทีที่ :00 และ :30) ฝั่งในเกมจะพากลับมาลอบบี้เอง
--  เก็บค่าลงไฟล์เดียวกับสคริปต์อื่น: AUTO_SELECT_SUMMON / SUMMON_MAP / SUMMON_WANTED
-- =====================================================================
do
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local _okV, VIM = pcall(function() return game:GetService("VirtualInputManager") end)
if not _okV then VIM = nil end

local SUMMON_CF = CFrame.new(583.37, 310.81, 741.09)   -- จุดที่ต้องไปยืนสุ่ม
local RESUME_FILE = "PexSkibidiTD_Resume.json"
-- ถ้าไม่ได้ใช้ autoexec ให้ปล่อย true (จะ queue_on_teleport สคริปต์ในเกมให้ก่อนกด Ready)
-- ถ้าใช้ autoexec อยู่แล้ว ตั้งเป็น false กันสคริปต์รันซ้อน
local QUEUE_GAME = true
local GAME_URL = "https://raw.githubusercontent.com/FCUKZX/Roblox-Scripts/refs/heads/main/CameramanTD.lua"

local SM = {
    on = false, wanted = {}, map = "", maps = {}, mapOrder = {},
    crate = nil, crateN = 0, state = "ปิดอยู่", bad = {}, loopOn = false,
    skipSummonUntil = 0, queued = false,
}

-- ---------- โหลดค่าที่เซฟไว้ ----------
do
    local d = readSettings()
    SM.on = d.AUTO_SELECT_SUMMON == true
    if type(d.SUMMON_MAP) == "string" then SM.map = d.SUMMON_MAP end
    if type(d.SUMMON_WANTED) == "table" then
        for _, n in ipairs(d.SUMMON_WANTED) do
            if type(n) == "string" and n ~= "" then SM.wanted[#SM.wanted + 1] = n end
        end
    end
end

local function saveSM()
    if not writefile then return end
    pcall(function()
        local data = readSettings()   -- อ่านใหม่ทุกครั้ง เก็บค่าอื่นไว้เหมือนเดิม
        if data.CFG_VERSION == nil then data.CFG_VERSION = 1 end
        data.AUTO_SELECT_SUMMON = SM.on
        data.SUMMON_MAP = SM.map
        data.SUMMON_WANTED = SM.wanted
        writefile(SETTINGS_FILE, HttpService:JSONEncode(data))
    end)
end

local function setState(t) SM.state = tostring(t) end

-- ---------- อ่านตู้ (รายชื่อตัวที่อยู่ในตู้ตอนนี้ เก็บสดทุกครั้ง ไม่สะสมของเก่า) ----------
local function scanCrate()
    local list = pg:FindFirstChild("SummonBoardUI")
    list = list and list:FindFirstChild("SummonHolder")
    list = list and list:FindFirstChild("MainFrame")
    list = list and list:FindFirstChild("UnitList")
    if not list then return nil end
    local set, n = {}, 0
    for _, d in ipairs(list:GetDescendants()) do
        if d.Name == "UnitName" and (d:IsA("TextLabel") or d:IsA("TextButton")) then
            local k = cleanText(d.Text)
            if k ~= "" and not set[k] then
                set[k] = (tostring(d.Text):gsub("<[^>]+>", ""))
                n = n + 1
            end
        end
    end
    if n == 0 then return nil end
    SM.crate, SM.crateN = set, n
    return set
end

local function foundWanted(set)
    local found = {}
    if set then
        for _, w in ipairs(SM.wanted) do
            local d = set[cleanText(w)]
            if d then found[#found + 1] = d end
        end
    end
    return found
end

local function waitFor(fn, timeout, active)
    local t0 = os.clock()
    repeat
        local v = fn()
        if v then return v end
        task.wait(0.5)
    until os.clock() - t0 > timeout or not (alive and active())
    return fn()
end

-- ---------- ลิฟต์ ----------
local function readText(obj)
    local ok, t = pcall(function() return obj.Text end)
    if ok and type(t) == "string" then return (t:gsub("<[^>]+>", "")) end
    return nil
end

local function allElevators()
    local out = {}
    local root = Workspace:FindFirstChild("Elevators")
    if not root then return out end
    for _, e in ipairs(root:GetChildren()) do
        local bp = e:FindFirstChild("BasePart")
        local sg = bp and bp:FindFirstChild("StatusGui")
        local mapL = sg and sg:FindFirstChild("MapName")
        local cntL = sg and sg:FindFirstChild("PlayersCount")
        local map = mapL and readText(mapL)
        local cnt = cntL and readText(cntL)
        local a, b = tostring(cnt or ""):match("(%d+)%s*/%s*(%d+)")
        out[#out + 1] = {
            model = e, map = map, key = map and cleanText(map) or nil,
            area = e:FindFirstChild("Area"), players = tonumber(a), max = tonumber(b),
        }
    end
    table.sort(out, function(x, y) return x.model.Name < y.model.Name end)
    return out
end

local function areaPos(area)
    if not area then return nil end
    if area:IsA("BasePart") then return area.Position end
    if area:IsA("Model") then return area:GetPivot().Position end
    local p = area:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end

-- ชื่อด่านซ้ำ = ที่เดียวกัน (เทียบด้วย key ตัวเล็ก)
local function scanMaps()
    local changed = false
    if SM.map ~= "" then
        local k = cleanText(SM.map)
        if not SM.maps[k] then SM.maps[k] = SM.map SM.mapOrder[#SM.mapOrder + 1] = k changed = true end
    end
    for _, e in ipairs(allElevators()) do
        if e.key and e.key ~= "" and not SM.maps[e.key] then
            SM.maps[e.key] = e.map
            SM.mapOrder[#SM.mapOrder + 1] = e.key
            changed = true
        end
    end
    return changed
end

local function queueFrame()
    local g = pg:FindFirstChild("ElevatorGui")
    return g and g:FindFirstChild("QueueFrame")
end

local function guiShown(o)
    local cur = o
    while cur and cur ~= pg do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return cur == pg
end

local function queueShown()
    local f = queueFrame()
    return (f and guiShown(f)) and f or nil
end

-- ---------- กดปุ่ม ----------
local function pressBtn(obj)
    local btn = obj
    if not obj:IsA("GuiButton") then btn = obj:FindFirstChildWhichIsA("GuiButton", true) or obj end
    local fired = false
    if getconnections then
        for _, sig in ipairs({ "MouseButton1Click", "Activated", "MouseButton1Down" }) do
            local ok, list = pcall(function() return getconnections(btn[sig]) end)
            if ok and list then
                for _, c in ipairs(list) do pcall(function() c:Fire() end) fired = true end
            end
            if fired then break end
        end
    end
    if not fired and firesignal then
        fired = pcall(function() firesignal(btn.MouseButton1Click) end)
        pcall(function() firesignal(btn.Activated) end)
    end
    if not fired and VIM then
        pcall(function()
            local pos, size = btn.AbsolutePosition, btn.AbsoluteSize
            local gui = btn:FindFirstAncestorWhichIsA("ScreenGui")
            local inset = (gui and gui.IgnoreGuiInset) and 0 or GuiService:GetGuiInset().Y
            local x, y = pos.X + size.X / 2, pos.Y + size.Y / 2 + inset
            VIM:SendMouseButtonEvent(x, y, 0, true, game, 1)
            task.wait(0.05)
            VIM:SendMouseButtonEvent(x, y, 0, false, game, 1)
        end)
    end
end

-- ---------- เดินฉลาด (PathfindingService หลบสิ่งกีดขวาง / กระโดดเมื่อติด / คำนวณทางใหม่) ----------
local function getRH()
    local ch = lp.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if hum and root and hum.Health > 0 then return root, hum end
    return nil
end

local function flat(a, b) return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude end

-- คืน true = ถึงแล้ว | false = ไม่ถึง / ถูกสั่งหยุด (active() เป็น false)
local function walkTo(target, active, reach)
    reach = reach or 3
    local t0, fails = os.clock(), 0
    while alive and active() and os.clock() - t0 < 120 and fails < 8 do
        local root, hum = getRH()
        if not root then
            task.wait(0.5)
        elseif flat(root.Position, target) <= reach and math.abs(root.Position.Y - target.Y) < 10 then
            pcall(function() hum:MoveTo(root.Position) end)
            return true
        else
            local path = PathfindingService:CreatePath({
                AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 4,
            })
            local okP = pcall(function() path:ComputeAsync(root.Position, target) end)
            if okP and path.Status == Enum.PathStatus.Success then
                local wps = path:GetWaypoints()
                local blocked = false
                local bc = path.Blocked:Connect(function() blocked = true end)
                for i = 2, #wps do
                    if blocked or not (alive and active()) then break end
                    local wp = wps[i]
                    if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
                    hum:MoveTo(wp.Position)
                    local ws, lastP, lastT = os.clock(), root.Position, os.clock()
                    while alive and active() and not blocked do
                        if not root.Parent or hum.Health <= 0 then blocked = true break end
                        if flat(root.Position, wp.Position) < 2.5 then break end
                        if os.clock() - ws > 5 then blocked = true break end
                        if (root.Position - lastP).Magnitude > 0.5 then
                            lastP, lastT = root.Position, os.clock()
                        elseif os.clock() - lastT > 0.7 then
                            hum.Jump = true            -- ติดสิ่งกีดขวาง ลองกระโดด
                            lastT = os.clock()
                        end
                        task.wait(0.1)
                    end
                end
                bc:Disconnect()
                if blocked then fails = fails + 1 else fails = 0 end
            else
                -- หาเส้นทางไม่ได้: แผนสำรอง เดินตรงไปทางเป้าหมาย
                fails = fails + 1
                pcall(function() hum:MoveTo(target) end)
                local lp0 = root.Position
                task.wait(1.5)
                if (root.Position - lp0).Magnitude < 1 then hum.Jump = true end
            end
        end
    end
    return false
end

-- ---------- สุ่มจนเงินหมด (ใช้ summonOnce / getCoins / handleResults ของสคริปต์เดิม) ----------
local function summonBody(active)
    local opened, spent, fails, stop = 0, 0, 0, nil
    local slot = os.time() // 1800
    while active() do
        if os.time() // 1800 ~= slot then   -- ตู้รีเซ็ตระหว่างสุ่ม: เช็กใหม่ว่ายังมีตัวที่เลือกไหม
            slot = os.time() // 1800
            local set = scanCrate()
            if set and #foundWanted(set) == 0 then stop = "ตู้รีเซ็ตแล้ว ไม่มีตัวที่เลือก" break end
        end
        local coins = getCoins()
        if not coins then stop = "อ่านเงินไม่ได้" break end
        local count, price
        if coins >= PRICE_TEN then count, price = 10, PRICE_TEN
        elseif coins >= PRICE_ONE then count, price = 1, PRICE_ONE
        else stop = "Coin หมดแล้ว" break end
        setState(string.format("กำลังสุ่ม... สุ่มแล้ว %d กล่อง (เหลือ %s Coins)", opened, fmt(coins)))
        local ok, err, fatal, res = summonOnce(count, price)
        if ok then
            fails = 0
            opened = opened + count
            spent = spent + price
            handleResults(res)
        else
            fails = fails + 1
            if fatal or fails >= 3 then
                stop = fatal and err or ("สุ่มไม่สำเร็จติดกัน 3 ครั้ง (" .. tostring(err) .. ")")
                break
            end
            task.wait(0.3)
        end
    end
    return opened, spent, stop
end

local function summonRun(active)
    running = true
    local ok, a, b, c = pcall(summonBody, active)
    running = false
    if ok then return a, b, c end
    return 0, 0, "error: " .. tostring(a)
end

-- ---------- กลับไปเล่น: ลิฟต์ -> Ready ----------
local function touchResume()   -- ต่ออายุไฟล์ resume ให้สคริปต์ในเกมยังเล่นต่อได้
    pcall(function()
        if isfile and readfile and isfile(RESUME_FILE) then
            local d = HttpService:JSONDecode(readfile(RESUME_FILE))
            if type(d) == "table" and d.playing then
                d.ts = os.time()
                writefile(RESUME_FILE, HttpService:JSONEncode(d))
            end
        end
    end)
end

local function goPlay(active)
    if SM.map == "" then
        setState("ยังไม่ได้เลือกด่านที่จะกลับไปเล่น (เลือกในรายการด่าน)")
        task.wait(3)
        return
    end
    local want = cleanText(SM.map)
    local cands = {}
    for _, e in ipairs(allElevators()) do
        local busy = e.players ~= nil and e.players >= 1          -- 1/5 ขึ้นไป = มีคนอยู่ ข้าม
        local bad = SM.bad[e.model] and SM.bad[e.model] > os.clock()
        if e.key == want and e.area and not busy and not bad then cands[#cands + 1] = e end
    end
    if #cands == 0 then
        setState("ไม่มีลิฟต์ว่างที่เป็นด่าน " .. SM.map .. " รอสักครู่...")
        task.wait(3)
        return
    end
    local e = cands[1]
    local ap = areaPos(e.area)
    if not ap then SM.bad[e.model] = os.clock() + 30 return end
    setState("เดินไปที่ " .. e.model.Name .. " (" .. SM.map .. ")")
    walkTo(ap, function() return alive and SM.on and not queueShown() end, 2.5)
    if not (alive and SM.on) then return end
    if not waitFor(queueShown, 4, function() return SM.on end) then
        SM.bad[e.model] = os.clock() + 20
        setState("ลิฟต์นี้ไม่เปิดหน้าคิว ลองอันอื่น")
        return
    end

    setState("เปิดหน้าคิวแล้ว กด Ready")
    touchResume()
    if QUEUE_GAME and queue_on_teleport and GAME_URL ~= "" and not SM.queued then
        SM.queued = true
        pcall(queue_on_teleport, string.format("loadstring(game:HttpGet(%q))()", GAME_URL))
    end
    local lastPress = -100
    local t0 = os.clock()
    while alive and SM.on and os.clock() - t0 < 90 do
        local qf = queueShown()
        if not qf then break end
        local rb = qf:FindFirstChild("ReadyButton")
        -- กดครั้งเดียวต่อรอบ 30 วิ (กันปุ่มเป็นแบบสลับ Ready/ยกเลิก)
        if rb and os.clock() - lastPress > 30 then
            lastPress = os.clock()
            pressBtn(rb)
            setState("กด Ready แล้ว รอเกมย้ายแมพ...")
        end
        task.wait(0.5)
    end
end

-- ---------- 1 รอบการตัดสินใจ ----------
function SM.cycle()
    local function active() return alive and SM.on end
    if not active() then return end
    setState("ตรวจเงินและตู้...")
    local coins = waitFor(getCoins, 20, active)
    local set = waitFor(scanCrate, 20, active)
    if not active() then return end
    local found = foundWanted(set)

    if #found > 0 and coins and coins >= PRICE_ONE and os.clock() >= SM.skipSummonUntil then
        if running then
            setState("กำลังสุ่มด้วยปุ่มอื่นอยู่ รอให้เสร็จก่อน")
            task.wait(2)
            return
        end
        setState("ตู้มี " .. table.concat(found, ", ") .. " -> เดินไปจุดสุ่ม")
        local arrived = walkTo(SUMMON_CF.Position, active, 3)
        if arrived and active() then
            local opened, spent, stop = summonRun(active)
            local msg = string.format("สุ่มตัวที่เลือกเสร็จ %d กล่อง (ใช้ %s Coins)%s",
                opened, fmt(spent), stop and (" | " .. stop) or "")
            notify(msg, (stop == "Coin หมดแล้ว") and PT.Good or PT.Warn, "trophy", 6)
            if stop and stop ~= "Coin หมดแล้ว" then SM.skipSummonUntil = os.clock() + 120 end
        elseif active() then
            SM.skipSummonUntil = os.clock() + 120
            notify("เดินไปจุดสุ่มไม่ถึง ข้ามไปเล่นก่อน", PT.Warn, "x")
        end
    else
        local why = (not set) and "อ่านตู้ไม่ได้"
            or (#found == 0) and "ตู้ไม่มีตัวที่เลือก"
            or (not coins or coins < PRICE_ONE) and "เงินไม่พอ"
            or "รอพักหลังสุ่มพลาด"
        setState(why .. " -> กลับไปเล่น")
    end
    if active() then goPlay(active) end
end

function SM.start()
    if SM.loopOn then return end
    SM.loopOn = true
    task.spawn(function()
        while alive and SM.on do
            local ok, err = pcall(SM.cycle)
            if not ok then
                setState("error: " .. tostring(err))
                task.wait(3)
            end
            task.wait(0.3)
        end
        SM.loopOn = false
        if not SM.on then setState("ปิดอยู่") end
    end)
end

-- =====================================================================
--  UI (แท็บ Auto Summon)
-- =====================================================================
local tabSM = win:AddTab({ Name = "Auto Summon", Category = "Lobby", Icon = "zap", Color = PT.Purple })

local sMain = tabSM:Section({
    Title = "ออโต้สุ่มตัวแบบกำหนดตัว",
    Desc = "ตู้มีตัวที่เลือก + เงินพอ = เดินไปสุ่มจนเงินหมด แล้วกลับไปเล่นต่อ | ตู้รีเซ็ตทุก 30 นาที (:00 / :30)",
    Icon = "gift", Color = PT.Purple,
})
sMain:Toggle({
    Title = "ออโต้สุ่มตัวแบบกำหนดตัว",
    Desc = "ปุ่มเดียวทำทุกอย่าง (ใช้ได้ข้ามแมพ) | ปิด = หยุดระบบนี้ทันที",
    Default = SM.on,
    Callback = function(v)
        SM.on = v and true or false
        saveSM()
        if SM.on then SM.start() else setState("ปิดอยู่") end
    end,
})
local lblState = sMain:Label({ Text = "สถานะ: ปิดอยู่", TextSize = 12, Color = PT.Text })
local lblReset = sMain:Label({ Text = "-", TextSize = 12, Color = PT.Text })
local lblCrate = sMain:Label({ Text = "ตู้ตอนนี้: กำลังอ่าน...", TextSize = 12, Color = PT.Text })
sMain:Action({
    Text = "สแกนตู้ตอนนี้", Icon = "refresh-cw", Color = PT.Blue,
    Callback = function()
        local set = scanCrate()
        if SM.refreshWant then SM.refreshWant() end
        notify(set and ("พบ " .. SM.crateN .. " ตัวในตู้") or "อ่านตู้ไม่ได้ (เปิดหน้า Summon ในเกมหนึ่งครั้ง)",
            set and PT.Good or PT.Warn, "refresh-cw")
    end,
})

local sWant = tabSM:Section({
    Title = "ตัวที่ต้องการ",
    Desc = "พิมพ์ชื่อให้ตรงกับชื่อในตู้ (ตัวใหญ่/เล็กไม่สำคัญ) | บันทึกอัตโนมัติ | แตะชื่อในรายการเพื่อลบ",
    Icon = "bell", Color = PT.Orange,
})
local wantList
local function addWanted(box)
    local name = (tostring(box.Text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    box.Text = ""
    if name == "" then return end
    for _, w in ipairs(SM.wanted) do
        if cleanText(w) == cleanText(name) then notify("มีชื่อนี้อยู่ในรายการแล้ว", PT.Warn, "x") return end
    end
    -- ถ้าตัวนี้อยู่ในตู้ตอนนี้ ใช้ชื่อจริงตามตู้ (สะกดตรงเป๊ะ)
    local real = SM.crate and SM.crate[cleanText(name)]
    SM.wanted[#SM.wanted + 1] = real or name
    saveSM()
    SM.refreshWant()
    notify(real and ("เพิ่ม " .. real .. " แล้ว (อยู่ในตู้ตอนนี้)") or ("เพิ่ม " .. name .. " แล้ว (ตอนนี้ยังไม่อยู่ในตู้ จะรอเจอ)"),
        PT.Good, "check")
end
sWant:Input({ Title = "พิมพ์ชื่อตัว แล้วกด Enter", Placeholder = "เช่น Camera Helicopter", Callback = addWanted })
wantList = sWant:List({ Height = 150, Title = "ตัวที่เลือกไว้" })
function SM.refreshWant()
    wantList:Clear()
    if #SM.wanted == 0 then wantList:Note("ยังไม่ได้เลือกตัว พิมพ์ชื่อด้านบนได้เลย") return end
    for i, name in ipairs(SM.wanted) do
        local inCrate = SM.crate and SM.crate[cleanText(name)]
        wantList:Add({
            Text = name .. (inCrate and "   ● อยู่ในตู้ตอนนี้" or ""), Order = i,
            Callback = function()
                win:Dialog({
                    Title = "ลบตัวนี้?", Text = "\"" .. name .. "\" จะถูกลบออกจากรายการ", Dismissable = true,
                    Buttons = {
                        { Text = "ยกเลิก" },
                        {
                            Text = "ลบ", Icon = "trash-2", Color = PT.Bad,
                            Callback = function()
                                for k, w in ipairs(SM.wanted) do
                                    if w == name then table.remove(SM.wanted, k) break end
                                end
                                saveSM()
                                SM.refreshWant()
                            end,
                        },
                    },
                })
            end,
        })
    end
end

local sMap = tabSM:Section({
    Title = "ด่านที่จะกลับไปเล่น",
    Desc = "อ่านชื่อด่านจากลิฟต์ทุกตัว (ชื่อซ้ำ = ที่เดียวกัน) | แตะเพื่อเลือก | ลิฟต์ที่มีคน (1/5 ขึ้นไป) จะข้ามไปตัวอื่นเอง",
    Icon = "map-pin", Color = PT.Cyan,
})
local mapList = sMap:List({ Height = 130, Title = "ด่านที่พบ" })
function SM.refreshMaps()
    mapList:Clear()
    if #SM.mapOrder == 0 then mapList:Note("ยังไม่พบลิฟต์ (รอเกมโหลด แล้วกดสแกน)") return end
    for i, key in ipairs(SM.mapOrder) do
        local nm = SM.maps[key]
        mapList:Add({
            Text = nm, Selected = (cleanText(SM.map) == key), Order = i,
            Callback = function()
                SM.map = nm
                saveSM()
                SM.refreshMaps()
                notify("เลือกด่าน: " .. nm, PT.Good, "check")
            end,
        })
    end
end
sMap:Action({
    Text = "สแกนลิฟต์ใหม่", Icon = "refresh-cw", Color = PT.Blue,
    Callback = function()
        scanMaps()
        SM.refreshMaps()
        notify(#SM.mapOrder > 0 and ("พบ " .. #SM.mapOrder .. " ด่าน") or "ยังไม่พบลิฟต์",
            #SM.mapOrder > 0 and PT.Good or PT.Warn, "refresh-cw")
    end,
})

-- ---------- ลูปอัปเดต UI ----------
task.spawn(function()
    local lastMaps, lastCrate, sig = -100, -100, ""
    while alive do
        local now = os.clock()
        if now - lastMaps > 3 then
            lastMaps = now
            if scanMaps() then SM.refreshMaps() end
        end
        if now - lastCrate > 5 then
            lastCrate = now
            scanCrate()
            local names = {}
            for _, v in pairs(SM.crate or {}) do names[#names + 1] = v end
            table.sort(names)
            local s = table.concat(names, ", ")
            if s ~= sig then
                sig = s
                SM.refreshWant()
                lblCrate.Text = (#names > 0) and ("ตู้ตอนนี้ (" .. #names .. "): " .. s) or "ตู้ตอนนี้: อ่านไม่ได้"
            end
        end
        local left = 1800 - (os.time() % 1800)
        lblReset.Text = string.format("ตู้รีเซ็ตในอีก %02d:%02d", left // 60, left % 60)
        lblState.Text = "สถานะ: " .. SM.state
        task.wait(0.5)
    end
end)

SM.refreshWant()
scanMaps()
SM.refreshMaps()
if SM.on then SM.start() end
end
