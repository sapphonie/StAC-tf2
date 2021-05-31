- `stac_enabled` - `enable/disable plugin (setting this to 0 immediately unloads stac)`

- `stac_verbose_info` - `[StAC] enable/disable showing verbose info about players' cvars and other similar info in admin console (recommended 0, this is essentially a debug cvar)`

- `stac_max_allowed_turn_secs` - `[StAC] maximum allowed time in seconds a client can use +right/+left inputs before getting kicked. -1 to disable autokicking, 0 instakicks (recommended -1 unless you're using this in a competitive setting that bans such usage)`

- `stac_ban_for_misccheats` - `[StAC] ban clients for non angle based cheats, aka cheat locked cvars, netprops, invalid chat characters, etc. (defaults to 1, will only log otherwise)`

- `stac_optimize_cvars` - `[StAC] optimize cvars related to patching backtracking, patching doubletap, limiting fakelag, patching any possible tele expoits, etc. (defaults to 1)`

- `stac_max_aimsnap_detections` - `[StAC] maximum aimsnap detections before banning a client. -1 to disable this check (saves cpu), 0 to print to admins/stv but never ban (recommended 20 or higher)`

- `stac_max_psilent_detections` - `[StAC] maximum silent aim/norecoil detections before banning a client. -1 to disable this check (saves cpu), 0 to print to admins/stv but never ban (recommended 10 or higher)`

- `stac_max_bhop_detections` - `[StAC] maximum consecutive bhop detections on a client before they get \antibhopped\, where their gravity is set to 8x. if the same client does 2 more consecutive frame perfect bhops on 8x gravity, they are banned. if they fail to bhop, their gravity gets reset to normal. -1 to disable this check (saves cpu), 0 to print to admins/stv but never ban (recommended 10 or higher)`

- `stac_max_fakeang_detections` - `[StAC] maximum fake angle / wrong / OOB angle detections before banning a client. -1 to disable even checking angles (saves cpu), 0 to print to admins/stv but never ban (recommended 10)`

- `stac_max_cmdnum_detections` - `[StAC] maximum "cmdnum spikes" a client can have before getting banned. lmaobox does this with nospread on certain weapons, other cheats utilize it for other stuff, like sequence breaking on nullcore etc. (recommended 20 or higher)`

- `stac_max_tbot_detections` - `[StAC] maximum triggerbot detections before banning a client. this can, has, and will pick up clients using macro software as well as cheaters. This check also will not be run if the wait command is enabled on your server, as wait essentially allows for legal triggerbotting. (defaults 0 - aka, it never bans, only logs. recommended 20+ if you are comfortable permabanning macroing users)`

- `stac_max_spinbot_detections` - `[StAC] maximum spinbot detections before banning a client. (recommended 50 or higher)`

- `stac_min_interp_ms` - `[StAC] minimum interp in milliseconds that a client can have before getting autokicked. set this to -1 to disable having a min interp. (recommended -1, this is essentially a legacy check)`

- `stac_max_interp_ms` - `[StAC] maximum interp (lerp) in milliseconds that a client is allowed to have before getting autokicked. set this to -1 to disable having a max interp (recommended 101)`

- `stac_min_randomcheck_secs` - `[StAC] stac runs cvar/netprop checks for clients at random intervals between this value and stac_max_randomcheck_secs, in seconds. (recommended 60)`

- `stac_max_randomcheck_secs` - `[StAC] stac runs cvar/netprop checks for clients at random intervals between stac_min_randomcheck_secs and this value, in seconds. (recommended 300)`

- `stac_include_demoname_in_banreason` - `[StAC] enable/disable putting the currently recording demo in the SourceBans / gbans ban reason (recommended 1)`

- `stac_log_to_file` - `[StAC] enable/disable logging to file (highly recommended 1)`

- `stac_fixpingmasking_enabled` - `[StAC] enable clamping client cl_cmdrate and cl_updaterate values to values specified by their server side counterparts (sv_mincmdrate, sv_minupdaterate, sv_maxcmdrate, sv_maxupdaterate)? This also allows StAC to detect and even ban cheating clients attempting to "ping reduce".`

- `stac_max_userinfo_spam_detections` - `maximum number of times a client can spam userinfo updates (currently, only tracks cl_cmdrate) over the course of 10 seconds before getting banned. (recommended 10+)`

- `stac_kick_unauthed_clients` - `[StAC] kick clients unauthorized with steam? This only kicks if steam has been stable and online for at least the past 300 seconds or more. (recommended 1)`

- `stac_silent` - `[StAC] If this cvar is 0 (default), StAC will print detections to admins with sm_ban access and to SourceTV, if extant. If this cvar is 1, it will print only to SourceTV. If this cvar is 2, StAC never print anything in chat to anyone, ever. If this cvar is -1, StAC will print ALL detections to ALL players. (recommended 0)`
