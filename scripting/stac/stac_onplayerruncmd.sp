#pragma semicolon 1

/********** OnPlayerRunCmd Detections **********/

/*
    in OnPlayerRunCmd, we check for:
    - CMDNUM SPIKES
    - SILENT AIM
    - AIM SNAPS
    - FAKE ANGLES
    - TURN BINDS
*/

bool useOnPlayerRunCmdPre = false;
public void OnPlayerRunCmdPre
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
    useOnPlayerRunCmdPre = true;

    PlayerRunCmd(Cl, buttons, impulse, vel, angles, weapon, subtype, cmdnum, tickcount, seed, mouse);
}

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

    // only run if OnPlayerRunCmdPre doesn't ever fire (meaning we're not on a sm.1.11.6876 install or newer)
    if (!useOnPlayerRunCmdPre)
    {
        PlayerRunCmd(Cl, buttons, impulse, vel, angles, weapon, subtype, cmdnum, tickcount, seed, mouse);
    }

    return Plugin_Continue;
}


stock void PlayerRunCmd
(
    const int Cl,
    const int buttons,
    const int impulse,
    const float vel[3],
    const float angles[3],
    const int weapon,
    const int subtype,
    const int cmdnum,
    const int tickcount,
    const int seed,
    const int mouse[2]
)
{
    // make sure client is real & not a bot
    if (!IsValidClient(Cl))
    {
        return;
    }

    // need this basically no matter what
    int userid = GetClientUserId(Cl);

    // originally from ssac - block invalid usercmds with invalid data
    if (cmdnum <= 0 || tickcount <= 0)
    {
        if (cmdnum < 0 || tickcount < 0)
        {
            StacLog("cmdnum %i, tickcount %i", cmdnum, tickcount);
            StacGeneralPlayerNotify(userid, "Client has invalid usercmd data!");
            return;
        }
        timeSinceNullCmd[Cl] = GetEngineTime();
        return;
    }

    // grab engine time
    for (int i = 2; i > 0; --i)
    {
        engineTime[Cl][i] = engineTime[Cl][i-1];
    }
    engineTime[Cl][0] = GetEngineTime();

    // calc client cmdrate
    calcTPSfor(Cl);

    // grab angles
    // thanks to nosoop from the sm discord for some help with this
    clangles[Cl][4] = clangles[Cl][3];
    clangles[Cl][3] = clangles[Cl][2];
    clangles[Cl][2] = clangles[Cl][1];
    clangles[Cl][1] = clangles[Cl][0];
    clangles[Cl][0] = angles;
    // GetClientEyeAngles( Cl, clangles[Cl][0] );


/*
    srvClangles[Cl][2] = srvClangles[Cl][1];
    srvClangles[Cl][1] = srvClangles[Cl][0];
    GetClientEyeAngles( Cl, srvClangles[Cl][0] );

    LogMessage(
        "real angles = %f %f %f",
        srvClangles[Cl][0][0],
        srvClangles[Cl][1][0],
        srvClangles[Cl][2][0]
    );
*/

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

    // round our angles.
    // fuzzy psilent detection to detect lmaobox silent+ and better detect other forms of silent aim
    // BONK: use an epsilon??

    fuzzyClangles[Cl][2][0] = RoundToPlace(clangles[Cl][2][0], 1);
    fuzzyClangles[Cl][2][1] = RoundToPlace(clangles[Cl][2][1], 1);
    fuzzyClangles[Cl][1][0] = RoundToPlace(clangles[Cl][1][0], 1);
    fuzzyClangles[Cl][1][1] = RoundToPlace(clangles[Cl][1][1], 1);
    fuzzyClangles[Cl][0][0] = RoundToPlace(clangles[Cl][0][0], 1);
    fuzzyClangles[Cl][0][1] = RoundToPlace(clangles[Cl][0][1], 1);


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
        || engineTime[Cl][0] - 0.1 < timeSinceNullCmd[Cl]
        // don't touch if map or plugin just started - let the server framerate stabilize a bit
        || engineTime[Cl][0] - 2.5 < timeSinceMapStart
        // lets wait a bit if we had a server lag spike in the last 5 seconds
        || engineTime[Cl][0] - ServerLagWaitLength < timeSinceLagSpikeFor[0]
        // lets also wait a bit if we had a lag spike in the last 5 seconds on this specific client
        || engineTime[Cl][0] - PlayerLagWaitLength < timeSinceLagSpikeFor[Cl]
        // make sure client isn't timing out - duh
        || IsClientTimingOut(Cl)
        // this is just for halloween shit - plenty of halloween effects can and will mess up all of these checks
        || playerInBadCond[Cl] != 0
    )
    {
        return;
    }

    // not really lag dependant check
    fakeangCheck(userid);

    if
    (
        // make sure client doesn't have invalid angles. "invalid" in this case means "any angle is 0.000000", usually caused by plugin / trigger based teleportation
        !HasValidAngles(Cl)
        // make sure client doesn't have OUTRAGEOUS ping
        // most cheater fakeping goes up to 800 so tack on 50 just in case
        || pingFor[Cl] > 850.0
    )
    {
        return;
    }

    // we don't want to check this if we're repeating tickcount a lot and/or if loss is high, but cmdnums and tickcounts DO NOT NEED TO BE PERFECT for this.
    if (!IsUserLagging(userid, false, false) && isCmdnumInOrder(userid))
    {
        cmdnumspikeCheck(userid);
    }

    if
    (
        // make sure client isnt using a spin bind
           buttons & IN_LEFT
        || buttons & IN_RIGHT
        // make sure we're not lagging and that cmdnum is saneish
        || IsUserLagging(userid, true, false)
    )
    // if any of these things are true, don't check angles etc
    {
        return;
    }
    aimsnapCheck(userid);
    triggerbotCheck(userid);
    psilentCheck(userid);

    return;
}

