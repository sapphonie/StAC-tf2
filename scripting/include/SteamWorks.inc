#if defined _SteamWorks_Included
 #endinput
#endif
#define _SteamWorks_Included

/* Constants */

/* results from UserHasLicenseForApp */
enum EUserHasLicenseForAppResult
{
	k_EUserHasLicenseResultHasLicense = 0,					// User has a license for specified app
	k_EUserHasLicenseResultDoesNotHaveLicense = 1,			// User does not have a license for the specified app
	k_EUserHasLicenseResultNoAuth = 2,						// User has not been authenticated
};

/* General result codes */
enum EResult
{
	k_EResultOK	= 1,							// success
	k_EResultFail = 2,							// generic failure 
	k_EResultNoConnection = 3,					// no/failed network connection
//	k_EResultNoConnectionRetry = 4,				// OBSOLETE - removed
	k_EResultInvalidPassword = 5,				// password/ticket is invalid
	k_EResultLoggedInElsewhere = 6,				// same user logged in elsewhere
	k_EResultInvalidProtocolVer = 7,			// protocol version is incorrect
	k_EResultInvalidParam = 8,					// a parameter is incorrect
	k_EResultFileNotFound = 9,					// file was not found
	k_EResultBusy = 10,							// called method busy - action not taken
	k_EResultInvalidState = 11,					// called object was in an invalid state
	k_EResultInvalidName = 12,					// name is invalid
	k_EResultInvalidEmail = 13,					// email is invalid
	k_EResultDuplicateName = 14,				// name is not unique
	k_EResultAccessDenied = 15,					// access is denied
	k_EResultTimeout = 16,						// operation timed out
	k_EResultBanned = 17,						// VAC2 banned
	k_EResultAccountNotFound = 18,				// account not found
	k_EResultInvalidSteamID = 19,				// steamID is invalid
	k_EResultServiceUnavailable = 20,			// The requested service is currently unavailable
	k_EResultNotLoggedOn = 21,					// The user is not logged on
	k_EResultPending = 22,						// Request is pending (may be in process, or waiting on third party)
	k_EResultEncryptionFailure = 23,			// Encryption or Decryption failed
	k_EResultInsufficientPrivilege = 24,		// Insufficient privilege
	k_EResultLimitExceeded = 25,				// Too much of a good thing
	k_EResultRevoked = 26,						// Access has been revoked (used for revoked guest passes)
	k_EResultExpired = 27,						// License/Guest pass the user is trying to access is expired
	k_EResultAlreadyRedeemed = 28,				// Guest pass has already been redeemed by account, cannot be acked again
	k_EResultDuplicateRequest = 29,				// The request is a duplicate and the action has already occurred in the past, ignored this time
	k_EResultAlreadyOwned = 30,					// All the games in this guest pass redemption request are already owned by the user
	k_EResultIPNotFound = 31,					// IP address not found
	k_EResultPersistFailed = 32,				// failed to write change to the data store
	k_EResultLockingFailed = 33,				// failed to acquire access lock for this operation
	k_EResultLogonSessionReplaced = 34,
	k_EResultConnectFailed = 35,
	k_EResultHandshakeFailed = 36,
	k_EResultIOFailure = 37,
	k_EResultRemoteDisconnect = 38,
	k_EResultShoppingCartNotFound = 39,			// failed to find the shopping cart requested
	k_EResultBlocked = 40,						// a user didn't allow it
	k_EResultIgnored = 41,						// target is ignoring sender
	k_EResultNoMatch = 42,						// nothing matching the request found
	k_EResultAccountDisabled = 43,
	k_EResultServiceReadOnly = 44,				// this service is not accepting content changes right now
	k_EResultAccountNotFeatured = 45,			// account doesn't have value, so this feature isn't available
	k_EResultAdministratorOK = 46,				// allowed to take this action, but only because requester is admin
	k_EResultContentVersion = 47,				// A Version mismatch in content transmitted within the Steam protocol.
	k_EResultTryAnotherCM = 48,					// The current CM can't service the user making a request, user should try another.
	k_EResultPasswordRequiredToKickSession = 49,// You are already logged in elsewhere, this cached credential login has failed.
	k_EResultAlreadyLoggedInElsewhere = 50,		// You are already logged in elsewhere, you must wait
	k_EResultSuspended = 51,					// Long running operation (content download) suspended/paused
	k_EResultCancelled = 52,					// Operation canceled (typically by user: content download)
	k_EResultDataCorruption = 53,				// Operation canceled because data is ill formed or unrecoverable
	k_EResultDiskFull = 54,						// Operation canceled - not enough disk space.
	k_EResultRemoteCallFailed = 55,				// an remote call or IPC call failed
	k_EResultPasswordUnset = 56,				// Password could not be verified as it's unset server side
	k_EResultExternalAccountUnlinked = 57,		// External account (PSN, Facebook...) is not linked to a Steam account
	k_EResultPSNTicketInvalid = 58,				// PSN ticket was invalid
	k_EResultExternalAccountAlreadyLinked = 59,	// External account (PSN, Facebook...) is already linked to some other account, must explicitly request to replace/delete the link first
	k_EResultRemoteFileConflict = 60,			// The sync cannot resume due to a conflict between the local and remote files
	k_EResultIllegalPassword = 61,				// The requested new password is not legal
	k_EResultSameAsPreviousValue = 62,			// new value is the same as the old one ( secret question and answer )
	k_EResultAccountLogonDenied = 63,			// account login denied due to 2nd factor authentication failure
	k_EResultCannotUseOldPassword = 64,			// The requested new password is not legal
	k_EResultInvalidLoginAuthCode = 65,			// account login denied due to auth code invalid
	k_EResultAccountLogonDeniedNoMail = 66,		// account login denied due to 2nd factor auth failure - and no mail has been sent
	k_EResultHardwareNotCapableOfIPT = 67,		// 
	k_EResultIPTInitError = 68,					// 
	k_EResultParentalControlRestricted = 69,	// operation failed due to parental control restrictions for current user
	k_EResultFacebookQueryError = 70,			// Facebook query returned an error
	k_EResultExpiredLoginAuthCode = 71,			// account login denied due to auth code expired
	k_EResultIPLoginRestrictionFailed = 72,
	k_EResultAccountLockedDown = 73,
	k_EResultAccountLogonDeniedVerifiedEmailRequired = 74,
	k_EResultNoMatchingURL = 75,
	k_EResultBadResponse = 76,					// parse failure, missing field, etc.
	k_EResultRequirePasswordReEntry = 77,		// The user cannot complete the action until they re-enter their password
	k_EResultValueOutOfRange = 78,				// the value entered is outside the acceptable range
	k_EResultUnexpectedError = 79,				// something happened that we didn't expect to ever happen
	k_EResultDisabled = 80,						// The requested service has been configured to be unavailable
	k_EResultInvalidCEGSubmission = 81,			// The set of files submitted to the CEG server are not valid !
	k_EResultRestrictedDevice = 82,				// The device being used is not allowed to perform this action
	k_EResultRegionLocked = 83,					// The action could not be complete because it is region restricted
	k_EResultRateLimitExceeded = 84,			// Temporary rate limit exceeded, try again later, different from k_EResultLimitExceeded which may be permanent
	k_EResultAccountLoginDeniedNeedTwoFactor = 85,	// Need two-factor code to login
	k_EResultItemDeleted = 86,					// The thing we're trying to access has been deleted
	k_EResultAccountLoginDeniedThrottle = 87,	// login attempt failed, try to throttle response to possible attacker
	k_EResultTwoFactorCodeMismatch = 88,		// two factor code mismatch
	k_EResultTwoFactorActivationCodeMismatch = 89,	// activation code for two-factor didn't match
	k_EResultAccountAssociatedToMultiplePartners = 90,	// account has been associated with multiple partners
	k_EResultNotModified = 91,					// data not modified
	k_EResultNoMobileDevice = 92,				// the account does not have a mobile device associated with it
	k_EResultTimeNotSynced = 93,				// the time presented is out of range or tolerance
	k_EResultSmsCodeFailed = 94,				// SMS code failure (no match, none pending, etc.)
	k_EResultAccountLimitExceeded = 95,			// Too many accounts access this resource
	k_EResultAccountActivityLimitExceeded = 96,	// Too many changes to this account
	k_EResultPhoneActivityLimitExceeded = 97,	// Too many changes to this phone
	k_EResultRefundToWallet = 98,				// Cannot refund to payment method, must use wallet
	k_EResultEmailSendFailure = 99,				// Cannot send an email
	k_EResultNotSettled = 100,					// Can't perform operation till payment has settled
	k_EResultNeedCaptcha = 101,					// Needs to provide a valid captcha
	k_EResultGSLTDenied = 102,					// a game server login token owned by this token's owner has been banned
	k_EResultGSOwnerDenied = 103,				// game server owner is denied for other reason (account lock, community ban, vac ban, missing phone)
	k_EResultInvalidItemType = 104,				// the type of thing we were requested to act on is invalid
	k_EResultIPBanned = 105,					// the ip address has been banned from taking this action
	k_EResultGSLTExpired = 106,					// this token has expired from disuse; can be reset for use
	k_EResultInsufficientFunds = 107,			// user doesn't have enough wallet funds to complete the action
	k_EResultTooManyPending = 108,				// There are too many of this thing pending already
	k_EResultNoSiteLicensesFound = 109,			// No site licenses found
	k_EResultWGNetworkSendExceeded = 110,		// the WG couldn't send a response because we exceeded max network send size
	k_EResultAccountNotFriends = 111,			// the user is not mutually friends
	k_EResultLimitedUserAccount = 112,			// the user is limited
	k_EResultCantRemoveItem = 113,				// item can't be removed
	k_EResultAccountDeleted = 114,				// account has been deleted
	k_EResultExistingUserCancelledLicense = 115,	// A license for this already exists, but cancelled
	k_EResultCommunityCooldown = 116,			// access is denied because of a community cooldown (probably from support profile data resets)
	k_EResultNoLauncherSpecified = 117,			// No launcher was specified, but a launcher was needed to choose correct realm for operation.
	k_EResultMustAgreeToSSA = 118,				// User must agree to china SSA or global SSA before login
	k_EResultLauncherMigrated = 119,			// The specified launcher type is no longer supported; the user should be directed elsewhere
	k_EResultSteamRealmMismatch = 120,			// The user's realm does not match the realm of the requested resource
	k_EResultInvalidSignature = 121,			// signature check did not match
	k_EResultParseFailure = 122,				// Failed to parse input
	k_EResultNoVerifiedPhone = 123,				// account does not have a verified phone number
	k_EResultInsufficientBattery = 124,			// user device doesn't have enough battery charge currently to complete the action
	k_EResultChargerRequired = 125,				// The operation requires a charger to be plugged in, which wasn't present
	k_EResultCachedCredentialInvalid = 126,		// Cached credential was invalid - user must reauthenticate
	K_EResultPhoneNumberIsVOIP = 127,			// The phone number provided is a Voice Over IP number
	k_EResultNotSupported = 128,				// The data being accessed is not supported by this API
	k_EResultFamilySizeLimitExceeded = 129,		// Reached the maximum size of the family
	k_EResultOfflineAppCacheInvalid = 130,		// The local data for the offline mode cache is insufficient to login
	k_EResultTryLater = 131						// retry the operation later
};

