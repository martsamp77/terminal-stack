-- ~/.wezterm.lua — macOS counterpart of windows/.wezterm.lua. Minimal baseline.
-- chezmoi applies this only on darwin; native Linux hosts in this stack are
-- headless (ssh/PuTTY) and need no WezTerm GUI config.
-- Near-stock WezTerm + a small set of pane/tab keybindings. One lightweight
-- event handler (format-tab-title) renders flat "<index>: <dir>" tab labels and
-- tints them green (done) / red (error) from the Claude Code state glyph the
-- hooks write into the tab title. A second handler (update-right-status) shows
-- the workspace + cwd top-right.
-- Keep in sync with windows/.wezterm.lua.

local wezterm = require 'wezterm'
local act = wezterm.action
local pane_grid = require 'pane_grid'
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
config.use_fancy_tab_bar = false   -- flat retro tab bar (see format-tab-title below)
config.hide_tab_bar_if_only_one_tab = false
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.initial_cols = 120
config.initial_rows = 40
config.tab_max_width = 120
config.window_frame = { font_size = 11.0 }
-- Strong active-pane signal: heavily dim inactive panes + a bright split line.
config.inactive_pane_hsb = { brightness = 0.25, saturation = 0.6, hue = 1.0 }
config.colors = { split = '#b4befe' }  -- lavender divider between panes

-- WebGpu is WezTerm's modern, fastest backend (set explicitly). If a render
-- stall on child-process startup reappears, fall back to 'OpenGL'.
config.front_end = 'WebGpu'
config.scrollback_lines = 10000

-- Ctrl+Space leader: left pinky + thumb, frees the right hand for j/k/i/m.
-- phys:Space matches the physical key (kept identical to the Windows side).
config.leader = { key = 'phys:Space', mods = 'CTRL', timeout_milliseconds = 1500 }

-- Fuzzy-pick a domain (Alt+L style) and split it into the current pane.
-- direction is a wezterm SplitPane direction ('Right' or 'Down').
local function pick_domain_split(window, pane, direction)
  local choices = {}
  for _, d in ipairs(wezterm.mux.all_domains()) do
    table.insert(choices, { id = d:name(), label = d:name() })
  end
  table.sort(choices, function(a, b) return a.label < b.label end)
  window:perform_action(act.InputSelector {
    title = 'Split ' .. direction:lower() .. ' into domain',
    choices = choices,
    fuzzy = true,
    action = wezterm.action_callback(function(win, p, id)
      if not id then return end
      -- SplitPane has no `domain` field; SplitHorizontal/SplitVertical take a
      -- SpawnCommand whose `domain` selects the target domain.
      if direction == 'Right' then
        win:perform_action(act.SplitHorizontal { domain = { DomainName = id } }, p)
      else
        win:perform_action(act.SplitVertical { domain = { DomainName = id } }, p)
      end
    end),
  }, pane)
end

local WEZTERM_CLI = 'wezterm'

-- Close every pane in the current workspace (the "delete this workspace" gesture).
-- WezTerm has no Lua API to close a tab/workspace, so collect pane ids from the mux
-- and kill them via `wezterm cli`, after switching the GUI to another workspace so
-- WezTerm doesn't quit when the last window of the doomed workspace closes.
local function kill_workspace(window, pane)
  local target = window:active_workspace()
  local fallback
  for _, n in ipairs(wezterm.mux.get_workspace_names()) do
    if n ~= target then fallback = n break end
  end
  if not fallback then
    window:toast_notification('WezTerm', 'Cannot kill the only workspace', nil, 4000)
    return
  end
  window:perform_action(act.InputSelector {
    title = "Kill workspace '" .. target .. "'? (closes all its panes)",
    choices = { { id = 'yes', label = 'Yes, close all panes' }, { id = 'no', label = 'Cancel' } },
    action = wezterm.action_callback(function(win, p, id)
      if id ~= 'yes' then return end
      local ids = {}
      for _, w in ipairs(wezterm.mux.all_windows()) do
        if w:get_workspace() == target then
          for _, tab in ipairs(w:tabs()) do
            for _, pn in ipairs(tab:panes()) do table.insert(ids, tostring(pn:pane_id())) end
          end
        end
      end
      win:perform_action(act.SwitchToWorkspace { name = fallback }, p)
      for _, pid in ipairs(ids) do
        wezterm.run_child_process { WEZTERM_CLI, 'cli', 'kill-pane', '--pane-id', pid }
      end
    end),
  }, pane)
