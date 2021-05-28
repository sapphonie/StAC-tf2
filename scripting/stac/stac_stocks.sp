/********** ISVALIDCLIENT STUFF *********/

bool IsValidClient(int client)
{
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && !IsClientInKickQueue(client)
        && !userBanQueued[client]
        && !IsFakeClient(client)
    );
}

bool IsValidClientOrBot(int client)
{
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && !IsClientInKickQueue(client)
        && !userBanQueued[client]
        // don't bother sdkhooking stv or replay bots lol
        && !IsClientSourceTV(client)
        && !IsClientReplay(client)
    );
}

bool IsValidAdmin(int Cl)
{
    if (IsValidClient(Cl))
    {
        if (CheckCommandAccess(Cl, "sm_ban", ADMFLAG_GENERIC))
        {
            return true;
        }
    }
    return false;
}

bool IsValidSrcTV(int client)
{
    return
    (
        (0 < client <= MaxClients)
        && IsClientInGame(client)
        && IsClientSourceTV(client)
    );
}

/********** MISC FUNCS **********/

void BanUser(int userid, char[] reason, char[] pubreason)
{
    int Cl = GetClientOfUserId(userid);

    // prevent double bans
    if (userBanQueued[Cl])
    {
        KickClient(Cl, "Banned by StAC");
        return;
    }

    // make sure we dont detect on already banned players
    userBanQueued[Cl] = true;

    // check if client is authed before banning normally
    bool isAuthed = IsClientAuthorized(Cl);

    if (demonameInBanReason)
    {
        if (GetDemoName())
        {
            char demoname_plus[256];
            strcopy(demoname_plus, sizeof(demoname_plus), demoname);
            Format(demoname_plus, sizeof(demoname_plus), ". Demo file: %s", demoname_plus);
            StrCat(reason, 256, demoname_plus);
            StacLog("Reason: %s", reason);
        }
        else
        {
            StacLog("[StAC] No STV demo is being recorded, no demo name will be printed to the ban reason!");
        }
    }
    if (isAuthed)
    {
        if (SOURCEBANS)
        {
            SBPP_BanPlayer(0, Cl, 0, reason);
            // there's no return value for that native, so we have to just assume it worked lol
            return;
        }
        if (GBANS)
        {
            ServerCommand("gb_ban %i, 0, %s", userid, reason);
            // there's no return value nor a native for gbans bans (YET), so we have to just assume it worked lol
            return;
        }
        // stock tf2, no ext ban system. if we somehow fail here, keep going.
        if (BanClient(Cl, 0, BANFLAG_AUTO, reason, reason, _, _))
        {
            return;
        }
    }
    // if we got here steam is being fussy or the client is not auth'd in some way, or the stock tf2 ban failed somehow.
    StacLog("Client %N is not authorized, steam is down, or the ban failed for some other reason. Attempting to ban with cached SteamID...", Cl);
    // if this returns true, we can still ban the client with their steamid in a roundabout and annoying way.
    if (!IsActuallyNullString(SteamAuthFor[Cl]))
    {
        ServerCommand("sm_addban 0 \"%s\" %s", SteamAuthFor[Cl], reason);
        KickClient(Cl, "%s", reason);
    }
    // if the above returns false, we can only do ip :/
    else
    {
        char ip[16];
        GetClientIP(Cl, ip, sizeof(ip));

        StacLog("[StAC] No cached SteamID for %N! Banning with IP %s...", Cl, ip);
        ServerCommand("sm_banip %s 0 %s", ip, reason);
        // this kick client might not be needed - you get kicked by "being added to ban list"
        // KickClient(Cl, "%s", reason);
    }

    MC_PrintToChatAll("%s", pubreason);
    StacLog("%s", pubreason);
}

bool GetDemoName()
{
    char tvStatus[512];
    ServerCommandEx(tvStatus, sizeof(tvStatus), "tv_status");
    char demoname_etc[128];
    if (MatchRegex(demonameRegex, tvStatus) > 0)
    {
        if (GetRegexSubString(demonameRegex, 0, demoname_etc, sizeof(demoname_etc)))
        {
            TrimString(demoname_etc);
            if (MatchRegex(demonameRegexFINAL, demoname_etc) > 0)
            {
                if (GetRegexSubString(demonameRegexFINAL, 0, demoname, sizeof(demoname)))
                {
                    TrimString(demoname);
                    StripQuotes(demoname);
                    return true;
                }
            }
        }
    }
    demoname = "N/A";
    return false;
}

bool isDefaultTickrate()
{
    if (tps > 60.0 && tps < 70.0)
    {
        return true;
    }
    return false;
}

// sourcemod is fucking ridiculous, "IsNullString" only checks for a specific definition of nullstring
bool IsActuallyNullString(char[] somestring)
{
    if (somestring[0] != '\0')
    {
        return false;
    }
    return true;
}