/* This enum is used in client API methods, do not re-number existing values. */
enum EHTTPMethod
{
	k_EHTTPMethodInvalid = 0,
	k_EHTTPMethodGET,
	k_EHTTPMethodHEAD,
	k_EHTTPMethodPOST,
	k_EHTTPMethodPUT,
	k_EHTTPMethodDELETE,
	k_EHTTPMethodOPTIONS,
	k_EHTTPMethodPATCH,

	// The remaining HTTP methods are not yet supported, per rfc2616 section 5.1.1 only GET and HEAD are required for 
	// a compliant general purpose server.  We'll likely add more as we find uses for them.

	// k_EHTTPMethodTRACE,
	// k_EHTTPMethodCONNECT
};


/* HTTP Status codes that the server can send in response to a request, see rfc2616 section 10.3 for descriptions
 of each of these. */
enum EHTTPStatusCode
{
	// Invalid status code (this isn't defined in HTTP, used to indicate unset in our code)
	k_EHTTPStatusCodeInvalid =					0,

	// Informational codes
	k_EHTTPStatusCode100Continue =				100,
	k_EHTTPStatusCode101SwitchingProtocols =	101,

	// Success codes
	k_EHTTPStatusCode200OK =					200,
	k_EHTTPStatusCode201Created =				201,
	k_EHTTPStatusCode202Accepted =				202,
	k_EHTTPStatusCode203NonAuthoritative =		203,
	k_EHTTPStatusCode204NoContent =				204,
	k_EHTTPStatusCode205ResetContent =			205,
	k_EHTTPStatusCode206PartialContent =		206,

	// Redirection codes
	k_EHTTPStatusCode300MultipleChoices =		300,
	k_EHTTPStatusCode301MovedPermanently =		301,
	k_EHTTPStatusCode302Found =					302,
	k_EHTTPStatusCode303SeeOther =				303,
	k_EHTTPStatusCode304NotModified =			304,
	k_EHTTPStatusCode305UseProxy =				305,
	//k_EHTTPStatusCode306Unused =				306, (used in old HTTP spec, now unused in 1.1)
	k_EHTTPStatusCode307TemporaryRedirect =		307,
	k_EHTTPStatusCode308PermanentRedirect =		308,

	// Error codes
	k_EHTTPStatusCode400BadRequest =			400,
	k_EHTTPStatusCode401Unauthorized =			401, // You probably want 403 or something else. 401 implies you're sending a WWW-Authenticate header and the client can sent an Authorization header in response.
	k_EHTTPStatusCode402PaymentRequired =		402, // This is reserved for future HTTP specs, not really supported by clients
	k_EHTTPStatusCode403Forbidden =				403,
	k_EHTTPStatusCode404NotFound =				404,
	k_EHTTPStatusCode405MethodNotAllowed =		405,
	k_EHTTPStatusCode406NotAcceptable =			406,
	k_EHTTPStatusCode407ProxyAuthRequired =		407,
	k_EHTTPStatusCode408RequestTimeout =		408,
	k_EHTTPStatusCode409Conflict =				409,
	k_EHTTPStatusCode410Gone =					410,
	k_EHTTPStatusCode411LengthRequired =		411,
	k_EHTTPStatusCode412PreconditionFailed =	412,
	k_EHTTPStatusCode413RequestEntityTooLarge =	413,
	k_EHTTPStatusCode414RequestURITooLong =		414,
	k_EHTTPStatusCode415UnsupportedMediaType =	415,
	k_EHTTPStatusCode416RequestedRangeNotSatisfiable = 416,
	k_EHTTPStatusCode417ExpectationFailed =		417,
	k_EHTTPStatusCode4xxUnknown = 				418, // 418 is reserved, so we'll use it to mean unknown
	k_EHTTPStatusCode421MisdirectedRequest =	421,
	k_EHTTPStatusCode422UnprocessableContent =	422,
	k_EHTTPStatusCode423Locked =				423,
	k_EHTTPStatusCode424FailedDependency =		424,
	k_EHTTPStatusCode425TooEarly =				425,
	k_EHTTPStatusCode426UpgradeRequired =		426,
	k_EHTTPStatusCode428PreconditionRequired =	428,
	k_EHTTPStatusCode429TooManyRequests	=		429,
	k_EHTTPStatusCode431RequestHeaderFieldsTooLarge =	431,
	k_EHTTPStatusCode444ConnectionClosed =		444, // nginx only?
	k_EHTTPStatusCode451UnavailableForLegalReasons =	451,

