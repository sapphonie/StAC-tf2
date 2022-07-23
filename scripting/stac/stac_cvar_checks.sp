#pragma semicolon 1

/********** CLIENT CONVAR BASED STUFF **********/

// Cvars that cheats tend to use to be out of bounds (or ones we need to check anyway) get appended to this array
char miscVars[][] =
{
    // misc vars
    "sensitivity",
    // possible cheat vars
    // must be == 0
    "sv_cheats",
    // must be == 1
    "cl_interpolate",
    // this is a useless check but we check it anyway
    "fov_desired",
    // must be >= 10
    "cl_cmdrate",
    // must be == 1
    "r_drawothermodels",
    // must be == 0
    "snd_show",
    // must be == 0
    "snd_visualize",
    // must be == 1
    "fog_enable",
    // must be == 0
    "cl_thirdperson",
    // must be == 0
    "r_portalsopenall",
    // must be == 1
    "host_timescale",
    // sv_force_transmit_ents ?
    // sv_suppress_viewpunch ?
    // tf_showspeed ?
    // tf_tauntcam_* for third person ?
};

// DEFINITE cheat vars get appended to this array.
// Every cheat except cathook is smart enough to not have queryable cvars.
// For now.
char cheatVars[][] =
{
    // lith
    // "lithium_disable_party_bypass",
    // rijin
    // "rijin_load",
    // "rijin_save",
    // lmaobox apparently uses this? haven't seen it
    // "setcvar",
    // ncc doesn't have any that i can find lol
    // cathook
    "cat_load",
    // ...melancholy? maybe? lol
    // "caramelldansen",
    // "SetCursor",
    // "melancholy",
    // general
    // "hook"
};


// set in InitCvarArray which is called in OnPluginLoad
char cvarsToCheck[sizeof(miscVars) + sizeof(cheatVars)][64];

// oh man this is ugly
// BONK: REWRITE THIS PLEASE
void InitCvarArray()
{
    int miscvars = sizeof(miscVars);
    int cheatvars = sizeof(cheatVars);
    for (int numofvars = 0; numofvars < miscvars; numofvars++)
    {
        strcopy(cvarsToCheck[numofvars], 32, miscVars[numofvars]);
    }
    for (int numofvars = 0; numofvars < cheatvars; numofvars++)
    {
        strcopy(cvarsToCheck[numofvars+miscvars], 32, cheatVars[numofvars]);
    }
}

// Some day I will clean this up so it's not just a billion elseifs.
public void ConVarCheck(QueryCookie cookie, int Cl, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
    // make sure client is valid
    if (!IsValidClient(Cl))
    {
        return;
    }
    int userid = GetClientUserId(Cl);

    if (DEBUG)
    {
        StacLog("Checked cvar %s value %s on %N", cvarName, cvarValue, Cl);
    }

    if (StrEqual(cvarName, "sensitivity"))
    {
        sensFor[Cl] = StringToFloat(cvarValue);
    }

    // TODO: yaw and pitch checks?

    /*
        non cheat client cvars, but we check if they have oob values or not
    */

    // sv_cheats
    // you know what this does and what it should be. 0.
    else if (StrEqual(cvarName, "sv_cheats"))
    {
        if (StringToInt(cvarValue) != 0)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (banForMiscCheats)
            {
                oobVarBan(userid);
            }
        }
    }

    // cl_interpolate (hidden cvar! should NEVER not be 1)
    // used for disabling client side interpolation wholesale
    else if (StrEqual(cvarName, "cl_interpolate"))
    {
        if (StringToInt(cvarValue) != 1)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (banForMiscCheats)
            {
                oobVarBan(userid);
            }
        }
    }

    // fov check #1 - if u get banned by this you are a clown
    // used for seeing more of the world
    else if (StrEqual(cvarName, "fov_desired"))
    {
        int fovDesired = StringToInt(cvarValue);
        // check just in case
        if (fovDesired < 20 || fovDesired > 90)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (banForMiscCheats)
            {
                oobVarBan(userid);
            }
        }
    }

    // cmdrate check - should always be at or above 10
    // used for faking ping to the server
    else if (StrEqual(cvarName, "cl_cmdrate"))
    {
        int clcmdrate = StringToInt(cvarValue);
        if (clcmdrate < 10)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (banForMiscCheats)
            {
                oobVarBan(userid);
            }
        }
    }

    // r_drawothermodels (cheat cvar! should NEVER not be 1)
    // used for seeing thru the world
    else if (StrEqual(cvarName, "r_drawothermodels"))
    {
        if (StringToInt(cvarValue) != 1)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (banForMiscCheats)
            {
                oobVarBan(userid);
            }
        }
    }

    // snd_show (cheat cvar! should NEVER not be 0)
    // used for showing currently playing sounds
    else if (StrEqual(cvarName, "snd_show"))
    {
        if (StringToInt(cvarValue) != 0)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (banForMiscCheats)
            {
                oobVarBan(userid);
            }
        }
    }

    // snd_visualize (cheat cvar! should NEVER not be 0)
    // used for visualizing sounds in the world
    else if (StrEqual(cvarName, "snd_visualize"))
    {
        if (StringToInt(cvarValue) != 0)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (banForMiscCheats)
            {
                oobVarBan(userid);
            }
        }
    }

    // fog_enable (cheat cvar! should NEVER not be 1)
    // used for making the world a little clearer. this should frankly be not cheat locked but i know cheaters will use it and that's still cheating
    else if (StrEqual(cvarName, "fog_enable"))
    {
        if (StringToInt(cvarValue) != 1)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (banForMiscCheats)
            {
                oobVarBan(userid);
            }
        }
    }

    // cl_thirdperson (hidden cvar! should NEVER not be 0)
    // used for enabling thirdperson
    else if (StrEqual(cvarName, "cl_thirdperson"))
    {
        if (StringToInt(cvarValue) != 0)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (banForMiscCheats)
            {
                oobVarBan(userid);
            }
        }
    }

    // r_portalsopenall (cheat cvar! should NEVER not be 0)
    // used for disabling areaportal checks, so you can see the entire world at once. essentially "far esp"
    // BONK: Wait, huh? Is this actually useful? AFAIK the server controls this...
    else if (StrEqual(cvarName, "r_portalsopenall"))
    {
        if (StringToInt(cvarValue) != 0)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (banForMiscCheats)
            {
                oobVarBan(userid);
            }
        }
    }

    // host_timescale (cheat cvar! should NEVER not be 1)
    // used to bypass VAC: https://github.com/ValveSoftware/Source-1-Games/issues/3911
    else if (StrEqual(cvarName, "host_timescale"))
    {
        if (StringToInt(cvarValue) != 1)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (banForMiscCheats)
            {
                oobVarBan(userid);
            }
        }
    }

    /*
        cheat program only cvars
    */
    if (result != ConVarQuery_NotFound && IsCheatOnlyVar(cvarName))
    {
        illegalVarsNotify(userid, cvarName);
        if (banForMiscCheats)
        {
            illegalVarBan(userid);
        }
    }
    // log something about cvar errors
    else if (result != ConVarQuery_Okay && !IsCheatOnlyVar(cvarName))
    {
        PrintToImportant("{hotpink}[StAC]{white} Could not query cvar %s on Player %N", cvarName, Cl);
        StacLog("Could not query cvar %s on player %L", cvarName, Cl);
    }
}

