--[[
    XenonUI v2.0
    UI library สไตล์ Xenon Hub สำหรับ Roblox (รองรับทั้ง PC และมือถือ)

    - หน้าต่างปรับขนาดตามจอเอง (มือถือ: กว้าง ~76% / สูง ~82% ของจอ)
    - ปุ่มเหลือง = ย่อเป็นวงกลมข้างจอ (ลากย้ายได้ ดูดเข้าขอบซ้าย/ขวา แตะเพื่อขยายกลับ)
    - ไม่มีอีโมจิ: ไอคอนทั้งหมดเป็นไอคอน ID (Lucide อัตโนมัติ หรือใส่ rbxassetid เองได้)
    - แอนิเมชัน: เปิด/ย่อ/ขยาย, สลับแท็บ, สวิตช์, ปุ่ม, Toast
    - v2.0: ปุ่มยุบตามจุดที่นิ้วกด + Ripple, ลากหน้าต่างแบบนุ่ม (lerp), เลื่อนแบบ iOS (ยางยืด)
            คอนโทรลใหม่: Slider, Dropdown (เดี่ยว/หลายตัวเลือก), Keybind, ColorPicker, Progress,
            Divider, Paragraph, Section พับได้ (Collapsible), Dialog ยืนยัน

    วิธีเรียกใช้ผ่าน Git:
        local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/USER/REPO/main/XenonUI.lua"))()
        local win = UI:CreateWindow({ Title = "My Hub", Subtitle = "v1", Icon = "zap" })
        local tab = win:AddTab({ Name = "Main", Category = "General", Icon = "home" })
        local sec = tab:Section({ Title = "Hello", Desc = "ตัวอย่าง", Icon = "sparkles" })
        sec:Toggle({ Title = "Auto", Default = false, Callback = function(v) print(v) end })

    ไอคอน (Icon = ...) รับได้ 3 แบบ
        "play"                      ชื่อไอคอน Lucide (โหลดเป็น asset id ให้อัตโนมัติ)
        1234567890 / "rbxassetid://1234567890"   ไอคอน ID ของคุณเอง
        {id = 123, offset = Vector2.new(0, 0), size = Vector2.new(48, 48)}   สไปรต์ชีต
    ผูกชื่อกับ ID ของตัวเอง:  UI.CustomIcons["play"] = 1234567890
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local UI = {}
UI.Version = "2.0.0"
-- แหล่งไอคอน Lucide (spritesheet asset id) ถ้าโหลดไม่ได้ ไอคอนจะเป็นจุดแทน ไม่ทำให้ UI พัง
UI.LucideURL = "https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau"
UI.LucideMirrors = {
    "https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau",
    "https://raw.githubusercontent.com/latte-soft/lucide-roblox/main/lucide-roblox.luau",
}
UI.CustomIcons = {}
UI.UiScale = 1 -- ขนาดตัวหน้าต่าง (1 = ขนาดจริง คมที่สุด)
UI.ForceMobile = nil -- true/false = บังคับโหมดมือถือ/คอม, nil = ตรวจเอง
UI.DragHoldTime = 0 -- กดค้างที่หัวหน้าต่างกี่วินาทีถึงจะลากได้ (0 = ลากได้ทันที ไม่ต้องกดค้าง)
UI.DragReturn = true -- ปล่อยหัวหน้าต่างแล้วค่อยๆ เด้งกลับที่เดิม (false = อยู่ตรงที่ปล่อย)
UI.SliderHoldTime = 0.5 -- ต้องกดค้างที่หลอด Slider กี่วินาทีถึงจะลากได้ (0 = ลากได้ทันที)
UI.IntroBubble = true -- ตอนเปิดสคริปต์: ผุดเป็นวงกลมแล้วขยายออกแบบเดียวกับตอนกดขยาย (false = แอนิเมชันเก่า)

UI.Theme = {
    Bg = Color3.fromRGB(16, 16, 24),
    Side = Color3.fromRGB(20, 20, 30),
    Top = Color3.fromRGB(19, 19, 28),
    Card = Color3.fromRGB(26, 26, 38),
    Inset = Color3.fromRGB(17, 17, 25),
    Elem = Color3.fromRGB(42, 42, 60),
    Line = Color3.fromRGB(58, 58, 80),
    Text = Color3.fromRGB(246, 246, 255),
    Muted = Color3.fromRGB(176, 176, 200),
    Accent = Color3.fromRGB(98, 112, 255),
    Good = Color3.fromRGB(52, 202, 120),
    Bad = Color3.fromRGB(240, 82, 98),
    Warn = Color3.fromRGB(240, 178, 60),
    Blue = Color3.fromRGB(56, 142, 248),
    Purple = Color3.fromRGB(160, 96, 245),
    Pink = Color3.fromRGB(244, 76, 150),
    Orange = Color3.fromRGB(250, 160, 50),
    Cyan = Color3.fromRGB(36, 190, 212),
}
local T = UI.Theme
local WHITE = Color3.new(1, 1, 1)

local F_REG, F_MED, F_BOLD = Enum.Font.Gotham, Enum.Font.GothamMedium, Enum.Font.GothamBold
local AX, AY = Enum.AutomaticSize.X, Enum.AutomaticSize.Y

-- =====================================================================
-- Utilities
-- =====================================================================
local activeTw = setmetatable({}, { __mode = "k" })
local function tween(o, props, t, style, dir)
    -- ยกเลิกทวีนเดิมที่แย่งคุณสมบัติชุดเดียวกัน -> ไม่ตีกัน ไม่สั่น ไม่กระตุก
    local keys = {}
    for k in pairs(props) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local sig = table.concat(keys, "|")
    local m = activeTw[o]
    if not m then
        m = {}
        activeTw[o] = m
    end
    local old = m[sig]
    if old then old:Cancel() end
    local tw = TweenService:Create(o, TweenInfo.new(t or 0.25, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    m[sig] = tw
    tw.Completed:Connect(function()
        if m[sig] == tw then m[sig] = nil end
    end)
    tw:Play()
    return tw
end
UI.Tween = tween

local function new(class, props, parent)
    local o = Instance.new(class)
    if props then
        for k, v in pairs(props) do o[k] = v end
    end
    if parent then o.Parent = parent end
    return o
end
UI.New = new

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

local function corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function stroke(o, color, th, tr)
    return new("UIStroke", { Color = color, Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function pad(o, l, t, r, b)
    t = t or l
    r = r or l
    b = b or t
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
        PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b),
    }, o)
end
local function vlist(o, gap)
    return new("UIListLayout", { Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder }, o)
end
local function label(parent, props)
    local base = {
        BackgroundTransparency = 1, BorderSizePixel = 0, Font = F_MED, TextSize = 13, TextColor3 = T.Text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    }
    for k, v in pairs(props) do base[k] = v end
    return new("TextLabel", base, parent)
end
UI.Corner, UI.Stroke, UI.Pad, UI.List, UI.Label = corner, stroke, pad, vlist, label

local function httpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and type(res) == "string" and #res > 0 then return res end
    local req = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
    if req then
        local ok2, r = pcall(req, { Url = url, Method = "GET" })
        if ok2 and r and r.Body and (r.Success or r.StatusCode == 200) then return r.Body end
    end
    return nil
end
UI.HttpGet = httpGet

-- =====================================================================
-- Icons (ไอคอน ID แทนอีโมจิ)
-- =====================================================================
local lucide, lucideTried = nil, false
local function loadLucide()
    if lucideTried then return lucide end
    lucideTried = true
    local ok, res = pcall(function()
        local urls = { UI.LucideURL }
        for _, u in ipairs(UI.LucideMirrors) do if u ~= UI.LucideURL then urls[#urls + 1] = u end end
        for _, u in ipairs(urls) do
            local src = httpGet(u)
            if src then
                local fn = loadstring(src)
                if fn then
                    local ok2, mod = pcall(fn)
                    if ok2 and type(mod) == "table" then return mod end
                end
            end
        end
        return nil
    end)
    if ok and type(res) == "table" and type(res.GetAsset) == "function" then lucide = res end
    return lucide
end
UI.LoadIcons = loadLucide

-- ชื่อไอคอน Lucide เปลี่ยนตามเวอร์ชัน -> ลองหลายชื่อ
local ALIASES = {
    ["bar-chart-3"] = { "bar-chart-3", "chart-column", "bar-chart-2", "bar-chart" },
    ["alert-triangle"] = { "alert-triangle", "triangle-alert" },
    ["panel-left"] = { "panel-left", "sidebar" },
    ["chevrons-up-down"] = { "chevrons-up-down", "chevron-up-down" },
    ["circle-dot"] = { "circle-dot", "dot-circle" },
    ["flask-conical"] = { "flask-conical", "flask-round", "beaker" },
    ["pencil-ruler"] = { "pencil-ruler", "pencil" },
    ["undo-2"] = { "undo-2", "undo", "rotate-ccw" },
    ["clipboard-copy"] = { "clipboard-copy", "copy" },
    ["trash-2"] = { "trash-2", "trash" },
    ["scroll-text"] = { "scroll-text", "file-text", "scroll" },
    ["clapperboard"] = { "clapperboard", "film", "video" },
    ["infinity"] = { "infinity", "repeat" },
    ["layout-list"] = { "layout-list", "list" },
    ["folder-open"] = { "folder-open", "folder" },
}

local function applyIcon(img, icon, px)
    img.Image = ""
    img.ImageRectOffset = Vector2.new(0, 0)
    img.ImageRectSize = Vector2.new(0, 0)
    if icon == nil or icon == "" then return false end
    local ty = type(icon)
    if ty == "number" then
        img.Image = "rbxassetid://" .. tostring(math.floor(icon))
        return true
    end
    if ty == "table" then
        local id = icon.id or icon[1]
        if not id then return false end
        img.Image = (type(id) == "number") and ("rbxassetid://" .. id) or tostring(id)
        if icon.offset then img.ImageRectOffset = icon.offset end
        if icon.size then img.ImageRectSize = icon.size end
        return true
    end
    if ty ~= "string" then return false end
    if icon:find("^rbxassetid://") or icon:find("^rbxthumb://") or icon:find("^rbxasset://") then
        img.Image = icon
        return true
    end
    if icon:match("^%d+$") then
        img.Image = "rbxassetid://" .. icon
        return true
    end
    local custom = UI.CustomIcons[icon]
    if custom ~= nil and custom ~= icon then return applyIcon(img, custom, px) end
    local L = loadLucide()
    if L then
        local size = (px and px > 24) and 96 or 48
        for _, name in ipairs(ALIASES[icon] or { icon }) do
            local ok, asset = pcall(L.GetAsset, name, size)
            if ok and asset and asset.Url then
                img.Image = asset.Url
                img.ImageRectSize = asset.ImageRectSize
                img.ImageRectOffset = asset.ImageRectOffset
                return true
            end
        end
    end
    return false
end


-- ไอคอนวาดเองด้วย Frame (ใช้เมื่อ Lucide โหลดไม่ได้ ไม่ต้องพึ่งเน็ตหรือ asset id)
local VEC = {}
local function bar(parent, color, x, y, w, h, rot, r)
    local f = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h),
        BackgroundColor3 = color, BorderSizePixel = 0, Rotation = rot or 0,
    }, parent)
    if r then corner(f, r) end
    return f
end
VEC["x"] = function(p, c)
    bar(p, c, 0.5, 0.5, 0.78, 0.12, 45, 3)
    bar(p, c, 0.5, 0.5, 0.78, 0.12, -45, 3)
end
VEC["plus"] = function(p, c)
    bar(p, c, 0.5, 0.5, 0.74, 0.12, 0, 3)
    bar(p, c, 0.5, 0.5, 0.12, 0.74, 0, 3)
end
VEC["minus"] = function(p, c) bar(p, c, 0.5, 0.5, 0.74, 0.12, 0, 3) end
VEC["check"] = function(p, c)
    bar(p, c, 0.36, 0.6, 0.3, 0.13, 45, 3)
    bar(p, c, 0.6, 0.52, 0.56, 0.13, -50, 3)
end
VEC["trash-2"] = function(p, c)
    bar(p, c, 0.5, 0.24, 0.8, 0.1, 0, 2)            -- ฝา
    bar(p, c, 0.5, 0.15, 0.28, 0.1, 0, 2)           -- หูจับ
    local body = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromScale(0.62, 0.62),
        BackgroundTransparency = 1, BorderSizePixel = 0,
    }, p)
    corner(body, 4)
    stroke(body, c, 2, 0)
    bar(body, c, 0.33, 0.5, 0.1, 0.5, 0, 2)
    bar(body, c, 0.67, 0.5, 0.1, 0.5, 0, 2)
end
VEC["trash"] = VEC["trash-2"]
VEC["chevron-down"] = function(p, c)
    bar(p, c, 0.34, 0.5, 0.5, 0.13, 45, 3)
    bar(p, c, 0.66, 0.5, 0.5, 0.13, -45, 3)
end
VEC["chevron-up"] = function(p, c)
    bar(p, c, 0.34, 0.5, 0.5, 0.13, -45, 3)
    bar(p, c, 0.66, 0.5, 0.5, 0.13, 45, 3)
end
VEC["chevrons-up-down"] = function(p, c)
    bar(p, c, 0.36, 0.3, 0.38, 0.12, -45, 3)
    bar(p, c, 0.64, 0.3, 0.38, 0.12, 45, 3)
    bar(p, c, 0.36, 0.7, 0.38, 0.12, 45, 3)
    bar(p, c, 0.64, 0.7, 0.38, 0.12, -45, 3)
