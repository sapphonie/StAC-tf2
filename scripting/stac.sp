// see the readme for more info:
// https://github.com/stephanieLGBT/StAC-tf2/blob/master/README.md
// written by steph, chloe, and liza
// i love my partners
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <morecolors>
#include <regex>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <autoexecconfig>
#undef REQUIRE_PLUGIN
#include <updater>
#include <sourcebanspp>

#define PLUGIN_VERSION  "3.6.0"
#define UPDATE_URL      "https://raw.githubusercontent.com/sapphonie/StAC-tf2/master/updatefile.txt"

public Plugin myinfo =
{
    name             =  "Steph's AntiCheat (StAC)",
    author           =  "steph&nie",
    description      =  "Anticheat plugin [tf2 only] written by Stephanie. Originally forked from IntegriTF2 by Miggy (RIP)",
    version          =   PLUGIN_VERSION,
    url              =  "https://sappho.io"
}

// TIMER HANDLES
Handle QueryTimer           [MAXPLAYERS+1];
Handle TriggerTimedStuffTimer;
// TPS INFO
float tickinterv;
float tps;
float bhopmult;
// DETECTIONS PER CLIENT
int turnTimes               [MAXPLAYERS+1];
int fovDesired              [MAXPLAYERS+1];
int fakeAngDetects          [MAXPLAYERS+1];
int aimsnapDetects          [MAXPLAYERS+1] = -1; // set to -1 to ignore first detections, as theyre most likely junk
int pSilentDetects          [MAXPLAYERS+1] = -1; // ^
int bhopDetects             [MAXPLAYERS+1] = -1; // set to -1 to ignore single jumps
bool isConsecStringOfBhops  [MAXPLAYERS+1];
int bhopConsecDetects       [MAXPLAYERS+1];
// TIME SINCE LAST ACTION PER CLIENT
float timeSinceSpawn        [MAXPLAYERS+1];
float timeSinceTaunt        [MAXPLAYERS+1];
float timeSinceTeled        [MAXPLAYERS+1];
// STORED ANGLES PER CLIENT
float clangles              [3][MAXPLAYERS+1][2];
// STORED POS PER CLIENT
float clpos                 [2][MAXPLAYERS+1][3];
// STORED cmdnum PER CLIENT
int clcmdnum                [3][MAXPLAYERS+1];
// STORED BUTTONS PER CLIENT
int buttonsPrev             [MAXPLAYERS+1];
// STORED GRAVITY STATE PER CLIENT
bool highGrav               [MAXPLAYERS+1];
// STORED MISC VARS PER CLIENT
bool playerTaunting         [MAXPLAYERS+1];
int playerInBadCond         [MAXPLAYERS+1];
bool userBanQueued          [MAXPLAYERS+1];
// STORED SENS PER CLIENT
float sensFor               [MAXPLAYERS+1];
// get last 6 ticks
float engineTime            [6] [MAXPLAYERS+1];

//float maxEngineTimeFor[MAXPLAYERS+1];
//
//// debug
//int maxMouseXFor[MAXPLAYERS+1];
//int maxMouseYFor[MAXPLAYERS+1];

// NATIVE BOOLS
bool SOURCEBANS;

// CVARS
ConVar stac_enabled;
ConVar stac_verbose_info;
ConVar stac_max_allowed_turn_secs;
ConVar stac_kick_for_pingmasking;
ConVar stac_ban_for_misccheats;
ConVar stac_optimize_cvars;
ConVar stac_max_aimsnap_detections;
ConVar stac_max_psilent_detections;
ConVar stac_max_bhop_detections;
ConVar stac_max_fakeang_detections;
ConVar stac_min_interp_ms;
ConVar stac_max_interp_ms;
ConVar stac_min_randomcheck_secs;
ConVar stac_max_randomcheck_secs;
ConVar stac_include_demoname_in_sb;
ConVar stac_log_to_file;

// VARIOUS DETECTION BOUNDS & CVAR VALUES
bool DEBUG                  = false;
float maxAllowedTurnSecs    = -1.0;
bool kickForPingMasking     = false;
bool banForMiscCheats       = true;
bool optimizeCvars          = true;
int maxAimsnapDetections    = 999;
int maxPsilentDetections    = 10;
int maxFakeAngDetections    = 10;
int maxBhopDetections       = 10;
// this gets set later
int maxBhopDetectionsScaled;
int min_interp_ms           = -1;
int max_interp_ms           = 101;
// RANDOM CVARS CHECK MIN/MAX BOUNDS (in seconds)
float minRandCheckVal       = 60.0;
float maxRandCheckVal       = 300.0;
// put demoname in sourcebans?
bool demonameinSB           = true;
bool logtofile              = true;

// REGEX
Regex pingmaskRegex;

// demoname for currently recording demo if extant
char demoname[128];

// Log file
File StacLogFile;

public void OnPluginStart()
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
    // open log
    OpenStacLog();
    // reg admin commands
    RegAdminCmd("sm_stac_checkall", ForceCheckAll, ADMFLAG_GENERIC, "Force check all client convars (ALL CLIENTS) for anticheat stuff");
    RegAdminCmd("sm_stac_detections", ShowDetections, ADMFLAG_GENERIC, "Show all current detections on all connected clients");
    //RegAdminCmd("sm_stac_maxmouse", PrintMaxMouse, ADMFLAG_GENERIC, "Show max mouse movement per player");
    //RegAdminCmd("sm_stac_maxticks", PrintMaxTicks, ADMFLAG_GENERIC, "Show max tick jumps per player");
    // get tick interval - some modded tf2 servers run at >66.7 tick!
    tickinterv = GetTickInterval();
    // reset random server seed
    ActuallySetRandomSeed();
    // grab round start events for calculating tps
    HookEvent("teamplay_round_start", eRoundStart);
    // grab player spawns
    HookEvent("player_spawn", ePlayerSpawned);
    // grab player name changes
    HookEvent("player_changename", ePlayerChangedName, EventHookMode_Pre);

    // check natives capibility
    CreateTimer(2.0, checkNatives);
    // check EVERYONE's cvars on plugin reload
    CreateTimer(3.0, checkEveryone);
    // pingmasking regex setup
    pingmaskRegex = new Regex("^\\d*\\.?\\d*$");
    // hook currently recording demo name if extant
    AddCommandListener(tvRecordListener, "tv_record");
    // hook sv_cheats so we can instantly unload if cheats get turned on
    HookConVarChange(FindConVar("sv_cheats"), GenericCvarChanged);
    // Create ConVars for adjusting settings
    initCvars();
    // load translations
    LoadTranslations("stac.phrases.txt");

    // check sv cheats on startup
    if (GetConVarBool(FindConVar("sv_cheats")))
    {
        SetFailState("[StAC] sv_cheats set to 1! Failing...");
    }

    // reset all client based vars on plugin reload
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            ClearClBasedVars(GetClientUserId(Cl));
        }
    }


    StacLog("[StAC] Plugin vers. ---- %s ---- loaded", PLUGIN_VERSION);
}

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
    HookConVarChange(stac_enabled, stacVarChanged);

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
    HookConVarChange(stac_verbose_info, stacVarChanged);

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
    else
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
    HookConVarChange(stac_ban_for_misccheats, stacVarChanged);

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
    HookConVarChange(stac_optimize_cvars, stacVarChanged);

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
    HookConVarChange(stac_max_aimsnap_detections, stacVarChanged);

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
    HookConVarChange(stac_max_psilent_detections, stacVarChanged);

    // bhop detections
    IntToString(maxBhopDetections, buffer, sizeof(buffer));
    stac_max_bhop_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_bhop_detections",
        buffer,
        "[StAC] maximum consecutive bhop detecions on a client before they get \"antibhopped\". client will get banned on this value + 2, so for default cvar settings, client will get banned on 12 tick perfect bhops.\nctrl + f for \"antibhop\" in stac.sp for more detailed info.\n-1 to disable even checking bhops (saves cpu), 0 to print to admins/stv but never ban\n(recommended 10 or higher)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_bhop_detections, stacVarChanged);

    // fakeang detections
    IntToString(maxFakeAngDetections, buffer, sizeof(buffer));
    stac_max_fakeang_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_fakeang_detections",
        buffer,
        "[StAC] maximum fake angle / wrong / OOB angle detecions before banning a client.\n-1 to disable even checking angles (saves cpu), 0 to print to admins/stv but never ban\n(recommended 10)",
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

    // demoname in sb
    if (demonameinSB)
    {
        buffer = "1";
    }
    else
    {
        buffer = "0";
    }
    stac_include_demoname_in_sb =
    AutoExecConfig_CreateConVar
    (
        "stac_include_demoname_in_sb",
        buffer,
        "[StAC] enable/disable putting the currently recording demo in the SourceBans ban reason\n(recommended 1)",
        FCVAR_NONE,
        true,
        0.0,
        true,
        1.0
    );
    HookConVarChange(stac_include_demoname_in_sb, stacVarChanged);

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
    HookConVarChange(stac_log_to_file, stacVarChanged);

    // actually exec the cfg after initing cvars lol
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
    setStacVars();
}

void stacVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    // this regrabs all cvar values but it's neater than having two similar functions that do the same thing
    setStacVars();
}

void setStacVars()
{
    // now covers late loads
    // enabled var
    if (!GetConVarBool(stac_enabled))
    {
        StacLog("[StAC] stac_enabled is set to 0 - unloading plugin!!!");
        ServerCommand("sm plugins unload stac");
    }
    // verbose info var
    DEBUG = GetConVarBool(stac_verbose_info);
    // turn seconds var
    maxAllowedTurnSecs = GetConVarFloat(stac_max_allowed_turn_secs);
    if (maxAllowedTurnSecs < 0.0 && maxAllowedTurnSecs != -1.0)
    {
        maxAllowedTurnSecs = 0.0;
    }
    // pingmasking var
    kickForPingMasking = GetConVarBool(stac_kick_for_pingmasking);
    // misccheats
    banForMiscCheats = GetConVarBool(stac_ban_for_misccheats);
    // optimizecvars
    optimizeCvars = GetConVarBool(stac_optimize_cvars);
    if (optimizeCvars)
    {
        RunOptimizeCvars();
    }
    // aimsnap var
    maxAimsnapDetections = GetConVarInt(stac_max_aimsnap_detections);
    // psilent var
    maxPsilentDetections = GetConVarInt(stac_max_psilent_detections);
    // bhop var
    maxBhopDetections = GetConVarInt(stac_max_bhop_detections);
    // fakeang var
    maxFakeAngDetections = GetConVarInt(stac_max_fakeang_detections);
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

    // log to file
    logtofile = GetConVarBool(stac_log_to_file);

    // this is for bhop detection only
    DoTPSMath();
}

void GenericCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    // IMMEDIATELY unload if we enable sv cheats
    if (convar == FindConVar("sv_cheats"))
    {
        if (StringToInt(newValue) != 0)
        {
            StacLog("[StAC] sv_cheats set to 1 - unloading plugin!!!");
            ServerCommand("sm plugins unload stac");
        }
    }
}

void RunOptimizeCvars()
{
    // attempt to patch doubletap
    SetConVarInt(FindConVar("sv_maxusrcmdprocessticks"), 16);
    // limit fakelag abuse
    SetConVarFloat(FindConVar("sv_maxunlag"), 0.2);
    // dont error out on server start
    if (FindConVar("backtrack_behavior") != INVALID_HANDLE)
    {
        // fix backtracking
        SetConVarInt(FindConVar("backtrack_behavior"), 1);
    }
    // get rid of any possible exploits by using teleporters and fov
    SetConVarInt(FindConVar("tf_teleporter_fov_start"), 90);
    SetConVarFloat(FindConVar("tf_teleporter_fov_time"), 0.0);
}

public Action checkNatives(Handle timer)
{
    if (GetFeatureStatus(FeatureType_Native, "SBPP_BanPlayer") == FeatureStatus_Available)
    {
        SOURCEBANS = true;
        if (DEBUG)
        {
            StacLog("[StAC] Sourcebans detected! Using Sourcebans as default ban handler.");
        }
    }
    else
    {
        SOURCEBANS = false;
        if (DEBUG)
        {
            StacLog("[StAC] No Sourcebans installation detected! Using TF2's default ban handler.");
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
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            if  (
                       turnTimes[Cl]           >= 1
                    || aimsnapDetects[Cl]      >= 1
                    || pSilentDetects[Cl]      >= 1
                    || fakeAngDetects[Cl]      >= 1
                    || bhopConsecDetects[Cl]   >= 1
                )
            {
                ReplyToCommand(callingCl, "Detections for %L", Cl);
                if (turnTimes[Cl] >= 1)
                {
                    ReplyToCommand(callingCl, "- %i turn bind frames for %N", turnTimes[Cl], Cl);
                }
                if (aimsnapDetects[Cl] >= 1)
                {
                    ReplyToCommand(callingCl, "- %i aimsnap detections for %N", aimsnapDetects[Cl], Cl);
                }
                if (pSilentDetects[Cl] >= 1)
                {
                    ReplyToCommand(callingCl, "- %i silent aim detections for %N", pSilentDetects[Cl], Cl);
                }
                if (fakeAngDetects[Cl] >= 1)
                {
                    ReplyToCommand(callingCl, "- %i fake angle detections for %N", fakeAngDetects[Cl], Cl);
                }
                if (bhopConsecDetects[Cl] >= 1)
                {
                    ReplyToCommand(callingCl, "- %i consecutive bhop strings for %N", bhopConsecDetects[Cl], Cl);
                }
            }
        }
    }
    ReplyToCommand(callingCl, "[StAC] == END DETECTIONS == ");
}

/*
public Action PrintMaxMouse(int callingCl, int args)
{
    ReplyToCommand(callingCl, "[StAC] == CURRENT MOUSE MOVEMENT == ");
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            // don't weight shit if sens for that client isn't checked yet
            if (sensFor[Cl] == 0.0)
            {
                ReplyToCommand(callingCl, "mouseX %i | mouseY %i | sens NOT_CHECKED_YET | client %N", maxMouseXFor[Cl], maxMouseYFor[Cl], sensFor[Cl], Cl);
            }
            else
            {
                // weighted to sens
                int wx = RoundFloat(maxMouseXFor[Cl] * ( 1 / sensFor[Cl]));
                int wy = RoundFloat(maxMouseYFor[Cl] * ( 1 / sensFor[Cl]));
                ReplyToCommand(callingCl, "mouseX %i | mouseY %i | sens %f | wx %i | wy %i | client %N", maxMouseXFor[Cl], maxMouseYFor[Cl], sensFor[Cl], wx, wy, Cl);
            }
        }
    }
    ReplyToCommand(callingCl, "[StAC] == END MOUSE MOVEMENT REPORT == ");
}

public Action PrintMaxTicks(int callingCl, int args)
{
    ReplyToCommand(callingCl, "[StAC] == CURRENT MAX TICKS == ");
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            ReplyToCommand(callingCl, "maxTick: %f | client %N", maxEngineTimeFor[Cl], Cl);
        }
    }
    ReplyToCommand(callingCl, "[StAC] == END MAX TICKS REPORT == ");
}
*/

public void OnPluginEnd()
{
    StacLog("[StAC] Plugin vers. ---- %s ---- unloaded", PLUGIN_VERSION);
    NukeTimers();
    OnMapEnd();
}

// reseed random server seed to help prevent certain nospread stuff from working
// this does not fix lmaobox's nospread, as it uses an essentially undetectable viewangle based method to remove spread
void ActuallySetRandomSeed()
{
    int seed = GetURandomInt();
    if (DEBUG)
    {
        StacLog("[StAC] setting random server seed to %i", seed);
    }
    SetRandomSeed(seed);
}

// NUKE the client timers from orbit on plugin and map reload
void NukeTimers()
{
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (QueryTimer[Cl] != null)
        {
            if (DEBUG)
            {
                StacLog("[StAC] Destroying timer for %L", Cl);
            }
            KillTimer(QueryTimer[Cl]);
            QueryTimer[Cl] = null;
        }
    }
    if (TriggerTimedStuffTimer != null)
    {
        if (DEBUG)
        {
            StacLog("[StAC] Destroying reseeding timer");
        }
        KillTimer(TriggerTimedStuffTimer);
        TriggerTimedStuffTimer = null;
    }
}

// recreate the timers we just nuked
void ResetTimers()
{
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            if (DEBUG)
            {
                StacLog("[StAC] Creating timer for %L", Cl);
            }
            QueryTimer[Cl] = CreateTimer(GetRandomFloat(minRandCheckVal, maxRandCheckVal), Timer_CheckClientConVars, GetClientUserId(Cl));
        }
    }
    // create timer to reset seed every 15 mins
    TriggerTimedStuffTimer = CreateTimer(900.0, timer_TriggerTimedStuff, _, TIMER_REPEAT);
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

