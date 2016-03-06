#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <ircrelay>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
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
ConVar g_hXsBan;
ConVar g_hXsKick;
ConVar g_hXsRcon;


/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
    // Create convars
    g_hXsBan  = CreateConVar("irc_xs_ban",  "o", "Access level needed for ban command");
    g_hXsKick = CreateConVar("irc_xs_kick", "o", "Access level needed for kick command");
    g_hXsRcon = CreateConVar("irc_xs_rcon", "o", "Access level needed for rcon command");

    // Hook convar changes
    g_hXsBan.AddChangeHook(ConVarChanged_ConVars);
    g_hXsKick.AddChangeHook(ConVarChanged_ConVars);
    g_hXsRcon.AddChangeHook(ConVarChanged_ConVars);

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

    char sXsBan[2], sXsKick[2], sXsRcon[2];
    g_hXsBan.GetString(sXsBan,   sizeof(sXsBan));
    g_hXsKick.GetString(sXsKick, sizeof(sXsKick));
    g_hXsRcon.GetString(sXsRcon, sizeof(sXsRcon));

    IRC_RegisterCommand("ban",  IrcCommand_Ban,  IRC_GetAccess(sXsBan));
    IRC_RegisterCommand("kick", IrcCommand_Kick, IRC_GetAccess(sXsKick));
    IRC_RegisterCommand("rcon", IrcCommand_Rcon, IRC_GetAccess(sXsRcon));
}

public void ConVarChanged_ConVars(ConVar convar, const char[] oldValue, const char[] newValue)
{
    OnLibraryAdded("ircrelay");
}


/**
 * IRC Commands
 */
public void IrcCommand_Ban(const char[] channel, const char[] name, const char[] arg)
{
    char sTarget[MAX_NAME_LENGTH + 1], sTime[12];
    int iLen    = BreakString(arg, sTarget, sizeof(sTarget)),
        iTarget = FindTarget(0, sTarget);

    if (iTarget == -1) {
        IRC_PrivMsg(channel, "Invalid player specified.");
        return;
    }

    iLen += BreakString(arg[iLen], sTime, sizeof(sTime));
    BanClient(iTarget, StringToInt(sTime), BANFLAG_AUTO, arg[iLen], _, "ircrelay");
}

public void IrcCommand_Kick(const char[] channel, const char[] name, const char[] arg)
{
    char sTarget[MAX_NAME_LENGTH + 1];
    int iLen    = BreakString(arg, sTarget, sizeof(sTarget)),
        iTarget = FindTarget(0, sTarget);

    if (iTarget == -1) {
        IRC_PrivMsg(channel, "Invalid player specified.");
        return;
    }

    KickClient(iTarget, arg[iLen]);
}

public void IrcCommand_Rcon(const char[] channel, const char[] name, const char[] arg)
{
    ServerCommand(arg);
    IRC_PrivMsg(channel, "RCON: %s", arg);
}
