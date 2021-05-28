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
        if (banForMiscCheats)
        {
            int userid = GetClientUserId(Cl);
            char reason[128];
            Format(reason, sizeof(reason), "%t", "newlineBanMsg");
            char pubreason[256];
            Format(pubreason, sizeof(pubreason), "%t", "newlineBanAllChat", Cl);
            BanUser(userid, reason, pubreason);
        }
        else
        {
            PrintToImportant("{hotpink}[StAC]{white} [Detection] Blocked newline print from player %L", Cl);
            StacLog("[StAC] [Detection] Blocked newline print from player %L", Cl);
        }
        return Plugin_Stop;
    }
    /*
    // MEGA DEBUG
    if (StrContains(sArgs, "steamdown", false) != -1)
    {
        Steam_SteamServersDisconnected();
        SteamWorks_SteamServersDisconnected(view_as<EResult>(1));
        LogMessage("steamdown!");
    }
    if (StrContains(sArgs, "steamup", false) != -1)
    {
        Steam_SteamServersConnected();
        SteamWorks_SteamServersConnected();
        LogMessage("steamup!");
    }

    if (StrContains(sArgs, "checksteam", false) != -1)
    {
        LogMessage("%i", shouldCheckAuth());
    }
    */
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

        if (DEBUG)
        {
            StacLog("[StAC] '%L' issued client side command with %i length:", Cl, strlen(ClientCommandChar));
            StacLog("%s", ClientCommandChar);
        }
        if (strlen(ClientCommandChar) > 255 || len > 255)
        {
            StacGeneralPlayerDiscordNotify(userid, "Client sent a very large command to the server!");
            StacLog("%s", ClientCommandChar);
            return Plugin_Stop;
        }
    }
    return Plugin_Continue;
}

// ban for cmdrate value change spam.
// cheats do this to fake their ping

char userinfoToCheck[][] =
{
    "cl_interp_npcs",
    "cl_flipviewmodels",
    "cl_predict",
    "cl_interp_ratio",
    "cl_interp",
    "cl_team",
    "cl_class",
    "hap_HasDevice",
    "cl_showhelp",
    "english",
    "cl_predictweapons",
    "cl_lagcompensation",
    "hud_classautokill",
    "cl_spec_mode",
    "cl_autorezoom",
    "tf_remember_activeweapon",
    "tf_remember_lastswitched",
    "cl_autoreload",
    "fov_desired",
    "hud_combattext",
    "hud_combattext_healing",
    "hud_combattext_batching",
    "hud_combattext_doesnt_block_overhead_text",
    "hud_combattext_green",
    "hud_combattext_red",
    "hud_combattext_blue",
    "tf_medigun_autoheal",
    "voice_loopback",
    "name",
    "tv_nochat",
    "cl_language",
    "rate",
    "cl_cmdrate",
    "cl_updaterate",
    "closecaption",
    "net_maxroutable"
};

//               [values][history][char size]

//char clcmdrateFor[TFMAXPLAYERS+1][64];
//char clupdaterateFor[TFMAXPLAYERS+1][64];

bool justclamped[TFMAXPLAYERS+1];

