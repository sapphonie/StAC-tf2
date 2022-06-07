#pragma semicolon 1

/********** StacLog functions **********/

// Open log file for StAC
void OpenStacLog()
{
    if (StacLogFile != null)
    {
        FlushFile(StacLogFile);
        return;
    }
    // current date for log file (gets updated on map change to not spread out maps across files on date changes)
    char curDate[32];

    // get current date
    FormatTime(curDate, sizeof(curDate), "%m%d%y", GetTime());

    // init path
    char path[128];
    // set path
    BuildPath(Path_SM, path, sizeof(path), "logs/stac");

    // create directory if not extant
    if (!DirExists(path, false))
    {
        LogMessage("[StAC] StAC directory not extant! Creating...");
        // 511 = unix 775 ?
        if (!CreateDirectory(path, 511, false))
        {
            LogMessage("[StAC] StAC directory could not be created!");
        }
    }

    // set up the full path here
    Format(path, sizeof(path), "%s/stac_%s.log", path, curDate);

    // actually create file here
    StacLogFile = OpenFile(path, "at", false);
}

// Close log file for StAC
void CloseStacLog()
{
    FlushFile(StacLogFile);
    delete StacLogFile;
}

// log to StAC log file
void StacLog(const char[] format, any ...)
{
    // crutch for reloading the plugin and still printing to our log file
    if (StacLogFile == null)
    {
        ConVar temp_staclogtofile = FindConVar("stac_log_to_file");
        if (temp_staclogtofile != null)
        {
            if (GetConVarBool(temp_staclogtofile))
            {
                OpenStacLog();
            }
        }
    }

    char buffer[254];
    VFormat(buffer,         sizeof(buffer),         format, 2);
    // clear color tags
    MC_RemoveTags(buffer, sizeof(buffer));

    char nowtime[64];
    int int_nowtime = GetTime();

    FormatTime(nowtime, sizeof(nowtime), "%H:%M:%S", int_nowtime);

    char file_buffer[254];
    strcopy(file_buffer,    sizeof(file_buffer),    buffer);
    // add newlines
    Format(file_buffer, sizeof(file_buffer), "<%s> %s\n", nowtime, file_buffer);

    char colored_buffer[254];
    strcopy(colored_buffer, sizeof(colored_buffer), buffer);


    if (StrEqual(os, "linux"))
    {
        // add colored tags :D
        Format(colored_buffer, sizeof(colored_buffer), ansi_bright_magenta ... "[StAC]" ... ansi_reset ... " %s", colored_buffer);
    }
    else
    {
        Format(colored_buffer, sizeof(colored_buffer), "[StAC] %s", colored_buffer);
    }

    // add the tag to the normal thing
    Format(buffer, sizeof(buffer), "[StAC] %s", buffer);


    if (StacLogFile != null)
    {
        WriteFileString(StacLogFile, file_buffer, false);
        FlushFile(StacLogFile);
    }
    // else if (logtofile)
    // {
    //     LogMessage("[StAC] File handle invalid!");
    // }

    PrintToServer("%s", colored_buffer);

    PrintToConsoleAllAdmins("%s", buffer);
}

void StacLogDemo()
{
    if (GetDemoName())
    {
        StacLog("Demo file: %s. Demo tick: %i", demoname, demotick);
    }
}

void StacLogSteam(int userid)
{
    int Cl = GetClientOfUserId(userid);

    StacLog
    ("\
        \n Player: %L\
        \n StAC cached SteamID: %s\
        ",
        Cl,
        SteamAuthFor[Cl]
    );
}