/*
    BHOP DETECTION - using lilac and ssac as reference, this one's better tho
*/
void bhopCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    // don't run this check if cvar is -1
    if (maxBhopDetections != -1)
    {
        // get movement flags
        int flags = GetEntityFlags(Cl);

        bool noban;
        if (maxBhopDetections == 0)
        {
            noban = true;
        }

        // reset their gravity if it's high!
        if (highGrav[Cl])
        {
            SetEntityGravity(Cl, 1.0);
            highGrav[Cl] = false;
        }

        if
        (
            // last input didn't have a jump
                !(clbuttons[Cl][1] & IN_JUMP)
            // player pressed jump
            &&  (clbuttons[Cl][0] & IN_JUMP)
            // they were on the ground when they jumped
            &&  (flags & FL_ONGROUND)
        )
        {
            // increment bhops
            bhopDetects[Cl]++;

            // print to admins if close to getting banned - or at default bhop amt ( 10 )
            if
            (
                (
                    bhopDetects[Cl] >= maxBhopDetections
                    &&
                    !noban
                )
                ||
                (
                    bhopDetects[Cl] >= 10
                    &&
                    noban
                )
            )
            {
                PrintToImportant("{hotpink}[StAC]{white} Player %N {mediumpurple}bhopped{white}!\nConsecutive detections so far: {palegreen}%i" , Cl, bhopDetects[Cl]);
                if (bhopDetects[Cl] % 5 == 0)
                {
                    StacDetectionNotify(userid, "consecutive tick perfect bhops", bhopDetects[Cl]);
                }
                StacLogSteam(userid);

                if (bhopDetects[Cl] >= maxBhopDetections)
                {
                    // punish on maxBhopDetections + 2 (for the extra TWO tick perfect bhops at 8x grav with no warning - no human can do this!)
                    if
                    (
                        (bhopDetects[Cl] >= (maxBhopDetections + 2))
                        &&
                        !noban
                    )
                    {
                        SetEntityGravity(Cl, 1.0);
                        highGrav[Cl] = false;
                        char reason[128];
                        Format(reason, sizeof(reason), "%t", "bhopBanMsg", bhopDetects[Cl]);
                        char pubreason[256];
                        Format(pubreason, sizeof(pubreason), "%t", "bhopBanAllChat", Cl, bhopDetects[Cl]);
                        BanUser(userid, reason, pubreason);
                        return;
                    }

                    // don't run antibhop if cvar is 0
                    if (maxBhopDetections > 0)
                    {
                        /* ANTIBHOP */
                        // set the player's gravity to 8x.
                        // if idiot cheaters keep holding their spacebar for an extra second and do 2 tick perfect bhops WHILE at 8x gravity...
                        // ...we will catch them autohopping and ban them!
                        SetEntityGravity(Cl, 8.0);
                        highGrav[Cl] = true;
                    }
                }
            }
        }
        else if
        (
            // player didn't press jump
            !(
                clbuttons[Cl][0] & IN_JUMP
            )
            // player is on the ground
            &&
            (
                flags & FL_ONGROUND
            )
        )
        {
            // set to -1 to ignore single jumps, we ONLY want to count bhops
            bhopDetects[Cl] = -1;
        }
    }
}

