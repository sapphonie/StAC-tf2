#pragma semicolon 1

#define TFMAXPLAYERS 33

#include <sourcemod>
#include <regex>
#include <dhooks>
#include <sdktools>
#include <morecolors>
#undef REQUIRE_PLUGIN
#tryinclude <discord>

#pragma newdecls required

public Plugin myinfo =
{
    name = "[DHooks] Block SM Plugins (Ricochet's Fork)",
    description = "",
    author = "Bara, Ricochet",
    version = "shfjgsh625063",
    url = "https://github.com/Bara"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("sbpstac");
	
	return APLRes_Success;
}

Handle g_hClientPrintf = null;

char g_sLogs[PLATFORM_MAX_PATH + 1];
char stacVersion[32]; // The size of this may be able to be reduced.
bool DISCORD;
bool adminsNotified[TFMAXPLAYERS+1] = {false, ...};
char hostname[64];
char realSMVer[32];
Regex smVerRegex;

public void OnPluginStart()
{
    // Fake the admin commands for the plugins we lie about...
    RegAdminCmd("sm_sql_addadmin", Command_DoNothing, ADMFLAG_ROOT, "Adds an admin to the SQL database");
    RegAdminCmd("sm_sql_deladmin", Command_DoNothing, ADMFLAG_ROOT, "Removes an admin from the SQL database");
    RegAdminCmd("sm_sql_addgroup", Command_DoNothing, ADMFLAG_ROOT, "Adds a group to the SQL database");
    RegAdminCmd("sm_sql_delgroup", Command_DoNothing, ADMFLAG_ROOT, "Removes a group from the SQL database");
    RegAdminCmd("sm_sql_setadmingroups", Command_DoNothing, ADMFLAG_ROOT, "Sets an admin's groups in the SQL database");
    
    Handle gameconf = LoadGameConfigFile("sbp.games");
    if (gameconf == null)
    {
        SetFailState("Failed to find sbp.games.txt gamedata");
        delete gameconf;
    }
    
    int offset = GameConfGetOffset(gameconf, "ClientPrintf");
    if (offset == -1)
    {
        SetFailState("Failed to find offset for ClientPrintf");
        delete gameconf;
    }
    
    StartPrepSDKCall(SDKCall_Static);
    
    if (!PrepSDKCall_SetFromConf(gameconf, SDKConf_Signature, "CreateInterface"))
    {
        SetFailState("Failed to get CreateInterface");
        delete gameconf;
    }
    
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    
    char identifier[64];
    if (!GameConfGetKeyValue(gameconf, "EngineInterface", identifier, sizeof(identifier)))
    {
        SetFailState("Failed to get engine identifier name");
        delete gameconf;
    }
    
    Handle temp = EndPrepSDKCall();
    Address addr = SDKCall(temp, identifier, 0);
    
    delete gameconf;
    delete temp;
    
    if (!addr)
    {
        SetFailState("Failed to get engine ptr");
    }
    
    g_hClientPrintf = DHookCreate(offset, HookType_Raw, ReturnType_Void, ThisPointer_Ignore, Hook_ClientPrintf);
    DHookAddParam(g_hClientPrintf, HookParamType_Edict);
    DHookAddParam(g_hClientPrintf, HookParamType_CharPtr);
    DHookRaw(g_hClientPrintf, false, addr);
    
    char sDate[18];
    FormatTime(sDate, sizeof(sDate), "%y-%m-%d");
    BuildPath(Path_SM, g_sLogs, sizeof(g_sLogs), "logs/sbp-%s.log", sDate);
}

