-- Szenen zum UTL-Manager: alle Reiter nacheinander und das Inventar mit angeklickter Ware.
local P = require("__UTLogistics__/prototypes/tips/scenes/common")

local function manager(tab, select)
  local arg = select and (", { ware = \"" .. select .. "\" }") or ""
  return "function() remote.call(\"utl\", \"open_manager\", player.index, \"" .. tab .. "\"" .. arg .. ") end"
end

local SIGN = [[
sign(-3, 6, "manager-open", { type = "item", name = "locomotive" })
]]

-- Beispiel-Warnung: Der Zug kommt mit Restladung ins Depot, ein Cleanup gibt es nicht → Warnung
-- „Restladung, kein Cleanup“ im Reiter „Alarme“. Danach wird der Wagen geleert (als hätte man ihn
-- ausgeräumt), und der Zug fährt normal. Ohne Simulation (tools/tipstest) keine Restladung, damit
-- der Test Lieferungen sieht.
local ALERT = [[
local alert_train = train(-8, 150)
if game.simulation then alert_train.cargo_wagons[1].insert({ name = "copper-plate", count = 100 }) end
function empty_wagon()
  if alert_train.valid then alert_train.cargo_wagons[1].get_inventory(defines.inventory.cargo_wagon).clear() end
end
]]

return {
  -- Reiter nacheinander, am Ende die Beispiel-Warnung im Reiter „Alarme“
  manager = P.scene({ P.SIMPLE, SIGN, ALERT, "show({\n"
    .. "  { 3, empty_wagon },\n"
    .. "  { 1, " .. manager("depots") .. " },\n"
    .. "  { 4, " .. manager("stations") .. " },\n"
    .. "  { 4, " .. manager("networks") .. " },\n"
    .. "  { 4, " .. manager("inventory") .. " },\n"
    .. "  { 4, " .. manager("history") .. " },\n"
    .. "  { 4, " .. manager("alerts") .. " },\n"
    .. "  { 6, close },\n})\n" }),
  -- Inventar: zwei Waren; ein Klick auf eine Ware zeigt rechts Summen, Stationen und Züge
  manager_inventory = P.scene({ P.REQUESTS, SIGN, "train(-8, 150)", "show({\n"
    .. "  { 3, " .. manager("inventory") .. " },\n"
    .. "  { 3, " .. manager("inventory", "item|iron-plate|normal") .. " },\n"
    .. "  { 5, " .. manager("inventory", "item|copper-plate|normal") .. " },\n"
    .. "  { 5, close },\n})\n" }),
}
