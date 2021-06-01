/********** TIMERS **********/

Action Timer_GetNetInfo(Handle timer)
{
    // reset all client based vars on plugin reload
    for (int Cl = 1; Cl <= MaxClients; Cl++)
    {
        if (IsValidClient(Cl))
        {
            // convert to percentages
            lossFor[Cl]      = GetClientAvgLoss(Cl, NetFlow_Both) * 100.0;
            chokeFor[Cl]     = GetClientAvgChoke(Cl, NetFlow_Both) * 100.0;
            inchokeFor[Cl]   = GetClientAvgChoke(Cl, NetFlow_Incoming) * 100.0;
            outchokeFor[Cl]  = GetClientAvgChoke(Cl, NetFlow_Outgoing) * 100.0;
            // convert to ms
            pingFor[Cl]      = GetClientLatency(Cl, NetFlow_Both) * 1000.0;
            rateFor[Cl]      = GetClientAvgData(Cl, NetFlow_Both) / 125.0;
            ppsFor[Cl]       = GetClientAvgPackets(Cl, NetFlow_Both);
            if (LiveFeedOn[Cl])
            {
                LiveFeed_NetInfo(GetClientUserId(Cl));
            }
        }
    }
}

Action Timer_TriggerTimedStuff(Handle timer)
{
    ActuallySetRandomSeed();
}
