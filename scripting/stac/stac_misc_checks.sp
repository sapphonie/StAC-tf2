#pragma semicolon 1

/********** MISC CHEAT DETECTIONS / PATCHES *********/

// ban on invalid characters (newlines, carriage returns, etc)
public Action OnClientSayCommand(int Cl, const char[] command, const char[] sArgs)
{
    // don't pick up console or bots
    if (!IsValidClient(Cl))
    {
        return Plugin_Continue;
    }
    if
    (
        StrContains(sArgs, "\n", false) != -1
        ||
        StrContains(sArgs, "\r", false) != -1
    )
    {
        int userid = GetClientUserId(Cl);
        if (banForMiscCheats)
        {
            char reason[128];
            Format(reason, sizeof(reason), "%t", "newlineBanMsg");
            char pubreason[256];
            Format(pubreason, sizeof(pubreason), "%t", "newlineBanAllChat", Cl);
            BanUser(userid, reason, pubreason);
        }
        else
        {
            PrintToImportant("{hotpink}[StAC] {red}[Detection]{white} Blocked newline print from player %N", Cl);
            StacLogSteam(userid);
        }
        StacDetectionNotify(userid, "Client tried to print a newline character", 1);
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

Action joinTeam(int Cl, const char[] command, int argc)
{
    if (!teamChecked[Cl])
    {
        char ClName[64];
        int userid = GetClientUserId(Cl);
        GetClientName(Cl, ClName, sizeof(ClName));
        timeSinceJointeam[Cl] = GetEngineTime();
        if (timeSinceJointeam[Cl] - timeSinceJoined[Cl] < 2.5)
        {
            PrintToImportant("Suspicious: %.2f seconds between %s fully joined and chose team", timeSinceJointeam[Cl] - timeSinceJoined[Cl], ClName);
            StacGeneralPlayerNotify(userid, "Suspicious: %.2f seconds between %s fully joined and chose team", timeSinceJointeam[Cl] - timeSinceJoined[Cl], ClName);
        }
        teamChecked[Cl] = true;
        return Plugin_Continue;
    }
    return Plugin_Continue;
}

Action joinClass(int Cl, const char[] command, int argc)
{
    if (!classChecked[Cl])
    {
        char ClName[64];
        int userid = GetClientUserId(Cl);
        GetClientName(Cl, ClName, sizeof(ClName));
        timeSinceJoinclass[Cl] = GetEngineTime();
        if (timeSinceJoinclass[Cl] - timeSinceJoined[Cl] < 2.5) // This value may need to be tweaked.
        {
            PrintToImportant("Suspicious: %.2f seconds between %s fully joined and chose class", timeSinceJoinclass[Cl] - timeSinceJoined[Cl], ClName);
            StacGeneralPlayerNotify(userid, "Suspicious: %.2f seconds between %s fully joined and chose class", timeSinceJoinclass[Cl] - timeSinceJoined[Cl], ClName);
        }
        classChecked[Cl] = true;
        return Plugin_Continue;
    }
    return Plugin_Continue;
}

void NameCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if (IsValidClient(Cl))
    {
        char curName[64];
        GetClientName(Cl, curName, sizeof(curName));
        // ban for invalid characters in names
        if
        (
            StrContains(curName, "\n")  != -1
            ||
            StrContains(curName, "\r")  != -1
            ||
            // right to left char
            StrContains(curName, "\xE2\x80\x8F") != -1
            ||
            // left to right char
            StrContains(curName, "\xE2\x80\x8E") != -1
        )
        {
            SaniNameAndBan(userid, curName);
        }
    }
}

void SaniNameAndBan(int userid, char name[64])
{
    int Cl = GetClientOfUserId(userid);

    hasBadName[Cl] = true;

    int newlines;
    int returns;
    int rtl;
    int ltr;

    // todo: implement C style iscntrl
    newlines    = ReplaceString(name, sizeof(name), "\n",           "");
    returns     = ReplaceString(name, sizeof(name), "\r",           "");
    rtl         = ReplaceString(name, sizeof(name), "\xE2\x80\x8F", "");
    ltr         = ReplaceString(name, sizeof(name), "\xE2\x80\x8E", "");

    SetClientName(Cl, name);

    StacLog
    (
        "Client had:\
        \n%i newline chars,\
        \n%i return chars,\
        \n%i right2left chars,\
        \n%i left2right chars",
        newlines,
        returns,
        rtl,
        ltr
    );

    CreateTimer(0.5, BanName, userid);
}

Action BanName(Handle timer, int userid)
{
    int Cl = GetClientOfUserId(userid);

    StacDetectionNotify(userid, "Client has illegal chars in their name!", 1);

    if (banForMiscCheats)
    {
        char reason[128];
        Format(reason, sizeof(reason), "%t", "illegalNameBanMsg");
        char pubreason[256];
        Format(pubreason, sizeof(pubreason), "%t", "illegalNameBanAllChat", Cl);
        BanUser(userid, reason, pubreason);
    }
    else
    {
        PrintToImportant("{hotpink}[StAC] {red}[Detection]{white} Player %N has illegal chars in their name!", Cl);
        StacLogSteam(userid);
        StacLog("[Detection] Player %N has illegal chars in their name!", Cl);
    }
    return Plugin_Continue;
}

// block long commands - i don't know if this actually does anything but it makes me feel better
public Action OnClientCommand(int Cl, int args)
{
    if (IsValidClient(Cl))
    {
        int userid = GetClientUserId(Cl);
        // init var
        char ClientCommandChar[512];
        // gets the first command
        GetCmdArg(0, ClientCommandChar, sizeof(ClientCommandChar));
        // get length of string
        int len = strlen(ClientCommandChar);

        // is there more after this command?
        if (GetCmdArgs() > 0)
        {
            // add a space at the end of it
            ClientCommandChar[len++] = ' ';
            GetCmdArgString(ClientCommandChar[len++], sizeof(ClientCommandChar));
        }


        strcopy(lastCommandFor[Cl], sizeof(lastCommandFor[]), ClientCommandChar);
        timeSinceLastCommand[Cl] = engineTime[Cl][0];


        // clean it up ( PROBABLY NOT NEEDED )
        // TrimString(ClientCommandChar);

        if (strlen(ClientCommandChar) > 255)
        {
            StacGeneralPlayerNotify(userid, "Client sent a very large command - length %i - to the server! Next message is the command.", strlen(ClientCommandChar));
            StacGeneralPlayerNotify(userid, "%s", ClientCommandChar);
            StacLog("Client sent a very large command - length %i - to the server! Next message is the command.", strlen(ClientCommandChar));
            StacLog("%s", ClientCommandChar);
            return Plugin_Stop;
        }
    }
    return Plugin_Continue;
}

// for achievement checking, because chook tries to be s n e a k y
// if there are upgrades to the call/response bullshit in chook i can and will make this iterate thru every single kv
public Action OnClientCommandKeyValues(int Cl, KeyValues kv)
{
    if (IsValidClient(Cl))
    {
        if (KvJumpToKey(kv, "achievementID", false))
        {
            if (KvGetDataType(kv, NULL_STRING) == KvData_Int)
            {
                // hack because KvGetNum doesn't just return a bool with an int&
                int id = KvGetNum(kv, NULL_STRING, -123456789);
                if (id != -123456789)
                {
                    int userid = GetClientUserId(Cl);
                    cheevCheck(userid, id);
                }
            }
        }
    }

    return Plugin_Continue;
}


// oh dear god why did I write this like this this is horrible
public void OnClientSettingsChanged(int Cl)
{
    // ignore invalid clients
    if (!IsValidClient(Cl))
    {
        return;
    }
    int userid = GetClientUserId(Cl);
    if
    (
        // command occured recently
        engineTime[Cl][0] - 1.5 < timeSinceLastCommand[Cl]
        &&
        (
            // and it's a demorestart
            StrEqual("demorestart", lastCommandFor[Cl])
        )
    )
    {
        if (DEBUG)
        {
            StacLog("Ignoring demorestart settings change for %N", Cl);
        }
        return;
    }

    // horrific
    for (int cvar; cvar < sizeof(userinfoToCheck); cvar++)
    {
        char cvarvalue[64];
        GetClientInfo(Cl, userinfoToCheck[cvar], cvarvalue, sizeof(cvarvalue));

        // one of our monitored cvars changed!
        if (!StrEqual(userinfoValues[cvar][Cl][0], cvarvalue))
        {
            // copy into history
            strcopy(userinfoValues[cvar][Cl][3], sizeof(userinfoValues[][][]), userinfoValues[cvar][Cl][2]);
            strcopy(userinfoValues[cvar][Cl][2], sizeof(userinfoValues[][][]), userinfoValues[cvar][Cl][1]);
            strcopy(userinfoValues[cvar][Cl][1], sizeof(userinfoValues[][][]), userinfoValues[cvar][Cl][0]);
            strcopy(userinfoValues[cvar][Cl][0], sizeof(userinfoValues[][][]), cvarvalue);

            // we have at least some history
            if (!IsActuallyNullString(userinfoValues[cvar][Cl][0]) && !IsActuallyNullString(userinfoValues[cvar][Cl][1]))
            {
                if (DEBUG)
                {
                    StacLog("Client %N changed %s: old %s new %s", Cl, userinfoToCheck[cvar], userinfoValues[cvar][Cl][1], cvarvalue);
                }

                // check interp
                if
                (
                    StrEqual(userinfoToCheck[cvar], "cl_interp_ratio")
                    ||
                    StrEqual(userinfoToCheck[cvar], "cl_interp")
                    ||
                    StrEqual(userinfoToCheck[cvar], "cl_updaterate")
                )
                {
                    checkInterp(userid);
                }
                // fix pingmasking
                if
                (
                    StrEqual(userinfoToCheck[cvar], "cl_cmdrate")
                    ||
                    StrEqual(userinfoToCheck[cvar], "cl_updaterate")
                    ||
                    StrEqual(userinfoToCheck[cvar], "rate")
                )
                {
                    if (fixpingmasking)
                    {
                        FixPingMasking(Cl, userinfoToCheck[cvar], userinfoValues[cvar][Cl][0]);
                    }
                }
                if
                (
                    StrEqual(userinfoToCheck[cvar], "cl_cmdrate")
                )
                {
                    // ban for illegal values
                    int cmdrate = StringToInt(cvarvalue);
                    if (cmdrate < 10)
                    {
                        oobVarsNotify(userid, userinfoToCheck[cvar], cvarvalue);
                        if (banForMiscCheats)
                        {
                            oobVarBan(userid);
                        }
                    }
                    // userinfo spam
                    // prevent clients from purposefully trying to trigger stac
                    if
                    (
                        !StrEqual(userinfoValues[cvar][Cl][3], userinfoValues[cvar][Cl][0])
                        &&
                        !StrEqual(userinfoValues[cvar][Cl][2], userinfoValues[cvar][Cl][0])
                        &&
                        !justclamped[Cl]
                    )
                    {
                        userinfoSpamEtc(userid, userinfoToCheck[cvar], userinfoValues[cvar][Cl][1], userinfoValues[cvar][Cl][0]);
                    }
                    if (justclamped[Cl])
                    {
                        justclamped[Cl] = false;
                    }
                }
            }
        }
    }
}

void userinfoSpamEtc(int userid, const char[] cvar, const char[] oldvalue, const char[] newvalue)
{
    int Cl = GetClientOfUserId(userid);
    userinfoSpamDetects[Cl]++;
    // have this detection expire in 10 seconds!!! remember - this means that the amount of detects are ONLY in the last 10 seconds!
    CreateTimer(10.0, Timer_decr_userinfospam, userid, TIMER_FLAG_NO_MAPCHANGE);
    if (userinfoSpamDetects[Cl] >= 5)
    {
        PrintToImportant
        (
            "{hotpink}[StAC]{white} %N is spamming userinfo updates. Detections in the last 10 seconds: {palegreen}%i{white}.\
            \n'{blue}%s{white}' changed, from '{blue}%s{white}' to '{blue}%s{white}'",
            Cl, userinfoSpamDetects[Cl],
            cvar, oldvalue, newvalue
        );
        if (userinfoSpamDetects[Cl] % 5 == 0)
        {
            StacDetectionNotify(userid, "userinfo spam", userinfoSpamDetects[Cl]);
        }
        StacLogSteam(userid);
        // BAN USER if they trigger too many detections
        if (userinfoSpamDetects[Cl] >= maxuserinfoSpamDetections && maxuserinfoSpamDetections > 0)
        {
            char reason[128];
            Format(reason, sizeof(reason), "%t", "userinfoSpamBanMsg", userinfoSpamDetects[Cl]);
            char pubreason[256];
            Format(pubreason, sizeof(pubreason), "%t", "userinfoSpamBanAllChat", Cl, userinfoSpamDetects[Cl]);
            BanUser(userid, reason, pubreason);
            return;
        }
    }
}

Action Timer_decr_userinfospam(Handle timer, any userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        if (userinfoSpamDetects[Cl] > 0)
        {
            userinfoSpamDetects[Cl]--;
        }
    }
    return Plugin_Continue;
}