	// Server error codes
	k_EHTTPStatusCode500InternalServerError =	500,
	k_EHTTPStatusCode501NotImplemented =		501,
	k_EHTTPStatusCode502BadGateway =			502,
	k_EHTTPStatusCode503ServiceUnavailable =	503,
	k_EHTTPStatusCode504GatewayTimeout =		504,
	k_EHTTPStatusCode505HTTPVersionNotSupported = 505,
	k_EHTTPStatusCode506VariantAlsoNegotiates =	506,
	k_EHTTPStatusCode507InsufficientStorage =	507,
	k_EHTTPStatusCode508LoopDetected =			508,
	k_EHTTPStatusCode510NotExtended =			510,
	k_EHTTPStatusCode511NetworkAuthenticationRequired =	511,
	k_EHTTPStatusCode5xxUnknown =				599,
};

/* list of possible return values from the ISteamGameCoordinator API */
enum EGCResults
{
	k_EGCResultOK = 0,
	k_EGCResultNoMessage = 1,			// There is no message in the queue
	k_EGCResultBufferTooSmall = 2,		// The buffer is too small for the requested message
	k_EGCResultNotLoggedOn = 3,			// The client is not logged onto Steam
	k_EGCResultInvalidMessage = 4,		// Something was wrong with the message being sent with SendMessage
};

/* Natives */

/**
 * Returns whether an HTTP status code represents success (a 2xx code).
 *
 * @param eStatusCode   HTTP status code to test.
 * @return              True if the code is in the 2xx range, false otherwise.
 */
stock bool IsHTTPStatusSuccess(EHTTPStatusCode eStatusCode)
{
	return (eStatusCode >= k_EHTTPStatusCode200OK && eStatusCode < k_EHTTPStatusCode300MultipleChoices);
}

/**
 * Returns whether the server is VAC (Valve Anti-Cheat) secured.
 *
 * @return              True if the server is VAC secured, false otherwise (including
 *                      when not yet connected to Steam).
 */
native bool SteamWorks_IsVACEnabled();

/**
 * Retrieves the server's public IP address as four octets.
 *
 * @param ipaddr        Array that receives the IP address, most-significant octet first
 *                      (e.g. 127.0.0.1 becomes {127, 0, 0, 1}).
 * @return              True on success, false if not connected to Steam or the public
 *                      IP is not yet known.
 */
native bool SteamWorks_GetPublicIP(int ipaddr[4]);

/**
 * Retrieves the server's public IP address packed into a single cell.
 *
 * @return              The IPv4 address as a 32-bit value (host byte order), or 0 if not
 *                      connected to Steam or the public IP is not yet known.
 */
native int SteamWorks_GetPublicIPCell();

/**
 * Returns whether the Steam client library has been loaded by the extension.
 *
 * @return              True if the Steam library is loaded, false otherwise.
 */
native bool SteamWorks_IsLoaded();

/**
 * Sets the "gamedata" string for the server, used for matchmaking/server-browser filtering.
 *
 * @param sData         Game data string.
 * @return              True on success, false if not connected to Steam.
 */
native bool SteamWorks_SetGameData(const char[] sData);

/**
 * Sets the game description reported to the server browser and client queries.
 *
 * @param sDesc         Game description string.
 * @return              True on success, false if not connected to Steam.
 */
native bool SteamWorks_SetGameDescription(const char[] sDesc);

/**
 * Sets the map name reported to the server browser and client queries.
 *
 * @param sMapName      Map name string.
 * @return              True on success, false if not connected to Steam.
 */
native bool SteamWorks_SetMapName(const char[] sMapName);

/**
 * Returns whether the server is currently logged on to Steam.
 *
 * @return              True if logged on to Steam, false otherwise.
 */
native bool SteamWorks_IsConnected();

/**
 * Adds or updates a key/value pair sent in A2S rules queries.
 *
 * @param sKey          Rule key.
 * @param sValue        Rule value.
 * @return              True on success, false if not connected to Steam.
 */
native bool SteamWorks_SetRule(const char[] sKey, const char[] sValue);

/**
 * Clears the entire list of key/value pairs sent in rules queries.
 *
 * @return              True on success, false if not connected to Steam.
 */
native bool SteamWorks_ClearRules();

/**
 * Sets whether the server should be advertised on the master server list and
 * respond to server browser / LAN discovery packets. Defaults to false; set
 * other server parameters before enabling advertising.
 *
 * @param bActive       True to advertise the server, false to hide it.
 * @return              True on success, false if not connected to Steam.
 */
native bool SteamWorks_SetAdvertiseServerActive(bool bActive);

/**
 * Returns the FakeIP address and port assigned to the game server, if any.
 * Does not function on games that don't support -enablefakeip.
 *
 * Check the return value before using the IP and port.
 *
 * @param ip            Variable to store the FakeIP (host byte order).
 * @param port          Variable to store the assigned fake port.
 * @return              True if a FakeIP was successfully retrieved, false otherwise.
 */
native bool SteamWorks_GetFakeIP(int &ip, int &port);

/**
 * Deprecated no-op. Newer Steamworks SDKs removed ForceHeartbeat; server list
 * heartbeats are now sent implicitly by Steam.
 *
 * @return              Always false.
 */
#pragma deprecated This function is deprecated in the SDK and no longer does anything in this extension
native bool SteamWorks_ForceHeartbeat();

/**
 * Asynchronously requests whether a client is a member of a given Steam group.
 * The result is delivered through the SteamWorks_OnClientGroupStatus forward.
 *
 * @param client        Client index.
 * @param groupid       32-bit account ID of the Steam group.
 * @return              True if the request was sent, false if not connected to Steam.
 * @error               Invalid client index.
 */
native bool SteamWorks_GetUserGroupStatus(int client, int groupid);

/**
 * Asynchronously requests whether a user is a member of a given Steam group.
 * The result is delivered through the SteamWorks_OnClientGroupStatus forward.
 *
 * @param authid        32-bit account ID of the user to query.
 * @param groupid       32-bit account ID of the Steam group.
 * @return              True if the request was sent, false if not connected to Steam.
 */
native bool SteamWorks_GetUserGroupStatusAuthID(int authid, int groupid);

/**
 * Returns whether a client owns/has a license for the given application.
 *
 * @param client        Client index.
 * @param app           Application (AppID) to check ownership of.
 * @return              An EUserHasLicenseForAppResult value; k_EUserHasLicenseResultNoAuth
 *                      if not connected to Steam.
 * @error               Invalid client index.
 */
native EUserHasLicenseForAppResult SteamWorks_HasLicenseForApp(int client, int app);

/**
 * Returns whether a user owns/has a license for the given application.
 *
 * @param authid        32-bit account ID of the user to check.
 * @param app           Application (AppID) to check ownership of.
 * @return              An EUserHasLicenseForAppResult value; k_EUserHasLicenseResultNoAuth
 *                      if not connected to Steam.
 */
native EUserHasLicenseForAppResult SteamWorks_HasLicenseForAppId(int authid, int app);

