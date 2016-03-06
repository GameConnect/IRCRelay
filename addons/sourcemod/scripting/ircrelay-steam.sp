#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <ircrelay>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
    name        = "IRC Relay - Steam Module",
    author      = "GameConnect",
    description = "IRC Relay for SourceMod",
    version     = IRC_VERSION,
    url         = "http://www.gameconnect.net"
};

/**
 * Globals
 */
ConVar g_hXsProfile;
ConVar g_hXsSteam;


/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
    g_hXsProfile = CreateConVar("irc_xs_profile", "", "Access level needed for profile command");
    g_hXsSteam   = CreateConVar("irc_xs_steam",   "", "Access level needed for steam command");

    g_hXsProfile.AddChangeHook(ConVarChanged_ConVars);
    g_hXsSteam.AddChangeHook(ConVarChanged_ConVars);

    if (LibraryExists("ircrelay")) {
        OnLibraryAdded("ircrelay");
    }
}

public void OnLibraryAdded(const char[] name)
{
    if (!StrEqual(name, "ircrelay")) {
        return;
    }

    char sXsProfile[2], sXsSteam[2];
    g_hXsProfile.GetString(sXsProfile, sizeof(sXsProfile));
    g_hXsSteam.GetString(sXsSteam,     sizeof(sXsSteam));

    IRC_RegisterCommand("profile", IrcCommand_Profile, IRC_GetAccess(sXsProfile));
    IRC_RegisterCommand("steam",   IrcCommand_Steam,   IRC_GetAccess(sXsSteam));
}

public void ConVarChanged_ConVars(ConVar convar, const char[] oldValue, const char[] newValue)
{
    OnLibraryAdded("ircrelay");
}


/**
 * IRC Commands
 */
public void IrcCommand_Profile(const char[] channel, const char[] name, const char[] arg)
{
    char sSteam[3][64];
    ExplodeString(arg, ":", sSteam, sizeof(sSteam), sizeof(sSteam[]));

    int iFriend = 60265728 + StringToInt(sSteam[1]) + StringToInt(sSteam[2]) * 2;
    IRC_PrivMsg(channel, "http://steamcommunity.com/profiles/765611979%d", iFriend);
}

public void IrcCommand_Steam(const char[] channel, const char[] name, const char[] arg)
{
    int iPos = StrContains(arg, "765611979");
    if (iPos == -1) {
        IRC_PrivMsg(channel, "You must send a SteamCommunity URL, eg: http://steamcommunity.com/profiles/76561197970389645");
        return;
    }

    int iSteam  = (StringToInt(arg[iPos + 9]) - 60265728) / 2,
        iServer = (iSteam + 60265728) * 2 == 76561197960265728 ? 0 : 1;
    IRC_PrivMsg(channel, "STEAM_0:%d:%d", iServer, iSteam);
}
