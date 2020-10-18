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
#include <tf2_stocks>
#include <autoexecconfig>
#undef REQUIRE_PLUGIN
#include <updater>
#include <sourcebanspp>

#define PLUGIN_VERSION  "3.4.0b"
#define UPDATE_URL      "https://raw.githubusercontent.com/sapphonie/StAC-tf2/master/updatefile.txt"

public Plugin myinfo =
{
    name             =  "Steph's AntiCheat (StAC)",
    author           =  "steph&nie",
    description      =  "Anticheat plugin [tf2 only] written by Stephanie. Originally forked from IntegriTF2 by Miggy (RIP)",
    version          =   PLUGIN_VERSION,
    url              =  "https://steph.anie.dev/"
}

// TIMER HANDLES
Handle g_hQueryTimer        [MAXPLAYERS+1];
Handle g_hTriggerTimedStuffTimer;
// TPS INFO
float tickinterv;
float tps;
float bhopmult;
// DETECTIONS PER CLIENT
int turnTimes               [MAXPLAYERS+1];
int fovDesired              [MAXPLAYERS+1];
int fakeAngDetects          [MAXPLAYERS+1];
int aimsnapDetects          [MAXPLAYERS+1];
int pSilentDetects          [MAXPLAYERS+1];
int bhopDetects             [MAXPLAYERS+1] = -1; // set to -1 to ignore single jumps
bool isConsecStringOfBhops  [MAXPLAYERS+1];
int bhopConsecDetects       [MAXPLAYERS+1];
// TIME SINCE LAST ACTION PER CLIENT
float timeSinceSpawn        [MAXPLAYERS+1];
float timeSinceTaunt        [MAXPLAYERS+1];
float timeSinceTeled        [MAXPLAYERS+1];
// STORED NET SETTINGS PER CLIENTS
float loss;
float choke;
float ping;
// STORED ANGLES PER CLIENT
float angles0               [MAXPLAYERS+1]   [2];
float angles1               [MAXPLAYERS+1]   [2];
float angles2               [MAXPLAYERS+1]   [2];
// STORED cmdnum PER CLIENT
int cmdnum0                 [MAXPLAYERS+1];
int cmdnum1                 [MAXPLAYERS+1];
int cmdnum2                 [MAXPLAYERS+1];
// STORED BUTTONS PER CLIENT
int buttonsPrev             [MAXPLAYERS+1];
// STORED GRAVITY STATE PER CLIENT
bool highGrav               [MAXPLAYERS+1];
// STORED VARS FOR INDIVIDUAL CLIENTS
bool playerTaunting         [MAXPLAYERS+1];
bool userBanQueued          [MAXPLAYERS+1];

// NATIVE BOOLS
bool SOURCEBANS;

// CVARS
ConVar stac_enabled;
ConVar stac_verbose_info;
ConVar stac_max_allowed_turn_secs;
ConVar stac_kick_for_pingmasking;
ConVar stac_ban_for_misccheats;
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
int maxAimsnapDetections    = 25;
int maxPsilentDetections    = 15;
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

// current date for log file (gets updated on map change to not spread out maps across files on date changes)
char curDate[32];