void StacLogNetData(int userid)
{
    int Cl = GetClientOfUserId(userid);

    StacLog
    (
        "\
        \nNetwork:\
        \n %.2f ms ping\
        \n %.2f loss\
        \n %.2f inchoke\
        \n %.2f outchoke\
        \n %.2f totalchoke\
        \n %.2f kbps rate\
        \n %.2f pps rate\
        ",
        pingFor[Cl],
        lossFor[Cl],
        inchokeFor[Cl],
        outchokeFor[Cl],
        chokeFor[Cl],
        rateFor[Cl],
        ppsFor[Cl]
    );

    StacLog
    (
        "\
        \nMore network:\
        \n Approx client cmdrate: ≈%i cmd/sec\
        \n Approx server tickrate: ≈%i tick/sec\
        \n Failing lag check? %s\
        \n HasValidAngles? %s\
        \n SequentialCmdnum? %s\
        \n OrderedTickcount? %s\
        ",
        tickspersec[Cl],
        tickspersec[0],
        IsUserLagging(userid) ? "yes" : "no",
        HasValidAngles(Cl) ? "yes" : "no",
        isCmdnumSequential(userid) ? "yes" : "no",
        isTickcountInOrder(userid) ? "yes" : "no"
    );
}

void StacLogMouse(int userid)
{
    int Cl = GetClientOfUserId(userid);
    //if (GetRandomInt(1, 5) == 1)
    //{
    //    QueryClientConVar(Cl, "sensitivity", ConVarCheck);
    //}
    // init vars for mouse movement - weightedx and weightedy
    int wx;
    int wy;
    // scale mouse movement to sensitivity
    if (sensFor[Cl] != 0.0)
    {
        wx = abs(RoundFloat(clmouse[Cl][0] * ( 1 / sensFor[Cl])));
        wy = abs(RoundFloat(clmouse[Cl][1] * ( 1 / sensFor[Cl])));
    }
    StacLog
    (
        "\
        \nMouse Movement (sens weighted):\
        \n abs(x): %i\
        \n abs(y): %i\
        \nMouse Movement (unweighted):\
        \n x: %i\
        \n y: %i\
        \nClient Sens:\
        \n %f\
        ",
        wx,
        wy,
        clmouse[Cl][0],
        clmouse[Cl][1],
        sensFor[Cl]
    );
    // log buttons whenever we log mouse
    StacLogButtons(userid);
}

void StacLogAngles(int userid)
{
    int Cl = GetClientOfUserId(userid);
    StacLog
    (
        "\
        \nAngles:\
        \n angles0: x %f y %f\
        \n angles1: x %f y %f\
        \n angles2: x %f y %f\
        \n angles3: x %f y %f\
        \n angles4: x %f y %f\
        ",
        clangles[Cl][0][0],
        clangles[Cl][0][1],
        clangles[Cl][1][0],
        clangles[Cl][1][1],
        clangles[Cl][2][0],
        clangles[Cl][2][1],
        clangles[Cl][3][0],
        clangles[Cl][3][1],
        clangles[Cl][4][0],
        clangles[Cl][4][1]
    );
}

void StacLogCmdnums(int userid)
{
    int Cl = GetClientOfUserId(userid);
    StacLog
    (
        "\
        \nPrevious cmdnums:\
        \n0 %i\
        \n1 %i\
        \n2 %i\
        \n3 %i\
        \n4 %i\
        \n5 %i\
        ",
        clcmdnum[Cl][0],
        clcmdnum[Cl][1],
        clcmdnum[Cl][2],
        clcmdnum[Cl][3],
        clcmdnum[Cl][4],
        clcmdnum[Cl][5]
    );
}

void StacLogTickcounts(int userid)
{
    int Cl = GetClientOfUserId(userid);
    StacLog
    (
        "\
        \nPrevious tickcounts:\
        \n0 %i\
        \n1 %i\
        \n2 %i\
        \n3 %i\
        \n4 %i\
        \n5 %i\
        ",
        cltickcount[Cl][0],
        cltickcount[Cl][1],
        cltickcount[Cl][2],
        cltickcount[Cl][3],
        cltickcount[Cl][4],
        cltickcount[Cl][5]
    );
}

