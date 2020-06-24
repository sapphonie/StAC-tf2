// see the readme for more info:
// https://github.com/stephanieLGBT/StAC-tf2/blob/master/README.md
// i love my partners
#pragma semicolon 1

#include <sourcemod>
#include <morecolors>
#include <regex>
#include <sdktools>
#include <tf2_stocks>
#include <autoexecconfig>
#undef REQUIRE_PLUGIN
#include <updater>
#include <sourcebanspp>

#define PLUGIN_VERSION  "3.1.4"
#define UPDATE_URL      "https://raw.githubusercontent.com/stephanieLGBT/StAC-tf2/master/updatefile.txt"

public Plugin myinfo =
{
    name             =  "Steph's AntiCheat (StAC)",
    author           =  "stephanie",
    description      =  "Anticheat plugin [tf2 only] written by Stephanie. Originally forked from IntegriTF2 by Miggy (RIP)",
    version          =   PLUGIN_VERSION,
    url              =  "https://steph.anie.dev/"
}

// TIMER HANDLES
Handle g_hQueryTimer[MAXPLAYERS+1];
Handle g_hTriggerTimedStuffTimer;
// TPS INFO
float tickinterv;
float tps;
// DETECTIONS PER CLIENT
int turnTimes           [MAXPLAYERS+1];
int fovDesired          [MAXPLAYERS+1];
int fakeAngDetects      [MAXPLAYERS+1];
int pSilentDetects      [MAXPLAYERS+1];
//int aimSnapDetects    [MAXPLAYERS+1];
// TIME SINCE LAST ACTION PER CLIENT
float timeSinceSpawn    [MAXPLAYERS+1];
float timeSinceTaunt    [MAXPLAYERS+1];
float timeSinceTeled    [MAXPLAYERS+1];
// STORED ANGLES PER CLIENT
float angCur            [MAXPLAYERS+1]   [2];
float angPrev1          [MAXPLAYERS+1]   [2];
float angPrev2          [MAXPLAYERS+1]   [2];
// STORED VARS FOR INDIVIDUAL CLIENTS
bool playerTaunting     [MAXPLAYERS+1];
float interpFor         [MAXPLAYERS+1] = -1.0;
float interpRatioFor    [MAXPLAYERS+1] = -1.0;
float updaterateFor     [MAXPLAYERS+1] = -1.0;
float REALinterpFor     [MAXPLAYERS+1] = -1.0;
bool userBanQueued      [MAXPLAYERS+1];

// SOURCEBANS BOOL
bool SOURCEBANS;

// CVARS
ConVar stac_enabled;
ConVar stac_verbose_info;
ConVar stac_autoban_enabled;
ConVar stac_max_allowed_turn_secs;
ConVar stac_kick_for_pingmasking;
ConVar stac_max_psilent_detections;
ConVar stac_max_fakeang_detections;
ConVar stac_min_interp_ms;
ConVar stac_max_interp_ms;
ConVar stac_min_randomcheck_secs;
ConVar stac_max_randomcheck_secs;

// VARIOUS DETECTION BOUNDS & CVAR VALUES
bool DEBUG                  = false;
bool autoban                = true;
float maxAllowedTurnSecs    = -1.0;
bool kickForPingMasking     = false;
int maxPsilentDetections    = 15;
int maxFakeAngDetections    = 10;
int min_interp_ms           = -1;
int max_interp_ms           = 101;
// RANDOM CVARS CHECK MIN/MAX BOUNDS (in seconds)
float minRandCheckVal       = 60.0;
float maxRandCheckVal       = 300.0;

// STORED VALUES FOR "sv_client_min/max_interp_ratio" (defaults to -2 for sanity checking)
int minInterpRatio          = -2;
int maxInterpRatio          = -2;
// STORED VALUE FOR IF MAP HAS COMPILED LIGHTING (assume true)
bool compiledVRAD           = true;

// STUFF FOR FUTURE AIMSNAP TEST
// float sensFor[MAXPLAYERS+1] = -1.0;
// float maxSensToCheck = 4.0;

public OnPluginStart()
{
    // check if tf2, unload if not
    if (GetEngineVersion() != Engine_TF2)
    {
        SetFailState("[StAC] This plugin is only supported for TF2! Aborting!");
    }

    // updater
    if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }

    // get rid of any possible exploits by using teleporters and fov
    SetConVarInt(FindConVar("tf_teleporter_fov_start"), 90);
    SetConVarFloat(FindConVar("tf_teleporter_fov_time"), 0.0);
    // reg admin commands
    RegAdminCmd("sm_stac_checkall", ForceCheckAll, ADMFLAG_GENERIC, "Force check all client convars (ALL CLIENTS) for anticheat stuff");
    RegAdminCmd("sm_stac_detections", ShowDetections, ADMFLAG_GENERIC, "Show all current detections on all connected clients");
    // get tick interval - some modded tf2 servers run at >66.7 tick!
    tickinterv = GetTickInterval();
    // reset random server seed
    ActuallySetRandomSeed();
    // grab round start events for calculating tps
    HookEvent("teamplay_round_start", eRoundStart);
    // grab player spawns
    HookEvent("player_spawn", ePlayerSpawned);
    // grab player teleports
    HookEvent("player_teleported", ePlayerTeled);
    // grab player name changes
    HookEvent("player_changename", ePlayerChangedName, EventHookMode_Pre);
    // check sourcebans capibility
    CreateTimer(2.0, checkSourceBans);
    // check EVERYONE's cvars on plugin reload
    CreateTimer(3.0, checkEveryone);
    // hook interp ratio cvars
    minInterpRatio = GetConVarInt(FindConVar("sv_client_min_interp_ratio"));
    maxInterpRatio = GetConVarInt(FindConVar("sv_client_max_interp_ratio"));
    compiledVRAD   = !GetConVarBool(FindConVar("mat_fullbright"));
    if  (GetConVarBool(FindConVar("sv_cheats")))
    {
        LogMessage("[StAC] sv_cheats set to 1 - unloading plugin!!!");
        ServerCommand("sm plugins unload stac");
    }
    HookConVarChange(FindConVar("sv_client_min_interp_ratio"), GenericCvarChanged);
    HookConVarChange(FindConVar("sv_client_max_interp_ratio"), GenericCvarChanged);
    HookConVarChange(FindConVar("mat_fullbright"), GenericCvarChanged);
    // hook sv_cheats so we can instantly unload if cheats get turned on
    HookConVarChange(FindConVar("sv_cheats"), GenericCvarChanged);
    // Create ConVars for adjusting settings
    initCvars();
    // load translations
    LoadTranslations("stac.phrases.txt");
    LogMessage("[StAC] Plugin vers. ---- %s ---- loaded", PLUGIN_VERSION);
}

