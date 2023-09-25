#pragma semicolon 1
#pragma newdecls required

/*
	Jay's Backtrack Patch
	Copyright (C) 2021 J_Tanzanite

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#include <sourcemod>
#include <sdktools_entoutput>


#define CVAR_ENABLE 	0
#define CVAR_TOLERANCE 	1
#define CVAR_MAX 		2


int backtrack_ticks = 0;
int prev_tickcount[TFMAXPLAYERS + 1];
int diff_tickcount[TFMAXPLAYERS + 1];
float time_timeout[TFMAXPLAYERS + 1];
float time_teleport[TFMAXPLAYERS + 1];

Handle hcvar[CVAR_MAX];
int icvar[CVAR_MAX];



void OnPluginStart_jaypatch()
{
	char gamefolder[16];

	GetGameFolderName(gamefolder, sizeof(gamefolder));

	if (StrEqual(gamefolder, "tf", false))
		HookEvent("player_teleported", event_teleported, EventHookMode_Post);

	HookEvent("player_spawn", event_teleported, EventHookMode_Post);

	HookEntityOutput("trigger_teleport", "OnEndTouch", map_teleport);

	hcvar[CVAR_ENABLE] = CreateConVar("jay_backtrack_enable", "1",
		"Enable Jay's Backtracking patch.",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	hcvar[CVAR_TOLERANCE] = CreateConVar("jay_backtrack_tolerance", "0",
		"Tolerance for tickcount changes.\n0 = Tickcount must increment.\nN+ = Tickcount can be off by N ticks (Don't go higher than 2).",
		FCVAR_PROTECTED, true, 0.0, true, 3.0);

	for (int i = 0; i < CVAR_MAX; i++) {
		icvar[i] = GetConVarInt(hcvar[i]);

		HookConVarChange(hcvar[i], cvar_change);
	}

	backtrack_ticks = time_to_ticks(0.2);
}

void cvar_change(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (view_as<Handle>(convar) == hcvar[CVAR_ENABLE]) {
		icvar[CVAR_ENABLE] = StringToInt(newValue, 10);
	}
	else {
		icvar[CVAR_TOLERANCE] = StringToInt(newValue, 10);
	}
}

Action event_teleported(Event event, const char[] name, bool dontBroadcast)
{
	int client;

	client = GetClientOfUserId(GetEventInt(event, "userid", -1));

	if (is_player_valid(client))
		time_teleport[client] = GetGameTime();

	return Plugin_Continue;
}

void map_teleport(const char[] output, int caller, int activator, float delay)
{
	if (!is_player_valid(activator) || IsFakeClient(activator))
		return;

	time_teleport[activator] = GetGameTime();
}

void OnClientPutInServer_jaypatch(int client)
{
	prev_tickcount[client] = 0;
	diff_tickcount[client] = 0;
	time_timeout[client] = 0.0;
	time_teleport[client] = 0.0;
}

stock Action OnPlayerRunCmd_jaypatch(int client, int& buttons, int& impulse,
				float vel[3], float angles[3], int& weapon,
				int& subtype, int& cmdnum, int& tickcount,
				int& seed, int mouse[2])
{
	// Ignore invalid players and bots.
	if (!is_player_valid(client) || IsFakeClient(client))
		return Plugin_Continue;

	// Store the tickcount (sets the prev_tickcount)
	// 	before we modify it.
	// We also need to store this even if the patch is disabled,
	// 	in case it gets enabled mid-game.
	store_tickcount(client, tickcount);

	// Patch is disabled.
	if (!icvar[CVAR_ENABLE])
		return Plugin_Continue;

	tickcount = correct_tickcount(client, tickcount);
	return Plugin_Continue;
}

// Store the tickcount of the players.
// Note: Using a buffer as we are modifying the tickcount
// 	and we need to buffer it due to how
// 	we are storing before patching.
void store_tickcount(int client, int tickcount)
{
	static int tmp[TFMAXPLAYERS + 1];

	prev_tickcount[client] = tmp[client];
	tmp[client] = tickcount;
}

int correct_tickcount(int client, int tickcount)
{
	// Player recently teleported, don't patch.
	if (time_teleport[client] + 2.0 > GetGameTime())
		return tickcount;

	// Tickcount went beyond the tolerance set, and the
	// 	player isn't currently set in a timeout.
	if (!valid_tickcount(client, tickcount) && !in_timeout(client))
		set_in_timeout(client);

	if (in_timeout(client))
		return simulate_tickcount(client);

	return tickcount;
}

void set_in_timeout(int client)
{
	int ping;
	int tick;

	// Set the client in a tickcount timeout for 1~ second (sv_maxunlag).
	time_timeout[client] = GetGameTime() + 1.1;

	// Ping in ticks.
	ping = RoundToNearest(GetClientAvgLatency(client, NetFlow_Outgoing) / GetTickInterval());

	// This is the estimated tickcount the player
	// 	should have had based on their ping.
	// Note: I say "should", but it varies due to packet chocking,
	// 	network variability etc.
	// But this is the average tick they should have.
	tick = GetGameTickCount() - ping;

	// Difference between what they had before the sudden illegal change
	// 	and what they should have had.
	// Adding 1 because this is the previous tick, not the current.
	diff_tickcount[client] = (prev_tickcount[client] - tick) + 1;

	// Clamp the value, because floating point precision and
	// 	network variability.
	if (diff_tickcount[client] > backtrack_ticks - 3)
		diff_tickcount[client] = backtrack_ticks - 3;
	else if (diff_tickcount[client] < ((backtrack_ticks * -1) + 3))
		diff_tickcount[client] = (backtrack_ticks * -1) + 3;

}

// Simulate the players tickcount as if it incremented normally
// 	before the sudden change over the tolerance set.
int simulate_tickcount(int client)
{
	int ping;
	int tick;

	ping = RoundToNearest(GetClientAvgLatency(client, NetFlow_Outgoing) / GetTickInterval());
	tick = diff_tickcount[client] + (GetGameTickCount() - ping);

	// Never return higher than server tickcount.
	return ((tick > GetGameTickCount()) ? GetGameTickCount() : tick);
}

bool in_timeout(int client)
{
	return (GetGameTime() < time_timeout[client]);
}

int time_to_ticks(float time)
{
	return RoundToNearest(time / GetTickInterval());
}

// Returns if a tickcount is within the tolerance set.
bool valid_tickcount(int client, int tickcount)
{
	return (intabs((prev_tickcount[client] + 1) - tickcount) <= icvar[CVAR_TOLERANCE]);
}

int intabs(int n)
{
	return ((n < 0) ? n * -1 : n);
}

bool is_player_valid(int client)
{
	return (client >= 1 && client <= MaxClients
		&& IsClientConnected(client) && IsClientInGame(client));
}
