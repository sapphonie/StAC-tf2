#pragma semicolon 1

/********** MISC CLIENT JOIN/LEAVE **********/

// THESE ARE IN ORDER OF OPERATION
// -> OnClientPreConnectEx is called
//      ~0.25 ms pass
// -> player_connect event is called
//      ~50 ms pass
// -> OnClientConnect is called
//      then basically
// -> OnClientConnected is called
//      ~a few seconds pass
// -> OnClientPutInServer is called

// There is almost certainly no way to ever have a client ever trigger OCPCE -> EPC -> OCC out of order
// But just in case we do a ton of checks

static char latestIP        [16];
static char latestSteamID   [MAX_AUTHID_LENGTH];

StringMap IPBuckets = null;
// runs on plugin start
void SetUpIPConnectLeakyBucket()
{
    IPBuckets = new StringMap();
    CreateTimer(5.0, LeakIPConnectBucket, _, TIMER_REPEAT);
    IPBuckets.Clear();
}

// Fired before anything
// CBaseServer::ConnectClient
// which calls (CGameClient*)client->Connect
// Does NOT fire on map change
public bool OnClientPreConnectEx(const char[] name, char password[255], const char[] ip, const char[] steamID, char rejectReason[255])
{
    if (stac_debug.BoolValue)
    {
        StacLog("-> OnClientPreConnectEx (name %s, ip %s) t=%f", name, ip, GetEngineTime());
        StacLog("-> OnClientPreConnectEx (steamid = %s)", steamID);
    }

    // cant use name since some plugins will alter clients' names on connect
    strcopy(latestIP,       sizeof(latestIP),       ip);
    strcopy(latestSteamID,  sizeof(latestSteamID),  steamID);


    if (!stac_prevent_connect_spam.BoolValue)
    {
        return true;
    }

    // TODO: does this need to be higher? or lower? or...?
    static int threshold = 5;
    int connects;
    IPBuckets.GetValue(ip, connects); // 0 if not present
    connects++;
    if (connects >= threshold)
    {
        rejectReason = "Rate limited.";
        
        DataPack steamidPlusIP = new DataPack();
        steamidPlusIP.Reset(true);
        steamidPlusIP.WriteString(steamID);
        steamidPlusIP.WriteString(ip);
        steamidPlusIP.WriteString(name);
        steamidPlusIP.Reset(false);
        
        // This is not arbitrary!
        RequestFrame(DelayedRateLimitBan, steamidPlusIP);

        return false;
    }
    IPBuckets.SetValue(ip, connects);

    if (stac_debug.BoolValue)
    {
        StacLog("-> connects from ip %s %i", ip, connects);
    }

    return true;
}

void DelayedRateLimitBan(DataPack dp)
{
    dp.Reset(false);
    char steamID[MAX_AUTHID_LENGTH];
    char ipAddr[256];
    char playerName[MAX_NAME_LENGTH];
    dp.ReadString(steamID, sizeof(steamID));
    dp.ReadString(ipAddr, sizeof(ipAddr));
    dp.ReadString(playerName, sizeof(playerName));
    dp.Reset(true);
    delete dp;

    static int rateLimitBanTime = 5;

    // BanIdentity(steamID, 60, BANFLAG_AUTHID, "");
    // BanIdentity(ip, 60, BANFLAG_IP, "");

    // THE REASON we are doing this so weirdly, is so that we hook into srcds's built in
    // "firewall", basically, where with the default game banning system,
    // srcds will ignore packets from banned ips.
    // this prevents any clients from spamming, in a way that would otherwise not really be possible,
    // without stupid memory hacks that would be overcomplicated anyway since this already exists

    // We're doing sm_addban / sm_banip because SourceBans, at least, will propagate this to other servers as well
    // which is what we want, so people don't have to get individually banned on each server on the same network that they try to spam on

    // Probably before un-betaing this, i'm going to try to move this to sm_ban and then addip after?
    // I don't really know. it's a tricky race condition here, since we're after OnClientPreConnectEx callback, so they should be rejected,
    // but they can rejoin, but regardless we don't actually have a client index yet?
#if 0
    if ( CommandExists("sm_banip") && CommandExists("sm_addban") )
    {
        ServerCommand("sm_addban %i %s %s",  rateLimitBanTime,   steamID,            "Rate limited");
        ServerCommand("sm_banip  %s %i %s",  ipAddr,             rateLimitBanTime,   "Rate limited");
    }
    else
    {
#endif
        ServerCommand("addip %i %s",        rateLimitBanTime, ipAddr);
        ServerCommand("banid %i %s kick",   rateLimitBanTime, steamID);
#if 0
    }
#endif
    char formattedMsg[1024];
    Format(formattedMsg, sizeof(formattedMsg), "Rate limited %s / %s / %s for %i minutes for connect spam", playerName, steamID, ipAddr, rateLimitBanTime);

    StacLog(formattedMsg);

    StacNotify(0, formattedMsg, 1);
}

