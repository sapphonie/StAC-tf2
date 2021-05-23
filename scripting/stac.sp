// see the readme for more info:
// https://github.com/stephanieLGBT/StAC-tf2/blob/master/README.md
// written by steph, chloe, and liza
// i love my partners
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <regex>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
// external incs
#include <morecolors>
#include <autoexecconfig>
#undef REQUIRE_PLUGIN
#include <updater>
#include <sourcebanspp>
#include <discord>
#undef REQUIRE_EXTENSIONS
#include <steamtools>
#include <SteamWorks>

#pragma newdecls required

#define PLUGIN_VERSION  "5.0.3a"

#define UPDATE_URL      "https://raw.githubusercontent.com/sapphonie/StAC-tf2/master/updatefile.txt"

public Plugin myinfo =
{
    name             =  "Steph's AntiCheat (StAC)",
    author           =  "steph&nie",
    description      =  "Anticheat plugin [tf2 only] written by Stephanie. Originally forked from IntegriTF2 by Miggy (RIP)",
    version          =   PLUGIN_VERSION,
    url              =  "https://sappho.io"
}

#define TFMAXPLAYERS 33

// TIMER HANDLES
Handle QueryTimer           [TFMAXPLAYERS+1];
Handle TriggerTimedStuffTimer;

// hud sync handles
Handle HudSyncRunCmd;
Handle HudSyncRunCmdMisc;
Handle HudSyncNetwork;

bool LiveFeedOn             [TFMAXPLAYERS+1];

float steamLastOnlineTime;
// TPS INFO
float tickinterv;
float tps;
// DETECTIONS PER CLIENT
int turnTimes               [TFMAXPLAYERS+1];
int fakeAngDetects          [TFMAXPLAYERS+1];
int aimsnapDetects          [TFMAXPLAYERS+1] = -1; // set to -1 to ignore first detections, as theyre most likely junk
int pSilentDetects          [TFMAXPLAYERS+1] = -1; // ^
int bhopDetects             [TFMAXPLAYERS+1] = -1; // set to -1 to ignore single jumps
int cmdnumSpikeDetects      [TFMAXPLAYERS+1];
int tbotDetects             [TFMAXPLAYERS+1] = -1;
int spinbotDetects          [TFMAXPLAYERS+1];
int fakeChokeDetects        [TFMAXPLAYERS+1];
int cmdrateSpamDetects      [TFMAXPLAYERS+1];
//int backtrackDetects      [TFMAXPLAYERS+1];

bool waitStatus;

// TIME SINCE LAST ACTION PER CLIENT
float timeSinceSpawn        [TFMAXPLAYERS+1];
float timeSinceTaunt        [TFMAXPLAYERS+1];
float timeSinceTeled        [TFMAXPLAYERS+1];
float timeSinceNullCmd      [TFMAXPLAYERS+1];
// STORED ANGLES PER CLIENT -
// we want the last 5 angles, including roll
float clangles              [TFMAXPLAYERS+1][5][3];

// we only need the last 3 angles, and we dont need roll
float fuzzyClangles         [TFMAXPLAYERS+1][3][2];

// STORED POS PER CLIENT - we want the current and last position (which is a vector) of the client
float clpos                 [TFMAXPLAYERS+1][2][3];
// STORED cmdnum PER CLIENT
int clcmdnum                [TFMAXPLAYERS+1][6];
// STORED tickcount PER CLIENT
int cltickcount             [TFMAXPLAYERS+1][6];

// STORED tickcount PER CLIENT
int climpulse               [TFMAXPLAYERS+1];

// MAX tickcount PER CLIENT [ for backtracking ]
//int maxTickCountFor[TFMAXPLAYERS+1];

// STORED BUTTONS PER CLIENT
int clbuttons               [TFMAXPLAYERS+1][6];
// STORED MOUSE PER CLIENT
int clmouse                 [TFMAXPLAYERS+1][2];

float calcCmdrateFor        [TFMAXPLAYERS+1];
// STORED GRAVITY STATE PER CLIENT
bool highGrav               [TFMAXPLAYERS+1];
// STORED MISC VARS PER CLIENT
bool playerTaunting         [TFMAXPLAYERS+1];
int playerInBadCond         [TFMAXPLAYERS+1];
bool userBanQueued          [TFMAXPLAYERS+1];
// STORED SENS PER CLIENT
float sensFor               [TFMAXPLAYERS+1];
// get last 11 ticks
float engineTime            [TFMAXPLAYERS+1][11];
// time since the map started (duh)
float timeSinceMapStart;
// time since the last lag spike occurred
float timeSinceLagSpike;
// weapon name, gets passed to aimsnap check
char hurtWeapon             [TFMAXPLAYERS+1][256];
// time since player did damage, for aimsnap check
bool didBangOnFrame         [TFMAXPLAYERS+1][3];
bool didHurtOnFrame         [TFMAXPLAYERS+1][3];

char SteamAuthFor           [TFMAXPLAYERS+1][64];

// time since player did damage, for aimsnap check
bool didBangThisFrame       [TFMAXPLAYERS+1];
bool didHurtThisFrame       [TFMAXPLAYERS+1];

// for fakechoke
int lastChokeAmt            [TFMAXPLAYERS+1];
int lastChokeCmdnum         [TFMAXPLAYERS+1];

// network info

float lossFor               [TFMAXPLAYERS+1];
float chokeFor              [TFMAXPLAYERS+1];
float inchokeFor            [TFMAXPLAYERS+1];
float outchokeFor           [TFMAXPLAYERS+1];
float pingFor               [TFMAXPLAYERS+1];
float rateFor               [TFMAXPLAYERS+1];
float ppsFor                [TFMAXPLAYERS+1];

char hostname[64];
char hostipandport[24];

int imaxcmdrate;
int imincmdrate;
int imaxupdaterate;
int iminupdaterate;


// NATIVE BOOLS
bool SOURCEBANS;
bool GBANS;
bool STEAMTOOLS;
bool STEAMWORKS;
bool AIMPLOTTER;
bool DISCORD;

char detectionTemplate[1024] = "{ \"embeds\": [ { \"title\": \"StAC Detection!\", \"color\": 16738740, \"fields\": [ { \"name\": \"Player\", \"value\": \"%N\" } , { \"name\": \"SteamID\", \"value\": \"%s\" }, { \"name\": \"Detection type\", \"value\": \"%s\" }, { \"name\": \"Detection\", \"value\": \"%i\" }, { \"name\": \"Hostname\", \"value\": \"%s\" }, { \"name\": \"IP\", \"value\": \"%s\" } , { \"name\": \"Current Demo Recording\", \"value\": \"%s\" } ] } ] }";

char generalTemplate[1024] = "{ \"embeds\": [ { \"title\": \"StAC Message\", \"color\": 16738740, \"fields\": [ { \"name\": \"Player\", \"value\": \"%N\" } , { \"name\": \"SteamID\", \"value\": \"%s\" }, { \"name\": \"Message\", \"value\": \"%s\" }, { \"name\": \"Hostname\", \"value\": \"%s\" }, { \"name\": \"IP\", \"value\": \"%s\" } , { \"name\": \"Current Demo Recording\", \"value\": \"%s\" } ] } ] }";

// are we in MVM
bool MVM;
// CVARS
ConVar stac_enabled;
ConVar stac_verbose_info;
ConVar stac_max_allowed_turn_secs;
ConVar stac_ban_for_misccheats;
ConVar stac_optimize_cvars;
ConVar stac_max_aimsnap_detections;
ConVar stac_max_psilent_detections;
ConVar stac_max_bhop_detections;
ConVar stac_max_fakeang_detections;
ConVar stac_max_cmdnum_detections;
ConVar stac_max_tbot_detections;
ConVar stac_max_spinbot_detections;
ConVar stac_max_cmdrate_spam_detections;
ConVar stac_min_interp_ms;
ConVar stac_max_interp_ms;
ConVar stac_min_randomcheck_secs;
ConVar stac_max_randomcheck_secs;
ConVar stac_include_demoname_in_banreason;
ConVar stac_log_to_file;
ConVar stac_fixpingmasking_enabled;
ConVar stac_kick_unauthed_clients;

// VARIOUS DETECTION BOUNDS & CVAR VALUES
bool DEBUG                  = false;
float maxAllowedTurnSecs    = -1.0;
bool banForMiscCheats       = true;
bool optimizeCvars          = true;

int maxAimsnapDetections    = 20;
int maxPsilentDetections    = 10;
int maxFakeAngDetections    = 10;
int maxBhopDetections       = 10;
int maxCmdnumDetections     = 20;
int maxTbotDetections       = 0;
int maxSpinbotDetections    = 50;
int maxCmdrateSpamDetects   = 25;

// interp limits
int min_interp_ms           = -1;
int max_interp_ms           = 101;
// RANDOM CVARS CHECK MIN/MAX BOUNDS (in seconds)
float minRandCheckVal       = 60.0;
float maxRandCheckVal       = 300.0;
// put demoname in sourcebans / gbans?
bool demonameInBanReason    = true;
// log to file?
bool logtofile              = true;
// fix pingmasking? required for pingreduce check
bool fixpingmasking         = true;
// bool that gets set by steamtools/steamworks forwards - used to kick clients that dont auth
int isSteamAlive            = -1;
bool kickUnauth             = true;

// current recording demoname
char demoname[128];

// server tickrate stuff
float gameEngineTime[2];
float realTPS[2];
float smoothedTPS;

// Log file
File StacLogFile;

// REGEX
Regex demonameRegex;
Regex demonameRegexFINAL;
Regex publicIPRegex;
Regex IPRegex;

float spinDiff[TFMAXPLAYERS+1][2];

public void OnPluginStart()
{
    // check if tf2, unload if not
    if (GetEngineVersion() != Engine_TF2)
    {
        SetFailState("[StAC] This plugin is only supported for TF2! Aborting!");
    }

    if (MaxClients > TFMAXPLAYERS)
    {
        SetFailState("[StAC] This plugin (and TF2 in general) does not support more than 33 players (32 + 1 for STV). Aborting!");
    }

    LoadTranslations("common.phrases");

    // updater
    if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
    // open log
    OpenStacLog();

    // reg admin commands
    // TODO: make these invisible for non admins
    RegAdminCmd("sm_stac_checkall", ForceCheckAll,    ADMFLAG_GENERIC, "Force check all client convars (ALL CLIENTS) for anticheat stuff");
    RegAdminCmd("sm_stac_detections", ShowDetections, ADMFLAG_GENERIC, "Show all current detections on all connected clients");
    RegAdminCmd("sm_stac_getauth", GetAuth,           ADMFLAG_GENERIC, "Print StAC's cached auth for a client");
    RegAdminCmd("sm_stac_livefeed", LiveFeed,         ADMFLAG_GENERIC, "Show live feed (debug info etc) for a client. This gets printed to SourceTV if available.");
    RegAdminCmd("sm_livefeed",      LiveFeed,         ADMFLAG_GENERIC, "Show live feed (debug info etc) for a client. This gets printed to SourceTV if available.");

    // get tick interval - some modded tf2 servers run at >66.7 tick!
    tickinterv = GetTickInterval();
    // reset random server seed
    ActuallySetRandomSeed();

    // setup regex - "Recording to ".*""
    demonameRegex       = CompileRegex("Recording to \".*\"");
    demonameRegexFINAL  = CompileRegex("\".*\"");
    publicIPRegex       = CompileRegex("public ip: \\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b");
    IPRegex             = CompileRegex("\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b");

    // grab round start events for calculating tps
    HookEvent("teamplay_round_start", eRoundStart);
    // grab player spawns
    HookEvent("player_spawn", ePlayerSpawned);

    HookEvent("player_disconnect", ePlayerDisconnect);

    // check EVERYONE's cvars on plugin reload
    CreateTimer(0.5, checkEveryone);

    // hook sv_cheats so we can instantly unload if cheats get turned on
    HookConVarChange(FindConVar("sv_cheats"), GenericCvarChanged);
    // hook wait for tbot
    HookConVarChange(FindConVar("sv_allow_wait_command"), GenericCvarChanged);

    // hook these for pingmasking stuff
    HookConVarChange(FindConVar("sv_mincmdrate"), RateChange);
    HookConVarChange(FindConVar("sv_maxcmdrate"), RateChange);
    HookConVarChange(FindConVar("sv_minupdaterate"), RateChange);
    HookConVarChange(FindConVar("sv_maxupdaterate"), RateChange);

    UpdateRates();

    // Create ConVars for adjusting settings
    initCvars();
    // load translations
    LoadTranslations("stac.phrases.txt");

    // reset all client based vars on plugin reload
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClientOrBot(Cl))
        {
            OnClientPutInServer(Cl);
        }
    }

    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        delete QueryTimer[Cl];
    }

    CreateTimer(0.5, timer_GetNetInfo, _, TIMER_REPEAT);

    timeSinceMapStart = GetEngineTime();
    AddTempEntHook("Fire Bullets", Hook_TEFireBullets);

    HudSyncRunCmd = CreateHudSynchronizer();
    HudSyncRunCmdMisc = CreateHudSynchronizer();
    HudSyncNetwork = CreateHudSynchronizer();

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
        "[StAC] maximum consecutive bhop detections on a client before they get \"antibhopped\". client will get banned on this value + 2, so for default cvar settings, client will get banned on 12 tick perfect bhops.\nctrl + f for \"antibhop\" in stac.sp for more detailed info.\n-1 to disable even checking bhops (saves cpu), 0 to print to admins/stv but never ban\n(recommended 10 or higher)",
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
        "[StAC] maximum fake angle / wrong / OOB angle detections before banning a client.\n-1 to disable even checking angles (saves cpu), 0 to print to admins/stv but never ban\n(recommended 10)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_fakeang_detections, stacVarChanged);

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
    HookConVarChange(stac_max_cmdnum_detections, stacVarChanged);

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
    HookConVarChange(stac_max_tbot_detections, stacVarChanged);

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
    HookConVarChange(stac_max_spinbot_detections, stacVarChanged);

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
    HookConVarChange(stac_include_demoname_in_banreason, stacVarChanged);

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
    HookConVarChange(stac_fixpingmasking_enabled, stacVarChanged);

    // pingreduce
    IntToString(maxCmdrateSpamDetects, buffer, sizeof(buffer));
    stac_max_cmdrate_spam_detections =
    AutoExecConfig_CreateConVar
    (
        "stac_max_cmdrate_spam_detections",
        buffer,
        "[StAC] maximum number of times a client can consecutively spam cmdrate changes before getting banned - this is used by cheats for \"ping reducing\".\n(recommended 50+)",
        FCVAR_NONE,
        true,
        -1.0,
        false,
        _
    );
    HookConVarChange(stac_max_cmdrate_spam_detections, stacVarChanged);


    // fixpingmasking
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
    HookConVarChange(stac_kick_unauthed_clients, stacVarChanged);

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
    maxCmdrateSpamDetects   = GetConVarInt(stac_max_cmdrate_spam_detections);

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

    // properly fix pingmasking
    kickUnauth              = GetConVarBool(stac_kick_unauthed_clients);

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

