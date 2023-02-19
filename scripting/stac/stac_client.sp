#pragma semicolon 1

/********** MISC CLIENT JOIN/LEAVE **********/

// client join
public void OnClientPutInServer(int Cl)
{
    int userid = GetClientUserId(Cl);

    if (IsValidClientOrBot(Cl))
    {
        SDKHook(Cl, SDKHook_OnTakeDamage, hOnTakeDamage);
    }
    if (IsValidClient(Cl))
    {
        // clear per client values
        ClearClBasedVars(userid);
        // clear timer
        QueryTimer[Cl] = null;
        // query convars on player connect
        if (DEBUG)
        {
            StacLog("%N joined. Checking cvars", Cl);
        }
        QueryTimer[Cl] = CreateTimer(30.0, Timer_CheckClientConVars_FirstTime, userid);

        CreateTimer(10.0, CheckAuthOn, userid);

        // bail if cvar is set to 0
        if (maxip > 0)
        {
            checkIP(Cl);
        }
    }
    OnClientPutInServer_jaypatch(Cl);
}

void checkIP(int Cl)
{
    int userid = GetClientUserId(Cl);
    char clientIP[16];
    GetClientIP(Cl, clientIP, sizeof(clientIP));

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
        Format(msg, sizeof(msg), "Too many connections from the same IP address %s from client %N", clientIP, Cl);
        StacGeneralPlayerNotify(userid, msg);
        PrintToImportant("{hotpink}[StAC]{white} Too many connections (%i) from the same IP address {mediumpurple}%s{white} from client %N!", sameip, clientIP, Cl);
        StacLog(msg);
        KickClient(Cl, "[StAC] Too many concurrent connections from your IP address!", maxip);
    }
}

Action CheckAuthOn(Handle timer, int userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        // don't bother checking if already authed
        if (!IsClientAuthorized(Cl))
        {
            SteamAuthFor[Cl][0] = '\0';
            if (kickUnauth)
            {
                StacGeneralPlayerNotify(userid, "Reconnecting player for being unauthorized w/ Steam");
                StacLog("Reconnecting %N for not being authorized with Steam.", Cl);
                PrintToChat(Cl, "You are being reconnected to the server in an attempt to reauthorize you with the Steam network.");
                ClientCommand(Cl, "retry");
                // Force clients who ignore the retry to do it anyway.
                CreateTimer(1.0, Reconn, userid);
                // TODO: detect clients that ignore this
                // KickClient(Cl, "[StAC] Not authorized with Steam Network, please authorize and reconnect");
            }
            else if (DEBUG)
            {
                StacGeneralPlayerNotify(userid, "Client failed to authorize w/ Steam in a timely manner");
                StacLog("Client %N failed to authorize w/ Steam in a timely manner.", Cl);
                SteamAuthFor[Cl][0] = '\0';
            }
        }
        else
        {
            char steamid[64];

            // let's try to get their auth
            if (GetClientAuthId(Cl, AuthId_Steam2, steamid, sizeof(steamid)))
            {
                // if we get it, copy to our global list
                strcopy(SteamAuthFor[Cl], sizeof(SteamAuthFor[]), steamid);
            }
            else
            {
                SteamAuthFor[Cl][0] = '\0';
            }
        }
    }

    return Plugin_Continue;
}

Action Reconn(Handle timer, int userid)
{
    int Cl = GetClientOfUserId(userid);
    if (IsValidClient(Cl))
    {
        StacGeneralPlayerNotify(userid, "Client failed to authorize w/ Steam AND ignored a retry command?? Suspicious! Forcing a reconnection.");
        // If we got this far they're probably cheating, but I need to verify that. Force them in the meantime.
        ReconnectClient(Cl);
    }

    return Plugin_Continue;
}

// cache this! we don't need to clear this because it gets overwritten when a new client connects with the same index
public void OnClientAuthorized(int Cl, const char[] auth)
{
    if (!IsFakeClient(Cl))
    {
        strcopy(SteamAuthFor[Cl], sizeof(SteamAuthFor[]), auth);
        if (DEBUG)
        {
            StacLog("Client %N authorized with auth %s.", Cl, auth);
        }
    }
}

