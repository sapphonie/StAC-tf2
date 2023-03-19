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
    int cl = GetClientOfUserId(userid);

    StacLog
    ("\
        \n Player: %L\
        \n StAC cached SteamID: %s\
        ",
        cl,
        SteamAuthFor[cl]
    );
}

void StacLogNetData(int userid)
{
    int cl = GetClientOfUserId(userid);

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
        pingFor[cl],
        lossFor[cl],
        inchokeFor[cl],
        outchokeFor[cl],
        chokeFor[cl],
        rateFor[cl],
        ppsFor[cl]
    );

    StacLog
    (
        "\
        \nMore network:\
        \n Approx client cmdrate: ≈%i cmd/sec\
        \n Approx server tickrate: ≈%i tick/sec\
        \n Failing lag check? %s\
        \n SequentialCmdnum? %s\
        ",
        tickspersec[cl],
        tickspersec[0],
        IsUserLagging(cl) ? "yes" : "no",
        isCmdnumSequential(cl) ? "yes" : "no"
    );
}

void StacLogMouse(int userid)
{
    int cl = GetClientOfUserId(userid);
    //if (GetRandomInt(1, 5) == 1)
    //{
    //    QueryClientConVar(Cl, "sensitivity", ConVarCheck);
    //}
    // init vars for mouse movement - weightedx and weightedy
    int wx;
    int wy;
    // scale mouse movement to sensitivity
    if (sensFor[cl] != 0.0)
    {
        wx = abs(RoundFloat(clmouse[cl][0] * ( 1 / sensFor[cl])));
        wy = abs(RoundFloat(clmouse[cl][1] * ( 1 / sensFor[cl])));
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
        clmouse[cl][0],
        clmouse[cl][1],
        sensFor[cl]
    );
    // log buttons whenever we log mouse
    StacLogButtons(userid);
}

void StacLogAngles(int userid)
{
    int cl = GetClientOfUserId(userid);
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
        clangles[cl][0][0],
        clangles[cl][0][1],
        clangles[cl][1][0],
        clangles[cl][1][1],
        clangles[cl][2][0],
        clangles[cl][2][1],
        clangles[cl][3][0],
        clangles[cl][3][1],
        clangles[cl][4][0],
        clangles[cl][4][1]
    );
    StacLog
    (
        "\
        \nClient eye positions:\
        \n eyepos 0: x %.3f y %.3f z %.3f\
        \n eyepos 1: x %.3f y %.3f z %.3f\
        ",
        clpos[cl][0][0],
        clpos[cl][0][1],
        clpos[cl][0][2],
        clpos[cl][1][0],
        clpos[cl][1][1],
        clpos[cl][1][2]
    );
}

void StacLogCmdnums(int userid)
{
    int cl = GetClientOfUserId(userid);
    StacLog
    (
        "\
        \nPrevious cmdnums:\
        \n0 %i\
        \n1 %i\
        \n2 %i\
        \n3 %i\
        \n4 %i\
        ",
        clcmdnum[cl][0],
        clcmdnum[cl][1],
        clcmdnum[cl][2],
        clcmdnum[cl][3],
        clcmdnum[cl][4]
    );
}

void StacLogTickcounts(int userid)
{
    int cl = GetClientOfUserId(userid);
    StacLog
    (
        "\
        \nPrevious tickcounts:\
        \n0 %i\
        \n1 %i\
        \n2 %i\
        \n3 %i\
        \n4 %i\
        ",
        cltickcount[cl][0],
        cltickcount[cl][1],
        cltickcount[cl][2],
        cltickcount[cl][3],
        cltickcount[cl][4]
    );
    StacLog
    (
        "\
        \nCurrent server tick:\
        \n%i\
        ",
        GetGameTickCount()
    );
}

void StacLogButtons(int userid)
{
    int cl = GetClientOfUserId(userid);

    StacLog
    (
        "\
        \nPrevious buttons - use https://sapphonie.github.io/flags.html to convert to readable input\
        \n0 %i\
        \n1 %i\
        \n2 %i\
        \n3 %i\
        \n4 %i\
        ",
        clbuttons[cl][0],
        clbuttons[cl][1],
        clbuttons[cl][2],
        clbuttons[cl][3],
        clbuttons[cl][4]
    );
}

/********** ISVALIDCLIENT STUFF *********/

bool IsValidClient(int cl)
{
    if
    (
        (0 < cl <= MaxClients)
        && IsClientInGame(cl)
        && !IsClientInKickQueue(cl)
        && !userBanQueued[cl]
        && !IsFakeClient(cl)
    )
    {
        return true;
    }
    return false;
}