void RunOptimizeCvars()
{
    // attempt to patch doubletap
    SetConVarInt(FindConVar("sv_maxusrcmdprocessticks"), 16);
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
        // clamp jaypatch to sane values
        SetConVarInt(jay_backtrack_tolerance, Math_Clamp(GetConVarInt(jay_backtrack_tolerance), 0, 1));
    }
    // get rid of any possible exploits by using teleporters and fov
    SetConVarInt(FindConVar("tf_teleporter_fov_start"), 90);
    SetConVarFloat(FindConVar("tf_teleporter_fov_time"), 0.0);
}

public Action checkNativesEtc(Handle timer)
{
    // check sv cheats
    if (GetConVarBool(FindConVar("sv_cheats")))
    {
        SetFailState("[StAC] sv_cheats set to 1! Aborting!");
    }
    // check wait command
    if (GetConVarBool(FindConVar("sv_allow_wait_command")))
    {
        waitStatus = true;
    }
    // check natives!
    if (GetFeatureStatus(FeatureType_Native, "Steam_IsConnected") == FeatureStatus_Available)
    {
        STEAMTOOLS = true;
    }
    if (GetFeatureStatus(FeatureType_Native, "SteamWorks_IsConnected") == FeatureStatus_Available)
    {
        STEAMWORKS = true;
    }
    if (GetFeatureStatus(FeatureType_Native, "SBPP_BanPlayer") == FeatureStatus_Available)
    {
        SOURCEBANS = true;
    }
    if (CommandExists("gb_ban"))
    {
        GBANS = true;
    }
    if (CommandExists("sm_aimplot"))
    {
        AIMPLOTTER = true;
    }

    if (GetFeatureStatus(FeatureType_Native, "Discord_SendMessage") == FeatureStatus_Available)
    {
        DISCORD = true;
    }

    if (GameRules_GetProp("m_bPlayingMannVsMachine") == 1)
    {
        MVM = true;
    }
    else
    {
        MVM = false;
    }

    if (isSteamAlive == -1)
    {
        checkSteam();
    }

    if (DEBUG)
    {
        StacLog
        (
            "\nSTEAMTOOLS = %i\nSTEAMWORKS = %i\nSOURCEBANS = %i\nGBANS = %i",
            STEAMTOOLS,
            STEAMWORKS,
            SOURCEBANS,
            GBANS
        );
    }
}

public Action checkEveryone(Handle timer)
{
    QueryEverythingAllClients();
}

public Action ForceCheckAll(int callingCl, int args)
{
    QueryEverythingAllClients();
}

public Action GetAuth(int callingCl, int args)
{
    if (args != 1)
    {
        ReplyToCommand(callingCl, "Usage: sm_stac_getauth <client>");
    }
    else
    {
        char arg1[32];
        GetCmdArg(1, arg1, sizeof(arg1));

        char target_name[MAX_TARGET_LENGTH];
        int target_list[MAXPLAYERS];
        int target_count;
        bool tn_is_ml;

        if
        (
            (
                target_count = ProcessTargetString
                (
                    arg1,
                    callingCl,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_NO_BOTS,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml
                )
            )
            <= 0
        )
        {
            ReplyToTargetError(callingCl, target_count);
            return Plugin_Handled;
        }

        for (int i = 0; i < target_count; i++)
        {
            int Cl = target_list[i];
            if (IsValidClient(Cl))
            {
                ReplyToCommand(callingCl, "[StAC] Auth for \"%N\" - %s", Cl, SteamAuthFor[Cl]);
            }
        }
    }
    StacGeneralPlayerDiscordNotify(GetClientUserId(callingCl), "Client attempted to use StAC getauth");
    return Plugin_Handled;
}

public Action LiveFeed(int callingCl, int args)
{
    if (args != 1)
    {
        ReplyToCommand(callingCl, "Usage: sm_stac_livefeed <client>");
    }
    else
    {
        char arg1[32];
        GetCmdArg(1, arg1, sizeof(arg1));

        char target_name[MAX_TARGET_LENGTH];
        int target_list[MAXPLAYERS];
        int target_count;
        bool tn_is_ml;

        if
        (
            (
                target_count = ProcessTargetString
                (
                    arg1,
                    callingCl,
                    target_list,
                    MAXPLAYERS,
                    COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_NO_MULTI,
                    target_name,
                    sizeof(target_name),
                    tn_is_ml
                )
            )
            <= 0
        )
        {
            ReplyToTargetError(callingCl, target_count);
            return Plugin_Handled;
        }

        for (int i = 0; i < target_count; i++)
        {
            int Cl = target_list[i];
            if (IsValidClient(Cl))
            {
                LiveFeedOn[Cl] = !LiveFeedOn[Cl];
            }
            for (int j = 1; j <= MaxClients; j++)
            {
                if (j != Cl)
                {
                    LiveFeedOn[j] = false;
                }
            }
        }
    }
    StacGeneralPlayerDiscordNotify(GetClientUserId(callingCl), "Client attempted to use StAC Livefeed");
    return Plugin_Handled;
}

public Action ShowDetections(int callingCl, int args)
{
    if (callingCl != 0)
    {
        ReplyToCommand(callingCl, "Check your console!");
    }
    PrintToConsole(callingCl, "\n[StAC] == CURRENT DETECTIONS == ");
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            if
            (
                   turnTimes[Cl]           >= 1
                || aimsnapDetects[Cl]      >= 1
                || pSilentDetects[Cl]      >= 1
                || fakeAngDetects[Cl]      >= 1
                || cmdnumSpikeDetects[Cl]  >= 1
                || tbotDetects[Cl]         >= 1
            )
            {
                PrintToConsole(callingCl, "Detections for %L", Cl);
                if (turnTimes[Cl] >= 1)
                {
                    PrintToConsole(callingCl, "- %i turn bind frames for %N", turnTimes[Cl], Cl);
                }
                if (aimsnapDetects[Cl] >= 1)
                {
                    PrintToConsole(callingCl, "- %i aimsnap detections for %N", aimsnapDetects[Cl], Cl);
                }
                if (pSilentDetects[Cl] >= 1)
                {
                    PrintToConsole(callingCl, "- %i silent aim detections for %N", pSilentDetects[Cl], Cl);
                }
                if (fakeAngDetects[Cl] >= 1)
                {
                    PrintToConsole(callingCl, "- %i fake angle detections for %N", fakeAngDetects[Cl], Cl);
                }
                if (cmdnumSpikeDetects[Cl] >= 1)
                {
                    PrintToConsole(callingCl, "- %i cmdnum spikes for %N", cmdnumSpikeDetects[Cl], Cl);
                }
                if (tbotDetects[Cl] >= 1)
                {
                    PrintToConsole(callingCl, "- %i triggerbot detections for %N", tbotDetects[Cl], Cl);
                }
            }
        }
    }
    PrintToConsole(callingCl, "[StAC] == END DETECTIONS == \n");
    StacGeneralPlayerDiscordNotify(GetClientUserId(callingCl), "Client attempted to check StAC detections");
}

public void OnPluginEnd()
{
    StacLog("[StAC] Plugin vers. ---- %s ---- unloaded", PLUGIN_VERSION);
    NukeTimers();
    OnMapEnd();
}

// reseed random server seed to help prevent certain nospread stuff from working.
// this probably doesn't do anything, but it makes me feel better.
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
        delete QueryTimer[Cl];
    }
    delete TriggerTimedStuffTimer;
}

// recreate the timers we just nuked
void ResetTimers()
{
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            int userid = GetClientUserId(Cl);

            if (DEBUG)
            {
                StacLog("[StAC] Creating timer for %L", Cl);
            }
            // lets make a timer with a random length between stac_min_randomcheck_secs and stac_max_randomcheck_secs
            QueryTimer[Cl] =
            CreateTimer
            (
                GetRandomFloat
                (
                    minRandCheckVal,
                    maxRandCheckVal
                ),
                Timer_CheckClientConVars,
                userid
            );
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
    // this counts
    timeSinceMapStart = GetEngineTime();
}

public Action ePlayerSpawned(Handle event, char[] name, bool dontBroadcast)
{
    int Cl = GetClientOfUserId(GetEventInt(event, "userid"));
    //int userid = GetEventInt(event, "userid");
    if (IsValidClient(Cl))
    {
        //if (snapOnNextSpawn[Cl])
        //{
        //    CreateTimer(2.0, SnapClientAngles, userid);
        //}
        timeSinceSpawn[Cl] = GetEngineTime();
    }
}

Action hOnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3])
{
    // get ent classname AKA the weapon name
    if (!IsValidEntity(weapon) || weapon <= 0 || !IsValidClient(attacker))
    {
        return Plugin_Continue;
    }

    GetEntityClassname(weapon, hurtWeapon[attacker], 256);
    if
    (
        // player didn't hurt self
           victim != attacker
    )
    {
        didHurtThisFrame[attacker] = true;
    }
    return Plugin_Continue;
}

public Action Hook_TEFireBullets(const char[] te_name, const int[] players, int numClients, float delay)
{
    int Cl = TE_ReadNum("m_iPlayer") + 1;
    // this user fired a bullet this frame!
    didBangThisFrame[Cl] = true;
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
        else if (IsHalloweenCond(condition))
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
        else if (IsHalloweenCond(condition))
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

public Action timer_GetNetInfo(Handle timer)
{
    // reset all client based vars on plugin reload
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            // convert to percentages
            lossFor[Cl]      = GetClientAvgLoss(Cl, NetFlow_Both) * 100.0;
            chokeFor[Cl]     = GetClientAvgChoke(Cl, NetFlow_Both) * 100.0;
            inchokeFor[Cl]   = GetClientAvgChoke(Cl, NetFlow_Incoming) * 100.0;
            outchokeFor[Cl]  = GetClientAvgChoke(Cl, NetFlow_Outgoing) * 100.0;
            // convert to ms
            pingFor[Cl]      = GetClientLatency(Cl, NetFlow_Both) * 1000.0;
            rateFor[Cl]      = GetClientAvgData(Cl, NetFlow_Both) / 125.0;
            ppsFor[Cl]       =GetClientAvgPackets(Cl, NetFlow_Both);
            if (LiveFeedOn[Cl])
            {
                LiveFeed_NetInfo(GetClientUserId(Cl));
            }
        }
    }
}

void LiveFeed_NetInfo(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if (!IsValidClient(Cl))
    {
        return;
    }
    for (int LiveFeedViewer = 1; LiveFeedViewer <= MaxClients; LiveFeedViewer++)
    {
        if (IsValidAdmin(LiveFeedViewer) || IsValidSrcTV(LiveFeedViewer))
        {
            // NETINFO
            SetHudTextParams
            (
                // x&y
                0.85, 0.40,
                // time to hold
                4.0,
                // rgba
                255, 255, 255, 255,
                // effects
                0, 0.0, 0.0, 0.0
            );
            ShowSyncHudText
            (
                LiveFeedViewer,
                HudSyncNetwork,
                "\
                \nClient: %N\
                \n Index: %i\
                \n Userid: %i\
                \n Status: %s\
                \n Connected for: %.0fs\
                \n\
                \nNetwork:\
                \n %.2f ms ping\
                \n %.2f loss\
                \n %.2f inchoke\
                \n %.2f outchoke\
                \n %.2f totalchoke\
                \n %.2f kbps rate\
                \n %.2f pps rate\
                ",
                Cl,
                Cl,
                GetClientUserId(Cl),
                IsPlayerAlive(Cl) ? "alive" : "dead",
                GetClientTime(Cl),
                pingFor[Cl],
                lossFor[Cl],
                inchokeFor[Cl],
                outchokeFor[Cl],
                chokeFor[Cl],
                rateFor[Cl],
                ppsFor[Cl]
            );
        }
    }
}

void DoTPSMath()
{
    tickinterv = GetTickInterval();
    tps = Pow(tickinterv, -1.0);

    if (DEBUG)
    {
        StacLog("tickinterv %f, tps %f", tickinterv, tps);
    }
}

public void OnMapStart()
{
    OpenStacLog();
    ActuallySetRandomSeed();
    DoTPSMath();
    ResetTimers();
    RequestFrame(checkStatus);
    if (optimizeCvars)
    {
        RunOptimizeCvars();
    }
    timeSinceMapStart = GetEngineTime();
    CreateTimer(0.1, checkNativesEtc);
    GetConVarString(FindConVar("hostname"), hostname, sizeof(hostname));
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
    fakeAngDetects          [Cl] = 0;
    aimsnapDetects          [Cl] = -1; // ignore first detect, it's prolly bunk
    pSilentDetects          [Cl] = -1; // ignore first detect, it's prolly bunk
    bhopDetects             [Cl] = -1; // set to -1 to ignore single jumps
    cmdnumSpikeDetects      [Cl] = 0;
    tbotDetects             [Cl] = -1; // ignore first detect, it's prolly bunk
    spinbotDetects          [Cl] = 0;
    fakeChokeDetects        [Cl] = 0;
    cmdrateSpamDetects      [Cl] = 0;

    // TIME SINCE LAST ACTION PER CLIENT
    timeSinceSpawn          [Cl] = 0.0;
    timeSinceTaunt          [Cl] = 0.0;
    timeSinceTeled          [Cl] = 0.0;
    timeSinceNullCmd        [Cl] = 0.0;
    // STORED GRAVITY STATE PER CLIENT
    highGrav                [Cl] = false;
    // STORED MISC VARS PER CLIENT
    playerTaunting          [Cl] = false;
    playerInBadCond         [Cl] = 0;
    userBanQueued           [Cl] = false;
    // STORED SENS PER CLIENT
    sensFor                 [Cl] = 0.0;
    // don't bother clearing arrays
    LiveFeedOn              [Cl] = false;
}

