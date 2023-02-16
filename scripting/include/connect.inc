#if defined _connect_included
#endinput
#endif
#define _connect_included

forward bool:OnClientPreConnectEx(const String:name[], String:password[255], const String:ip[], const String:steamID[], String:rejectReason[255]);

public Extension:__ext_Connect = 
{
	name = "Connect",
	file = "connect.ext",
#if defined AUTOLOAD_EXTENSIONS
	autoload = 1,
#else
	autoload = 0,
#endif
#if defined REQUIRE_EXTENSIONS
	required = 1,
#else
	required = 0,
#endif
}