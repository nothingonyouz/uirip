--[[
    VSCodeUILib  —  Single-file Roblox UI Library (VS Code style)
    --------------------------------------------------------------
    Features:
      • VS Code "Dark+" themed window (Activity Bar, Side Bar, Editor, Status Bar)
      • Tabs, Sections, Buttons, Toggles, Sliders, Dropdowns, Textboxes, Keybinds, Labels
      • Built-in Config Manager (save / load / list / delete) using exploit file API
        with a graceful in-memory fallback when the file API is unavailable.
      • Draggable window, toggle key, notifications.

    Usage:  local Library = loadstring(readfile("VSCodeUILib.lua"))()
            (or require the ModuleScript)

    Author: local hub
]]

local UILib = {}
UILib.__index = UILib

----------------------------------------------------------------------
-- Services
----------------------------------------------------------------------
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer and LocalPlayer:GetMouse()

----------------------------------------------------------------------
-- VS Code "Dark+" Theme
----------------------------------------------------------------------
local Theme = {
    Editor      = Color3.fromRGB(30, 30, 30),    -- #1e1e1e  main editor
    SideBar     = Color3.fromRGB(37, 37, 38),     -- #252526  side panel
    ActivityBar = Color3.fromRGB(45, 45, 45),     -- #2d2d2d  far-left icon bar
    TitleBar    = Color3.fromRGB(60, 60, 60),     -- #3c3c3c  title bar
    StatusBar   = Color3.fromRGB(0, 122, 204),    -- #007acc  bottom status bar
    Accent      = Color3.fromRGB(0, 122, 204),    -- #007acc  selection / focus
    AccentDim   = Color3.fromRGB(14, 99, 156),
    Input       = Color3.fromRGB(60, 60, 60),     -- #3c3c3c  input fields
    Hover       = Color3.fromRGB(42, 45, 46),     -- #2a2d2e  list hover
    Selected    = Color3.fromRGB(55, 55, 56),     -- selected list item
    Border      = Color3.fromRGB(64, 64, 64),
    Text        = Color3.fromRGB(204, 204, 204),  -- #cccccc
    TextDim     = Color3.fromRGB(133, 133, 133),  -- #858585
    TextBright  = Color3.fromRGB(255, 255, 255),
    Success     = Color3.fromRGB(137, 209, 133),
    Warning     = Color3.fromRGB(229, 192, 123),
    Error       = Color3.fromRGB(244, 135, 113),
}
UILib.Theme = Theme

local FONT     = Enum.Font.Code   -- monospace, very VS Code
local FONT_UI  = Enum.Font.Gotham

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function create(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    return inst
end

local function corner(parent, radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius or 4), Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function padding(parent, all)
    return create("UIPadding", {
        PaddingTop = UDim.new(0, all),
        PaddingBottom = UDim.new(0, all),
        PaddingLeft = UDim.new(0, all),
        PaddingRight = UDim.new(0, all),
        Parent = parent,
    })
end

local function tween(inst, time, props)
    local t = TweenService:Create(inst, TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

-- Normalize an image reference: accepts a number, "12345", or a full rbxassetid/http string.
local function toAssetId(v)
    if v == nil then return nil end
    v = tostring(v)
    if v:match("^rbxassetid://") or v:match("^rbxthumb") or v:match("^http") or v:match("^rbxasset") then
        return v
    end
    return "rbxassetid://" .. v
end

-- Recolor every primitive inside a drawn icon holder.
local function setIconColor(holder, color)
    if holder:IsA("ImageLabel") then holder.ImageColor3 = color; return end
    if holder:IsA("TextLabel") then holder.TextColor3 = color; return end
    for _, d in ipairs(holder:GetDescendants()) do
        if d:IsA("Frame") then d.BackgroundColor3 = color
        elseif d:IsA("UIStroke") then d.Color = color end
    end
end

-- Built-in monochrome vector icons (drawn from frames, no assets required).
local BUILTIN_ICONS = {
    target = true, crosshair = true, person = true, settings = true, sliders = true,
    home = true, bolt = true, eye = true, info = true, success = true, check = true,
    warning = true, error = true, close = true, minus = true, search = true,
}

-- Draws icon `name` (sized to `px`) into `parent`.
local function drawIcon(parent, name, color, px)
    color = color or Theme.Text
    local zi = (parent.ZIndex or 1) + 1
    local function bar(w, h, ox, oy, rot)
        return create("Frame", {
            BackgroundColor3 = color, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, ox or 0, 0.5, oy or 0),
            Size = UDim2.new(0, w, 0, h), Rotation = rot or 0, ZIndex = zi, Parent = parent,
        }, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
    end
    local function dot(d, ox, oy)
        return create("Frame", {
            BackgroundColor3 = color, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, ox or 0, 0.5, oy or 0),
            Size = UDim2.new(0, d, 0, d), ZIndex = zi, Parent = parent,
        }, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
    end
    local function ring(d, thick, ox, oy)
        local f = create("Frame", {
            BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, ox or 0, 0.5, oy or 0),
            Size = UDim2.new(0, d, 0, d), ZIndex = zi, Parent = parent,
        })
        create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
        create("UIStroke", { Color = color, Thickness = thick or 2, Parent = f })
        return f
    end
    local t = math.max(2, math.floor(px * 0.09))

    if name == "minus" then
        bar(px * 0.5, t, 0, 0, 0)
    elseif name == "close" or name == "error" then
        bar(px * 0.6, t, 0, 0, 45)
        bar(px * 0.6, t, 0, 0, -45)
    elseif name == "success" or name == "check" then
        bar(px * 0.30, t, -px * 0.16, px * 0.08, 45)
        bar(px * 0.52, t, px * 0.07, -px * 0.04, -45)
    elseif name == "info" then
        dot(t + 1, 0, -px * 0.26)
        bar(t, px * 0.34, 0, px * 0.08, 0)
    elseif name == "warning" then
        bar(t, px * 0.32, 0, -px * 0.04, 0)
        dot(t, 0, px * 0.26)
    elseif name == "target" or name == "crosshair" then
        ring(px * 0.78, t * 0.8)
        dot(t, 0, 0)
        bar(px * 0.18, t * 0.7, 0, -px * 0.46, 0)
        bar(px * 0.18, t * 0.7, 0, px * 0.46, 0)
        bar(t * 0.7, px * 0.18, -px * 0.46, 0, 0)
        bar(t * 0.7, px * 0.18, px * 0.46, 0, 0)
    elseif name == "person" then
        dot(px * 0.34, 0, -px * 0.2)
        local body = create("Frame", {
            BackgroundColor3 = color, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -px * 0.06),
            Size = UDim2.new(0, px * 0.52, 0, px * 0.36), ZIndex = zi, Parent = parent,
        })
        create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = body })
    elseif name == "settings" or name == "sliders" then
        for i = 0, 2 do
            local y = -px * 0.26 + i * px * 0.26
            bar(px * 0.62, t * 0.8, 0, y, 0)
            dot(px * 0.2, (i % 2 == 0) and -px * 0.14 or px * 0.14, y)
        end
    elseif name == "home" then
        bar(px * 0.5, t, 0, px * 0.34, 45) -- placeholder roof line
        local b = create("Frame", { BackgroundColor3 = color, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.5, px * 0.34),
            Size = UDim2.new(0, px * 0.46, 0, px * 0.36), ZIndex = zi, Parent = parent })
        create("UICorner", { CornerRadius = UDim.new(0, 2), Parent = b })
    elseif name == "bolt" then
        bar(px * 0.18, px * 0.4, -px * 0.06, -px * 0.12, 20)
        bar(px * 0.18, px * 0.4, px * 0.06, px * 0.12, 20)
    elseif name == "eye" then
        ring(px * 0.5, t * 0.8)
        dot(px * 0.18, 0, 0)
    elseif name == "search" then
        ring(px * 0.46, t * 0.8, -px * 0.08, -px * 0.08)
        bar(px * 0.26, t * 0.9, px * 0.2, px * 0.2, 45)
    else
        -- fallback: a small filled dot
        dot(px * 0.4, 0, 0)
    end
end

-- Builds an icon element inside `parent`. `icon` may be a built-in name,
-- an image asset id (number / "rbxassetid://..."), or a short text fallback.
-- Returns the created element (compatible with setIconColor).
local function buildIconElement(parent, icon, color, px, fallback)
    if type(icon) == "string" and BUILTIN_ICONS[icon] then
        local holder = create("Frame", {
            BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, px, 0, px),
            ZIndex = (parent.ZIndex or 1) + 1, Parent = parent,
        })
        drawIcon(holder, icon, color, px)
        return holder
    end
    local isAsset = type(icon) == "number"
        or (type(icon) == "string" and (icon:match("^%d+$") or icon:match("^rbxassetid")
            or icon:match("^http") or icon:match("^rbxasset") or icon:match("^rbxthumb")))
    if isAsset then
        return create("ImageLabel", {
            BackgroundTransparency = 1, Image = toAssetId(icon), ImageColor3 = color,
            ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, px, 0, px),
            ZIndex = (parent.ZIndex or 1) + 1, Parent = parent,
        })
    end
    local txt = (type(icon) == "string" and icon ~= "" and icon) or fallback or "?"
    return create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        Font = FONT, TextSize = px, TextColor3 = color, Text = txt,
        ZIndex = (parent.ZIndex or 1) + 1, Parent = parent,
    })