/*
    TURN BIND TEST
*/
void turnbindCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if
    (
        maxAllowedTurnSecs != -1.0
        &&
        (
            clbuttons[Cl][0] & IN_LEFT
            ||
            clbuttons[Cl][0] & IN_RIGHT
        )
    )
    {
        turnTimes[Cl]++;
        float turnSec = turnTimes[Cl] * tickinterv;
        PrintToImportant("%t", "turnbindAdminMsg", Cl, turnSec);
        StacLogSteam(userid);

        if (turnSec < maxAllowedTurnSecs)
        {
            MC_PrintToChat(Cl, "%t", "turnbindWarnPlayer");
        }
        else if (turnSec >= maxAllowedTurnSecs)
        {
            StacGeneralPlayerNotify(userid, "Client was kicked for turn binds");
            KickClient(Cl, "%t", "turnbindKickMsg");
            MC_PrintToChatAll("%t", "turnbindAllChat", Cl);
            StacLog("%t", "turnbindAllChat", Cl);
        }
    }
}

/*
    EYE ANGLES TEST
    if clients are outside of allowed angles in tf2, which are
      +/- 89.0 x (up / down)
      +/- 180 y (left / right, but we don't check this atm because there's things that naturally fuck up y angles, such as taunts)
      +/- 50 z (roll / tilt)
    while they are not in spec & on a map camera, we should log it.
    we would fix them but cheaters can just ignore server-enforced viewangle changes so there's no point

    these bounds were lifted from lilac. Thanks lilac.
    lilac patches roll, we do not, i think it (screen shake) is an important part of tf2,
    jtanz says that lmaobox can abuse roll so it should just be removed. i think both opinions are fine
*/
void fakeangCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if
    (
        // don't bother checking if fakeang detection is off
        maxFakeAngDetections != -1
        &&
        (
            FloatAbs(clangles[Cl][0][0]) > 89.00
            ||
            FloatAbs(clangles[Cl][0][2]) > 50.00
        )
    )
    {
        fakeAngDetects[Cl]++;
        PrintToImportant
        (
            "{hotpink}[StAC]{white} Player %N has {mediumpurple}invalid eye angles{white}!\nCurrent angles: {mediumpurple}%.2f %.2f %.2f{white}.\nDetections so far: {palegreen}%i",
            Cl,
            clangles[Cl][0][0],
            clangles[Cl][0][1],
            clangles[Cl][0][2],
            fakeAngDetects[Cl]
        );
        StacLogSteam(userid);
        if (fakeAngDetects[Cl] == 1 || fakeAngDetects[Cl] % 5 == 0)
        {
            StacDetectionNotify(userid, "fake angles", fakeAngDetects[Cl]);
        }
        if (fakeAngDetects[Cl] >= maxFakeAngDetections && maxFakeAngDetections > 0)
        {
            char reason[128];
            Format(reason, sizeof(reason), "%t", "fakeangBanMsg", fakeAngDetects[Cl]);
            char pubreason[256];
            Format(pubreason, sizeof(pubreason), "%t", "fakeangBanAllChat", Cl, fakeAngDetects[Cl]);
            BanUser(userid, reason, pubreason);
        }
    }
}

