-- Laderaum geparkter Züge neu messen: Tankwagen zählten bis 0.0.26 immer mit normaler Qualität (legendär = 2,5-fach).
-- Gemessen wird sonst erst beim nächsten Einparken; diese Migration läuft einmal je Spielstand.
local trains = storage.trains
if not (trains and trains.by_id) then return end
for _, record in pairs(trains.by_id) do
  local train = record.train
  if train and train.valid and record.fluid then
    local fluid = 0
    for _, wagon in pairs(train.fluid_wagons) do
      fluid = fluid + wagon.prototype.get_fluid_capacity(wagon.quality)
    end
    record.fluid = fluid
  end
end
