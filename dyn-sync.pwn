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

	Redis_Subscribe("localhost", 6379, "", "dynamo:local:api:player-update", "OnServerUpdatePlayer", pubsub_2);
	SetTimer("IteratePlayers", 1000, true);
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

public OnPlayerUpdate(playerid) {

    if(!IsPlayerConnected(playerid)) return 0;

    new name[MAX_PLAYER_NAME];
    new message[256];
    new Float:x, Float:y, Float:z, Float:health, Float:armor;

    GetPlayerName(playerid, name, sizeof(name));
    GetPlayerPos(playerid, x, y, z);
    GetPlayerHealth(playerid, health);
    GetPlayerArmour(playerid, armor);

    format(message, sizeof(message), "%d|%s|%f|%f|%f|%f|%f", playerid, name, x, y, z, health, armor);
    Redis_Publish(client, "dynamo:local:samp:player-update", message);
    return 1;

}

forward IteratePlayers();
public IteratePlayers()
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

forward OnServerUpdatePlayer(PubSub:id, data[]);
public OnServerUpdatePlayer(PubSub:id, data[]){

    new Node:node;
    new ret;

    ret = JSON_Parse(data, node);
    if(ret) {
        printf("[OnServerUpdatePlayer] could not parse json. Err: %d", ret);
        return 0;
    }


    new playerid;
    ret = JSON_GetInt(node, "playerid", playerid);
    if(ret) {
        printf("[OnServerUpdatePlayer] Could not get playerid. Err: %d", ret);
        return 0;
    }

    if(!IsPlayerConnected(playerid)) {
        printf("[OnServerUpdatePlayer] Player %d is not connected", playerid);
        return 0;
    }

    // Get the 'stats' object
    new Node:stats;
    ret = JSON_GetObject(node, "stats", stats);
    if(ret == 0) {

        new Float:health, Float:armour, skin;

        ret = JSON_GetFloat(stats, "health", health);
        if(!ret) {
            SetPlayerHealth(playerid, health);
            printf("[OnServerUpdatePlayer] Updating player %d health to %f", playerid, health);
        }

        // Check for 'armour' and set it if present
        ret = JSON_GetFloat(stats, "armour", armour);
        if(!ret) {
            SetPlayerArmour(playerid, armour);
            printf("[OnServerUpdatePlayer] Updating player %d armour to %f", playerid, armour);
        }

        // Update Skin
        ret = JSON_GetInt(stats, "skin", skin);
        if(!ret) {
            SetPlayerSkin(playerid, skin);
            printf("[OnServerUpdatePlayer] Updating player %d skin to %d", playerid, skin);
        }

    }

    // Get the 'pos' object
    new Node:pos;
    ret = JSON_GetObject(node, "pos", pos);
    if(ret == 0) {

        new interior, virtualWorld;

        // Update Interior
        ret = JSON_GetInt(pos, "interior", interior);
        if(!ret) {
            SetPlayerInterior(playerid, interior);
            printf("[OnServerUpdatePlayer] Updating player %d interior to %d", playerid, interior);
        }

        // Update Virtual World
        ret = JSON_GetInt(pos, "virtualWorld", virtualWorld);
        if(!ret) {
            SetPlayerVirtualWorld(playerid, virtualWorld);
            printf("[OnServerUpdatePlayer] Updating player %d virtual world to %d", playerid, virtualWorld);
        }

        new Float:cur_x, Float:cur_y, Float:cur_z;
        GetPlayerPos(playerid, cur_x, cur_y, cur_z);  // Get current player position

        new Float:new_x = cur_x, Float:new_y = cur_y, Float:new_z = cur_z;

        // Update X-coordinate if provided
        ret = JSON_GetFloat(pos, "x", new_x);

        // Update Y-coordinate if provided
        ret = JSON_GetFloat(pos, "y", new_y);

        // Update Z-coordinate if provided
        ret = JSON_GetFloat(pos, "z", new_z);

        // Set the updated position
        if(new_x != cur_x || new_y != cur_y || new_z != cur_z) {
            SetPlayerPos(playerid, new_x, new_y, new_z);
            printf("[OnServerUpdatePlayer] Updating player %d position to (%f, %f, %f)", playerid, new_x, new_y, new_z);
        }

    }


    return 1;
}