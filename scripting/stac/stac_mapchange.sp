#pragma semicolon 1

/********** MAP CHANGE / STARTUP RELATED STUFF **********/

public void OnMapStart()
{
    OpenStacLog();
    ActuallySetRandomSeed();
    DoTPSMath();
    ResetTimers();
    if (optimizeCvars)
    {
        RunOptimizeCvars();
    }
    timeSinceMapStart = GetEngineTime();
    CreateTimer(0.1, checkNativesEtc);
    CreateTimer(0.5, getIP);

    GetConVarString(FindConVar("hostname"), hostname, sizeof(hostname));
}

public Action eRoundStart(Handle event, char[] name, bool dontBroadcast)
{
    DoTPSMath();
    // might as well do this here!
    ActuallySetRandomSeed();
    // this counts
    timeSinceMapStart = GetEngineTime();

    return Plugin_Continue;
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
    if (!ignore_sv_cheats)
    {
        if (GetConVarBool(FindConVar("sv_cheats")))
        {
            SetFailState("sv_cheats set to 1! Aborting!");
        }
    }

    // check timescale so we can check if the client's matches the server's
    timescale = GetConVarFloat(FindConVar("host_timescale"));

    // check wait command
    if (GetConVarBool(FindConVar("sv_allow_wait_command")))
    {
        waitStatus = true;
    }

    #if defined OF
    MVM = false;
    #else
    // are we in mann vs machine?
    if (GameRules_GetProp("m_bPlayingMannVsMachine") == 1)
    {
        MVM = true;
    }
    else
    {
        MVM = false;
    }
    #endif
    // check natives!

    // sourcebans
    if (GetFeatureStatus(FeatureType_Native, "SBPP_BanPlayer") == FeatureStatus_Available)
    {
        SOURCEBANS = true;
    }
    // materialadmin
    if (GetFeatureStatus(FeatureType_Native, "MABanPlayer") == FeatureStatus_Available)
    {
        MATERIALADMIN = true;
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
    // srctvmgr functionality, for demo ticks
    if (GetFeatureStatus(FeatureType_Native, "SourceTV_GetDemoFileName") == FeatureStatus_Available)
    {
        SOURCETVMGR = true;
    }
    // steamworks
    if (GetFeatureStatus(FeatureType_Native, "SteamWorks_GetPublicIP") == FeatureStatus_Available)
    {
        STEAMWORKS = true;
    }

    return Plugin_Continue;
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
                StacLog("Creating timer for %L", Cl);
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
        StacLog("setting random server seed to %i", seed);
    }
    SetRandomSeed(seed);
}

// jesus this is ugly
Action getIP(Handle timer)
{
    // get our host port
    char hostport[8];
    GetConVarString(FindConVar("hostport"), hostport, sizeof(hostport));

    // if we have steamworks we can get our ip ez pz
    if (STEAMWORKS)
    {
        int sw_ip[4];
        SteamWorks_GetPublicIP(sw_ip);
        Format(hostipandport, sizeof(hostipandport), "%i.%i.%i.%i:%s", sw_ip[0], sw_ip[1], sw_ip[2], sw_ip[3], hostport);
    }
    // otherwise we have to scrape the status command (ugly and frightening)
    else
    {
        char status_out[2048];
        ServerCommandEx(status_out, sizeof(status_out), "status");

        char ipetc[128];
        char ip[24];

        Format(hostipandport, sizeof(hostipandport), "un.known.ip.addr:%s", hostport);

        if (MatchRegex(publicIPRegex, status_out) > 0)
        {
            if (GetRegexSubString(publicIPRegex, 0, ipetc, sizeof(ipetc)))
            {
                TrimString(ipetc);
                if (MatchRegex(IPRegex, ipetc) > 0)
                {
                    if (GetRegexSubString(IPRegex, 0, ip, sizeof(ip)))
                    {
                        Format(hostipandport, sizeof(hostipandport), "%s:%s", ip, hostport);
                    }
                }
            }
        }
    }
    if (DEBUG)
    {
        StacLog("Server IP + Port = %s", hostipandport);
    }
    return Plugin_Continue;
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