end

----------------------------------------------------------------------
-- File API detection (exploit environments) with in-memory fallback
----------------------------------------------------------------------
local hasFileAPI = (typeof(writefile) == "function")
    and (typeof(readfile) == "function")
    and (typeof(isfile) == "function")

local FileSys
if hasFileAPI then
    FileSys = {
        write  = writefile,
        read   = readfile,
        exists = isfile,
        list   = (typeof(listfiles) == "function") and listfiles or function() return {} end,
        delete = (typeof(delfile) == "function") and delfile or function() end,
        mkdir  = (typeof(makefolder) == "function") and makefolder or function() end,
        isdir  = (typeof(isfolder) == "function") and isfolder or function() return false end,
    }
else
    -- In-memory virtual filesystem so the library still runs in Studio.
    local mem = {}
    FileSys = {
        write  = function(p, c) mem[p] = c end,
        read   = function(p) return mem[p] or "" end,
        exists = function(p) return mem[p] ~= nil end,
        list   = function() local t = {} for k in pairs(mem) do t[#t+1] = k end return t end,
        delete = function(p) mem[p] = nil end,
        mkdir  = function() end,
        isdir  = function() return true end,
    }
end

----------------------------------------------------------------------
-- Config Manager
----------------------------------------------------------------------
local ConfigManager = {}
ConfigManager.__index = ConfigManager

function ConfigManager.new(folder)
    local self = setmetatable({}, ConfigManager)
    self.Folder = folder or "VSCodeUILib"
    self.Flags = {}        -- flag -> { get = fn, set = fn }
    if not FileSys.isdir(self.Folder) then
        pcall(FileSys.mkdir, self.Folder)
    end
    return self
end

-- Register a flag so the config manager can read/write it.
function ConfigManager:Register(flag, getter, setter)
    if flag == nil then return end
    self.Flags[flag] = { get = getter, set = setter }
end

function ConfigManager:_path(name)
    return self.Folder .. "/" .. name .. ".json"
end

function ConfigManager:Save(name)
    name = name or "default"
    local data = {}
    for flag, fns in pairs(self.Flags) do
        local ok, val = pcall(fns.get)
        if ok then data[flag] = val end
    end
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if not ok then return false, "encode failed" end
    local ok2, err = pcall(FileSys.write, self:_path(name), encoded)
    if not ok2 then return false, err end
    return true
end

function ConfigManager:Load(name)
    name = name or "default"
    if not FileSys.exists(self:_path(name)) then
        return false, "config not found"
    end
    local ok, raw = pcall(FileSys.read, self:_path(name))
    if not ok then return false, raw end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok2 or type(data) ~= "table" then return false, "decode failed" end
    for flag, val in pairs(data) do
        local fns = self.Flags[flag]
        if fns and fns.set then
            pcall(fns.set, val)
        end
    end
    return true
end

function ConfigManager:Delete(name)
    name = name or "default"
    if FileSys.exists(self:_path(name)) then
        pcall(FileSys.delete, self:_path(name))
        return true
    end
    return false, "config not found"
end

function ConfigManager:List()
    local out = {}
    local ok, files = pcall(FileSys.list, self.Folder)
    if ok and type(files) == "table" then
        for _, f in ipairs(files) do
            local fname = tostring(f):match("([^/\\]+)%.json$")
            if fname then out[#out+1] = fname end
        end
    end
    return out
end

-- Autoload: remembers a config name to load automatically on next launch.
function ConfigManager:_autoloadPath()
    return self.Folder .. "/autoload.txt"
end

function ConfigManager:SetAutoload(name)
    pcall(FileSys.write, self:_autoloadPath(), tostring(name or ""))
    self._autoload = name
    return true
end

function ConfigManager:GetAutoload()
    if FileSys.exists(self:_autoloadPath()) then
        local ok, raw = pcall(FileSys.read, self:_autoloadPath())
        if ok and raw then
            local name = raw:match("^%s*(.-)%s*$")
            if name and name ~= "" then return name end
        end
    end
    return nil
end

function ConfigManager:ClearAutoload()
    if FileSys.exists(self:_autoloadPath()) then
        pcall(FileSys.delete, self:_autoloadPath())
    end
    self._autoload = nil
    return true
end

-- Loads the autoload config if one is set. Call AFTER the UI is built so all
-- flags are registered. Returns (loaded:boolean, name:string?).
function ConfigManager:LoadAutoload()
    local name = self:GetAutoload()
    if name then
        local ok = self:Load(name)
        return ok, name
    end
    return false, nil
end

UILib.ConfigManager = ConfigManager

----------------------------------------------------------------------
-- Root ScreenGui (protected when possible)
----------------------------------------------------------------------
local function getGuiParent()
    if RunService:IsStudio() then
        return LocalPlayer:WaitForChild("PlayerGui")
    end
    local ok, hidden = pcall(function() return gethui and gethui() end)
    if ok and hidden then return hidden end
    return CoreGui
end

local ScreenGui = create("ScreenGui", {
    Name = "VSCodeUILib_" .. tostring(math.random(1000, 9999)),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
})

-- syn.protect_gui support for some executors
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end
end)
ScreenGui.Parent = getGuiParent()
UILib.ScreenGui = ScreenGui

----------------------------------------------------------------------
-- Notifications
----------------------------------------------------------------------
local notifyHolder = create("Frame", {
    Name = "Notifications",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -18, 1, -44),
    Size = UDim2.new(0, 300, 1, -60),
    BackgroundTransparency = 1,
    ZIndex = 200,
    Parent = ScreenGui,
}, {
    create("UIListLayout", {
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
    }),
})

local NOTIFY_STYLES = {
    info    = { color = Theme.Accent,  icon = "info" },
    success = { color = Theme.Success, icon = "success" },
    warning = { color = Theme.Warning, icon = "warning" },
    error   = { color = Theme.Error,   icon = "error" },
}

