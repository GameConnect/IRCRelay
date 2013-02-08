#pragma semicolon 1
#pragma dynamic 65536

#include <sourcemod>
#include <sdktools>
#include <socket>
#include <ircrelay>

public Plugin:myinfo =
{
	name        = "IRC Relay",
	author      = "GameConnect",
	description = "IRC Relay for SourceMod",
	version     = IRC_VERSION,
	url         = "http://www.gameconnect.net"
};


/**
 * Globals
 */
enum Config
{
	Config_Channels,
	Config_TeamColors
}

enum Mod
{
	Mod_Default,
	Mod_Insurgency
}

new g_iTeamColors[8];
new g_iTriggerGroups;
new bool:g_bDebug;
new bool:g_bColor;
new Config:g_iConfig;
new Function:g_fCommandCallbacks[64];
new Handle:g_hAuthPassword;
new Handle:g_hAuthString;
new Handle:g_hAuthUsername;
new Handle:g_hChannels;
new Handle:g_hChannelUsers[64];
new Handle:g_hCommands;
new Handle:g_hCommandPlugins[64];
new Handle:g_hConfigParser;
new Handle:g_hColor;
new Handle:g_hDebug;
new Handle:g_hNickname;
new Handle:g_hPassword;
new Handle:g_hPort;
new Handle:g_hQueue;
new Handle:g_hServer;
new Handle:g_hTrigger;
new Handle:g_hTriggerGroups;
new Handle:g_hModes;
new Handle:g_hOnConnect;
new Handle:g_hOnDisconnect;
new Handle:g_hOnError;
new Handle:g_hOnReceive;
new Handle:g_hSocket;
new IrcAccess:g_iCommandAccess[64];
new IrcChannel:g_iChannelTypes[64];
new Mod:g_iMod = Mod_Default;
new String:g_sNickname[33];
new String:g_sServerIp[16];
new String:g_sTeamNames[8][33];
new String:g_sTrigger[33];
new String:g_sTriggerGroups[10][33];


/**
 * Plugin Forwards
 */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("IRC_Broadcast",          Native_Broadcast);
	CreateNative("IRC_GetAccess",          Native_GetAccess);
	CreateNative("IRC_GetClientName",      Native_GetClientName);
	CreateNative("IRC_GetTeamClientCount", Native_GetTeamClientCount);
	CreateNative("IRC_GetTeamCount",       Native_GetTeamCount);
	CreateNative("IRC_GetTeamName",        Native_GetTeamName);
	CreateNative("IRC_IsConnected",        Native_IsConnected);
	CreateNative("IRC_Notice",             Native_Notice);
	CreateNative("IRC_PrivMsg",            Native_PrivMsg);
	CreateNative("IRC_RegisterCommand",    Native_RegisterCommand);
	CreateNative("IRC_SendRaw",            Native_SendRaw);
	RegPluginLibrary("ircrelay");
	
	return APLRes_Success;
}

