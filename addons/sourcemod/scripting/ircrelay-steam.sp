#pragma semicolon 1

#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <ircrelay>

public Plugin:myinfo =
{
	name        = "IRC Relay - Steam Module",
	author      = "GameConnect",
	description = "IRC Relay for SourceMod",
	version     = IRC_VERSION,
	url         = "http://www.gameconnect.net"
};

new Handle:g_hXsProfile;
new Handle:g_hXsSteam;

public OnPluginStart()
{
	g_hXsProfile = CreateConVar("irc_xs_profile", "", "Access level needed for profile command", FCVAR_PLUGIN);
	g_hXsSteam   = CreateConVar("irc_xs_steam",   "", "Access level needed for steam command",   FCVAR_PLUGIN);
	
	HookConVarChange(g_hXsProfile, ConVarChanged_ConVars);
	HookConVarChange(g_hXsSteam,   ConVarChanged_ConVars);
	
	if(LibraryExists("ircrelay"))
		OnLibraryAdded("ircrelay");
}

public OnLibraryAdded(const String:name[])
{
	if(!StrEqual(name, "ircrelay"))
		return;
	
	decl String:sXsProfile[2], String:sXsSteam[2];
	GetConVarString(g_hXsProfile, sXsProfile, sizeof(sXsProfile));
	GetConVarString(g_hXsSteam,   sXsSteam,   sizeof(sXsSteam));
	
	IRC_RegisterCommand("profile", IrcCommand_Profile, IRC_GetAccess(sXsProfile));
	IRC_RegisterCommand("steam",   IrcCommand_Steam,   IRC_GetAccess(sXsSteam));
}

public ConVarChanged_ConVars(Handle:convar, const String:oldValue[], const String:newValue[])
{
	OnLibraryAdded("ircrelay");
}


/**
 * IRC Commands
 */
public IrcCommand_Profile(const String:channel[], const String:name[], const String:arg[])
{
	decl String:sSteam[3][64];
	ExplodeString(arg, ":", sSteam, sizeof(sSteam), sizeof(sSteam[]));
	
	new iFriend = 60265728 + StringToInt(sSteam[1]) + StringToInt(sSteam[2]) * 2;
	IRC_PrivMsg(channel, "http://steamcommunity.com/profiles/765611979%d", iFriend);
}

public IrcCommand_Steam(const String:channel[], const String:name[], const String:arg[])
{
	new iPos = StrContains(arg, "765611979");
	if(iPos == -1)
	{
		IRC_PrivMsg(channel, "You must send a SteamCommunity URL, eg: http://steamcommunity.com/profiles/76561197970389645");
		return;
	}
	
	new iSteam  = (StringToInt(arg[iPos + 9]) - 60265728) / 2,
			iServer = (iSteam + 60265728) * 2 == 76561197960265728 ? 0 : 1;
	IRC_PrivMsg(channel, "STEAM_0:%d:%d", iServer, iSteam);
}