/**
 * Retrieves a client's 64-bit Steam ID (community ID) as a string.
 *
 * @param client        Client index.
 * @param sSteamID      Buffer to store the rendered 64-bit Steam ID.
 * @param length        Maximum length of the buffer.
 * @return              Number of bytes written, including the null terminator.
 * @error               Invalid client index.
 */
native int SteamWorks_GetClientSteamID(int client, char[] sSteamID, int length);

/**
 * Asynchronously requests the stats of a user from Steam. Stats become available
 * afterwards through SteamWorks_GetStatAuthIDCell / SteamWorks_GetStatAuthIDFloat.
 *
 * @param authid        32-bit account ID of the user whose stats to request.
 * @param appid         Application (AppID) to request stats for.
 * @return              True if the request was sent, false if not connected to Steam.
 */
native bool SteamWorks_RequestStatsAuthID(int authid, int appid);

/**
 * Asynchronously requests the stats of a client from Steam. Stats become available
 * afterwards through SteamWorks_GetStatCell / SteamWorks_GetStatFloat.
 *
 * @param client        Client index.
 * @param appid         Application (AppID) to request stats for.
 * @return              True if the request was sent, false if not connected to Steam.
 * @error               Invalid client index.
 */
native bool SteamWorks_RequestStats(int client, int appid);

/**
 * Retrieves an integer stat for a client. The client's stats must have been
 * requested first with SteamWorks_RequestStats.
 *
 * @param client        Client index.
 * @param sKey          Stat name.
 * @param value         Variable to store the stat value in.
 * @return              True on success, false on failure or if not connected to Steam.
 * @error               Invalid client index.
 */
native bool SteamWorks_GetStatCell(int client, const char[] sKey, int &value);

/**
 * Retrieves an integer stat for a user. The user's stats must have been
 * requested first with SteamWorks_RequestStatsAuthID.
 *
 * @param authid        32-bit account ID of the user.
 * @param sKey          Stat name.
 * @param value         Variable to store the stat value in.
 * @return              True on success, false on failure or if not connected to Steam.
 */
native bool SteamWorks_GetStatAuthIDCell(int authid, const char[] sKey, int &value);

/**
 * Retrieves a floating-point stat for a client. The client's stats must have been
 * requested first with SteamWorks_RequestStats.
 *
 * @param client        Client index.
 * @param sKey          Stat name.
 * @param value         Variable to store the stat value in.
 * @return              True on success, false on failure or if not connected to Steam.
 * @error               Invalid client index.
 */
native bool SteamWorks_GetStatFloat(int client, const char[] sKey, float &value);

/**
 * Retrieves a floating-point stat for a user. The user's stats must have been
 * requested first with SteamWorks_RequestStatsAuthID.
 *
 * @param authid        32-bit account ID of the user.
 * @param sKey          Stat name.
 * @param value         Variable to store the stat value in.
 * @return              True on success, false on failure or if not connected to Steam.
 */
native bool SteamWorks_GetStatAuthIDFloat(int authid, const char[] sKey, float &value);

/**
 * Creates a new HTTP request. The URL must be absolute and start with http:// or https://.
 *
 * The returned handle must be freed with CloseHandle/delete once the request is finished.
 *
 * @param method        HTTP method to use.
 * @param sURL          Absolute URL for the request.
 * @return              A handle to the new HTTP request, or INVALID_HANDLE on failure
 *                      (including when not connected to Steam).
 */
native Handle SteamWorks_CreateHTTPRequest(EHTTPMethod method, const char[] sURL);

/**
 * Sets one or two context values that will be passed back to the request's callbacks.
 * These let you associate arbitrary data with a request.
 *
 * @param hHandle       HTTP request handle.
 * @param data1         First context value.
 * @param data2         Second context value.
 * @return              True on success, false on an invalid handle or if the request was
 *                      already sent.
 */
native bool SteamWorks_SetHTTPRequestContextValue(Handle hHandle, any data1, any data2=0);

/**
 * Sets a network-activity timeout, in seconds, for the request. Must be called before sending.
 * The default is 60 seconds. The timer resets whenever more data is received.
 *
 * @param hHandle       HTTP request handle.
 * @param timeout       Timeout in seconds.
 * @return              True on success, false on an invalid handle or if the request was
 *                      already sent.
 */
native bool SteamWorks_SetHTTPRequestNetworkActivityTimeout(Handle hHandle, int timeout);

/**
 * Sets a request header value. Must be called before sending the request.
 *
 * @param hHandle       HTTP request handle.
 * @param sName         Header name.
 * @param sValue        Header value.
 * @return              True on success, false on an invalid handle or if the request was
 *                      already sent.
 */
native bool SteamWorks_SetHTTPRequestHeaderValue(Handle hHandle, const char[] sName, const char[] sValue);

/**
 * Sets a GET or POST parameter on the request (which is used depends on the request method).
 * Must be called before sending the request.
 *
 * @param hHandle       HTTP request handle.
 * @param sName         Parameter name.
 * @param sValue        Parameter value.
 * @return              True on success, false on an invalid handle or if the request was
 *                      already sent.
 */
native bool SteamWorks_SetHTTPRequestGetOrPostParameter(Handle hHandle, const char[] sName, const char[] sValue);

/**
 * Appends extra user-agent info to the request. This does not clobber the normal user
 * agent; it is added to the end.
 *
 * @param hHandle       HTTP request handle.
 * @param sUserAgentInfo    Extra user-agent info string.
 * @return              True on success, false on an invalid handle.
 */
native bool SteamWorks_SetHTTPRequestUserAgentInfo(Handle hHandle, const char[] sUserAgentInfo);

/**
 * Enables or disables verification of SSL/TLS certificates. By default, certificates
 * are verified for all HTTPS requests.
 *
 * @param hHandle       HTTP request handle.
 * @param bRequireVerifiedCertificate   True to require a verified certificate, false to disable.
 * @return              True on success, false on an invalid handle.
 */
native bool SteamWorks_SetHTTPRequestRequiresVerifiedCertificate(Handle hHandle, bool bRequireVerifiedCertificate);

/**
 * Sets an absolute timeout, in milliseconds, on the request. Unlike the network-activity
 * timeout, this is a total time limit that does not reset as data arrives.
 *
 * @param hHandle       HTTP request handle.
 * @param unMilliseconds    Total timeout in milliseconds.
 * @return              True on success, false on an invalid handle.
 */
native bool SteamWorks_SetHTTPRequestAbsoluteTimeoutMS(Handle hHandle, int unMilliseconds);

/**
 * Called when an HTTP request has completed (or failed). The number of trailing context
 * parameters matches how many values were passed to SteamWorks_SetHTTPRequestContextValue.
 *
 * @param hRequest              HTTP request handle.
 * @param bFailure              True if the request failed due to an internal or network
 *                              error (no response from the server).
 * @param bRequestSuccessful    True if any response was received from the server (even an
 *                              error response).
 * @param eStatusCode           HTTP status code returned by the server.
 * @param data1                 First context value, if one was set.
 * @param data2                 Second context value, if one was set.
 */
typeset SteamWorksHTTPRequestCompleted
{
	function void (Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode);
	function void (Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1);
	function void (Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1, any data2);
};

/**
 * Called when the response headers for a streaming request have been received. The number
 * of trailing context parameters matches the context values set on the request.
 *
 * @param hRequest      HTTP request handle.
 * @param bFailure      Always false; headers-received is a success-only notification. A
 *                      failed request is reported through SteamWorksHTTPRequestCompleted.
 * @param data1         First context value, if one was set.
 * @param data2         Second context value, if one was set.
 */