void FixPingMasking(int Cl, const char[] cvar, const char[] value)
{
    int irate;
    int ioptimalrate;
    char soptimalrate[24];


    // convert value to int
    irate = StringToInt(value);
    if (StrEqual("cl_cmdrate", cvar))
    {
        // clamp it
        ioptimalrate = clamp(irate, imincmdrate, imaxcmdrate);
    }
    else if (StrEqual("cl_updaterate", cvar))
    {
        // clamp it
        ioptimalrate = clamp(irate, iminupdaterate, imaxupdaterate);
    }
    else if (StrEqual("rate", cvar))
    {
        // clamp it
        ioptimalrate = clamp(irate, iminrate, imaxrate);
    }
    // we shouldn't get here
    else
    {
        return;
    }
    // convert it to string
    IntToString(ioptimalrate, soptimalrate, sizeof(soptimalrate));

    if
    (
        // cmdrate isnt == to optimal clamped rate
        irate != ioptimalrate
        ||
        // client string isnt equal to string of optimal cmdrate
        !StrEqual(value, soptimalrate)
    )
    {
        SetClientInfo(Cl, cvar, soptimalrate);
        justclamped[Cl] = true;
    }
}


// no longer just for netprops!
void MiscCheatsEtcsCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        // there used to be an fov check here - but there's odd behavior that i don't want to work around regarding the m_iFov netprop.
        // sorry!

        checkInterp(userid);
    }
}

