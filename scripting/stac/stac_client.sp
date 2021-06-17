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
            StacLog("[StAC] %N joined. Checking cvars", Cl);
        }
        QueryTimer[Cl] = CreateTimer(5.0, Timer_CheckClientConVars, userid);

        CreateTimer(2.5, CheckAuthOn, userid);
    }
    OnClientPutInServer_jaypatch(Cl);
}

Action CheckAuthOn(Handle timer, int userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        // don't bother checking if already authed and DEFINITELY don't check if steam is down or there's no way to do so thru an ext
        if (!IsClientAuthorized(Cl))
        {
            if (shouldCheckAuth())
            {
                SteamAuthFor[Cl][0] = '\0';
                if (kickUnauth)
                {
                    StacGeneralPlayerDiscordNotify(userid, "Kicked for being unauthorized w/ Steam");
                    StacLog("[StAC] Kicking %N for not being authorized with Steam.", Cl);
                    KickClient(Cl, "[StAC] Not authorized with Steam Network, please authorize and reconnect");
                }
                else
                {
                    StacGeneralPlayerDiscordNotify(userid, "Client failed to authorize w/ Steam in a timely manner");
                    StacLog("[StAC] Client %N failed to authorize w/ Steam in a timely manner.", Cl);
                }
            }
        }
        else
        {
            char steamid[64];

            // let's try to get their auth anyway
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
}

// cache this! we don't need to clear this because it gets overwritten when a new client connects with the same index
public void OnClientAuthorized(int Cl, const char[] auth)
{
    if (!IsFakeClient(Cl))
    {
        strcopy(SteamAuthFor[Cl], sizeof(SteamAuthFor[]), auth);
        //StacLog("auth %s for Cl %N", auth, Cl);
    }
}

public void OnClientDisconnect(int Cl)
{
    int userid = GetClientUserId(Cl);
    // clear per client values
    ClearClBasedVars(userid);
    delete QueryTimer[Cl];
}

// player is OUT of the server
void ePlayerDisconnect(Handle event, const char[] name, bool dontBroadcast)
{
    int Cl = GetClientOfUserId(GetEventInt(event, "userid"));
    SteamAuthFor[Cl][0] = '\0';
}

/********** CLIENT BASED EVENTS **********/

Action ePlayerSpawned(Handle event, char[] name, bool dontBroadcast)
{
    int Cl = GetClientOfUserId(GetEventInt(event, "userid"));
    //int userid = GetEventInt(event, "userid");
    if (IsValidClient(Cl))
    {
        timeSinceSpawn[Cl] = GetEngineTime();
    }
}

Action hOnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3])
{
    // get ent classname AKA the weapon name
    if (!IsValidEntity(weapon) || weapon <= 0 || !IsValidClient(attacker))
    {
        return Plugin_Continue;
    }

    GetEntityClassname(weapon, hurtWeapon[attacker], 256);
    if
    (
        // player didn't hurt self
           victim != attacker
    )
    {
        didHurtThisFrame[attacker] = true;
    }
    return Plugin_Continue;
}

Action Hook_TEFireBullets(const char[] te_name, const int[] players, int numClients, float delay)
{
    int Cl = TE_ReadNum("m_iPlayer") + 1;
    // this user fired a bullet this frame!
    didBangThisFrame[Cl] = true;
}

public Action TF2_OnPlayerTeleport(int Cl, int teleporter, bool& result)
{
    if (IsValidClient(Cl))
    {
        timeSinceTeled[Cl] = GetEngineTime();
    }
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
    spinbotDetects          [Cl] = 0;
    userinfoSpamDetects     [Cl] = 0;



    maxTickCountFor         [Cl] = 0;

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


    for (int cvar; cvar < sizeof(userinfoToCheck); cvar++)
    {
        userinfoValues[cvar][Cl][0][0] = '\0';
        userinfoValues[cvar][Cl][1][0] = '\0';
        userinfoValues[cvar][Cl][2][0] = '\0';
        userinfoValues[cvar][Cl][3][0] = '\0';
    }
    justclamped             [Cl] = false;
}