Action LeakIPConnectBucket(Handle timer)
{
    if (!stac_prevent_connect_spam.BoolValue)
    {
        IPBuckets.Clear();
        return Plugin_Continue;
    }

    StringMapSnapshot snap = IPBuckets.Snapshot();
    
    for (int i = 0; i < snap.Length; i++)
    {
        char ip[32];
        snap.GetKey(i, ip, sizeof(ip));

        int connects;
        IPBuckets.GetValue(ip, connects); // 0 if not present per zero-init above
        connects--;

        if (stac_debug.BoolValue)
        {
            StacLog("(LeakIPConnectBucket) connects from ip %s %i", ip, connects);
        }

        if (connects <= 0)
        {
            if (stac_debug.BoolValue)
            {
                StacLog("-> connects from ip %s %i [ REMOVING ] ", ip, connects);
            }

            IPBuckets.Remove(ip);
            continue;
        }
        IPBuckets.SetValue(ip, connects);
    }

    delete snap;

    return Plugin_Continue;
}

// Fired after client is allowed thru connect ext
// CGameClient::Connect() ?
// Does NOT fire on map change
public void ePlayerConnect(Handle event, const char[] name, bool dontBroadcast)
{
    /*

        player_connect

        Note:   A new client connected
        Name:   player_connect
        Structure:
        string  name        player name
        byte    index       player slot (entity index-1)
        short   userid      user ID on server (unique on server)
        string  networkid   player network (i.e steam) id
        string  address     ip:port
        short   bot         is a bot

    */
    // it says index. it is the client slot. it is lying.
    // actual client index = slot + 1
    int cl = ( GetEventInt(event, "index") + 1 );

    // wipe the steamid for this client no matter what
    SteamAuthFor[cl][0] = '\0';

    // Don't run any more logic if we're a bot
    bool bot = GetEventBool(event, "bot");
    if (bot)
    {
        return;
    }

    char ipWithPort[24];
    GetEventString(event, "address", ipWithPort, sizeof(ipWithPort), /* default value */ "junk");

    if
    (
        // ip matches - latestIP has no port (for now)
        StrContains(ipWithPort, latestIP) != -1
    )
    {
        strcopy(SteamAuthFor[cl], sizeof(latestSteamID), latestSteamID);
        if (stac_debug.BoolValue)
        {
            StacLog("\n\nplayer_connect steamid = %s\n", SteamAuthFor[cl]);
        }
    }
    // this should LITERALLY NEVER HAPPEN
    else
    {
        char netid[MAX_AUTHID_LENGTH];
        GetEventString(event, "networkid", netid, sizeof(netid), /* default value */ "junk");

        char cname[MAX_NAME_LENGTH];
        GetEventString(event, "name", cname, sizeof(cname), /* default value */ "junk");

        char dbginfo[512];
        Format
        (
            dbginfo,
            sizeof(dbginfo),
            "\n\
            latestIP            = %s \n\
            ipWithPort          = %s \n\
            latestSteamID       = %s \n\
            netid               = %s \n",

            latestIP,
            ipWithPort,
            latestSteamID,
            netid
        );

        char msg[2048];
        Format
        (
            msg,
            sizeof(msg),
            "Client %s somehow triggered a race condition in player_connect.\n \
            Please report this (along with a screenshot of this embed or error message) on the StAC issue tracker on github:\n \
            https://github.com/sapphonie/StAC-tf2/issues\n \
            ```%s```",
            cname,
            dbginfo
        );
        StacNotify(0, msg);

        StacLog("Client %s somehow triggered a race condition in OnClientConnect. Report this error on the GitHub.", cname);
        StacLog(dbginfo);
    }
}

