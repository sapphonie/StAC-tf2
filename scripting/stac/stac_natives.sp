#pragma semicolon 1

/********** NATIVES FOR OTHER PLUGINS, see include/stac.inc **********/

void CreateStacNatives()
{
    CreateNative("StAC_GetVersion",                             Native_GetVersion);
    CreateNative("StAC_GetClientData",                          Native_GetClientData);
    CreateNative("StAC_ClientData.GetAngles",                   Native_ClientData_GetAngles);
    CreateNative("StAC_ClientData.GetEyePosition",              Native_ClientData_GetEyePosition);
    CreateNative("StAC_ClientData.GetCmdNum",                   Native_ClientData_GetCmdNum);
    CreateNative("StAC_ClientData.GetTickCount",                Native_ClientData_GetTickCount);
    CreateNative("StAC_ClientData.GetButtons",                  Native_ClientData_GetButtons);
    CreateNative("StAC_ClientData.GetMouse",                    Native_ClientData_GetMouse);
    CreateNative("StAC_ClientData.GetSteamID",                  Native_ClientData_GetSteamID);
    CreateNative("StAC_ClientData.GetDetections",               Native_ClientData_GetDetections);
    CreateNative("StAC_ClientData.Sensitivity.get",             Native_ClientData_Sensitivity);
    CreateNative("StAC_ClientData.Ping.get",                    Native_ClientData_Ping);
    CreateNative("StAC_ClientData.AveragePing.get",             Native_ClientData_AveragePing);
    CreateNative("StAC_ClientData.Loss.get",                    Native_ClientData_Loss);
    CreateNative("StAC_ClientData.Choke.get",                   Native_ClientData_Choke);
    CreateNative("StAC_ClientData.InChoke.get",                 Native_ClientData_InChoke);
    CreateNative("StAC_ClientData.OutChoke.get",                Native_ClientData_OutChoke);
    CreateNative("StAC_ClientData.Rate.get",                    Native_ClientData_Rate);
    CreateNative("StAC_ClientData.PacketsPerSecond.get",        Native_ClientData_PacketsPerSecond);
    CreateNative("StAC_ClientData.CommandsPerSecond.get",       Native_ClientData_CommandsPerSecond);
    CreateNative("StAC_ClientData.IsLagging.get",               Native_ClientData_IsLagging);
    CreateNative("StAC_ClientData.HasSequentialCmdnums.get",    Native_ClientData_HasSequentialCmdnums);
}

// Every method takes its StAC_ClientData first, which is the client it was made for, or 0.
// StAC only has data for real clients that are in game. Returns 0 for everyone else, also
// for a client who left since the object was made, and the methods then give zero values.
int NativeClient(int client)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
    {
        return 0;
    }
    return client;
}

// A wrong index is a mistake in the calling plugin, which the thrown error reaches once the native returns.
bool NativeHistoryIndex(int index, int size)
{
    if (index < 0 || index >= size)
    {
        ThrowNativeError(SP_ERROR_INDEX, "Invalid history index %i, must be 0 to %i", index, size - 1);
        return false;
    }
    return true;
}

any Native_GetVersion(Handle plugin, int numParams)
{
    SetNativeString(1, PLUGIN_VERSION, GetNativeCell(2));
    return 0;
}

any Native_GetClientData(Handle plugin, int numParams)
{
    int cl = NativeClient(GetNativeCell(1));
    SetNativeCellRef(2, cl);
    return cl != 0;
}

any Native_ClientData_GetAngles(Handle plugin, int numParams)
{
    int cl      = NativeClient(GetNativeCell(1));
    int index   = GetNativeCell(2);
    if (!NativeHistoryIndex(index, sizeof(clangles[])))
    {
        return 0;
    }
    float angles[3];
    if (cl)
    {
        angles = clangles[cl][index];
    }
    SetNativeArray(3, angles, sizeof(angles));
    return 0;
}

any Native_ClientData_GetEyePosition(Handle plugin, int numParams)
{
    int cl      = NativeClient(GetNativeCell(1));
    int index   = GetNativeCell(2);
    if (!NativeHistoryIndex(index, sizeof(clpos[])))
    {
        return 0;
    }
    float position[3];
    if (cl)
    {
        position = clpos[cl][index];
    }
    SetNativeArray(3, position, sizeof(position));
    return 0;
}

any Native_ClientData_GetCmdNum(Handle plugin, int numParams)
{
    int cl      = NativeClient(GetNativeCell(1));
    int index   = GetNativeCell(2);
    if (!NativeHistoryIndex(index, sizeof(clcmdnum[])) || !cl)
    {
        return 0;
    }
    return clcmdnum[cl][index];
}

