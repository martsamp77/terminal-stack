-- pane_grid.lua — quadrant pane selection for WezTerm.
-- Deployed to ~/.wezterm/pane_grid.lua (WezTerm's Lua module search path).
-- Keep in sync with windows/.wezterm/pane_grid.lua (Windows sync deploy).
-- F1-F4 (and Ctrl+Space 1-4) activate the pane occupying each quadrant of a
-- 2x2 split. Selection is by largest overlap, so it works for uneven splits too.

local wezterm = require 'wezterm'
local act = wezterm.action

local M = {}

local function unzoom_tab_if_needed(tab)
  for _, info in ipairs(tab:panes_with_info()) do
    if info.is_zoomed then
      tab:set_zoomed(false)
      return
    end
  end
end

local function quadrant_rect(cols, rows, quadrant)
  local mid_x = math.floor(cols / 2)
  local mid_y = math.floor(rows / 2)
  if quadrant == 'tl' then
    return 0, 0, mid_x, mid_y
  elseif quadrant == 'tr' then
    return mid_x, 0, cols - mid_x, mid_y
  elseif quadrant == 'bl' then
    return 0, mid_y, mid_x, rows - mid_y
  elseif quadrant == 'br' then
    return mid_x, mid_y, cols - mid_x, rows - mid_y
  end
  return 0, 0, cols, rows
end

local function overlap_area(left, top, width, height, qleft, qtop, qwidth, qheight)
  local x1 = math.max(left, qleft)
  local y1 = math.max(top, qtop)
  local x2 = math.min(left + width, qleft + qwidth)
  local y2 = math.min(top + height, qtop + qheight)
  if x2 <= x1 or y2 <= y1 then
    return 0
  end
  return (x2 - x1) * (y2 - y1)
end

function M.activate_quadrant(window, pane, quadrant)
  local tab = pane:tab()
  if not tab then
    return
  end
  unzoom_tab_if_needed(tab)
  local size = tab:get_size()
  local qleft, qtop, qwidth, qheight = quadrant_rect(size.cols, size.rows, quadrant)
  local best = nil
  local best_area = 0
  for _, info in ipairs(tab:panes_with_info()) do
    local area = overlap_area(info.left, info.top, info.width, info.height, qleft, qtop, qwidth, qheight)
    if area > best_area then
      best_area = area
      best = info
    end
  end
  if best then
    window:perform_action(act.ActivatePaneByIndex(best.index), pane)
  end
end

-- Register quadrant bindings. Uses phys:F* (physical key position) because
-- key_map_preference defaults to Mapped and bare F1 may not match on Windows.
function M.bind_keys(keys, wezterm_mod)
  local specs = {
    { key = 'phys:F1', leader = '1', quadrant = 'tl' },
    { key = 'phys:F2', leader = '2', quadrant = 'tr' },
    { key = 'phys:F3', leader = '3', quadrant = 'bl' },
    { key = 'phys:F4', leader = '4', quadrant = 'br' },
  }
  for _, spec in ipairs(specs) do
    local quadrant = spec.quadrant  -- capture for closure (loop var is not stable across invocations)
    local action = wezterm_mod.action_callback(function(w, p)
      M.activate_quadrant(w, p, quadrant)
    end)
    table.insert(keys, { key = spec.key, mods = 'NONE', action = action })
    table.insert(keys, { key = spec.leader, mods = 'LEADER', action = action })
  end
end

return M
