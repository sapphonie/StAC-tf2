// see the readme for more info:
// https://github.com/stephanieLGBT/StAC-tf2/blob/master/README.md
// i love my girlfriends
#pragma semicolon 1

#include <sourcemod>
#include <color_literals>
#include <regex>
#include <entity_prop_stocks>
#include <sdktools>
#include <tf2_stocks>
#undef REQUIRE_PLUGIN
#include <updater>
#include <sourcebanspp>

#define PLUGIN_VERSION  "2.2.3"
#define UPDATE_URL      "https://raw.githubusercontent.com/stephanieLGBT/StAC-tf2/master/updatefile.txt"

public Plugin myinfo =
{
    name             =  "Steph's AntiCheat (StAC)",
    author           =  "stephanie",
    description      =  "Anticheat plugin [tf2 only] written by Stephanie. Originally forked from IntegriTF2 by Miggy",
    version          =   PLUGIN_VERSION,
    url              =  "https://steph.anie.dev/"
}

Handle g_hQueryTimer[MAXPLAYERS+1];
Handle g_hTriggerTimedStuffTimer;
int turnTimes[MAXPLAYERS+1];
int fovDesired[MAXPLAYERS+1];
int fakeAngDetects[MAXPLAYERS+1];
int pSilentDetects[MAXPLAYERS+1];
int aimSnapDetects[MAXPLAYERS+1];
//float sensFor[MAXPLAYERS+1] = -1.0;
float timeSinceSpawn[MAXPLAYERS+1];
float timeSinceTaunt[MAXPLAYERS+1];
float timeSinceTeled[MAXPLAYERS+1];
//float maxSensToCheck = 4.0;
float tickinterv;
float tps;
float maxAllowedTurnSecs = 1.0;
int maxPsilentDetections = 15;
float minRandCheckVal = 60.0;
float maxRandCheckVal = 300.0;
float angCur[MAXPLAYERS+1][2];
float angPrev1[MAXPLAYERS+1][2];
float angPrev2[MAXPLAYERS+1][2];

bool isHumiliation;
bool SOURCEBANS;
bool DEBUG = true;

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
    RegAdminCmd("sm_showdetections", ShowDetections, ADMFLAG_ROOT, "Show all current detections on all connected clients");
    // RegAdminCmd("sm_forcecheck", ForceCheck, ADMFLAG_ROOT, "Force check all client convars (SINGLE CLIENT) for anticheat stuff");
    // get tick interval - some modded tf2 servers run at >66.7 tick!
    tickinterv = GetTickInterval();
    // don't accidentally ban ppl during humiliation for forced taunt cam! (may be unneeded?)
    HookEvent("teamplay_round_start", Event_RoundStart);
    HookEvent("teamplay_round_win", Event_RoundWin);
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
    CreateTimer(5.0, checkEveryone);
    // todo: Create ConVars for adjusting settings
    LogMessage("[StAC] Plugin loaded");
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

public Action ShowDetections(int client, int args)
{
    LogMessage("[StAC] == CURRENT DETECTIONS == ");
    for (int Cl = 0; Cl < MaxClients + 1; Cl++)
    {
        if (IsValidClient(Cl))
        {
            if (turnTimes[Cl] >= 1 || pSilentDetects[Cl] >= 1 || fakeAngDetects[Cl] >= 1)
            {
                LogMessage("Detections for %L", Cl);
                if (turnTimes[Cl] >= 1)
                {
                    LogMessage("- %i turnTimes for %N", turnTimes[Cl], Cl);
                }
                if (pSilentDetects[Cl] >= 1)
                {
                    LogMessage("- %i pSilentDetects for %N", pSilentDetects[Cl], Cl);
                }
                if (fakeAngDetects[Cl] >= 1)
                {
                    LogMessage("- %i fakeAngDetects for %N", fakeAngDetects[Cl], Cl);
                }
            }
        }
    }
    LogMessage("[StAC] == END DETECTIONS == ");
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
}

public Action ePlayerSpawned(Handle event, char[] name, bool dontBroadcast)
{
    int Cl = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsValidClient(Cl))
    {
        timeSinceSpawn[Cl] = GetTickedTime();
        //PrintToChatAll("spawn time for cl %N = %f", Cl, timeSinceSpawn[Cl]);
    }
}

