local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Per-window focus state, shared between window-focus-changed and format-tab-title.
-- Keyed by window:window_id() (integer). Defaults to true so first render looks focused.
local win_focused = {}

config.default_prog = { 'pwsh.exe', '-NoLogo' }

config.launch_menu = {
  { label = 'PowerShell 7',         args = { 'pwsh.exe', '-NoLogo' } },
  { label = 'WSL zsh',              args = { 'wsl.exe', '--cd', '~', '-e', 'zsh', '-l' } },
  -- Plain variants: no profile / no rc files — escape hatch when the stack misbehaves.
  { label = 'PowerShell 7 (plain)', args = { 'pwsh.exe', '-NoLogo', '-NoProfile' } },
  { label = 'WSL zsh (plain)',      args = { 'wsl.exe', '--cd', '~', '-e', 'zsh', '-df' } },
}

config.ssh_domains = wezterm.default_ssh_domains()
for _, dom in ipairs(config.ssh_domains) do
  dom.assume_shell = 'Posix'
end

config.font = wezterm.font_with_fallback {
  'JetBrainsMono Nerd Font',
  'CaskaydiaCove Nerd Font',
  'Cascadia Code',
}
config.font_size = 11.5
config.color_scheme = 'Catppuccin Mocha'
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.initial_cols = 120
config.initial_rows = 30
config.tab_max_width = 120
config.window_frame = {
  font_size            = 11.0,
  active_titlebar_bg   = '#000000',
  inactive_titlebar_bg = '#2a2a2a',
  active_titlebar_fg   = '#cdd6f4',
  inactive_titlebar_fg = '#585b70',
}

-- OpenGL avoids the WebGpu output-buffer stall where child-process output (e.g. Claude Code starting up) only renders after the next input event.
config.front_end = 'OpenGL'
config.scrollback_lines = 50000
config.audible_bell = 'Disabled'
config.adjust_window_size_when_changing_font_size = false
config.inactive_pane_hsb = { brightness = 0.6, saturation = 0.9, hue = 1.0 }

config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1500 }

config.keys = {
  { key = 'l', mods = 'ALT', action = act.ShowLauncherArgs {
      flags = 'FUZZY|TABS|DOMAINS|LAUNCH_MENU_ITEMS|WORKSPACES|COMMANDS' } },
  { key = 'w', mods = 'LEADER', action = act.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' } },
  { key = 'n', mods = 'LEADER', action = act.PromptInputLine {
      description = 'New/switch workspace:',
      action = wezterm.action_callback(function(window, pane, line)
        if line and #line > 0 then
          window:perform_action(act.SwitchToWorkspace { name = line }, pane)
        end
      end) } },
  { key = '\\', mods = 'LEADER', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '-',  mods = 'LEADER', action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },
  { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
  { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
  { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
  { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
  { key = 'a', mods = 'LEADER|CTRL', action = act.SendKey { key = 'a', mods = 'CTRL' } },
  -- Pop the current pane out into its own new window.
  -- LEADER+o for muscle memory; CTRL+SHIFT+O for quick access without the leader.
  { key = 'o', mods = 'LEADER',      action = wezterm.action_callback(function(window, pane) pane:move_to_new_window() end) },
  { key = 'o', mods = 'CTRL|SHIFT',  action = wezterm.action_callback(function(window, pane) pane:move_to_new_window() end) },
  { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
}

-- When focused: active tab = surface0 highlight, inactive tabs = dim.
-- When unfocused: all tabs collapse to the same grey as the pane background so
-- the whole window reads as a single unified grey block.
wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
  local title = tab.tab_title
  if not title or #title == 0 then title = tab.active_pane.title end
  title = wezterm.truncate_right(title, max_width - 2)

  local focused = win_focused[tab.window_id] ~= false  -- true when unknown (first render)

  if not focused then
    return {
      { Background = { Color = '#2a2a2a' } },
      { Foreground = { Color = tab.is_active and '#cccccc' or '#888888' } },
      { Text = ' ' .. title .. ' ' },
    }
  end

  if tab.is_active then
    return {
      { Background = { Color = '#313244' } },
      { Foreground = { Color = '#cdd6f4' } },
      { Attribute = { Intensity = 'Bold' } },
      { Text = ' ' .. title .. ' ' },
    }
  end
  if hover then
    return {
      { Background = { Color = '#1e1e2e' } },
      { Foreground = { Color = '#a6adc8' } },
      { Text = ' ' .. title .. ' ' },
    }
  end
  return {
    { Background = { Color = '#1e1e2e' } },
    { Foreground = { Color = '#585b70' } },
    { Text = ' ' .. title .. ' ' },
  }
end)

-- Show workspace name only when it's not the default; hide path (CWD is in the Claude Code statusline).
wezterm.on('update-right-status', function(window, pane)
  local workspace = window:active_workspace()
  if workspace ~= 'default' then
    window:set_right_status(wezterm.format {
      { Foreground = { Color = '#a6e3a1' } },
      { Text = '  ⬡ ' .. workspace .. '  ' },
    })
  else
    window:set_right_status('')
  end
end)

-- Entire window goes grey when it loses OS focus; pure black when active.
-- Also records focus state so format-tab-title can match the tab colours.
wezterm.on('window-focus-changed', function(window, pane)
  win_focused[window:window_id()] = window:is_focused()
  local overrides = window:get_config_overrides() or {}
  if window:is_focused() then
    overrides.colors = { background = '#000000' }
  else
    overrides.colors = { background = '#2a2a2a' }
  end
  window:set_config_overrides(overrides)
end)

return config