public Action ePlayerChangedName(Handle event, char[] name, bool dontBroadcast)
{
    int userid = GetEventInt(event, "userid");
    NameCheck(userid);
}

public Action TF2_OnPlayerTeleport(int Cl, int teleporter, bool& result)
{
    if (IsValidClient(Cl))
    {
        timeSinceTeled[Cl] = GetEngineTime();
    }
}

public void TF2_OnConditionAdded(int Cl, TFCond condition)
{
    if (IsValidClient(Cl))
    {
        if (condition == TFCond_Taunting)
        {
            playerTaunting[Cl] = true;
        }
        else if
        (
               condition == TFCond_HalloweenKart
            || condition == TFCond_HalloweenKartDash
            || condition == TFCond_HalloweenThriller
            || condition == TFCond_HalloweenBombHead
            || condition == TFCond_HalloweenGiant
            || condition == TFCond_HalloweenTiny
            || condition == TFCond_HalloweenInHell
            || condition == TFCond_HalloweenGhostMode
            || condition == TFCond_HalloweenKartNoTurn
            || condition == TFCond_HalloweenKartCage
            || condition == TFCond_SwimmingCurse
        )
        {
            playerInBadCond[Cl]++;
        }
    }
}

public void TF2_OnConditionRemoved(int Cl, TFCond condition)
{
    if (IsValidClient(Cl))
    {
        if (condition == TFCond_Taunting)
        {
            timeSinceTaunt[Cl] = GetEngineTime();
            playerTaunting[Cl] = false;
        }
        else if
        (
               condition == TFCond_HalloweenKart
            || condition == TFCond_HalloweenKartDash
            || condition == TFCond_HalloweenThriller
            || condition == TFCond_HalloweenBombHead
            || condition == TFCond_HalloweenGiant
            || condition == TFCond_HalloweenTiny
            || condition == TFCond_HalloweenInHell
            || condition == TFCond_HalloweenGhostMode
            || condition == TFCond_HalloweenKartNoTurn
            || condition == TFCond_HalloweenKartCage
            || condition == TFCond_SwimmingCurse
        )
        {
            if (playerInBadCond[Cl] > 0)
            {
                playerInBadCond[Cl]--;
            }
        }
    }
}

public Action timer_TriggerTimedStuff(Handle timer)
{
    ActuallySetRandomSeed();
}

void DoTPSMath()
{
    tickinterv = GetTickInterval();
    tps = Pow(tickinterv, -1.0);

    // we have to adjust bhop stuff for tickrate - ignore past 200
    // you can bhop easier on higher tick
    // 66 = default, 133 = * 2, 200 = * 3

    // thanks to joined senses for some cleanup
    if (tps > 210.0 || tps < 65.0)
    {
        bhopmult = 0.0;
    }
    else if (tps >= 195.0)
    {
        bhopmult = 2.0;
    }
    else if (tps >= 165.0)
    {
        bhopmult = 1.75;
    }
    else if (tps >= 99.0)
    {
        bhopmult = 1.5;
    }
    else
    {
        bhopmult = 1.0;
    }

    maxBhopDetectionsScaled = RoundFloat(bhopmult * maxBhopDetections);

    if (DEBUG)
    {
        StacLog("tickinterv %.2f, tps %.2f, bhopmult %.2f, maxBhopDetectionsScaled %i", tickinterv, tps, bhopmult, maxBhopDetectionsScaled);
    }
}

public void OnMapStart()
{
    OpenStacLog();
    ActuallySetRandomSeed();
    DoTPSMath();
    ResetTimers();
    if (optimizeCvars)
    {
        RunOptimizeCvars();
    }
}

public void OnMapEnd()
{
    ActuallySetRandomSeed();
    DoTPSMath();
    NukeTimers();
    CloseStacLog();
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}

void ClearClBasedVars(int userid)
{
    // get fresh cli id
    int Cl = GetClientOfUserId(userid);
    // clear all old values for cli id based stuff
    turnTimes               [Cl] = 0;
    fovDesired              [Cl] = 0;
    fakeAngDetects          [Cl] = 0;
    aimsnapDetects          [Cl] = -1; // ignore likely false positives
    pSilentDetects          [Cl] = -1; // ^
    bhopDetects             [Cl] = -1; // set to -1 to ignore single jumps
    isConsecStringOfBhops   [Cl] = false;
    bhopConsecDetects       [Cl] = 0;
    timeSinceSpawn          [Cl] = 0.0;
    timeSinceTaunt          [Cl] = 0.0;
    timeSinceTeled          [Cl] = 0.0;
    // STORED BUTTONS PER CLIENT
    buttonsPrev             [Cl] = 0;
    // STORED GRAVITY STATE PER CLIENT
    highGrav                [Cl] = false;
    // STORED MISC VARS PER CLIENT
    playerTaunting          [Cl] = false;
    playerInBadCond         [Cl] = 0;
    userBanQueued           [Cl] = false;
    // STORED SENS PER CLIENT
    sensFor                 [Cl] = 0.0;

    // don't bother clearing arrays
}

public void OnClientPutInServer(int Cl)
{
    if (IsValidClient(Cl))
    {
        int userid = GetClientUserId(Cl);
        // clear per client values
        ClearClBasedVars(userid);
        // clear timer
        QueryTimer[Cl] = null;
        // query convars on player connect
        if (DEBUG)
        {
            StacLog("[StAC] %N joined. Checking cvars", Cl);
        }
        QueryTimer[Cl] = CreateTimer(0.01, Timer_CheckClientConVars, userid);
    }
}

