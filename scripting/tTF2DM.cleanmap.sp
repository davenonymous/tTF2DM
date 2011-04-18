#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>

// Plugin Version
#define VERSION "2.0.1"

// Handles
new Handle:g_hCvarEnable 	= INVALID_HANDLE;

new bool:g_bEnable;

public Plugin:myinfo =
{
	name = "tTF2DM, Cleanmap",
	author = "Thrawn",
	description = "Disables lockers, control points etc",
	version = VERSION,
	url = "http://forums.alliedmods.net/member.php?u=51683"
};

public OnPluginStart()
{
	CreateConVar("sm_ttf2dm_cleanmap_version", VERSION, "Version of Force Timelimit", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	g_hCvarEnable = CreateConVar("sm_ttf2dm_cleanmap_enable", "1", "- enables/disables the plugin", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvarEnable, Cvar_Changed);

	HookEvent("teamplay_round_start", OnRoundStart);
	HookEvent("teamplay_restart_round", OnRoundStart);

	AutoExecConfig(true, "plugin.tTF2DM.cleanmap");
}

public OnConfigsExecuted() {
	g_bEnable = GetConVarBool(g_hCvarEnable);
}

public Cvar_Changed(Handle:convar, const String:oldValue[], const String:newValue[]) {
	if(StrEqual(oldValue, "1") && StrEqual(newValue, "0")) {
		//Disabled, so enable stuff again
		DisableGameplayEntities(false);
	}

	if(StrEqual(oldValue, "0") && StrEqual(newValue, "1")) {
		//Enabled, so disble stuff again
		DisableGameplayEntities(true);
	}

	OnConfigsExecuted();
}

public Action:OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	CreateTimer(2.0, Timer_RemoveLockersAndSpawns);
}

public Action:Timer_RemoveLockersAndSpawns(Handle:timer, any:client) {
	DisableGameplayEntities(g_bEnable);
}

DisableGameplayEntities(bool:bState) {
	decl String:sState[16];
	if(bState)Format(sState, sizeof(sState), "Disable");
	else Format(sState, sizeof(sState), "Enable");

	new ent = MaxClients+1;
	while((ent = FindEntityByClassname(ent, "func_regenerate"))!=-1) {
		if(IsValidEdict(ent))
			AcceptEntityInput(ent, sState);
	}

	ent = MaxClients+1;
	while((ent = FindEntityByClassname(ent, "team_control_point_master"))!=-1) {
		if(IsValidEdict(ent))
			AcceptEntityInput(ent, sState);
	}

	ent = MaxClients+1;
	while((ent = FindEntityByClassname(ent, "team_control_point"))!=-1) {
		if(IsValidEdict(ent))
			AcceptEntityInput(ent, sState);
	}

	ent = MaxClients+1;
	while((ent = FindEntityByClassname(ent, "trigger_capture_area"))!=-1) {
		if(IsValidEdict(ent))
			AcceptEntityInput(ent, sState);
	}

	ent = FindEntityByClassname(-1, "team_round_timer");
	if(ent != -1 && IsValidEdict(ent)) {
		SetVariantBool(bState);
		AcceptEntityInput(ent, "ShowInHUD");

		if(bState) {
			AcceptEntityInput(ent, "Pause");
		} else {
			AcceptEntityInput(ent, "Resume");
		}
	}
}