public OnPluginStart()
{
	// Create convars
	CreateConVar("sm_irc_version", IRC_VERSION, "IRC Relay for SourceMod", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_PLUGIN);
	g_hAuthPassword  = CreateConVar("irc_auth_password",  "",     "IRC Auth Password",  FCVAR_PLUGIN);
	g_hAuthString    = CreateConVar("irc_auth_string",    "",     "IRC Auth String",    FCVAR_PLUGIN);
	g_hAuthUsername  = CreateConVar("irc_auth_username",  "",     "IRC Auth Username",  FCVAR_PLUGIN);
	g_hColor         = CreateConVar("irc_color",          "1",    "IRC Color",          FCVAR_PLUGIN);
	g_hDebug         = CreateConVar("irc_debug",          "0",    "IRC Debug",          FCVAR_PLUGIN);
	g_hNickname      = CreateConVar("irc_nickname",       "",     "IRC Nickname",       FCVAR_PLUGIN);
	g_hPassword      = CreateConVar("irc_password",       "",     "IRC Password",       FCVAR_PLUGIN);
	g_hPort          = CreateConVar("irc_port",           "6667", "IRC Port",           FCVAR_PLUGIN);
	g_hServer        = CreateConVar("irc_server",         "",     "IRC Server",         FCVAR_PLUGIN);
	g_hTrigger       = CreateConVar("irc_trigger",        "",     "IRC Trigger",        FCVAR_PLUGIN);
	g_hTriggerGroups = CreateConVar("irc_trigger_groups", "all",  "IRC Trigger Groups", FCVAR_PLUGIN);
	
	// Create global forwards
	g_hOnConnect     = CreateGlobalForward("IRC_OnConnect",    ET_Ignore, Param_Cell);
	g_hOnDisconnect  = CreateGlobalForward("IRC_OnDisconnect", ET_Ignore);
	g_hOnError       = CreateGlobalForward("IRC_OnError",      ET_Ignore, Param_Cell, Param_Cell);
	g_hOnReceive     = CreateGlobalForward("IRC_OnReceive",    ET_Ignore, Param_String);
	
	// Create arrays and tries
	g_hChannels      = CreateArray(64);
	g_hCommands      = CreateArray(64);
	g_hModes         = CreateTrie();
	g_hQueue         = CreateArray(1024);
	
	// Create config parser
	g_hConfigParser  = SMC_CreateParser();
	SMC_SetReaders(g_hConfigParser, ReadConfig_NewSection, ReadConfig_KeyValue, ReadConfig_EndSection);
	
	// Hook convar changes
	HookConVarChange(g_hDebug,         ConVarChanged_ConVars);
	HookConVarChange(g_hColor,         ConVarChanged_ConVars);
	HookConVarChange(g_hNickname,      ConVarChanged_ConVars);
	HookConVarChange(g_hTrigger,       ConVarChanged_ConVars);
	HookConVarChange(g_hTriggerGroups, ConVarChanged_ConVars);
	
	// Store access modes
	SetTrieValue(g_hModes, "q", IrcAccess_Founder);
	SetTrieValue(g_hModes, "~", IrcAccess_Founder);
	SetTrieValue(g_hModes, "a", IrcAccess_SuperOp);
	SetTrieValue(g_hModes, "&", IrcAccess_SuperOp);
	SetTrieValue(g_hModes, "o", IrcAccess_Op);
	SetTrieValue(g_hModes, "@", IrcAccess_Op);
	SetTrieValue(g_hModes, "h", IrcAccess_HalfOp);
	SetTrieValue(g_hModes, "%", IrcAccess_HalfOp);
	SetTrieValue(g_hModes, "v", IrcAccess_Voice);
	SetTrieValue(g_hModes, "+", IrcAccess_Voice);
	SetTrieValue(g_hModes, "x", IrcAccess_Disabled);
	
	// Store mod
	decl String:sGameDesc[65], String:sGameDir[33];
	GetGameFolderName(sGameDir, sizeof(sGameDir));
	
	if(StrContains(sGameDir, "insurgency", false) != -1)
		g_iMod = Mod_Insurgency;
	else
	{
		GetGameDescription(sGameDesc, sizeof(sGameDesc));
		
		if(StrContains(sGameDesc, "Insurgency", false) != -1)
			g_iMod = Mod_Insurgency;
	}
	
	// Store server IP
	new iIp = GetConVarInt(FindConVar("hostip"));
	Format(g_sServerIp, sizeof(g_sServerIp), "%i.%i.%i.%i", (iIp >> 24) & 0x000000FF,
																													(iIp >> 16) & 0x000000FF,
																													(iIp >>  8) & 0x000000FF,
																													iIp         & 0x000000FF);
	
	CreateTimer(0.5, Timer_ProcessQueue, _, TIMER_REPEAT);
	
	LoadConfig();
	LoadConfig(sGameDir);
	IRC_RegisterCommand("commands", IrcCommand_Commands);
	IRC_RegisterCommand("version",  IrcCommand_Version);
	
	AutoExecConfig(true, "ircrelay");
}

public OnPluginEnd()
{
	if(IRC_IsConnected())
		SocketSend(g_hSocket, "QUIT :Plugin unloaded\r\n");
}

public OnConfigsExecuted()
{
	g_bColor = GetConVarBool(g_hColor);
	g_bDebug = GetConVarBool(g_hDebug);
	GetConVarString(g_hNickname,      g_sNickname,    sizeof(g_sNickname));
	GetConVarString(g_hTrigger,       g_sTrigger,     sizeof(g_sTrigger));
	
	decl String:sTriggerGroups[256];
	GetConVarString(g_hTriggerGroups, sTriggerGroups, sizeof(sTriggerGroups));
	g_iTriggerGroups = ExplodeString(sTriggerGroups, " ", g_sTriggerGroups, sizeof(g_sTriggerGroups), sizeof(g_sTriggerGroups[]));
	
	LoadTeamNames();
	
	if(IRC_IsConnected())
		return;
	
	decl String:sServer[32];
	GetConVarString(g_hServer, sServer, sizeof(sServer));
	
	g_hSocket = SocketCreate(SOCKET_TCP, OnSocketError);
	if(!g_hSocket)
	{
		LogError("Unable to create socket.");
		return;
	}
	
	SocketBind(g_hSocket, g_sServerIp, 0);
	SocketConnect(g_hSocket, OnSocketConnect, OnSocketReceive, OnSocketDisconnect, sServer, GetConVarInt(g_hPort));
}

