#pragma semicolon 1

#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <ircrelay>

public Plugin:myinfo =
{
	name        = "IRC Relay - Admin Module",
	author      = "GameConnect",
	description = "IRC Relay for SourceMod",
	version     = IRC_VERSION,
	url         = "http://www.gameconnect.net"
};


/**
 * Globals
 */
new Handle:g_hXsBan;
new Handle:g_hXsKick;
new Handle:g_hXsRcon;


/**
 * Plugin Forwards
 */
public OnPluginStart()
{
	// Create convars
	g_hXsBan  = CreateConVar("irc_xs_ban",  "o", "Access level needed for ban command",  FCVAR_PLUGIN);
	g_hXsKick = CreateConVar("irc_xs_kick", "o", "Access level needed for kick command", FCVAR_PLUGIN);
	g_hXsRcon = CreateConVar("irc_xs_rcon", "o", "Access level needed for rcon command", FCVAR_PLUGIN);
	
	// Hook convar changes
	HookConVarChange(g_hXsBan,  ConVarChanged_ConVars);
	HookConVarChange(g_hXsKick, ConVarChanged_ConVars);
	HookConVarChange(g_hXsRcon, ConVarChanged_ConVars);
	
	LoadTranslations("common.phrases");
	
	if(LibraryExists("ircrelay"))
		OnLibraryAdded("ircrelay");
}

public OnLibraryAdded(const String:name[])
{
	if(!StrEqual(name, "ircrelay"))
		return;
	
	decl String:sXsBan[2], String:sXsKick[2], String:sXsRcon[2];
	GetConVarString(g_hXsBan,  sXsBan,  sizeof(sXsBan));
	GetConVarString(g_hXsKick, sXsKick, sizeof(sXsKick));
	GetConVarString(g_hXsRcon, sXsRcon, sizeof(sXsRcon));
	
	IRC_RegisterCommand("ban",  IrcCommand_Ban,  IRC_GetAccess(sXsBan));
	IRC_RegisterCommand("kick", IrcCommand_Kick, IRC_GetAccess(sXsKick));
	IRC_RegisterCommand("rcon", IrcCommand_Rcon, IRC_GetAccess(sXsRcon));
}

public ConVarChanged_ConVars(Handle:convar, const String:oldValue[], const String:newValue[])
{
	OnLibraryAdded("ircrelay");
}


/**
 * IRC Commands
 */
public IrcCommand_Ban(const String:channel[], const String:name[], const String:arg[])
{
	decl iLen, String:sTarget[MAX_NAME_LENGTH + 1], String:sTime[12];
	iLen  = BreakString(arg,       sTarget, sizeof(sTarget));
	iLen += BreakString(arg[iLen], sTime,   sizeof(sTime));
	
	new iTarget = FindTarget(0, sTarget);
	if(iTarget == -1)
	{
		IRC_PrivMsg(channel, "Invalid player specified.");
		return;
	}
	
	BanClient(iTarget, StringToInt(sTime), BANFLAG_AUTO, arg[iLen], _, "ircrelay");
}

public IrcCommand_Kick(const String:channel[], const String:name[], const String:arg[])
{
	decl iLen, String:sTarget[MAX_NAME_LENGTH + 1];
	iLen = BreakString(arg, sTarget, sizeof(sTarget));
	
	new iTarget = FindTarget(0, sTarget);
	if(iTarget == -1)
	{
		IRC_PrivMsg(channel, "Invalid player specified.");
		return;
	}
	
	KickClient(iTarget, arg[iLen]);
}

public IrcCommand_Rcon(const String:channel[], const String:name[], const String:arg[])
{
	ServerCommand(arg);
	IRC_PrivMsg(channel, "RCON: %s", arg);
}