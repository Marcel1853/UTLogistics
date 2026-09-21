--- Stationsfenster im Aufbau von LTN Combinator Modernized:
---   links:  Status, Vorschau, Netzwerk, Rollen, Mengen-Editor, Anforderungs-Slots, Live-Waren
---   rechts: Abschnitte Allgemein / Anbieter / Abnehmer / Depot mit Symbol-Zeilen
--- UTL-Combinator:  eigenes Fenster, beide Kästen nebeneinander.
--- UTL-Haltestelle: Panel links am Vanilla-Haltestellenfenster (rechts sitzt das Schaltungs-Panel), Kästen untereinander,
---                  ohne Vorschau (die zeigt Vanilla schon).
local C = require("scripts.core.constants")
local Builder = require("scripts.gui.common.builder")
local Main = require("scripts.gui.station.panel-main")
local Values = require("scripts.gui.station.panel-values")
local RequestsSection = require("scripts.gui.station.section-requests")
local Goods = require("scripts.gui.station.section-goods")
local CleanupSection = require("scripts.gui.station.section-cleanup")
local Registry = require("scripts.stations.registry")
local Fields = require("scripts.stations.fields")

local Window = {}

local NAME = "utl_station_window"
-- Bei jedem Umbau des Fensters erhöhen: offene Fenster aus alten Spielständen werden dann
-- geschlossen statt mit falschem Aufbau aufgefrischt.
local GUI_VERSION = 10 -- 9: Netzwerk-Abschnitt, 8: Ladefilter-Schalter – beides zusammen
-- Breiten passend zum Inhalt (Kasten-Innenrand 2 × 12 px):
local LEFT_WIDTH = 10 * 40 + 24 -- 10 Slots
local RIGHT_WIDTH = 380         -- Reset 20 + Symbol 32 + Beschriftung 190 + Feld 80 + Ränder

function Window.is_window(element)
  return element and element.valid and element.name == NAME
end

function Window.close(player_index)
  local gui = storage.guis[player_index]
  storage.guis[player_index] = nil
  if gui and gui.frame and gui.frame.valid then gui.frame.destroy() end
end

--- Alle UTL-Fenster schließen (nach Mod-Update); auch verwaiste ohne storage-Eintrag.
function Window.close_all()
  for player_index in pairs(storage.guis) do Window.close(player_index) end
  for _, player in pairs(game.players) do
    for _, root in ipairs({ player.gui.screen, player.gui.relative }) do
      local frame = root[NAME]
      if frame then frame.destroy() end
    end
  end
end

--- `standalone`: Haltestellen-Panel als eigenes Fenster statt am Vanilla-Haltestellenfenster (Tipps-
--- Szenen: dort schöbe das Schaltungsfenster der Haltestelle das Panel aus dem Bild).
local function create_frame(player, station, standalone)
  if station.kind == "stop" and not standalone then
    return player.gui.relative.add({
      type = "frame",
      name = NAME,
      direction = "vertical",
      caption = { "utl-gui.station-title" },
      anchor = {
        gui = defines.relative_gui_type.train_stop_gui,
        position = defines.relative_gui_position.left, -- links: rechts sitzt das Schaltungs-Panel
        name = C.train_stop,
      },
    })
  end
  local frame = player.gui.screen.add({ type = "frame", name = NAME, direction = "vertical" })
  frame.auto_center = true
  Builder.titlebar(frame, { "utl-gui.station-title" }, "close")
  return frame
end

local function box(parent, width)
  local frame = parent.add({ type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical" })
  frame.style.width = width
  frame.style.vertically_stretchable = true
  local flow = frame.add({ type = "flow", direction = "vertical" })
  flow.style.vertical_spacing = 6
  return flow
end

function Window.open(player, station, standalone)
  Window.close(player.index)
  -- Reste alter Fenster/Panels ohne storage-Eintrag (z. B. aus älteren Spielständen).
  for _, root in ipairs({ player.gui.screen, player.gui.relative }) do
    local old = root[NAME]
    if old then old.destroy() end
  end

  Fields.fill(station.config) -- fehlende Werte älterer Stationen ergänzen
  local is_stop = station.kind == "stop"
  local frame = create_frame(player, station, standalone)
  local left_parent, right_parent, tabs
  if is_stop then
    -- Panel an der Haltestelle: zwei Reiter statt alles untereinander (passt auf den Bildschirm).
    tabs = frame.add({ type = "tabbed-pane" })
    local tab_station = tabs.add({ type = "tab", caption = { "utl-gui.tab-station" } })
    local tab_values = tabs.add({ type = "tab", caption = { "utl-gui.tab-values" } })
    left_parent = tabs.add({ type = "flow", direction = "vertical" })
    right_parent = tabs.add({ type = "flow", direction = "vertical" })
    tabs.add_tab(tab_station, left_parent)
    tabs.add_tab(tab_values, right_parent)
    tabs.selected_tab_index = 1
  else
    local boxes = frame.add({ type = "flow", direction = "horizontal" })
    boxes.style.horizontal_spacing = 12
    left_parent, right_parent = boxes, boxes
  end

  local left = box(left_parent, LEFT_WIDTH)
  local main = Main.build(left, station, not is_stop)
  left.add({ type = "line" })
  local requests = RequestsSection.build(left, station)
  local goods = Goods.build(left, station)

  local right = box(right_parent, is_stop and LEFT_WIDTH or RIGHT_WIDTH)
  Values.build(right, station)
  CleanupSection.build(right, station)

  -- Beim Combinator ersetzt unser Fenster das Vanilla-Fenster.
  if standalone or not is_stop then player.opened = frame end
  storage.guis[player.index] = {
    version = GUI_VERSION, frame = frame, unit = station.unit, main = main, requests = requests, goods = goods,
    tabs = tabs, standalone = standalone,
  }
  Window.refresh(player.index)
end

--- Aktualisiert Status und Live-Waren. Schließt das Fenster, wenn die Station weg ist.
function Window.refresh(player_index)
  local gui = storage.guis[player_index]
  if not gui then return end
  if gui.version ~= GUI_VERSION then -- Fenster aus älterer Mod-Fassung
    Window.close(player_index)
    return
  end
  local station = Registry.get(gui.unit)
  if not (station and station.entity.valid and gui.frame.valid) then
    Window.close(player_index)
    return
  end
  Main.refresh(gui.main, station)
  Goods.refresh(gui.goods, station)
end

--- Heartbeat-Aufgabe: nur offene Fenster auffrischen.
function Window.refresh_all()
  for player_index in pairs(storage.guis) do
    Window.refresh(player_index)
  end
end

--- Reiter des Haltestellen-Panels wählen (1 = Station, 2 = Werte); der Combinator hat keine Reiter.
function Window.select_tab(player_index, index)
  local gui = Window.get(player_index)
  if gui and gui.tabs and gui.tabs.valid then gui.tabs.selected_tab_index = index end
end

function Window.get(player_index)
  local gui = storage.guis[player_index]
  if gui and gui.version == GUI_VERSION then return gui end
  return nil
end

--- Station des offenen Fensters eines Spielers.
function Window.station_of(player_index)
  local gui = Window.get(player_index)
  return gui and Registry.get(gui.unit)
end

return Window
