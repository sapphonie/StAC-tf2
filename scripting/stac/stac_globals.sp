#pragma semicolon 1

#if defined TF2C
    #define TFMAXPLAYERS 65
#else
    #define TFMAXPLAYERS 33
#endif


/********** GLOBAL VARS **********/


/***** Cvar Handles *****/
ConVar stac_enabled;
ConVar stac_ban_duration;
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
ConVar stac_max_cmdrate_spam_detections;
ConVar stac_min_interp_ms;
ConVar stac_max_interp_ms;
ConVar stac_min_randomcheck_secs;
ConVar stac_max_randomcheck_secs;
ConVar stac_include_demoname_in_banreason;
ConVar stac_log_to_file;
ConVar stac_fixpingmasking_enabled;
ConVar stac_kick_unauthed_clients;
ConVar stac_silent;
ConVar stac_max_connections_from_ip;
ConVar stac_work_with_sv_cheats;

/***** Misc cheat defaults *****/
// ban duration
int banDuration                 = 0;
// verbose mode
bool DEBUG                      = false;
// interp
int min_interp_ms               = -1;
int max_interp_ms               = 101;
// random misccheats check (in secs)
float minRandCheckVal           = 60.0;
float maxRandCheckVal           = 300.0;
// demoname in sourcebans / gbans?
bool demonameInBanReason        = true;
// log to file
bool logtofile                  = true;
// fix pingmasking - required for pingreduce check
bool fixpingmasking             = true;
bool kickUnauth                 = false;
float maxAllowedTurnSecs        = -1.0;
bool banForMiscCheats           = true;
bool optimizeCvars              = true;
int silent                      = 0;
int maxip                       = 0;
bool ignore_sv_cheats           = false;

/***** Detection based cheat defaults *****/
int maxAimsnapDetections        = 20;
int maxPsilentDetections        = 10;
int maxFakeAngDetections        = 5;
int maxBhopDetections           = 10;
int maxCmdnumDetections         = 20;
int maxTbotDetections           = 0;
int maxuserinfoSpamDetections   = 25;

/***** Server based stuff *****/

// tickrate stuff
float tickinterv;
float tps;

// time to wait after server lags before checking all client's OnPlayerRunCmd
float ServerLagWaitLength = 5.0;
// time to wait after player lags before checking single client's OnPlayerRunCmd
float PlayerLagWaitLength = 1.0;

// misc server info
char hostname[64];
char hostipandport[24];
char demoname[128];
int demotick = -1;

// server cvar values
bool waitStatus;
int imaxcmdrate;
int imincmdrate;
int imaxupdaterate;
int iminupdaterate;
int imaxrate;
int iminrate;
float timescale;

// time since some server event happened
// time since the map started
float timeSinceMapStart;
// time since the last stutter/lag spike occurred per client
float timeSinceLagSpikeFor[TFMAXPLAYERS + 1];

// native/gamemode/plugin etc bools
bool SOURCEBANS;
bool MATERIALADMIN;
bool GBANS;
bool AIMPLOTTER;
bool DISCORD;
bool MVM;
bool SOURCETVMGR;
bool STEAMWORKS;

/***** client based stuff *****/

// cheat detections per client
int turnTimes               [TFMAXPLAYERS+1];
int fakeAngDetects          [TFMAXPLAYERS+1];
int aimsnapDetects          [TFMAXPLAYERS+1] = {-1, ...}; // set to -1 to ignore first detections, as theyre most likely junk
int pSilentDetects          [TFMAXPLAYERS+1] = {-1, ...}; // ^
int bhopDetects             [TFMAXPLAYERS+1] = {-1, ...}; // set to -1 to ignore single jumps
int cmdnumSpikeDetects      [TFMAXPLAYERS+1];
int tbotDetects             [TFMAXPLAYERS+1] = {-1, ...};
int userinfoSpamDetects     [TFMAXPLAYERS+1];

// frames since client "did something"
//                          [ client index ][history]
float timeSinceSpawn        [TFMAXPLAYERS+1];
float timeSinceTaunt        [TFMAXPLAYERS+1];
float timeSinceTeled        [TFMAXPLAYERS+1];
float timeSinceNullCmd      [TFMAXPLAYERS+1];
float timeSinceLastCommand  [TFMAXPLAYERS+1];
// ticks since client "did something"
//                          [ client index ][history]
bool didBangOnFrame         [TFMAXPLAYERS+1][3];
bool didHurtOnFrame         [TFMAXPLAYERS+1][3];
bool didBangThisFrame       [TFMAXPLAYERS+1];
bool didHurtThisFrame       [TFMAXPLAYERS+1];