typeset SteamWorksHTTPHeadersReceived
{
	function void (Handle hRequest, bool bFailure);
	function void (Handle hRequest, bool bFailure, any data1);
	function void (Handle hRequest, bool bFailure, any data1, any data2);
};

/**
 * Called when a chunk of data for a streaming request has been received. Pass the offset
 * and byte count to SteamWorks_GetHTTPStreamingResponseBodyData to read the chunk. The
 * number of trailing context parameters matches the context values set on the request.
 *
 * @param hRequest      HTTP request handle.
 * @param bFailure      Always false; data-received is a success-only notification. A
 *                      failed request is reported through SteamWorksHTTPRequestCompleted.
 * @param offset        Offset of this chunk within the response body.
 * @param bytesreceived Number of bytes in this chunk.
 * @param data1         First context value, if one was set.
 * @param data2         Second context value, if one was set.
 */
typeset SteamWorksHTTPDataReceived
{
	function void (Handle hRequest, bool bFailure, int offset, int bytesreceived);
	function void (Handle hRequest, bool bFailure, int offset, int bytesreceived, any data1);
	function void (Handle hRequest, bool bFailure, int offset, int bytesreceived, any data1, any data2);
};

/**
 * Called by SteamWorks_GetHTTPResponseBodyCallback with the response body. Use the string
 * overload for text bodies or the int[] overload for binary bodies.
 *
 * @param sData         Response body as a string (text overload).
 * @param data          Response body as a byte array (binary overload).
 * @param value         The context value passed to SteamWorks_GetHTTPResponseBodyCallback.
 * @param datalen       Length of the body, in bytes (binary overload).
 */
typeset SteamWorksHTTPBodyCallback
{
	function void (const char[] sData);
	function void (const char[] sData, any value);
	function void (const int[] data, any value, int datalen);
};

/**
 * Sets the callbacks fired for a request. Must be called before sending the request.
 * The completion callback is used by both regular and streaming requests; the headers and
 * data callbacks are only fired for streaming requests.
 *
 * @param hHandle       HTTP request handle.
 * @param fCompleted    Callback fired when the request completes, or INVALID_FUNCTION.
 * @param fHeaders      Callback fired when streaming headers arrive, or INVALID_FUNCTION.
 * @param fData         Callback fired when a streaming data chunk arrives, or INVALID_FUNCTION.
 * @param hCalling      Handle of the plugin that owns the callbacks, or INVALID_HANDLE for
 *                      the calling plugin.
 * @return              True on success, false on an invalid handle.
 * @error               Invalid plugin handle or invalid function.
 */
native bool SteamWorks_SetHTTPCallbacks(Handle hHandle, SteamWorksHTTPRequestCompleted fCompleted = INVALID_FUNCTION, SteamWorksHTTPHeadersReceived fHeaders = INVALID_FUNCTION, SteamWorksHTTPDataReceived fData = INVALID_FUNCTION, Handle hCalling = INVALID_HANDLE);

/**
 * Sends an HTTP request. The result is delivered asynchronously to the completion callback
 * set with SteamWorks_SetHTTPCallbacks.
 *
 * @param hRequest      HTTP request handle.
 * @return              True if the request was sent, false on an invalid handle.
 */
native bool SteamWorks_SendHTTPRequest(Handle hRequest);

/**
 * Sends an HTTP request and streams the response. Headers and data are delivered
 * asynchronously to the callbacks set with SteamWorks_SetHTTPCallbacks.
 *
 * @param hRequest      HTTP request handle.
 * @return              True if the request was sent, false on an invalid handle.
 */
native bool SteamWorks_SendHTTPRequestAndStreamResponse(Handle hRequest);

/**
 * Moves an already-sent request to the tail of the client's request queue.
 *
 * @param hRequest      HTTP request handle.
 * @return              True on success, false on an invalid handle or if the request has
 *                      not been sent.
 */
native bool SteamWorks_DeferHTTPRequest(Handle hRequest);

/**
 * Moves an already-sent request to the head of the client's request queue.
 *
 * @param hRequest      HTTP request handle.
 * @return              True on success, false on an invalid handle or if the request has
 *                      not been sent.
 */
native bool SteamWorks_PrioritizeHTTPRequest(Handle hRequest);

/**
 * Checks whether a response header is present and retrieves the size of its value, so a
 * correctly-sized buffer can be allocated for SteamWorks_GetHTTPResponseHeaderValue.
 * Call from the completion callback.
 *
 * @param hRequest      HTTP request handle.
 * @param sHeader       Header name.
 * @param size          Variable to store the header value size in.
 * @return              True if the header is present, false otherwise.
 */
native bool SteamWorks_GetHTTPResponseHeaderSize(Handle hRequest, const char[] sHeader, int &size);

/**
 * Retrieves a response header value. Call from the completion callback. Use
 * SteamWorks_GetHTTPResponseHeaderSize first to size the buffer.
 *
 * @param hRequest      HTTP request handle.
 * @param sHeader       Header name.
 * @param sValue        Buffer to store the header value in.
 * @param size          Maximum length of the buffer.
 * @return              True on success, false if the header is not present or the buffer
 *                      is too small.
 */
native bool SteamWorks_GetHTTPResponseHeaderValue(Handle hRequest, const char[] sHeader, char[] sValue, int size);

/**
 * Retrieves the size of the response body. Call from the completion callback.
 *
 * @param hRequest      HTTP request handle.
 * @param size          Variable to store the body size in.
 * @return              True on success, false on an invalid handle.
 */
native bool SteamWorks_GetHTTPResponseBodySize(Handle hRequest, int &size);

/**
 * Retrieves the response body. Call from the completion callback. Use
 * SteamWorks_GetHTTPResponseBodySize first to size the buffer. Not valid for streaming
 * responses.
 *
 * @param hRequest      HTTP request handle.
 * @param sBody         Buffer to store the body in.
 * @param length        Length of the buffer, which must match the body size.
 * @return              True on success, false on an invalid handle, a streaming response,
 *                      or an incorrectly-sized buffer.
 */
native bool SteamWorks_GetHTTPResponseBodyData(Handle hRequest, char[] sBody, int length);

/**
 * Retrieves a chunk of a streaming response body. Call from the data-received callback,
 * passing the offset and length reported by that callback.
 *
 * @param hRequest      HTTP request handle.
 * @param cOffset       Offset of the chunk, as provided by the data-received callback.
 * @param sBody         Buffer to store the chunk in.
 * @param length        Length of the chunk, as provided by the data-received callback.
 * @return              True on success, false on an invalid handle, a non-streaming
 *                      response, or a mismatched offset/length.
 */
native bool SteamWorks_GetHTTPStreamingResponseBodyData(Handle hRequest, int cOffset, char[] sBody, int length);

/**
 * Retrieves download progress for the request. This is zero until a response header with a
 * content-length has been received; for responses with no content-length it stays zero.
 *
 * @param hRequest      HTTP request handle.
 * @param percent       Variable to store the progress percentage in.
 * @return              True on success, false on an invalid handle.
 */
native bool SteamWorks_GetHTTPDownloadProgressPct(Handle hRequest, float &percent);

/**
 * Checks whether the request failed because it timed out (rather than a harder failure).
 *
 * @param hRequest      HTTP request handle.
 * @param bWasTimedOut  Variable to store the result in.
 * @return              True on success, false on an invalid handle.
 */
native bool SteamWorks_GetHTTPRequestWasTimedOut(Handle hRequest, bool &bWasTimedOut);

/**
 * Sets a raw body for a POST request. Fails on a GET request or if GET/POST parameters
 * were already set. This makes the raw body the entire contents of the POST.
 *
 * @param hRequest      HTTP request handle.
 * @param sContentType  Value for the Content-Type header.
 * @param sBody         Raw body data.
 * @param bodylen       Length of the body, in bytes.
 * @return              True on success, false on failure.
 */
