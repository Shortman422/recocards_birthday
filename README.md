# **Recocard Birthday Card Quest — v5**

## 

## This version adds the Sweatling System and Moist Mobbing

# 

# **Core Mechanics**

# 

## Recocards are spawned individually throughout the world.

## 

## Cards only spawn within the zones defined in bridge/spawn\_zones.csv.

## Cards do not overlap each other.

## Claiming a card's sweatling marks it as Found.

## The HUD only displays:

## Birthday Cards: X / Y

## 

## The player receives Dunk's Birthday Book at the start of each run.

## The player receives Birthday Guiding Powder at the start of each run.



## The book starts empty.

## Only discovered cards appear in the book.

## There is one card per page.

## Newly discovered cards automatically open as the newest page.

## Previous/Next only cycles through cards that have already been found.



# **Sweatling System**

# 

## Each card is carried by a Sweatling: a layered bust that falls and settles on

## terrain, wears the card author's cosmetics, and shows the author's name above it.

## 

## Claim the card either way:

## Damage the sweatling to defeat it (angry/red burst), or

## Interact to pick it up (friendly/blue burst).

## 

## Either outcome grants the card once; there is no gold or corpse drop.



# **Moist Mobbing**

# 

## Subs and gifts are celebrated in-world: a large sub/gifter Sweatling and emitters

## appear at the streamer, and chatters typing dnkM/dnkMM spawn a mob of sweatlings

## in expanding rings around the sub/gifter for about 30 seconds.

## 

## Moist Mobbing requires a Twitch connection through Noita's built-in Streaming

## tab (Options -> Streaming) so the mod can read chat events.

## 

## Mod Settings (Options -> Mod Settings -> DunkOrSlam Birthday Card Quest: Relaunch to apply):

## Enable Moist Mobbing — master toggle (ON by default).

## Enable Debug Moist Mobbing — test mode: any chatter typing 'sub: name' or

## 'gift: name' triggers a simulated mob (OFF by default; leave OFF for the event).

## Enable debug logging — writes debug/trigger logs to files (OFF for best performance).





# **Integrated Mods**

* Rhythm Arcade
* Punch-Out Arcade
* GlimmersBirthdayed
* Celebratium
* Hämis Party
* Custom Credits
* Chests are Presents

# **Installation**

# 

## Copy the recocards\_birthday folder to:

## 

## ...\\Steam\\steamapps\\common\\Noita\\mods\\

## 

## Then:

## 

## Run bridge/start.bat

## Start Noita.

## Allow Unsafe Mods.

## Enable the mod.

## Restart Noita with mods enabled.



# **Opening the Book**

# 

## The book is added to the player's inventory as a quest item.

## The book GUI displays one large Recocard per page.

# 

# **Spawn Zones**

# 

## Spawn zones are defined in:

## bridge/spawn\_zones.csv

## 

## Format:

## name,x1,y1,x2,y2,weight

## 

# 

# **Quest Configuration**

# 

## Configuration file:

## 

## bridge/quest\_config.txt

## 

## Current settings:

## 

## card\_world\_width=115

## spawn\_margin=28

## discover\_radius=34

## spawn\_seed=156008746

## 

## hud\_x=16

## hud\_y=22

## 

## book\_image\_width=300

## book\_image\_max\_height=180

## book\_x=18

## book\_y=18



# **Stable IDs**

# 

## The bridge generates a stable, shortened SHA-1-based ID for each card using its text.

## 

## This means a card's Found State does not depend on its current position or order on the Recocards website.

## 

## For example, generated card files can look like this:

## 

## card\_a82fd190ac21.png

