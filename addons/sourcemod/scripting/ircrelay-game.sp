#pragma semicolon 1

#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <ircrelay>

public Plugin:myinfo =
{
	name        = "IRC Relay - Game Module",
	author      = "GameConnect",
	description = "IRC Relay for SourceMod",
	version     = IRC_VERSION,
	url         = "http://www.gameconnect.net"
};


/**
 * Globals
 */
new g_iServerPort;
new Handle:g_hHostname;
new Handle:g_hXsGameInfo;
new Handle:g_hXsPlayerInfo;
new Handle:g_hXsPlayers;
new String:g_sServerIp[16];


/**
 * Plugin Forwards
 */
public OnPluginStart()
{
	// Find hostname convar
	g_hHostname     = FindConVar("hostname");
	
	// Create convars
	g_hXsGameInfo   = CreateConVar("irc_xs_gameinfo",   "", "Access level needed for gameinfo command",   FCVAR_PLUGIN);
	g_hXsPlayerInfo = CreateConVar("irc_xs_playerinfo", "", "Access level needed for playerinfo command", FCVAR_PLUGIN);
	g_hXsPlayers    = CreateConVar("irc_xs_players",    "", "Access level needed for players command",    FCVAR_PLUGIN);
	
	// Hook convar changes
	HookConVarChange(g_hXsGameInfo,   ConVarChanged_ConVars);
	HookConVarChange(g_hXsPlayerInfo, ConVarChanged_ConVars);
	HookConVarChange(g_hXsPlayers,    ConVarChanged_ConVars);
	
	// Store server IP and port
	new iIp       = GetConVarInt(FindConVar("hostip"));
	g_iServerPort = GetConVarInt(FindConVar("hostport"));
	Format(g_sServerIp, sizeof(g_sServerIp), "%i.%i.%i.%i", (iIp >> 24) & 0x000000FF,
																													(iIp >> 16) & 0x000000FF,
																													(iIp >>  8) & 0x000000FF,
																													iIp         & 0x000000FF);
	
	LoadTranslations("common.phrases");
	
	if(LibraryExists("ircrelay"))
		OnLibraryAdded("ircrelay");
}

public OnLibraryAdded(const String:name[])
{
	if(!StrEqual(name, "ircrelay"))
		return;
	
	decl String:sXsGameInfo[2], String:sXsPlayerInfo[2], String:sXsPlayers[2];
	GetConVarString(g_hXsGameInfo,   sXsGameInfo,   sizeof(sXsGameInfo));
	GetConVarString(g_hXsPlayerInfo, sXsPlayerInfo, sizeof(sXsPlayerInfo));
	GetConVarString(g_hXsPlayers,    sXsPlayers,    sizeof(sXsPlayers));
	
	IRC_RegisterCommand("gameinfo",   IrcCommand_GameInfo,   IRC_GetAccess(sXsGameInfo));
	IRC_RegisterCommand("playerinfo", IrcCommand_PlayerInfo, IRC_GetAccess(sXsPlayerInfo));
	IRC_RegisterCommand("players",    IrcCommand_Players,    IRC_GetAccess(sXsPlayers));
}

public ConVarChanged_ConVars(Handle:convar, const String:oldValue[], const String:newValue[])
{
	OnLibraryAdded("ircrelay");
}


/**
 * IRC Commands
 */
public IrcCommand_GameInfo(const String:channel[], const String:name[], const String:arg[])
{
	decl iTimeLeft, String:sGameDesc[64], String:sHostname[256], String:sMap[32], String:sTimeLeft[32];
	GetConVarString(g_hHostname, sHostname, sizeof(sHostname));
	GetGameDescription(sGameDesc, sizeof(sGameDesc));
	GetCurrentMap(sMap,           sizeof(sMap));
	
	if(GetMapTimeLeft(iTimeLeft) && iTimeLeft >= 0)
		SecondsToString(iTimeLeft, sTimeLeft, sizeof(sTimeLeft));
	else
		sTimeLeft = "Infinite";
	
	IRC_PrivMsg(channel, "Name: %s - IP: %s:%i", sHostname, g_sServerIp, g_iServerPort);
	IRC_PrivMsg(channel, "Map: %s - Timeleft: %s", sMap, sTimeLeft);
	IRC_PrivMsg(channel, "Players: %i/%i - Mod: %s", GetClientCount(), MaxClients, sGameDesc);
}

public IrcCommand_PlayerInfo(const String:channel[], const String:name[], const String:arg[])
{
	new iTarget = FindTarget(0, arg);
	if(iTarget == -1)
	{
		IRC_PrivMsg(channel, "Invalid player specified.");
		return;
	}
	
	decl String:sAuth[20], String:sIp[15], String:sName[MAX_NAME_LENGTH + 1];
	GetClientAuthString(iTarget, sAuth, sizeof(sAuth));
	GetClientIP(iTarget,         sIp,   sizeof(sIp));
	IRC_GetClientName(iTarget,   sName, sizeof(sName));
	
	IRC_PrivMsg(channel, "%s (%i, %s, %s) - Score/Deaths: %i/%i - HP/AP: %i/%i - Ping: %i",
												sName, GetClientUserId(iTarget), sAuth, sIp, GetClientFrags(iTarget),
												GetClientDeaths(iTarget), GetClientHealth(iTarget), GetClientArmor(iTarget),
												IsFakeClient(iTarget) ? 0 : RoundToNearest(GetClientAvgLatency(iTarget, NetFlow_Outgoing) * 1000.0));
}

public IrcCommand_Players(const String:channel[], const String:name[], const String:arg[])
{
	new iClients = GetClientCount();
	IRC_PrivMsg(channel, "Total Players: %i", iClients);
	if(!iClients)
		return;
	
	for(new i = IRC_GetTeamCount() - 1; i >= 0; i--)
	{
		iClients = IRC_GetTeamClientCount(i);
		if(!iClients)
			continue;
		
		decl String:sBuffer[4096] = "", String:sName[MAX_NAME_LENGTH + 1], String:sTeam[MAX_NAME_LENGTH + 1];
		IRC_GetTeamName(i, sTeam, sizeof(sTeam));
		
		for(new j = 1; j <= MaxClients; j++)
		{
			if(!IsClientInGame(j) || GetClientTeam(j) != i)
				continue;
			
			IRC_GetClientName(j, sName, sizeof(sName));
			StrCat(sBuffer, sizeof(sBuffer), ", ");
			StrCat(sBuffer, sizeof(sBuffer), sName);
		}
		IRC_PrivMsg(channel, "%s (%i): %s", sTeam, iClients, sBuffer[2]); // Skip the ', ' from the front
	}
}


/**
 * Stocks
 */
stock SecondsToString(seconds, String:buffer[], maxlength)
{
	new iHours   = seconds / 60 / 60;
	seconds     -= iHours  * 60 / 60;
	new iMinutes = seconds / 60;
	seconds     %= 60;
	
	Format(buffer, maxlength, "%i Hours, %i Minutes, %i Seconds", iHours, iMinutes, seconds);
}