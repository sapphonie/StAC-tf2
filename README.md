
# STEPH'S ANTICHEAT <span color=#FF69B4>[StAC]</span>

### Disclaimers
I can not make guarantees on the stability or performance of this plugin as of yet as it is still in beta. Use with caution!

### This plugin currently prevents:
- interp/lerp abuse (some detection methods only available on default tickrate servers)
*(kick if outside of values you set with `stac_min_interp_ms` and `stac_max_interp_ms`)*
- clients using turn binds (can severely fuck up hitboxes)
*(kick if `stac_max_allowed_turn_secs` is set to a value other than -1)*
- cmdrate pingmasking if cvar has nonnumerical chars)
*(kick)*
- newlines in chat messages
*(ban)*
- NoLerp cheats
*(ban)*
- fov abuse > 90
*(fixes most cases / can ban on blatant netprop/cvar changing)*
- SOME third person cheats on clients
*(fixes some cases / can ban on blatant netprop/cvar changing)*
- blatant othermodels abuse (will not catch most)
*(only bans blatant cvar changing)*
- blatant fullbright abuse (will not catch most)
*(only bans blatant cvar changing)*
- pSilentAim / NoRecoil cheats
*(logs detections to admins / STV, bans on `stac_max_psilent_detections` detections, defaults to 15)*
- fake eye angle violations
*(logs detections to admins / STV, bans on `stac_max_fakeang_detections` detections, defaults to 2000)*

### Attempted nospread fix
This plugin currently reseeds the hl2 random seed at each map / tournament start and every 15 minutes to attempt to prevent possible nospread exploits by cheats guessing the server seed. This appears to work at least on NCC but I have not bothered to test it with other cheats.

### Installation & Configuration
1) download latest version from [here](https://github.com/stephanieLGBT/StAC-tf2/raw/master/plugins/stac.smx) to your `/tf/addons/sourcemod/plugins` folder
2) restart your server
3) wait 30 seconds
4) edit `/tf/cfg/sourcemod/stac.cfg` to your liking. the recommended values are the default but feel free to change any of them to your liking. I personally use stricter values on my own servers.
5) restart your server again

You should be good to go!

### Sourcebans
This plugin is compatible with both SourceBans and the default TF2 ban handler, and auto detects which it should use.

### Todo (may not be possible):
- add basic snap detection outside of psilent snaps (in the works!)
- break/ban for esp/wallhack shit (not thru painting but possibly with checking m_bGlowEnabled)
- fix spy decloak exploit / other soundscript exploits (STILL in the works)
- fix other sv pure stuff (flat / invisible textures)
- fix sniper scope removal exploit
- fix changing world visibility

### Other AC plugins that I took inspiration from / lifted a few lines of code from - Check them out!

LilAC: https://forums.alliedmods.net/showthread.php?t=321480

SMAC: https://github.com/Silenci0/SMAC