bool IsValidClientOrBot(int cl)
{
    if
    (
        (0 < cl <= MaxClients)
        && IsClientInGame(cl)
        && !IsClientInKickQueue(cl)
        && !userBanQueued[cl]
        // don't bother sdkhooking stv or replay bots lol
        && !IsClientSourceTV(cl)
        && !IsClientReplay(cl)
    )
    {
        return true;
    }
    return false;
}

bool IsValidAdmin(int cl)
{
    if (IsValidClient(cl))
    {
        // can this client ban, or are they me, sappho?
        if
        (
            CheckCommandAccess(cl, "sm_ban", ADMFLAG_GENERIC)
            //|| Maybe someday, w/ stac_telemetry. Not today. -sappho
            //StrEqual(SteamAuthFor[cl], "STEAM_0:1:124178191")
        )
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
    int cl = GetClientOfUserId(userid);

    // prevent double bans
    if (userBanQueued[cl])
    {
        KickClient(cl, "Banned by StAC");
        return;
    }

    StacGeneralPlayerNotify(userid, reason);
    // make sure we dont detect on already banned players
    userBanQueued[cl] = true;

    // check if client is authed before banning normally
    bool isAuthed = IsClientAuthorized(cl);

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
        //else
        //{
        //    StacLog("No STV demo is being recorded, no demo name will be printed to the ban reason!");
        //}
    }
    if (isAuthed)
    {
        if (SOURCEBANS)
        {
            SBPP_BanPlayer(0, cl, banDuration, reason);
            // there's no return value for that native, so we have to just assume it worked lol
            return;
        }
        if (MATERIALADMIN && MABanPlayer(0, cl, MA_BAN_STEAM, banDuration, reason))
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
        if (BanClient(cl, banDuration, BANFLAG_AUTO, reason, reason, _, _))
        {
            return;
        }
    }
    // if we got here steam is being fussy or the client is not auth'd in some way, or the stock tf2 ban failed somehow.
    StacLog("Client %N is not authorized, steam is down, or the ban failed for some other reason. Attempting to ban with cached SteamID...", cl);
    // if this returns true, we can still ban the client with their steamid in a roundabout and annoying way.
    if (!IsActuallyNullString(SteamAuthFor[cl]))
    {
        ServerCommand("sm_addban %i \"%s\" %s", banDuration, SteamAuthFor[cl], reason);
        KickClient(cl, "%s", reason);
    }
    // if the above returns false, we can only do ip :/
    else
    {
        char ip[16];
        GetClientIP(cl, ip, sizeof(ip));

        StacLog("No cached SteamID for %N! Banning with IP %s...", cl, ip);
        ServerCommand("sm_banip %s %i %s", ip, banDuration, reason);
        // this kick client might not be needed - you get kicked by "being added to ban list"
        // KickClient(cl, "%s", reason);
    }

    MC_PrintToChatAll("%s", pubreason);
    StacLog("%s", pubreason);
}

bool GetDemoName()
{
    demotick = SourceTV_GetRecordingTick();
    if (!SourceTV_GetDemoFileName(demoname, sizeof(demoname)))
    {
        demoname = "N/A";
        return false;
    }

    return true;
}

bool isDefaultTickrate()
{
    // Hack! Sometimes tps is set as default when it really isn't
    if (tps == 0)
    {
        DoTPSMath();
    }
    // 66.66666 -> 67
    if (itps == 67)
    {
        return true;
    }
    return false;
}