public void OnMapStart()
{
    smVerRegex = CompileRegex("([1-9]\\d*|0)(\\.(([1-9]\\d*)|0)){0,3}"); // Might break someday lol
    char smVerOut[2048];
    ServerCommandEx(smVerOut, sizeof(smVerOut), "sm version");
    GetConVarString(FindConVar("hostname"), hostname, sizeof(hostname));

    if (MatchRegex(smVerRegex, smVerOut) > 0)
    {
        GetRegexSubString(smVerRegex, 0, realSMVer, sizeof(realSMVer));
    }
    else 
    {
        realSMVer = SOURCEMOD_VERSION;
    }
    CreateTimer(0.1, checkDiscord);
}

public void OnClientDisconnect(int client)
{
    adminsNotified[client] = false;
}

public MRESReturn Hook_ClientPrintf(Handle hParams)
{
    char sBuffer[1024];
    int client = DHookGetParam(hParams, 1);
    
    if (client == 0)
    {
        return MRES_Ignored;
    }

    if (IsValidAdmin(client))
    {
        return MRES_Ignored;
    }
    
    DHookGetParamString(hParams, 2, sBuffer, sizeof(sBuffer));
    // Ideally, I wouldn't need to fake what plugin is loaded and would just remove ours from the list, but that seemingly isn't possible with this approach.
    // DiscordAPI
    char fakePreSQL[64] = " \"SQL Admins (Prefetch)\" (";
    StrCat(fakePreSQL, sizeof(fakePreSQL), realSMVer);
    StrCat(fakePreSQL, sizeof(fakePreSQL), ") by AlliedModders LLC\n");
    //char fakePreSQL[64];
    //Format(fakePreSQL, sizeof(fakePreSQL),  " \"SQL Admins (Prefetch)\" (" ... realSMVer ... ") by AlliedModders LLC\n");
    char discordName[] = " \"Discord API\" (1.0) by .#Zipcore, Credits: Shavit, bara, ImACow and Phire\n";
    if (StrEqual(sBuffer, discordName))
    {
        notifyAdmins(client);
        DHookSetParamString(hParams, 2, fakePreSQL);
        return MRES_ChangedHandled;
    }

    // StAC
    // Create fake Admin Manager string
    char fakeAdmMan[64] = " \"SQL Admin Manager\" (";
    StrCat(fakeAdmMan, sizeof(fakeAdmMan), realSMVer);
    StrCat(fakeAdmMan, sizeof(fakeAdmMan), ") by AlliedModders LLC\n");
    // Create real StAC string for strcmp
    char stacName[128] = " \"Steph's AntiCheat [StAC]\" (";
    StrCat(stacName, sizeof(stacName), stacVersion);
    StrCat(stacName, sizeof(stacName), ") by https://sappho.io\n"); // May not be escaped properly. I haven't tried compiling StAC's version yet.
    if (StrEqual(sBuffer, stacName))
    {
        notifyAdmins(client);
        DHookSetParamString(hParams, 2, fakeAdmMan);
        return MRES_ChangedHandled;
    }
    // SBP itself
    // Create fake SQL Admins string
    char fakeThrSQL[64] = " \"SQL Admins (Threaded)\" (";
    StrCat(fakeThrSQL, sizeof(fakeThrSQL), realSMVer);
    StrCat(fakeThrSQL, sizeof(fakeThrSQL), ") by AlliedModders LLC\n");
    // Create SBP string for strcmp
    char sbpName[] = " \"[DHooks] Block SM Plugins (Ricochet's Fork)\" (shfjgsh625063) by Bara, Ricochet\n";
    if (StrEqual(sBuffer, sbpName))
    {
        notifyAdmins(client);
        DHookSetParamString(hParams, 2, fakeThrSQL);
        return MRES_ChangedHandled;
    }
    // Make sure Admin Help looks as if it's bundled (version number)
    if (!StrEqual(SOURCEMOD_VERSION, realSMVer)) // No need to do any of this if the compiler version number and real version number are the same
    {
        // Create fake Admin Help string
        char fakeAdmHlp[64] = " \"Admin Help\" (";
        StrCat(fakeAdmHlp, sizeof(fakeAdmHlp), realSMVer);
        StrCat(fakeAdmHlp, sizeof(fakeAdmHlp), ") by AlliedModders LLC\n");
        // Create real Admin Help string for strcmp
        char admHlpName[64] = " \"Admin Help\" (";
        StrCat(admHlpName, sizeof(admHlpName), SOURCEMOD_VERSION);
        StrCat(admHlpName, sizeof(admHlpName), ") by AlliedModders LLC\n");
        if (StrEqual(sBuffer, admHlpName))
        {
            notifyAdmins(client);
            DHookSetParamString(hParams, 2, fakeAdmHlp);
            return MRES_ChangedHandled;  
        }
    }
    return MRES_Ignored;
}