end
VEC["panel-left"] = function(p, c)
    local box = new("Frame", { Size = UDim2.fromScale(0.86, 0.76), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1 }, p)
    corner(box, 4)
    stroke(box, c, 2, 0)
    bar(p, c, 0.38, 0.5, 0.1, 0.62, 0, 2)
end
VEC["menu"] = function(p, c)
    for i = 1, 3 do bar(p, c, 0.5, 0.2 + (i - 1) * 0.3, 0.76, 0.11, 0, 3) end
end
VEC["search"] = function(p, c)
    local ring = new("Frame", { Size = UDim2.fromScale(0.56, 0.56), Position = UDim2.fromScale(0.1, 0.1),
        BackgroundTransparency = 1 }, p)
    corner(ring, 99)
    stroke(ring, c, 2, 0)
    bar(p, c, 0.78, 0.78, 0.34, 0.12, 45, 3)
end
VEC["copy"] = function(p, c)
    local a = new("Frame", { Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.34, 0.34), BackgroundTransparency = 1 }, p)
    corner(a, 3) stroke(a, c, 2, 0)
    local b = new("Frame", { Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.12, 0.12), BackgroundTransparency = 1 }, p)
    corner(b, 3) stroke(b, c, 2, 0)
end
VEC["clipboard-copy"] = VEC["copy"]
VEC["folder-open"] = function(p, c)
    local f = new("Frame", { Size = UDim2.fromScale(0.84, 0.58), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.56), BackgroundTransparency = 1 }, p)
    corner(f, 3) stroke(f, c, 2, 0)
    bar(p, c, 0.28, 0.24, 0.3, 0.1, 0, 2)
end
-- ไอคอนสำรองของแจ้งเตือน (วงกลม + เครื่องหมาย / กระดิ่ง) ใช้เมื่อ Lucide โหลดไม่ได้
local function ring(p, c)
    local r = new("Frame", { Size = UDim2.fromScale(0.86, 0.86), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1 }, p)
    corner(r, 99) stroke(r, c, 2, 0)
end
VEC["alert-triangle"] = function(p, c)
    ring(p, c)
    bar(p, c, 0.5, 0.38, 0.11, 0.3, 0, 2)
    bar(p, c, 0.5, 0.69, 0.12, 0.12, 0, 6)
end
VEC["info"] = function(p, c)
    ring(p, c)
    bar(p, c, 0.5, 0.31, 0.12, 0.12, 0, 6)
    bar(p, c, 0.5, 0.6, 0.11, 0.3, 0, 2)
end
VEC["bell"] = function(p, c)
    local dome = new("Frame", { Size = UDim2.fromScale(0.56, 0.52), AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0.12), BackgroundTransparency = 1 }, p)
    corner(dome, 99) stroke(dome, c, 2, 0)
    bar(p, c, 0.5, 0.72, 0.8, 0.1, 0, 2)
    bar(p, c, 0.5, 0.88, 0.2, 0.1, 0, 5)
end

local function drawVector(img, icon, color)
    local name = tostring(icon)
    local fn = VEC[name]
    if not fn then
        local al = ALIASES[name]
        if al then for _, n in ipairs(al) do if VEC[n] then fn = VEC[n] break end end end
    end
    if not fn then return false end
    img.Image = ""
    local holder = new("Frame", { Name = "Vec", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, img)
    fn(holder, color or WHITE)
    return true, holder
end

-- สร้าง ImageLabel ไอคอน (ถ้าไอคอนโหลดไม่ได้ จะโชว์จุดเล็กๆ หรือข้อความสำรอง ไม่ใช่อีโมจิ)
local function iconLabel(parent, icon, px, color, fallbackText, extra)
    local img = new("ImageLabel", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(px, px),
        ImageColor3 = color or WHITE, ScaleType = Enum.ScaleType.Fit,
    })
    if extra then
        for k, v in pairs(extra) do img[k] = v end
    end
    img.Parent = parent
    if not applyIcon(img, icon, px) then
        local okVec, holder = false, nil
        if type(icon) == "string" then okVec, holder = drawVector(img, icon, color or WHITE) end
        if okVec then
            -- ให้ไอคอนวาดเองเปลี่ยนสีตาม ImageColor3 (hover ฯลฯ)
            img:GetPropertyChangedSignal("ImageColor3"):Connect(function()
                for _, d in ipairs(holder:GetDescendants()) do
                    if d:IsA("Frame") and d.BackgroundTransparency < 1 then d.BackgroundColor3 = img.ImageColor3 end
                    if d:IsA("UIStroke") then d.Color = img.ImageColor3 end
                end
                for _, d in ipairs(holder:GetChildren()) do
                    if d:IsA("Frame") and d.BackgroundTransparency < 1 then d.BackgroundColor3 = img.ImageColor3 end
                end
            end)
            img:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
                for _, d in ipairs(holder:GetDescendants()) do
                    if d:IsA("Frame") and d.BackgroundTransparency < 1 then d.BackgroundTransparency = img.ImageTransparency end
                    if d:IsA("UIStroke") then d.Transparency = img.ImageTransparency end
                end
            end)
        elseif fallbackText then
            label(img, {
                Size = UDim2.fromScale(1, 1), Text = fallbackText, Font = F_BOLD, TextSize = math.max(10, px - 2),
                TextColor3 = color or WHITE, TextXAlignment = Enum.TextXAlignment.Center,
            })
        else
            local dot = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(math.max(4, px * 0.28), math.max(4, px * 0.28)),
                BackgroundColor3 = color or WHITE, BorderSizePixel = 0,
            }, img)
            corner(dot, 8)
        end
    end
    return img
end
UI.Icon = iconLabel

local CENTER = { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) }

local function mask(name)
    name = tostring(name or "")
    if #name <= 5 then return name end
    return name:sub(1, 2) .. string.rep("*", math.min(#name - 4, 10)) .. name:sub(-2)
end

-- =====================================================================
-- Interaction helpers (ตำแหน่งนิ้ว / Ripple / ลาก)
-- =====================================================================
local function isPress(input)
    local t = input.UserInputType
    return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
end
UI.IsPress = isPress

-- ตำแหน่งที่กดเป็นสัดส่วน 0..1 ภายในปุ่ม (ชดเชย GuiInset ให้ตรงกับ AbsolutePosition)
local function pressRatio(gui, input)
    local inset = GuiService:GetGuiInset()
    local px, py = input.Position.X + inset.X, input.Position.Y + inset.Y
    local ap, as = gui.AbsolutePosition, gui.AbsoluteSize
    local rx = as.X > 0 and clamp((px - ap.X) / as.X, 0, 1) or 0.5
    local ry = as.Y > 0 and clamp((py - ap.Y) / as.Y, 0, 1) or 0.5
    return rx, ry
end

-- วงคลื่นกระจายจากจุดที่นิ้วกด (ใช้ UIAspectRatio จึงเป็นวงกลมเสมอ ไม่ต้องคำนวณพิกเซล)
-- ปิดคลื่นไว้เป็นค่าเริ่มต้น (คลื่นที่ใช้ UIAspectRatio ในแถว AutomaticSize ทำให้แถวสูงขึ้นตอนกดค้าง
-- จนเนื้อหาด้านล่างเลื่อนลง) ถ้าอยากเปิดเอง: UI.RippleEnabled = true
UI.RippleEnabled = false
local function ripple(host, rx, ry, color, alpha)
    if not UI.RippleEnabled then return end
    local r = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(rx, ry), Size = UDim2.fromScale(0, 0),
        BackgroundColor3 = color or WHITE, BackgroundTransparency = alpha or 0.84, BorderSizePixel = 0, ZIndex = 0,
    }, host)
    new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, r)
    new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width }, r)
    tween(r, { Size = UDim2.fromScale(2.2, 2.2) }, 0.6, Enum.EasingStyle.Quint)
    tween(r, { BackgroundTransparency = 1 }, 0.6, Enum.EasingStyle.Sine)
    task.delay(0.65, function() r:Destroy() end)
end
UI.Ripple = ripple

-- ลากแนวนอนบน hit (สำหรับ Slider / ColorPicker) ปิดการเลื่อนหน้าระหว่างลาก
-- ล็อกการลากทั้งระบบ: ลากได้ทีละอย่างเท่านั้น (กันนิ้วลากผ่านตัวอื่นแล้วลากพร้อมกัน)
UI._dragLock = nil

-- hold (วินาที): ต้องกดค้างที่หลอดครบเวลาก่อนถึงจะลากได้ (0/nil = ลากได้ทันที)
-- ถ้านิ้วขยับก่อนครบเวลา = ยกเลิก ปล่อยให้เลื่อนหน้าตามปกติ
local function bindDrag(win, hit, page, onAlpha, onState, hold)
    hold = hold or 0
    local dragging, active, armed, token, startPos = false, nil, false, 0, nil
    local function alphaOf(input)
        return clamp((input.Position.X - hit.AbsolutePosition.X) / math.max(1, hit.AbsoluteSize.X), 0, 1)
    end
    local function arm()
        armed = true
        if page then page.ScrollingEnabled = false end
        if onState then onState(true) end
        onAlpha(alphaOf(active))
    end
    hit.InputBegan:Connect(function(input)
        if not isPress(input) then return end
        if UI._dragLock then return end
        UI._dragLock = input
        dragging, active, armed = true, input, false
        startPos = input.Position
        token = token + 1
        local my = token
        if hold <= 0 then
            arm()
        else
            task.delay(hold, function()
                if dragging and token == my and not armed then arm() end
            end)
        end
        local c
        c = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                c:Disconnect()
                if UI._dragLock == input then UI._dragLock = nil end
                token = token + 1
                local wasArmed = armed
                dragging, armed = false, false
                if page then page.ScrollingEnabled = true end
                if wasArmed and onState then onState(false) end
            end
        end)
    end)
    win:_conn(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        local t = input.UserInputType
        local ok = (t == Enum.UserInputType.MouseMovement and active.UserInputType ~= Enum.UserInputType.Touch)
            or (t == Enum.UserInputType.Touch and input == active)
        if not ok then return end
        if not armed then
            -- ขยับก่อนครบเวลา = ไม่ใช่การกดค้าง -> ยกเลิกรอบนี้ (ปล่อยให้เลื่อนหน้า)
            local d = input.Position - startPos
            if math.abs(d.X) + math.abs(d.Y) > 12 then token = token + 1 end
            return
        end
        onAlpha(alphaOf(input))
    end))
end