public ConVarChanged_ConVars(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar      == g_hColor)
		g_bColor = bool:StringToInt(newValue);
	else if(convar == g_hDebug)
		g_bDebug = bool:StringToInt(newValue);
	else if(convar == g_hNickname)
		strcopy(g_sNickname, sizeof(g_sNickname), newValue);
	else if(convar == g_hTrigger)
		strcopy(g_sTrigger,  sizeof(g_sTrigger),  newValue);
	else if(convar == g_hTriggerGroups)
		g_iTriggerGroups = ExplodeString(newValue, " ", g_sTriggerGroups, sizeof(g_sTriggerGroups), sizeof(g_sTriggerGroups[]));
}


/**
 * Socket Callbacks
 */
public OnSocketConnect(Handle:socket, any:arg)
{
	decl String:sPassword[64];
	GetConVarString(g_hPassword, sPassword, sizeof(sPassword));
	
	if(sPassword[0])
		IRC_SendRaw("PASS %s", sPassword);
	
	IRC_SendRaw("USER %s %s %s :IRC Relay\r\nNICK %s", g_sTrigger, g_sTrigger, g_sTrigger, g_sNickname);
	
	Call_StartForward(g_hOnConnect);
	Call_PushCell(socket);
	Call_Finish();
}

public OnSocketDisconnect(Handle:socket, any:arg)
{
	g_hSocket = INVALID_HANDLE;
	
	Call_StartForward(g_hOnDisconnect);
	Call_Finish();
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:arg)
{
	g_hSocket = INVALID_HANDLE;
	
	LogError("Socket error %i (%i)", errorType, errorNum);
	
	Call_StartForward(g_hOnError);
	Call_PushCell(errorType);
	Call_PushCell(errorNum);
	Call_Finish();
}

public OnSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:arg)
{
	decl String:sLines[32][2048];
	for(new i = 0, iLines = ExplodeString(receiveData, "\r\n", sLines, sizeof(sLines), sizeof(sLines[])); i <= iLines; i++)
	{
		// If line is empty, ignore
		if(!sLines[i][0])
			continue;
		
		if(g_bDebug)
			PrintToServer("[IRC] Receive: %s", sLines[i]);
		
		decl iChannel, iStart, String:sData[256][256], String:sHost[2][32], String:sNickname[35];
		ExplodeString(sLines[i],   " ", sData, sizeof(sData), sizeof(sData[]));
		ExplodeString(sData[0][1], "!", sHost, sizeof(sHost), sizeof(sHost[]));
		Format(sNickname, sizeof(sNickname), ":%s!", g_sNickname);
		
		// Ping
		if(StrEqual(sData[0], "PING"))
			IRC_SendRaw("PONG %s", sData[1]);
		// If data applies to bot
		else if(strncmp(sData[0], sNickname, strlen(sNickname)) == 0)
		{
			// Join & Part
			if(StrEqual(sData[1], "JOIN") || StrEqual(sData[1], "PART"))
			{
				iChannel = FindStringInArray(g_hChannels, sData[2]);
				if(iChannel == -1)
					continue;
				
				ClearTrie(g_hChannelUsers[iChannel]);
			}
		}
		// Mode
		else if(StrEqual(sData[1], "MODE"))
		{
			// Find channel index
			iChannel = FindStringInArray(g_hChannels, sData[2]);
			if(iChannel == -1)
				continue;
			
			ClearTrie(g_hChannelUsers[iChannel]);
			IRC_SendRaw("NAMES %s", sData[2]);
		}
		// Nick
		else if(StrEqual(sData[1], "NICK"))
		{
			// Loop through channels
			for(new j = 0, IrcAccess:iAccess, iSize = GetArraySize(g_hChannels); j < iSize; j++)
			{
				// If this channel has no user with this nickname, ignore
				if(!GetTrieValue(g_hChannelUsers[j], sHost[0], iAccess))
					continue;
				
				// Store new nickname and remove old one
				SetTrieValue(g_hChannelUsers[j], sData[2][1], iAccess);
				RemoveFromTrie(g_hChannelUsers[j], sHost[0]);
			}
		}
		// PrivMsg
		else if(StrEqual(sData[1], "PRIVMSG"))
		{
			// CTCP
			if(sData[3][1] == '\001' && sData[3][strlen(sData[3]) - 1] == '\001')
			{
				// Version
				if(StrEqual(sData[3][1], "\001VERSION\001"))
					IRC_Notice(sHost[0], "\001VERSION IRC Relay %s\001", IRC_VERSION);
				continue;
			}
			
			// Find channel index
			iChannel = FindStringInArray(g_hChannels, sData[2]);
			if(iChannel == -1)
				continue;
			
			// If start of text does not equal trigger, ignore
			new iPos = StrContains(sLines[i][1], ":") + 2;
			iStart   = CheckForTrigger(sLines[i][iPos]);
			if(iStart == -1)
				continue;
			
			// Parse command and parameters
			decl String:sCommand[16];
			new iLen = BreakString(sLines[i][iPos + iStart], sCommand, sizeof(sCommand));
			
			// Find command index
			new iCommand = FindStringInArray(g_hCommands, sCommand);
			if(iCommand == -1)
				continue;
			
			// Get user access
			new IrcAccess:iAccess;
			GetTrieValue(g_hChannelUsers[iChannel], sHost[0], iAccess);
			
			// If user does not have access, ignore
			if(g_iCommandAccess[iCommand]  == IrcAccess_Disabled ||
			   (g_iCommandAccess[iCommand] != IrcAccess_None && iAccess < g_iCommandAccess[iCommand]))
			{
				IRC_PrivMsg(sData[2], "Access denied.");
				continue;
			}
			
			// Call command callback
			Call_StartFunction(g_hCommandPlugins[iCommand], g_fCommandCallbacks[iCommand]);
			Call_PushString(sData[2]);
			Call_PushString(sHost[0]);
			Call_PushString(sLines[i][iPos + iStart + iLen]);
			Call_Finish();
		}
		// Numeric Replies
		else
		{
			switch(StringToInt(sData[1]))
			{
				// Names
				case 353:
				{
					decl IrcAccess:iAccess, String:sMode[2];
					new iName = 4;
					iChannel = FindStringInArray(g_hChannels, sData[4]);
					if(iChannel == -1)
						continue;
					
					// For each name
					while(sData[++iName][0])
					{
						// Parse mode from name
						iStart = (sData[iName][0] == ':' ? 1 : 0);
						Format(sMode, sizeof(sMode), "%c", sData[iName][iStart]);
						
						// If mode is valid, add to users list
						if(!IsCharAlpha(sMode[0]) && (iAccess = IRC_GetAccess(sMode)) > IrcAccess_None)
							SetTrieValue(g_hChannelUsers[iChannel], sData[iName][iStart + 1], iAccess);
					}
				}
				// End Of MOTD, MOTD Missing
				case 376, 422:
				{
					// Authenticate to services
					decl String:sAuthPassword[64], String:sAuthString[128], String:sAuthUsername[64];
					GetConVarString(g_hAuthPassword, sAuthPassword, sizeof(sAuthPassword));
					GetConVarString(g_hAuthString,   sAuthString,   sizeof(sAuthString));
					GetConVarString(g_hAuthUsername, sAuthUsername, sizeof(sAuthUsername));
					
					if(sAuthPassword[0] && sAuthString[0] && sAuthUsername[0])
					{
						IRC_SendRaw(sAuthString, sAuthUsername, sAuthPassword);
						IRC_SendRaw("MODE %s +x", sData[2]);
					}
					
					// Join channels
					decl String:sChannel[32];
					for(new j = 0, iSize = GetArraySize(g_hChannels); j < iSize; j++)
					{
						GetArrayString(g_hChannels, j, sChannel, sizeof(sChannel));
						IRC_SendRaw("JOIN %s", sChannel);
					}
				}
			}
		}
		
		Call_StartForward(g_hOnReceive);
		Call_PushString(sLines[i]);
		Call_Finish();
	}
}


/**
 * IRC Commands
 */
public IrcCommand_Commands(const String:channel[], const String:name[], const String:command[])
{
	decl String:sCommand[32], String:sCommands[2048] = "";
	for(new i = 0, iSize = GetArraySize(g_hCommands); i < iSize; i++)
	{
		GetArrayString(g_hCommands, i, sCommand, sizeof(sCommand));
		StrCat(sCommands, sizeof(sCommands), ", ");
		StrCat(sCommands, sizeof(sCommands), sCommand);
	}
	
	IRC_PrivMsg(channel, "%cCommands:%c %s", IRC_BOLD, IRC_BOLD, sCommands[2]);
}

