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
    // must be == 0
    "cl_thirdperson",
    // must be == 0
    "r_portalsopenall",
    // must be == 1.0
    "host_timescale",
    // must be == 0
    "mat_wireframe",
    //must be == 0
    "mat_fillrate",
    //must be == 0
    "mat_fullbright",
    //must be == 1
    "r_drawparticles",

    // 0
    "net_blockmsg",
    "net_droppackets",
    "net_fakejitter",
    "net_fakelag",
    "net_fakeloss",

    // 1
    "r_skybox",
    "r_drawskybox",

    //89
    "cl_pitchup",
    "cl_pitchdown"

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
    "rijin_load",
    // "rijin_save",
    // plenty of idiot cheats use this
    "setcvar",
    // ncc doesn't have any that i can find lol
    // cathook
    "cat_load",
    // ...melancholy? maybe? lol
    // "caramelldansen",
    // "SetCursor",
    // "melancholy",
    // general
    // "hook"
    // fware
    "crash",
    // cathook uses this to "spoof" windows
    "windows_speaker_config",
    // Amalgam uses this in the Src (https://github.com/rei-2/Amalgam/blob/master/Amalgam/src/Features/Commands/Commands.cpp)
    "getcvar",
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
public void ConVarCheck(QueryCookie cookie, int cl, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
    // make sure client is valid
    if (!IsValidClient(cl))
    {
        return;
    }
    int userid = GetClientUserId(cl);

    if (stac_debug.BoolValue)
    {
        StacLog("Checked cvar %s value %s on %N", cvarName, cvarValue, cl);
    }

    if (StrEqual(cvarName, "sensitivity"))
    {
        sensFor[cl] = StringToFloat(cvarValue);
    }

    // TODO: yaw and pitch checks?

    /*
        non cheat client cvars, but we check if they have oob values or not
    */

    // sv_cheats
    else if (StrEqual(cvarName, "sv_cheats"))
    {
        // if we're ignoring sv_cheats being on, obviously don't check this cvar
        if (configsExecuted && !stac_work_with_sv_cheats.BoolValue)
        {
            if (StringToInt(cvarValue) != 0)
            {
                oobVarsNotify(userid, cvarName, cvarValue);
                if (stac_ban_for_misccheats.BoolValue)
                {
                    oobVarBan(userid);
                }
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
            if (stac_ban_for_misccheats.BoolValue)
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
            if (stac_ban_for_misccheats.BoolValue)
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
            if (stac_ban_for_misccheats.BoolValue)
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
            if (stac_ban_for_misccheats.BoolValue)
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
            if (stac_ban_for_misccheats.BoolValue)
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
            if (stac_ban_for_misccheats.BoolValue)
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
            if (stac_ban_for_misccheats.BoolValue)
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
            if (stac_ban_for_misccheats.BoolValue)
            {
                oobVarBan(userid);
            }
        }
    }

    // host_timescale (cheat cvar! should NEVER not be 1)
    // used to bypass VAC: https://github.com/ValveSoftware/Source-1-Games/issues/3911
    else if (StrEqual(cvarName, "host_timescale"))
    {
        // floatcmpreal is just a ==
        // only bother if server timescale == 1.0
        if
        (
            // host_timescale value == 1
            floatcmpreal(host_timescale.FloatValue, 1.0, 0.01)
            &&
            // client host_timescale cvar != 1
            !floatcmpreal(StringToFloat(cvarValue), 1.0, 0.01)
        )
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (stac_ban_for_misccheats.BoolValue)
            {
                oobVarBan(userid);
            }
        }
    }
  
    // mat_wireframe (cheat cvar! should NEVER not be 0)
    // a la r_drawothermodels 2
    else if (StrEqual(cvarName, "mat_wireframe"))
    {
        if (StringToInt(cvarValue) != 0)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (stac_ban_for_misccheats.BoolValue)
            {
                oobVarBan(userid);
            }
        }
    }

    // mat_fillrate (cheat cvar! should NEVER not be 0)
    // AKA "ASUS wallhack"
    else if (StrEqual(cvarName, "mat_fillrate"))
    {
        if (StringToInt(cvarValue) != 0)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (stac_ban_for_misccheats.BoolValue)
            {
                oobVarBan(userid);
            }
        }
    }

    // mat_fullbright (cheat cvar! should NEVER not be 0)
    // see-thru smoke when 2
    else if (StrEqual(cvarName, "mat_fullbright"))
    {
        if (StringToInt(cvarValue) != 0)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (stac_ban_for_misccheats.BoolValue)
            {
                oobVarBan(userid);
            }
        }
    }
  
    // r_drawparticles (cheat cvar! should NEVER not be 1)
    // disables smoke
    else if (StrEqual(cvarName, "r_drawparticles"))
    {
        if (StringToInt(cvarValue) != 1)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (stac_ban_for_misccheats.BoolValue)
            {
                oobVarBan(userid);
            }
        }
    }

    // probably will get detected anyway due to invalid pitch, but dosen't hurt to check
    else if (StrEqual(cvarName, "cl_pitchup") || StrEqual(cvarName, "cl_pitchdown"))
    {
        if (StringToInt(cvarValue) != 89)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (stac_ban_for_misccheats.BoolValue)
            {
                oobVarBan(userid);
            }
        }
    }

    /*
        // 0
        "net_blockmsg",
        "net_droppackets",
        "net_fakejitter",
        "net_fakelag",
        "net_fakeloss",
    */
    else if (StrContains(cvarName, "net_") == 0 /* starts with "net_", doesn't just contain it */)
    {
        if (StringToInt(cvarValue) != 0)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (stac_ban_for_misccheats.BoolValue)
            {
                oobVarBan(userid);
            }
        }
    }

    else if (StrEqual(cvarName, "r_skybox") || StrEqual(cvarName, "r_drawskybox"))
    {
        if (StringToInt(cvarValue) != 1)
        {
            oobVarsNotify(userid, cvarName, cvarValue);
            if (stac_ban_for_misccheats.BoolValue)
            {
                oobVarBan(userid);
            }
        }
    }
    /*
        cheat program only cvars
    */
    if
    (
        (
               result == ConVarQuery_Okay
            || result == ConVarQuery_NotValid
            || result == ConVarQuery_Protected
        )
        &&
        IsCheatOnlyVar(cvarName)
    )
    {
        illegalVarsNotify(userid, cvarName);
        if (stac_ban_for_misccheats.BoolValue)
        {
            illegalVarBan(userid);
        }
    }
    // log something about cvar errors
    else if (result != ConVarQuery_Okay && !IsCheatOnlyVar(cvarName))
    {
        char fmtmsg[512];
        Format
        (
            fmtmsg,
            sizeof(fmtmsg),
            "Could not query cvar %s on player %N! This person is probably cheating, but please verify this!",
            cvarName,
            cl
        );
        PrintToImportant("{hotpink}[StAC]{white} Could not query cvar %s on player %N! This person is probably cheating, but please verify this!", cvarName, cl);
        StacLog(fmtmsg);
        StacNotify(userid, fmtmsg);
    }
}

