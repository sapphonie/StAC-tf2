#if defined _sbpstac_included
 #endinput
#endif
#define __sbpstac_included_included

public SharedPlugin __pl_sbpstac =
{
	name = "sbpstac",
	file = "sbpstac.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