void calcTPSfor(int cl)
{
    t[cl]++;
    if (GetEngineTime() - 1.0 >= secTime[cl])
    {
        secTime[cl] = GetEngineTime();
        tickspersec[cl] = t[cl];
        t[cl] = 0;
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
            team != TFTeam_Unassigned && team != TFTeam_Spectator
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

/*
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
*/


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

    static char generalTemplate[] = \
    "{ \"embeds\": \
        [{ \"title\": \"StAC Client Message!\", \"color\": 16738740, \"fields\":\
            [\
                { \"name\": \"Player\",             \"value\": \"%N\", \"inline\": true },\
                { \"name\": \"SteamID\",            \"value\": \"%s\", \"inline\": true },\
                { \"name\": \" \",                  \"value\": \" \" },\
                { \"name\": \"Message\",            \"value\": \"%s\", \"inline\": true },\
                { \"name\": \" \",                  \"value\": \" \" },\
                { \"name\": \"Hostname\",           \"value\": \"%s\", \"inline\": true },\
                { \"name\": \"Server IP\",          \"value\": \"%s\", \"inline\": true },\
                { \"name\": \" \",                  \"value\": \" \" },\
                { \"name\": \"Current Demo\",       \"value\": \"%s\", \"inline\": true },\
                { \"name\": \"Demo Tick\",          \"value\": \"%i\", \"inline\": true },\
                { \"name\": \" \",                  \"value\": \" \" },\
                { \"name\": \"Server tick\",        \"value\": \"%i\", \"inline\": true },\
                { \"name\": \"Unix timestamp\",     \"value\": \"%i\", \"inline\": true }\
            ]\
        }],\
        \"avatar_url\": \"https://i.imgur.com/RKRaLPl.png\"\
    }";

    char msg[8192];


    char fmtmsg[256];
    VFormat(fmtmsg, sizeof(fmtmsg), format, 3);

    int cl = GetClientOfUserId(userid);
    char ClName[64];
    GetClientName(cl, ClName, sizeof(ClName));
    Discord_EscapeString(ClName, sizeof(ClName));

    // we technically store the url in this so it has to be bigger
    char steamid[96];
    // ok we store these on client connect & auth, this shouldn't be null
    if (!IsActuallyNullString(SteamAuthFor[cl]))
    {
        // make this a clickable link in discord
        Format(steamid, sizeof(steamid), "[%s](https://steamid.io/lookup/%s)", SteamAuthFor[cl], SteamAuthFor[cl]);
    }
    // if it is, that means the plugin reloaded or steam is being fussy.
    else
    {
        steamid = "N/A";
    }

    char hostname[256];
    GetConVarString(FindConVar("hostname"), hostname, sizeof(hostname));

    Format
    (
        msg,
        sizeof(msg),
        generalTemplate,
        cl,
        steamid,
        fmtmsg,
        hostname,
        hostipandport,
        demoname,
        demotick,
        servertick,
        GetTime()
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

    static char detectionTemplate[] = \
    "{ \"embeds\": \
        [{ \"title\": \"StAC Detection!\", \"color\": 16738740, \"fields\":\
            [\
                { \"name\": \"Player\",             \"value\": \"%N\", \"inline\": true },\
                { \"name\": \"SteamID\",            \"value\": \"%s\", \"inline\": true },\
                { \"name\": \" \",                  \"value\": \" \" },\
                { \"name\": \"Detection type\",     \"value\": \"%s\", \"inline\": true },\
                { \"name\": \"Detection #\",          \"value\": \"%i\", \"inline\": true },\
                { \"name\": \" \",                  \"value\": \" \" },\
                { \"name\": \"Hostname\",           \"value\": \"%s\", \"inline\": true },\
                { \"name\": \"Server IP\",          \"value\": \"%s\", \"inline\": true },\
                { \"name\": \" \",                  \"value\": \" \" },\
                { \"name\": \"Current Demo\",       \"value\": \"%s\", \"inline\": true },\
                { \"name\": \"Demo Tick\",          \"value\": \"%i\", \"inline\": true },\
                { \"name\": \" \",                  \"value\": \" \" },\
                { \"name\": \"Server tick\",        \"value\": \"%i\", \"inline\": true },\
                { \"name\": \"Unix timestamp\",     \"value\": \"%i\", \"inline\": true },\
                { \"name\": \" \",                  \"value\": \" \" },\
                { \"name\": \"viewangle history\",  \"value\":\
               \"```==----pitch---yaw-----roll-----\\n\
                    0 | %7.2f %7.2f %7.2f\\n\
                    1 | %7.2f %7.2f %7.2f\\n\
                    2 | %7.2f %7.2f %7.2f\\n\
                    3 | %7.2f %7.2f %7.2f\\n\
                    4 | %7.2f %7.2f %7.2f\\n```\"\
                }, \
                { \"name\": \"eye position history\",  \"value\":\
               \"```==-----x--------y--------z---------\\n\
                    0 | %8.2f %8.2f %8.2f\\n\
                    1 | %8.2f %8.2f %8.2f\\n```\"\
                }, \
                { \
                \"name\": \"cmdnum history\",       \"value\":\
                \"approx client sequence number\\n\
                ```\
                    0 | %i\\n\
                    1 | %i\\n\
                    2 | %i\\n\
                    3 | %i\\n\
                    4 | %i\\n```\",\
                    \"inline\": true \
                }, \
                { \
                \"name\": \"tickcount history\",    \"value\":\
                \"approx client gpGlobals->tickcount\\n\
                ```\
                    0 | %i\\n\
                    1 | %i\\n\
                    2 | %i\\n\
                    3 | %i\\n\
                    4 | %i\\n```\",\
                    \"inline\": true \
                }, \
                { \
                \"name\": \"buttons history\",      \"value\":\
                \"convert to button flags [here](https://sapphonie.github.io/flags.html)\\n\
                    ```\
                    0 | %i\\n\
                    1 | %i\\n\
                    2 | %i\\n\
                    3 | %i\\n\
                    4 | %i\\n```\",\
                    \"inline\": true \
                }, \
                { \
                \"name\": \"network info\",         \"value\":\
                \"```\
                    ping               | %7.2fms\\n\
                    loss               | %7.2f%%\\n\
                    inchoke            | %7.2f%%\\n\
                    outchoke           | %7.2f%%\\n\
                    totalchoke         | %7.2f%%\\n\
                    rate               | %7.2fkbps\\n\
                    approx packets/sec | %7.2f\\n\
                    approx usrcmds/sec | %7i\\n```\"\
                } \
            ]\
        }], \
        \"avatar_url\": \"https://i.imgur.com/RKRaLPl.png\"\
    }";


    char msg[8192];

    int cl = GetClientOfUserId(userid);
    char ClName[64];
    GetClientName(cl, ClName, sizeof(ClName));
    Discord_EscapeString(ClName, sizeof(ClName));

    // we technically store the url in this so it has to be bigger
    char steamid[96];
    // ok we store these on client connect & auth, this shouldn't be null
    if (!IsActuallyNullString(SteamAuthFor[cl]))
    {
        // make this a clickable link in discord
        Format(steamid, sizeof(steamid), "[%s](https://steamid.io/lookup/%s)", SteamAuthFor[cl], SteamAuthFor[cl]);
    }
    // if it is, that means the plugin reloaded or steam is being fussy.
    else
    {
        steamid = "N/A";
    }

    char hostname[256];
    GetConVarString(FindConVar("hostname"), hostname, sizeof(hostname));

    Format
    (
        msg,
        sizeof(msg),
        detectionTemplate,
        cl,
        steamid,
        type,
        detections,
        hostname,
        hostipandport,
        demoname,
        demotick,
        servertick,
        GetTime(),

        // angles
        clangles[cl][0][0],
        clangles[cl][0][1],
        clangles[cl][0][2],

        clangles[cl][1][0],
        clangles[cl][1][1],
        clangles[cl][1][2],

        clangles[cl][2][0],
        clangles[cl][2][1],
        clangles[cl][2][2],

        clangles[cl][3][0],
        clangles[cl][3][1],
        clangles[cl][3][2],

        clangles[cl][4][0],
        clangles[cl][4][1],
        clangles[cl][4][2],

        // eye positions
        clpos[cl][0][0],
        clpos[cl][0][1],
        clpos[cl][0][2],
        clpos[cl][1][0],
        clpos[cl][1][1],
        clpos[cl][1][2],

        // cmdnum
        clcmdnum[cl][0],
        clcmdnum[cl][1],
        clcmdnum[cl][2],
        clcmdnum[cl][3],
        clcmdnum[cl][4],

        // tickcount
        cltickcount[cl][0],
        cltickcount[cl][1],
        cltickcount[cl][2],
        cltickcount[cl][3],
        cltickcount[cl][4],

        // buttons
        clbuttons[cl][0],
        clbuttons[cl][1],
        clbuttons[cl][2],
        clbuttons[cl][3],
        clbuttons[cl][4],

        // network
        pingFor[cl],
        lossFor[cl],
        inchokeFor[cl],
        outchokeFor[cl],
        chokeFor[cl],
        rateFor[cl],
        ppsFor[cl],
        tickspersec[cl]
    );

    SendMessageToDiscord(msg);
}

void StacGeneralMessageNotify(const char[] format, any ...)
{
    StacLogDemo();

    if (!DISCORD)
    {
        return;
    }


    static char bareTemplate[] = \
    "{ \"embeds\": \
        [{ \"title\": \"StAC General Message!\", \"color\": 16738740, \"fields\":\
            [\
                { \"name\": \"Message\",            \"value\": \"%s\" },\
                { \"name\": \" \",                  \"value\": \" \" },\
                { \"name\": \"Hostname\",           \"value\": \"%s\", \"inline\": true },\
                { \"name\": \"Server IP\",          \"value\": \"%s\", \"inline\": true },\
                { \"name\": \" \",                  \"value\": \" \" },\
                { \"name\": \"Current Demo\",       \"value\": \"%s\", \"inline\": true },\
                { \"name\": \"Demo Tick\",          \"value\": \"%i\", \"inline\": true },\
                { \"name\": \" \",                  \"value\": \" \" },\
                { \"name\": \"Server tick\",        \"value\": \"%i\", \"inline\": true },\
                { \"name\": \"Unix timestamp\",     \"value\": \"%i\", \"inline\": true }\
            ]\
        }],\
        \"avatar_url\": \"https://i.imgur.com/RKRaLPl.png\"\
    }";

    char msg[8192];

    char fmtmsg[256];
    VFormat(fmtmsg, sizeof(fmtmsg), format, 2);


    char hostname[256];
    GetConVarString(FindConVar("hostname"), hostname, sizeof(hostname));

    Format
    (
        msg,
        sizeof(msg),
        bareTemplate,
        fmtmsg,
        hostname,
        hostipandport,
        demoname,
        demotick,
        servertick,
        GetTime()
    );

    SendMessageToDiscord(msg);
}


void SendMessageToDiscord(char[] message)
{
    char webhook[8] = "stac";
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