function UILib:Notify(opts)
    opts = opts or {}
    local title  = opts.Title or "Notification"
    local text   = opts.Text or ""
    local dur    = opts.Duration or 3
    local style  = NOTIFY_STYLES[opts.Type or "info"] or NOTIFY_STYLES.info
    local accent = opts.Accent or style.color

    -- outer (managed by the list layout)
    local outer = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 200,
        Parent = notifyHolder,
    })
    local uiScale = create("UIScale", { Scale = 0.9, Parent = outer })

    local card = create("Frame", {
        BackgroundColor3 = Theme.SideBar,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 200, Parent = outer,
    })
    corner(card, 8)
    local cardStroke = stroke(card, Theme.Border, 1, 0.2)

    -- icon chip
    local chip = create("Frame", {
        BackgroundColor3 = accent, BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(0, 26, 0, 26),
        ZIndex = 201, Parent = card,
    })
    corner(chip, 8)
    drawIcon(chip, style.icon, Theme.TextBright, 26)

    local body = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 50, 0, 0), Size = UDim2.new(1, -64, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 201, Parent = card,
    }, {
        create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
        create("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }),
    })
    local titleLbl = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
        Font = FONT, TextSize = 14, TextColor3 = Theme.TextBright,
        TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        Text = title, ZIndex = 201, Parent = body,
    })
    local msgLbl = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = FONT_UI, TextSize = 12, TextColor3 = Theme.TextDim,
        TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, Text = text, ZIndex = 201, Parent = body,
    })

    -- progress bar
    local track = create("Frame", {
        BackgroundColor3 = Theme.Editor, BorderSizePixel = 0,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 3), ZIndex = 201, Parent = card,
    })
    local prog = create("Frame", {
        BackgroundColor3 = accent, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0), ZIndex = 201, Parent = track,
    })

    -- click anywhere to dismiss
    local dismissBtn = create("TextButton", {
        BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 202, Parent = card,
    })

    local closed = false
    local function close()
        if closed then return end
        closed = true
        tween(card, 0.25, { BackgroundTransparency = 1 })
        tween(cardStroke, 0.25, { Transparency = 1 })
        tween(titleLbl, 0.2, { TextTransparency = 1 })
        tween(msgLbl, 0.2, { TextTransparency = 1 })
        TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.9 }):Play()
        task.wait(0.26)
        outer:Destroy()
    end
    dismissBtn.MouseButton1Click:Connect(function() task.spawn(close) end)

    -- entrance
    tween(card, 0.25, { BackgroundTransparency = 0 })
    tween(titleLbl, 0.3, { TextTransparency = 0 })
    tween(msgLbl, 0.3, { TextTransparency = 0 })
    tween(track, 0.25, { BackgroundTransparency = 0.4 })
    TweenService:Create(uiScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    tween(prog, dur, { Size = UDim2.new(0, 0, 1, 0) })

    task.delay(dur, function() task.spawn(close) end)
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
function UILib:CreateWindow(opts)
    opts = opts or {}
    local window = setmetatable({}, UILib)
    window.Title    = opts.Title or "VS Code UI"
    window.Subtitle = opts.Subtitle or "Untitled - Visual Studio Code"
    window.Tabs     = {}
    window.ActiveTab = nil
    window.ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift
    window.Config   = ConfigManager.new(opts.ConfigFolder or "VSCodeUILib")
    window._connections = {}
    function window:_track(conn) table.insert(self._connections, conn); return conn end

    local size = opts.Size or UDim2.new(0, 720, 0, 460)

    -- Holder: the drag + scale target (transparent wrapper) ----------
    local holder = create("Frame", {
        Name = "Holder",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = size,
        BackgroundTransparency = 1,
        Visible = false,
        Parent = ScreenGui,
    })
    local uiScale = create("UIScale", { Scale = 1, Parent = holder })
    window.Holder = holder
    window.UIScale = uiScale

    -- Root window frame ----------------------------------------------
    local root = create("Frame", {
        Name = "Window",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.Editor,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 1,
        Parent = holder,
    })
    corner(root, 8)
    stroke(root, Theme.Border, 1)
    window.Root = root

    -- Overlay layer for dropdowns / popups (renders above everything) -
    local overlay = create("Frame", {
        Name = "Overlay",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 50,
        Parent = holder,
    })
    window.Overlay = overlay

    -- Tab hover tooltip (slides out showing the tab name)
    local tooltip = create("Frame", {
        Name = "TabTooltip", BackgroundColor3 = Theme.TitleBar, Visible = false,
        AnchorPoint = Vector2.new(0, 0.5), AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 0, 26), ZIndex = 60, Parent = overlay,
    })
    corner(tooltip, 6)
    stroke(tooltip, Theme.Border, 1)
    local ttScale = create("UIScale", { Scale = 1, Parent = tooltip })
    local ttLabel = create("TextLabel", {
        BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0), Font = FONT, TextSize = 13, TextColor3 = Theme.Text,
        Text = "", ZIndex = 61, Parent = tooltip,
    }, {
        create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
    })
    function window:_showTabTooltip(text, iconBtn)
        ttLabel.Text = text
        local relY = iconBtn.AbsolutePosition.Y + iconBtn.AbsoluteSize.Y / 2 - root.AbsolutePosition.Y
        tooltip.Position = UDim2.fromOffset(54, relY)
        tooltip.Visible = true
        ttScale.Scale = 0
        TweenService:Create(ttScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    end
    function window:_hideTabTooltip()
        local t = TweenService:Create(ttScale, TweenInfo.new(0.12), { Scale = 0 })
        t:Play()
        t.Completed:Once(function() if ttScale.Scale < 0.05 then tooltip.Visible = false end end)
    end

    ------------------------------------------------------------------
    -- Title bar (window chrome)
    ------------------------------------------------------------------
    local titleBar = create("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Theme.TitleBar,
        BorderSizePixel = 0,
        Parent = root,
    })
    -- traffic lights
    local lights = { Color3.fromRGB(255, 95, 86), Color3.fromRGB(255, 189, 46), Color3.fromRGB(39, 201, 63) }
    for i, c in ipairs(lights) do
        create("Frame", {
            BackgroundColor3 = c, BorderSizePixel = 0,
            Position = UDim2.new(0, 8 + (i - 1) * 18, 0.5, -6),
            Size = UDim2.new(0, 12, 0, 12), Parent = titleBar,
        }, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
    end
    create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -160, 1, 0),
        Position = UDim2.new(0, 80, 0, 0),
        Font = FONT_UI, TextSize = 13, TextColor3 = Theme.TextDim,
        Text = window.Subtitle, TextXAlignment = Enum.TextXAlignment.Center,
        Parent = titleBar,
    })
    -- minimize + close (destroy), top-right, drawn icons -------------
    local function chromeButton(xOffset, iconName)
        local btn = create("TextButton", {
            BackgroundColor3 = Theme.Hover, BackgroundTransparency = 1,
            AutoButtonColor = false, Text = "",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, xOffset, 0.5, 0),
            Size = UDim2.new(0, 28, 0, 22), Parent = titleBar,
        })
        corner(btn, 5)
        local holder = create("Frame", {
            BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 14, 0, 14),
            Parent = btn,
        })
        drawIcon(holder, iconName, Theme.TextDim, 14)
        return btn, holder
    end
    local minBtn, minIcon = chromeButton(-40, "minus")
    local closeBtn, closeIcon = chromeButton(-8, "close")

    minBtn.MouseEnter:Connect(function()
        tween(minBtn, 0.1, { BackgroundTransparency = 0.5 }); setIconColor(minIcon, Theme.TextBright)
    end)
    minBtn.MouseLeave:Connect(function()
        tween(minBtn, 0.1, { BackgroundTransparency = 1 }); setIconColor(minIcon, Theme.TextDim)
    end)
    closeBtn.MouseEnter:Connect(function()
        closeBtn.BackgroundColor3 = Theme.Error
        tween(closeBtn, 0.1, { BackgroundTransparency = 0 }); setIconColor(closeIcon, Theme.TextBright)
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, 0.1, { BackgroundTransparency = 1 }); setIconColor(closeIcon, Theme.TextDim)
    end)
    -- minimize hides the window (reopen via the toggle button / key); close destroys it
    minBtn.MouseButton1Click:Connect(function() window:SetOpen(false) end)
    closeBtn.MouseButton1Click:Connect(function() window:Destroy() end)

    -- Dragging
    do
        local dragging, dragStart, startPos
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = holder.Position
            end
        end)
        window:_track(UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                holder.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end))
        window:_track(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end))
    end

    ------------------------------------------------------------------
    -- Body container (below title, above status)
    ------------------------------------------------------------------
    local body = create("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 30),
        Size = UDim2.new(1, 0, 1, -52),
        Parent = root,
    })

    -- Activity bar (far left icons -> one per tab)
    local activityBar = create("Frame", {
        Name = "ActivityBar",
        BackgroundColor3 = Theme.ActivityBar, BorderSizePixel = 0,
        Size = UDim2.new(0, 48, 1, 0), Parent = body,
    }, {
        create("UIListLayout", {
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        create("UIPadding", { PaddingTop = UDim.new(0, 8) }),
    })
    window.ActivityBar = activityBar

    -- Side bar (tab title + section list)
    local sideBar = create("Frame", {
        Name = "SideBar",
        BackgroundColor3 = Theme.SideBar, BorderSizePixel = 0,
        Position = UDim2.new(0, 48, 0, 0),
        Size = UDim2.new(0, 180, 1, 0), Parent = body,
    })
    create("TextLabel", {
        Name = "Header", BackgroundTransparency = 1,
        Size = UDim2.new(1, -24, 0, 35), Position = UDim2.new(0, 12, 0, 0),
        Font = FONT, TextSize = 12, TextColor3 = Theme.TextDim,
        Text = string.upper(window.Title), TextXAlignment = Enum.TextXAlignment.Left,
        Parent = sideBar,
    })
    window.SideBar = sideBar

    -- Editor (scrolling content area for the active tab)
    local editorHolder = create("Frame", {
        Name = "Editor", BackgroundColor3 = Theme.Editor, BorderSizePixel = 0,
        Position = UDim2.new(0, 228, 0, 0),
        Size = UDim2.new(1, -228, 1, 0), Parent = body,
    })
    window.EditorHolder = editorHolder

    ------------------------------------------------------------------
    -- Status bar
    ------------------------------------------------------------------
    local statusBar = create("Frame", {
        Name = "StatusBar",
        BackgroundColor3 = Theme.StatusBar, BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -22),
        Size = UDim2.new(1, 0, 0, 22), Parent = root,
    })
    create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.5, -8, 1, 0), Position = UDim2.new(0, 10, 0, 0),
        Font = FONT, TextSize = 12, TextColor3 = Theme.TextBright,
        Text = window.Title, TextXAlignment = Enum.TextXAlignment.Left,
        Parent = statusBar,
    })
    window.StatusLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.5, -8, 1, 0), Position = UDim2.new(0.5, 0, 0, 0),
        Font = FONT, TextSize = 12, TextColor3 = Theme.TextBright,
        Text = "Ln 1, Col 1    UTF-8    Lua", TextXAlignment = Enum.TextXAlignment.Right,
        Parent = statusBar,
    })

    ------------------------------------------------------------------
    -- Open / close animation + state
    ------------------------------------------------------------------
    local OPEN_INFO  = TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local CLOSE_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    window._open = true

    function window:_updateHamburger()
        local hb = self.Hamburger
        if not hb then return end
        local hbScale = hb:FindFirstChildOfClass("UIScale")
        if self._open then
            local t = TweenService:Create(hbScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
            t:Play()
            t.Completed:Once(function() if self._open then hb.Visible = false end end)
        else
            hb.Visible = true
            hbScale.Scale = 0
            TweenService:Create(hbScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        end
    end

    function window:SetOpen(open, instant)
        self._open = open and true or false
        if self._activeDropdownClose then self._activeDropdownClose() end
        if self._open then
            holder.Visible = true
            if instant then
                uiScale.Scale = 1
            else
                uiScale.Scale = 0.8
                TweenService:Create(uiScale, OPEN_INFO, { Scale = 1 }):Play()
            end
        else
            if instant then
                holder.Visible = false
            else
                local t = TweenService:Create(uiScale, CLOSE_INFO, { Scale = 0.8 })
                t:Play()
                t.Completed:Once(function()
                    if not self._open then holder.Visible = false end
                end)
            end
        end
        self:_updateHamburger()
    end

    function window:Toggle() self:SetOpen(not self._open) end

    function window:SetToggleKey(key)
        if type(key) == "string" then key = Enum.KeyCode[key] end
        if key then self.ToggleKey = key end
    end

    -- Fully tears down the window (disconnects inputs, removes GUI).
    function window:Destroy()
        if self._destroyed then return end
        self._destroyed = true
        if self._activeDropdownClose then self._activeDropdownClose() end
        for _, c in ipairs(self._connections) do
            pcall(function() c:Disconnect() end)
        end
        table.clear(self._connections)
        if self.Hamburger then self.Hamburger:Destroy(); self.Hamburger = nil end
        local t = TweenService:Create(uiScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
        t:Play()
        t.Completed:Once(function() holder:Destroy() end)
    end

    ------------------------------------------------------------------
    -- Floating toggle button (custom logo or 3-line icon, draggable)
    ------------------------------------------------------------------
    local logoId = toAssetId(opts.Logo)
    local hbSize = opts.ToggleSize or 52
    local hb = create("TextButton", {
        Name = "ToggleButton",
        Size = UDim2.new(0, hbSize, 0, hbSize),
        BackgroundColor3 = Theme.Accent,
        AutoButtonColor = false, Text = "",
        Visible = false, ZIndex = 150, Parent = ScreenGui,
    })
    -- position: "left" (default), "center", or a custom UDim2
    local tp = opts.TogglePosition
    if typeof(tp) == "UDim2" then
        hb.Position = tp
    elseif tp == "center" then
        hb.AnchorPoint = Vector2.new(0.5, 0.5)
        hb.Position = UDim2.new(0.5, 0, 0.5, 0)
    else -- left
        hb.Position = UDim2.new(0, 22, 0, 120)
    end
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = hb }) -- circle
    hb.ClipsDescendants = true
    create("UIScale", { Scale = 1, Parent = hb })

    local hasLogo = logoId ~= nil
    if hasLogo then
        -- logo only: circular, no accent box, just the image
        hb.BackgroundTransparency = 1
        local logo = create("ImageLabel", {
            Name = "Logo", BackgroundTransparency = 1, Image = logoId,
            ScaleType = Enum.ScaleType.Crop, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 151, Parent = hb,
        })
        create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = logo }) -- round the image itself
    else
        -- accent circle with a 3-line (hamburger) icon
        stroke(hb, Color3.fromRGB(255, 255, 255), 1, 0.55)
        for i = 1, 3 do
            create("Frame", {
                BackgroundColor3 = Theme.TextBright, BorderSizePixel = 0,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, (i - 2) * 8),
                Size = UDim2.new(0, 22, 0, 3), ZIndex = 151, Parent = hb,
            }, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
        end
    end
    window.Hamburger = hb
    local hbScaleInst = hb:FindFirstChildOfClass("UIScale")
    hb.MouseEnter:Connect(function()
        if not hasLogo then tween(hb, 0.12, { BackgroundColor3 = Theme.AccentDim }) end
        TweenService:Create(hbScaleInst, TweenInfo.new(0.12), { Scale = 1.1 }):Play()
    end)
    hb.MouseLeave:Connect(function()
        if not hasLogo then tween(hb, 0.12, { BackgroundColor3 = Theme.Accent }) end
        TweenService:Create(hbScaleInst, TweenInfo.new(0.12), { Scale = 1 }):Play()
    end)
    do
        local dragging, moved, dragStart, startPos
        hb.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; moved = false
                dragStart = input.Position; startPos = hb.Position
            end
        end)
        window:_track(UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                if delta.Magnitude > 5 then moved = true end
                hb.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end))
        window:_track(UserInputService.InputEnded:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false
                if not moved then window:Toggle() end
            end
        end))
    end

    -- toggle key
    window:_track(UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == window.ToggleKey then
            window:Toggle()
        end
    end))

    -- startup open animation
    holder.Visible = true
    uiScale.Scale = 0.8
    TweenService:Create(uiScale, OPEN_INFO, { Scale = 1 }):Play()

    return window