public IrcCommand_Version(const String:channel[], const String:name[], const String:command[])
{
	IRC_PrivMsg(channel, "%cVersion:%c %s %cBuilt:%c %s @ %s", IRC_BOLD, IRC_BOLD, IRC_VERSION, IRC_BOLD, IRC_BOLD, __DATE__, __TIME__);
}


/**
 * Natives
 */
public Native_Broadcast(Handle:plugin, numParams)
{
	decl String:sChannel[32], String:sText[256];
	FormatNativeString(0, 2, 3, sizeof(sText), _, sText);
	
	for(new i = 0, iSize = GetArraySize(g_hChannels), IrcChannel:iType = IrcChannel:GetNativeCell(1); i < iSize; i++)
	{
		if(iType != IrcChannel_Both && g_iChannelTypes[i] != iType)
			continue;
		
		GetArrayString(g_hChannels, i, sChannel, sizeof(sChannel));
		IRC_PrivMsg(sChannel, sText);
	}
}

public Native_GetAccess(Handle:plugin, numParams)
{
	decl String:sMode[2];
	GetNativeString(1, sMode, sizeof(sMode));
	
	new iAccess = _:IrcAccess_None;
	GetTrieValue(g_hModes, sMode, iAccess);
	return iAccess;
}

public Native_GetClientName(Handle:plugin, numParams)
{
	new iClient = GetNativeCell(1),
			iLen    = GetNativeCell(3),
			iTeam   = GetClientTeam(iClient);
	
	decl String:sBuffer[iLen], String:sName[MAX_NAME_LENGTH + 1];
	GetClientName(iClient, sName, sizeof(sName));
	
	if(g_bColor)
		Format(sBuffer, iLen, "%c%d%s%c", IRC_COLOR, g_iTeamColors[iTeam], sName, IRC_COLOR);
	else
		Format(sBuffer, iLen, "%s", sName);
	
	SetNativeString(2, sBuffer, iLen);
}

public Native_GetTeamClientCount(Handle:plugin, numParams)
{
	new iTeam = GetNativeCell(1);
	
	if(g_iMod == Mod_Insurgency)
	{
		new iClients = 0;
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == iTeam)
				iClients++;
		}
		return iClients;
	}
	else
		return GetTeamClientCount(iTeam);
}

public Native_GetTeamCount(Handle:plugin, numParams)
{
	if(g_iMod == Mod_Insurgency)
	{
		new iTeams = 0;
		while(g_sTeamNames[iTeams][0]) iTeams++;
		return iTeams;
	}
	else
		return GetTeamCount();
}

public Native_GetTeamName(Handle:plugin, numParams)
{
	new iLen  = GetNativeCell(3),
			iTeam = GetNativeCell(1);
	
	decl String:sBuffer[iLen];
	if(g_bColor)
		Format(sBuffer, iLen, "%c%d%s%c", IRC_COLOR, g_iTeamColors[iTeam], g_sTeamNames[iTeam], IRC_COLOR);
	else
		Format(sBuffer, iLen, "%s", g_sTeamNames[iTeam]);
	
	SetNativeString(2, sBuffer, iLen);
}

public Native_IsConnected(Handle:plugin, numParams)
{
	return g_hSocket && SocketIsConnected(g_hSocket);
}

public Native_Notice(Handle:plugin, numParams)
{
	decl String:sText[256], String:sName[32];
	GetNativeString(1, sName,   sizeof(sName));
	FormatNativeString(0, 2, 3, sizeof(sText), _, sText);
	
	IRC_SendRaw("NOTICE %s :%s", sName, sText);
}

public Native_PrivMsg(Handle:plugin, numParams)
{
	decl String:sText[256], String:sName[32];
	GetNativeString(1, sName,   sizeof(sName));
	FormatNativeString(0, 2, 3, sizeof(sText), _, sText);
	
	IRC_SendRaw("PRIVMSG %s :%s", sName, sText);
}

public Native_RegisterCommand(Handle:plugin, numParams)
{
	decl String:sName[32];
	GetNativeString(1, sName, sizeof(sName));
	
	new iCommand = FindStringInArray(g_hCommands, sName);
	if(iCommand == -1)
		iCommand = PushArrayString(g_hCommands, sName);
	
	g_iCommandAccess[iCommand]    = IrcAccess:GetNativeCell(3);
	g_fCommandCallbacks[iCommand] = Function:GetNativeCell(2);
	g_hCommandPlugins[iCommand]   = plugin;
}