/*
    CMDNUM SPIKE TEST - heavily modified from SSAC
    this is for detecting when cheats "skip ahead" their cmdnum so they can fire a "perfect shot" aka a shot with no spread
    funnily enough, it actually DOESN'T change where their bullet goes, it's just a client side visual effect with decals
*/
void cmdnumspikeCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if (maxCmdnumDetections != -1)
    {
        int spikeamt = clcmdnum[Cl][0] - clcmdnum[Cl][1];
        // https://github.com/sapphonie/StAC-tf2/issues/74

        // clients in OF can trigger this by lagging, hackers tend to hit ~1000
        // -rowedahelicon
        #if defined OF
        if (spikeamt >= 999 || spikeamt < 0)
        #else
        if (spikeamt >= 32 || spikeamt < 0)
        #endif
        {
            char heldWeapon[256];
            GetClientWeapon(Cl, heldWeapon, sizeof(heldWeapon));

            cmdnumSpikeDetects[Cl]++;
            PrintToImportant
            (
                "{hotpink}[StAC]{white} Cmdnum SPIKE of {yellow}%i{white} on %N.\nDetections so far: {palegreen}%i{white}.",
                spikeamt,
                Cl,
                cmdnumSpikeDetects[Cl]
            );
            StacLogSteam(userid);
            StacLogNetData(userid);
            StacLogCmdnums(userid);
            StacLogTickcounts(userid);
            StacLog("Held weapon: %s", heldWeapon);

            if (cmdnumSpikeDetects[Cl] % 5 == 0)
            {
                StacDetectionNotify(userid, "cmdnum spike", cmdnumSpikeDetects[Cl]);
            }

            // punish if we reach limit set by cvar
            if (cmdnumSpikeDetects[Cl] >= maxCmdnumDetections && maxCmdnumDetections > 0)
            {
                char reason[128];
                Format(reason, sizeof(reason), "%t", "cmdnumSpikesBanMsg", cmdnumSpikeDetects[Cl]);
                char pubreason[256];
                Format(pubreason, sizeof(pubreason), "%t", "cmdnumSpikesBanAllChat", Cl, cmdnumSpikeDetects[Cl]);
                BanUser(userid, reason, pubreason);
            }
        }
    }
}

/*
    SILENT AIM DETECTION
    silent aim (in this context) works by aimbotting for 1 tick and then snapping your viewangle back to what it was
    example snap:
        L 03/25/2020 - 06:03:50: [stac.smx] [StAC] pSilent detection: angles0  angles: x 5.120096 y 9.763162
        L 03/25/2020 - 06:03:50: [stac.smx] [StAC] pSilent detection: angles1  angles: x 1.635611 y 12.876886
        L 03/25/2020 - 06:03:50: [stac.smx] [StAC] pSilent detection: angles2  angles: x 5.120096 y 9.763162
    we can just look for these snaps and log them as detections!
    note that this won't detect some snaps when a player is moving their strafe keys and mouse @ the same time while they are aimlocking.

    we have to do EXTRA checks because a lot of things can fuck up silent aim detection
    make sure ticks are sequential, hopefully avoid laggy players
    example real detection:

    [StAC] pSilent / NoRecoil detection of 5.20° on <user>.
    Detections so far: 15
    User Net Info: 0.00% loss, 24.10% choke, 66.22 ms ping
     clcmdnum[0]: 61167
     clcmdnum[1]: 61166
     clcmdnum[2]: 61165
     angles0: x 8.82 y 127.68
     angles1: x 5.38 y 131.60
     angles2: x 8.82 y 127.68
*/