public void OnClientPutInServer(int Cl)
{
    int userid = GetClientUserId(Cl);

    if (IsValidClientOrBot(Cl))
    {
        SDKHook(Cl, SDKHook_OnTakeDamage, hOnTakeDamage);
    }
    if (IsValidClient(Cl))
    {
        // clear per client values
        ClearClBasedVars(userid);
        // clear timer
        QueryTimer[Cl] = null;
        // query convars on player connect
        if (DEBUG)
        {
            StacLog("[StAC] %N joined. Checking cvars", Cl);
        }
        QueryTimer[Cl] = CreateTimer(0.1, Timer_CheckClientConVars, userid);

        CreateTimer(2.5, CheckAuthOn, userid);
    }
}

Action CheckAuthOn(Handle timer, int userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        // don't bother checking if already authed and DEFINITELY don't check if steam is down or there's no way to do so thru an ext
        if (!IsClientAuthorized(Cl))
        {
            if (shouldCheckAuth())
            {
                SteamAuthFor[Cl][0] = '\0';
                if (kickUnauth)
                {
                    StacGeneralPlayerDiscordNotify(userid, "Kicked for being unauthorized w/ Steam");
                    StacLog("[StAC] Kicking %N for not being authorized with Steam.", Cl);
                    KickClient(Cl, "[StAC] Not authorized with Steam Network, please authorize and reconnect");
                }
                else
                {
                    StacGeneralPlayerDiscordNotify(userid, "Client failed to authorize w/ Steam in a timely manner");
                    StacLog("[StAC] Client %N failed to authorize w/ Steam in a timely manner.", Cl);
                }
            }
        }
        else
        {
            char steamid[64];

            // let's try to get their auth anyway
            if (GetClientAuthId(Cl, AuthId_Steam2, steamid, sizeof(steamid)))
            {
                // if we get it, copy to our global list
                strcopy(SteamAuthFor[Cl], sizeof(SteamAuthFor[]), steamid);
            }
            else
            {
                SteamAuthFor[Cl][0] = '\0';
            }
        }
    }
}

// cache this! we don't need to clear this because it gets overwritten when a new client connects with the same index
public void OnClientAuthorized(int Cl, const char[] auth)
{
    if (IsValidClient(Cl))
    {
        strcopy(SteamAuthFor[Cl], sizeof(SteamAuthFor[]), auth);
        LogMessage("auth %s for Cl %N", auth, Cl);
    }
}

public void OnClientDisconnect(int Cl)
{
    int userid = GetClientUserId(Cl);
    // clear per client values
    ClearClBasedVars(userid);
    delete QueryTimer[Cl];
}

// player is OUT of the server
public void ePlayerDisconnect(Handle event, const char[] name, bool dontBroadcast)
{
    int Cl = GetClientOfUserId(GetEventInt(event, "userid"));
    SteamAuthFor[Cl][0] = '\0';

}
float stutterWaitLength = 5.0;
// monitor server tickrate
public void OnGameFrame()
{
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            if (LiveFeedOn[Cl])
            {
                LiveFeed_PlayerCmd(GetClientUserId(Cl));
            }
        }
    }

    gameEngineTime[1] = gameEngineTime[0];
    gameEngineTime[0] = GetEngineTime();

    realTPS[1] = realTPS[0];
    realTPS[0] = 1/(gameEngineTime[0] - gameEngineTime[1]);

    smoothedTPS = ((realTPS[0] + realTPS[1]) / 2);

    if (GetEngineTime() - 30.0 < timeSinceMapStart)
    {
        return;
    }

    if (isDefaultTickrate())
    {
        if (smoothedTPS < (tps / 2.0))
        {
            timeSinceLagSpike = GetEngineTime();
            StacLog("[StAC] Server framerate stuttered. Expected: %f, got %f.\nDisabling OnPlayerRunCmd checks for %.2f seconds.", tps, realTPS[0], stutterWaitLength);
            if (DEBUG)
            {
                PrintToImportant("{hotpink}[StAC]{white} Server framerate stuttered. Expected: {palegreen}%f{white}, got {fullred}%f{white}.\nDisabling OnPlayerRunCmd checks for %f seconds.", tps, smoothedTPS, stutterWaitLength);
            }
        }
    }
}

/*
    in OnPlayerRunCmd, we check for:
    - CMDNUM SPIKES
    - SILENT AIM
    - AIM SNAPS
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
    // sanity check, don't let banned clients do anything!
    if (userBanQueued[Cl])
    {
        return Plugin_Handled;
    }

    // make sure client is real & not a bot
    if (!IsValidClient(Cl))
    {
        return Plugin_Continue;
    }

    // need this basically no matter what
    int userid = GetClientUserId(Cl);

    // originally from ssac - block invalid usercmds with invalid data
    if (cmdnum <= 0 || tickcount <= 0)
    {
        if (cmdnum < 0 || tickcount < 0)
        {
            StacLog("[StAC] cmdnum %i, tickcount %i", cmdnum, tickcount);
            StacGeneralPlayerDiscordNotify(userid, "Client has invalid usercmd data!");
            return Plugin_Handled;
        }
        timeSinceNullCmd[Cl] = GetEngineTime();
        return Plugin_Continue;
    }

    // grab engine time
    for (int i = 10; i > 0; --i)
    {
        engineTime[Cl][i] = engineTime[Cl][i-1];
    }
    engineTime[Cl][0] = GetEngineTime();

    // grab angles - we ignore roll
    // thanks to nosoop from the sm discord for some help with this
    clangles[Cl][4] = clangles[Cl][3];
    clangles[Cl][3] = clangles[Cl][2];
    clangles[Cl][2] = clangles[Cl][1];
    clangles[Cl][1] = clangles[Cl][0];
    clangles[Cl][0][0] = angles[0];
    clangles[Cl][0][1] = angles[1];
    clangles[Cl][0][2] = angles[2];

    // grab cmdnum
    for (int i = 5; i > 0; --i)
    {
        clcmdnum[Cl][i] = clcmdnum[Cl][i-1];
    }
    clcmdnum[Cl][0] = cmdnum;

    // grab tickccount
    for (int i = 5; i > 0; --i)
    {
        cltickcount[Cl][i] = cltickcount[Cl][i-1];
    }
    cltickcount[Cl][0] = tickcount;

    // grab buttons
    for (int i = 5; i > 0; --i)
    {
        clbuttons[Cl][i] = clbuttons[Cl][i-1];
    }
    clbuttons[Cl][0] = buttons;

    clmouse[Cl] = mouse;

    climpulse[Cl] = impulse;

    // grab position
    clpos[Cl][1] = clpos[Cl][0];
    GetClientEyePosition(Cl, clpos[Cl][0]);

    // did we hurt someone in any of the past few frames?
    didHurtOnFrame[Cl][2] = didHurtOnFrame[Cl][1];
    didHurtOnFrame[Cl][1] = didHurtOnFrame[Cl][0];
    didHurtOnFrame[Cl][0] = didHurtThisFrame[Cl];
    didHurtThisFrame[Cl] = false;

    // did we shoot a bullet in any of the past few frames?
    didBangOnFrame[Cl][2] = didBangOnFrame[Cl][1];
    didBangOnFrame[Cl][1] = didBangOnFrame[Cl][0];
    didBangOnFrame[Cl][0] = didBangThisFrame[Cl];
    didBangThisFrame[Cl] = false;


    // detect trigger teleports
    if (GetVectorDistance(clpos[Cl][0], clpos[Cl][1], false) > 500)
    {
        // reuse this variable
        timeSinceTeled[Cl] = GetEngineTime();
    }

    // R O U N D ( fuzzy psilent detection to detect lmaobox silent+ and better detect other forms of silent aim )

    fuzzyClangles[Cl][2][0] = RoundToPlace(clangles[Cl][2][0], 1);
    fuzzyClangles[Cl][2][1] = RoundToPlace(clangles[Cl][2][1], 1);
    fuzzyClangles[Cl][1][0] = RoundToPlace(clangles[Cl][1][0], 1);
    fuzzyClangles[Cl][1][1] = RoundToPlace(clangles[Cl][1][1], 1);
    fuzzyClangles[Cl][0][0] = RoundToPlace(clangles[Cl][0][0], 1);
    fuzzyClangles[Cl][0][1] = RoundToPlace(clangles[Cl][0][1], 1);

    // avg'd over 10 ticks
    calcCmdrateFor[Cl] = 10.0 * Pow((engineTime[Cl][0] - engineTime[Cl][10]), -1.0),

    /*
    // backtrack shennanigans - you can't have the same tickcount twice
    maxTickCountFor[Cl] = Math_Min(maxTickCountFor[Cl], tickcount);
    if
    (
        tickcount < maxTickCountFor[Cl]
    )
    {
        if (isCmdnumSequential(userid) && clbuttons[Cl][0] & IN_ATTACK)
        {
            backtrackDetects[Cl]++;
            PrintToImportant("\
                {hotpink}[StAC]{white} Player %N {mediumpurple}tried to backtrack {white} another client!\
                \nDetections so far: {palegreen}%i",
                Cl,
                backtrackDetects[Cl]
            );
            StacLog("\
                [StAC] Player %N {mediumpurple}tried to backtrack another client!\
                \nDetections so far: %i\
                \nTickcount: %i\
                \nPrevious maximum tickcount: %i",
                Cl,
                backtrackDetects[Cl],
                tickcount,
                maxTickCountFor[Cl]
            );
            StacLogNetData(userid);
            StacLogCmdnums(userid);
            StacLogTickcounts(userid);

            if (backtrackDetects[Cl] % 5 == 0)
            {
                StacDetectionDiscordNotify(userid, "backtrack detection [ beta ]", backtrackDetects[Cl]);
            }
        }
        // correct it anyway
        tickcount = maxTickCountFor[Cl];
    }
    */

    // neither of these tests need fancy checks, so we do them first
    bhopCheck(userid);
    turnbindCheck(userid);

    // we have to do all these annoying checks to make sure we get as few false positives as possible.
    if
    (
        // make sure client is on a team & alive - spec cameras can cause fake angs!
           !IsClientPlaying(Cl)
        // ...isn't currently taunting - can cause fake angs!
        || playerTaunting[Cl]
        // ...didn't recently spawn - can cause invalid psilent detects
        || engineTime[Cl][0] - 1.0 < timeSinceSpawn[Cl]
        // ...didn't recently taunt - can (obviously) cause fake angs!
        || engineTime[Cl][0] - 1.0 < timeSinceTaunt[Cl]
        // ...didn't recently teleport - can cause psilent detects
        || engineTime[Cl][0] - 1.0 < timeSinceTeled[Cl]
        // don't touch this client if they've recently run a nullcmd, because they're probably lagging
        // I will tighten this up if cheats decide to try to get around stac by spamming nullcmds.
        // Do not test me.
        || engineTime[Cl][0] - 0.5 < timeSinceNullCmd[Cl]
        // don't touch if map or plugin just started - let the server framerate stabilize a bit
        || engineTime[Cl][0] - 2.5 < timeSinceMapStart
        // lets wait a bit if we had a lag spike in the last 5 seconds
        || engineTime[Cl][0] - stutterWaitLength < timeSinceLagSpike
        // make sure client isn't timing out - duh
        || IsClientTimingOut(Cl)
        // this is just for halloween shit - plenty of halloween effects can and will mess up all of these checks
        || playerInBadCond[Cl] != 0
        // exp lag check - if the client is taking less than a tickinterval to send TEN ticks of information, that's bad news bears
        || engineTime[Cl][0] - engineTime[Cl][10] < (tickinterv)
    )
    {
        return Plugin_Continue;
    }

    fakeangCheck(userid);

    // make sure client doesn't have 1.5% or more packet loss, can mess with cmdnumspikes
    if (lossFor[Cl] >= 1.5)
    {
        return Plugin_Continue;
    }

    cmdnumspikeCheck(userid);

    // check if we're lagging in other ways
    // cmdnums need to be sequential and not repeated
    // tickcount needs to be sequential and to not go downward - repeating is ok
    if
    (
        !isCmdnumSequential(userid)
        ||
        !isTickcountInOrder(userid)
    )
    {
        return Plugin_Continue;
    }

    if
    (
        // make sure client doesn't have invalid angles. "invalid" in this case means "any angle is 0.000000", usually caused by plugin / trigger based teleportation
        !HasValidAngles(Cl)
        // make sure client isnt using a spin bind
        || buttons & IN_LEFT
        || buttons & IN_RIGHT
    )
    // if any of these things are true, don't check angles or cmdnum spikes or spinbot stuff
    {
        return Plugin_Continue;
    }

    //if (isClientAFK(Cl))
    //{
    //    LogMessage("AFK");
    //}
    //else
    //{
    //    LogMessage("NOTAFK");
    //}

    fakechokeCheck(userid);
    spinbotCheck(userid);
    psilentCheck(userid);
    aimsnapCheck(userid);
    triggerbotCheck(userid);

    //snapanglesCheck(userid);
    return Plugin_Continue;
}


