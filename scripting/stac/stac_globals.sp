#pragma semicolon 1

// we don't need 64 maxplayers because this is only for tf2. saves some memory.
#define TFMAXPLAYERS 33

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
ConVar stac_max_invalid_usercmd_detections;
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
int maxInvalidUsercmdDetections = 5;

/***** Server based stuff *****/

// tickrate stuff
float tickinterv;
float tps;
int itps;
//int itps_maxaheadsecs;
int servertick;

// time to wait after server lags before checking all client's OnPlayerRunCmd
float ServerLagWaitLength = 5.0;

// misc server info
char hostipandport[24];
char demoname[128];
int demotick = -1;

// server cvar values
bool waitStatus;
float timescale;

// time since some server event happened
// time since the map started
float timeSinceMapStart;

// native/gamemode/plugin etc bools
bool configsExecuted = false;

bool SOURCEBANS;
bool MATERIALADMIN;
bool GBANS;
bool AIMPLOTTER;
bool DISCORD;
bool MVM;

/***** client based stuff *****/
// This insane shit will eventually be an enum struct
// cheat detections per client
int turnTimes               [TFMAXPLAYERS+1];
int fakeAngDetects          [TFMAXPLAYERS+1];
int aimsnapDetects          [TFMAXPLAYERS+1] = {-1, ...}; // set to -1 to ignore first detections, as theyre most likely junk
int pSilentDetects          [TFMAXPLAYERS+1] = {-1, ...}; // ^
int bhopDetects             [TFMAXPLAYERS+1] = {-1, ...}; // set to -1 to ignore single jumps
int cmdnumSpikeDetects      [TFMAXPLAYERS+1];
int tbotDetects             [TFMAXPLAYERS+1] = {-1, ...};
int invalidUsercmdDetects   [TFMAXPLAYERS+1];

// frames since client "did something"
//                          [ client index ][history]
float timeSinceSpawn        [TFMAXPLAYERS+1];
float timeSinceTaunt        [TFMAXPLAYERS+1];
float timeSinceTeled        [TFMAXPLAYERS+1];
float timeSinceLastCommand  [TFMAXPLAYERS+1];
// ticks since client "did something"
//                          [ client index ][history]
bool didBangOnFrame         [TFMAXPLAYERS+1][3];
bool didHurtOnFrame         [TFMAXPLAYERS+1][3];
bool didBangThisFrame       [TFMAXPLAYERS+1];
bool didHurtThisFrame       [TFMAXPLAYERS+1];

// OnPlayerRunCmd vars      [ client index ][history][ang/pos/etc]
float clangles              [TFMAXPLAYERS+1][5][3];
int   clcmdnum              [TFMAXPLAYERS+1][5];
int   cltickcount           [TFMAXPLAYERS+1][5];
int   clbuttons             [TFMAXPLAYERS+1][5];
int   clmouse               [TFMAXPLAYERS+1]   [2];
// OnPlayerRunCmd misc
float engineTime            [TFMAXPLAYERS+1][3];
float clpos                 [TFMAXPLAYERS+1][2][3];

// Misc stuff per client    [ client index ][char size]
char SteamAuthFor           [TFMAXPLAYERS+1][MAX_AUTHID_LENGTH];

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
float avgPingFor            [TFMAXPLAYERS+1];
float rateFor               [TFMAXPLAYERS+1];
float ppsFor                [TFMAXPLAYERS+1];

// time since the last stutter/lag spike occurred per client
float timeSinceLagSpikeFor  [TFMAXPLAYERS+1];

/***** Misc other handles *****/

// Log file
File StacLogFile;

// hud sync handles for livefeed
Handle HudSyncRunCmd;
Handle HudSyncRunCmdMisc;
Handle HudSyncNetwork;

bool livefeedActive = false;

// Timer handles
Handle QueryTimer           [TFMAXPLAYERS+1];

// for checking if we just fixed a client's network settings so we don't double detect
bool justClamped        [TFMAXPLAYERS+1];

// tps etc
int tickspersec        [TFMAXPLAYERS+1];
// iterated tick num per client
int t                  [TFMAXPLAYERS+1];

float secTime          [TFMAXPLAYERS+1];

char os                [16];

// client has waited the full 60 seconds for their first convar check
bool hasWaitedForCvarCheck[TFMAXPLAYERS+1];


/*
TODO: point_worldtext entities

this will be an array, probably
int pointWorldTextEnts[TFMAXPLAYERS+1][5];

*/

// int pwt = 0;
// int pwt2 = 0;
// int pwt3 = 0;

/* stac memory stuff */
// signon state per client
int signonStateFor[TFMAXPLAYERS+1] = {-1, ...};


#define SIGNONSTATE_NONE        0   // no state yet, about to connect
#define SIGNONSTATE_CHALLENGE   1   // client challenging server, all OOB packets
#define SIGNONSTATE_CONNECTED   2   // client is connected to server, netchans ready
#define SIGNONSTATE_NEW         3   // just got serverinfo and string tables
#define SIGNONSTATE_PRESPAWN    4   // received signon buffers
#define SIGNONSTATE_SPAWN       5   // ready to receive entity packets
#define SIGNONSTATE_FULL        6   // we are fully connected, first non-delta packet received
#define SIGNONSTATE_CHANGELEVEL 7   // server is changing level, please wait


// Address Offset_PacketSize;
Address Offset_SignonState;
Address Offset_IClient_HACK;

GameData stac_gamedata;

Handle SDKCall_GetPlayerSlot;
Handle SDKCall_GetMsgHandler;
Handle SDKCall_GetTimeSinceLastReceived;

float   timeSinceLastRecvFor    [TFMAXPLAYERS+1];
int Offset_m_fFlags;


int PITCH   = 0;
int YAW     = 1;
int ROLL    = 2;
