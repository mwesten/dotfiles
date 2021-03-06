spaces = require("hs._asm.undocumented.spaces")

-- Config
local mash = {
  split   = {"ctrl", "alt", "cmd"},
  corner  = {"ctrl", "alt", "shift"},
  focus   = {"ctrl", "alt"},
  utils   = {"ctrl", "alt", "cmd"}
}

local spacesModifier = "ctrl"

local animationDuration = 0

local centeredWindowRatios = {
  small = { w = 0.8, h = 0.8 }, -- screen width < 2560
  large = { w = 0.66, h = 0.66 } -- screen width >= 2560
}

local defaultBrightness = 60
local nightModeBrightness = 6

-- Setup
local logger = hs.logger.new("config", "verbose")

hs.alert.defaultStyle.strokeColor = { white = 0, alpha = 0.75 }
hs.alert.defaultStyle.textSize = 25

hs.window.animationDuration = animationDuration

hs.grid.setGrid("10x2")
hs.grid.setMargins("0x0")

-- Reload config
hs.hotkey.bind(mash.utils, "-", function()
  hs.reload()
end)

-- Resize windows
local gridPositions = {
  -- splits
  top              = { ["50-50"] = "0,0 10x1", ["60-40"] = "0,0 10x1" },
  right            = { ["50-50"] = "5,0 5x2",  ["60-40"] = "6,0 4x2" },
  bottom           = { ["50-50"] = "0,1 10x1", ["60-40"] = "0,1 10x1" },
  left             = { ["50-50"] = "0,0 5x2",  ["60-40"] = "0,0 6x2" },
  -- corners
  ["top-left"]     = { ["50-50"] = "0,0 5x1", ["60-40"] = "0,0 6x1" },
  ["top-right"]    = { ["50-50"] = "5,0 5x1", ["60-40"] = "6,0 4x1" },
  ["bottom-right"] = { ["50-50"] = "5,1 5x1", ["60-40"] = "6,1 4x1" },
  ["bottom-left"]  = { ["50-50"] = "0,1 5x1", ["60-40"] = "0,1 6x1" }
}

local function adjustWindow(position)
  local gridPosition = gridPositions[position]

  return function()
    local win = hs.window.focusedWindow()
    if not win then return end

    local grid = spaces.currentSpace() == 3 and "60-40" or "50-50"

    hs.grid.set(win, gridPosition[grid])
  end
end

-- top half
hs.hotkey.bind(mash.split, "up", adjustWindow("top"))

-- right half
hs.hotkey.bind(mash.split, "right", adjustWindow("right"))

-- bottom half
hs.hotkey.bind(mash.split, "down", adjustWindow("bottom"))

-- left half
hs.hotkey.bind(mash.split, "left", adjustWindow("left"))

-- top left
hs.hotkey.bind(mash.corner, "up", adjustWindow("top-left"))

-- top right
hs.hotkey.bind(mash.corner, "right", adjustWindow("top-right"))

-- bottom right
hs.hotkey.bind(mash.corner, "down", adjustWindow("bottom-right"))

-- bottom left
hs.hotkey.bind(mash.corner, "left", adjustWindow("bottom-left"))

-- fullscreen
hs.hotkey.bind(mash.split, ",", hs.grid.maximizeWindow)

-- center small
hs.hotkey.bind(mash.split, ".", function()
  local win = hs.window.focusedWindow()
  if not win then return end

  local f = win:frame()
  local screen = win:screen():frame()
  local size = screen.w >= 2560 and "large" or "small"

  f.w = math.floor(screen.w * centeredWindowRatios[size].w)
  f.h = math.floor(screen.h * centeredWindowRatios[size].h)
  f.x = math.floor((screen.w / 2) - (f.w / 2))
  f.y = math.floor((screen.h / 2) - (f.h / 2))
  win:setFrame(f)
end)


-- Focus windows
hs.hotkey.bind(mash.focus, "up", hs.window.focusWindowNorth)
hs.hotkey.bind(mash.focus, "right", hs.window.focusWindowEast)
hs.hotkey.bind(mash.focus, "down", hs.window.focusWindowSouth)
hs.hotkey.bind(mash.focus, "left", hs.window.focusWindowWest)


-- Spaces
local spacesCount = spaces.count()
local spacesModifiers = {"fn", spacesModifier}

