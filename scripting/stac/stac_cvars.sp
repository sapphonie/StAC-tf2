#pragma semicolon 1

/********** STAC CONVAR RELATED STUFF **********/

void initUsercmdCvars()
{
    // turn seconds
    stac_max_allowed_turn_secs =
    AutoExecConfig_CreateConVar
    (
        "stac_max_allowed_turn_secs",
        "-1.0",
        "[StAC] maximum allowed time in seconds before client is autokicked for using turn binds (+right/+left inputs).\n\
        -1.0 to disable autokicking, 0 instakicks\n\
        (recommended -1.0 unless you're using this in a competitive setting)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );

    stac_generic_ban_msgs =
    AutoExecConfig_CreateConVar
    (
        "stac_generic_ban_msgs",
        "1",
        "[StAC] Use a generic message when banning clients - this goes in SourceBans, chat, and other public places, but it does NOT change your logs.\n\
        You should almost always leave this alone.\n\
        (recommended 1)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );

    // aimsnap detections
    stac_max_aimsnap_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_aimsnap_detections",
        "10",
        "[StAC] maximum aimsnap detections before banning a client.\n\
        -1 to disable even checking angles (saves cpu), 0 to print to admins/stv but never ban.\n\
        (recommended 10 or higher)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );

    // psilent detections
    stac_max_psilent_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_psilent_detections",
        "10",
        "[StAC] maximum silent aim/norecoil detections before banning a client.\n\
        -1 to disable even checking angles (saves cpu), 0 to print to admins/stv but never ban.\n\
        (recommended 10 or higher)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );

    // bhop detections
    stac_max_bhop_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_bhop_detections",
        "10",
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

    // fakeang detections
    stac_max_fakeang_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_fakeang_detections",
        "5",
        "[StAC] maximum fake angle / wrong / OOB angle detections before banning a client.\n\
        -1 to disable even checking angles (saves cpu), 0 to print to admins/stv but never ban\n\
        (recommended 5)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );

    // cmdnum spike detections
    stac_max_cmdnum_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_cmdnum_detections",
        "20",
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

    // triggerbot detections
    stac_max_tbot_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_tbot_detections",
        "0",
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

    // invalid usercmds
    stac_max_invalid_usercmd_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_invalid_usercmd_detections",
        "5",
        "[StAC] maximum invalid usercmds a client can send before getting banned. This detects poorly coded cheats sending invalid data in their inputs to the server.\n\
        -1 to disable even checking for invalid usercmds (saves cpu), 0 to print to admins/stv but never ban.\n\
        (recommended 5)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
}


void initCvars()
{
    AutoExecConfig_SetFile("stac");
    AutoExecConfig_SetCreateFile(true);


    stac_debug =
    AutoExecConfig_CreateConVar
    (
        "stac_debug",
        "0",
        "[StAC] enable/disable showing verbose info about players' cvars and other similar info in admin and server console\n\
        (recommended 0 unless you want spam in console)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );

    stac_ban_for_misccheats =
    AutoExecConfig_CreateConVar
    (
        "stac_ban_for_misccheats",
        "1",
        "[StAC] ban clients for non usercommand based cheats, aka cheat locked cvars, netprops, invalid names, invalid chat characters, etc.\n\
        (recommended 1)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );

    stac_ban_duration = 
    AutoExecConfig_CreateConVar
    (
        "stac_ban_duration",
        "0",
        "[StAC] ban duration that StAC will use upon banning cheating clients. 0 = permanent.\n\
        (recommended 0)",
        FCVAR_NONE,
        true,
        0.0,
        false,
        _
    );


    stac_optimize_cvars =
    AutoExecConfig_CreateConVar
    (
        "stac_optimize_cvars",
        "1",
        "[StAC] optimize cvars related to patching \"server laggers\", patching backtracking, mostly patching doubletap, limiting fakelag, patching any possible tele expoits, etc.\n\
        (recommended 1)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );

    // min interp
    stac_min_interp_ms =
    AutoExecConfig_CreateConVar
    (
        "stac_min_interp_ms",
        "-1.0",
        "[StAC] minimum interp (lerp) in milliseconds that a client is allowed to have before getting autokicked. set this to -1 to disable having a min interp\n\
        (recommended -1.0, but if you want to enable it, feel free. interp values below 15.1515151 ms don't seem to have any noticable effects on anything meaningful)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );

    // min interp
    stac_max_interp_ms =
    AutoExecConfig_CreateConVar
    (
        "stac_max_interp_ms",
        "101.0",
        "[StAC] maximum interp (lerp) in milliseconds that a client is allowed to have before getting autokicked. set this to -1 to disable having a max interp\n\
        (recommended 101.0)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );

    // min random check secs
    stac_min_randomcheck_secs =
    AutoExecConfig_CreateConVar
    (
        "stac_min_randomcheck_secs",
        "60.0",
        "[StAC] check AT LEAST this often in seconds for clients with violating cvar values/netprops\n\
        (recommended 60)",
        FCVAR_NONE,
        true,
        5.0,
        false,
        _
    );

    // min random check secs
    stac_max_randomcheck_secs =
    AutoExecConfig_CreateConVar
    (
        "stac_max_randomcheck_secs",
        "300.0",
        "[StAC] check AT MOST this often in seconds for clients with violating cvar values/netprops\n\
        (recommended 300)",
        FCVAR_NONE,
        true,
        15.0,
        false,
        _
    );

    stac_include_demoname_in_banreason =
    AutoExecConfig_CreateConVar
    (
        "stac_include_demoname_in_banreason",
        "1",
        "[StAC] enable/disable putting the currently recording demo in the SourceBans / gbans ban reason\n\
        (recommended 1)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );

    stac_log_to_file =
    AutoExecConfig_CreateConVar
    (
        "stac_log_to_file",
        "1",
        "[StAC] enable/disable logging to file\n\
        (recommended 1)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );

    stac_fixpingmasking_enabled =
    AutoExecConfig_CreateConVar
    (
        "stac_fixpingmasking_enabled",
        "1",
        "[StAC] enable fixing clients \"pingmasking\". this also allows StAC to ban cheating clients attempting to reduce their reported ping.\n\
        (recommended 1)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );

    stac_silent =
    AutoExecConfig_CreateConVar
    (
        "stac_silent",
        "0",
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

    // max connections from the same ip
    stac_max_connections_from_ip =
    AutoExecConfig_CreateConVar
    (
        "stac_max_connections_from_ip",
        "0",
        "[StAC] max connections allowed from the same IP address. useful for autokicking bots, though StAC should do that with cvar checks anyway.\n\
        (recommended 0, you should really only enable this if you're getting swarmed by bots, and StAC isn't doing much against them, in which case, consider opening a bug report!)",
        FCVAR_NONE,
        true,
        0.0,
        false,
        _
    );

    stac_work_with_sv_cheats =
    AutoExecConfig_CreateConVar
    (
        "stac_work_with_sv_cheats",
        "0",
        "[StAC] allow StAC to work when sv_cheats is 1. WARNING; you might get false positives, and I will not provide support for servers running this cvar!\n\
        (recommended 0)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );


    initUsercmdCvars();
    // actually exec the cfg after initing cvars lol
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
}


public void GenericCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (configsExecuted && !stac_work_with_sv_cheats.BoolValue && convar == FindConVar("sv_cheats") && StringToInt(newValue) != 0)
    {
        OnPluginEnd();
        SetFailState("[StAC] sv_cheats set to 1! Aborting!");
    }

    // set timescale so we don't ban clients if its not default
    // if (convar == FindConVar("host_timescale"))
    //{
    //    timescale = GetConVarFloat(convar);
    //}

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


void RunOptimizeCvars()
{
    // don't optimize anything if we have high players, let server ops override
    if ( highPlayerServer )
    {
        return;
    }

    // attempt to patch doubletap (CS:GO default value!)
    SetConVarInt(FindConVar("sv_maxusrcmdprocessticks"), 8);

    // force psilent to show up properly
    SetConVarInt(FindConVar("sv_maxusrcmdprocessticks_holdaim"), 1);

    // limit fakelag abuse / backtracking (CS:GO default value!)
    // Note from the future: we DON'T need to do this with our backtrack patch.
    // SetConVarFloat(FindConVar("sv_maxunlag"), 0.2);

    // print dc reasons to clients
    SetConVarBool(FindConVar("net_disconnect_reason"), true);

    // prevent all sorts of exploits involving CNetChan fuzzing etc.
    ConVar net_chan_limit_msec = FindConVar("net_chan_limit_msec");
    // don't override server set settings if they have set it to a value other than 0
    if (GetConVarInt(net_chan_limit_msec) <= 0)
    {
        SetConVarInt(net_chan_limit_msec, 128);
    }

    if (isDefaultTickrate())
    {
        if (GetConVarInt(FindConVar("sv_mincmdrate")) < 30)
        {
            SetConVarInt(FindConVar("sv_mincmdrate"), 30);
        }
        if (GetConVarInt(FindConVar("sv_minupdaterate")) < 30)
        {
            SetConVarInt(FindConVar("sv_minupdaterate"), 30);
        }
        // 65536 = 0.5 mebibits per second
        if (GetConVarInt(FindConVar("sv_minrate")) < 65536)
        {
            SetConVarInt(FindConVar("sv_minrate"), 65536);
        }
    }

    // OVERRIDE this setting
    // There is basically NO situation where you want the client updating FROM the server at a different rate
    // than they are updating the server itself by sending usercmds
    SetConVarInt(FindConVar("sv_client_cmdrate_difference"), 0);

    // fix backtracking
    ConVar jay_backtrack_enable     = FindConVar("jay_backtrack_enable");
    ConVar jay_backtrack_tolerance  = FindConVar("jay_backtrack_tolerance");
    // dont error out on server start
    if ( jay_backtrack_enable && jay_backtrack_tolerance )
    {
        // enable jaypatch
        SetConVarInt(jay_backtrack_enable, 1);
        // set jaypatch to sane value
        SetConVarInt(jay_backtrack_tolerance, 1);
    }

    // there have been several exploits in the past regarding non steam codec
    // this is defensive
    SetConVarString(FindConVar("sv_voicecodec"), "steam");
}
