local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

config.default_prog = { 'pwsh.exe', '-NoLogo' }

config.launch_menu = {
  { label = 'PowerShell 7', args = { 'pwsh.exe', '-NoLogo' } },
  { label = 'WSL zsh',      args = { 'wsl.exe', '--cd', '~', '-e', 'zsh', '-l' } },
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
config.window_background_opacity = 1.0
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
-- INTEGRATED_BUTTONS (min/max/close in the fancy tab bar) requires a build newer than the
-- last `wezterm` stable (20240203 — what choco and other winget-less hosts get). On that
-- build the value is invalid and the *whole* config errors out, so detect the build date and
-- fall back to a plain resize border. Nightly keeps the integrated buttons.
local build_date = tonumber((wezterm.version or ''):match('^(%d+)')) or 0
if build_date > 20240203 then
  config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
else
  config.window_decorations = 'RESIZE'
end
config.initial_cols = 120
config.initial_rows = 30
config.tab_max_width = 120
config.window_frame = {
  font_size = 11.0,
}

-- OpenGL avoids the WebGpu output-buffer stall where child-process output (e.g. Claude Code starting up) only renders after the next input event.
-- Over RDP / on a headless server there's no usable GPU context and the GUI won't start at
-- all; set the WEZTERM_FRONT_END env var to 'Software' (machine-wide) on such hosts to override.
config.front_end = os.getenv('WEZTERM_FRONT_END') or 'OpenGL'
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
  -- Pop the current tab/pane out into its own new window. WezTerm has no native
  -- mouse drag-to-detach; this is the supported equivalent (pane:move_to_new_window).
  { key = 'o', mods = 'LEADER', action = wezterm.action_callback(function(window, pane)
      -- pane:move_to_new_window() exists only on builds newer than the 20240203 stable; no-op there.
      if build_date > 20240203 then pane:move_to_new_window() end
  end) },
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