void oobVarBan(int userid)
{
    int Cl = GetClientOfUserId(userid);
    char reason[128];
    Format(reason, sizeof(reason), "%t", "oobVarBanMsg");
    char pubreason[256];
    Format(pubreason, sizeof(pubreason), "%t", "oobVarBanAllChat", Cl);
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

void illegalVarBan(int userid)
{
    int Cl = GetClientOfUserId(userid);
    char reason[128];
    Format(reason, sizeof(reason), "%t", "cheatVarBanMsg");
    char pubreason[256];
    Format(pubreason, sizeof(pubreason), "%t", "cheatVarBanAllChat", Cl);
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

bool IsCheatOnlyVar(const char[] cvarName)
{
    for (int i = 0; i < sizeof(cheatVars); i++)
    {
        if (StrEqual(cvarName, cheatVars[i]))
        {
            return true;
        }
    }
    return false;
}

// oob cvar values
void oobVarsNotify(int userid, const char[] name, const char[] value)
{
    int Cl = GetClientOfUserId(userid);
    PrintToImportant("{hotpink}[StAC] {red}[Detection]{white} Player %N is cheating - OOB cvar/netvar value {blue}%s{white} on var {blue}%s{white}!", Cl, value, name);
    StacLogSteam(userid);
    char msg[128];
    Format(msg, sizeof(msg), "Client has OOB value %s for var %s!", value, name);
    StacDetectionNotify(userid, msg, 1);
}


// cheatonly cvars/concmds/etc
void illegalVarsNotify(int userid, const char[] name)
{
    int Cl = GetClientOfUserId(userid);
    PrintToImportant("{hotpink}[StAC] {red}[Detection]{white} Player %N is cheating - detected known cheat var/concommand {blue}%s{white}!", Cl, name);
    StacLogSteam(userid);
    char msg[128];
    Format(msg, sizeof(msg), "Known cheat var %s exists on client!", name);
    StacDetectionNotify(userid, msg, 1);
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

    return Plugin_Continue;
}

// don't check clients in our random timer until they've waited 60 seconds after joining the server
Action Timer_CheckClientConVars_FirstTime(Handle timer, int userid)
{
    // get actual client index
    int Cl = GetClientOfUserId(userid);
    // null out timer here
    QueryTimer[Cl] = null;
    if (IsValidClient(Cl))
    {
        hasWaitedForCvarCheck[Cl] = true;
        CreateTimer(0.1, Timer_CheckClientConVars, userid);
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
        if (!hasWaitedForCvarCheck[Cl])
        {
            if (DEBUG)
            {
                StacLog("Client %N can't be checked because they haven't waited 60 seconds for their first cvar check!", Cl);
            }
            return Plugin_Continue;
        }
        if (DEBUG)
        {
            StacLog("Checking client id, %i, %L", Cl, Cl);
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

    return Plugin_Continue;
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

    return Plugin_Continue;
}

// expensive!
void QueryEverythingAllClients()
{
    if (DEBUG)
    {
        StacLog("Querying all clients");
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
