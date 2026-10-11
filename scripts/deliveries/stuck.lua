--- Hänger-Erkennung (Kartenwert „utl-stuck-minutes“, Standard 5, 0 = aus): Steht ein Lieferzug
--- länger als so viele Minuten ohne Fortschritt – wartet an einem Signal, findet keinen Weg, Ziel
--- voll –, kommt die Warnung „Zug steckt fest“ (Gruppe „train“) und der Manager zeigt es an.
--- Nur melden, nie abbrechen.
---
--- Ausnahme: verwaiste Lieferungen. Hat ein Lieferzug seit mindestens einer Minute keinen
--- Zustandswechsel und keinen einzigen UTL-Halt mehr im Fahrplan (von Hand oder von einem anderen
--- Mod geleert), fährt er nie mehr hin – die Lieferung würde den Bedarf des Abnehmers für immer
--- blockieren. Dann wird sie abgebrochen („Fahrplan verloren“).
---
--- Fortschritt = jeder Zustandswechsel des Zugs (on_train_changed_state, kein Polling):
--- `delivery.progress` = Tick. Geprüft wird reihum im Heartbeat mit festem Budget (Regel 5).
local Alerts = require("scripts.alerts.alerts")
local Deliveries = require("scripts.deliveries.deliveries")
local Rekey = require("scripts.trains.rekey")
local Held = require("scripts.trains.held")
local Depot = require("scripts.trains.depot")
local Log = require("scripts.lib.log")

local Stuck = {}

local S = defines.train_state
local WAITING = {
  [S.wait_signal] = true, [S.arrive_signal] = true, [S.no_path] = true, [S.destination_full] = true,
}
local BUDGET = 50
local ORPHAN_TICKS = 3600 -- erst nach einer Minute ohne Zustandswechsel den Fahrplan ansehen

--- Fahrplan als kurzer Text fürs Protokoll; liefert außerdem, ob noch ein UTL-Halt drinsteht
--- (temporär und nicht von einer Unterbrechung).
local function utl_records(train)
  local schedule = train.get_schedule()
  local records = schedule and schedule.get_records()
  if not records then return false, "(kein Fahrplan)" end
  local found, names = false, {}
  for i, record in ipairs(records) do
    if record.temporary and not record.created_by_interrupt then found = true end
    if i <= 10 then
      names[#names + 1] = (record.station or (record.rail and "Gleis") or "?") .. (record.temporary and "*" or "")
    end
  end
  return found, table.concat(names, ", ")
end

--- Lieferung ohne UTL-Halt im Fahrplan abbrechen (liefert dann true). Steht der Zug schon im Depot,
--- ist er danach frei.
local function cancel_if_orphan(delivery, train)
  local found, schedule_text = utl_records(train)
  if found then return false end
  Log.info("Lieferung " .. delivery.id .. ": Zug " .. train.id .. " hat keinen UTL-Halt mehr im Fahrplan ("
    .. schedule_text .. "), steht an " .. Log.stop_name(train.station) .. " – Lieferung wird abgebrochen.")
  Deliveries.cancel(delivery, "schedule-lost")
  if train.valid and not storage.trains.service[train.id] then
    local stop = train.station
    if stop and stop.valid then Depot.scan_stop(stop) end
  end
  return true
end

--- Zustandswechsel eines Lieferzugs: Uhr neu stellen.
function Stuck.progress(delivery)
  delivery.progress = game.tick
  delivery.stuck = nil
end

--- Heartbeat-Aufgabe: einige Lieferungen prüfen (reihum). Nebenbei (immer, auch mit Warnung aus):
--- Lieferungen, deren Zug ohne Umbau-Ereignis verschwunden ist (Oberfläche gelöscht, Script-
--- `destroy`), abbrechen – sonst blieben ihre Reservierungen für immer stehen.
function Stuck.check()
  local minutes = storage.cfg.stuck_minutes or 0
  local limit = minutes > 0 and minutes * 3600 or nil
  local deliveries = storage.deliveries
  local active = deliveries.active
  local id = deliveries.stuck_cursor
  if id and not active[id] then id = nil end
  for _ = 1, BUDGET do
    id = next(active, id)
    if not id then break end
    local delivery = active[id]
    local train = delivery.train
    -- Lieferungen aus älteren Spielständen haben noch keine Uhr: ab jetzt zählen
    if not delivery.progress then delivery.progress = game.tick end
    if not (train and train.valid) then
      if not Rekey.protected(delivery.train_id) then Deliveries.cancel(delivery, "rebuilt") end
    elseif not train.manual_mode and not Held.is(train.id) and game.tick - delivery.progress >= ORPHAN_TICKS
      and not Rekey.protected(delivery.train_id) and cancel_if_orphan(delivery, train) then
      -- abgebrochen, Lieferung ist weg
    elseif limit and not Held.is(train.id) and WAITING[train.state] and game.tick - delivery.progress >= limit then
      delivery.stuck = true
      local loading = delivery.state == "to_provider" or delivery.state == "loading"
      Alerts.raise("train", "stuck", train.front_stock, { "utl-alert.stuck", Alerts.train_name(train),
        math.floor((game.tick - delivery.progress) / 3600), (loading and delivery.from or delivery.to) or "?" },
        "stuck:" .. id)
    end
  end
  deliveries.stuck_cursor = id
end

--- Minuten ohne Fortschritt, wenn der Zug als festgefahren gilt, sonst nil (für den Manager).
function Stuck.minutes(delivery)
  if not (delivery.stuck and delivery.progress) then return nil end
  return math.floor((game.tick - delivery.progress) / 3600)
end

return Stuck