void checkInterp(int userid)
{
    int Cl = GetClientOfUserId(userid);
    // lerp check - we check the netprop
    // don't check if not default tickrate
    if (isDefaultTickrate())
    {
        float lerp = GetEntPropFloat(Cl, Prop_Data, "m_fLerpTime") * 1000;
        if (DEBUG)
        {
            StacLog("%.2f ms interp on %N", lerp, Cl);
        }

        // nolerp
        if (lerp <= 0.1)
        {
            char lerpStr[16];
            FloatToString(lerp, lerpStr, sizeof(lerpStr));
            oobVarsNotify(userid, "m_fLerpTime", lerpStr);
            if (banForMiscCheats)
            {
                oobVarBan(userid);
            }
        }
        else if
        (
            lerp < min_interp_ms && min_interp_ms != -1
            ||
            lerp > max_interp_ms && max_interp_ms != -1
        )
        {
            char message[256];
            Format(message, sizeof(message), "Client was kicked for attempted interp exploitation. Their interp: %.2fms", lerp);
            StacGeneralPlayerNotify(userid, message);
            KickClient(Cl, "%t", "interpKickMsg", lerp, min_interp_ms, max_interp_ms);
            MC_PrintToChatAll("%t", "interpAllChat", Cl, lerp);
            StacLog("%t", "interpAllChat", Cl, lerp);
        }
    }
}