public void OnClientDisconnect(int Cl)
{
    int userid = GetClientUserId(Cl);
    // clear per client values
    ClearClBasedVars(userid);
    if (QueryTimer[Cl] != null)
    {
        KillTimer(QueryTimer[Cl]);
        QueryTimer[Cl] = null;
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
    - AIM SNAPS
    - FAKE ANGLES
    - TURN BINDS
*/
public Action OnPlayerRunCmd
(
    // check
    int Cl,
    // check
    int& buttons,
    // don't check
    int& impulse,
    // not yet
    float vel[3],
    // check
    float angles[3],
    // not yet
    int& weapon,
    // ^
    int& subtype,
    // check
    int& cmdnum,
    // check
    int& tickcount,
    // nope
    int& seed,
    // check
    int mouse[2]
)
{
    // make sure client is real & not a bot.
    if (IsValidClient(Cl))
    {
        // from ssac - debug :P
        //LogMessage("[sSAC-]: OnPlayerRunCmd Debug\nbuttons = \"%i\".\nint &impulse = \"%i\".\nint &cmdnum = \"%i\".\nint &tickcount = \"%i\".\nint &seed, = \"%i\".\nint mouse[2] [1] = \"%i\", [2] = \"%i\".\n", buttons, impulse, cmdnum, tickcount, seed, mouse[0], mouse[1]);
        //LogMessage("cmdnum = \"%i\"", cmdnum);
        //LogMessage("playercond = \"%i\"", playerInBadCond[Cl]);


        // from ssac - block invalid cmds
        if (cmdnum <= 0)
        {
            return Plugin_Handled;
        }

        // testing
        //if (tickcount <= 0 || tickcount < GetGameTickCount())
        //{
        //    tickcount = GetGameTickCount();
        //}

        // set previous tick times to test lagginess (THANK YOU BACKWARDS FOR HELP WITH THIS)
        engineTime[5][Cl] = engineTime[4][Cl];
        engineTime[4][Cl] = engineTime[3][Cl];
        engineTime[3][Cl] = engineTime[2][Cl];
        engineTime[2][Cl] = engineTime[1][Cl];
        engineTime[1][Cl] = engineTime[0][Cl];
        engineTime[0][Cl] = GetEngineTime();

        // grab current time to compare to time since last spawn/taunt/tele
        // convert to percentages
        float loss = GetClientAvgLoss(Cl, NetFlow_Both) * 100.0;
        float choke = GetClientAvgChoke(Cl, NetFlow_Both) * 100.0;
        // convert to ms
        float ping = GetClientAvgLatency(Cl, NetFlow_Both) * 1000.0;
        /*
            AIMSNAP DETECTION
        */
        if  // if both anglesnap detection cvars are -1, don't bother even going past this point.
        (
            maxAimsnapDetections != -1
            ||
            maxPsilentDetections != -1
        )
        {
            // grab angles
            // thanks to nosoop from the sm discord for some help with this
            clangles[2][Cl] = clangles[1][Cl];
            clangles[1][Cl] = clangles[0][Cl];
            clangles[0][Cl][0] = angles[0];
            clangles[0][Cl][1] = angles[1];

            // grab cmdnum
            clcmdnum[2][Cl] = clcmdnum[1][Cl];
            clcmdnum[1][Cl] = clcmdnum[0][Cl];
            clcmdnum[0][Cl] = cmdnum;

            // grab positions
            clpos[1][Cl] = clpos[0][Cl];
            GetClientEyePosition(Cl, clpos[0][Cl]);

            // detect trigger teleports
            if (GetVectorDistance(clpos[0][Cl], clpos[1][Cl], false) > 500)
            {
                // reuse this variable
                timeSinceTeled[Cl] = GetEngineTime();
            }

            // R O U N D ( fuzzy psilent detection to detect lmaobox silent+ and better detect other forms of silent aim )
            float fuzzyClangles[3][2];

            fuzzyClangles[2][0] = RoundFloat(clangles[2][Cl][0] * 10.0) / 10.0;
            fuzzyClangles[2][1] = RoundFloat(clangles[2][Cl][1] * 10.0) / 10.0;
            fuzzyClangles[1][0] = RoundFloat(clangles[1][Cl][0] * 10.0) / 10.0;
            fuzzyClangles[1][1] = RoundFloat(clangles[1][Cl][1] * 10.0) / 10.0;
            fuzzyClangles[0][0] = RoundFloat(clangles[0][Cl][0] * 10.0) / 10.0;
            fuzzyClangles[0][1] = RoundFloat(clangles[0][Cl][1] * 10.0) / 10.0;

            // we need this later for decrimenting psilent detections after 10 minutes!
            int userid = GetClientUserId(Cl);

            // we have to do all these annoying checks to make sure we get as few false positives as possible.
            if
            (
                // make sure client is on a team & alive,
                   IsClientPlaying(Cl)
                // ...isn't taunting,
                && !playerTaunting[Cl]
                // ...didn't recently spawn,
                && engineTime[0][Cl] - 1.0 > timeSinceSpawn[Cl]
                // ...didn't recently taunt,
                && engineTime[0][Cl] - 1.0 > timeSinceTaunt[Cl]
                // ...didn't recently teleport,
                && engineTime[0][Cl] - 1.0 > timeSinceTeled[Cl]
                // ...isn't already queued to be banned,
                && !userBanQueued[Cl]
                // ...and isn't timing out.
                && !IsClientTimingOut(Cl)
                // this is just for halloween shit
                && playerInBadCond[Cl] == 0
            )
            {
                /*
                    EYE ANGLES TEST
                    if clients are outside of allowed angles in tf2, which are
                      +/- 89.0 x (up / down)
                      +/- 180 y (left / right, but we don't check this atm because there's things that naturally fuck up y angles, such as taunts)
                      +/- 50 z (roll / tilt)
                    while they are not in spec & on a map camera, we should log it.
                    we would fix them but cheaters can just ignore server-enforced viewangle changes so there's no point

                    these bounds were lifted from lilac. Thanks lilac. although i don't know why you "patch" roll because that's a legit thing in tf2 LOL
                */
                if
                (
                    // don't bother checking if fakeang detection is off
                    maxFakeAngDetections != -1
                    &&
                    (
                           angles[0] < -89.01
                        || angles[0] > 89.01
                        || angles[2] < -50.01
                        || angles[2] > 50.01
                    )
                )
                {
                    fakeAngDetects[Cl]++;
                    PrintToImportant("{hotpink}[StAC]{white} Player %N has {mediumpurple}invalid eye angles{white}!\nCurrent angles: {mediumpurple}%.2f %.2f %.2f{white}.\nDetections so far: {palegreen}%i", Cl, angles[0], angles[1], angles[2], fakeAngDetects[Cl]);
                    StacLog("[StAC] Player %N has invalid eye angles!\nCurrent angles: %.2f %.2f %.2f.\nDetections so far: %i", Cl, angles[0], angles[1], angles[2], fakeAngDetects[Cl]);
                    if (fakeAngDetects[Cl] >= maxFakeAngDetections && maxFakeAngDetections > 0)
                    {
                        char reason[128];
                        Format(reason, sizeof(reason), "%t", "fakeangBanMsg", fakeAngDetects[Cl]);
                        BanUser(userid, reason);
                        MC_PrintToChatAll("%t", "fakeangBanAllChat", Cl, fakeAngDetects[Cl]);
                        StacLog("%t", "fakeangBanMsg", fakeAngDetects[Cl]);
                    }
                }
                /*
                    SILENT AIM DETECTION
                    silent aim (in this context) works by aimbotting for 1 tick and then snapping your viewangle back to what it was
                    example snap:
                        L 03/25/2020 - 06:03:50: [stac.smx] [StAC] pSilent detection: angles0  angles: x 5.120096 y 9.763162
                        L 03/25/2020 - 06:03:50: [stac.smx] [StAC] pSilent detection: angles1  angles: x 1.635611 y 12.876886
                        L 03/25/2020 - 06:03:50: [stac.smx] [StAC] pSilent detection: angles2  angles: x 5.120096 y 9.763162
                    we can just look for these snaps and log them as detections!
                    note that this won't detect some snaps when a player is moving their strafe keys and mouse @ the same time while they are aimlocking.
                    i'll *try* to work mouse movement into this function at SOME point but it works reasonably well for right now.
                */
                // we have to do EXTRA checks because a lot of things can fuck up silent aim detection
                if
                (
                    AreAnglesUnlaggyAndValid(Cl)
                    &&  // don't run these checks if client is currently using a spin bind
                        !(
                            buttons & IN_LEFT
                            ||
                            buttons & IN_RIGHT
                        )
                    // ...doesn't have 5% or more packet loss,
                    && loss <= 5.0
                    // ...doesn't have 51% or more packet choke,
                    && choke <= 51.0
                    // check difference between client ticks to make sure client has been relatively unlaggy
                    && engineTime[0][Cl] - engineTime[1][Cl] < 0.1
                    && engineTime[1][Cl] - engineTime[2][Cl] < 0.1
                    && engineTime[2][Cl] - engineTime[3][Cl] < 0.1
                    && engineTime[3][Cl] - engineTime[4][Cl] < 0.1
                    && engineTime[4][Cl] - engineTime[5][Cl] < 0.1
                )
                {
                    // is this a fuzzy detect or not
                    int fuzzy = -1;
                    // don't run this check if silent aim cvar is -1
                    if (maxPsilentDetections != -1)
                    {
                        if
                        (
                            // so the current and 2nd previous angles match...
                            (
                                   clangles[0][Cl][0] == clangles[2][Cl][0]
                                && clangles[0][Cl][1] == clangles[2][Cl][1]
                            )
                            &&
                            // BUT the 1st previous (in between) angle doesnt?
                            (
                                   clangles[1][Cl][0] != clangles[0][Cl][0]
                                && clangles[1][Cl][1] != clangles[0][Cl][1]
                                && clangles[1][Cl][0] != clangles[2][Cl][0]
                                && clangles[1][Cl][1] != clangles[2][Cl][1]
                            )
                        )
                        {
                            fuzzy = 0;
                        }
                        else if
                        (
                            // etc
                            (
                                   fuzzyClangles[0][0] == fuzzyClangles[2][0]
                                && fuzzyClangles[0][1] == fuzzyClangles[2][1]
                            )
                            &&
                            // etc
                            (
                                   fuzzyClangles[1][0] != fuzzyClangles[0][0]
                                && fuzzyClangles[1][1] != fuzzyClangles[0][1]
                                && fuzzyClangles[1][0] != fuzzyClangles[2][0]
                                && fuzzyClangles[1][1] != fuzzyClangles[2][1]
                            )
                        )
                        {
                            fuzzy = 1;
                        }
                        if (fuzzy > -1)
                        {
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
                            // actual angle calculation here
                            float aDiffReal = CalcAngDeg(clangles[0][Cl], clangles[1][Cl]);
                            // refactored from smac - make sure we don't fuck up angles near the x/y axes!
                            if (aDiffReal > 180.0)
                            {
                                aDiffReal = FloatAbs(aDiffReal - 360.0);
                            }
                            if
                            (
                                (
                                    // needs to be more than a degree if not fuzzy
                                    aDiffReal >= 1.0 && fuzzy == 0
                                )
                                ||
                                (
                                    // needs to be more 3 degrees if fuzzy
                                    aDiffReal >= 3.0 && fuzzy == 1
                                )
                            )
                            {
                                pSilentDetects[Cl]++;
                                // have this detection expire in 10 minutes
                                CreateTimer(600.0, Timer_decr_pSilent, userid);
                                // first detection is LIKELY bullshit
                                if (pSilentDetects[Cl] > 0)
                                {
                                    // print a bunch of bullshit
                                    PrintToImportant("{hotpink}[StAC]{white} SilentAim detection of {yellow}%.2f{white}° on %N.\nDetections so far: {palegreen}%i{white}. fuzzy = {blue}%i", aDiffReal, Cl,  pSilentDetects[Cl], fuzzy);
                                    PrintToImportant("{white}User Net Info: {palegreen}%.2f{white}%% loss, {palegreen}%.2f{white}%% choke, {palegreen}%.2f{white} ms ping", loss, choke, ping);
                                    CPrintToSTV("clangles0: x %.2f y %.2f clangles1: x %.2f y %.2f clangles2: x %.2f y %.2f", clangles[0][Cl][0], clangles[0][Cl][1], clangles[1][Cl][0], clangles[1][Cl][1], clangles[2][Cl][0], clangles[2][Cl][1]);
                                    CPrintToSTV("clcmdnum0: %i clcmdnum1: %i clcmdnum2: %i", clcmdnum[0][Cl], clcmdnum[1][Cl], clcmdnum[2][Cl]);
                                    PrintToImportant("Time between last 5 client ticks (most recent first):\n1 %f 2 %f 3 %f 4 %f 5 %f", engineTime[0][Cl] - engineTime[1][Cl],  engineTime[1][Cl] - engineTime[2][Cl],  engineTime[2][Cl] - engineTime[3][Cl],  engineTime[3][Cl] - engineTime[4][Cl],  engineTime[4][Cl] - engineTime[5][Cl]);
                                    StacLog("[StAC] SilentAim detection of %.2f° on \n%L.\nDetections so far: %i.\nfuzzy = %i", aDiffReal, Cl,  pSilentDetects[Cl], fuzzy);
                                    StacLog("\nNetwork:\n %.2f loss\n %.2f choke\n %.2f ms ping\nAngles:\n angles0: x %.2f y %.2f\n angles1: x %.2f y %.2f\n angles2: x %.2f y %.2f\nCmdnum:\n clcmdnum[0]: %i\n clcmdnum[1]: %i\n clcmdnum[2]: %i", loss, choke, ping, clangles[0][Cl][0], clangles[0][Cl][1], clangles[1][Cl][0], clangles[1][Cl][1], clangles[2][Cl][0], clangles[2][Cl][1], clcmdnum[0][Cl], clcmdnum[1][Cl], clcmdnum[2][Cl]);
                                    StacLog("\nTime between last 5 client ticks (most recent first):\n1 %f\n2 %f\n3 %f\n4 %f\n5 %f\n", engineTime[0][Cl] - engineTime[1][Cl],  engineTime[1][Cl] - engineTime[2][Cl],  engineTime[2][Cl] - engineTime[3][Cl],  engineTime[3][Cl] - engineTime[4][Cl],  engineTime[4][Cl] - engineTime[5][Cl]);
                                    // BAN USER if they trigger too many detections
                                    if (pSilentDetects[Cl] >= maxPsilentDetections && maxPsilentDetections > 0)
                                    {
                                        char reason[128];
                                        Format(reason, sizeof(reason), "%t", "pSilentBanMsg", pSilentDetects[Cl]);
                                        BanUser(userid, reason);
                                        MC_PrintToChatAll("%t", "pSilentBanAllChat", Cl, pSilentDetects[Cl]);
                                        StacLog("%t", "pSilentBanMsg", pSilentDetects[Cl]);
                                    }
                                }
                            }
                        }
                    }
                    /*
                        AIMSNAP DETECTION
                        Now lets be fair here - this also detects silent aim a lot too, but it's more for checking plain snaps.
                    */
                    if
                    (
                        // don't check if disabled
                        (
                            maxAimsnapDetections != -1
                        )
                        &&
                        // only go further if sens is definitely valid and not crazy high
                        (
                            5.0 > sensFor[Cl] > 0.0
                        )
                    )
                    {
                        // calculate 1 tick angle snap
                        float aDiffReal = CalcAngDeg(clangles[0][Cl], clangles[1][Cl]);
                        // refactored from smac - make sure we don't fuck up angles near the x/y axes!
                        if (aDiffReal > 180.0)
                        {
                            aDiffReal = FloatAbs(aDiffReal - 360.0);
                        }
                        // 30 seems reasonable, considering that we're working mouse movement into this as well
                        if (aDiffReal >= 30.0)
                        {
                            // TODO: MAKE SURE sensFor IS AS ACC AS POSSIBLE
                            int wx = abs(RoundFloat(mouse[0] * ( 1 / sensFor[Cl])));
                            int wy = abs(RoundFloat(mouse[1] * ( 1 / sensFor[Cl])));
                            if
                            (   // literally no mouse movement on both axes - buggy, don't enable
                                //(
                                //    wx == 0
                                //    &&
                                //    wy == 0
                                //)
                                //||
                                // stupidly big amts of mouse movement on either axis
                                //(
                                    wx >= 5000
                                    ||
                                    wy >= 5000
                                //)
                            )
                            {
                                aimsnapDetects[Cl]++;
                                // have this detection expire in 10 minutes
                                CreateTimer(600.0, Timer_decr_aimsnaps, userid);
                                if (aimsnapDetects[Cl] > 0)
                                {
                                    PrintToImportant("{hotpink}[StAC]{white} Aimsnap detection of {yellow}%.2f{white}° on %N.\nDetections so far: {palegreen}%i{white}.", aDiffReal, Cl,  aimsnapDetects[Cl]);
                                    PrintToImportant("{white}User Net Info: {palegreen}%.2f{white}%% loss, {palegreen}%.2f{white}%% choke, {palegreen}%.2f{white} ms ping", loss, choke, ping);
                                    PrintToImportant("User Mouse Movement (weighted to sens): abs(x): %i, abs(y): %i. sens: %f", wx, wy, sensFor[Cl]);
                                    PrintToImportant("User Mouse Movement (unweighted): x: %i, y: %i.", mouse[0], mouse[1]);
                                    CPrintToSTV("clangles0: x %.2f y %.2f clangles1: x %.2f y %.2f", clangles[0][Cl][0], clangles[0][Cl][1], clangles[1][Cl][0], clangles[1][Cl][1]);
                                    CPrintToSTV("clcmdnum0: %i clcmdnum1: %i clcmdnum2: %i", clcmdnum[0][Cl], clcmdnum[1][Cl], clcmdnum[2][Cl]);
                                    PrintToImportant("Time between last 5 client ticks (most recent first):\n1 %f 2 %f 3 %f 4 %f 5 %f", engineTime[0][Cl] - engineTime[1][Cl],  engineTime[1][Cl] - engineTime[2][Cl],  engineTime[2][Cl] - engineTime[3][Cl],  engineTime[3][Cl] - engineTime[4][Cl],  engineTime[4][Cl] - engineTime[5][Cl]);
                                    StacLog("[StAC] Aimsnap detection of %.2f° on \n%L.\nDetections so far: %i.", aDiffReal, Cl,  aimsnapDetects[Cl]);
                                    StacLog("\nNetwork:\n %.2f loss\n %.2f choke\n %.2f ms ping\nAngles:\n angles0: x %.2f y %.2f\n angles1: x %.2f y %.2f\n\nCmdnum:\n clcmdnum[0]: %i\n clcmdnum[1]: %i\n clcmdnum[2]: %i", loss, choke, ping, clangles[0][Cl][0], clangles[0][Cl][1], clangles[1][Cl][0], clangles[1][Cl][1], clcmdnum[0][Cl], clcmdnum[1][Cl], clcmdnum[2][Cl]);
                                    StacLog("\nTime between last 5 client ticks (most recent first):\n1 %f\n2 %f\n3 %f\n4 %f\n5 %f\n", engineTime[0][Cl] - engineTime[1][Cl],  engineTime[1][Cl] - engineTime[2][Cl],  engineTime[2][Cl] - engineTime[3][Cl],  engineTime[3][Cl] - engineTime[4][Cl],  engineTime[4][Cl] - engineTime[5][Cl]);
                                    StacLog("User Mouse Movement (weighted to sens): abs(x): %i, abs(y): %i.", wx, wy);
                                    StacLog("User Mouse Movement (unweighted): x: %i, y: %i.", mouse[0], mouse[1]);
                                    // BAN USER if they trigger too many detections
                                    if (aimsnapDetects[Cl] >= maxAimsnapDetections && maxAimsnapDetections > 0)
                                    {
                                        char reason[128];
                                        Format(reason, sizeof(reason), "%t", "AimsnapBanMsg", aimsnapDetects[Cl]);
                                        BanUser(userid, reason);
                                        MC_PrintToChatAll("%t", "AimsnapBanAllChat", Cl, aimsnapDetects[Cl]);
                                        StacLog("%t", "AimsnapBanMsg", aimsnapDetects[Cl]);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            /*
                BHOP DETECTION - using lilac and ssac as reference, this one's better tho
            */
            // IGNORE IF HIGHER TICKRATE (AKA invalid bhop mult) as bhops become SIGNIFICANTLY easier for noncheaters on higher tickrates
            // don't run this check if cvar is -1
            if (maxBhopDetections != -1)
            {
                if (bhopmult >= 1.0 && bhopmult <= 2.0)
                {
                    int flags = GetEntityFlags(Cl);

                    // reset their gravity if it's high!
                    if (highGrav[Cl])
                    {
                        SetEntityGravity(Cl, 1.0);
                        highGrav[Cl] = false;
                    }

                    if
                    (
                        // player didn't press jump
                        !(
                            buttons & IN_JUMP
                        )
                        // player is on the ground
                        &&
                        (
                            flags & FL_ONGROUND
                        )
                    )
                    // RESET COUNT!
                    {
                        // set to -1 to ignore single jumps, we ONLY want to count bhops
                        bhopDetects[Cl] = -1;
                        // count consecutive strings of bhops- a "consecutive string" is maxBhopDetectionsScaled or more
                        // bhopmult is for higher tickrate servers
                        if (isConsecStringOfBhops[Cl])
                        {
                            bhopConsecDetects[Cl]++;
                            isConsecStringOfBhops[Cl] = false;
                            // print to admins if we get a consec detection
                            // i don't want to ban legits who are REALLY fucking good at real bhopping, so I removed the consec ban code for now
                            PrintToImportant("{hotpink}[StAC]{white} Player %N {mediumpurple}bhopped consecutively {yellow}%i{mediumpurple} or more times{white}!\nDetections so far: {palegreen}%i", Cl, maxBhopDetectionsScaled, bhopConsecDetects[Cl]);
                            StacLog("[StAC] Player %N bhopped consecutively %i or more times! Detections so far: %i", Cl, maxBhopDetectionsScaled, bhopConsecDetects[Cl]);
                        }
                    }
                    // if a client didn't trigger the reset conditions above, they bhopped
                    else if
                    (
                        // last input didn't have a jump - include to prevent legits holding spacebar from triggering detections
                        !(
                            buttonsPrev[Cl] & IN_JUMP
                        )
                        &&
                        // player pressed jump
                        (
                            buttons & IN_JUMP
                        )
                        // they were on the ground when they pressed space
                        &&
                        (
                            flags & FL_ONGROUND
                        )
                    )
                    {
                        bhopDetects[Cl]++;
                        // print to player if halfway to getting punished
                        if (bhopDetects[Cl] >= maxBhopDetectionsScaled)
                        {
                            isConsecStringOfBhops[Cl] = true;
                            // print to admin
                            PrintToImportant("{hotpink}[StAC]{white} Player %N {mediumpurple}bhopped{white}!\nConsecutive detections so far: {palegreen}%i" , Cl, bhopDetects[Cl]);
                            StacLog("[StAC] Player %N bhopped! Consecutive detections so far: %i" , Cl, bhopDetects[Cl]);

                            // don't run antibhop if cvar is 0 or somehow -1 (sanity check)
                            if (maxBhopDetections > 0)
                            {
                                /* ANTIBHOP */
                                // zero the player's velocity and set their gravity to 8x.
                                // if idiot cheaters keep holding their spacebar for an extra second and do 2 tick perfect bhops WHILE at 8x gravity...
                                // ...we will catch them autohopping and ban them!
                                //TeleportEntity(Cl, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0})); // sourcepawn is disgusting btw
                                SetEntityGravity(Cl, 8.0);
                                highGrav[Cl] = true;
                            }
                        }
                        // punish on maxBhopDetectionsScaled + 2 (for the extra TWO tick perfect bhops at 8x grav with no warning - no human can do this!)
                        if (bhopDetects[Cl] >= (maxBhopDetectionsScaled + 2) && maxBhopDetections > 0)
                        {
                            char reason[128];
                            Format(reason, sizeof(reason), "%t", "bhopBanMsg", bhopDetects[Cl]);
                            BanUser(userid, reason);
                            MC_PrintToChatAll("%t", "bhopBanAllChat", Cl, bhopDetects[Cl]);
                            StacLog("%t", "bhopBanMsg", bhopDetects[Cl]);
                        }
                    }
                    buttonsPrev[Cl] = buttons;
                }
            }
            /*
                TURN BIND TEST
            */
            if
            (
                buttons & IN_LEFT
                ||
                buttons & IN_RIGHT
            )
            {
                if (maxAllowedTurnSecs != -1.0)
                {
                    turnTimes[Cl]++;
                    float turnSec = turnTimes[Cl] * tickinterv;
                    PrintToImportant("%t", "turnbindAdminMsg", Cl, turnSec);
                    // not worth logging to console tbqh
                    if (turnSec < maxAllowedTurnSecs)
                    {
                        MC_PrintToChat(Cl, "%t", "turnbindWarnPlayer");
                    }
                    else if (turnSec >= maxAllowedTurnSecs)
                    {
                        KickClient(Cl, "%t", "turnbindKickMsg");
                        StacLog("%t", "turnbindLogMsg", Cl);
                        MC_PrintToChatAll("%t", "turnbindAllChat", Cl);
                    }
                }
            }
        }
    }
    return Plugin_Continue;
}

public Action Timer_decr_aimsnaps(Handle timer, any userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        if (aimsnapDetects[Cl] > -1)
        {
            aimsnapDetects[Cl]--;
        }
    }
}

public Action Timer_decr_pSilent(Handle timer, any userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        if (pSilentDetects[Cl] > -1)
        {
            pSilentDetects[Cl]--;
        }
    }
}

char cvarsToCheck[][] =
{
    // misc vars
    "sensitivity",
    // possible cheat vars
    "cl_interpolate",
    // this is a useless check but we leave it here to set fov randomly to annoy cheaters
    "fov_desired",
    // network cvars
    "cl_cmdrate",
};

public void ConVarCheck(QueryCookie cookie, int Cl, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
    // don't bother checking bots or users who already queued to be banned
    if (!IsValidClient(Cl) || userBanQueued[Cl])
    {
        return;
    }
    int userid = GetClientUserId(Cl);
    // log something about cvar errors xcept for cheat only cvars
    if (result != ConVarQuery_Okay)
    {
        PrintToImportant("{hotpink}[StAC]{white} Could not query CVar %s on Player %N", Cl);
        StacLog("[StAC] Could not query cvar %s on player %N", cvarName, Cl);
    }

    if (StrEqual(cvarName, "sensitivity"))
    {
        sensFor[Cl] = StringToFloat(cvarValue);
    }

    /*
        POSSIBLE CHEAT VARS
    */
    // cl_interpolate (hidden cvar! should NEVER not be 1)
    else if (StrEqual(cvarName, "cl_interpolate"))
    {
        if (StringToInt(cvarValue) != 1)
        {
            if (banForMiscCheats)
            {
                char reason[128];
                Format(reason, sizeof(reason), "%t", "nolerpBanMsg");
                BanUser(userid, reason);
                MC_PrintToChatAll("%t", "nolerpBanAllChat", Cl);
                StacLog("%t", "nolerpBanMsg");
            }
            else
            {
                StacLog("[StAC] [Detection] Player %L is using NoLerp!", Cl);
            }
        }
    }
    // fov check #1 (if u get banned by this you are a clown)
    else if (StrEqual(cvarName, "fov_desired"))
    {
        // save fov to var to reset later with netpropcheck
        fovDesired[Cl] = StringToInt(cvarValue);
        // check just in case
        if (StringToInt(cvarValue) > 90)
        {
            char reason[128];
            Format(reason, sizeof(reason), "%t", "fovBanMsg");
            BanUser(userid, reason);
            MC_PrintToChatAll("%t", "fovBanAllChat", Cl);
            LogMessage("%t", "fovBanMsg");
        }
    }
    /*
        NETWORK CVARS
    */
    // cl_cmdrate
    else if (StrEqual(cvarName, "cl_cmdrate"))
    {
        if (!cvarValue[0])
        {
            StacLog("[StAC] Null string returned as cvar result when querying cvar %s on %N", cvarName, Cl);
            PrintToImportant("{hotpink}[StAC]{white} Null string returned as cvar result when querying cvar %s on %N", cvarName, Cl);
        }
        // cl_cmdrate needs to not have any non numerical chars (xcept the . sign if its a float) in it because otherwise player ping gets messed up on the scoreboard
        else if (MatchRegex(pingmaskRegex, cvarValue) <= 0)
        {
            if (kickForPingMasking)
            {
                KickClient(Cl, "%t", "pingmaskingKickMsg", cvarValue);
                StacLog("%t", "pingmaskingLogMsg", Cl, cvarValue);
                MC_PrintToChatAll("%t", "pingmaskingAllChat", Cl, cvarValue);
            }
        }
    }
    if (DEBUG)
    {
        StacLog("[StAC] Checked cvar %s value %s on %N", cvarName, cvarValue, Cl);
    }
}

// ban on invalid characters (newlines, carriage returns, etc)
public Action OnClientSayCommand(int Cl, const char[] command, const char[] sArgs)
{
    if
    (
        StrContains(sArgs, "\n", false) != -1
        ||
        StrContains(sArgs, "\r", false) != -1
    )
    {
        if (banForMiscCheats)
        {
            int userid = GetClientUserId(Cl);
            char reason[128];
            Format(reason, sizeof(reason), "%t", "newlineBanMsg");
            BanUser(userid, reason);
            MC_PrintToChatAll("%t", "newlineBanAllChat", Cl);
            StacLog("%t", "newlineBanMsg");
        }
        else
        {
            StacLog("[StAC] [Detection] Blocked newline print from player %L!", Cl);
        }
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

Action tvRecordListener(int client, const char[] command, int argc)
{
    if (client == 0)
    {
        if (SOURCEBANS)
        {
            // null out old info
            demoname[0] = '\0';
            // get the recording name
            GetCmdArg(1, demoname, sizeof(demoname));
            // strip dem extension if it exists because i don't want double extensions. we'll add it later
            ReplaceString(demoname, sizeof(demoname), ".dem", "", false);
        }
    }
}

public void BanUser(int userid, char[] reason)
{
    int Cl = GetClientOfUserId(userid);
    if (userBanQueued[Cl])
    {
        return;
    }
    if (SOURCEBANS)
    {
        if (demonameinSB)
        {
            // make sure demoname is initialized!
            if (demoname[0] != '\0')
            {
                char tvStatus[512];
                ServerCommandEx(tvStatus, sizeof(tvStatus), "tv_status");

                // is there a demo recording?
                if (StrContains(tvStatus, "Recording to", false) != -1)
                {
                    Format(demoname, sizeof(demoname), ". Demo file: %s.dem", demoname);
                    StrCat(reason, 256, demoname);
                    StacLog("Reason: %s", reason);
                }
                else
                {
                    StacLog("[StAC] No STV demo is being recorded! No STV info will be printed to SourceBans!");
                    // clear demoname
                    demoname[0] = '\0';
                }
            }
            else
            {
                StacLog("[StAC] Null string returned for demoname. No STV info will be printed to SourceBans!");
                // don't need to clear, it's already null
            }
        }

        SBPP_BanPlayer(0, Cl, 0, reason);
        userBanQueued[Cl] = true;
    }
    else
    {
        BanClient(Cl, 0, BANFLAG_AUTO, reason, reason, _, _);
        userBanQueued[Cl] = true;
    }
}

void NameCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if (IsValidClient(Cl))
    {
        char curName[64];
        GetClientName(Cl, curName, sizeof(curName));
        // ban for invalid characters in names
        if
        (
            // nullcore uses \xE0\xB9\x8A for namestealing but you can put it in your steam name so we cant check for it
            // might look into kicking for combining chars but who honestly cares
            // apparently other cheats use these:
            // thanks pazer
               StrContains(curName, "\xE2\x80\x8F", false) != -1
            || StrContains(curName, "\xE2\x80\x8E", false) != -1
            // cathook uses this
            || StrContains(curName, "\x1B", false)         != -1
            // just in case
            || StrContains(curName, "\n", false)           != -1
            || StrContains(curName, "\r", false)           != -1
        )
        {
            if (banForMiscCheats)
            {
                char reason[128];
                Format(reason, sizeof(reason), "%t", "illegalNameBanMsg");
                BanUser(userid, reason);
                MC_PrintToChatAll("%t", "illegalNameBanAllChat", Cl);
                StacLog("%t", "illegalNameBanMsg");
            }
            else
            {
                StacLog("[StAC] Player %N has illegal chars in their name!", Cl);
            }
        }
    }
}

void NetPropCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        // not a net prop. Whatever though.
        NameCheck(userid);

        // set real fov from client here - overrides cheat values (mostly works with ncc, untested on others)
        // we don't want to touch fov if a client is zoomed in while sniping or if they're in a bumper car or some other dumb halloween bullshit
        // we also don't want to check fov if they're dead or if cvars aren't optimized, because fov gets raised temporarily above 90 by teleporters if it isn't explicitly disabled by stac
        if
        (
               !TF2_IsPlayerInCondition(Cl, TFCond_Zoomed)
            && IsClientPlaying(Cl)
            && playerInBadCond[Cl] == 0
            && optimizeCvars
        )
        {
            // double check fov just in case
            if (GetEntProp(Cl, Prop_Send, "m_iFOV") > 90)
            {
                char reason[128];
                Format(reason, sizeof(reason), "%t", "fovBanMsg");
                BanUser(userid, reason);
                MC_PrintToChatAll("%t", "fovBanAllChat", Cl);
                LogMessage("%t", "fovBanMsg");
            }
            SetEntProp(Cl, Prop_Send, "m_iFOV", fovDesired[Cl]);
        }
        // forcibly disables thirdperson with some cheats
        ClientCommand(Cl, "firstperson");
        if (DEBUG)
        {
            StacLog("[StAC] Executed firstperson command on Player %N", Cl);
        }
        // lerp check (again). this time we check the netprop. Just in case.
        // don't check if not default tickrate
        if (tps < 70.0 && tps > 60.0)
        {
            float lerp = GetEntPropFloat(Cl, Prop_Data, "m_fLerpTime") * 1000;
            if (DEBUG)
            {
                StacLog("%.2f ms interp on %N", lerp, Cl);
            }
            if
            (
                lerp < min_interp_ms && min_interp_ms != -1
                ||
                lerp > max_interp_ms && max_interp_ms != -1
            )
            {
                KickClient(Cl, "%t", "interpKickMsg", lerp, min_interp_ms, max_interp_ms);
                StacLog("%t", "interpLogMsg",  Cl, lerp);
                MC_PrintToChatAll("%t", "interpAllChat", Cl, lerp);
            }
        }
        if (IsClientPlaying(Cl))
        {
            // fix broken equip slots. Note: this was patched by valve but you can still equip invalid items...
            // ...just without the annoying unequipping other people's items part.
            // cathook is cringe
            // only check if player has 3 valid hats on
            if (TF2_GetNumWearables(Cl) >= 3)
            {
                int slot1wearable = TF2_GetWearable(Cl, 0);
                int slot2wearable = TF2_GetWearable(Cl, 1);
                int slot3wearable = TF2_GetWearable(Cl, 2);
                // check that the ents are valid and have the correct entprops
                if
                (
                       IsValidEntity(slot1wearable)
                    && IsValidEntity(slot2wearable)
                    && IsValidEntity(slot3wearable)
                    && HasEntProp(slot1wearable, Prop_Send, "m_iItemDefinitionIndex")
                    && HasEntProp(slot2wearable, Prop_Send, "m_iItemDefinitionIndex")
                    && HasEntProp(slot3wearable, Prop_Send, "m_iItemDefinitionIndex")
                )
                {
                    int slot1itemdef = GetEntProp(slot1wearable, Prop_Send, "m_iItemDefinitionIndex");
                    int slot2itemdef = GetEntProp(slot2wearable, Prop_Send, "m_iItemDefinitionIndex");
                    int slot3itemdef = GetEntProp(slot3wearable, Prop_Send, "m_iItemDefinitionIndex");
                    if
                    (
                        // frontline field recorder
                        (
                               slot1itemdef == 302
                            || slot2itemdef == 302
                            || slot3itemdef == 302
                        )
                        // gibus
                        &&
                        (
                               slot1itemdef == 940
                            || slot2itemdef == 940
                            || slot3itemdef == 940
                        )
                        &&
                        // skull topper
                        (
                               slot1itemdef == 941
                            || slot2itemdef == 941
                            || slot3itemdef == 941
                        )
                    )
                    {
                        if (banForMiscCheats)
                        {
                            char reason[128];
                            Format(reason, sizeof(reason), "%t", "badItemSchemaBanMsg");
                            BanUser(userid, reason);
                            MC_PrintToChatAll("%t", "badItemSchemaBanAllChat", Cl);
                            StacLog("%t", "badItemSchemaBanMsg");
                        }
                        else
                        {
                            StacLog("[StAC] [Detection] Player %L has an illegal item schema!", Cl);
                        }
                    }
                }
            }
        }
    }
}

// these 3 functions are a god damn mess
void QueryEverything(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if (IsValidClient(Cl))
    {
        // check cvars!
        int i;
        QueryCvars(userid, i);
    }
}

void QueryCvars(int userid, int i)
{
    int Cl = GetClientOfUserId(userid);
    // don't check cvars if client is invalid
    if (IsValidClient(Cl))
    {
        if (i < sizeof(cvarsToCheck) || i == 0)
        {
            DataPack pack;
            QueryClientConVar(Cl, cvarsToCheck[i], ConVarCheck);
            i++;
            CreateDataTimer(2.5, timerqC, pack);
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
    QueryTimer[Cl] = null;
    if (IsValidClient(Cl))
    {
        if (DEBUG)
        {
            StacLog("[StAC] Checking client id, %i, %N", Cl, Cl);
        }
        // query the client!
        QueryEverything(userid);
        // check randomly using values of stac_min_randomcheck_secs & stac_max_randomcheck_secs for violating clients, then recheck with a new random value
        QueryTimer[Cl] = CreateTimer(GetRandomFloat(minRandCheckVal, maxRandCheckVal), Timer_CheckClientConVars, userid);
    }
}

// expensive!
void QueryEverythingAllClients()
{
    if (DEBUG)
    {
        StacLog("[StAC] Querying all clients");
    }
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

// Open log file for StAC
OpenStacLog()
{
    // current date for log file (gets updated on map change to not spread out maps across files on date changes)
    char curDate[32];

    // get current date
    FormatTime(curDate, sizeof(curDate), "%m%d%y", GetTime());

    // init path
    char path[128];
    // set path
    BuildPath(Path_SM, path, sizeof(path), "logs/stac");

    // create directory if not extant
    if (!DirExists(path, false))
    {
        LogMessage("[StAC] StAC directory not extant! Creating...");
        // 511 = 775 ?
        if (!CreateDirectory(path, 511, false))
        {
            LogMessage("[StAC] StAC directory could not be created!");
        }
    }

    // set up the full path here
    Format(path, sizeof(path), "%s/stac_%s.log", path, curDate);

    // actually create file here
    StacLogFile = OpenFile(path, "at", false);
}

// Close log file for StAC
CloseStacLog()
{
    if (StacLogFile != null)
    {
        if (DEBUG)
        {
            StacLog("[StAC] Closing StAC log file");
        }
        CloseHandle(StacLogFile);
        StacLogFile = null;
    }
}

// log to StAC log file
void StacLog(const char[] format, any ...)
{
    char buffer[254];
    VFormat(buffer, sizeof(buffer), format, 2);
    if (StacLogFile != null)
    {
        LogToOpenFile(StacLogFile, buffer);
    }
    else
    {
        LogMessage("[StAC] File handle invalid!");
        LogMessage("%s", buffer);
    }
}

// i hope youre proud of me, 9th grade geometry teacher
float CalcAngDeg(const float array1[2], const float array2[2])
{
    float arDiff[2];
    arDiff[0] = array1[0] - array2[0];
    arDiff[1] = array1[1] - array2[1];
    return SquareRoot(arDiff[0] * arDiff[0] + arDiff[1] * arDiff[1]);
}

// IsValidClient Stock
bool IsValidClient(int client)
{
    return ((0 < client <= MaxClients) && IsClientInGame(client) && !IsFakeClient(client));
}

// is client on a team and not dead
bool IsClientPlaying(int client)
{
    TFTeam team = TF2_GetClientTeam(client);
    if
    (
        IsPlayerAlive(client)
        &&
        (
            team != TFTeam_Unassigned
            &&
            team != TFTeam_Spectator
        )
    )
    {
        return true;
    }
    return false;
}

bool AreAnglesUnlaggyAndValid(int Cl)
{
    if
    (
        (
            // OK lets make sure we dont get any fake detections on startup
            // this also ignores weird angle resets in mge / dm
               clangles[0][Cl][0] != 0.00
            && clangles[0][Cl][1] != 0.00
            && clangles[1][Cl][0] != 0.00
            && clangles[1][Cl][1] != 0.00
            && clangles[2][Cl][0] != 0.00
            && clangles[2][Cl][1] != 0.00
        )
        &&
        // make sure ticks are sequential, hopefully avoid laggy players
        // example real detection:
        /*
            [StAC] pSilent / NoRecoil detection of 5.20° on <user>.
            Detections so far: 15
            User Net Info: 0.00% loss, 24.10% choke, 66.22 ms ping
             clcmdnum[0]: 61167
             clcmdnum[1]: 61166
             clcmdnum[2]: 61165
             angles0: x 8.82 y 127.68
             angles1: x 5.38 y 131.60
             angles2: x 8.82 y 127.68
        */
        (
               clcmdnum[0][Cl] - 1 == clcmdnum[1][Cl]
            && clcmdnum[1][Cl] - 1 == clcmdnum[2][Cl]
        )
    )
    {
        return true;
    }
    return false;
}

// print colored chat to all server/sourcemod admins
void PrintColoredChatToAdmins(const char[] format, any ...)
{
    char buffer[254];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && CheckCommandAccess(i, "sm_ban", ADMFLAG_ROOT))
        {
            SetGlobalTransTarget(i);
            VFormat(buffer, sizeof(buffer), format, 2);
            MC_PrintToChat(i, "%s", buffer);
        }
    }
}

// print to important ppl on server
void PrintToImportant(const char[] format, any ...)
{
    char buffer[254];
    VFormat(buffer, sizeof(buffer), format, 2);
    PrintColoredChatToAdmins("%s", buffer);
    CPrintToSTV("%s", buffer);
}

// adapted & deuglified from f2stocks
// Finds STV Bot to use for CPrintToSTV
int CachedSTV;
int FindSTV()
{
    if
    (
        !(
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
            if
            (
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
void CPrintToSTV(const char[] format, any ...)
{
    int stv = FindSTV();
    if (stv <= 0)
    {
        return;
    }
    char buffer[254];
    VFormat(buffer, sizeof(buffer), format, 2);
    MC_PrintToChat(stv, "%s", buffer);
}

// get entindx of player wearable, thanks scags
// https://github.com/Scags/The-Dump/blob/master/scripting/tfwearables.sp#L33-L40
int TF2_GetWearable(int client, int wearableidx)
{
    // 3540 linux
    // 3520 windows
    int offset = FindSendPropInfo("CTFPlayer", "m_flMaxspeed") - 20;
    Address m_hMyWearables = view_as< Address >(LoadFromAddress(GetEntityAddress(client) + view_as< Address >(offset), NumberType_Int32));
    return LoadFromAddress(m_hMyWearables + view_as< Address >(4 * wearableidx), NumberType_Int32) & 0xFFF;
}

int TF2_GetNumWearables(int client)
{
    // 3552 linux
    // 3532 windows
    int offset = FindSendPropInfo("CTFPlayer", "m_flMaxspeed") - 20 + 12;
    return GetEntData(client, offset);
}

any abs(x)
{
   return x > 0 ? x : -x;
}
