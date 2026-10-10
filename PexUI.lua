--[[
    XenonUI v1.0
    UI library สไตล์ Xenon Hub สำหรับ Roblox (รองรับทั้ง PC และมือถือ)

    - หน้าต่างปรับขนาดตามจอเอง (มือถือ: กว้าง ~76% / สูง ~82% ของจอ)
    - ปุ่มเหลือง = ย่อเป็นวงกลมข้างจอ (ลากย้ายได้ ดูดเข้าขอบซ้าย/ขวา แตะเพื่อขยายกลับ)
    - ไม่มีอีโมจิ: ไอคอนทั้งหมดเป็นไอคอน ID (Lucide อัตโนมัติ หรือใส่ rbxassetid เองได้)
    - แอนิเมชัน: เปิด/ย่อ/ขยาย, สลับแท็บ, สวิตช์, ปุ่ม, Toast

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

local UI = {}
UI.Version = "1.1.0"
-- แหล่งไอคอน Lucide (spritesheet asset id) ถ้าโหลดไม่ได้ ไอคอนจะเป็นจุดแทน ไม่ทำให้ UI พัง
UI.LucideURL = "https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau"
UI.LucideMirrors = {
    "https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau",
    "https://raw.githubusercontent.com/latte-soft/lucide-roblox/main/lucide-roblox.luau",
}
UI.CustomIcons = {}
UI.UiScale = 1 -- ค่า != 1 จะทำให้ตัวอักษรในหน้าต่างเบลอ (CanvasGroup) แนะนำให้คงไว้ที่ 1
UI.ForceMobile = nil -- true/false = บังคับโหมดมือถือ/คอม, nil = ตรวจเอง

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
local function tween(o, props, t, style, dir)
    local tw = TweenService:Create(o, TweenInfo.new(t or 0.25, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
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
-- Button builder (ใช้ร่วมกันทั้งปุ่มในแถวและปุ่มเต็มความกว้าง)
-- =====================================================================
local function makeButton(parent, o)
    local color = o.Color or T.Elem
    local b = new("TextButton", {
        Text = "", AutoButtonColor = false, BackgroundColor3 = color, BorderSizePixel = 0,
        Size = o.Size or UDim2.new(1, 0, 0, 38), LayoutOrder = o.LayoutOrder or 0, ClipsDescendants = true,
    }, parent)
    corner(b, 9)
    stroke(b, WHITE, 1, 0.85)
    local sc = new("UIScale", { Scale = 1 }, b)
    local content = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, b)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder,
    }, content)
    local obj = { Instance = b }
    local iconObj
    local function setIcon(icon)
        if iconObj then iconObj:Destroy() iconObj = nil end
        if icon then
            iconObj = iconLabel(content, icon, 17, WHITE)
            iconObj.LayoutOrder = 1
        end
    end
    setIcon(o.Icon)
    local txt = label(content, {
        Text = o.Text or "", Font = F_BOLD, TextSize = o.TextSize or 13, TextColor3 = WHITE,
        AutomaticSize = AX, Size = UDim2.fromOffset(0, 20), LayoutOrder = 2,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    obj.TextLabel = txt
    function obj:SetText(t) txt.Text = tostring(t) end
    function obj:SetColor(c)
        color = c
        tween(b, { BackgroundColor3 = c }, 0.25)
    end
    function obj:SetIcon(icon) setIcon(icon) end
    b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = color:Lerp(WHITE, 0.14) }, 0.15) end)
    b.MouseLeave:Connect(function()
        tween(b, { BackgroundColor3 = color }, 0.2)
        tween(sc, { Scale = 1 }, 0.2)
    end)
    b.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            tween(sc, { Scale = 0.95 }, 0.1)
        end
    end)
    b.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            tween(sc, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
        end
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
local function makeRow(sec, title, desc, ctlSize, clickable)
    local order = nextSlot(sec)
    local row = new(clickable and "TextButton" or "Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = order,
    }, sec.Card)
    if clickable then
        row.Text = ""
        row.AutoButtonColor = false
    end
    new("UISizeConstraint", { MinSize = Vector2.new(0, 54) }, row)
    pad(row, 14, 10, 14, 10)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)
    local block = new("Frame", {
        Size = ctlSize and UDim2.new(1, -(ctlSize.X + 12), 0, 0) or UDim2.new(1, 0, 0, 0),
        AutomaticSize = AY, BackgroundTransparency = 1, LayoutOrder = 1,
    }, row)
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
        ctl = new("Frame", { Size = UDim2.fromOffset(ctlSize.X, ctlSize.Y), BackgroundTransparency = 1, LayoutOrder = 2 }, row)
    end
    return row, ctl, tl, dl
end

