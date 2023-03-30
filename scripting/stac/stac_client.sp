#pragma semicolon 1

/********** MISC CLIENT JOIN/LEAVE **********/

// THESE ARE IN ORDER OF OPERATION
// OnClientPreConnectEx
//      ~0.25 ms
// -> player_connect event
//      ~50 ms
// -> OnClientConnect
//      basically instant
// -> OnClientConnected
//      ~a few seconds
// -> OnClientPutInServer

// There is almost certainly no way to ever have a client ever trigger OCPCE -> EPC -> OCC out of order
// But just in case we do a ton of checks

static int  latestUserid;
static char latestName     [MAX_NAME_LENGTH];
static char latestIP       [16];
static char latestSteamID  [MAX_AUTHID_LENGTH];
static float latestPreConnect;
static float latesteConnect;

// Fired before anything
// CBaseServer::ConnectClient
// Does NOT fire on map change
public bool OnClientPreConnectEx(const char[] name, char password[255], const char[] ip, const char[] steamID, char rejectReason[255])
{
    if (DEBUG)
    {
        StacLog("-> OnClientPreConnectEx (name %s, ip %s) t=%f", name, ip, GetEngineTime());
    }

    latestPreConnect = GetEngineTime();

    strcopy(latestName,     sizeof(latestName),     name);
    strcopy(latestIP,       sizeof(latestIP),       ip);
    strcopy(latestSteamID,  sizeof(latestSteamID),  steamID);

    return true;
}

// Fired after client is allowed thru connect ext
// CBaseClient::SendFullConnectEvent() ?
// Does NOT fire on map change
public void ePlayerConnect(Handle event, const char[] name, bool dontBroadcast)
{
    latesteConnect = GetEngineTime();

    int userid = (GetEventInt(event, "userid"));
    if (DEBUG)
    {
        StacLog("-> player_connect (userid %i) t=%f", userid, GetEngineTime());
    }
    latestUserid = userid;
}

// After player_connect
// DOES fire on map change
public bool OnClientConnect(int cl, char[] rejectmsg, int maxlen)
{
    float nowTime = GetEngineTime();

    if (DEBUG)
    {
        StacLog("-> OnClientConnect (index %i)", cl);
        StacLog("-> OnClientConnect     t=%f", nowTime);
        StacLog("-> latestPreConnect    t=%f", latestPreConnect);
        StacLog("-> latesteConnect      t=%f", latesteConnect);
    }

    // OCPCE   t=2940.308837
    // eCC     t=2940.309082
    // OCC     t=2940.383789
    if
    (
        // Bot
        IsFakeClient(cl)
        // don't rerun logic if we didn't JUST fire preconnect AND player_connect
        || (nowTime - 0.5 >= latestPreConnect)
        || (nowTime - 0.5 >= latesteConnect)
    )
    {
        return true;
    }

    SteamAuthFor[cl][0] = '\0';

    int userid = GetClientUserId(cl);

    char clName[MAX_NAME_LENGTH];
    GetClientName(cl, clName, sizeof(clName));

    char clIP[16];
    GetClientIP(cl, clIP, sizeof(clIP), /* removeport */ true);

    if
    (
           latestUserid == userid
        && StrEqual(latestName, clName)
        && StrEqual(latestIP, clIP)
    )
    {
        strcopy(SteamAuthFor[cl], sizeof(latestSteamID), latestSteamID);
        if (DEBUG)
        {
            StacLog("OnClientConnect steamid = %s", SteamAuthFor[cl]);
        }
    }
    else
    {
        char dbginfo[512];
        Format
        (
            dbginfo,
            sizeof(dbginfo),
            "\n\
            latestUserid    = %i \n\
            userid          = %i \n\
            latestName      = %s \n\
            clName          = %s \n\
            latestIP        = %s \n\
            clIP            = %s \n",
            userid,
            latestUserid,
            latestName,
            clName,
            latestIP,
            clIP
        );

        char msg[2048];
        Format
        (
            msg,
            sizeof(msg),
            "Client %L somehow triggered a race condition in OnClientConnect.\n \
            Please report this (along with a screenshot of this embed or error message) on the StAC issue tracker on github:\n \
            https://github.com/sapphonie/StAC-tf2/issues\n \
            ```%s```",
            cl,
            dbginfo
        );
        StacNotify(userid, msg);

        StacLog("Client %L somehow triggered a race condition in OnClientConnect. Report this error on the GitHub.", cl);
        StacLog(dbginfo);

#if defined( DC_ON_CONNECTION_RACECON )
        strcopy(rejectmsg, maxlen, "Didn't fire proper connection functions. Please reconnect");
        return false;
#endif

    }

    return true;
}

