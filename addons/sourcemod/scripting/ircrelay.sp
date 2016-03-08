#include <sourcemod>
#include <sdktools>
#include <socket>
#include <ircrelay>

#pragma dynamic 65536
#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
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

int g_iTeamColors[8];
int g_iTriggerGroups;
bool g_bDebug;
bool g_bColor;
Config g_iConfig;
Function g_fCommandCallbacks[64];
ConVar g_hAuthPassword;
ConVar g_hAuthString;
ConVar g_hAuthUsername;
ArrayList g_hChannels;
StringMap g_hChannelUsers[64];
ArrayList g_hCommands;
Handle g_hCommandPlugins[64];
SMCParser g_hConfigParser;
ConVar g_hColor;
ConVar g_hDebug;
ConVar g_hNickname;
ConVar g_hPassword;
ConVar g_hPort;
ArrayList g_hQueue;
ConVar g_hServer;
ConVar g_hTrigger;
ConVar g_hTriggerGroups;
StringMap g_hModes;
Handle g_hOnConnect;
Handle g_hOnDisconnect;
Handle g_hOnError;
Handle g_hOnReceive;
Handle g_hSocket;
IrcAccess g_iCommandAccess[64];
IrcChannel g_iChannelTypes[64];
Mod g_iMod = Mod_Default;
char g_sNickname[33];
char g_sServerIp[16];
char g_sTeamNames[8][33];
char g_sTrigger[33];
char g_sTriggerGroups[10][33];