initCvars()
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
    HookConVarChange(stac_enabled, stacVarChanged);
    // verbose mode
    if (DEBUG)
    {
        buffer = "1";
    }
    else if (!DEBUG)
    {
        buffer = "0";
    }
    stac_verbose_info =
    AutoExecConfig_CreateConVar
    (
        "stac_verbose_info",
        buffer,
        "[StAC] enable/disable  showing verbose info about players' cvars and other similar info in admin console\n(recommended 0 unless you want spam in console)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_verbose_info, stacVarChanged);
    // autoban
    if (autoban)
    {
        buffer = "1";
    }
    else if (!autoban)
    {
        buffer = "0";
    }
    stac_autoban_enabled =
    AutoExecConfig_CreateConVar
    (
        "stac_autoban_enabled",
        buffer,
        "[StAC] enable/disable autobanning for anything at all\n(recommended 1 - THIS IS A DEBUG CVAR FOR TESTING THINGS - 0 IS FOR DEBUGGING ONLY and ban messages will still get printed to chat!\nset detection cvars to -1 to sanely disable banning instead!!)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_autoban_enabled, stacVarChanged);
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
    HookConVarChange(stac_max_allowed_turn_secs, stacVarChanged);
    // pingmasking
    if (kickForPingMasking)
    {
        buffer = "1";
    }
    else if (!kickForPingMasking)
    {
        buffer = "0";
    }
    stac_kick_for_pingmasking =
    AutoExecConfig_CreateConVar
    (
        "stac_kick_for_pingmasking",
        buffer,
        "[StAC] kick clients for masking their ping with nonnumerical characters in their cl_cmdrate cvar\n(defaults to 0)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_kick_for_pingmasking, stacVarChanged);
    // psilent detections
    IntToString(maxPsilentDetections, buffer, sizeof(buffer));
    stac_max_psilent_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_psilent_detections",
        buffer,
        "[StAC] maximum silent aim/norecoil detecions before banning a client. -1 to disable\n(recommended 15 or higher)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_psilent_detections, stacVarChanged);
    // fakeang detections
    IntToString(maxFakeAngDetections, buffer, sizeof(buffer));
    stac_max_fakeang_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_fakeang_detections",
        buffer,
        "[StAC] maximum fake angle / wrong / OOB angle detecions before banning a client. -1 to disable\n(recommended 10)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_fakeang_detections, stacVarChanged);
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
    HookConVarChange(stac_min_interp_ms, stacVarChanged);
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
    HookConVarChange(stac_max_interp_ms, stacVarChanged);
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
    HookConVarChange(stac_min_randomcheck_secs, stacVarChanged);
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
    HookConVarChange(stac_max_randomcheck_secs, stacVarChanged);

    // actually exec the cfg after initing cvars lol
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
    setStacVars();
}

stacVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    // this regrabs all cvar values but it's neater than having two similar functions that do the same thing
    setStacVars();
}

setStacVars()
{
    // now covers late loads
    // enabled var
    if (!GetConVarBool(stac_enabled))
    {
        LogMessage("[StAC] stac_enabled is set to 0 - unloading plugin!!!");
        ServerCommand("sm plugins unload stac");
    }
    // verbose info var
    DEBUG = GetConVarBool(stac_verbose_info);
    // autoban
    autoban = GetConVarBool(stac_autoban_enabled);
    // turn seconds var
    maxAllowedTurnSecs = GetConVarFloat(stac_max_allowed_turn_secs);
    if (maxAllowedTurnSecs < 0.0 && maxAllowedTurnSecs != -1.0)
    {
        maxAllowedTurnSecs = 0.0;
    }
    // pingmasking var
    kickForPingMasking = GetConVarBool(stac_kick_for_pingmasking);
    // psilent var - clamp to -1 if 0
    maxPsilentDetections = GetConVarInt(stac_max_psilent_detections);
    if (maxPsilentDetections == 0)
    {
        maxPsilentDetections = -1;
    }
    // fakeang var - clamp to -1 if 0
    maxFakeAngDetections = GetConVarInt(stac_max_fakeang_detections);
    if (maxFakeAngDetections == 0)
    {
        maxFakeAngDetections = -1;
    }
    // minterp var - clamp to -1 if 0
    min_interp_ms = GetConVarInt(stac_min_interp_ms);
    if (min_interp_ms == 0)
    {
        min_interp_ms = -1;
    }
    // maxterp var - clamp to -1 if 0
    max_interp_ms = GetConVarInt(stac_max_interp_ms);
    if (max_interp_ms == 0)
    {
        max_interp_ms = -1;
    }
    // min check sec var
    minRandCheckVal = GetConVarFloat(stac_min_randomcheck_secs);
    // max check sec var
    maxRandCheckVal = GetConVarFloat(stac_max_randomcheck_secs);
}

GenericCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == FindConVar("sv_client_min_interp_ratio"))
    {
        minInterpRatio = StringToInt(newValue);
    }
    else if (convar == FindConVar("sv_client_min_interp_ratio"))
    {
        maxInterpRatio = StringToInt(newValue);
    }
    else if (convar == FindConVar("mat_fullbright"))
    {
        if (StringToInt(newValue) != 0)
        {
            compiledVRAD = false;
        }
        else
        {
            compiledVRAD = true;
        }
    }
    // IMMEDIATELY unload if we enable sv cheats
    else if (convar == FindConVar("sv_cheats"))
    {
        if (StringToInt(newValue) != 0)
        {
            LogMessage("[StAC] sv_cheats set to 1 - unloading plugin!!!");
            ServerCommand("sm plugins unload stac");
        }
    }
}

public Action checkSourceBans(Handle timer)
{
    if (GetFeatureStatus(FeatureType_Native, "SBPP_BanPlayer") == FeatureStatus_Available)
    {
        SOURCEBANS = true;
        if (DEBUG)
        {
            LogMessage("[StAC] Sourcebans detected! Using Sourcebans as default ban handler.");
        }
    }
    else
    {
        SOURCEBANS = false;
        if (DEBUG)
        {
            LogMessage("[StAC] No Sourcebans installation detected! Using TF2's default ban handler.");
        }
    }
}