-- infinitely cycle through spaces using ctrl+left/right to trigger ctrl+[1..n]
local spacesEventtap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(o)
  local keyCode = o:getKeyCode()
  local modifiers = o:getFlags()

  --logger.i(keyCode, hs.inspect(modifiers))

  -- check if correct key code
  if keyCode ~= 123 and keyCode ~= 124 then return end
  if not modifiers[spacesModifier] then return end

  -- check if no other modifiers where pressed
  local passed = hs.fnutils.every(modifiers, function(_, modifier)
    return hs.fnutils.contains(spacesModifiers, modifier)
  end)

  if not passed then return end

  -- switch spaces
  local currentSpace = spaces.currentSpace()
  local nextSpace

  -- left arrow
  if keyCode == 123 then
    nextSpace = currentSpace ~= 1 and currentSpace - 1 or spacesCount
   -- right arrow
  elseif keyCode == 124 then
    nextSpace = currentSpace ~= spacesCount and currentSpace + 1 or 1
  end

  local event = require("hs.eventtap").event
  event.newKeyEvent({spacesModifier}, string.format("%d", nextSpace), true):post()
  event.newKeyEvent({spacesModifier}, string.format("%d", nextSpace), false):post()
  -- TODO: replace with this once > 0.9.50 has been released
  --hs.eventtap.keyStroke({spacesModifier}, string.format("%d", nextSpace), 0)

  -- stop propagation
  return true
end):start()

hs.hotkey.bind(mash.utils, "e", function()
  -- this is to bind the spacesEventtap variable to a long-lived function in
  -- order to prevent GC from doing their evil business
  hs.alert.show("Fast space switching enabled: " .. tostring(spacesEventtap:isEnabled()))
end)

-- Wifi
function ssidChangedCallback()
    local ssid = hs.wifi.currentNetwork()
    if ssid then
      hs.alert.show("Network connected: " .. ssid)
    end
end

hs.wifi.watcher.new(ssidChangedCallback):start()

hs.hotkey.bind(mash.utils, "r", function()
  local ssid = hs.wifi.currentNetwork()
  if not ssid then return end

  hs.alert.show("Reconnecting to: " .. ssid)
  hs.execute("networksetup -setairportpower en0 off")
  hs.execute("networksetup -setairportpower en0 on")
end)


-- Caffeinate
-- Icon shamelessly copied from https://github.com/BrianGilbert/.hammerspoon
local caffeine

function toggleCaffeine()
  setCaffeineMenuItem(hs.caffeinate.toggle("systemIdle"))
end

function setCaffeineMenuItem(state)
  if state then
    if not caffeine then
      caffeine = hs.menubar.new(false)
      caffeine:setIcon(os.getenv("HOME") .. "/.hammerspoon/caffeine-on.pdf")
      caffeine:setClickCallback(toggleCaffeine)
    end

    caffeine:returnToMenuBar()
    hs.alert.show("Caffeinated!")
  else
    caffeine:removeFromMenuBar()
    hs.alert.show("Decaf")
  end
end

hs.hotkey.bind(mash.utils, "c", toggleCaffeine)


-- Battery
local previousPowerSource = hs.battery.powerSource()

function minutesToHours(minutes)
  if minutes <= 0 then
    return "0:00";
  else
    hours = string.format("%d", math.floor(minutes / 60))
    mins = string.format("%02.f", math.floor(minutes - (hours * 60)))
    return string.format("%s:%s", hours, mins)
  end
end

function showBatteryStatus()
  local message

  if hs.battery.isCharging() then
    local pct = hs.battery.percentage()
    local untilFull = hs.battery.timeToFullCharge()
    message = "Charging:"

    if untilFull == -1 then
      message = string.format("%s %.0f%% (calculating...)", message, pct);
    else
      local watts = hs.battery.watts()
      message = string.format("%s %.0f%% (%s remaining @ %.1fW)", message, pct, minutesToHours(untilFull), watts)
    end
  elseif hs.battery.powerSource() == "Battery Power" then
    local pct = hs.battery.percentage()
    local untilEmpty = hs.battery.timeRemaining()
    message = "Battery:"

    if untilEmpty == -1 then
      message = string.format("%s %.0f%% (calculating...)", message, pct)
    else
      local watts = hs.battery.watts()
      message = string.format("%s %.0f%% (%s remaining @ %.1fW)", message, pct, minutesToHours(untilEmpty), watts)
    end
  else
    message = "Fully charged"
  end

  hs.alert.show(message)
end

function batteryChangedCallback()
  local powerSource = hs.battery.powerSource()

  if powerSource ~= previousPowerSource then
    showBatteryStatus()
    previousPowerSource = powerSource;
  end
end

hs.battery.watcher.new(batteryChangedCallback):start()

hs.hotkey.bind(mash.utils, "b", showBatteryStatus)


-- Night mode toggle
local previousBrightness = defaultBrightness

hs.hotkey.bind(mash.utils, "n", function()
  local currentBrightness = hs.brightness.get()
  if nightModeBrightness / currentBrightness >= 0.9 then
    -- night off
    hs.brightness.set(previousBrightness)
  else
    -- night on
    previousBrightness = currentBrightness
    hs.brightness.set(nightModeBrightness)
  end
end)


-- Audio device mute toggle
hs.hotkey.bind(mash.utils, "m", function()
  local audio = hs.audiodevice.defaultOutputDevice()
  local wasMuted = audio:muted()
  audio:setMuted(not wasMuted)

  hs.alert.show(wasMuted and string.format("Volume %.0f%%", audio:volume()) or "Muted")
end)


-- All set
hs.alert.show("Hammerspoon!")
