#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <shavit>
#include "tagteam/invite.sp"
#include "tagteam/team.sp"

public void OnPluginStart()
{
    RegConsoleCmd("sm_tagteam", Command_TagTeam);
}

public Action Command_TagTeam(int client, int args)
{
    if (!client)
    {
        ReplyToCommand(client, "Who.ru");
        return Plugin_Handled;
    }

    OpenTagteamMenu(client);

    return Plugin_Handled;
}