/*
    BHOP DETECTION - using lilac and ssac as reference, this one's better tho
*/
void bhopCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    // don't run this check if cvar is -1
    if (maxBhopDetections != -1)
    {
        // get movement flags
        int flags = GetEntityFlags(Cl);

        bool noban;
        if (maxBhopDetections == 0)
        {
            noban = true;
        }

        // reset their gravity if it's high!
        if (highGrav[Cl])
        {
            SetEntityGravity(Cl, 1.0);
            highGrav[Cl] = false;
        }

        if
        (
            // last input didn't have a jump - include to prevent legits holding spacebar from triggering detections
            !(
                clbuttons[Cl][1] & IN_JUMP
            )
            &&
            // player pressed jump
            (
                clbuttons[Cl][0] & IN_JUMP
            )
            // they were on the ground when they pressed space
            &&
            (
                flags & FL_ONGROUND
            )
        )
        {
            // increment bhops
            bhopDetects[Cl]++;

            // print to admins if halfway to getting banned - or halfway to default bhop amt ( 10 )
            if
            (
                (
                    bhopDetects[Cl] >= RoundToFloor(maxBhopDetections / 2.0)
                    &&
                    !noban
                )
                ||
                (
                    bhopDetects[Cl] >= 5
                    &&
                    noban
                )
            )
            {
                PrintToImportant("{hotpink}[StAC]{white} Player %N {mediumpurple}bhopped{white}!\nConsecutive detections so far: {palegreen}%i" , Cl, bhopDetects[Cl]);
                StacLog("\n[StAC] Player %N bhopped! Consecutive detections so far: %i" , Cl, bhopDetects[Cl]);

                if (bhopDetects[Cl] >= maxBhopDetections)
                {
                    // punish on maxBhopDetections + 2 (for the extra TWO tick perfect bhops at 8x grav with no warning - no human can do this!)
                    if
                    (
                        (bhopDetects[Cl] >= (maxBhopDetections + 2))
                        &&
                        !noban
                    )
                    {
                        SetEntityGravity(Cl, 1.0);
                        highGrav[Cl] = false;
                        char reason[128];
                        Format(reason, sizeof(reason), "%t", "bhopBanMsg", bhopDetects[Cl]);
                        char pubreason[256];
                        Format(pubreason, sizeof(pubreason), "%t", "bhopBanAllChat", Cl, bhopDetects[Cl]);
                        BanUser(userid, reason, pubreason);
                        return;
                    }

                    // don't run antibhop if cvar is 0
                    if (maxBhopDetections > 0)
                    {
                        /* ANTIBHOP */
                        // set the player's gravity to 8x.
                        // if idiot cheaters keep holding their spacebar for an extra second and do 2 tick perfect bhops WHILE at 8x gravity...
                        // ...we will catch them autohopping and ban them!
                        SetEntityGravity(Cl, 8.0);
                        highGrav[Cl] = true;
                    }
                }
            }
        }
        else if
        (
            // player didn't press jump
            !(
                clbuttons[Cl][0] & IN_JUMP
            )
            // player is on the ground
            &&
            (
                flags & FL_ONGROUND
            )
        )
        {
            // set to -1 to ignore single jumps, we ONLY want to count bhops
            bhopDetects[Cl] = -1;
        }
    }
}


/*
    TURN BIND TEST
*/
void turnbindCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if
    (
        maxAllowedTurnSecs != -1.0
        &&
        (
            clbuttons[Cl][0] & IN_LEFT
            ||
            clbuttons[Cl][0] & IN_RIGHT
        )
    )
    {
        turnTimes[Cl]++;
        float turnSec = turnTimes[Cl] * tickinterv;
        PrintToImportant("%t", "turnbindAdminMsg", Cl, turnSec);

        if (turnSec < maxAllowedTurnSecs)
        {
            MC_PrintToChat(Cl, "%t", "turnbindWarnPlayer");
        }
        else if (turnSec >= maxAllowedTurnSecs)
        {
            StacGeneralPlayerDiscordNotify(userid, "Client was kicked for turn binds");
            KickClient(Cl, "%t", "turnbindKickMsg");
            MC_PrintToChatAll("%t", "turnbindAllChat", Cl);
            StacLog("%t", "turnbindAllChat", Cl);
        }
    }
}

/*
    FAKECHOKE TEST
*/
void fakechokeCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if (!isDefaultTickrate())
    {
        return;
    }
    // detect fakechoke ( BETA )
    if (engineTime[Cl][0] - engineTime[Cl][1] > tickinterv * 8)
    {
        // off by one from what ncc says
        int amt = clcmdnum[Cl][0] - lastChokeCmdnum[Cl];
        if (amt >= 8)
        {
            if (amt == lastChokeAmt[Cl])
            {
                fakeChokeDetects[Cl]++;
                if (fakeChokeDetects[Cl] >= 5)
                {
                    PrintToImportant("{hotpink}[StAC]{white} Player %N is repeatedly choking {mediumpurple}%i{white} ticks.\nThey may be fake-choking. Bother steph!\nDetections so far: {palegreen}%i" , Cl, amt, fakeChokeDetects[Cl]);
                    StacLog("Player %L is repeatedly choking exactly %i ticks - %i detections", Cl, amt, fakeChokeDetects[Cl]);
                    StacLogNetData(userid);
                    StacLogCmdnums(userid);
                    StacLogTickcounts(userid);
                    if (fakeChokeDetects[Cl] % 20 == 0)
                    {
                        StacDetectionDiscordNotify(userid, "fake choke [ BETA ]", fakeChokeDetects[Cl]);
                    }
                }
            }
            else
            {
                fakeChokeDetects[Cl] = 0;
            }
        }
        lastChokeAmt[Cl]    = amt;
        lastChokeCmdnum[Cl] = clcmdnum[Cl][0];
    }
}

/*
    EYE ANGLES TEST
    if clients are outside of allowed angles in tf2, which are
      +/- 89.0 x (up / down)
      +/- 180 y (left / right, but we don't check this atm because there's things that naturally fuck up y angles, such as taunts)
      +/- 50 z (roll / tilt)
    while they are not in spec & on a map camera, we should log it.
    we would fix them but cheaters can just ignore server-enforced viewangle changes so there's no point

    these bounds were lifted from lilac. Thanks lilac.
    lilac patches roll, we do not, i think it (screen shake) is an important part of tf2,
    jtanz says that lmaobox can abuse roll so it should just be removed. i think both opinions are fine
*/
void fakeangCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if
    (
        // don't bother checking if fakeang detection is off
        maxFakeAngDetections != -1
        &&
        (
            FloatAbs(clangles[Cl][0][0]) > 89.00
            ||
            FloatAbs(clangles[Cl][0][2]) > 50.00
        )
    )
    {
        fakeAngDetects[Cl]++;
        PrintToImportant
        (
            "{hotpink}[StAC]{white} Player %N has {mediumpurple}invalid eye angles{white}!\nCurrent angles: {mediumpurple}%.2f %.2f %.2f{white}.\nDetections so far: {palegreen}%i",
            Cl,
            clangles[Cl][0][0],
            clangles[Cl][0][1],
            clangles[Cl][0][2],
            fakeAngDetects[Cl]
        );
        StacLog
        (
            "\n==========\n[StAC] Player %N has invalid eye angles!\nCurrent angles: %f %f %f.\nDetections so far: %i\n==========",
            Cl,
            clangles[Cl][0][0],
            clangles[Cl][0][1],
            clangles[Cl][0][2],
            fakeAngDetects[Cl]
        );
        if (fakeAngDetects[Cl] % 20 == 0)
        {
            StacDetectionDiscordNotify(userid, "fake angles", fakeAngDetects[Cl]);
        }
        if (fakeAngDetects[Cl] >= maxFakeAngDetections && maxFakeAngDetections > 0)
        {
            char reason[128];
            Format(reason, sizeof(reason), "%t", "fakeangBanMsg", fakeAngDetects[Cl]);
            char pubreason[256];
            Format(pubreason, sizeof(pubreason), "%t", "fakeangBanAllChat", Cl, fakeAngDetects[Cl]);
            BanUser(userid, reason, pubreason);
        }
    }
}

/*
    CMDNUM SPIKE TEST - heavily modified from SSAC
    this is for detecting when cheats "skip ahead" their cmdnum so they can fire a "perfect shot" aka a shot with no spread
    funnily enough, it actually DOESN'T change where their bullet goes, it's just a client side visual effect with decals
*/
void cmdnumspikeCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if (maxCmdnumDetections != -1)
    {
        int spikeamt = clcmdnum[Cl][0] - clcmdnum[Cl][1];
        if (spikeamt >= 64 || spikeamt < 0)
        {
            char heldWeapon[256];
            GetClientWeapon(Cl, heldWeapon, sizeof(heldWeapon));

            cmdnumSpikeDetects[Cl]++;
            PrintToImportant
            (
                "{hotpink}[StAC]{white} Cmdnum SPIKE of {yellow}%i{white} on %N.\nDetections so far: {palegreen}%i{white}.",
                spikeamt,
                Cl,
                cmdnumSpikeDetects[Cl]
            );
            StacLog
            (
                "\n[StAC] Cmdnum SPIKE of %i on %L.\nDetections so far: %i. Held weapon: %s",
                spikeamt,
                Cl,
                cmdnumSpikeDetects[Cl],
                heldWeapon
            );
            StacLogNetData(userid);
            StacLogCmdnums(userid);
            StacLogTickcounts(userid);

            if (cmdnumSpikeDetects[Cl] % 25 == 0)
            {
                StacDetectionDiscordNotify(userid, "cmdnum spike", cmdnumSpikeDetects[Cl]);
            }

            // punish if we reach limit set by cvar
            if (cmdnumSpikeDetects[Cl] >= maxCmdnumDetections && maxCmdnumDetections > 0)
            {
                char reason[128];
                Format(reason, sizeof(reason), "%t", "cmdnumSpikesBanMsg", cmdnumSpikeDetects[Cl]);
                char pubreason[256];
                Format(pubreason, sizeof(pubreason), "%t", "cmdnumSpikesBanAllChat", Cl, cmdnumSpikeDetects[Cl]);
                BanUser(userid, reason, pubreason);
            }
        }
    }
}