local function safe(cb, ...)
    if not cb then return end
    local ok, err = pcall(cb, ...)
    if not ok then warn("[XenonUI] callback error: " .. tostring(err)) end
end

function Section:Toggle(o)
    local row, ctl = makeRow(self, o.Title, o.Desc, Vector2.new(46, 26), true)
    local track = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Elem, BorderSizePixel = 0 }, ctl)
    corner(track, 13)
    stroke(track, T.Line, 1, 0)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = WHITE, BorderSizePixel = 0,
    }, track)
    corner(knob, 10)
    local state = o.Default and true or false
    local function render(instant)
        local c = state and T.Accent or T.Elem
        local p = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
        if instant then
            track.BackgroundColor3 = c
            knob.Position = p
        else
            tween(track, { BackgroundColor3 = c }, 0.25)
            tween(knob, { Position = p }, 0.35, Enum.EasingStyle.Back)
        end
    end
    render(true)
    row.Activated:Connect(function()
        state = not state
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
    local w = o.Width or 120
    local row, ctl = makeRow(self, o.Title, o.Desc, Vector2.new(w, 34), false)
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
        o.Size = UDim2.new(1 / n, -(8 * (n - 1)) / n, 0, o.Height or 38)
        o.LayoutOrder = i
        out[i] = makeButton(f, o)
    end
    return out
end

function Section:Action(o)
    return self:Actions({ o })[1]
end

-- รายการเลื่อนได้ (ไฟล์บันทึก / แถวแอคชัน / Log ฯลฯ)
function Section:List(o)
    o = o or {}
    local order = nextSlot(self)
    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, (o.Height or 150) + 20), BackgroundTransparency = 1, LayoutOrder = order,
    }, self.Card)
    pad(holder, 10)
    local sf = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Inset, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Muted, CanvasSize = UDim2.new(), AutomaticCanvasSize = AY,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, holder)
    corner(sf, 9)
    stroke(sf, T.Line, 1, 0)
    pad(sf, 6, 6, 8, 6)
    vlist(sf, 4)
    local list = { Frame = sf, Holder = holder }
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
-- Tab
-- =====================================================================
local Tab = {}
Tab.__index = Tab

function Tab:Section(o)
    o = o or {}
    self._n = self._n + 1
    local wrap = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, LayoutOrder = self._n }, self.Page)
    vlist(wrap, 9)
    if o.Title then
        local head = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 1 }, wrap)
        local x = 2
        if o.Icon then
            local tile = new("Frame", {
                Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = o.Color or self.Color, BorderSizePixel = 0,
            }, head)
            corner(tile, 9)
            iconLabel(tile, o.Icon, 18, WHITE, nil, CENTER)
            x = 44
        end
        if o.Desc then
            label(head, {
                Text = o.Title, Font = F_BOLD, TextSize = 14, Position = UDim2.fromOffset(x, 1), Size = UDim2.new(1, -x, 0, 18),
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            label(head, {
                Text = o.Desc, TextSize = 12, TextColor3 = T.Muted, Position = UDim2.fromOffset(x, 19), Size = UDim2.new(1, -x, 0, 16),
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
        else
            label(head, {
                Text = o.Title, Font = F_BOLD, TextSize = 14, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x, 1, 0),
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
        end
    end
    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundColor3 = T.Card, BorderSizePixel = 0, LayoutOrder = 2,
    }, wrap)
    corner(card, 12)
    stroke(card, T.Line, 1)
    vlist(card, 0)
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
    self.CurrentTab = tab
    for _, t in ipairs(self.TabList) do
        local on = (t == tab)
        t.Page.Visible = on
        tween(t.Button, { BackgroundTransparency = on and 0 or 1 }, 0.2)
        tween(t.Label, { TextColor3 = on and T.Text or T.Muted }, 0.2)
    end
    self:SetBreadcrumb(tab.Category, tab.Name)
    if not instant then
        tab.Page.Position = UDim2.fromOffset(0, 14)
        tween(tab.Page, { Position = UDim2.fromOffset(0, 0) }, 0.4, Enum.EasingStyle.Quint)
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
        AutomaticCanvasSize = AY, Visible = false,
    }, self._pages)
    pad(page, 16, 14, 16, 20)
    vlist(page, 16)

    local tab = setmetatable({
        Window = self, Name = o.Name, Category = catName, Page = page, Button = btn, Label = lbl, Color = color, _n = 0,
    }, Tab)
    self.Tabs[o.Name] = tab
    self.TabList[#self.TabList + 1] = tab

    btn.MouseEnter:Connect(function()
        if self.CurrentTab ~= tab then tween(btn, { BackgroundTransparency = 0.6 }, 0.15) end
    end)
    btn.MouseLeave:Connect(function()
        if self.CurrentTab ~= tab then tween(btn, { BackgroundTransparency = 1 }, 0.2) end
    end)
    btn.Activated:Connect(function() self:SelectTab(o.Name) end)

    if not self.CurrentTab then self:SelectTab(o.Name, true) end
    return tab
end

-- ---------------- drag helper ----------------
function Window:_drag(handle, cbs)
    local dragging, dragInput, startPos, moved = false, nil, nil, false
    handle.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            dragging, moved, dragInput = true, false, input
            startPos = input.Position
            if cbs.Start then cbs.Start() end
            local c
            c = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    if c then c:Disconnect() end
                    if dragging then
                        dragging = false
                        if cbs.End then cbs.End(moved) end
                    end
                end
            end)
        end
    end)
    self:_conn(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseMovement or (t == Enum.UserInputType.Touch and input == dragInput) then
            local d = input.Position - startPos
            if not moved and (math.abs(d.X) + math.abs(d.Y)) > 8 then moved = true end
            if moved and cbs.Move then cbs.Move(d.X, d.Y) end
        end
    end))