void StacLogButtons(int userid)
{
    int Cl = GetClientOfUserId(userid);

    StacLog
    (
        "\
        \nPrevious buttons - use https://sapphonie.github.io/flags.html to convert to readable input\
        \n0 %i\
        \n1 %i\
        \n2 %i\
        \n3 %i\
        \n4 %i\
        \n5 %i\
        ",
        clbuttons[Cl][0],
        clbuttons[Cl][1],
        clbuttons[Cl][2],
        clbuttons[Cl][3],
        clbuttons[Cl][4],
        clbuttons[Cl][5]
    );
}

/********** ISVALIDCLIENT STUFF *********/

bool IsValidClient(int client)
{
    if
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && !IsClientInKickQueue(client)
        && !userBanQueued[client]
        && !IsFakeClient(client)
    )
    {
        return true;
    }
    return false;
}

bool IsValidClientOrBot(int client)
{
    if
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && !IsClientInKickQueue(client)
        && !userBanQueued[client]
        // don't bother sdkhooking stv or replay bots lol
        && !IsClientSourceTV(client)
        && !IsClientReplay(client)
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
        if (CheckCommandAccess(Cl, "sm_ban", ADMFLAG_GENERIC))
        {
            return true;
        }
    }
    return false;
}

bool IsValidSrcTV(int client)
{
    if
    (
        0 < client <= MaxClients
        && IsClientInGame(client)
        && IsClientSourceTV(client)
    )
    {
        return true;
    }
    return false;
}

/********** MISC FUNCS **********/

void BanUser(int userid, char[] reason, char[] pubreason)
{
    int Cl = GetClientOfUserId(userid);

    // prevent double bans
    if (userBanQueued[Cl])
    {
        KickClient(Cl, "Banned by StAC");
        return;
    }

    StacGeneralPlayerNotify(userid, reason);
    // make sure we dont detect on already banned players
    userBanQueued[Cl] = true;

    // check if client is authed before banning normally
    bool isAuthed = IsClientAuthorized(Cl);

    if (demonameInBanReason)
    {
        if (GetDemoName())
        {
            char demoname_plus[256];
            strcopy(demoname_plus, sizeof(demoname_plus), demoname);
            Format(demoname_plus, sizeof(demoname_plus), ". Demo file: %s", demoname_plus);
            StrCat(reason, 256, demoname_plus);
            StacLog("Reason: %s", reason);
        }
        else
        {
            StacLog("No STV demo is being recorded, no demo name will be printed to the ban reason!");
        }
    }
    if (isAuthed)
    {
        if (SOURCEBANS)
        {
            SBPP_BanPlayer(0, Cl, banDuration, reason);
            // there's no return value for that native, so we have to just assume it worked lol
            return;
        }
        if (MATERIALADMIN && MABanPlayer(0, Cl, MA_BAN_STEAM, banDuration, reason))
        {
            return;
        }
        if (GBANS)
        {
            ServerCommand("gb_ban %i, %i, %s", userid, banDuration, reason);
            // there's no return value nor a native for gbans bans (YET), so we have to just assume it worked lol
            return;
        }
        // stock tf2, no ext ban system. if we somehow fail here, keep going.
        if (BanClient(Cl, banDuration, BANFLAG_AUTO, reason, reason, _, _))
        {
            return;
        }
    }
    // if we got here steam is being fussy or the client is not auth'd in some way, or the stock tf2 ban failed somehow.
    StacLog("Client %N is not authorized, steam is down, or the ban failed for some other reason. Attempting to ban with cached SteamID...", Cl);
    // if this returns true, we can still ban the client with their steamid in a roundabout and annoying way.
    if (!IsActuallyNullString(SteamAuthFor[Cl]))
    {
        ServerCommand("sm_addban %i \"%s\" %s", banDuration, SteamAuthFor[Cl], reason);
        KickClient(Cl, "%s", reason);
    }
    // if the above returns false, we can only do ip :/
    else
    {
        char ip[16];
        GetClientIP(Cl, ip, sizeof(ip));

        StacLog("No cached SteamID for %N! Banning with IP %s...", Cl, ip);
        ServerCommand("sm_banip %s %i %s", ip, banDuration, reason);
        // this kick client might not be needed - you get kicked by "being added to ban list"
        // KickClient(Cl, "%s", reason);
    }

    MC_PrintToChatAll("%s", pubreason);
    StacLog("%s", pubreason);
}

