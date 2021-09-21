#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <shavit>

bool g_bSentInvitation[MAXPLAYERS+1][MAXPLAYERS+1];
Handle g_bInviationTimer[MAXPLAYERS+1];


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

// A few things we need to be careful with:
// 1. Dont add the client + invited + invitation sent players + bots to menu item
// 2. If invited target gets the invitation but doesn't do anything to it then it should be invalid after 30sec
// 3. Reject any join-team action when the team is full
void OpenTagteamMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Tagteam);
    menu.SetTitle("Invite players to join your team");

    char info[4];
    char player_name[MAX_NAME_LENGTH];

    menu.AddItem("create", "Create team");

    // TODO: Dont add the player himself
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidClient(i) || IsFakeClient(i) )
            continue;

        if (g_bSentInvitation[client][i])
            continue;

        IntToString(i, info, 4);
        GetClientName(i, player_name, MAX_NAME_LENGTH);

        menu.AddItem(info, player_name);
    }

    menu.Display(client, -1);
}

public int MenuHandler_Tagteam(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        char info[8];
        menu.GetItem(item, info, 8);

        if (!strcmp("create", info))
        {
            PrintToChat(client, "[-] TODO: Create team");
        }
        else 
        {
            int target = StringToInt(info);
            g_bSentInvitation[client][target] = true;
            //PrintToChat(client, "[-] i: %d - %N", target, target);

            PrintToChat(target, "[-] You got an invation to %N's team", client);
            OpenInvitedMenu(target, client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

// target here is the invited guy, client is invite-sender
void OpenInvitedMenu(int target, int client)
{
    Menu menu = new Menu(MenuHandler_Tagteam_Invited);
    menu.SetTitle("You just got an invitation to %N's team, accept it?", client);

    char info[16];
    FormatEx(info, 16, "yes;%d", client);

    menu.AddItem(info, "Yes");
    FormatEx(info, 16, "no;%d", client);
    menu.AddItem(info, "No!!!!");

    menu.Display(target, 29);

    DataPack dp = new DataPack();
    dp.WriteCell(target);
    dp.WriteCell(client);

    // I dont know why but it has ~1 second delay
    g_bInviationTimer[target] = CreateTimer(30.0, Timer_InvitationHandler, dp);
}

public int MenuHandler_Tagteam_Invited(Menu menu, MenuAction action, int target, int item)
{
    if (action == MenuAction_Select)
    {
        char info[16];
        menu.GetItem(item, info, 16);

        char buffer[2][16];
        ExplodeString(info, ";", buffer, 16, 16);
        int client = StringToInt(buffer[1]);

        if (!strcmp("yes", buffer[0]))
        {
            PrintToChat(target, "[+] You joined %N's team", client);
            PrintToChat(client, "[+] %N joined your team", target);
            g_bSentInvitation[client][target] = false;
            KillTimer(g_bInviationTimer[target]);
        }
        else if (!strcmp("no", buffer[0]))
        {
            PrintToChat(target, "[+] You rejected %N's invitation", client);
            PrintToChat(client, "[+] %N rejected the invitation", target);
            g_bSentInvitation[client][target] = false;
            KillTimer(g_bInviationTimer[target]);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public Action Timer_InvitationHandler(Handle timer, DataPack dp)
{
    dp.Reset();
    int target = dp.ReadCell();
    int client = dp.ReadCell();

    PrintToChat(target, "[+] The invitation from %N is automatically rejected.", client);
    g_bSentInvitation[client][target] = false;
}