end

----------------------------------------------------------------------
-- Tabs
----------------------------------------------------------------------
function UILib:CreateTab(opts)
    opts = opts or {}
    local window = self
    local tab = setmetatable({}, UILib)
    tab.Window = window
    tab.Name = opts.Name or "Tab"
    tab.Sections = {}

    -- Activity bar icon button
    local iconBtn = create("TextButton", {
        BackgroundColor3 = Theme.Hover, BackgroundTransparency = 1,
        Size = UDim2.new(0, 40, 0, 40), AutoButtonColor = false,
        Text = "", Parent = window.ActivityBar,
    })
    corner(iconBtn, 6)
    local iconEl = buildIconElement(iconBtn, opts.Icon, Theme.TextDim, 22,
        string.sub(tab.Name, 1, 1):upper())
    tab._setIconColor = function(c) setIconColor(iconEl, c) end
    -- selection indicator bar
    local indicator = create("Frame", {
        BackgroundColor3 = Theme.TextBright, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, -4, 0.5, 0), Size = UDim2.new(0, 2, 0, 0),
        Parent = iconBtn,
    })
    corner(indicator, 2)
    tab.IconButton = iconBtn

    -- Side bar page: list of section headers for this tab (acts like explorer)
    local sidePage = create("ScrollingFrame", {
        BackgroundTransparency = 1, Visible = false,
        Position = UDim2.new(0, 0, 0, 35),
        Size = UDim2.new(1, 0, 1, -35),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Border,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = window.SideBar,
    }, {
        create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
        create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
    })
    tab.SidePage = sidePage

    -- Editor page: where sections actually render
    local editorPage = create("ScrollingFrame", {
        BackgroundTransparency = 1, Visible = false,
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.Border,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = window.EditorHolder,
    }, {
        create("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
        create("UIPadding", {
            PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16),
            PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16),
        }),
    })
    tab.EditorPage = editorPage

    function tab:Select()
        if window._activeDropdownClose then window._activeDropdownClose() end
        for _, t in ipairs(window.Tabs) do
            t.SidePage.Visible = false
            t.EditorPage.Visible = false
            t._setIconColor(Theme.TextDim)
            tween(t.IconButton, 0.15, { BackgroundTransparency = 1 })
            tween(t._indicator, 0.15, { Size = UDim2.new(0, 2, 0, 0) })
        end
        sidePage.Visible = true
        editorPage.Visible = true
        tab._setIconColor(Theme.TextBright)
        tween(iconBtn, 0.15, { BackgroundTransparency = 0 })
        tween(indicator, 0.2, { Size = UDim2.new(0, 2, 0, 24) })
        window.ActiveTab = tab
        if window.StatusLabel then
            window.StatusLabel.Text = "Tab: " .. tab.Name .. "    UTF-8    Lua"
        end

        -- subtle slide + fade-in of the content
        editorPage.Position = UDim2.new(0, 0, 0, 12)
        tween(editorPage, 0.22, { Position = UDim2.new(0, 0, 0, 0) })
    end
    tab._indicator = indicator
    iconBtn.BackgroundTransparency = 1

    iconBtn.MouseEnter:Connect(function()
        window:_showTabTooltip(tab.Name, iconBtn)
        if window.ActiveTab ~= tab then
            tab._setIconColor(Theme.Text)
            tween(iconBtn, 0.12, { BackgroundTransparency = 0.4 })
        end
    end)
    iconBtn.MouseLeave:Connect(function()
        window:_hideTabTooltip()
        if window.ActiveTab ~= tab then
            tab._setIconColor(Theme.TextDim)
            tween(iconBtn, 0.12, { BackgroundTransparency = 1 })
        end
    end)
    iconBtn.MouseButton1Click:Connect(function() tab:Select() end)

    table.insert(window.Tabs, tab)
    if #window.Tabs == 1 then tab:Select() end
    return tab
end

