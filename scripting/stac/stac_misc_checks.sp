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
public void OnClientSettingsChanged(int Cl)
{
    CheckAndFixCmdrate(Cl);
}

void CheckAndFixCmdrate(int Cl)
{
    // ignore invalid clients and dead / in spec clients
    if (!IsValidClient(Cl) || !IsClientPlaying(Cl) || !fixpingmasking)
    {
        return;
    }

    if
    (
        // command occured recently
        engineTime[Cl][0] - 2.5 < timeSinceLastCommand[Cl]
        &&
        // and it's a demorestart
        StrEqual("demorestart", lastCommandFor[Cl])
    )
    {
        //StacLog("Ignoring demorestart settings change for %N", Cl);
        return;
    }

    // get userid for timer
    int userid = GetClientUserId(Cl);

    // pingreduce check only works if you are using fixpingmasking!
    // buffer for cmdrate value

    char scmdrate[16];
    // get actual value of cl cmdrate
    GetClientInfo(Cl, "cl_cmdrate", scmdrate, sizeof(scmdrate));
    // convert it to int
    int icmdrate = StringToInt(scmdrate);

    // clamp it
    int iclamprate = clamp(icmdrate, imincmdrate, imaxcmdrate);
    char sclamprate[4];
    // convert it to string
    IntToString(iclamprate, sclamprate, sizeof(sclamprate));

    // do the same thing with updaterate
    char supdaterate[4];
    // get actual value of cl updaterate
    GetClientInfo(Cl, "cl_updaterate", supdaterate, sizeof(supdaterate));
    // convert it to int
    int iupdaterate = StringToInt(supdaterate);

    // clamp it
    int iclampupdaterate = clamp(iupdaterate, iminupdaterate, imaxupdaterate);
    char sclampupdaterate[4];
    // convert it to string
    IntToString(iclampupdaterate, sclampupdaterate, sizeof(sclampupdaterate));

    /*
        CMDRATE SPAM CHECK

        technically this could be triggered by clients spam recording and stopping demos, but cheats do it infinitely faster
    */
    cmdrateSpamDetects[Cl]++;
    // have this detection expire in 10 seconds!!! remember - this means that the amount of detects are ONLY in the last 10 seconds!
    // ncc caps out at 140ish
    CreateTimer(10.0, Timer_decr_cmdratespam, userid, TIMER_FLAG_NO_MAPCHANGE);
    if (cmdrateSpamDetects[Cl] > 1)
    {
        PrintToImportant
        (
            "{hotpink}[StAC]{white} %N is suspected of ping-reducing or masking using a cheat.\nDetections within the last 10 seconds: {palegreen}%i{white}. Cmdrate value: {blue}%i",
            Cl,
            cmdrateSpamDetects[Cl],
            icmdrate
        );
        StacLog
        (
            "[StAC] %N is suspected of ping-reducing or masking using a cheat.\nDetections so far: %i.\nCmdrate: %i\nUpdaterate: %i",
            Cl,
            cmdrateSpamDetects[Cl],
            icmdrate,
            iupdaterate
        );
        if (cmdrateSpamDetects[Cl] % 5 == 0)
        {
            StacDetectionDiscordNotify(userid, "cmdrate spam / ping modification", cmdrateSpamDetects[Cl]);
        }

        // BAN USER if they trigger too many detections
        if (cmdrateSpamDetects[Cl] >= maxCmdrateSpamDetections && maxCmdrateSpamDetections > 0)
        {
            char reason[128];
            Format(reason, sizeof(reason), "%t", "cmdrateSpamBanMsg", cmdrateSpamDetects[Cl]);
            char pubreason[256];
            Format(pubreason, sizeof(pubreason), "%t", "cmdrateSpamBanAllChat", Cl, cmdrateSpamDetects[Cl]);
            BanUser(userid, reason, pubreason);
            return;
        }
    }

    if
    (
        // cmdrate is == to optimal clamped rate
        icmdrate != iclamprate
        ||
        // client string is exactly equal to string of optimal cmdrate
        !StrEqual(scmdrate, sclamprate)
    )
    {
        SetClientInfo(Cl, "cl_cmdrate", sclamprate);
        //LogMessage("clamping cmdrate to %s", sclamprate);
    }

    if
    (
        // cmdrate is == to optimal clamped rate
        iupdaterate != iclampupdaterate
        ||
        // client string is exactly equal to string of optimal cmdrate
        !StrEqual(supdaterate, sclampupdaterate)
    )
    {
        SetClientInfo(Cl, "cl_updaterate", sclampupdaterate);
        //LogMessage("clamping updaterate to %s", sclampupdaterate);
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