public void OnClientSettingsChanged(int Cl)
{
    //                    [cvar][history][charsize]
    static char userinfoValues[64][4][256];

    // ignore invalid clients
    if (!IsValidClient(Cl))
    {
        return;
    }

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
        //StacLog("Ignoring demorestart settings change for %N", Cl);
        return;
    }


    int userid = GetClientUserId(Cl);

    // hm
    for (int cvar; cvar < sizeof(userinfoToCheck); cvar++)
    {
        GetClientInfo(Cl, userinfoToCheck[cvar], userinfoValues[cvar][0], sizeof(userinfoValues[][]));
        if
        (
            !StrEqual(userinfoValues[cvar][1], userinfoValues[cvar][0])
            && !IsActuallyNullString(userinfoValues[cvar][0])
            && !IsActuallyNullString(userinfoValues[cvar][1])
        )
        {
            StacLog("Client %N changed %s: old %s != new %s", Cl, userinfoToCheck[cvar], userinfoValues[cvar][1], userinfoValues[cvar][0]);

            // fixpingmasking stuff
            if
            (
                StrEqual(userinfoToCheck[cvar], "cl_cmdrate")
                ||
                StrEqual(userinfoToCheck[cvar], "cl_updaterate")
                ||
                StrEqual(userinfoToCheck[cvar], "rate")
            )
            {
                // we just clamped this client! don't count it as userinfo spam
                if (justclamped[Cl] == true)
                {
                    justclamped[Cl] = false;
                }
                // this prevents against legit clients from purposefully messing with their cl_cmdrate/rate/etc trying to trigger stac
                else if (!StrEqual(userinfoValues[cvar][3], userinfoValues[cvar][1]))
                {
                    userinfoSpamEtc(userid, userinfoToCheck[cvar], userinfoValues[cvar][1], userinfoValues[cvar][0]);
                }

                if (fixpingmasking)
                {
                    FixPingMasking(Cl, userinfoToCheck[cvar], userinfoValues[cvar][0]);
                }
            }
            else
            {
                userinfoSpamEtc(userid, userinfoToCheck[cvar], userinfoValues[cvar][1], userinfoValues[cvar][0]);
            }
        }
        strcopy(userinfoValues[cvar][1], sizeof(userinfoValues[][]), userinfoValues[cvar][0]);
        strcopy(userinfoValues[cvar][2], sizeof(userinfoValues[][]), userinfoValues[cvar][1]);
        strcopy(userinfoValues[cvar][3], sizeof(userinfoValues[][]), userinfoValues[cvar][2]);
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
            StacDetectionDiscordNotify(userid, "userinfo spam", userinfoSpamDetects[Cl]);
        }
        // BAN USER if they trigger too many detections
        //if (userinfoSpamDetects[Cl] >= maxuserinfoSpamDetections && maxuserinfoSpamDetections > 0)
        //{
        //    char reason[128];
        //    Format(reason, sizeof(reason), "%t", "userinfoSpamBanMsg", userinfoSpamDetects[Cl]);
        //    char pubreason[256];
        //    Format(pubreason, sizeof(pubreason), "%t", "userinfoSpamBanAllChat", Cl, userinfoSpamDetects[Cl]);
        //    BanUser(userid, reason, pubreason);
        //    return;
        //}
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
}

void FixPingMasking(int Cl, const char[] cvar, const char[] value)
{
    //int userid = GetClientUserId(Cl);
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
        LogMessage("---> CLAMPING %s to %s", cvar, soptimalrate);
        justclamped[Cl] = true;
        //CreateTimer(0.1, Timer_decr_userinfospam, userid);
        //CreateTimer(0.1, Timer_decr_userinfospam, userid);
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

        // forcibly disables thirdperson with some cheats
        ClientCommand(Cl, "firstperson");
        if (DEBUG)
        {
            StacLog("[StAC] Executed firstperson command on Player %N", Cl);
        }

        // lerp check - we check the netprop
        // don't check if not default tickrate
        if (isDefaultTickrate())
        {
            float lerp = GetEntPropFloat(Cl, Prop_Data, "m_fLerpTime") * 1000;
            if (DEBUG)
            {
                StacLog("%.2f ms interp on %N", lerp, Cl);
            }
            if (lerp == 0.0)
            {
                // repeated code lol
                if (banForMiscCheats)
                {
                    char reason[128];
                    Format(reason, sizeof(reason), "%t", "nolerpBanMsg");
                    char pubreason[256];
                    Format(pubreason, sizeof(pubreason), "%t", "nolerpBanAllChat", Cl);
                }
                else
                {
                    StacGeneralPlayerDiscordNotify(userid, "Client sent a very large command to the server!");
                    PrintToImportant("{hotpink}[StAC]{white} [Detection] Player %L is using NoLerp!", Cl);
                    StacLog("[StAC] [Detection] Player %L is using NoLerp!", Cl);
                }
            }
            if
            (
                lerp < min_interp_ms && min_interp_ms != -1
                ||
                lerp > max_interp_ms && max_interp_ms != -1
            )
            {
                char message[256];
                Format(message, sizeof(message), "Client was kicked for attempted interp exploitation. Their interp: %.2fms", lerp);
                StacGeneralPlayerDiscordNotify(userid, message);
                KickClient(Cl, "%t", "interpKickMsg", lerp, min_interp_ms, max_interp_ms);
                MC_PrintToChatAll("%t", "interpAllChat", Cl, lerp);
                StacLog("%t", "interpAllChat", Cl, lerp);
            }
        }
    }
}
