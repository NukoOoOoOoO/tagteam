ArrayList g_aTeamMember[MAXPLAYERS+1];

void JoinTeam(int leader, int member)
{
    if (!g_aTeamMember[leader])
    {
        g_aTeamMember[leader] = new ArrayList();
    }

    // TODO: If member is creating a team but joins someone else's team, then break up member's team

    int len = g_aTeamMember[leader].Length;

    if (len > 10) 
    {
        PrintToChat(member, "[!] Failed to join team. Team is full");
        return;
    }

    g_aTeamMember[leader].Push(member);

    PrintToChat(leader, "[+] %N has joint your team", member);

    g_bIsInTeam[member] = true;

    PrintToServer("------");

    for (int i = 0; i < g_aTeamMember[leader].Length; i++)
    {
        int t = g_aTeamMember[leader].Get(i);
        PrintToServer("%N - %d", t, t);
    }
}

bool CreateTeam(int leader)
{
    if (!g_aTeamMember[leader] || !g_aTeamMember[leader].Length)
    {
        PrintToChat(leader, "[!] Failed to create team. No member");
        return false;
    }

    ArrayList temp = g_aTeamMember[leader].Clone();
    g_aTeamMember[leader].Clear();
    PrintToServer("Length: %d", g_aTeamMember[leader].Length);
    g_aTeamMember[leader].Push(leader);

    for (int i = 0; i < temp.Length; i++)
    {
        int member = temp.Get(i);

        if (!IsValidClient(member))
            continue;

        g_aTeamMember[leader].Push(member);
    }

    PrintToServer("------");

    for (int i = 0; i < g_aTeamMember[leader].Length; i++)
    {
        int member = g_aTeamMember[leader].Get(i);
        PrintToServer("%N - %d", member, member);
    }

    delete temp;

    return true;
}