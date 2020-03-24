////////////////////////////////////////////////////////////////////////////////////
//                                                                                //
//                             STEPH'S AC (StAC)                                  //
//                                                                                //
//    SEE HERE FOR PROBABLY BETTER AC PLUGINS:                                    //
//    LilAC:  -> https://forums.alliedmods.net/showthread.php?t=321480            //
//    SMAC:   -> https://github.com/Silenci0/SMAC                                 //
//                                                                                //
//    This plugin currently prevents:                                             //
//     -> interp abuse                                           -kick            //
//     -> clients using turn binds                               -kick            //
//     -> cmdrate pingmasking if cvar has nonnumerical chars)    -kick            //
//     -> othermodels abuse (lol)                                -ban             //
//     -> (hopefully) fov abuse > 90                             -ban             //
//     -> (hopefully) third person cheats on clients             -ban             //
//                                                                                //
//    Currently notifies to server console of:                                    //
//     -> cmdrate pingmasking (if cmdrate is > 60)                                //
//                                                                                //
//    This plugin also currently reseeds the hl2 random seed at each map start to //
//    attempt to prevent possible nospread exploits by guessing server seed.      //
//    This is currently untested but there is no harm by doing it.                //
//                                                                                //
//    Todo (may not be possible):                                                 //
//     -> break/ban for esp/wallhack shit                                         //
//              (not thru painting but possibly with checking m_bGlowEnabled)     //
//     -> fix spy decloak exploit / other soundscript exploits                    //
//              (in the works)                                                    //
//     -> fix other sv pure stuff (flat / invisible textures)                     //
//     -> fix sniper scope removal exploit                                        //
//     -> fix changing world visiblity                                            //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////

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

#define PLUGIN_VERSION  "2.1.1"
#define UPDATE_URL      "https://raw.githubusercontent.com/stephanieLGBT/StAC-tf2/master/updatefile.txt"

public Plugin myinfo =
{
    name             =  "Steph's AntiCheat (StAC)",
    author           =  "stephanie",
    description      =  "Anticheat plugin [tf2 only] (orig. forked from IntegriTF2)",
    version          =   PLUGIN_VERSION,
    url              =  "https://steph.anie.dev/"
}

Handle g_hQueryTimer[MAXPLAYERS+1];
Handle g_hTriggerTimedStuffTimer;
int turnTimes[MAXPLAYERS+1];
int fovDesired[MAXPLAYERS+1];
int minUpdateRate;
int maxUpdateRate;
int optUpdateRate;
float tickinterv;
float tps;
float maxAllowedTurnSecs = 1.0;
float minRandCheckVal = 60.0;
float maxRandCheckVal = 300.0;

bool isHumiliation;
bool SOURCEBANS;
bool DEBUG = true;

public OnPluginStart()
{
    RegAdminCmd("sm_forcecheckall", ForceCheckAll, ADMFLAG_ROOT, "Force check all client convars (ALL CLIENTS) for anticheat stuff");
//  RegAdminCmd("sm_forcecheck", ForceCheck, ADMFLAG_ROOT, "Force check all client convars (SINGLE CLIENT) for anticheat stuff");
    // get tick interval - some modded tf2 servers run at >66.7 tick!
    tickinterv = GetTickInterval();
    // don't accidentally ban ppl during humiliation for forced taunt cam! (may be unneeded?)
    HookEvent("teamplay_round_start", Event_RoundStart);
    HookEvent("teamplay_round_win", Event_RoundWin);
    // reset random server seed
    ActuallySetRandomSeed();
    // todo: Create ConVars for adjusting settings
    HookEvent("teamplay_round_start", eRoundStart);
    // check sourcebans capibility
    CreateTimer(2.0, checkSourceBans);
    // check EVERYONE's cvars on plugin reload
    CreateTimer(5.0, checkEveryone);
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

public OnPluginEnd()
{
    NukeTimers();
    OnMapEnd();
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
    DoUpdateRateMath();
}

public Action timer_TriggerTimedStuff(Handle timer)
{
    ActuallySetRandomSeed();

}// set stuff for updaterate checking here.
DoUpdateRateMath()
{
    // there is NO REASON to have updaterate below default (20) or above 100 on a default server.
    // the reason we use the tickinterv equation is that some servers run at higher tickrates. default tickrate is 66.7 * 1.5 + 1 = 101.05 ...
    // ... which is basically where we want to draw the line as things start getting fucked up past there.
    // .. although technically things get fucked up at anything higher than sv_maxupdaterate...
    // .. too many tf2 cfgs have it set at 100 and it would annoy way too many ppl.
    tps           = Pow(tickinterv, -1.0);
    optUpdateRate = RoundToFloor(tps);
    if (DEBUG)
    {
        LogMessage("tickinterv %f tps %f optUpdateRate %i", tickinterv, tps, optUpdateRate);
    }
}



public OnMapStart()
{
    ActuallySetRandomSeed();
    ResetTimers();
    DoUpdateRateMath();
}

public OnMapEnd()
{
    ActuallySetRandomSeed();
    DoUpdateRateMath();
    NukeTimers();
}

public OnLibraryAdded(const String:name[])
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
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

        //  clear all old values for id based stuff
        turnTimes[Cl]              = 0;
        g_hQueryTimer[Cl]          = null;
        // query convars on player connect
        LogMessage("[StAC] %N joined. Checking cvars", Cl);
        g_hQueryTimer[Cl] = CreateTimer(GetRandomFloat(minRandCheckVal, maxRandCheckVal), Timer_CheckClientConVars, userid);
    }
}

