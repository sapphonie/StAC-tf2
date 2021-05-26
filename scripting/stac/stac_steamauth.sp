/********** STEAM CHECKS **********/

public void Steam_SteamServersDisconnected()
{
    isSteamAlive = 0;
    StacLog("[Steamtools] Steam disconnected.");
}

public void SteamWorks_SteamServersDisconnected(EResult result)
{
    isSteamAlive = 0;
    StacLog("[SteamWorks] Steam disconnected.");
}

public void Steam_SteamServersConnected()
{
    setSteamOnline();
    StacLog("[Steamtools] Steam connected.");
}

public void SteamWorks_SteamServersConnected()
{
    setSteamOnline();
    StacLog("[SteamWorks] Steam connected.");
}

void setSteamOnline()
{
    isSteamAlive = 1;
    steamLastOnlineTime = GetEngineTime();
}

// this will return false for 300 seconds after server start. just a heads up.
bool isSteamStable()
{
    if (steamLastOnlineTime == 0.0 || isSteamAlive == -1)
    {
        checkSteam();
        return false;
    }

    StacLog("[StAC] GetEngineTime() - steamLastOnlineTime = %f >? 300.0", GetEngineTime() - steamLastOnlineTime);

    // time since steam last came online must be greater than 300
    if (GetEngineTime() - steamLastOnlineTime >= 300.0)
    {
        StacLog("steam stable!");
        return true;
    }
    StacLog("steam went down too recently");
    return false;
}

bool checkSteam()
{
    if (STEAMTOOLS)
    {
        if (Steam_IsConnected())
        {
            steamLastOnlineTime = GetEngineTime();
            isSteamAlive = 1;
            return true;
        }
        isSteamAlive = 0;
    }
    if (STEAMWORKS)
    {
        if (SteamWorks_IsConnected())
        {
            steamLastOnlineTime = GetEngineTime();
            isSteamAlive = 1;
            return true;
        }
        isSteamAlive = 0;
    }
    isSteamAlive = -1;
    return false;
}

bool shouldCheckAuth()
{
    if
    (
        isSteamAlive == 1
        &&
        isSteamStable()
    )
    {
        return true;
    }
    return false;
}
