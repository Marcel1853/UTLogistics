--- Szenario „UTL-Nachladen“: Aufbau und alles, was in der Welt zu sehen ist.
--- Ein City Block mit Depot (1 Zug, 2 Wagen), Anbieter (Eisen) und Abnehmer. Dazu Anzeigefelder
--- mit Erklärung und schwebende Texte: über dem Zug seine Ladeliste, über dem Abnehmer sein Bedarf.
---
--- Am Abnehmer stehen **Eisenkisten** (man sieht, was ankommt). Dahinter leert eine Schaltung die
--- Kisten in eine Vernichtungs-Kiste – aber erst, wenn keine Runde läuft und seit 20 s Ware darin
--- liegt: Zähler (Entscheider mit Rückkopplung) zählt, solange Eisen in den Kisten ist und das
--- Signal R (Runde läuft) 0 ist; ab T > 1200 arbeiten die Leer-Greifarme.
local Builder = require("__UTLogistics__/scenarios/UTL-Lasttest/builder")
local Signs = require("__UTLogistics__/scripts/lib/signs")

local World = {}

local W = defines.wire_connector_id
World.EMPTY_DELAY = 20 * 60 -- so lange nach der Runde bleibt die Ware sichtbar in den Kisten

World.SURFACE = "utl-nachladen"
World.KEY = "item|iron-plate|normal"

local STATIONS = {
  { kind = "depot", name = "Depot", network = "Demo", cars = 2 },
  { kind = "provider", name = "Anbieter", network = "Demo", item = "iron-plate" },
  { kind = "requester", name = "Abnehmer", network = "Demo", item = "iron-plate" },
}

