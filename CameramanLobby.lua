-- =====================================================================
--  Pex Hub Lobby : สุ่มกล่อง Basic Crate (สคริปต์หน้าลอบบี้)
--  ถูกเรียกจาก CameramanTD.lua อัตโนมัติ เมื่อไม่เจอ UI ในเกมและ PlaceId ตรงกับลอบบี้
--  ใส่จำนวนกล่อง -> กดสุ่ม | ทุก 10 กล่อง = 900 Coins, เศษกล่องละ 100 Coins
--  สุ่มทีละ 10 กล่อง จนเหลือเศษหลักหน่วยแล้วสุ่มทีละ 1 กล่อง จนครบจำนวน
--  + ซ่อนชื่อตัวเอง / ซ่อนตัวละคร NOOB (แท็บ Crate > ความเป็นส่วนตัว) ใช้ไฟล์ตั้งค่าเดียวกับ CameramanTD
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
    local HIDDEN_TEXT = "ถูกซ่อน"
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
    Desc = "เปิด = ชื่อบัญชีและชื่อที่แสดงของเราจะถูกซ่อน,
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
