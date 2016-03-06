#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <ircrelay>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
    name        = "IRC Relay - Chat Module",
    author      = "GameConnect",
    description = "IRC Relay for SourceMod",
    version     = IRC_VERSION,
    url         = "http://www.gameconnect.net"
};


/**
 * Globals
 */
IrcChannel g_iChatRelayType;
IrcChannel g_iMessageRelayType;
ConVar g_hChatRelayType;
ConVar g_hMessageRelayType;
ConVar g_hXsMsg;
ConVar g_hXsPage;


/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
    // Create convars
    g_hChatRelayType    = CreateConVar("irc_chat_relaytype",    "0", "Channel type to relay chat to. (0 = off, 1 = public, 2 = private, 3 = both)");
    g_hMessageRelayType = CreateConVar("irc_message_relaytype", "1", "Channel type to relay /irc messages to. (0 = off, 1 = public, 2 = private, 3 = both)");
    g_hXsMsg            = CreateConVar("irc_xs_msg",            "v", "Access level needed for msg command");
    g_hXsPage           = CreateConVar("irc_xs_page",           "v", "Access level needed for page command");

    // Hook convar changes
    g_hChatRelayType.AddChangeHook(ConVarChanged_ConVars);
    g_hMessageRelayType.AddChangeHook(ConVarChanged_ConVars);
    g_hXsMsg.AddChangeHook(ConVarChanged_ConVars);
    g_hXsPage.AddChangeHook(ConVarChanged_ConVars);

    LoadTranslations("common.phrases");

    if (LibraryExists("ircrelay")) {
        OnLibraryAdded("ircrelay");
    }
}

public void OnLibraryAdded(const char[] name)
{
    if (!StrEqual(name, "ircrelay")) {
        return;
    }

    g_iChatRelayType    = view_as<IrcChannel>(g_hChatRelayType.IntValue);
    g_iMessageRelayType = view_as<IrcChannel>(g_hMessageRelayType.IntValue);

    char sXsMsg[2], sXsPage[2];
    g_hXsMsg.GetString(sXsMsg,   sizeof(sXsMsg));
    g_hXsPage.GetString(sXsPage, sizeof(sXsPage));

    IRC_RegisterCommand("msg",  IrcCommand_Msg,  IRC_GetAccess(sXsMsg));
    IRC_RegisterCommand("page", IrcCommand_Page, IRC_GetAccess(sXsPage));
}

public void ConVarChanged_ConVars(ConVar convar, const char[] oldValue, const char[] newValue)
{
    OnLibraryAdded("ircrelay");
}


/**
 * IRC Commands
 */
public void IrcCommand_Msg(const char[] channel, const char[] name, const char[] arg)
{
    PrintToChatAll("%c[IRC]%c %s: %s", CLR_GREEN, CLR_DEFAULT, name, arg);
    IRC_PrivMsg(channel, "(IRC) %s: %s", name, arg);
}

public void IrcCommand_Page(const char[] channel, const char[] name, const char[] arg)
{
    char sName[MAX_NAME_LENGTH + 1], sTarget[MAX_NAME_LENGTH + 1];
    int iLen    = BreakString(arg, sTarget, sizeof(sTarget)),
        iTarget = FindTarget(0, sTarget);

    if (iTarget == -1) {
        IRC_PrivMsg(channel, "Invalid player specified.");
        return;
    }

    IRC_GetClientName(iTarget, sName, sizeof(sName));

    PrintToChat(iTarget, "%c[IRC]%c (Private) %s: %s", CLR_GREEN, CLR_DEFAULT, name, arg[iLen]);
    IRC_PrivMsg(channel, "Page sent to %s: %s", sName, arg[iLen]);
}


/**
 * Commands
 */
public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
    if (!client) {
        return Plugin_Continue;
    }

    char sName[MAX_NAME_LENGTH + 1];
    IRC_GetClientName(client, sName, sizeof(sName));

    if (g_iMessageRelayType && strncmp(sArgs, "/irc", 4) == 0) {
        if (!sArgs[4]) {
            PrintToChat(client, "%c[IRC]%c You must enter a message to send", CLR_GREEN, CLR_DEFAULT);
            return Plugin_Handled;
        }

        IRC_Broadcast(g_iMessageRelayType, "(%s): %s", sName, sArgs[4]);
        PrintToChat(client, "%c[IRC]%c Your message was sent!", CLR_GREEN, CLR_DEFAULT);
        return Plugin_Handled;
    }
    if (g_iChatRelayType) {
        IRC_Broadcast(g_iChatRelayType, "%s: %s", sName, sArgs);
    }

    return Plugin_Continue;
}
