#if defined _conplex_included
#endinput
#endif
#define _conplex_included

#pragma semicolon 1
#pragma newdecls required

methodmap ConplexSocket < Handle
{
	public native int Send(const char[] data, int length, int flags);
	public native int Receive(char[] buffer, int length, int flags);

	property any Context {
		public native get();
		public native set(any value);
	}
}

enum ConplexProtocolDetectionState
{
	ConplexProtocolDetection_NoMatch,
	ConplexProtocolDetection_NeedMoreData,
	ConplexProtocolDetection_Match,
}

typedef ConplexProtocolDetector = function ConplexProtocolDetectionState (const char[] id, const char[] data, int length);
typedef ConplexProtocolHandler = function bool (const char[] id, ConplexSocket socket, const char[] address);

#pragma deprecated This interface should only be used for prototyping. Write production handlers in C++ please.
native bool Conplex_RegisterProtocol(const char[] id, ConplexProtocolDetector detector, ConplexProtocolHandler handler);

public Extension __ext_Conplex =
{
	name = "Conplex",
	file = "conplex.ext",
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
