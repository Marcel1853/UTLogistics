# Unified Train Logistics (UTL)

[![Factorio](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2FMarcel1853%2FUTLogistics%2Fmain%2Finfo.json&query=%24.factorio_version&label=Factorio&color=green)](https://factorio.com)
[![Version](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2FMarcel1853%2FUTLogistics%2Fmain%2Finfo.json&query=%24.version&label=version&color=orange)](https://mods.factorio.com/mod/UTLogistics)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://github.com/Marcel1853/UTLogistics/blob/main/LICENSE)

A train dispatcher for Factorio 2.1. You tell your stations what they have and what they need, and
UTL sends empty trains from the depot to pick it up and drop it off. Fuel stops, cleanup of leftover
cargo and an overview window are built in, so you need only this one mod.

*Deutsch: [README-de.md](https://github.com/Marcel1853/UTLogistics/blob/main/README-de.md)*

**The [wiki](https://github.com/Marcel1853/UTLogistics/wiki) explains everything with pictures.** This page is the short version.

- Needs Factorio 2.1 and [flib](https://mods.factorio.com/mod/flib). Space Age is optional.
- Languages: English and German. Russian, Chinese, French, Spanish, Polish and Brazilian Portuguese are
  AI translations – corrections are welcome on GitHub.
- Research **“Unified Train Logistics”** to start. Extras come with later research. If you don't want
  to research anything, turn off the map setting “UTL features need research”.

## Quick start

1. Build a **UTL train stop** and tick **Depot**. This is where empty trains wait.
2. Give a train a schedule with only that depot stop and set it to automatic. The train must be empty.
3. Build a second UTL train stop, tick **Provider** and connect a chest to the stop with a red or green
   wire. Inserters load the train.
4. Build a third one, tick **Requester**, click a request slot and enter what you want, e.g. 8000 iron
   plates. Inserters unload the train.

That's it. When the requester runs low, a train drives depot → provider → requester → depot.

Shift + right-click a station and Shift + left-click another to copy the settings. Blueprints and
Ctrl + C / Ctrl + V keep them too.

## Stations

You can use a **UTL train stop** (replaces the normal one, you can build it on top) or put a **UTL
station combinator** next to a normal train stop and wire its output to the stop. Both work the same
and need no power.

Each station gets a role:

- **Provider** – offers what is in its chests (positive signals).
- **Requester** – asks for goods. The amount is the stock you want to have, not the amount per train:
  UTL only brings what is missing, minus what is already on the way.
- **Provider and requester** at once – a buffer.
- **Active provider** – gets emptied even if nobody asks: first to requesters, then to storages,
  the rest to cleanup.
- **Depot** – empty trains wait here.
- **Fuel station** – trains go here when a locomotive drops below 40 %.
- **Cleanup** – trains that still have cargo get emptied here.
- **Storage** – keeps a stock between a minimum and a maximum: below the minimum it requests, above it
  it offers.

Per station you can set train length, max. trains, thresholds and priorities. Number fields accept
math like `4000*2`.

## Networks

Every station has a network name. Stations only work with others of the same name, so you can run
separate systems on one map, each with its own depots. Leave the field empty and everything is in one
network.

With research you can link networks so they share trains, depots, fuel and cleanup stations.
[Wiki – Networks](https://github.com/Marcel1853/UTLogistics/wiki/Networks)

## How trains run

- UTL doesn't replace your schedule. Provider and requester are added as temporary stops and removed
  after the train leaves. Train groups and interrupts keep working.
- The train waits at the provider until the order is loaded and at the requester until it is empty.
- One train can carry several items. Fluids work too (one fluid per trip).
- UTL picks a free train that fits the most in one trip and is close by, and checks that it can reach
  both stations.
- Requests with the same priority are served oldest first.
- The vanilla train limit of the stop still counts.

Trains low on fuel visit the nearest fuel station first. If there is none, they keep driving until 10 %
and then stay in the depot with an alert. Trains with leftover cargo go to a cleanup station. A cleanup
can offer its contents again, like a provider.
[Wiki – Fuel, cleanup and depots](https://github.com/Marcel1853/UTLogistics/wiki/Fuel-cleanup-and-depots)

## Mixed chests

A provider can keep several goods in one chest. During a delivery UTL sets the wagon filters to the
ordered goods, so a plain inserter loads only those. Next to every stop there is a small **order
output** with the current job as signals – use it for filter inserters, pumps or lamps.
[Wiki – Mixed providers and job output](https://github.com/Marcel1853/UTLogistics/wiki/Mixed-providers-and-job-output)

## UTL Manager

Open it with the locomotive button in the shortcut bar or Ctrl + Shift + U. It shows depots, stations,
networks, what is in stock, the last 100 deliveries, statistics and alerts. Click a station to see it
on the map, click a train to follow it.

The small button next to the magnifier filters everything by one item or fluid. Right-click it to clear.

![UTL Manager filtered by copper plate: only the two stations with copper plates are listed](https://raw.githubusercontent.com/wiki/Marcel1853/UTLogistics/images/utl-manager-ware-filter.png)

UTL also uses normal Factorio alerts: no train available, leftover cargo, train stuck and so on. Each
can be turned off.
[Wiki – UTL Manager and alerts](https://github.com/Marcel1853/UTLogistics/wiki/UTL-Manager-and-alerts)

## Status display

Wire a normal display panel to a UTL station and it shows what is going on: blue = train on the way,
green = train at the stop, cyan = train waiting in the depot, yellow = nothing to do, red = stop
disabled. Above it you see the train number and its cargo.

![Display panels at UTL stations in the five colors](https://raw.githubusercontent.com/wiki/Marcel1853/UTLogistics/images/utl-status-display.png)

## Train stop look

UTL train stops look like normal ones by default. In the startup settings you can switch to the UTL
look: a lattice mast with a control cabinet and cables. You can switch back any time.

![The UTL look of the train stop in all four directions](https://raw.githubusercontent.com/wiki/Marcel1853/UTLogistics/images/utl-stop-look.png)

## More features

- **Blueprints with parameters** – goods, amounts and role can be asked when you place a blueprint.
  The UTL parameter planner in the shortcut bar makes this easy.
- **Network combinator** – puts the state of a network on the circuit network: stock, demand,
  shortage, trains.
- **Teams and planets** are kept apart. Every planet needs its own depots and trains.
- **Top up while loading** (off by default) – if the requester needs more while the train is still
  loading, it is added to the same trip.
- **Second provider** (off by default) – if one provider doesn't have enough, the train picks up the
  rest at a second one on the way.
- **Next job right away** – after unloading, a train can take the next job without going back to the
  depot first.

All settings: [Wiki – Settings](https://github.com/Marcel1853/UTLogistics/wiki/Settings)

## Other mods

- **[Cargo Ships](https://mods.factorio.com/mod/cargo-ships):** ports become UTL stations and ships
  deliver like trains. A shortcut button turns a rail blueprint into a waterway blueprint.
- **[Space Exploration](https://mods.factorio.com/mod/space-exploration):** trains can deliver
  through the space elevator between a planet and its orbit.
  [Wiki – Space elevator](https://github.com/Marcel1853/UTLogistics/wiki/Space-elevator)
- **Mod authors:** there is a remote interface, events and an add-on API.
  [Wiki – For mod authors](https://github.com/Marcel1853/UTLogistics/wiki/For-mod-authors)

## Performance

UTL does its work in small steps and only looks at stations that changed. In the load test (384 trains,
880 stations, no factory around it) UTL needs about 0.24 ms per tick on average. Most of the time goes
to the game's own train movement and pathfinding.

## Learn it in the game

- **Scenarios** (New game → Scenarios): small examples you can watch, plus the load test.
  [Wiki – Scenarios and tips](https://github.com/Marcel1853/UTLogistics/wiki/Scenarios-and-tips)
- **Tips & tricks** has a UTL category with seventeen short scenes.
- After an update, one line in the chat says what is new.
- Questions: [Wiki – FAQ](https://github.com/Marcel1853/UTLogistics/wiki/FAQ-and-troubleshooting) or the
  [discussion](https://mods.factorio.com/mod/UTLogistics/discussion).

## How UTL is made

I'm Marcel. UTL is written with AI (Claude by Anthropic) – the code and most of the texts. I decide what
it should do and test every version myself in my own saves before it goes online. There are also
automated tests in [`tools/`](https://github.com/Marcel1853/UTLogistics/tree/main/tools). I play and
test on a Ryzen 7 5700G with no graphics card.

Bug reports and ideas help a lot – post them in the
[discussion](https://mods.factorio.com/mod/UTLogistics/discussion).

## License

[Apache License 2.0](https://github.com/Marcel1853/UTLogistics/blob/main/LICENSE). You may use and
change UTL, also in your own mods, as long as you keep `LICENSE` and `NOTICE` and link to
[github.com/Marcel1853/UTLogistics](https://github.com/Marcel1853/UTLogistics).
