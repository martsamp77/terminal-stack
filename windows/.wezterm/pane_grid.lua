-- pane_grid.lua — predictable, geometry-driven 3x2 pane grid for WezTerm.
-- Deployed to ~/.wezterm/pane_grid.lua (WezTerm's Lua module search path).
-- Keep in sync with dot_wezterm/pane_grid.lua (macOS chezmoi deploy).
--
-- F1..F6 (and Ctrl+Space 1..6) map to cells of a row-major 3-across x 2-down grid:
--     F1 | F2 | F3        F1 also maximizes the window.
--     F4 | F5 | F6
--
-- Labels are derived from on-screen geometry EVERY press, so F<n> always lands on
-- the same pane regardless of build order. Press F<n>:
--   * pane n exists  -> activate it (F1 also maximizes).
--   * n == count+1 and the layout is the canonical one for `count` -> create it
--     (the next step in the strict build order), then focus it.
--   * otherwise       -> do nothing (e.g. F4 while only F1/F2 exist).
--
-- Build order (each key creates the NEXT pane; columns become even thirds, rows
-- even halves by construction):
--   1->2  F2: split the sole pane Right
--   2->3  F3: split the left column Down       (lower-left)
--   3->4  F4: split the right column Down       (2x2)
--   4->5  F5: top-level split Right (full height far-right column; relabels)
--   5->6  F6: split the full-height right column Down
-- WezTerm has no absolute-resize/equalize API, so a grid that was MANUALLY resized
-- is not auto-re-evened; rebuild via the F-keys for an even grid.

local wezterm = require 'wezterm'
local act = wezterm.action

local M = {}

local MAXCOLS, MAXROWS = 3, 2
local TOL = 2  -- cells: collapse near-identical pane edges into one column/row

-- BUILD[count] = how to create pane (count+1). `label` = which existing pane to
-- split (by its current grid label); top_level splits the whole tab.
local BUILD = {
  [1] = { label = 1, dir = 'Right',  size = 0.5 },
  [2] = { label = 1, dir = 'Bottom', size = 0.5 },
  [3] = { label = 2, dir = 'Bottom', size = 0.5 },
  [4] = { top_level = true, dir = 'Right', size = 1 / 3 },
  [5] = { label = 3, dir = 'Bottom', size = 0.5 },
}

local function distinct_sorted(vals)
  table.sort(vals)
  local out = {}
  for _, v in ipairs(vals) do
    if #out == 0 or v - out[#out] > TOL then table.insert(out, v) end
  end
  return out
end

local function index_of(edges, x)
  for i = 1, #edges do
    if math.abs(x - edges[i]) <= TOL then return i end
  end
  local idx = 1
  for i = 1, #edges do if x >= edges[i] then idx = i end end
  return idx
end

local function unzoom(tab)
  for _, it in ipairs(tab:panes_with_info()) do
    if it.is_zoomed then tab:set_zoomed(false); return end
  end
end

-- Build the label->pane map from current geometry, plus a canonical flag.
local function geometry(tab)
  local infos = tab:panes_with_info()
  local lefts, tops = {}, {}
  for _, it in ipairs(infos) do
    table.insert(lefts, it.left)
    table.insert(tops, it.top)
  end
  lefts, tops = distinct_sorted(lefts), distinct_sorted(tops)
  local ncols, nrows = #lefts, #tops
  local map, canonical = {}, (ncols <= MAXCOLS and nrows <= MAXROWS)
  for _, it in ipairs(infos) do
    local col = index_of(lefts, it.left)
    local row = index_of(tops, it.top)
    local label = (row - 1) * ncols + col
    if map[label] then canonical = false end  -- two panes claim one cell
    map[label] = it.pane
  end
  local count = #infos
  for i = 1, count do if not map[i] then canonical = false end end  -- contiguous 1..count
  return { map = map, count = count, ncols = ncols, nrows = nrows, canonical = canonical }
end

-- Activate a mux pane via its index in the tab (the proven activation path).
local function focus(window, ref_pane, tab, target)
  local tid = target:pane_id()
  for _, it in ipairs(tab:panes_with_info()) do
    if it.pane:pane_id() == tid then
      window:perform_action(act.ActivatePaneByIndex(it.index), ref_pane)
      return
    end
  end
end

-- Create pane n (== count+1) per the build step; returns the new pane or nil.
local function create(tab, n, leaf_domain)
  local g = geometry(tab)
  if not g.canonical or n ~= g.count + 1 then return nil end
  local step = BUILD[g.count]
  if not step then return nil end
  local src = step.top_level and (g.map[1] or tab:active_pane()) or g.map[step.label]
  if not src then return nil end
  return src:split {
    direction = step.dir,
    size = step.size,
    top_level = step.top_level or false,
    domain = leaf_domain or 'CurrentPaneDomain',
  }
end

-- Press F<n> (leaf_domain set only for the Shift+F variant).
function M.go(window, pane, n, leaf_domain)
  local tab = pane:tab()
  if not tab then return end
  unzoom(tab)
  local g = geometry(tab)
  local target = g.map[n]
  if target then
    focus(window, pane, tab, target)
    if n == 1 then window:maximize() end
    return
  end
  local newp = create(tab, n, leaf_domain)
  if newp then focus(window, pane, tab, newp) end
  -- else: invalid for the current layout -> no-op
end

local function domain_choices()
  local choices = {}
  for _, d in ipairs(wezterm.mux.all_domains()) do
    table.insert(choices, { id = d:name(), label = d:name() })
  end
  table.sort(choices, function(a, b) return a.label < b.label end)
  return choices
end

-- F1..F6 + Leader+1..6 build/focus the grid. Shift+F1..F6 do the same, but a
-- newly CREATED pane opens in a fuzzy-picked domain. phys:F* because
-- key_map_preference defaults to Mapped and bare F-keys may not match on Windows.
function M.bind_keys(keys, wezterm_mod)
  for n = 1, 6 do
    local num = n                      -- fresh per iteration -> safe to close over
    local plain = wezterm_mod.action_callback(function(w, p) M.go(w, p, num, nil) end)
    table.insert(keys, { key = 'phys:F' .. n, mods = 'NONE',   action = plain })
    table.insert(keys, { key = tostring(n),   mods = 'LEADER', action = plain })

    local pick = wezterm_mod.action_callback(function(w, p)
      w:perform_action(act.InputSelector {
        title = 'Open grid cell F' .. num .. ' in domain',
        choices = domain_choices(),
        fuzzy = true,
        action = wezterm_mod.action_callback(function(win, p2, id)
          if id then M.go(win, p2, num, { DomainName = id }) end
        end),
      }, p)
    end)
    table.insert(keys, { key = 'phys:F' .. n, mods = 'SHIFT', action = pick })
  end
end

return M
