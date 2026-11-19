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
