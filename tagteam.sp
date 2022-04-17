#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <shavit>

// Invite 
bool g_bSentInvitation[MAXPLAYERS+1][MAXPLAYERS+1];
Handle g_bInviationTimer[MAXPLAYERS+1];
bool g_bIsInTeam[MAXPLAYERS+1];
bool g_bIsCreatingTeam[MAXPLAYERS+1];

// Team
ArrayList g_aTeamMember[MAXPLAYERS+1];
int g_iLeaderIndex[MAXPLAYERS+1];
int g_iNextPlayerIndex[MAXPLAYERS+1];

public void OnPluginStart()
{
    RegConsoleCmd("sm_tagteam", Command_TagTeam);
    RegConsoleCmd("sm_showteam", Command_ShowTeam);
    RegConsoleCmd("sm_breakup", Command_Breakup);
    RegConsoleCmd("sm_exitteam", Command_Exit);
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

public Action Command_ShowTeam(int client, int args)
{
    if (!client)
    {
        ReplyToCommand(client, "Who.ru");
        return Plugin_Handled;
    }

    if (!g_aTeamMember[client] || !g_aTeamMember[client].Length)
    {
        PrintToChat(client, "[!] No member");
        return Plugin_Handled;
    }

    for (int i = 0; i < g_aTeamMember[client].Length; i++)
    {
        int member = g_aTeamMember[client].Get(i);
        PrintToChat(client, "[-] %N. Leader: %N", member, g_iLeaderIndex[member]);
    }

    return Plugin_Handled;
}

public Action Command_Breakup(int client, int args)
{
    if (!client)
    {
        ReplyToCommand(client, "Who.ru");
        return Plugin_Handled;
    }

    BreakupTeam(client);

    return Plugin_Handled;
}

public Action Command_Exit(int client, int args)
{
    if (!client)
    {
        ReplyToCommand(client, "Who.ru");
        return Plugin_Handled;
    }

    ExitTeam(client);

    return Plugin_Handled;
}

// Invite functions
// A few things we need to be careful with:
// 1. Dont add the client + invited + invitation sent players + bots to menu item
// 2. If invited target gets the invitation but doesn't do anything to it then it should be invalid after 30sec
// 3. Reject any join-team action when the team is full
void OpenTagteamMenu(int client)
{
    if (g_bIsInTeam[client])
    {
        PrintToChat(client, "[!] Failed to open tagteam menu. You are already in a team.");
        return;
    }

    Menu menu = new Menu(MenuHandler_Tagteam);
    menu.SetTitle("Invite players to join your team");

    char info[4];
    char player_name[MAX_NAME_LENGTH];

    menu.AddItem("create", "Create team");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidClient(i))
            continue;

        if (i == client || IsFakeClient(i))
            continue;
        
        if (g_bIsInTeam[i] || g_bIsCreatingTeam[i])
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

        if (!g_bIsCreatingTeam[client])
            g_bIsCreatingTeam[client] = true;

        if (!strcmp("create", info))
        {
            if (CreateTeam(client))
            {
                return 0;
            }
        }
        else 
        {
            int target = StringToInt(info);

            if (!IsValidClient(target))
            {
                OpenTagteamMenu(client);
                return 0;
            }

            if (IsFakeClient(target))
            {
                JoinTeam(client, target);
                OpenTagteamMenu(client);
            }
            else
            {
                g_bSentInvitation[client][target] = true;

                PrintToChat(target, "[-] You got an invation to %N's team", client);
                OpenInvitedMenu(target, client);
            }
        }

        OpenTagteamMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void OpenInvitedMenu(int receiver, int sender)
{
    Menu menu = new Menu(MenuHandler_Tagteam_Invited);
    menu.SetTitle("You just got an invitation to %N's team, accept it?", sender);

    char info[16];
    FormatEx(info, 16, "yes;%d", sender);

    menu.AddItem(info, "Yes");
    FormatEx(info, 16, "no;%d", sender);
    menu.AddItem(info, "No!!!!");

    menu.Display(receiver, 30);

    DataPack dp = new DataPack();
    dp.WriteCell(receiver);
    dp.WriteCell(sender);

    // I dont know why but it has ~1 second delay
    g_bInviationTimer[receiver] = CreateTimer(30.0, Timer_InvitationHandler, dp);
}

public int MenuHandler_Tagteam_Invited(Menu menu, MenuAction action, int receiver, int item)
{
    if (action == MenuAction_Select)
    {
        char info[16];
        menu.GetItem(item, info, 16);

        char buffer[2][16];
        ExplodeString(info, ";", buffer, 16, 16);
        int sender = StringToInt(buffer[1]);

        if (!strcmp("yes", buffer[0]))
        {
            JoinTeam(sender, receiver);
        }
        else if (!strcmp("no", buffer[0]))
        {
            PrintToChat(receiver, "[+] You rejected %N's invitation", sender);
            PrintToChat(sender, "[+] %N rejected the invitation", receiver);
        }

        g_bSentInvitation[sender][receiver] = false;
        KillTimer(g_bInviationTimer[receiver]);
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
    int receiver = dp.ReadCell();
    int sender = dp.ReadCell();

    delete dp;

    PrintToChat(receiver, "[+] The invitation from %N is automatically rejected.", sender);
    g_bSentInvitation[sender][receiver] = false;
}


// Team functions
void JoinTeam(int leader, int member)
{
    if (g_bIsInTeam[member])
    {
        PrintToChat(member, "[!] Failed to join team. You are already in a team.");
        return;
    }

    if (!g_aTeamMember[leader])
    {
        g_aTeamMember[leader] = new ArrayList();
    }

    int len = g_aTeamMember[leader].Length;

    // TODO: A cvar to set max team size
    if (len > 10) 
    {
        PrintToChat(member, "[!] Failed to join team. Team is full");
        return;
    }

    g_aTeamMember[leader].Push(member);

    if (!g_bIsInTeam[leader])
    {
        g_bIsInTeam[leader] = true;
    }

    PrintToChat(leader, "[+] %N has joint your team", member);
    PrintToChat(member, "[+] You have joint %N's team", leader);

    g_bIsInTeam[member] = true;

    #if 0
        PrintToServer("------");

        for (int i = 0; i < g_aTeamMember[leader].Length; i++)
        {
            int t = g_aTeamMember[leader].Get(i);
            PrintToServer("%N - %d", t, t);
        }
    #endif
}

bool CreateTeam(int leader)
{
    if (!g_aTeamMember[leader] || !g_aTeamMember[leader].Length)
    {
        PrintToChat(leader, "[!] Failed to create team. No member");
        return false;
    }

    // kinda stupid but ok
    g_iLeaderIndex[leader] = leader;

    // In case someone joins the team and disconnects from the server
    ArrayList temp = g_aTeamMember[leader].Clone();
    g_aTeamMember[leader].Clear();
    PrintToServer("Length: %d", temp.Length);
    g_aTeamMember[leader].Push(leader);
    g_iNextPlayerIndex[leader] = temp.Get(0);

    for (int i = 1; i < temp.Length; i++)
    {
        int member = temp.Get(i - 1);

        if (!IsValidClient(member))
            continue;

        g_aTeamMember[leader].Push(member);
        g_iLeaderIndex[member] = leader;
        
        int next_player = temp.Get(i);
        g_iNextPlayerIndex[member] = next_player;
        if (i == temp.Length - 1)
            g_iNextPlayerIndex[member] = leader;

        PrintToServer("Member: %N - %d. Leader: %N - %d", member, member, leader, leader);
    }

    delete temp;

    #if 1
        PrintToServer("------");

        for (int i = 0; i < g_aTeamMember[leader].Length; i++)
        {
            int member = g_aTeamMember[leader].Get(i);
            PrintToServer("%N - %d", member, member);
        }
    #endif 

    return true;
}

void BreakupTeam(int leader)
{
    if (!g_aTeamMember[leader] || !g_aTeamMember[leader].Length)
    {
        return;
    }

    for (int i = 0; i < g_aTeamMember[leader].Length; i++)
    {
        int member = g_aTeamMember[leader].Get(i);

        if (!IsValidClient(member))
            continue;

        PrintToChat(member, "[+] Your team has been broken up");
        g_bIsInTeam[member] = false;
        g_bSentInvitation[leader][member] = false;
        g_bIsCreatingTeam[member] = false;
        g_iLeaderIndex[member] = 0;
    }

    g_aTeamMember[leader].Clear();
    delete g_aTeamMember[leader];
}

void ExitTeam(int client)
{
    g_bIsInTeam[client] = false;
    g_bIsCreatingTeam[client] = false;
    int leader = g_iLeaderIndex[client];

    #if 0
        PrintToChat(client, "Leader: %N - %d, Client: %N - %d", leader, leader, client, client);
    #endif

    g_iLeaderIndex[client] = 0;

    if (leader && g_aTeamMember[leader] && g_aTeamMember[leader].Length)
    {
        g_bSentInvitation[leader][client] = false;

        int index = g_aTeamMember[leader].FindValue(client);
        if (index != -1)
        {
            g_aTeamMember[leader].Erase(index);
        }

        // If leader is the only member left, disband the team
        if (g_aTeamMember[leader].Length == 1)
        {
            // Reuse it haha
            BreakupTeam(leader);
        }
    }

    PrintToChat(client, "[+] You have left %N's team", leader);
}


// Checkpoint functions
public Action Shavit_OnCheckPointMenuMade(int client, bool segment, Menu menu)
{
    int style = Shavit_GetBhopStyle(client);
    if (!Shavit_GetStyleSettingBool(style, "tagteam"))
    {
        return Plugin_Continue;
    }

    if (!g_bIsInTeam[client])
    {
        PrintToChat(client, "[!] Failed to open checkpoint menu. You are not in a team");

        return Plugin_Handled;
    }

    char display[64];
    FormatEx(display, sizeof(display), "Pass to next team member");
    menu.AddItem("pass", display);

    // if client is leader
    if (client == g_iLeaderIndex[client])
    {
        FormatEx(display, sizeof(display), "Breakup team");
        menu.AddItem("breakup", display);
    }

    return Plugin_Changed;
}

public Action Shavit_OnCheckpointMenuSelect(int client, int param2, char[] info, int maxlength, int currentCheckpoint, int maxCPs)
{
    if (StrEqual(info, "pass"))
    {
        // PassToNext(client);
        return Plugin_Stop;
    }

    if (StrEqual(info, "breakup"))
    {
        BreakupTeam(client);
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