// After player_connect
// CGameClient::CheckConnect which calls
// CServerPlugin::ClientConnect(edict_t *pEntity, const char *pszName, const char *pszAddress, char *reject, int maxrejectlen)
// DOES fire on map change
public bool OnClientConnect(int cl, char[] rejectmsg, int maxlen)
{
    float nowTime = GetEngineTime();

    if (stac_debug.BoolValue)
    {
        StacLog("-> OnClientConnect (index %i)", cl);
        StacLog("-> OnClientConnect t=%f", nowTime);
    }

    return true;
}

public void OnClientConnected(int cl)
{
    if (stac_debug.BoolValue)
    {
        StacLog("-> OnClientConnected (index %i) t=%f", cl, GetEngineTime());
    }
}

// client join
public void OnClientPutInServer(int cl)
{
    if (stac_debug.BoolValue)
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
    if (stac_debug.BoolValue)
    {
        StacLog("%N joined. Checking cvars", cl);
    }
    QueryTimer[cl] = CreateTimer( float_rand(30.0, 45.0), Timer_CheckClientConVars_FirstTime, userid );

    if (!SteamAuthFor[cl][0])
    {
        // LogMessage("NO STEAMAUTH IN ONCLIENTPUTINSERVER");
        // char msg[2048];
        // Format
        // (
        //     msg,
        //     sizeof(msg),
        //     "Client %L had no SteamID in OnClientPutInServer ???\n
        //     This should never happen unless the plugin was reloaded!\n",
        //     cl
        // );
        // StacNotify(userid, msg);
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
        else
        {
            char msg[2048];
            Format
            (
                msg,
                sizeof(msg),
                "Client %L had no SteamID in OnClientPutInServer AND GetClientAuthId failed???\n\
                This should never happen unless the plugin was reloaded AND Steam is down?!\n",
                cl
            );
            StacLog("NO STEAMAUTH IN ONCLIENTPUTINSERVER");
            StacNotify(userid, msg);

            SteamAuthFor[cl][0] = '\0';
        }
    }

    if (stac_debug.BoolValue)
    {
        StacLog("OCPIS steamid = %s", SteamAuthFor[cl]);
    }

    // bail if cvar is set to 0
    if (stac_max_connections_from_ip.IntValue > 0)
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
    if (sameip > stac_max_connections_from_ip.IntValue)
    {
        char msg[256];
        Format(msg, sizeof(msg), "Too many connections from the same IP address %s from client %N", clientIP, cl);
        StacNotify(userid, msg);
        PrintToImportant("{hotpink}[StAC]{white} Too many connections (%i) from the same IP address {mediumpurple}%s{white} from client %N!", sameip, clientIP, cl);
        StacLog(msg);
        KickClient(cl, "[StAC] Too many concurrent connections from your IP address!");
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
    // StacNotify(0, "misc message no client");
    // StacNotify(GetClientUserId(cl), "detection", 1);
    // StacNotify(GetClientUserId(cl), "message");

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
    if
    (
        cl == 0
        ||
        // Ignore connected fake clients
        (IsClientConnected(cl) && IsFakeClient(cl))
    )
    {
        return Plugin_Continue;
    }
    if
    (
           StrEqual(command, "menuclosed")
        || StrEqual(command, "vmodenable")
        || StrEqual(command, "vban")
        || StrEqual(command, "timeleft")
    )
    {
        return Plugin_Continue;
    }
    if (signonStateFor[cl] <= SIGNONSTATE_SPAWN)
    {
        /*
        char msg[1024];
        Format(msg, sizeof(msg), "Client %L sent cmd `%s` before signon", cl, command);

        StacLog(msg);
        StacNotify(GetClientUserId(cl), msg);
        */
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
    //                      [ client index ][history]
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
