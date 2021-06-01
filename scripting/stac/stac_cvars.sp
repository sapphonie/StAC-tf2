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
        "[StAC] enable/disable plugin (setting this to 0 immediately unloads stac)",
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
        "[StAC] enable/disable showing verbose info about players' cvars and other similar info in admin console\n(recommended 0 unless you want spam in console)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_verbose_info, setStacVars);

    // turn seconds
    FloatToString(maxAllowedTurnSecs, buffer, sizeof(buffer));
    stac_max_allowed_turn_secs =
    AutoExecConfig_CreateConVar
    (
        "stac_max_allowed_turn_secs",
        buffer,
        "[StAC] maximum allowed time in seconds before client is autokicked for using turn binds (+right/+left inputs). -1 to disable autokicking, 0 instakicks\n(recommended -1.0 unless you're using this in a competitive setting)",
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
        "[StAC] ban clients for non angle based cheats, aka cheat locked cvars, netprops, invalid names, invalid chat characters, etc.\n(defaults to 1)",
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
        "[StAC] optimize cvars related to patching backtracking, mostly patching doubletap, limiting fakelag, patching any possible tele expoits, etc.\n(defaults to 1)",
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
        "[StAC] maximum aimsnap detections before banning a client.\n-1 to disable even checking angles (saves cpu), 0 to print to admins/stv but never ban\n(recommended 25 or higher)",
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
        "[StAC] maximum silent aim/norecoil detections before banning a client.\n-1 to disable even checking angles (saves cpu), 0 to print to admins/stv but never ban\n(recommended 15 or higher)",
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
        "[StAC] maximum consecutive bhop detections on a client before they get \"antibhopped\". client will get banned on this value + 2, so for default cvar settings, client will get banned on 12 tick perfect bhops.\nctrl + f for \"antibhop\" in stac.sp for more detailed info.\n-1 to disable even checking bhops (saves cpu), 0 to print to admins/stv but never ban\n(recommended 10 or higher)",
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
        "[StAC] maximum fake angle / wrong / OOB angle detections before banning a client.\n-1 to disable even checking angles (saves cpu), 0 to print to admins/stv but never ban\n(recommended 10)",
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
        "[StAC] maximum cmdnum spikes a client can have before getting banned. lmaobox does this with nospread on certain weapons, other cheats utilize it for other stuff, like sequence breaking on nullcore etc. legit users should never ever trigger this!\n(recommended 25)",
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
        "[StAC] maximum triggerbot detections before banning a client. This can, has, and will pick up clients using macro software as well as run of the mill cheaters. This check also DOES NOT RUN if the wait command is enabled on your server, as wait allows in-game macroing, making this a nonsensical check in that case.\n(defaults 0 - aka, it never bans, only logs. recommended 20+ if you are comfortable permabanning macroing users)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_tbot_detections, setStacVars);

    // spinbot detections
    IntToString(maxSpinbotDetections, buffer, sizeof(buffer));
    stac_max_spinbot_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_spinbot_detections",
        buffer,
        "[StAC] maximum spinbot detections before banning a client. \n(recommended 50 or higher)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_spinbot_detections, setStacVars);

    // min interp
    IntToString(min_interp_ms, buffer, sizeof(buffer));
    stac_min_interp_ms =
    AutoExecConfig_CreateConVar
    (
        "stac_min_interp_ms",
        buffer,
        "[StAC] minimum interp (lerp) in milliseconds that a client is allowed to have before getting autokicked. set this to -1 to disable having a min interp\n(recommended disabled, but if you want to enable it, feel free. interp values below 15.1515151 ms don't seem to have any noticable effects on anything meaningful)",
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
        "[StAC] maximum interp (lerp) in milliseconds that a client is allowed to have before getting autokicked. set this to -1 to disable having a max interp\n(recommended 101)",
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
        "[StAC] check AT LEAST this often in seconds for clients with violating cvar values/netprops\n(recommended 60)",
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
        "[StAC] check AT MOST this often in seconds for clients with violating cvar values/netprops\n(recommended 300)",
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
        "[StAC] enable/disable putting the currently recording demo in the SourceBans / gbans ban reason\n(recommended 1)",
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
        "[StAC] enable/disable logging to file\n(recommended 1)",
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
        "enable fixing pingmasking? This also allows StAC to ban cheating clients attempting to pingreduce.",
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
        "[StAC] maximum number of times a client can spam userinfo updates (over the course of 10 seconds) before getting banned.\n(recommended 10+)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_cmdrate_spam_detections, setStacVars);


    // kick unauthed clients
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
        "[StAC] kick clients unauthorized with steam? This only checks if steam has been stable and online for at least the past 300 seconds or more.\n(recommended 1)",
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
        "[StAC] If this cvar is 0 (default), StAC will print detections to admins with sm_ban access and to SourceTV, if extant. If this cvar is 1, it will print only to SourceTV. If this cvar is 2, StAC never print anything in chat to anyone, ever. If this cvar is -1, StAC will print ALL detections to ALL players. \n(recommended 0)",
        FCVAR_NONE,
        true,
        -1.0,
        true,
        2.0
    );
    HookConVarChange(stac_silent, setStacVars);

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

    // spinbot var
    maxSpinbotDetections    = GetConVarInt(stac_max_spinbot_detections);

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
}

void GenericCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    // IMMEDIATELY unload if we enable sv cheats
    if (convar == FindConVar("sv_cheats"))
    {
        if (StringToInt(newValue) != 0)
        {
            SetFailState("[StAC] sv_cheats set to 1! Aborting!");
        }
    }
    if (convar == FindConVar("sv_allow_wait_command"))
    {
        if (StringToInt(newValue) != 0)
        {
            waitStatus = true;
        }
    }
}

#define MAX_RATE        (1024*1024)
#define MIN_RATE        1000
// update server rate settings for cmdrate spam check - i'd rather have one func do this lol
void UpdateRates(ConVar convar, const char[] oldValue, const char[] newValue)
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
    // attempt to patch doubletap
    SetConVarInt(FindConVar("sv_maxusrcmdprocessticks"), 16);
    // force psilent to show up properly
    SetConVarInt(FindConVar("sv_maxusrcmdprocessticks_holdaim"), 1);
    // limit fakelag abuse
    SetConVarFloat(FindConVar("sv_maxunlag"), 0.2);
    // fix backtracking
    // dont error out on server start
    ConVar jay_backtrack_enable     = FindConVar("jay_backtrack_enable");
    ConVar jay_backtrack_tolerance  = FindConVar("jay_backtrack_tolerance");
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
