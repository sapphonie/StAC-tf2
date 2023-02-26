
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
    /*
        Memory offsets
    */
    {
        // offset from client's signon state, offset from CBaseClient::this (?)
        Offset_SignonState  = view_as<Address>( GameConfGetOffset(stac_gamedata, "Offset_SignonState") );
        // Hack, see gamedata
        Offset_IClient_HACK = view_as<Address>( GameConfGetOffset(stac_gamedata, "Offset_IClient_HACK") );
    }

    /*
        ProcessPacket - for getting client's signonstate
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
        GetMsgHandler - for converting CNetChan::this* to a IClient*
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
        GetPlayerSlot - for converting IClient* to ent idx
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
        // LogMessage("sos = %i", signonStateFor[entity]);
        return MRES_Supercede;
    }
    return MRES_Ignored;
}

public MRESReturn Detour_CNetChan__ProcessPacket(Address pThis, DHookParam hParams)
{
    // LogMessage("this = %x", pThis);
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



    // LogMessage("sos = %i", signonState);
    return MRES_Ignored;
}

/*
public void OnClientSpeaking(int client)
{
    if (signonStateFor[client] <= SIGNONSTATE_SPAWN)
    {
        // SetClientListeningFlags(target, VOICE_MUTED);
    }
}
*/

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