// todo: https://github.com/sapphonie/StAC-tf2/issues/74
// check angle diff from clangles[Cl][1] to clangles[Cl][0] and clangles[Cl][2] , count if they "match" up to an epsilon of 1.0 deg (ish?)
// my foolishly =='ing floats must unfortunately come to an end
/*

bool floatcmpreal( float a, float b, float precision = 0.001 )
{
    return FloatAbs( a - b ) <= precision;
}

*/
void psilentCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    // get difference between angles - used for psilent
    float aDiffReal = NormalizeAngleDiff(CalcAngDeg(clangles[Cl][0], clangles[Cl][1]));

    // is this a fuzzy detect or not
    int fuzzy = -1;
    // don't run this check if silent aim cvar is -1
    if
    (
        maxPsilentDetections != -1
        &&
        (
            clbuttons[Cl][0] & IN_ATTACK
            ||
            clbuttons[Cl][1] & IN_ATTACK
        )
    )
    {
        if
        (
            // so the current and 2nd previous angles match...
            (
                   clangles[Cl][0][0] == clangles[Cl][2][0]
                && clangles[Cl][0][1] == clangles[Cl][2][1]
                // floatcmpreal(clangles[Cl][0][0], clangles[Cl][2][0], 1.0);
                // floatcmpreal(clangles[Cl][0][0], clangles[Cl][2][0], 1.0);
            )
            &&
            // BUT the 1st previous (in between) angle doesnt?
            (
                   clangles[Cl][1][0] != clangles[Cl][0][0]
                && clangles[Cl][1][1] != clangles[Cl][0][1]
                && clangles[Cl][1][0] != clangles[Cl][2][0]
                && clangles[Cl][1][1] != clangles[Cl][2][1]
            )
        )
        {
            fuzzy = 0;
        }
        else if
        (
            // etc
            (
                   fuzzyClangles[Cl][0][0] == fuzzyClangles[Cl][2][0]
                && fuzzyClangles[Cl][0][1] == fuzzyClangles[Cl][2][1]
            )
            &&
            // etc
            (
                   fuzzyClangles[Cl][1][0] != fuzzyClangles[Cl][0][0]
                && fuzzyClangles[Cl][1][1] != fuzzyClangles[Cl][0][1]
                && fuzzyClangles[Cl][1][0] != fuzzyClangles[Cl][2][0]
                && fuzzyClangles[Cl][1][1] != fuzzyClangles[Cl][2][1]
            )
        )
        {
            fuzzy = 1;
        }
        //  ok - lets make sure there's a difference of at least 1 degree on either axis to avoid most fake detections
        //  these are probably caused by packets arriving out of order but i'm not a fucking network engineer (yet) so idk
        //  examples of fake detections we want to avoid:
        //      03/25/2020 - 18:18:11: [stac.smx] [StAC] pSilent detection on [redacted]: curang angles: x 14.871331 y 154.979812
        //      03/25/2020 - 18:18:11: [stac.smx] [StAC] pSilent detection on [redacted]: prev1  angles: x 14.901910 y 155.010391
        //      03/25/2020 - 18:18:11: [stac.smx] [StAC] pSilent detection on [redacted]: prev2  angles: x 14.871331 y 154.979812
        //  and
        //      03/25/2020 - 22:16:36: [stac.smx] [StAC] pSilent detection on [redacted2]: curang angles: x 21.516006 y -140.723709
        //      03/25/2020 - 22:16:36: [stac.smx] [StAC] pSilent detection on [redacted2]: prev1  angles: x 21.560007 y -140.943710
        //      03/25/2020 - 22:16:36: [stac.smx] [StAC] pSilent detection on [redacted2]: prev2  angles: x 21.516006 y -140.723709
        //  doing this might make it harder to detect legitcheaters but like. legitcheating in a 12 yr old dead game OMEGALUL who fucking cares
        if
        (
            aDiffReal >= 1.0 && fuzzy >= 0
        )
        {
            pSilentDetects[Cl]++;
            // have this detection expire in 30 minutes
            CreateTimer(1800.0, Timer_decr_pSilent, userid, TIMER_FLAG_NO_MAPCHANGE);
            // first detection is LIKELY bullshit
            if (pSilentDetects[Cl] > 0)
            {
                // only print a bit in chat, rest goes to console (stv and admin and also the stac log)
                PrintToImportant
                (
                    "\
                    {hotpink}[StAC]{white} SilentAim detection of {yellow}%.2f{white}° on %N.\
                    \nDetections so far: {palegreen}%i{white}. fuzzy = {blue}%s{white} norecoil = {plum}%s",
                    aDiffReal, Cl,
                    pSilentDetects[Cl], fuzzy == 1 ? "yes" : "no", aDiffReal <= 3.0 ? "yes" : "no"
                );
                StacLogSteam(userid);
                StacLogNetData(userid);
                StacLogAngles(userid);
                StacLogCmdnums(userid);
                StacLogTickcounts(userid);
                StacLogMouse(userid);
                if (AIMPLOTTER)
                {
                    ServerCommand("sm_aimplot #%i on", userid);
                }
                if (pSilentDetects[Cl] % 5 == 0)
                {
                    StacDetectionNotify(userid, "psilent", pSilentDetects[Cl]);
                }
                // BAN USER if they trigger too many detections
                if (pSilentDetects[Cl] >= maxPsilentDetections && maxPsilentDetections > 0)
                {
                    char reason[128];
                    Format(reason, sizeof(reason), "%t", "pSilentBanMsg", pSilentDetects[Cl]);
                    char pubreason[256];
                    Format(pubreason, sizeof(pubreason), "%t", "pSilentBanAllChat", Cl, pSilentDetects[Cl]);
                    BanUser(userid, reason, pubreason);
                }
            }
        }
    }
}