void oobVarBan(int userid)
{
    int cl = GetClientOfUserId(userid);
    char reason[128];
    Format(reason, sizeof(reason), "%t", "oobVarBanMsg");
    char pubreason[256];
    Format(pubreason, sizeof(pubreason), "%t", "oobVarBanAllChat", cl);
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
    int cl = GetClientOfUserId(userid);
    char reason[128];
    Format(reason, sizeof(reason), "%t", "cheatVarBanMsg");
    char pubreason[256];
    Format(pubreason, sizeof(pubreason), "%t", "cheatVarBanAllChat", cl);
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
    int cl = GetClientOfUserId(userid);
    PrintToImportant("{hotpink}[StAC] {red}[Detection]{white} Player %N is cheating - OOB cvar/netvar value {blue}%s{white} on var {blue}%s{white}!", cl, value, name);
    StacLogSteam(userid);
    char msg[128];
    Format(msg, sizeof(msg), "Client has OOB value %s for var %s!", value, name);
    StacNotify(userid, msg, 1);
}


// cheatonly cvars/concmds/etc
void illegalVarsNotify(int userid, const char[] name)
{
    int cl = GetClientOfUserId(userid);
    PrintToImportant("{hotpink}[StAC] {red}[Detection]{white} Player %N is cheating - detected known cheat var/concommand {blue}%s{white}!", cl, name);
    StacLogSteam(userid);
    char msg[128];
    Format(msg, sizeof(msg), "Known cheat var %s exists on client!", name);
    StacNotify(userid, msg, 1);
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
    int cl              = GetClientOfUserId(userid);

    // check validity of client index
    if (IsValidClient(cl))
    {
        BanUser(userid, reason, pubreason);
    }

    return Plugin_Continue;
}

