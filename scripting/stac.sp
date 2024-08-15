// see the readme for more info:
// https://github.com/sapphonie/StAC-tf2/blob/master/README.md
// written by steph&

#pragma semicolon 1
#pragma newdecls required

// For json
#pragma dynamic 8192 * 4

#include <sourcemod>
#include <regex>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>

// hack for unrestricted maxplayers. sorry.
#if defined (MAXPLAYERS)
    #undef MAXPLAYERS
    #define MAXPLAYERS 101
#endif

#if !defined (AUTOLOAD_EXTENSIONS)
#define AUTOLOAD_EXTENSIONS
#endif
// REQUIRED extensions:
// SteamWorks for being able to make webrequests: https://forums.alliedmods.net/showthread.php?t=229556
// Get latest version from here: https://github.com/KyleSanderson/SteamWorks/releases
#include <SteamWorks>
// Connect for preventing SteamID spoofing: https://forums.alliedmods.net/showthread.php?t=162489
// Get latest version from here: https://builds.limetech.io/?project=connect
#include <connect>
// SourceTV Manager for reading currently recording demo information: https://forums.alliedmods.net/showthread.php?t=280402
// Get latest version from here or it will not work: https://github.com/peace-maker/sourcetvmanager/actions
#include <sourcetvmanager>
// Conplex for rcon hardening: https://forums.alliedmods.net/showthread.php?t=270962
// Get latest version from here: https://builds.limetech.io/?p=webcon
#include <conplex>
#undef AUTOLOAD_EXTENSIONS

// external incs
#include <achievements>
#include <morecolors>
#include <concolors>
#include <autoexecconfig>
#include <json>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#tryinclude <sourcebanspp>
#tryinclude <materialadmin>
#tryinclude <discord>
// #undef REQUIRE_EXTENSIONS

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION  "6.1.7-namechangelogic-beta"

#define UPDATE_URL      "https://raw.githubusercontent.com/sapphonie/StAC-tf2/master/updatefile.txt"

public Plugin myinfo =
{
    name             =  "Steph's AntiCheat [StAC]",
    author           =  "https://sappho.io",
    description      =  "AntiCheat plugin for TF2 written by https://sappho.io . Originally forked from IntegriTF2 by Miggy, RIP",
    version          =   PLUGIN_VERSION,
    url              =  "https://sappho.io"
}

/********** SUBPLUGINS **********/

// globals
#include "stac/stac_globals.sp"
// misc funcs used around the plugin
#include "stac/stac_stocks.sp"
// stac cvars
#include "stac/stac_cvars.sp"
// admin commands
#include "stac/stac_commands.sp"
// stuff that gets run on map change
#include "stac/stac_mapchange.sp"
// oprc
#include "stac/stac_onplayerruncmd.sp"
// client stuff
#include "stac/stac_client.sp"
// client cvar checks
#include "stac/stac_cvar_checks.sp"
// client netprop etc checks
#include "stac/stac_misc_checks.sp"
// stac livefeed
#include "stac/stac_livefeed.sp"
// gamedata / memory hacking bullshit
#include "stac/stac_memory.sp"
// if it ain't broke, don't fix it. jtanz has written a great backtrack patch.
#include "stac/jay_backtrack_patch.sp"

/********** PLUGIN LOAD & UNLOAD **********/


public void OnPluginStart()
{
    StopIncompatPlugins();
    StacLog("\n\n----> StAC version [%s] loaded\n", PLUGIN_VERSION);
    DoStACGamedata();

    if (!AddCommandListener(OnAllClientCommands))
    {
        SetFailState("Failed to AddCommandListener?");
    }

    LoadTranslations("common.phrases");
    LoadTranslations("stac.phrases.txt");

    checkOS();

    // updater
    if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }

    // reg admin commands
    RegConsoleCmd("sm_stac_checkall",   checkAdmin, "Force check all client convars (ALL CLIENTS) for anticheat stuff");
    RegConsoleCmd("sm_stac_detections", checkAdmin, "Show all current detections on all connected clients");
    RegConsoleCmd("sm_stac_getauth",    checkAdmin, "Print StAC's cached auth for a client");
    RegConsoleCmd("sm_stac_livefeed",   checkAdmin, "Show live feed (debug info etc) for a client. This gets printed to SourceTV too, if available.");

    // steamidRegex = CompileRegex("^STEAM_[0-5]:[0-1]:[0-9]+$");

    // grab round start events for calculating tps
    HookEvent("teamplay_round_start", eRoundStart);
    // grab player spawns
    HookEvent("player_spawn", ePlayerSpawned);
    // hook real player disconnects
    HookEvent("player_connect", ePlayerConnect);

    // hook real player disconnects
    HookEvent("player_disconnect", ePlayerDisconnect);
    // grab player cheevs
    HookEvent("achievement_earned", ePlayerAchievement, EventHookMode_Post);

    // hook sv_cheats so we can instantly unload if cheats get turned on
    HookConVarChange(FindConVar("sv_cheats"), GenericCvarChanged);
    // hook host_timescale so we don't ban ppl if it's not default
    // HookConVarChange(FindConVar("host_timescale"), GenericCvarChanged);
    // hook wait command status for tbot
    HookConVarChange(FindConVar("sv_allow_wait_command"), GenericCvarChanged);

    // Create Stac ConVars for adjusting settings
    initCvars();

    EngineSanityChecks();

    // redo all client based stuff on plugin reload
    for (int cl = 1; cl <= MaxClients; cl++)
    {
        if (IsValidClientOrBot(cl))
        {
            // Force network settings
            OnClientSettingsChanged(cl);
            OnClientPutInServer(cl);
        }
    }

    // hook bullets fired for aimsnap and triggerbot
    AddTempEntHook("Fire Bullets", Hook_TEFireBullets);

    // create global timer running every couple jiffys for getting all clients' network info
    // This immediately populates the arrays instead of waiting a timer tick
    CreateTimer(0.1, Timer_GetNetInfo, _, TIMER_REPEAT);

    SetUpIPConnectLeakyBucket();


    Timer_GetNetInfo(null);

    // init hud sync stuff for livefeed
    HudSyncRunCmd       = CreateHudSynchronizer();
    HudSyncRunCmdMisc   = CreateHudSynchronizer();
    HudSyncNetwork      = CreateHudSynchronizer();

    // set up our array we'll use for checking cvars
    InitCvarArray();

    // jaypatch
    OnPluginStart_jaypatch();
}


