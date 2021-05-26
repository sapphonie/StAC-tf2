/********** OnPlayerRunCmd Detections **********/

/*
    in OnPlayerRunCmd, we check for:
    - CMDNUM SPIKES
    - SILENT AIM
    - AIM SNAPS
    - FAKE ANGLES
    - TURN BINDS
*/
public Action OnPlayerRunCmd
(
    int Cl,
    int& buttons,
    int& impulse,
    float vel[3],
    float angles[3],
    int& weapon,
    int& subtype,
    int& cmdnum,
    int& tickcount,
    int& seed,
    int mouse[2]
)
{
    OnPlayerRunCmd_jaypatch(Cl, buttons, impulse, vel, angles, weapon, subtype, cmdnum, tickcount, seed, mouse);
    // sanity check, don't let banned clients do anything!
    if (userBanQueued[Cl])
    {
        return Plugin_Handled;
    }

    // make sure client is real & not a bot
    if (!IsValidClient(Cl))
    {
        return Plugin_Continue;
    }

    // need this basically no matter what
    int userid = GetClientUserId(Cl);

    // originally from ssac - block invalid usercmds with invalid data
    if (cmdnum <= 0 || tickcount <= 0)
    {
        if (cmdnum < 0 || tickcount < 0)
        {
            StacLog("[StAC] cmdnum %i, tickcount %i", cmdnum, tickcount);
            StacGeneralPlayerDiscordNotify(userid, "Client has invalid usercmd data!");
            return Plugin_Handled;
        }
        timeSinceNullCmd[Cl] = GetEngineTime();
        return Plugin_Continue;
    }

    // grab engine time
    for (int i = 10; i > 0; --i)
    {
        engineTime[Cl][i] = engineTime[Cl][i-1];
    }
    engineTime[Cl][0] = GetEngineTime();


    // we use these later
    bool islagging = IsUserLagging(userid);
    bool islossy   = IsUserLossy(userid);

    // patch psilent
    bool silentpatched;
    float srvangles[3];
    GetClientEyeAngles(Cl, srvangles);

    float fakediff;
    if (!(IsZeroVector(clangles[Cl][0])))
    {
        fakediff = NormalizeAngleDiff(CalcAngDeg(clangles[Cl][0], srvangles));
        if (islagging || islossy)
        {
            if (fakediff > 5.0)
            {
                angles = srvangles;
                LogMessage("x y z %f %f %f", clangles[Cl][0][0], clangles[Cl][0][1], clangles[Cl][0][2]);
                LogMessage("%f", fakediff);
                silentpatched = true;
            }
        }
        else if (fakediff >= 0.1)
        {
            angles = srvangles;
            LogMessage("%f", fakediff);
            silentpatched = true;
        }
    }


    // grab angles
    // thanks to nosoop from the sm discord for some help with this
    clangles[Cl][4] = clangles[Cl][3];
    clangles[Cl][3] = clangles[Cl][2];
    clangles[Cl][2] = clangles[Cl][1];
    clangles[Cl][1] = clangles[Cl][0];
    clangles[Cl][0] = angles;

    // grab cmdnum
    for (int i = 5; i > 0; --i)
    {
        clcmdnum[Cl][i] = clcmdnum[Cl][i-1];
    }
    clcmdnum[Cl][0] = cmdnum;

    // grab tickccount
    for (int i = 5; i > 0; --i)
    {
        cltickcount[Cl][i] = cltickcount[Cl][i-1];
    }
    cltickcount[Cl][0] = tickcount;

    // grab buttons
    for (int i = 5; i > 0; --i)
    {
        clbuttons[Cl][i] = clbuttons[Cl][i-1];
    }
    clbuttons[Cl][0] = buttons;

    // grab mouse
    clmouse[Cl] = mouse;

    // grab position
    clpos[Cl][1] = clpos[Cl][0];
    GetClientEyePosition(Cl, clpos[Cl][0]);

    // did we hurt someone in any of the past few frames?
    didHurtOnFrame[Cl][2] = didHurtOnFrame[Cl][1];
    didHurtOnFrame[Cl][1] = didHurtOnFrame[Cl][0];
    didHurtOnFrame[Cl][0] = didHurtThisFrame[Cl];
    didHurtThisFrame[Cl] = false;

    // did we shoot a bullet in any of the past few frames?
    didBangOnFrame[Cl][2] = didBangOnFrame[Cl][1];
    didBangOnFrame[Cl][1] = didBangOnFrame[Cl][0];
    didBangOnFrame[Cl][0] = didBangThisFrame[Cl];
    didBangThisFrame[Cl] = false;

    // detect trigger teleports
    if (GetVectorDistance(clpos[Cl][0], clpos[Cl][1], false) > 500)
    {
        // reuse this variable
        timeSinceTeled[Cl] = GetEngineTime();
    }

    // R O U N D ( fuzzy psilent detection to detect lmaobox silent+ and better detect other forms of silent aim )

    fuzzyClangles[Cl][2][0] = RoundToPlace(clangles[Cl][2][0], 1);
    fuzzyClangles[Cl][2][1] = RoundToPlace(clangles[Cl][2][1], 1);
    fuzzyClangles[Cl][1][0] = RoundToPlace(clangles[Cl][1][0], 1);
    fuzzyClangles[Cl][1][1] = RoundToPlace(clangles[Cl][1][1], 1);
    fuzzyClangles[Cl][0][0] = RoundToPlace(clangles[Cl][0][0], 1);
    fuzzyClangles[Cl][0][1] = RoundToPlace(clangles[Cl][0][1], 1);

    // avg'd over 10 ticks
    calcCmdrateFor[Cl] = 10.0 * Pow((engineTime[Cl][0] - engineTime[Cl][10]), -1.0);

    // neither of these tests need fancy checks, so we do them first
    bhopCheck(userid);
    turnbindCheck(userid);

    // we have to do all these annoying checks to make sure we get as few false positives as possible.
    if
    (
        // make sure client is on a team & alive - spec cameras can cause fake angs!
           !IsClientPlaying(Cl)
        // ...isn't currently taunting - can cause fake angs!
        || playerTaunting[Cl]
        // ...didn't recently spawn - can cause invalid psilent detects
        || engineTime[Cl][0] - 1.0 < timeSinceSpawn[Cl]
        // ...didn't recently taunt - can (obviously) cause fake angs!
        || engineTime[Cl][0] - 1.0 < timeSinceTaunt[Cl]
        // ...didn't recently teleport - can cause psilent detects
        || engineTime[Cl][0] - 1.0 < timeSinceTeled[Cl]
        // don't touch this client if they've recently run a nullcmd, because they're probably lagging
        // I will tighten this up if cheats decide to try to get around stac by spamming nullcmds.
        || engineTime[Cl][0] - 0.5 < timeSinceNullCmd[Cl]
        // don't touch if map or plugin just started - let the server framerate stabilize a bit
        || engineTime[Cl][0] - 2.5 < timeSinceMapStart
        // lets wait a bit if we had a lag spike in the last 5 seconds
        || engineTime[Cl][0] - stutterWaitLength < timeSinceLagSpike
        // make sure client isn't timing out - duh
        || IsClientTimingOut(Cl)
        // this is just for halloween shit - plenty of halloween effects can and will mess up all of these checks
        || playerInBadCond[Cl] != 0
    )
    {
        return Plugin_Continue;
    }

    // not really lag dependant check
    fakeangCheck(userid);

    // we don't want to check this if we're repeating tickcount a lot and/or if loss is high, but cmdnums and tickcounts DO NOT NEED TO BE PERFECT for this.
    if (!islagging && !islossy)
    {
        cmdnumspikeCheck(userid);
    }

    if
    (
        // make sure client doesn't have invalid angles. "invalid" in this case means "any angle is 0.000000", usually caused by plugin / trigger based teleportation
        !HasValidAngles(Cl)
        // make sure client isnt using a spin bind
        || buttons & IN_LEFT
        || buttons & IN_RIGHT
    )
    // if any of these things are true, don't check angles or cmdnum spikes or spinbot stuff
    {
        return Plugin_Continue;
    }

    if (silentpatched)
    {
        psilentCheck(userid, true, fakediff);
    }
    else
    {
        psilentCheck(userid);
    }

    // psilent has better checks for lag, these funcs do not.
    if (IsUserLagging(userid) || IsUserLossy(userid))
    {
        return Plugin_Continue;
    }

    fakechokeCheck(userid);
    spinbotCheck(userid);
    aimsnapCheck(userid);
    triggerbotCheck(userid);

    return Plugin_Continue;
}

public void OnPlayerRunCmdPost
(
    int Cl,
    int buttons,
    int impulse,
    const float vel[3],
    const float angles[3],
    int weapon,
    int subtype,
    int cmdnum,
    int tickcount,
    int seed,
    const int mouse[2]
)
{
    realclangles    [Cl] = angles;
    realclcmdnum    [Cl] = cmdnum;
    realcltickcount [Cl] = tickcount;
    realclbuttons   [Cl] = buttons;
    realclmouse     [Cl] = mouse;
}
