/*
    Gamedata
*/

void DoStACGamedata()
{
    // Our base gamedata file
    stac_gamedata = LoadGameConfigFile("stac");
    if (!stac_gamedata)
    {
        SetFailState("Failed to load StAC gamedata.");
        return;
    }

    // MEMORY OFFSETS

    /*
        Memory offsets
    */
    {
        // offset from client's signon state, offset from CBaseClient::this (?)
        Offset_SignonState  = view_as<Address>( GameConfGetOffset(stac_gamedata, "Offset_SignonState") );
        // Hack, see gamedata
        Offset_IClient_HACK = view_as<Address>( GameConfGetOffset(stac_gamedata, "Offset_IClient_HACK") );
    }

    // SIGNATURES

    /*
        CNetChan::ProcessPacket - for getting client's signonstate
    */
    {
        Handle hProcessPacket = DHookCreateFromConf(stac_gamedata, "CNetChan::ProcessPacket");
        if (!hProcessPacket)
        {
            SetFailState("Failed to setup detour for CNetChan::ProcessPacket");
        }
        // detour
        if ( !DHookEnableDetour(hProcessPacket, false, Detour_CNetChan__ProcessPacket) )
        {
            SetFailState("Failed to detour CNetChan::ProcessPacket.");
        }
        PrintToServer("CNetChan::ProcessPacket detoured!");
    }

    /*
        CBasePlayer::ProcessUsercmds - for eating usercmds from players who aren't signed on
    */
    {
        Handle CBasePlayer__ProcessUsercmds = DHookCreateFromConf( stac_gamedata, "CBasePlayer::ProcessUsercmds" );
        if ( !CBasePlayer__ProcessUsercmds )
        {
            SetFailState( "Failed to setup detour for CBasePlayer::ProcessUsercmds" );
        }

        // detour
        if ( !DHookEnableDetour( CBasePlayer__ProcessUsercmds, false, Detour_CBasePlayer__ProcessUsercmds ) )
        {
            SetFailState( "Failed to detour CBasePlayer::ProcessUsercmds." );
        }
        PrintToServer( "CBasePlayer::ProcessUsercmds detoured!" );
    }
    /*
        CBasePlayer::ProcessUsercmds - for eating usercmds from players who aren't signed on
    */
    {
        Handle CVEngineServer__GetClientConVarValue = DHookCreateFromConf( stac_gamedata, "CVEngineServer::GetClientConVarValue" );
        if ( !CVEngineServer__GetClientConVarValue )
        {
            SetFailState( "Failed to setup detour for CVEngineServer::GetClientConVarValue" );
        }

        // detour
        if ( !DHookEnableDetour( CVEngineServer__GetClientConVarValue, false, Detour_CVEngineServer__GetClientConVarValue ) )
        {
            SetFailState( "Failed to detour CVEngineServer::GetClientConVarValue." );
        }
        PrintToServer( "CVEngineServer::GetClientConVarValue detoured!" );
    }





    // VTABLE OFFSETS

    /*
        CBaseClient::GetPlayerSlot - for converting IClient* to ent idx
    */
    {
        StartPrepSDKCall( SDKCall_Raw );
        PrepSDKCall_SetFromConf( stac_gamedata, SDKConf_Virtual, "CBaseClient::GetPlayerSlot" );
        PrepSDKCall_SetReturnInfo( SDKType_PlainOldData, SDKPass_Plain );
        SDKCall_GetPlayerSlot = EndPrepSDKCall();
        if ( SDKCall_GetPlayerSlot != INVALID_HANDLE )
        {
            PrintToServer( "CBaseClient::GetPlayerSlot set up!" );
        }
        else
        {
            SetFailState( "Failed to get CBaseClient::GetPlayerSlot offset." );
        }
    }

    /*
        CNetChan::GetMsgHandler - for converting CNetChan::this* to a IClient*
    */
    {
        StartPrepSDKCall( SDKCall_Raw );
        PrepSDKCall_SetFromConf( stac_gamedata, SDKConf_Virtual, "CNetChan::GetMsgHandler" );
        PrepSDKCall_SetReturnInfo( SDKType_PlainOldData, SDKPass_Plain );
        SDKCall_GetMsgHandler = EndPrepSDKCall();
        if ( SDKCall_GetMsgHandler != INVALID_HANDLE )
        {
            PrintToServer( "CNetChan::GetMsgHandler set up!" );
        }
        else
        {
            SetFailState( "Failed to get CNetChan::GetMsgHandler offset." );
        }
    }

    /*
        CNetChan::GetTimeSinceLastReceived
    */
    {
        StartPrepSDKCall( SDKCall_Raw );
        PrepSDKCall_SetFromConf( stac_gamedata, SDKConf_Virtual, "CNetChan::GetTimeSinceLastReceived" );
        PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
        SDKCall_GetTimeSinceLastReceived = EndPrepSDKCall();
        if ( SDKCall_GetTimeSinceLastReceived != INVALID_HANDLE )
        {
            PrintToServer( "CNetChan::GetTimeSinceLastReceived set up!" );
        }
        else
        {
            SetFailState( "Failed to get CNetChan::GetTimeSinceLastReceived offset." );
        }
    }

    // ENTPROP OFFSETS

    /* ent flags */
    Offset_m_fFlags = FindSendPropInfo("CTFPlayer", "m_fFlags");

    if ( Offset_m_fFlags == -1 )
    {
        SetFailState( "Failed to get CTFPlayer::m_fFlags offset." );
    }
}