native bool SteamWorks_SetHTTPRequestRawPostBody(Handle hRequest, const char[] sContentType, const char[] sBody, int bodylen);

/**
 * Sets a raw POST body read from a file (relative to the game directory). Same constraints
 * as SteamWorks_SetHTTPRequestRawPostBody.
 *
 * @param hRequest      HTTP request handle.
 * @param sContentType  Value for the Content-Type header.
 * @param sFileName     Path to the file, relative to the game directory.
 * @return              True on success, false on failure (e.g. an empty file).
 * @error               Unable to open the file for reading.
 */
native bool SteamWorks_SetHTTPRequestRawPostBodyFromFile(Handle hRequest, const char[] sContentType, const char[] sFileName);

/**
 * Retrieves the full response body and passes it to a callback. Useful for bodies larger
 * than a single fixed buffer. Call from the completion callback.
 *
 * @param hRequest      HTTP request handle.
 * @param fCallback     Callback that receives the body.
 * @param data          Context value passed through to the callback.
 * @param hPlugin       Handle of the plugin that owns the callback, or INVALID_HANDLE for
 *                      the calling plugin.
 * @return              True on success, false on an invalid handle or if the body could not
 *                      be retrieved.
 * @error               Invalid plugin handle or invalid function.
 */
native bool SteamWorks_GetHTTPResponseBodyCallback(Handle hRequest, SteamWorksHTTPBodyCallback fCallback, any data = 0, Handle hPlugin = INVALID_HANDLE);

/**
 * Writes the full response body to a file (relative to the game directory). Call from the
 * completion callback.
 *
 * @param hRequest      HTTP request handle.
 * @param sFileName     Path to the output file, relative to the game directory.
 * @return              True on success, false on an invalid handle or if the body could not
 *                      be retrieved.
 * @error               Unable to open the file for writing.
 */
native bool SteamWorks_WriteHTTPResponseBodyToFile(Handle hRequest, const char[] sFileName);

/**
 * Sends a message to the Game Coordinator.
 *
 * @param unMsgType     Message type.
 * @param pubData       Message payload.
 * @param cubData       Size of the payload, in bytes.
 * @return              An EGCResults value; k_EGCResultNotLoggedOn if not connected to Steam.
 */
native EGCResults SteamWorks_SendMessageToGC(int unMsgType, const char[] pubData, int cubData);

methodmap SteamWorksHTTPRequest < Handle
{
	/**
	 * Creates a new HTTP request.
	 *
	 * @param method        HTTP method to use.
	 * @param sURL          Absolute URL for the request.
	 * @return              A new request handle, or INVALID_HANDLE on failure (including when
	 *                      not connected to Steam).
	 */
	public native SteamWorksHTTPRequest(EHTTPMethod method, const char[] sURL);

	/**
	 * Sets one or two context values that will be passed back to the request's callbacks.
	 * These let you associate arbitrary data with a request.
	 *
	 * @param data1         First context value.
	 * @param data2         Second context value.
	 * @return              True on success, false on an invalid handle or if the request was
	 *                      already sent.
	 */
	public native bool SetContextValue(any data1, any data2 = 0);

	/**
	 * Sets a network-activity timeout, in seconds, for the request. Must be called before
	 * sending. The default is 60 seconds. The timer resets whenever more data is received.
	 *
	 * @param timeout       Timeout in seconds.
	 * @return              True on success, false on an invalid handle or if the request was
	 *                      already sent.
	 */
	public native bool SetNetworkActivityTimeout(int timeout);

	/**
	 * Sets a request header value. Must be called before sending the request.
	 *
	 * @param sName         Header name.
	 * @param sValue        Header value.
	 * @return              True on success, false on an invalid handle or if the request was
	 *                      already sent.
	 */
	public native bool SetHeaderValue(const char[] sName, const char[] sValue);

	/**
	 * Sets a GET or POST parameter on the request (which is used depends on the request
	 * method). Must be called before sending the request.
	 *
	 * @param sName         Parameter name.
	 * @param sValue        Parameter value.
	 * @return              True on success, false on an invalid handle or if the request was
	 *                      already sent.
	 */
	public native bool SetGetOrPostParameter(const char[] sName, const char[] sValue);

	/**
	 * Appends extra user-agent info to the request. This does not clobber the normal user
	 * agent; it is added to the end.
	 *
	 * @param sUserAgentInfo    Extra user-agent info string.
	 * @return              True on success, false on an invalid handle.
	 */
	public native bool SetUserAgentInfo(const char[] sUserAgentInfo);

	/**
	 * Enables or disables verification of SSL/TLS certificates. By default, certificates
	 * are verified for all HTTPS requests.
	 *
	 * @param bRequireVerifiedCertificate   True to require a verified certificate, false to disable.
	 * @return              True on success, false on an invalid handle.
	 */
	public native bool SetRequiresVerifiedCertificate(bool bRequireVerifiedCertificate);

	/**
	 * Sets an absolute timeout, in milliseconds, on the request. Unlike the network-activity
	 * timeout, this is a total time limit that does not reset as data arrives.
	 *
	 * @param unMilliseconds    Total timeout in milliseconds.
	 * @return              True on success, false on an invalid handle.
	 */
	public native bool SetAbsoluteTimeoutMS(int unMilliseconds);

	/**
	 * Sets the callbacks fired for a request. Must be called before sending the request.
	 * The completion callback is used by both regular and streaming requests; the headers
	 * and data callbacks are only fired for streaming requests.
	 *
	 * @param fCompleted    Callback fired when the request completes, or INVALID_FUNCTION.
	 * @param fHeaders      Callback fired when streaming headers arrive, or INVALID_FUNCTION.
	 * @param fData         Callback fired when a streaming data chunk arrives, or INVALID_FUNCTION.
	 * @param hCalling      Handle of the plugin that owns the callbacks, or INVALID_HANDLE for
	 *                      the calling plugin.
	 * @return              True on success, false on an invalid handle.
	 * @error               Invalid plugin handle or invalid function.
	 */
	public native bool SetCallbacks(SteamWorksHTTPRequestCompleted fCompleted = INVALID_FUNCTION, SteamWorksHTTPHeadersReceived fHeaders = INVALID_FUNCTION, SteamWorksHTTPDataReceived fData = INVALID_FUNCTION, Handle hCalling = INVALID_HANDLE);

	/**
	 * Sends an HTTP request. The result is delivered asynchronously to the completion
	 * callback set with SetCallbacks.
	 *
	 * @return              True if the request was sent, false on an invalid handle.
	 */
	public native bool Send();

	/**
	 * Sends an HTTP request and streams the response. Headers and data are delivered
	 * asynchronously to the callbacks set with SetCallbacks.
	 *
	 * @return              True if the request was sent, false on an invalid handle.
	 */
	public native bool SendAndStreamResponse();

	/**
	 * Moves an already-sent request to the tail of the client's request queue.
	 *
	 * @return              True on success, false on an invalid handle or if the request has
	 *                      not been sent.
	 */
	public native bool Defer();

	/**
	 * Moves an already-sent request to the head of the client's request queue.
	 *
	 * @return              True on success, false on an invalid handle or if the request has
	 *                      not been sent.
	 */
	public native bool Prioritize();

	/**
	 * Checks whether a response header is present and retrieves the size of its value, so a
	 * correctly-sized buffer can be allocated for GetResponseHeaderValue. Call from the
	 * completion callback.
	 *
	 * @param sHeader       Header name.
	 * @param size          Variable to store the header value size in.
	 * @return              True if the header is present, false otherwise.
	 */
	public native bool GetResponseHeaderSize(const char[] sHeader, int &size);

	/**
	 * Retrieves a response header value. Call from the completion callback. Use
	 * GetResponseHeaderSize first to size the buffer.
	 *
	 * @param sHeader       Header name.
	 * @param sValue        Buffer to store the header value in.
	 * @param size          Maximum length of the buffer.
	 * @return              True on success, false if the header is not present or the buffer
	 *                      is too small.
	 */
	public native bool GetResponseHeaderValue(const char[] sHeader, char[] sValue, int size);

	/**
	 * Retrieves the size of the response body. Call from the completion callback.
	 *
	 * @param size          Variable to store the body size in.
	 * @return              True on success, false on an invalid handle.
	 */
	public native bool GetResponseBodySize(int &size);

	/**
	 * Retrieves the response body. Call from the completion callback. Use GetResponseBodySize
	 * first to size the buffer. Not valid for streaming responses.
	 *
	 * @param sBody         Buffer to store the body in.
	 * @param length        Length of the buffer, which must match the body size.
	 * @return              True on success, false on an invalid handle, a streaming response,
	 *                      or an incorrectly-sized buffer.
	 */
	public native bool GetResponseBodyData(char[] sBody, int length);

	/**
	 * Retrieves a chunk of a streaming response body. Call from the data-received callback,
	 * passing the offset and length reported by that callback.
	 *
	 * @param cOffset       Offset of the chunk, as provided by the data-received callback.
	 * @param sBody         Buffer to store the chunk in.
	 * @param length        Length of the chunk, as provided by the data-received callback.
	 * @return              True on success, false on an invalid handle, a non-streaming
	 *                      response, or a mismatched offset/length.
	 */
	public native bool GetStreamingResponseBodyData(int cOffset, char[] sBody, int length);

	/**
	 * Retrieves download progress for the request. This is zero until a response header with
	 * a content-length has been received; for responses with no content-length it stays zero.
	 *
	 * @param percent       Variable to store the progress percentage in.
	 * @return              True on success, false on an invalid handle.
	 */
	public native bool GetDownloadProgressPct(float &percent);

	/**
	 * Checks whether the request failed because it timed out (rather than a harder failure).
	 *
	 * @param bWasTimedOut  Variable to store the result in.
	 * @return              True on success, false on an invalid handle.
	 */
	public native bool GetWasTimedOut(bool &bWasTimedOut);

	/**
	 * Sets a raw body for a POST request. Fails on a GET request or if GET/POST parameters
	 * were already set. This makes the raw body the entire contents of the POST.
	 *
	 * @param sContentType  Value for the Content-Type header.
	 * @param sBody         Raw body data.
	 * @param bodylen       Length of the body, in bytes.
	 * @return              True on success, false on failure.
	 */
	public native bool SetRawPostBody(const char[] sContentType, const char[] sBody, int bodylen);

	/**
	 * Sets a raw POST body read from a file (relative to the game directory). Same constraints
	 * as SetRawPostBody.
	 *
	 * @param sContentType  Value for the Content-Type header.
	 * @param sFileName     Path to the file, relative to the game directory.
	 * @return              True on success, false on failure (e.g. an empty file).
	 * @error               Unable to open the file for reading.
	 */
	public native bool SetRawPostBodyFromFile(const char[] sContentType, const char[] sFileName);

	/**
	 * Retrieves the full response body and passes it to a callback. Useful for bodies larger
	 * than a single fixed buffer. Call from the completion callback.
	 *
	 * @param fCallback     Callback that receives the body.
	 * @param data          Context value passed through to the callback.
	 * @param hPlugin       Handle of the plugin that owns the callback, or INVALID_HANDLE for
	 *                      the calling plugin.
	 * @return              True on success, false on an invalid handle or if the body could not
	 *                      be retrieved.
	 * @error               Invalid plugin handle or invalid function.
	 */
	public native bool GetResponseBodyCallback(SteamWorksHTTPBodyCallback fCallback, any data = 0, Handle hPlugin = INVALID_HANDLE);

	/**
	 * Writes the full response body to a file (relative to the game directory). Call from the
	 * completion callback.
	 *
	 * @param sFileName     Path to the output file, relative to the game directory.
	 * @return              True on success, false on an invalid handle or if the body could not
	 *                      be retrieved.
	 * @error               Unable to open the file for writing.
	 */
	public native bool WriteResponseBodyToFile(const char[] sFileName);
};