bool GetDemoName()
{
    if (SOURCETVMGR)
    {
        demotick = SourceTV_GetRecordingTick();
        if (!SourceTV_GetDemoFileName(demoname, sizeof(demoname)))
        {
            demoname = "N/A";
            return false;
        }

        return true;
    }

    else
    {
        char tvStatus[512];
        ServerCommandEx(tvStatus, sizeof(tvStatus), "tv_status");
        char demoname_etc[128];
        if (MatchRegex(demonameRegex, tvStatus) > 0)
        {
            if (GetRegexSubString(demonameRegex, 0, demoname_etc, sizeof(demoname_etc)))
            {
                TrimString(demoname_etc);
                if (MatchRegex(demonameRegexFINAL, demoname_etc) > 0)
                {
                    if (GetRegexSubString(demonameRegexFINAL, 0, demoname, sizeof(demoname)))
                    {
                        TrimString(demoname);
                        StripQuotes(demoname);
                        return true;
                    }
                }
            }
        }
        demoname = "N/A";
        demotick = -1;

        return false;
    }
}

bool isDefaultTickrate()
{
    // Hack! Sometimes tps is set as default when it really isn't
    if (tps == 0)
    {
        DoTPSMath();
        LogMessage("redoing tps math");
    }
    if (tps > 60.0 && tps < 70.0)
    {
        return true;
    }
    return false;
}

void calcTPSfor(int Cl)
{
    t[Cl]++;
    if (GetEngineTime() - 1.0 >= secTime[Cl])
    {
        secTime[Cl] = GetEngineTime();
        tickspersec[Cl] = t[Cl];
        t[Cl] = 0;
    }
}

bool IsActuallyNullString(char[] somestring)
{
    if (somestring[0] != '\0')
    {
        return false;
    }
    return true;
}

bool IsHalloweenCond(TFCond condition)
{
    if
    (
           condition == TFCond_HalloweenKart
        || condition == TFCond_HalloweenKartDash
        || condition == TFCond_HalloweenThriller
        || condition == TFCond_HalloweenBombHead
        || condition == TFCond_HalloweenGiant
        || condition == TFCond_HalloweenTiny
        || condition == TFCond_HalloweenInHell
        || condition == TFCond_HalloweenGhostMode
        || condition == TFCond_HalloweenKartNoTurn
        || condition == TFCond_HalloweenKartCage
        || condition == TFCond_SwimmingCurse
    )
    {
        return true;
    }
    return false;
}

/********** MISC CLIENT CHECKS **********/

// is client on a team and not dead
bool IsClientPlaying(int client)
{
    TFTeam team = TF2_GetClientTeam(client);
    if
    (
        IsPlayerAlive(client)
        &&
        (
            team != TFTeam_Unassigned
            &&
            team != TFTeam_Spectator
        )
    )
    {
        return true;
    }
    return false;
}

/********** PRINT HELPER FUNCS **********/