public Action Command_DoNothing(int client, int args)
{
    return Plugin_Handled;
}

public void OnAllPluginsLoaded()
{
    GetConVarString(FindConVar("stac_version"), stacVersion, sizeof(stacVersion));
    HookConVarChange(FindConVar("stac_version"), getStACVersion);
}

public void getStACVersion(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (StrEqual(stacVersion, newValue))
    {
        return;
    }
    GetConVarString(FindConVar("stac_version"), stacVersion, sizeof(stacVersion));
}

// print colored chat to all server/sourcemod admins
void PrintToImportant(const char[] format, any ...)
{
    char buffer[254];
    
    // print translations in the servers lang first
    SetGlobalTransTarget(LANG_SERVER);
    // format it properly
    VFormat(buffer, sizeof(buffer), format, 2);
    buffer[0] = '\0';

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidAdmin(i))
        {
            SetGlobalTransTarget(i);
            VFormat(buffer, sizeof(buffer), format, 2);
            MC_PrintToChat(i, "%s", buffer);
        }
    }
}

public Action checkDiscord(Handle timer)
{
    // discord functionality
    if (GetFeatureStatus(FeatureType_Native, "Discord_SendMessage") == FeatureStatus_Available)
    {
        DISCORD = true;
    }
    return Plugin_Handled;
}

void notifyAdmins(int client)
{
    if (adminsNotified[client])
    {
        return;
    }
    adminsNotified[client] = true;
    PrintToImportant("{hotpink}[StAC]{white} %N accessed sm plugins", client);
    SendMessageToDiscord(client, "Client accessed sm plugins");
}

void SendMessageToDiscord(int client, const char[] format, any ...)
{

    if (!DISCORD)
    {
        return;
    }

    static char generalTemplate[2048] = \
    "{ \"embeds\": \
        [{ \"title\": \"StAC Notification!\", \"color\": 14177041, \"fields\":\
            [\
                { \"name\": \"Player\",           \"value\": \"%N\" } ,\
                { \"name\": \"Message\",          \"value\": \"%s\" } ,\
                { \"name\": \"Hostname\",         \"value\": \"%s\" } ,\
                { \"name\": \"Unix timestamp\",   \"value\": \"%i\" }  \
            ]\
        }],\
        \"avatar_url\": \"https://i.imgur.com/RKRaLPl.png\"\
    }";

    char msg[1024];

    char message[256];
    VFormat(message, sizeof(message), format, 3);

    char ClName[64];
    GetClientName(client, ClName, sizeof(ClName));
    Discord_EscapeString(ClName, sizeof(ClName));

    Format
    (
        msg,
        sizeof(msg),
        generalTemplate,
        client,
        message,
        hostname,
        GetTime()
    );

    char webhook[8] = "stac";
    Discord_SendMessage(webhook, msg);
}

bool IsValidClient(int client)
{
    if
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && !IsClientInKickQueue(client)
        && !IsFakeClient(client)
    )
    {
        return true;
    }
    return false;
}

bool IsValidAdmin(int Cl)
{
    if (IsValidClient(Cl))
    {
        if
        (
            CheckCommandAccess(Cl, "sm_ban", ADMFLAG_GENERIC)
        )
        {
            return true;
        }
    }
    return false;
}