public MRESReturn Detour_CBasePlayer__ProcessUsercmds(int entity, DHookParam hParams)
{
    // Could this ever throw? We may one day find out...
    if (IsFakeClient(entity))
    {
        return MRES_Ignored;
    }

    if (signonStateFor[entity] <= SIGNONSTATE_SPAWN)
    {
        return MRES_Supercede;
    }
    return MRES_Ignored;
}


public MRESReturn Detour_CNetChan__ProcessPacket(Address pThis, DHookParam hParams)
{
    // Get our client idx and iclient ptr
    Address icl_ptr;
    int cl;
    if (!GetClientFromNetChan(pThis, icl_ptr, cl) || !icl_ptr || cl <= 0 )
    {
        StacLog("bunk addr in procpacket dtor");
        return MRES_Ignored;
    }

    // TODO: do this in a SetSignonState detour?
    // ^ no, would break on lateload
    int signonState     = GetSignonState(icl_ptr);
    signonStateFor[cl]  = signonState;

    timeSinceLastRecvFor[cl] = SDKCall(SDKCall_GetTimeSinceLastReceived, pThis);

    return MRES_Ignored;
}

bool GetClientFromNetChan(Address pThis, Address& IClient, int& client)
{
    IClient = Address_Null;
    client  = -1;
    // sanity check
    if (!pThis)
    {
        StacLog("null pThis??");
        return false;
    }

    IClient = SDKCall( SDKCall_GetMsgHandler, pThis );
    // Clients will be null when connecting and disconnecting
    if (!IClient)
    {
        StacLog("null iclient??");
        return false;
    }

    // Client's ent index is always GetPlayerSlot() + 1
    client = SDKCall(SDKCall_GetPlayerSlot, IClient) + 1;

    return true;
}

Address DerefPtr(Address addr)
{
    return view_as<Address>( LoadFromAddress(addr, NumberType_Int32) );
}

int GetSignonState(Address IClient)
{
    if (!IClient)
    {
        return -1;
    }

    int signonState = view_as<int>( DerefPtr( (IClient - Offset_IClient_HACK) + Offset_SignonState ) );
    return signonState;
}



// const char* GetClientConVarValue( int clientIndex, const char *name );
public MRESReturn Detour_CVEngineServer__GetClientConVarValue(Address pThis, DHookReturn hReturn, DHookParam hParams)
{
    int cl = hParams.Get(1);
    char nameOfCvar[256];
    hParams.GetString(2, nameOfCvar, sizeof(nameOfCvar));
    if (!StrEqual(nameOfCvar, "name", .caseSensitive=true))
    {
        return MRES_Ignored;
    }

    // Invalid client, do not care
    if (!IsValidClient(cl))
    {
        return MRES_Ignored;
    }

    // lol
    char name[(MAX_NAME_LENGTH*2)+1];
    // sv.GetClient( clientIndex - 1 )->GetUserSetting( name );
    GetClientName(cl, name, sizeof(name));

    int newlines;
    int returns;
    int rtl;
    int ltr;

    // todo: implement C style iscntrl
    newlines    = ReplaceString(name, sizeof(name), "\n",           "");
    returns     = ReplaceString(name, sizeof(name), "\r",           "");
    rtl         = ReplaceString(name, sizeof(name), "\xE2\x80\x8F", "");
    ltr         = ReplaceString(name, sizeof(name), "\xE2\x80\x8E", "");

    // We didn't replace anything. We don't care.
    if ( newlines == 0 && returns == 0 && rtl == 0 && ltr == 0 )
    {
        return MRES_Ignored;
    }
    hReturn.SetString(name);

    char namemsg[512];
    Format
    (
        namemsg,
        sizeof(namemsg),
        "Client had %i newline chars, %i return chars, %i right2left chars, and %i left2right chars in their name",
        newlines,
        returns,
        rtl,
        ltr
    );

    int userid = GetClientUserId(cl);
    DataPack pack = new DataPack();
    pack.Reset(.clear=true);
    pack.WriteCell(userid);
    pack.WriteString(namemsg);
    pack.Reset(.clear=false);
    CreateTimer(1.0, Timer_SendStacNameNotif, pack);


    CreateTimer(2.0, BanName, userid);
    return MRES_Supercede;
}

Action Timer_SendStacNameNotif(Handle timer, DataPack pack)
{
    // already at the beginning of the pack...
    // pack.Reset(.clear=false);
    int userid = pack.ReadCell();
    char namemsg[512];
    pack.ReadString(namemsg, sizeof(namemsg));
    pack.Reset(.clear=true);
    delete pack;

    int cl = GetClientOfUserId(userid);
    if (!IsValidClient(cl))
    {
        return Plugin_Continue;
    }
    StacLog(namemsg);
    StacNotify(userid, namemsg, 1);

    return Plugin_Continue;
}