public Action checkEveryone(Handle timer)
{
    ForceCheckAll(0, 0);
}

public Action ShowDetections(int callingCl, int args)
{
    ReplyToCommand(callingCl, "[StAC] == CURRENT DETECTIONS == ");
    for (int Cl = 0; Cl < MaxClients + 1; Cl++)
    {
        if (IsValidClient(Cl))
        {
            if  (
                    turnTimes[Cl] >= 1
                     || pSilentDetects[Cl] >= 1
                     || fakeAngDetects[Cl] >= 1
                )
            {
                ReplyToCommand(callingCl, "Detections for %L", Cl);
                if (turnTimes[Cl] >= 1)
                {
                    ReplyToCommand(callingCl, "- %i turnTimes (frames) for %N", turnTimes[Cl], Cl);
                }
                if (pSilentDetects[Cl] >= 1)
                {
                    ReplyToCommand(callingCl, "- %i pSilentDetects for %N", pSilentDetects[Cl], Cl);
                }
                if (fakeAngDetects[Cl] >= 1)
                {
                    ReplyToCommand(callingCl, "- %i fakeAngDetects for %N", fakeAngDetects[Cl], Cl);
                }
            }
        }
    }
    ReplyToCommand(callingCl, "[StAC] == END DETECTIONS == ");
}

public OnPluginEnd()
{
    NukeTimers();
    OnMapEnd();
    LogMessage("[StAC] Plugin unloaded");
}

// reseed random server seed to help prevent certain nospread stuff from working (probably)
ActuallySetRandomSeed()
{
    int seed = GetURandomInt();
    if (DEBUG)
    {
        LogMessage("[StAC] setting random server seed to %i", seed);
    }
    SetRandomSeed(seed);
}

// NUKE the client timers from orbit on plugin and map reload
NukeTimers()
{
    for (int Cl = 0; Cl < MaxClients + 1; Cl++)
    {
        if (g_hQueryTimer[Cl] != null)
        {
            if (DEBUG)
            {
                LogMessage("[StAC] Destroying timer for %L", Cl);
            }
            KillTimer(g_hQueryTimer[Cl]);
            g_hQueryTimer[Cl] = null;
        }
    }
    if (g_hTriggerTimedStuffTimer != null)
    {
        if (DEBUG)
        {
            LogMessage("[StAC] Destroying reseeding timer");
        }
        KillTimer(g_hTriggerTimedStuffTimer);
        g_hTriggerTimedStuffTimer = null;
    }
}

// recreate the timers we just nuked
ResetTimers()
{
    for (int Cl = 0; Cl < MaxClients + 1; Cl++)
    {
    if (IsValidClient(Cl))
        {
            if (DEBUG)
            {
                LogMessage("[StAC] Creating timer for %L", Cl);
            }
            g_hQueryTimer[Cl] = CreateTimer(GetRandomFloat(minRandCheckVal, maxRandCheckVal), Timer_CheckClientConVars, GetClientUserId(Cl));
        }
    }
    // create timer to reset seed every 15 mins
    g_hTriggerTimedStuffTimer = CreateTimer(900.0, timer_TriggerTimedStuff, _, TIMER_REPEAT);
}

public Action eRoundStart(Handle event, char[] name, bool dontBroadcast)
{
    DoTPSMath();
    // might as well do this here!
    ActuallySetRandomSeed();
}

public Action ePlayerSpawned(Handle event, char[] name, bool dontBroadcast)
{
    int Cl = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsValidClient(Cl))
    {
        timeSinceSpawn[Cl] = GetEngineTime();
    }
}

public Action ePlayerTeled(Handle event, char[] name, bool dontBroadcast)
{
    int Cl = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsValidClient(Cl))
    {
        timeSinceTeled[Cl] = GetEngineTime();
    }
}

public Action ePlayerChangedName(Handle event, char[] name, bool dontBroadcast)
{
    int userid = GetEventInt(event, "userid");
    NameCheck(userid);
}

public TF2_OnConditionAdded(int Cl, TFCond condition)
{
    if (IsValidClient(Cl))
    {
        if (condition == TFCond_Taunting)
        {
            playerTaunting[Cl] = true;
        }
    }
}

public TF2_OnConditionRemoved(int Cl, TFCond condition)
{
    if (IsValidClient(Cl))
    {
        if (condition == TFCond_Taunting)
        {
            timeSinceTaunt[Cl] = GetEngineTime();
            playerTaunting[Cl] = false;
        }
    }
}

public Action timer_TriggerTimedStuff(Handle timer)
{
    ActuallySetRandomSeed();
}

// set stuff for tps based checking here.
DoTPSMath()
{
    tickinterv    = GetTickInterval();
    tps           = Pow(tickinterv, -1.0);
    if (DEBUG)
    {
        LogMessage("tickinterv %f tps %f", tickinterv, tps);
    }
}

public OnMapStart()
{
    ActuallySetRandomSeed();
    DoTPSMath();
    ResetTimers();
}

public OnMapEnd()
{
    ActuallySetRandomSeed();
    DoTPSMath();
    NukeTimers();
}

public OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}

ClearClBasedVars(userid)
{
    // get fresh cli id
    int Cl = GetClientOfUserId(userid);
    // clear all old values for cli id based stuff
    turnTimes[Cl]      = 0;
    pSilentDetects[Cl] = 0;
    fakeAngDetects[Cl] = 0;
//  aimSnapDetects[Cl] = 0;
    timeSinceSpawn[Cl] = 0.0;
    timeSinceTaunt[Cl] = 0.0;
    timeSinceTeled[Cl] = 0.0;
    interpFor[Cl]      = -1.0;
    interpRatioFor[Cl] = -1.0;
    updaterateFor[Cl]  = -1.0;
    REALinterpFor[Cl]  = -1.0;
    userBanQueued[Cl] = false;
}

public OnClientPostAdminCheck(Cl)
{
    if (IsValidClient(Cl))
    {
        int userid = GetClientUserId(Cl);
        // clear per client values
        ClearClBasedVars(userid);
        // clear timer
        g_hQueryTimer[Cl] = null;
        // query convars on player connect
        if (DEBUG)
        {
            LogMessage("[StAC] %N joined. Checking cvars", Cl);
        }
        g_hQueryTimer[Cl] = CreateTimer(0.01, Timer_CheckClientConVars, userid);
    }
}

