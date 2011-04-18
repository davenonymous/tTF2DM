#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>

// Plugin Version
#define VERSION "2.0.1"
#define TEAM_RED 2
#define TEAM_BLUE 3

// Handles
new Handle:g_hCvarEnable 	= INVALID_HANDLE;
new Handle:g_hCvarStartTime	= INVALID_HANDLE;
new Handle:g_hCvarPanic = INVALID_HANDLE;

new bool:g_bPanic;
new bool:g_bEnable;
new bool:g_bIsOn;
new g_iStartTime;

new g_iScoreBlue = 0;
new g_iScoreRed = 0;

new g_iScores[MAXPLAYERS+1][2];
new g_iCount = 0;

public Plugin:myinfo =
{
	name = "tTF2DM, Roundend",
	author = "Thrawn",
	description = "Ends each round nicely",
	version = VERSION,
	url = "http://forums.alliedmods.net/member.php?u=51683"
};

public OnPluginStart()
{
	CreateConVar("sm_ttf2dm_roundend_version", VERSION, "Ends each round nicely", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	g_hCvarEnable = CreateConVar("sm_ttf2dm_roundend_enable", "1", "- enables/disables the plugin", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hCvarPanic = CreateConVar("sm_ttf2dm_roundend_panic", "1", "- enables/disables panic for losing players", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hCvarStartTime = CreateConVar("sm_ttf2dm_roundend_time", "10", "Time before mapend to show winpanel", FCVAR_PLUGIN, true, 5.0, true, 30.0);

	HookEvent("teamplay_round_start", OnRoundStart);
	HookEvent("teamplay_restart_round", OnRoundStart);
	HookEvent("player_spawn", OnPlayerSpawn);

	AutoExecConfig(true, "plugin.tTF2DM.roundend");
}

public OnConfigsExecuted() {
	g_bPanic = GetConVarBool(g_hCvarPanic);
	g_bEnable = GetConVarBool(g_hCvarEnable);
	g_iStartTime = GetConVarInt(g_hCvarStartTime);
}

public OnMapStart() {
	g_bIsOn = false;

}

public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	if(g_bIsOn && g_bEnable) {
		new client = GetClientOfUserId(GetEventInt(event, "userid"));

		if(client == g_iScores[0][0] || client == g_iScores[1][0] || client == g_iScores[2][0]) {
			//Winner
			TF2_SetPlayerPowerPlay(client, true);
		} else {
			//Loser
			TF2_StunPlayer(client, float(g_iStartTime), 0.6, TF_STUNFLAGS_LOSERSTATE);
		}
	}
}

public Action:OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	CreateTimer(1.0, CheckTime, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action:CheckTime(Handle:timer, any:ignore)
{
	new iTimeLeft;
	GetMapTimeLeft(iTimeLeft);

	if(iTimeLeft < g_iStartTime && g_bEnable && !g_bIsOn) {
		g_bIsOn = true;

		GetWinners();
		ShowArenaWinPanel();
		if(g_bPanic) {
			WinEffects();
		}
	}

	if(iTimeLeft == 1 && g_bIsOn && g_bEnable) {
		EndGame();
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

stock WinEffects() {
	for(new client = 1; client <= MaxClients; client++) {
		if(IsClientInGame(client) && IsPlayerAlive(client)) {
			if(client == g_iScores[0][0] || client == g_iScores[1][0] || client == g_iScores[2][0]) {
				//Winner
				TF2_SetPlayerPowerPlay(client, true);
			} else {
				//Loser
				TF2_StunPlayer(client, float(g_iStartTime), 0.6, TF_STUNFLAGS_LOSERSTATE);
			}
		}
	}
}

stock ShowArenaWinPanel() {
	new iWinningTeam = g_iScoreRed > g_iScoreBlue ? TEAM_RED : TEAM_BLUE;
	//LogMessage("Showing arena win panel!");
	new Handle:event = CreateEvent("teamplay_win_panel");

	SetEventInt(event,"blue_score_prev",g_iScoreBlue);
	SetEventInt(event,"red_score_prev",g_iScoreRed);
	SetEventInt(event,"blue_score",g_iScoreBlue);
	SetEventInt(event,"red_score",g_iScoreRed);

	SetEventInt(event,"winreason",0);
	SetEventInt(event,"round_complete",1);

	SetEventInt(event,"winning_team", iWinningTeam);

	SetEventInt(event,"player_1", g_iScores[0][0]);
	SetEventInt(event,"player_1_points", g_iScores[0][1]);
	SetEventInt(event,"player_2", g_iScores[1][0]);
	SetEventInt(event,"player_2_points", g_iScores[1][1]);
	SetEventInt(event,"player_3", g_iScores[2][0]);
	SetEventInt(event,"player_3_points", g_iScores[2][1]);

	FireEvent(event);
}

stock GetWinners() {
	ResetScores();

	for(new iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
		{
			new iTmpScore = TF2_GetPlayerResourceData(iClient, TFResource_TotalScore);
			g_iScores[g_iCount][1] = iTmpScore;
			g_iScores[g_iCount][0] = iClient;

			if(GetClientTeam(iClient) == TEAM_RED) {
				g_iScoreRed += iTmpScore;
			} else if(GetClientTeam(iClient) == TEAM_BLUE) {
				g_iScoreBlue += iTmpScore;
			}

			g_iCount++;
		}
	}

	SortCustom2D(g_iScores, g_iCount, SortScoreDesc);

	LogMessage("#1: %i - %N", g_iScores[0][1], g_iScores[0][0]);
	LogMessage("#2: %i - %N", g_iScores[1][1], g_iScores[1][0]);
	LogMessage("#3: %i - %N", g_iScores[2][1], g_iScores[2][0]);
}

stock ResetScores() {
	g_iCount = 0;
	g_iScoreRed = 0;
	g_iScoreBlue = 0;

	for(new iClient = 0; iClient < MaxClients; iClient++)
	{
		g_iScores[iClient][1] = 0;
		g_iScores[iClient][0] = 0;
	}
}

stock bool:EndGame() {
	new iGameEnd  = FindEntityByClassname(-1, "game_end");
	if (iGameEnd == -1 && (iGameEnd = CreateEntityByName("game_end")) == -1) {
		LogError("Unable to create entity \"game_end\"!");
		return false;
	}

	AcceptEntityInput(iGameEnd, "EndGame");
	return true;
}

public SortScoreDesc(x[], y[], array[][], Handle:data)      // this sorts everything in the info array descending
{
    if (x[1] > y[1])
        return -1;
    else if (x[1] < y[1])
        return 1;
    return 0;
}