/*
    SPINBOT DETECTION - again heavily modified from SSAC
*/
void spinbotCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    // ignore clients using turn binds!
    if
    (
        maxSpinbotDetections != -1
    )
    {
        // get the abs value of the difference between the last two y angles
        float angBuff = FloatAbs(NormalizeAngleDiff(clangles[Cl][0][1] - clangles[Cl][1][1]));
        // set up our array
        spinDiff[Cl][1] = spinDiff[Cl][0];
        spinDiff[Cl][0] = angBuff;

        // only count this as a detect if the spin amt ( spinDiff[Cl][0] )
        // is greater than 10 degrees and ALSO matches the last value ( spinDiff[Cl][1] )
        // AND it isn't a moronicly high amt of mouse movement / sensitivity
        if
        (
            clmouse[Cl][0] < 5000
            &&
            clmouse[Cl][1] < 5000
            &&
            (
                FloatAbs(spinDiff[Cl][0]) >= 10.0
                &&
                (spinDiff[Cl][0] == spinDiff[Cl][1])
            )
        )
        {
            spinbotDetects[Cl]++;

            // this can trigger on normal players, only care about if it happens 10 times in a row at least!
            if (spinbotDetects[Cl] >= 10)
            {
                PrintToImportant
                (
                    "{hotpink}[StAC]{white} Spinbot detection of {yellow}%.2f{white}° on %N.\nDetections so far: {palegreen}%i{white}.",
                    spinDiff[Cl][0],
                    Cl,
                    spinbotDetects[Cl]
                );
                StacLog
                (
                    "[StAC] Spinbot detection of %f° on %N.\nDetections so far: %i.",
                    spinDiff[Cl][0],
                    Cl,
                    spinbotDetects[Cl]
                );
                StacLogNetData(userid);
                StacLogAngles(userid);
                StacLogCmdnums(userid);
                StacLogTickcounts(userid);
                StacLogMouse(userid);
                if (spinbotDetects[Cl] % 20 == 0)
                {
                    StacDetectionDiscordNotify(userid, "spinbot", spinbotDetects[Cl]);
                }
                if (spinbotDetects[Cl] >= maxSpinbotDetections && maxSpinbotDetections > 0)
                {
                    char reason[128];
                    Format(reason, sizeof(reason), "%t", "spinbotBanMsg", spinbotDetects[Cl]);
                    char pubreason[256];
                    Format(pubreason, sizeof(pubreason), "%t", "spinbotBanAllChat", Cl, spinbotDetects[Cl]);
                    BanUser(userid, reason, pubreason);
                }
            }
        }
        // reset if we don't get consecutive detects
        else
        {
            if (spinbotDetects[Cl] > 0)
            {
                spinbotDetects[Cl]--;
            }
        }
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

    we have to do EXTRA checks because a lot of things can fuck up silent aim detection
    make sure ticks are sequential, hopefully avoid laggy players
    example real detection:

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

void psilentCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    // get difference between angles - used for psilent
    float aDiffReal = NormalizeAngleDiff(CalcAngDeg(clangles[Cl][0], clangles[Cl][1]));

    // is this a fuzzy detect or not
    int fuzzy = -1;
    // don't run this check if silent aim cvar is -1
    if
    (
        maxPsilentDetections != -1
        &&
        (
            clbuttons[Cl][0] & IN_ATTACK
            ||
            clbuttons[Cl][1] & IN_ATTACK
        )
    )
    {
        if
        (
            // so the current and 2nd previous angles match...
            (
                   clangles[Cl][0][0] == clangles[Cl][2][0]
                && clangles[Cl][0][1] == clangles[Cl][2][1]
            )
            &&
            // BUT the 1st previous (in between) angle doesnt?
            (
                   clangles[Cl][1][0] != clangles[Cl][0][0]
                && clangles[Cl][1][1] != clangles[Cl][0][1]
                && clangles[Cl][1][0] != clangles[Cl][2][0]
                && clangles[Cl][1][1] != clangles[Cl][2][1]
            )
        )
        {
            fuzzy = 0;
        }
        else if
        (
            // etc
            (
                   fuzzyClangles[Cl][0][0] == fuzzyClangles[Cl][2][0]
                && fuzzyClangles[Cl][0][1] == fuzzyClangles[Cl][2][1]
            )
            &&
            // etc
            (
                   fuzzyClangles[Cl][1][0] != fuzzyClangles[Cl][0][0]
                && fuzzyClangles[Cl][1][1] != fuzzyClangles[Cl][0][1]
                && fuzzyClangles[Cl][1][0] != fuzzyClangles[Cl][2][0]
                && fuzzyClangles[Cl][1][1] != fuzzyClangles[Cl][2][1]
            )
        )
        {
            fuzzy = 1;
        }
        //  ok - lets make sure there's a difference of at least 1 degree on either axis to avoid most fake detections
        //  these are probably caused by packets arriving out of order but i'm not a fucking network engineer (yet) so idk
        //  examples of fake detections we want to avoid:
        //      03/25/2020 - 18:18:11: [stac.smx] [StAC] pSilent detection on [redacted]: curang angles: x 14.871331 y 154.979812
        //      03/25/2020 - 18:18:11: [stac.smx] [StAC] pSilent detection on [redacted]: prev1  angles: x 14.901910 y 155.010391
        //      03/25/2020 - 18:18:11: [stac.smx] [StAC] pSilent detection on [redacted]: prev2  angles: x 14.871331 y 154.979812
        //  and
        //      03/25/2020 - 22:16:36: [stac.smx] [StAC] pSilent detection on [redacted2]: curang angles: x 21.516006 y -140.723709
        //      03/25/2020 - 22:16:36: [stac.smx] [StAC] pSilent detection on [redacted2]: prev1  angles: x 21.560007 y -140.943710
        //      03/25/2020 - 22:16:36: [stac.smx] [StAC] pSilent detection on [redacted2]: prev2  angles: x 21.516006 y -140.723709
        //  doing this might make it harder to detect legitcheaters but like. legitcheating in a 12 yr old dead game OMEGALUL who fucking cares
        if
        (
            aDiffReal >= 1.0 && fuzzy >= 0
        )
        {
            pSilentDetects[Cl]++;
            // have this detection expire in 30 minutes
            CreateTimer(1800.0, Timer_decr_pSilent, userid, TIMER_FLAG_NO_MAPCHANGE);
            // first detection is LIKELY bullshit
            if (pSilentDetects[Cl] > 0)
            {
                // only print a bit in chat, rest goes to console (stv and admin and also the stac log)
                PrintToImportant
                (
                    "{hotpink}[StAC]{white} SilentAim detection of {yellow}%.2f{white}° on %N.\nDetections so far: {palegreen}%i{white}. fuzzy = {blue}%i",
                    aDiffReal,
                    Cl,
                    pSilentDetects[Cl],
                    fuzzy
                );
                StacLog
                (
                    "\n[StAC] SilentAim detection of %f° on \n%L.\nDetections so far: %i.\nfuzzy = %i",
                    aDiffReal,
                    Cl,
                    pSilentDetects[Cl],
                    fuzzy
                );
                StacLogNetData(userid);
                StacLogAngles(userid);
                StacLogCmdnums(userid);
                StacLogTickcounts(userid);
                StacLogMouse(userid);
                if (AIMPLOTTER)
                {
                    ServerCommand("sm_aimplot #%i on", userid);
                }
                if (pSilentDetects[Cl] % 5 == 0)
                {
                    StacDetectionDiscordNotify(userid, "psilent", pSilentDetects[Cl]);
                }
                // BAN USER if they trigger too many detections
                if (pSilentDetects[Cl] >= maxPsilentDetections && maxPsilentDetections > 0)
                {
                    char reason[128];
                    Format(reason, sizeof(reason), "%t", "pSilentBanMsg", pSilentDetects[Cl]);
                    char pubreason[256];
                    Format(pubreason, sizeof(pubreason), "%t", "pSilentBanAllChat", Cl, pSilentDetects[Cl]);
                    BanUser(userid, reason, pubreason);
                }
            }
        }
    }
}
/*
    AIMSNAP DETECTION - BETA

    Alright, here's how this works.

    If we try to just detect one frame snaps and nothing else, users can just crank up their sens,
    and wave their mouse around and get detects. so what we do is this:

    if a user has a snap of more than 10 degrees, and that snap is surrounded on one or both sides by "noise delta" of LESS than 5 degrees
    ...that counts as an aimsnap. this will catch cheaters, unless they wave their mouse around wildly, making the game miserable to play
    AND obvious that they're avoiding the anticheat.

*/
void aimsnapCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    // for some reason this just does not behave well in mvm
    if (maxAimsnapDetections != -1 && !MVM)
    {
        float aDiff[4];
        aDiff[0] = NormalizeAngleDiff(CalcAngDeg(clangles[Cl][0], clangles[Cl][1]));
        aDiff[1] = NormalizeAngleDiff(CalcAngDeg(clangles[Cl][1], clangles[Cl][2]));
        aDiff[2] = NormalizeAngleDiff(CalcAngDeg(clangles[Cl][2], clangles[Cl][3]));
        aDiff[3] = NormalizeAngleDiff(CalcAngDeg(clangles[Cl][3], clangles[Cl][4]));

        // example values of a snap:
        // 0.000000, 91.355995, 0.000000, 0.000000
        // 0.018540, 0.000000, 91.355995, 0.000000

        // only check if we actually did hitscan dmg in the current frame
        if
        (
            didHurtOnFrame[Cl][1]
            &&
            didBangOnFrame[Cl][1]
        )
        {
            float snapsize = 15.0;
            float noisesize = 1.0;

            int aDiffToUse = -1;

            //if
            //(
            //       aDiff[0] > snapsize
            //    && aDiff[1] < noisesize
            //    && aDiff[2] < noisesize
            //    && aDiff[3] < noisesize
            //)
            //{
            //    aDiffToUse = 0;
            //}
            if
            (
                   aDiff[0] < noisesize
                && aDiff[1] > snapsize
                && aDiff[2] < noisesize
                && aDiff[3] < noisesize
            )
            {
                aDiffToUse = 1;
            }
            if
            (
                   aDiff[0] < noisesize
                && aDiff[1] < noisesize
                && aDiff[2] > snapsize
                && aDiff[3] < noisesize
            )
            {
                aDiffToUse = 2;
            }
            //else if
            //(
            //       aDiff[0] < noisesize
            //    && aDiff[1] < noisesize
            //    && aDiff[2] < noisesize
            //    && aDiff[3] > snapsize
            //)
            //{
            //    aDiffToUse = 3;
            //}
            // we got one!
            if (aDiffToUse > -1)
            {
                float aDiffReal = aDiff[aDiffToUse];

                // increment aimsnap detects
                aimsnapDetects[Cl]++;
                // have this detection expire in 30 minutes
                CreateTimer(1800.0, Timer_decr_aimsnaps, userid, TIMER_FLAG_NO_MAPCHANGE);
                // first detection is, likely bullshit
                // because i don't fucking know
                if (aimsnapDetects[Cl] > 0)
                {
                    PrintToImportant
                    (
                        "{hotpink}[StAC]{white} Aimsnap detection of {yellow}%.2f{white}° on %N.\nDetections so far: {palegreen}%i{white}.",
                        aDiffReal,
                        Cl,
                        aimsnapDetects[Cl]
                    );
                    // etc
                    StacLog
                    (
                        "\n==========\n[StAC] Aimsnap detection of %f° on \n%L.\nDetections so far: %i.",
                        aDiffReal,
                        Cl,
                        aimsnapDetects[Cl]
                    );
                    StacLogNetData(userid);
                    StacLogAngles(userid);
                    StacLogCmdnums(userid);
                    StacLogTickcounts(userid);
                    StacLogMouse(userid);
                    StacLog
                    (
                        "\nAngle deltas:\n0 %f\n1 %f\n2 %f\n3 %f\n",
                        aDiff[0],
                        aDiff[1],
                        aDiff[2],
                        aDiff[3]
                    );

                    if (AIMPLOTTER)
                    {
                        ServerCommand("sm_aimplot #%i on", userid);
                    }

                    if (aimsnapDetects[Cl] % 5 == 0)
                    {
                        StacDetectionDiscordNotify(userid, "aimsnap", aimsnapDetects[Cl]);
                    }

                    // BAN USER if they trigger too many detections
                    if (aimsnapDetects[Cl] >= maxAimsnapDetections && maxAimsnapDetections > 0)
                    {
                        char reason[128];
                        Format(reason, sizeof(reason), "%t", "AimsnapBanMsg", aimsnapDetects[Cl]);
                        char pubreason[256];
                        Format(pubreason, sizeof(pubreason), "%t", "AimsnapBanAllChat", Cl, aimsnapDetects[Cl]);
                        BanUser(userid, reason, pubreason);
                    }
                }
            }
        }
    }
}

/*
    TRIGGERBOT DETECTION - BETA
*/
void triggerbotCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    // don't run if cvar is -1 or if wait is enabled on this server
    if (maxTbotDetections != -1 && !waitStatus)
    {
        int attack = 0;
        // grab single tick +attack inputs - this checks for the following pattern:
        // frame before last    //
        // last frame           // IN_ATTACK
        // current frame        //

        if
        (
            !(
                clbuttons[Cl][2] & IN_ATTACK
            )
            &&
            (
                clbuttons[Cl][1] & IN_ATTACK
            )
            &&
            !(
                clbuttons[Cl][0] & IN_ATTACK
            )
        )
        {
            attack = 1;
        }
        // grab single tick +attack2 inputs - pyro airblast, demo det, etc
        // this checks for the following pattern:
        //                      //-----------
        // frame before last    //
        // last frame           // IN_ATTACK2
        // current frame        //

        else if
        (
            !(
                clbuttons[Cl][2] & IN_ATTACK2
            )
            &&
            (
                clbuttons[Cl][1] & IN_ATTACK2
            )
            &&
            !(
                clbuttons[Cl][0] & IN_ATTACK2
            )
        )
        {
            attack = 2;
        }
        if
        (
            (
                attack == 1
                &&
                (
                    (
                        didBangOnFrame[Cl][0]
                        &&
                        didHurtOnFrame[Cl][0]
                    )
                    ||
                    (
                        didBangOnFrame[Cl][1]
                        &&
                        didHurtOnFrame[Cl][1]
                    )
                    ||
                    (
                        didBangOnFrame[Cl][2]
                        &&
                        didHurtOnFrame[Cl][2]
                    )
                )
                ||
                // count all attack2 single inputs
                (
                    attack == 2
                    &&
                    (
                        didHurtOnFrame[Cl][0]
                        ||
                        didHurtOnFrame[Cl][1]
                        ||
                        didHurtOnFrame[Cl][2]
                    )
                )
            )
        )
        {
            tbotDetects[Cl]++;
            // have this detection expire in 30 minutes
            CreateTimer(1800.0, Timer_decr_tbot, userid, TIMER_FLAG_NO_MAPCHANGE);

            if (tbotDetects[Cl] > 0)
            {
                PrintToImportant
                (
                    "{hotpink}[StAC]{white} Triggerbot detection on %N.\nDetections so far: {palegreen}%i{white}. Type: +attack{blue}%i",
                    Cl,
                    tbotDetects[Cl],
                    attack
                );
                StacLog
                (
                    "[StAC] Triggerbot detection on %N.\nDetections so far: %i{white}. Type: +attack%i\n",
                    Cl,
                    tbotDetects[Cl],
                    attack
                );
                StacLogNetData(userid);
                StacLogAngles(userid);
                StacLogCmdnums(userid);
                StacLogTickcounts(userid);
                StacLogMouse(userid);
                StacLog
                (
                    "Weapon used: %s",
                    hurtWeapon[Cl]
                );

                if (AIMPLOTTER)
                {
                    ServerCommand("sm_aimplot #%i on", userid);
                }
                if (tbotDetects[Cl] % 5 == 0)
                {
                    StacDetectionDiscordNotify(userid, "triggerbot", tbotDetects[Cl]);
                }
                // BAN USER if they trigger too many detections
                if (tbotDetects[Cl] >= maxTbotDetections && maxTbotDetections > 0)
                {
                    char reason[128];
                    Format(reason, sizeof(reason), "%t", "tbotBanMsg", tbotDetects[Cl]);
                    char pubreason[256];
                    Format(pubreason, sizeof(pubreason), "%t", "tbotBanAllChat", Cl, tbotDetects[Cl]);
                    BanUser(userid, reason, pubreason);
                }
            }
        }
    }
}