public OnClientDisconnect(Cl)
{
    int userid = GetClientUserId(Cl);
    // clear per client values
    ClearClBasedVars(userid);
    if (g_hQueryTimer[Cl] != null)
    {
        KillTimer(g_hQueryTimer[Cl]);
        g_hQueryTimer[Cl] = null;
    }
}

public Action ForceCheckAll(int client, int args)
{
    QueryEverythingAllClients();
    ReplyToCommand(client, "[StAC] Checking cvars on all clients.");
}

/*
in OnPlayerRunCmd, we check for:
- SILENT AIM
- FAKE ANGLES
- TURN BINDS
- (EVENTUALLY) AIM SNAPS
*/
public Action OnPlayerRunCmd
    (
        int Cl,
        int& buttons,
        int& impulse,
        float vel[3],
        float angles[3],
        int& weapon,
        int& subtype,
        int& cmdnum,
        int& tickcount,
        int& seed,
        int mouse[2]
    )
{
    // grab current time to compare to time since last spawn/taunt/tele
    float engineTime = GetEngineTime();
    if  (
            // make sure client is real, not a bot, on a team, AND didnt spawn, taunt, or teleport in the last .1 seconds AND isnt taunting AND isn't already queued to be banned
            IsValidClient(Cl)
             && IsClientPlaying(Cl)
             && !playerTaunting[Cl]
             && engineTime - 0.1 > timeSinceSpawn[Cl]
             && engineTime - 0.1 > timeSinceTaunt[Cl]
             && engineTime - 0.1 > timeSinceTeled[Cl]
             && !userBanQueued[Cl]
        )
    {
        // we need this later for decrimenting psilent and fakeang detections after 20 minutes!
        int userid = GetClientUserId(Cl);

        // grab angles (probably expensive but who cares)
        // thanks to nosoop from the sm discord for some help with this
        angPrev2[Cl][0] = angPrev1[Cl][0];
        angPrev2[Cl][1] = angPrev1[Cl][1];
        angPrev1[Cl][0] = angCur[Cl][0];
        angPrev1[Cl][1] = angCur[Cl][1];
        angCur[Cl][0]   = angles[0];
        angCur[Cl][1]   = angles[1];
        /*
            SILENT AIM DETECTION
            silent aim works by aimbotting for 1 frame and then snapping your viewangle back to what it was
            example snap:
                L 03/25/2020 - 06:03:50: [stac.smx] [StAC] pSilent detection: curang angles: x 5.120096 y 9.763162
                L 03/25/2020 - 06:03:50: [stac.smx] [StAC] pSilent detection: prev1  angles: x 1.635611 y 12.876886
                L 03/25/2020 - 06:03:50: [stac.smx] [StAC] pSilent detection: prev2  angles: x 5.120096 y 9.763162
            we can just look for these snaps and log them as detections!
            note that this won't detect some snaps when a player is moving their strafe keys and mouse @ the same time while they are aimlocking.
            i'll *try* to work mouse movement into this function at SOME point but it works reasonably well for right now.
        */
        if
        (
            // so the current and 2nd previous angles match...
            (
                angCur[Cl][0] == angPrev2[Cl][0]
                 &&
                angCur[Cl][1] == angPrev2[Cl][1]
            )
            &&
            // BUT the 1st previous (in between) angle doesnt?
            (
                angPrev1[Cl][0]     != angCur[Cl][0]
                 && angPrev1[Cl][1] != angCur[Cl][1]
                 && angPrev1[Cl][0] != angPrev2[Cl][0]
                 && angPrev1[Cl][1] != angPrev2[Cl][1]
            )
            &&
            // make sure we dont get any fake detections on startup (might not really be needed? but just in case)
            // this also ignores weird angle resets in mge / dm
            (
                angCur[Cl][0]       != 0.000000
                 && angCur[Cl][1]   != 0.000000
                 && angPrev1[Cl][0] != 0.000000
                 && angPrev1[Cl][1] != 0.000000
                 && angPrev2[Cl][0] != 0.000000
                 && angPrev2[Cl][1] != 0.000000
            )
        )
        /*
            ok - lets make sure there's a difference of at least 1 degree on either axis to avoid most fake detections
            these are probably caused by packets arriving out of order but i'm not a fucking network engineer (yet) so idk
            examples of fake detections we want to avoid:
                03/25/2020 - 18:18:11: [stac.smx] [StAC] pSilent detection on [redacted]: curang angles: x 14.871331 y 154.979812
                03/25/2020 - 18:18:11: [stac.smx] [StAC] pSilent detection on [redacted]: prev1  angles: x 14.901910 y 155.010391
                03/25/2020 - 18:18:11: [stac.smx] [StAC] pSilent detection on [redacted]: prev2  angles: x 14.871331 y 154.979812
            and
                03/25/2020 - 22:16:36: [stac.smx] [StAC] pSilent detection on [redacted2]: curang angles: x 21.516006 y -140.723709
                03/25/2020 - 22:16:36: [stac.smx] [StAC] pSilent detection on [redacted2]: prev1  angles: x 21.560007 y -140.943710
                03/25/2020 - 22:16:36: [stac.smx] [StAC] pSilent detection on [redacted2]: prev2  angles: x 21.516006 y -140.723709
            doing this might make it harder to detect legitcheaters but like. legitcheating in a 12 yr old dead game OMEGALUL who fucking cares
        */
        {
            // actual angle calculation here
            float aDiffReal = CalcAngDeg(angCur[Cl], angPrev1[Cl]);

            // refactored from smac - make sure we don't fuck up angles near the x/y axes!
            if (aDiffReal > 180.0)
            {
                aDiffReal = FloatAbs(aDiffReal - 360.0);
            }
            // needs to be more than a degree
            if (aDiffReal >= 1.0)
            {
                pSilentDetects[Cl]++;
                // have this detection expire in 20 minutes
                CreateTimer(1200.0, Timer_decr_pSilent, userid);
                // print a bunch of bullshit
                PrintToImportant("{hotpink}[StAC]{white} pSilent / NoRecoil detection of {yellow}%.2f{white}° on %N.\nDetections so far: {palegreen}%i", aDiffReal, Cl,  pSilentDetects[Cl]);
                PrintToImportant("|----- curang angles: x %f y %f", angCur[Cl][0], angCur[Cl][1]);
                PrintToImportant("|----- prev 1 angles: x %f y %f", angPrev1[Cl][0], angPrev1[Cl][1]);
                PrintToImportant("|----- prev 2 angles: x %f y %f", angPrev2[Cl][0], angPrev2[Cl][1]);
                // BAN USER if they trigger too many detections
                if (pSilentDetects[Cl] >= maxPsilentDetections && maxPsilentDetections != -1)
                {
                    char reason[256];
                    Format(reason, sizeof(reason), "%t", "pSilentBanMsg", Cl, pSilentDetects[Cl]);
                    BanUser(userid, reason);
                    CPrintToChatAll("%t", "pSilentBanAllChat", Cl, pSilentDetects[Cl]);
                    LogMessage("%t", "pSilentBanMsg", Cl, pSilentDetects[Cl]);
                }
            }
        }
        /*
            BASIC AIMSNAP TEST (not currently hooked up)
        */
        /*
        PrintToServer("raw : x %f y %f", angCur[Cl][0], angCur[Cl][1]);
        if  (
                // ignore stupidly high sens players
                // technically can be spoofed but also it would be annoying for the cheater
                (
                    // def "max sens" is 4
                    sensFor[Cl] < maxSensToCheck
                     &&
                    sensFor[Cl] != -1.0
                )
                &&
                (
                    // hopefully detect snaps of over 10.0 degrees
                    FloatAbs(FloatAbs(angCur[Cl][0]) - FloatAbs(angPrev1[Cl][0])) > 10.0 ||
                    FloatAbs(FloatAbs(angCur[Cl][1]) - FloatAbs(angPrev1[Cl][1])) > 10.0
                )
                &&
                // ignore angle resets
                (
                    angCur[Cl][0]   != 0.000000 &&
                    angCur[Cl][1]   != 0.000000 &&
                    angPrev1[Cl][0] != 0.000000 &&
                    angPrev1[Cl][1] != 0.000000 &&
                    angPrev2[Cl][0] != 0.000000 &&
                    angPrev2[Cl][1] != 0.000000
                )
            )
        {
            // check if we hit a player here
            //if (ClDidHitPlayer(Cl))
            //// maybe use TR_DidHit ? i dont know
            //{
                aimSnapDetects[Cl]++;
                PrintToChatAll("aimSnapDetects = %i", aimSnapDetects[Cl]);
                CPrintToChatAll("[StAC] snap %f d on %N: curang angles: x %f y %f", (FloatAbs(angCur[Cl][0] - angPrev1[Cl][0])), Cl, angCur[Cl][0], angCur[Cl][1]);
                CPrintToChatAll("[StAC] snap      on %N: prev1  angles: x %f y %f", Cl, angPrev1[Cl][0], angPrev1[Cl][1]);
                CPrintToChatAll("[StAC] snap      on %N: prev2  angles: x %f y %f", Cl, angPrev2[Cl][0], angPrev2[Cl][1]);
                CPrintToChatAll("[StAC] mouse movement at time of snap: mouse x %i, y %i",   IntAbs(mouse[0]), IntAbs(mouse[1]));
            //}
        }

*/

        /*
            EYE ANGLES TEST
            if clients are outside of allowed angles in tf2, which are
              +/- 89.0 x (up / down)
              +/- 180 y (left / right, but we don't check this atm because there's things that naturally fuck up y angles)
              +/- 50 z (roll / tilt)
            while they are not in spec & on a map camera, we should log it.
            we would fix it but cheaters can just ignore server-enforced viewangle changes so there's no point

            these bounds were lifted from lilac. Thanks lilac
        */
        if  (
                (
                     angles[0]    < -89.01
                     || angles[0] > 89.01
                     || angles[2] < -50.01
                     || angles[2] > 50.01
                )
            )
        {
            fakeAngDetects[Cl]++;
            PrintToImportant("{hotpink}[StAC]{white} Player %N has {mediumpurple}invalid eye angles{white}!\nCurrent angles: {mediumpurple}%.2f %.2f %.2f{white}.\nDetections so far: {palegreen}%i", Cl, angles[0], angles[1], angles[2], fakeAngDetects[Cl]);
            LogMessage("[StAC] Player %N has invalid eye angles! Current angles: %.2f %.2f %.2f Detections so far: %i", Cl, angles[0], angles[1], angles[2], fakeAngDetects[Cl]);
            if (fakeAngDetects[Cl] >= maxFakeAngDetections && maxFakeAngDetections != -1)
            {
                char reason[256];
                Format(reason, sizeof(reason), "%t", "fakeangBanMsg", Cl, fakeAngDetects[Cl]);
                BanUser(userid, reason);
                CPrintToChatAll("%t", "fakeangBanAllChat", Cl, fakeAngDetects[Cl]);
                LogMessage( "%t", "fakeangBanMsg", Cl, fakeAngDetects[Cl]);
            }
        }
        /*
            TURN BIND TEST
        */
        if (buttons & IN_LEFT || buttons & IN_RIGHT)
        {
            if (maxAllowedTurnSecs != -1.0)
            {
                turnTimes[Cl]++;
                float turnSec = turnTimes[Cl] * tickinterv;
                PrintToImportant("%t", "turnbindAdminMsg", Cl, turnSec);
                if (turnSec < maxAllowedTurnSecs)
                {
                    CPrintToChat(Cl, "%t", "turnbindWarnPlayer");
                }
                else if (turnSec >= maxAllowedTurnSecs)
                {
                    KickClient(Cl, "%t", "turnbindKickMsg");
                    LogMessage("%t", "turnbindLogMsg", Cl);
                    CPrintToChatAll("%t", "turnbindAllChat", Cl);
                }
            }
        }
    }
}