// OnPlayerRunCmd vars      [ client index ][history][ang/pos/etc]
float clangles              [TFMAXPLAYERS+1][5][3];
int   clcmdnum              [TFMAXPLAYERS+1][6];
int   cltickcount           [TFMAXPLAYERS+1][6];
int   clbuttons             [TFMAXPLAYERS+1][6];
int   clmouse               [TFMAXPLAYERS+1]   [2];
// OnPlayerRunCmd misc
float engineTime            [TFMAXPLAYERS+1][3];
float fuzzyClangles         [TFMAXPLAYERS+1][5][2];
float clpos                 [TFMAXPLAYERS+1][2][3];

// Misc stuff per client    [ client index ][char size]
char SteamAuthFor           [TFMAXPLAYERS+1][64];

bool highGrav               [TFMAXPLAYERS+1];
bool playerTaunting         [TFMAXPLAYERS+1];
int playerInBadCond         [TFMAXPLAYERS+1];
bool userBanQueued          [TFMAXPLAYERS+1];
float sensFor               [TFMAXPLAYERS+1];
// weapon name, gets passed to aimsnap check
char hurtWeapon             [TFMAXPLAYERS+1][256];
char lastCommandFor         [TFMAXPLAYERS+1][256];
bool LiveFeedOn             [TFMAXPLAYERS+1];
bool hasBadName             [TFMAXPLAYERS+1];

// network info
float lossFor               [TFMAXPLAYERS+1];
float chokeFor              [TFMAXPLAYERS+1];
float inchokeFor            [TFMAXPLAYERS+1];
float outchokeFor           [TFMAXPLAYERS+1];
float pingFor               [TFMAXPLAYERS+1];
float rateFor               [TFMAXPLAYERS+1];
float ppsFor                [TFMAXPLAYERS+1];

/***** Misc other handles *****/

// Log file
File StacLogFile;

// regex for getting demoname and server pub ip
Regex demonameRegex;
Regex demonameRegexFINAL;
Regex publicIPRegex;
Regex IPRegex;

// hud sync handles for livefeed
Handle HudSyncRunCmd;
Handle HudSyncRunCmdMisc;
Handle HudSyncNetwork;

// Timer handles
Handle QueryTimer           [TFMAXPLAYERS+1];
Handle TriggerTimedStuffTimer;

/*
    "cl_interp_npcs",
    "cl_flipviewmodels",
    "cl_predict",
    "cl_interp_ratio",
    "cl_interp",
    "cl_team",
    "cl_class",
    "hap_HasDevice",
    "cl_showhelp",
    "english",
    "cl_predictweapons",
    "cl_lagcompensation",
    "hud_classautokill",
    "cl_spec_mode",
    "cl_autorezoom",
    "tf_remember_activeweapon",
    "tf_remember_lastswitched",
    "cl_autoreload",
    "fov_desired",
    "hud_combattext",
    "hud_combattext_healing",
    "hud_combattext_batching",
    "hud_combattext_doesnt_block_overhead_text",
    "hud_combattext_green",
    "hud_combattext_red",
    "hud_combattext_blue",
    "tf_medigun_autoheal",
    "voice_loopback",
    "name",
    "tv_nochat",
    "cl_language",
    "rate",
    "cl_cmdrate",
    "cl_updaterate",
    "closecaption",
    "net_maxroutable"
*/

char userinfoToCheck[][] =
{
    "cl_cmdrate",       // for fixpingmasking, check for invalid values, check for spamming
    "cl_updaterate",    // for fixpingmasking, for interp check
    "rate",             // for fixpingmasking
    //"cl_autoreload",     // check for spamming
    "cl_interp",        // for interp check
    "cl_interp_ratio"   // for interp check
};

//  [cvarvalue][history][charsize]
char userinfoValues[64][TFMAXPLAYERS+1][4][64];

// for checking if we just fixed a client's network settings so we don't double detect
bool justclamped        [TFMAXPLAYERS+1];

// tps etc
int tickspersec        [TFMAXPLAYERS+1];
// iterated tick num per client
int t                  [TFMAXPLAYERS+1];

float secTime          [TFMAXPLAYERS+1];

char os                [16];

// client has waited the full 60 seconds for their first convar check
bool hasWaitedForCvarCheck[TFMAXPLAYERS+1];
