#pragma semicolon 1

/********** MISC CLIENT JOIN/LEAVE **********/

// client join
public void OnClientPutInServer(int cl)
{
    int userid = GetClientUserId(cl);

    if (IsValidClientOrBot(cl))
    {
        SDKHook(cl, SDKHook_OnTakeDamage, hOnTakeDamage);
    }
    if (IsValidClient(cl))
    {
        // clear per client values
        ClearClBasedVars(userid);
        // clear timer
        QueryTimer[cl] = null;
        // query convars on player connect
        if (DEBUG)
        {
            StacLog("%N joined. Checking cvars", cl);
        }
        QueryTimer[cl] = CreateTimer(30.0, Timer_CheckClientConVars_FirstTime, userid);

        CreateTimer(10.0, CheckAuthOn, userid);

        // bail if cvar is set to 0
        if (maxip > 0)
        {
            checkIP(cl);
        }
    }
    OnClientPutInServer_jaypatch(cl);
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
        StacGeneralPlayerNotify(userid, msg);
        PrintToImportant("{hotpink}[StAC]{white} Too many connections (%i) from the same IP address {mediumpurple}%s{white} from client %N!", sameip, clientIP, cl);
        StacLog(msg);
        KickClient(cl, "[StAC] Too many concurrent connections from your IP address!", maxip);
    }
}

Action CheckAuthOn(Handle timer, int userid)
{
    int cl = GetClientOfUserId(userid);

    if (IsValidClient(cl))
    {
        // don't bother checking if already authed
        if (!IsClientAuthorized(cl))
        {
            SteamAuthFor[cl][0] = '\0';
            if (kickUnauth)
            {
                StacGeneralPlayerNotify(userid, "Reconnecting player for being unauthorized w/ Steam");
                StacLog("Reconnecting %N for not being authorized with Steam.", cl);
                PrintToChat(cl, "You are being reconnected to the server in an attempt to reauthorize you with the Steam network.");
                ClientCommand(cl, "retry");
                // Force clients who ignore the retry to do it anyway.
                CreateTimer(1.0, Reconn, userid);
                // TODO: detect clients that ignore this
                // KickClient(cl, "[StAC] Not authorized with Steam Network, please authorize and reconnect");
            }
            else if (DEBUG)
            {
                StacGeneralPlayerNotify(userid, "Client failed to authorize w/ Steam in a timely manner");
                StacLog("Client %N failed to authorize w/ Steam in a timely manner.", cl);
                SteamAuthFor[cl][0] = '\0';
            }
        }
        else
        {
            char steamid[64];

            // let's try to get their auth
            if (GetClientAuthId(cl, AuthId_Steam2, steamid, sizeof(steamid)))
            {
                // if we get it, copy to our global list
                strcopy(SteamAuthFor[cl], sizeof(SteamAuthFor[]), steamid);
            }
            else
            {
                SteamAuthFor[cl][0] = '\0';
            }
        }
    }

    return Plugin_Continue;
}

Action Reconn(Handle timer, int userid)
{
    int cl = GetClientOfUserId(userid);
    if (IsValidClient(cl))
    {
        StacGeneralPlayerNotify(userid, "Client failed to authorize w/ Steam AND ignored a retry command?? Suspicious! Forcing a reconnection.");
        // If we got this far they're probably cheating, but I need to verify that. Force them in the meantime.
        ReconnectClient(cl);
    }

    return Plugin_Continue;
}