-- =====================================================================
-- Button builder (ปุ่มยุบ/เด้งโดยใช้จุดที่นิ้วกดเป็นจุดหมุน + Ripple)
-- =====================================================================
local function makeButton(parent, o)
    local color = o.Color or T.Elem
    -- b = พื้นที่รับสัมผัส (โปร่งใส อยู่กับที่เสมอ), face = ตัวปุ่มที่ยุบ/เด้งจริง
    local b = new("TextButton", {
        Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = o.Size or UDim2.new(1, 0, 0, 34), LayoutOrder = o.LayoutOrder or 0,
    }, parent)
    local face = new("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0, ClipsDescendants = true,
    }, b)
    corner(face, 9)
    stroke(face, WHITE, 1, 0.85)
    local sc = new("UIScale", { Scale = 1 }, face)
    local content = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, face)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder,
    }, content)
    local obj = { Instance = b, Face = face }
    local iconObj
    local function setIcon(icon)
        if iconObj then iconObj:Destroy() iconObj = nil end
        if icon then
            iconObj = iconLabel(content, icon, 15, WHITE)
            iconObj.LayoutOrder = 1
        end
    end
    setIcon(o.Icon)
    local txt = label(content, {
        Text = o.Text or "", Font = F_BOLD, TextSize = o.TextSize or 12, TextColor3 = WHITE,
        AutomaticSize = AX, Size = UDim2.fromOffset(0, 20), LayoutOrder = 2,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    obj.TextLabel = txt
    function obj:SetText(t) txt.Text = tostring(t) end
    function obj:SetColor(c)
        color = c
        tween(face, { BackgroundColor3 = c }, 0.25)
    end
    function obj:SetIcon(icon) setIcon(icon) end
    b.MouseEnter:Connect(function() tween(face, { BackgroundColor3 = color:Lerp(WHITE, 0.12) }, 0.18) end)
    b.MouseLeave:Connect(function()
        tween(face, { BackgroundColor3 = color }, 0.28)
        tween(sc, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
    end)
    b.InputBegan:Connect(function(input)
        if not isPress(input) then return end
        -- ย้ายจุดหมุน (AnchorPoint) ไปที่ตำแหน่งนิ้ว แล้วชดเชย Position ให้ปุ่มไม่ขยับ
        -- UIScale ย่อ/ขยายรอบ AnchorPoint -> ปุ่มยุบเข้าหานิ้วพอดี ไม่เด้งไปทางซ้ายอีก
        local rx, ry = pressRatio(face, input)
        face.AnchorPoint = Vector2.new(rx, ry)
        face.Position = UDim2.fromScale(rx, ry)
        tween(sc, { Scale = 0.94 }, 0.12, Enum.EasingStyle.Quad)
        ripple(face, rx, ry, WHITE, 0.8)
    end)
    b.InputEnded:Connect(function(input)
        if isPress(input) then tween(sc, { Scale = 1 }, 0.5, Enum.EasingStyle.Back) end
    end)
    b.Activated:Connect(function()
        if o.Callback then
            local ok, err = pcall(o.Callback, obj)
            if not ok then warn("[XenonUI] callback error: " .. tostring(err)) end
        end
    end)
    return obj
end

-- =====================================================================
-- Section (การ์ดรวมแถวตั้งค่า)
-- =====================================================================
local Section = {}
Section.__index = Section

local function nextSlot(sec)
    sec._n = sec._n + 1
    local order = sec._n * 2
    if sec._n > 1 then
        new("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.Line, BorderSizePixel = 0, LayoutOrder = order - 1 }, sec.Card)
    end
    return order
end

-- แถวมาตรฐาน: ซ้าย = ชื่อ + คำอธิบาย, ขวา = ตัวควบคุม
-- parent (ไม่บังคับ): วางแถวในที่อื่น เช่น หัวของ Dropdown
local function makeRow(sec, title, desc, ctlSize, clickable, parent)
    local order = 1
    if not parent then order = nextSlot(sec) end
    local row = new(clickable and "TextButton" or "Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = order,
        ClipsDescendants = clickable and true or false,
    }, parent or sec.Card)
    if clickable then
        row.Text = ""
        row.AutoButtonColor = false
        row.InputBegan:Connect(function(input)
            if isPress(input) then
                local rx, ry = pressRatio(row, input)
                ripple(row, rx, ry, WHITE, 0.9)
            end
        end)
    end
    -- เนื้อหาจริงอยู่ใน inner (มี layout) ส่วน row ว่างไว้ให้วาง Ripple
    local inner = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2,
    }, row)
    new("UISizeConstraint", { MinSize = Vector2.new(0, 54) }, inner)
    pad(inner, 14, 10, 14, 10)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder,
    }, inner)
    local block = new("Frame", {
        Size = ctlSize and UDim2.new(1, -(ctlSize.X + 12), 0, 0) or UDim2.new(1, 0, 0, 0),
        AutomaticSize = AY, BackgroundTransparency = 1, LayoutOrder = 1,
    }, inner)
    vlist(block, 2)
    local tl = label(block, {
        Text = title or "", Font = F_BOLD, TextSize = 14, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY,
        TextWrapped = true, LayoutOrder = 1,
    })
    local dl
    if desc and desc ~= "" then
        dl = label(block, {
            Text = desc, TextSize = 12, TextColor3 = T.Muted, Font = F_MED, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY,
            TextWrapped = true, LayoutOrder = 2,
        })
    end
    local ctl
    if ctlSize then
        ctl = new("Frame", { Size = UDim2.fromOffset(ctlSize.X, ctlSize.Y), BackgroundTransparency = 1, LayoutOrder = 2 }, inner)
    end
    return row, ctl, tl, dl
end

local function safe(cb, ...)
    if not cb then return end
    local ok, err = pcall(cb, ...)
    if not ok then warn("[XenonUI] callback error: " .. tostring(err)) end
end

function Section:Toggle(o)
    local TW, TH, KN = 42, 24, 18
    local row, ctl = makeRow(self, o.Title, o.Desc, Vector2.new(TW, TH), true)
    local track = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Elem, BorderSizePixel = 0 }, ctl)
    corner(track, TH / 2)
    stroke(track, T.Line, 1, 0)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(KN, KN), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = WHITE, BorderSizePixel = 0,
    }, track)
    corner(knob, KN / 2)
    local state = o.Default and true or false
    local pressed = false
    local function render(instant)
        local c = state and T.Accent or T.Elem
        local w = pressed and (KN + 5) or KN -- แบบ iOS: ปุ่มยืดออกตอนกดค้าง
        local p = UDim2.fromOffset(state and (TW - 3 - w) or 3, 3)
        local sz = UDim2.fromOffset(w, KN)
        if instant then
            track.BackgroundColor3 = c
            knob.Position, knob.Size = p, sz
        else
            tween(track, { BackgroundColor3 = c }, 0.25)
            tween(knob, { Position = p, Size = sz }, 0.38, Enum.EasingStyle.Back)
        end
    end
    render(true)
    row.InputBegan:Connect(function(input)
        if isPress(input) then
            pressed = true
            render(false)
        end
    end)
    row.InputEnded:Connect(function(input)
        if isPress(input) then
            pressed = false
            render(false)
        end
    end)
    row.Activated:Connect(function()
        state = not state
        pressed = false
        render(false)
        safe(o.Callback, state)
    end)
    local obj = { Row = row }
    function obj.Set(v, silent)
        state = v and true or false
        render(false)
        if not silent then safe(o.Callback, state) end
    end
    function obj.Get() return state end
    return obj
end

function Section:Button(o)
    local w = o.Width or 106
    local row, ctl = makeRow(self, o.Title, o.Desc, Vector2.new(w, 30), false)
    return makeButton(ctl, {
        Text = o.Text or "Run", Icon = o.Icon, Color = o.Color or T.Accent, Callback = o.Callback,
        Size = UDim2.fromScale(1, 1), TextSize = 12,
    })
end

function Section:Input(o)
    local w = o.Width or 190
    local row, ctl = makeRow(self, o.Title, o.Desc, Vector2.new(w, 32), false)
    local holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Elem, BorderSizePixel = 0 }, ctl)
    corner(holder, 9)
    stroke(holder, T.Line, 1, 0)
    local st = stroke(holder, T.Accent, 1.5, 1)
    local box = new("TextBox", {
        Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1,
        Text = o.Default or "", PlaceholderText = o.Placeholder or "", PlaceholderColor3 = Color3.fromRGB(150, 150, 176),
        TextColor3 = T.Text, Font = F_MED, TextSize = 13, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    }, holder)
    box.Focused:Connect(function() tween(st, { Transparency = 0 }, 0.2) end)
    box.FocusLost:Connect(function(enter)
        tween(st, { Transparency = 1 }, 0.2)
        safe(o.Callback, box, enter)
    end)
    return box
end

function Section:Stepper(o)
    local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
    local value = clamp(o.Default or min, min, max)
    local row, ctl = makeRow(self, o.Title, o.Desc, Vector2.new(o.Width or 140, 32), false)
    local holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Elem, BorderSizePixel = 0 }, ctl)
    corner(holder, 9)
    stroke(holder, T.Line, 1, 0)
    local function fmt(v)
        if v % 1 == 0 then return tostring(math.floor(v + 0.5)) end
        return string.format("%.1f", v)
    end
    local box = new("TextBox", {
        Size = UDim2.new(1, -64, 1, 0), Position = UDim2.fromOffset(32, 0), BackgroundTransparency = 1,
        Text = fmt(value), TextColor3 = T.Text, Font = F_BOLD, TextSize = 13, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, holder)
    local function setValue(v, silent)
        v = clamp(math.floor(v * 100 + 0.5) / 100, min, max)
        value = v
        box.Text = fmt(v)
        if not silent then safe(o.Callback, v) end
    end
    local function stepBtn(icon, fb, x, dir)
        local b = new("TextButton", {
            Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
            Size = UDim2.new(0, 32, 1, 0), Position = UDim2.new(x, x == 1 and -32 or 0, 0, 0),
        }, holder)
        local ic = iconLabel(b, icon, 14, T.Muted, fb, CENTER)
        b.MouseEnter:Connect(function() tween(ic, { ImageColor3 = T.Text }, 0.15) end)
        b.MouseLeave:Connect(function() tween(ic, { ImageColor3 = T.Muted }, 0.15) end)
        b.Activated:Connect(function() setValue(value + dir * step) end)
    end
    stepBtn("minus", "-", 0, -1)
    stepBtn("plus", "+", 1, 1)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then setValue(n) else box.Text = fmt(value) end
    end)
    return {
        Box = box, Row = row,
        Get = function() return value end,
        Set = function(v) setValue(v, true) end,
    }
end

function Section:Label(o)
    if type(o) == "string" then o = { Text = o } end
    local order = nextSlot(self)
    local f = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, LayoutOrder = order }, self.Card)
    pad(f, 14, 10, 14, 10)
    return label(f, {
        Text = o.Text or "", TextSize = o.TextSize or 12, TextColor3 = o.Color or T.Muted, Font = o.Font or F_REG,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
        RichText = o.RichText or false,
    })
end

-- แถวปุ่มเต็มความกว้าง แบ่งเท่าๆ กัน: list = { {Text, Icon, Color, Callback}, ... }
function Section:Actions(list)
    local order = nextSlot(self)
    local f = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, LayoutOrder = order }, self.Card)
    pad(f, 12, 10, 12, 10)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
    }, f)
    local n = #list
    local out = {}
    for i, o in ipairs(list) do
        o.Size = UDim2.new(1 / n, -(8 * (n - 1)) / n, 0, o.Height or 34)
        o.LayoutOrder = i
        out[i] = makeButton(f, o)
    end
    return out
end

function Section:Action(o)
    return self:Actions({ o })[1]
end

-- รายการเลื่อนได้ (ไฟล์บันทึก / แถวแอคชัน / Log ฯลฯ)
-- มีหัวรายการ แตะเพื่อพับ/กางได้ (ถ้าข้อมูลเยอะ)  o.Title = ชื่อหัว, o.Collapsed = เริ่มแบบพับ, o.Collapsible = false = ไม่มีหัว
function Section:List(o)
    o = o or {}
    local order = nextSlot(self)
    local height = o.Height or 150
    local collapsible = o.Collapsible ~= false
    local open = not o.Collapsed
    local wrap = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, LayoutOrder = order }, self.Card)
    vlist(wrap, 0)
    local head, titleLbl, cntLbl, chev
    if collapsible then
        head = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
            Text = "", ClipsDescendants = true, LayoutOrder = 1,
        }, wrap)
        head.InputBegan:Connect(function(input)
            if isPress(input) then
                local rx, ry = pressRatio(head, input)
                ripple(head, rx, ry, WHITE, 0.9)
            end
        end)
        titleLbl = label(head, {
            Text = o.Title or "รายการ", Font = F_BOLD, TextSize = 13, Position = UDim2.fromOffset(14, 0),
            Size = UDim2.new(1, -120, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
        })
        cntLbl = label(head, {
            Text = "", Font = F_MED, TextSize = 12, TextColor3 = T.Muted, AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -38, 0.5, 0), Size = UDim2.fromOffset(70, 20), TextXAlignment = Enum.TextXAlignment.Right,
        })
        chev = iconLabel(head, "chevron-down", 14, T.Muted, "v", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) })
        chev.Rotation = open and 180 or 0
    end
    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, open and (height + 20) or 0), BackgroundTransparency = 1, ClipsDescendants = true,
        LayoutOrder = 2, Visible = open,
    }, wrap)
    local inner = new("Frame", { Size = UDim2.new(1, 0, 0, height + 20), BackgroundTransparency = 1 }, holder)
    pad(inner, 10)
    local sf = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Inset, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Muted, CanvasSize = UDim2.new(), AutomaticCanvasSize = AY,
        ScrollingDirection = Enum.ScrollingDirection.Y, ElasticBehavior = Enum.ElasticBehavior.Always,
    }, inner)
    corner(sf, 9)
    stroke(sf, T.Line, 1, 0)
    pad(sf, 6, 6, 8, 6)
    vlist(sf, 4)
    local list = { Frame = sf, Holder = holder, Wrap = wrap }

    local function recount()
        if not cntLbl then return end
        local n = 0
        for _, c in ipairs(sf:GetChildren()) do
            if c:IsA("TextButton") then n = n + 1 end
        end
        cntLbl.Text = n > 0 and (n .. " รายการ") or ""
    end
    sf.ChildAdded:Connect(function() task.defer(recount) end)
    sf.ChildRemoved:Connect(function() task.defer(recount) end)

    function list:IsOpen() return open end
    function list:Set(v)
        v = v and true or false
        if v == open then return end
        open = v
        if chev then tween(chev, { Rotation = open and 180 or 0 }, 0.35, Enum.EasingStyle.Quint) end
        if open then
            holder.Visible = true
            tween(holder, { Size = UDim2.new(1, 0, 0, height + 20) }, 0.4, Enum.EasingStyle.Quint)
        else
            tween(holder, { Size = UDim2.new(1, 0, 0, 0) }, 0.3, Enum.EasingStyle.Quint)
            task.delay(0.32, function()
                if not open then holder.Visible = false end
            end)
        end
    end
    function list:Open() self:Set(true) end
    function list:Close() self:Set(false) end
    function list:Toggle() self:Set(not open) end
    function list:SetTitle(t) if titleLbl then titleLbl.Text = tostring(t) end end

    if head then head.Activated:Connect(function() list:Toggle() end) end

    function list:Clear()
        for _, c in ipairs(sf:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
    end
    function list:Note(text)
        return label(sf, {
            Text = text, TextSize = 12, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 30),
            TextXAlignment = Enum.TextXAlignment.Center,
        })
    end
    function list:Add(it)
        local sel = it.Selected and true or false
        local base = sel and T.Accent or T.Elem
        local b = new("TextButton", {
            Size = UDim2.new(1, 0, 0, it.Height or 34), BackgroundColor3 = base, BorderSizePixel = 0, AutoButtonColor = false,
            Text = it.Text or "", TextColor3 = WHITE, Font = F_MED, TextSize = it.TextSize or 13, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = it.Order or 0,
        }, sf)
        corner(b, 8)
        stroke(b, sel and T.Accent:Lerp(WHITE, 0.25) or T.Line, 1, 0)
        pad(b, 12, 0, 8, 0)
        b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = base:Lerp(WHITE, 0.1) }, 0.15) end)
        b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = base }, 0.2) end)
        b.Activated:Connect(function() safe(it.Callback, b) end)
        return b
    end
    return list