public void OnClientConnected(int cl)
{
    if (DEBUG)
    {
        StacLog("-> OnClientConnected (index %i) t=%f", cl, GetEngineTime());
    }
}

// client join
public void OnClientPutInServer(int cl)
{
    if (DEBUG)
    {
        StacLog("-> OnClientPutInServer (index %i) t=%f", cl, GetEngineTime());
    }

    int userid = GetClientUserId(cl);

    if (IsValidClientOrBot(cl))
    {
        SDKHook(cl, SDKHook_OnTakeDamage, hOnTakeDamage);
    }

    OnClientPutInServer_jaypatch(cl);

    if (!IsValidClient(cl))
    {
        return;
    }

    // clear per client values
    ClearClBasedVars(userid);
    // clear timer
    QueryTimer[cl] = null;
    // query convars on player connect
    if (DEBUG)
    {
        StacLog("%N joined. Checking cvars", cl);
    }
    QueryTimer[cl] = CreateTimer( float_rand(30.0, 45.0), Timer_CheckClientConVars_FirstTime, userid );

    if (!SteamAuthFor[cl][0])
    {
        LogMessage("NO STEAMAUTH IN ONCLIENTPUTINSERVER");
        char msg[2048];
        Format
        (
            msg,
            sizeof(msg),
            "Client %L had no SteamID in OnClientPutInServer ???\n\
            This should never happen unless the plugin was reloaded!\n",
            cl
        );
        StacNotify(userid, msg);
        char steamid[MAX_AUTHID_LENGTH];

        // let's try to get their auth
        if (GetClientAuthId(cl, AuthId_Steam2, steamid, sizeof(steamid)))
        {
            // if we get it, copy to our global list
            strcopy(SteamAuthFor[cl], sizeof(SteamAuthFor[]), steamid);
        }
        // We should only get here on lateload AND if a client is unauthorized
        // Theoretically we could either not verify the client's steamid OR force reconnect clients
        // But 1 is unsafe and 2 is annoying, especially for such a corner case
        /*
        else
        {
            SteamAuthFor[cl][0] = '\0';
        }
        */
    }

    if (DEBUG)
    {
        StacLog("OCPIS steamid = %s", SteamAuthFor[cl]);
    }

    // bail if cvar is set to 0
    if (maxip > 0)
    {
        checkIP(cl);
    }
}

void checkIP(int cl)
{
    int userid = GetClientUserId(cl);
    char clientIP[16];
    GetClientIP(cl, clientIP, sizeof(clientIP));

    int sameip;

    for (int itercl = 1; itercl <= MaxClients; itercl++)
    {
        if (IsValidClient(itercl))
        {
            char playersip[16];
            GetClientIP(itercl, playersip, sizeof(playersip));

            if (StrEqual(clientIP, playersip))
            {
                sameip++;
            }
        }
    }

    // maxip is our cached stac_max_connections_from_ip
    if (sameip > maxip)
    {
        char msg[256];
        Format(msg, sizeof(msg), "Too many connections from the same IP address %s from client %N", clientIP, cl);
        StacNotify(userid, msg);
        PrintToImportant("{hotpink}[StAC]{white} Too many connections (%i) from the same IP address {mediumpurple}%s{white} from client %N!", sameip, clientIP, cl);
        StacLog(msg);
        KickClient(cl, "[StAC] Too many concurrent connections from your IP address!", maxip);
    }
}

// player left and mapchanges
public void OnClientDisconnect(int cl)
{
    int userid = GetClientUserId(cl);
    // clear per client values
    ClearClBasedVars(userid);
    delete QueryTimer[cl];
}