/**
 * Plugin Forwards
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
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

public void OnPluginStart()
{
    // Create convars
    CreateConVar("sm_irc_version", IRC_VERSION, "IRC Relay for SourceMod", FCVAR_NOTIFY);
    g_hAuthPassword  = CreateConVar("irc_auth_password",  "",     "IRC Auth Password");
    g_hAuthString    = CreateConVar("irc_auth_string",    "",     "IRC Auth String");
    g_hAuthUsername  = CreateConVar("irc_auth_username",  "",     "IRC Auth Username");
    g_hColor         = CreateConVar("irc_color",          "1",    "IRC Color");
    g_hDebug         = CreateConVar("irc_debug",          "0",    "IRC Debug");
    g_hNickname      = CreateConVar("irc_nickname",       "",     "IRC Nickname");
    g_hPassword      = CreateConVar("irc_password",       "",     "IRC Password");
    g_hPort          = CreateConVar("irc_port",           "6667", "IRC Port");
    g_hServer        = CreateConVar("irc_server",         "",     "IRC Server");
    g_hTrigger       = CreateConVar("irc_trigger",        "",     "IRC Trigger");
    g_hTriggerGroups = CreateConVar("irc_trigger_groups", "all",  "IRC Trigger Groups");

    // Create global forwards
    g_hOnConnect     = CreateGlobalForward("IRC_OnConnect",    ET_Ignore, Param_Cell);
    g_hOnDisconnect  = CreateGlobalForward("IRC_OnDisconnect", ET_Ignore);
    g_hOnError       = CreateGlobalForward("IRC_OnError",      ET_Ignore, Param_Cell, Param_Cell);
    g_hOnReceive     = CreateGlobalForward("IRC_OnReceive",    ET_Ignore, Param_String);

    // Create arrays and tries
    g_hChannels      = new ArrayList(64);
    g_hCommands      = new ArrayList(64);
    g_hModes         = new StringMap();
    g_hQueue         = new ArrayList(1024);

    // Create config parser
    g_hConfigParser  = new SMCParser();
    g_hConfigParser.OnEnterSection = ReadConfig_NewSection;
    g_hConfigParser.OnKeyValue     = ReadConfig_KeyValue;
    g_hConfigParser.OnLeaveSection = ReadConfig_EndSection;

    // Hook convar changes
    g_hDebug.AddChangeHook(ConVarChanged_ConVars);
    g_hColor.AddChangeHook(ConVarChanged_ConVars);
    g_hNickname.AddChangeHook(ConVarChanged_ConVars);
    g_hTrigger.AddChangeHook(ConVarChanged_ConVars);
    g_hTriggerGroups.AddChangeHook(ConVarChanged_ConVars);

    // Store access modes
    g_hModes.SetValue("q", IrcAccess_Founder);
    g_hModes.SetValue("~", IrcAccess_Founder);
    g_hModes.SetValue("a", IrcAccess_SuperOp);
    g_hModes.SetValue("&", IrcAccess_SuperOp);
    g_hModes.SetValue("o", IrcAccess_Op);
    g_hModes.SetValue("@", IrcAccess_Op);
    g_hModes.SetValue("h", IrcAccess_HalfOp);
    g_hModes.SetValue("%", IrcAccess_HalfOp);
    g_hModes.SetValue("v", IrcAccess_Voice);
    g_hModes.SetValue("+", IrcAccess_Voice);
    g_hModes.SetValue("x", IrcAccess_Disabled);

    // Store mod
    char sGameDesc[65], sGameDir[33];
    GetGameFolderName(sGameDir, sizeof(sGameDir));

    if (StrContains(sGameDir, "insurgency", false) != -1) {
        g_iMod = Mod_Insurgency;
    } else {
        GetGameDescription(sGameDesc, sizeof(sGameDesc));

        if (StrContains(sGameDesc, "Insurgency", false) != -1) {
            g_iMod = Mod_Insurgency;
        }
    }

    // Store server IP
    int iServerIp = FindConVar("hostip").IntValue;
    Format(g_sServerIp, sizeof(g_sServerIp), "%i.%i.%i.%i", (iServerIp >> 24) & 0x000000FF,
                                                            (iServerIp >> 16) & 0x000000FF,
                                                            (iServerIp >>  8) & 0x000000FF,
                                                            iServerIp         & 0x000000FF);

    CreateTimer(0.5, Timer_ProcessQueue, _, TIMER_REPEAT);

    LoadConfig();
    LoadConfig(sGameDir);
    IRC_RegisterCommand("commands", IrcCommand_Commands);
    IRC_RegisterCommand("version",  IrcCommand_Version);

    AutoExecConfig(true, "ircrelay");
}

public void OnPluginEnd()
{
    if (IRC_IsConnected()) {
        SocketSend(g_hSocket, "QUIT :Plugin unloaded\r\n");
    }
}

public void OnConfigsExecuted()
{
    g_bColor = g_hColor.BoolValue;
    g_bDebug = g_hDebug.BoolValue;
    g_hNickname.GetString(g_sNickname, sizeof(g_sNickname));
    g_hTrigger.GetString(g_sTrigger,   sizeof(g_sTrigger));

    char sTriggerGroups[256];
    g_hTriggerGroups.GetString(sTriggerGroups, sizeof(sTriggerGroups));
    g_iTriggerGroups = ExplodeString(sTriggerGroups, " ", g_sTriggerGroups, sizeof(g_sTriggerGroups), sizeof(g_sTriggerGroups[]));

    LoadTeamNames();

    if (IRC_IsConnected()) {
        return;
    }

    char sServer[32];
    g_hServer.GetString(sServer, sizeof(sServer));

    g_hSocket = SocketCreate(SOCKET_TCP, OnSocketError);
    if (!g_hSocket) {
        LogError("Unable to create socket.");
        return;
    }

    SocketBind(g_hSocket, g_sServerIp, 0);
    SocketConnect(g_hSocket, OnSocketConnect, OnSocketReceive, OnSocketDisconnect, sServer, g_hPort.IntValue);
}

public void ConVarChanged_ConVars(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar      == g_hColor) {
        g_bColor = view_as<bool>(StringToInt(newValue));
    }
    else if (convar == g_hDebug) {
        g_bDebug = view_as<bool>(StringToInt(newValue));
    }
    else if (convar == g_hNickname) {
        strcopy(g_sNickname, sizeof(g_sNickname), newValue);
    }
    else if (convar == g_hTrigger) {
        strcopy(g_sTrigger,  sizeof(g_sTrigger),  newValue);
    }
    else if (convar == g_hTriggerGroups) {
        g_iTriggerGroups = ExplodeString(newValue, " ", g_sTriggerGroups, sizeof(g_sTriggerGroups), sizeof(g_sTriggerGroups[]));
    }
}


/**
 * Socket Callbacks
 */