end

-- =====================================================================
-- คอนโทรลใหม่ (v2.0)
-- =====================================================================
local function autoFrame(sec, padv, gap)
    local order = nextSlot(sec)
    local f = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, LayoutOrder = order }, sec.Card)
    if padv then pad(f, padv[1], padv[2], padv[3], padv[4]) end
    if gap then vlist(f, gap) end
    return f
end

function Section:Divider(text)
    local order = nextSlot(self)
    local f = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = order }, self.Card)
    pad(f, 14, 0, 14, 0)
    label(f, {
        Text = string.upper(tostring(text or "")), Font = F_BOLD, TextSize = 11, TextColor3 = T.Muted,
        Size = UDim2.fromScale(1, 1),
    })
    return f
end

function Section:Paragraph(o)
    o = o or {}
    local f = autoFrame(self, { 14, 12, 14, 12 }, 4)
    local tl
    if o.Title then
        tl = label(f, { Text = o.Title, Font = F_BOLD, TextSize = 14, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, TextWrapped = true, LayoutOrder = 1 })
    end
    local bl = label(f, {
        Text = tostring(o.Text or ""), Font = F_MED, TextSize = 12, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = AY, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2, RichText = o.RichText or false,
    })
    return { Row = f, Title = tl, Body = bl, SetText = function(t) bl.Text = tostring(t) end }
end

function Section:Progress(o)
    o = o or {}
    local f = autoFrame(self, { 14, 12, 14, 12 }, 8)
    local head = new("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 1 }, f)
    label(head, { Text = o.Title or "", Font = F_BOLD, TextSize = 14, Size = UDim2.new(1, -60, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
    local val = label(head, {
        Text = "0%", Font = F_MED, TextSize = 12, TextColor3 = T.Muted, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Right,
    })
    local track = new("Frame", { Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = T.Elem, BorderSizePixel = 0, LayoutOrder = 2, ClipsDescendants = true }, f)
    corner(track, 4)
    local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = o.Color or T.Accent, BorderSizePixel = 0 }, track)
    corner(fill, 4)
    local function set(a, text)
        a = clamp(a or 0, 0, 1)
        tween(fill, { Size = UDim2.fromScale(a, 1) }, 0.45, Enum.EasingStyle.Quint)
        val.Text = text or (tostring(math.floor(a * 100 + 0.5)) .. "%")
    end
    set(o.Default or 0)
    return { Row = f, Set = set }
end

function Section:Slider(o)
    o = o or {}
    local min, max = o.Min or 0, o.Max or 100
    local step = o.Step or 1
    local suffix = o.Suffix or ""
    local value = clamp(o.Default or min, min, max)
    local accent = o.Color or T.Accent
    local dec = o.Decimals
    if dec == nil then
        if step % 1 == 0 then dec = 0 else
            local d = tostring(step):match("%.(%d+)")
            dec = d and #d or 2
        end
    end
    local function fmt(v) return string.format("%." .. dec .. "f", v) .. suffix end

    local f = autoFrame(self, { 14, 12, 14, 12 }, 4)
    local head = new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 1 }, f)
    label(head, { Text = o.Title or "", Font = F_BOLD, TextSize = 14, Size = UDim2.new(1, -80, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
    local box = new("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(72, 22),
        BackgroundColor3 = T.Elem, BorderSizePixel = 0, Text = "", TextColor3 = T.Text, Font = F_BOLD, TextSize = 12, ClearTextOnFocus = false,
    }, head)
    corner(box, 7)
    if o.Desc and o.Desc ~= "" then
        label(f, { Text = o.Desc, TextSize = 12, TextColor3 = T.Muted, Font = F_MED, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, TextWrapped = true, LayoutOrder = 2 })
    end
    local hit = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 3 }, f)
    local track = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = T.Elem, BorderSizePixel = 0,
    }, hit)
    corner(track, 3)
    local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = accent, BorderSizePixel = 0 }, track)
    corner(fill, 3)
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = WHITE, BorderSizePixel = 0,
    }, track)
    corner(knob, 9)
    stroke(knob, accent, 2, 0)
    local ks = new("UIScale", { Scale = 1 }, knob)

    local function apply(v, silent, instant)
        v = clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
        v = tonumber(string.format("%." .. dec .. "f", v)) or v
        local changed = v ~= value
        value = v
        local a = (max > min) and (v - min) / (max - min) or 0
        if instant then
            fill.Size = UDim2.fromScale(a, 1)
            knob.Position = UDim2.fromScale(a, 0.5)
        else
            tween(fill, { Size = UDim2.fromScale(a, 1) }, 0.12, Enum.EasingStyle.Quad)
            tween(knob, { Position = UDim2.fromScale(a, 0.5) }, 0.12, Enum.EasingStyle.Quad)
        end
        box.Text = fmt(v)
        if changed and not silent then safe(o.Callback, v) end
    end
    apply(value, true, true)
    bindDrag(self.Window, hit, self.Tab.Page, function(a)
        apply(min + a * (max - min))
    end, function(down)
        tween(ks, { Scale = down and 1.28 or 1 }, 0.25, Enum.EasingStyle.Back)
    end, UI.SliderHoldTime)
    box.Focused:Connect(function() box.Text = tostring(value) end)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text:match("-?%d+%.?%d*"))
        if n then apply(n) else box.Text = fmt(value) end
    end)
    return { Row = f, Get = function() return value end, Set = function(v) apply(v, true) end }
end

-- ส่วนที่กางออกได้ใต้แถว (ใช้ร่วมกันใน Dropdown / ColorPicker)
local function makeCollapsePanel(wrap)
    local panel = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
        LayoutOrder = 2, Visible = false,
    }, wrap)
    local open = false
    local ctl = {}
    function ctl.Set(v, height)
        open = v
        if v then
            panel.Visible = true
            tween(panel, { Size = UDim2.new(1, 0, 0, height) }, 0.4, Enum.EasingStyle.Quint)
        else
            tween(panel, { Size = UDim2.new(1, 0, 0, 0) }, 0.3, Enum.EasingStyle.Quint)
            task.delay(0.32, function()
                if not open then panel.Visible = false end
            end)
        end
    end
    function ctl.IsOpen() return open end
    return panel, ctl
end

function Section:Dropdown(o)
    o = o or {}
    local multi = o.Multi and true or false
    local options = o.Options or {}
    local selected, value = {}, nil
    if multi then
        for _, v in ipairs(o.Default or {}) do selected[v] = true end
    else
        value = o.Default
    end
    local order = nextSlot(self)
    local wrap = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, LayoutOrder = order }, self.Card)
    vlist(wrap, 0)
    local row, ctl = makeRow(self, o.Title, o.Desc, Vector2.new(o.Width or 150, 32), true, wrap)
    local pill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Elem, BorderSizePixel = 0 }, ctl)
    corner(pill, 9)
    local pst = stroke(pill, T.Line, 1, 0)
    local vl = label(pill, {
        Text = "", Font = F_MED, TextSize = 12, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -34, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local chev = iconLabel(pill, "chevron-down", 14, T.Muted, "v", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0) })
    local panel, pc = makeCollapsePanel(wrap)
    local scroll = new("ScrollingFrame", {
        Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 0, 100), BackgroundColor3 = T.Inset, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = T.Muted, CanvasSize = UDim2.new(), AutomaticCanvasSize = AY,
        ScrollingDirection = Enum.ScrollingDirection.Y, ElasticBehavior = Enum.ElasticBehavior.Always,
    }, panel)
    corner(scroll, 9)
    stroke(scroll, T.Line, 1, 0)
    pad(scroll, 5, 5, 5, 5)
    vlist(scroll, 3)

    local btns = {}
    local function isSel(v)
        if multi then return selected[v] == true end
        return value == v
    end
    local function list()
        local t = {}
        for _, op in ipairs(options) do
            if selected[op] then t[#t + 1] = op end
        end
        return t
    end
    local function text()
        if multi then
            local t = {}
            for _, op in ipairs(options) do
                if selected[op] then t[#t + 1] = tostring(op) end
            end
            if #t > 2 then return t[1] .. ", " .. t[2] .. " +" .. (#t - 2) end   -- เลือกเยอะ: สรุปสั้นๆ ไม่ให้ล้นช่อง
            return #t > 0 and table.concat(t, ", ") or (o.Placeholder or "None")
        end
        return value ~= nil and tostring(value) or (o.Placeholder or "Select")
    end
    local function paint()
        vl.Text = text()
        for i, b in ipairs(btns) do
            local on = isSel(options[i])
            tween(b, { BackgroundTransparency = on and 0 or 1 }, 0.2)
            tween(b, { TextColor3 = on and WHITE or T.Muted }, 0.2)
        end
    end
    local function panelHeight()
        local content = #options * 33 - 3 + 10
        local view = math.min(math.max(content, 20), o.MaxHeight or 180)
        scroll.Size = UDim2.new(1, -24, 0, view)
        return view + 12
    end
    local function setOpen(v)
        pc.Set(v, v and panelHeight() or 0)
        tween(chev, { Rotation = v and 180 or 0 }, 0.4, Enum.EasingStyle.Quint)
        tween(pst, { Color = v and T.Accent or T.Line }, 0.25)
    end
    local function fire()
        if multi then safe(o.Callback, list()) else safe(o.Callback, value) end
    end
    local function build()
        for _, b in ipairs(btns) do b:Destroy() end
        btns = {}
        for i, op in ipairs(options) do
            local b = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.Accent, BackgroundTransparency = 1, BorderSizePixel = 0,
                AutoButtonColor = false, Text = tostring(op), Font = F_MED, TextSize = 12, TextColor3 = T.Muted,
                TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, ClipsDescendants = true,
            }, scroll)
            corner(b, 7)
            pad(b, 10, 0, 10, 0)
            b.InputBegan:Connect(function(input)
                if isPress(input) then
                    local rx, ry = pressRatio(b, input)
                    ripple(b, rx, ry, WHITE, 0.8)
                end
            end)
            b.MouseEnter:Connect(function()
                if not isSel(op) then tween(b, { BackgroundTransparency = 0.82 }, 0.12) end
            end)
            b.MouseLeave:Connect(function()
                if not isSel(op) then tween(b, { BackgroundTransparency = 1 }, 0.18) end
            end)
            b.Activated:Connect(function()
                if multi then
                    selected[op] = (not selected[op]) and true or nil
                else
                    value = op
                    setOpen(false)
                end
                paint()
                fire()
            end)
            btns[i] = b
        end
        paint()
    end
    build()
    row.Activated:Connect(function() setOpen(not pc.IsOpen()) end)

    local obj = { Row = wrap }
    -- กดหัว Dropdown เพื่อเปิด/ปิดได้เสมอ + สั่งจากโค้ดได้
    function obj.IsOpen() return pc.IsOpen() end
    function obj.Open() setOpen(true) end
    function obj.Close() setOpen(false) end
    function obj.Toggle() setOpen(not pc.IsOpen()) end
    function obj.Get() return multi and list() or value end
    function obj.Set(v, silent)
        if multi then
            selected = {}
            for _, x in ipairs(v or {}) do selected[x] = true end
        else
            value = v
        end
        paint()
        if not silent then fire() end
    end
    function obj.Refresh(newOptions, keep)
        options = newOptions or {}
        if not keep then
            selected, value = {}, nil
        end
        build()
        if pc.IsOpen() then setOpen(true) end
    end
    return obj
end

function Section:Keybind(o)
    o = o or {}
    local key = o.Default
    local row, ctl = makeRow(self, o.Title, o.Desc, Vector2.new(o.Width or 104, 32), false)
    local listening = false
    local function nameOf(k) return k and k.Name or "None" end
    local btn
    btn = makeButton(ctl, {
        Text = nameOf(key), Color = T.Elem, Size = UDim2.fromScale(1, 1), TextSize = 12,
        Callback = function()
            if listening then return end
            listening = true
            btn:SetText("...")
            btn:SetColor(T.Accent)
        end,
    })
    self.Window:_conn(UserInputService.InputBegan:Connect(function(input, gp)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if listening then
            listening = false
            if input.KeyCode == Enum.KeyCode.Backspace then
                key = nil
            elseif input.KeyCode ~= Enum.KeyCode.Escape then
                key = input.KeyCode
            end
            btn:SetText(nameOf(key))
            btn:SetColor(T.Elem)
            safe(o.Changed, key)
            return
        end
        if not gp and key and input.KeyCode == key then safe(o.Callback, key) end
    end))
    return {
        Row = row, Get = function() return key end,
        Set = function(k) key = k; btn:SetText(nameOf(k)) end,
    }
end