// player is OUT of the server
public void ePlayerDisconnect(Handle event, const char[] name, bool dontBroadcast)
{
    int cl = GetClientOfUserId(GetEventInt(event, "userid"));
    SteamAuthFor[cl][0] = '\0';
}

/********** CLIENT BASED EVENTS **********/
public Action ePlayerSpawned(Handle event, char[] name, bool dontBroadcast)
{
    int userid = GetEventInt(event, "userid");
    int cl = GetClientOfUserId(userid);
    if (IsValidClient(cl))
    {
        timeSinceSpawn[cl] = GetEngineTime();
    }
    return Plugin_Continue;
}

public Action hOnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3])
{
    // ignore if it's a mvm robot weapon or an mvm robot or the world doing damage
    if (!IsValidEntity(weapon) || weapon <= 0 || !IsValidClient(attacker))
    {
        return Plugin_Continue;
    }

    // get ent classname AKA the weapon name
    GetEntityClassname(weapon, hurtWeapon[attacker], sizeof(hurtWeapon[]));
    if
    (
        // player didn't hurt self
        victim != attacker
        // not fire
        && !(damagetype & DMG_IGNITE)
        && !(damagetype & TF_CUSTOM_BURNING_FLARE)
        && !(damagetype & TF_CUSTOM_BURNING)
    )
    {
        didHurtThisFrame[attacker] = true;
    }
    return Plugin_Continue;
}

public Action Hook_TEFireBullets(const char[] te_name, const int[] players, int numClients, float delay)
{
    int cl = TE_ReadNum("m_iPlayer") + 1;
    // this user fired a bullet this frame!
    didBangThisFrame[cl] = true;

    // For testing discord notifs
    StacNotify(0, "misc message no client");
    StacNotify(GetClientUserId(cl), "detection", 1);
    StacNotify(GetClientUserId(cl), "message");

    return Plugin_Continue;
}

public Action TF2_OnPlayerTeleport(int cl, int teleporter, bool& result)
{
    if (IsValidClient(cl))
    {
        timeSinceTeled[cl] = GetEngineTime();
    }

    return Plugin_Continue;
}

public void TF2_OnConditionAdded(int cl, TFCond condition)
{
    if (IsValidClient(cl))
    {
        if (condition == TFCond_Taunting)
        {
            playerTaunting[cl] = true;
        }
        else if (IsHalloweenCond(condition))
        {
            playerInBadCond[cl]++;
        }
    }
}

public void TF2_OnConditionRemoved(int cl, TFCond condition)
{
    if (IsValidClient(cl))
    {
        if (condition == TFCond_Taunting)
        {
            timeSinceTaunt[cl] = GetEngineTime();
            playerTaunting[cl] = false;
        }
        else if (IsHalloweenCond(condition))
        {
            if (playerInBadCond[cl] > 0)
            {
                playerInBadCond[cl]--;
            }
        }
    }
}

public Action ePlayerChangedName(Handle event, char[] name, bool dontBroadcast)
{
    int userid = GetEventInt(event, "userid");

    int cl = GetClientOfUserId(userid);

    // I dont remember why this is here..........
    if (hasBadName[cl])
    {
        hasBadName[cl] = false;
        return Plugin_Continue;
    }
    NameCheck(userid);

    return Plugin_Continue;
}

public Action ePlayerAchievement(Handle event, char[] name, bool dontBroadcast)
{
    // ent index of achievement earner
    int cl              = GetEventInt(event, "player");
    int userid          = GetClientUserId(cl);

    // id of our achievement
    int achieve_id      = GetEventInt(event, "achievement");
    cheevCheck(userid, achieve_id);

    return Plugin_Continue;
}

// Ignore cmds from unconnected clients
Action OnAllClientCommands(int cl, const char[] command, int argc)
{
    if (cl == 0 || IsFakeClient(cl))
    {
        return Plugin_Continue;
    }
    if (StrEqual(command, "menuclosed") || StrEqual(command, "vmodenable"))
    {
        return Plugin_Continue;
    }
    if (signonStateFor[cl] <= SIGNONSTATE_SPAWN)
    {
        char msg[1024];
        Format(msg, sizeof(msg), "Client %L sent cmd `%s` before signon", cl, command);

        StacLog(msg);
        StacNotify(GetClientUserId(cl), msg);

        return Plugin_Handled;
    }
    return Plugin_Continue;
}

