#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>

#define PL_VERSION "2.0.1"
#define TEAM_BLUE 3
#define TEAM_RED 2
#define DF_FEIGNDEATH 32

#define BOTH 3
#define INCREASING 2
#define INSTANT 1
#define OFF 0

new bool:g_bRegen[MAXPLAYERS+1];
new bool:g_bRegenAmmo[MAXPLAYERS+1];
new Float:g_fRegenTick;
new Float:g_fRegenAmmoTick;
new Float:g_fRegenDelay;

new g_maxAmmo[MAXPLAYERS+1][2];
new g_maxClip[MAXPLAYERS+1][3];

new g_iOffsetAmmo;
new g_iOffsetClip;

new g_iRegenMode;

new g_iRegenHP;
new Float:g_fRegenAmmo;
new Handle:g_hRegenHP = INVALID_HANDLE;
new Handle:g_hRegenAmmo = INVALID_HANDLE;
new Handle:g_hRegenAmmoTick = INVALID_HANDLE;
new Handle:g_hRegenTick = INVALID_HANDLE;
new Handle:g_hRegenDelay = INVALID_HANDLE;
new Handle:g_hRegenEnable = INVALID_HANDLE;

new Handle:g_hRegenTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
new Handle:g_hRegenTimerAmmo[MAXPLAYERS+1] = {INVALID_HANDLE, ...};

public Plugin:myinfo =
{
	name = "tTF2DM - Regeneration",
	author = "Thrawn",
	description = "Automatically regenerates players",
	version = PL_VERSION,
	url = "http://forums.alliedmods.net/member.php?u=51683"
};

public OnPluginStart() {
	CreateConVar("sm_ttf2dm_regen_version", PL_VERSION, "TF2 Deathmatch version.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_iOffsetAmmo = FindSendPropInfo("CTFPlayer", "m_iAmmo");
	g_iOffsetClip = FindSendPropInfo("CTFWeaponBase", "m_iClip1");

	g_hRegenEnable = CreateConVar("sm_ttf2dm_regenmode", "1", "Enable health regeneration, 1=instant on kill, 2=increasing, 3=both.", FCVAR_PLUGIN);
	g_hRegenHP = CreateConVar("sm_ttf2dm_regenhp", "1", "Health added per regeneration tick.", FCVAR_PLUGIN);
	g_hRegenAmmo = CreateConVar("sm_ttf2dm_regenammo", "0.05", "Percent of Maxammo added per regeneration tick.", FCVAR_PLUGIN);
	g_hRegenAmmoTick = CreateConVar("sm_ttf2dm_regenammotick", "3.0", "Delay between ammo regeration ticks.", FCVAR_PLUGIN);
	g_hRegenTick = CreateConVar("sm_ttf2dm_regentick", "0.1", "Delay between regeration ticks.", FCVAR_PLUGIN);
	g_hRegenDelay = CreateConVar("sm_ttf2dm_regendelay", "4.0", "Seconds after damage before regeneration.", FCVAR_PLUGIN);

	HookConVarChange(g_hRegenEnable, Cvar_Changed);
	HookConVarChange(g_hRegenAmmo, Cvar_Changed);
	HookConVarChange(g_hRegenHP, Cvar_Changed);
	HookConVarChange(g_hRegenTick, Cvar_Changed);
	HookConVarChange(g_hRegenAmmoTick, Cvar_Changed);
	HookConVarChange(g_hRegenDelay, Cvar_Changed);

	HookEvent("player_death", Event_player_death);
	HookEvent("player_hurt", Event_player_hurt);
	HookEvent("player_spawn", Event_player_spawn);
	HookEvent("teamplay_round_start", Event_round_start);
	HookEvent("teamplay_restart_round", Event_round_start);
	HookEvent("post_inventory_application", CallCheckInventory, EventHookMode_Post);

	AutoExecConfig(true, "plugin.tTF2DM.regeneration");
}

public Action:CallCheckInventory(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.1, CheckInventory, client);
}

public Action:CheckInventory(Handle:timer, any:client)
{
	g_maxAmmo[client][0] = GetEntData(client, g_iOffsetAmmo+4, 4);
	g_maxAmmo[client][1] = GetEntData(client, g_iOffsetAmmo+8, 4);

	for (new iWeaponIndex = 0; iWeaponIndex < 3; iWeaponIndex++)
	{
		new iEnt = GetPlayerWeaponSlot(client, iWeaponIndex);

		if(IsValidEdict(iEnt)) {
			g_maxClip[client][iWeaponIndex] = GetEntData(iEnt, g_iOffsetClip);
		}
	}
}

ClearHandle(&Handle:hndl) {
	if(hndl == INVALID_HANDLE)
		return;

	CloseHandle(hndl);
	hndl = INVALID_HANDLE;
}