// player left and mapchanges
public void OnClientDisconnect(int Cl)
{
    int userid = GetClientUserId(Cl);
    // clear per client values
    ClearClBasedVars(userid);
    delete QueryTimer[Cl];
}

// player is OUT of the server
public void ePlayerDisconnect(Handle event, const char[] name, bool dontBroadcast)
{
    int Cl = GetClientOfUserId(GetEventInt(event, "userid"));
    SteamAuthFor[Cl][0] = '\0';
}

// Just in case SourceMod whines about this not being used or we wanna do something with this later
public bool OnClientPreConnectEx(const char[] name, char password[255], const char[] ip, const char[] steamID, char rejectReason[255])
{
    return true;
}

/********** CLIENT BASED EVENTS **********/

public Action ePlayerSpawned(Handle event, char[] name, bool dontBroadcast)
{
    int Cl = GetClientOfUserId(GetEventInt(event, "userid"));
    //int userid = GetEventInt(event, "userid");
    if (IsValidClient(Cl))
    {
        timeSinceSpawn[Cl] = GetEngineTime();
    }

    /*

    TODO
    point_worldtext replacement for livefeed

    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "point_worldtext")) != -1)
    {
        if (IsValidEntity(ent))
        {
            RemoveEntity(ent);
        }
    }

    pwt = CreateEntityByName("point_worldtext");
    DispatchKeyValue        (pwt, "message", "test");
    DispatchKeyValueFloat   (pwt, "textsize", 2.5);
    DispatchKeyValue        (pwt, "color", "255 105 180");
    DispatchKeyValueInt     (pwt, "Orientation", 1);
    // 8 looks pretty good, 9 looks good, 10 looks good, 11 is weirdly colored
    DispatchKeyValueInt     (pwt, "font", 10);
    // SetEntityMoveType       (pwt, MOVETYPE_PUSH);
    DispatchSpawn           (pwt);

    int vm = GetEntPropEnt(Cl, Prop_Data, "m_hViewModel", 0);

    SetVariantString        ("!activator");
    AcceptEntityInput       (pwt, "SetParent", vm, 0);
    // ?, ?, y
    TeleportEntity          (pwt, {32.0, 24.0, 24.0 } , NULL_VECTOR, NULL_VECTOR);
    AcceptEntityInput       (pwt, "Enable");
    SetEntityRenderMode(pwt, RENDER_GLOW);

    */
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
    int Cl = TE_ReadNum("m_iPlayer") + 1;
    // this user fired a bullet this frame!
    didBangThisFrame[Cl] = true;

    // For testing discord notifs
    // StacDetectionNotify(GetClientUserId(Cl), "test", 0);
    // StacLogAngles(GetClientUserId(Cl));

    return Plugin_Continue;
}

public Action TF2_OnPlayerTeleport(int Cl, int teleporter, bool& result)
{
    if (IsValidClient(Cl))
    {
        timeSinceTeled[Cl] = GetEngineTime();
    }

    return Plugin_Continue;
}

public void TF2_OnConditionAdded(int Cl, TFCond condition)
{
    if (IsValidClient(Cl))
    {
        if (condition == TFCond_Taunting)
        {
            playerTaunting[Cl] = true;
        }
        else if (IsHalloweenCond(condition))
        {
            playerInBadCond[Cl]++;
        }
    }
}

public void TF2_OnConditionRemoved(int Cl, TFCond condition)
{
    if (IsValidClient(Cl))
    {
        if (condition == TFCond_Taunting)
        {
            timeSinceTaunt[Cl] = GetEngineTime();
            playerTaunting[Cl] = false;
        }
        else if (IsHalloweenCond(condition))
        {
            if (playerInBadCond[Cl] > 0)
            {
                playerInBadCond[Cl]--;
            }
        }
    }
}

public Action ePlayerChangedName(Handle event, char[] name, bool dontBroadcast)
{
    int userid = GetEventInt(event, "userid");

    int Cl = GetClientOfUserId(userid);

    if (hasBadName[Cl])
    {
        hasBadName[Cl] = false;
        return Plugin_Continue;
    }
    NameCheck(userid);

    return Plugin_Continue;
}