/* Forwards */

/**
 * Deprecated alias for SteamWorks_OnValidateClient, kept for backwards compatibility.
 * Use SteamWorks_OnValidateClient in new code.
 *
 * @param ownerauthid   32-bit account ID of the account that owns the game license.
 * @param authid        32-bit account ID of the validated client.
 */
forward void SW_OnValidateClient(int ownerauthid, int authid);

/**
 * Called when a client has been validated by Steam. For clients playing on a borrowed
 * (Family Sharing) license, the owner and client account IDs differ.
 *
 * @param ownerauthid   32-bit account ID of the account that owns the game license.
 * @param authid        32-bit account ID of the validated client.
 */
forward void SteamWorks_OnValidateClient(int ownerauthid, int authid);

/**
 * Called when the server successfully connects (logs on) to Steam.
 */
forward void SteamWorks_SteamServersConnected();

/**
 * Called when the server fails to connect to Steam.
 *
 * @param result        Result code describing the failure.
 */
forward void SteamWorks_SteamServersConnectFailure(EResult result);

/**
 * Called when the server is disconnected from Steam.
 *
 * @param result        Result code describing the disconnection.
 */
forward void SteamWorks_SteamServersDisconnected(EResult result);

/**
 * Called when the Steam master server has requested that the server restart. Return
 * Plugin_Handled or higher to indicate the restart request has been handled.
 *
 * @return              Plugin_Handled or higher to signal the restart was handled,
 *                      Plugin_Continue otherwise.
 */
forward Action SteamWorks_RestartRequested();

/**
 * Called when the server is about to log on anonymously, giving a plugin the chance to
 * supply a Game Server Login Token (GSLT) instead. Write the token into sToken.
 *
 * @param sToken        Buffer to write the login token into.
 * @param maxlen        Maximum length of the buffer.
 */
forward void SteamWorks_TokenRequested(char[] sToken, int maxlen);

/**
 * Called with the result of a SteamWorks_GetUserGroupStatus /
 * SteamWorks_GetUserGroupStatusAuthID request.
 *
 * @param authid        32-bit account ID of the user.
 * @param groupid       32-bit account ID of the group.
 * @param isMember      True if the user is a member of the group.
 * @param isOfficer     True if the user is an officer of the group.
 */
forward void SteamWorks_OnClientGroupStatus(int authid, int groupid, bool isMember, bool isOfficer);

/**
 * Called when the game code sends a message to the Game Coordinator, letting a plugin
 * observe or override it. Return a non-OK EGCResults value to supersede the send, or
 * k_EGCResultOK to let it proceed.
 *
 * @param unMsgType     Message type.
 * @param pubData       Message payload.
 * @param cubData       Size of the payload, in bytes.
 * @return              An EGCResults value to override the send, or k_EGCResultOK to allow it.
 */
forward EGCResults SteamWorks_GCSendMessage(int unMsgType, const char[] pubData, int cubData);

/**
 * Called when a message from the Game Coordinator is available to be retrieved.
 *
 * @param cubData       Size of the available message, in bytes.
 */
forward void SteamWorks_GCMsgAvailable(int cubData);