/*
    AIMSNAP DETECTION - BETA

    Alright, here's how this works.

    If we try to just detect one frame snaps and nothing else, users can just crank up their sens,
    and wave their mouse around and get detects. so what we do is this:

    if a user has a snap of more than 20 degrees, and that snap is surrounded on one or both sides by "noise delta" of LESS than 5 degrees
    ...that counts as an aimsnap. this will catch cheaters, unless they wave their mouse around wildly, making the game miserable to play
    AND obvious that they're avoiding the anticheat.

*/
void aimsnapCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);

    if
    (
        // for some reason this just does not behave well in mvm
            !MVM
        // only check if we have this check enabled
        &&  maxAimsnapDetections != -1
        // only check if we pressed attack recently
        &&
        (
               clbuttons[Cl][0] & IN_ATTACK
            || clbuttons[Cl][1] & IN_ATTACK
            || clbuttons[Cl][2] & IN_ATTACK
        )
    )
    {
        float aDiff[4];
        aDiff[0] = NormalizeAngleDiff(CalcAngDeg(clangles[Cl][0], clangles[Cl][1]));
        aDiff[1] = NormalizeAngleDiff(CalcAngDeg(clangles[Cl][1], clangles[Cl][2]));
        aDiff[2] = NormalizeAngleDiff(CalcAngDeg(clangles[Cl][2], clangles[Cl][3]));
        aDiff[3] = NormalizeAngleDiff(CalcAngDeg(clangles[Cl][3], clangles[Cl][4]));

        // example values of a snap:
        // 0.000000, 91.355995, 0.000000, 0.000000
        // 0.018540, 0.000000, 91.355995, 0.000000

        // only check if we actually did hitscan dmg in the current frame
        // thinking about removing this...
        if
        (
            didHurtOnFrame[Cl][1]
            &&
            didBangOnFrame[Cl][1]
        )
        {
            float snapsize  = 20.0;
            float noisesize = 1.0;

            int aDiffToUse = -1;
            // commented so we can make sure we have one or more noise buffers
            //if
            //(
            //       aDiff[0] > snapsize
            //    && aDiff[1] < noisesize
            //    && aDiff[2] < noisesize
            //    && aDiff[3] < noisesize
            //)
            //{
            //    aDiffToUse = 0;
            //}
            if
            (
                   aDiff[0] < noisesize
                && aDiff[1] > snapsize
                && aDiff[2] < noisesize
                && aDiff[3] < noisesize
            )
            {
                aDiffToUse = 1;
            }
            if
            (
                   aDiff[0] < noisesize
                && aDiff[1] < noisesize
                && aDiff[2] > snapsize
                && aDiff[3] < noisesize
            )
            {
                aDiffToUse = 2;
            }
            //else if
            //(
            //       aDiff[0] < noisesize
            //    && aDiff[1] < noisesize
            //    && aDiff[2] < noisesize
            //    && aDiff[3] > snapsize
            //)
            //{
            //    aDiffToUse = 3;
            //}
            // we got one!
            if (aDiffToUse > -1)
            {
                float aDiffReal = aDiff[aDiffToUse];

                // increment aimsnap detects
                aimsnapDetects[Cl]++;
                // have this detection expire in 30 minutes
                CreateTimer(1800.0, Timer_decr_aimsnaps, userid, TIMER_FLAG_NO_MAPCHANGE);
                // first detection is likely bullshit
                if (aimsnapDetects[Cl] > 0)
                {
                    PrintToImportant
                    (
                        "{hotpink}[StAC]{white} Aimsnap detection of {yellow}%.2f{white}° on %N.\nDetections so far: {palegreen}%i{white}.",
                        aDiffReal,
                        Cl,
                        aimsnapDetects[Cl]
                    );
                    StacLogSteam(userid);
                    StacLogNetData(userid);
                    StacLogAngles(userid);
                    StacLogCmdnums(userid);
                    StacLogTickcounts(userid);
                    StacLogMouse(userid);
                    StacLog
                    (
                        "\nAngle deltas:\n0 %f\n1 %f\n2 %f\n3 %f\n",
                        aDiff[0],
                        aDiff[1],
                        aDiff[2],
                        aDiff[3]
                    );

                    if (AIMPLOTTER)
                    {
                        ServerCommand("sm_aimplot #%i on", userid);
                    }

                    if (aimsnapDetects[Cl] % 5 == 0)
                    {
                        StacDetectionNotify(userid, "aimsnap", aimsnapDetects[Cl]);
                    }

                    // BAN USER if they trigger too many detections
                    if (aimsnapDetects[Cl] >= maxAimsnapDetections && maxAimsnapDetections > 0)
                    {
                        char reason[128];
                        Format(reason, sizeof(reason), "%t", "AimsnapBanMsg", aimsnapDetects[Cl]);
                        char pubreason[256];
                        Format(pubreason, sizeof(pubreason), "%t", "AimsnapBanAllChat", Cl, aimsnapDetects[Cl]);
                        BanUser(userid, reason, pubreason);
                    }
                }
            }
        }
    }
}