// print colored chat to all server/sourcemod admins
void PrintToImportant(const char[] format, any ...)
{
    char buffer[254];

    // print translations in the servers lang first
    SetGlobalTransTarget(LANG_SERVER);
    // format it properly
    VFormat(buffer, sizeof(buffer), format, 2);
    // print detections to staclog as well
    if (StrContains(buffer, "detect", false) != -1)
    {
        // seperate detections with a lotta whitespace for easier readability
        StacLog("\n\n----------\n\n%s", buffer);
    }
    buffer[0] = '\0';

    for (int i = 1; i <= MaxClients; i++)
    {
        // If this cvar is 0 (default), StAC will print detections to admins with sm_ban access and to SourceTV, if extant.
        // If this cvar is 1, it will print only to SourceTV.
        // If this cvar is 2, StAC never print anything in chat to anyone, ever.
        // If this cvar is -1, StAC will print ALL detections to ALL players

        if
        (
            (silent == -1 && (IsValidClient(i) || IsValidSrcTV(i)))
            ||
            (silent == 0 && (IsValidAdmin(i) || IsValidSrcTV(i)))
            ||
            (silent == 1 && IsValidSrcTV(i))
        )
        {
            SetGlobalTransTarget(i);
            VFormat(buffer, sizeof(buffer), format, 2);
            MC_PrintToChat(i, "%s", buffer);
        }
    }
}

// print to all server/sourcemod admin's consoles
void PrintToConsoleAllAdmins(const char[] format, any ...)
{
    char buffer[254];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidAdmin(i) || IsValidSrcTV(i))
        {
            SetGlobalTransTarget(i);
            VFormat(buffer, sizeof(buffer), format, 2);
            PrintToConsole(i, "%s", buffer);
        }
    }
}

/********** MATH STUFF **********/

int min(int a, int b)
{
    return a < b ? a : b;
}

int max(int a, int b)
{
    return a > b ? a : b;
}

int clamp(int num, int minnum, int maxnum)
{
    num  = max(num, minnum);
    return min(num, maxnum);
}

any abs(any x)
{
    return x > 0 ? x : -x;
}

float RoundToPlace(float input, int decimalPlaces)
{
    float poweroften = Pow(10.0, float(decimalPlaces));
    return RoundToNearest(input * poweroften) / (poweroften);
}

bool IsZeroVector(const float vec[3])
{
    if
    (
           vec[0] == 0.0
        && vec[1] == 0.0
        && vec[2] == 0.0
    )
    {
        return true;
    }
    return false;
}

/********** UPDATER **********/

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}

/********** DETECTIONS & DISCORD **********/





void StacGeneralPlayerNotify(int userid, const char[] format, any ...)
{
    StacLogDemo();

    if (!DISCORD)
    {
        return;
    }

    JSON_Array hFields = new JSON_Array();

    // detection message generated from our format string
    char detectMsg[256];
    VFormat(detectMsg, sizeof(detectMsg), format, 3);

    // get name
    int Cl = GetClientOfUserId(userid);
    char ClName[64];
    GetClientName(Cl, ClName, sizeof(ClName));
    json_escape_string(ClName, sizeof(ClName));

    json_escape_string(detectMsg, sizeof(detectMsg));

    json_escape_string(demoname, sizeof(demoname));
 
    json_escape_string(hostname, sizeof(hostname));

    // we technically store the url in this so it has to be bigger
    char steamid[96];
    // ok we store these on client connect & auth, this shouldn't be null
    if (!IsActuallyNullString(SteamAuthFor[Cl]))
    {
        // make this a clickable link in discord
        Format(steamid, sizeof(steamid), "[%s](https://steamid.io/lookup/%s)", SteamAuthFor[Cl], SteamAuthFor[Cl]);
    }
    // if it is, that means the plugin reloaded or steam is being fussy.
    else
    {
        steamid = "N/A";
    }

    char strDemotick[64];
    Format(strDemotick, sizeof(strDemotick), "%i", demotick );

    char strUnixTimestamp[64];
    Format(strUnixTimestamp, sizeof(strUnixTimestamp), "%i", GetTime() );

    PushField(hFields, "Player", ClName);
    PushField(hFields, "SteamID", steamid);
    PushField(hFields, "Message", detectMsg);
    PushField(hFields, "Hostname", hostname);
    PushField(hFields, "Server IP", hostipandport);
    PushField(hFields, "Current Demo", demoname);
    PushField(hFields, "Demo Tick", strDemotick );
    PushField(hFields, "Unix timestamp", strUnixTimestamp );


    JSON_Object hEmbed = new JSON_Object();
    hEmbed.EnableOrderedKeys();

    hEmbed.SetValue("color", 16738740);
    hEmbed.SetString("title", "StAC Detection!");
    hEmbed.SetString("avatar_url", "https://i.imgur.com/RKRaLPl.png");
    hEmbed.SetObject("fields", hFields);

    JSON_Array hEmbeds = new JSON_Array();
    hEmbeds.EnableOrderedKeys();

    hEmbeds.PushObject(hEmbed);

    JSON_Object hObj = new JSON_Object();
    hObj.EnableOrderedKeys();

    hObj.SetObject("embeds", hEmbeds);

    char ourjson[2048];
    hObj.Encode(ourjson, 2048);

    // Do the thing?
    SendMessageToDiscord(ourjson);

    json_cleanup_and_delete(hObj);
}