public Action Timer_decr_pSilent(Handle timer, any userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        if (pSilentDetects[Cl] > 0)
        {
            pSilentDetects[Cl]--;
        }
    }
}

char cvarsToCheck[][] =
{
    // misc vars
    // "sensitivity"
    // possible cheat vars
    "cl_interpolate",
    "r_drawothermodels",
    "fov_desired",
    "mat_fullbright",
    "cl_thirdperson",
    // network cvars
    "cl_interp",
    "cl_cmdrate",
    "cl_interp_ratio",
    "cl_updaterate",
};

public ConVarCheck(QueryCookie cookie, int Cl, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
    // don't bother checking bots or users who already queued to be banned or anyone if cheats are enabled
    if (!IsValidClient(Cl) || userBanQueued[Cl])
    {
        return;
    }
    int userid = GetClientUserId(Cl);
    // log something about cvar errors xcept for cheat only cvars
    if (result != ConVarQuery_Okay)
    {
        PrintToImportant("{hotpink}[StAC]{white} Could not query CVar %s on Player %N", Cl);
        LogMessage("[StAC] Could not query CVar %s on Player %N", cvarName, Cl);
    }
    /*
        POSSIBLE CHEAT VARS
    */
    // cl_interpolate (hidden cvar! should NEVER not be 1)
    if (StrEqual(cvarName, "cl_interpolate"))
    {
        if (StringToInt(cvarValue) != 1)
        {
            char reason[256];
            Format(reason, sizeof(reason), "%t", "nolerpBanMsg", Cl);
            BanUser(userid, reason);
            CPrintToChatAll("%t", "nolerpBanAllChat", Cl);
            LogMessage("%t", "nolerpBanMsg", Cl);
        }
    }
    // r_drawothermodels (if u get banned by this you are a clown)
    else if (StrEqual(cvarName, "r_drawothermodels"))
    {
        if (StringToInt(cvarValue) != 1)
        {
            char reason[256];
            Format(reason, sizeof(reason), "%t", "othermodelsBanMsg", Cl);
            BanUser(userid, reason);
            CPrintToChatAll("%t", "othermodelsBanAllChat", Cl);
            LogMessage("%t", "othermodelsBanMsg", Cl);
        }
    }
    // fov check #1 (if u get banned by this you are a clown)
    else if (StrEqual(cvarName, "fov_desired"))
    {
        // save fov to var to reset later with netpropcheck
        fovDesired[Cl] = StringToInt(cvarValue);
        if (StringToInt(cvarValue) > 90)
        {
            char reason[256];
            Format(reason, sizeof(reason), "%t", "fovBanMsg", Cl);
            BanUser(userid, reason);
            CPrintToChatAll("%t", "fovBanAllChat", Cl);
            LogMessage("%t", "fovBanMsg", Cl);
        }
    }
    // mat_fullbright
    if (StrEqual(cvarName, "mat_fullbright"))
    {
        // can only ever be 0 unless you're cheating or on a map with uncompiled lighting so check for both of these
        if (StringToInt(cvarValue) != 0 && compiledVRAD)
        {
            char reason[256];
            Format(reason, sizeof(reason), "%t", "fullbrightBanMsg", Cl);
            BanUser(userid, reason);
            CPrintToChatAll("%t", "fovBanAllChat", Cl);
            LogMessage("%t", "fullbrightBanMsg", Cl);
        }
    }
    // thirdperson (hidden cvar)
    else if (StrEqual(cvarName, "cl_thirdperson"))
    {
        if (StringToInt(cvarValue) != 0)
        {
            char reason[256];
            Format(reason, sizeof(reason), "%t", "tpBanMsg", Cl);
            BanUser(userid, reason);
            CPrintToChatAll("%t", "tpBanAllChat", Cl);
            LogMessage("%t", "tpBanMsg", Cl);
        }
    }
    /*
        NETWORK CVARS
    */
    // cl_interp
    else if (StrEqual(cvarName, "cl_interp"))
    {
        interpFor[Cl] = StringToFloat(cvarValue);
    }
    // cl_cmdrate
    else if (StrEqual(cvarName, "cl_cmdrate"))
    {
        if (!kickForPingMasking)
        {
            return;
        }
        if (!cvarValue[0])
        {
            LogMessage("[StAC] Null string returned as cvar result when querying cvar %s on %N", cvarName, Cl);
            PrintToImportant("{hotpink}[StAC]{white} Null string returned as cvar result when querying cvar %s on %N", cvarName, Cl);
        }
        // cl_cmdrate needs to not have any non numerical chars (xcept the . sign if its a float) in it because otherwise player ping gets messed up on the scoreboard
        else if (SimpleRegexMatch(cvarValue, "^\\d*\\.?\\d*$") <= 0)
        {
            KickClient(Cl, "%t", "pingmaskingKickMsg", cvarValue);
            LogMessage("%t", "pingmaskingLogMsg", Cl, cvarValue);
            CPrintToChatAll("%t", "pingmaskingAllChat", Cl, cvarValue);
        }
    }
    // cl_interp_ratio
    else if (StrEqual(cvarName, "cl_interp_ratio"))
    {
        // we have to clamp interp ratio to make sure we're getting the "real" client interp
        // https://github.com/TheAlePower/TeamFortress2/blob/1b81dded673d49adebf4d0958e52236ecc28a956/tf2_src/game/server/gameinterface.cpp#L2845
        interpRatioFor[Cl] = StringToFloat(cvarValue);
        if (interpRatioFor[Cl] == 0.0)
        {
            interpRatioFor[Cl] = 1.0;
        }
        if (minInterpRatio && maxInterpRatio && float(minInterpRatio) != -1)
        {
            interpRatioFor[Cl] = Math_Clamp(interpRatioFor[Cl], float(minInterpRatio), float(maxInterpRatio));
        }
        else
        {
            if (interpRatioFor[Cl] == 0.0)
            {
                interpRatioFor[Cl] = 1.0;
            }
        }
    }
    // cl_updaterate
    else if (StrEqual(cvarName, "cl_updaterate"))
    {
        updaterateFor[Cl] = StringToFloat(cvarValue);
        // calculate real lerp here
        REALinterpFor[Cl] = (fMax(interpFor[Cl], interpRatioFor[Cl] / updaterateFor[Cl])) * 1000;
        if (DEBUG)
        {
            LogMessage("%f ms interp on %N", REALinterpFor[Cl], Cl);
        }
        // don't bother actually doing anything about lerp if tickrate isnt default
        if (tps < 70.0 && tps > 60.0)
        {
            if  (
                    REALinterpFor[Cl] < min_interp_ms && min_interp_ms != -1
                     ||
                    REALinterpFor[Cl] > max_interp_ms && max_interp_ms != -1
                )
            {
                KickClient(Cl, "%t", "interpKickMsg", REALinterpFor[Cl], min_interp_ms, max_interp_ms);
                LogMessage("%t", "interpLogMsg",  Cl, REALinterpFor[Cl]);
                CPrintToChatAll("%t", "interpAllChat", Cl, REALinterpFor[Cl]);
            }
        }
    }
    /*  will be used later for aimsnap checking
        else if (StrEqual(cvarName, "sensitivity"))
    {
        sensFor[Cl] = StringToFloat(cvarValue);
        //PrintToChatAll("Client %N's sens is %f", Cl, sensFor[Cl]);
        // min bounds is actually .000100 so
        if (StringToFloat(cvarValue) < 0.000100)
        // do somethin about it!
        {
        //
        }
    }
    */
    if (DEBUG)
    {
        LogMessage("[StAC] Checked cvar %s value %s on %N", cvarName, cvarValue, Cl);
        PrintToConsoleAllAdmins("[StAC] Checked cvar %s value %s on %N", cvarName, cvarValue, Cl);
    }
}