end

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
  -- Workspace management: R = rename, X = kill (close every pane in it).
  { key = 'R', mods = 'LEADER', action = act.PromptInputLine {
      description = 'Rename workspace to:',
      action = wezterm.action_callback(function(window, pane, line)
        if line and #line > 0 then
          wezterm.mux.rename_workspace(window:active_workspace(), line)
        end
      end) } },
  { key = 'X', mods = 'LEADER', action = wezterm.action_callback(kill_workspace) },
  -- Local splits: h = top/bottom (stacked), v = left/right (side-by-side).
  { key = 'h', mods = 'LEADER', action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },
  { key = 'v', mods = 'LEADER', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  -- Domain splits (Shift = "remote"): H = pick domain → top/bottom, V = pick domain → left/right.
  { key = 'H', mods = 'LEADER', action = wezterm.action_callback(function(w, p) pick_domain_split(w, p, 'Down') end) },
  { key = 'V', mods = 'LEADER', action = wezterm.action_callback(function(w, p) pick_domain_split(w, p, 'Right') end) },
  { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
  { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
  { key = 'i', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
  { key = 'm', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
  { key = 'J', mods = 'LEADER', action = act.AdjustPaneSize { 'Left',  5 } },
  { key = 'K', mods = 'LEADER', action = act.AdjustPaneSize { 'Right', 5 } },
  { key = 'I', mods = 'LEADER', action = act.AdjustPaneSize { 'Up',    5 } },
  { key = 'M', mods = 'LEADER', action = act.AdjustPaneSize { 'Down',  5 } },
  { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
  { key = 'phys:Space', mods = 'LEADER|CTRL', action = act.SendKey { key = ' ', mods = 'CTRL' } },
  { key = 'r', mods = 'LEADER', action = act.ReloadConfiguration },
  -- Tab selection: Alt+1..9 (number matches tab); Ctrl+Tab / Ctrl+Shift+Tab cycle.
  -- (Leader+1..6 build/focus the 3×2 pane grid; see pane_grid.lua.)
  { key = 'Tab', mods = 'CTRL',       action = act.ActivateTabRelative(1) },
  { key = 'Tab', mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(-1) },
  -- Pop the current pane out into its own new window.
  -- Leader+o for muscle memory; Ctrl+Shift+O for quick access without the leader.
  { key = 'o', mods = 'LEADER',     action = wezterm.action_callback(function(window, pane) pane:move_to_new_window() end) },
  { key = 'o', mods = 'CTRL|SHIFT', action = wezterm.action_callback(function(window, pane) pane:move_to_new_window() end) },
  -- Close the current pane (x freed when the domain picker moved to Leader+V).
  { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },
  { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
  -- Shift+Enter → newline in CLI REPLs (Claude Code): send LF (= Ctrl+J, the
  -- default chat:newline). WezTerm doesn't deliver a distinct Shift+Enter to the
  -- app by default, so the app-level keybinding (keybindings.json) alone can't fire.
  { key = 'Enter', mods = 'SHIFT', action = act.SendString '\n' },
}

-- ── Flat tab labels: "<index>: <dir-leaf>", with a light Claude Code hint ─────
-- The CC hooks set the tab title to "cc <glyph> <project>" (✓ on Stop, ✗ on
-- error). We read only the glyph for colour and always render our own label, so
-- thinking/working tabs stay plain and the colour shows on inactive tabs too.
local CC_DONE  = '\xe2\x9c\x93'  -- ✓  Stop        → green
local CC_ERROR = '\xe2\x9c\x97'  -- ✗  StopFailure → red

local function dir_leaf(pane)
  local cwd = pane.current_working_dir
  if not cwd then return nil end
  local p = (type(cwd) == 'userdata' and cwd.file_path) or tostring(cwd)
  p = p:gsub('^file://[^/]*', ''):gsub('[/\\]+$', '')
  return p:match('[^/\\]+$')
end

wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
  local leaf = dir_leaf(tab.active_pane) or tab.active_pane.title or ''
  local label = wezterm.truncate_right(' ' .. (tab.tab_index + 1) .. ': ' .. leaf .. ' ', max_width)
  local ttl = tab.tab_title or ''
  if ttl:find(CC_ERROR, 1, true) then
    return { { Foreground = { Color = '#f38ba8' } }, { Text = label } }  -- red
  elseif ttl:find(CC_DONE, 1, true) then
    return { { Foreground = { Color = '#a6e3a1' } }, { Text = label } }  -- green
  end
  return label
end)

-- ── Top-right status: workspace + current path (both always shown) ────────────
local function cwd_path(pane)
  local cwd = pane:get_current_working_dir()
  if not cwd then return '' end
  if type(cwd) == 'userdata' then return cwd.file_path or tostring(cwd) end
  return (tostring(cwd):gsub('^file://[^/]*', ''))
end

wezterm.on('update-right-status', function(window, pane)
  window:set_right_status(wezterm.format {
    { Foreground = { Color = '#89b4fa' } },
    { Text = '⬡ ' .. window:active_workspace() },
    { Foreground = { Color = '#585b70' } },
    { Text = '  │  ' },
    { Foreground = { Color = '#a6adc8' } },
    { Text = cwd_path(pane) .. '  ' },
  })
end)

-- ── Dim every pane while the window is unfocused ──────────────────────────────
-- inactive_pane_hsb only dims *inactive* panes of the focused window; the active
-- pane stays bright. On blur we want a uniform dim across all panes, so we dim all
-- text (foreground_text_hsb) and cancel the per-pane inactive dim. On focus we drop
-- both overrides → back to active-bright / inactive-dim.
wezterm.on('window-focus-changed', function(window)
  local o = window:get_config_overrides() or {}
  if window:is_focused() then
    o.foreground_text_hsb = nil
    o.inactive_pane_hsb   = nil
  else
    o.foreground_text_hsb = { brightness = 0.35, saturation = 0.8, hue = 1.0 }
    o.inactive_pane_hsb   = { brightness = 1.0, saturation = 1.0, hue = 1.0 }
  end
  window:set_config_overrides(o)
end)

-- Alt+1..9 → activate tab by number (appended to the literal config.keys above).
for i = 1, 9 do
  table.insert(config.keys, { key = tostring(i), mods = 'ALT', action = act.ActivateTab(i - 1) })
end

pane_grid.bind_keys(config.keys, wezterm)

return config
