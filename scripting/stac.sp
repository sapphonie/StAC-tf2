////////////////////////////////////////////////////////////////////////////////////
//                                                                                //
//                               STEPHAC (StAC)                                   //
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

#define PLUGIN_VERSION  "2.1.0"
#define UPDATE_URL      "https://raw.githubusercontent.com/stephanieLGBT/tf2-stopexploits/master/updatefile.txt"
public Plugin myinfo =
{
    name             =  "Steph AntiCheat (StAC)",
    author           =  "stephanie",
    description      =  "super simple basic anticheat plugin (orig. forked from IntegriTF2)",
    version          =   PLUGIN_VERSION,
    url              =  "https://steph.anie.dev/"
}

Handle g_hQueryTimer[MAXPLAYERS+1];
turnTimes[MAXPLAYERS+1];
float tickinterv;
float maxAllowedTurnSecs = 1.0;
float minRandCheckVal = 60.0;
float maxRandCheckVal = 300.0;
bool isHumiliation;


bool DEBUG = true;

public OnPluginStart()
{
    RegAdminCmd("sm_forcecheckall", ForceCheckAll, ADMFLAG_ROOT, "Force check all client convars (ALL CLIENTS) for anticheat stuff");
//  RegAdminCmd("sm_forcecheck", ForceCheck, ADMFLAG_ROOT, "Force check all client convars (SINGLE CLIENT) for anticheat stuff");
    // get tick interval
    Float:tickinterv = GetTickInterval();
    NukeTimers();
    ResetTimers();
    // don't accidentally ban ppl during humiliation for forced taunt cam!
    HookEvent("teamplay_round_start", Event_RoundStart);
    HookEvent("teamplay_round_win", Event_RoundWin);
    // reset random server seed
    ActuallySetRandomSeed();
    // todo: Create ConVars for adjusting settings
}

// reseed random server seed to help prevent nospread stuff from working (probably)
ActuallySetRandomSeed()
{
    int seed = GetURandomInt();
    SetRandomSeed(seed);
}

// NUKE the client timers from orbit on plugin and map reload
NukeTimers()
{
    for (int Cl = 0; Cl < MAXPLAYERS + 1; Cl++)
    {
        if (g_hQueryTimer[Cl] != null)
        {
            KillTimer(g_hQueryTimer[Cl]);
            g_hQueryTimer[Cl] = null;
        }
    }
}

// recreate the timers we just nuked
ResetTimers()
{
    for (int Cl = 0; Cl < MAXPLAYERS + 1; Cl++)
    {
    if (IsValidClient(Cl))
        {
            if (DEBUG)
            {
                LogMessage("[DEBUG] creating timer for %L", Cl);
            }
            g_hQueryTimer[Cl] = CreateTimer(GetRandomFloat(minRandCheckVal, maxRandCheckVal), Timer_CheckClientConVars, GetClientUserId(Cl));
        }
    }
}

public OnMapStart()
{
    ActuallySetRandomSeed();
    ResetTimers();
}