public OnConfigsExecuted() {
	GetConVars();
}

public Cvar_Changed(Handle:convar, const String:oldValue[], const String:newValue[]) {
	GetConVars();
}

public GetConVars() {
	g_iRegenMode = GetConVarInt(g_hRegenEnable);
	g_iRegenHP = GetConVarInt(g_hRegenHP);
	g_fRegenAmmo = GetConVarFloat(g_hRegenAmmo);
	g_fRegenTick = GetConVarFloat(g_hRegenTick);
	g_fRegenAmmoTick = GetConVarFloat(g_hRegenAmmoTick);
	g_fRegenDelay = GetConVarFloat(g_hRegenDelay);
}

public Action:StartRegen(Handle:timer, any:client) {
	g_bRegen[client] = true;
	Regen(INVALID_HANDLE, client);
}

public Action:StartRegenAmmo(Handle:timer, any:client) {
	g_bRegenAmmo[client] = true;
	RegenAmmo(INVALID_HANDLE, client);
}


public Action:RegenAmmo(Handle:timer, any:client) {
	if(g_bRegenAmmo[client] && IsClientInGame(client) && IsPlayerAlive(client)) {
		GiveAmmo(client, g_fRegenAmmo);
		g_hRegenTimerAmmo[client] = CreateTimer(g_fRegenAmmoTick, RegenAmmo, client);
	}
}

public Action:Regen(Handle:timer, any:client) {
	if(g_bRegen[client] && IsClientInGame(client) && IsPlayerAlive(client)) {
		new health = GetClientHealth(client)+g_iRegenHP;
		new iDefaultHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
		if(health > iDefaultHealth)
			health = iDefaultHealth;

		SetEntProp(client, Prop_Send, "m_iHealth", health, 1);
		SetEntProp(client, Prop_Data, "m_iHealth", health, 1);

		g_hRegenTimer[client] = CreateTimer(g_fRegenTick, Regen, client);
	}
}

public GiveAmmo( client, Float:addPercent) {
	//for all the players weapons
	for (new iWeaponIndex = 0; iWeaponIndex < 2; iWeaponIndex++)
	{
		new iOffset = g_iOffsetAmmo + ( iWeaponIndex + 1 ) * 4;
		new add = RoundFloat(addPercent * g_maxAmmo[client][iWeaponIndex]);
		new amount = GetEntData(client, iOffset, 4) + add;

		//get the maximum clip and reserve ammo for the given weapon
		if(amount > g_maxAmmo[client][iWeaponIndex])
			continue;

		SetEntData(client, iOffset, amount);
	}
}

public Action:Event_player_death(Handle:event, const String:name[], bool:dontBroadcast) {
	if (g_iRegenMode == INSTANT || g_iRegenMode == BOTH) {
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		new deathFlags = GetEventInt(event, "death_flags");

		if (deathFlags & DF_FEIGNDEATH)		//skip dead ringer
			return Plugin_Continue;

		if (attacker > 0 && IsClientInGame(attacker) && attacker != client ) {
			TF2_RegeneratePlayer(attacker);
		}
	}

	return Plugin_Continue;
}

public Action:Event_player_hurt(Handle:event, const String:name[], bool:dontBroadcast) {
	if(g_iRegenMode == INCREASING || g_iRegenMode == BOTH) {
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

		if(attacker != 0) {
			ClearHandle(g_hRegenTimer[client]);
			ClearHandle(g_hRegenTimerAmmo[client]);

			g_bRegen[client] = false;
			g_bRegenAmmo[client] = false;

			g_hRegenTimer[client] = CreateTimer(g_fRegenDelay, StartRegen, client);
			g_hRegenTimerAmmo[client] = CreateTimer(g_fRegenDelay, StartRegenAmmo, client);
		}
	}
}

public Action:Event_player_spawn(Handle:event, const String:name[], bool:dontBroadcast) {
	if(g_iRegenMode == INCREASING || g_iRegenMode == BOTH) {
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(IsClientOnTeam(client)) {
			ClearHandle(g_hRegenTimer[client]);
			ClearHandle(g_hRegenTimerAmmo[client]);

			g_hRegenTimer[client] = CreateTimer(0.1, StartRegen, client);
			g_hRegenTimerAmmo[client] = CreateTimer(0.1, StartRegenAmmo, client);
		}
	}
}


public Action:Event_round_start(Handle:event, const String:name[], bool:dontBroadcast) {
	for(new i=0;i<=MaxClients;i++) {
		ClearHandle(g_hRegenTimer[i]);
		ClearHandle(g_hRegenTimerAmmo[i]);
	}
}

IsClientOnTeam(client) {
	new team = GetClientTeam(client);
	return team==2||team==3;
}

