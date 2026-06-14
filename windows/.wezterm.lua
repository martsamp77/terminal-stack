-- ~/.wezterm.lua (Windows) — minimal baseline.
-- Near-stock WezTerm + a small set of pane/tab keybindings. One lightweight
-- event handler (format-tab-title) renders flat "<index>: <dir>" tab labels and
-- tints them green (done) / red (error) from the Claude Code state glyph the
-- hooks write into the tab title. A second handler (update-right-status) shows
-- the workspace + cwd top-right.
-- Keep visual settings + keys in sync with dot_wezterm.lua (macOS).

local wezterm = require 'wezterm'
local act = wezterm.action
local pane_grid = require 'pane_grid'
local config = wezterm.config_builder()

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
config.use_fancy_tab_bar = true    -- native/fancy tabs (styled via window_frame + colors.tab_bar)
config.hide_tab_bar_if_only_one_tab = false
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.initial_cols = 120
config.initial_rows = 30
config.tab_max_width = 120
config.window_frame = {
  font = wezterm.font { family = 'JetBrainsMono Nerd Font', weight = 'Bold' },
  font_size = 11.0,
  active_titlebar_bg = '#181825',    -- Catppuccin mantle (focused)
  inactive_titlebar_bg = '#11111b',  -- crust (unfocused)
}

-- WebGpu is WezTerm's modern, fastest backend (set explicitly). If a render
-- stall on child-process startup reappears, fall back to 'OpenGL'.
config.front_end = 'WebGpu'
config.scrollback_lines = 10000
config.audible_bell = 'Disabled'
config.adjust_window_size_when_changing_font_size = false
-- Strong active-pane signal: heavily dim inactive panes + a bright split line.
config.inactive_pane_hsb = { brightness = 0.25, saturation = 0.6, hue = 1.0 }
config.colors = {
  split = '#b4befe',  -- lavender divider between panes
  tab_bar = {  -- Catppuccin Mocha; per-segment text colour is driven in format-tab-title
    background = '#11111b',
    active_tab         = { bg_color = '#313244', fg_color = '#cdd6f4', intensity = 'Bold' },
    inactive_tab       = { bg_color = '#181825', fg_color = '#6c7086' },
    inactive_tab_hover = { bg_color = '#313244', fg_color = '#a6adc8', italic = true },
    new_tab            = { bg_color = '#181825', fg_color = '#6c7086' },
    new_tab_hover      = { bg_color = '#313244', fg_color = '#cdd6f4' },
  },
}

-- Ctrl+Space leader: left pinky + thumb, frees the right hand for j/k/i/m.
-- phys:Space matches the physical key — Ctrl+Space emits NUL on Windows, which a
-- logical ' ' match would miss (same reason pane_grid.lua uses phys:F*).
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

local WEZTERM_CLI = 'wezterm.exe'

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

-- ── Tab labels: " <idx>  <icon> <dir>  <badge|dots> " ─────────────────────────
-- Per-pane Claude state comes from the `cc_state` user var the wez-tab-status hook
-- sets (working/done/error, cleared on exit). We show a coloured dot per pane and
-- tint the whole label by the most urgent state (error > done; working stays
-- neutral, shown only by its dot). The process icon is best-effort from the
-- foreground process; Claude is detected via the user var because Windows/WSL often
-- report a wrapper process rather than `claude`. Nerd-font lookups are fallback-
-- guarded (unknown names resolve to nil) so a missing glyph can't break the bar.
local PROC_ICONS = {
  pwsh = wezterm.nerdfonts.md_powershell, powershell = wezterm.nerdfonts.md_powershell,
  zsh = wezterm.nerdfonts.md_console, bash = wezterm.nerdfonts.md_console,
  sh = wezterm.nerdfonts.md_console, wsl = wezterm.nerdfonts.md_console,
  nvim = wezterm.nerdfonts.custom_vim, vim = wezterm.nerdfonts.custom_vim,
  git = wezterm.nerdfonts.dev_git, node = wezterm.nerdfonts.md_nodejs,
  python = wezterm.nerdfonts.md_language_python, python3 = wezterm.nerdfonts.md_language_python,
}
local ICON_CLAUDE   = wezterm.nerdfonts.md_robot or '*'
local ICON_FALLBACK = wezterm.nerdfonts.md_console or '>'
local ICON_ZOOM     = wezterm.nerdfonts.md_fullscreen or 'Z'
local TAB = {  -- Catppuccin Mocha
  text = '#cdd6f4', dim = '#6c7086',
  working = '#fab387', done = '#a6e3a1', error = '#eba0ac',  -- maroon, not the old hot pink
}

local function dir_leaf(pane)
  local cwd = pane.current_working_dir
  if not cwd then return nil end
  local p = (type(cwd) == 'userdata' and cwd.file_path) or tostring(cwd)
  p = p:gsub('^file://[^/]*', ''):gsub('[/\\]+$', '')
  return p:match('[^/\\]+$')
end

local function proc_leaf(pane)
  local name = pane.foreground_process_name
  if not name or name == '' then return nil end
  return (name:gsub('[/\\]+$', ''):match('[^/\\]+$') or name):gsub('%.exe$', ''):lower()
end

-- Claude state from a pane's user var: 'working'|'done'|'error' or nil.
local function pane_cc(pane)
  local s = pane.user_vars and pane.user_vars.cc_state
  if s == nil or s == '' then return nil end
  return s
end

wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
  local active = tab.active_pane
  local leaf = wezterm.truncate_right(dir_leaf(active) or active.title or '', 24)

  -- icon: Claude (by user var) else the foreground process, with a fallback glyph.
  local icon
  if pane_cc(active) then
    icon = ICON_CLAUDE
  else
    local p = proc_leaf(active)
    icon = (p and PROC_ICONS[p]) or ICON_FALLBACK
  end

  -- per-pane dots + aggregate state; note Claude panes and zoom.
  local dots, agg, any_cc, zoomed = {}, nil, false, false
  for _, p in ipairs(tab.panes) do
    local s = pane_cc(p)
    if s then
      any_cc = true
      table.insert(dots, { c = TAB[s] or TAB.dim, g = '●' })
      if s == 'error' then agg = 'error'
      elseif s == 'done' and agg ~= 'error' then agg = 'done'
      elseif s == 'working' and not agg then agg = 'working' end
    else
      table.insert(dots, { c = TAB.dim, g = '○' })
    end
    if p.is_zoomed then zoomed = true end
  end

  -- label colour: error/done tint (calm); else neutral, dimmed when inactive.
  local fg = TAB.text
  if agg == 'error' then fg = TAB.error
  elseif agg == 'done' then fg = TAB.done
  elseif not tab.is_active then fg = TAB.dim end
  local bold = tab.is_active or agg == 'error' or agg == 'done'

  local items = {
    { Attribute = { Intensity = bold and 'Bold' or 'Half' } },
    { Foreground = { Color = fg } },
    { Text = ' ' .. (tab.tab_index + 1) .. '  ' .. icon .. ' ' .. leaf .. ' ' },
  }
  if any_cc then                         -- dots imply the pane count
    table.insert(items, { Text = ' ' })
    for _, d in ipairs(dots) do
      table.insert(items, { Foreground = { Color = d.c } })
      table.insert(items, { Text = d.g })
    end
  elseif #tab.panes > 1 then
    table.insert(items, { Foreground = { Color = TAB.dim } })
    table.insert(items, { Text = ' ' .. #tab.panes })
  end
  if zoomed then
    table.insert(items, { Foreground = { Color = TAB.dim } })
    table.insert(items, { Text = ' ' .. ICON_ZOOM })
  end
  table.insert(items, { Text = ' ' })
  return items
end)

-- ── Per-pane Claude background tint (ConPTY-proof) ────────────────────────────
-- The hook also emits an OSC 11 background tint, but on Windows ConPTY eats OSC
-- 10/11/12 before they reach WezTerm (the cc_state user var survives because
-- ConPTY passes the unknown OSC 1337 through verbatim — that's why the tab dots
-- work but the pane never tinted). Re-drive the tint from that user var here:
-- user-var-changed fires reliably, and pane:inject_output feeds the OSC 11 into
-- WezTerm's own emulator, bypassing ConPTY entirely. Local panes, every platform;
-- mux/SSH panes (no inject_output) fall back to the hook's raw OSC 11. See
-- docs/powershell-quirks.md § "ConPTY swallows the OSC 11 pane background tint".
local CC_BG   = { working = '#2a2420', done = '#1f2a20', error = '#2e1e24' }
local CC_BASE = '#1e1e2e'  -- Catppuccin Mocha base (matches config.color_scheme)
wezterm.on('user-var-changed', function(window, pane, name, value)
  if name ~= 'cc_state' then return end
  local color = CC_BG[value] or CC_BASE          -- '' (cleared on exit) → reset
  pcall(function() pane:inject_output('\x1b]11;' .. color .. '\x07') end)
end)

-- ── Top-right status: [⬡ workspace │] user@host │ current path ─────────────────
-- The ⬡ workspace segment shows only when it isn't the default (it's `default` most of
-- the time, so that slot is freed for the identity). user@host is computed once below.
local function cwd_path(pane)
  local cwd = pane:get_current_working_dir()
  if not cwd then return '' end
  if type(cwd) == 'userdata' then return cwd.file_path or tostring(cwd) end
  return (tostring(cwd):gsub('^file://[^/]*', ''))
end

-- Local identity for the right status: "User@host" (FQDN domain stripped). os.getenv
-- reads the wezterm GUI process env (USERNAME on Windows, USER on macOS/Linux).
local function titlecase(s) return #s > 0 and (s:sub(1, 1):upper() .. s:sub(2):lower()) or s end
local IDENTITY = (function()
  local user = titlecase(os.getenv('USERNAME') or os.getenv('USER') or '')
  local host = titlecase((wezterm.hostname() or ''):gsub('%..*$', ''))   -- ORION -> Orion
  if #user > 0 and #host > 0 then return user .. '@' .. host end
  return user .. host
end)()

wezterm.on('update-right-status', function(window, pane)
  local items = {}
  local ws = window:active_workspace()
  if ws ~= 'default' then                              -- workspace only when non-default
    table.insert(items, { Foreground = { Color = '#89b4fa' } })
    table.insert(items, { Text = '⬡ ' .. ws })
    table.insert(items, { Foreground = { Color = '#585b70' } })
    table.insert(items, { Text = '  │  ' })
  end
  table.insert(items, { Foreground = { Color = '#94e2d5' } })   -- identity (teal)
  table.insert(items, { Text = IDENTITY })
  table.insert(items, { Foreground = { Color = '#585b70' } })
  table.insert(items, { Text = '  │  ' })
  table.insert(items, { Foreground = { Color = '#a6adc8' } })   -- path (grey)
  table.insert(items, { Text = cwd_path(pane) .. '  ' })
  window:set_right_status(wezterm.format(items))
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