void LiveFeed_PlayerCmd(int userid)
{
    int Cl = GetClientOfUserId(userid);

    static char RareButtonNames[][] =
    {
        "",
        "",
        "",
        "",
        "",
        "",
        "CANCEL",
        "LEFT",
        "RIGHT",
        "",
        "",
        "",
        "RUN",
        "",
        "ALT1",
        "ALT2",
        "SCORE",
        "SPEED",
        "WALK",
        "ZOOM",
        "WEAPON1",
        "WEAPON2",
        "BULLRUSH",
        "GRENADE1",
        "GRENADE2",
        ""
    };


    int buttons = clbuttons[Cl][0];

    char fwd    [4] = "_";
    if (buttons & IN_FORWARD)
    {
        fwd = "^";
    }

    char back   [4] = "_";
    if (buttons & IN_BACK)
    {
        back = "v";
    }

    char left   [4] = "_";
    if (buttons & IN_MOVELEFT)
    {
        left = "<";
    }

    char right  [4] = "_";
    if (buttons & IN_MOVERIGHT)
    {
        right = ">";
    }

    char m1     [4] = "_";
    if (buttons & IN_ATTACK)
    {
        m1 = "1";
    }

    char m2     [4] = "_";
    if (buttons & IN_ATTACK2)
    {
        m2 = "2";
    }

    char m3     [4] = "_";
    if (buttons & IN_ATTACK3)
    {
        m3 = "3";
    }

    char jump   [6] = "____";
    if (buttons & IN_JUMP)
    {
        jump = "JUMP";
    }

    char duck   [6] = "____";
    if (buttons & IN_DUCK)
    {
        duck = "DUCK";
    }

    char reload [4] = "_";
    if (buttons & IN_RELOAD)
    {
        reload = "R";
    }
    char use [4] = "_";
    if (buttons & IN_USE)
    {
        use = "U";
    }

    char strButtons[512];
    for (int i = 0; i < sizeof(RareButtonNames); i++)
    {
        if (buttons & (1 << i))
        {
            Format(strButtons, sizeof(strButtons), "%s %s", strButtons, RareButtonNames[i]);
        }
    }
    TrimString(strButtons);

    for (int LiveFeedViewer = 1; LiveFeedViewer <= MaxClients; LiveFeedViewer++)
    {
        if (IsValidAdmin(LiveFeedViewer) || IsValidSrcTV(LiveFeedViewer))
        {
            // ONPLAYERRUNCMD
            SetHudTextParams
            (
                // x&y
                0.0, 0.0,
                // time to hold
                0.15,
                // rgba
                255, 255, 255, 255,
                // effects
                0, 0.0, 0.0, 0.0
            );
            ShowSyncHudText
            (
                LiveFeedViewer,
                HudSyncRunCmd,
                "\
                \nOnPlayerRunCmd Info:\
                \n %i cmdnum\
                \n %i tickcount\
                \n common buttons:\
                \n  %c %c %c\
                \n  %c %c %c    %c %c %c\
                \n  %s    %s\
                \n other buttons:\
                \n  %s\
                \n buttons int\
                \n  %i\
                \n mouse\
                \n x %i\
                \n y %i\
                \n angles\
                \n x %.2f \
                \n y %.2f \
                \n z %.2f \
                ",
                clcmdnum[Cl],
                cltickcount[Cl],
                use,  fwd, reload,
                left, back, right,    m1, m2, m3,
                jump, duck,
                IsActuallyNullString(strButtons) ? "N/A" : strButtons,
                buttons,
                clmouse[Cl][0], clmouse[Cl][1],
                clangles[Cl][0][0], clangles[Cl][0][1], clangles[Cl][0][2]
            );

            // OTHER STUFF
            SetHudTextParams
            (
                // x&y
                0.0, 0.75,
                // time to hold
                0.15,
                // rgba
                255, 255, 255, 255,
                // effects
                0, 0.0, 0.0, 0.0
            );
            ShowSyncHudText
            (
                LiveFeedViewer,
                HudSyncRunCmdMisc,
                "\
                \nMisc Info:\
                \n Approx client cmdrate: ≈%.2f cmd/sec\
                \n Approx server tickrate: ≈%.2f tick/sec\
                \n 10 tick time : %.4f\
                \n Failing lag check? %s\
                \n HasValidAngles? %s\
                \n SequentialCmdnum? %s\
                \n OrderedTickcount? %s\
                ",
                calcCmdrateFor[Cl],
                smoothedTPS,
                engineTime[Cl][0] - engineTime[Cl][10],
                engineTime[Cl][0] - engineTime[Cl][10] < (tickinterv) ? "yes" : "no",
                HasValidAngles(Cl) ? "yes" : "no",
                isCmdnumSequential(userid) ? "yes" : "no",
                isTickcountInOrder(userid) ? "yes" : "no"
            );
        }
    }
}

void StacLogNetData(int userid)
{
    int Cl          = GetClientOfUserId(userid);
    // convert to percentages
    float loss      = GetClientAvgLoss(Cl, NetFlow_Both) * 100.0;
    float choke     = GetClientAvgChoke(Cl, NetFlow_Both) * 100.0;
    float inchoke   = GetClientAvgChoke(Cl, NetFlow_Incoming) * 100.0;
    float outchoke  = GetClientAvgChoke(Cl, NetFlow_Outgoing) * 100.0;
    // convert to ms
    float ping      = GetClientAvgLatency(Cl, NetFlow_Both) * 1000.0;

    StacLog
    (
        "\
        \nNetwork:\
        \n %.2f loss\
        \n %.2f ms ping\
        \n %.2f inchoke\
        \n %.2f outchoke\
        \n %.2f totalchoke\
        ",
        loss,
        ping,
        inchoke,
        outchoke,
        choke
    );
    StacLog("Time since last 10 ticks: %f", engineTime[Cl][0] - engineTime[Cl][10]);
}

void StacLogMouse(int userid)
{
    int Cl = GetClientOfUserId(userid);
    //if (GetRandomInt(1, 5) == 1)
    //{
    //    QueryClientConVar(Cl, "sensitivity", ConVarCheck);
    //}
    // init vars for mouse movement - weightedx and weightedy
    int wx;
    int wy;
    // scale mouse movement to sensitivity
    if (sensFor[Cl] != 0.0)
    {
        wx = abs(RoundFloat(clmouse[Cl][0] * ( 1 / sensFor[Cl])));
        wy = abs(RoundFloat(clmouse[Cl][1] * ( 1 / sensFor[Cl])));
    }
    StacLog
    (
        "\
        \nMouse Movement (sens weighted):\
        \n abs(x): %i\
        \n abs(y): %i\
        \nMouse Movement (unweighted):\
        \n x: %i\
        \n y: %i\
        \nClient Sens:\
        \n %f\
        ",
        wx,
        wy,
        clmouse[Cl][0],
        clmouse[Cl][1],
        sensFor[Cl]
    );
}

void StacLogAngles(int userid)
{
    int Cl = GetClientOfUserId(userid);
    StacLog
    (
        "\
        \nAngles:\
        \n angles0: x %f y %f\
        \n angles1: x %f y %f\
        \n angles2: x %f y %f\
        \n angles3: x %f y %f\
        \n angles4: x %f y %f\
        ",
        clangles[Cl][0][0],
        clangles[Cl][0][1],
        clangles[Cl][1][0],
        clangles[Cl][1][1],
        clangles[Cl][2][0],
        clangles[Cl][2][1],
        clangles[Cl][3][0],
        clangles[Cl][3][1],
        clangles[Cl][4][0],
        clangles[Cl][4][1]
    );
}

void StacLogCmdnums(int userid)
{
    int Cl = GetClientOfUserId(userid);
    StacLog
    (
        "\
        \nPrevious cmdnums:\
        \n0 %i\
        \n1 %i\
        \n2 %i\
        \n3 %i\
        \n4 %i\
        \n5 %i\
        ",
        clcmdnum[Cl][0],
        clcmdnum[Cl][1],
        clcmdnum[Cl][2],
        clcmdnum[Cl][3],
        clcmdnum[Cl][4],
        clcmdnum[Cl][5]
    );
}

void StacLogTickcounts(int userid)
{
    int Cl = GetClientOfUserId(userid);
    StacLog
    (
        "\
        \nPrevious tickcounts:\
        \n0 %i\
        \n1 %i\
        \n2 %i\
        \n3 %i\
        \n4 %i\
        \n5 %i\
        ",
        cltickcount[Cl][0],
        cltickcount[Cl][1],
        cltickcount[Cl][2],
        cltickcount[Cl][3],
        cltickcount[Cl][4],
        cltickcount[Cl][5]
    );
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
        if (aimsnapDetects[Cl] <= 0)
        {
            if (AIMPLOTTER)
            {
                ServerCommand("sm_aimplot #%i off", userid);
            }
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
        if (pSilentDetects[Cl] <= 0)
        {
            if (AIMPLOTTER)
            {
                ServerCommand("sm_aimplot #%i off", userid);
            }
        }
    }
}

public Action Timer_decr_tbot(Handle timer, any userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        if (tbotDetects[Cl] > -1)
        {
            tbotDetects[Cl]--;
        }
        if (tbotDetects[Cl] <= 0)
        {
            if (AIMPLOTTER)
            {
                ServerCommand("sm_aimplot #%i off", userid);
            }
        }
    }
}

public Action Timer_decr_cmdratespam(Handle timer, any userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        if (cmdrateSpamDetects[Cl] > 0)
        {
            cmdrateSpamDetects[Cl]--;
        }
    }
}

char cvarsToCheck[][] =
{
    // misc vars
    "sensitivity",
    // possible cheat vars
    "cl_interpolate",
    // this is a useless check but we check it anyway
    "fov_desired",
    //
    "cl_cmdrate",
};

public void ConVarCheck(QueryCookie cookie, int Cl, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
    // make sure client is valid
    if (!IsValidClient(Cl))
    {
        return;
    }
    int userid = GetClientUserId(Cl);

    if (DEBUG)
    {
        StacLog("[StAC] Checked cvar %s value %s on %N", cvarName, cvarValue, Cl);
    }

    // log something about cvar errors
    if (result != ConVarQuery_Okay)
    {
        PrintToImportant("{hotpink}[StAC]{white} Could not query cvar %s on Player %N", Cl);
        StacLog("[StAC] Could not query cvar %s on player %N", cvarName, Cl);
        return;
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
                char pubreason[256];
                Format(pubreason, sizeof(pubreason), "%t", "nolerpBanAllChat", Cl);
                // we have to do extra bullshit here so we don't crash when banning clients out of this callback
                // make a pack
                DataPack pack = CreateDataPack();

                // prepare pack
                WritePackCell(pack, userid);
                WritePackString(pack, reason);
                WritePackString(pack, pubreason);

                ResetPack(pack, false);

                // make data timer
                CreateTimer(0.1, Timer_BanUser, pack, TIMER_DATA_HNDL_CLOSE);
                return;
            }
            else
            {
                PrintToImportant("{hotpink}[StAC]{white} [Detection] Player %L is using NoLerp!", Cl);
                StacLog("[StAC] [Detection] Player %L is using NoLerp!", Cl);
            }
        }
    }
    // fov check #1 - if u get banned by this you are a clown
    else if (StrEqual(cvarName, "fov_desired"))
    {
        int fovDesired = StringToInt(cvarValue);
        // check just in case
        if
        (
            fovDesired < 20
            ||
            fovDesired > 90
        )
        {
            if (banForMiscCheats)
            {
                char reason[128];
                Format(reason, sizeof(reason), "%t", "fovBanMsg");
                char pubreason[256];
                Format(pubreason, sizeof(pubreason), "%t", "fovBanAllChat", Cl);
                // we have to do extra bullshit here so we don't crash when banning clients out of this callback
                // make a pack
                DataPack pack = CreateDataPack();

                // prepare pack
                WritePackCell(pack, userid);
                WritePackString(pack, reason);
                WritePackString(pack, pubreason);

                ResetPack(pack, false);

                // make data timer
                CreateTimer(0.1, Timer_BanUser, pack, TIMER_DATA_HNDL_CLOSE);
                return;
            }
            else
            {
                PrintToImportant("{hotpink}[StAC]{white} [Detection] Player %L is using fov cheats!", Cl);
                StacLog("[StAC] [Detection] Player %L is using fov cheats!", Cl);
            }
        }
    }
    // fov check #1 - if u get banned by this you are a clown
    else if (StrEqual(cvarName, "cl_cmdrate"))
    {
        if
        (
            StrEqual("-9999", cvarValue)
            ||
            StrEqual("-1", cvarValue)
        )
        {
            char scmdrate[16];
            // get actual value of cl cmdrate
            GetClientInfo(Cl, "cl_cmdrate", scmdrate, sizeof(scmdrate));
            if (!StrEqual(cvarValue, scmdrate))
            {
                StacLog("%N had cl_cmdrate value of %s, userinfo showed %s", Cl, cvarValue, scmdrate);
                if (banForMiscCheats)
                {
                    char reason[128];
                    Format(reason, sizeof(reason), "%t", "illegalCmdrateBanMsg");
                    char pubreason[256];
                    Format(pubreason, sizeof(pubreason), "%t", "illegalCmdrateBanAllChat", Cl);
                    // we have to do extra bullshit here so we don't crash when banning clients out of this callback
                    // make a pack
                    DataPack pack = CreateDataPack();
                    // prepare pack
                    WritePackCell(pack, userid);
                    WritePackString(pack, reason);
                    WritePackString(pack, pubreason);
                    ResetPack(pack, false);
                    // make data timer
                    CreateTimer(0.1, Timer_BanUser, pack, TIMER_DATA_HNDL_CLOSE);
                    return;
                }
                else
                {
                    PrintToImportant("{hotpink}[StAC] {red}[Detection]{white} Player %L has an illegal cmdrate value!", Cl);
                    StacLog("[StAC] [Detection] Player %L has an illegal cmdrate value!", Cl);
                }
            }
        }
    }
}

// we wait a bit to prevent crashing the server when banning a player from a queryclientconvar callback
public Action Timer_BanUser(Handle timer, DataPack pack)
{
    int userid          = ReadPackCell(pack);
    char reason[128];
    ReadPackString(pack, reason, sizeof(reason));
    char pubreason[256];
    ReadPackString(pack, pubreason, sizeof(pubreason));

    // get client index out of userid
    int Cl              = GetClientOfUserId(userid);

    // check validity of client index
    if (IsValidClient(Cl))
    {
        BanUser(userid, reason, pubreason);
    }
}

// ban on invalid characters (newlines, carriage returns, etc)
public Action OnClientSayCommand(int Cl, const char[] command, const char[] sArgs)
{
    // don't pick up console or bots
    if (!IsValidClient(Cl))
    {
        return Plugin_Continue;
    }
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
            char pubreason[256];
            Format(pubreason, sizeof(pubreason), "%t", "newlineBanAllChat", Cl);
            BanUser(userid, reason, pubreason);
        }
        else
        {
            PrintToImportant("{hotpink}[StAC]{white} [Detection] Blocked newline print from player %L", Cl);
            StacLog("[StAC] [Detection] Blocked newline print from player %L", Cl);
        }
        return Plugin_Stop;
    }
    /*
    // MEGA DEBUG
    if (StrContains(sArgs, "steamdown", false) != -1)
    {
        Steam_SteamServersDisconnected();
        SteamWorks_SteamServersDisconnected(view_as<EResult>(1));
        LogMessage("steamdown!");
    }
    if (StrContains(sArgs, "steamup", false) != -1)
    {
        Steam_SteamServersConnected();
        SteamWorks_SteamServersConnected();
        LogMessage("steamup!");
    }

    if (StrContains(sArgs, "checksteam", false) != -1)
    {
        LogMessage("%i", shouldCheckAuth());
    }
    */
    return Plugin_Continue;
}

