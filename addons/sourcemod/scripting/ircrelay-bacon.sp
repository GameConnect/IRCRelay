#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <ircrelay>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
    name        = "IRC Relay - Bacon Module",
    author      = "GameConnect",
    description = "IRC Relay for SourceMod",
    version     = IRC_VERSION,
    url         = "http://www.gameconnect.net"
};


/**
 * Globals
 */
char g_sBacon[][] =
{
    "http://en.wikipedia.org/wiki/Bacon",
    "http://www.aldenteblog.com/2008/02/im-a-lucky-girl.html",
    "http://www.aldenteblog.com/2008/02/put-away-the-pi.html",
    "http://homecooking.about.com/od/foodhistory/a/baconhistory.htm",
    "http://www.seenontvproducts.net/baconwave/Bacon%20Wave.jpg",
    "http://www.seenontvproducts.net/baconwave/index.html",
    "http://media3.guzer.com/pictures/diet_coke_bacon.jpg",
    "http://www.coolest-gadgets.com/20071115/bacon-wallet-for-your-bacon-lover/",
    "http://www.coolest-gadgets.com/20071113/bacon-flavored-toothpicks/",
    "http://img63.imageshack.us/img63/9935/1143671015499zw1.jpg",
    "http://img209.imageshack.us/img209/4898/1188160686722ha8.gif"
};


/**
 * Plugin Forwards
 */
public void OnPluginStart()
{
    if (LibraryExists("ircrelay")) {
        OnLibraryAdded("ircrelay");
    }
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "ircrelay")) {
        IRC_RegisterCommand("baconize", IrcCommand_Baconize);
    }
}


/**
 * IRC Commands
 */
public void IrcCommand_Baconize(const char[] channel, const char[] name, const char[] arg)
{
    IRC_PrivMsg(channel, g_sBacon[GetRandomInt(0, sizeof(g_sBacon) - 1)]);
}
