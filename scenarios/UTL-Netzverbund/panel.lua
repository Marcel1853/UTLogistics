--- Szenario „UTL-Netzverbund“: Erklärfenster (scripts/lib/explain-panel.lua) im Legenden-Modus.
--- Die Kamera folgt bevorzugt einer netzübergreifenden Fahrt (Zug aus Netz A beliefert Netz B) –
--- genau das ist die Pointe des Szenarios. Die Legende hebt hervor, was gerade zu sehen ist, und
--- ein Zähler hält fest, wer bisher für wen gefahren ist. „Kohle → Kupfer“ bleibt dabei 0: Partner
--- helfen sich nicht untereinander.
local Explain = require("__UTLogistics__/scripts/lib/explain-panel")

local Panel = {}

local NAME = "utl_verbund_panel"
local NEXT = "next"

-- (Zugnetz, Abnehmernetz) → Eintrag der Legende
local function legend_index(train_net, target_net)
  if train_net == "Eisen" and (target_net == "Kupfer" or target_net == "Kohle") then return 2 end
  if train_net == "Kohle" and target_net == "Eisen" then return 3 end
  if train_net == "Kohle" and target_net == "Kupfer" then return 4 end -- darf nie vorkommen
  if train_net == "Stein" then return 5 end
  return 1 -- eigene Fahrt im eigenen Netz
end

local function state()
  storage.panel = storage.panel or { seen = {}, count = {}, follow = nil, network_of = {} }
  return storage.panel
end

--- Netz eines Abnehmers (gemerkt, ändert sich im Szenario nicht).
local function network_of(unit)
  local st = state()
  if st.network_of[unit] == nil then
    local info = remote.call("utl", "get_station", unit) --[[@as table?]]
    st.network_of[unit] = info and info.config and info.config.network or false
  end
  return st.network_of[unit] or "?"
end

local function count_key(from, to) return from .. "→" .. to end

function Panel.create(player)
  Explain.create(player, {
    name = NAME,
    title = { "utl-verbund-panel.title" },
    intro = { "utl-verbund-panel.intro" },
    button = { action = NEXT, tooltip = { "utl-verbund-panel.next-tooltip" } },
  })
  Panel.refresh(player)
end

--- Einmal pro Sekunde: Fahrten zählen, verfolgte Fahrt halten oder eine neue wählen.
function Panel.tick(skip_current)
  local st = state()
  local list = remote.call("utl", "get_deliveries") --[[@as table]]
  local by_id, cross = {}, {}
  for _, d in pairs(list) do
    d.target = network_of(d.requester)
    by_id[d.id] = d
    if not st.seen[d.id] then
      st.seen[d.id] = true
      local key = count_key(d.network or "?", d.target)
      st.count[key] = (st.count[key] or 0) + 1
    end
    if d.network ~= d.target then cross[#cross + 1] = d end
  end
  -- Die verfolgte Fahrt behalten, solange sie läuft; sonst bevorzugt eine netzübergreifende.
  if skip_current or not (st.follow and by_id[st.follow]) then
    local pool = #cross > 0 and cross or list
    local pick = nil
    for _, d in ipairs(pool) do
      if d.id ~= st.follow then pick = d break end
    end
    st.follow = (pick or pool[1] or {}).id
  end
  st.current = st.follow and by_id[st.follow] or nil
  for _, player in pairs(game.connected_players) do Panel.refresh(player) end
end

function Panel.refresh(player)
  local st = state()
  local d = st.current
  local follow = nil
  if d then
    local train = game.train_manager.get_train_by_id(d.train_id)
    follow = train and train.valid and train.front_stock or nil
  end
  local c = st.count
  Explain.update(player, NAME, {
    headline = d and { "utl-verbund-panel.following", d.from or "?", d.to or "?" } or { "utl-verbund-panel.waiting" },
    button = { "utl-verbund-panel.next" },
    steps = {
      { "utl-verbund-panel.legend-own" },
      { "utl-verbund-panel.legend-iron-copper" },
      { "utl-verbund-panel.legend-coal-iron" },
      { "utl-verbund-panel.legend-coal-copper" },
      { "utl-verbund-panel.legend-stone" },
    },
    current = d and legend_index(d.network, d.target) or 0,
    legend = true,
    follow = follow,
    big = d and { "utl-verbund-panel.big", d.network or "?", d.target or "?" } or { "utl-verbund-panel.no-trip" },
    note = { "utl-verbund-panel.count",
      c[count_key("Eisen", "Kupfer")] or 0, c[count_key("Eisen", "Kohle")] or 0,
      c[count_key("Kohle", "Eisen")] or 0, c[count_key("Kohle", "Kupfer")] or 0 },
  })
end

--- Klick: zur nächsten laufenden Fahrt springen.
function Panel.on_click(event)
  if Explain.on_click(event) == NEXT then Panel.tick(true) end
end

return Panel
