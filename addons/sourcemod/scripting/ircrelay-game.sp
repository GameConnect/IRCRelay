#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <ircrelay>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
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
int g_iServerPort;
ConVar g_hHostname;
ConVar g_hXsGameInfo;
ConVar g_hXsPlayerInfo;
ConVar g_hXsPlayers;
char g_sServerIp[16];


/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
    // Find hostname convar
    g_hHostname     = FindConVar("hostname");

    // Create convars
    g_hXsGameInfo   = CreateConVar("irc_xs_gameinfo",   "", "Access level needed for gameinfo command");
    g_hXsPlayerInfo = CreateConVar("irc_xs_playerinfo", "", "Access level needed for playerinfo command");
    g_hXsPlayers    = CreateConVar("irc_xs_players",    "", "Access level needed for players command");

    // Hook convar changes
    g_hXsGameInfo.AddChangeHook(ConVarChanged_ConVars);
    g_hXsPlayerInfo.AddChangeHook(ConVarChanged_ConVars);
    g_hXsPlayers.AddChangeHook(ConVarChanged_ConVars);

    // Store server IP and port
    int iServerIp = FindConVar("hostip").IntValue;
    g_iServerPort = FindConVar("hostport").IntValue;
    Format(g_sServerIp, sizeof(g_sServerIp), "%i.%i.%i.%i", (iServerIp >> 24) & 0x000000FF,
                                                            (iServerIp >> 16) & 0x000000FF,
                                                            (iServerIp >>  8) & 0x000000FF,
                                                            iServerIp         & 0x000000FF);

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

    char sXsGameInfo[2], sXsPlayerInfo[2], sXsPlayers[2];
    g_hXsGameInfo.GetString(sXsGameInfo,     sizeof(sXsGameInfo));
    g_hXsPlayerInfo.GetString(sXsPlayerInfo, sizeof(sXsPlayerInfo));
    g_hXsPlayers.GetString(sXsPlayers,       sizeof(sXsPlayers));

    IRC_RegisterCommand("gameinfo",   IrcCommand_GameInfo,   IRC_GetAccess(sXsGameInfo));
    IRC_RegisterCommand("playerinfo", IrcCommand_PlayerInfo, IRC_GetAccess(sXsPlayerInfo));
    IRC_RegisterCommand("players",    IrcCommand_Players,    IRC_GetAccess(sXsPlayers));
}

public void ConVarChanged_ConVars(ConVar convar, const char[] oldValue, const char[] newValue)
{
    OnLibraryAdded("ircrelay");
}


/**
 * IRC Commands
 */
public void IrcCommand_GameInfo(const char[] channel, const char[] name, const char[] arg)
{
    char sGameDesc[64], sHostname[256], sMap[32], sTimeLeft[32] = "Infinite";
    g_hHostname.GetString(sHostname, sizeof(sHostname));
    GetGameDescription(sGameDesc,    sizeof(sGameDesc));
    GetCurrentMap(sMap,              sizeof(sMap));

    int iTimeLeft;
    if (GetMapTimeLeft(iTimeLeft) && iTimeLeft >= 0) {
        SecondsToString(iTimeLeft, sTimeLeft, sizeof(sTimeLeft));
    }

    IRC_PrivMsg(channel, "Name: %s - IP: %s:%i", sHostname, g_sServerIp, g_iServerPort);
    IRC_PrivMsg(channel, "Map: %s - Timeleft: %s", sMap, sTimeLeft);
    IRC_PrivMsg(channel, "Players: %i/%i - Mod: %s", GetClientCount(), MaxClients, sGameDesc);
}

public void IrcCommand_PlayerInfo(const char[] channel, const char[] name, const char[] arg)
{
    int iTarget = FindTarget(0, arg);
    if (iTarget == -1) {
        IRC_PrivMsg(channel, "Invalid player specified.");
        return;
    }

    char sAuth[20], sIp[15], sName[MAX_NAME_LENGTH + 1];
    GetClientAuthId(iTarget, AuthId_Steam2, sAuth, sizeof(sAuth));
    GetClientIP(iTarget,                    sIp,   sizeof(sIp));
    IRC_GetClientName(iTarget,              sName, sizeof(sName));

    IRC_PrivMsg(channel, "%s (%i, %s, %s) - Score/Deaths: %i/%i - HP/AP: %i/%i - Ping: %i",
                          sName, GetClientUserId(iTarget), sAuth, sIp, GetClientFrags(iTarget),
                          GetClientDeaths(iTarget), GetClientHealth(iTarget), GetClientArmor(iTarget),
                          IsFakeClient(iTarget) ? 0 : RoundToNearest(GetClientAvgLatency(iTarget, NetFlow_Outgoing) * 1000.0));
}

public void IrcCommand_Players(const char[] channel, const char[] name, const char[] arg)
{
    int iClients = GetClientCount();
    IRC_PrivMsg(channel, "Total Players: %i", iClients);
    if (!iClients) {
        return;
    }

    for (int i = IRC_GetTeamCount() - 1; i >= 0; i--) {
        iClients = IRC_GetTeamClientCount(i);
        if (!iClients) {
            continue;
        }

        char sBuffer[4096] = "", sName[MAX_NAME_LENGTH + 1], sTeam[MAX_NAME_LENGTH + 1];
        IRC_GetTeamName(i, sTeam, sizeof(sTeam));

        for (int j = 1; j <= MaxClients; j++) {
            if (!IsClientInGame(j) || GetClientTeam(j) != i) {
                continue;
            }

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
void SecondsToString(int seconds, char[] buffer, int maxlength)
{
    int iHours   = seconds / 60 / 60;
    seconds     -= iHours  * 60 / 60;
    int iMinutes = seconds / 60;
    seconds     %= 60;

    Format(buffer, maxlength, "%i Hours, %i Minutes, %i Seconds", iHours, iMinutes, seconds);
}
