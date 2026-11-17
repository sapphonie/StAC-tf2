#if defined _stac_included
    #endinput
#endif
#define _stac_included

// Why StAC is about to ban a client.
// Only extend this list, do not sort, remove or swap entries.
enum StACBanReason
{
    StACBan_Bhop = 0,           // too many consecutive tick perfect bhops
    StACBan_FakeAngles,         // eye angles outside of what a client can legitimately send
    StACBan_CmdnumSpikes,       // cmdnum spikes (nospread etc)
    StACBan_PSilent,            // silent aim / norecoil
    StACBan_Aimsnap,            // aimsnaps
    StACBan_Triggerbot,         // triggerbot
    StACBan_InvalidUsercmd,     // invalid usercmd data
    StACBan_NewlineInChat,      // newline characters in a chat message
    StACBan_IllegalName,        // illegal characters in the client's name
    StACBan_Playerperf,         // playerperf command (seed prediction / crit hack)
    StACBan_BogusAchievement,   // earned an achievement that does not exist
    StACBan_OOBCvar,            // out of bounds value for a client cvar/netvar
    StACBan_CheatCvar           // known cheat cvar/concommand exists on the client
};

/**
 * Called when StAC is about to ban a client, before the ban is logged or executed.
 *
 * A cancelled ban does not reset the client's detections, so this is called again for each
 * further detection of the same cheat on a client.
 *
 * @param client        Client index.
 * @param reason        Why the client is about to be banned. See the StACBanReason enum.
 * @param reasonText    The ban reason as string, in the server's language.
 * @param pubReasonText The message about the ban for all players in chat, in the server's language.
 * @return              Plugin_Handled or Plugin_Stop to cancel the ban, Plugin_Continue to allow it.
 */
forward Action StAC_OnBan(int client, StACBanReason reason, const char[] reasonText, const char[] pubReasonText);
