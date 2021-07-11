/********** STAC COMMANDS FOR ADMINS **********/

Action checkAdmin(int callingCl, int args)
{
    char arg0[32];
    GetCmdArg(0, arg0, sizeof(arg0));
    char arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));

    if (callingCl != 0)
    {
        bool isAdmin;
        AdminId clAdmin = GetUserAdmin(callingCl);
        if (GetAdminFlag(clAdmin, Admin_Ban))
        {
            isAdmin = true;
        }
        if (!isAdmin)
        {
            StacGeneralPlayerDiscordNotify(GetClientUserId(callingCl), "Client %N attempted to use %s, blocked access!", callingCl, arg0);
            StacLogSteam(GetClientUserId(callingCl));
            PrintToImportant("{hotpink}[StAC]{white} Client %N attempted to use %s, blocked access." , callingCl, arg0);
            return Plugin_Handled;
        }
        StacGeneralPlayerDiscordNotify(GetClientUserId(callingCl), "Admin %N used %s", callingCl, arg0);
    }

    if (StrEqual(arg0, "sm_stac_checkall"))
    {
        ForceCheckAll(callingCl);
        return Plugin_Handled;
    }

    if (StrEqual(arg0, "sm_stac_detections"))
    {
        ShowAllDetections(callingCl);
        return Plugin_Handled;
    }

    if (StrEqual(arg0, "sm_stac_getauth"))
    {
        if (args != 1)
        {
            ReplyToCommand(callingCl, "[StAC] Invalid number of arguments for command.");
        }

        StacTargetCommand(callingCl, arg0, arg1);
        return Plugin_Handled;
    }
    if (StrEqual(arg0, "sm_stac_livefeed"))
    {
        if (args != 1)
        {
            ReplyToCommand(callingCl, "[StAC] Invalid number of arguments for command.");
        }

        StacTargetCommand(callingCl, arg0, arg1);
        return Plugin_Handled;
    }
    return Plugin_Handled;
}

// sm_stac_checkall
void ForceCheckAll(int callingCl)
{
    ReplyToCommand(callingCl, "[StAC] Checking cvars on all clients.");
    QueryEverythingAllClients();
    return;
}

// sm_stac_detections
void ShowAllDetections(int callingCl)
{
    if (callingCl != 0)
    {
        ReplyToCommand(callingCl, "[StAC] Check your console!");
    }
    PrintToConsole(callingCl, "[StAC] === Printing current detections ===");
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            // we don't check everything because some checks are "in the moment" and can expire very quickly
            if
            (
                   turnTimes               [Cl] > 0
                || fakeAngDetects          [Cl] > 0
                || aimsnapDetects          [Cl] > 0
                || pSilentDetects          [Cl] > 0
                || cmdnumSpikeDetects      [Cl] > 0
                || tbotDetects             [Cl] > 0
                || userinfoSpamDetects     [Cl] > 0
            )
            {
                PrintToConsole
                (
                    callingCl,
                    "\n\
                    Detections for %L -\
                    \n Turn binds    %i\
                    \n FakeAngs      %i\
                    \n Aimsnaps      %i\
                    \n pSilent       %i\
                    \n Cmdnum spikes %i\
                    \n Triggerbots   %i\
                    \n",
                    Cl,
                    turnTimes               [Cl],
                    fakeAngDetects          [Cl],
                    aimsnapDetects          [Cl],
                    pSilentDetects          [Cl],
                    cmdnumSpikeDetects      [Cl],
                    tbotDetects             [Cl]
                );
            }
        }
    }
    PrintToConsole(callingCl, "[StAC] === Done ===");

    return;
}

// sm_stac_getauth  <client/s>
// sm_stac_livefeed <single client>
void StacTargetCommand(int callingCl, const char[] arg0, const char[] arg1)
{
    int flags = COMMAND_FILTER_NO_BOTS;

    bool getauth;
    bool livefeed;

    if (StrEqual(arg0, "sm_stac_getauth"))
    {
        getauth = true;
    }
    if (StrEqual(arg0, "sm_stac_livefeed"))
    {
        flags |= COMMAND_FILTER_NO_MULTI;
        livefeed = true;
    }

    char target_name[MAX_TARGET_LENGTH];
    int target_list[TFMAXPLAYERS+1];
    int target_count;
    bool tn_is_ml;

    if
    (
        (
            target_count = ProcessTargetString
            (
                arg1,
                callingCl,
                target_list,
                TFMAXPLAYERS+1,
                flags,
                target_name,
                sizeof(target_name),
                tn_is_ml
            )
        )
        <= 0
    )
    {
        ReplyToTargetError(callingCl, target_count);
        return;
    }

    for (int i = 0; i < target_count; i++)
    {
        int Cl = target_list[i];
        if (IsValidClient(Cl))
        {
            // getauth
            if (getauth)
            {
                ReplyToCommand(callingCl, "[StAC] Auth for \"%N\" - %s", Cl, SteamAuthFor[Cl]);
            }
            if (livefeed)
            {
                // livefeed
                LiveFeedOn[Cl] = !LiveFeedOn[Cl];
                for (int j = 1; j <= MaxClients; j++)
                {
                    if (j != Cl)
                    {
                        LiveFeedOn[j] = false;
                    }
                }
                ReplyToCommand(callingCl, "[StAC] Toggled livefeed for \"%N\".", Cl);
            }
        }
    }

    return;
}