function Section:ColorPicker(o)
    o = o or {}
    local h, s, v = (o.Default or T.Accent):ToHSV()
    local color = Color3.fromHSV(h, s, v)
    local order = nextSlot(self)
    local wrap = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, LayoutOrder = order }, self.Card)
    vlist(wrap, 0)
    local row, ctl = makeRow(self, o.Title, o.Desc, Vector2.new(58, 28), true, wrap)
    local sw = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, ctl)
    corner(sw, 9)
    stroke(sw, WHITE, 1, 0.7)
    local panel, pc = makeCollapsePanel(wrap)
    local holder = new("Frame", { Position = UDim2.fromOffset(14, 2), Size = UDim2.new(1, -28, 0, 92), BackgroundTransparency = 1 }, panel)
    vlist(holder, 4)

    local function mkTrack(order2, onAlpha)
        local hit = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order2 }, holder)
        local tr = new("Frame", {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 10),
            BackgroundColor3 = WHITE, BorderSizePixel = 0,
        }, hit)
        corner(tr, 5)
        local g = new("UIGradient", {}, tr)
        local knob = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(18, 18),
            BackgroundColor3 = WHITE, BorderSizePixel = 0,
        }, tr)
        corner(knob, 9)
        stroke(knob, Color3.fromRGB(40, 40, 56), 2, 0)
        local ks = new("UIScale", { Scale = 1 }, knob)
        bindDrag(self.Window, hit, self.Tab.Page, onAlpha, function(down)
            tween(ks, { Scale = down and 1.25 or 1 }, 0.22, Enum.EasingStyle.Back)
        end)
        return { Gradient = g, Knob = knob }
    end

    local hueT, satT, valT
    local function refresh(silent)
        color = Color3.fromHSV(h, s, v)
        sw.BackgroundColor3 = color
        hueT.Knob.Position = UDim2.fromScale(h, 0.5)
        satT.Knob.Position = UDim2.fromScale(s, 0.5)
        valT.Knob.Position = UDim2.fromScale(v, 0.5)
        satT.Gradient.Color = ColorSequence.new(Color3.fromHSV(h, 0, v), Color3.fromHSV(h, 1, v))
        valT.Gradient.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(h, s, 1))
        if not silent then safe(o.Callback, color) end
    end
    hueT = mkTrack(1, function(a) h = a; refresh() end)
    satT = mkTrack(2, function(a) s = a; refresh() end)
    valT = mkTrack(3, function(a) v = a; refresh() end)
    local seq = {}
    for i = 0, 6 do seq[#seq + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(math.min(i / 6, 0.9999), 1, 1)) end
    seq[#seq] = ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1))
    hueT.Gradient.Color = ColorSequence.new(seq)
    refresh(true)
    row.Activated:Connect(function() pc.Set(not pc.IsOpen(), 100) end)
    return {
        Row = wrap, Get = function() return color end,
        Set = function(c, silent)
            h, s, v = c:ToHSV()
            refresh(silent ~= false and true or false)
        end,
    }
end

-- =====================================================================
-- Tab
-- =====================================================================
local Tab = {}
Tab.__index = Tab

function Tab:Section(o)
    o = o or {}
    self._n = self._n + 1
    local wrap = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, LayoutOrder = self._n }, self.Page)
    vlist(wrap, 9)
    local head
    if o.Title then
        head = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 1 }, wrap)
        local x = 2
        if o.Icon then
            local tile = new("Frame", {
                Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = o.Color or self.Color, BorderSizePixel = 0,
            }, head)
            corner(tile, 9)
            iconLabel(tile, o.Icon, 18, WHITE, nil, CENTER)
            x = 44
        end
        local rightPad = o.Collapsible and 30 or 0
        if o.Desc then
            label(head, {
                Text = o.Title, Font = F_BOLD, TextSize = 14, Position = UDim2.fromOffset(x, 1), Size = UDim2.new(1, -(x + rightPad), 0, 18),
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            label(head, {
                Text = o.Desc, TextSize = 12, TextColor3 = T.Muted, Position = UDim2.fromOffset(x, 19), Size = UDim2.new(1, -(x + rightPad), 0, 16),
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
        else
            label(head, {
                Text = o.Title, Font = F_BOLD, TextSize = 14, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -(x + rightPad), 1, 0),
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
        end
    end
    local shell
    if o.Collapsible and head then
        shell = new("Frame", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = 2,
        }, wrap)
    end
    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundColor3 = T.Card, BorderSizePixel = 0, LayoutOrder = 2,
    }, shell or wrap)
    corner(card, 12)
    stroke(card, T.Line, 1)
    vlist(card, 0)

    if shell then
        local open = not o.Collapsed
        local tk = 0
        local chev = iconLabel(head, "chevron-down", 16, T.Muted, "v", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
        })
        chev.Rotation = open and 0 or -90
        if not open then
            shell.AutomaticSize = Enum.AutomaticSize.None
            shell.Size = UDim2.new(1, 0, 0, 0)
            shell.ClipsDescendants = true
        end
        local hb = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, head)
        hb.Activated:Connect(function()
            local S = (self.Window.M and self.Window.M.S) or 1
            local h = card.AbsoluteSize.Y / S
            tk = tk + 1
            local my = tk
            open = not open
            tween(chev, { Rotation = open and 0 or -90 }, 0.4, Enum.EasingStyle.Quint)
            shell.ClipsDescendants = true
            shell.AutomaticSize = Enum.AutomaticSize.None
            if open then
                tween(shell, { Size = UDim2.new(1, 0, 0, h) }, 0.42, Enum.EasingStyle.Quint)
                task.delay(0.45, function()
                    if tk == my then
                        shell.AutomaticSize = AY
                        shell.Size = UDim2.new(1, 0, 0, 0)
                        shell.ClipsDescendants = false
                    end
                end)
            else
                shell.Size = UDim2.new(1, 0, 0, h)
                tween(shell, { Size = UDim2.new(1, 0, 0, 0) }, 0.36, Enum.EasingStyle.Quint)
            end
        end)
    end
    return setmetatable({ Tab = self, Window = self.Window, Card = card, _n = 0, Color = o.Color or self.Color }, Section)
end

-- =====================================================================
-- Window
-- =====================================================================
local Window = {}
Window.__index = Window

local SW_EXP, SW_COL = 204, 66
local TOP_H = 48

function Window:_conn(c)
    self._conns[#self._conns + 1] = c
    return c
end

function Window:_metrics()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local mobile = UI.ForceMobile
    if mobile == nil then mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled end
    local w, h, s
    if mobile then
        local portrait = vp.Y > vp.X
        if self.Maximized then
            w, h = vp.X * 0.96, vp.Y * 0.94
        else
            -- มือถือ: ใหญ่เกือบเต็มจอ (ไม่ต่ำกว่า 70%)
            w = vp.X * (portrait and 0.95 or 0.76)
            h = vp.Y * (portrait and 0.72 or 0.82)
        end
        s = UI.UiScale or 1
    else
        if self.Maximized then
            w, h = vp.X - 40, vp.Y - 40
        else
            w = clamp(vp.X * 0.6, 640, 980)
            h = clamp(vp.Y * 0.74, 420, 640)
        end
        w = math.min(w, vp.X - 16)
        h = math.min(h, vp.Y - 16)
        s = UI.UiScale or 1
    end
    -- ปัดขนาดเป็นพิกเซลเต็ม + ให้ความกว้าง/สูงมี parity เดียวกับจอ -> หน้าต่างไม่ครึ่งพิกเซล (ตัวอักษรไม่เบลอ)
    w, h = math.floor(w), math.floor(h)
    if (w - math.floor(vp.X)) % 2 ~= 0 then w = w - 1 end
    if (h - math.floor(vp.Y)) % 2 ~= 0 then h = h - 1 end
    return { W = w, H = h, S = s, DW = w / s, DH = h / s, Mobile = mobile, VP = vp }
end

function Window:_tweenWin(props, t, style, dir)
    if self._winTween then self._winTween:Cancel() end
    self._winTween = tween(self.Win, props, t, style, dir)
end

function Window:_bubblePos()
    local m = self.M
    local R = self.BubbleSize / 2
    local margin = 10
    local y = clamp(self.BubbleY * m.VP.Y, R + margin, m.VP.Y - R - margin)
    if self.BubbleSide == "left" then
        return UDim2.new(0, margin + R, 0, y)
    end
    return UDim2.new(1, -(margin + R), 0, y)
end

function Window:Relayout(animate)
    local m = self:_metrics()
    self.M = m
    self.BubbleSize = m.Mobile and 56 or 52
    local function set(o, props)
        if animate then
            tween(o, props, 0.35, Enum.EasingStyle.Quint)
        else
            for k, v in pairs(props) do o[k] = v end
        end
    end
    local collapse = self._userCollapse
    if collapse == nil then collapse = m.DW < 700 end
    if collapse ~= self.SidebarCollapsed then self:SetSidebar(collapse, not animate) end
    -- canvas + scale ต้องตรงกับขนาดจอเสมอ (แม้ตอนย่ออยู่ จะได้ขยายกลับถูกขนาด)
    set(self.Canvas, { Size = UDim2.fromOffset(m.DW, m.DH) })
    set(self._scale, { Scale = m.S })
    if self.State == "bubble" then
        set(self.Win, { Position = self:_bubblePos() })
    else
        set(self.Win, { Size = UDim2.fromOffset(m.W, m.H), Position = UDim2.new(0.5, self.OX, 0.5, self.OY) })
    end
    -- breadcrumb / status pill
    local mainW = m.DW - (self.SidebarCollapsed and SW_COL or SW_EXP)
    local showPill = mainW > 560
    self._pill.Visible = showPill
    self._crumb.Size = UDim2.new(1, -(60 + 104 + (showPill and 186 or 0)), 1, 0)
    self._toasts.Size = UDim2.new(0, m.Mobile and 250 or 300, 1, -28)
end

function Window:SetSidebar(collapsed, instant)
    self.SidebarCollapsed = collapsed
    local w = collapsed and SW_COL or SW_EXP
    local fade = collapsed and 1 or 0
    local function set(o, props)
        if instant then
            for k, v in pairs(props) do o[k] = v end
        else
            tween(o, props, 0.38, Enum.EasingStyle.Quint)
        end
    end
    set(self._sidebar, { Size = UDim2.new(0, w, 1, 0) })
    set(self._main, { Position = UDim2.fromOffset(w, 0), Size = UDim2.new(1, -w, 1, 0) })
    for _, t in ipairs(self.TabList) do set(t.Label, { TextTransparency = fade }) end
    for _, c in pairs(self.Categories) do
        set(c.Label, { TextTransparency = fade, Size = UDim2.new(1, 0, 0, collapsed and 8 or 24) })
    end
    for _, o in ipairs(self._fadeText) do set(o, { TextTransparency = fade }) end
    set(self._userChevron, { ImageTransparency = fade })
end

function Window:SetBreadcrumb(cat, name)
    self._crumb.Text = string.format('<font color="#%s">%s</font>   >   %s', T.Muted:ToHex(), cat, name)
end

function Window:SelectTab(name, instant)
    local tab = self.Tabs[name]
    if not tab or self.CurrentTab == tab then return end
    local prev = self.CurrentTab
    self.CurrentTab = tab
    local dir = 1
    if prev then
        local pi, ni = 0, 0
        for i, t in ipairs(self.TabList) do
            if t == prev then pi = i end
            if t == tab then ni = i end
        end
        dir = (ni >= pi) and 1 or -1
    end
    for _, t in ipairs(self.TabList) do
        local on = (t == tab)
        t.Page.Visible = on
        tween(t.Button, { BackgroundTransparency = on and 0 or 1 }, 0.2)
        tween(t.Label, { TextColor3 = on and T.Text or T.Muted }, 0.2)
        if t.Ind then tween(t.Ind, { Size = UDim2.fromOffset(3, on and 18 or 0) }, 0.4, Enum.EasingStyle.Quint) end
    end
    self:SetBreadcrumb(tab.Category, tab.Name)
    if not instant then
        -- สไลด์เข้าตามทิศที่เปลี่ยนแท็บ (ลง = เลื่อนขึ้นมา, ขึ้น = เลื่อนลงมา)
        tab.Page.Position = UDim2.fromOffset(0, 22 * dir)
        tween(tab.Page, { Position = UDim2.fromOffset(0, 0) }, 0.55, Enum.EasingStyle.Quint)
        self._curtain.BackgroundTransparency = 0
        tween(self._curtain, { BackgroundTransparency = 1 }, 0.32, Enum.EasingStyle.Sine)
    end
end

function Window:AddTab(o)
    local catName = o.Category or "General"
    local cat = self.Categories[catName]
    if not cat then
        self._catSeq = self._catSeq + 1
        local lbl = label(self._tabScroll, {
            Text = catName, Font = F_BOLD, TextSize = 12, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, self.SidebarCollapsed and 8 or 24),
            LayoutOrder = self._catSeq * 1000, TextTransparency = self.SidebarCollapsed and 1 or 0,
            TextYAlignment = Enum.TextYAlignment.Bottom,
        })
        pad(lbl, 8, 0, 0, 4)
        cat = { Name = catName, Label = lbl, Seq = self._catSeq, N = 0 }
        self.Categories[catName] = cat
    end
    cat.N = cat.N + 1
    local color = o.Color or T.Accent

    local btn = new("TextButton", {
        Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = T.Elem, BackgroundTransparency = 1,
        BorderSizePixel = 0, LayoutOrder = cat.Seq * 1000 + cat.N,
    }, self._tabScroll)
    corner(btn, 11)
    btn.ClipsDescendants = true
    local ind = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(3, 0),
        BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3,
    }, btn)
    corner(ind, 2)
    local tile = new("Frame", {
        Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0),
        BackgroundColor3 = color, BorderSizePixel = 0,
    }, btn)
    corner(tile, 9)
    iconLabel(tile, o.Icon, 17, WHITE, nil, CENTER)
    local lbl = label(btn, {
        Text = o.Name, Font = F_MED, TextSize = 13, TextColor3 = T.Muted, Position = UDim2.fromOffset(49, 0),
        Size = UDim2.new(1, -54, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, TextTransparency = self.SidebarCollapsed and 1 or 0,
    })

    local page = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Muted, ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = AY, Visible = false, ElasticBehavior = Enum.ElasticBehavior.Always, ScrollBarImageTransparency = 0.35,
    }, self._pages)
    pad(page, 16, 14, 16, 20)
    vlist(page, 16)

    local tab = setmetatable({
        Window = self, Name = o.Name, Category = catName, Page = page, Button = btn, Label = lbl, Color = color, Ind = ind, _n = 0,
    }, Tab)
    self.Tabs[o.Name] = tab
    self.TabList[#self.TabList + 1] = tab

    btn.MouseEnter:Connect(function()
        if self.CurrentTab ~= tab then tween(btn, { BackgroundTransparency = 0.6 }, 0.15) end
    end)
    btn.MouseLeave:Connect(function()
        if self.CurrentTab ~= tab then tween(btn, { BackgroundTransparency = 1 }, 0.2) end
    end)
    btn.InputBegan:Connect(function(input)
        if isPress(input) then
            local rx, ry = pressRatio(btn, input)
            ripple(btn, rx, ry, WHITE, 0.88)
        end
    end)
    btn.Activated:Connect(function() self:SelectTab(o.Name) end)

    if not self.CurrentTab then self:SelectTab(o.Name, true) end
    return tab
end

-- ---------------- drag helper ----------------
-- hold (วินาที): ต้องกดค้างที่หัวลากครบเวลาก่อนถึงจะลากได้ ถ้านิ้วขยับก่อนครบ = ยกเลิก (ไม่ลาก)
-- hold = 0 หรือ nil: ลากได้ทันที (ใช้กับปุ่มวงกลม เพื่อให้แตะเปิดได้)
function Window:_drag(handle, cbs, hold)
    hold = hold or 0
    local dragging, dragInput, startPos, moved, armed, token = false, nil, nil, false, false, 0
    handle.InputBegan:Connect(function(input)
        if not isPress(input) then return end
        if UI._dragLock then return end -- มีอย่างอื่นกำลังลากอยู่
        UI._dragLock = input
        dragging, moved, dragInput = true, false, input
        startPos = input.Position
        token = token + 1
        local my = token
        armed = hold <= 0
        if armed then
            if cbs.Start then cbs.Start() end
        else
            task.delay(hold, function()
                if dragging and token == my and not armed and not moved then
                    armed = true
                    if cbs.Start then cbs.Start() end
                    if cbs.Armed then cbs.Armed() end
                end
            end)
        end
        local c
        c = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                if c then c:Disconnect() end
                if UI._dragLock == input then UI._dragLock = nil end
                if dragging then
                    dragging = false
                    token = token + 1
                    if armed and cbs.End then cbs.End(moved) end
                    armed = false
                end
            end
        end)
    end)
    self:_conn(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        local t = input.UserInputType
        local ok = (t == Enum.UserInputType.MouseMovement and dragInput.UserInputType ~= Enum.UserInputType.Touch)
            or (t == Enum.UserInputType.Touch and input == dragInput)
        if not ok then return end
        local d = input.Position - startPos
        local dist = math.abs(d.X) + math.abs(d.Y)
        if not armed then
            -- ขยับก่อนครบเวลา = ไม่ใช่การกดค้าง -> ยกเลิกการลากรอบนี้
            if dist > 12 then
                moved = true
                token = token + 1
            end
            return
        end
        if not moved and dist > 8 then moved = true end
        if moved and cbs.Move then cbs.Move(d.X, d.Y) end
    end))
