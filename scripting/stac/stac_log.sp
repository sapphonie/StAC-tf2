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
        \n Approx client cmdrate: ≈%.2f cmd/sec\
        \n Approx server tickrate: ≈%.2f tick/sec\
        \n Failing lag check? %s\
        \n HasValidAngles? %s\
        \n SequentialCmdnum? %s\
        \n OrderedTickcount? %s\
        ",
        calcCmdrateFor[Cl],
        smoothedTPS,
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
