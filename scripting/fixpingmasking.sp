#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
    name             =  "[StAC] Fix ping masking",
    author           =  "sappho",
    description      =  "Fix fake ping values for clients that are ping masking",
    version          =  "1.0.0",
    url              =  "https://github.com/sapphonie/StAC-tf2"
}

int imaxcmdrate;
int imincmdrate;

public void OnPluginStart()
{
    HookConVarChange(FindConVar("sv_mincmdrate"), CmdRateChange);
    HookConVarChange(FindConVar("sv_maxcmdrate"), CmdRateChange);

    UpdateCmdRate();

    // loop thru all clients
    for (int client = 1; client <= MaxClients; client++)
    {
        // don't check bots
        if (IsValidClient(client))
        {
            OnClientSettingsChanged(client);
        }
    }
}

void UpdateCmdRate()
{
    imincmdrate = GetConVarInt(FindConVar("sv_mincmdrate"));
    imaxcmdrate = GetConVarInt(FindConVar("sv_maxcmdrate"));
}

void CmdRateChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    UpdateCmdRate();
}

public void OnClientSettingsChanged(int client)
{
    char scmdrate[4];
    // get actual value of cl cmdrate
    GetClientInfo(client, "cl_cmdrate", scmdrate, sizeof(scmdrate));
    // convert it to int
    int icmdrate = StringToInt(scmdrate);
    // clamp it
    int iclamprate = Math_Clamp(icmdrate, imincmdrate, imaxcmdrate);
    char sclamprate[4];
    // convert it to string
    IntToString(iclamprate, sclamprate, sizeof(sclamprate));

    if
    (
        // cmdrate is == to optimal clamped rate
        icmdrate == iclamprate
        &&
        // client string is exactly equal to string of optimal cmdrate
        StrEqual(scmdrate, sclamprate)
    )
    {
        return;
    }

    // if client has unoptimal cmdrate, clamp it.
    SetClientInfo(client, "cl_cmdrate", sclamprate);

    // check our work - debug only
    // GetClientInfo(client, "cl_cmdrate", sclamprate, sizeof(sclamprate));
    // LogMessage("client cmdrate is %s", sclamprate);
}

bool IsValidClient(int client)
{
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && !IsFakeClient(client)
    );
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
