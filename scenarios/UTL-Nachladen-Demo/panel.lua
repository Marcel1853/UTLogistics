--- Szenario „UTL-Nachladen“: füttert das gemeinsame Erklärfenster (scripts/lib/explain-panel.lua)
--- mit dem Stand der Runde – Schritte, Kamera am Zug, Ladeliste und Zähler.
local Explain = require("__UTLogistics__/scripts/lib/explain-panel")

local Panel = {}

local NAME = "utl_demo_panel"
Panel.MODE_ACTION = "mode"

-- Schritte je Modus (Locale utl-demo.step-…); 4 und 5 unterscheiden sich
local STEPS = {
  on = { "step-1", "step-2", "step-3", "step-4-on", "step-5-on", "step-6" },
  off = { "step-1", "step-2", "step-3", "step-4-off", "step-5-off", "step-6" },
}

local MODE_CAPTION = { alternate = "mode-alternate", on = "mode-on", off = "mode-off" }

--- Fenster für einen Spieler anlegen (vorhandenes wird ersetzt).
function Panel.create(player)
  Explain.create(player, {
    name = NAME,
    title = { "utl-demo.title" },
    intro = { "utl-demo.intro" },
    button = { action = Panel.MODE_ACTION, tooltip = { "utl-demo.mode-tooltip" } },
  })
  Panel.refresh(player)
end

--- Inhalt auffrischen (einmal pro Sekunde, nur Texte).
function Panel.refresh(player)
  local demo = storage.demo or {}
  local steps = {}
  for i, key in ipairs(STEPS[demo.round_on and "on" or "off"]) do
    steps[i] = { "utl-demo." .. key, demo.rest or 2000 }
  end
  local st = demo.stats or {}
  Explain.update(player, NAME, {
    headline = { "utl-demo.round", demo.round or 0, { demo.round_on and "utl-demo.on" or "utl-demo.off" } },
    button = { "utl-demo." .. MODE_CAPTION[demo.mode or "alternate"] },
    steps = steps,
    current = demo.step or 0,
    follow = demo.locomotive,
    big = demo.cargo and { "utl-demo.cargo", demo.cargo } or { "utl-demo.cargo-none" },
    note = { "utl-demo.stats", st.on_rounds or 0, st.on_trips or 0, st.off_rounds or 0, st.off_trips or 0 },
  })
end

function Panel.refresh_all()
  for _, player in pairs(game.connected_players) do Panel.refresh(player) end
end

--- Klick auswerten; liefert true, wenn der Modus-Knopf gedrückt wurde.
function Panel.on_click(event)
  return Explain.on_click(event) == Panel.MODE_ACTION
end

return Panel