any Native_ClientData_GetTickCount(Handle plugin, int numParams)
{
    int cl      = NativeClient(GetNativeCell(1));
    int index   = GetNativeCell(2);
    if (!NativeHistoryIndex(index, sizeof(cltickcount[])) || !cl)
    {
        return 0;
    }
    return cltickcount[cl][index];
}

any Native_ClientData_GetButtons(Handle plugin, int numParams)
{
    int cl      = NativeClient(GetNativeCell(1));
    int index   = GetNativeCell(2);
    if (!NativeHistoryIndex(index, sizeof(clbuttons[])) || !cl)
    {
        return 0;
    }
    return clbuttons[cl][index];
}

any Native_ClientData_GetMouse(Handle plugin, int numParams)
{
    int cl = NativeClient(GetNativeCell(1));
    int mouse[2];
    if (cl)
    {
        mouse = clmouse[cl];
    }
    SetNativeArray(2, mouse, sizeof(mouse));
    return 0;
}

any Native_ClientData_GetSteamID(Handle plugin, int numParams)
{
    int cl = NativeClient(GetNativeCell(1));
    SetNativeString(2, cl ? SteamAuthFor[cl] : "", GetNativeCell(3));
    return 0;
}

any Native_ClientData_GetDetections(Handle plugin, int numParams)
{
    int cl = NativeClient(GetNativeCell(1));
    if (!cl)
    {
        return 0;
    }
    int detects;
    switch (view_as<StAC_Detection>(GetNativeCell(2)))
    {
        case StAC_Detection_Bhop:           detects = bhopDetects[cl];
        case StAC_Detection_FakeAngles:     detects = fakeAngDetects[cl];
        case StAC_Detection_CmdnumSpikes:   detects = cmdnumSpikeDetects[cl];
        case StAC_Detection_PSilent:        detects = pSilentDetects[cl];
        case StAC_Detection_Aimsnap:        detects = aimsnapDetects[cl];
        case StAC_Detection_Triggerbot:     detects = tbotDetects[cl];
        case StAC_Detection_InvalidUsercmd: detects = invalidUsercmdDetects[cl];
        case StAC_Detection_Playerperf:     detects = playerperfDetects[cl];
    }
    // some counters start at -1 so that the first detection is ignored
    return detects > 0 ? detects : 0;
}

// The value of one of StAC's per-client float arrays, 0.0 without a client.
any NativeClientFloat(const float[] values)
{
    int cl = NativeClient(GetNativeCell(1));
    return cl ? values[cl] : 0.0;
}

any Native_ClientData_Sensitivity(Handle plugin, int numParams)
{
    return NativeClientFloat(sensFor);
}

any Native_ClientData_Ping(Handle plugin, int numParams)
{
    return NativeClientFloat(pingFor);
}

any Native_ClientData_AveragePing(Handle plugin, int numParams)
{
    return NativeClientFloat(avgPingFor);
}

any Native_ClientData_Loss(Handle plugin, int numParams)
{
    return NativeClientFloat(lossFor);
}

any Native_ClientData_Choke(Handle plugin, int numParams)
{
    return NativeClientFloat(chokeFor);
}

any Native_ClientData_InChoke(Handle plugin, int numParams)
{
    return NativeClientFloat(inchokeFor);
}

any Native_ClientData_OutChoke(Handle plugin, int numParams)
{
    return NativeClientFloat(outchokeFor);
}

any Native_ClientData_Rate(Handle plugin, int numParams)
{
    return NativeClientFloat(rateFor);
}

any Native_ClientData_PacketsPerSecond(Handle plugin, int numParams)
{
    return NativeClientFloat(ppsFor);
}

any Native_ClientData_CommandsPerSecond(Handle plugin, int numParams)
{
    int cl = NativeClient(GetNativeCell(1));
    return cl ? tickspersec[cl] : 0;
}

any Native_ClientData_IsLagging(Handle plugin, int numParams)
{
    int cl = NativeClient(GetNativeCell(1));
    if (!cl)
    {
        return false;
    }
    // IsUserLagging remembers when it last saw a lag spike, which holds detections back.
    // Another plugin asking must not change that.
    float lagSpikeTime      = timeSinceLagSpikeFor[cl];
    bool lagging            = IsUserLagging(cl);
    timeSinceLagSpikeFor[cl] = lagSpikeTime;
    return lagging;
}

any Native_ClientData_HasSequentialCmdnums(Handle plugin, int numParams)
{
    int cl = NativeClient(GetNativeCell(1));
    return cl && isCmdnumSequential(cl);
}
