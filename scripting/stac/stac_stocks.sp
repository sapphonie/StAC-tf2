/********** StacLog functions **********/

// Open log file for StAC
void OpenStacLog()
{
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
    delete StacLogFile;
}

// log to StAC log file
void StacLog(const char[] format, any ...)
{
    char buffer[254];
    VFormat(buffer, sizeof(buffer), format, 2);
    // clear color tags
    MC_RemoveTags(buffer, sizeof(buffer));

    if (StacLogFile != null)
    {
        LogToOpenFile(StacLogFile, buffer);
    }
    else if (logtofile)
    {
        LogMessage("[StAC] File handle invalid!");
        LogMessage("%s", buffer);
    }
    else
    {
        LogMessage("%s", buffer);
    }
    PrintToConsoleAllAdmins("%s", buffer);
}

void StacLogDemo()
{
    if (GetDemoName())
    {
        StacLog("Demo file: %s", demoname);
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
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && !IsClientInKickQueue(client)
        && !userBanQueued[client]
        && !IsFakeClient(client)
    );
}

bool IsValidClientOrBot(int client)
{
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && !IsClientInKickQueue(client)
        && !userBanQueued[client]
        // don't bother sdkhooking stv or replay bots lol
        && !IsClientSourceTV(client)
        && !IsClientReplay(client)
    );
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
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && IsClientSourceTV(client)
    );
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
            StacLog("[StAC] No STV demo is being recorded, no demo name will be printed to the ban reason!");
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
            ServerCommand("gb_ban %i, banDuration, %s", userid, reason);
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

        StacLog("[StAC] No cached SteamID for %N! Banning with IP %s...", Cl, ip);
        ServerCommand("sm_banip %s %i %s", ip, banDuration, reason);
        // this kick client might not be needed - you get kicked by "being added to ban list"
        // KickClient(Cl, "%s", reason);
    }

    MC_PrintToChatAll("%s", pubreason);
    StacLog("%s", pubreason);
}

bool GetDemoName()
{
    // TODO: SourceTVManager
    // TODO: Demoticks
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
    return false;
}

bool isDefaultTickrate()
{
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

// sourcemod is fucking ridiculous, "IsNullString" only checks for a specific definition of nullstring
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
        // "[StAC] If this cvar is 0 (default), StAC will print detections to admins with sm_ban access and to SourceTV, if extant. If this cvar is 1, it will print only to SourceTV. If this cvar is 2, StAC never print anything in chat to anyone, ever. If this cvar is -1, StAC will print ALL detections to ALL players. \n(recommended 0)",

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
    static char generalTemplate[1024] = \
    "{ \"embeds\": [ { \"title\": \"StAC Message\", \"color\": 16738740, \"fields\": [ { \"name\": \"Player\", \"value\": \"%N\" } , { \"name\": \"SteamID\", \"value\": \"%s\" }, { \"name\": \"Message\", \"value\": \"%s\" }, { \"name\": \"Hostname\", \"value\": \"%s\" }, { \"name\": \"IP\", \"value\": \"%s\" } , { \"name\": \"Current Demo Recording\", \"value\": \"%s\" } ] } ] }";

    char msg[1024];

    char message[256];
    VFormat(message, sizeof(message), format, 3);

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
        generalTemplate,
        Cl,
        steamid,
        message,
        hostname,
        hostipandport,
        demoname
    );
    SendMessageToDiscord(msg);
}

void StacDetectionNotify(int userid, char[] type, int detections)
{
    StacLogDemo();

    if (!DISCORD)
    {
        return;
    }

    static char detectionTemplate[1024] = \
    "{ \"embeds\": [ { \"title\": \"StAC Detection!\", \"color\": 16738740, \"fields\": [ { \"name\": \"Player\", \"value\": \"%N\" } , { \"name\": \"SteamID\", \"value\": \"%s\" }, { \"name\": \"Detection type\", \"value\": \"%s\" }, { \"name\": \"Detection\", \"value\": \"%i\" }, { \"name\": \"Hostname\", \"value\": \"%s\" }, { \"name\": \"IP\", \"value\": \"%s\" } , { \"name\": \"Current Demo Recording\", \"value\": \"%s\" } , { \"name\": \"Unix timestamp of detection\", \"value\": \"%i\" } ] } ] }";

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
        GetTime()
    );
    SendMessageToDiscord(msg);
}

void SendMessageToDiscord(char[] message)
{
    char webhook[32] = "stac";
    Discord_SendMessage(webhook, message);
}