----------------------------------------------------------------------
-- Sections
----------------------------------------------------------------------
function UILib:CreateSection(title)
    local tab = self
    local window = tab.Window
    local section = setmetatable({}, UILib)
    section.Tab = tab
    section.Window = window
    section._entries = {}
    section._title = title or "Section"

    -- Side bar entry (jump target)
    local sideEntry = create("TextButton", {
        BackgroundColor3 = Theme.Hover, BackgroundTransparency = 1,
        AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 24),
        Font = FONT, Text = "  ▸ " .. (title or "Section"), TextSize = 12,
        TextColor3 = Theme.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
        Parent = tab.SidePage,
    })
    corner(sideEntry, 4)
    section._sideEntry = sideEntry
    sideEntry.MouseEnter:Connect(function() tween(sideEntry, 0.12, { BackgroundTransparency = 0 }) end)
    sideEntry.MouseLeave:Connect(function() tween(sideEntry, 0.12, { BackgroundTransparency = 1 }) end)

    -- Editor container card
    local card = create("Frame", {
        BackgroundColor3 = Theme.SideBar, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Parent = tab.EditorPage,
    })
    corner(card, 6)
    stroke(card, Theme.Border, 1)
    section._card = card

    local headerBtn = create("TextButton", {
        BackgroundTransparency = 1, AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 36), Text = "", Parent = card,
    })
    local titleLbl = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        Font = FONT, TextSize = 14, TextColor3 = Theme.TextBright,
        Text = "# " .. (title or "Section"), TextXAlignment = Enum.TextXAlignment.Left,
        Parent = headerBtn,
    })
    local chevron = create("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.new(0, 14, 0, 14),
        Font = FONT, TextSize = 12, TextColor3 = Theme.TextDim, Text = "▾",
        Parent = headerBtn,
    })

    local content = create("Frame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 36),
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Parent = card,
    }, {
        create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
        create("UIPadding", {
            PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
        }),
    })
    section.Content = content

    -- Collapsible
    section._collapsed = false
    function section:Collapse(state)
        if state == nil then state = not self._collapsed end
        self._collapsed = state and true or false
        content.Visible = not self._collapsed
        if self.Window._activeDropdownClose then self.Window._activeDropdownClose() end
        TweenService:Create(chevron, TweenInfo.new(0.2), { Rotation = self._collapsed and -90 or 0 }):Play()
    end
    headerBtn.MouseButton1Click:Connect(function() section:Collapse() end)
    headerBtn.MouseEnter:Connect(function()
        tween(titleLbl, 0.12, { TextColor3 = Theme.Accent })
        tween(chevron, 0.12, { TextColor3 = Theme.Accent })
    end)
    headerBtn.MouseLeave:Connect(function()
        tween(titleLbl, 0.12, { TextColor3 = Theme.TextBright })
        tween(chevron, 0.12, { TextColor3 = Theme.TextDim })
    end)

    sideEntry.MouseButton1Click:Connect(function()
        local pos = card.AbsolutePosition.Y - tab.EditorPage.AbsolutePosition.Y + tab.EditorPage.CanvasPosition.Y
        tween(tab.EditorPage, 0.25, { CanvasPosition = Vector2.new(0, math.max(0, pos - 16)) })
    end)

    if tab.Sections then table.insert(tab.Sections, section) end
    return section
end

-- Registers an element row with its section so the search box can filter it.
function UILib:_addEntry(inst, text)
    if self._entries then
        table.insert(self._entries, { row = inst, text = tostring(text or ""):lower() })
    end
end

-- Base row used by most elements
local function makeRow(parent, height)
    local row = create("Frame", {
        BackgroundColor3 = Theme.Editor, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height or 32),
        Parent = parent,
    })
    corner(row, 4)
    return row
end

-- Row with a left-aligned title and an optional dim description line below.
-- `labelScale` controls how much horizontal room the text gets (rest is for the control).
-- Returns: row, titleLabel
local function labeledRow(parent, name, description, labelScale)
    local hasDesc = description ~= nil and tostring(description) ~= ""
    local row = makeRow(parent, hasDesc and 48 or 32)
    labelScale = labelScale or 0.6
    local title = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(labelScale, -12, hasDesc and 0 or 1, hasDesc and 18 or 0),
        Font = FONT, TextSize = 13, TextColor3 = Theme.Text,
        Text = name, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = hasDesc and Enum.TextYAlignment.Bottom or Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
    })
    if hasDesc then
        title.Position = UDim2.new(0, 12, 0, 7)
        create("TextLabel", {
            Name = "Description", BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 26),
            Size = UDim2.new(labelScale + 0.1, -12, 0, 15),
            Font = FONT_UI, TextSize = 11, TextColor3 = Theme.TextDim,
            Text = description, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
        })
    end
    return row, title
end

----------------------------------------------------------------------
-- Elements
----------------------------------------------------------------------
function UILib:CreateLabel(text)
    local lbl = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
        Font = FONT_UI, TextSize = 13, TextColor3 = Theme.TextDim,
        Text = text or "Label", TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
        Parent = self.Content,
    })
    self:_addEntry(lbl, text)
    return {
        Set = function(_, t) lbl.Text = t end,
        Instance = lbl,
    }
end

function UILib:CreateButton(opts)
    opts = opts or {}
    local hasDesc = opts.Description ~= nil and tostring(opts.Description) ~= ""
    local row = makeRow(self.Content, hasDesc and 46 or 34)
    self:_addEntry(row, (opts.Name or "") .. " " .. (opts.Description or ""))
    local btnStroke = stroke(row, Theme.Border, 1, 0.4)
    local scale = create("UIScale", { Scale = 1, Parent = row })
    local btn = create("TextButton", {
        BackgroundTransparency = 1, AutoButtonColor = false,
        Size = UDim2.new(1, 0, hasDesc and 0 or 1, hasDesc and 24 or 0),
        Position = UDim2.new(0, 0, 0, hasDesc and 8 or 0),
        Font = FONT, TextSize = 13, TextColor3 = Theme.Text,
        Text = opts.Name or "Button", Parent = row,
    })
    local descLbl
    if hasDesc then
        descLbl = create("TextLabel", {
            Name = "Description", BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 0, 14),
            Font = FONT_UI, TextSize = 11, TextColor3 = Theme.TextDim,
            Text = opts.Description, TextXAlignment = Enum.TextXAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
        })
    end
    btn.MouseEnter:Connect(function()
        tween(row, 0.13, { BackgroundColor3 = Theme.Accent })
        tween(btnStroke, 0.13, { Color = Theme.Accent })
        tween(btn, 0.13, { TextColor3 = Theme.TextBright })
        if descLbl then tween(descLbl, 0.13, { TextColor3 = Theme.TextBright }) end
    end)
    btn.MouseLeave:Connect(function()
        tween(row, 0.13, { BackgroundColor3 = Theme.Editor })
        tween(btnStroke, 0.13, { Color = Theme.Border })
        tween(btn, 0.13, { TextColor3 = Theme.Text })
        if descLbl then tween(descLbl, 0.13, { TextColor3 = Theme.TextDim }) end
    end)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.97 }):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        if opts.Callback then task.spawn(opts.Callback) end
    end)
    return { Instance = btn }
end

function UILib:CreateToggle(opts)
    opts = opts or {}
    local window = self.Window
    local state = opts.Default or false

    local row = labeledRow(self.Content, opts.Name or "Toggle", opts.Description, 0.7)
    self:_addEntry(row, (opts.Name or "") .. " " .. (opts.Description or ""))
    -- switch
    local track = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0, 38, 0, 18), BackgroundColor3 = Theme.Input,
        BorderSizePixel = 0, Parent = row,
    })
    corner(track, 9)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = Theme.TextDim,
        BorderSizePixel = 0, Parent = track,
    })
    corner(knob, 7)

    local clickBtn = create("TextButton", {
        BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, 0), Parent = row,
    })

    local api = {}
    function api:Set(v)
        state = v and true or false
        if state then
            tween(track, 0.15, { BackgroundColor3 = Theme.Accent })
            tween(knob, 0.15, { Position = UDim2.new(1, -16, 0.5, 0), BackgroundColor3 = Theme.TextBright })
        else
            tween(track, 0.15, { BackgroundColor3 = Theme.Input })
            tween(knob, 0.15, { Position = UDim2.new(0, 2, 0.5, 0), BackgroundColor3 = Theme.TextDim })
        end
        if opts.Callback then task.spawn(opts.Callback, state) end
    end
    function api:Get() return state end

    clickBtn.MouseButton1Click:Connect(function() api:Set(not state) end)
    api:Set(state)

    if opts.Flag then
        window.Config:Register(opts.Flag, function() return api:Get() end, function(v) api:Set(v) end)
    end
    return api
end

function UILib:CreateSlider(opts)
    opts = opts or {}
    local window = self.Window
    local min = opts.Min or 0
    local max = opts.Max or 100
    local decimals = opts.Decimals or 0
    local value = math.clamp(opts.Default or min, min, max)

    local function round(n)
        local m = 10 ^ decimals
        return math.floor(n * m + 0.5) / m
    end

    local hasDesc = opts.Description ~= nil and tostring(opts.Description) ~= ""
    local row = makeRow(self.Content, hasDesc and 62 or 46)
    self:_addEntry(row, (opts.Name or "") .. " " .. (opts.Description or ""))
    create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -70, 0, 22),
        Position = UDim2.new(0, 12, 0, 2),
        Font = FONT, TextSize = 13, TextColor3 = Theme.Text,
        Text = opts.Name or "Slider", TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    if hasDesc then
        create("TextLabel", {
            Name = "Description", BackgroundTransparency = 1,
            Size = UDim2.new(1, -24, 0, 14), Position = UDim2.new(0, 12, 0, 24),
            Font = FONT_UI, TextSize = 11, TextColor3 = Theme.TextDim,
            Text = opts.Description, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
        })
    end
    local valLabel = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(0, 60, 0, 22),
        Position = UDim2.new(1, -70, 0, 2),
        Font = FONT, TextSize = 13, TextColor3 = Theme.Accent,
        Text = tostring(value), TextXAlignment = Enum.TextXAlignment.Right,
        Parent = row,
    })
    local bar = create("Frame", {
        Position = UDim2.new(0, 12, 1, -16), Size = UDim2.new(1, -24, 0, 6),
        BackgroundColor3 = Theme.Input, BorderSizePixel = 0, Parent = row,
    })
    corner(bar, 3)
    local fill = create("Frame", {
        Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = bar,
    })
    corner(fill, 3)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 12, 0, 12), BackgroundColor3 = Theme.TextBright,
        BorderSizePixel = 0, Parent = fill,
    })
    corner(knob, 6)

    local api = {}
    function api:Set(v)
        value = math.clamp(round(v), min, max)
        local pct = (value - min) / (max - min)
        tween(fill, 0.08, { Size = UDim2.new(pct, 0, 1, 0) })
        valLabel.Text = (opts.Suffix and (tostring(value) .. opts.Suffix)) or tostring(value)
        if opts.Callback then task.spawn(opts.Callback, value) end
    end
    function api:Get() return value end

    local dragging = false
    local function update(input)
        local pct = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        api:Set(min + (max - min) * pct)
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; update(input) end
    end)
    window:_track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then update(input) end
    end))
    window:_track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
    api:Set(value)

    if opts.Flag then
        window.Config:Register(opts.Flag, function() return api:Get() end, function(v) api:Set(v) end)
    end
    return api