public Action ePlayerTeled(Handle event, char[] name, bool dontBroadcast)
{
    int Cl = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsValidClient(Cl))
    {
        timeSinceTeled[Cl] = GetTickedTime();
        //PrintToChatAll("tele time for cl %N = %f", Cl, timeSinceTeled[Cl]);
    }
}

public TF2_OnConditionRemoved(int Cl, TFCond condition)
{
    if (IsValidClient(Cl))
    {
        if (condition == TFCond_Taunting)
        {
            timeSinceTaunt[Cl] = GetTickedTime();
            //PrintToChatAll("taunt time for cl %N = %f", Cl, timeSinceTaunt[Cl]);
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
}

public OnClientPostAdminCheck(Cl)
{
    if (IsValidClient(Cl))
    {
        int userid = GetClientUserId(Cl);
        // TODO - check if the ip is a proxy/alt/vpn/whatever
        // char ip[17], city[45], region[45], country_name[45], country_code[3], country_code3[4];
        // GetClientIP(Cl, ip, sizeof(ip));
        // GeoipGetRecord(ip, city, region, country_name, country_code, country_code3);
        // if  (
        //         StrContains(country_name, "Anonymous", false) != -1 ||
        //         StrContains(country_name, "Proxy", false) != -1
        //     )
        // {
        //     PrintColoredChatAll(Cl, COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... "Player %N is likely using a proxy!", Cl);
        // }
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
    // make sure client is real and not in spectate
    if (IsValidClient(Cl) && IsClientPlaying(Cl))
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
                angCur[Cl][0] == angPrev2[Cl][0] &&
                angCur[Cl][1] == angPrev2[Cl][1]
            )
            &&
            // BUT the 1st previous (in between) angle doesnt?
            (

                angPrev1[Cl][0] != angCur[Cl][0]   &&
                angPrev1[Cl][1] != angCur[Cl][0]   &&
                angPrev1[Cl][0] != angPrev2[Cl][0] &&
                angPrev1[Cl][1] != angPrev2[Cl][1]
            )
            &&
            // and make sure we dont get any fake detections on startup (might not really be needed? but just in case)
            // also ignores weird angle resets in mge / dm
            (
                angCur[Cl][0]   != 0.000000 &&
                angCur[Cl][1]   != 0.000000 &&
                angPrev1[Cl][0] != 0.000000 &&
                angPrev1[Cl][1] != 0.000000 &&
                angPrev2[Cl][0] != 0.000000 &&
                angPrev2[Cl][1] != 0.000000
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
                // avoid as many false positives as we can, all of these events can fuck up angles and lead to wrong detections
                float tickdTime = GetTickedTime();
                // THESE ARE JUST IN CASE
                // ignore 0.5 seconds after respawning
                if
                (
                    (
                        tickdTime - 0.1 > timeSinceSpawn[Cl]
                    )
                    &&
                    // and 0.5 seconds after taunting
                    (
                        tickdTime - 0.1 > timeSinceTaunt[Cl]
                    )
                    &&
                    // and 0.5 seconds after teleporting
                    (
                       tickdTime - 0.1 > timeSinceTeled[Cl]
                    )
                )
                {
                pSilentDetects[Cl]++;
                // have this detection expire in 20 minutes
                CreateTimer(1200.0, Timer_decr_pSilent, userid);
                // print a bunch of bullshit
                // print to admins only up to the 19th snap
                // i know this is ugly. ill mess with it later.
                if (pSilentDetects[Cl] <= (maxPsilentDetections - 1))
                {
                    PrintColoredChatToAdmins(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N is possibly using " ... COLOR_MEDIUMPURPLE ... "pSilentAim" ... COLOR_WHITE ..." or " ... COLOR_MEDIUMPURPLE     ... "NoRecoil"  ... COLOR_WHITE ... ". Detections so far: " ... COLOR_PALEGREEN ... "%i", Cl, pSilentDetects[Cl]);
                    PrintColoredChatToAdmins("[StAC] pSilent detection on %N: curang angles: x %f y %f", Cl, angCur[Cl][0], angCur[Cl][1]);
                    PrintColoredChatToAdmins("[StAC] pSilent detection on %N: prev1  angles: x %f y %f", Cl, angPrev1[Cl][0], angPrev1[Cl][1]);
                    PrintColoredChatToAdmins("[StAC] pSilent detection on %N: prev2  angles: x %f y %f", Cl, angPrev2[Cl][0], angPrev2[Cl][1]);
                    CPrintToSTV(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N is possibly using " ... COLOR_MEDIUMPURPLE ... "pSilentAim" ... COLOR_WHITE ..." or " ... COLOR_MEDIUMPURPLE     ... "NoRecoil"  ... COLOR_WHITE ... ". Detections so far: " ... COLOR_PALEGREEN ... "%i", Cl, pSilentDetects[Cl]);
                    CPrintToSTV("[StAC] pSilent detection on %N: curang angles: x %f y %f", Cl, angCur[Cl][0], angCur[Cl][1]);
                    CPrintToSTV("[StAC] pSilent detection on %N: prev1  angles: x %f y %f", Cl, angPrev1[Cl][0], angPrev1[Cl][1]);
                    CPrintToSTV("[StAC] pSilent detection on %N: prev2  angles: x %f y %f", Cl, angPrev2[Cl][0], angPrev2[Cl][1]);
                    LogMessage("[StAC] Player %N is possibly using pSilent or NoRecoil! Detections so far: %i.", Cl, pSilentDetects[Cl]);
                    LogMessage("[StAC] pSilent detection on %N: curang angles: x %f y %f", Cl, angCur[Cl][0], angCur[Cl][1]);
                    LogMessage("[StAC] pSilent detection on %N: prev1  angles: x %f y %f", Cl, angPrev1[Cl][0], angPrev1[Cl][1]);
                    LogMessage("[StAC] pSilent detection on %N: prev2  angles: x %f y %f", Cl, angPrev2[Cl][0], angPrev2[Cl][1]);
                }
                // BAN USER if they trigger too many detections
                else if (pSilentDetects[Cl] >= maxPsilentDetections)
                {
                    char KickMsg[256];
                    Format(KickMsg, sizeof(KickMsg), "Player %N was using pSilentAim or NoRecoil. Total detections: %i. Banned from server", Cl, pSilentDetects[Cl]);
                    BanUser(userid, KickMsg);
                    PrintColoredChatAll("[StAC] pSilent detection on %N: curang angles: x %f y %f", Cl, angCur[Cl][0], angCur[Cl][1]);
                    PrintColoredChatAll("[StAC] pSilent detection on %N: prev1  angles: x %f y %f", Cl, angPrev1[Cl][0], angPrev1[Cl][1]);
                    PrintColoredChatAll("[StAC] pSilent detection on %N: prev2  angles: x %f y %f", Cl, angPrev2[Cl][0], angPrev2[Cl][1]);
                    PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using " ... COLOR_MEDIUMPURPLE ... "pSilentAim" ... COLOR_WHITE ..." or " ... COLOR_MEDIUMPURPLE ... "NoRecoil"  ... COLOR_WHITE ... ". Total detections: " ... COLOR_MEDIUMPURPLE ... "%i" ... COLOR_WHITE ... ". " ... COLOR_PALEGREEN ... "BANNED from server", Cl, pSilentDetects[Cl]);
                    LogMessage("[StAC] Player %N was banned for using pSilent or NoRecoil! Total detections: %i.", Cl, pSilentDetects[Cl]);
                    LogMessage("[StAC] pSilent detection on %N: curang angles: x %f y %f", Cl, angCur[Cl][0], angCur[Cl][1]);
                    LogMessage("[StAC] pSilent detection on %N: prev1  angles: x %f y %f", Cl, angPrev1[Cl][0], angPrev1[Cl][1]);
                    LogMessage("[StAC] pSilent detection on %N: prev2  angles: x %f y %f", Cl, angPrev2[Cl][0], angPrev2[Cl][1]);
                    }
                }
            }
        }
        /*
            EYE ANGLES TEST
            a typical "angle clamper" will look something like this (stolen from unknowncheats)
            if (pCmd->viewangles.x > 89.0f)
            {
                pCmd->viewangles.x = 89.0f;
            }
            if (pCmd->viewangles.x < -89.0f)
            {
                pCmd->viewangles.x = -89.0f;
            }
            if (pCmd->viewangles.y > 180.0f)
            {
                pCmd->viewangles.y = 180.0f;
            }
            if (pCmd->viewangles.y < -180.0f)
            {
                pCmd->viewangles.y = -180.0f;
            }
            if clients are outside of allowed angles while they are not in spec and on a map camera we should log it!
        */
        if  (
                (
                    angles[0] < -89.0   || // x angles SHOULD BE clamped between -89.0...
                    angles[0] > 89.0    || // ...and 89.0.
                    angles[1] < -180.0  || // y angles SHOULD BE clamped between -180.0...
                    angles[1] > 180.0      // ...and 180.0.
                )
            )
        {
            fakeAngDetects[Cl]++;
            // have this detection expire in 20 minutes
            // might remove this depending on performance
            CreateTimer(1200.0, Timer_decrFakeAngs, userid);
            PrintColoredChatToAdmins(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N has " ... COLOR_MEDIUMPURPLE ... "invalid eye angles" ... COLOR_WHITE ..."! Current angles: " ... COLOR_MEDIUMPURPLE     ... "%i %i %i"  ... COLOR_WHITE ... ". Detections so far: " ... COLOR_PALEGREEN ... "%i", Cl, RoundToNearest(angles[0]), RoundToNearest(angles[1]), RoundToNearest(angles[2]), fakeAngDetects[Cl]);
            CPrintToSTV(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N has " ... COLOR_MEDIUMPURPLE ... "invalid eye angles" ... COLOR_WHITE ..."! Current angles: " ... COLOR_MEDIUMPURPLE     ... "%i %i %i"  ... COLOR_WHITE ... ". Detections so far: " ... COLOR_PALEGREEN ... "%i", Cl, RoundToNearest(angles[0]), RoundToNearest(angles[1]), RoundToNearest(angles[2]), fakeAngDetects[Cl]);
            LogMessage("[StAC] Player %N has invalid eye angles! Current angles: %i %i %i. Detections so far: %i", Cl, RoundToNearest(angles[0]), RoundToNearest(angles[1]), RoundToNearest(angles[2]), fakeAngDetects[Cl]);
        }
        /*
            TURN BIND TEST
        */
        if (buttons & IN_LEFT || buttons & IN_RIGHT)
        {
            turnTimes[Cl]++;
            float turnSec = turnTimes[Cl] * tickinterv;
            LogMessage("[StAC] Detected turn bind on player [%L] for [%f] seconds", Cl, turnSec);
            if (turnSec < maxAllowedTurnSecs)
            {
                PrintColoredChat(Cl, COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Turn binds and spin binds are not allowed on this server. If you  continue to use them you will be autokicked!");
                PrintColoredChatToAdmins(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Client %N used a turn bind!", Cl);
                CPrintToSTV(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Client %N used a turn bind!", Cl);
            }
            else if (turnSec >= maxAllowedTurnSecs)
            {
                KickClient(Cl, "Usage of turn binds or spin binds is not allowed. Autokicked");
                LogMessage("[StAC] Player %N was using turn binds! Kicked from server.", Cl);
                PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using turn binds! " ... COLOR_PALEGREEN ... "Kicked from server.", Cl);
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
                &&
                // ignore 5 seconds after respawning
                (
                    GetTickedTime() - 5.0 > timeSinceSpawn[Cl]
                )
                &&
                // and 1 second after taunting
                (
                    GetTickedTime() - 1.0 > timeSinceTaunt[Cl]
                )
                &&
                // and for 5 seconds after teleporting
                (
                   GetTickedTime() - 1.0 > timeSinceTeled[Cl]
                )
            )
        {
            aimSnapDetects[Cl]++;
            PrintToChatAll("aimSnapDetects = %i", aimSnapDetects[Cl]);
            PrintColoredChatAll("[StAC] snap %f d on %N: curang angles: x %f y %f", (FloatAbs(angCur[Cl][0] - angPrev1[Cl][0])), Cl, angCur[Cl][0], angCur[     Cl][1]);
            PrintColoredChatAll("[StAC] snap      on %N: prev1  angles: x %f y %f", Cl, angPrev1[Cl][0], angPrev1[Cl][1]);
            PrintColoredChatAll("[StAC] snap      on %N: prev2  angles: x %f y %f", Cl, angPrev2[Cl][0], angPrev2[Cl][1]);
            PrintColoredChatAll("[StAC] mouse movement at time of snap: mouse x %i, y %i",   abs(mouse[0]), abs(mouse[1]));
        }
        */
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

public ConVarCheck(QueryCookie cookie, int Cl, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
    int userid = GetClientUserId(Cl);

    if (!IsValidClient(Cl))
    {
        return;
    }
    // log something about cvar errors xcept for cheat only cvars
    if (result != ConVarQuery_Okay && !StrEqual(cvarName, "cat"))
    {
        PrintColoredChatToAdmins(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Could not query CVar %s on Player %N", cvarName, Cl);
        CPrintToSTV(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Could not query CVar %s on Player %N", Cl);
        LogMessage("[StAC] Could not query CVar %s on Player %N", cvarName, Cl);
    }
    if (StrEqual(cvarName, "cat") && result == ConVarQuery_Okay)
    {
        PrintToChatAll("Client %N is using cathook! I didn't bother to put anything to ban them here yet because I'm lazy!", Cl);
    }
    // cl_interp
    if (StrEqual(cvarName, "cl_interp"))
    {
        // cl_interp needs to be at or BELOW tf2's default settings
        if (StringToFloat(cvarValue) > 0.100000)
        {
            KickClient(Cl, "CVar %s = %s, outside reasonable bounds. Change it to .1 at most", cvarName, cvarValue);
            LogMessage("[StAC] Player %N was using CVar %s = %s, indicating interp explotation. Kicked from server.", Cl, cvarName, cvarValue);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar " ... COLOR_MEDIUMPURPLE ... "%s" ... COLOR_WHITE ..." = " ... COLOR_MEDIUMPURPLE ... "%s"  ... COLOR_WHITE ... ", indicating interp explotation. " ... COLOR_PALEGREEN ... "Kicked from server.", Cl, cvarName, cvarValue);
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
    // cl_cmdrate
    else if (StrEqual(cvarName, "cl_cmdrate"))
    {
        if (!cvarValue[0])
        {
            LogMessage("[StAC] Null string returned as cvar result when querying cvar %s on %N", cvarName, Cl);
            PrintColoredChatToAdmins(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Null string returned as cvar result when querying cvar %s on %N", cvarName, Cl);
            CPrintToSTV(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Null string returned as cvar result when querying cvar %s on %N", cvarName, Cl);
        }
        // cl_cmdrate needs to be above 60 AND not have any non numerical chars (xcept the . sign if its a float) in it because otherwise player ping gets messed up on the scoreboard
        else if (SimpleRegexMatch(cvarValue, "^\\d*\\.?\\d*$") <= 0)
        {
            KickClient(Cl, "CVar %s = %s, indicating pingmasking. Remove any non numeric characters", cvarName, cvarValue);
            LogMessage("[StAC] Player %N is using CVar %s = %s, ping-masking! Kicked from server", Cl, cvarName, cvarValue);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar " ... COLOR_MEDIUMPURPLE ... "%s" ... COLOR_WHITE ..." = " ... COLOR_MEDIUMPURPLE ... "%s"  ... COLOR_WHITE ... ", indicating ping masking. " ... COLOR_PALEGREEN ... "Kicked from server.", Cl, cvarName, cvarValue);
        }
    }
    // there exists an exploit involving updaterate and lerp which allows you to have literally whatever interp you want. the "m_fLerpTime" netprop DOES NOT CHANGE so we have to check the actual cvar.
    else if (StrEqual(cvarName, "cl_updaterate"))
    {
        // don't bother checking if tickrate isnt default
        if (tps < 70.0 && tps > 60.0)
        {
            if ((StringToFloat(cvarValue) < 20.0 || StringToFloat(cvarValue) > 128.0))
            {
                KickClient(Cl, "CVar %s = %s, indicating possible lerp exploitation. Change it to between 20 and 128. Recommended value: 66", cvarName, cvarValue);
                LogMessage("[StAC] Player %N is using CVar %s = %s, indicating lerp exploitation! Kicked from server", Cl, cvarName, cvarValue);
                PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar " ... COLOR_MEDIUMPURPLE ... "%s" ... COLOR_WHITE ..." = " ... COLOR_MEDIUMPURPLE ... "%s"  ... COLOR_WHITE ... ", indicating lerp exploitation. " ... COLOR_PALEGREEN ... "Kicked from server.", Cl, cvarName, cvarValue);
            }
        }
    }
    // cl_interpolate (hidden cvar! should NEVER not be 1.0)
    else if (StrEqual(cvarName, "cl_interpolate"))
    {
        if (StringToFloat(cvarValue) != 1.0)
        {
            char KickMsg[256];
            Format(KickMsg, sizeof(KickMsg), "CVar %s was %s, indicating NOLERP! Banned from server", cvarName, cvarValue);
            BanUser(userid, KickMsg);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N is using CVar %s = %s, indicating NOLERP!" ... COLOR_PALEGREEN ... "BANNED from server.", Cl, cvarName, cvarValue);
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
            LogMessage("[StAC] Player %N is using CVar %s = %s, indicating WALLHACKING! BANNED from server!", Cl, cvarName, cvarValue);
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
            LogMessage("[StAC] Player %N is using CVar %s = %s, indicating FOV HACKING! BANNED from server!", Cl, cvarName, cvarValue);
        }
        else if (StringToFloat(cvarValue) < 90.000)
        {
            PrintColoredChatToAdmins(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N has an FOV below 90! FOV: %f", Cl, StringToFloat(cvarValue));
        }
    }
    // cam_idealyaw
    // yet another third person check!
    else if (StrEqual(cvarName, "cam_idealyaw"))
    {
        if (StringToFloat(cvarValue) != 0.0)
        {
            char KickMsg[256];
            Format(KickMsg, sizeof(KickMsg), "CVar %s was %s, indicating cheating with THIRD PERSON! Banned from server", cvarName, cvarValue);
            BanUser(userid, KickMsg);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar " ... COLOR_MEDIUMPURPLE ... "%s" ... COLOR_WHITE ..." = " ... COLOR_MEDIUMPURPLE ... "%s"  ... COLOR_WHITE ... ", indicating cheating with THIRD PERSON!" ... COLOR_PALEGREEN ... "BANNED from server.", Cl, cvarName, cvarValue);
            LogMessage("[StAC] Player %N was using CVar %s = %s, indicating cheating with THIRD PERSON! BANNED from server!", Cl, cvarName, cvarValue);
        }
    }
//    else if (StrEqual(cvarName, "sensitivity"))
//    {
//        sensFor[Cl] = StringToFloat(cvarValue);
//        //PrintToChatAll("Client %N's sens is %f", Cl, sensFor[Cl]);
//        if (StringToFloat(cvarValue) < 0.000100)
//        // do somethin about it!
//        {
//        //
//        }
//    }
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
            StrContains(sArgs, "\n", false) != -1 ||
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
            LogMessage("[StAC] entprop m_fLerpTime of %N is %f", Cl, GetEntPropFloat(Cl, Prop_Data, "m_fLerpTime"));
            // log entprop values
            LogMessage("[StAC] entprop m_nForceTauntCam of %N is %i", Cl, GetEntProp(Cl, Prop_Send, "m_nForceTauntCam"));
            LogMessage("[StAC] entprop m_iDefaultFOV of %N is %i", Cl, GetEntProp(Cl, Prop_Send, "m_iDefaultFOV"));
            LogMessage("[StAC] entprop m_iFOV of %N is %i", Cl, GetEntProp(Cl, Prop_Send, "m_iFOV"));
            LogMessage("[StAC] entprop m_iFOVStart of %N is %i", Cl, GetEntProp(Cl, Prop_Send, "m_iFOVStart"));
            PrintToConsoleAllAdmins("[StAC] entprop m_nForceTauntCam of %N is %i", Cl, GetEntProp(Cl, Prop_Send, "m_nForceTauntCam"));
            PrintToConsoleAllAdmins("[StAC] entprop m_iDefaultFOV of %N is %i", Cl, GetEntProp(Cl, Prop_Send, "m_iDefaultFOV"));
            PrintToConsoleAllAdmins("[StAC] entprop m_iFOV of %N is %i", Cl, GetEntProp(Cl, Prop_Send, "m_iFOV"));
            PrintToConsoleAllAdmins("[StAC] entprop m_iFOVStart of %N is %i", Cl, GetEntProp(Cl, Prop_Send, "m_iFOVStart"));
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
                    iFov > 90 ||
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
        // lerp check (BROKEN RN)
        // don't bother on non default tick servers until i get around to Doing Math to make it work on other tickrates
        if (tps < 70.0 && tps > 60.0)
        {
            float lerp = GetEntPropFloat(Cl, Prop_Data, "m_fLerpTime");
            if (lerp > 0.1)
            {
                KickClient(Cl, "[StAC] Your interp was %f ms, outside reasonable bounds! Kicked from server", lerp * 1000);
                LogMessage("[StAC] Player %N Netprop 'm_fLerpTime' was %f, outside reasonable bounds!", Cl, lerp);
                PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N's " ... COLOR_MEDIUMPURPLE ... "interp" ... COLOR_WHITE ..." was " ... COLOR_MEDIUMPURPLE ... "%f"  ... COLOR_WHITE ... ", indicating interp explotation. " ... COLOR_PALEGREEN ... "Kicked from server.", Cl, lerp * 1000);
            }
            else if (lerp < 0.015151 || lerp > 0.5)
            {
                char KickMsg[256];
                Format(KickMsg, sizeof(KickMsg), "[StAC] Player %N's interp was %f ms, impossible value without cheating! Banned from server.", Cl, lerp * 1000);
                BanUser(userid, KickMsg);
                LogMessage("[StAC] Player %N Netprop 'm_fLerpTime' is impossible value (%f) without cheating!", Cl, lerp);
                PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N's " ... COLOR_MEDIUMPURPLE ... "interp" ... COLOR_WHITE ..." was " ...   COLOR_MEDIUMPURPLE ... "%f"  ... COLOR_WHITE ... ", indicating interp explotation through external cheating. " ... COLOR_PALEGREEN ... "Banned from server.", Cl, lerp * 1000);
            }
        }
        // third person "check" 2 (fixes some other methods of activating tp on clients, can't ban but it sort of works)
        ClientCommand(Cl, "firstperson");
        if (DEBUG)
        {
            LogMessage("[StAC] Executed firstperson command on Player %N", Cl);
            PrintToConsoleAllAdmins("[StAC] Executed firstperson command on Player %N", Cl);
            CPrintToSTV(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Executed firstperson command on Player %N", Cl);
        }
    }
}

public Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
    isHumiliation = false;
    // might as well!
    ActuallySetRandomSeed();
}

public Event_RoundWin(Handle event, const char[] name, bool dontBroadcast)
{
    isHumiliation = true;
    // might as well!
    ActuallySetRandomSeed();
}

//char propSendsToCheck[][] =
//{
//    "m_nForceTauntCam",
//    "m_iDefaultFOV",
//    "m_iFOV",
//    "m_iFOVStart"
//};
//
//char propDatasToCheck[][] =
//{
//    "m_fLerpTime"
//};

char cvarsToCheck[][] =
{
    "cl_interp",
    "cl_cmdrate",
    "cl_updaterate",
    "cl_interpolate",
    "r_drawothermodels",
    "fov_desired",
    "cam_idealyaw",
    "mat_fullbright",
    "sensitivity",
    "cat"
};

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
// STOCKS //
////////////

// cleaned up IsValidClient Stock
stock bool IsValidClient(client)
{
    if  (
            client <= 0                 ||
            client > MaxClients         ||
            !IsClientConnected(client)  ||
            IsFakeClient(client)
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
                team == TFTeam_Red ||
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

// these stocks are adapted & deuglified from f2stocks
// Finds STV Bot to use for CPrintToSTV
CachedSTV;
stock FindSTV()
{
    if  (!
            (
                CachedSTV >= 1               &&
                CachedSTV <= MaxClients      &&
                IsClientConnected(CachedSTV) &&
                IsClientInGame(CachedSTV)    &&
                IsClientSourceTV(CachedSTV)
            )
        )
    {
        CachedSTV = -1;
        for (int client = 1; client <= MaxClients; client++)
        {
            if  (
                    IsClientConnected(client) &&
                    IsClientInGame(client)    &&
                    IsClientSourceTV(client)
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

// absolute value stock
//stock int abs(int x)
//{
//    return (x > 0) ? x : -x;
//}