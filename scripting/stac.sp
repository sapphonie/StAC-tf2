// see the readme for more info:
// https://github.com/stephanieLGBT/StAC-tf2/blob/master/README.md
// i love my girlfriends
#pragma semicolon 1

#include <sourcemod>
#include <color_literals>
#include <regex>
#include <sdktools>
#include <tf2_stocks>
#include <geoip>
#include <autoexecconfig>
#undef REQUIRE_PLUGIN
#include <updater>
#include <sourcebanspp>

#define PLUGIN_VERSION  "3.0.0"
#define UPDATE_URL      "https://raw.githubusercontent.com/stephanieLGBT/StAC-tf2/master/updatefile.txt"

public Plugin myinfo =
{
    name             =  "Steph's AntiCheat (StAC)",
    author           =  "stephanie",
    description      =  "Anticheat plugin [tf2 only] written by Stephanie. Originally forked from IntegriTF2 by Miggy",
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
int turnTimes[MAXPLAYERS+1];
int fovDesired[MAXPLAYERS+1];
int fakeAngDetects[MAXPLAYERS+1];
int pSilentDetects[MAXPLAYERS+1];
int aimSnapDetects[MAXPLAYERS+1];
// TIME SINCE LAST ACTION PER CLIENT
float timeSinceSpawn[MAXPLAYERS+1];
float timeSinceTaunt[MAXPLAYERS+1];
float timeSinceTeled[MAXPLAYERS+1];
// STORED ANGLES PER CLIENT
float angCur[MAXPLAYERS+1][2];
float angPrev1[MAXPLAYERS+1][2];
float angPrev2[MAXPLAYERS+1][2];
// STORED VARS FOR INDIVIDUAL CLIENTS
float interpFor[MAXPLAYERS+1]      = -1.0;
float interpRatioFor[MAXPLAYERS+1] = -1.0;
float updaterateFor[MAXPLAYERS+1]  = -1.0;
float REALinterpFor[MAXPLAYERS+1]  = -1.0;

// STORES IF CURRENTLY IN AFTER ROUND HUMILIATION OR NOT
bool isHumiliation;
// SOURCEBANS BOOL
bool SOURCEBANS;

// CVARS
ConVar stac_enabled;
ConVar stac_verbose_info;
ConVar stac_autoban_enabled;
ConVar stac_max_allowed_turn_secs;
ConVar stac_max_psilent_detections;
ConVar stac_max_fakeang_detections;
ConVar stac_min_interp_ms;
ConVar stac_max_interp_ms;
ConVar stac_min_randomcheck_secs;
ConVar stac_max_randomcheck_secs;

// VARIOUS DETECTION BOUNDS & CVAR VALUES
bool autoban = true;
float maxAllowedTurnSecs = 1.0;
int maxPsilentDetections = 15;
int maxFakeAngDetections = 2000;
int min_interp_ms = 15;
int max_interp_ms = 101;
// RANDOM CVARS CHECK MIN/MAX BOUNDS (in seconds)
float minRandCheckVal = 60.0;
float maxRandCheckVal = 300.0;

// DEBUG BOOL
bool DEBUG = true;

// STORED VALUES FOR "sv_client_min/max_interp_ratio" (defaults to -2 for sanity checking)
int MinInterpRatio = -2;
int MaxInterpRatio = -2;

// STUFF FOR FUTURE AIMSNAP TEST
//float sensFor[MAXPLAYERS+1] = -1.0;
//float maxSensToCheck = 4.0;

public OnPluginStart()
{
    // lifted from lilac
    char gamefolder[32];
    GetGameFolderName(gamefolder, sizeof(gamefolder));
    if (!StrEqual(gamefolder, "tf", false))
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
    RegAdminCmd("sm_forcecheckall", ForceCheckAll, ADMFLAG_ROOT, "Force check all client convars (ALL CLIENTS) for anticheat stuff");
    RegAdminCmd("sm_stac_detections", ShowDetections, ADMFLAG_ROOT, "Show all current detections on all connected clients");
    // RegAdminCmd("sm_forcecheck", ForceCheck, ADMFLAG_ROOT, "Force check all client convars (SINGLE CLIENT) for anticheat stuff");
    // get tick interval - some modded tf2 servers run at >66.7 tick!
    tickinterv = GetTickInterval();
    // don't accidentally ban ppl during humiliation for forced taunt cam! (may be unneeded?)
    HookEvent("teamplay_round_win", eRoundWin);
    // reset random server seed
    ActuallySetRandomSeed();
    // grab round start events for calculating tps
    HookEvent("teamplay_round_start", eRoundStart);
    // grab player spawns
    HookEvent("player_spawn", ePlayerSpawned);
    // grab player teleports
    HookEvent("player_teleported", ePlayerTeled);
    // check sourcebans capibility
    CreateTimer(2.0, checkSourceBans);
    // check EVERYONE's cvars on plugin reload
    CreateTimer(3.0, checkEveryone);
    // hook interp ratio cvars
    MinInterpRatio = GetConVarInt(FindConVar("sv_client_min_interp_ratio"));
    MaxInterpRatio = GetConVarInt(FindConVar("sv_client_max_interp_ratio"));
    HookConVarChange(FindConVar("sv_client_min_interp_ratio"), InterpRatioChanged);
    HookConVarChange(FindConVar("sv_client_max_interp_ratio"), InterpRatioChanged);
    // Create ConVars for adjusting settings
    initCvars();
    LogMessage("[StAC] Plugin loaded");
}

initCvars()
{
    AutoExecConfig_SetFile("stac");
    AutoExecConfig_SetCreateFile(true);

    stac_enabled =
    AutoExecConfig_CreateConVar
    (
        "stac_enabled",
        "1",
        "[StAC] enable/disable plugin (setting this to 0 immediately unloads stac.smx)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_enabled, stacVarChanged);

    stac_verbose_info =
    AutoExecConfig_CreateConVar
    (
        "stac_verbose_info",
        "1",
        "[StAC] enable/disable showing verbose info about players' cvars and other similar info in admin console\n(recommended 1)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_verbose_info, stacVarChanged);

    stac_autoban_enabled =
    AutoExecConfig_CreateConVar
    (
        "stac_autoban_enabled",
        "1",
        "[StAC] enable/disable autobanning for anything at all\n(recommended 1)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_autoban_enabled, stacVarChanged);

    stac_max_allowed_turn_secs =
    AutoExecConfig_CreateConVar
    (
        "stac_max_allowed_turn_secs",
        "1.0",
        "[StAC] maximum allowed time in seconds before client is autokicked for using turn binds (+right/+left inputs). -1 to disable autokicking, 0 instakicks\n(recommended 1.0)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_allowed_turn_secs, stacVarChanged);

    stac_max_psilent_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_psilent_detections",
        "15",
        "[StAC] maximum silent aim/norecoil detecions before banning a client. -1 to disable\n(recommended 15 or higher)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_psilent_detections, stacVarChanged);

    stac_max_fakeang_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_fakeang_detections",
        "2000",
        "[StAC] maximum fake angle / wrong angle detecions before banning a client. -1 to disable\n(recommended 2000)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_fakeang_detections, stacVarChanged);

    stac_min_interp_ms =
    AutoExecConfig_CreateConVar
    (
        "stac_min_interp_ms",
        "15",
        "[StAC] minimum interp milliseconds that a client is allowed to have before getting autokicked. set this to -1 to disable having a min interp\n(recommended 15)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_min_interp_ms, stacVarChanged);

    stac_max_interp_ms =
    AutoExecConfig_CreateConVar
    (
        "stac_max_interp_ms",
        "101",
        "[StAC] maximum interp in milliseconds that a client is allowed to have before getting autokicked. set this to -1 to disable having a max interp\n(recommended 101)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_interp_ms, stacVarChanged);

    stac_min_randomcheck_secs =
    AutoExecConfig_CreateConVar
    (
        "stac_min_randomcheck_secs",
        "60.0",
        "[StAC] check AT LEAST this often in seconds for clients with violating cvar values/netprops\n(recommended 60)",
        FCVAR_NONE,
        true,
        1.0,
        false,
        _
    );
    HookConVarChange(stac_min_randomcheck_secs, stacVarChanged);

    stac_max_randomcheck_secs =
    AutoExecConfig_CreateConVar
    (
        "stac_max_randomcheck_secs",
        "300.0",
        "[StAC] check AT MOST this often in seconds for clients with violating cvar values/netprops\n(recommended 300)",
        FCVAR_NONE,
        true,
        1.0,
        false,
        _
    );
    HookConVarChange(stac_max_randomcheck_secs, stacVarChanged);

    // actually exec the cfg after initing cvars lol
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
}

stacVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == stac_enabled)
    {
        if (StringToInt(newValue) != 1)
        {
            LogMessage("[StAC] unloading plugin!!!");
            ServerCommand("sm plugins unload stac");
        }
    }
    if (convar == stac_verbose_info)
    {
        if (StringToInt(newValue) != 1)
        {
            DEBUG = false;
        }
        else if (StringToInt(newValue) == 1)
        {
            DEBUG = true;
        }
    }
    else if (convar == stac_autoban_enabled)
    {
        if (StringToInt(newValue) != 1)
        {
            autoban = false;
        }
        else if (StringToInt(newValue) == 1)
        {
            autoban = true;
        }
    }
    // clamp to -1, 0, or higher
    else if (convar == stac_max_allowed_turn_secs)
    {
        if (StringToFloat(newValue) < 0.0 && StringToFloat(newValue) != -1.0)
        {
            maxAllowedTurnSecs = 0.0;
        }
        else
        {
            maxAllowedTurnSecs = StringToFloat(newValue);
        }
    }
    // clamp to -1 if 0
    else if (convar == stac_max_psilent_detections)
    {
        if (StringToInt(newValue) == 0)
        {
            maxPsilentDetections = 1;
        }
        else
        {
            maxPsilentDetections = StringToInt(newValue);
        }
    }
    // clamp to -1 if 0
    else if (convar == stac_max_fakeang_detections)
    {
        if (StringToInt(newValue) == 0)
        {
            maxFakeAngDetections = -1;
        }
        else
        {
            maxFakeAngDetections = StringToInt(newValue);
        }
    }
    // clamp to -1 if 0
    else if (convar == stac_min_interp_ms)
    {
        if (StringToInt(newValue) == 0)
        {
            min_interp_ms = -1;
        }
        else
        {
            min_interp_ms = StringToInt(newValue);
        }
    }
    // clamp to -1 if 0
    else if (convar == stac_max_interp_ms)
    {
        if (StringToInt(newValue) == 0)
        {
            max_interp_ms = -1;
        }
        else
        {
            max_interp_ms = StringToInt(newValue);
        }
    }
    // these have a cvar set minimum we don't need to clamp them
    else if (convar == stac_min_randomcheck_secs)
    {
        minRandCheckVal = StringToFloat(newValue);
    }
    else if (convar == stac_max_randomcheck_secs)
    {
        maxRandCheckVal = StringToFloat(newValue);
    }
}

InterpRatioChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == FindConVar("sv_client_min_interp_ratio"))
    {
        MinInterpRatio = StringToInt(newValue);
    }
    else if (convar == FindConVar("sv_client_min_interp_ratio"))
    {
        MaxInterpRatio = StringToInt(newValue);
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
    isHumiliation = false;
    // might as well!
    ActuallySetRandomSeed();
}

public eRoundWin(Handle event, const char[] name, bool dontBroadcast)
{
    isHumiliation = true;
    // might as well!
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

public TF2_OnConditionRemoved(int Cl, TFCond condition)
{
    if (IsValidClient(Cl))
    {
        if (condition == TFCond_Taunting)
        {
            timeSinceTaunt[Cl] = GetEngineTime();
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

public OnLibraryAdded(const String:name[])
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
    aimSnapDetects[Cl] = 0;
    timeSinceSpawn[Cl] = 0.0;
    timeSinceTaunt[Cl] = 0.0;
    timeSinceTeled[Cl] = 0.0;
    interpFor[Cl]      = -1.0;
    interpRatioFor[Cl] = -1.0;
    updaterateFor[Cl]  = -1.0;
    REALinterpFor[Cl]  = -1.0;
}

public OnClientPostAdminCheck(Cl)
{
    if (IsValidClient(Cl))
    {
        int userid = GetClientUserId(Cl);
        // TODO - test this and see if it's accurate enough to autokick people with
        char ip[17];
        char country_name[45];
        GetClientIP(Cl, ip, sizeof(ip));
        GeoipCountry(ip, country_name, sizeof(country_name));
        if  (
                StrContains(country_name, "Anonymous", false) != -1 ||
                StrContains(country_name, "Proxy", false) != -1
            )
        {
            PrintToImportant(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... "Player %L is likely using a proxy!", Cl);
        }
        // clear per client values
        ClearClBasedVars(userid);
        // clear timer
        g_hQueryTimer[Cl] = null;
        // query convars on player connect
        LogMessage("[StAC] %N joined. Checking cvars", Cl);
        g_hQueryTimer[Cl] = CreateTimer(GetRandomFloat(minRandCheckVal, maxRandCheckVal), Timer_CheckClientConVars, userid);
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

//public Action ForceCheck(int client, int args)
//{
//
//    QueryEverything();
//    ReplyToCommand(client, "Forcibly checking cvars on client %n.");
//}

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
            // make sure client is real, not a bot, on a team, AND didnt spawn, taunt, or teleport in the last .1 seconds
            IsValidClient(Cl)
             && IsClientPlaying(Cl)
             && engineTime - 0.1 > timeSinceSpawn[Cl]
             && engineTime - 0.1 > timeSinceTaunt[Cl]
             && engineTime - 0.1 > timeSinceTeled[Cl]
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
                 && angPrev1[Cl][1] != angCur[Cl][0]
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
            ok - lets make sure there's a difference of at least 0.5 degrees on either axis to avoid most fake detections
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
            // refactored from smac - make sure we don't fuck up angles near the x/y axes!
            float aDiff[2];
            aDiff[0] = angCur[Cl][0] - angPrev1[Cl][0];
            aDiff[1] = angCur[Cl][1] - angPrev1[Cl][1];
            if (aDiff[0] > 180.0)
            {
                aDiff[0] = FloatAbs(aDiff[0] - 360);
            }
            if (aDiff[1] > 180.0)
            {
                aDiff[1] = FloatAbs(aDiff[1] - 360);
            }
            // actual angle calculation here
            if (aDiff[0] > 0.5 || aDiff[1] > 0.5)
            {
                pSilentDetects[Cl]++;
                // have this detection expire in 20 minutes
                CreateTimer(1200.0, Timer_decr_pSilent, userid);
                // print a bunch of bullshit
                PrintToImportant(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " pSilent / NoRecoil detection on %N. Detections so far: " ... COLOR_PALEGREEN ... "%i", Cl, pSilentDetects[Cl]);
                PrintToImportant("|----- curang angles: x %f y %f", angCur[Cl][0], angCur[Cl][1]);
                PrintToImportant("|----- prev 1 angles: x %f y %f", angPrev1[Cl][0], angPrev1[Cl][1]);
                PrintToImportant("|----- prev 2 angles: x %f y %f", angPrev2[Cl][0], angPrev2[Cl][1]);
                // BAN USER if they trigger too many detections
                if (pSilentDetects[Cl] >= maxPsilentDetections && maxPsilentDetections != -1)
                {
                    char KickMsg[256];
                    Format(KickMsg, sizeof(KickMsg), "Player %N was using pSilentAim or NoRecoil. Total detections: %i. Banned from server", Cl, pSilentDetects[Cl]);
                    BanUser(userid, KickMsg);
                    PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using " ... COLOR_MEDIUMPURPLE ... "pSilentAim" ... COLOR_WHITE ..." or " ... COLOR_MEDIUMPURPLE ... "NoRecoil"  ... COLOR_WHITE ... ". Total detections: " ... COLOR_MEDIUMPURPLE ... "%i" ... COLOR_WHITE ... ". " ... COLOR_PALEGREEN ... "BANNED from server", Cl, pSilentDetects[Cl]);
                    LogMessage("[StAC] Player %N was banned for using pSilent or NoRecoil! Total detections: %i.", Cl, pSilentDetects[Cl]);
                }
            }
        }
        /*
            BASIC AIMSNAP TEST (not currently hooked up)
        */
        /*
        float SmouseFl[2];
        SmouseFl[0] = float(abs(mouse[0])) / sensFor[Cl];
        SmouseFl[1] = float(abs(mouse[1])) / sensFor[Cl];
        PrintToServer("mouse0 %f mouse1 %f", SmouseFl[0], SmouseFl[1]);
        //PrintToServer("raw : x %f y %f, mouse0 %i, mouse1 %i", angCur[Cl][0], angCur[Cl][1], mouse[0], mouse[1]);
        //PrintToServer("sc : x %f y %f, mouse0 %f, mouse1 %f", angCur[Cl][0], angCur[Cl][1], mouseFl[0] / sensFor[Cl], mouseFl[1] / sensFor[Cl]);
        if  (
                // ignore stupidly high sens players
                // technically can be spoofed but also it would be annoying for the cheater
                (
                    // def "max sens" is 4
                    //sensFor[Cl] < maxSensToCheck &&
                    sensFor[Cl] != -1
                )
                &&
                (
                    // hopefully detect snaps of over 10.0 degrees
                    FloatAbs(FloatAbs(angCur[Cl][0]) - FloatAbs(angPrev1[Cl][0])) > 10.0 ||
                    FloatAbs(FloatAbs(angCur[Cl][1]) - FloatAbs(angPrev1[Cl][1])) > 10.0
                )
                &&
                // make sure theres minimal mouse movement (less than 20 scaled to client sens)
                (
                    abs(mouse[0]) / sensFor[Cl] < 20 &&
                    abs(mouse[1]) / sensFor[Cl] < 20
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
            if (ClDidHitPlayer(Cl))
            // maybe use TR_DidHit ? i dont know
            {
                aimSnapDetects[Cl]++;
                PrintToChatAll("aimSnapDetects = %i", aimSnapDetects[Cl]);
                PrintColoredChatAll("[StAC] snap %f d on %N: curang angles: x %f y %f", (FloatAbs(angCur[Cl][0] - angPrev1[Cl][0])), Cl, angCur[Cl][0], angCur[     Cl][1]);
                PrintColoredChatAll("[StAC] snap      on %N: prev1  angles: x %f y %f", Cl, angPrev1[Cl][0], angPrev1[Cl][1]);
                PrintColoredChatAll("[StAC] snap      on %N: prev2  angles: x %f y %f", Cl, angPrev2[Cl][0], angPrev2[Cl][1]);
                PrintColoredChatAll("[StAC] mouse movement at time of snap: mouse x %i, y %i",   abs(mouse[0]), abs(mouse[1]));
            }
        }
        */
        /*
            EYE ANGLES TEST
            if clients are outside of allowed angles in tf2, which are
              +/- 89.0 x
              +/- 180 y
            while they are not in spec & on a map camera, we should log it.
            we would fix it but cheaters can just ignore server-enforced viewangle changes so there's no point
        */
        if  (
                (
                    angles[0]     < -89.0       // x angles SHOULD BE clamped between -89.0...
                     || angles[0] > 89.0        // ...and 89.0.
                     || angles[1] < -180.0      // y angles SHOULD BE clamped between -180.0...
                     || angles[1] > 180.0       // ...and 180.0.
                )
            )
        {
            // log
            fakeAngDetects[Cl]++;
            PrintToImportant(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N has " ... COLOR_MEDIUMPURPLE ... "invalid eye angles" ... COLOR_WHITE ... "!\n Current angles: " ... COLOR_MEDIUMPURPLE     ... "%.2f %.2f %.2f"  ... COLOR_WHITE ... ". Detections so far: " ... COLOR_PALEGREEN ... "%i", Cl, angles[0], angles[1], angles[2], fakeAngDetects[Cl]);
            LogMessage("[StAC] Player %N has invalid eye angles! Current angles: %.2f %.2f %.2f Detections so far: %i", Cl, angles[0], angles[1], angles[2], fakeAngDetects[Cl]);
            if (fakeAngDetects[Cl] >= maxFakeAngDetections && maxFakeAngDetections != -1)
            {
                char KickMsg[256];
                Format(KickMsg, sizeof(KickMsg), "Player %N had too many invalid eye angles. Total detections: %i. Banned from server", Cl, fakeAngDetects[Cl]);
                BanUser(userid, KickMsg);
                PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using " ... COLOR_MEDIUMPURPLE ... "fake angles" ... COLOR_WHITE ..." or had too many " ... COLOR_MEDIUMPURPLE ... "invalid eye angles"  ... COLOR_WHITE ... ". Total detections: " ... COLOR_MEDIUMPURPLE ... "%i" ... COLOR_WHITE ... ". " ... COLOR_PALEGREEN ... "BANNED from server", Cl, fakeAngDetects[Cl]);
                LogMessage("[StAC] Player %N was banned for having too many fake angle detections! Total detections: %i.", Cl, fakeAngDetects[Cl]);
            }
        }
        /*
            TURN BIND TEST
        */
        if  (buttons & IN_LEFT || buttons & IN_RIGHT)
        {
            if (maxAllowedTurnSecs != -1.0)
            {
                turnTimes[Cl]++;
                float turnSec = turnTimes[Cl] * tickinterv;
                PrintToImportant(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... "Detected turn bind on player %L for " ... COLOR_PALEGREEN ... "%f" ... COLOR_WHITE ... " seconds", Cl, turnSec);
                if (turnSec < maxAllowedTurnSecs)
                {
                    PrintColoredChat(Cl, COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Turn binds and spin binds are not allowed on this server. If you continue to use them you will be autokicked!");
                }
                else if (turnSec >= maxAllowedTurnSecs)
                {
                    KickClient(Cl, "Usage of turn binds or spin binds is not allowed. Autokicked");
                    LogMessage("[StAC] Player %N was using turn binds! Kicked from server.", Cl);
                    PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using turn binds! " ... COLOR_PALEGREEN ... "Kicked from server.", Cl);
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
        if (fakeAngDetects[Cl] > 0)
        {
            pSilentDetects[Cl]--;
        }
    }
}

public Action Timer_decrFakeAngs(Handle timer, any userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        if (fakeAngDetects[Cl] > 0)
        {
            fakeAngDetects[Cl]--;
        }
    }
}

char cvarsToCheck[][] =
{
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
    // other vars
    //"sensitivity"
};

public ConVarCheck(QueryCookie cookie, int Cl, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
    // don't bother checking bots
    if (!IsValidClient(Cl))
    {
        return;
    }
    int userid = GetClientUserId(Cl);
    // log something about cvar errors xcept for cheat only cvars
    if (result != ConVarQuery_Okay)
    {
        PrintToImportant(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Could not query CVar %s on Player %N", Cl);
        LogMessage("[StAC] Could not query CVar %s on Player %N", cvarName, Cl);
    }
    /*
        POSSIBLE CHEAT VARS
    */
    // cl_interpolate (hidden cvar! should NEVER not be 1.0)
    if (StrEqual(cvarName, "cl_interpolate"))
    {
        if (StringToFloat(cvarValue) != 1.0)
        {
            char KickMsg[256];
            Format(KickMsg, sizeof(KickMsg), "CVar %s was %s, indicating NOLERP! Banned from server", cvarName, cvarValue);
            BanUser(userid, KickMsg);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar %s = %s, indicating NOLERP!" ... COLOR_PALEGREEN ... "BANNED from server.", Cl, cvarName, cvarValue);
            LogMessage("[StAC] Player %N is using CVar %s = %s, indicating NOLERP! BANNED from server!", Cl, cvarName, cvarValue);
        }
    }
    // r_drawothermodels (if u get banned by this you are a clown)
    else if (StrEqual(cvarName, "r_drawothermodels"))
    {
        if (StringToInt(cvarValue) != 1)
        {
            char KickMsg[256];
            Format(KickMsg, sizeof(KickMsg), "CVar %s was %s, indicating WALLHACKING! Banned from server", cvarName, cvarValue);
            BanUser(userid, KickMsg);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar " ... COLOR_MEDIUMPURPLE ... "%s" ... COLOR_WHITE ..." = " ... COLOR_MEDIUMPURPLE ... "%s"  ... COLOR_WHITE ... ", indicating WALLHACKING!" ... COLOR_PALEGREEN ... "BANNED from server.", Cl, cvarName, cvarValue);
            LogMessage("[StAC] Player %N was using CVar %s = %s, indicating WALLHACKING! BANNED from server!", Cl, cvarName, cvarValue);
        }
    }
    // fov check #1 (if u get banned by this you are a clown)
    else if (StrEqual(cvarName, "fov_desired"))
    {
        // save fov to var to reset later with netpropcheck
        fovDesired[Cl] = StringToInt(cvarValue);
        if (StringToInt(cvarValue) > 90)
        {
            char KickMsg[256];
            Format(KickMsg, sizeof(KickMsg), "CVar %s was %s, indicating FOV HACKING! Banned from server", cvarName, cvarValue);
            BanUser(userid, KickMsg);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar " ... COLOR_MEDIUMPURPLE ... "%s" ... COLOR_WHITE ..." = " ... COLOR_MEDIUMPURPLE ... "%s"  ... COLOR_WHITE ... ", indicating FOV HACKING!" ... COLOR_PALEGREEN ... "BANNED from server.", Cl, cvarName, cvarValue);
            LogMessage("[StAC] Player %N was using CVar %s = %s, indicating FOV HACKING! BANNED from server!", Cl, cvarName, cvarValue);
        }
        else if (StringToFloat(cvarValue) < 90.000)
        {
            PrintColoredChatToAdmins(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N has an FOV below 90! FOV: %f", Cl, StringToFloat(cvarValue));
        }
    }
    // mat_fullbright
    if (StrEqual(cvarName, "mat_fullbright"))
    {
        // can only ever be 0 unless you're cheating or on a map with uncompiled lighting
        if (StringToInt(cvarValue) != 0)
        {
            char KickMsg[256];
            Format(KickMsg, sizeof(KickMsg), "CVar %s was %s, indicating FULLBRIGHT! Banned from server", cvarName, cvarValue);
            BanUser(userid, KickMsg);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar " ... COLOR_MEDIUMPURPLE ... "%s" ... COLOR_WHITE ..." = " ... COLOR_MEDIUMPURPLE ... "%s"  ... COLOR_WHITE ... ", indicating FULLBRIGHT!" ... COLOR_PALEGREEN ... "BANNED from server.", Cl, cvarName, cvarValue);
            LogMessage("[StAC] Player %N is using CVar %s = %s, indicating FULLBRIGHT! BANNED from server!", Cl, cvarName, cvarValue);
        }
    }
    // thirdperson (hidden cvar)
    else if (StrEqual(cvarName, "cl_thirdperson"))
    {
        if (StringToFloat(cvarValue) != 0.0)
        {
            char KickMsg[256];
            Format(KickMsg, sizeof(KickMsg), "CVar %s was %s, indicating cheating with THIRDPERSON! Banned from server", cvarName, cvarValue);
            BanUser(userid, KickMsg);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N is using CVar %s = %s, indicating cheating with THIRDPERSON!" ... COLOR_PALEGREEN ... "BANNED from server.", Cl, cvarName, cvarValue);
            LogMessage("[StAC] Player %N is using CVar %s = %s, indicating cheating with THIRDPERSON! Banned from server!", Cl, cvarName, cvarValue);
        }
    }
    /*
        NETWORK CVARS
    */
    // cl_interp
    else if (StrEqual(cvarName, "cl_interp"))
    {
        interpFor[Cl] = StringToFloat(cvarValue);
        // cl_interp needs to be at or BELOW tf2's default settings
        if (StringToFloat(cvarValue) > 0.100000)
        {
            KickClient(Cl, "CVar %s = %s, outside reasonable bounds. Change it to .1 at most", cvarName, cvarValue);
            LogMessage("[StAC] Player %N was using CVar %s = %s, indicating interp explotation. Kicked from server.", Cl, cvarName, cvarValue);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar " ... COLOR_MEDIUMPURPLE ... "%s" ... COLOR_WHITE ..." = " ... COLOR_MEDIUMPURPLE ... "%s"  ... COLOR_WHITE ... ", indicating interp explotation. " ... COLOR_PALEGREEN ... "Kicked from server.", Cl, cvarName, cvarValue);
        }
    }
    // cl_cmdrate
    else if (StrEqual(cvarName, "cl_cmdrate"))
    {
        if (!cvarValue[0])
        {
            LogMessage("[StAC] Null string returned as cvar result when querying cvar %s on %N", cvarName, Cl);
            PrintToImportant(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Null string returned as cvar result when querying cvar %s on %N", cvarName, Cl);
        }
        // cl_cmdrate needs to not have any non numerical chars (xcept the . sign if its a float) in it because otherwise player ping gets messed up on the scoreboard
        else if (SimpleRegexMatch(cvarValue, "^\\d*\\.?\\d*$") <= 0)
        {
            KickClient(Cl, "CVar %s = %s, indicating pingmasking. Remove any non numeric characters", cvarName, cvarValue);
            LogMessage("[StAC] Player %N is using CVar %s = %s, ping-masking! Kicked from server", Cl, cvarName, cvarValue);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar " ... COLOR_MEDIUMPURPLE ... "%s" ... COLOR_WHITE ..." = " ... COLOR_MEDIUMPURPLE ... "%s"  ... COLOR_WHITE ... ", indicating ping masking. " ... COLOR_PALEGREEN ... "Kicked from server.", Cl, cvarName, cvarValue);
        }
    }
    // cl_interp_ratio
    else if (StrEqual(cvarName, "cl_interp_ratio"))
    {
        // we have to clamp this value according to here to make sure we're getting the "real" client interp
        // https://github.com/TheAlePower/TeamFortress2/blob/1b81dded673d49adebf4d0958e52236ecc28a956/tf2_src/game/server/gameinterface.cpp#L2845
        interpRatioFor[Cl] = StringToFloat(cvarValue);
        if (interpRatioFor[Cl] == 0.0)
        {
            interpRatioFor[Cl] = 1.0;
        }
        if (MinInterpRatio && MaxInterpRatio && float(MinInterpRatio) != -1)
        {
            interpRatioFor[Cl] = Math_Clamp(interpRatioFor[Cl], float(MinInterpRatio), float(MaxInterpRatio));
        }
        else
        {
            if (interpFor[Cl] == 0.0)
            {
                interpFor[Cl] = 1.0;
            }
        }
    }
    // there is an exploit involving updaterate and lerp which allows you to have literally whatever interp you want. the "m_fLerpTime" netprop DOES NOT CHANGE so we have to check the actual cvar
    // technically this can't give you ""real"" interp below 15.151515151 ms but it can cause higher than 500ms interp AND client desync and can make things annoying for other people
    else if (StrEqual(cvarName, "cl_updaterate"))
    {
        updaterateFor[Cl] = StringToFloat(cvarValue);
        // don't bother checking if tickrate isnt default
        if (tps < 70.0 && tps > 60.0)
        {
            REALinterpFor[Cl] = (fMax( interpFor[Cl], interpRatioFor[Cl] / updaterateFor[Cl])) * 1000;
            //PrintToChatAll("%f ms interp on %N", REALinterpFor[Cl], Cl);
            LogMessage("%f ms interp on %N", REALinterpFor[Cl], Cl);
            //
            if  (
                    REALinterpFor[Cl] < min_interp_ms && min_interp_ms != -1
                     ||
                    REALinterpFor[Cl] > max_interp_ms && max_interp_ms != -1
                )
            {
                KickClient(Cl, "[StAC] Your interp was %f ms, outside reasonable bounds! Kicked from server", REALinterpFor[Cl]);
                LogMessage("[StAC] Player %N 's interp was %f ms, outside reasonable bounds!", Cl, REALinterpFor[Cl]);
                PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N's " ... COLOR_MEDIUMPURPLE ... "interp" ... COLOR_WHITE ..." was " ... COLOR_MEDIUMPURPLE ... "%f"  ... COLOR_WHITE ... " ms, indicating interp exploitation. " ... COLOR_PALEGREEN ... "Kicked from server.", Cl, REALinterpFor[Cl]);
            }
        }
    }
    //  will be used later for aimsnap checking
        /*  else if (StrEqual(cvarName, "sensitivity"))
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
        char KickMsg[256];
        Format(KickMsg, sizeof(KickMsg), "Player %N attempted to print a newline, indicating usage of an external cheat program. Banned from server", Cl);
        BanUser(userid, KickMsg);
        PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N attempted to " ... COLOR_MEDIUMPURPLE ... "print a newline" ... COLOR_WHITE ...", indicating usage of an external cheat program! " ... COLOR_PALEGREEN ... "BANNED from server.", Cl);
        LogMessage("[StAC] Player %N attempted to print a newline. Banned from server.", Cl);
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

public BanUser(userid, char[] KickMsg)
{
    if (!autoban)
    {
        PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Autoban cvar set to 0. Not banning!");
        return;
    }
    int Cl = GetClientOfUserId(userid);
    if (SOURCEBANS)
    {
        SBPP_BanPlayer(0, Cl, 0, KickMsg);
    }
    else
    {
        BanClient(Cl, 0, BANFLAG_AUTO, KickMsg, KickMsg, _, _);
    }
}

// todo- try GetClientModel for detecting possible chams? don't think that would work though as you can't check client's specific models for other things afaik
NetPropCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        // set real fov from client here - overrides cheat values (works with ncc, untested on others)
        // we don't want to touch fov if a client is zoomed in while sniping...
        if (!TF2_IsPlayerInCondition(Cl, TFCond_Zoomed))
        {
            SetEntProp(Cl, Prop_Send, "m_iFOV", fovDesired[Cl]);
        }
        if (DEBUG)
        {
            // log entprop values
            LogMessage("[StAC] entprop m_nForceTauntCam of %N is %i", Cl, GetEntProp(Cl, Prop_Send, "m_nForceTauntCam"));
            LogMessage("[StAC] entprop m_iDefaultFOV of %N is %i", Cl, GetEntProp(Cl, Prop_Send, "m_iDefaultFOV"));
            LogMessage("[StAC] entprop m_iFOV of %N is %i", Cl, GetEntProp(Cl, Prop_Send, "m_iFOV"));
            LogMessage("[StAC] entprop m_iFOVStart of %N is %i", Cl, GetEntProp(Cl, Prop_Send, "m_iFOVStart"));
            LogMessage("[StAC] entprop m_fLerpTime of %N is %f ms", Cl, GetEntPropFloat(Cl, Prop_Data, "m_fLerpTime") * 1000);
            PrintToConsoleAllAdmins("[StAC] entprop m_nForceTauntCam of %N is %i", Cl, GetEntProp(Cl, Prop_Send, "m_nForceTauntCam"));
            PrintToConsoleAllAdmins("[StAC] entprop m_iDefaultFOV of %N is %i", Cl, GetEntProp(Cl, Prop_Send, "m_iDefaultFOV"));
            PrintToConsoleAllAdmins("[StAC] entprop m_iFOV of %N is %i", Cl, GetEntProp(Cl, Prop_Send, "m_iFOV"));
            PrintToConsoleAllAdmins("[StAC] entprop m_iFOVStart of %N is %i", Cl, GetEntProp(Cl, Prop_Send, "m_iFOVStart"));
            PrintToConsoleAllAdmins("[StAC] entprop m_fLerpTime of %N is %f ms", Cl, GetEntPropFloat(Cl, Prop_Data, "m_fLerpTime") * 1000);
        }
        // check netprops!!!
        // fov - client has to be alive, on a team, and have an above normal fov
        int iFov = GetEntProp(Cl, Prop_Send, "m_iFOV", 1);
        if  (
                IsClientPlaying(Cl)
                &&
                (
                    iFov != 0
                )
                &&
                (
                    iFov > 90
                     ||
                    iFov < 20
                )
            )
        {
            char KickMsg[256] = "Netprop 'm_iFOV' was invalid ( >90 or <20 ), indicating FOV HACKING! Banned from server";
            BanUser(userid, KickMsg);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using an invalid Netprop value for " ... COLOR_MEDIUMPURPLE ... "m_iFOV" ...    COLOR_WHITE ... ", indicating FOV HACKING!" ... COLOR_PALEGREEN ... "BANNED from server.", Cl);
            LogMessage("[StAC] Player %N Netprop m_iFOV was > 90, indicating FOV HACKING! BANNED from server!", Cl);
        }
        // third person (check 1)
        if (GetEntProp(Cl, Prop_Send, "m_nForceTauntCam") != 0 && !isHumiliation)
        {
            char KickMsg[256] = "Netprop 'm_nForceTauntCam' was != 0, indicating cheating with THIRD PERSON! Banned from server";
            BanUser(userid, KickMsg);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using Netprop " ... COLOR_MEDIUMPURPLE ... "m_nForceTauntCam" ...    COLOR_WHITE ..." != " ... COLOR_MEDIUMPURPLE ... "0"  ... COLOR_WHITE ... ", cheating with THIRD PERSON!" ... COLOR_PALEGREEN ... "BANNED from server.", Cl);
            LogMessage("[StAC] Player %N Netprop 'm_nForceTauntCam' was != 0, indicating cheating with THIRD PERSON! BANNED from server!", Cl);
        }
        // third person "check" 2 (fixes some other methods of activating tp on clients, can't ban but it sort of works)
        // will look into doing this every frame on every client if it's not too expensive?
        ClientCommand(Cl, "firstperson");
        if (DEBUG)
        {
            LogMessage("[StAC] Executed firstperson command on Player %N", Cl);
            PrintToConsoleAllAdmins("[StAC] Executed firstperson command on Player %N", Cl);
            CPrintToSTV(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Executed firstperson command on Player %N", Cl);
        }
        // lerp check (again). this time we check the netprop. Just in case.
        if (tps < 70.0 && tps > 60.0)
        {
            float lerp = GetEntPropFloat(Cl, Prop_Data, "m_fLerpTime") * 1000;
            if  (
                    lerp < min_interp_ms && min_interp_ms != -1
                     ||
                    lerp > max_interp_ms && max_interp_ms != -1
                )
            {
                KickClient(Cl, "[StAC] Your interp was %f ms, outside reasonable bounds! Kicked from server", lerp);
                LogMessage("[StAC] Player %N 's interp was %f ms, outside reasonable bounds!", Cl, lerp);
                PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N's " ... COLOR_MEDIUMPURPLE ... "interp" ... COLOR_WHITE ..." was " ... COLOR_MEDIUMPURPLE ... "%f"  ... COLOR_WHITE ... " ms, indicating interp exploitation. " ... COLOR_PALEGREEN ... "Kicked from server.", Cl, lerp);
            }
        }
    }
}

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
            PrintColoredChat(i, "%s", buffer);
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

// these stocks are adapted & deuglified from f2stocks
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

// print to stv (now with color)
// requires color-literals.inc
stock CPrintToSTV(const String:format[], any:...)
{
    int stv = FindSTV();
    if (stv < 1)
    {
        return;
    }

    char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 2);
    PrintColoredChat(stv, "%s", buffer);
}

// float max

stock float fMax(float a, float b) {
    return a > b ? a : b;
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