// cache this! we don't need to clear this because it gets overwritten when a new client connects with the same index
public void OnClientAuthorized(int cl, const char[] auth)
{
    if (!IsFakeClient(cl))
    {
        strcopy(SteamAuthFor[cl], sizeof(SteamAuthFor[]), auth);
        if (DEBUG)
        {
            StacLog("Client %N authorized with auth %s.", cl, auth);
        }
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

// Just in case SourceMod whines about this not being used or we wanna do something with this later
public bool OnClientPreConnectEx(const char[] name, char password[255], const char[] ip, const char[] steamID, char rejectReason[255])
{
    return true;
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

    /*

    TODO
    point_worldtext replacement for livefeed

    */
    //if (IsFakeClient(cl))
    //{
    //    return Plugin_Continue;
    //}
    // CreateTimer(1.0, bleh, userid);
    return Plugin_Continue;
}

/*
int test;
Action bleh(Handle timer, int userid)
{
    int cl = GetClientOfUserId(userid);
    //if (!IsFakeClient(cl))
    //{
    //    return Plugin_Continue;
    //}
    int vm = GetEntPropEnt(cl, Prop_Data, "m_hViewModel", 0);
    float vec[3];
    GetEntPropVector(vm, Prop_Data, "m_vecAbsOrigin", vec);

    LogMessage("vec = %f %f %f", vec[0], vec[1], vec[2]);

    int fl = GetEdictFlags(vm);
    fl &= FL_EDICT_ALWAYS;
    SetEdictFlags(vm, fl);
    if (!vm || !IsValidEntity(vm))
    {
        return Plugin_Stop;
    }

    LogMessage("%i", vm);

    int pwt;

    //pwt = pointWorldTextEnts[cl][0];
    //if (pwt && IsValidEntity(pwt))
    //{
    //    RemoveEntity(pwt);
    //}
    pwt = CreateEntityByName("point_worldtext");
    pointWorldTextEnts[cl][0] = pwt;


    DispatchKeyValue        (pwt, "message", "test");
    DispatchKeyValueFloat   (pwt, "textsize", 1.75);
    DispatchKeyValue        (pwt, "color", "255 255 255");
    DispatchKeyValueInt     (pwt, "Orientation", 1);
    // 8 looks pretty good, 9 looks good, 10 looks good, 11 is weirdly colored
    DispatchKeyValueInt     (pwt, "font", 10);
    DispatchSpawn           (pwt);

    SetVariantString        ("!activator");
    AcceptEntityInput       (pwt, "SetParent", vm, -1, -1);

    // in z out, <- x ->, ^ y v
    TeleportEntity          (pwt, { 128.0, 128.0, 128.0 }, NULL_VECTOR, NULL_VECTOR);
    AcceptEntityInput       (pwt, "Enable");
    SetEntityRenderMode     (pwt, RENDER_GLOW);

    pwt = pointWorldTextEnts[cl][1];
    if (pwt && IsValidEntity(pwt))
    {
        RemoveEntity(pwt);
    }
    pwt = CreateEntityByName("point_worldtext");
    pointWorldTextEnts[cl][1] = pwt;

    DispatchKeyValue        (pwt, "message", "test");
    DispatchKeyValueFloat   (pwt, "textsize", 1.75);
    DispatchKeyValue        (pwt, "color", "255 255 255");
    DispatchKeyValueInt     (pwt, "Orientation", 1);
    DispatchKeyValueInt     (pwt, "font", 10);
    DispatchSpawn           (pwt);


    SetVariantString        ("!activator");
    AcceptEntityInput       (pwt, "SetParent", vm, cl);
    TeleportEntity          (pwt, { 48.0, 22.0, -8.0 } , NULL_VECTOR, NULL_VECTOR);
    AcceptEntityInput       (pwt, "Enable");
    SetEntityRenderMode     (pwt, RENDER_GLOW);


    pwt = pointWorldTextEnts[cl][2];
    if (pwt && IsValidEntity(pwt))
    {
        RemoveEntity(pwt);
    }
    pwt = CreateEntityByName("point_worldtext");
    pointWorldTextEnts[cl][2] = pwt;

    DispatchKeyValue        (pwt, "message", "test");
    DispatchKeyValueFloat   (pwt, "textsize", 1.75);
    DispatchKeyValue        (pwt, "color", "255 255 255");
    DispatchKeyValueInt     (pwt, "Orientation", 1);
    DispatchKeyValueInt     (pwt, "font", 10);
    DispatchSpawn           (pwt);


    SetVariantString        ("!activator");
    AcceptEntityInput       (pwt, "SetParent", vm, 0);
    TeleportEntity          (pwt, { 48.0, -24.0, 24.0 } , NULL_VECTOR, NULL_VECTOR);
    AcceptEntityInput       (pwt, "Enable");
    SetEntityRenderMode     (pwt, RENDER_GLOW);
}
*/

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
    // StacDetectionNotify(GetClientUserId(cl), "test", 0);
    // StacLogAngles(GetClientUserId(cl));

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
Action OnAllClientCommands(int client, const char[] command, int argc)
{
    if (client == 0)
    {
        return Plugin_Continue;
    }
    if (StrEqual(command, "menuclosed") || StrEqual(command, "vmodenable"))
    {
        return Plugin_Continue;
    }
    if (signonStateFor[client] <= SIGNONSTATE_SPAWN)
    {
        StacLog("Client %L sent cmd %s b4 signon???", client, command);
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

void ClearClBasedVars(int userid)
{
    // get fresh cli id
    int cl = GetClientOfUserId(userid);
    // clear all old values for cli id based stuff
    turnTimes               [cl] = 0;
    fakeAngDetects          [cl] = 0;
    aimsnapDetects          [cl] = -1; // ignore first detect, it's prolly bunk
    pSilentDetects          [cl] = -1; // ignore first detect, it's prolly bunk
    bhopDetects             [cl] = -1; // set to -1 to ignore single jumps
    cmdnumSpikeDetects      [cl] = 0;
    tbotDetects             [cl] = -1; // ignore first detect, it's prolly bunk
    userinfoSpamDetects     [cl] = 0;


    // TIME SINCE LAST ACTION PER CLIENT
    timeSinceSpawn          [cl] = 0.0;
    timeSinceTaunt          [cl] = 0.0;
    timeSinceTeled          [cl] = 0.0;
    timeSinceNullCmd        [cl] = 0.0;
    timeSinceLastCommand    [cl] = 0.0;

    lastCommandFor          [cl][0] = '\0';
    // STORED GRAVITY STATE PER CLIENT
    highGrav                [cl] = false;
    // STORED MISC VARS PER CLIENT
    playerTaunting          [cl] = false;
    playerInBadCond         [cl] = 0;
    userBanQueued           [cl] = false;
    // STORED SENS PER CLIENT
    sensFor                 [cl] = 0.0;
    // don't bother clearing arrays
    LiveFeedOn              [cl] = false;

    // reset namechanging var
    hasBadName              [cl] = false;

    justClamped             [cl] = false;

    // has client has waited 60 seconds for their first cvar check
    hasWaitedForCvarCheck   [cl] = false;

    signonStateFor          [cl] = -1;
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
