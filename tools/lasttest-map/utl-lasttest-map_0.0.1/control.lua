--- Baut nur das Gleisnetz des Szenarios „UTL-Lasttest“ (Gleise und Signale), damit
--- tools/lasttest-map.sh es als Karte (blueprint.zip) ins Szenario übernehmen kann.
local Builder = require("__UTLogistics__/scenarios/UTL-Lasttest/builder")
local Lasttest = require("__UTLogistics__/scenarios/UTL-Lasttest/lasttest")

script.on_init(function()
  local cfg = {}
  for k, v in pairs(Lasttest.CFG) do cfg[k] = v end
  cfg.mode = "track"
  local built = Builder.build(cfg)
  local s = built.stats
  log(("[MAP] Gleisnetz: %d Blöcke, Gleise %d (%d fehlgeschlagen), Signale %d (%d fehlgeschlagen), %d Signale für längere Blöcke entfernt")
    :format(s.blocks, s.rails, s.failed, s.signals, s.signals_failed, s.signals_merged or 0))
end)
