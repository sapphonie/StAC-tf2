
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

    /*
        GetTimeSinceLastReceived
    */
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
/*

        GetSeqNumber

    StartPrepSDKCall( SDKCall_Raw );
    PrepSDKCall_SetFromConf( stac_gamedata, SDKConf_Virtual, "CNetChan::GetSequenceNr" );
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    SDKCall_GetSeqNum = EndPrepSDKCall();
    if ( SDKCall_GetSeqNum != INVALID_HANDLE )
    {
        PrintToServer( "CNetChan::GetSequenceNr set up!" );
    }
    else
    {
        SetFailState( "Failed to get CNetChan::GetSequenceNr offset." );
    }

        GetTime

    StartPrepSDKCall( SDKCall_Raw );
    PrepSDKCall_SetFromConf( stac_gamedata, SDKConf_Virtual, "CNetChan::GetTime" );
    PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
    SDKCall_GetTime = EndPrepSDKCall();
    if ( SDKCall_GetTime != INVALID_HANDLE )
    {
        PrintToServer( "CNetChan::GetTime set up!" );
    }
    else
    {
        SetFailState( "Failed to get CNetChan::GetTime offset." );
    }


        GetDropNumber

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(stac_gamedata, SDKConf_Virtual, "CNetChan::GetDropNumber");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    SDKCall_GetDropNumber = EndPrepSDKCall();
    if (SDKCall_GetDropNumber != INVALID_HANDLE)
    {
        PrintToServer("CNetChan::GetDropNumber set up!");
    }
    else
    {
        SetFailState("Failed to get CNetChan::GetDropNumber offset.");
    }
*/
    Offset_m_fFlags     = FindSendPropInfo("CTFPlayer", "m_fFlags");

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
        // LogMessage("sos = %i", signonStateFor[entity]);
        return MRES_Supercede;
    }
    return MRES_Ignored;
}


public MRESReturn Detour_CNetChan__ProcessPacket(Address pThis, DHookParam hParams)
{
    //LogMessage("this = %x", pThis);

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


    // int     CLI_seqNrFor             [TFMAXPLAYERS+1][5];
    // int     SRV_seqNrFor             [TFMAXPLAYERS+1][5];
    // int     dropNumFor               [TFMAXPLAYERS+1][5];
    // float   packetTimeFor            [TFMAXPLAYERS+1][5];
    // float   timeSinceLastRecvFor     [TFMAXPLAYERS+1][5];


    /*
    for (int i = 4; i > 0; --i)
    {
        CLI_seqNrFor[cl][i] = CLI_seqNrFor[cl][i-1];
    }
    CLI_seqNrFor[cl][0] = SDKCall(SDKCall_GetSeqNum, pThis, view_as<int>(NetFlow_Outgoing));

    for (int i = 4; i > 0; --i)
    {
        SRV_seqNrFor[cl][i] = SRV_seqNrFor[cl][i-1];
    }
    SRV_seqNrFor[cl][0] = SDKCall(SDKCall_GetSeqNum, pThis, view_as<int>(NetFlow_Incoming));

    for (int i = 4; i > 0; --i)
    {
        dropNumFor[cl][i] = dropNumFor[cl][i-1];
    }
    dropNumFor[cl][0] = SDKCall(SDKCall_GetDropNumber, pThis)

    for (int i = 4; i > 0; --i)
    {
        packetTimeFor[cl][i] = packetTimeFor[cl][i-1];
    }
    packetTimeFor[cl][0] = SDKCall(SDKCall_GetTime, pThis);
    */
    for (int i = 4; i > 0; --i)
    {
        timeSinceLastRecvFor[cl][i] = timeSinceLastRecvFor[cl][i-1];
    }
    timeSinceLastRecvFor[cl][0] = SDKCall(SDKCall_GetTimeSinceLastReceived, pThis);

    /*
    if ( CLI_seqNrFor[cl][0] > SRV_seqNrFor[cl][0])
    {
        //LogMessage("BAD");
    }


    if
    (
           SRV_seqNrFor[cl][0] > SRV_seqNrFor[cl][1]
        && SRV_seqNrFor[cl][1] > SRV_seqNrFor[cl][2]
        && SRV_seqNrFor[cl][2] > SRV_seqNrFor[cl][3]
        && SRV_seqNrFor[cl][3] > SRV_seqNrFor[cl][4]
    )
    {
        //LogMessage("%i %i %i %i %i", SRV_seqNrFor[cl][0], SRV_seqNrFor[cl][1], SRV_seqNrFor[cl][2], SRV_seqNrFor[cl][3], SRV_seqNrFor[cl][4]);

        //LogMessage("seq");
    }
    else
    {
        //LogMessage("%i %i %i %i %i", SRV_seqNrFor[cl][0], SRV_seqNrFor[cl][1], SRV_seqNrFor[cl][2], SRV_seqNrFor[cl][3], SRV_seqNrFor[cl][4]);
    }
    */
    //LogMessage("-> %i", dropNumFor[cl][0]);
    /*
    // client seq num
    int outSeq  = SDKCall(SDKCall_GetSeqNum, pThis, view_as<int>(NetFlow_Outgoing));
    // LogMessage("outSeq -> %i", outSeq);

    // server seq num
    int inSeq   = SDKCall(SDKCall_GetSeqNum, pThis, view_as<int>(NetFlow_Incoming));
    // LogMessage("inSeq -> %i", inSeq);


    seqNr[cl][4] = seqNr[cl][3];
    seqNr[cl][3] = seqNr[cl][2];
    seqNr[cl][2] = seqNr[cl][1];
    seqNr[cl][1] = seqNr[cl][0];
    seqNr[cl][0] = outSeq;
    */
    //
    // if (seqNr[cl][4] + 6 < outSeq)
    // {
    //     LogMessage("%i %i", seqNr[cl][4], outSeq);
    //     LogMessage("beh");
    // }


    // Packet size
    // int offset          = ( 13 * 4 );
    // Address netpacket   = DHookGetParamAddress( hParams, 1 );
    // int size = DerefPtr( netpacket + offset );
    //LogMessage("-> %x", netpacket);
    //LogMessage("-> %i", size);


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
