#if defined _stac_included
    #endinput
#endif
#define _stac_included

// What StAC detected on a client, and why it is about to ban a client.
// Only extend this list, do not sort, remove or swap entries.
enum StAC_Detection
{
    StAC_Detection_None = -1,          // not a detection
    StAC_Detection_Bhop = 0,           // too many consecutive tick perfect bhops
    StAC_Detection_FakeAngles,         // eye angles outside of what a client can legitimately send
    StAC_Detection_CmdnumSpikes,       // cmdnum spikes (nospread etc)
    StAC_Detection_PSilent,            // silent aim / norecoil
    StAC_Detection_Aimsnap,            // aimsnaps
    StAC_Detection_Triggerbot,         // triggerbot
    StAC_Detection_InvalidUsercmd,     // invalid usercmd data
    StAC_Detection_NewlineInChat,      // newline characters in a chat message
    StAC_Detection_IllegalName,        // illegal characters in the client's name
    StAC_Detection_Playerperf,         // playerperf command (seed prediction / crit hack)
    StAC_Detection_BogusAchievement,   // earned an achievement that does not exist
    StAC_Detection_OOBCvar,            // out of bounds value for a client cvar/netvar
    StAC_Detection_CheatCvar           // known cheat cvar/concommand exists on the client
};

// What kind of notification StAC sends.
// Only extend this list, do not sort, remove or swap entries.
enum StAC_NotificationType
{
    StAC_Notification_Detection = 0,   // a detection on a client, with the number of detections so far
    StAC_Notification_ClientMessage,   // a message about a client that is not a detection
    StAC_Notification_ServerMessage,   // a message without a client
    StAC_Notification_Ban,             // a client is being banned
    StAC_Notification_BanCancelled     // another plugin cancelled a client's ban in StAC_OnBan
};

/**
 * Called when StAC is about to ban a client, before the ban is logged or executed.
 *
 * A cancelled ban does not reset the client's detections, so this is called again for each
 * further detection of the same cheat on a client.
 *
 * @param client        Client index.
 * @param detection     Why the client is about to be banned. See the StAC_Detection enum.
 * @param reasonText    The ban reason as string, in the server's language.
 * @param pubReasonText The message about the ban for all players in chat, in the server's language.
 * @return              Plugin_Handled or Plugin_Stop to cancel the ban, Plugin_Continue to allow it.
 */
forward Action StAC_OnBan(int client, StAC_Detection detection, const char[] reasonText, const char[] pubReasonText);

/**
 * Called for everything StAC notifies about, which is what it also sends to Discord: detections
 * (not every single one, most checks notify on the first and then every fifth detection), messages
 * about a client, messages without a client, bans and bans cancelled in StAC_OnBan.
 *
 * Not called for a client whose ban is already queued.
 *
 * @param type          What kind of notification this is. See the StAC_NotificationType enum.
 * @param client        Client index, or 0 for StAC_Notification_ServerMessage.
 * @param detection     What was detected or what the ban is for, or StAC_Detection_None for messages
 *                      and for detections without an entry in the StAC_Detection enum.
 * @param detections    Number of detections so far for StAC_Notification_Detection, otherwise 0.
 * @param text          The notification as string.
 */
forward void StAC_OnNotify(StAC_NotificationType type, int client, StAC_Detection detection, int detections, const char[] text);

/**
 * What StAC knows about a client: the history of their last user commands, their network values
 * and their detections.
 *
 * The object is the client and holds nothing itself: every call reads what StAC has right now.
 * Read it inside StAC_OnNotify or StAC_OnBan to get the data that belongs to that notification.
 *
 * StAC only has data for real clients that are in game. Without data, also when the client has
 * left since StAC_GetClientData, every call gives zero values: 0, 0.0, false or an empty string.
 */
