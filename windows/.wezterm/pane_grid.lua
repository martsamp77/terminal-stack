-- pane_grid.lua — build-or-focus a 3×2 pane grid for WezTerm.
-- Deployed to ~/.wezterm/pane_grid.lua (WezTerm's Lua module search path).
-- Keep in sync with dot_wezterm/pane_grid.lua (macOS chezmoi deploy).
--
-- F1..F6 (and Ctrl+Space 1..6) each map to one cell of a row-major
-- 3-across × 2-down grid:
--     F1 | F2 | F3      columns grow rightward → even thirds
--     F4 | F5 | F6      rows grow downward     → even halves
-- Pressing a key focuses that cell's pane, creating it — and any missing parent
-- cells — by splitting. Shift+F<n> prompts for a domain and opens the new pane
-- there. Panes are tracked by id per tab (not by geometry), so uneven/manual
-- splits don't confuse it and a re-press just refocuses. State is per WezTerm
-- process: it resets on config reload / restart, and a grid pane closed by hand
-- is recreated from its parent on the next press.

local wezterm = require 'wezterm'
local act = wezterm.action

local M = {}

-- Cell construction tree. Each non-origin cell is made by splitting its parent in
-- `dir`, the NEW pane taking `frac` of the parent (pane:split size = fraction).
-- Column fracs make the finished top row even thirds: F2 takes 2/3 of F1 (→ 1/3
-- each), then F3 halves F2's 2/3 block (→ 1/3, 1/3). Rows are even halves.
-- (Stopping at two columns therefore leaves a 1/3–2/3 split; resize with
-- Leader+J/K if you don't go on to add the third.)
local CELLS = {
  ['1'] = {},                                          -- origin (top-left)
  ['2'] = { parent = '1', dir = 'Right',  frac = 0.67 },
  ['3'] = { parent = '2', dir = 'Right',  frac = 0.5 },
  ['4'] = { parent = '1', dir = 'Bottom', frac = 0.5 },
  ['5'] = { parent = '2', dir = 'Bottom', frac = 0.5 },
  ['6'] = { parent = '3', dir = 'Bottom', frac = 0.5 },
}

-- grid_state[tab_id] = { ['1'] = pane_id, ... }
local grid_state = {}

local function unzoom_tab_if_needed(tab)
  for _, info in ipairs(tab:panes_with_info()) do
    if info.is_zoomed then
      tab:set_zoomed(false)
      return
    end
  end
end

-- The live MuxPane for pane_id if it still exists *in this tab*, else nil.
local function pane_in_tab(tab, pane_id)
  if not pane_id then return nil end
  for _, p in ipairs(tab:panes()) do
    if p:pane_id() == pane_id then return p end
  end
  return nil
end

-- Return the pane for `key`, creating it (and any missing parents) as needed.
-- `leaf_domain` (a pane:split domain spec) applies only to the key's own new
-- pane; parents are always created in the current domain.
local function ensure(tab, key, leaf_domain)
  local tid = tab:tab_id()
  grid_state[tid] = grid_state[tid] or {}
  local st = grid_state[tid]
  local cell = CELLS[key]
  if not cell then return nil end

  local existing = pane_in_tab(tab, st[key])
  if existing then return existing end

  if not cell.parent then          -- origin: adopt the active pane
    local p = tab:active_pane()
    st[key] = p:pane_id()
    return p
  end

  local parent = ensure(tab, cell.parent, nil)
  if not parent then return nil end
  local newp = parent:split {
    direction = cell.dir,
    size = cell.frac,
    domain = leaf_domain or 'CurrentPaneDomain',
  }
  st[key] = newp:pane_id()
  return newp
end

-- Build-or-focus grid cell `key`. `leaf_domain` is nil (current domain) or a
-- pane:split domain spec (e.g. { DomainName = 'WSL:Ubuntu' }).
function M.go(window, pane, key, leaf_domain)
  local tab = pane:tab()
  if not tab then return end
  unzoom_tab_if_needed(tab)
  local target = ensure(tab, key, leaf_domain)
  if target then target:activate() end
end

local function domain_choices()
  local choices = {}
  for _, d in ipairs(wezterm.mux.all_domains()) do
    table.insert(choices, { id = d:name(), label = d:name() })
  end
  table.sort(choices, function(a, b) return a.label < b.label end)
  return choices
end

-- F1..F6 + Leader+1..6 → build/focus in the current domain.
-- Shift+F1..F6      → prompt for a domain, open the cell's new pane there.
-- phys:F* (physical position) because key_map_preference defaults to Mapped and
-- bare F-keys may not match on Windows.
function M.bind_keys(keys, wezterm_mod)
  for n = 1, 6 do
    local key = tostring(n)   -- fresh local per iteration → safe to close over
    local plain = wezterm_mod.action_callback(function(w, p)
      M.go(w, p, key, nil)
    end)
    table.insert(keys, { key = 'phys:F' .. n, mods = 'NONE',   action = plain })
    table.insert(keys, { key = key,           mods = 'LEADER', action = plain })

    local pick = wezterm_mod.action_callback(function(w, p)
      w:perform_action(act.InputSelector {
        title = 'Open grid cell F' .. key .. ' in domain',
        choices = domain_choices(),
        fuzzy = true,
        action = wezterm_mod.action_callback(function(win, p2, id)
          if id then M.go(win, p2, key, { DomainName = id }) end
        end),
      }, p)
    end)
    table.insert(keys, { key = 'phys:F' .. n, mods = 'SHIFT', action = pick })
  end
end

return M
