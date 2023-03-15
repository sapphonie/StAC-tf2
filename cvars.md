## Cvars

// [StAC] enable/disable plugin (setting this to 0 immediately unloads stac)
// (recommended 1)
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
stac_enabled "1"

// [StAC] enable/disable showing verbose info about players' cvars and other similar info in admin and server console
// (recommended 0 unless you want spam in console)
// -
// Default: "0"
// Minimum: "0.000000"
// Maximum: "1.000000"
stac_verbose_info "0"

// [StAC] ban duration that StAC will use upon banning cheating clients. 0 = permanent.
// (recommended 0)
// -
// Default: "0"
// Minimum: "0.000000"
stac_ban_duration "0"

// [StAC] maximum allowed time in seconds before client is autokicked for using turn binds (+right/+left inputs).
// -1 to disable autokicking, 0 instakicks
// (recommended -1.0 unless you're using this in a competitive setting)
// -
// Default: "-1.000000"
// Minimum: "-1.000000"
stac_max_allowed_turn_secs "-1.000000"

// [StAC] ban clients for non usercommand based cheats, aka cheat locked cvars, netprops, invalid names, invalid chat characters, etc.
// (recommended 1)
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
stac_ban_for_misccheats "1"

// [StAC] optimize cvars related to patching "server laggers", patching backtracking, mostly patching doubletap, limiting fakelag, patching any possible tele expoits, etc.
// (recommended 1)
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
stac_optimize_cvars "1"

// [StAC] maximum aimsnap detections before banning a client.
// -1 to disable even checking angles (saves cpu), 0 to print to admins/stv but never ban.
// (recommended 20 or higher)
// -
// Default: "20"
// Minimum: "-1.000000"
stac_max_aimsnap_detections "20"

// [StAC] maximum silent aim/norecoil detections before banning a client.
// -1 to disable even checking angles (saves cpu), 0 to print to admins/stv but never ban.
// (recommended 15 or higher)
// -
// Default: "10"
// Minimum: "-1.000000"
stac_max_psilent_detections "10"

// [StAC] maximum consecutive bhop detections on a client before they get "antibhopped", aka they get their gravity set to 8x.
// client will get banned on this value + 2 (meaning they did 2 more perfect bhops on 8x gravity), so for default cvar settings, client will get banned on 12 tick perfect bhops.
// ctrl + f for "antibhop" in stac.sp for more detailed info.
// -1 to disable even checking bhops (saves cpu), 0 to print to admins/stv but never ban
// (recommended 10 or higher)
// -
// Default: "10"
// Minimum: "-1.000000"
stac_max_bhop_detections "10"

// [StAC] maximum fake angle / wrong / OOB angle detections before banning a client.
// -1 to disable even checking angles (saves cpu), 0 to print to admins/stv but never ban
// (recommended 5)
// -
// Default: "5"
// Minimum: "-1.000000"
stac_max_fakeang_detections "5"

// [StAC] maximum cmdnum spikes a client can have before getting banned.
// lmaobox does this with nospread on certain weapons, other cheats utilize it for other stuff, like sequence breaking on nullcore.
// legit users should never ever trigger this!
// (recommended 20)
// -
// Default: "20"
// Minimum: "-1.000000"
stac_max_cmdnum_detections "20"

// [StAC] maximum triggerbot detections before banning a client. This can, has, and will pick up clients using macro software as well as run of the mill cheaters.
// This check also DOES NOT RUN if the wait command is enabled on your server, as wait allows in-game macroing, making this a nonsensical check in that case.
// defaults 0 - aka, it never bans, only logs.
// (recommended 20+ if you are comfortable permabanning macroing users)
// -
// Default: "0"
// Minimum: "-1.000000"
stac_max_tbot_detections "0"

// [StAC] minimum interp (lerp) in milliseconds that a client is allowed to have before getting autokicked. set this to -1 to disable having a min interp
// (recommended -1.0, but if you want to enable it, feel free. interp values below 15.1515151 ms don't seem to have any noticable effects on anything meaningful)
// -
// Default: "-1"
// Minimum: "-1.000000"
stac_min_interp_ms "-1"

// [StAC] maximum interp (lerp) in milliseconds that a client is allowed to have before getting autokicked. set this to -1 to disable having a max interp
// (recommended 101.0)
// -
// Default: "101"
// Minimum: "-1.000000"
stac_max_interp_ms "101"

// [StAC] check AT LEAST this often in seconds for clients with violating cvar values/netprops
// (recommended 60)
// -
// Default: "60.000000"
// Minimum: "5.000000"
stac_min_randomcheck_secs "60.000000"

// [StAC] check AT MOST this often in seconds for clients with violating cvar values/netprops
// (recommended 300)
// -
// Default: "300.000000"
// Minimum: "15.000000"
stac_max_randomcheck_secs "300.000000"

// [StAC] enable/disable putting the currently recording demo in the SourceBans / gbans ban reason
// (recommended 1)
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
stac_include_demoname_in_banreason "1"

// [StAC] enable/disable logging to file
// (recommended 1)
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
stac_log_to_file "1"

// [StAC] enable fixing clients "pingmasking". this also allows StAC to ban cheating clients attempting to reduce their reported ping.
// (recommended 1)
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
stac_fixpingmasking_enabled "1"

// [StAC] forcibly reconnect clients unauthorized with steam - this protects against cheat clients not setting steamids, at the cost of making your server inaccessible when Steam is down.
// (recommended 0, only enable this if you have consistent issues with unauthed cheaters!)
// -
// Default: "0"
// Minimum: "0.000000"
// Maximum: "1.000000"
stac_kick_unauthed_clients "0"

// [StAC] if this cvar is 0 (default), StAC will print detections to admins with sm_ban access and to SourceTV, if it exists.
// if this cvar is 1, it will print only to SourceTV.
// if this cvar is 2, StAC never print anything in chat to anyone, ever.
// if this cvar is -1, StAC will print ALL detections to ALL players.
// (recommended 0)
// -
// Default: "0"
// Minimum: "-1.000000"
// Maximum: "2.000000"
stac_silent "0"

// [StAC] max connections allowed from the same IP address. useful for autokicking bots, though StAC should do that with cvar checks anyway.
// (recommended 0, you should really only enable this if you're getting swarmed by bots, and StAC isn't doing much against them, in which case, consider opening a bug report!)
// -
// Default: "0"
// Minimum: "0.000000"
stac_max_connections_from_ip "0"

// [StAC] allow StAC to work when sv_cheats is 1. WARNING; you might get false positives, and I will not provide support for servers running this cvar!
// (recommended 0)
// -
// Default: "0"
// Minimum: "0.000000"
// Maximum: "1.000000"
stac_work_with_sv_cheats "0"

## Admin commands

"sm_stac_checkall"
Force check all client convars (ALL CLIENTS) for anticheat stuff

"sm_stac_detections"
Show all current detections on all connected clients

"sm_stac_getauth"
Print StAC's cached auth for a client

"sm_stac_livefeed"
Show live feed (debug info etc) for a client. This gets printed to SourceTV if available.