end

function UILib:CreateTextbox(opts)
    opts = opts or {}
    local window = self.Window
    local value = opts.Default or ""

    local row = labeledRow(self.Content, opts.Name or "Input", opts.Description, 0.4)
    self:_addEntry(row, (opts.Name or "") .. " " .. (opts.Description or ""))
    local boxFrame = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0.55, 0, 0, 24), BackgroundColor3 = Theme.Input,
        BorderSizePixel = 0, Parent = row,
    })
    corner(boxFrame, 4)
    local inputStroke = stroke(boxFrame, Theme.Border, 1)
    local box = create("TextBox", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        Font = FONT, TextSize = 13, TextColor3 = Theme.Text,
        PlaceholderText = opts.Placeholder or "", PlaceholderColor3 = Theme.TextDim,
        Text = value, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = boxFrame,
    })
    box.Focused:Connect(function() tween(inputStroke, 0.1, { Color = Theme.Accent }) end)
    box.FocusLost:Connect(function(enter)
        tween(inputStroke, 0.1, { Color = Theme.Border })
        value = box.Text
        if opts.Callback then task.spawn(opts.Callback, value, enter) end
    end)

    local api = {}
    function api:Set(v) value = tostring(v); box.Text = value end
    function api:Get() return value end
    if opts.Flag then
        window.Config:Register(opts.Flag, function() return api:Get() end, function(v) api:Set(v) end)
    end
    return api
end

function UILib:CreateKeybind(opts)
    opts = opts or {}
    local window = self.Window
    local current = opts.Default
    local listening = false

    local row = labeledRow(self.Content, opts.Name or "Keybind", opts.Description, 0.6)
    self:_addEntry(row, (opts.Name or "") .. " " .. (opts.Description or ""))
    local keyBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0, 80, 0, 24), BackgroundColor3 = Theme.Input,
        AutoButtonColor = false, Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
        Text = current and current.Name or "None", Parent = row,
    })
    corner(keyBtn, 4)
    stroke(keyBtn, Theme.Border, 1)

    local api = {}
    function api:Set(key)
        if type(key) == "string" then key = Enum.KeyCode[key] end
        current = key
        keyBtn.Text = current and current.Name or "None"
    end
    function api:Get() return current and current.Name or nil end

    keyBtn.MouseButton1Click:Connect(function()
        listening = true
        keyBtn.Text = "..."
        keyBtn.TextColor3 = Theme.Accent
    end)
    window:_track(UserInputService.InputBegan:Connect(function(input, gpe)
        if listening and input.UserInputType == Enum.UserInputType.Keyboard then
            listening = false
            keyBtn.TextColor3 = Theme.Text
            api:Set(input.KeyCode)
            if opts.Callback then task.spawn(opts.Callback, input.KeyCode) end
        elseif not gpe and current and input.KeyCode == current then
            if opts.OnPress then task.spawn(opts.OnPress) end
        end
    end))
    api:Set(current)
    if opts.Flag then
        window.Config:Register(opts.Flag, function() return api:Get() end, function(v) if v then api:Set(v) end end)
    end
    return api
end

function UILib:CreateDropdown(opts)
    opts = opts or {}
    local window = self.Window
    local options = opts.Options or {}
    local multi = opts.Multi or false
    local selected = multi and (opts.Default or {}) or (opts.Default)
    local open = false
    local outsideConn
    local filterText = ""

    local ITEM_H, MAX_H = 30, 190

    local row = labeledRow(self.Content, opts.Name or "Dropdown", opts.Description, 0.4)
    self:_addEntry(row, (opts.Name or "") .. " " .. (opts.Description or ""))
    local ddBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0.55, 0, 0, 24), BackgroundColor3 = Theme.Input,
        AutoButtonColor = false, Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
        Text = "", TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
    })
    corner(ddBtn, 5)
    local ddStroke = stroke(ddBtn, Theme.Border, 1)
    create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 22), Parent = ddBtn })
    local arrow = create("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.new(0, 16, 1, 0),
        Font = FONT, TextSize = 12, TextColor3 = Theme.TextDim, Text = "⌄",
        Rotation = 0, Parent = ddBtn,
    })

    -- The list lives on the window overlay so it is never clipped by the
    -- scrolling editor and always renders above other elements.
    local listFrame = create("Frame", {
        Name = "DropdownList", BackgroundColor3 = Theme.SideBar,
        BorderSizePixel = 0, Visible = false, ZIndex = 51,
        Size = UDim2.new(0, 0, 0, 0), ClipsDescendants = true,
        Parent = window.Overlay,
    })
    corner(listFrame, 6)
    stroke(listFrame, Theme.Accent, 1, 0.2)

    -- optional search box (filters the options)
    local searchEnabled = opts.Search and true or false
    local searchH = searchEnabled and 34 or 0
    local searchBox
    if searchEnabled then
        local sf = create("Frame", {
            BackgroundColor3 = Theme.Input, BorderSizePixel = 0,
            Position = UDim2.new(0, 6, 0, 6), Size = UDim2.new(1, -12, 0, 24),
            ZIndex = 52, Parent = listFrame,
        })
        corner(sf, 4)
        stroke(sf, Theme.Border, 1)
        create("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(0, 18, 1, 0),
            Position = UDim2.new(0, 6, 0, 0), Font = FONT, TextSize = 12,
            TextColor3 = Theme.TextDim, Text = "⌕", ZIndex = 52, Parent = sf,
        })
        searchBox = create("TextBox", {
            BackgroundTransparency = 1, Size = UDim2.new(1, -30, 1, 0),
            Position = UDim2.new(0, 26, 0, 0), Font = FONT, TextSize = 12,
            TextColor3 = Theme.Text, PlaceholderText = "Search...",
            PlaceholderColor3 = Theme.TextDim, Text = "", ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 52, Parent = sf,
        })
    end

    local listScroll = create("ScrollingFrame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, searchH),
        Size = UDim2.new(1, 0, 1, -searchH),
        CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.Border, ZIndex = 51,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = listFrame,
    }, {
        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
        create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
            PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
    })

    local api = {}
    local function isSelected(o)
        if multi then
            for _, v in ipairs(selected) do if v == o then return true end end
            return false
        end
        return selected == o
    end
    local function displayText()
        if multi then
            local n = #selected
            if n == 0 then return opts.Placeholder or "Select..." end
            if #options > 0 and n == #options then return "All (" .. n .. ")" end
            if n == 1 then return tostring(selected[1]) end
            if n > 3 then
                return tostring(selected[1]) .. ", " .. tostring(selected[2]) .. " +" .. (n - 2) .. " more"
            end
            return table.concat(selected, ", ")
        end
        return selected and tostring(selected) or (opts.Placeholder or "Select...")
    end
    local function refresh()
        ddBtn.Text = displayText()
        local hasValue = (multi and #selected > 0) or (not multi and selected ~= nil)
        ddBtn.TextColor3 = hasValue and Theme.Text or Theme.TextDim
        for _, child in ipairs(listScroll:GetChildren()) do
            if child:IsA("TextButton") then
                local sel = isSelected(child.Name)
                tween(child, 0.1, { BackgroundColor3 = sel and Theme.Selected or Theme.SideBar })
                child.TextColor3 = sel and Theme.TextBright or Theme.Text
                local mark = child:FindFirstChild("Mark")
                if mark then mark.Text = sel and "✓" or "" end
            end
        end
    end

    local function pointIn(gui, pos)
        local p, s = gui.AbsolutePosition, gui.AbsoluteSize
        return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
    end

    local function matches(o)
        if filterText == "" then return true end
        return tostring(o):lower():find(filterText, 1, true) ~= nil
    end
    local function computeH()
        local vis = 0
        for _, o in ipairs(options) do if matches(o) then vis += 1 end end
        return searchH + math.min(math.max(vis, 1) * ITEM_H + 8, MAX_H)
    end
    local function applyFilter()
        for _, child in ipairs(listScroll:GetChildren()) do
            if child:IsA("TextButton") then child.Visible = matches(child.Name) end
        end
        if open then
            local w = listFrame.Size.X.Offset
            tween(listFrame, 0.12, { Size = UDim2.fromOffset(w, computeH()) })
        end
    end

    local function closeList()
        if not open then return end
        open = false
        if window._activeDropdownClose == closeList then window._activeDropdownClose = nil end
        if outsideConn then outsideConn:Disconnect(); outsideConn = nil end
        TweenService:Create(arrow, TweenInfo.new(0.15), { Rotation = 0 }):Play()
        local w = listFrame.Size.X.Offset
        local t = tween(listFrame, 0.13, { Size = UDim2.fromOffset(w, 0) })
        t.Completed:Once(function() if not open then listFrame.Visible = false end end)
    end

    local function openList()
        if open then return end
        if window._activeDropdownClose then window._activeDropdownClose() end
        open = true
        window._activeDropdownClose = closeList
        refresh()

        -- reset filter so the full list shows on open
        filterText = ""
        if searchBox then searchBox.Text = "" end
        for _, child in ipairs(listScroll:GetChildren()) do
            if child:IsA("TextButton") then child.Visible = true end
        end

        local rootAbs = window.Root.AbsolutePosition
        local btnAbs, btnSize = ddBtn.AbsolutePosition, ddBtn.AbsoluteSize
        local relX = btnAbs.X - rootAbs.X
        local relY = btnAbs.Y - rootAbs.Y
        local fullH = computeH()
        local spaceBelow = (rootAbs.Y + window.Root.AbsoluteSize.Y) - (btnAbs.Y + btnSize.Y)
        local up = spaceBelow < fullH + 14

        listFrame.Visible = true
        listFrame.Size = UDim2.fromOffset(btnSize.X, 0)
        if up then
            listFrame.AnchorPoint = Vector2.new(0, 1)
            listFrame.Position = UDim2.fromOffset(relX, relY - 4)
        else
            listFrame.AnchorPoint = Vector2.new(0, 0)
            listFrame.Position = UDim2.fromOffset(relX, relY + btnSize.Y + 4)
        end
        TweenService:Create(arrow, TweenInfo.new(0.18), { Rotation = 180 }):Play()
        tween(listFrame, 0.18, { Size = UDim2.fromOffset(btnSize.X, fullH) })

        outsideConn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                local p = input.Position
                if not (pointIn(listFrame, p) or pointIn(ddBtn, p)) then
                    closeList()
                end
            end
        end)
    end

    local function rebuild()
        for _, c in ipairs(listScroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for _, o in ipairs(options) do
            local item = create("TextButton", {
                Name = tostring(o), BackgroundColor3 = Theme.SideBar,
                AutoButtonColor = false, Size = UDim2.new(1, 0, 0, ITEM_H - 2),
                Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
                Text = "  " .. tostring(o), TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 52, Parent = listScroll,
            })
            corner(item, 4)
            create("TextLabel", {
                Name = "Mark", BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.new(0, 14, 1, 0), Font = FONT, TextSize = 13,
                TextColor3 = Theme.Accent, Text = "", ZIndex = 52, Parent = item,
            })
            item.MouseEnter:Connect(function()
                if not isSelected(o) then tween(item, 0.1, { BackgroundColor3 = Theme.Hover }) end
            end)
            item.MouseLeave:Connect(function()
                if not isSelected(o) then tween(item, 0.1, { BackgroundColor3 = Theme.SideBar }) end
            end)
            item.MouseButton1Click:Connect(function()
                if multi then
                    if isSelected(o) then
                        for i, v in ipairs(selected) do if v == o then table.remove(selected, i) break end end
                    else
                        table.insert(selected, o)
                    end
                    refresh()
                else
                    selected = o
                    refresh()
                    closeList()
                end
                if opts.Callback then task.spawn(opts.Callback, selected) end
            end)
        end
    end

    ddBtn.MouseEnter:Connect(function() tween(ddStroke, 0.1, { Color = Theme.Accent }) end)
    ddBtn.MouseLeave:Connect(function() if not open then tween(ddStroke, 0.1, { Color = Theme.Border }) end end)
    ddBtn.MouseButton1Click:Connect(function()
        if open then closeList() else openList() end
    end)

    if searchBox then
        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            filterText = searchBox.Text:lower()
            applyFilter()
        end)
    end

    function api:Set(v) selected = v; refresh(); if opts.Callback then task.spawn(opts.Callback, selected) end end
    function api:Get() return selected end
    function api:Refresh(newOptions)
        options = newOptions or options
        rebuild(); refresh()
    end
    function api:Close() closeList() end

    rebuild()
    refresh()
    if opts.Flag then
        window.Config:Register(opts.Flag, function() return api:Get() end, function(v) selected = v; refresh() end)
    end
    return api