// demoname for currently recording demo if extant
char demoname[128];

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
    // grab player hurt events (for aimsnaps)
    HookEvent("player_hurt", ePlayerHurt, EventHookMode_Post);

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

    FormatTime(curDate, sizeof(curDate), "%m%d%y", GetTime());

    // check sv cheats on startup
    if (GetConVarBool(FindConVar("sv_cheats")))
    {
        StacLog("[StAC] sv_cheats set to 1 - unloading plugin!!!");
        ServerCommand("sm plugins unload stac");
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
    for (int Cl = 0; Cl < MaxClients + 1; Cl++)
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
                    ReplyToCommand(callingCl, "- %i psilent / norecoil detections for %N", pSilentDetects[Cl], Cl);
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

public void OnPluginEnd()
{
    NukeTimers();
    OnMapEnd();
    StacLog("[StAC] Plugin vers. ---- %s ---- unloaded", PLUGIN_VERSION);
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
    for (int Cl = 0; Cl < MaxClients + 1; Cl++)
    {
        if (g_hQueryTimer[Cl] != null)
        {
            if (DEBUG)
            {
                StacLog("[StAC] Destroying timer for %L", Cl);
            }
            KillTimer(g_hQueryTimer[Cl]);
            g_hQueryTimer[Cl] = null;
        }
    }
    if (g_hTriggerTimedStuffTimer != null)
    {
        if (DEBUG)
        {
            StacLog("[StAC] Destroying reseeding timer");
        }
        KillTimer(g_hTriggerTimedStuffTimer);
        g_hTriggerTimedStuffTimer = null;
    }
}

// recreate the timers we just nuked
void ResetTimers()
{
    for (int Cl = 0; Cl < MaxClients + 1; Cl++)
    {
        if (IsValidClient(Cl))
        {
            if (DEBUG)
            {
                StacLog("[StAC] Creating timer for %L", Cl);
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

public Action ePlayerHurt(Handle event, char[] name, bool dontBroadcast)
{
    // attacker clientid
    int Cl = GetClientOfUserId(GetEventInt(event, "attacker"));
    int userid = GetEventInt(event, "attacker");
    // victim clientid
    int vCl = GetClientOfUserId(GetEventInt(event, "userid"));
    // attacker weaponid
    int weaponid = GetEventInt(event, "weaponid");

    if  (
            // make sure these are real players
                IsValidClient(Cl)
            // && IsValidClient(vCl)
            // ignore self damage
            // && vCl != Cl
            // ignore sentries
             && weaponid != TF_WEAPON_SENTRY_BULLET
             && weaponid != TF_WEAPON_SENTRY_ROCKET
        )
    {
        if (AreAnglesUnlaggyAndValid(Cl))
        {
            /*
                PLAIN AIMSNAP DETECTION
            */
            // don't run this check if cvar is -1
            if (maxAimsnapDetections != -1)
            {
                // calculate 1 tick angle snap
                float aDiffReal = CalcAngDeg(angles0[Cl], angles1[Cl]);
                // refactored from smac - make sure we don't fuck up angles near the x/y axes!
                if (aDiffReal > 180.0)
                {
                    aDiffReal = FloatAbs(aDiffReal - 360.0);
                }
                // 20 seems reasonable, so lets do 30 just in case
                if (aDiffReal >= 30.0)
                {
                    aimsnapDetects[Cl]++;
                    // have this detection expire in 20 minutes
                    CreateTimer(1200.0, Timer_decr_aimsnaps, userid);
                    PrintToImportant("{hotpink}[StAC]{white} Plain Aimsnap detection of {red}%.2f{white}° on %N.\nDetections so far: {palegreen}%i", aDiffReal, Cl,  aimsnapDetects[Cl]);
                    PrintToImportant("{white}User Net Info: {palegreen}%.2f{white}%% loss, {palegreen}%.2f{white}%% choke, {palegreen}%.2f{white} ms ping", loss, choke, ping);
                    CPrintToSTV("angles0: x %.2f y %.2f angles1: x %.2f y %.2f", angles0[Cl][0], angles0[Cl][1], angles1[Cl][0], angles1[Cl][1]);
                    CPrintToSTV("cmdnum0: %i cmdnum1: %i cmdnum2: %i", cmdnum0[Cl], cmdnum1[Cl], cmdnum2[Cl]);
                    StacLog("[StAC] Plain Aimsnap of %.2f° on \n%L.\nDetections so far: %i", aDiffReal, Cl,  aimsnapDetects[Cl]);
                    StacLog("\nNetwork:\n %.2f loss\n %.2f choke\n %.2f ms ping\nAngles:\n angles0: x %.2f y %.2f\n angles1: x %.2f y %.2f\nCmdnum:\n cmdnum0: %i\n cmdnum1: %i\n cmdnum2: %i", loss, choke, ping, angles0[Cl][0], angles0[Cl][1], angles1[Cl][0], angles1[Cl][1], cmdnum0[Cl], cmdnum1[Cl], cmdnum2[Cl]);
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

public void TF2_OnConditionAdded(int Cl, TFCond condition)
{
    if (IsValidClient(Cl))
    {
        if (condition == TFCond_Taunting)
        {
            playerTaunting[Cl] = true;
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
    FormatTime(curDate, sizeof(curDate), "%m%d%y", GetTime());
    ActuallySetRandomSeed();
    DoTPSMath();
    ResetTimers();
}

public void OnMapEnd()
{
    FormatTime(curDate, sizeof(curDate), "%m%d%y", GetTime());
    ActuallySetRandomSeed();
    DoTPSMath();
    NukeTimers();
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
    buttonsPrev[Cl]             = 0;
    turnTimes[Cl]               = 0;
    aimsnapDetects[Cl]          = 0;
    pSilentDetects[Cl]          = 0;
    bhopDetects[Cl]             = 0;
    isConsecStringOfBhops[Cl]   = false;
    bhopConsecDetects[Cl]       = 0;
    fakeAngDetects[Cl]          = 0;
    timeSinceSpawn[Cl]          = 0.0;
    timeSinceTaunt[Cl]          = 0.0;
    timeSinceTeled[Cl]          = 0.0;
    userBanQueued[Cl]           = false;
    if (highGrav[Cl])
    {
        highGrav[Cl] = false;
        if (IsValidEntity(Cl))
        {
            SetEntityGravity(Cl, 1.0);
        }
    }
}

public void OnClientPostAdminCheck(int Cl)
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
            StacLog("[StAC] %N joined. Checking cvars", Cl);
        }
        g_hQueryTimer[Cl] = CreateTimer(0.01, Timer_CheckClientConVars, userid);
    }
}

public void OnClientDisconnect(int Cl)
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
    // make sure client is real & not a bot.
    if (IsValidClient(Cl))
    {
        // grab current time to compare to time since last spawn/taunt/tele
        float engineTime = GetEngineTime();
        // from ssac - block invalid cmds
        if (cmdnum <= 0)
        {
            return Plugin_Handled;
        }

        // convert to percentages
        loss = GetClientAvgLoss(Cl, NetFlow_Both) * 100.0;
        choke = GetClientAvgChoke(Cl, NetFlow_Both) * 100.0;
        // convert to ms
        ping = GetClientAvgLatency(Cl, NetFlow_Both) * 1000.0;

        /*
            AIMSNAP DETECTION
        */
        if  (
                // we have to do all these annoying checks to make sure we get as few false positives as possible.
                (
                    // make sure client is on a team & alive,
                        IsClientPlaying(Cl)
                    // ...isn't taunting,
                     && !playerTaunting[Cl]
                    // ...didn't recently spawn,
                     && engineTime - 0.25 > timeSinceSpawn[Cl]
                    // ...didn't recently taunt,
                     && engineTime - 0.25 > timeSinceTaunt[Cl]
                    // ...didn't recently teleport,
                     && engineTime - 0.25 > timeSinceTeled[Cl]
                    // ...isn't already queued to be banned,
                     && !userBanQueued[Cl]
                    // ...doesn't have 10% or more packet loss,
                     && loss < 10.0
                    //// ...doesn't have 51% or more packet choke,
                     && choke < 51.0
                    // ...and isn't timing out.
                     && !IsClientTimingOut(Cl)
                )
                &&
                // if both anglesnap detection cvars are -1, don't bother even going past this point.
                (
                    maxAimsnapDetections != -1
                     ||
                    maxPsilentDetections != -1
                )
            )
        {
            // debug
            //StacLog("%f %f", angles[0], angles[1]);

            // we need this later for decrimenting psilent detections after 20 minutes!
            int userid = GetClientUserId(Cl);

            // grab angles
            // thanks to nosoop from the sm discord for some help with this
            angles2[Cl][0] = angles1[Cl][0];
            angles2[Cl][1] = angles1[Cl][1];
            angles1[Cl][0] = angles0[Cl][0];
            angles1[Cl][1] = angles0[Cl][1];
            angles0[Cl][0] = angles[0];
            angles0[Cl][1] = angles[1];

            // grab cmdnum
            cmdnum2[Cl] = cmdnum1[Cl];
            cmdnum1[Cl] = cmdnum0[Cl];
            cmdnum0[Cl] = cmdnum;

            // R O U N D ( fuzzy psilent detection to detect lmaobox silent+ SOOON )
            // angles2[Cl][0] = RoundFloat(angles2[Cl][0] * 10.0) / 10.0;
            // angles2[Cl][1] = RoundFloat(angles2[Cl][1] * 10.0) / 10.0;
            // angles1[Cl][0] = RoundFloat(angles1[Cl][0] * 10.0) / 10.0;
            // angles1[Cl][1] = RoundFloat(angles1[Cl][1] * 10.0) / 10.0;
            // angles0[Cl][0] = RoundFloat(angles0[Cl][0] * 10.0) / 10.0;
            // angles0[Cl][1] = RoundFloat(angles0[Cl][1] * 10.0) / 10.0;
            if (AreAnglesUnlaggyAndValid)
            {
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
                // don't run this check if cvar is -1
                if (maxPsilentDetections != -1)
                {
                    if
                    (
                        // so the current and 2nd previous angles match...
                        (
                                angles0[Cl][0] == angles2[Cl][0]
                             && angles0[Cl][1] == angles2[Cl][1]
                        )
                        &&
                        // BUT the 1st previous (in between) angle doesnt?
                        (
                                angles1[Cl][0] != angles0[Cl][0]
                             && angles1[Cl][1] != angles0[Cl][1]
                             && angles1[Cl][0] != angles2[Cl][0]
                             && angles1[Cl][1] != angles2[Cl][1]
                        )
                    )
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
                        float aDiffReal = CalcAngDeg(angles0[Cl], angles1[Cl]);
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
                            PrintToImportant("{hotpink}[StAC]{white} SilentAim detection of {yellow}%.2f{white}° on %N.\nDetections so far: {palegreen}%i", aDiffReal, Cl,  pSilentDetects[Cl]);
                            PrintToImportant("{white}User Net Info: {palegreen}%.2f{white}%% loss, {palegreen}%.2f{white}%% choke, {palegreen}%.2f{white} ms ping", loss, choke, ping);
                            CPrintToSTV("angles0: x %.2f y %.2f angles1: x %.2f y %.2f angles2: x %.2f y %.2f", angles0[Cl][0], angles0[Cl][1], angles1[Cl][0], angles1[Cl][1], angles2[Cl][0], angles2[Cl][1]);
                            CPrintToSTV("cmdnum0: %i cmdnum1: %i cmdnum2: %i", cmdnum0[Cl], cmdnum1[Cl], cmdnum2[Cl]);
                            StacLog("[StAC] SilentAim detection of %.2f° on \n%L.\nDetections so far: %i", aDiffReal, Cl,  pSilentDetects[Cl]);
                            StacLog("\nNetwork:\n %.2f loss\n %.2f choke\n %.2f ms ping\nAngles:\n angles0: x %.2f y %.2f\n angles1: x %.2f y %.2f\n angles2: x %.2f y %.2f\nCmdnum:\n cmdnum0: %i\n cmdnum1: %i\n cmdnum2: %i", loss, choke, ping, angles0[Cl][0], angles0[Cl][1], angles1[Cl][0], angles1[Cl][1], angles2[Cl][0], angles2[Cl][1], cmdnum0[Cl], cmdnum1[Cl], cmdnum2[Cl]);
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

                    if  (
                            !(buttons & IN_JUMP)  // player didn't press jump
                             &&
                            (flags & FL_ONGROUND) // player is on the ground
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
                    else if (
                                !(buttonsPrev[Cl] & IN_JUMP) // last input didn't have a jump - include to prevent legits holding spacebar from triggering detections
                                 && (buttons & IN_JUMP)      // player pressed jump
                                 && (flags & FL_ONGROUND)    // they were on the ground when they pressed space
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
                                // zero the player's velocity and set their gravity to 8x.
                                // if idiot cheaters keep holding their spacebar for an extra second and do 2 tick perfect bhops WHILE at 8x gravity...
                                // ...we will catch them autohopping and ban them!
                                TeleportEntity(Cl, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0})); // sourcepawn is disgusting btw
                                SetEntityGravity(Cl, 8.0);
                                highGrav[Cl] = true;
                            }
                            /* ANTIBHOP */

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
                TURN BIND TEST
            */
            if  (
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
        if (aimsnapDetects[Cl] > 0)
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
    // network cvars
    "cl_cmdrate",
};

public void ConVarCheck(QueryCookie cookie, int Cl, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
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
        StacLog("[StAC] Could not query cvar %s on player %N", cvarName, Cl);
    }
    /*
        POSSIBLE CHEAT VARS
    */
    // cl_interpolate (hidden cvar! should NEVER not be 1)
    if (StrEqual(cvarName, "cl_interpolate"))
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
    /*
        NETWORK CVARS
    */
    // cl_cmdrate
    else if (StrEqual(cvarName, "cl_cmdrate"))
    {
        if (!kickForPingMasking)
        {
            return;
        }
        if (!cvarValue[0])
        {
            StacLog("[StAC] Null string returned as cvar result when querying cvar %s on %N", cvarName, Cl);
            PrintToImportant("{hotpink}[StAC]{white} Null string returned as cvar result when querying cvar %s on %N", cvarName, Cl);
        }
        // cl_cmdrate needs to not have any non numerical chars (xcept the . sign if its a float) in it because otherwise player ping gets messed up on the scoreboard
        else if (MatchRegex(pingmaskRegex, cvarValue) <= 0)
        {
            KickClient(Cl, "%t", "pingmaskingKickMsg", cvarValue);
            StacLog("%t", "pingmaskingLogMsg", Cl, cvarValue);
            MC_PrintToChatAll("%t", "pingmaskingAllChat", Cl, cvarValue);
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
    if  (
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
            demoname = "";
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
                if (StrContains(tvStatus, "Recording to", false) != -1)
                {
                    Format(demoname, sizeof(demoname), ". Demo file: %s.dem", demoname);
                    StrCat(reason, 256, demoname);
                    StacLog("Reason: %s", reason);
                }
                else
                {
                    StacLog("[StAC] No STV demo is being recorded! No STV info will be printed to SourceBans!");
                    // null out old info (just in case)
                    demoname = "";
                    demoname[0] = '\0';
                }
            }
            else
            {
                StacLog("[StAC] Null string returned for demoname. No STV info will be printed to SourceBans!");
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
        if (
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
        // we don't want to touch fov if a client is zoomed in while sniping...
        if (!TF2_IsPlayerInCondition(Cl, TFCond_Zoomed))
        {
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
            if  (
                    lerp < min_interp_ms && min_interp_ms != -1
                     ||
                    lerp > max_interp_ms && max_interp_ms != -1
                )
            {
                KickClient(Cl, "%t", "interpKickMsg", lerp, min_interp_ms, max_interp_ms);
                StacLog("%t", "interpLogMsg",  Cl, lerp);
                MC_PrintToChatAll("%t", "interpAllChat", Cl, lerp);
            }
            /* ping netprop check. some cheats can set this to below 5 by fucking up their m_iPing netprop, but it's clamped here:
                https://github.com/TheAlePower/TeamFortress2/blob/1b81dded673d49adebf4d0958e52236ecc28a956/tf2_src/game/server/util.cpp#L708
            this is nested under the tps check because there's something about cmdrate fuckery in the UTIL_GetPlayerConnectionInfo and i don't trust it
            to NOT be dependant on tickrate somehow. further, although the ping prop gets set here:
                https://github.com/TheAlePower/TeamFortress2/blob/1b81dded673d49adebf4d0958e52236ecc28a956/tf2_src/game/server/player_resource.cpp#L137-L148
            the ping on scoreboard should theoretically __never__ be below 5 or above 1000 because there should never be a value below 5 or above 1000 to throw the average off.
            ---> THIS IS AN EXPERIMENTAL CHECK <---
            */
            int pingprop = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iPing", _, Cl);

            // check that client has valid net info
            if (GetClientAvgLatency(Cl, NetFlow_Outgoing) != -1)
            {
                if (pingprop < 5 || pingprop > 1000)
                {
                    if (banForMiscCheats)
                    {
                        //char reason[128];
                        //Format(reason, sizeof(reason), "%t", "illegalPingPropBanMsg", pingprop);
                        //BanUser(userid, reason);
                        //MC_PrintToChatAll("%t", "illegalPingPropBanAllChat", Cl);
                        StacLog("%t", "illegalPingPropBanMsg");
                    }
                    else
                    {
                        StacLog("[StAC] [Detection] Player %L (probably) has illegal scoreboard ping of %i!", Cl, pingprop);
                    }
                }
            }
            else
            {
                StacLog("[StAC] Client %N had no valid network info!", Cl);
            }
        }
        if (IsClientPlaying(Cl))
        {
            // fix broken equip slots. Note: this was patched by valve but you can still equip invalid items...
            // ...just without the annoying unequipping other people's items part.
            // cathook is cringe
            // only check if player has 3 valid hats on
            if (TF2_GetNumWearables(Cl) == 3)
            {
                int slot1wearable = TF2_GetWearable(Cl, 0);
                int slot2wearable = TF2_GetWearable(Cl, 1);
                int slot3wearable = TF2_GetWearable(Cl, 2);
                // check that the ents are valid and have the correct entprops
                if  (
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
                    if  (
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
        int i = 0;
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
    g_hQueryTimer[Cl] = null;
    if (IsValidClient(Cl))
    {
        if (DEBUG)
        {
            StacLog("[StAC] Checking client id, %i, %N", Cl, Cl);
        }
        // query the client!
        QueryEverything(userid);
        // check randomly using values of stac_min_randomcheck_secs & stac_max_randomcheck_secs for violating clients, then recheck with a new random value
        g_hQueryTimer[Cl] = CreateTimer(GetRandomFloat(minRandCheckVal, maxRandCheckVal), Timer_CheckClientConVars, userid);
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

// i hope youre proud of me, 9th grade geometry teacher
stock float CalcAngDeg(const float array1[2], const float array2[2])
{
    float arDiff[2];
    arDiff[0] = array1[0] - array2[0];
    arDiff[1] = array1[1] - array2[1];
    return SquareRoot(arDiff[0] * arDiff[0] + arDiff[1] * arDiff[1]);
}

// IsValidClient Stock
stock bool IsValidClient(int client)
{
    return
    (
        (
            0 < client <= MaxClients
        )
        && IsClientInGame(client)
        && !IsFakeClient(client)
    );
}

// is client on a team and not dead
stock bool IsClientPlaying(int client)
{
    TFTeam team = TF2_GetClientTeam(client);
    if  (
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

stock bool AreAnglesUnlaggyAndValid(int Cl)
{
    if
        (
            (
                // OK lets make sure we dont get any fake detections on startup
                // this also ignores weird angle resets in mge / dm
                    angles0[Cl][0] != 0.000000
                 && angles0[Cl][1] != 0.000000
                 && angles1[Cl][0] != 0.000000
                 && angles1[Cl][1] != 0.000000
                 && angles2[Cl][0] != 0.000000
                 && angles2[Cl][1] != 0.000000
            )
            &&
            // make sure ticks are sequential, hopefully avoid laggy players
            // example real detection:
            /*
            [StAC] pSilent / NoRecoil detection of 5.20° on <user>.
            Detections so far: 15
            User Net Info: 0.00% loss, 24.10% choke, 66.22 ms ping
             cmdnum0: 61167
             cmdnum1: 61166
             cmdnum2: 61165
             angles0: x 8.82 y 127.68
             angles1: x 5.38 y 131.60
             angles2: x 8.82 y 127.68
            */
            (
                   cmdnum0[Cl] - 1 == cmdnum1[Cl]
                && cmdnum1[Cl] - 1 == cmdnum2[Cl]
            )
        )
        {
            return true;
        }
    return false;
}


// print colored chat to all server/sourcemod admins
stock void PrintColoredChatToAdmins(const char[] format, any ...)
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
stock void PrintToImportant(const char[] format, any ...)
{
    char buffer[254];
    VFormat(buffer, sizeof(buffer), format, 2);
    PrintColoredChatToAdmins("%s", buffer);
    CPrintToSTV("%s", buffer);
}

// print to important ppl on server
stock void StacLog(const char[] format, any ...)
{
    char buffer[254];
    VFormat(buffer, sizeof(buffer), format, 2);

    // init curdate if uninited
    if (curDate[0] == '\0')
    {
        FormatTime(curDate, sizeof(curDate), "%m%d%y", GetTime());
    }

    //LogMessage("%s", buffer);

    // will use logtoopenfile eventually, likely hooked to onmapstart and end
    if (logtofile)
    {
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

        // actually log here
        LogToFileEx(path, buffer);
    }
}

// adapted & deuglified from f2stocks
// Finds STV Bot to use for CPrintToSTV
int CachedSTV;
stock int FindSTV()
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
stock void CPrintToSTV(const char[] format, any ...)
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
stock int TF2_GetWearable(int client, int wearableidx)
{
    // 3540 linux
    // 3520 windows
    int offset = FindSendPropInfo("CTFPlayer", "m_flMaxspeed") - 20;
    Address m_hMyWearables = view_as< Address >(LoadFromAddress(GetEntityAddress(client) + view_as< Address >(offset), NumberType_Int32));
    return LoadFromAddress(m_hMyWearables + view_as< Address >(4 * wearableidx), NumberType_Int32) & 0xFFF;
}

stock int TF2_GetNumWearables(int client)
{
    // 3552 linux
    // 3532 windows
    int offset = FindSendPropInfo("CTFPlayer", "m_flMaxspeed") - 20 + 12;
    return GetEntData(client, offset);
}
