#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>

#define VERSION "2.0.1"

new Handle:g_hCvarEnabled = INVALID_HANDLE;

new bool:g_bEnabled;

public Plugin:myinfo =
{
	name = "tTF2DM - Remove damage of sticky bombs",
	author = "Thrawn",
	description = "Remove damage of sticky bombs",
	version = VERSION,
	url = "http://forums.alliedmods.net/member.php?u=51683"
};

public OnPluginStart() {
	CreateConVar("sm_ttf2dm_removestickydmg_version", VERSION, "", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_hCvarEnabled = CreateConVar("sm_ttf2dm_removestickydmg_enable", "1", "Remove damage of sticky bombs", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvarEnabled, Cvar_ChangedEnable);

	for(new i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i) && !IsFakeClient(i)) {
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public OnConfigsExecuted() {
	g_bEnabled = GetConVarBool(g_hCvarEnabled);
}

public Cvar_ChangedEnable(Handle:convar, const String:oldValue[], const String:newValue[]) {
	g_bEnabled = GetConVarBool(g_hCvarEnabled);
}


public OnClientPutInServer(client) {
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) {
	if(g_bEnabled) {
		decl String:sWeapon[32];
		GetEdictClassname(inflictor, sWeapon, sizeof(sWeapon));

		if(StrEqual(sWeapon, "tf_projectile_pipe_remote") && victim != attacker) {
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}