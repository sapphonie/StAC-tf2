#pragma semicolon 1

/********** STAC CONVAR RELATED STUFF **********/

void initCvars()
{
    AutoExecConfig_SetFile("stac");
    AutoExecConfig_SetCreateFile(true);

    char buffer[16];

    // plugin enabled
    stac_enabled =
    AutoExecConfig_CreateConVar
    (
        "stac_enabled",
        "1",
        "[StAC] enable/disable plugin (setting this to 0 immediately unloads stac)\n\
        (recommended 1)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_enabled, setStacVars);

    // verbose mode
    if (DEBUG)
    {
        buffer = "1";
    }
    else
    {
        buffer = "0";
    }
    stac_verbose_info =
    AutoExecConfig_CreateConVar
    (
        "stac_verbose_info",
        buffer,
        "[StAC] enable/disable showing verbose info about players' cvars and other similar info in admin and server console\n\
        (recommended 0 unless you want spam in console)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_verbose_info, setStacVars);

    // ban duration
    IntToString(banDuration, buffer, sizeof(buffer));
    stac_ban_duration =
    AutoExecConfig_CreateConVar
    (
        "stac_ban_duration",
        buffer,
        "[StAC] ban duration that StAC will use upon banning cheating clients. 0 = permanent.\n\
        (recommended 0)",
        FCVAR_NONE,
        true,
        0.0,
        false,
        _
    );
    HookConVarChange(stac_verbose_info, setStacVars);

    // turn seconds
    FloatToString(maxAllowedTurnSecs, buffer, sizeof(buffer));
    stac_max_allowed_turn_secs =
    AutoExecConfig_CreateConVar
    (
        "stac_max_allowed_turn_secs",
        buffer,
        "[StAC] maximum allowed time in seconds before client is autokicked for using turn binds (+right/+left inputs).\n\
        -1 to disable autokicking, 0 instakicks\n\
        (recommended -1.0 unless you're using this in a competitive setting)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_allowed_turn_secs, setStacVars);

    // cheatvars ban bool
    if (banForMiscCheats)
    {
        buffer = "1";
    }
    else
    {
        buffer = "0";
    }
    stac_ban_for_misccheats =
    AutoExecConfig_CreateConVar
    (
        "stac_ban_for_misccheats",
        buffer,
        "[StAC] ban clients for non usercommand based cheats, aka cheat locked cvars, netprops, invalid names, invalid chat characters, etc.\n\
        (recommended 1)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_ban_for_misccheats, setStacVars);

    // cheatvars ban bool
    if (optimizeCvars)
    {
        buffer = "1";
    }
    else
    {
        buffer = "0";
    }
    stac_optimize_cvars =
    AutoExecConfig_CreateConVar
    (
        "stac_optimize_cvars",
        buffer,
        "[StAC] optimize cvars related to patching \"server laggers\", patching backtracking, mostly patching doubletap, limiting fakelag, patching any possible tele expoits, etc.\n\
        (recommended 1)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_optimize_cvars, setStacVars);

    // aimsnap detections
    IntToString(maxAimsnapDetections, buffer, sizeof(buffer));
    stac_max_aimsnap_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_aimsnap_detections",
        buffer,
        "[StAC] maximum aimsnap detections before banning a client.\n\
        -1 to disable even checking angles (saves cpu), 0 to print to admins/stv but never ban.\n\
        (recommended 20 or higher)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_aimsnap_detections, setStacVars);

    // psilent detections
    IntToString(maxPsilentDetections, buffer, sizeof(buffer));
    stac_max_psilent_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_psilent_detections",
        buffer,
        "[StAC] maximum silent aim/norecoil detections before banning a client.\n\
        -1 to disable even checking angles (saves cpu), 0 to print to admins/stv but never ban.\n\
        (recommended 15 or higher)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_psilent_detections, setStacVars);

    // bhop detections
    IntToString(maxBhopDetections, buffer, sizeof(buffer));
    stac_max_bhop_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_bhop_detections",
        buffer,
        "[StAC] maximum consecutive bhop detections on a client before they get \"antibhopped\", aka they get their gravity set to 8x.\n\
        client will get banned on this value + 2 (meaning they did 2 more perfect bhops on 8x gravity), so for default cvar settings, client will get banned on 12 tick perfect bhops.\n\
        ctrl + f for \"antibhop\" in stac.sp for more detailed info.\n\
        -1 to disable even checking bhops (saves cpu), 0 to print to admins/stv but never ban\n\
        (recommended 10 or higher)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_bhop_detections, setStacVars);

    // fakeang detections
    IntToString(maxFakeAngDetections, buffer, sizeof(buffer));
    stac_max_fakeang_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_fakeang_detections",
        buffer,
        "[StAC] maximum fake angle / wrong / OOB angle detections before banning a client.\n\
        -1 to disable even checking angles (saves cpu), 0 to print to admins/stv but never ban\n\
        (recommended 5)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_fakeang_detections, setStacVars);

    // cmdnum spike detections
    IntToString(maxCmdnumDetections, buffer, sizeof(buffer));
    stac_max_cmdnum_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_cmdnum_detections",
        buffer,
        "[StAC] maximum cmdnum spikes a client can have before getting banned.\n\
        lmaobox does this with nospread on certain weapons, other cheats utilize it for other stuff, like sequence breaking on nullcore.\n\
        legit users should never ever trigger this!\n\
        (recommended 20)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_cmdnum_detections, setStacVars);

    // triggerbot detections
    IntToString(maxTbotDetections, buffer, sizeof(buffer));
    stac_max_tbot_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_tbot_detections",
        buffer,
        "[StAC] maximum triggerbot detections before banning a client. This can, has, and will pick up clients using macro software as well as run of the mill cheaters.\n\
        This check also DOES NOT RUN if the wait command is enabled on your server, as wait allows in-game macroing, making this a nonsensical check in that case.\n\
        defaults 0 - aka, it never bans, only logs.\n\
        (recommended 20+ if you are comfortable permabanning macroing users)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_tbot_detections, setStacVars);

    // min interp
    IntToString(min_interp_ms, buffer, sizeof(buffer));
    stac_min_interp_ms =
    AutoExecConfig_CreateConVar
    (
        "stac_min_interp_ms",
        buffer,
        "[StAC] minimum interp (lerp) in milliseconds that a client is allowed to have before getting autokicked. set this to -1 to disable having a min interp\n\
        (recommended -1.0, but if you want to enable it, feel free. interp values below 15.1515151 ms don't seem to have any noticable effects on anything meaningful)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_min_interp_ms, setStacVars);

    // min interp
    IntToString(max_interp_ms, buffer, sizeof(buffer));
    stac_max_interp_ms =
    AutoExecConfig_CreateConVar
    (
        "stac_max_interp_ms",
        buffer,
        "[StAC] maximum interp (lerp) in milliseconds that a client is allowed to have before getting autokicked. set this to -1 to disable having a max interp\n\
        (recommended 101.0)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_interp_ms, setStacVars);

    // min random check secs
    FloatToString(minRandCheckVal, buffer, sizeof(buffer));
    stac_min_randomcheck_secs =
    AutoExecConfig_CreateConVar
    (
        "stac_min_randomcheck_secs",
        buffer,
        "[StAC] check AT LEAST this often in seconds for clients with violating cvar values/netprops\n\
        (recommended 60)",
        FCVAR_NONE,
        true,
        5.0,
        false,
        _
    );
    HookConVarChange(stac_min_randomcheck_secs, setStacVars);

    // min random check secs
    FloatToString(maxRandCheckVal, buffer, sizeof(buffer));
    stac_max_randomcheck_secs =
    AutoExecConfig_CreateConVar
    (
        "stac_max_randomcheck_secs",
        buffer,
        "[StAC] check AT MOST this often in seconds for clients with violating cvar values/netprops\n\
        (recommended 300)",
        FCVAR_NONE,
        true,
        15.0,
        false,
        _
    );
    HookConVarChange(stac_max_randomcheck_secs, setStacVars);

    // demoname in ban reason
    if (demonameInBanReason)
    {
        buffer = "1";
    }
    else
    {
        buffer = "0";
    }
    stac_include_demoname_in_banreason =
    AutoExecConfig_CreateConVar
    (
        "stac_include_demoname_in_banreason",
        buffer,
        "[StAC] enable/disable putting the currently recording demo in the SourceBans / gbans ban reason\n\
        (recommended 1)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_include_demoname_in_banreason, setStacVars);

    // log to file
    if (logtofile)
    {
        buffer = "1";
    }
    else
    {
        buffer = "0";
    }
    stac_log_to_file =
    AutoExecConfig_CreateConVar
    (
        "stac_log_to_file",
        buffer,
        "[StAC] enable/disable logging to file\n\
        (recommended 1)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_log_to_file, setStacVars);

    // fixpingmasking
    if (fixpingmasking)
    {
        buffer = "1";
    }
    else
    {
        buffer = "0";
    }
    stac_fixpingmasking_enabled =
    AutoExecConfig_CreateConVar
    (
        "stac_fixpingmasking_enabled",
        buffer,
        "[StAC] enable fixing clients \"pingmasking\". this also allows StAC to ban cheating clients attempting to reduce their reported ping.\n\
        (recommended 1)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_fixpingmasking_enabled, setStacVars);

    // pingreduce
    IntToString(maxuserinfoSpamDetections, buffer, sizeof(buffer));
    stac_max_cmdrate_spam_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_userinfo_spam_detections",
        buffer,
        "[StAC] maximum number of times a client can spam userinfo updates (over the course of 10 seconds) before getting banned.\n\
        (recommended 10+)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_cmdrate_spam_detections, setStacVars);

    // reconnect unauthed clients
    if (kickUnauth)
    {
        buffer = "1";
    }
    else
    {
        buffer = "0";
    }
    stac_kick_unauthed_clients =
    AutoExecConfig_CreateConVar
    (
        "stac_kick_unauthed_clients",
        buffer,
        "[StAC] forcibly reconnect clients unauthorized with steam - this protects against cheat clients not setting steamids, at the cost of making your server inaccessible when Steam is down.\n\
        (recommended 0, only enable this if you have consistent issues with unauthed cheaters!)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_kick_unauthed_clients, setStacVars);

    // shut up!
    IntToString(silent, buffer, sizeof(buffer));
    stac_silent =
    AutoExecConfig_CreateConVar
    (
        "stac_silent",
        buffer,
        "[StAC] if this cvar is 0 (default), StAC will print detections to admins with sm_ban access and to SourceTV, if it exists.\n\
        if this cvar is 1, it will print only to SourceTV.\n\
        if this cvar is 2, StAC never print anything in chat to anyone, ever.\n\
        if this cvar is -1, StAC will print ALL detections to ALL players.\n\
        (recommended 0)",
        FCVAR_NONE,
        true,
        -1.0,
        true,
        2.0
    );
    HookConVarChange(stac_silent, setStacVars);

    // max connections from the same ip
    IntToString(maxip, buffer, sizeof(buffer));
    stac_max_connections_from_ip =
    AutoExecConfig_CreateConVar
    (
        "stac_max_connections_from_ip",
        buffer,
        "[StAC] max connections allowed from the same IP address. useful for autokicking bots, though StAC should do that with cvar checks anyway.\n\
        (recommended 0, you should really only enable this if you're getting swarmed by bots, and StAC isn't doing much against them, in which case, consider opening a bug report!)",
        FCVAR_NONE,
        true,
        0.0,
        false,
        _
    );
    HookConVarChange(stac_max_connections_from_ip, setStacVars);

    // max connections from the same ip
    IntToString(ignore_sv_cheats, buffer, sizeof(buffer));
    stac_work_with_sv_cheats =
    AutoExecConfig_CreateConVar
    (
        "stac_work_with_sv_cheats",
        buffer,
        "[StAC] allow StAC to work when sv_cheats is 1. WARNING; you might get false positives, and I will not provide support for servers running this cvar!\n\
        (recommended 0)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_work_with_sv_cheats, setStacVars);


    // actually exec the cfg after initing cvars lol
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
    setStacVars(null, "", "");
}

void setStacVars(ConVar convar, const char[] oldValue, const char[] newValue)
{
    // this regrabs all cvar values but it's neater than having two similar functions that do the same thing
    // now covers late loads

    // enabled var
    if (!GetConVarBool(stac_enabled))
    {
        SetFailState("[StAC] stac_enabled is set to 0 - aborting!");
    }

    // ban duration var
    banDuration             = GetConVarInt(stac_ban_duration);

    // verbose info var
    DEBUG                   = GetConVarBool(stac_verbose_info);

    // turn seconds var
    maxAllowedTurnSecs      = GetConVarFloat(stac_max_allowed_turn_secs);
    if (maxAllowedTurnSecs < 0.0 && maxAllowedTurnSecs != -1.0)
    {
        maxAllowedTurnSecs = 0.0;
    }

    // misccheats
    banForMiscCheats        = GetConVarBool(stac_ban_for_misccheats);

    // optimizecvars
    optimizeCvars           = GetConVarBool(stac_optimize_cvars);
    if (optimizeCvars)
    {
        RunOptimizeCvars();
    }

    // aimsnap var
    maxAimsnapDetections    = GetConVarInt(stac_max_aimsnap_detections);

    // psilent var
    maxPsilentDetections    = GetConVarInt(stac_max_psilent_detections);

    // bhop var
    maxBhopDetections       = GetConVarInt(stac_max_bhop_detections);

    // fakeang var
    maxFakeAngDetections    = GetConVarInt(stac_max_fakeang_detections);

    // cmdnum spikes var
    maxCmdnumDetections     = GetConVarInt(stac_max_cmdnum_detections);

    // tbot var
    maxTbotDetections       = GetConVarInt(stac_max_tbot_detections);

    // max ping reduce detections - clamp to -1 if 0
    maxuserinfoSpamDetections   = GetConVarInt(stac_max_cmdrate_spam_detections);

    // minterp var - clamp to -1 if 0
    min_interp_ms           = GetConVarInt(stac_min_interp_ms);
    if (min_interp_ms == 0)
    {
        min_interp_ms = -1;
    }

    // maxterp var - clamp to -1 if 0
    max_interp_ms           = GetConVarInt(stac_max_interp_ms);
    if (max_interp_ms == 0)
    {
        max_interp_ms = -1;
    }

    // min check sec var
    minRandCheckVal         = GetConVarFloat(stac_min_randomcheck_secs);

    // max check sec var
    maxRandCheckVal         = GetConVarFloat(stac_max_randomcheck_secs);

    // log to file
    logtofile               = GetConVarBool(stac_log_to_file);

    // properly fix pingmasking
    fixpingmasking          = GetConVarBool(stac_fixpingmasking_enabled);

    // kick unauthed clients
    kickUnauth              = GetConVarBool(stac_kick_unauthed_clients);

    // silent mode
    silent                  = GetConVarInt(stac_silent);

    // max conns from same ip
    maxip                   = GetConVarInt(stac_max_connections_from_ip);

    // max conns from same ip
    ignore_sv_cheats        = GetConVarBool(stac_work_with_sv_cheats);
}

public void GenericCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (!ignore_sv_cheats)
    {
        // IMMEDIATELY unload if we enable sv cheats
        if (convar == FindConVar("sv_cheats"))
        {
            if (StringToInt(newValue) != 0)
            {
                SetFailState("[StAC] sv_cheats set to 1! Aborting!");
            }
        }
    }

    // set timescale so we don't ban clients if its not default
    if (convar == FindConVar("host_timescale"))
    {
        timescale = GetConVarFloat(convar);
    }

    if (convar == FindConVar("sv_allow_wait_command"))
    {
        if (StringToInt(newValue) != 0)
        {
            waitStatus = true;
        }
        else
        {
            waitStatus = false;
        }
    }
}

#define MAX_RATE        (1024*1024)
#define MIN_RATE        1000
// update server rate settings for cmdrate spam check - i'd rather have one func do this lol
public void UpdateRates(ConVar convar, const char[] oldValue, const char[] newValue)
{
    imincmdrate    = GetConVarInt(FindConVar("sv_mincmdrate"));
    imaxcmdrate    = GetConVarInt(FindConVar("sv_maxcmdrate"));
    iminupdaterate = GetConVarInt(FindConVar("sv_minupdaterate"));
    imaxupdaterate = GetConVarInt(FindConVar("sv_maxupdaterate"));
    iminrate       = GetConVarInt(FindConVar("sv_minrate"));
    imaxrate       = GetConVarInt(FindConVar("sv_maxrate"));

    if (iminrate <= 0)
    {
        iminrate = MIN_RATE;
    }

    if (imaxrate <= 0)
    {
        imaxrate = MAX_RATE;
    }

    // update clients
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            OnClientSettingsChanged(Cl);
        }
    }
}

void RunOptimizeCvars()
{
    // attempt to patch doubletap (CS:GO default value!)
    SetConVarInt(FindConVar("sv_maxusrcmdprocessticks"), 8);

    // force psilent to show up properly
    SetConVarInt(FindConVar("sv_maxusrcmdprocessticks_holdaim"), 1);

    // limit fakelag abuse / backtracking (CS:GO default value!)
    SetConVarFloat(FindConVar("sv_maxunlag"), 0.2);

// these cvars don't exist outside of tf2 (atm)
#if !defined OF && !defined TF2C
    // print dc reasons to clients
    SetConVarBool(FindConVar("net_disconnect_reason"), true);

    // prevent all sorts of exploits involving CNetChan fuzzing etc.
    ConVar net_chan_limit_msec = FindConVar("net_chan_limit_msec");
    // don't override server set settings if they have set it to a value other than 0
    if (GetConVarInt(net_chan_limit_msec) == 0)
    {
        SetConVarInt(net_chan_limit_msec, 75);
    }
#endif

    // fix backtracking
    ConVar jay_backtrack_enable     = FindConVar("jay_backtrack_enable");
    ConVar jay_backtrack_tolerance  = FindConVar("jay_backtrack_tolerance");
    // dont error out on server start
    if (jay_backtrack_enable != null && jay_backtrack_tolerance != null)
    {
        // enable jaypatch
        SetConVarInt(jay_backtrack_enable, 1);
        // set jaypatch to sane value
        SetConVarInt(jay_backtrack_tolerance, 1);
    }

    // get rid of any possible exploits by using teleporters and fov
    SetConVarInt(FindConVar("tf_teleporter_fov_start"), 90);
    SetConVarFloat(FindConVar("tf_teleporter_fov_time"), 0.0);
}
