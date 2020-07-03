#include <sourcemod>
#include <sdktools>

// fixed the whitespace to fit repo style thats it
#define PLUGIN_VERSION "1.2w"

ConVar gCV_Behavior = null;

ArrayList gA_TickCounts[MAXPLAYERS+1];

public Plugin myinfo =
{
    name        = "Backtrack Elimination",
    author      = "shavit",
    description = "Fixes the 'backtrack' exploit.",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/shavitush"
}

public void OnPluginStart()
{
    CreateConVar("backtrack_version", PLUGIN_VERSION, "Plugin version.", (FCVAR_NOTIFY | FCVAR_DONTRECORD));
    gCV_Behavior = CreateConVar("backtrack_behavior", "1", "Should the plugin be enabled?\n0 - no\n1 - yes, eliminate backtracking", 0, true, 0.0, true, 1.0);

    AutoExecConfig();

    for (int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i))
        {
            OnClientPutInServer(i);
        }
    }

    HookEvent("player_spawn", Player_Spawn);
}

public void Player_Spawn(Event event, const char[] name, bool dontBroadcast)
{
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);

    if (gA_TickCounts[client] != null)
    {
        gA_TickCounts[client].Clear();
    }
}

public void OnClientPutInServer(int client)
{
    if (!IsFakeClient(client) && gA_TickCounts[client] == null)
    {
        gA_TickCounts[client] = new ArrayList();
    }
}

public void OnClientDisconnect(int client)
{
    delete gA_TickCounts[client];
}

public Action OnPlayerRunCmd
    (
        int client,
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
    if  (
            IsFakeClient(client)
            || !IsPlayerAlive(client)
            || !gCV_Behavior.BoolValue
            || gA_TickCounts[client] == null
        )
    {
        return Plugin_Continue;
    }

    if (gA_TickCounts[client].FindValue(tickcount) == -1)
    {
        gA_TickCounts[client].Push(tickcount);
    }

    // illegal usercmd->tick_count
    // you cannot have the same tick_count twice!
    else
    {
        // makes the exploit useless by editing tick_count to a random value, below the possible window for backtracking
        SortADTArray(gA_TickCounts[client], Sort_Descending, Sort_Integer);
        tickcount = gA_TickCounts[client].Get(0) - GetRandomInt(32, 64);

        // prevent duplicates
        if (gA_TickCounts[client].FindValue(tickcount) == -1)
        {
            gA_TickCounts[client].Push(tickcount);
        }

        return Plugin_Changed;
    }
    return Plugin_Continue;
}