char lastCommandFor[TFMAXPLAYERS+1][256];
float timeSinceLastCommand[TFMAXPLAYERS+1];
// block long commands - i don't know if this actually does anything but it makes me feel better
public Action OnClientCommand(int Cl, int args)
{
    if (IsValidClient(Cl))
    {
        int userid = GetClientUserId(Cl);
        // init var
        char ClientCommandChar[512];
        // gets the first command
        GetCmdArg(0, ClientCommandChar, sizeof(ClientCommandChar));
        // get length of string
        int len = strlen(ClientCommandChar);

        // is there more after this command?
        if (GetCmdArgs() > 0)
        {
            // add a space at the end of it
            ClientCommandChar[len++] = ' ';
            GetCmdArgString(ClientCommandChar[len++], sizeof(ClientCommandChar));
        }

        strcopy(lastCommandFor[Cl], sizeof(lastCommandFor[]), ClientCommandChar);
        timeSinceLastCommand[Cl] = engineTime[Cl][0];


        // clean it up ( PROBABLY NOT NEEDED )
        // TrimString(ClientCommandChar);

        if (DEBUG)
        {
            StacLog("[StAC] '%L' issued client side command with %i length:", Cl, strlen(ClientCommandChar));
            StacLog("%s", ClientCommandChar);
        }
        if (strlen(ClientCommandChar) > 255 || len > 255)
        {
            StacGeneralPlayerDiscordNotify(userid, "Client sent a very large command to the server!");
            StacLog("%s", ClientCommandChar);
            return Plugin_Stop;
        }
    }
    return Plugin_Continue;
}

// ban for cmdrate value change spam.
// cheats do this to fake their ping
public void OnClientSettingsChanged(int Cl)
{
    CheckAndFixCmdrate(Cl);
}

void CheckAndFixCmdrate(int Cl)
{
    // ignore invalid clients and dead / in spec clients
    if (!IsValidClient(Cl) || !IsClientPlaying(Cl) || !fixpingmasking)
    {
        return;
    }

    if
    (
        // command occured recently
        engineTime[Cl][0] - 2.5 < timeSinceLastCommand[Cl]
        &&
        // and it's a demorestart
        StrEqual("demorestart", lastCommandFor[Cl])
    )
    {
        //StacLog("Ignoring demorestart settings change for %N", Cl);
        return;
    }

    // get userid for timer
    int userid = GetClientUserId(Cl);

    // pingreduce check only works if you are using fixpingmasking!
    // buffer for cmdrate value

    char scmdrate[16];
    // get actual value of cl cmdrate
    GetClientInfo(Cl, "cl_cmdrate", scmdrate, sizeof(scmdrate));
    // convert it to int
    int icmdrate = StringToInt(scmdrate);

    // clamp it
    int iclamprate = Math_Clamp(icmdrate, imincmdrate, imaxcmdrate);
    char sclamprate[4];
    // convert it to string
    IntToString(iclamprate, sclamprate, sizeof(sclamprate));

    // do the same thing with updaterate
    char supdaterate[4];
    // get actual value of cl updaterate
    GetClientInfo(Cl, "cl_updaterate", supdaterate, sizeof(supdaterate));
    // convert it to int
    int iupdaterate = StringToInt(supdaterate);

    // clamp it
    int iclampupdaterate = Math_Clamp(iupdaterate, iminupdaterate, imaxupdaterate);
    char sclampupdaterate[4];
    // convert it to string
    IntToString(iclampupdaterate, sclampupdaterate, sizeof(sclampupdaterate));

    /*
        CMDRATE SPAM CHECK

        technically this could be triggered by clients spam recording and stopping demos, but cheats do it infinitely faster
    */
    cmdrateSpamDetects[Cl]++;
    // have this detection expire in 10 seconds!!! remember - this means that the amount of detects are ONLY in the last 10 seconds!
    // ncc caps out at 140ish
    CreateTimer(10.0, Timer_decr_cmdratespam, userid, TIMER_FLAG_NO_MAPCHANGE);
    if (cmdrateSpamDetects[Cl] >= 10)
    {
        PrintToImportant
        (
            "{hotpink}[StAC]{white} %N is suspected of ping-reducing or masking using a cheat.\nDetections within the last 10 seconds: {palegreen}%i{white}. Cmdrate value: {blue}%i",
            Cl,
            cmdrateSpamDetects[Cl],
            icmdrate
        );
        StacLog
        (
            "[StAC] %N is suspected of ping-reducing or masking using a cheat.\nDetections so far: %i.\nCmdrate: %i\nUpdaterate: %i",
            Cl,
            cmdrateSpamDetects[Cl],
            icmdrate,
            iupdaterate
        );
        if (cmdrateSpamDetects[Cl] % 5 == 0)
        {
            StacDetectionDiscordNotify(userid, "cmdrate spam / ping modification", cmdrateSpamDetects[Cl]);
        }

        // BAN USER if they trigger too many detections
        if (cmdrateSpamDetects[Cl] >= maxCmdrateSpamDetects && maxCmdrateSpamDetects > 0)
        {
            char reason[128];
            Format(reason, sizeof(reason), "%t", "cmdrateSpamBanMsg", cmdrateSpamDetects[Cl]);
            char pubreason[256];
            Format(pubreason, sizeof(pubreason), "%t", "cmdrateSpamBanAllChat", Cl, cmdrateSpamDetects[Cl]);
            BanUser(userid, reason, pubreason);
            return;
        }
    }

    if
    (
        // cmdrate is == to optimal clamped rate
        icmdrate != iclamprate
        ||
        // client string is exactly equal to string of optimal cmdrate
        !StrEqual(scmdrate, sclamprate)
    )
    {
        SetClientInfo(Cl, "cl_cmdrate", sclamprate);
        //LogMessage("clamping cmdrate to %s", sclamprate);
    }

    if
    (
        // cmdrate is == to optimal clamped rate
        iupdaterate != iclampupdaterate
        ||
        // client string is exactly equal to string of optimal cmdrate
        !StrEqual(supdaterate, sclampupdaterate)
    )
    {
        SetClientInfo(Cl, "cl_updaterate", sclampupdaterate);
        //LogMessage("clamping updaterate to %s", sclampupdaterate);
    }
}

void UpdateRates()
{
    imincmdrate    = GetConVarInt(FindConVar("sv_mincmdrate"));
    imaxcmdrate    = GetConVarInt(FindConVar("sv_maxcmdrate"));
    iminupdaterate = GetConVarInt(FindConVar("sv_minupdaterate"));
    imaxupdaterate = GetConVarInt(FindConVar("sv_maxupdaterate"));

    // reset all client based vars on plugin reload
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            OnClientSettingsChanged(Cl);
        }
    }
}

void RateChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    UpdateRates();
}

// no longer just for netprops!
void NetPropEtcCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        // there used to be an fov check here - but there's odd behavior that i don't want to work around regarding the m_iFov netprop.
        // sorry!

        // forcibly disables thirdperson with some cheats
        ClientCommand(Cl, "firstperson");
        if (DEBUG)
        {
            StacLog("[StAC] Executed firstperson command on Player %N", Cl);
        }

        // lerp check - we check the netprop
        // don't check if not default tickrate
        if (isDefaultTickrate())
        {
            float lerp = GetEntPropFloat(Cl, Prop_Data, "m_fLerpTime") * 1000;
            if (DEBUG)
            {
                StacLog("%.2f ms interp on %N", lerp, Cl);
            }
            if (lerp == 0.0)
            {
                // repeated code lol
                if (banForMiscCheats)
                {
                    char reason[128];
                    Format(reason, sizeof(reason), "%t", "nolerpBanMsg");
                    char pubreason[256];
                    Format(pubreason, sizeof(pubreason), "%t", "nolerpBanAllChat", Cl);
                }
                else
                {
                    StacGeneralPlayerDiscordNotify(userid, "Client sent a very large command to the server!");
                    PrintToImportant("{hotpink}[StAC]{white} [Detection] Player %L is using NoLerp!", Cl);
                    StacLog("[StAC] [Detection] Player %L is using NoLerp!", Cl);
                }
            }
            if
            (
                lerp < min_interp_ms && min_interp_ms != -1
                ||
                lerp > max_interp_ms && max_interp_ms != -1
            )
            {
                char message[256];
                Format(message, sizeof(message), "Client was kicked for attempted interp exploitation. Their interp: %.2fms", lerp);
                StacGeneralPlayerDiscordNotify(userid, message);
                KickClient(Cl, "%t", "interpKickMsg", lerp, min_interp_ms, max_interp_ms);
                MC_PrintToChatAll("%t", "interpAllChat", Cl, lerp);
                StacLog("%t", "interpAllChat", Cl, lerp);
            }
        }
    }
}

/////////////////
// TIMER STUFF //
/////////////////

// timer for (re)checking ALL cvars and net props and everything else
public Action Timer_CheckClientConVars(Handle timer, int userid)
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
        // init variable to pass to QueryCvarsEtc
        int i;
        // query the client!
        QueryCvarsEtc(userid, i);
        // we just checked, but we want to check again eventually
        // lets make a timer with a random length between stac_min_randomcheck_secs and stac_max_randomcheck_secs
        QueryTimer[Cl] =
        CreateTimer
        (
            GetRandomFloat
            (
                minRandCheckVal,
                maxRandCheckVal
            ),
            Timer_CheckClientConVars,
            userid
        );
    }
}

// query all cvars and netprops for userid
void QueryCvarsEtc(int userid, int i)
{
    // get client index of userid
    int Cl = GetClientOfUserId(userid);
    // don't go no further if client isn't valid!
    if (IsValidClient(Cl))
    {
        // check cvars!
        if (i < sizeof(cvarsToCheck))
        {
            // make pack
            DataPack pack = CreateDataPack();
            // actually query the cvar here based on pos in convar array
            QueryClientConVar(Cl, cvarsToCheck[i], ConVarCheck);
            // increase pos in convar array
            i++;
            // prepare pack
            WritePackCell(pack, userid);
            WritePackCell(pack, i);
            // reset pack pos to 0
            ResetPack(pack, false);
            // make data timer
            CreateTimer(2.5, timer_QueryNextCvar, pack, TIMER_DATA_HNDL_CLOSE);
        }
        // we checked all the cvars!
        else
        {
            // now lets check some AC related netprops and other misc stuff
            NetPropEtcCheck(userid);
        }
    }
}

// timer for checking the next cvar in the list (waits a bit to balance out server load)
public Action timer_QueryNextCvar(Handle timer, DataPack pack)
{
    // read userid
    int userid = ReadPackCell(pack);
    // read i
    int i      = ReadPackCell(pack);

    // get client index out of userid
    int Cl     = GetClientOfUserId(userid);

    // check validity of client index
    if (IsValidClient(Cl))
    {
        QueryCvarsEtc(userid, i);
    }
}

// expensive!
void QueryEverythingAllClients()
{
    if (DEBUG)
    {
        StacLog("[StAC] Querying all clients");
    }
    // loop thru all clients
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            // get userid of this client index
            int userid = GetClientUserId(Cl);
            // init variable to pass to QueryCvarsEtc
            int i;
            // query the client!
            QueryCvarsEtc(userid, i);
        }
    }
}

////////////
// STONKS //
////////////

public void BanUser(int userid, char[] reason, char[] pubreason)
{
    int Cl = GetClientOfUserId(userid);

    // prevent double bans
    if (userBanQueued[Cl])
    {
        KickClient(Cl, "Banned by StAC");
        return;
    }

    // make sure we dont detect on already banned players
    userBanQueued[Cl] = true;

    // check if client is authed before banning normally
    bool isAuthed = IsClientAuthorized(Cl);

    if (demonameInBanReason)
    {
        if (GetDemoName())
        {
            char demoname_plus[256];
            strcopy(demoname_plus, sizeof(demoname_plus), demoname);
            Format(demoname_plus, sizeof(demoname_plus), ". Demo file: %s", demoname_plus);
            StrCat(reason, 256, demoname_plus);
            StacLog("Reason: %s", reason);
        }
        else
        {
            StacLog("[StAC] No STV demo is being recorded, no demo name will be printed to the ban reason!");
        }
    }
    if (isAuthed)
    {
        if (SOURCEBANS)
        {
            SBPP_BanPlayer(0, Cl, 0, reason);
            // there's no return value for that native, so we have to just assume it worked lol
            return;
        }
        if (GBANS)
        {
            ServerCommand("gb_ban %i, 0, %s", userid, reason);
            // there's no return value nor a native for gbans bans (YET), so we have to just assume it worked lol
            return;
        }
        // stock tf2, no ext ban system. if we somehow fail here, keep going.
        if (BanClient(Cl, 0, BANFLAG_AUTO, reason, reason, _, _))
        {
            return;
        }
    }
    // if we got here steam is being fussy or the client is not auth'd in some way, or the stock tf2 ban failed somehow.
    StacLog("Client %N is not authorized, steam is down, or the ban failed for some other reason. Attempting to ban with cached SteamID...", Cl);
    // if this returns true, we can still ban the client with their steamid in a roundabout and annoying way.
    if (!IsActuallyNullString(SteamAuthFor[Cl]))
    {
        ServerCommand("sm_addban 0 \"%s\" %s", SteamAuthFor[Cl], reason);
        KickClient(Cl, "%s", reason);
    }
    // if the above returns false, we can only do ip :/
    else
    {
        char ip[16];
        GetClientIP(Cl, ip, sizeof(ip));

        StacLog("[StAC] No cached SteamID for %N! Banning with IP %s...", Cl, ip);
        ServerCommand("sm_banip %s 0 %s", ip, reason);
        // this kick client might not be needed - you get kicked by "being added to ban list"
        // KickClient(Cl, "%s", reason);
    }

    MC_PrintToChatAll("%s", pubreason);
    StacLog("%s", pubreason);
}

