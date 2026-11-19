// Sends everything StAC notifies about (detections, client and server messages, bans) to Discord.
// Needs StAC and zipcore's Discord API plugin: https://forums.alliedmods.net/showthread.php?t=292663
// see the readme for more info:
// https://github.com/sapphonie/StAC-tf2/blob/master/README.md

#pragma semicolon 1
#pragma newdecls required

// For json
// if you have to make this any bigger there's probably an evil bug in json parsing code somewhere -sappho
#pragma dynamic 8192 * 8

#include <sourcemod>
// for the server's public ip
#include <SteamWorks>
// for the currently recording demo
#include <sourcetvmanager>
#include <json>
#include <stac>
#undef REQUIRE_PLUGIN
#include <discord>

#define PLUGIN_VERSION  "1.0.0"

public Plugin myinfo =
{
    name             =  "Steph's AntiCheat [StAC] - Discord",
    author           =  "https://sappho.io",
    description      =  "Sends StAC's detections and messages to Discord",
    version          =   PLUGIN_VERSION,
    url              =  "https://sappho.io"
}

// titles of the embeds, by StAC_NotificationType
char notifTitles[][] =
{
    "Client Detection",
    "Client Notification",
    "Server Message",
    "Client Ban",
    "Ban Cancelled"
};

// if our client is 0, it's a server message without a client
// if our detections are 0, it's a client message without a detection
// otherwise, it's a detection with a number of detections
public void StAC_OnNotify(StAC_NotificationType type, int client, StAC_Detection detection, int detections, const char[] text)
{
    if (GetFeatureStatus(FeatureType_Native, "Discord_SendMessage") != FeatureStatus_Available)
    {
        return;
    }

    // everything StAC knows about our client. without a client this has no data and is not read
    StAC_ClientData data;
    StAC_GetClientData(client, data);

    char hostIPAndPort[24];
    GetHostIPAndPort(hostIPAndPort, sizeof(hostIPAndPort));


    static char output[8192 * 2];
    output[0] = 0x0;

    // individual fields

    // empty fields for spacing
    JSON_Object spacerField = new JSON_Object();
    spacerField.SetString("name",   " ");
    spacerField.SetString("value",  " ");
    spacerField.SetBool  ("inline", false);

    JSON_Object spacerCpy1;
    if (client)
    {
        spacerCpy1 = spacerField.DeepCopy();
    }

    JSON_Object spacerCpy2 = spacerField.DeepCopy();
    JSON_Object spacerCpy3 = spacerField.DeepCopy();
    JSON_Object spacerCpy4 = spacerField.DeepCopy();
    JSON_Object spacerCpy5 = spacerField.DeepCopy();
    JSON_Object spacerCpy6;
    JSON_Object spacerCpy7;
    if (detections)
    {
        spacerCpy6 = spacerField.DeepCopy();
        spacerCpy7 = spacerField.DeepCopy();
    }

    // this isn't used anywhere we're just using it to copy off of
    json_cleanup_and_delete(spacerField);

    JSON_Object nameField;
    JSON_Object steamIDfield;
    if (client)
    {
        // playername
        char ClName[64];
        GetClientName(client, ClName, sizeof(ClName));
        Discord_EscapeString(ClName, sizeof(ClName));
        json_escape_string(ClName, sizeof(ClName));

        nameField = new JSON_Object();
        nameField.SetString("name", "Player");
        nameField.SetString("value", ClName);
        nameField.SetBool("inline", true);


        // steamid
        char cachedSteamID[MAX_AUTHID_LENGTH];
        data.GetSteamID(cachedSteamID, sizeof(cachedSteamID));
        // we technically store the url in this so it has to be bigger
        char steamid[96];
        // ok we store these on client connect & auth, this shouldn't be null
        if ( cachedSteamID[0] )
        {
            // make this a clickable link in discord
            Format(steamid, sizeof(steamid), "[%s](https://steamid.io/lookup/%s)", cachedSteamID, cachedSteamID);
        }
        // if it is, that means we lateloaded and the client was unauth'd.
        else
        {
            steamid = "N/A";
        }

        steamIDfield = new JSON_Object();
        steamIDfield.SetString("name", "SteamID");
        steamIDfield.SetString("value", steamid);
        steamIDfield.SetBool  ("inline", true);
    }


    // detection / notify fields
    JSON_Object detectOrMsgfield = new JSON_Object();
    if (!client)
    {
        detectOrMsgfield.SetString("name", "Message");
    }
    else if (!detections)
    {
        detectOrMsgfield.SetString("name", "Notification");
    }
    else
    {
        detectOrMsgfield.SetString("name", "Detection");
    }
    detectOrMsgfield.SetString("value", text);
    detectOrMsgfield.SetBool("inline", true);

    // number of detections

    JSON_Object detectNumfield;
    if (detections)
    {
        detectNumfield = new JSON_Object();
        detectNumfield.SetString("name", "Detection #");
        detectNumfield.SetInt("value", detections);
        detectNumfield.SetBool("inline", true);
    }


    // server hostname
    char hostname[256];
    GetConVarString(FindConVar("hostname"), hostname, sizeof(hostname));

    JSON_Object hostname_field = new JSON_Object();
    hostname_field.SetString("name", "Hostname");
    hostname_field.SetString("value", hostname);
    hostname_field.SetBool  ("inline", true);

    // server IP - steam:///connect ??
    JSON_Object serverip_field = new JSON_Object();
    serverip_field.SetString("name", "Server IP");
    serverip_field.SetString("value", hostIPAndPort);
    serverip_field.SetBool  ("inline", true);


    // STV
    char demoname[128];
    int demotick = GetDemoName(demoname, sizeof(demoname));


    JSON_Object demoname_field = new JSON_Object();
    demoname_field.SetString("name", "Demo name");
    demoname_field.SetString("value", demoname);
    demoname_field.SetBool  ("inline", true);


    JSON_Object demotick_field = new JSON_Object();
    demotick_field.SetString("name", "Demo tick");
    demotick_field.SetInt   ("value", demotick);
    demotick_field.SetBool  ("inline", true);

    float tickedTime = GetTickedTime();
    char tickedTimeStr[512];
    // 1 day
    if (tickedTime > 86400)
    {
        Format
        (
            tickedTimeStr,
            sizeof(tickedTimeStr),
            "%.2f minutes(!)\n\n\
            Source Engine has memory leaks\n\
            and suffers from \n\
            [floating point precision loss](https://www.youtube.com/watch?v=RdTJHVG_IdU)\n\
            after running for too long.\n\
            You should restart your server ASAP,\n\
            or it will become choppy,\n\
            and StAC may not work correctly!",
            tickedTime / 60.0
        );
    }
    else
    {
        Format
        (
            tickedTimeStr,
            sizeof(tickedTimeStr),
            "%.2f minutes",
            tickedTime / 60.0
        );
    }

    JSON_Object gametime_field = new JSON_Object();
    gametime_field.SetString("name", "Approx server uptime");
    gametime_field.SetString("value", tickedTimeStr);
    gametime_field.SetBool  ("inline", true);


    JSON_Object servertick_field = new JSON_Object();
    servertick_field.SetString("name", "Server tick");
    servertick_field.SetInt   ("value", GetGameTickCount());
    servertick_field.SetBool  ("inline", true);

    int unixTimestamp = GetTime();
    char discordTimestamp[512];

    Format
    (
        discordTimestamp,
        sizeof(discordTimestamp),
        "\
        <t:%i:T> on <t:%i:D>\n\
        <t:%i:R>\
        ",
        unixTimestamp,
        unixTimestamp,
        unixTimestamp
    );



    JSON_Object discordtimestamp_field = new JSON_Object();
    discordtimestamp_field.SetString("name", "Discord Timestamp");
    discordtimestamp_field.SetString("value", discordTimestamp);
    discordtimestamp_field.SetBool  ("inline", true);


    JSON_Object unixtimestamp_field = new JSON_Object();
    unixtimestamp_field.SetString("name", "Unix Timestamp");
    unixtimestamp_field.SetInt   ("value", unixTimestamp);
    unixtimestamp_field.SetBool  ("inline", true);



    JSON_Object viewangle_field;
    JSON_Object clpos_field;
    JSON_Object tickcount_field;
    JSON_Object cmdnum_field;
    JSON_Object buttons_field;
    JSON_Object netinfo_field;


    if (detections)
    {
        float angles[5][3];
        float eyepos[2][3];
        int cmdnums[5];
        int tickcounts[5];
        int buttons[5];
        for (int i = 0; i < sizeof(angles); i++)
        {
            data.GetAngles(i, angles[i]);
            cmdnums[i]      = data.GetCmdNum(i);
            tickcounts[i]   = data.GetTickCount(i);
            buttons[i]      = data.GetButtons(i);
        }
        for (int i = 0; i < sizeof(eyepos); i++)
        {
            data.GetEyePosition(i, eyepos[i]);
        }

        // VIEWANGLES
        char viewangleHistoryBuf[1024];
        Format
        (
            viewangleHistoryBuf,
            sizeof(viewangleHistoryBuf),
            "```\
                ==----pitch---yaw-----roll-----\n\
                0 | %7.2f %7.2f %7.2f\n\
                1 | %7.2f %7.2f %7.2f\n\
                2 | %7.2f %7.2f %7.2f\n\
                3 | %7.2f %7.2f %7.2f\n\
                4 | %7.2f %7.2f %7.2f\n\
            ```",

                // angles
                angles[0][0],
                angles[0][1],
                angles[0][2],

                angles[1][0],
                angles[1][1],
                angles[1][2],

                angles[2][0],
                angles[2][1],
                angles[2][2],

                angles[3][0],
                angles[3][1],
                angles[3][2],

                angles[4][0],
                angles[4][1],
                angles[4][2]
        );


        viewangle_field = new JSON_Object();
        viewangle_field.SetString("name", "viewangle history");
        viewangle_field.SetString("value", viewangleHistoryBuf);
        viewangle_field.SetBool  ("inline", false);


        // EYE POSITIONS
        char eyeposBuf[1024];
        Format
        (
            eyeposBuf,
            sizeof(eyeposBuf),

            "```\
            ==-----x--------y--------z---------\n\
            0 | %8.2f %8.2f %8.2f\n\
            1 | %8.2f %8.2f %8.2f\n\
            ```",

            // eye positions
            eyepos[0][0],
            eyepos[0][1],
            eyepos[0][2],
            eyepos[1][0],
            eyepos[1][1],
            eyepos[1][2]
        );

        clpos_field = new JSON_Object();
        clpos_field.SetString("name", "eye position history");
        clpos_field.SetString("value", eyeposBuf);
        clpos_field.SetBool  ("inline", false);

        // CMDNUMS
        char cmdnumBuf[1024];
        Format
        (
            cmdnumBuf,
            sizeof(cmdnumBuf),

            "[what's this?](https://github.com/VSES/SourceEngine2007/blob/43a5c90a5ada1e69ca044595383be67f40b33c61/se2007/game/client/in_main.cpp#L1008)\n```\
                0 | %i\n\
                1 | %i\n\
                2 | %i\n\
                3 | %i\n\
                4 | %i\n\
            ```",

            // cmdnum
            cmdnums[0],
            cmdnums[1],
            cmdnums[2],
            cmdnums[3],
            cmdnums[4]
        );

        cmdnum_field = new JSON_Object();
        cmdnum_field.SetString("name", "cmdnum history");
        cmdnum_field.SetString("value", cmdnumBuf);
        cmdnum_field.SetBool  ("inline", true);

        // TICKCOUNTS
        char tickcountBuf[1024];
        Format
        (
            tickcountBuf,
            sizeof(tickcountBuf),

            "[what's this?](https://github.com/VSES/SourceEngine2007/blob/43a5c90a5ada1e69ca044595383be67f40b33c61/se2007/game/client/in_main.cpp#L1009)\n```\
                0 | %i\n\
                1 | %i\n\
                2 | %i\n\
                3 | %i\n\
                4 | %i\n\
            ```",

            // tickcount
            tickcounts[0],
            tickcounts[1],
            tickcounts[2],
            tickcounts[3],
            tickcounts[4]
        );


        tickcount_field = new JSON_Object();
        tickcount_field.SetString("name", "tickcount history");
        tickcount_field.SetString("value", tickcountBuf);
        tickcount_field.SetBool  ("inline", true);

        // BUTTONS
        char buttonsBuf[1024];
        Format
        (
            buttonsBuf,
            sizeof(buttonsBuf),

            "[what's this?](https://sapphonie.github.io/flags.html)\n\
            ```\
                0 | %i\n\
                1 | %i\n\
                2 | %i\n\
                3 | %i\n\
                4 | %i\n\
            ```",

            // buttons
            buttons[0],
            buttons[1],
            buttons[2],
            buttons[3],
            buttons[4]
        );


        buttons_field = new JSON_Object();
        buttons_field.SetString("name", "buttons history");
        buttons_field.SetString("value", buttonsBuf);
        buttons_field.SetBool  ("inline", true);

        // NETWORK INFO
        char netinfoBuf[1024];
        Format
        (
            netinfoBuf,
            sizeof(netinfoBuf),

            "```\
                ping               | %7.2fms\n\
                loss               | %7.2f%%\n\
                inchoke            | %7.2f%%\n\
                outchoke           | %7.2f%%\n\
                totalchoke         | %7.2f%%\n\
                rate               | %7.2fkbps\n\
                approx packets/sec | %7.2f\n\
                approx usrcmds/sec | %7i\n\
            ```",

            // network
            data.Ping,
            data.Loss,
            data.InChoke,
            data.OutChoke,
            data.Choke,
            data.Rate,
            data.PacketsPerSecond,
            data.CommandsPerSecond
        );

        netinfo_field = new JSON_Object();
        netinfo_field.SetString("name", "network info");
        netinfo_field.SetString("value", netinfoBuf);
        netinfo_field.SetBool  ("inline", false);
    }


    // fields list
    JSON_Array fieldArray = new JSON_Array();
    if (client)
    {
        fieldArray.PushObject(nameField);
        fieldArray.PushObject(steamIDfield);
        fieldArray.PushObject(spacerCpy1);
    }
    fieldArray.PushObject(detectOrMsgfield);
    if (detections)
    {
        fieldArray.PushObject(detectNumfield);
    }
    fieldArray.PushObject(spacerCpy2);
    fieldArray.PushObject(hostname_field);
    fieldArray.PushObject(serverip_field);
    fieldArray.PushObject(spacerCpy3);
    fieldArray.PushObject(demoname_field);
    fieldArray.PushObject(demotick_field);
    fieldArray.PushObject(spacerCpy4);
    fieldArray.PushObject(gametime_field);
    fieldArray.PushObject(servertick_field);
    fieldArray.PushObject(spacerCpy5);
    fieldArray.PushObject(discordtimestamp_field);
    fieldArray.PushObject(unixtimestamp_field);
    if (detections)
    {
        fieldArray.PushObject(spacerCpy6);
        fieldArray.PushObject(viewangle_field);
        fieldArray.PushObject(clpos_field);
        fieldArray.PushObject(spacerCpy7);
        fieldArray.PushObject(cmdnum_field);
        fieldArray.PushObject(tickcount_field);
        fieldArray.PushObject(buttons_field);
        fieldArray.PushObject(netinfo_field);
    }


    // embeds header info
    JSON_Object embedsFields = new JSON_Object();

    embedsFields.SetObject("fields", fieldArray);
    char stacVersion[32];
    StAC_GetVersion(stacVersion, sizeof(stacVersion));
    char notifType[64];
    Format(notifType, sizeof(notifType), "StAC v%s %s", stacVersion, notifTitles[type]);

    static int color = 0xFF69B4;
    embedsFields.SetString  ("title",       notifType);
    embedsFields.SetInt     ("color",       color);

    JSON_Array finalArr = new JSON_Array();

    finalArr.PushObject(embedsFields);

    // root
    JSON_Object rootEmbeds = new JSON_Object();
    rootEmbeds.SetObject("embeds", finalArr);
    rootEmbeds.SetString("avatar_url", "https://i.imgur.com/RKRaLPl.png");
    rootEmbeds.Encode(output, sizeof(output));

    json_cleanup_and_delete(rootEmbeds);
    SendMessageToDiscord(output);
}

void SendMessageToDiscord(char[] message)
{
    static char webhook[8] = "stac";
    Discord_SendMessage(webhook, message);
}

// name of the currently recording demo, or N/A. returns the demo tick
int GetDemoName(char[] demoname, int maxlen)
{
    int demotick = SourceTV_GetRecordingTick();
    if (!SourceTV_GetDemoFileName(demoname, maxlen))
    {
        strcopy(demoname, maxlen, "N/A");
    }
    return demotick;
}

void GetHostIPAndPort(char[] hostIPAndPort, int maxlen)
{
    // get our host port
    char hostport[8];
    GetConVarString(FindConVar("hostport"), hostport, sizeof(hostport));

    int sw_ip[4];
    SteamWorks_GetPublicIP(sw_ip);
    Format(hostIPAndPort, maxlen, "%i.%i.%i.%i:%s", sw_ip[0], sw_ip[1], sw_ip[2], sw_ip[3], hostport);
}
