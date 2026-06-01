# VSCodeUILib — Documentation

A single-file Visual Studio Code styled UI library for Roblox. Includes a Config
Manager, notifications, a draggable toggle button, and a Dark+ theme.

> Source: `src/VSCodeUILib.lua` • Example: `src/Example.lua`

---

## Table of Contents

1. [Installation / Loading](#installation--loading)
2. [Quick Start](#quick-start)
3. [Window](#window)
4. [Tab](#tab)
5. [Section](#section)
6. [Elements](#elements)
   - [Label](#label)
   - [Paragraph](#paragraph)
   - [Divider](#divider)
   - [Button](#button)
   - [Toggle](#toggle)
   - [Slider](#slider)
   - [Dropdown](#dropdown)
   - [Textbox](#textbox)
   - [Keybind](#keybind)
   - [ColorPicker](#colorpicker)
7. [Notifications](#notifications)
8. [Config Manager](#config-manager)
9. [Icons](#icons)
10. [Theme](#theme)
11. [Quick API Reference](#quick-api-reference)

---

## Installation / Loading

```lua
-- Load from your hosting (must return raw Lua source)
local Library = loadstring(game:HttpGet("http://nyee.online/uilib.lua"))()

-- Alternatives
-- local Library = loadstring(readfile("VSCodeUILib.lua"))()  -- local file (executor)
-- local Library = require(script.Parent.VSCodeUILib)         -- ModuleScript in Studio
```

The returned `Library` object is the entry point for creating windows and firing
notifications.

---

## Quick Start

```lua
local Library = loadstring(game:HttpGet("http://nyee.online/uilib.lua"))()

local Window = Library:CreateWindow({
    Title = "Phantom Hub",
    ConfigFolder = "PhantomHub",
    Logo = 124163837094498,        -- asset id, or omit for the 3-line icon
})

local Tab = Window:CreateTab({ Name = "Main", Icon = "target" })
local Section = Tab:CreateSection("Combat")

Section:CreateToggle({
    Name = "God Mode",
    Description = "Makes the character invincible",
    Default = false,
    Flag = "godmode",
    Callback = function(on) print("God Mode:", on) end,
})

-- Load the autoload config (call last, after every UI element exists)
Window.Config:LoadAutoload()
```

---

## Window

Creates the main window.

```lua
local Window = Library:CreateWindow({
    Title          = "Phantom Hub",                  -- shown in the side bar + status bar
    Subtitle       = "main.lua — Phantom Hub",       -- centered text in the title bar
    Size           = UDim2.new(0, 740, 0, 470),      -- window size
    ToggleKey      = Enum.KeyCode.RightShift,         -- key that hides / shows the window
    ConfigFolder   = "PhantomHub",                    -- folder where configs are saved
    Logo           = 124163837094498,                 -- toggle-button logo (asset id); omit = 3-line icon
    TogglePosition = "left",                           -- "left" | "center" | UDim2
    ToggleSize     = 52,                               -- toggle button size in pixels
})
```

| Option | Type | Default | Description |
|---|---|---|---|
| `Title` | string | `"VS Code UI"` | Hub name |
| `Subtitle` | string | `"Untitled - Visual Studio Code"` | Title bar text |
| `Size` | UDim2 | `720 x 460` | Window size |
| `ToggleKey` | KeyCode | `RightShift` | Show/hide key |
| `ConfigFolder` | string | `"VSCodeUILib"` | Folder for config files |
| `Logo` | number/string | `nil` | Circular toggle-button logo |
| `TogglePosition` | string/UDim2 | `"left"` | Toggle button position |
| `ToggleSize` | number | `52` | Toggle button size |

### Window methods

```lua
Window:CreateTab(opts)         -- create a tab (see Tab)
Window:SetOpen(true)           -- open the UI (false = hide). Pass true as 2nd arg to skip animation
Window:Toggle()                -- flip open/close state
Window:SetToggleKey(key)       -- change the toggle key (KeyCode or string like "RightControl")
Window:Destroy()               -- remove the UI permanently and disconnect every event
Window.Config                  -- the Config Manager (see Config Manager)
```

Title bar buttons:
- `—` (minimize) hides the window. Reopen with the toggle button or the toggle key
- `✕` (close) calls `Window:Destroy()` and removes the UI permanently
- The floating toggle button (the circular logo) is draggable; click it to open the UI

---

## Tab

```lua
local Tab = Window:CreateTab({
    Name = "Combat",     -- shown as a tooltip on hover
    Icon = "target",     -- built-in name / asset id / single character
})
```

| Option | Type | Description |
|---|---|---|
| `Name` | string | Tab label |
| `Icon` | string/number | Activity bar icon (see [Icons](#icons)) |

Methods:
```lua
Tab:CreateSection(title)        -- create a section
Tab:CreateConfigSection(title)  -- create a ready-made config-management section
Tab:Select()                    -- switch to this tab
```

Hovering a tab icon slides out a tooltip with the tab name to the right of the
activity bar.

---

## Section

A grouping container for elements inside a tab.

```lua
local Section = Tab:CreateSection("Aimbot")
```

Every element is created through a section, e.g. `Section:CreateToggle({...})`.

The side bar on the left lists every section in the active tab. Click a section
entry to scroll the editor view to that section.

### Collapsing

Click the section header (`# Section`) to collapse or expand its contents. The
chevron rotates to indicate state. You can also drive it from code:

```lua
Section:Collapse()        -- toggle
Section:Collapse(true)    -- force collapse
Section:Collapse(false)   -- force expand
```

---

## Elements

> Most elements accept `Flag` (string) so the Config Manager can save and load
> the value automatically, and `Description` (string) for a small dim line below
> the label.

### Label

A single line of plain text.

```lua
local lbl = Section:CreateLabel("A short note")
lbl:Set("Updated text")
print(lbl.Instance)   -- direct access to the underlying TextLabel
```

### Paragraph

A multi-line read-only text block, optionally with a title. Useful for tips,
warnings, or explanatory copy.

```lua
local p = Section:CreateParagraph({
    Title = "Performance tip",
    Text  = "Disable styles you do not need. Each enabled style adds per-frame draw cost.",
})

p:Set("New body text")
p:SetTitle("New title")
```

### Divider

A thin horizontal rule used to break up content groups.

```lua
Section:CreateDivider()
```

### Button

```lua
Section:CreateButton({
    Name = "Kill All",
    Description = "Damages every player on the server",  -- (optional)
    Callback = function() print("clicked") end,
})
```

### Toggle

```lua
local t = Section:CreateToggle({
    Name = "Enable Aimbot",
    Description = "Turn the aimbot on or off",   -- (optional)
    Default = false,
    Flag = "aimbot_enabled",                     -- (optional) save in config
    Callback = function(state) print(state) end,
})

t:Set(true)          -- set value (also fires Callback)
local on = t:Get()   -- read the current boolean
```

### Slider

```lua
local s = Section:CreateSlider({
    Name = "WalkSpeed",
    Description = "Movement speed",     -- (optional)
    Min = 16, Max = 250,
    Default = 16,
    Decimals = 0,        -- number of decimal places (0 = integer)
    Suffix = " studs",   -- (optional) appended to the displayed value
    Flag = "walkspeed",
    Callback = function(v) print(v) end,
})

s:Set(120)
local v = s:Get()
```

### Dropdown

Supports single-select, multi-select (`Multi`), and an optional in-list search
box (`Search`).

```lua
local dd = Section:CreateDropdown({
    Name = "Target Part",
    Description = "Body part to aim at",   -- (optional)
    Options = { "Head", "Torso", "HumanoidRootPart" },
    Default = "Head",        -- when Multi, use a table, e.g. { "Head" }
    Multi = false,           -- true = allow multiple selections
    Search = false,          -- true = show a search box at the top of the list
    Placeholder = "Select...",
    Flag = "aim_target",
    Callback = function(value)
        -- single: value is a string
        -- multi: value is a table of strings
        print(value)
    end,
})

dd:Set("Torso")                              -- set value
local cur = dd:Get()                          -- current value
dd:Refresh({ "A", "B", "C" })                 -- replace the option list
dd:Close()                                    -- close the popup
```

The list opens as an overlay above everything else, automatically flips upward
when there isn't enough room below, and closes when you click outside.

When in multi-select mode, the button label uses a smart compact format so it
never overflows: `"All (5)"` when every option is selected, `"First, Second +3
more"` when more than three are selected, otherwise the values joined with
commas. `TextTruncate.AtEnd` is set as a safety net.

### Textbox

```lua
local box = Section:CreateTextbox({
    Name = "Nickname",
    Description = "Set your display name",   -- (optional)
    Placeholder = "Type here...",
    Default = "",
    Flag = "nickname",
    Callback = function(text, enterPressed)
        print(text, enterPressed)
    end,
})

box:Set("Hello")
local s = box:Get()
```

### Keybind

```lua
local kb = Section:CreateKeybind({
    Name = "Aim Key",
    Description = "Hold to aim",                       -- (optional)
    Default = Enum.KeyCode.E,
    Flag = "aim_key",
    OnPress  = function() print("bound key pressed") end,  -- runs when the bound key is pressed
    Callback = function(key) print("rebound to:", key) end,
})

kb:Set(Enum.KeyCode.F)   -- or kb:Set("F")
local name = kb:Get()    -- string like "F", or nil
```

### ColorPicker

A full HSV picker with a saturation/value plane, a hue bar, and a hex input.

```lua
local cp = Section:CreateColorPicker({
    Name = "Highlight Color",
    Description = "Color used for ESP rendering",   -- (optional)
    Default = Color3.fromRGB(0, 200, 255),           -- or "#00C8FF"
    Flag = "esp_color",
    Callback = function(color) print(color) end,
})

cp:Set(Color3.fromRGB(255, 100, 0))
cp:Set("#FF6400")
local c = cp:Get()   -- always a Color3
```

The popup opens above or below the swatch depending on available space, and
closes when you click outside. Configs persist the color as a `#RRGGBB` hex
string for easy editing.

---

## Notifications

```lua
Library:Notify({
    Title = "Saved",
    Text = "Config saved successfully.",
    Type = "success",        -- "info" | "success" | "warning" | "error"
    Duration = 3,            -- seconds
    -- Accent = Color3.fromRGB(0, 122, 204),  -- (optional) override accent color
})
```

| Option | Type | Default | Description |
|---|---|---|---|
| `Title` | string | `"Notification"` | Heading |
| `Text` | string | `""` | Body |
| `Type` | string | `"info"` | Style preset (color + icon) |
| `Duration` | number | `3` | Seconds visible |
| `Accent` | Color3 | per `Type` | Override the accent color |

Each notification has a typed icon, a count-down progress bar, and can be
dismissed early by clicking the card.

---

## Config Manager

Every element with a `Flag` is registered with the Config Manager automatically.
Access it through `Window.Config`.

```lua
local cfg = Window.Config

cfg:Save("loadout1")     -- save every flagged value to file "loadout1.json"
cfg:Load("loadout1")     -- load values back into the elements
cfg:Delete("loadout1")   -- delete the file
local list = cfg:List()  -- returns { "name1", "name2", ... }

-- Autoload: remember a config to load automatically next launch
cfg:SetAutoload("loadout1")
cfg:GetAutoload()        -- returns the autoload name, or nil
cfg:ClearAutoload()      -- forget the autoload target
cfg:LoadAutoload()       -- load it. Call this last, after every element exists
```

> Notes: when running on an executor with the file API
> (`writefile`/`readfile`/...), configs persist to disk under `ConfigFolder`.
> When that API is missing (e.g. Studio), values are kept in memory and lost on
> rejoin.

### Ready-made Config section

Build a complete config-management UI (Save / Load / Delete + saved-config
dropdown + autoload buttons) in one line.

```lua
local SettingsTab = Window:CreateTab({ Name = "Settings", Icon = "settings" })
SettingsTab:CreateConfigSection("Config Manager")
```

Typical flow: tweak settings → type a config name → Save → (optionally) Set
Autoload to Selected. On the next launch `Window.Config:LoadAutoload()` will
restore everything.

---

## Icons

A Tab `Icon` accepts three forms:

1. **Built-in name** (drawn as monochrome vectors):
   `target`, `crosshair`, `person`, `settings`, `sliders`, `home`, `bolt`,
   `eye`, `info`, `success`, `check`, `warning`, `error`, `close`, `minus`,
   `search`
2. **Asset id** of an image — e.g. `Icon = 1234567890` or
   `Icon = "rbxassetid://1234567890"`. The image is tinted to match the theme
3. **Single character** — e.g. `Icon = "C"`. If omitted, the first letter of
   the tab name is used

```lua
Window:CreateTab({ Name = "Combat",  Icon = "target" })
Window:CreateTab({ Name = "Player",  Icon = "person" })
Window:CreateTab({ Name = "Visuals", Icon = "eye" })
```

---

## Theme

The library ships with a Visual Studio Code "Dark+" palette. Read the colors
from `Library.Theme`:

```lua
local Theme = Library.Theme
print(Theme.Accent)   -- Color3.fromRGB(0, 122, 204)
```

Available colors: `Editor`, `SideBar`, `ActivityBar`, `TitleBar`, `StatusBar`,
`Accent`, `AccentDim`, `Input`, `Hover`, `Selected`, `Border`, `Text`,
`TextDim`, `TextBright`, `Success`, `Warning`, `Error`.

---

## Quick API Reference

```lua
-- Loading
local Library = loadstring(game:HttpGet("URL"))()

-- Window
local Window = Library:CreateWindow({ Title, Subtitle, Size, ToggleKey,
                                      ConfigFolder, Logo, TogglePosition, ToggleSize })
Window:SetOpen(open, instant)
Window:Toggle()
Window:SetToggleKey(key)
Window:Destroy()
Window.Config        -- Config Manager

-- Notify (callable on Library or Window)
Library:Notify({ Title, Text, Type, Duration, Accent })

-- Tab
local Tab = Window:CreateTab({ Name, Icon })
Tab:Select()
local Section = Tab:CreateSection(title)
Tab:CreateConfigSection(title)

-- Section
Section:Collapse(state)     -- nil = toggle, true = collapse, false = expand

-- Elements (created via Section)
Section:CreateLabel(text)                              -- :Set(t), .Instance
Section:CreateParagraph({ Title, Text })               -- :Set(t), :SetTitle(t), .Instance
Section:CreateDivider()                                -- .Instance
Section:CreateButton({ Name, Description, Callback })  -- .Instance
Section:CreateToggle({ Name, Description, Default, Flag, Callback })   -- :Set(v) :Get()
Section:CreateSlider({ Name, Description, Min, Max, Default, Decimals, Suffix, Flag, Callback })
                                                                       -- :Set(v) :Get()
Section:CreateDropdown({ Name, Description, Options, Default, Multi, Search, Placeholder, Flag, Callback })
                                                                       -- :Set :Get :Refresh :Close
Section:CreateTextbox({ Name, Description, Placeholder, Default, Flag, Callback })
                                                                       -- :Set(v) :Get()
Section:CreateKeybind({ Name, Description, Default, Flag, OnPress, Callback })
                                                                       -- :Set(k) :Get()
Section:CreateColorPicker({ Name, Description, Default, Flag, Callback })
                                                                       -- :Set(c) :Get()

-- Config Manager
Window.Config:Save(name)
Window.Config:Load(name)
Window.Config:Delete(name)
Window.Config:List()            -- -> { "name1", "name2", ... }
Window.Config:SetAutoload(name)
Window.Config:GetAutoload()     -- -> name | nil
Window.Config:ClearAutoload()
Window.Config:LoadAutoload()    -- -> loaded:boolean, name:string?
```

---

See `src/Example.lua` for a complete working example.