public Native_SendRaw(Handle:plugin, numParams)
{
	decl String:sData[4096];
	FormatNativeString(0, 1, 2, sizeof(sData), _, sData);
	
	PushArrayString(g_hQueue, sData);
}


/**
 * Timers
 */
public Action:Timer_ProcessQueue(Handle:timer)
{
	if(!IRC_IsConnected() || !GetArraySize(g_hQueue))
		return;
	
	decl String:sData[4096];
	GetArrayString(g_hQueue, 0, sData, sizeof(sData));
	RemoveFromArray(g_hQueue, 0);
	
	if(g_bDebug)
		PrintToServer("[IRC] Send: %s", sData);
	
	Format(sData, sizeof(sData), "%s\r\n", sData);
	SocketSend(g_hSocket, sData);
}


/**
 * Config Parser
 */
public SMCResult:ReadConfig_EndSection(Handle:smc)
{
	return SMCParse_Continue;
}

public SMCResult:ReadConfig_KeyValue(Handle:smc, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
	if(!key[0] || !value[0])
		return SMCParse_Continue;
	
	if(g_iConfig      == Config_Channels)
	{
		new iChannel              = PushArrayString(g_hChannels, key);
		g_hChannelUsers[iChannel] = CreateTrie();
		
		if(StrEqual(value, "private"))
			g_iChannelTypes[iChannel] = IrcChannel_Private;
		else if(StrEqual(value, "public"))
			g_iChannelTypes[iChannel] = IrcChannel_Public;
	}
	else if(g_iConfig == Config_TeamColors)
		g_iTeamColors[StringToInt(key)] = StringToInt(value);
	
	return SMCParse_Continue;
}

public SMCResult:ReadConfig_NewSection(Handle:smc, const String:name[], bool:opt_quotes)
{
	if(StrEqual(name,      "Channels"))
		g_iConfig = Config_Channels;
	else if(StrEqual(name, "TeamColors"))
		g_iConfig = Config_TeamColors;
	
	return SMCParse_Continue;
}


/**
 * Stocks
 */
CheckForTrigger(const String:text[])
{
	// Get trigger name and check for single trigger
	decl String:sTrigger[35];
	Format(sTrigger, sizeof(sTrigger), "!%s.", g_sTrigger);
	if(strncmp(text, sTrigger, strlen(sTrigger)) == 0)
		return strlen(sTrigger);
	
	// Get trigger groups and check for group trigger
	for(new i = 0; i <= g_iTriggerGroups; i++)
	{
		if(!g_sTriggerGroups[i][0])
			continue;
		
		Format(sTrigger, sizeof(sTrigger), "@%s.", g_sTriggerGroups[i]);
		if(strncmp(text, sTrigger, strlen(sTrigger)) == 0)
			return strlen(sTrigger);
	}
	
	return -1;
}

LoadConfig(const String:name[] = "default")
{
	decl String:sPath[PLATFORM_MAX_PATH + 1];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/ircrelay/%s.cfg", name);
	
	if(!FileExists(sPath))
	{
		if(StrEqual(name, "default"))
			SetFailState("File not found: %s", sPath);
		return;
	}
	
	// Parse config file
	new SMCError:iError = SMC_ParseFile(g_hConfigParser, sPath);
	if(iError          != SMCError_Okay)
	{
		decl String:sError[64];
		if(SMC_GetErrorString(iError, sError, sizeof(sError)))
			LogError(sError);
		else
			LogError("Fatal parse error");
	}
}

LoadTeamNames()
{
	if(g_iMod == Mod_Insurgency)
	{
		decl String:sMap[32];
		GetCurrentMap(sMap, sizeof(sMap));
		
		if(StrEqual(sMap, "ins_baghdad") || StrEqual(sMap, "ins_karam"))
		{
			g_sTeamNames[1] = "Iraqi Insurgents";
			g_sTeamNames[2] = "U.S. Marines";
		}
		else
		{
			g_sTeamNames[1] = "U.S. Marines";
			g_sTeamNames[2] = "Iraqi Insurgents";
		}
		
		g_sTeamNames[0] = "Unassigned";
		g_sTeamNames[3] = "Spectator";
	}
	else
	{
		for(new i = GetTeamCount() - 1; i >= 0; i--)
			GetTeamName(i, g_sTeamNames[i], sizeof(g_sTeamNames[]));
	}
}