// ban on invalid characters (newlines, carriage returns, etc)
public Action OnClientSayCommand(int Cl, const char[] command, const char[] sArgs)
{
    if  (
            StrContains(sArgs, "\n", false) != -1
             ||
            StrContains(sArgs, "\r", false) != -1
        )
    {
        int userid = GetClientUserId(Cl);
        char reason[256];
        Format(reason, sizeof(reason), "%t", "newlineBanMsg", Cl);
        BanUser(userid, reason);
        CPrintToChatAll("%t", "newlineBanAllChat", Cl);
        LogMessage("%t", "newlineBanMsg", Cl);
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

public BanUser(userid, char[] reason)
{
    if (!autoban)
    {
        CPrintToChatAll("{hotpink}[StAC]{white} Autoban cvar set to 0. Not banning!");
        return;
    }
    int Cl = GetClientOfUserId(userid);
    if (userBanQueued[Cl])
    {
        return;
    }
    if (SOURCEBANS)
    {
        SBPP_BanPlayer(0, Cl, 0, reason);
        userBanQueued[Cl] = true;
    }
    else
    {
        BanClient(Cl, 0, BANFLAG_AUTO, reason, reason, _, _);
        userBanQueued[Cl] = true;
    }
}

NameCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if (IsValidClient(Cl))
    {
        char curName[64];
        GetClientName(Cl, curName, sizeof(curName));
        // ban for invalid characters in names
        if (
            // nullcore uses \xE0\xB9\x8A for namestealing but you can put it in your steam name so we cant check for it
            // might look into kicking for combining chars but who honestly cares
            // apparently other cheats use these:
            // thanks pazer
            StrContains(curName, "\xE2\x80\x8F", false)     != -1
             || StrContains(curName, "\xE2\x80\x8E", false) != -1
            // cathook uses this
             || StrContains(curName, "\x1B", false)         != -1
            // just in case
             || StrContains(curName, "\n", false)           != -1
             || StrContains(curName, "\r", false)           != -1
            )
        {
            char reason[256];
            Format(reason, sizeof(reason), "%t", "illegalNameBanMsg", Cl);
            BanUser(userid, reason);
            CPrintToChatAll("%t", "illegalNameBanAllChat", Cl);
            LogMessage("%t", "illegalNameBanMsg", Cl);
        }
    }
}

// todo- try GetClientModel for detecting possible chams? don't think that would work though as you can't check client's specific models for other things afaik
NetPropCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        // not a net prop. Whatever though.
        NameCheck(userid);
        // set real fov from client here - overrides cheat values (mostly works with ncc, untested on others)
        // we don't want to touch fov if a client is zoomed in while sniping...
        if (!TF2_IsPlayerInCondition(Cl, TFCond_Zoomed))
        {
            SetEntProp(Cl, Prop_Send, "m_iFOV", fovDesired[Cl]);
        }
        // forcibly disables thirdperson with some cheats
        ClientCommand(Cl, "firstperson");
        if (DEBUG)
        {
            LogMessage("[StAC] Executed firstperson command on Player %N", Cl);
            PrintToConsoleAllAdmins("[StAC] Executed firstperson command on Player %N", Cl);
        }
        // lerp check (again). this time we check the netprop. Just in case.
        //if (tps < 70.0 && tps > 60.0)
        //{
        //    float lerp = GetEntPropFloat(Cl, Prop_Data, "m_fLerpTime") * 1000;
        //    if  (
        //            lerp < min_interp_ms && min_interp_ms != -1
        //             ||
        //            lerp > max_interp_ms && max_interp_ms != -1
        //        )
        //    {
        //        KickClient(Cl, "%t", "interpKickMsg", lerp, min_interp_ms, max_interp_ms);
        //        LogMessage("%t", "interpLogMsg",  Cl, lerp);
        //        CPrintToChatAll("%t", "interpAllChat", Cl, lerp);
        //    }
        //}
        if (IsClientPlaying(Cl))
        {
            // fix broken equip slots
            // cathook is cringe
            int slot1wearable = TF2_GetWearable(Cl, 0);
            int slot2wearable = TF2_GetWearable(Cl, 1);
            int slot3wearable = TF2_GetWearable(Cl, 2);
            int maxEnts       = GetMaxEntities();
            // only check if player has 3 valid hats on
            if  (
                    0 < slot1wearable <= maxEnts
                    &&
                    0 < slot2wearable <= maxEnts
                    &&
                    0 < slot3wearable <= maxEnts
                )
            {
                int slot1itemdef = GetEntProp(slot1wearable, Prop_Send, "m_iItemDefinitionIndex");
                int slot2itemdef = GetEntProp(slot2wearable, Prop_Send, "m_iItemDefinitionIndex");
                int slot3itemdef = GetEntProp(slot3wearable, Prop_Send, "m_iItemDefinitionIndex");
                if  (
                        // frontline field recorder
                        (
                            slot1itemdef    == 302
                            || slot2itemdef == 302
                            || slot3itemdef == 302
                        )
                        // gibus
                        &&
                        (
                            slot1itemdef    == 940
                            || slot2itemdef == 940
                            || slot3itemdef == 940
                        )
                        &&
                        // skull topper
                        (
                            slot1itemdef    == 941
                            || slot2itemdef == 941
                            || slot3itemdef == 941
                        )
                    )
                {
                    char reason[256];
                    Format(reason, sizeof(reason), "%t", "badItemSchemaBanMsg", Cl);
                    BanUser(userid, reason);
                    CPrintToChatAll("%t", "badItemSchemaBanAllChat", Cl);
                    LogMessage("%t", "badItemSchemaBanMsg", Cl);
                }
            }
        }
    }
}