/*
    TRIGGERBOT DETECTION
*/
void triggerbotCheck(int userid)
{
    int Cl = GetClientOfUserId(userid);
    // don't run if cvar is -1 or if wait is enabled on this server
    if (maxTbotDetections != -1 && !waitStatus)
    {
        int attack = 0;
        // grab single tick +attack inputs - this checks for the following pattern:
        // frame before last    //
        // last frame           // IN_ATTACK
        // current frame        //

        if
        (
            !(clbuttons[Cl][2] & IN_ATTACK)
            &&
            (clbuttons[Cl][1] & IN_ATTACK)
            &&
            !(clbuttons[Cl][0] & IN_ATTACK)
        )
        {
            attack = 1;
        }
        // grab single tick +attack2 inputs - pyro airblast, demo det, etc
        // this checks for the following pattern:
        // frame before last    //
        // last frame           // IN_ATTACK2
        // current frame        //

        else if
        (
            !(clbuttons[Cl][2] & IN_ATTACK2)
            &&
            (clbuttons[Cl][1] & IN_ATTACK2)
            &&
            !(clbuttons[Cl][0] & IN_ATTACK2)
        )
        {
            attack = 2;
        }

        if
        (
            // did dmg on this tick
            didHurtOnFrame[Cl][0]
            &&
            // single tick input
            attack > 0
        )
        {
            tbotDetects[Cl]++;
            // have this detection expire in 30 minutes
            CreateTimer(1800.0, Timer_decr_tbot, userid, TIMER_FLAG_NO_MAPCHANGE);

            if (tbotDetects[Cl] > 0)
            {
                PrintToImportant
                (
                    "{hotpink}[StAC]{white} Triggerbot detection on %N.\nDetections so far: {palegreen}%i{white}. Type: +attack{blue}%i",
                    Cl,
                    tbotDetects[Cl],
                    attack
                );
                StacLogSteam(userid);
                StacLogNetData(userid);
                StacLogAngles(userid);
                StacLogCmdnums(userid);
                StacLogTickcounts(userid);
                StacLogMouse(userid);
                StacLog
                (
                    "Weapon used: %s",
                    hurtWeapon[Cl]
                );

                if (AIMPLOTTER)
                {
                    ServerCommand("sm_aimplot #%i on", userid);
                }
                if (tbotDetects[Cl] % 5 == 0)
                {
                    StacDetectionNotify(userid, "triggerbot", tbotDetects[Cl]);
                }
                // BAN USER if they trigger too many detections
                if (tbotDetects[Cl] >= maxTbotDetections && maxTbotDetections > 0)
                {
                    char reason[128];
                    Format(reason, sizeof(reason), "%t", "tbotBanMsg", tbotDetects[Cl]);
                    char pubreason[256];
                    Format(pubreason, sizeof(pubreason), "%t", "tbotBanAllChat", Cl, tbotDetects[Cl]);
                    BanUser(userid, reason, pubreason);
                }
            }
        }
    }
}

/********** OnPlayerRunCmd based helper functions **********/

bool IsUserLagging(int userid, bool checkcmdnum = true, bool checktickcount = true)
{
    int Cl = GetClientOfUserId(userid);
    // check if we have sequential cmdnums
    if
    (
        // we don't want very much loss at all. this may be removed some day.
            lossFor[Cl] >= 1.0
        || !isCmdnumSequential(userid) && checkcmdnum
        || !isTickcountInOrder(userid) && checktickcount
        // tickcount the same over 6 ticks, client is *definitely* lagging
        || isTickcountRepeated(userid)
        ||
        (
            isDefaultTickrate()
            &&
            (
                // too short
                tickspersec[Cl] <= (40)
                ||
                // too long
                tickspersec[Cl] >= (100)
            )
        )
    )
    {
        if (!checktickcount)
        {
            timeSinceLagSpikeFor[Cl] = engineTime[Cl][0];
        }
        return true;
    }
    return false;
}