methodmap StAC_ClientData
{
    // The client index this data belongs to, or 0 when StAC_GetClientData returned false.
    property int Client
    {
        public get() { return view_as<int>(this); }
    }

    /**
     * The view angles of one of the client's last 5 user commands.
     *
     * @param index         0 for the newest user command, up to 4 for the oldest.
     * @param angles        Pitch, yaw and roll.
     * @error               Invalid index.
     */
    public native void GetAngles(int index, float angles[3]);

    /**
     * One of the client's last 2 eye positions.
     *
     * @param index         0 for the newest eye position, 1 for the one before.
     * @param position      The eye position.
     * @error               Invalid index.
     */
    public native void GetEyePosition(int index, float position[3]);

    /**
     * The command number of one of the client's last 5 user commands.
     *
     * @param index         0 for the newest user command, up to 4 for the oldest.
     * @error               Invalid index.
     */
    public native int GetCmdNum(int index);

    /**
     * The tick count of one of the client's last 5 user commands.
     *
     * @param index         0 for the newest user command, up to 4 for the oldest.
     * @error               Invalid index.
     */
    public native int GetTickCount(int index);

    /**
     * The buttons (IN_* bits) of one of the client's last 5 user commands.
     *
     * @param index         0 for the newest user command, up to 4 for the oldest.
     * @error               Invalid index.
     */
    public native int GetButtons(int index);

    /**
     * The mouse movement of the client's newest user command.
     *
     * @param mouse         Movement in x and y.
     */
    public native void GetMouse(int mouse[2]);

    /**
     * The SteamID StAC cached when the client connected, which it still has when Steam is down.
     *
     * @param buffer        Buffer for the SteamID, empty when StAC has none.
     * @param maxlen        Size of the buffer.
     */
    public native void GetSteamID(char[] buffer, int maxlen);

    /**
     * How many detections of a kind the client has so far.
     *
     * @param detection     The kind of detection.
     * @return              Number of detections, 0 for kinds StAC does not count.
     */
    public native int GetDetections(StAC_Detection detection);

    // The client's mouse sensitivity, 0.0 until StAC has asked for it.
    property float Sensitivity
    {
        public native get();
    }

    // Latency in milliseconds.
    property float Ping
    {
        public native get();
    }

    // Average latency in milliseconds. StAC takes a Ping far from it as lag.
    property float AveragePing
    {
        public native get();
    }

    // Average incoming packet loss in percent.
    property float Loss
    {
        public native get();
    }

    // Average choke in both directions in percent.
    property float Choke
    {
        public native get();
    }

    // Average incoming choke in percent.
    property float InChoke
    {
        public native get();
    }

    // Average outgoing choke in percent.
    property float OutChoke
    {
        public native get();
    }

    // Average data rate in both directions in kbit/s.
    property float Rate
    {
        public native get();
    }

    // Average packets per second in both directions.
    property float PacketsPerSecond
    {
        public native get();
    }

    // Approximately how many user commands the client sent in the last second.
    property int CommandsPerSecond
    {
        public native get();
    }

    // Whether StAC considers the client to be lagging, which holds some detections back.
    property bool IsLagging
    {
        public native get();
    }

    // Whether the command numbers of the client's last 5 user commands follow each other.
    property bool HasSequentialCmdnums
    {
        public native get();
    }
}

/**
 * Gets what StAC knows about a client.
 *
 * @param client        Client index.
 * @param data          The client's data.
 * @return              True when StAC has data for the client, false for an invalid client index,
 *                      a client that is not in game and a bot.
 */
native bool StAC_GetClientData(int client, StAC_ClientData &data);

/**
 * Gets the version of the running StAC.
 *
 * @param buffer        Buffer for the version, for example "6.3.13".
 * @param maxlen        Size of the buffer.
 */
native void StAC_GetVersion(char[] buffer, int maxlen);

public SharedPlugin __pl_stac =
{
    name = "stac",
    file = "stac.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_stac_SetNTVOptional()
{
    MarkNativeAsOptional("StAC_GetVersion");
    MarkNativeAsOptional("StAC_GetClientData");
    MarkNativeAsOptional("StAC_ClientData.GetAngles");
    MarkNativeAsOptional("StAC_ClientData.GetEyePosition");
    MarkNativeAsOptional("StAC_ClientData.GetCmdNum");
    MarkNativeAsOptional("StAC_ClientData.GetTickCount");
    MarkNativeAsOptional("StAC_ClientData.GetButtons");
    MarkNativeAsOptional("StAC_ClientData.GetMouse");
    MarkNativeAsOptional("StAC_ClientData.GetSteamID");
    MarkNativeAsOptional("StAC_ClientData.GetDetections");
    MarkNativeAsOptional("StAC_ClientData.Sensitivity.get");
    MarkNativeAsOptional("StAC_ClientData.Ping.get");
    MarkNativeAsOptional("StAC_ClientData.AveragePing.get");
    MarkNativeAsOptional("StAC_ClientData.Loss.get");
    MarkNativeAsOptional("StAC_ClientData.Choke.get");
    MarkNativeAsOptional("StAC_ClientData.InChoke.get");
    MarkNativeAsOptional("StAC_ClientData.OutChoke.get");
    MarkNativeAsOptional("StAC_ClientData.Rate.get");
    MarkNativeAsOptional("StAC_ClientData.PacketsPerSecond.get");
    MarkNativeAsOptional("StAC_ClientData.CommandsPerSecond.get");
    MarkNativeAsOptional("StAC_ClientData.IsLagging.get");
    MarkNativeAsOptional("StAC_ClientData.HasSequentialCmdnums.get");
}
#endif
