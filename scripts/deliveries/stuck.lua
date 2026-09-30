--- Hänger-Erkennung (Kartenwert „utl-stuck-minutes“, Standard 5, 0 = aus): Steht ein Lieferzug
--- länger als so viele Minuten ohne Fortschritt – wartet an einem Signal, findet keinen Weg, Ziel
--- voll –, kommt die Warnung „Zug steckt fest“ (Gruppe „train“) und der Manager zeigt es an.
--- Nur melden, nie abbrechen.
---
--- Fortschritt = jeder Zustandswechsel des Zugs (on_train_changed_state, kein Polling):
--- `delivery.progress` = Tick. Geprüft wird reihum im Heartbeat mit festem Budget (Regel 5).
local Alerts = require("scripts.alerts.alerts")
local Deliveries = require("scripts.deliveries.deliveries")
local Rekey = require("scripts.trains.rekey")

local Stuck = {}

local S = defines.train_state
local WAITING = {
  [S.wait_signal] = true, [S.arrive_signal] = true, [S.no_path] = true, [S.destination_full] = true,
}
local BUDGET = 50

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
      if not Rekey.in_transfer(delivery.train_id) then Deliveries.cancel(delivery, "rebuilt") end
    elseif limit and WAITING[train.state] and game.tick - delivery.progress >= limit then
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
