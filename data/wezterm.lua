local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Kanagawa Dragon color scheme (defined manually for portability)
config.color_scheme = 'Kanagawa (Gogh)'

config.font = wezterm.font('MesloLGS Nerd Font')
config.font_size = 13.0
config.dpi = 96.0

config.window_background_opacity = 0.88
config.macos_window_background_blur = 0
config.window_background_image_hsb = {
  brightness = 0.04,
  hue = 1.0,
  saturation = 0.12,
}

config.window_padding = {
  left = 6,
  right = 6,
  top = 6,
  bottom = 6,
}

config.cursor_thickness = '2pt'
config.cursor_blink_rate = 500
config.default_cursor_style = 'BlinkingBlock'

config.scrollback_lines = 10000
config.animation_fps = 120

config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = true
config.tab_max_width = 32

config.window_decorations = 'RESIZE'
config.window_close_confirmation = 'NeverPrompt'
config.adjust_window_size_when_changing_font_size = false

config.default_prog = { 'zsh' }

config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }
config.keys = {
  {
    key = '|',
    mods = 'LEADER',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = '-',
    mods = 'LEADER',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'h',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection 'Left',
  },
  {
    key = 'j',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection 'Down',
  },
  {
    key = 'k',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection 'Up',
  },
  {
    key = 'l',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection 'Right',
  },
  {
    key = 'z',
    mods = 'LEADER',
    action = wezterm.action.TogglePaneZoomState,
  },
  {
    key = 'q',
    mods = 'LEADER',
    action = wezterm.action.CloseCurrentPane { confirm = true },
  },
  {
    key = 'x',
    mods = 'LEADER',
    action = wezterm.action.ActivateCopyMode,
  },
  {
    key = 'c',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CopyTo 'Clipboard',
  },
  {
    key = 'v',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
  {
    key = 'n',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SpawnWindow,
  },
  {
    key = 't',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SpawnTab 'CurrentPaneDomain',
  },
  {
    key = 'w',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CloseCurrentTab { confirm = true },
  },
  {
    key = 'Tab',
    mods = 'CTRL',
    action = wezterm.action.ActivateTabRelative(1),
  },
  {
    key = 'Tab',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ActivateTabRelative(-1),
  },
  {
    key = 'PageUp',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ScrollByPage(-1),
  },
  {
    key = 'PageDown',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ScrollByPage(1),
  },
}

config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
}

config.colors = {
  tab_bar = {
    background = '#1f1f28',
    active_tab = {
      bg_color = '#2a2a37',
      fg_color = '#dcd7ba',
      intensity = 'Bold',
    },
    inactive_tab = {
      bg_color = '#16161d',
      fg_color = '#54546d',
    },
    new_tab = {
      bg_color = '#16161d',
      fg_color = '#54546d',
    },
    new_tab_hover = {
      bg_color = '#2a2a37',
      fg_color = '#dcd7ba',
    },
  },
}

wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local pane = tab.active_pane
  local title = pane.title
  local index = tab.tab_index + 1

  local cwd = pane.current_working_dir
  local cwd_str = ''
  if cwd then
    cwd_str = cwd.file_path:match('([^/]+)$') or cwd.file_path
    local home = os.getenv('HOME')
    if cwd_str == home then
      cwd_str = '~'
    elseif cwd.file_path:find(home, 1, true) == 1 then
      cwd_str = '~/' .. cwd.file_path:sub(#home + 2)
    end
  end

  local tab_title = cwd_str ~= '' and cwd_str or title

  if hover then
    return {
      { Background = { Color = '#2a2a37' } },
      { Foreground = { Color = '#dcd7ba' } },
      { Text = ' ' .. index .. ' ' },
    }
  end

  local is_active = tab.is_active
  local bg = is_active and '#2a2a37' or '#16161d'
  local fg = is_active and '#dcd7ba' or '#54546d'
  local attr = is_active and 'Bold' or 'Normal'

  return {
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Attribute = { Intensity = attr } },
    { Text = ' ' .. index .. ':' .. tab_title .. ' ' },
  }
end)

return config
