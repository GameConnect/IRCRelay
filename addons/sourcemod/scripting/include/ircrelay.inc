#if defined _ircrelay_included
  #endinput
#endif
#define _ircrelay_included

#define CLR_DEFAULT			1
#define CLR_LIGHTGREEN	3
#define CLR_GREEN				4
#define CLR_DARKGREEN		5

#define IRC_BOLD				2
#define IRC_COLOR				3
#define IRC_PLAIN				15
#define IRC_REVERSE			22
#define IRC_UNDERLINE		31

#define IRC_VERSION			"2.5.3"

enum IrcAccess
{
    IrcAccess_Disabled = -1,
    IrcAccess_None,
    IrcAccess_Voice,
    IrcAccess_HalfOp,
    IrcAccess_Op,
    IrcAccess_SuperOp,
    IrcAccess_Founder
}

enum IrcChannel
{
    IrcChannel_Disabled = 0,
    IrcChannel_Public   = 1,
    IrcChannel_Private  = 2,
    IrcChannel_Both     = 3
}

typedef IrcCommand = function void (const char[] channel, const char[] name, const char[] arg);


/**
 * When connected to the IRC server
 *
 * @param socket		The socket handle
 */
forward void IRC_OnConnect(Handle socket);

/**
 * When disconnected from the IRC server
 */
forward void IRC_OnDisconnect();

/**
 * When a socket error occurs
 *
 * @param errorType	The error type
 * @param errorNum	The error number
 */
forward void IRC_OnError(int errorType, int errorNum);

/**
 * When the core is loaded
 * Useful for registering commands
 */
forward void IRC_OnLoad();

/**
 * When socket data is received
 *
 * @param data			The data string
 */
forward void IRC_OnReceive(const char[] data);


/**
 * Sends a message to all channels of a specific type
 *
 * @param type			The channel type
 * @param format		Formatting rules
 * @param ...				Variable number of format parameters
 */
native void IRC_Broadcast(IrcChannel type, const char[] format, any ...);

/**
 * Returns the access level for a specific mode
 *
 * @param mode			The mode to return the access level for
 * @return The access level for a specific mode
 */
native IrcAccess IRC_GetAccess(const char[] mode);

/**
 * Returns the client's name
 * Optionally with IRC colors
 *
 * @param client		Player index.
 * @param name			Buffer to store the client's name.
 * @param maxlen		Maximum length of string buffer (includes NULL terminator).
 */
native void IRC_GetClientName(int client, const char[] name, int maxlen);

/**
 * Retrieves the number of players in a certain team.
 *
 * @param index			Team index.
 * @return					Number of players in the team.
 */
native int IRC_GetTeamClientCount(int index);

/**
 * Returns the total number of teams in a game.
 * Note: This native should not be called before OnMapStart.
 *
 * @return					Total number of teams.
 */
native int IRC_GetTeamCount();

/**
 * Retrieves the team name based on a team index.
 * Note: This native should not be called before OnMapStart.
 *
 * @param index			Team index.
 * @param name			Buffer to store string in.
 * @param maxlength	Maximum length of string buffer.
 * @error				Invalid team index.
 */
native void IRC_GetTeamName(int index, char[] name, int maxlength);

/**
 * Returns whether or not the bot is connected to IRC
 *
 * @return Whether or not the bot is connected to IRC
 */
native bool IRC_IsConnected();

/**
 * Sends a notice to IRC
 *
 * @param name			The receiver name
 * @param format		Formatting rules
 * @param ...				Variable number of format parameters
 */
native void IRC_Notice(const char[] name, const char[] format, any ...);

/**
 * Sends a private message to IRC
 *
 * @param name			The receiver name
 * @param format		Formatting rules
 * @param ...				Variable number of format parameters
 */
native void IRC_PrivMsg(const char[] name, const char[] format, any ...);

/**
 * Registers an IRC command
 *
 * @param name			The command name
 * @param callback	The command callback
 * @param access		The command access level
 */
native void IRC_RegisterCommand(const char[] name, IrcCommand callback, IrcAccess access = IrcAccess_None);

/**
 * Sends raw IRC data
 *
 * @param format		Formatting rules
 * @param ...				Variable number of format parameters
 */
native void IRC_SendRaw(const char[] format, any ...);


public SharedPlugin __pl_ircrelay =
{
    name = "ircrelay",
    file = "ircrelay.smx",
    #if defined REQUIRE_PLUGIN
    required = 1,
    #else
    required = 0,
    #endif
};

public __pl_ircrelay_SetNTVOptional()
{
    // Forwards
    MarkNativeAsOptional("IRC_OnConnect");
    MarkNativeAsOptional("IRC_OnDisconnect");
    MarkNativeAsOptional("IRC_OnError");
    MarkNativeAsOptional("IRC_OnLoad");
    MarkNativeAsOptional("IRC_OnReceive");

    // Natives
    MarkNativeAsOptional("IRC_Broadcast");
    MarkNativeAsOptional("IRC_GetAccess");
    MarkNativeAsOptional("IRC_GetClientName");
    MarkNativeAsOptional("IRC_GetTeamClientCount");
    MarkNativeAsOptional("IRC_GetTeamCount");
    MarkNativeAsOptional("IRC_GetTeamName");
    MarkNativeAsOptional("IRC_IsConnected");
    MarkNativeAsOptional("IRC_PrivMsg");
    MarkNativeAsOptional("IRC_RegisterCommand");
    MarkNativeAsOptional("IRC_SendRaw");
}
