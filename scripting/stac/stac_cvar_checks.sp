/********** CLIENT CONVAR BASED STUFF **********/

char cvarsToCheck[][] =
{
    // misc vars
    "sensitivity",
    // possible cheat vars
    "cl_interpolate",
    // this is a useless check but we check it anyway
    "fov_desired",
    //
    "cl_cmdrate",
};

void ConVarCheck(QueryCookie cookie, int Cl, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
    // make sure client is valid
    if (!IsValidClient(Cl))
    {
        return;
    }
    int userid = GetClientUserId(Cl);

    if (DEBUG)
    {
        StacLog("[StAC] Checked cvar %s value %s on %N", cvarName, cvarValue, Cl);
    }

    // log something about cvar errors
    if (result != ConVarQuery_Okay)
    {
        PrintToImportant("{hotpink}[StAC]{white} Could not query cvar %s on Player %N", Cl);
        StacLog("[StAC] Could not query cvar %s on player %N", cvarName, Cl);
        return;
    }

    if (StrEqual(cvarName, "sensitivity"))
    {
        sensFor[Cl] = StringToFloat(cvarValue);
    }

    /*
        POSSIBLE CHEAT VARS
    */
    // cl_interpolate (hidden cvar! should NEVER not be 1)
    else if (StrEqual(cvarName, "cl_interpolate"))
    {
        if (StringToInt(cvarValue) != 1)
        {
            if (banForMiscCheats)
            {
                char reason[128];
                Format(reason, sizeof(reason), "%t", "nolerpBanMsg");
                char pubreason[256];
                Format(pubreason, sizeof(pubreason), "%t", "nolerpBanAllChat", Cl);
                // we have to do extra bullshit here so we don't crash when banning clients out of this callback
                // make a pack
                DataPack pack = CreateDataPack();

                // prepare pack
                WritePackCell(pack, userid);
                WritePackString(pack, reason);
                WritePackString(pack, pubreason);

                ResetPack(pack, false);

                // make data timer
                CreateTimer(0.1, Timer_BanUser, pack, TIMER_DATA_HNDL_CLOSE);
                return;
            }
            else
            {
                PrintToImportant("{hotpink}[StAC]{white} [Detection] Player %L is using NoLerp!", Cl);
                StacLog("[StAC] [Detection] Player %L is using NoLerp!", Cl);
            }
        }
    }
    // fov check #1 - if u get banned by this you are a clown
    else if (StrEqual(cvarName, "fov_desired"))
    {
        int fovDesired = StringToInt(cvarValue);
        // check just in case
        if
        (
            fovDesired < 20
            ||
            fovDesired > 90
        )
        {
            if (banForMiscCheats)
            {
                char reason[128];
                Format(reason, sizeof(reason), "%t", "fovBanMsg");
                char pubreason[256];
                Format(pubreason, sizeof(pubreason), "%t", "fovBanAllChat", Cl);
                // we have to do extra bullshit here so we don't crash when banning clients out of this callback
                // make a pack
                DataPack pack = CreateDataPack();

                // prepare pack
                WritePackCell(pack, userid);
                WritePackString(pack, reason);
                WritePackString(pack, pubreason);

                ResetPack(pack, false);

                // make data timer
                CreateTimer(0.1, Timer_BanUser, pack, TIMER_DATA_HNDL_CLOSE);
                return;
            }
            else
            {
                PrintToImportant("{hotpink}[StAC]{white} [Detection] Player %L is using fov cheats!", Cl);
                StacLog("[StAC] [Detection] Player %L is using fov cheats!", Cl);
            }
        }
    }
    // fov check #1 - if u get banned by this you are a clown
    else if (StrEqual(cvarName, "cl_cmdrate"))
    {
        if
        (
            StrEqual("-9999", cvarValue)
            ||
            StrEqual("-1", cvarValue)
        )
        {
            char scmdrate[16];
            // get actual value of cl cmdrate
            GetClientInfo(Cl, "cl_cmdrate", scmdrate, sizeof(scmdrate));
            if (!StrEqual(cvarValue, scmdrate))
            {
                StacLog("%N had cl_cmdrate value of %s, userinfo showed %s", Cl, cvarValue, scmdrate);
                if (banForMiscCheats)
                {
                    char reason[128];
                    Format(reason, sizeof(reason), "%t", "illegalCmdrateBanMsg");
                    char pubreason[256];
                    Format(pubreason, sizeof(pubreason), "%t", "illegalCmdrateBanAllChat", Cl);
                    // we have to do extra bullshit here so we don't crash when banning clients out of this callback
                    // make a pack
                    DataPack pack = CreateDataPack();
                    // prepare pack
                    WritePackCell(pack, userid);
                    WritePackString(pack, reason);
                    WritePackString(pack, pubreason);
                    ResetPack(pack, false);
                    // make data timer
                    CreateTimer(0.1, Timer_BanUser, pack, TIMER_DATA_HNDL_CLOSE);
                    return;
                }
                else
                {
                    PrintToImportant("{hotpink}[StAC] {red}[Detection]{white} Player %L has an illegal cmdrate value!", Cl);
                    StacLog("[StAC] [Detection] Player %L has an illegal cmdrate value!", Cl);
                }
            }
        }
    }
}

