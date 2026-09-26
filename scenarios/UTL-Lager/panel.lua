--- Szenario „UTL-Lager“: Erklärfenster (scripts/lib/explain-panel.lua) mit drei Teilen – Lager,
--- Wende-Greifarm, Cleanup gibt zurück. Die Schritte sind eine Legende: hervorgehoben ist, was
--- gerade zu sehen ist; die Kamera folgt dem beteiligten Zug bzw. Greifarm.
local Explain = require("__UTLogistics__/scripts/lib/explain-panel")

local Panel = {}

local NAME = "utl_lager_panel"
local NEXT = "next"
local CHAPTERS = { "storage", "reversible", "cleanup" }

local last -- letzter Stand aus control.lua (für den Knopf zwischen zwei Sekunden)

function Panel.create(player)
  Explain.create(player, {
    name = NAME,
    title = { "utl-lager.title" },
    intro = { "utl-lager.intro" },
    button = { action = NEXT, tooltip = { "utl-lager.next-tooltip" } },
  })
  if last then Panel.refresh(player, last) end
end

local function steps(chapter, count)
  local list = {}
  for i = 1, count do list[i] = { "utl-lager." .. chapter .. "-" .. i } end
  return list
end

--- Je Teil: aktueller Schritt, Kameraziel, große Zeile und Notiz.
local VIEW = {
  storage = function(v)
    local by, current, follow = v.by, 6, v.stops.storage
    if by.into then
      current = (by.into.state == "to_provider" or by.into.state == "loading") and 1 or 2
      follow = v.front(by.into.train_id)
    elseif by.out then
      current, follow = v.out_to_workshop and 5 or 3, v.front(by.out.train_id)
    elseif by.workshop then
      current, follow = 4, v.front(by.workshop.train_id)
    end
    return current, follow, { "utl-lager.storage-big", v.storage_stock },
      { "utl-lager.storage-note", v.counts.into, v.counts.out, v.counts.workshop }
  end,
  reversible = function(v)
    local by, current, follow = v.by, 1, v.revs.storage
    if by.into and by.into.state == "unloading" then
      current = 2
    elseif by.out and by.out.state == "loading" then
      current = 3
    elseif by.returned and by.returned.state == "loading" then
      current, follow = 5, v.revs.cleanup
    elseif v.rest_train then
      current, follow = 4, v.revs.cleanup
    end
    return current, follow, { v.flipped and "utl-lager.rev-flipped" or "utl-lager.rev-normal" },
      { "utl-lager.rev-note", v.counts.flips }
  end,
  cleanup = function(v)
    local by, current, follow = v.by, 1, v.stops.cleanup
    if by.returned then
      current, follow = 5, v.front(by.returned.train_id)
    elseif v.rest_train then
      current, follow = 3, v.rest_train
    elseif by.copper_a then
      local late = by.copper_a.state == "to_requester" or by.copper_a.state == "unloading"
      current = (late and v.filled == by.copper_a.id) and 2 or 1
      follow = v.front(by.copper_a.train_id)
    elseif v.cleanup_stock > 0 then
      current = 4
    end
    return current, follow, { "utl-lager.cleanup-big", v.cleanup_stock },
      { "utl-lager.cleanup-note", v.counts.rest, v.counts.returned }
  end,
}
local STEP_COUNT = { storage = 6, reversible = 5, cleanup = 5 }

function Panel.refresh(player, v)
  local index = storage.lager and storage.lager.chapter or 1
  local chapter = CHAPTERS[index]
  local current, follow, big, note = VIEW[chapter](v)
  Explain.update(player, NAME, {
    headline = { "utl-lager.headline", index, { "utl-lager.chapter-" .. chapter } },
    button = { "utl-lager.next", { "utl-lager.chapter-" .. CHAPTERS[index % 3 + 1] } },
    steps = steps(chapter, STEP_COUNT[chapter]),
    current = current,
    legend = true,
    follow = follow and follow.valid and follow or nil,
    big = big,
    note = note,
  })
end

--- `v` = Stand aus control.lua; ohne `v` der letzte (Knopf gedrückt).
function Panel.refresh_all(v)
  last = v or last
  if not last then return end
  for _, player in pairs(game.connected_players) do Panel.refresh(player, last) end
end

--- Liefert true, wenn „Nächster Teil“ gedrückt wurde.
function Panel.on_click(event)
  return Explain.on_click(event) == NEXT
end

return Panel