end

-- ---------------- state: open / bubble ----------------
-- ทิศจากกลางหน้าต่างไปหาปุ่มวงกลม (องศา) ใช้เป็นทิศการไล่สี
function Window:_aimGradient(bubbleCenter, winCenter)
    local d = bubbleCenter - winCenter
    local ang = 0
    if d.Magnitude > 1 then ang = math.deg(math.atan2(d.Y, d.X)) end
    self._grad.Rotation = ang
end

function Window:_bubbleCenterPx()
    local vp = self.M.VP
    local R = self.BubbleSize / 2
    local margin = 10
    local x = (self.BubbleSide == "left") and (margin + R) or (vp.X - margin - R)
    local y = clamp(self.BubbleY * vp.Y, R + margin, vp.Y - R - margin)
    return Vector2.new(x, y)
end

function Window:_clipOn()
    self._clipToken = (self._clipToken or 0) + 1
    self.Canvas.Parent = self._clip
end

-- คืนเมนูกลับมาอยู่นอกตัวตัด (หลังหน้าต่างขยายเสร็จ)
function Window:_clipOff(delay)
    local token = self._clipToken
    task.delay(delay, function()
        if self._destroyed or self._clipToken ~= token or self.State ~= "open" then return end
        self.Canvas.Parent = self.Win
    end)
end