void cheevCheck(int userid, int achieve_id)
{
    // ent index of achievement earner
    int Cl              = GetClientOfUserId(userid);

    // we can't sdkcall CAchievementMgr::GetAchievementByIndex(int) here because the server will never have a valid CAchievementMgr*
    // this is because achievements are all client side (because Valve just trusts clients fsr?)
    // we have to (use other peoples') hardcode, in this case nosoop's achievements.inc.

    // achievment number is bogus:
    if
    (
        // it's too low
        achieve_id < view_as<int>(Achievement_GetTurretKills)
        ||
        // it's too high
        achieve_id > view_as<int>(Achievement_MapsPowerhouseKillEnemyInWater)
    )
    {
        // uid for passing to GenPlayerNotify
        StacLogSteam(userid);

        if (banForMiscCheats)
        {
            PrintToImportant("{hotpink}[StAC] {white} User %N earned BOGUS achievement ID %i (hex %X)", Cl, achieve_id, achieve_id);
            char reason[128];
            Format(reason, sizeof(reason), "%t", "bogusAchieveBanMsg");
            char pubreason[256];
            Format(pubreason, sizeof(pubreason), "%t", "bogusAchieveBanAllChat", Cl);
            BanUser(userid, reason, pubreason);
        }
        else
        {
            PrintToImportant("{hotpink}[StAC] {red}[Detection]{white} User %N earned BOGUS achievement ID %i (hex %X)", Cl, achieve_id, achieve_id);
        }

        char message[256];
        Format(message, sizeof(message), "Client is cheating with bogus AchievementID %i (hex %X)", achieve_id, achieve_id);
        StacDetectionNotify(userid, message, 1);

    }

}