end

----------------------------------------------------------------------
-- Divider: a thin horizontal rule used to break up content.
----------------------------------------------------------------------
function UILib:CreateDivider()
    local wrap = create("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 8),
        Parent = self.Content,
    })
    create("Frame", {
        BackgroundColor3 = Theme.Border, BorderSizePixel = 0,
        BackgroundTransparency = 0.4,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(1, -8, 0, 1), Parent = wrap,
    })
    return { Instance = wrap }
end

----------------------------------------------------------------------
-- Paragraph: a styled multi-line read-only text block (with optional title).
----------------------------------------------------------------------
function UILib:CreateParagraph(opts)
    opts = opts or {}
    local box = create("Frame", {
        BackgroundColor3 = Theme.Editor, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Parent = self.Content,
    })
    corner(box, 6)
    stroke(box, Theme.Border, 1, 0.6)
    create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = box })
    create("UIPadding", {
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = box,
    })
    local titleLbl
    if opts.Title and opts.Title ~= "" then
        titleLbl = create("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
            Font = FONT, TextSize = 13, TextColor3 = Theme.TextBright,
            Text = opts.Title, TextXAlignment = Enum.TextXAlignment.Left, Parent = box,
        })
    end
    local body = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = FONT_UI, TextSize = 12, TextColor3 = Theme.TextDim,
        Text = opts.Text or "", TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, Parent = box,
    })
    self:_addEntry(box, (opts.Title or "") .. " " .. (opts.Text or ""))
    return {
        Set = function(_, t) body.Text = t end,
        SetTitle = function(_, t) if titleLbl then titleLbl.Text = t end end,
        Instance = box,
    }
end

----------------------------------------------------------------------
-- ColorPicker: HSV picker (saturation/value plane + hue bar + hex input).
----------------------------------------------------------------------
local function _colorToHex(c)
    return string.format("#%02X%02X%02X",
        math.floor(c.R * 255 + 0.5),
        math.floor(c.G * 255 + 0.5),
        math.floor(c.B * 255 + 0.5))
end
local function _hexToColor(s)
    s = tostring(s):gsub("#", "")
    if #s ~= 6 then return nil end
    local r = tonumber(s:sub(1, 2), 16)
    local g = tonumber(s:sub(3, 4), 16)
    local b = tonumber(s:sub(5, 6), 16)
    if not (r and g and b) then return nil end
    return Color3.fromRGB(r, g, b)
end

