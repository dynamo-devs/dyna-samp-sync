// generated by "sampctl package init"
#include <a_samp>
#include <redis>
#include <json>

new Redis:client;
new PubSub:pubsub_2;

public OnFilterScriptInit(){
    print("\n--REDIS.\n");
	new ret = Redis_Connect("localhost", 6379, "", client);
	printf("REDIS ret: %d", ret);

	Redis_Subscribe("localhost", 6379, "", "dynamo:local:api:run-function", "OnServerExecuteRemoteFunction", pubsub_2);
	SetTimer("SyncConnectedPlayers", 1000, true);
	return 1;
}


public OnPlayerConnect(playerid) {
    new name[MAX_PLAYER_NAME];
    new message[256];

    GetPlayerName(playerid, name, sizeof(name));
    format(message, sizeof(message), "%d|%s", playerid, name);
    printf("OnPlayerConnect: %s",message);
    //TODO: convert to json?
    new ret = Redis_Publish(client, "dynamo:local:samp:player-connect", message);
    printf("OnPlayerConnect ret: %d", ret);

    return 1;
}
public OnPlayerDisconnect(playerid) {
    new name[MAX_PLAYER_NAME];
    new message[256];
    GetPlayerName(playerid, name, sizeof(name));
    format(message, sizeof(message), "%d|%s", playerid, name);
    printf("OnPlayerDisconnect: %s",message);
    new ret = Redis_Publish(client, "dynamo:local:samp:player-disconnect", message);
    printf("OnPlayerDisconnect ret: %d", ret);

}

forward SyncConnectedPlayers();
public SyncConnectedPlayers()
{
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        if (IsPlayerConnected(i))
        {
            SyncPlayer(i);
        }
    }
}

forward SyncPlayer(playerid);
public SyncPlayer(playerid) {
    // Add name to JSON
    new name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));

    // Add position to JSON
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    // Add health and armour to JSON
    new Float:health, Float:armour;
    GetPlayerHealth(playerid, health);
    GetPlayerArmour(playerid, armour);

    // Add skin, interior, and virtual world to JSON
    new skin = GetPlayerSkin(playerid);
    new interior = GetPlayerInterior(playerid);
    new virtualWorld = GetPlayerVirtualWorld(playerid);

    new Node:playerJson = JSON_Object(
        "id", JSON_Int(playerid),
        "name", JSON_String(name),
        "pos", JSON_Object(
            "x", JSON_Float(x),
            "y", JSON_Float(y),
            "z", JSON_Float(z)
        ),
        "health", JSON_Float(health),
        "armour", JSON_Float(armour),
        "skin", JSON_Int(skin),
        "interior", JSON_Int(interior),
        "virtualWorld", JSON_Int(virtualWorld)
    );

    new jsonStr[512];
    JSON_Stringify(playerJson, jsonStr, sizeof(jsonStr));

    Redis_Publish(client, "dynamo:local:samp:player-sync", jsonStr);

}

forward OnServerExecuteRemoteFunction(PubSub:id, data[]);
public OnServerExecuteRemoteFunction(PubSub:id, data[]){

    new Node:node;
    new ret;

    ret = JSON_Parse(data, node);
    if(ret) {
        printf("[OnServerExecuteRemoteFunction] could not parse json. Err: %d", ret);
        return 0;
    }

    new execution_id[36];
    if (JSON_GetString(node, "id", execution_id))
    {
        printf("[OnServerExecuteRemoteFunction] Failed to get 'execution_id' from JSON.");
        return 0;
    }

    // Extract "function" from JSON
    new func_to_call[32];
    if (JSON_GetString(node, "function", func_to_call))
    {
        printf("[OnServerExecuteRemoteFunction//%s] Failed to get 'function' from JSON.", execution_id);
        return 0;
    }

    new full_func_to_call[40] = "Remote";
    strcat(full_func_to_call, func_to_call);

    new params_to_send[128];
    if (JSON_GetString(node, "params", params_to_send))
    {
        printf("[OnServerExecuteRemoteFunction//%s] Failed to get 'params' from JSON.", execution_id);
        return 0;
    }

    ret = CallRemoteFunction(full_func_to_call, "s", params_to_send);

    new Node:callbackJson = JSON_Object(
        "id", JSON_String(execution_id),
        "ret", JSON_Int(ret)
    );

    new jsonStr[512];
    JSON_Stringify(callbackJson, jsonStr, sizeof(jsonStr));

    Redis_Publish(client, "dynamo:local:samp:callback-function", jsonStr);

    return 1;
}

forward RemoteSetPlayerPos(data[]);
public RemoteSetPlayerPos(data[]){

    new Node:node;

    if(JSON_Parse(data, node)) {
        printf("[RemoteSetPlayerPos] could not parse json");
        return 0;
    }

    new playerid, Float:pos_x, Float:pos_y, Float:pos_z;

    if (JSON_GetInt(node, "player_id", playerid))
    {
        printf("[RemoteSetPlayerPos] Failed to get 'player_id' from JSON.");
        return 0;
    }

    if (JSON_GetFloat(node, "pos_x", pos_x) || JSON_GetFloat(node, "pos_y", pos_y) || JSON_GetFloat(node, "pos_z", pos_z))
    {
        printf("[RemoteSetPlayerPos] Failed to get complete position from JSON.");
        return 0;
    }

    printf("[RemoteSetPlayerPos] Moving player %d to %f, %f, %f.", playerid, pos_x, pos_y, pos_z);
    return SetPlayerPos(playerid, pos_x, pos_y, pos_z);
}

