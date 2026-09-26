-- Runtime-Einstieg: nur verdrahten, die Logik liegt in scripts/.
local Events = require("scripts.core.events")

require("scripts.stations.init")
require("scripts.trains.init")
require("scripts.dispatcher.init")
require("scripts.inserters.init")
require("scripts.gui.station.init")
require("scripts.gui.manager.init")
require("scripts.gui.admin.init")
require("scripts.commands.init")
require("scripts.api.remote")

Events.register()