// calc distance between snaps in degrees
float CalcAngDeg(float array1[3], float array2[3])
{
    // ignore roll
    array1[2] = 0.0;
    array2[2] = 0.0;
    return SquareRoot(GetVectorDistance(array1, array2, true));
}

float NormalizeAngleDiff(float aDiff)
{
    if (aDiff > 180.0)
    {
        aDiff = FloatAbs(aDiff - 360.0);
    }
    return aDiff;
}

bool HasValidAngles(int Cl)
{
    if
    (
        // ignore weird angle resets in mge / dm && ignore laggy players
           IsZeroVector(clangles[Cl][0])
        || IsZeroVector(clangles[Cl][1])
        || IsZeroVector(clangles[Cl][2])
        || IsZeroVector(clangles[Cl][3])
        || IsZeroVector(clangles[Cl][4])
    )
    {
        return false;
    }
    return true;
}

bool isCmdnumSequential(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if
    (
           clcmdnum[Cl][0] == clcmdnum[Cl][1] + 1
        && clcmdnum[Cl][1] == clcmdnum[Cl][2] + 1
        && clcmdnum[Cl][2] == clcmdnum[Cl][3] + 1
        && clcmdnum[Cl][3] == clcmdnum[Cl][4] + 1
        && clcmdnum[Cl][4] == clcmdnum[Cl][5] + 1
    )
    {
        return true;
    }
    return false;
}

// check if the current cmdnum is greater than the last value etc
bool isCmdnumInOrder(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if (clcmdnum[Cl][0] > clcmdnum[Cl][1] > clcmdnum[Cl][2] > clcmdnum[Cl][3] > clcmdnum[Cl][4] > clcmdnum[Cl][5])
    {
        return true;
    }
    return false;
}

bool isTickcountInOrder(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if (cltickcount[Cl][0] > cltickcount[Cl][1] > cltickcount[Cl][2] > cltickcount[Cl][3] > cltickcount[Cl][4] > cltickcount[Cl][5])
    {
        return true;
    }
    return false;
}

bool isTickcountRepeated(int userid)
{
    int Cl = GetClientOfUserId(userid);
    if
    (
           cltickcount[Cl][0] == cltickcount[Cl][1]
        && cltickcount[Cl][1] == cltickcount[Cl][2]
        && cltickcount[Cl][2] == cltickcount[Cl][3]
        && cltickcount[Cl][3] == cltickcount[Cl][4]
        && cltickcount[Cl][4] == cltickcount[Cl][5]
    )
    {
        return true;
    }
    return false;
}

/********** DETECTION FORGIVENESS TIMERS **********/

Action Timer_decr_aimsnaps(Handle timer, any userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        if (aimsnapDetects[Cl] > -1)
        {
            aimsnapDetects[Cl]--;
        }
        if (aimsnapDetects[Cl] <= 0)
        {
            if (AIMPLOTTER)
            {
                ServerCommand("sm_aimplot #%i off", userid);
            }
        }
    }

    return Plugin_Continue;
}

Action Timer_decr_pSilent(Handle timer, any userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        if (pSilentDetects[Cl] > -1)
        {
            pSilentDetects[Cl]--;
        }
        if (pSilentDetects[Cl] <= 0)
        {
            if (AIMPLOTTER)
            {
                ServerCommand("sm_aimplot #%i off", userid);
            }
        }
    }

    return Plugin_Continue;
}

Action Timer_decr_tbot(Handle timer, any userid)
{
    int Cl = GetClientOfUserId(userid);

    if (IsValidClient(Cl))
    {
        if (tbotDetects[Cl] > -1)
        {
            tbotDetects[Cl]--;
        }
        if (tbotDetects[Cl] <= 0)
        {
            if (AIMPLOTTER)
            {
                ServerCommand("sm_aimplot #%i off", userid);
            }
        }
    }

    return Plugin_Continue;
}