void ClearClBasedVars(int userid)
{
    // get fresh cli id
    int cl = GetClientOfUserId(userid);
    // clear all old values for cli id based stuff
    /***** client based stuff *****/

    // cheat detections per client
    turnTimes               [cl] = 0;
    fakeAngDetects          [cl] = 0;
    aimsnapDetects          [cl] = -1; // set to -1 to ignore first detections, as theyre most likely junk
    pSilentDetects          [cl] = -1; // ^
    bhopDetects             [cl] = -1; // set to -1 to ignore single jumps
    cmdnumSpikeDetects      [cl] = 0;
    tbotDetects             [cl] = -1;
    invalidUsercmdDetects   [cl] = 0;

    // frames since client "did something"
    //                      [ client index ][history]
    timeSinceSpawn          [cl] = 0.0;
    timeSinceTaunt          [cl] = 0.0;
    timeSinceTeled          [cl] = 0.0;
    timeSinceLastCommand    [cl] = 0.0;
    // ticks since client "did something"
    //                  [ client index ][history]
    didBangThisFrame        [cl] = false;
    didHurtThisFrame        [cl] = false;

    // SteamAuthFor            [cl][0] = '\0';

    highGrav                [cl] = false;
    playerTaunting          [cl] = false;
    playerInBadCond         [cl] = 0;
    userBanQueued           [cl] = false;
    sensFor                 [cl] = 0.0;
    // weapon name, gets passed to aimsnap check
    hurtWeapon              [cl][0] = '\0';
    lastCommandFor          [cl][0] = '\0';
    LiveFeedOn              [cl] = false;

    checkLiveFeed();
    hasBadName              [cl] = false;

    // network info
    lossFor                 [cl] = 0.0;
    chokeFor                [cl] = 0.0;
    inchokeFor              [cl] = 0.0;
    outchokeFor             [cl] = 0.0;
    pingFor                 [cl] = 0.0;
    avgPingFor              [cl] = 0.0;
    rateFor                 [cl] = 0.0;
    ppsFor                  [cl] = 0.0;

    // time since the last stutter/lag spike occurred per client
    timeSinceLagSpikeFor    [cl] = 0.0;

    // do we need to do this
    // QueryTimer           [cl] = null;

    // for checking if we just fixed a client's network settings so we don't double detect
    justClamped             [cl] = false;

    // tps etc
    tickspersec             [cl] = 0;
    // iterated tick num per client
    t                       [cl] = 0;

    secTime                 [cl] = 0.0;

    hasWaitedForCvarCheck   [cl] = false;

    signonStateFor          [cl] = -1;

    timeSinceLastRecvFor    [cl] = 0.0;
}

/********** TIMER FOR NETINFO **********/
// CNetChan::FlowUpdate
public Action Timer_GetNetInfo(Handle timer)
{
    // reset all client based vars on plugin reload
    for (int cl = 1; cl <= MaxClients; cl++)
    {
        if (IsValidClient(cl))
        {
            // convert to percentages
            lossFor[cl]      = GetClientAvgLoss(cl, NetFlow_Incoming)   * 100.0;
            chokeFor[cl]     = GetClientAvgChoke(cl, NetFlow_Both)      * 100.0;
            inchokeFor[cl]   = GetClientAvgChoke(cl, NetFlow_Incoming)  * 100.0;
            outchokeFor[cl]  = GetClientAvgChoke(cl, NetFlow_Outgoing)  * 100.0;
            // convert to ms
            pingFor[cl]      = GetClientLatency(cl, NetFlow_Both)       * 1000.0;
            avgPingFor[cl]   = GetClientAvgLatency(cl, NetFlow_Both)    * 1000.0;
            rateFor[cl]      = GetClientAvgData(cl, NetFlow_Both)       / 125.0;
            ppsFor[cl]       = GetClientAvgPackets(cl, NetFlow_Both);
            if (LiveFeedOn[cl])
            {
                LiveFeed_NetInfo(GetClientUserId(cl));
            }
        }
    }
    return Plugin_Continue;
}