function Window:Minimize()
    if self.State ~= "open" or self._destroyed then return end
    self.State = "bubble"
    local B = self.BubbleSize
    local vp = self.M.VP
    self._holder.Visible = true
    self._hit.Visible = true
    self:_clipOn()
    -- ทุกอย่างเริ่มพร้อมกันทันที: แสงม่วงกวาดไปทางปุ่ม + หน้าต่างหดเข้าหาปุ่ม
    self:_aimGradient(self:_bubbleCenterPx(), Vector2.new(vp.X / 2 + self.OX, vp.Y / 2 + self.OY))
    self._sweep.Value = 0
    tween(self._sweep, { Value = 1 }, 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    self._edgeStroke.Transparency = 1
    tween(self._edgeCorner, { CornerRadius = UDim.new(0, B / 2 - 1) }, 0.45, Enum.EasingStyle.Quint)
    self.Win.BackgroundColor3 = T.Accent
    self:_tweenWin({ Size = UDim2.fromOffset(B, B), Position = self:_bubblePos() }, 0.45, Enum.EasingStyle.Quint)
    tween(self._corner, { CornerRadius = UDim.new(0, B / 2) }, 0.45, Enum.EasingStyle.Quint)
    tween(self._coverCorner, { CornerRadius = UDim.new(0, B / 2) }, 0.45, Enum.EasingStyle.Quint)
    tween(self._clipCorner, { CornerRadius = UDim.new(0, B / 2) }, 0.45, Enum.EasingStyle.Quint)
    tween(self._bubbleIcon, { ImageTransparency = 0 }, 0.25)
    task.delay(0.3, function()
        if self.State == "bubble" and not self._destroyed then self.Canvas.Visible = false end
    end)
end

function Window:Restore()
    if self.State ~= "bubble" or self._destroyed then return end
    self.State = "open"
    local m = self.M
    local ap, as, dp = self.Win.AbsolutePosition, self.Win.AbsoluteSize, self.Dock.AbsolutePosition
    local bubbleC = Vector2.new(ap.X + as.X / 2 - dp.X, ap.Y + as.Y / 2 - dp.Y)
    self._hit.Visible = false
    self:_aimGradient(bubbleC, Vector2.new(m.VP.X / 2 + self.OX, m.VP.Y / 2 + self.OY))
    -- เริ่มพร้อมกันทันที: หน้าต่างขยาย + แสงม่วงถอยกลับไปทางปุ่ม เผยเมนูพร้อมกัน
    self._sweep.Value = 1
    self:_clipOn()
    self.Canvas.Visible = true
    task.delay(0.2, function()
        if self.State == "open" and not self._destroyed then self.Win.BackgroundColor3 = T.Bg end
    end)
    self:_tweenWin({ Size = UDim2.fromOffset(m.W, m.H), Position = UDim2.new(0.5, self.OX, 0.5, self.OY) }, 0.45, Enum.EasingStyle.Quint)
    tween(self._corner, { CornerRadius = UDim.new(0, 14) }, 0.45, Enum.EasingStyle.Quint)
    tween(self._coverCorner, { CornerRadius = UDim.new(0, 14) }, 0.45, Enum.EasingStyle.Quint)
    tween(self._clipCorner, { CornerRadius = UDim.new(0, 14) }, 0.45, Enum.EasingStyle.Quint)
    self:_clipOff(0.55)
    tween(self._bubbleIcon, { ImageTransparency = 1 }, 0.15)
    tween(self._sweep, { Value = 0 }, 0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    self._edgeStroke.Transparency = 1
    tween(self._edgeCorner, { CornerRadius = UDim.new(0, 13) }, 0.45, Enum.EasingStyle.Quint)
    task.delay(0.5, function()
        if self.State == "open" and not self._destroyed then tween(self._edgeStroke, { Transparency = 0 }, 0.25) end
    end)
    task.delay(0.2, function()
        if self.State == "open" and not self._destroyed then self._holder.Visible = false end
    end)
end

function Window:Toggle()
    if self.State == "open" then self:Minimize() elseif self.State == "bubble" then self:Restore() end
end

function Window:Maximize()
    if self.State ~= "open" then return end
    self.Maximized = not self.Maximized
    self.OX, self.OY = 0, 0
    self:Relayout(true)
end

function Window:ResetPosition()
    self.OX, self.OY = 0, 0
    if self.State == "open" then
        self:_tweenWin({ Position = UDim2.new(0.5, 0, 0.5, 0) }, 0.5, Enum.EasingStyle.Quint)
    end
end

function Window:SetStatus(text, color)
    self.StatusLabel.Text = tostring(text)
    if color then self.StatusDot.BackgroundColor3 = color end
end

function Window:Notify(a, b, c)
    if self._destroyed then return end
    local o = type(a) == "table" and a or { Text = a, Color = b, Duration = c }
    local color = o.Color or T.Accent
    local dur = math.max(0.5, o.Duration or 3)
    self._toastN = self._toastN + 1

    -- ไอคอนอัตโนมัติตามสี (ใส่ Icon = "ชื่อ" เพื่อเปลี่ยน หรือ Icon = false เพื่อซ่อน)
    local icon = o.Icon
    if icon == nil then
        -- เดาจากโทนสี (ไม่ต้องตรงกับสีธีมเป๊ะ สีที่สคริปต์ส่งมาเองก็ได้ไอคอนถูก)
        local h, s = color:ToHSV()
        if s < 0.3 then icon = "bell"
        elseif h < 0.04 or h > 0.93 then icon = "x" -- แดง
        elseif h < 0.18 then icon = "alert-triangle" -- ส้ม/เหลือง
        elseif h > 0.25 and h < 0.46 then icon = "check" -- เขียว
        else icon = "bell" end
    end
    local hasIcon = icon ~= false

    local wrap = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, LayoutOrder = self._toastN,
    }, self._toasts)

    -- การ์ด: พื้นไล่เฉดโทนสีแจ้งเตือนจางๆ + ขอบสี
    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, Position = UDim2.new(1.2, 0, 0, 0),
        BackgroundColor3 = WHITE, BorderSizePixel = 0,
    }, wrap)
    corner(card, 12)
    stroke(card, color, 1, 0.55)
    new("UIGradient", { Color = ColorSequence.new(T.Card:Lerp(color, 0.2), T.Card), Rotation = 0 }, card)

    -- แถบสีด้านซ้าย (เว้นจากขอบบน/ล่าง ไม่ชนมุมโค้ง)
    local pill = new("Frame", {
        Size = UDim2.new(0, 3, 1, -20), Position = UDim2.new(0, 7, 0, 10), BackgroundColor3 = color, BorderSizePixel = 0,
    }, card)
    corner(pill, 2)

    -- เนื้อหา: [ไอคอน | ข้อความ] แล้วตามด้วยเส้นนับเวลา อยู่ในเลย์เอาต์เดียวกัน (ภายใต้ padding) -> ไม่มีทางล้นออกนอกการ์ด
    local body = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1 }, card)
    pad(body, 18, 11, 14, 11)
    vlist(body, 8)

    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, LayoutOrder = 1 }, body)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    }, row)

    if hasIcon then
        local badge = new("Frame", {
            Size = UDim2.fromOffset(28, 28), BackgroundColor3 = color, BackgroundTransparency = 0.82, BorderSizePixel = 0, LayoutOrder = 1,
        }, row)
        corner(badge, 8)
        stroke(badge, color, 1, 0.65)
        iconLabel(badge, icon, 16, color, nil, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
    end

    local txt = new("Frame", {
        Size = UDim2.new(1, hasIcon and -38 or 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, LayoutOrder = 2,
    }, row)
    vlist(txt, 2)
    if o.Title then
        label(txt, { Text = o.Title, Font = F_BOLD, TextSize = 13, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, TextWrapped = true, LayoutOrder = 1 })
    end
    label(txt, {
        Text = tostring(o.Text or ""), Font = F_MED, TextSize = 12, TextColor3 = o.Title and T.Muted or T.Text,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, TextWrapped = true, LayoutOrder = 2,
    })

    -- เส้นนับเวลา: ราง + แท่งเต็มที่หดจากขวาไปซ้าย (อยู่ในกรอบของราง ไม่ล้น)
    local track = new("Frame", {
        Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = color, BackgroundTransparency = 0.86, BorderSizePixel = 0, LayoutOrder = 2,
    }, body)
    corner(track, 2)
    local fill = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, track)
    corner(fill, 2)
    new("UIGradient", { Color = ColorSequence.new(color, color:Lerp(WHITE, 0.5)), Rotation = 0 }, fill)
    tween(fill, { Size = UDim2.new(0, 0, 1, 0) }, dur, Enum.EasingStyle.Linear)

    -- แสงสีขาวเอียงวิ่งตัดผ่านการ์ด (ใช้ UIGradient บนเฟรมที่มีมุมโค้งเท่าการ์ด -> ไม่เลยขอบ)
    local shine = new("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Active = false, ZIndex = 10,
    }, card)
    corner(shine, 12)
    local sg = new("UIGradient", {
        Rotation = 24, Offset = Vector2.new(-1, 0),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.34, 1),
            NumberSequenceKeypoint.new(0.44, 0.9),
            NumberSequenceKeypoint.new(0.50, 0.7),
            NumberSequenceKeypoint.new(0.56, 0.9),
            NumberSequenceKeypoint.new(0.60, 1),
            NumberSequenceKeypoint.new(0.63, 1),
            NumberSequenceKeypoint.new(0.65, 0.78),
            NumberSequenceKeypoint.new(0.67, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, shine)
    task.spawn(function()
        task.wait(0.3)
        while wrap.Parent do
            sg.Offset = Vector2.new(-1, 0)
            tween(sg, { Offset = Vector2.new(1, 0) }, 0.95, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(2.5) -- วิ่ง 0.95 วิ แล้วเว้นช่วงก่อนวิ่งรอบใหม่
        end
    end)

    tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.55, Enum.EasingStyle.Back)
    -- จำกัดไม่เกิน 4 อัน
    local kids = {}
    for _, k in ipairs(self._toasts:GetChildren()) do
        if k:IsA("Frame") then kids[#kids + 1] = k end
    end
    table.sort(kids, function(x, y) return x.LayoutOrder < y.LayoutOrder end)
    while #kids > 4 do table.remove(kids, 1):Destroy() end
    task.delay(dur, function()
        if wrap.Parent then
            tween(card, { Position = UDim2.new(1.2, 0, 0, 0) }, 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            task.wait(0.45)
            if wrap.Parent then wrap:Destroy() end
        end
    end)
end

-- กล่องยืนยัน: win:Dialog({ Title, Text, Buttons = { {Text, Color, Callback}, ... }, Dismissable = true })
function Window:Dialog(o)
    if self._destroyed then return end
    o = o or {}
    local buttons = o.Buttons or { { Text = "OK" } }
    local overlay = new("TextButton", {
        Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 400,
    }, self.Dock)
    local vp = self.M and self.M.VP or Vector2.new(800, 600)
    local card = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(math.min(330, vp.X - 40), 0), AutomaticSize = AY,
        BackgroundColor3 = T.Card, BorderSizePixel = 0, Active = true,
    }, overlay)
    corner(card, 16)
    stroke(card, T.Line, 1, 0)
    pad(card, 18, 18, 18, 16)
    vlist(card, 10)
    local dsc = new("UIScale", { Scale = 0.86 }, card)
    if o.Title then
        label(card, { Text = o.Title, Font = F_BOLD, TextSize = 16, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, TextWrapped = true, LayoutOrder = 1 })
    end
    if o.Text then
        label(card, {
            Text = tostring(o.Text), Font = F_MED, TextSize = 13, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = AY, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2,
        })
    end
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 3 }, card)
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, row)
    local closed = false
    local function close()
        if closed then return end
        closed = true
        tween(overlay, { BackgroundTransparency = 1 }, 0.2, Enum.EasingStyle.Sine)
        tween(dsc, { Scale = 0.9 }, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(0.25, function() overlay:Destroy() end)
    end
    local n = #buttons
    for i, b in ipairs(buttons) do
        makeButton(row, {
            Text = b.Text or "OK", Icon = b.Icon, Color = b.Color or ((i == n) and T.Accent or T.Elem),
            Size = UDim2.new(1 / n, -(8 * (n - 1)) / n, 1, 0), LayoutOrder = i,
            Callback = function()
                close()
                safe(b.Callback)
            end,
        })
    end
    if o.Dismissable then overlay.Activated:Connect(close) end
    tween(overlay, { BackgroundTransparency = 0.5 }, 0.25, Enum.EasingStyle.Sine)
    tween(dsc, { Scale = 1 }, 0.5, Enum.EasingStyle.Back)
    return { Close = close }
end

function Window:Destroy(instant)
    if self._destroyed then return end
    self._destroyed = true
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    local genv = (getgenv and getgenv()) or _G
    if genv.__XenonUI == self then genv.__XenonUI = nil end
    if instant then
        pcall(function() self.Gui:Destroy() end)
        return
    end
    pcall(function()
        if self._winTween then self._winTween:Cancel() end
        self._veil.Visible = true
        tween(self._veil, { BackgroundTransparency = 0 }, 0.3, Enum.EasingStyle.Sine)
        if self.State ~= "bubble" then
            tween(self.Win, { Size = UDim2.fromOffset(self.M.W * 0.9, self.M.H * 0.9) }, 0.3, Enum.EasingStyle.Quint)
        end
    end)
    task.delay(0.35, function() pcall(function() self.Gui:Destroy() end) end)
end

function Window:Close()
    if self.OnClose then safe(self.OnClose) end
    self:Destroy()
end

-- =====================================================================
-- CreateWindow
-- =====================================================================
function UI:CreateWindow(opts)
    opts = opts or {}
    local genv = (getgenv and getgenv()) or _G
    if genv.__XenonUI and genv.__XenonUI.Destroy then
        pcall(function() genv.__XenonUI:Destroy(true) end)
    end

    local self = setmetatable({}, Window)
    genv.__XenonUI = self
    self.Title = opts.Title or "Xenon Hub"
    self.Subtitle = opts.Subtitle or ""
    self.OnClose = opts.OnClose
    self.ToggleKey = (opts.ToggleKey == nil) and Enum.KeyCode.RightShift or opts.ToggleKey
    if opts.Accent then T.Accent = opts.Accent end
    self.Tabs, self.TabList, self.Categories = {}, {}, {}
    self.State = "opening"
    self.Maximized = false
    self.OX, self.OY = 0, 0
    self.BubbleSide, self.BubbleY, self.BubbleSize = "left", 0.5, 54
    self._conns, self._catSeq, self._toastN = {}, 0, 0
    self._fadeText = {}

    -- ที่วาง GUI: gethui -> CoreGui -> PlayerGui
    local parent
    local okH, h = pcall(function() return gethui and gethui() end)
    if okH and typeof(h) == "Instance" then parent = h end
    if not parent then
        local okC, cg = pcall(function() return game:GetService("CoreGui") end)
        if okC and cg then
            local probe = Instance.new("Folder")
            local okW = pcall(function() probe.Parent = cg end)
            if okW and probe.Parent == cg then parent = cg end
            probe:Destroy()
        end
    end
    parent = parent or Players.LocalPlayer:WaitForChild("PlayerGui")
    local guiName = opts.Name or "XenonHubUI"
    local old = parent:FindFirstChild(guiName)
    if old then old:Destroy() end

    local gui = new("ScreenGui", {
        Name = guiName, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999, IgnoreGuiInset = true,
    })
    gui.Parent = parent
    self.Gui = gui
    local dock = new("Frame", { Name = "Dock", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, gui)
    self.Dock = dock

    -- หน้าต่าง (Frame ธรรมดา ไม่ใช้ CanvasGroup เพื่อให้ตัวอักษรคมชัด 100%)
    local win = new("Frame", {
        Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 380),
        BackgroundColor3 = T.Bg, BorderSizePixel = 0, ClipsDescendants = true,
    }, dock)
    self.Win = win
    self._corner = corner(win, 14)
    self._veil = new("Frame", { Name = "Veil", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Bg, BorderSizePixel = 0, ZIndex = 300 }, win)
    corner(self._veil, 14)

    -- ตัวตัดขอบมน "เฉพาะตอนย่อ/ขยาย": ย้ายเมนูเข้ามาในนี้ชั่วคราวเพื่อให้มุมไม่โผล่พ้นขอบโค้ง
    -- (ตอนนิ่งเมนูอยู่นอกตัวนี้ จึงยังคมชัดเต็มที่)
    self._clip = new("CanvasGroup", {
        Name = "TransitionClip", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1,
    }, win)
    self._clipCorner = corner(self._clip, 14)

    local canvas = new("Frame", {
        Name = "Canvas", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(860, 500),
        BackgroundTransparency = 1, BorderSizePixel = 0,
    }, win)
    self.Canvas = canvas
    self._scale = new("UIScale", { Scale = 1 }, canvas)

    -- ---------- Sidebar ----------
    local sidebar = new("Frame", { Name = "Sidebar", Size = UDim2.new(0, SW_EXP, 1, 0), BackgroundColor3 = T.Side, BorderSizePixel = 0, ZIndex = 2 }, canvas)
    self._sidebar = sidebar
    corner(sidebar, 14)
    new("Frame", { Size = UDim2.new(0, 24, 1, 0), Position = UDim2.new(1, -24, 0, 0), BackgroundColor3 = T.Side, BorderSizePixel = 0 }, sidebar)
    new("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = T.Line, BorderSizePixel = 0 }, sidebar)

    local head = new("Frame", { Size = UDim2.new(1, 0, 0, 68), BackgroundTransparency = 1, Active = true }, sidebar)
    local logo = new("Frame", {
        Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(14, 15), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ClipsDescendants = true,
    }, head)
    corner(logo, 11)
    iconLabel(logo, opts.Icon or 95338661062378, 38, WHITE, nil, CENTER)
    local tl = label(head, {
        Text = self.Title, Font = F_BOLD, TextSize = 15, Position = UDim2.fromOffset(62, 15), Size = UDim2.new(1, -70, 0, 20),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local sl = label(head, {
        Text = self.Subtitle, TextSize = 11, TextColor3 = T.Muted, Position = UDim2.fromOffset(62, 35), Size = UDim2.new(1, -70, 0, 16),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    self._fadeText[#self._fadeText + 1] = tl
    self._fadeText[#self._fadeText + 1] = sl

    local tabScroll = new("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 1, -68 - 62), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = AY, ScrollingDirection = Enum.ScrollingDirection.Y,
    }, sidebar)
    pad(tabScroll, 9, 2, 9, 8)
    vlist(tabScroll, 3)
    self._tabScroll = tabScroll

    -- user card
    local user = new("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1,
    }, sidebar)
    new("Frame", { Size = UDim2.new(1, -1, 0, 1), BackgroundColor3 = T.Line, BorderSizePixel = 0 }, user)
    local ucard = new("Frame", {
        Position = UDim2.fromOffset(9, 9), Size = UDim2.new(1, -19, 1, -18), BackgroundColor3 = T.Card, BorderSizePixel = 0,
    }, user)
    corner(ucard, 11)
    local lp = Players.LocalPlayer
    local avatar = new("ImageLabel", {
        Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0),
        BackgroundColor3 = T.Elem, BorderSizePixel = 0, Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(lp and lp.UserId or 1) .. "&w=48&h=48",
    }, ucard)
    corner(avatar, 15)
    local uname = label(ucard, {
        Text = mask(lp and lp.Name), Font = F_MED, TextSize = 12, TextColor3 = T.Text, Position = UDim2.fromOffset(48, 0),
        Size = UDim2.new(1, -78, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
    })
    self._fadeText[#self._fadeText + 1] = uname
    self._userChevron = iconLabel(ucard, "chevrons-up-down", 15, T.Muted, nil, {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0),
    })

    -- ---------- Main ----------
    local main = new("Frame", {
        Name = "Main", Position = UDim2.fromOffset(SW_EXP, 0), Size = UDim2.new(1, -SW_EXP, 1, 0), BackgroundColor3 = T.Bg,
        BorderSizePixel = 0, ClipsDescendants = true,
    }, canvas)
    self._main = main
    corner(main, 14)
    new("Frame", { Size = UDim2.new(0, 24, 1, 0), BackgroundColor3 = T.Bg, BorderSizePixel = 0 }, main)

    local top = new("Frame", { Name = "Top", Size = UDim2.new(1, 0, 0, TOP_H), BackgroundColor3 = T.Top, BorderSizePixel = 0, ZIndex = 3, Active = true }, main)
    corner(top, 14)
    new("Frame", { Size = UDim2.new(0, 24, 1, 0), BackgroundColor3 = T.Top, BorderSizePixel = 0 }, top)
    new("Frame", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -24), BackgroundColor3 = T.Top, BorderSizePixel = 0 }, top)
    new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = T.Line, BorderSizePixel = 0 }, top)

    local tog = new("TextButton", {
        Text = "", AutoButtonColor = false, BackgroundColor3 = T.Elem, BackgroundTransparency = 1, Size = UDim2.fromOffset(32, 32),
        Position = UDim2.new(0, 12, 0.5, -16), BorderSizePixel = 0,
    }, top)
    corner(tog, 9)
    local togIcon = iconLabel(tog, "panel-left", 18, T.Muted, "=", CENTER)
    tog.MouseEnter:Connect(function()
        tween(tog, { BackgroundTransparency = 0.3 }, 0.15)
        tween(togIcon, { ImageColor3 = T.Text }, 0.15)
    end)
    tog.MouseLeave:Connect(function()
        tween(tog, { BackgroundTransparency = 1 }, 0.2)
        tween(togIcon, { ImageColor3 = T.Muted }, 0.2)
    end)
    tog.Activated:Connect(function()
        self._userCollapse = not self.SidebarCollapsed
        self:SetSidebar(self._userCollapse)
        self:Relayout(true)
    end)
    new("Frame", { Size = UDim2.fromOffset(1, 18), Position = UDim2.new(0, 52, 0.5, -9), BackgroundColor3 = T.Line, BorderSizePixel = 0 }, top)
    self._crumb = label(top, {
        Text = "", RichText = true, Font = F_MED, TextSize = 13, TextColor3 = T.Text, Position = UDim2.fromOffset(62, 0),
        Size = UDim2.new(1, -250, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
    })

    -- ไฟจราจร: แดง = ปิด, เหลือง = ย่อเป็นวงกลม, เขียว = ขยาย/คืนขนาด
    local function light(color, xr, cb)
        local hit = new("TextButton", {
            Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(24, 24),
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xr, 0.5, 0),
        }, top)
        local dot = new("Frame", {
            Size = UDim2.fromOffset(13, 13), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            BackgroundColor3 = color, BorderSizePixel = 0,
        }, hit)
        corner(dot, 7)
        hit.MouseEnter:Connect(function() tween(dot, { Size = UDim2.fromOffset(17, 17) }, 0.15, Enum.EasingStyle.Back) end)
        hit.MouseLeave:Connect(function() tween(dot, { Size = UDim2.fromOffset(13, 13) }, 0.2) end)
        hit.Activated:Connect(cb)
    end
    light(Color3.fromRGB(255, 95, 87), -74, function() self:Close() end)
    light(Color3.fromRGB(254, 188, 46), -46, function() self:Minimize() end)
    light(Color3.fromRGB(40, 200, 64), -18, function() self:Maximize() end)

    -- status pill
    local pill = new("TextButton", {
        Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -104, 0.5, 0),
        Size = UDim2.fromOffset(176, 28), BackgroundColor3 = T.Elem, BorderSizePixel = 0,
    }, top)
    corner(pill, 14)
    self._pill = pill
    self.StatusDot = new("Frame", {
        Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 12, 0.5, -4), BackgroundColor3 = T.Muted, BorderSizePixel = 0,
    }, pill)
    corner(self.StatusDot, 4)
    self.StatusLabel = label(pill, {
        Text = "Ready", TextSize = 12, TextColor3 = T.Muted, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -36, 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    pill.Activated:Connect(function() self:Notify({ Text = self.StatusLabel.Text, Duration = 5 }) end)

    local pages = new("Frame", {
        Position = UDim2.fromOffset(0, TOP_H), Size = UDim2.new(1, 0, 1, -TOP_H), BackgroundTransparency = 1, ClipsDescendants = true,
    }, main)
    self._pages = pages
    self._curtain = new("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Bg, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10,
    }, pages)

    -- ---------- layer สำหรับโหมดวงกลม ----------
    self._cover = new("Frame", {
        Name = "Cover", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 50,
    }, win)
    self._coverCorner = corner(self._cover, 14)
    -- ไล่สีแบบกวาดไปทางตำแหน่งปุ่มวงกลม
    -- t = 0 ฝั่งไกลปุ่ม, t = 1 ฝั่งปุ่ม | หน้ากวาดเคลื่อนจากไกล -> ปุ่ม
    -- หลังหน้ากวาด = ม่วงทึบ, ตรงขอบหน้ากวาด = ม่วงเข้ม/ดำที่ค่อยๆ จางใส (เห็นเมนูด้านในทีละน้อย)
    self._grad = new("UIGradient", { Rotation = 0 }, self._cover)
    local PAL = {
        Color3.fromRGB(176, 104, 255), Color3.fromRGB(104, 84, 238), Color3.fromRGB(44, 26, 104),
    }
    local function palette(t)
        if t < 0.5 then return PAL[1]:Lerp(PAL[2], t / 0.5) end
        return PAL[2]:Lerp(PAL[3], (t - 0.5) / 0.5)
    end
    local BLACK = Color3.fromRGB(6, 4, 14)
    local GLOW = Color3.fromRGB(226, 196, 255)
    self._coverStroke = stroke(self._cover, Color3.fromRGB(190, 140, 255), 2.5, 1)
    local function setSweep(p)
        local N, w = 10, 0.6
        local cols, trs = {}, {}
        for i = 0, N - 1 do
            local t = i / (N - 1)
            local q = clamp((p * (1 + w) - t) / w, 0, 1)
            q = q * q * (3 - 2 * q) -- smoothstep
            -- เรืองแสง: ตรงขอบหน้ากวาด (q กลางๆ) สว่างขึ้นเป็นแถบแสง
            local g = 4 * q * (1 - q)
            local col = BLACK:Lerp(palette(t), q):Lerp(GLOW, g * 0.8)
            cols[#cols + 1] = ColorSequenceKeypoint.new(t, col)
            trs[#trs + 1] = NumberSequenceKeypoint.new(t, clamp(1 - q, 0, 1))
        end
        self._grad.Color = ColorSequence.new(cols)
        self._grad.Transparency = NumberSequence.new(trs)
        -- ขอบเรืองแสงรอบหน้าต่างสว่างสุดกลางการกวาด
        self._coverStroke.Transparency = 1 - math.sin(math.pi * clamp(p, 0, 1)) * 0.85
    end
    self._sweep = new("NumberValue", { Value = 0 }, self._cover)
    self._sweep.Changed:Connect(setSweep)
    setSweep(0)
    local edge = new("Frame", {
        Name = "Edge", Size = UDim2.new(1, -2, 1, -2), Position = UDim2.fromOffset(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 52,
    }, win)
    self._edgeCorner = corner(edge, 13)
    self._edgeStroke = stroke(edge, T.Line, 1.5, 0)
    self._holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 55 }, win)
    self._bubbleIcon = iconLabel(self._holder, opts.Icon or 95338661062378, 40, WHITE, nil, CENTER)
    self._bubbleIcon.ImageTransparency = 1
    self._hit = new("TextButton", {
        Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 100, Visible = false,
    }, win)

    -- toast
    local toasts = new("Frame", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.new(0, 300, 1, -28),
        BackgroundTransparency = 1, ZIndex = 200,
    }, dock)
    new("UIListLayout", {
        Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right,
    }, toasts)
    self._toasts = toasts

    -- ---------- drag: หน้าต่าง (นุ่มด้วย lerp ตามเฟรม ไม่กระตุกตามอัตราส่งอินพุต) ----------
    local sx, sy = 0, 0
    local curX, curY, tgtX, tgtY = 0, 0, 0, 0
    local dragOn = false
    local winDrag = {
        Start = function()
            if self._winTween then self._winTween:Cancel() end
            -- เริ่มจากตำแหน่งที่เห็นจริงตอนนี้ (กรณีจับตอนกำลังเด้งกลับ)
            local p = win.Position
            sx, sy = math.floor(p.X.Offset + 0.5), math.floor(p.Y.Offset + 0.5)
            self.OX, self.OY = sx, sy
            curX, curY, tgtX, tgtY = sx, sy, sx, sy
            dragOn = true
            tween(self._edgeStroke, { Color = T.Accent }, 0.15) -- ขอบเรืองสีหลักตอนลาก
        end,
        Move = function(dx, dy)
            if self.State ~= "open" then return end
            local m = self.M
            local maxX = m.VP.X / 2 + m.W / 2 - 90
            local minY = -(m.VP.Y / 2 - m.H / 2)
            local maxY = m.VP.Y / 2 - 50
            tgtX = clamp(sx + dx, -maxX, maxX)
            tgtY = clamp(sy + dy, minY, maxY)
        end,
        Armed = function()
            -- กดค้างครบเวลาแล้ว: ขอบหน้าต่างเรืองสีหลัก + สั่นเบาๆ ให้รู้ว่าลากได้แล้ว
            if self.State ~= "open" then return end
            tween(self._edgeStroke, { Color = T.Accent }, 0.15)
            local s = self._scale
            tween(s, { Scale = s.Scale * 1.015 }, 0.12, Enum.EasingStyle.Quad)
            task.delay(0.12, function()
                if not self._destroyed then tween(s, { Scale = self.M.S }, 0.25, Enum.EasingStyle.Back) end
            end)
        end,
        End = function(moved)
            dragOn = false
            tween(self._edgeStroke, { Color = T.Line }, 0.25)
            if self.State ~= "open" then return end
            if UI.DragReturn then
                -- ปล่อยแล้วค่อยๆ เด้งกลับที่เดิม (กลางจอ)
                self.OX, self.OY = 0, 0
                self:_tweenWin({ Position = UDim2.new(0.5, 0, 0.5, 0) }, 0.6, Enum.EasingStyle.Quint)
            elseif moved then
                self.OX, self.OY = math.floor(tgtX + 0.5), math.floor(tgtY + 0.5)
                self:_tweenWin({ Position = UDim2.new(0.5, self.OX, 0.5, self.OY) }, 0.22, Enum.EasingStyle.Quint)
            end
        end,
    }
    self:_conn(RunService.RenderStepped:Connect(function(dt)
        if not dragOn or self.State ~= "open" then return end
        local k = 1 - math.exp(-dt * 26)
        curX = curX + (tgtX - curX) * k
        curY = curY + (tgtY - curY) * k
        self.OX, self.OY = math.floor(curX + 0.5), math.floor(curY + 0.5)
        win.Position = UDim2.new(0.5, self.OX, 0.5, self.OY)
    end))
    self:_drag(top, winDrag, UI.DragHoldTime)
    self:_drag(head, winDrag, UI.DragHoldTime)

    -- ---------- drag + แตะ: วงกลม ----------
    local cx, cy = 0, 0
    self:_drag(self._hit, {
        Start = function()
            if self._winTween then self._winTween:Cancel() end
            local ap, as, dp = win.AbsolutePosition, win.AbsoluteSize, dock.AbsolutePosition
            cx, cy = ap.X + as.X / 2 - dp.X, ap.Y + as.Y / 2 - dp.Y
            tween(self._cover, { BackgroundColor3 = Color3.fromRGB(205, 205, 220) }, 0.1)
        end,
        Move = function(dx, dy)
            local vp = self.M.VP
            local R = self.BubbleSize / 2
            win.Position = UDim2.fromOffset(clamp(cx + dx, R, vp.X - R), clamp(cy + dy, R, vp.Y - R))
        end,
        End = function(moved)
            tween(self._cover, { BackgroundColor3 = WHITE }, 0.2)
            if not moved then
                self:Restore()
                return
            end
            local vp = self.M.VP
            local pos = win.Position
            self.BubbleSide = (pos.X.Offset < vp.X / 2) and "left" or "right"
            self.BubbleY = pos.Y.Offset / vp.Y
            self:_tweenWin({ Position = self:_bubblePos() }, 0.5, Enum.EasingStyle.Quint)
        end,
    })

    -- ปุ่มลัด + จอเปลี่ยนขนาด
    if self.ToggleKey then
        self:_conn(UserInputService.InputBegan:Connect(function(input, gp)
            if not gp and input.KeyCode == self.ToggleKey then self:Toggle() end
        end))
    end
    local cam = workspace.CurrentCamera
    if cam then
        self:_conn(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if not self._destroyed then self:Relayout(true) end
        end))
    end

    -- เริ่มต้น + แอนิเมชันเปิด
    self.SidebarCollapsed = false
    self:Relayout(false)
    local m = self.M
    if UI.IntroBubble ~= false then
        -- ผุดเป็นวงกลมก่อน แล้วขยายเป็นหน้าต่างด้วยแอนิเมชันเดียวกับตอนกดขยาย (Restore)
        local B = self.BubbleSize
        self.State = "bubble"
        self._veil.Visible = false
        self._veil.BackgroundTransparency = 1
        self._holder.Visible = true
        self._hit.Visible = true
        self:_clipOn()
        self.Canvas.Visible = false
        win.BackgroundColor3 = T.Accent
        self._corner.CornerRadius = UDim.new(0, B / 2)
        self._coverCorner.CornerRadius = UDim.new(0, B / 2)
        self._clipCorner.CornerRadius = UDim.new(0, B / 2)
        self._edgeCorner.CornerRadius = UDim.new(0, B / 2 - 1)
        self._edgeStroke.Transparency = 1
        self._sweep.Value = 1
        self._bubbleIcon.ImageTransparency = 0
        win.Position = self:_bubblePos()
        win.Size = UDim2.fromOffset(0, 0)
        self:_tweenWin({ Size = UDim2.fromOffset(B, B) }, 0.3, Enum.EasingStyle.Back)
        task.delay(0.38, function()
            if not self._destroyed and self.State == "bubble" and not UI._dragLock then self:Restore() end
        end)
        return self
    end
    win.Size = UDim2.fromOffset(m.W * 0.9, m.H * 0.9)
    self:_tweenWin({ Size = UDim2.fromOffset(m.W, m.H) }, 0.6, Enum.EasingStyle.Back)
    tween(self._veil, { BackgroundTransparency = 1 }, 0.4, Enum.EasingStyle.Sine)
    task.delay(0.45, function() if self._veil then self._veil.Visible = false end end)
    self.State = "open"
    return self
end

return UI
