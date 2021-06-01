/********** MAP CHANGE / STARTUP RELATED STUFF **********/

public void OnMapStart()
{
    OpenStacLog();
    ActuallySetRandomSeed();
    DoTPSMath();
    ResetTimers();
    RequestFrame(checkStatus);
    if (optimizeCvars)
    {
        RunOptimizeCvars();
    }
    timeSinceMapStart = GetEngineTime();
    CreateTimer(0.1, checkNativesEtc);
    GetConVarString(FindConVar("hostname"), hostname, sizeof(hostname));
}

Action eRoundStart(Handle event, char[] name, bool dontBroadcast)
{
    DoTPSMath();
    // might as well do this here!
    ActuallySetRandomSeed();
    // this counts
    timeSinceMapStart = GetEngineTime();
}

public void OnMapEnd()
{
    ActuallySetRandomSeed();
    DoTPSMath();
    NukeTimers();
    CloseStacLog();
}

Action checkNativesEtc(Handle timer)
{
    // check sv cheats
    if (GetConVarBool(FindConVar("sv_cheats")))
    {
        //SetFailState("[StAC] sv_cheats set to 1! Aborting!");
    }
    // check wait command
    if (GetConVarBool(FindConVar("sv_allow_wait_command")))
    {
        waitStatus = true;
    }
    // are we in mann vs machine?
    if (GameRules_GetProp("m_bPlayingMannVsMachine") == 1)
    {
        MVM = true;
    }
    else
    {
        MVM = false;
    }

    // check natives!

    // steamtools
    if (GetFeatureStatus(FeatureType_Native, "Steam_IsConnected") == FeatureStatus_Available)
    {
        STEAMTOOLS = true;
    }
    // steamworks
    if (GetFeatureStatus(FeatureType_Native, "SteamWorks_IsConnected") == FeatureStatus_Available)
    {
        STEAMWORKS = true;
    }
    // sourcebans
    if (GetFeatureStatus(FeatureType_Native, "SBPP_BanPlayer") == FeatureStatus_Available)
    {
        SOURCEBANS = true;
    }
    // gbans
    if (CommandExists("gb_ban"))
    {
        GBANS = true;
    }
    // sourcemod aimplotter
    if (CommandExists("sm_aimplot"))
    {
        AIMPLOTTER = true;
    }
    // discord functionality
    if (GetFeatureStatus(FeatureType_Native, "Discord_SendMessage") == FeatureStatus_Available)
    {
        DISCORD = true;
    }

    // check steam status real quick
    if (isSteamAlive == -1)
    {
        checkSteam();
    }
}

// NUKE the client timers from orbit on plugin and map reload
void NukeTimers()
{
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        delete QueryTimer[Cl];
    }
    delete TriggerTimedStuffTimer;
}

// recreate the timers we just nuked
void ResetTimers()
{
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            int userid = GetClientUserId(Cl);

            if (DEBUG)
            {
                StacLog("[StAC] Creating timer for %L", Cl);
            }
            // lets make a timer with a random length between stac_min_randomcheck_secs and stac_max_randomcheck_secs
            QueryTimer[Cl] =
            CreateTimer
            (
                GetRandomFloat
                (
                    minRandCheckVal,
                    maxRandCheckVal
                ),
                Timer_CheckClientConVars,
                userid
            );
        }
    }
    // create timer to reset seed every 15 mins
    TriggerTimedStuffTimer = CreateTimer(900.0, Timer_TriggerTimedStuff, _, TIMER_REPEAT);
}

// reseed random server seed to help prevent certain nospread stuff from working.
// this probably doesn't do anything, but it makes me feel better.
void ActuallySetRandomSeed()
{
    int seed = GetURandomInt();
    if (DEBUG)
    {
        StacLog("[StAC] setting random server seed to %i", seed);
    }
    SetRandomSeed(seed);
}

void checkStatus()
{
    char status[2048];
    ServerCommandEx(status, sizeof(status), "status");
    char ipetc[128];
    char ip[24];
    if (MatchRegex(publicIPRegex, status) > 0)
    {
        if (GetRegexSubString(publicIPRegex, 0, ipetc, sizeof(ipetc)))
        {
            TrimString(ipetc);
            if (MatchRegex(IPRegex, ipetc) > 0)
            {
                if (GetRegexSubString(IPRegex, 0, ip, sizeof(ip)))
                {
                    strcopy(hostipandport, sizeof(hostipandport), ip);
                    StrCat(hostipandport, sizeof(hostipandport), ":");
                    char hostport[6];
                    GetConVarString(FindConVar("hostport"), hostport, sizeof(hostport));
                    StrCat(hostipandport, sizeof(hostipandport), hostport);
                }
            }
        }
    }
}

void DoTPSMath()
{
    tickinterv = GetTickInterval();
    tps = Pow(tickinterv, -1.0);

    if (DEBUG)
    {
        StacLog("tickinterv %f, tps %f", tickinterv, tps);
    }
}

