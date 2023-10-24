#pragma semicolon 1

/********** MAP CHANGE / STARTUP RELATED STUFF **********/

public void OnConfigsExecuted()
{
    checkNativesEtc(null);
    configsExecuted = true;
}

public void OnMapStart()
{
    OpenStacLog();
    DoTPSMath();
    ResetTimers();
    if (stac_optimize_cvars.BoolValue)
    {
        RunOptimizeCvars();
    }
    timeSinceMapStart = GetEngineTime();
    CreateTimer(0.1, checkNativesEtc);
    CreateTimer(0.2, getIP);
    EngineSanityChecks();

/*
    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "point_worldtext")) != -1)
    {
        if (IsValidEntity(ent))
        {
            RemoveEntity(ent);
        }
    }
*/
}

public Action eRoundStart(Handle event, char[] name, bool dontBroadcast)
{
    DoTPSMath();
    // this counts
    timeSinceMapStart = GetEngineTime();

    return Plugin_Continue;
}

public void OnMapEnd()
{
    DoTPSMath();
    NukeTimers();
    CloseStacLog();
}

Action checkNativesEtc(Handle timer)
{
    if (!configsExecuted)
    {
        return Plugin_Handled;
    }

    // check sv cheats
    if ( !stac_work_with_sv_cheats.BoolValue )
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

    return Plugin_Continue;
}

// NUKE the client timers from orbit on plugin and map reload
void NukeTimers()
{
    for (int cl = 1; cl <= MaxClients; cl++)
    {
        delete QueryTimer[cl];
    }
}

// recreate the timers we just nuked
void ResetTimers()
{
    for (int cl = 1; cl <= MaxClients; cl++)
    {
        if (IsValidClient(cl))
        {
            int userid = GetClientUserId(cl);

            if (stac_debug.BoolValue)
            {
                StacLog("Creating timer for %L", cl);
            }
            // lets make a timer with a random length between stac_min_randomcheck_secs and stac_max_randomcheck_secs
            QueryTimer[cl] =
            CreateTimer
            (
                GetRandomFloat
                (
                    stac_min_randomcheck_secs.FloatValue,
                    stac_max_randomcheck_secs.FloatValue
                ),
                Timer_CheckClientConVars,
                userid
            );
        }
    }
}

Action getIP(Handle timer)
{
    // get our host port
    char hostport[8];
    GetConVarString(FindConVar("hostport"), hostport, sizeof(hostport));

    int sw_ip[4];
    SteamWorks_GetPublicIP(sw_ip);
    Format(hostipandport, sizeof(hostipandport), "%i.%i.%i.%i:%s", sw_ip[0], sw_ip[1], sw_ip[2], sw_ip[3], hostport);

    if (stac_debug.BoolValue)
    {
        StacLog("Server IP + Port = %s", hostipandport);
    }
    return Plugin_Continue;
}

void DoTPSMath()
{
    tickinterv = GetTickInterval();
    tps = Pow(tickinterv, -1.0);
    itps = RoundToNearest(tps);

    //// max amt of time a client is allowed to be ahead of the server in terms of tickcount, in seconds
    //static int maxAheadSeconds = 5;
    //itps_maxaheadsecs = ( itps * maxAheadSeconds );

    if (stac_debug.BoolValue)
    {
        StacLog("tickinterv %f, tps %f, itps %i", tickinterv, tps, itps);
    }
}