function UILib:CreateColorPicker(opts)
    opts = opts or {}
    local window = self.Window
    local default = opts.Default
    if type(default) == "string" then default = _hexToColor(default) end
    if typeof(default) ~= "Color3" then default = Color3.fromRGB(255, 0, 0) end

    local h, s, v = Color3.toHSV(default)
    local current = default
    local open = false
    local outsideConn

    local row = labeledRow(self.Content, opts.Name or "Color", opts.Description, 0.7)
    self:_addEntry(row, (opts.Name or "") .. " " .. (opts.Description or ""))

    local swatch = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0, 44, 0, 22), BackgroundColor3 = current,
        AutoButtonColor = false, Text = "", Parent = row,
    })
    corner(swatch, 5)
    local swatchStroke = stroke(swatch, Theme.Border, 1)

    -- popup ----------------------------------------------------------
    local POP_W, POP_H = 220, 200
    local popup = create("Frame", {
        Name = "ColorPicker", BackgroundColor3 = Theme.SideBar, BorderSizePixel = 0,
        Visible = false, ZIndex = 51, Size = UDim2.fromOffset(POP_W, POP_H),
        Parent = window.Overlay,
    })
    corner(popup, 6)
    stroke(popup, Theme.Accent, 1, 0.2)
    local popScale = create("UIScale", { Scale = 0, Parent = popup })

    local svBox = create("Frame", {
        BackgroundColor3 = Color3.fromHSV(h, 1, 1),
        Position = UDim2.new(0, 10, 0, 10),
        Size = UDim2.new(1, -52, 0, 140), ZIndex = 52, Parent = popup,
    })
    corner(svBox, 4)
    local svGrad = create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 1, 1)),
        }),
        Parent = svBox,
    })
    local valOverlay = create("Frame", {
        BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0), ZIndex = 53, Parent = svBox,
    })
    corner(valOverlay, 4)
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Rotation = 90, Parent = valOverlay,
    })
    local svCursor = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(s, 0, 1 - v, 0),
        Size = UDim2.new(0, 10, 0, 10), BackgroundTransparency = 1,
        ZIndex = 54, Parent = svBox,
    })
    corner(svCursor, 5)
    stroke(svCursor, Color3.new(1, 1, 1), 2)

    local hueBar = create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 10),
        Size = UDim2.new(0, 22, 0, 140), ZIndex = 52, Parent = popup,
    })
    corner(hueBar, 4)
    create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.000, Color3.fromHSV(0.000, 1, 1)),
            ColorSequenceKeypoint.new(0.166, Color3.fromHSV(0.166, 1, 1)),
            ColorSequenceKeypoint.new(0.333, Color3.fromHSV(0.333, 1, 1)),
            ColorSequenceKeypoint.new(0.500, Color3.fromHSV(0.500, 1, 1)),
            ColorSequenceKeypoint.new(0.666, Color3.fromHSV(0.666, 1, 1)),
            ColorSequenceKeypoint.new(0.833, Color3.fromHSV(0.833, 1, 1)),
            ColorSequenceKeypoint.new(1.000, Color3.fromHSV(1.000, 1, 1)),
        }),
        Rotation = 90, Parent = hueBar,
    })
    local hueCursor = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, h, 0),
        Size = UDim2.new(1, 6, 0, 4), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, ZIndex = 53, Parent = hueBar,
    })
    corner(hueCursor, 2)
    stroke(hueCursor, Color3.new(0, 0, 0), 1, 0.4)

    -- hex
    local hexFrame = create("Frame", {
        BackgroundColor3 = Theme.Input, BorderSizePixel = 0,
        Position = UDim2.new(0, 10, 1, -34), Size = UDim2.new(1, -20, 0, 24),
        ZIndex = 52, Parent = popup,
    })
    corner(hexFrame, 4)
    local hexStroke = stroke(hexFrame, Theme.Border, 1)
    create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(0, 24, 1, 0),
        Position = UDim2.new(0, 6, 0, 0), Font = FONT, TextSize = 12,
        TextColor3 = Theme.TextDim, Text = "HEX", ZIndex = 52, Parent = hexFrame,
    })
    local hexBox = create("TextBox", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -38, 1, 0),
        Position = UDim2.new(0, 34, 0, 0), Font = FONT, TextSize = 12,
        TextColor3 = Theme.Text, Text = _colorToHex(current),
        PlaceholderText = "#FFFFFF", PlaceholderColor3 = Theme.TextDim,
        ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 52, Parent = hexFrame,
    })

    local api = {}
    local function applyAll(fireCb)
        current = Color3.fromHSV(h, s, v)
        swatch.BackgroundColor3 = current
        svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 1, 1)),
        })
        svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
        hueCursor.Position = UDim2.new(0.5, 0, h, 0)
        if not hexBox:IsFocused() then hexBox.Text = _colorToHex(current) end
        if fireCb and opts.Callback then task.spawn(opts.Callback, current) end
    end

    function api:Set(c)
        if type(c) == "string" then c = _hexToColor(c) end
        if typeof(c) ~= "Color3" then return end
        h, s, v = Color3.toHSV(c)
        applyAll(true)
    end
    function api:Get() return current end

    -- drag handlers
    local svDrag, hueDrag = false, false
    svBox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then svDrag = true end
    end)
    hueBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then hueDrag = true end
    end)
    window:_track(UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if svDrag then
            local rel = input.Position - svBox.AbsolutePosition
            s = math.clamp(rel.X / svBox.AbsoluteSize.X, 0, 1)
            v = math.clamp(1 - rel.Y / svBox.AbsoluteSize.Y, 0, 1)
            applyAll(true)
        end
        if hueDrag then
            local rel = input.Position - hueBar.AbsolutePosition
            h = math.clamp(rel.Y / hueBar.AbsoluteSize.Y, 0, 1)
            applyAll(true)
        end
    end))
    window:_track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            svDrag = false; hueDrag = false
        end
    end))
    hexBox.Focused:Connect(function() tween(hexStroke, 0.1, { Color = Theme.Accent }) end)
    hexBox.FocusLost:Connect(function()
        tween(hexStroke, 0.1, { Color = Theme.Border })
        local c = _hexToColor(hexBox.Text)
        if c then api:Set(c) else hexBox.Text = _colorToHex(current) end
    end)

    -- open / close popup
    local function pointIn(g, p)
        local pp, sz = g.AbsolutePosition, g.AbsoluteSize
        return p.X >= pp.X and p.X <= pp.X + sz.X and p.Y >= pp.Y and p.Y <= pp.Y + sz.Y
    end
    local function close()
        if not open then return end
        open = false
        if window._activeDropdownClose == close then window._activeDropdownClose = nil end
        if outsideConn then outsideConn:Disconnect(); outsideConn = nil end
        tween(swatchStroke, 0.12, { Color = Theme.Border })
        local t = TweenService:Create(popScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
        t:Play()
        t.Completed:Once(function() if not open then popup.Visible = false end end)
    end
    local function openP()
        if open then return end
        if window._activeDropdownClose then window._activeDropdownClose() end
        open = true
        window._activeDropdownClose = close
        applyAll(false)
        tween(swatchStroke, 0.12, { Color = Theme.Accent })

        local rootAbs = window.Root.AbsolutePosition
        local sa, ss = swatch.AbsolutePosition, swatch.AbsoluteSize
        local relX = sa.X + ss.X - rootAbs.X
        local relYBelow = sa.Y + ss.Y + 6 - rootAbs.Y
        local relYAbove = sa.Y - 6 - rootAbs.Y
        local spaceBelow = (rootAbs.Y + window.Root.AbsoluteSize.Y) - (sa.Y + ss.Y)
        local up = spaceBelow < POP_H + 14

        if up then
            popup.AnchorPoint = Vector2.new(1, 1)
            popup.Position = UDim2.fromOffset(relX, relYAbove)
        else
            popup.AnchorPoint = Vector2.new(1, 0)
            popup.Position = UDim2.fromOffset(relX, relYBelow)
        end
        popup.Visible = true
        TweenService:Create(popScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

        outsideConn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                local p = input.Position
                if not (pointIn(popup, p) or pointIn(swatch, p)) then close() end
            end
        end)
    end
    swatch.MouseButton1Click:Connect(function()
        if open then close() else openP() end
    end)

    applyAll(false)
    if opts.Flag then
        window.Config:Register(opts.Flag,
            function() return _colorToHex(current) end,
            function(stored)
                if type(stored) == "string" then api:Set(stored) end
            end)
    end
    return api
end

----------------------------------------------------------------------
-- Config helper UI: drop-in section to manage configs from the UI
----------------------------------------------------------------------
function UILib:CreateConfigSection(title)
    local window = self.Window
    local section = self:CreateSection(title or "Configuration")
    local currentName = window.Config:GetAutoload() or "default"

    section:CreateLabel(
        (typeof(writefile) == "function")
            and "File API detected — configs persist to disk."
            or "No file API — configs stored in memory (lost on rejoin).")

    local nameBox            -- forward declarations
    local listDropdown
    local autoloadLabel

    local function refreshList(selectName)
        if listDropdown then
            listDropdown:Refresh(window.Config:List())
            if selectName then listDropdown:Set(selectName) end
        end
    end
    local function updateAutoloadLabel()
        if autoloadLabel then
            local a = window.Config:GetAutoload()
            autoloadLabel:Set("Autoload: " .. (a and ("'" .. a .. "'") or "off"))
        end
    end

    nameBox = section:CreateTextbox({
        Name = "Config Name", Placeholder = "default", Default = currentName,
        Callback = function(v) currentName = (v ~= "" and v) or "default" end,
    })

    section:CreateButton({
        Name = "Save Config",
        Callback = function()
            local ok, err = window.Config:Save(currentName)
            UILib:Notify({
                Title = ok and "Config Saved" or "Save Failed",
                Text = ok and ("Saved '" .. currentName .. "'") or tostring(err),
                Accent = ok and Theme.Success or Theme.Error,
            })
            if ok then refreshList(currentName) end  -- show + select immediately
        end,
    })
    section:CreateButton({
        Name = "Load Selected",
        Callback = function()
            local ok, err = window.Config:Load(currentName)
            UILib:Notify({
                Title = ok and "Config Loaded" or "Load Failed",
                Text = ok and ("Loaded '" .. currentName .. "'") or tostring(err),
                Accent = ok and Theme.Success or Theme.Error,
            })
        end,
    })
    section:CreateButton({
        Name = "Delete Selected",
        Callback = function()
            local ok, err = window.Config:Delete(currentName)
            UILib:Notify({
                Title = ok and "Config Deleted" or "Delete Failed",
                Text = ok and ("Deleted '" .. currentName .. "'") or tostring(err),
                Accent = ok and Theme.Warning or Theme.Error,
            })
            if ok then refreshList() end
        end,
    })

    listDropdown = section:CreateDropdown({
        Name = "Saved Configs", Options = window.Config:List(),
        Placeholder = "Select config...", Default = window.Config:GetAutoload(),
        Callback = function(v)
            if v then currentName = v; nameBox:Set(v) end
        end,
    })

    autoloadLabel = section:CreateLabel("Autoload: off")
    updateAutoloadLabel()

    section:CreateButton({
        Name = "Set Autoload to Selected",
        Callback = function()
            window.Config:SetAutoload(currentName)
            updateAutoloadLabel()
            UILib:Notify({
                Title = "Autoload Set",
                Text = "'" .. currentName .. "' will load on launch.",
                Accent = Theme.Success,
            })
        end,
    })
    section:CreateButton({
        Name = "Clear Autoload",
        Callback = function()
            window.Config:ClearAutoload()
            updateAutoloadLabel()
            UILib:Notify({ Title = "Autoload Cleared", Accent = Theme.Warning })
        end,
    })

    return section
end

return UILib