static void PushField(JSON_Array hFields, const char[] name, const char[] value)
{
    JSON_Object hField = new JSON_Object();
    hField.EnableOrderedKeys();
    hField.SetString("name", name);
    hField.SetString("value", value);
    hFields.PushObject(hField);
}   

void StacDetectionNotify(int userid, char[] type, int detections)
{
    StacLogDemo();

    if (!DISCORD)
    {
        return;
    }

    static char detectionTemplate[2048] = \
    "{ \"embeds\": \
        [{ \"title\": \"StAC Detection!\", \"color\": 16738740, \"fields\":\
            [\
                { \"name\": \"Player\",         \"value\": \"%N\" } ,\
                { \"name\": \"SteamID\",        \"value\": \"%s\" } ,\
                { \"name\": \"Detection type\", \"value\": \"%s\" } ,\
                { \"name\": \"Detection\",      \"value\": \"%i\" } ,\
                { \"name\": \"Hostname\",       \"value\": \"%s\" } ,\
                { \"name\": \"Server IP\",      \"value\": \"%s\" } ,\
                { \"name\": \"Current Demo\",   \"value\": \"%s\" } ,\
                { \"name\": \"Demo Tick\",      \"value\": \"%i\" } ,\
                { \"name\": \"Unix timestamp\", \"value\": \"%i\" } \
            ]\
        }],\
        \"avatar_url\": \"https://i.imgur.com/RKRaLPl.png\"\
    }";

    char msg[1024];

    int Cl = GetClientOfUserId(userid);
    char ClName[64];
    GetClientName(Cl, ClName, sizeof(ClName));
    Discord_EscapeString(ClName, sizeof(ClName));

    // we technically store the url in this so it has to be bigger
    char steamid[96];
    // ok we store these on client connect & auth, this shouldn't be null
    if (!IsActuallyNullString(SteamAuthFor[Cl]))
    {
        // make this a clickable link in discord
        Format(steamid, sizeof(steamid), "[%s](https://steamid.io/lookup/%s)", SteamAuthFor[Cl], SteamAuthFor[Cl]);
    }
    // if it is, that means the plugin reloaded or steam is being fussy.
    else
    {
        steamid = "N/A";
    }

    Format
    (
        msg,
        sizeof(msg),
        detectionTemplate,
        Cl,
        steamid,
        type,
        detections,
        hostname,
        hostipandport,
        demoname,
        demotick,
        GetTime()
    );

    SendMessageToDiscord(msg);
}

void SendMessageToDiscord(char[] message)
{
    char webhook[32] = "stac";
    Discord_SendMessage(webhook, message);
}

void checkOS()
{
    // only need the beginning of this
    char cmdline[32];
    GetCommandLine(cmdline, sizeof(cmdline));

    if (StrContains(cmdline, "./srcds_linux ", false) != -1)
    {
        os = "linux";
    }
    else if (StrContains(cmdline, ".exe", false) != -1)
    {
        os = "windows";
    }
    else
    {
        os = "unknown";
    }
}