public OnMapEnd ()
{
    ActuallySetRandomSeed();
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
    ReplyToCommand(client, "Forcibly checking cvars.");
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
    if (!IsValidClient(Cl))
    {
        return;
    }
    // log something about cvar errors
    if (result != ConVarQuery_Okay)
    {
        PrintColoredChatToAdmins(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Could not query CVar %s on Player %N", cvarName, Cl);
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
        }
        // cl_cmdrate needs to be above 60 AND not have any non numerical chars (xcept the . sign if its a float) in it because otherwise player ping gets messed up on the scoreboard
        else if (SimpleRegexMatch(cvarValue, "^\\d*\\.?\\d*$") <= 0)
        {
            KickClient(Cl, "CVar %s = %s, indicating pingmasking. Remove any non numeric characters", cvarName, cvarValue);
            LogMessage("[StAC] Player %N is using CVar %s = %s, ping-masking! Kicked from server", Cl, cvarName, cvarValue);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar " ... COLOR_MEDIUMPURPLE ... "%s" ... COLOR_WHITE ..." = " ... COLOR_MEDIUMPURPLE ... "%s"  ... COLOR_WHITE ... ", indicating ping masking." ... COLOR_PALEGREEN ... "Kicked from server.", Cl, cvarName, cvarValue);
        }
        else if (StringToFloat(cvarValue) < 60)
        {
            LogMessage("[StAC] Player %N is using CVar %s = %s, possibly ping-masking or rate exploiting! Recommended cmdrate: 60 or higher", Cl, cvarName, cvarValue);
            PrintColoredChatToAdmins(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N is using CVar %s = %s, possibly ping-masking or rate exploiting! Recommended cmdrate: 60 or higher", Cl, cvarName, cvarValue);
        }
    }
    // r_drawothermodels (if u get banned by this you are a clown)
    else if (StrEqual(cvarName, "r_drawothermodels"))
    {
        if (StringToInt(cvarValue) != 1)
        {
            char KickMsg[256];
            Format(KickMsg, sizeof(KickMsg), "CVar %s was %s, indicating WALLHACKING! Banned from server", cvarName, cvarValue);
            BanClient(Cl, 0, BANFLAG_AUTO, KickMsg, KickMsg, _, _);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar " ... COLOR_MEDIUMPURPLE ... "%s" ... COLOR_WHITE ..." = " ... COLOR_MEDIUMPURPLE ... "%s"  ... COLOR_WHITE ... ", indicating WALLHACKING!" ... COLOR_PALEGREEN ... "BANNED from server.", Cl, cvarName, cvarValue);
            LogMessage("[StAC] Player %N is using CVar %s = %s, indicating WALLHACKING! BANNED from server!", Cl, cvarName, cvarValue);
        }
    }
    // fov check #1 (if u get banned by this you are a clown)
    else if (StrEqual(cvarName, "fov_desired"))
    {
        if (StringToFloat(cvarValue) > 90.000)
        {
            char KickMsg[256];
            Format(KickMsg, sizeof(KickMsg), "CVar %s was %s, indicating FOV HACKING! Banned from server", cvarName, cvarValue);
            BanClient(Cl, 0, BANFLAG_AUTO, KickMsg, KickMsg, _, _);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar " ... COLOR_MEDIUMPURPLE ... "%s" ... COLOR_WHITE ..." = " ... COLOR_MEDIUMPURPLE ... "%s"  ... COLOR_WHITE ... ", indicating FOV HACKING!" ... COLOR_PALEGREEN ... "BANNED from server.", Cl, cvarName, cvarValue);
            LogMessage("[StAC] Player %N is using CVar %s = %s, indicating FOV HACKING! BANNED from server!", Cl, cvarName, cvarValue);
        }
        else if (StringToFloat(cvarValue) < 90.000)
        {
            PrintColoredChatToAdmins(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N has an FOV below 90! FOV: %s", Cl, StringToFloat(cvarValue));
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
            BanClient(Cl, 0, BANFLAG_AUTO, KickMsg, KickMsg, _, _);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using CVar " ... COLOR_MEDIUMPURPLE ... "%s" ... COLOR_WHITE ..." = " ... COLOR_MEDIUMPURPLE ... "%s"  ... COLOR_WHITE ... ", indicating cheating with THIRD PERSON!" ... COLOR_PALEGREEN ... "BANNED from server.", Cl, cvarName, cvarValue);
            LogMessage("[StAC] Player %N was using CVar %s = %s, indicating cheating with THIRD PERSON! BANNED from server!", Cl, cvarName, cvarValue);
        }
    }
    if (DEBUG)
    {
        LogMessage("Checked cvar %s value %s on %N", cvarName, cvarValue, Cl);
        PrintToConsoleAllAdmins("Checked cvar %s value %s on %N", cvarName, cvarValue, Cl);
    }
}

// todo- try GetClientModel for detecting possible chams? don't think that would work though as you can't check client's specific models for other things afaik
NetPropCheck(userid)
{
    int Cl = GetClientOfUserId(userid);
    if (IsValidClient(Cl))
    {
        // check netprops!!!
        // fov
        // client has to be alive, on a team, and have an above normal fov
        if  (
                IsPlayerAlive(Cl) &&
                (
                    TF2_GetClientTeam(Cl) == TFTeam_Red ||
                    TF2_GetClientTeam(Cl) == TFTeam_Blue
                )
                &&
                GetEntProp(Cl, Prop_Data, "m_iFOV", 1) > 90
            )
        {
            char KickMsg[256] = "Netprop 'm_iFOV' was > 90, indicating FOV HACKING! Banned from server";
            BanClient(Cl, 0, BANFLAG_AUTO, KickMsg, KickMsg, _, _);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using Netprop " ... COLOR_MEDIUMPURPLE ... "m_iFOV" ...    COLOR_WHITE ..." > " ... COLOR_MEDIUMPURPLE ... "90"  ... COLOR_WHITE ... ", indicating FOV HACKING!" ... COLOR_PALEGREEN ... "BANNED from server.", Cl);
            LogMessage("[StAC] Player %N Netprop m_iFOV was > 90, indicating FOV HACKING! BANNED from server!", Cl);
        }
        // third person (check 1)
        if (GetEntProp(Cl, Prop_Send, "m_nForceTauntCam") != 0 && !isHumiliation)
        {
            char KickMsg[256] = "Netprop 'm_nForceTauntCam' was != 0, indicating cheating with THIRD PERSON! Banned from server";
            BanClient(Cl, 0, BANFLAG_AUTO, KickMsg, KickMsg, _, _);
            PrintColoredChatAll(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Player %N was using Netprop " ... COLOR_MEDIUMPURPLE ... "m_nForceTauntCam" ...    COLOR_WHITE ..." != " ... COLOR_MEDIUMPURPLE ... "0"  ... COLOR_WHITE ... ", cheating with THIRD PERSON!" ... COLOR_PALEGREEN ... "BANNED from server.", Cl);
            LogMessage("[StAC] Player %N Netprop 'm_nForceTauntCam' was != 0, indicating cheating with THIRD PERSON! BANNED from server!", Cl);
        }
        // third person "check" 2 (fixes most other methods, can't ban but it hopefully works and itll annoy cheaters lol)
        ClientCommand(Cl, "firstperson");
        if (DEBUG)
        {
            PrintColoredChatToAdmins(COLOR_HOTPINK ... "[StAC]" ... COLOR_WHITE ... " Executed firstpersson command on Player %N", Cl);
        }
        // glow check goes here
        // if m_bGlowEnabled etc
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

QueryEverything(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if (IsValidClient(Cl))
    {
        // convars to check
        // will at some point be spaced out for less server load
        // interp check
        QueryClientConVar(Cl, "cl_interp", ConVarQueryFinished:ConVarCheck);
        // cmdrate check for pingmasking
        QueryClientConVar(Cl, "cl_cmdrate", ConVarQueryFinished:ConVarCheck);
        // BASIC othermodels check (will almost never catch anyone)
        QueryClientConVar(Cl, "r_drawothermodels", ConVarQueryFinished:ConVarCheck);
        // BASIC fov check (will almost never catch anyone)
        QueryClientConVar(Cl, "fov_desired", ConVarQueryFinished:ConVarCheck);
        // BASIC camyaw check, PROBABLY won't catch anyone
        QueryClientConVar(Cl, "cam_idealyaw", ConVarQueryFinished:ConVarCheck);
        // checks a bunch of AC related netprops
        NetPropCheck(userid);
    }
}

public Action Timer_CheckClientConVars(Handle timer, any userid)
{
    // get actual client index
    int Cl = GetClientOfUserId(userid);
    // null out timer here
    g_hQueryTimer[Cl] = null;
    if (DEBUG)
    {
        LogMessage("Checking client id, %i, %N", Cl, Cl);
    }
    if (IsValidClient(Cl))
    {
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
stock bool:IsValidClient(client)
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
stock void PrintColoredChatToAdmins(const char[] format, any ...)
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
stock void PrintToConsoleAllAdmins(const char[] format, any ...)
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