public int OnSocketConnect(Handle socket, any arg)
{
    char sPassword[64];
    g_hPassword.GetString(sPassword, sizeof(sPassword));

    if (sPassword[0]) {
        IRC_SendRaw("PASS %s", sPassword);
    }

    IRC_SendRaw("USER %s %s %s :IRC Relay\r\nNICK %s", g_sTrigger, g_sTrigger, g_sTrigger, g_sNickname);

    Call_StartForward(g_hOnConnect);
    Call_PushCell(socket);
    Call_Finish();
}

public int OnSocketDisconnect(Handle socket, any arg)
{
    g_hSocket = INVALID_HANDLE;

    Call_StartForward(g_hOnDisconnect);
    Call_Finish();
}

public int OnSocketError(Handle socket, const int errorType, const int errorNum, any arg)
{
    g_hSocket = INVALID_HANDLE;

    LogError("Socket error %i (%i)", errorType, errorNum);

    Call_StartForward(g_hOnError);
    Call_PushCell(errorType);
    Call_PushCell(errorNum);
    Call_Finish();
}

public int OnSocketReceive(Handle socket, char[] receiveData, const int dataSize, any arg)
{
    char sLines[32][2048];
    for (int i = 0, iLines = ExplodeString(receiveData, "\r\n", sLines, sizeof(sLines), sizeof(sLines[])); i <= iLines; i++) {
        // If line is empty, ignore
        if (!sLines[i][0]) {
            continue;
        }

        if (g_bDebug) {
            PrintToServer("[IRC] Receive: %s", sLines[i]);
        }

        int iChannel, iStart;
        char sData[256][256], sHost[2][32], sNickname[35];
        ExplodeString(sLines[i],   " ", sData, sizeof(sData), sizeof(sData[]));
        ExplodeString(sData[0][1], "!", sHost, sizeof(sHost), sizeof(sHost[]));
        Format(sNickname, sizeof(sNickname), ":%s!", g_sNickname);

        // Ping
        if (StrEqual(sData[0], "PING")) {
            IRC_SendRaw("PONG %s", sData[1]);
        }
        // If data applies to bot
        else if (strncmp(sData[0], sNickname, strlen(sNickname)) == 0) {
            // Join & Part
            if (StrEqual(sData[1], "JOIN") || StrEqual(sData[1], "PART")) {
                iChannel = g_hChannels.FindString(sData[2]);
                if (iChannel == -1) {
                    continue;
                }

                g_hChannelUsers[iChannel].Clear();
            }
        }
        // Mode
        else if (StrEqual(sData[1], "MODE")) {
            // Find channel index
            iChannel = g_hChannels.FindString(sData[2]);
            if (iChannel == -1) {
                continue;
            }

            g_hChannelUsers[iChannel].Clear();
            IRC_SendRaw("NAMES %s", sData[2]);
        }
        // Nick
        else if (StrEqual(sData[1], "NICK")) {
            // Loop through channels
            IrcAccess iAccess;
            for (int j = 0, iSize = g_hChannels.Length; j < iSize; j++) {
                // If this channel has no user with this nickname, ignore
                if (!g_hChannelUsers[j].GetValue(sHost[0], iAccess)) {
                    continue;
                }

                // Store new nickname and remove old one
                g_hChannelUsers[j].SetValue(sData[2][1], iAccess);
                g_hChannelUsers[j].Remove(sHost[0]);
            }
        }
        // PrivMsg
        else if (StrEqual(sData[1], "PRIVMSG")) {
            // CTCP
            if (sData[3][1] == '\001' && sData[3][strlen(sData[3]) - 1] == '\001') {
                // Version
                if (StrEqual(sData[3][1], "\001VERSION\001")) {
                    IRC_Notice(sHost[0], "\001VERSION IRC Relay %s\001", IRC_VERSION);
                }
                continue;
            }

            // Find channel index
            iChannel = g_hChannels.FindString(sData[2]);
            if (iChannel == -1) {
                continue;
            }

            // If start of text does not equal trigger, ignore
            int iPos = StrContains(sLines[i][1], ":") + 2;
            iStart   = CheckForTrigger(sLines[i][iPos]);
            if (iStart == -1) {
                continue;
            }

            // Parse command and parameters
            char sCommand[16];
            int iLen = BreakString(sLines[i][iPos + iStart], sCommand, sizeof(sCommand));

            // Find command index
            int iCommand = g_hCommands.FindString(sCommand);
            if (iCommand == -1) {
                continue;
            }

            // Get user access
            IrcAccess iAccess;
            g_hChannelUsers[iChannel].GetValue(sHost[0], iAccess);

            // If user does not have access, ignore
            if (g_iCommandAccess[iCommand]  == IrcAccess_Disabled ||
                (g_iCommandAccess[iCommand] != IrcAccess_None && iAccess < g_iCommandAccess[iCommand])) {
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
        else {
            switch (StringToInt(sData[1])) {
                // Names
                case 353:
                {
                    char sMode[2];
                    IrcAccess iAccess;
                    int iName = 4;
                    iChannel = g_hChannels.FindString(sData[4]);
                    if (iChannel == -1) {
                        continue;
                    }

                    // For each name
                    while (sData[++iName][0]) {
                        // Parse mode from name
                        iStart = (sData[iName][0] == ':' ? 1 : 0);
                        Format(sMode, sizeof(sMode), "%c", sData[iName][iStart]);

                        // If mode is valid, add to users list
                        if (!IsCharAlpha(sMode[0]) && (iAccess = IRC_GetAccess(sMode)) > IrcAccess_None) {
                            g_hChannelUsers[iChannel].SetValue(sData[iName][iStart + 1], iAccess);
                        }
                    }
                }
                // End Of MOTD, MOTD Missing
                case 376, 422:
                {
                    // Authenticate to services
                    char sAuthPassword[64], sAuthString[128], sAuthUsername[64];
                    g_hAuthPassword.GetString(sAuthPassword, sizeof(sAuthPassword));
                    g_hAuthString.GetString(sAuthString,     sizeof(sAuthString));
                    g_hAuthUsername.GetString(sAuthUsername, sizeof(sAuthUsername));

                    if (sAuthPassword[0] && sAuthString[0] && sAuthUsername[0]) {
                        IRC_SendRaw(sAuthString, sAuthUsername, sAuthPassword);
                        IRC_SendRaw("MODE %s +x", sData[2]);
                    }

                    // Join channels
                    char sChannel[32];
                    for (int j = 0, iSize = g_hChannels.Length; j < iSize; j++) {
                        g_hChannels.GetString(j, sChannel, sizeof(sChannel));
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
public void IrcCommand_Commands(const char[] channel, const char[] name, const char[] arg)
{
    char sCommand[32], sCommands[2048] = "";
    for (int i = 0, iSize = g_hCommands.Length; i < iSize; i++) {
        g_hCommands.GetString(i, sCommand, sizeof(sCommand));
        StrCat(sCommands, sizeof(sCommands), ", ");
        StrCat(sCommands, sizeof(sCommands), sCommand);
    }

    IRC_PrivMsg(channel, "%cCommands:%c %s", IRC_BOLD, IRC_BOLD, sCommands[2]); // Skip the ', ' from the front
}

public void IrcCommand_Version(const char[] channel, const char[] name, const char[] arg)
{
    IRC_PrivMsg(channel, "%cVersion:%c %s %cBuilt:%c %s @ %s", IRC_BOLD, IRC_BOLD, IRC_VERSION, IRC_BOLD, IRC_BOLD, __DATE__, __TIME__);
}


/**
 * Natives
 */
public int Native_Broadcast(Handle plugin, int numParams)
{
    char sChannel[32], sText[256];
    IrcChannel iType = GetNativeCell(1);
    FormatNativeString(0, 2, 3, sizeof(sText), _, sText);

    for (int i = 0, iSize = g_hChannels.Length; i < iSize; i++) {
        if (iType != IrcChannel_Both && g_iChannelTypes[i] != iType) {
            continue;
        }

        g_hChannels.GetString(i, sChannel, sizeof(sChannel));
        IRC_PrivMsg(sChannel, sText);
    }
}

public int Native_GetAccess(Handle plugin, int numParams)
{
    char sMode[2];
    GetNativeString(1, sMode, sizeof(sMode));

    IrcAccess iAccess = IrcAccess_None;
    g_hModes.GetValue(sMode, iAccess);
    return view_as<int>(iAccess);
}

public int Native_GetClientName(Handle plugin, int numParams)
{
    int iClient = GetNativeCell(1),
        iLen    = GetNativeCell(3),
        iTeam   = GetClientTeam(iClient);

    char[] sBuffer = new char[iLen];
    char sName[MAX_NAME_LENGTH + 1];
    GetClientName(iClient, sName, sizeof(sName));

    if (g_bColor) {
        Format(sBuffer, iLen, "%c%d%s%c", IRC_COLOR, g_iTeamColors[iTeam], sName, IRC_COLOR);
    } else {
        Format(sBuffer, iLen, "%s", sName);
    }

    SetNativeString(2, sBuffer, iLen);
}

public int Native_GetTeamClientCount(Handle plugin, int numParams)
{
    int iTeam = GetNativeCell(1);

    if (g_iMod == Mod_Insurgency) {
        int iClients = 0;
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && GetClientTeam(i) == iTeam) {
                iClients++;
            }
        }
        return iClients;
    }

    return GetTeamClientCount(iTeam);
}

public int Native_GetTeamCount(Handle plugin, int numParams)
{
    if (g_iMod == Mod_Insurgency) {
        int iTeams = 0;
        while (g_sTeamNames[iTeams][0]) iTeams++;
        return iTeams;
    }

    return GetTeamCount();
}

public int Native_GetTeamName(Handle plugin, int numParams)
{
    int iLen  = GetNativeCell(3),
        iTeam = GetNativeCell(1);

    char[] sBuffer = new char[iLen];
    if (g_bColor) {
        Format(sBuffer, iLen, "%c%d%s%c", IRC_COLOR, g_iTeamColors[iTeam], g_sTeamNames[iTeam], IRC_COLOR);
    } else {
        Format(sBuffer, iLen, "%s", g_sTeamNames[iTeam]);
    }

    SetNativeString(2, sBuffer, iLen);
}

public int Native_IsConnected(Handle plugin, int numParams)
{
    return g_hSocket && SocketIsConnected(g_hSocket);
}

public int Native_Notice(Handle plugin, int numParams)
{
    char sText[256], sName[32];
    GetNativeString(1, sName,   sizeof(sName));
    FormatNativeString(0, 2, 3, sizeof(sText), _, sText);

    IRC_SendRaw("NOTICE %s :%s", sName, sText);
}

public int Native_PrivMsg(Handle plugin, int numParams)
{
    char sText[256], sName[32];
    GetNativeString(1, sName,   sizeof(sName));
    FormatNativeString(0, 2, 3, sizeof(sText), _, sText);

    IRC_SendRaw("PRIVMSG %s :%s", sName, sText);
}

public int Native_RegisterCommand(Handle plugin, int numParams)
{
    char sName[32];
    GetNativeString(1, sName, sizeof(sName));

    int iCommand = g_hCommands.FindString(sName);
    if (iCommand == -1) {
        iCommand = g_hCommands.PushString(sName);
    }

    g_iCommandAccess[iCommand]    = GetNativeCell(3);
    g_fCommandCallbacks[iCommand] = GetNativeCell(2);
    g_hCommandPlugins[iCommand]   = plugin;
}

public int Native_SendRaw(Handle plugin, int numParams)
{
    char sData[4096];
    FormatNativeString(0, 1, 2, sizeof(sData), _, sData);

    g_hQueue.PushString(sData);
}


/**
 * Timers
 */
public Action Timer_ProcessQueue(Handle timer)
{
    if (!IRC_IsConnected() || !g_hQueue.Length) {
        return;
    }

    char sData[4096];
    g_hQueue.GetString(0, sData, sizeof(sData));
    g_hQueue.Erase(0);

    if (g_bDebug) {
        PrintToServer("[IRC] Send: %s", sData);
    }

    Format(sData, sizeof(sData), "%s\r\n", sData);
    SocketSend(g_hSocket, sData);
}


/**
 * Config Parser
 */
public SMCResult ReadConfig_EndSection(SMCParser smc)
{
    return SMCParse_Continue;
}

public SMCResult ReadConfig_KeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
    if (!key[0] || !value[0]) {
        return SMCParse_Continue;
    }

    if (g_iConfig      == Config_Channels) {
        int iChannel              = g_hChannels.PushString(key);
        g_hChannelUsers[iChannel] = new StringMap();

        if (StrEqual(value, "private")) {
            g_iChannelTypes[iChannel] = IrcChannel_Private;
        }
        else if (StrEqual(value, "public")) {
            g_iChannelTypes[iChannel] = IrcChannel_Public;
        }
    }
    else if (g_iConfig == Config_TeamColors) {
        g_iTeamColors[StringToInt(key)] = StringToInt(value);
    }

    return SMCParse_Continue;
}

public SMCResult ReadConfig_NewSection(SMCParser smc, const char[] name, bool opt_quotes)
{
    if (StrEqual(name,      "Channels")) {
        g_iConfig = Config_Channels;
    }
    else if (StrEqual(name, "TeamColors")) {
        g_iConfig = Config_TeamColors;
    }

    return SMCParse_Continue;
}


/**
 * Stocks
 */
int CheckForTrigger(const char[] text)
{
    // Get trigger name and check for single trigger
    char sTrigger[35];
    Format(sTrigger, sizeof(sTrigger), "!%s.", g_sTrigger);
    if (strncmp(text, sTrigger, strlen(sTrigger)) == 0) {
        return strlen(sTrigger);
    }

    // Get trigger groups and check for group trigger
    for (int i = 0; i <= g_iTriggerGroups; i++) {
        if (!g_sTriggerGroups[i][0]) {
            continue;
        }

        Format(sTrigger, sizeof(sTrigger), "@%s.", g_sTriggerGroups[i]);
        if (strncmp(text, sTrigger, strlen(sTrigger)) == 0) {
            return strlen(sTrigger);
        }
    }

    return -1;
}

void LoadConfig(const char[] name = "default")
{
    char sPath[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/ircrelay/%s.cfg", name);

    if (!FileExists(sPath)) {
        if (StrEqual(name, "default")) {
            SetFailState("File not found: %s", sPath);
        }
        return;
    }

    // Parse config file
    SMCError iError = g_hConfigParser.ParseFile(sPath);
    if (iError     != SMCError_Okay) {
        char sError[64] = "Fatal parse error";
        SMC_GetErrorString(iError, sError, sizeof(sError));
        LogError(sError);
    }
}

void LoadTeamNames()
{
    if (g_iMod == Mod_Insurgency) {
        char sMap[32];
        GetCurrentMap(sMap, sizeof(sMap));

        if (StrEqual(sMap, "ins_baghdad") || StrEqual(sMap, "ins_karam")) {
            g_sTeamNames[1] = "Iraqi Insurgents";
            g_sTeamNames[2] = "U.S. Marines";
        } else {
            g_sTeamNames[1] = "U.S. Marines";
            g_sTeamNames[2] = "Iraqi Insurgents";
        }

        g_sTeamNames[0] = "Unassigned";
        g_sTeamNames[3] = "Spectator";
    } else {
        for (int i = GetTeamCount() - 1; i >= 0; i--) {
            GetTeamName(i, g_sTeamNames[i], sizeof(g_sTeamNames[]));
        }
    }
}