/**
 * Called when the game code retrieves a message from the Game Coordinator, letting a plugin
 * observe or override it. Return a non-OK EGCResults value to supersede the retrieval.
 *
 * @param punMsgType    Message type.
 * @param pubDest       Message payload.
 * @param cubDest       Size of the destination buffer, in bytes.
 * @param pcubMsgSize   Size of the message, in bytes.
 * @return              An EGCResults value to override the retrieval, or k_EGCResultOK to
 *                      allow it.
 */
forward EGCResults SteamWorks_GCRetrieveMessage(int punMsgType, const char[] pubDest, int cubDest, int pcubMsgSize);

/**
 * Called when a user's stats have been received in response to
 * SteamWorks_RequestStats or SteamWorks_RequestStatsAuthID.
 *
 * @param authid    32-bit account ID of the user whose stats were requested.
 * @param result       EResult code; k_EResultOK (1) indicates success.
 * @param gameid        Game ID (AppID) of the game the stats were requested for.
 */
forward void SteamWorks_OnUserStatsReceived(int authid, EResult result, int gameid);

/**
 * Called when Steam unloads user stats from the cache.
 * After this, stats for this user are no longer available until RequestStats is called again.
 *
 * @param authid        32-bit account ID of the user.
 */
forward void SteamWorks_OnUserStatsUnloaded(int authid);

/**
 * Called when a request to store user stats has completed.
 *
 * @param authid        32-bit account ID of the user.
 * @param result        EResult code; k_EResultOK (1) indicates success.
 */
forward void SteamWorks_OnUserStatsStored(int authid, EResult result);

public Extension __ext_SteamWorks =
{
	name = "SteamWorks",
	file = "SteamWorks.ext",
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
};

#if !defined REQUIRE_EXTENSIONS
public void __ext_SteamWorks_SetNTVOptional()
{
	MarkNativeAsOptional("SteamWorks_IsVACEnabled");
	MarkNativeAsOptional("SteamWorks_GetPublicIP");
	MarkNativeAsOptional("SteamWorks_GetPublicIPCell");
	MarkNativeAsOptional("SteamWorks_IsLoaded");
	MarkNativeAsOptional("SteamWorks_SetGameData");
	MarkNativeAsOptional("SteamWorks_SetGameDescription");
	MarkNativeAsOptional("SteamWorks_IsConnected");
	MarkNativeAsOptional("SteamWorks_SetRule");
	MarkNativeAsOptional("SteamWorks_ClearRules");
	MarkNativeAsOptional("SteamWorks_SetAdvertiseServerActive");
	MarkNativeAsOptional("SteamWorks_GetFakeIP");
	MarkNativeAsOptional("SteamWorks_ForceHeartbeat");
	MarkNativeAsOptional("SteamWorks_GetUserGroupStatus");
	MarkNativeAsOptional("SteamWorks_GetUserGroupStatusAuthID");

	MarkNativeAsOptional("SteamWorks_HasLicenseForApp");
	MarkNativeAsOptional("SteamWorks_HasLicenseForAppId");
	MarkNativeAsOptional("SteamWorks_GetClientSteamID");

	MarkNativeAsOptional("SteamWorks_RequestStatsAuthID");
	MarkNativeAsOptional("SteamWorks_RequestStats");
	MarkNativeAsOptional("SteamWorks_GetStatCell");
	MarkNativeAsOptional("SteamWorks_GetStatAuthIDCell");
	MarkNativeAsOptional("SteamWorks_GetStatFloat");
	MarkNativeAsOptional("SteamWorks_GetStatAuthIDFloat");

	MarkNativeAsOptional("SteamWorks_SendMessageToGC");

	MarkNativeAsOptional("SteamWorks_CreateHTTPRequest");
	MarkNativeAsOptional("SteamWorks_SetHTTPRequestContextValue");
	MarkNativeAsOptional("SteamWorks_SetHTTPRequestNetworkActivityTimeout");
	MarkNativeAsOptional("SteamWorks_SetHTTPRequestHeaderValue");
	MarkNativeAsOptional("SteamWorks_SetHTTPRequestGetOrPostParameter");

	MarkNativeAsOptional("SteamWorks_SetHTTPCallbacks");
	MarkNativeAsOptional("SteamWorks_SendHTTPRequest");
	MarkNativeAsOptional("SteamWorks_SendHTTPRequestAndStreamResponse");
	MarkNativeAsOptional("SteamWorks_DeferHTTPRequest");
	MarkNativeAsOptional("SteamWorks_PrioritizeHTTPRequest");
	MarkNativeAsOptional("SteamWorks_GetHTTPResponseHeaderSize");
	MarkNativeAsOptional("SteamWorks_GetHTTPResponseHeaderValue");
	MarkNativeAsOptional("SteamWorks_GetHTTPResponseBodySize");
	MarkNativeAsOptional("SteamWorks_GetHTTPResponseBodyData");
	MarkNativeAsOptional("SteamWorks_GetHTTPStreamingResponseBodyData");
	MarkNativeAsOptional("SteamWorks_GetHTTPDownloadProgressPct");
	MarkNativeAsOptional("SteamWorks_SetHTTPRequestRawPostBody");
	MarkNativeAsOptional("SteamWorks_SetHTTPRequestRawPostBodyFromFile");

	MarkNativeAsOptional("SteamWorks_GetHTTPResponseBodyCallback");
	MarkNativeAsOptional("SteamWorks_WriteHTTPResponseBodyToFile");

	MarkNativeAsOptional("SteamWorksHTTPRequest.SteamWorksHTTPRequest");
	MarkNativeAsOptional("SteamWorksHTTPRequest.SetContextValue");
	MarkNativeAsOptional("SteamWorksHTTPRequest.SetNetworkActivityTimeout");
	MarkNativeAsOptional("SteamWorksHTTPRequest.SetHeaderValue");
	MarkNativeAsOptional("SteamWorksHTTPRequest.SetGetOrPostParameter");
	MarkNativeAsOptional("SteamWorksHTTPRequest.SetUserAgentInfo");
	MarkNativeAsOptional("SteamWorksHTTPRequest.SetRequiresVerifiedCertificate");
	MarkNativeAsOptional("SteamWorksHTTPRequest.SetAbsoluteTimeoutMS");
	MarkNativeAsOptional("SteamWorksHTTPRequest.SetCallbacks");
	MarkNativeAsOptional("SteamWorksHTTPRequest.Send");
	MarkNativeAsOptional("SteamWorksHTTPRequest.SendAndStreamResponse");
	MarkNativeAsOptional("SteamWorksHTTPRequest.Defer");
	MarkNativeAsOptional("SteamWorksHTTPRequest.Prioritize");
	MarkNativeAsOptional("SteamWorksHTTPRequest.GetResponseHeaderSize");
	MarkNativeAsOptional("SteamWorksHTTPRequest.GetResponseHeaderValue");
	MarkNativeAsOptional("SteamWorksHTTPRequest.GetResponseBodySize");
	MarkNativeAsOptional("SteamWorksHTTPRequest.GetResponseBodyData");
	MarkNativeAsOptional("SteamWorksHTTPRequest.GetStreamingResponseBodyData");
	MarkNativeAsOptional("SteamWorksHTTPRequest.GetDownloadProgressPct");
	MarkNativeAsOptional("SteamWorksHTTPRequest.GetWasTimedOut");
	MarkNativeAsOptional("SteamWorksHTTPRequest.SetRawPostBody");
	MarkNativeAsOptional("SteamWorksHTTPRequest.SetRawPostBodyFromFile");
	MarkNativeAsOptional("SteamWorksHTTPRequest.GetResponseBodyCallback");
	MarkNativeAsOptional("SteamWorksHTTPRequest.WriteResponseBodyToFile");
}
#endif