// we wait a bit to prevent crashing the server when banning a player from a queryclientconvar callback
Action Timer_BanUser(Handle timer, DataPack pack)
{
    int userid          = ReadPackCell(pack);
    char reason[128];
    ReadPackString(pack, reason, sizeof(reason));
    char pubreason[256];
    ReadPackString(pack, pubreason, sizeof(pubreason));

    // get client index out of userid
    int Cl              = GetClientOfUserId(userid);

    // check validity of client index
    if (IsValidClient(Cl))
    {
        BanUser(userid, reason, pubreason);
    }
}

// timer for (re)checking ALL cvars and net props and everything else
Action Timer_CheckClientConVars(Handle timer, int userid)
{
    // get actual client index
    int Cl = GetClientOfUserId(userid);
    // null out timer here
    QueryTimer[Cl] = null;
    if (IsValidClient(Cl))
    {
        if (DEBUG)
        {
            StacLog("[StAC] Checking client id, %i, %N", Cl, Cl);
        }
        // init variable to pass to QueryCvarsEtc
        int i;
        // query the client!
        QueryCvarsEtc(userid, i);
        // we just checked, but we want to check again eventually
        // lets redo this timer in a random length between stac_min_randomcheck_secs and stac_max_randomcheck_secs
        QueryTimer[Cl] =
        CreateTimer
        (
            GetRandomFloat(minRandCheckVal, maxRandCheckVal),
            Timer_CheckClientConVars,
            userid
        );
    }
}

// query all cvars and netprops for userid
void QueryCvarsEtc(int userid, int i)
{
    // get client index of userid
    int Cl = GetClientOfUserId(userid);
    // don't go no further if client isn't valid!
    if (IsValidClient(Cl))
    {
        // check cvars!
        if (i < sizeof(cvarsToCheck))
        {
            // make pack
            DataPack pack = CreateDataPack();
            // actually query the cvar here based on pos in convar array
            QueryClientConVar(Cl, cvarsToCheck[i], ConVarCheck);
            // increase pos in convar array
            i++;
            // prepare pack
            WritePackCell(pack, userid);
            WritePackCell(pack, i);
            // reset pack pos to 0
            ResetPack(pack, false);
            // make data timer
            CreateTimer(2.5, Timer_QueryNextCvar, pack, TIMER_DATA_HNDL_CLOSE);
        }
        // we checked all the cvars!
        else
        {
            // now lets check some AC related netprops and other misc stuff
            MiscCheatsEtcsCheck(userid);
        }
    }
}

// timer for checking the next cvar in the list (waits a bit to balance out server load)
Action Timer_QueryNextCvar(Handle timer, DataPack pack)
{
    // read userid
    int userid = ReadPackCell(pack);
    // read i
    int i      = ReadPackCell(pack);

    // get client index out of userid
    int Cl     = GetClientOfUserId(userid);

    // check validity of client index
    if (IsValidClient(Cl))
    {
        QueryCvarsEtc(userid, i);
    }
}

// expensive!
void QueryEverythingAllClients()
{
    if (DEBUG)
    {
        StacLog("[StAC] Querying all clients");
    }
    // loop thru all clients
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            // get userid of this client index
            int userid = GetClientUserId(Cl);
            // init variable to pass to QueryCvarsEtc
            int i;
            // query the client!
            QueryCvarsEtc(userid, i);
        }
    }
}
