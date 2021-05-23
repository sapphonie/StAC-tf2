# STEPH'S ANTICHEAT <span color=#FF69B4>[StAC]</span>

## An Anti-Cheat SourceMod Plugin for Team Fortress 2

### This plugin can currently prevent:
- pSilentAim / NoRecoil cheats
*(logs detections to admins / STV / file, bans on `stac_max_psilent_detections` detections, defaults to 15)*
- plain aimsnap/aimbot cheats
*(logs detections to admins / STV / file, bans on `stac_max_aimsnap_detections` detections, defaults to 25)*
- bhop cheats and scripts
*(logs detections to admins / STV, bans on `stac_max_bhop_detections` detections + 2 (defaults to 10)*

Note: After a client does `stac_max_bhop_detections` tick perfect bhops (default 10), they will get "antibhopped". This will set their gravity to 8x and their velocity to 0. Cheating clients will get banned if they hold down their spacebar and successfully do 2 extra tick perfect bhops with 8x gravity, something that is functionally impossible for a human.

- fake eye angle violations
*(logs detections to admins / STV, bans on `stac_max_fakeang_detections` detections, defaults to 10)*
- cmdnum spikes - used for lmaobox NoRecoil and other shenanigans
*(logs detections to admins / STV, bans on `stac_max_cmdnum_detections` detections, defaults to 25)*
- interp/lerp abuse (some detection methods only available on default tickrate servers)
*(kick if outside of values you set with `stac_min_interp_ms` and `stac_max_interp_ms`)*
- clients using turn binds (can severely fuck up hitboxes)
*(kick if `stac_max_allowed_turn_secs` is set to a value <= 0)*
- newlines in chat messages
*(ban)*
- NoLerp cheats
*(ban)*
- fov abuse > 90 || < 20
*(fixes most cases, bans on blatant cvar changing)*
- SOME third person cheats on clients
*(fixes some cases)*
- certain fake item schema violations - i.e. "ben cat hats" (cheat that ~~can unequip~~ used to unequip other people's hats)
*(ban)*
- certain fake item schema violations - i.e. "ben cat hats" (cheat that ~~can unequip~~ used to unequip other people's hats)
*(ban)*

## Where'd the "Illegal Characters In Name" ban method go?
Long story short: it was subject to false positives. I tested this, and thought Steam sanitized names, but it appears to only do so in the friends ui name change section, and NOT on the steamcommunity.com website. Any bans that have been recorded with this ban method __should be removed__. I ***HIGHLY RECOMMEND*** using something like [JoinedSenses' RegexTriggers plugin](https://github.com/JoinedSenses/SM-Regex-Trigger) to sanitize names to only contain ASCII characters, not only to fix possible sql issues with mismatched character sets / collation AND possibly sql injection, but also to prevent cheaters from using newlines and other malicious characters. Doing so in StAC would be outside the scope of this plugin.


# Steph's AntiCheat
### This plugin - "StAC" - and the ones bundled with it, can detect, log, patch, and punish for a majority of the cheats, macros, and unfair scripts available for Team Fortress 2, including:
- pSilentAim / NoRecoil / Angle Repeat cheats
- Plain aimsnap / Aimbot cheats
- Auto bhop cheats
- Fake eye angle cheats
- NoLerp cheats
- Some FoV cheats
- Spinbot cheats
### It also prevents and/or detects:
- Newlines/invalid characters in chat messages
- Cmdnum manipulation (clientside nospread)
- Tickcount manipulation (backtracking)
- Interp/lerp abuse
- Clients using +right/+left inputs
- "Ping reducing" cheats (and patches "pingmasking" by legit clients as well)
- Clients purposefully not authorizing with Steam

##
I hate cheaters. Everyone does. But you know what I hate more? Taking the sweet time out of my day to catch them. A lot of TF2 cheats do a lot of the same things, and if you know what to look for, you can detect their patterns and ban them ***automatically***! Cool!
Of course, StAC is serverside, so that means it sucks, right? Wrong! Of course, there's limitations to what this plugin can do. It **can't** scan the memory or programs on your computer, it **can't** see exactly what keys you're pressing on your keyboard, and players don't live inside the server room, so there's always the factor of **lag** and **loss**. But StAC is written so that it has as few false detections as possible. I would rather someone closet cheat, and not get banned, than have someone get falsely banned for cheating. No server admin wants to unban someone who wasn't cheating, and **no player wants to get banned when they weren't cheating**. This plugin is set up to be as easy to use and install as possible, and it's designed to work right. I've reverse engineered cheats, installed them myself (on an alt, don't worry!) and I've tested and refined this plugin over the course of years and thousands of hours of work. It also [runs on](https://sappho.io) [more community servers](https://creators.tf) [than you might think](https://gflclan.com/)!

StAC is also fully configurable, and the current list of cvars is listed [here](cvars.md). The defaults should be good for most people, if you want to the plugin to autoban. If not, you can set any "detection" cvar to 0 to never ban, and to -1 to never even log or check in the first place.

### Installation & Configuration
1) clone the repository from [here](https://github.com/sapphonie/StAC-tf2/archive/refs/heads/master.zip)
2) drag the `translations`, `scripting`, and `plugins` folders into `/tf/addons/sourcemod/` on your tf2 server. Overwrite any files if prompted.
3) restart your server

If you want to customize cvars,

4) wait 30 seconds after doing the above
5) edit `/tf/cfg/sourcemod/stac.cfg` to your liking
6) restart your server again

You should be good to go!

### Sourcebans
This plugin is compatible with both SourceBans, gbans, and the default TF2 ban handler, and auto detects which it should use. The plugin, by default, logs the currently recording demo (if one is recording) to the sourcebans ban message. To disable this, set `stac_include_demoname_in_sb` to `0`.

### Logging
This plugin logs (by default) to /tf/addons/sourcemod/logs/stac/stac_month_day_year.log. To disable this, set `stac_log_to_file` to `0`

### Disclaimers
Though I wrote StAC to throw as few false positives as possible, I can't guarantee perfection. I also can't guarantee that everything will always work how it's supposed to. Please submit a bug report if you can reproduce a way to trigger false positives, or for any bug or feature request. If you're more comfortable talking to me personally about it, join the development discord for StAC here: https://discord.gg/tUGgCByZVJ


### Other AC plugins that I took inspiration from / lifted a few lines of code from

LilAC: https://forums.alliedmods.net/showthread.php?t=321480

SMAC: https://github.com/Silenci0/SMAC

SSaC: Private. Thank you [AS] Nacho Replay, dog, and Miggy.

