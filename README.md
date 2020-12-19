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
- interp/lerp abuse (some detection methods only available on default tickrate servers)
*(kick if outside of values you set with `stac_min_interp_ms` and `stac_max_interp_ms`)*
- clients using turn binds (can severely fuck up hitboxes)
*(kick if `stac_max_allowed_turn_secs` is set to a value <= 0)*
- cmdrate pingmasking if cvar has nonnumerical chars)
*(kick if `stac_kick_for_pingmasking` is set to 1, default 0)*
- newlines in chat messages
*(ban)*
- NoLerp cheats
*(ban)*
- fov abuse > 90
*(fixes most cases, bans on blatant cvar changing)*
- SOME third person cheats on clients
*(fixes some cases)*
- certain fake item schema violations - i.e. "ben cat hats" (cheat that ~~can unequip~~ used to unequip other people's hats)
*(ban)*
- illegal characters in name
*(ban)*

### Backtrack Fix by J_Tanz
This repo includes the latest version of J_Tanzanite's (author of another popular anticheat, [LilAC](https://github.com/J-Tanzanite/Little-Anti-Cheat) Backtrack Patch, available [here](https://github.com/J-Tanzanite/Backtrack-Patch). It is enabled by default, but to disable it, set `stac_optimize_cvars` to `0` and `jay_backtrack_enable` to `0`.

### Attempted nospread fix
This plugin currently reseeds the hl2 random seed at each map / tournament start and every 15 minutes to attempt to prevent possible nospread exploits by cheats guessing the server seed. This appears to work at least on NCC but I have not bothered to test it with other cheats.

### Installation & Configuration
1) download latest version from [here](https://github.com/sapphonie/StAC-tf2/raw/master/plugins/stac.smx) to your `/tf/addons/sourcemod/plugins` folder
2) download latest translation file from [here](https://github.com/sapphonie/StAC-tf2/raw/master/translations/stac.phrases.txt) to your `/tf/addons/sourcemod/translations` folder
3) restart your server
4) wait 30 seconds
5) edit `/tf/cfg/sourcemod/stac.cfg` to your liking. the recommended values are the default but feel free to change any of them to your liking. I personally use stricter values on my own servers.
6) restart your server again

You should be good to go!

### Sourcebans
This plugin is compatible with both SourceBans and the default TF2 ban handler, and auto detects which it should use. The plugin, by default, logs the currently recording demo (if one is recording) to the sourcebans ban message. To disable this, set `stac_include_demoname_in_sb` to `0`.

### Logging
This plugin logs (by default) to /tf/addons/sourcemod/logs/stac/stac_month_day_year.log. To disable this, set `stac_log_to_file` to `0`

### Disclaimers
False positives are always a possibility! Feel free to submit a bug report if you can reproduce a way to trigger false positives.

### Todo (may not be possible):
- break/ban for esp/wallhack shit (not thru painting but possibly with checking m_bGlowEnabled)
- fix spy decloak exploit / other soundscript exploits (STILL in the works)
- fix other sv pure stuff (flat / invisible textures)
- fix sniper scope removal exploit
- fix changing world visibility

### Other AC plugins that I took inspiration from / lifted a few lines of code from - Check them out!

LilAC: https://forums.alliedmods.net/showthread.php?t=321480

SMAC: https://github.com/Silenci0/SMAC

