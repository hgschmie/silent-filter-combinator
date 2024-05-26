--
-- sprites supplied by the framework
--

local indicators = {}
for i, color in ipairs({ "black", "white", "red", "orange", "yellow", "green", "cyan", "blue", "purple", "pink" }) do
  indicators[i] = {
    type = "sprite",
    name = "framework_indicator_" .. color,
    filename = "/framework/graphics/indicators.png",
    y = (i - 1) * 32,
    size = 32,
    flags = { "icon" },
  }
end
data:extend(indicators)

local fab = "/framework/graphics/frame-action-icons.png"

data:extend {
  {
    type = "sprite",
    name = "framework_pin_black",
    filename = fab,
    position = { 0, 0 },
    size = 32,
    flags = { "gui-icon" },
  },
  {
    type = "sprite",
    name = "framework_pin_white",
    filename = fab,
    position = { 32, 0 },
    size = 32,
    flags = { "gui-icon" },
  },
  {
    type = "sprite",
    name = "framework_pin_disabled",
    filename = fab,
    position = { 64, 0 },
    size = 32,
    flags = { "gui-icon" },
  },
  {
    type = "sprite",
    name = "framework_settings_black",
    filename = fab,
    position = { 0, 32 },
    size = 32,
    flags = { "gui-icon" },
  },
  {
    type = "sprite",
    name = "framework_settings_white",
    filename = fab,
    position = { 32, 32 },
    size = 32,
    flags = { "gui-icon" },
  },
  {
    type = "sprite",
    name = "framework_settings_disabled",
    filename = fab,
    position = { 64, 32 },
    size = 32,
    flags = { "gui-icon" },
  },
  {
    type = "sprite",
    name = "framework_nav_backward_black",
    filename = "/framework/graphics/nav-backward-black.png",
    size = 32,
    flags = { "gui-icon" },
  },
  {
    type = "sprite",
    name = "framework_nav_backward_white",
    filename = "/framework/graphics/nav-backward-white.png",
    size = 32,
    flags = { "gui-icon" },
  },
  {
    type = "sprite",
    name = "framework_nav_backward_disabled",
    filename = "/framework/graphics/nav-backward-disabled.png",
    size = 32,
    flags = { "gui-icon" },
  },
  {
    type = "sprite",
    name = "framework_nav_forward_black",
    filename = "/framework/graphics/nav-forward-black.png",
    size = 32,
    flags = { "gui-icon" },
  },
  {
    type = "sprite",
    name = "framework_nav_forward_white",
    filename = "/framework/graphics/nav-forward-white.png",
    size = 32,
    flags = { "gui-icon" },
  },
  {
    type = "sprite",
    name = "framework_nav_forward_disabled",
    filename = "/framework/graphics/nav-forward-disabled.png",
    size = 32,
    flags = { "gui-icon" },
  },
}
