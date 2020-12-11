#define MANTRA_CHANNEL -216684563
#define VOICE_CHANNEL   166845631
#define RLV_CHANNEL     166845630
#define MC_CHANNEL            999
#define API_RESET              -1
#define API_SELF_DESC          -2
#define API_SELF_SAY           -3
#define API_SAY                -4
key owner = NULL_KEY;
integer noim = FALSE;
string name = "";
string prefix = "xx";
list nearby = [];
string path;

doScan()
{
    llSetTimerEvent(0.0);
    if(!noim)
    {
        llOwnerSay("@clear=recvimfrom,clear=sendimto");
        nearby = [];
        llMessageLinked(LINK_SET, API_SAY, "/me can IM with people within 20 meters of them again.", (key)name);
        return;
    }
    list check = llGetAgentList(AGENT_LIST_REGION, []);
    vector pos = llGetPos();

    // Filter by distance.
    integer l = llGetListLength(check);
    integer i;
    key k;
    for(l--; l >= 0; l--)
    {
        k = llList2Key(check, l);
        if(llVecDist(pos, llList2Vector(llGetObjectDetails(k, [OBJECT_POS]), 0)) > 19.5) check = llDeleteSubList(check, l, l);
    }
    
    // Check for every key in nearby, remove restriction if no longer present.
    l = llGetListLength(nearby);
    for(l--; l >= 0; l--)
    {
        k = llList2Key(nearby, l);
        i = llListFindList(check, [k]);
        if(i == -1) 
        {
            llOwnerSay("@recvimfrom:" + (string)k +"=y,sendimto:" + (string)k +"=y");
            nearby = llDeleteSubList(nearby, l, l);
        }
    }
    
    // Check for newly arrived people, add restriction.
    l = llGetListLength(check);
    for(l--; l >= 0; l--)
    {
        k = llList2Key(check, l);
        i = llListFindList(nearby, [k]);
        if(i == -1 && llGetAgentSize(k) != ZERO_VECTOR && k != (key)NULL_KEY && k != owner)
        {
            llOwnerSay("@recvimfrom:" + (string)k +"=n,sendimto:" + (string)k +"=n");
            nearby += [k];
        }
    }
    llSetTimerEvent(1.0);
}

integer getStringBytes(string msg)
{
    return (llStringLength((string)llParseString2List(llStringToBase64(msg), ["="], [])) * 3) >> 2;
}

integer contains(string haystack, string needle)
{
    return ~llSubStringIndex(haystack, needle);
}

integer endswith(string haystack, string needle)
{
    return llDeleteSubString(haystack, 0x8000000F, ~llStringLength(needle)) == needle;
}

integer startswith(string haystack, string needle)
{
    return llDeleteSubString(haystack, llStringLength(needle), 0x7FFFFFF0) == needle;
}

string slurl()
{
    vector pos = llGetPos();
    return "http://maps.secondlife.com/secondlife/" + llEscapeURL(llGetRegionName()) + "/" + (string)llRound(pos.x) + "/" + (string)llRound(pos.y) + "/" + (string)llRound(pos.z) + "/";
}

string strreplace(string source, string pattern, string replace) 
{
    while (llSubStringIndex(source, pattern) > -1) 
    {
        integer len = llStringLength(pattern);
        integer pos = llSubStringIndex(source, pattern);
        if (llStringLength(source) == len) { source = replace; }
        else if (pos == 0) { source = replace+llGetSubString(source, pos+len, -1); }
        else if (pos == llStringLength(source)-len) { source = llGetSubString(source, 0, pos-1)+replace; }
        else { source = llGetSubString(source, 0, pos-1)+replace+llGetSubString(source, pos+len, -1); }
    }
    return source;
}

doSetup()
{
    llSetTimerEvent(0.0);
    llOwnerSay("@accepttp:" + (string)owner + "=add,accepttprequest:" + (string) owner + "=add,acceptpermission=add");
    nearby = [];
    if(noim) llSetTimerEvent(1.0);
}

default
{
    link_message(integer sender_num, integer num, string str, key id)
    {
        if(num == API_RESET && id == llGetOwner()) llResetScript();
    }

    changed(integer change)
    {
        if(change & CHANGED_OWNER) llResetScript();
        if(change & CHANGED_TELEPORT) llInstantMessage(owner, "secondlife:///app/agent/" + (string)llGetOwner() + "/about has arrived at " + slurl() + ".");
    }

    attach(key id)
    {
        if(id != NULL_KEY) 
        {
            doSetup();
            llInstantMessage(owner, "The intrusive thoughts slave has been worn by secondlife:///app/agent/" + (string)llGetOwner() + "/about at " + slurl() + ".");
        }
        else
        {
            llSetTimerEvent(0.0);
            llInstantMessage(owner, "The intrusive thoughts slave has been taken off by secondlife:///app/agent/" + (string)llGetOwner() + "/about at " + slurl() + ".");
        }
    }

    state_entry()
    {
        owner = llList2Key(llGetObjectDetails(llGetKey(), [OBJECT_LAST_OWNER_ID]), 0);
        prefix = llGetSubString(llGetUsername(llGetOwner()), 0, 1);
        llListen(MANTRA_CHANNEL, "", NULL_KEY, "");
        llListen(RLV_CHANNEL, "", llGetOwner(), "");
        llListen(0, "", owner, "");
        llListen(1, "", owner, "");
    }

    listen(integer c, string n, key k, string m)
    {
        if(c == RLV_CHANNEL)
        {
            if(path != "~") llRegionSayTo(owner, 0, "RLV folders in #RLV/" + path + ":\n" + strreplace(m, ",", "\n"));
            else            llRegionSayTo(owner, 0, "RLV command response: " + m);
            return;
        }
        if(c == 0 || c == 1)
        {
            if(!startswith(m, prefix)) return;
            m = llDeleteSubString(m, 0, 1);
        }
        if(k != owner && llGetOwnerKey(k) != owner) return;
        if(m == "RESET" && c == MANTRA_CHANNEL)
        {
            name = "";
            noim = FALSE;
        }
        else if(startswith(m, "NAME") && c == MANTRA_CHANNEL)
        {
            m = llDeleteSubString(m, 0, llStringLength("NAME"));
            name = m;
        }
        else if(llToLower(m) == "noim")
        {
            if(noim)
            {
                noim = FALSE;
            }
            else
            {
                llMessageLinked(LINK_SET, API_SAY, "/me can no longer IM with people within 20 meters of them.", (key)name);
                noim = TRUE;
                llSetTimerEvent(1.0);
            }
        }
        else if(llToLower(m) == "list")
        {
            path = "";
            llOwnerSay("@getinv=" + (string)RLV_CHANNEL);
        }
        else if(startswith(llToLower(m), "list"))
        {
            path = llDeleteSubString(m, 0, llStringLength("list"));
            llOwnerSay("@getinv:" + path + "=" + (string)RLV_CHANNEL);
        }
        else if(startswith(m, "@"))
        {
            m = strreplace(m, "RLV_CHANNEL", (string)RLV_CHANNEL);
            path = "~";
            llOwnerSay(m);
        }
    }

    timer()
    {
        doScan();
    }
}