public Action ePlayerAchievement(Handle event, char[] name, bool dontBroadcast)
{
    // ent index of achievement earner
    int Cl              = GetEventInt(event, "player");
    int userid          = GetClientUserId(Cl);

    // id of our achievement
    int achieve_id      = GetEventInt(event, "achievement");
    cheevCheck(userid, achieve_id);

    return Plugin_Continue;
}

// Ignore cmds from unconnected clients
Action OnAllClientCommands(int client, const char[] command, int argc)
{
    if (client == 0)
    {
        return Plugin_Continue;
    }
    if (StrEqual(command, "menuclosed"))
    {
        return Plugin_Continue;
    }
    if (signonStateFor[client] <= SIGNONSTATE_SPAWN)
    {
        LogMessage("cmd = %s", command);
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

void ClearClBasedVars(int userid)
{
    // get fresh cli id
    int Cl = GetClientOfUserId(userid);
    // clear all old values for cli id based stuff
    turnTimes               [Cl] = 0;
    fakeAngDetects          [Cl] = 0;
    aimsnapDetects          [Cl] = -1; // ignore first detect, it's prolly bunk
    pSilentDetects          [Cl] = -1; // ignore first detect, it's prolly bunk
    bhopDetects             [Cl] = -1; // set to -1 to ignore single jumps
    cmdnumSpikeDetects      [Cl] = 0;
    tbotDetects             [Cl] = -1; // ignore first detect, it's prolly bunk
    userinfoSpamDetects     [Cl] = 0;


    // TIME SINCE LAST ACTION PER CLIENT
    timeSinceSpawn          [Cl] = 0.0;
    timeSinceTaunt          [Cl] = 0.0;
    timeSinceTeled          [Cl] = 0.0;
    timeSinceNullCmd        [Cl] = 0.0;
    timeSinceLastCommand    [Cl] = 0.0;

    lastCommandFor          [Cl][0] = '\0';
    // STORED GRAVITY STATE PER CLIENT
    highGrav                [Cl] = false;
    // STORED MISC VARS PER CLIENT
    playerTaunting          [Cl] = false;
    playerInBadCond         [Cl] = 0;
    userBanQueued           [Cl] = false;
    // STORED SENS PER CLIENT
    sensFor                 [Cl] = 0.0;
    // don't bother clearing arrays
    LiveFeedOn              [Cl] = false;

    // reset namechanging var
    hasBadName              [Cl] = false;


    for (int cvar; cvar < sizeof(userinfoToCheck); cvar++)
    {
        userinfoValues[cvar][Cl][0][0] = '\0';
        userinfoValues[cvar][Cl][1][0] = '\0';
        userinfoValues[cvar][Cl][2][0] = '\0';
        userinfoValues[cvar][Cl][3][0] = '\0';
    }
    justclamped             [Cl] = false;

    // has client has waited 60 seconds for their first cvar check
    hasWaitedForCvarCheck   [Cl] = false;

    signonStateFor          [Cl] = -1;
}

/********** TIMER FOR NETINFO **********/
// CNetChan::FlowUpdate
public Action Timer_GetNetInfo(Handle timer)
{
    // reset all client based vars on plugin reload
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            // convert to percentages
            lossFor[Cl]      = GetClientAvgLoss(Cl, NetFlow_Both) * 100.0;
            chokeFor[Cl]     = GetClientAvgChoke(Cl, NetFlow_Both) * 100.0;
            inchokeFor[Cl]   = GetClientAvgChoke(Cl, NetFlow_Incoming) * 100.0;
            outchokeFor[Cl]  = GetClientAvgChoke(Cl, NetFlow_Outgoing) * 100.0;
            // convert to ms
            pingFor[Cl]      = GetClientLatency(Cl, NetFlow_Both) * 1000.0;
            rateFor[Cl]      = GetClientAvgData(Cl, NetFlow_Both) / 125.0;
            ppsFor[Cl]       = GetClientAvgPackets(Cl, NetFlow_Both);
            if (LiveFeedOn[Cl])
            {
                LiveFeed_NetInfo(GetClientUserId(Cl));
            }
        }
    }
    return Plugin_Continue;
}
