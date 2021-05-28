#include <sourcemod>
#include <sdktools>

public void OnPluginStart()
{
    RegConsoleCmd("sm_test", CommandTest);
}
public Action CommandTest(int client, int args)
{
    int userinfo = FindStringTable("userinfo");

    if (userinfo == INVALID_STRING_TABLE)
    {
        LogError("cannot find userinfo tableid!");
        return Plugin_Handled;
    }

    char userInfo[334];
    char userInfo2[334];
    for (int i = 1; i < 33; i++)
    {
        //ReadStringTable(tableIdx, i, userInfo, sizeof(userInfo));
        //GetStringTableData(tableIdx, client - 1, userInfo, sizeof(userInfo))
        ReadStringTable(userinfo, i - 1, userInfo, sizeof(userInfo));
        GetStringTableData(userinfo, i - 1, userInfo2, 64)
        LogMessage("%s", userInfo);
        LogMessage("%s", userInfo2);

    }
        LogMessage("%i",  GetStringTableNumStrings(userinfo));

    //char userInfo[334];
    //
    //if (!GetStringTableData(tableIdx, client - 1, userInfo, 334))
    //{
    //    LogError("cannot find string table data!");
    //    return Plugin_Handled;
    //}
    //
    //bool lockTable = LockStringTables(false);
    //SetStringTableData(tableIdx, client - 1, userInfo, 334);
    //LockStringTables(lockTable);
    //return Plugin_Handled;
}