// Open log file for StAC
void OpenStacLog()
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
        // 511 = unix 775 ?
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
void CloseStacLog()
{
    delete StacLogFile;
}

// log to StAC log file
void StacLog(const char[] format, any ...)
{
    char buffer[254];
    VFormat(buffer, sizeof(buffer), format, 2);
    // clear color tags
    MC_RemoveTags(buffer, sizeof(buffer));

    if (StacLogFile != null)
    {
        LogToOpenFile(StacLogFile, buffer);
    }
    else
    {
        LogMessage("[StAC] File handle invalid!");
        LogMessage("%s", buffer);
    }
    PrintToConsoleAllAdmins("%s", buffer);
}

float CalcAngDeg(float array1[3], float array2[3])
{
    // ignore roll
    array1[2] = 0.0;
    array2[2] = 0.0;
    return SquareRoot(GetVectorDistance(array1, array2, true));
}

// IsValidClient stocks
bool IsValidClient(int client)
{
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && !IsClientInKickQueue(client)
        && !userBanQueued[client]
        && !IsFakeClient(client)
    );
}

bool IsValidClientOrBot(int client)
{
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && !IsClientInKickQueue(client)
        && !userBanQueued[client]
        // don't bother sdkhooking stv or replay bots lol
        && !IsClientSourceTV(client)
        && !IsClientReplay(client)
    );
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

bool HasValidAngles(int Cl)
{
    if
    (
        // ignore weird angle resets in mge / dm, ignore laggy players
        (
            IsNullVector(clangles[Cl][0])
        )
        ||
        (
            IsNullVector(clangles[Cl][1])
        )
        ||
        (
            IsNullVector(clangles[Cl][2])
        )
        ||
        (
            IsNullVector(clangles[Cl][3])
        )
        ||
        (
            IsNullVector(clangles[Cl][4])
        )
    )
    {
        return false;
    }
    return true;
}

// print colored chat to all server/sourcemod admins
void PrintToImportant(const char[] format, any ...)
{
    char buffer[254];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidAdmin(i) || IsValidSrcTV(i))
        {
            SetGlobalTransTarget(i);
            VFormat(buffer, sizeof(buffer), format, 2);
            MC_PrintToChat(i, "%s", buffer);
        }
    }
}

// print to all server/sourcemod admin's consoles
void PrintToConsoleAllAdmins(const char[] format, any ...)
{
    char buffer[254];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidAdmin(i) || IsValidSrcTV(i))
        {
            SetGlobalTransTarget(i);
            VFormat(buffer, sizeof(buffer), format, 2);
            PrintToConsole(i, "%s", buffer);
        }
    }
}

any abs(any x)
{
    return x > 0 ? x : -x;
}

public void Steam_SteamServersDisconnected()
{
    isSteamAlive = 0;
    StacLog("[Steamtools] Steam disconnected.");
}

public void SteamWorks_SteamServersDisconnected(EResult result)
{
    isSteamAlive = 0;
    StacLog("[SteamWorks] Steam disconnected.");
}

public void Steam_SteamServersConnected()
{
    setSteamOnline();
    StacLog("[Steamtools] Steam connected.");
}

public void SteamWorks_SteamServersConnected()
{
    setSteamOnline();
    StacLog("[SteamWorks] Steam connected.");
}

void setSteamOnline()
{
    isSteamAlive = 1;
    steamLastOnlineTime = GetEngineTime();
}

// this will return false for 300 seconds after server start. just a heads up.
bool isSteamStable()
{
    if (steamLastOnlineTime == 0.0 || isSteamAlive == -1)
    {
        checkSteam();
        return false;
    }

    StacLog("[StAC] GetEngineTime() - steamLastOnlineTime = %f >? 300.0", GetEngineTime() - steamLastOnlineTime);

    // time since steam last came online must be greater than 300
    if (GetEngineTime() - steamLastOnlineTime >= 300.0)
    {
        StacLog("steam stable!");
        return true;
    }
    StacLog("steam went down too recently");
    return false;
}

bool checkSteam()
{
    if (STEAMTOOLS)
    {
        if (Steam_IsConnected())
        {
            steamLastOnlineTime = GetEngineTime();
            isSteamAlive = 1;
            return true;
        }
        isSteamAlive = 0;
    }
    if (STEAMWORKS)
    {
        if (SteamWorks_IsConnected())
        {
            steamLastOnlineTime = GetEngineTime();
            isSteamAlive = 1;
            return true;
        }
        isSteamAlive = 0;
    }
    isSteamAlive = -1;
    return false;
}

bool shouldCheckAuth()
{
    if
    (
        isSteamAlive == 1
        &&
        isSteamStable()
    )
    {
        return true;
    }
    return false;
}

bool IsHalloweenCond(TFCond condition)
{
    if
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
        return true;
    }
    return false;
}

// stolen from smlib
int Math_Clamp(int value, int min, int max)
{
    value = Math_Min(value, min);
    value = Math_Max(value, max);

    return value;
}

int Math_Min(int value, int min)
{
    if (value < min)
    {
        value = min;
    }

    return value;
}

int Math_Max(int value, int max)
{
    if (value > max)
    {
        value = max;
    }

    return value;
}

float NormalizeAngleDiff(float aDiff)
{
    if (aDiff > 180.0)
    {
        aDiff = FloatAbs(aDiff - 360.0);
    }
    return aDiff;
}

void StacDetectionDiscordNotify(int userid, char[] type, int detections)
{
    if (!DISCORD)
    {
        return;
    }

    char msg[1024];

    int Cl = GetClientOfUserId(userid);
    char ClName[64];
    GetClientName(Cl, ClName, sizeof(ClName));
    Discord_EscapeString(ClName, sizeof(ClName));
    GetDemoName();
    // we technically store the url in this so it has to be bigger
    char steamid[96];
    // ok we store these on client connect & auth, this shouldn't be null
    if (!IsActuallyNullString(SteamAuthFor[Cl]))
    {
        // make this a clickable link in discord
        Format(steamid, sizeof(steamid), "[%s](https://steamid.io/lookup/%s)", SteamAuthFor[Cl], SteamAuthFor[Cl]);
    }
    // if it is, that means the plugin reloaded or steam is being fussy.
    else
    {
        steamid = "N/A";
    }

    Format
    (
        msg,
        sizeof(msg),
        detectionTemplate,
        Cl,
        steamid,
        type,
        detections,
        hostname,
        hostipandport,
        demoname
    );
    SendMessageToDiscord(msg);
}

void StacGeneralPlayerDiscordNotify(int userid, char[] message)
{
    if (!DISCORD)
    {
        return;
    }

    char msg[1024];

    int Cl = GetClientOfUserId(userid);
    char ClName[64];
    GetClientName(Cl, ClName, sizeof(ClName));
    Discord_EscapeString(ClName, sizeof(ClName));
    GetDemoName();
    // we technically store the url in this so it has to be bigger
    char steamid[96];
    // ok we store these on client connect & auth, this shouldn't be null
    if (!IsActuallyNullString(SteamAuthFor[Cl]))
    {
        // make this a clickable link in discord
        Format(steamid, sizeof(steamid), "[%s](https://steamid.io/lookup/%s)", SteamAuthFor[Cl], SteamAuthFor[Cl]);
    }
    // if it is, that means the plugin reloaded or steam is being fussy.
    else
    {
        steamid = "N/A";
    }
    Format
    (
        msg,
        sizeof(msg),
        generalTemplate,
        Cl,
        steamid,
        message,
        hostname,
        hostipandport,
        demoname
    );
    SendMessageToDiscord(msg);
}

void SendMessageToDiscord(char[] message)
{
    char webhook[32] = "stac";
    Discord_SendMessage(webhook, message);
}

void checkStatus()
{
    char status[2048];
    ServerCommandEx(status, sizeof(status), "status");
    char ipetc[128];
    char ip[24];
    if (MatchRegex(publicIPRegex, status) > 0)
    {
        if (GetRegexSubString(publicIPRegex, 0, ipetc, sizeof(ipetc)))
        {
            TrimString(ipetc);
            if (MatchRegex(IPRegex, ipetc) > 0)
            {
                if (GetRegexSubString(IPRegex, 0, ip, sizeof(ip)))
                {
                    strcopy(hostipandport, sizeof(hostipandport), ip);
                    StrCat(hostipandport, sizeof(hostipandport), ":");
                    char hostport[6];
                    GetConVarString(FindConVar("hostport"), hostport, sizeof(hostport));
                    StrCat(hostipandport, sizeof(hostipandport), hostport);
                }
            }
        }
    }
}

bool GetDemoName()
{
    char tvStatus[512];
    ServerCommandEx(tvStatus, sizeof(tvStatus), "tv_status");
    char demoname_etc[128];
    if (MatchRegex(demonameRegex, tvStatus) > 0)
    {
        if (GetRegexSubString(demonameRegex, 0, demoname_etc, sizeof(demoname_etc)))
        {
            TrimString(demoname_etc);
            if (MatchRegex(demonameRegexFINAL, demoname_etc) > 0)
            {
                if (GetRegexSubString(demonameRegexFINAL, 0, demoname, sizeof(demoname)))
                {
                    TrimString(demoname);
                    StripQuotes(demoname);
                    return true;
                }
            }
        }
    }
    demoname = "N/A";
    return false;
}

bool isDefaultTickrate()
{
    if (tps > 60.0 && tps < 70.0)
    {
        return true;
    }
    return false;
}

bool isCmdnumSequential(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if
    (
           clcmdnum[Cl][0] == clcmdnum[Cl][1] + 1
        && clcmdnum[Cl][1] == clcmdnum[Cl][2] + 1
        && clcmdnum[Cl][2] == clcmdnum[Cl][3] + 1
        && clcmdnum[Cl][3] == clcmdnum[Cl][4] + 1
        && clcmdnum[Cl][4] == clcmdnum[Cl][5] + 1
    )
    {
        return true;
    }
    return false;
}

bool isTickcountInOrder(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if
    (
        cltickcount[Cl][0] >=
        cltickcount[Cl][1] >=
        cltickcount[Cl][2] >=
        cltickcount[Cl][3] >=
        cltickcount[Cl][4] >=
        cltickcount[Cl][5]
    )
    {
        return true;
    }
    return false;
}

// sourcemod is fucking ridiculous, "IsNullString" only checks for a specific definition of nullstring
bool IsActuallyNullString(char[] somestring)
{
    if (somestring[0] != '\0')
    {
        return false;
    }
    return true;
}

float RoundToPlace(float input, int decimalPlaces)
{
    float poweroften = Pow(10.0, float(decimalPlaces));
    return RoundToNearest(input * poweroften) / (poweroften);
}

//float NormalizeAngleVector(float angles[3])
//{
//    if (angles[0] > 89.0)
//    {
//        angles[0] = 89.0;
//    }
//    if (angles[0] < -89.0)
//    {
//        angles[0] = -89.0;
//    }
//
//    while (angles[1] > 180.0)
//    {
//        angles[1] -= 360.0;
//    }
//    while (angles[1] < -180.0)
//    {
//        angles[1] += 360.0;
//    }
//    if (angles[2] != 0.0)
//    {
//        angles[2] = 0.0;
//    }
//    return angles;
//}

//bool isClientAFK(int Cl)
//{
//    if
//    (
//           clmouse[Cl][0] == 0
//        && clmouse[Cl][1] == 0
//        && AreVectorsEqual(clpos[Cl][0], clpos[Cl][1])
//        && clbuttons[Cl][0] == 0
//        && clbuttons[Cl][1] == 0
//        && clbuttons[Cl][2] == 0
//        && clbuttons[Cl][3] == 0
//        && clbuttons[Cl][4] == 0
//        && clbuttons[Cl][5] == 0
//        && AreVectorsEqual(clangles[Cl][0], clangles[Cl][1])
//        && AreVectorsEqual(clangles[Cl][1], clangles[Cl][2])
//        && AreVectorsEqual(clangles[Cl][2], clangles[Cl][3])
//        && AreVectorsEqual(clangles[Cl][3], clangles[Cl][4])
//    )
//    {
//        return true;
//    }
//
//    return false;
//}
//
//bool AreVectorsEqual(float vector1[3], float vector2[3])
//{
//    return (vector1[0] == vector2[0] && vector1[1] == vector2[1] && vector1[2] == vector2[2]);
//}

bool IsValidAdmin(int Cl)
{
    if (IsValidClient(Cl))
    {
        if (CheckCommandAccess(Cl, "sm_ban", ADMFLAG_GENERIC))
        {
            return true;
        }
    }
    return false;
}

bool IsValidSrcTV(int client)
{
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && IsClientSourceTV(client)
    );
}

// stolen from ssac
//void SendPanelMessage(int Cl, const char[] format, any ...)
//{
//    /* Bascially is the same thing as sm_msay. Thanks to " ferret " https://forums.alliedmods.net/member.php?u=14068 */
//    /* Ied much rather use this due to the fact it give us more freedom to change values over the stock "menu" handler. */
//
//    char sBuffer[512];
//    VFormat(sBuffer, sizeof(sBuffer), format, 3);
//    Panel LiveFeedPanel = new Panel();
//    LiveFeedPanel.SetTitle("");
//    LiveFeedPanel.DrawText(sBuffer);
//    LiveFeedPanel.DrawItem("", ITEMDRAW_SPACER);
//    LiveFeedPanel.CurrentKey = 10;
//    LiveFeedPanel.DrawItem("Exit", ITEMDRAW_CONTROL);
//    LiveFeedPanel.Send(Cl, Handler_DoNothing, 1);
//    delete LiveFeedPanel;
//}
//
//public int Handler_DoNothing(Menu menu, MenuAction action, int param1, int param2)
//{
//    /* Do nothing */
//}
