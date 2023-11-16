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
        // chmod perms - rwxrwxr-x . it needs to be octal.
        // yes I could use the FPERM flags but pawn doesn't have constexpr and i don't want to make a mess
        // with a bunch of ORs and not being able to check it in my IDE
        static int perms = 0o775;
        if (!CreateDirectory(path, perms, false))
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

/*
    log to StAC log file
    This strips color strings, e.g.
    {color}test{color2}
    will become
    [StAC] test
*/
void StacLog(const char[] format, any ...)
{
    // crutch for reloading the plugin and still printing to our log file
    if (StacLogFile == null)
    {
        stac_log_to_file = FindConVar("stac_log_to_file");
        if (stac_log_to_file != null)
        {
            if (stac_log_to_file.BoolValue)
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

    // strip out any instances of "[StAC] " at the front of the string so we don't get double instances of it later
    ReplaceStringEx(colored_buffer, sizeof(colored_buffer), "[StAC] ", "", 7, -1, true);

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

void BanUser(int userid, char reason[128], char pubreason[256])
{
    int cl = GetClientOfUserId(userid);

    // prevent double bans
    if (userBanQueued[cl])
    {
        KickClient(cl, "Banned from server");
        return;
    }

    StacNotify(userid, reason);
    
    char cleaned_pubreason[256];
    if ( stac_generic_ban_msgs.BoolValue )
    {
        Format(reason,              sizeof(reason),             "%t", "GenericBanMsg", cl);
        Format(cleaned_pubreason,   sizeof(cleaned_pubreason),  "%t", "GenericBanAllChat", cl);
    }
    else
    {
        strcopy(cleaned_pubreason, sizeof(cleaned_pubreason), pubreason);
    }

    // make sure we dont detect on already banned players
    userBanQueued[cl] = true;

    // check if client is authed before banning normally
    bool isAuthed = IsClientAuthorized(cl);

    int banDuration = stac_ban_duration.IntValue;

    if (stac_include_demoname_in_banreason.BoolValue && SourceTV_IsRecording() && GetDemoName())
    {
        char demoname_plus[256];
        strcopy(demoname_plus, sizeof(demoname_plus), demoname);
        Format(demoname_plus, sizeof(demoname_plus), ". Demo file: %s", demoname_plus);
        StrCat(reason, 256, demoname_plus);
        StacLog("Reason: %s", reason);
    }
    if (isAuthed)
    {
        if (SOURCEBANS)
        {
            SBPP_BanPlayer(0, cl, banDuration, reason);
            // there's no return value for that native, so we have to just assume it worked lol
            return;
        }
        if (MATERIALADMIN)
        {
            MABanPlayer(0, cl, MA_BAN_STEAM, banDuration, reason);
            return;
        }
        if (GBANS)
        {
            ServerCommand("gb_ban %i, %i, %s", userid, banDuration, reason);
            // There is a native for gbans now but i don't think it can accept the server as an admin
            // GB_BanClient(0 /* ? */, userid /* ? */, cheating, banDuration, BSBanned);

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

    MC_PrintToChatAll("%s", cleaned_pubreason);
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
            (stac_silent.IntValue == -1 && (IsValidClient(i) || IsValidSrcTV(i)))
            ||
            (stac_silent.IntValue == 0 && (IsValidAdmin(i) || IsValidSrcTV(i)))
            ||
            (stac_silent.IntValue == 1 && IsValidSrcTV(i))
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

int math_min(int a, int b)
{
    return a < b ? a : b;
}

int math_max(int a, int b)
{
    return a > b ? a : b;
}

int clamp(int num, int minnum, int maxnum)
{
    num  = math_max(num, minnum);
    return math_min(num, maxnum);
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


// if our userid is 0, it's a server message without a client
// if our detections are 0, it's a client message without a detection
// otherwise, it's a detection with a number of detections
void StacNotify(int userid, const char[] prefmtedstring, int detections = 0)
{
    StacLogDemo();

    if (!DISCORD)
    {
        return;
    }

    static char output[8192 * 2];
    output[0] = 0x0;

    // individual fields

    // empty fields for spacing
    JSON_Object spacerField = new JSON_Object();
    spacerField.EnableOrderedKeys();
    spacerField.SetString("name",   " ");
    spacerField.SetString("value",  " ");
    spacerField.SetBool  ("inline", false);

    JSON_Object spacerCpy1;
    if (userid)
    {
        spacerCpy1 = spacerField.DeepCopy();
    }

    JSON_Object spacerCpy2 = spacerField.DeepCopy();
    JSON_Object spacerCpy3 = spacerField.DeepCopy();
    JSON_Object spacerCpy4 = spacerField.DeepCopy();
    JSON_Object spacerCpy5 = spacerField.DeepCopy();
    JSON_Object spacerCpy6;
    JSON_Object spacerCpy7;
    if (detections)
    {
        spacerCpy6 = spacerField.DeepCopy();
        spacerCpy7 = spacerField.DeepCopy();
    }

    // this isn't used anywhere we're just using it to copy off of
    json_cleanup_and_delete(spacerField);

    int cl = GetClientOfUserId(userid);

    JSON_Object nameField;
    JSON_Object steamIDfield;
    if (userid)
    {
        // playername
        char ClName[64];
        GetClientName(cl, ClName, sizeof(ClName));
        Discord_EscapeString(ClName, sizeof(ClName));
        json_escape_string(ClName, sizeof(ClName));

        nameField = new JSON_Object();
        nameField.EnableOrderedKeys();
        nameField.SetString("name", "Player");
        nameField.SetString("value", ClName);
        nameField.SetBool("inline", true);


        // steamid
        // we technically store the url in this so it has to be bigger
        char steamid[96];
        // ok we store these on client connect & auth, this shouldn't be null
        if ( SteamAuthFor[cl][0] )
        {
            // make this a clickable link in discord
            Format(steamid, sizeof(steamid), "[%s](https://steamid.io/lookup/%s)", SteamAuthFor[cl], SteamAuthFor[cl]);
        }
        // if it is, that means we lateloaded and the client was unauth'd.
        else
        {
            steamid = "N/A";
        }

        steamIDfield = new JSON_Object();
        steamIDfield.EnableOrderedKeys();
        steamIDfield.SetString("name", "SteamID");
        steamIDfield.SetString("value", steamid);
        steamIDfield.SetBool  ("inline", true);
    }


    // detection / notify fields
    JSON_Object detectOrMsgfield = new JSON_Object();
    detectOrMsgfield.EnableOrderedKeys();
    if (!userid)
    {
        detectOrMsgfield.SetString("name", "Message");
    }
    else if (!detections)
    {
        detectOrMsgfield.SetString("name", "Notification");
    }
    else
    {
        detectOrMsgfield.SetString("name", "Detection");
    }
    detectOrMsgfield.SetString("value", prefmtedstring);
    detectOrMsgfield.SetBool("inline", true);

    // number of detections

    JSON_Object detectNumfield;
    if (detections)
    {
        detectNumfield = new JSON_Object();
        detectNumfield.EnableOrderedKeys();
        detectNumfield.SetString("name", "Detection #");
        detectNumfield.SetInt("value", detections);
        detectNumfield.SetBool("inline", true);
    }


    // server hostname
    char hostname[256];
    GetConVarString(FindConVar("hostname"), hostname, sizeof(hostname));

    JSON_Object hostname_field = new JSON_Object();
    hostname_field.EnableOrderedKeys();
    hostname_field.SetString("name", "Hostname");
    hostname_field.SetString("value", hostname);
    hostname_field.SetBool  ("inline", true);

    // server IP - steam:///connect ??
    JSON_Object serverip_field = new JSON_Object();
    serverip_field.EnableOrderedKeys();
    serverip_field.SetString("name", "Server IP");
    serverip_field.SetString("value", hostipandport);
    serverip_field.SetBool  ("inline", true);


    // STV
    GetDemoName();


    JSON_Object demoname_field = new JSON_Object();
    demoname_field.EnableOrderedKeys();
    demoname_field.SetString("name", "Demo name");
    demoname_field.SetString("value", demoname);
    demoname_field.SetBool  ("inline", true);


    JSON_Object demotick_field = new JSON_Object();
    demotick_field.EnableOrderedKeys();
    demotick_field.SetString("name", "Demo tick");
    demotick_field.SetInt   ("value", demotick);
    demotick_field.SetBool  ("inline", true);

    float tickedTime = GetTickedTime();
    char tickedTimeStr[512];
    // 1 day
    if (tickedTime > 86400)
    {
        Format
        (
            tickedTimeStr,
            sizeof(tickedTimeStr),
            "%.2f minutes(!)\n\n\
            Source Engine has memory leaks\n\
            and suffers from \n\
            [floating point precision loss](https://www.youtube.com/watch?v=RdTJHVG_IdU)\n\
            after running for too long.\n\
            You should restart your server ASAP,\n\
            or it will become choppy,\n\
            and StAC may not work correctly!",
            tickedTime / 60.0
        );
    }
    else
    {
        Format
        (
            tickedTimeStr,
            sizeof(tickedTimeStr),
            "%.2f minutes",
            tickedTime / 60.0
        );
    }

    JSON_Object gametime_field = new JSON_Object();
    gametime_field.EnableOrderedKeys();
    gametime_field.SetString("name", "Approx server uptime");
    gametime_field.SetString("value", tickedTimeStr);
    gametime_field.SetBool  ("inline", true);


    JSON_Object servertick_field = new JSON_Object();
    servertick_field.EnableOrderedKeys();
    servertick_field.SetString("name", "Server tick");
    servertick_field.SetInt   ("value", servertick);
    servertick_field.SetBool  ("inline", true);

    int unixTimestamp = GetTime();
    char discordTimestamp[512];

    Format
    (
        discordTimestamp,
        sizeof(discordTimestamp),
        "\
        <t:%i:T> on <t:%i:D>\n\
        <t:%i:R>\
        ",
        unixTimestamp,
        unixTimestamp,
        unixTimestamp
    );



    JSON_Object discordtimestamp_field = new JSON_Object();
    discordtimestamp_field.EnableOrderedKeys();
    discordtimestamp_field.SetString("name", "Discord Timestamp");
    discordtimestamp_field.SetString("value", discordTimestamp);
    discordtimestamp_field.SetBool  ("inline", true);


    JSON_Object unixtimestamp_field = new JSON_Object();
    unixtimestamp_field.EnableOrderedKeys();
    unixtimestamp_field.SetString("name", "Unix Timestamp");
    unixtimestamp_field.SetInt   ("value", unixTimestamp);
    unixtimestamp_field.SetBool  ("inline", true);



    JSON_Object viewangle_field;
    JSON_Object clpos_field;
    JSON_Object tickcount_field;
    JSON_Object cmdnum_field;
    JSON_Object buttons_field;
    JSON_Object netinfo_field;


    if (detections)
    {
        // VIEWANGLES
        char viewangleHistoryBuf[1024];
        Format
        (
            viewangleHistoryBuf,
            sizeof(viewangleHistoryBuf),
            "```\
                ==----pitch---yaw-----roll-----\n\
                0 | %7.2f %7.2f %7.2f\n\
                1 | %7.2f %7.2f %7.2f\n\
                2 | %7.2f %7.2f %7.2f\n\
                3 | %7.2f %7.2f %7.2f\n\
                4 | %7.2f %7.2f %7.2f\n\
            ```",

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
                clangles[cl][4][2]
        );


        viewangle_field = new JSON_Object();
        viewangle_field.EnableOrderedKeys();
        viewangle_field.SetString("name", "viewangle history");
        viewangle_field.SetString("value", viewangleHistoryBuf);
        viewangle_field.SetBool  ("inline", false);


        // EYE POSITIONS
        char eyeposBuf[1024];
        Format
        (
            eyeposBuf,
            sizeof(eyeposBuf),

            "```\
            ==-----x--------y--------z---------\n\
            0 | %8.2f %8.2f %8.2f\n\
            1 | %8.2f %8.2f %8.2f\n\
            ```",

            // eye positions
            clpos[cl][0][0],
            clpos[cl][0][1],
            clpos[cl][0][2],
            clpos[cl][1][0],
            clpos[cl][1][1],
            clpos[cl][1][2]
        );

        clpos_field = new JSON_Object();
        clpos_field.EnableOrderedKeys();
        clpos_field.SetString("name", "eye position history");
        clpos_field.SetString("value", eyeposBuf);
        clpos_field.SetBool  ("inline", false);

        // CMDNUMS
        char cmdnumBuf[1024];
        Format
        (
            cmdnumBuf,
            sizeof(cmdnumBuf),

            "[what's this?](https://github.com/VSES/SourceEngine2007/blob/43a5c90a5ada1e69ca044595383be67f40b33c61/se2007/game/client/in_main.cpp#L1008)\n```\
                0 | %i\n\
                1 | %i\n\
                2 | %i\n\
                3 | %i\n\
                4 | %i\n\
            ```",

            // cmdnum
            clcmdnum[cl][0],
            clcmdnum[cl][1],
            clcmdnum[cl][2],
            clcmdnum[cl][3],
            clcmdnum[cl][4]
        );

        cmdnum_field = new JSON_Object();
        cmdnum_field.EnableOrderedKeys();
        cmdnum_field.SetString("name", "cmdnum history");
        cmdnum_field.SetString("value", cmdnumBuf);
        cmdnum_field.SetBool  ("inline", true);

        // TICKCOUNTS
        char tickcountBuf[1024];
        Format
        (
            tickcountBuf,
            sizeof(tickcountBuf),

            "[what's this?](https://github.com/VSES/SourceEngine2007/blob/43a5c90a5ada1e69ca044595383be67f40b33c61/se2007/game/client/in_main.cpp#L1009)\n```\
                0 | %i\n\
                1 | %i\n\
                2 | %i\n\
                3 | %i\n\
                4 | %i\n\
            ```",

            // tickcount
            cltickcount[cl][0],
            cltickcount[cl][1],
            cltickcount[cl][2],
            cltickcount[cl][3],
            cltickcount[cl][4]
        );


        tickcount_field = new JSON_Object();
        tickcount_field.EnableOrderedKeys();
        tickcount_field.SetString("name", "tickcount history");
        tickcount_field.SetString("value", tickcountBuf);
        tickcount_field.SetBool  ("inline", true);

        // BUTTONS
        char buttonsBuf[1024];
        Format
        (
            buttonsBuf,
            sizeof(buttonsBuf),

            "[what's this?](https://sapphonie.github.io/flags.html)\n\
            ```\
                0 | %i\n\
                1 | %i\n\
                2 | %i\n\
                3 | %i\n\
                4 | %i\n\
            ```",

            // buttons
            clbuttons[cl][0],
            clbuttons[cl][1],
            clbuttons[cl][2],
            clbuttons[cl][3],
            clbuttons[cl][4]
        );


        buttons_field = new JSON_Object();
        buttons_field.EnableOrderedKeys();
        buttons_field.SetString("name", "buttons history");
        buttons_field.SetString("value", buttonsBuf);
        buttons_field.SetBool  ("inline", true);

        // NETWORK INFO
        char netinfoBuf[1024];
        Format
        (
            netinfoBuf,
            sizeof(netinfoBuf),

            "```\
                ping               | %7.2fms\n\
                loss               | %7.2f%%\n\
                inchoke            | %7.2f%%\n\
                outchoke           | %7.2f%%\n\
                totalchoke         | %7.2f%%\n\
                rate               | %7.2fkbps\n\
                approx packets/sec | %7.2f\n\
                approx usrcmds/sec | %7i\n\
            ```",

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

        netinfo_field = new JSON_Object();
        netinfo_field.EnableOrderedKeys();
        netinfo_field.SetString("name", "network info");
        netinfo_field.SetString("value", netinfoBuf);
        netinfo_field.SetBool  ("inline", false);
    }


    // fields list
    JSON_Array fieldArray = new JSON_Array();
    if (userid)
    {
        fieldArray.PushObject(nameField);
        fieldArray.PushObject(steamIDfield);
        fieldArray.PushObject(spacerCpy1);
    }
    fieldArray.PushObject(detectOrMsgfield);
    if (detections)
    {
        fieldArray.PushObject(detectNumfield);
    }
    fieldArray.PushObject(spacerCpy2);
    fieldArray.PushObject(hostname_field);
    fieldArray.PushObject(serverip_field);
    fieldArray.PushObject(spacerCpy3);
    fieldArray.PushObject(demoname_field);
    fieldArray.PushObject(demotick_field);
    fieldArray.PushObject(spacerCpy4);
    fieldArray.PushObject(gametime_field);
    fieldArray.PushObject(servertick_field);
    fieldArray.PushObject(spacerCpy5);
    fieldArray.PushObject(discordtimestamp_field);
    fieldArray.PushObject(unixtimestamp_field);
    if (detections)
    {
        fieldArray.PushObject(spacerCpy6);
        fieldArray.PushObject(viewangle_field);
        fieldArray.PushObject(clpos_field);
        fieldArray.PushObject(spacerCpy7);
        fieldArray.PushObject(cmdnum_field);
        fieldArray.PushObject(tickcount_field);
        fieldArray.PushObject(buttons_field);
        fieldArray.PushObject(netinfo_field);
    }


    // embeds header info
    JSON_Object embedsFields = new JSON_Object();
    embedsFields.EnableOrderedKeys();

    embedsFields.SetObject("fields", fieldArray);
    char notifType[64];
    if (!userid)
    {
        Format(notifType, sizeof(notifType), "StAC v%s %s", PLUGIN_VERSION, "Server Message");
    }
    else if (!detections)
    {
        Format(notifType, sizeof(notifType), "StAC v%s %s", PLUGIN_VERSION, "Client Notification");
    }
    else
    {
        Format(notifType, sizeof(notifType), "StAC v%s %s", PLUGIN_VERSION, "Client Detection");
    }

    static int color = 0xFF69B4;
    embedsFields.SetString  ("title",       notifType);
    embedsFields.SetInt     ("color",       color);

    JSON_Array finalArr = new JSON_Array();

    finalArr.PushObject(embedsFields);

    // root
    JSON_Object rootEmbeds = new JSON_Object();
    rootEmbeds.EnableOrderedKeys();
    rootEmbeds.SetObject("embeds", finalArr);
    rootEmbeds.SetString("avatar_url", "https://i.imgur.com/RKRaLPl.png");
    rootEmbeds.Encode(output, sizeof(output));

    json_cleanup_and_delete(rootEmbeds);
    SendMessageToDiscord(output);

    return;
}

void SendMessageToDiscord(char[] message)
{
    static char webhook[8] = "stac";
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

// see if anyone is actively being viewed with livefeed so we dont have to loop every frame
void checkLiveFeed()
{
    livefeedActive = false;
    for (int k = 1; k <= MaxClients; k++)
    {
        if (LiveFeedOn[k])
        {
            livefeedActive = true;
            break;
        }
    }
}

// https://stackoverflow.com/a/44105089
float float_rand(float min, float max)
{
    float scale = GetURandomFloat();    /* [0, 1.0] */
    return min + scale * ( max - min ); /* [min, max] */
}



bool KthBitOfN(int n, int k)
{
    int bit = (n >> k) & 1;
    return !!bit;
}


// Signed version of GetURandomInt
int GetSRandomInt()
{
    bool sign = KthBitOfN(GetURandomInt(), 0);
    int random = GetURandomInt();

    if (sign)
    {
        random = -random;
    }

    return random;
}



// https://forums.alliedmods.net/showpost.php?p=2698561&postcount=2
// STEAM_1:1:23456789 to 23456789
/*
int GetAccountIdFromSteam2(const char[] steam_id)
{
    int matches = MatchRegex(steamidRegex, steam_id);

    if (matches != 1)
    {
        return 0;
    }

    return StringToInt(steam_id[10]) * 2 + (steam_id[8] - 48);
}
*/