// these 3 functions are a god damn mess

QueryEverything(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if (IsValidClient(Cl))
    {
        // check cvars!
        int i = 0;
        QueryCvars(userid, i);
    }
}

QueryCvars(int userid, int i)
{
    int Cl = GetClientOfUserId(userid);
    // don't check cvars if client is invalid
    if (IsValidClient(Cl))
    {
        if (i < sizeof(cvarsToCheck) || i == 0)
        {
            DataPack pack;
            QueryClientConVar(Cl, cvarsToCheck[i], ConVarQueryFinished:ConVarCheck);
            i++;
            CreateDataTimer(1.0, timerqC, pack);
            WritePackCell(pack, userid);
            WritePackCell(pack, i);
        }
        else if (i >= sizeof(cvarsToCheck))
        {
            // checks a bunch of AC related netprops
            NetPropCheck(userid);
        }
    }
}

// timer for checking the next cvar in the list (waits a second to balance out server load)
public Action timerqC(Handle timer, DataPack pack)
{
    ResetPack(pack, false);
    int userid = ReadPackCell(pack);
    int i      = ReadPackCell(pack);
    int Cl     = GetClientOfUserId(userid);
    if (IsValidClient(Cl))
    {
        QueryCvars(userid, i);
    }
}

// timer for checking ALL cvars and net props and everything else
public Action Timer_CheckClientConVars(Handle timer, any userid)
{
    // get actual client index
    int Cl = GetClientOfUserId(userid);
    // null out timer here
    g_hQueryTimer[Cl] = null;
    if (IsValidClient(Cl))
    {
        if (DEBUG)
        {
            LogMessage("[StAC] Checking client id, %i, %N", Cl, Cl);
        }
        // query the client!
        QueryEverything(userid);
        // check randomly (every 1 - 5 minutes) for violating clients, then recheck with a new random value
        g_hQueryTimer[Cl] = CreateTimer(GetRandomFloat(minRandCheckVal, maxRandCheckVal), Timer_CheckClientConVars, userid);
    }
}