--- Die drei Stationen gleichmäßig über die Plätze des Blocks verteilen.
local function assign(places)
  local specs = {}
  local step = math.max(1, math.floor(#places / #STATIONS))
  for i, spec in ipairs(STATIONS) do specs[1 + (i - 1) * step] = spec end
  return specs
end

-- Rechtsvektor je Fahrtrichtung der Haltestelle (Anzeigefeld zwischen Nebengleis und Hauptgleis)
local RIGHT = { [0] = { 1, 0 }, [4] = { 0, 1 }, [8] = { -1, 0 }, [12] = { 0, -1 } }

local function sign(stop, key)
  local r = RIGHT[stop.direction] or RIGHT[0]
  Signs.place(stop.surface, { stop.position.x - 5 * r[1], stop.position.y - 5 * r[2] }, key,
    { type = "item", name = "iron-plate" })
end

--- Schwebender Text, der `target` folgt (Entity oder Position).
local function label(surface, target, text, color)
  return rendering.draw_text({
    text = text, surface = surface, target = target, color = color or { 1, 1, 1 },
    scale = 3, font = "default-large-bold", alignment = "center", vertical_alignment = "bottom",
    -- wächst und schrumpft mit der Welt: in der kleinen Kamera im Fenster bleibt er klein
    use_rich_text = true, scale_with_zoom = false,
  })
end

local function signal(name) return { type = "virtual", name = name } end

--- Freier Platz für `name` nahe `near` (oder nil).
local function place(surface, name, near, extra)
  local position = surface.find_non_colliding_position(name, near, 8, 0.5)
  if not position then return nil end
  local spec = extra or {}
  spec.name, spec.position, spec.force = name, position, "player"
  return surface.create_entity(spec)
end

--- Abnehmer: Vernichtungs-Kisten des Baukastens durch Eisenkisten ersetzen, dahinter je ein
--- Greifarm in eine Vernichtungs-Kiste, dazu die Zeitschaltung. Liefert Kisten und Schalter „R“.
local function rebuild_requester(surface, stop)
  local p = stop.position
  local old = {}
  for _, chest in pairs(surface.find_entities_filtered({ name = "infinity-chest",
    area = { { p.x - 40, p.y - 40 }, { p.x + 40, p.y + 40 } } })) do
    if chest.remove_unfiltered_items then old[#old + 1] = chest end -- nur die des Abnehmers
  end
  local chests, voids = {}, {}
  for _, chest in ipairs(old) do
    local pos = chest.position
    local feeder = surface.find_entities_filtered({ type = "inserter", position = pos, radius = 1.2 })[1]
    -- Leitungen nach außen (Haltestelle bzw. Combinator) merken, bevor die Kiste weg ist
    local outside = {}
    for _, conn in pairs(chest.get_wire_connector(W.circuit_green, true).connections) do
      if conn.target.owner.name ~= "infinity-chest" then outside[#outside + 1] = conn.target end
    end
    chest.destroy()
    local new = surface.create_entity({ name = "iron-chest", position = pos, force = "player" })
    if new then
      for _, target in ipairs(outside) do new.get_wire_connector(W.circuit_green, true).connect_to(target) end
      chests[#chests + 1] = new
      if feeder then
        -- Richtung Gleis → Kiste; der Leer-Greifarm sitzt eine Kachel weiter außen
        local r = { pos.x - feeder.position.x, pos.y - feeder.position.y }
        local ins = surface.create_entity({ name = "bulk-inserter", position = { pos.x + r[1], pos.y + r[2] },
          direction = feeder.direction, force = "player" })
        local void = surface.create_entity({ name = "infinity-chest", position = { pos.x + 2 * r[1], pos.y + 2 * r[2] },
          force = "player" })
        if void then void.remove_unfiltered_items = true end
        if ins then
          local cb = ins.get_or_create_control_behavior() --[[@as LuaInserterControlBehavior]]
          cb.circuit_enable_disable = true
          cb.circuit_condition = { first_signal = signal("signal-T"), comparator = ">", constant = World.EMPTY_DELAY }
          voids[#voids + 1] = ins
        end
      end
    end
  end
  -- Kisten untereinander verbinden (grün): so liest die Station alle zusammen
  table.sort(chests, function(a, b)
    if a.position.x ~= b.position.x then return a.position.x < b.position.x end
    return a.position.y < b.position.y
  end)
  for i = 2, #chests do
    chests[i - 1].get_wire_connector(W.circuit_green, true).connect_to(chests[i].get_wire_connector(W.circuit_green, true))
  end
  if #chests == 0 or #voids == 0 then return chests, nil end

  -- Zeitschaltung hinter der letzten Kiste
  local last = chests[#chests].position
  local away = { voids[#voids].position.x - last.x, voids[#voids].position.y - last.y }
  local base = { last.x + 4 * away[1], last.y + 4 * away[2] }
  local counter = place(surface, "decider-combinator", base)
  local one = place(surface, "constant-combinator", base)
  local round = place(surface, "constant-combinator", base)
  if not (counter and one and round) then return chests, nil end
  one.get_control_behavior().get_section(1).set_slot(1, { value = { type = "virtual", name = "signal-T", quality = "normal" }, min = 1 })
  round.get_control_behavior().get_section(1).set_slot(1, { value = { type = "virtual", name = "signal-R", quality = "normal" }, min = 1 })
  local dcb = counter.get_control_behavior() --[[@as LuaDeciderCombinatorControlBehavior]]
  dcb.parameters = {
    conditions = {
      { first_signal = { type = "item", name = "iron-plate" }, comparator = ">", constant = 0,
        first_signal_networks = { red = false, green = true } },
      { first_signal = signal("signal-R"), comparator = "=", constant = 0, compare_type = "and",
        first_signal_networks = { red = true, green = false } },
    },
    outputs = { { signal = signal("signal-T"), copy_count_from_input = true, networks = { red = true, green = false } } },
  }
  local input_red = counter.get_wire_connector(W.combinator_input_red, true)
  local output_red = counter.get_wire_connector(W.combinator_output_red, true)
  counter.get_wire_connector(W.combinator_input_green, true).connect_to(chests[#chests].get_wire_connector(W.circuit_green, true))
  one.get_wire_connector(W.circuit_red, true).connect_to(input_red)
  round.get_wire_connector(W.circuit_red, true).connect_to(input_red)
  output_red.connect_to(input_red) -- Rückkopplung: zählt jeden Tick um 1 hoch
  -- Leer-Greifarme in einer Kette an den Zähler (nächster zuerst)
  table.sort(voids, function(a, b)
    local da = (a.position.x - counter.position.x) ^ 2 + (a.position.y - counter.position.y) ^ 2
    local db = (b.position.x - counter.position.x) ^ 2 + (b.position.y - counter.position.y) ^ 2
    return da < db
  end)
  local previous = output_red
  for _, ins in ipairs(voids) do
    local connector = ins.get_wire_connector(W.circuit_red, true)
    previous.connect_to(connector)
    previous = connector
  end
  Signs.place(surface, { base[1] + 3 * away[1], base[2] + 3 * away[2] }, "demo-circuit",
    { type = "virtual", name = "signal-T" })
  return chests, round.get_control_behavior()
end

--- Alles bauen und einstellen. Liefert die Teile, die der Ablauf braucht.
function World.build()
  local built = Builder.build({ surface = World.SURFACE, grid = 1, depots = {}, assign = assign })
  local result = { surface = built.surface, area = built.areas[1] }
  for _, spec in ipairs(built.stations) do
    local unit = (spec.combinator_entity or spec.stop).unit_number
    if spec.kind == "depot" then
      remote.call("utl", "configure_station", unit, { mode = "depot", network = "Demo" })
      sign(spec.stop, "demo-depot")
      result.depot = spec.stop
    elseif spec.kind == "provider" then
      remote.call("utl", "configure_station", unit,
        { mode = "station", provide = true, request = false, network = "Demo" })
      sign(spec.stop, "demo-provider")
      result.provider = spec.stop
    elseif spec.kind == "requester" then
      remote.call("utl", "configure_station", unit,
        { mode = "station", provide = false, request = true, network = "Demo", request_threshold = 100, max_trains = 1 })
      sign(spec.stop, "demo-requester")
      result.requester, result.requester_unit = spec.stop, unit
      result.chests, result.round_switch = rebuild_requester(result.surface, spec.stop)
    end
  end
  local train = built.trains[1]
  result.locomotive = train and train.front_stock
  -- schwebende Texte: über der Lok die Ladeliste, über dem Abnehmer der Bedarf
  if result.locomotive then
    result.train_label = label(result.surface, { entity = result.locomotive, offset = { 0, -3 } },
      { "utl-demo.train-idle" })
  end
  result.need_label = label(result.surface, { entity = result.requester, offset = { 0, -3 } },
    { "utl-demo.need", 0 })
  return result
end

--- Eisen in den Kisten des Abnehmers.
function World.stock(chests)
  local n = 0
  for _, chest in pairs(chests or {}) do
    if chest.valid then n = n + chest.get_item_count("iron-plate") end
  end
  return n
end

--- Signal „Runde läuft“ an/aus (solange es an ist, bleiben die Kisten voll).
function World.set_round(switch, running)
  if switch and switch.valid then switch.enabled = running end
end

return World