forward RemoteResetPlayerWeapons(data[]);
public RemoteResetPlayerWeapons(data[]){
    new Node:node;
    if(JSON_Parse(data, node)) {
        printf("[RemoteResetPlayerWeapons] Could not parse json");
        return 0;
    }

    new playerid;
    if (JSON_GetInt(node, "player_id", playerid)) {
        printf("[RemoteResetPlayerWeapons] Failed to get 'player_id' from JSON.");
        return 0;
    }

    return ResetPlayerWeapons(playerid);
}

forward RemoteSetPlayerArmour(data[]);
public RemoteSetPlayerArmour(data[]){
    new Node:node;
    if(JSON_Parse(data, node)) {
        printf("[RemoteSetPlayerArmour] Could not parse json");
        return 0;
    }

    new playerid;
    new Float:armour;
    if (JSON_GetInt(node, "player_id", playerid) || JSON_GetFloat(node, "armour", armour)) {
        printf("[RemoteSetPlayerArmour] Failed to get required parameters from JSON.");
        return 0;
    }

    return SetPlayerArmour(playerid, armour);
}

forward RemoteSetPlayerFightingStyle(data[]);
public RemoteSetPlayerFightingStyle(data[]){
    new Node:node;
    if(JSON_Parse(data, node)) {
        printf("[RemoteSetPlayerFightingStyle] Could not parse json");
        return 0;
    }

    new playerid, style;
    if (JSON_GetInt(node, "player_id", playerid) || JSON_GetInt(node, "style", style)) {
        printf("[RemoteSetPlayerFightingStyle] Failed to get required parameters from JSON.");
        return 0;
    }

    return SetPlayerFightingStyle(playerid, style);
}

forward RemoteSetPlayerHealth(data[]);
public RemoteSetPlayerHealth(data[]){
    new Node:node;
    if(JSON_Parse(data, node)) {
        printf("[RemoteSetPlayerHealth] Could not parse json");
        return 0;
    }

    new playerid;
    new Float:health;
    if (JSON_GetInt(node, "player_id", playerid) || JSON_GetFloat(node, "health", health)) {
        printf("[RemoteSetPlayerHealth] Failed to get required parameters from JSON.");
        return 0;
    }

    return SetPlayerHealth(playerid, health);
}

forward RemoteSetPlayerInterior(data[]);
public RemoteSetPlayerInterior(data[]){
    new Node:node;
    if(JSON_Parse(data, node)) {
        printf("[RemoteSetPlayerInterior] Could not parse json");
        return 0;
    }

    new playerid, interiorid;
    if (JSON_GetInt(node, "player_id", playerid) || JSON_GetInt(node, "interior_id", interiorid)) {
        printf("[RemoteSetPlayerInterior] Failed to get required parameters from JSON.");
        return 0;
    }

    return SetPlayerInterior(playerid, interiorid);
}

forward RemoteSetPlayerSkin(data[]);
public RemoteSetPlayerSkin(data[]){
    new Node:node;
    if(JSON_Parse(data, node)) {
        printf("[RemoteSetPlayerSkin] Could not parse json");
        return 0;
    }

    new playerid, skinid;
    if (JSON_GetInt(node, "player_id", playerid) || JSON_GetInt(node, "skin_id", skinid)) {
        printf("[RemoteSetPlayerSkin] Failed to get required parameters from JSON.");
        return 0;
    }

    return SetPlayerSkin(playerid, skinid);
}

forward RemoteSetPlayerVirtualWorld(data[]);
public RemoteSetPlayerVirtualWorld(data[]){
    new Node:node;
    if(JSON_Parse(data, node)) {
        printf("[RemoteSetPlayerVirtualWorld] Could not parse json");
        return 0;
    }

    new playerid, worldid;
    if (JSON_GetInt(node, "player_id", playerid) || JSON_GetInt(node, "world_id", worldid)) {
        printf("[RemoteSetPlayerVirtualWorld] Failed to get required parameters from JSON.");
        return 0;
    }

    return SetPlayerVirtualWorld(playerid, worldid);
}

forward RemoteSetPlayerWeather(data[]);
public RemoteSetPlayerWeather(data[]){
    new Node:node;
    if(JSON_Parse(data, node)) {
        printf("[RemoteSetPlayerWeather] Could not parse json");
        return 0;
    }

    new playerid, weather;
    if (JSON_GetInt(node, "player_id", playerid) || JSON_GetInt(node, "weather", weather)) {
        printf("[RemoteSetPlayerWeather] Failed to get required parameters from JSON.");
        return 0;
    }

    return SetPlayerWeather(playerid, weather);
}
