#pragma semicolon 1

#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <ircrelay>

public Plugin:myinfo =
{
	name        = "IRC Relay - Chat Module",
	author      = "GameConnect",
	description = "IRC Relay for SourceMod",
	version     = IRC_VERSION,
	url         = "http://www.gameconnect.net"
}


/**
 * Globals
 */
new IrcChannel:g_iChatRelayType;
new IrcChannel:g_iMessageRelayType;
new Handle:g_hChatRelayType;
new Handle:g_hMessageRelayType;
new Handle:g_hXsMsg;
new Handle:g_hXsPage;


/**
 * Plugin Forwards
 */
public OnPluginStart()
{
	// Create convars
	g_hChatRelayType    = CreateConVar("irc_chat_relaytype",    "0", "Channel type to relay chat to. (0 = off, 1 = public, 2 = private, 3 = both)",          FCVAR_PLUGIN);
	g_hMessageRelayType = CreateConVar("irc_message_relaytype", "1", "Channel type to relay /irc messages to. (0 = off, 1 = public, 2 = private, 3 = both)", FCVAR_PLUGIN);
	g_hXsMsg            = CreateConVar("irc_xs_msg",            "v", "Access level needed for msg command",                                                  FCVAR_PLUGIN);
	g_hXsPage           = CreateConVar("irc_xs_page",           "v", "Access level needed for page command",                                                 FCVAR_PLUGIN);
	
	// Hook convar changes
	HookConVarChange(g_hChatRelayType,    ConVarChanged_ConVars);
	HookConVarChange(g_hMessageRelayType, ConVarChanged_ConVars);
	HookConVarChange(g_hXsMsg,            ConVarChanged_ConVars);
	HookConVarChange(g_hXsPage,           ConVarChanged_ConVars);
	
	// Hook say commands
	AddCommandListener(CommandListener_Say, "say");
	AddCommandListener(CommandListener_Say, "say_team");
	
	LoadTranslations("common.phrases");
	
	if(LibraryExists("ircrelay"))
		OnLibraryAdded("ircrelay");
}

public OnLibraryAdded(const String:name[])
{
	if(!StrEqual(name, "ircrelay"))
		return;
	
	g_iChatRelayType    = IrcChannel:GetConVarInt(g_hChatRelayType);
	g_iMessageRelayType = IrcChannel:GetConVarInt(g_hMessageRelayType);
	
	decl String:sXsMsg[2], String:sXsPage[2];
	GetConVarString(g_hXsMsg,  sXsMsg,  sizeof(sXsMsg));
	GetConVarString(g_hXsPage, sXsPage, sizeof(sXsPage));
	
	IRC_RegisterCommand("msg",  IrcCommand_Msg,  IRC_GetAccess(sXsMsg));
	IRC_RegisterCommand("page", IrcCommand_Page, IRC_GetAccess(sXsPage));
}

public ConVarChanged_ConVars(Handle:convar, const String:oldValue[], const String:newValue[])
{
	OnLibraryAdded("ircrelay");
}


/**
 * IRC Commands
 */
public IrcCommand_Msg(const String:channel[], const String:name[], const String:arg[])
{
	PrintToChatAll("%c[IRC]%c %s: %s", CLR_GREEN, CLR_DEFAULT, name, arg);
	IRC_PrivMsg(channel, "(IRC) %s: %s", name, arg);
}

public IrcCommand_Page(const String:channel[], const String:name[], const String:arg[])
{
	decl String:sTarget[MAX_NAME_LENGTH + 1];
	new iLen    = BreakString(arg, sTarget, sizeof(sTarget)),
			iTarget = FindTarget(0, sTarget);
	
	if(iTarget == -1)
	{
		IRC_PrivMsg(channel, "Invalid player specified.");
		return;
	}
	
	decl String:sName[MAX_NAME_LENGTH + 1];
	IRC_GetClientName(iTarget, sName, sizeof(sName));
	
	PrintToChat(iTarget, "%c[IRC]%c (Private) %s: %s", CLR_GREEN, CLR_DEFAULT, name, arg[iLen]);
	IRC_PrivMsg(channel, "Page sent to %s: %s", sName, arg[iLen]);
}


/**
 * Command Listeners
 */
public Action:CommandListener_Say(client, const String:command[], argc)
{
	if(!client)
		return Plugin_Continue;
	
	decl String:sText[192];
	new iStart = 0;
	if(GetCmdArgString(sText, sizeof(sText)) < 1)
		return Plugin_Continue;
	
	if(sText[strlen(sText) - 1] == '"')
	{
		sText[strlen(sText) - 1] = '\0';
		iStart                   = 1;
	}
	if(g_iMessageRelayType && strncmp(sText[iStart], "/irc", 4) == 0)
	{
		if(!sText[iStart + 4])
		{
			PrintToChat(client, "%c[IRC]%c You must enter a message to send", CLR_GREEN, CLR_DEFAULT);
			return Plugin_Handled;
		}
		
		decl String:sName[MAX_NAME_LENGTH + 1];
		IRC_GetClientName(client, sName, sizeof(sName));
		IRC_Broadcast(g_iMessageRelayType, "(%s): %s", sName, sText[iStart + 4]);
		
		PrintToChat(client, "%c[IRC]%c Your message was sent!", CLR_GREEN, CLR_DEFAULT);
		return Plugin_Handled;
	}
	if(g_iChatRelayType)
	{
		decl String:sName[MAX_NAME_LENGTH + 1];
		IRC_GetClientName(client, sName, sizeof(sName));
		IRC_Broadcast(g_iChatRelayType, "%s: %s", sName, sText[iStart]);
	}
	
	return Plugin_Continue;
}