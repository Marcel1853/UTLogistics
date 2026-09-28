--- Szenario „UTL-Beispiele“: Beobachter-Fenster (scripts/lib/explain-panel.lua). Es folgt einem der
--- beiden Züge und erklärt, was er gerade tut – vom Auftrag über das Laden (Auftrags-Ausgabe gibt
--- nur den passenden Greifarm bzw. die passende Pumpe frei) bis zum Entladen. Ein Knopf wechselt
--- zwischen Artikelzug und Flüssigkeitszug. Nichts wird gesteuert, das Fenster schaut nur zu.
local Explain = require("__UTLogistics__/scripts/lib/explain-panel")

local Panel = {}

local NAME = "utl_beispiele_panel"
local SWITCH = "switch"

-- Zustand der Lieferung → Schritt (1 = kein Auftrag)
local STEP = { to_provider = 2, loading = 3, to_requester = 4, unloading = 5 }

local function state()
  storage.panel = storage.panel or { follow = "item", seen = { item = {}, fluid = {} }, count = { item = 0, fluid = 0 } }
  return storage.panel
end

--- Ladeliste als Symbole mit Menge, z. B. „[item=iron-plate] 400  [item=copper-plate] 200“.
local function manifest_text(manifest)
  local parts = { "" }
  for key, amount in pairs(manifest or {}) do
    local kind, name = string.match(key, "^(%a+)|([^|]+)")
    if kind and name and #parts < 19 then
      parts[#parts + 1] = "[" .. kind .. "=" .. name .. "] " .. math.floor(amount) .. "   "
    end
  end
  return parts
end

function Panel.create(player)
  Explain.create(player, {
    name = NAME,
    title = { "utl-beispiele-panel.title" },
    intro = { "utl-beispiele-panel.intro" },
    button = { action = SWITCH, tooltip = { "utl-beispiele-panel.switch-tooltip" } },
  })
  Panel.refresh(player)
end

--- Einmal pro Sekunde: aktuellen Auftrag des verfolgten Zugs suchen, Zähler führen, Fenster füllen.
function Panel.tick()
  local made = storage.made
  if not made then return end
  local st = state()
  local trains = { item = made.train, fluid = made.fluid_train }
  st.current = {}
  for _, d in pairs(remote.call("utl", "get_deliveries") --[[@as table]]) do
    for kind, train in pairs(trains) do
      if train and train.valid and d.train_id == train.id then
        st.current[kind] = d
        if not st.seen[kind][d.id] then
          st.seen[kind][d.id] = true
          st.count[kind] = st.count[kind] + 1
        end
      end
    end
  end
  for _, player in pairs(game.connected_players) do Panel.refresh(player) end
end

function Panel.refresh(player)
  local made = storage.made
  if not made then return end
  local st = state()
  local kind = st.follow
  local train = kind == "fluid" and made.fluid_train or made.train
  local d = st.current and st.current[kind]
  local from, to = d and d.from or "?", d and d.to or "?"
  local fluid = kind == "fluid"
  Explain.update(player, NAME, {
    headline = { "utl-beispiele-panel.following-" .. kind },
    button = { "utl-beispiele-panel.switch-to-" .. (fluid and "item" or "fluid") },
    steps = {
      { "utl-beispiele-panel.step-idle" },
      { "utl-beispiele-panel.step-job", from, to },
      { fluid and "utl-beispiele-panel.step-load-fluid" or "utl-beispiele-panel.step-load-item", from },
      { "utl-beispiele-panel.step-drive", to },
      { "utl-beispiele-panel.step-unload", to },
    },
    current = d and STEP[d.state] or 1,
    follow = train and train.valid and train.front_stock or nil,
    big = d and { "", { "utl-beispiele-panel.cargo" }, " ", manifest_text(d.manifest) } or { "utl-beispiele-panel.no-job" },
    note = { "utl-beispiele-panel.count", st.count.item, st.count.fluid },
  })
end

--- Klick: Kameraziel wechseln.
function Panel.on_click(event)
  if Explain.on_click(event) ~= SWITCH then return end
  local st = state()
  st.follow = st.follow == "item" and "fluid" or "item"
  local player = game.get_player(event.player_index)
  if player then Panel.refresh(player) end
end

return Panel