public void OnPluginEnd()
{
    // do this to make sure we don't try and fail to send discord messages if the server is restarting
    // we need to use OnLibraryLoad/Unload eventually...
    CheckNatives();

    StacLog("\n\n----> StAC version [%s] unloaded\n", PLUGIN_VERSION);

    MC_PrintToChatAll("{hotpink}StAC{white} version [%s] unloaded!!! If this wasn't intentional, something nefarious is afoot!", PLUGIN_VERSION);
    MC_PrintToChatAll("{hotpink}StAC{white} version [%s] unloaded!!! If this wasn't intentional, something nefarious is afoot!", PLUGIN_VERSION);
    MC_PrintToChatAll("{hotpink}StAC{white} version [%s] unloaded!!! If this wasn't intentional, something nefarious is afoot!", PLUGIN_VERSION);

    StacNotify(0, "StAC was just unloaded!!! Was this intentional??");

    NukeTimers();
    OnMapEnd();
}


/********** ONGAMEFRAME **********/

// monitor server tickrate
public void OnGameFrame()
{
    servertick = GetGameTickCount();

    calcTPSfor(0);

    // LIVEFEED
    if (livefeedActive)
    {
        for (int cl = 1; cl <= MaxClients; cl++)
        {
            if (IsValidClient(cl))
            {
                if (LiveFeedOn[cl])
                {
                    LiveFeed_PlayerCmd(GetClientUserId(cl));
                }
            }
        }
    }

    if (GetEngineTime() - 15.0 < timeSinceMapStart)
    {
        return;
    }

    if (tickspersec[0] < (tps / 2.0))
    {
        // don't bother printing again lol
        if (GetEngineTime() - ServerLagWaitLength < timeSinceLagSpikeFor[0])
        {
            // silently refresh this var
            timeSinceLagSpikeFor[0] = GetEngineTime();
            return;
        }
        timeSinceLagSpikeFor[0] = GetEngineTime();

        StacLog("Server framerate stuttered. Expected: ~%.1f, got %i.\nDisabling OnPlayerRunCmd checks for %.2f seconds.", tps, tickspersec[0], ServerLagWaitLength);
        if (stac_debug.BoolValue)
        {
            PrintToImportant("{hotpink}[StAC]{white} Server framerate stuttered. Expected: {palegreen}~%.1f{white}, got {fullred}%i{white}.\nDisabling OnPlayerRunCmd checks for %f seconds.",
            tps, tickspersec[0], ServerLagWaitLength);
        }
    }
}

void StopIncompatPlugins()
{
    // https://forums.alliedmods.net/showpost.php?p=1744525&postcount=6
    char plName[128];

    // Mama mia
    Handle plugini = GetPluginIterator();
    while (MorePlugins(plugini))
    {
        Handle thisPlug = ReadPlugin(plugini);
        GetPluginInfo(thisPlug, PlInfo_Name, plName, sizeof(plName));
        // Compile it out if you want, I don't care. If you do this shit you're cringe and should feel bad about it.
        // I will not provide any support for you or your annoying server if you do this.
        if
        (
               StrContains(plName, "Simple block",  false)  != -1 /* SM Plugins blocker */
            || StrContains(plName, "Block SM",      false)  != -1 /* wildcard for blocking sm plugins */
        )
        {
            delete plugini;
            SetFailState("[StAC] Refusing to load with malicious plugins.");
            return;
        }
        else if
        (
               StrContains(plName, "Backtrack Patch",       false)  != -1 /* JTanz backtrack fix */
            || StrContains(plName, "Backtrack Elimination", false)  != -1 /* Shavit backtrack fix */
        )
        {
            delete plugini;
            SetFailState("[StAC] Refusing to load with other backtrack fix plugins. StAC contains its own backtrack patch built in, written by J-Tanzanite, author of LilAC. Uninstall them and try again.");
            return;
        }
        /*
            Todo, maybe;
            Scan all SM plugin memory for instances of "rcon" inside plugins to maybe prevent malicious plugins?
            Might be unfeasible and get too many false positives.
        */
    }
    delete plugini;

    if
    (
            LibraryExists("smac") 
        &&  GetFeatureStatus(FeatureType_Capability, "SMAC_Ban"))
    {
        SetFailState("[StAC] Refusing to load with SMAC. SMAC is outdated and is actively harmful to server performance as well as StAC's operation. Uninstall SMAC and try again.");
    }
}


void EngineSanityChecks()
{
    // check if tf2, unload if not
    // strip when sdk13 support
    if (GetEngineVersion() != Engine_TF2)
    {
        SetFailState("[StAC] This plugin is only supported for TF2! Aborting!");
    }

    if ( MaxClients > 33 || GetMaxHumanPlayers() > 33 )
    {
        highPlayerServer = true;
        StacLog("Running StAC with high maxplayers. Things will break!");
    }
}