// expensive!
QueryEverythingAllClients()
{
    LogMessage("[StAC] Querying all clients");
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            int userid = GetClientUserId(Cl);
            QueryEverything(userid);
        }
    }
}

////////////
// STONKS //
////////////

// i hope youre proud of me, 9th grade geometry teacher
stock float CalcAngDeg(const float array1[2], const float array2[2])
{
    float arDiff[2];
    arDiff[0] = array1[0] - array2[0];
    arDiff[1] = array1[1] - array2[1];
    return SquareRoot(arDiff[0] * arDiff[0] + arDiff[1] * arDiff[1]);
}

// cleaned up IsValidClient Stock
stock bool IsValidClient(client)
{
    if  (
            client <= 0
             || client > MaxClients
             || !IsClientConnected(client)
             || IsFakeClient(client)
        )
    {
        return false;
    }
    return IsClientInGame(client);
}

// is client on a team and not dead
stock bool IsClientPlaying(client)
{
    TFTeam team = TF2_GetClientTeam(client);
    if  (
            IsPlayerAlive(client)
            &&
            (
                team == TFTeam_Red
                 ||
                team == TFTeam_Blue
            )
        )
    {
        return true;
    }
    return false;
}

// print colored chat to all server/sourcemod admins
stock PrintColoredChatToAdmins(const char[] format, any ...)
{
    char buffer[254];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && CheckCommandAccess(i, "sm_ban", ADMFLAG_ROOT))
        {
            SetGlobalTransTarget(i);
            VFormat(buffer, sizeof(buffer), format, 2);
            CPrintToChat(i, "%s", buffer);
        }
    }
}

// print to all server/sourcemod admin's consoles
stock PrintToConsoleAllAdmins(const char[] format, any ...)
{
    char buffer[254];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && CheckCommandAccess(i, "sm_ban", ADMFLAG_ROOT))
        {
            SetGlobalTransTarget(i);
            VFormat(buffer, sizeof(buffer), format, 2);
            PrintToConsole(i, "%s", buffer);
        }
    }
}

// print to important ppl on server
stock PrintToImportant(const char[] format, any ...)
{
    char buffer[254];
    VFormat(buffer, sizeof(buffer), format, 2);
    PrintColoredChatToAdmins("%s", buffer);
    CPrintToSTV("%s", buffer);
}

// adapted & deuglified from f2stocks
// Finds STV Bot to use for CPrintToSTV
CachedSTV;
stock FindSTV()
{
    if  (!
            (
                CachedSTV >= 1
                 && CachedSTV <= MaxClients
                 && IsClientConnected(CachedSTV)
                 && IsClientInGame(CachedSTV)
                 && IsClientSourceTV(CachedSTV)
            )
        )
    {
        CachedSTV = -1;
        for (int client = 1; client <= MaxClients; client++)
        {
            if  (
                    IsClientConnected(client)
                     && IsClientInGame(client)
                     && IsClientSourceTV(client)
                )
            {
                CachedSTV = client;
                break;
            }
        }
    }
    return CachedSTV;
}

// adapted & deuglified from f2stocks
// print to stv (now with color)
stock CPrintToSTV(const char[] format, any:...)
{
    int stv = FindSTV();
    if (stv < 1)
    {
        return;
    }

    char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 2);
    CPrintToChat(stv, "%s", buffer);
}

// float max
stock float fMax(float a, float b) {
    return a > b ? a : b;
}
// abs
stock int IntAbs(int val)
{
   return (val < 0) ? -val : val;
}

// stolen from smlib
stock any Math_Min(any value, any min)
{
    if (value < min) {
        value = min;
    }

    return value;
}

stock any Math_Max(any value, any max)
{
    if (value > max) {
        value = max;
    }

    return value;
}

stock any Math_Clamp(any value, any min, any max)
{
    value = Math_Min(value, min);
    value = Math_Max(value, max);

    return value;
}

// get entindx of player wearable
stock int TF2_GetWearable(int client, int wearableidx)
{
	// 3540 linux
	// 3520 windows
	int offset = FindSendPropInfo("CTFPlayer", "m_flMaxspeed") - 20;
	Address m_hMyWearables = view_as< Address >(LoadFromAddress(GetEntityAddress(client) + view_as< Address >(offset), NumberType_Int32));
	return LoadFromAddress(m_hMyWearables + view_as< Address >(4 * wearableidx), NumberType_Int32) & 0xFFF;
}
