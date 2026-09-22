# Unified Train Logistics (UTL)

Automatic train logistics for Factorio 2.1: **providers, requesters, depots, fuel stations,
cleanup and an overview window in one mod**, built for high UPS.

*Auf Deutsch lesen: [README-de.md](https://github.com/Marcel1853/UTLogistics/blob/main/README-de.md) im GitHub-Repository.*

- Requires: Factorio 2.1, [flib](https://mods.factorio.com/mod/flib). Space Age is optional.
- Unlock: technology **“Unified Train Logistics”** (after automated rail transportation and
  circuit network). Upgrades: **“UTL: Loading control”** (wagon filters and job output) and
  **“UTL: Network links I–III”** (link a network with 1, 2 or 3 partner networks). The map
  setting “UTL features need research” turns this off – then everything is available right away.

> **Young mod, tested small.** UTL runs through an automated self test (85 checks) and a headless
> load test, and the new loading features and network links are shown in the example scenarios. In
> real games it has so far only been played on small networks. **Network links (0.0.4) are brand
> new** – errors may still show up there. If something goes wrong, please report it in the
> [discussion](https://mods.factorio.com/mod/UTLogistics/discussion) – ideally with the save and
> what you did. Keep a backup of your save before adding it to a long-running base.

## Quick start

1. **Depot:** place a **UTL train stop**, open it, tick **Depot**.
2. **Train:** schedule with **only the depot stop** (any wait condition, e.g. inactivity 5 s),
   automatic mode. The train must be **empty**.
3. **Provider:** UTL train stop, tick **Provider**, wire a chest (red or green) **to the stop**.
   Inserters load the train.
4. **Requester:** UTL train stop, tick **Requester**. Click a **request slot**, pick an item,
   enter an amount (e.g. 8000 iron plates). Inserters unload the train.
5. Done: as soon as the requester is short enough, a free train goes depot → provider →
   requester → depot.

Tip: **Shift + right-click** a configured station and **Shift + left-click** another one to
copy all UTL settings (stop ↔ stop, combinator ↔ combinator). **Blueprints** and
Ctrl + C / Ctrl + V keep the settings as well.

## Two station types, same logic

- **UTL train stop:** replaces the normal stop (can be built over it). Wires go to the stop.
  The UTL panel opens to the left of the train stop window (tabs “Station” and “Values”).
- **UTL station combinator:** belongs to a normal train stop – wire its **output** (red or green) to the stop. Chest wires go to the
  combinator input. Own window. Neither needs power.

## Roles

**Provider** (positive signals are picked up), **Requester** (negative signals or request slots
are delivered), both = buffer, **Depot** (free trains wait here), **Fuel station**,
**Cleanup** (trains with leftover cargo are emptied here). Depot, fuel station and cleanup
exclude each other and provider/requester.

## Requests are a target stock

The amount in a request slot is the **stock you want to have**. Only the difference
is delivered: *demand = target − in stock − already in transit*. A train is sent once the
demand reaches the **requester threshold**. Want several trains at once? Set a higher target.

## Values

Min./max. train length (0 = any; also for depots, see below), max. trains, supply threshold /
stack threshold, provider priority, locked slots per wagon, demand threshold / stack threshold,
requester priority. The grey ⟲ button resets a value. **Math works in every number field**:
`4000*2`, `8000/4`, `(1+2)*3`, `2^3`, `1e3`. The **network** name is explained in the next
section.

## Networks

Every station has **one network name** (field "Network" in its window). Empty means `default`.
Two stations only work together when the name is **exactly the same** – there is no numbering
and no bitmask.

This applies to **all roles**:

| Role | Effect of the network |
|---|---|
| Provider | is only offered to requesters with the same name |
| Requester | is only served from providers with the same name |
| Depot | hands its trains only to that network |
| Fuel station | a train only refuels in its own network |
| Cleanup | a train is only emptied in its own network |

Example: two separate systems on one map.

| Station | Network |
|---|---|
| Iron mine, iron smelter, depot "Ore depot" | `Ore` |
| Plate storage, plate consumers, depot "Plate depot" | `Plates` |

Ore trains never take a plate job, and each system needs **its own depot, fuel and cleanup
stations** – unless you link the networks (see below). Leave the field empty everywhere if you just
want one big network.

### Linking networks

*Needs research: “UTL: Network links I”, II and III allow 1, 2 and 3 partners per network.*

**How many networks you create is not limited** – name as many as you like. Research only limits
how many networks you can **link** with each other.

Linked networks **help each other**: trains, depots, fuel stations and cleanups of one also serve
the other. A link is a **star**:

- One network is the **center**, the networks linked to it are its **partners**.
- Center and partner help each other in **both directions**.
- **Partners do not help each other.** They only share the center.
- A network belongs to **at most one star**: a partner cannot get partners of its own and cannot be
  linked to a second center. This keeps everything clear – no chains where half the map ends up in
  one network by accident.
- Links count **per surface**. Networks on Nauvis and on Vulcanus are linked separately, even if they
  have the same name; each planet can have its own stars.

Example: an iron network as center with three partners (needs “Network links III”).

| Network | Role | helps / gets help from |
|---|---|---|
| `Iron` | center | `Copper`, `Coal`, `Stone` |
| `Copper` | partner | `Iron` only |
| `Coal` | partner | `Iron` only |
| `Stone` | partner | `Iron` only |

A free train from the iron depot takes copper, coal and stone jobs, and a copper train may take an
iron job – but a copper train never takes a coal job. `Copper`, `Coal` and `Stone` cannot be linked to
any further network while they belong to `Iron`.

This also makes a **reserve depot** easy: put a depot in its own network `Reserve`, link `Ore` and
`Plates` to it. Its trains serve both, while ore and plate stations still ignore each other.

**Where to set it up** – both ways do the same thing, a link always applies to the whole network on
that surface, not just to one station:

- **Station window:** the box “Linked with” below the home network. Pick a network from the list or
  create a new one with “New”; each partner appears as a button, a click removes the link. If the
  network is a partner itself, the button shows its center, and a click leaves that star.
- **UTL Manager, “Networks” tab:** pick a network on the left; above the station list you add and
  remove partners the same way.

The counter shows how many partners are used and allowed, e.g. `Linked with (2 / 3)`. When the
limit is reached, the tooltip names the research that allows more.

The UTL Manager shows the network in brackets behind the station name when it is not `default`,
links as `[Iron ↔ Copper, Coal]` for a center and `[Copper → Iron]` for a partner. The **Networks**
tab lists every network per surface with free trains, running deliveries and the stations of the
star.

**Typical mistakes**

- Depot in the wrong network → alert "no free train in network …", although trains are waiting.
- Fuel station in the wrong network → low trains are not sent (see *Refueling*).
- A typo or a capital letter is a different network: `Ore` and `ore` do not work together.

## Mixed providers

*Needs research: “UTL: Loading control”.*

A provider may keep several goods in **one** chest. UTL makes sure a train only takes what its
job asks for – in two ways that work together:

**1. Wagon filters (no wiring).** While a delivery runs, UTL sets the cargo wagon slots to the
goods of that job and locks the remaining slots. A plain inserter pulling from a mixed chest
then loads only the ordered item; everything else simply does not fit. Switch it off per station
("Load only the current job" in the Values tab) or for the whole map (map settings). Wagons where
**you** set filters yourself are never touched.

**2. The job as circuit signals.** Next to every train stop sits a small **job output**. It
carries the running jobs as signals: goods to be loaded here are **positive**, goods arriving
here are **negative**. While a delivery train stands at the stop, four more signals are added:
**train number**, **train length** (carriages), **locomotives** and **wagons in the train**. Wire it to filter inserters, to displays – and to pumps: for fluids there
are no slot filters, so this is how you open the right pump at a provider with several tanks.
Draining leftover fluid stays your job.

The output is placed and removed by UTL together with the station; it cannot be built or mined.
Do not wire it to the station's input – that would feed the job back in as stock.

## How trains run

- UTL **does not overwrite your schedule**: provider and requester are inserted as
  **temporary stops** that vanish after departure. **Train groups and interrupts** are kept.
- A rail waypoint in front of each stop makes the train use exactly that stop, even if several
  stops share the name.
- The train waits at the provider until the ordered amount is loaded, at the requester until
  it is empty.
- Selection: highest provider priority and amount, then a free train that carries as much as
  possible in one trip and is close; reachability is checked with the pathfinder.
- Reservations prevent several trains from being sent for the same demand.
- **Several items per train**, **fluids** (fluid wagons, one fluid per delivery) and **next job
  right away** after unloading or cleanup/fuel stations (map setting).

## Refueling

If **any** locomotive is below **40 %** (map setting “Refuel below (%)”), the train visits the
nearest matching **fuel station** – before its next job, right after unloading or from the
depot – and waits until all locomotives are full (max. 30 s). If no fuel station is free, a low
train gets no job and waits in the depot; UTL retries every 10 seconds. If the network has **no** UTL fuel station at all (you refuel via
interrupts or by hand), low trains run normally. Use min./max. train length on fuel stations to
separate small and large trains; the stations may share a name.

## Cleanup

Trains with leftover cargo (arriving at the depot with cargo, after a canceled delivery, or not
fully unloaded at the requester) go to the nearest matching **cleanup station**. What a cleanup
station accepts is set in its window ("Values" tab, "Cleanup" section, not via the stop name): **All items** and **All fluids** switches (both on by default) or single items and
fluids. Goods entered one by one come before "All …"; if one station is not enough, the train
visits several in a row and waits at each until its goods are gone (max. 30 s without change).
Empty fluids with pumps; use "All fluids" only with a drain, fluids mix in pipes. Without a
fitting free cleanup, the train waits in the depot with the alert "no fitting cleanup for
[good]" and UTL retries every 10 s.

## Depots and train length

Free trains wait **empty** at stops with the **Depot** role – **every** depot stop needs the
role, the name alone is not enough; a train that ends up at a stop with a depot's name but
without the role (also vanilla stops) moves on to a free real depot of that name. If a train
arrives at a depot whose min./max. length does
not fit, it moves to a **free matching depot with the same name**; if there is none, it stays
and remains available.

## UTL Manager

Open with the **locomotive button in the shortcut bar** or **Ctrl + Shift + U** (or **Ctrl + Alt + U** – on Linux, IBus sometimes grabs Ctrl + Shift + U). Tabs:
**Depots** (trains with composition, status, cargo), **Stations** (role, provided/requested,
in transit, trains), **Networks** (every network with its stations, free trains and deliveries),
**Inventory** (network totals; click an item for details), **History**
(last 100 deliveries, canceled ones in red), **Alerts** (last 100 alerts, repeats merged). Search by station name; click a station to view it
on the map, click a train to follow it.

**Several planets (Space Age only):** a drop-down next to the
magnifier picks what is shown – *Automatic* (the planet you are on or looking at, default – empty if it has no UTL stations yet), *All
planets*, or one planet (planets from other mods included). Depots with the same name on different
planets stay separate; inventory counts only the chosen planet. Without Space Age the drop-down is
hidden.

## Alerts

UTL reports problems as regular Factorio alerts (bottom right; click to see the spot) in three
groups: **no suitable train** (only after a request has been unserved for 5 minutes – map
setting – and no train with the item is on its way), **leftover/missing cargo**, **train problems** (no path, no free
depot, refueling failed, delivery canceled). Each group can be turned off per player in
**Settings → Mod settings → Per player**. The same alert repeats at most every 10 seconds.

## Trains tab

Rails, elevated rails, signals, stops, locomotives, wagons and train combinators – also from
other mods – get their own crafting tab (startup setting).

## Map settings

Heartbeat (10 ticks), stations per heartbeat (20), new deliveries per cycle (2), next job right
away (on), **load only the current job** (on, wagon filters), **job output at the train stop**
(on), **UTL features need research** (on), refuel below (40 %), “no train” alert after (5 minutes), default supply/demand threshold
(1000), debug log (off).

## Performance

Measured headless (no graphics, so no FPS) with the load test scenario:

| Network | Run | UTL per tick (avg.) | whole game per tick (avg.) | ticks below 60 UPS |
|---|---|---|---|---|
| 9 × 9, 180 trains, 340 stations | 40 min, ~1300 deliveries | 0.045 ms | – | 0 |
| 12 × 12, 384 trains (24 fluid), 496 stations | 10 min | 0.067 ms | 3.6 ms | 36 of 36,000 |

UTL itself peaks at about 15 ms when it sends trains (sending triggers the game's pathfinding).
Most of the time is spent by the game's own trains (movement and pathfinding).

**Important:** the map is otherwise **almost empty** – no factory, no mining drills, no belts, no
biters, just rails, stations, inserters at infinity chests, poles and radars. In a real save the
factory costs extra UPS and FPS; the numbers show what UTL and the trains themselves need, not the
UPS of a whole megabase.

## Scenarios

**New game → Scenarios → UTL examples (mixed provider)**: a small practice network on Marcel's
ring with sidings. One provider keeps iron plates, copper plates and gears in three chests with
three inserters, and the job output enables only the one whose good is ordered. One requester needs iron **and**
copper and gets both in one trip. A fluid provider has two tanks,
oil and water have their own requesters, and the pumps are switched by the **job output**. Two
depots in a row, a fuel station and a cleanup. Two trains, no measuring – made for trying out.

**New game → Scenarios → UTL network links (2 × 2 city blocks)**: four networks on 2 × 2 city
blocks, each in its own part of the map. `Eisen` (iron, middle) is the center of a star with a
depot (4 trains), fuel station and cleanup. Its partners: `Kupfer` (copper) has **no trains of its
own** – the iron trains run its jobs – and `Kohle` (coal) has its own depot with 2 trains, which
also help iron but **never** copper, because partners do not help each other. `Stein` (stone) is
linked to nobody and only runs its own trains. Open the UTL Manager, tab **Networks**, to remove
a link or add `Stein`, and watch in **History** who goes where.

All scenarios and the tips & tricks scenes carry **display panels** with short explanations next to
the stations (in your game language).

## Load test scenario

**New game → Scenarios → UTL load test (384 trains)**: a ready-made city-block grid (12 × 12,
4 tracks per corridor, chain-signalled crossings). 5 depots of 72 trains in depot-only blocks
plus "Depot Flüssig" with 24 fluid trains; 496 stations with room for 3 trains each, providers
and requesters mixed, crude oil and petroleum gas with pumps and tanks, 16 fuel and 6 cleanup
stations spread evenly; every fourth station is a normal stop with a **UTL station combinator**.

**The first start takes a moment:** the scenario builds about 48,000 rail pieces, 3,840 signals,
880 stations and 384 trains by script. Depending on your machine the game freezes for a few
seconds up to a minute – that is normal and happens only once. **No other mods needed**:
infinity chests, infinity pipes and power sources are part of the base game.

## Tips & tricks

The in-game **Tips & tricks** menu has a **Unified Train Logistics** category: fifteen entries
explaining how to use the mod, each with a running example scene (some with an open UTL window,
the manager and shift-click copying), among them: a UTL stop with provider, requester and depot; the same
line with normal stops and UTL station combinators (wires visible); a train that refuels
first and then delivers; a train with leftover cargo that is emptied at a cleanup station first;
**two separate networks** side by side with a camera tour; linking two networks in the station
window (pick from the list, create one with “New”); the manager tab by tab, its Networks tab with a
link being made, and the Inventory tab where a click on a good lists stations and trains.
Plus explanations of roles, requests, values and network, linking networks (star, research
“Network links”), depots, copying settings/blueprints and the manager.

## FAQ

- **Only one train runs:** one is probably enough (target stock, see above), or there are no
  more free trains – `/utl-status` shows “trains in depot”.
- **A depot train is not used:** does the stop have the Depot role? Is the train empty and in
  automatic mode? Does its length fit provider and requester?
- **A train does not refuel:** is there a reachable fuel station in the same network whose
  train length fits?

## Not yet included

Loading/unloading timeouts. Topping up a delivery that is already being loaded (the load list is
fixed when the train is sent), and collecting from a second provider on the way.

**Surfaces (Space Age):** every surface is handled on its own. UTL only matches stations, depots,
fuel and cleanup stations **on the same surface**, so Nauvis and Vulcanus each need their own
depot and their own trains. Deliveries *between* surfaces are not planned – trains cannot change
planet.

## For mod authors

Remote interface `utl`: `station_count`, `get_station(unit)`, `configure_station(unit, changes)`,
`set_request(unit, slot, signal, count)`, `copy_settings(from, to)`, `tag_blueprint(stack, mapping, surface)`, `idle_train_count`,
`delivery_count`, `get_deliveries`, `get_alerts`.
