// see the readme for more info:
// https://github.com/sapphonie/StAC-tf2/blob/master/README.md
// written by steph&

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
#tryinclude <sourcebanspp>
#tryinclude <materialadmin>
#tryinclude <discord>
#undef REQUIRE_EXTENSIONS
#tryinclude <steamtools>
#tryinclude <SteamWorks>

// we have to re pragma because sourcemod sucks lol
#pragma newdecls required

#define PLUGIN_VERSION  "5.1.1"

#define UPDATE_URL      "https://raw.githubusercontent.com/sapphonie/StAC-tf2/master/updatefile.txt"

public Plugin myinfo =
{
    name             =  "Steph's AntiCheat (StAC)",
    author           =  "steph&nie",
    description      =  "TF2 AntiCheat plugin written by Stephanie. Originally forked from IntegriTF2 by Miggy (RIP)",
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
// server repeating timers
#include "stac/stac_misc_timers.sp"
// stac livefeed
#include "stac/stac_livefeed.sp"
// for kicking unauthorized clients
#include "stac/stac_steamauth.sp"
// if it ain't broke, don't fix it. jtanz has written a great backtrack patch.
#include "stac/jay_backtrack_patch.sp"

/********** PLUGIN LOAD & UNLOAD **********/

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
    LoadTranslations("stac.phrases.txt");

    // updater
    if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }

    // reg admin commands
    // TODO: make these invisible for non admins
    RegConsoleCmd("sm_stac_checkall",   checkAdmin, "Force check all client convars (ALL CLIENTS) for anticheat stuff");
    RegConsoleCmd("sm_stac_detections", checkAdmin, "Show all current detections on all connected clients");
    RegConsoleCmd("sm_stac_getauth",    checkAdmin, "Print StAC's cached auth for a client");
    RegConsoleCmd("sm_stac_livefeed",   checkAdmin, "Show live feed (debug info etc) for a client. This gets printed to SourceTV if available.");


    // setup regex - "Recording to ".*""
    demonameRegex       = CompileRegex("Recording to \".*\"");
    demonameRegexFINAL  = CompileRegex("\".*\"");
    publicIPRegex       = CompileRegex("public ip: \\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b");
    IPRegex             = CompileRegex("\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b");

    // grab round start events for calculating tps
    HookEvent("teamplay_round_start", eRoundStart);
    // grab player spawns
    HookEvent("player_spawn", ePlayerSpawned);
    // hook real player disconnects
    HookEvent("player_disconnect", ePlayerDisconnect);
    // grab player name changes
    HookEvent("player_changename", ePlayerChangedName, EventHookMode_Pre);

    // hook sv_cheats so we can instantly unload if cheats get turned on
    HookConVarChange(FindConVar("sv_cheats"), GenericCvarChanged);
    // hook wait command status for tbot
    HookConVarChange(FindConVar("sv_allow_wait_command"), GenericCvarChanged);
    // hook these for pingmasking stuff
    HookConVarChange(FindConVar("sv_mincmdrate"), UpdateRates);
    HookConVarChange(FindConVar("sv_maxcmdrate"), UpdateRates);
    HookConVarChange(FindConVar("sv_minupdaterate"), UpdateRates);
    HookConVarChange(FindConVar("sv_maxupdaterate"), UpdateRates);

    // make sure we get the actual values on plugin load in our plugin vars
    UpdateRates(null, "", "");

    // Create Stac ConVars for adjusting settings
    initCvars();

    // redo all client based stuff on plugin reload
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClientOrBot(Cl))
        {
            OnClientPutInServer(Cl);
        }
    }

    // hook bullets fired for aimsnap and triggerbot
    AddTempEntHook("Fire Bullets", Hook_TEFireBullets);

    // create global timer running every half second for getting all clients' network info
    CreateTimer(0.5, Timer_GetNetInfo, _, TIMER_REPEAT);

    // init hud sync stuff for livefeed
    HudSyncRunCmd       = CreateHudSynchronizer();
    HudSyncRunCmdMisc   = CreateHudSynchronizer();
    HudSyncNetwork      = CreateHudSynchronizer();

    // set up our array we'll use for checking cvars
    InitCvarArray();

    StacLog("[StAC] Plugin vers. ---- %s ---- loaded", PLUGIN_VERSION);

    OnPluginStart_jaypatch();
}

public void OnPluginEnd()
{
    StacLog("[StAC] Plugin vers. ---- %s ---- unloaded", PLUGIN_VERSION);
    NukeTimers();
    OnMapEnd();
}


/********** ONGAMEFRAME **********/

// monitor server tickrate
public void OnGameFrame()
{
    // LIVEFEED
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

    calcTPSfor(0);

    if (GetEngineTime() - 15.0 < timeSinceMapStart)
    {
        return;
    }
    if (isDefaultTickrate())
    {
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

            StacLog("[StAC] Server framerate stuttered. Expected: ~%.1f, got %i.\nDisabling OnPlayerRunCmd checks for %.2f seconds.", tps, tickspersec[0], ServerLagWaitLength);
            if (DEBUG)
            {
                PrintToImportant("{hotpink}[StAC]{white} Server framerate stuttered. Expected: {palegreen}~%.1f{white}, got {fullred}%i{white}.\nDisabling OnPlayerRunCmd checks for %f seconds.",
                tps, tickspersec[0], ServerLagWaitLength);
            }
        }
    }
}
