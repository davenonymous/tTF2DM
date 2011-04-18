#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <colors>

#define PL_VERSION "2.0.1"
#define TEAM_BLUE 3
#define TEAM_RED 2
#define DF_FEIGNDEATH 32

new bool:g_bEnable;
new bool:g_bSpawnRandom;
new bool:g_bSpawnMap;
new Float:g_fSpawn;

new Handle:g_hSpawn = INVALID_HANDLE;
new Handle:g_hSpawnRandom = INVALID_HANDLE;
new Handle:g_hRedSpawns = INVALID_HANDLE;
new Handle:g_hBluSpawns = INVALID_HANDLE;
new Handle:g_hKv = INVALID_HANDLE;
new Handle:g_hEnable = INVALID_HANDLE;


new bool:g_bWinPanelShown = false;

public Plugin:myinfo =
{
	name = "tTF2DM",
	author = "Thrawn",
	description = "TF2 Deathmatch Gameplay",
	version = PL_VERSION,
	url = "http://forums.alliedmods.net/member.php?u=51683"
};

public OnPluginStart() {
	CreateConVar("sm_ttf2dm_version", PL_VERSION, "TF2 Deathmatch version.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_hEnable = CreateConVar("sm_ttf2dm_enable", "1", "Enable deathmatch mode.", FCVAR_PLUGIN|FCVAR_NOTIFY);

	g_hSpawn = CreateConVar("sm_ttf2dm_spawn", "1.5", "Spawn timer.", FCVAR_PLUGIN);
	g_hSpawnRandom = CreateConVar("sm_ttf2dm_spawnrandom", "1", "Enable random spawns.", FCVAR_PLUGIN);

	HookConVarChange(g_hEnable, Cvar_enable);
	HookConVarChange(g_hSpawn, Cvar_Changed);
	HookConVarChange(g_hSpawnRandom, Cvar_Changed);

	HookEvent("player_death", Event_player_death);
	HookEvent("player_spawn", Event_player_spawn);
	HookEvent("teamplay_win_panel", Event_win_panel);

	g_hRedSpawns = CreateArray();
	g_hBluSpawns = CreateArray();

	AutoExecConfig(true, "plugin.tTF2DM.core");
}

public OnMapStart() {
	PrecacheSound("items/spawn_item.wav", true);

	LoadSpawns();
	g_bWinPanelShown = false;
}

public OnConfigsExecuted() {
	GetConVars();
}

public Cvar_enable(Handle:convar, const String:oldValue[], const String:newValue[]) {
	g_bEnable = GetConVarBool(g_hEnable);

	if(g_bEnable) {
		CPrintToChatAll("{blue}DM mode is now enabled!");
	} else {
		CPrintToChatAll("{blue}DM mode is now disabled!");
	}
}

public Cvar_Changed(Handle:convar, const String:oldValue[], const String:newValue[]) {
	GetConVars();
}

public GetConVars() {
	g_fSpawn = GetConVarFloat(g_hSpawn);
	g_bSpawnRandom = GetConVarBool(g_hSpawnRandom);
	g_bEnable = GetConVarBool(g_hEnable);
}

/* ----------------- */
/* --- SPAWNS ------ */
/* ----------------- */
public LoadSpawns() {
	ClearArray(g_hRedSpawns);
	ClearArray(g_hBluSpawns);

	for(new i=0;i<MAXPLAYERS;i++) {
		PushArrayCell(g_hRedSpawns, CreateArray(6));
		PushArrayCell(g_hBluSpawns, CreateArray(6));
	}
	g_bSpawnMap = false;

	ClearHandle(g_hKv);
	g_hKv = CreateKeyValues("Spawns");

	decl String:map[64];
	GetCurrentMap(map, sizeof(map));

	decl String:path[256];
	BuildPath(Path_SM, path, sizeof(path), "configs/tf2dm/%s.cfg", map);

	if(FileExists(path)) {
		g_bSpawnMap = true;
		FileToKeyValues(g_hKv, path);

		decl String:sTeam[5], Float:vectors[6], Float:origin[3], Float:angles[3];
		KvGotoFirstSubKey(g_hKv);

		do {
			KvGetString(g_hKv, "team", sTeam, sizeof(sTeam));
			KvGetVector(g_hKv, "origin", origin);
			KvGetVector(g_hKv, "angles", angles);
			vectors[0] = origin[0];
			vectors[1] = origin[1];
			vectors[2] = origin[2];
			vectors[3] = angles[0];
			vectors[4] = angles[1];
			vectors[5] = angles[2];

			if(strcmp(sTeam,"red") == 0 || strcmp(sTeam,"both") == 0) {
				for(new i=0;i<MAXPLAYERS;i++)
					PushArrayArray(GetArrayCell(g_hRedSpawns, i), vectors);
			}

			if(strcmp(sTeam,"blue") == 0 || strcmp(sTeam,"both") == 0) {
				for(new i=0;i<MAXPLAYERS;i++)
					PushArrayArray(GetArrayCell(g_hBluSpawns, i), vectors);
			}
		} while(KvGotoNextKey(g_hKv));
	} else {
		LogError("File Not Found: %s", path);
	}
}

public Action:RandomSpawn(Handle:timer, any:client) {
	if(IsClientInGame(client) && IsPlayerAlive(client)) {
		new team = GetClientTeam(client), Handle:array, size, Handle:spawns = CreateArray(), count = GetClientCount();
		decl Float:vectors[6], Float:origin[3], Float:angles[3];
		if(team==2) {
			for(new i=0;i<=count;i++) {
				array = GetArrayCell(g_hRedSpawns, i);
				if(GetArraySize(array)!=0)
					size = PushArrayCell(spawns, array);
			}
		} else {
			for(new i=0;i<=count;i++) {
				array = GetArrayCell(g_hBluSpawns, i);
				if(GetArraySize(array)!=0)
					size = PushArrayCell(spawns, array);
			}
		}
		array = GetArrayCell(spawns, GetRandomInt(0, GetArraySize(spawns)-1));
		size = GetArraySize(array);
		GetArrayArray(array, GetRandomInt(0, size-1), vectors);
		CloseHandle(spawns);
		origin[0] = vectors[0];
		origin[1] = vectors[1];
		origin[2] = vectors[2];
		angles[0] = vectors[3];
		angles[1] = vectors[4];
		angles[2] = vectors[5];
		TeleportEntity(client, origin, angles, NULL_VECTOR);
		EmitAmbientSound("items/spawn_item.wav", origin);
	}
}

public Action:Respawn(Handle:timer, any:client) {
	if(IsClientInGame(client) && IsClientOnTeam(client)) {
		if(!g_bWinPanelShown)
			TF2_RespawnPlayer(client);
	}
}

/* ----------------- */
/* --- EVENTS ------ */
/* ----------------- */
public Action:Event_player_death(Handle:event, const String:name[], bool:dontBroadcast) {
	if(g_bEnable) {
		if (GetEventInt(event, "death_flags") & DF_FEIGNDEATH)		//skip dead ringer
			return Plugin_Continue;

		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

		if (attacker > 0 && IsClientInGame(attacker) && attacker != client ) {
			CPrintToChatEx(client, attacker, "{teamcolor}%N{default} killed you with {olive}%d{default} hp left", attacker, GetClientHealth(attacker));
		}

		if (attacker == 0) {
			CPrintToChat(client, "The {olive}world{default} killed you!");
		}


		CreateTimer(g_fSpawn, Respawn, client);
	}

	return Plugin_Continue;
}

public Action:Event_player_spawn(Handle:event, const String:name[], bool:dontBroadcast) {
	if(g_bEnable && g_bSpawnRandom && g_bSpawnMap) {
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(IsClientOnTeam(client)) {
			CreateTimer(0.03, RandomSpawn, client);
		}
	}
}


public Action:Event_win_panel(Handle:event, const String:name[], bool:dontBroadcast) {
	g_bWinPanelShown = true;
}


/* ----------------- */
/* --- Helper ------ */
/* ----------------- */

IsClientOnTeam(client) {
	new team = GetClientTeam(client);
	return team==2||team==3;
}

ClearHandle(&Handle:hndl) {
	if(hndl == INVALID_HANDLE)
		return;

	CloseHandle(hndl);
	hndl = INVALID_HANDLE;
}