end

-- ---------------- state: open / bubble ----------------
function Window:Minimize()
    if self.State ~= "open" or self._destroyed then return end
    self.State = "bubble"
    local B = self.BubbleSize
    self._holder.Visible = true
    self._hit.Visible = true
    self:_tweenWin({ Size = UDim2.fromOffset(B, B), Position = self:_bubblePos() }, 0.6, Enum.EasingStyle.Quint)
    tween(self._corner, { CornerRadius = UDim.new(0, B / 2) }, 0.6, Enum.EasingStyle.Quint)
    tween(self._edgeStroke, { Transparency = 1 }, 0.25)
    tween(self._cover, { BackgroundTransparency = 0 }, 0.32, Enum.EasingStyle.Sine)
    task.delay(0.15, function()
        if self.State == "bubble" and not self._destroyed then tween(self._bubbleIcon, { ImageTransparency = 0 }, 0.3) end
    end)
    task.delay(0.65, function()
        if self.State == "bubble" and not self._destroyed then self.Canvas.Visible = false end
    end)
end

function Window:Restore()
    if self.State ~= "bubble" or self._destroyed then return end
    self.State = "open"
    local m = self.M
    self.Canvas.Visible = true
    self._hit.Visible = false
    self:_tweenWin({ Size = UDim2.fromOffset(m.W, m.H), Position = UDim2.new(0.5, self.OX, 0.5, self.OY) }, 0.65, Enum.EasingStyle.Quint)
    tween(self._corner, { CornerRadius = UDim.new(0, 14) }, 0.55, Enum.EasingStyle.Quint)
    tween(self._bubbleIcon, { ImageTransparency = 1 }, 0.15)
    task.delay(0.12, function()
        if self._destroyed then return end
        tween(self._cover, { BackgroundTransparency = 1 }, 0.45, Enum.EasingStyle.Sine)
        tween(self._edgeStroke, { Transparency = 0 }, 0.45)
    end)
    task.delay(0.25, function()
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
    local dur = o.Duration or 3
    self._toastN = self._toastN + 1
    local wrap = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1, LayoutOrder = self._toastN,
    }, self._toasts)
    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, Position = UDim2.new(1.2, 0, 0, 0), BackgroundColor3 = T.Card, BorderSizePixel = 0,
    }, wrap)
    corner(card, 10)
    stroke(card, color, 1, 0.5)
    pad(card, 20, 10, 12, 10)
    new("Frame", {
        Size = UDim2.new(0, 3, 1, 8), Position = UDim2.new(0, -14, 0, -4), BackgroundColor3 = color, BorderSizePixel = 0,
    }, card)
    local inner = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, BackgroundTransparency = 1 }, card)
    vlist(inner, 2)
    if o.Title then
        label(inner, { Text = o.Title, Font = F_BOLD, TextSize = 13, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, TextWrapped = true, LayoutOrder = 1 })
    end
    label(inner, {
        Text = tostring(o.Text or ""), Font = F_MED, TextSize = 12, TextColor3 = o.Title and T.Muted or T.Text,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AY, TextWrapped = true, LayoutOrder = 2,
    })
    tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.5, Enum.EasingStyle.Quint)
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
        tween(self.Win, { GroupTransparency = 1 }, 0.3, Enum.EasingStyle.Sine)
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

    -- หน้าต่าง (CanvasGroup = ตัดขอบมนได้ตอนย่อเป็นวงกลม + เฟดได้)
    local win = new("CanvasGroup", {
        Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 380),
        BackgroundColor3 = T.Bg, BorderSizePixel = 0, GroupTransparency = 1,
    }, dock)
    self.Win = win
    self._corner = corner(win, 14)

    local canvas = new("Frame", {
        Name = "Canvas", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(860, 500),
        BackgroundTransparency = 1, BorderSizePixel = 0,
    }, win)
    self.Canvas = canvas
    self._scale = new("UIScale", { Scale = 1 }, canvas)

    -- ---------- Sidebar ----------
    local sidebar = new("Frame", { Name = "Sidebar", Size = UDim2.new(0, SW_EXP, 1, 0), BackgroundColor3 = T.Side, BorderSizePixel = 0, ZIndex = 2 }, canvas)
    self._sidebar = sidebar
    new("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = T.Line, BorderSizePixel = 0 }, sidebar)

    local head = new("Frame", { Size = UDim2.new(1, 0, 0, 68), BackgroundTransparency = 1, Active = true }, sidebar)
    local logo = new("Frame", {
        Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(14, 15), BackgroundColor3 = T.Accent, BorderSizePixel = 0,
    }, head)
    corner(logo, 11)
    iconLabel(logo, opts.Icon or "zap", 22, WHITE, nil, CENTER)
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

    local top = new("Frame", { Name = "Top", Size = UDim2.new(1, 0, 0, TOP_H), BackgroundColor3 = T.Top, BorderSizePixel = 0, ZIndex = 3, Active = true }, main)
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
        Name = "Cover", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50,
    }, win)
    local edge = new("Frame", {
        Name = "Edge", Size = UDim2.new(1, -2, 1, -2), Position = UDim2.fromOffset(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 52,
    }, win)
    corner(edge, 13)
    self._edgeStroke = stroke(edge, T.Line, 1.5, 0)
    self._holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 55 }, win)
    self._bubbleIcon = iconLabel(self._holder, opts.Icon or "zap", 28, WHITE, nil, CENTER)
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

    -- ---------- drag: หน้าต่าง ----------
    local sx, sy = 0, 0
    self:_drag(top, {
        Start = function()
            if self._winTween then self._winTween:Cancel() end
            sx, sy = self.OX, self.OY
        end,
        Move = function(dx, dy)
            if self.State ~= "open" then return end
            local m = self.M
            local maxX = m.VP.X / 2 + m.W / 2 - 90
            local minY = -(m.VP.Y / 2 - m.H / 2)
            local maxY = m.VP.Y / 2 - 50
            self.OX = math.floor(clamp(sx + dx, -maxX, maxX) + 0.5)
            self.OY = math.floor(clamp(sy + dy, minY, maxY) + 0.5)
            win.Position = UDim2.new(0.5, self.OX, 0.5, self.OY)
        end,
    })
    self:_drag(head, {
        Start = function()
            if self._winTween then self._winTween:Cancel() end
            sx, sy = self.OX, self.OY
        end,
        Move = function(dx, dy)
            if self.State ~= "open" then return end
            local m = self.M
            local maxX = m.VP.X / 2 + m.W / 2 - 90
            local minY = -(m.VP.Y / 2 - m.H / 2)
            local maxY = m.VP.Y / 2 - 50
            self.OX = math.floor(clamp(sx + dx, -maxX, maxX) + 0.5)
            self.OY = math.floor(clamp(sy + dy, minY, maxY) + 0.5)
            win.Position = UDim2.new(0.5, self.OX, 0.5, self.OY)
        end,
    })

    -- ---------- drag + แตะ: วงกลม ----------
    local cx, cy = 0, 0
    self:_drag(self._hit, {
        Start = function()
            if self._winTween then self._winTween:Cancel() end
            local ap, as, dp = win.AbsolutePosition, win.AbsoluteSize, dock.AbsolutePosition
            cx, cy = ap.X + as.X / 2 - dp.X, ap.Y + as.Y / 2 - dp.Y
            tween(self._cover, { BackgroundColor3 = T.Accent:Lerp(WHITE, 0.15) }, 0.1)
        end,
        Move = function(dx, dy)
            local vp = self.M.VP
            local R = self.BubbleSize / 2
            win.Position = UDim2.fromOffset(clamp(cx + dx, R, vp.X - R), clamp(cy + dy, R, vp.Y - R))
        end,
        End = function(moved)
            tween(self._cover, { BackgroundColor3 = T.Accent }, 0.2)
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
    win.Size = UDim2.fromOffset(m.W * 0.9, m.H * 0.9)
    self:_tweenWin({ Size = UDim2.fromOffset(m.W, m.H) }, 0.7, Enum.EasingStyle.Quint)
    tween(win, { GroupTransparency = 0 }, 0.4, Enum.EasingStyle.Sine)
    self.State = "open"
    return self
end

return UI
