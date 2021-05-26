/********** LIVEFEED **********/

void LiveFeed_PlayerCmd(int userid)
{
    int Cl = GetClientOfUserId(userid);

    static char RareButtonNames[][] =
    {
        "",
        "",
        "",
        "",
        "",
        "",
        "CANCEL",
        "LEFT",
        "RIGHT",
        "",
        "",
        "",
        "RUN",
        "",
        "ALT1",
        "ALT2",
        "SCORE",
        "SPEED",
        "WALK",
        "ZOOM",
        "WEAPON1",
        "WEAPON2",
        "BULLRUSH",
        "GRENADE1",
        "GRENADE2",
        ""
    };


    int buttons = clbuttons[Cl][0];

    char fwd    [4] = "_";
    if (buttons & IN_FORWARD)
    {
        fwd = "^";
    }

    char back   [4] = "_";
    if (buttons & IN_BACK)
    {
        back = "v";
    }

    char left   [4] = "_";
    if (buttons & IN_MOVELEFT)
    {
        left = "<";
    }

    char right  [4] = "_";
    if (buttons & IN_MOVERIGHT)
    {
        right = ">";
    }

    char m1     [4] = "_";
    if (buttons & IN_ATTACK)
    {
        m1 = "1";
    }

    char m2     [4] = "_";
    if (buttons & IN_ATTACK2)
    {
        m2 = "2";
    }

    char m3     [4] = "_";
    if (buttons & IN_ATTACK3)
    {
        m3 = "3";
    }

    char jump   [6] = "____";
    if (buttons & IN_JUMP)
    {
        jump = "JUMP";
    }

    char duck   [6] = "____";
    if (buttons & IN_DUCK)
    {
        duck = "DUCK";
    }

    char reload [4] = "_";
    if (buttons & IN_RELOAD)
    {
        reload = "R";
    }
    char use [4] = "_";
    if (buttons & IN_USE)
    {
        use = "U";
    }

    char strButtons[512];
    for (int i = 0; i < sizeof(RareButtonNames); i++)
    {
        if (buttons & (1 << i))
        {
            Format(strButtons, sizeof(strButtons), "%s %s", strButtons, RareButtonNames[i]);
        }
    }
    TrimString(strButtons);

    for (int LiveFeedViewer = 1; LiveFeedViewer <= MaxClients; LiveFeedViewer++)
    {
        if (IsValidAdmin(LiveFeedViewer) || IsValidSrcTV(LiveFeedViewer))
        {
            // ONPLAYERRUNCMD
            SetHudTextParams
            (
                // x&y
                0.0, 0.0,
                // time to hold
                0.20,
                // rgba
                255, 255, 255, 255,
                // effects
                0, 0.0, 0.0, 0.0
            );
            ShowSyncHudText
            (
                LiveFeedViewer,
                HudSyncRunCmd,
                "\
                \nOnPlayerRunCmd Info:\
                \n %i cmdnum\
                \n %i tickcount\
                \n common buttons:\
                \n  %c %c %c\
                \n  %c %c %c    %c %c %c\
                \n  %s    %s\
                \n other buttons:\
                \n  %s\
                \n buttons int\
                \n  %i\
                \n mouse\
                \n x %i\
                \n y %i\
                \n angles\
                \n x %.2f \
                \n y %.2f \
                \n z %.2f \
                ",
                clcmdnum[Cl][0],
                cltickcount[Cl][0],
                use,  fwd, reload,
                left, back, right,    m1, m2, m3,
                jump, duck,
                IsActuallyNullString(strButtons) ? "N/A" : strButtons,
                clbuttons[Cl][0],
                clmouse[Cl][0], clmouse[Cl][1],
                clangles[Cl][0][0], clangles[Cl][0][1], clangles[Cl][0][2]
            );

            // OTHER STUFF
            SetHudTextParams
            (
                // x&y
                0.0, 0.75,
                // time to hold
                0.20,
                // rgba
                255, 255, 255, 255,
                // effects
                0, 0.0, 0.0, 0.0
            );
            ShowSyncHudText
            (
                LiveFeedViewer,
                HudSyncRunCmdMisc,
                "\
                \nMisc Info:\
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
    }
}

void LiveFeed_NetInfo(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if (!IsValidClient(Cl))
    {
        return;
    }
    for (int LiveFeedViewer = 1; LiveFeedViewer <= MaxClients; LiveFeedViewer++)
    {
        if (IsValidAdmin(LiveFeedViewer) || IsValidSrcTV(LiveFeedViewer))
        {
            // NETINFO
            SetHudTextParams
            (
                // x&y
                0.85, 0.40,
                // time to hold
                2.0,
                // rgba
                255, 255, 255, 255,
                // effects
                0, 0.0, 0.0, 0.0
            );
            ShowSyncHudText
            (
                LiveFeedViewer,
                HudSyncNetwork,
                "\
                \nClient: %N\
                \n Index: %i\
                \n Userid: %i\
                \n Status: %s\
                \n Connected for: %.0fs\
                \n\
                \nNetwork:\
                \n %.2f ms ping\
                \n %.2f loss\
                \n %.2f inchoke\
                \n %.2f outchoke\
                \n %.2f totalchoke\
                \n %.2f kbps rate\
                \n %.2f pps rate\
                ",
                Cl,
                Cl,
                GetClientUserId(Cl),
                IsPlayerAlive(Cl) ? "alive" : "dead",
                GetClientTime(Cl),
                pingFor[Cl],
                lossFor[Cl],
                inchokeFor[Cl],
                outchokeFor[Cl],
                chokeFor[Cl],
                rateFor[Cl],
                ppsFor[Cl]
            );
        }
    }
}