bool IsHalloweenCond(TFCond condition)
{
    if
    (
           condition == TFCond_HalloweenKart
        || condition == TFCond_HalloweenKartDash
        || condition == TFCond_HalloweenThriller
        || condition == TFCond_HalloweenBombHead
        || condition == TFCond_HalloweenGiant
        || condition == TFCond_HalloweenTiny
        || condition == TFCond_HalloweenInHell
        || condition == TFCond_HalloweenGhostMode
        || condition == TFCond_HalloweenKartNoTurn
        || condition == TFCond_HalloweenKartCage
        || condition == TFCond_SwimmingCurse
    )
    {
        return true;
    }
    return false;
}

/********** MISC CLIENT CHECKS **********/

// is client on a team and not dead
bool IsClientPlaying(int client)
{
    TFTeam team = TF2_GetClientTeam(client);
    if
    (
        IsPlayerAlive(client)
        &&
        (
            team != TFTeam_Unassigned
            &&
            team != TFTeam_Spectator
        )
    )
    {
        return true;
    }
    return false;
}

/********** PRINT HELPER FUNCS **********/

// print colored chat to all server/sourcemod admins
void PrintToImportant(const char[] format, any ...)
{
    char buffer[254];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidAdmin(i) || IsValidSrcTV(i))
        {
            SetGlobalTransTarget(i);
            VFormat(buffer, sizeof(buffer), format, 2);
            MC_PrintToChat(i, "%s", buffer);
        }
    }
    if (StrContains(buffer, "detect", false) != -1)
    {
        StacLog("%s", buffer);
    }
}

// print to all server/sourcemod admin's consoles
void PrintToConsoleAllAdmins(const char[] format, any ...)
{
    char buffer[254];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidAdmin(i) || IsValidSrcTV(i))
        {
            SetGlobalTransTarget(i);
            VFormat(buffer, sizeof(buffer), format, 2);
            PrintToConsole(i, "%s", buffer);
        }
    }
}

/********** MATH STUFF **********/

int min(int a, int b)
{
    return a < b ? a : b;
}

int max(int a, int b)
{
    return a > b ? a : b;
}

int clamp(int num, int minnum, int maxnum)
{
    num  = max(num, minnum);
    return min(num, maxnum);
}

any abs(any x)
{
    return x > 0 ? x : -x;
}

float RoundToPlace(float input, int decimalPlaces)
{
    float poweroften = Pow(10.0, float(decimalPlaces));
    return RoundToNearest(input * poweroften) / (poweroften);
}

bool IsZeroVector(const float vec[3])
{
    if
    (
           vec[0] == 0.0
        && vec[1] == 0.0
        && vec[2] == 0.0
    )
    {
        return true;
    }
    return false;
}

/********** UPDATER **********/

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}

/********** DISCORD **********/

void StacGeneralPlayerDiscordNotify(int userid, char[] message)
{
    if (!DISCORD)
    {
        return;
    }

    char msg[1024];

    int Cl = GetClientOfUserId(userid);
    char ClName[64];
    GetClientName(Cl, ClName, sizeof(ClName));
    Discord_EscapeString(ClName, sizeof(ClName));
    GetDemoName();
    // we technically store the url in this so it has to be bigger
    char steamid[96];
    // ok we store these on client connect & auth, this shouldn't be null
    if (!IsActuallyNullString(SteamAuthFor[Cl]))
    {
        // make this a clickable link in discord
        Format(steamid, sizeof(steamid), "[%s](https://steamid.io/lookup/%s)", SteamAuthFor[Cl], SteamAuthFor[Cl]);
    }
    // if it is, that means the plugin reloaded or steam is being fussy.
    else
    {
        steamid = "N/A";
    }
    Format
    (
        msg,
        sizeof(msg),
        generalTemplate,
        Cl,
        steamid,
        message,
        hostname,
        hostipandport,
        demoname
    );
    SendMessageToDiscord(msg);
}

void StacDetectionDiscordNotify(int userid, char[] type, int detections)
{
    if (!DISCORD)
    {
        return;
    }

    char msg[1024];

    int Cl = GetClientOfUserId(userid);
    char ClName[64];
    GetClientName(Cl, ClName, sizeof(ClName));
    Discord_EscapeString(ClName, sizeof(ClName));
    GetDemoName();
    // we technically store the url in this so it has to be bigger
    char steamid[96];
    // ok we store these on client connect & auth, this shouldn't be null
    if (!IsActuallyNullString(SteamAuthFor[Cl]))
    {
        // make this a clickable link in discord
        Format(steamid, sizeof(steamid), "[%s](https://steamid.io/lookup/%s)", SteamAuthFor[Cl], SteamAuthFor[Cl]);
    }
    // if it is, that means the plugin reloaded or steam is being fussy.
    else
    {
        steamid = "N/A";
    }

    Format
    (
        msg,
        sizeof(msg),
        detectionTemplate,
        Cl,
        steamid,
        type,
        detections,
        hostname,
        hostipandport,
        demoname
    );
    SendMessageToDiscord(msg);
}

void SendMessageToDiscord(char[] message)
{
    char webhook[32] = "stac";
    Discord_SendMessage(webhook, message);
}