// don't check clients in our random timer until they've waited 60 seconds after joining the server
Action Timer_CheckClientConVars_FirstTime(Handle timer, int userid)
{
    // get actual client index
    int cl = GetClientOfUserId(userid);
    // null out timer here
    QueryTimer[cl] = null;
    if (IsValidClient(cl))
    {
        hasWaitedForCvarCheck[cl] = true;
        CreateTimer(0.1, Timer_CheckClientConVars, userid);
    }

    return Plugin_Continue;
}

// timer for (re)checking ALL cvars and net props and everything else
Action Timer_CheckClientConVars(Handle timer, int userid)
{
    // get actual client index
    int cl = GetClientOfUserId(userid);
    // null out timer here
    QueryTimer[cl] = null;
    if (IsValidClient(cl))
    {
        if (!hasWaitedForCvarCheck[cl])
        {
            if (stac_debug.BoolValue)
            {
                StacLog("Client %N can't be checked because they haven't waited 60 seconds for their first cvar check!", cl);
            }
            return Plugin_Continue;
        }
        if (stac_debug.BoolValue)
        {
            StacLog("Checking client id, %i, %L", cl, cl);
        }
        // init variable to pass to QueryCvarsEtc
        int i;
        // query the client!
        QueryCvarsEtc(userid, i);
        // we just checked, but we want to check again eventually
        // lets redo this timer in a random length between stac_min_randomcheck_secs and stac_max_randomcheck_secs
        QueryTimer[cl] =
        CreateTimer
        (
            float_rand
            (
                stac_min_randomcheck_secs.FloatValue, stac_max_randomcheck_secs.FloatValue
            ),
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
    int cl = GetClientOfUserId(userid);
    // don't go no further if client isn't valid!
    if (IsValidClient(cl))
    {
        // check cvars!
        if (i < sizeof(cvarsToCheck))
        {
            // make pack
            DataPack pack = CreateDataPack();
            // actually query the cvar here based on pos in convar array
            QueryClientConVar(cl, cvarsToCheck[i], ConVarCheck);
            // increase pos in convar array
            i++;
            // prepare pack
            WritePackCell(pack, userid);
            WritePackCell(pack, i);
            // reset pack pos to 0
            ResetPack(pack, false);
            // make data timer
            // rand just in case theres some stupid way that cheaters use the nonrandom 2.5 seconds
            // to do nefarious bullshit
            CreateTimer( float_rand(2.5, 5.0), Timer_QueryNextCvar, pack, TIMER_DATA_HNDL_CLOSE);
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
    int cl     = GetClientOfUserId(userid);

    // check validity of client index
    if (IsValidClient(cl))
    {
        QueryCvarsEtc(userid, i);
    }

    return Plugin_Continue;
}

// expensive!
void QueryEverythingAllClients()
{
    if (stac_debug.BoolValue)
    {
        StacLog("Querying all clients");
    }
    // loop thru all clients
    for (int cl = 1; cl <= MaxClients; cl++)
    {
        if (IsValidClient(cl))
        {
            // get userid of this client index
            int userid = GetClientUserId(cl);
            // init variable to pass to QueryCvarsEtc
            int i;
            // query the client!
            QueryCvarsEtc(userid, i);
        }
    }
}
