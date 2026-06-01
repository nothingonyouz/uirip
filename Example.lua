--[[
    Example.lua  —  Demonstrates VSCodeUILib
    ------------------------------------------
    How to load:
      • As a ModuleScript in Studio:
            local Library = require(path.to.VSCodeUILib)
      • As an executor script:
            local Library = loadstring(readfile("VSCodeUILib.lua"))()
        or  local Library = loadstring(game:HttpGet("URL_TO_RAW_FILE"))()

    Then run this file.
]]

-- Load the library from your hosting (returns raw Lua source).
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/nothingonyouz/uirip/refs/heads/main/VSCodeUILib.lua"))()

-- Alternatives:
--   local Library = loadstring(readfile("VSCodeUILib.lua"))()      -- local file
--   local Library = require(script.Parent.VSCodeUILib)             -- ModuleScript in Studio

----------------------------------------------------------------------
-- Create the window
----------------------------------------------------------------------
local Window = Library:CreateWindow({
    Title = "Phantom Hub",
    Subtitle = "main.lua — Phantom Hub — Visual Studio Code",
    Size = UDim2.new(0, 740, 0, 470),
    ToggleKey = Enum.KeyCode.RightShift,
    ConfigFolder = "PhantomHub",        -- configs saved under workspace/PhantomHub/
    Logo = 124163837094498,             -- circular toggle-button logo (omit for a 3-line icon)
    TogglePosition = "left",            -- "left", "center", or a UDim2
})

Library:Notify({
    Title = "Phantom Hub",
    Text = "Loaded successfully. Press Right-Shift to toggle.",
    Type = "success",
    Duration = 4,
})

----------------------------------------------------------------------
-- Tab 1: Combat
----------------------------------------------------------------------
local CombatTab = Window:CreateTab({ Name = "Combat", Icon = "target" })

local aimSection = CombatTab:CreateSection("Aimbot")

aimSection:CreateToggle({
    Name = "Enable Aimbot",
    Description = "Locks your aim onto the nearest target",
    Default = false,
    Flag = "aimbot_enabled",
    Callback = function(state)
        print("Aimbot:", state)
    end,
})

aimSection:CreateSlider({
    Name = "Smoothness",
    Description = "Higher = slower, smoother aim",
    Min = 0, Max = 100, Default = 25, Suffix = "%",
    Flag = "aimbot_smoothness",
    Callback = function(v) print("Smoothness:", v) end,
})

aimSection:CreateDropdown({
    Name = "Target Part",
    Description = "Which body part to aim at",
    Options = { "Head", "Torso", "HumanoidRootPart" },
    Default = "Head",
    Flag = "aimbot_target",
    Callback = function(v) print("Target:", v) end,
})

aimSection:CreateKeybind({
    Name = "Aim Key",
    Description = "Hold to activate aimbot",
    Default = Enum.KeyCode.E,
    Flag = "aimbot_key",
    OnPress = function() print("Aim key pressed!") end,
})

local espSection = CombatTab:CreateSection("ESP")

espSection:CreateToggle({
    Name = "Box ESP", Default = true, Flag = "esp_box",
    Callback = function(s) print("Box ESP:", s) end,
})
espSection:CreateToggle({
    Name = "Name ESP", Default = false, Flag = "esp_name",
})
espSection:CreateDropdown({
    Name = "ESP Targets",
    Description = "Pick what to highlight",
    Multi = true,
    Options = { "Players", "NPCs", "Items", "Vehicles" },
    Default = { "Players" },
    Flag = "esp_targets",
    Callback = function(v) print("ESP targets:", table.concat(v, ", ")) end,
})
espSection:CreateDropdown({
    Name = "Highlight Color",
    Description = "Searchable — type to filter",
    Search = true,
    Options = { "Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Purple", "Pink", "White", "Black" },
    Default = "Red",
    Flag = "esp_color",
    Callback = function(v) print("ESP color:", v) end,
})

----------------------------------------------------------------------
-- Tab 2: Player
----------------------------------------------------------------------
local PlayerTab = Window:CreateTab({ Name = "Player", Icon = "person" })

local moveSection = PlayerTab:CreateSection("Movement")

moveSection:CreateSlider({
    Name = "WalkSpeed", Min = 16, Max = 250, Default = 16, Flag = "walkspeed",
    Callback = function(v)
        local char = game.Players.LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end,
})
moveSection:CreateSlider({
    Name = "JumpPower", Min = 50, Max = 350, Default = 50, Flag = "jumppower",
    Callback = function(v)
        local char = game.Players.LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.UseJumpPower = true; hum.JumpPower = v end
    end,
})
moveSection:CreateToggle({ Name = "Infinite Jump", Flag = "inf_jump" })

local miscSection = PlayerTab:CreateSection("Misc")
miscSection:CreateTextbox({
    Name = "Nickname", Placeholder = "Enter text...", Default = "",
    Flag = "nickname",
    Callback = function(text, enter) if enter then print("Name set:", text) end end,
})
miscSection:CreateButton({
    Name = "Reset Character",
    Callback = function()
        local char = game.Players.LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end,
})
miscSection:CreateLabel("Tip: use the Settings tab to save and load your configs.")

----------------------------------------------------------------------
-- Tab 3: Settings (with the built-in Config Manager UI)
----------------------------------------------------------------------
local SettingsTab = Window:CreateTab({ Name = "Settings", Icon = "settings" })

-- One-liner that builds Save / Load / Delete + saved-config dropdown.
SettingsTab:CreateConfigSection("Config Manager")

local infoSection = SettingsTab:CreateSection("About")
infoSection:CreateLabel("Phantom Hub • built with VSCodeUILib")
infoSection:CreateKeybind({
    Name = "UI Toggle Key",
    Description = "Key to show / hide the window",
    Default = Enum.KeyCode.RightShift,
    Flag = "ui_toggle_key",
    Callback = function(key) Window:SetToggleKey(key) end,
})
infoSection:CreateButton({
    Name = "Test Notifications",
    Description = "Fires one of each notification style",
    Callback = function()
        Library:Notify({ Title = "Info", Text = "Just so you know.", Type = "info" })
        task.wait(0.4)
        Library:Notify({ Title = "Success", Text = "That worked.", Type = "success" })
        task.wait(0.4)
        Library:Notify({ Title = "Warning", Text = "Be careful here.", Type = "warning" })
        task.wait(0.4)
        Library:Notify({ Title = "Error", Text = "Something went wrong.", Type = "error" })
    end,
})
infoSection:CreateButton({
    Name = "Unload / Destroy UI",
    Description = "Removes the interface completely",
    Callback = function() Window:Destroy() end,
})

----------------------------------------------------------------------
-- Autoload: run LAST, after every tab/section/element exists so all
-- flags are registered. Loads the config marked with "Set Autoload".
----------------------------------------------------------------------
local loaded, name = Window.Config:LoadAutoload()
if loaded then
    Library:Notify({
        Title = "Autoload",
        Text = "Loaded config '" .. name .. "'",
        Duration = 3,
    })
end

print("[Example] UI built. Press Right-Shift to toggle.")