public OnClientDisconnect_Post(Cl)
{
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
    if (buttons & IN_LEFT || buttons & IN_RIGHT)
    {
        turnTimes[Cl]++;
        float turnSec = turnTimes[Cl] * tickinterv;
        LogMessage("[StAC] Detected turn bind on player [%L] for [%f] seconds", Cl, turnSec);
        if (turnSec < maxAllowedTurnSecs)
        {
            PrintColoredChat(Cl, COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Turn binds and spin binds are not allowed on this server. If you continue to use them you will be autokicked!");
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
}

public ConVarCheck(QueryCookie cookie, int Cl, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
    int userid = GetClientUserId(Cl);

    if (!IsValidClient(Cl))
    {
        return;
    }
    // && StrEqual(cvarName, "cl_interpolate")
    // log something about cvar errors
    if (result != ConVarQuery_Okay)
    {
        PrintColoredChatToAdmins(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Could not query CVar %s on Player %N", cvarName, Cl);
        CPrintToSTV(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Could not query CVar %s on Player %N", Cl);
        LogMessage("[StAC] Could not query CVar %s on Player %N", cvarName, Cl);
    }
    // cl_interp
    if (StrEqual(cvarName, "cl_interp"))
    {
        // cl_interp needs to be at or BELOW tf2's default settings
        if (StringToFloat(cvarValue) > 0.100000)
        {
            KickClient(Cl, "CVar %s = %s, outside reasonable bounds. Change it to .1 at most", cvarName, cvarValue);
            LogMessage("[StAC] Player %N was using CVar %s = %s, indicating interp explotation. Kicked from server.", Cl, cvarName, cvarValue);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar " ... COLOR_MEDIUMPURPLE ... "%s" ... COLOR_WHITE ..." = " ... COLOR_MEDIUMPURPLE ... "%s"  ... COLOR_WHITE ... ", indicating interp explotation." ... COLOR_PALEGREEN ... "Kicked from server.", Cl, cvarName, cvarValue);
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
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar " ... COLOR_MEDIUMPURPLE ... "%s" ... COLOR_WHITE ..." = " ... COLOR_MEDIUMPURPLE ... "%s"  ... COLOR_WHITE ... ", indicating ping masking." ... COLOR_PALEGREEN ... "Kicked from server.", Cl, cvarName, cvarValue);
        }
    }
    // there exists an exploit involving updaterate and lerp which allows you to have literally whatever interp you want. the "m_fLerpTime" netprop DOES NOT CHANGE so we have to check the actual cvar.
    else if (StrEqual(cvarName, "cl_updaterate"))
    {
        // don't bother checking if tickrate isnt default
        if (tps < 70 && (StringToFloat(cvarValue) < 20.0 || StringToFloat(cvarValue) > 100))
        {
            KickClient(Cl, "CVar %s = %s, indicating possible lerp exploitation. Change it to between %i and %i. Recommended value: %i", cvarName, cvarValue, minUpdateRate, maxUpdateRate, optUpdateRate);
            LogMessage("[StAC] Player %N is using CVar %s = %s, indicating lerp exploitation! Kicked from server", Cl, cvarName, cvarValue);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar " ... COLOR_MEDIUMPURPLE ... "%s" ... COLOR_WHITE ..." = " ... COLOR_MEDIUMPURPLE ... "%s"  ... COLOR_WHITE ... ", indicating lerp exploitation." ... COLOR_PALEGREEN ... "Kicked from server.", Cl, cvarName, cvarValue);
        }
    }
    // cl_interpolate (hidden cvar! should never not be 1.0)
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
    if (DEBUG)
    {
        LogMessage("[StAC] Checked cvar %s value %s on %N", cvarName, cvarValue, Cl);
        PrintToConsoleAllAdmins("[StAC] Checked cvar %s value %s on %N", cvarName, cvarValue, Cl);
    }
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
        SetEntProp(Cl, Prop_Send, "m_iFOV", fovDesired[Cl]);
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
        if  (
                IsPlayerAlive(Cl) &&
                (
                    TF2_GetClientTeam(Cl) == TFTeam_Red ||
                    TF2_GetClientTeam(Cl) == TFTeam_Blue
                )
                &&
                (
                    GetEntProp(Cl, Prop_Send, "m_iFOV", 1) != 0
                )
                &&
                (
                    GetEntProp(Cl, Prop_Send, "m_iFOV", 1) > 90 ||
                    GetEntProp(Cl, Prop_Send, "m_iFOV", 1) < 20
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
        // lerp check (UNTESTED)
        // float lerp = GetEntPropFloat(Cl, Prop_Data, "m_fLerpTime");
        // if ( lerp > 0.1)
        // {
        //     LogMessage("[StAC] Player %N Netprop 'm_fLerpTime' is %f, outside reasonable bounds!", Cl, lerp);
        // }
        // else if (lerp < 0.015151 || lerp > .5)
        // {
        //     LogMessage("[StAC] Player %N Netprop 'm_fLerpTime' is impossible value (%f) without cheating!", Cl, lerp);
        // }
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

char cvarsToCheck[][] =
{
    "cl_interp",
    "cl_cmdrate",
    "cl_updaterate",
    "cl_interpolate",
    "r_drawothermodels",
    "fov_desired",
    "cam_idealyaw"
    // will get added if i manage to fix the othermodels thing
    // "mat_fullbright"
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

