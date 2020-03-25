# STEPH'S ANTICHEAT <span color=#FF69B4>[StAC]</span>

### Disclaimers
I can not make ANY guarantees on the stability or performance of this plugin as of yet as it is still VERY MUCH in beta. Use with caution!

#### SEE HERE FOR POSSIBLY BETTER AC PLUGINS:
LilAC: https://forums.alliedmods.net/showthread.php?t=321480

SMAC: https://github.com/Silenci0/SMAC

### This plugin currently prevents:
- interp abuse
*(kick / ban if impossible value like < 0.015151 or > 0.5)*
- updaterate abuse that can cause to interp abuse
*(kick only if updaterate is below 20 [default] or above 128)*
- clients using turn binds
*(kick)*
- cmdrate pingmasking if cvar has nonnumerical chars)
*(kick)*
- newlines in chat messages
*(ban)*
- NoLerp cheats
*(ban - untested on all but NCC)*
- fov abuse > 90
*(fixes most cases / can ban on blatant netprop/cvar changing)*
- SOME third person cheats on clients
*(fixes some cases / can ban on blatant netprop/cvar changing)*
- blatant othermodels abuse (will not catch most)
*(only bans blatant cvar changing)*
- blatant fullbright abuse (will not catch most)
*(only bans blatant cvar changing)*
- pSilentAim / NoRecoil cheats
*(currently only notifies admins and STV of detections, not tested well enough to autoban yet)*
- fake eye angle violations
*(currently only notifies admins and STV of detections, not tested well enough to autoban yet)*

### Attempted nospread fix
This plugin currently reseeds the hl2 random seed at each map / tournament start and every 15 minutes to attempt to prevent possible nospread exploits by cheats guessing the server seed. This appears to work at least on NCC but I have not bothered to test it with other cheats.

### Todo (may not be possible):
- break/ban for esp/wallhack shit (not thru painting but possibly with checking m_bGlowEnabled)
- fix spy decloak exploit / other soundscript exploits (STILL in the works)
- fix other sv pure stuff (flat / invisible textures)
- fix sniper scope removal exploit
- fix changing world visiblity

### Sourcebans and customization
This plugin is compatible with both SourceBans and the default TF2 ban handler.
There are currently NO cvars to modify the plugin's default behavior, these will be added later when the plugin is in less of a beta state.
