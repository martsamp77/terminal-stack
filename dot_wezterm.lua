-- ~/.wezterm.lua — macOS counterpart of windows/.wezterm.lua.
-- chezmoi applies this only on darwin (see .chezmoiignore); native Linux hosts in
-- this stack are headless (ssh/PuTTY), so they need no WezTerm GUI config.
-- Keep visual settings (font, theme, tab bar, keys, status) in sync with the
-- Windows file; the only intentional divergence is the launch shell.

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- On macOS the default program is the login shell (zsh) — no default_prog needed.

config.ssh_domains = wezterm.default_ssh_domains()
for _, dom in ipairs(config.ssh_domains) do
  dom.assume_shell = 'Posix'
end

-- Final fallback is Menlo, not Cascadia Code: Menlo ships with macOS, Cascadia does not.
config.font = wezterm.font_with_fallback {
  'JetBrainsMono Nerd Font',
  'CaskaydiaCove Nerd Font',
  'Menlo',
}
config.font_size = 11.5
config.color_scheme = 'Catppuccin Mocha'
config.window_background_opacity = 1.0
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.window_decorations = 'RESIZE'
config.initial_cols = 120
config.initial_rows = 40
config.tab_max_width = 120
config.window_frame = {
  font_size = 11.0,
}

-- OpenGL avoids the WebGpu output-buffer stall where child-process output (e.g. Claude Code starting up) only renders after the next input event.
config.front_end = 'OpenGL'
config.scrollback_lines = 50000

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
  { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
}

wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local title = tab.tab_title
  if not title or #title == 0 then title = tab.active_pane.title end
  title = wezterm.truncate_right(title, max_width - 2)
  return ' ' .. title .. ' '
end)

wezterm.on('update-right-status', function(window, pane)
  local workspace = window:active_workspace()
  local cwd = pane:get_current_working_dir()
  local cwd_str = cwd and (cwd.file_path or '') or ''
  window:set_right_status(wezterm.format {
    { Foreground = { AnsiColor = 'Green' } }, { Text = '  ' .. workspace .. '  ' },
    { Foreground = { AnsiColor = 'Blue' } },  { Text = '│  ' .. cwd_str .. ' ' },
  })
end)

return config
