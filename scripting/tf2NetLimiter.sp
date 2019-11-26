#pragma semicolon 1

#include <sourcemod>
#include <morecolors>
#include <regex>

#define PLUGIN_VERSION "1.1"

public Plugin myinfo = {
    name        = "Net Settings Limiter",
    author      = "Miggy, Mizx, Dr.McKay, and Stephanie",
    description = "Plugin that prevents net settings abuse (forked from IntegriTF2)",
    version     =  PLUGIN_VERSION,
    url         = "https://stephanie.lgbt"
}

public OnPluginStart()
{
    // wait 15 secs to start checking clients after startup
    CreateTimer(15.0, Timer_CheckClientConVars);
}

public OnClientPostAdminCheck(client)
{
    // query convars on player connect
    QueryClientConVar(client, "cl_interp", ConVarQueryFinished:ClientConVar1);
    QueryClientConVar(client, "cl_cmdrate", ConVarQueryFinished:ClientConVar2);
}

public ClientConVar1(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
    if (client == 0 || !IsClientInGame(client))
    {
        return;
    }
    if (result != ConVarQuery_Okay)
    {
        CPrintToChatAll("{hotpink}[NetLimiter]{white} Unable to check CVar %s on player %N.", cvarName, client);
    }
    // cl_interp needs to be at or BELOW tf2's default settings
    else if (StringToFloat(cvarValue) > 0.100000)
    {
        KickClient(client, "CVar %s = %s, outside reasonable bounds. Change it to .1 at most", cvarName, cvarValue);
        LogMessage("[NetLimiter] Player %N is using CVar %s = %s, indicating net settings explotation. Kicked from server.", client, cvarName, cvarValue);
        PrintToChatAll("{hotpink}[NetLimiter]{white} Player %N was using CVar %s = %s, kicked from server.", client, cvarName, cvarValue);
    }
}

public ClientConVar2(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
    if (client == 0 || !IsClientInGame(client))
    {
        return;
    }
    if (result != ConVarQuery_Okay)
    {
        CPrintToChatAll("{hotpink}[NetLimiter]{white} Unable to check CVar %s on player %N.", cvarName, client);
    }
    // cl_cmdrate needs to be above 60 AND not have any non numerical chars in it because otherwise player ping gets messed up on the scoreboard
    else if ((StringToFloat(cvarValue) < 60) || SimpleRegexMatch(cvarValue, "^[0-9]*$") <= 0)
    {
        KickClient(client, "CVar %s = %s, indicating exploitative net settings. Change it to at least 60 and remove all non numerical characters from it", cvarName, cvarValue);
        LogMessage("[NetLimiter] Player %N is using CVar %s = %s, indicating exploitative net settings. Kicked from server.", client, cvarName, cvarValue);
        CPrintToChatAll("{hotpink}[NetLimiter]{white} Player %N was using CVar %s = %s, indicating exploitative net settings. Kicked from server.", client, cvarName, cvarValue);
    }
}

public Action:Timer_CheckClientConVars(Handle:timer)
{
    // iterate thru clients
    for (new client = 1; client <= MaxClients; client++)
    {
        // check cvars if client is in game
        if (IsClientInGame(client) && !IsFakeClient(client))
        {
            QueryClientConVar(client, "cl_interp", ConVarQueryFinished:ClientConVar1);
            QueryClientConVar(client, "cl_cmdrate", ConVarQueryFinished:ClientConVar2);
        }
    }
    // check randomly (every 1 - 5 minutes) for violating players, then recheck with a new random value
    CreateTimer(GetRandomFloat(60.0, 300.0), Timer_CheckClientConVars);
}
