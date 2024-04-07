#pragma semicolon 1

/********** STAC COMMANDS FOR ADMINS **********/

Action checkAdmin(int callingCl, int args)
{
    // dont realloc since this might be hammered
    static char arg0[512];
    static char arg1[512];

    // clear out whatever might be in there
    arg0 = 0x0;
    arg1 = 0x0;

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
            // Detect DOES NOT!!! decrement on a timer, it's just reset every map!
            stacProbingDetects[callingCl]++;
            if
            (
                   stacProbingDetects[callingCl] == 1
                || stacProbingDetects[callingCl] == 5
                || stacProbingDetects[callingCl] % 10 == 0
            )
            {
                GetCmdArg(0, arg0, sizeof(arg0));

                PrintToImportant("{hotpink}[StAC]{white} Client %N attempted to use %s, blocked access." , callingCl, arg0);
                StacLogSteam(GetClientUserId(callingCl));
                char fmtmsg[512];
                Format(fmtmsg, sizeof(fmtmsg), "Client %N attempted to use %s, blocked access!", callingCl, arg0);
                StacNotify(GetClientUserId(callingCl), fmtmsg);
            }
            // https://github.com/sapphonie/StAC-tf2/pull/189
            // "Plugin_Continue will show "Unknown command" client side."
            return Plugin_Continue;
        }
    }
    GetCmdArg(0, arg0, sizeof(arg0));
    GetCmdArg(1, arg1, sizeof(arg1));

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
    for (int cl = 1; cl <= MaxClients; cl++)
    {
        if (IsValidClient(cl))
        {
            // we don't check everything because some checks are "in the moment" and can expire very quickly
            if
            (
                   turnTimes               [cl] > 0
                || fakeAngDetects          [cl] > 0
                || aimsnapDetects          [cl] > 0
                || pSilentDetects          [cl] > 0
                || cmdnumSpikeDetects      [cl] > 0
                || tbotDetects             [cl] > 0
                || invalidUsercmdDetects   [cl] > 0
                || stacProbingDetects      [cl] > 0
            )
            {
                PrintToConsole
                (
                    callingCl,
                    "\n\
                    Detections for %L -\
                    \n Turn binds - %i\
                    \n FakeAngs - %i\
                    \n Aimsnaps - %i\
                    \n pSilent - %i\
                    \n Cmdnum spikes - %i\
                    \n Possible triggerbot detects - %i\
                    \n Invalid Usercmds -%i\
                    \n Attempts to see if StAC is running - %i\
                    \n",
                    cl,
                    turnTimes               [cl],
                    fakeAngDetects          [cl],
                    aimsnapDetects          [cl],
                    pSilentDetects          [cl],
                    cmdnumSpikeDetects      [cl],
                    tbotDetects             [cl],
                    invalidUsercmdDetects   [cl],
                    stacProbingDetects      [cl]
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
        int cl = target_list[i];
        if (IsValidClient(cl))
        {
            // getauth
            if (getauth)
            {
                ReplyToCommand(callingCl, "[StAC] Auth for \"%N\" - %s", cl, SteamAuthFor[cl]);
            }
            if (livefeed)
            {
                // livefeed
                LiveFeedOn[cl] = !LiveFeedOn[cl];
                for (int j = 1; j <= MaxClients; j++)
                {
                    if (j != cl)
                    {
                        LiveFeedOn[j] = false;
                    }
                }
                ReplyToCommand(callingCl, "[StAC] Toggled livefeed for \"%N\".", cl);
                checkLiveFeed();
            }
        }
    }

    return;
}
