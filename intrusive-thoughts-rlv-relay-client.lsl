#include <IT/globals.lsl>
integer rlvid = 0;
key id = NULL_KEY;
key wearer = NULL_KEY;
integer viewerlistener;
key sitid;
list restrictions = [];

release()
{
    if(restrictions != [])
    {
        integer l = llGetListLength(restrictions)-1;
        while(l >= 0) 
        {
            llOwnerSay("@" + llList2String(restrictions, l) + "=y");
            --l;
        }
        llRegionSayTo(id, RLVRC, "release,"+(string)id+",!release,ok");
    }
    llMessageLinked(LINK_SET, API_RLV_CLR_SRC, (string)rlvid, NULL_KEY);
    llResetScript();
}

handlerlvrc(string msg)
{
    list args = llParseStringKeepNulls(msg,[","],[]);
    if(llGetListLength(args)!=3) return;
    if(llList2Key(args,1) != wearer && llList2Key(args, 1) != (key)"ffffffff-ffff-ffff-ffff-ffffffffffff") return;

    string ident = llList2String(args,0);
    list commands = llParseString2List(llList2String(args,2),["|"],[]);
    integer i;
    string command;
    integer nc = llGetListLength(commands);

    for (i=0; i<nc; ++i) 
    {
        command = llList2String(commands,i);
        if (llGetSubString(command,0,0)=="@") 
        {
            llOwnerSay(command);
            llRegionSayTo(id, RLVRC, ident+","+(string)id+","+command+",ok");
            list subargs = llParseString2List(command, ["="], []);
            string behav = llGetSubString(llList2String(subargs, 0), 1, -1);
            integer index = llListFindList(restrictions, [behav]);
            string comtype = llList2String(subargs, 1);                
            if (comtype == "n" || comtype == "add") 
            {
                if(index == -1) restrictions += [behav];
                if(behav == "unsit" && llGetAgentInfo(wearer) & AGENT_SITTING)
                {
                    viewerlistener = llListen(12345, "", wearer, "");
                    llOwnerSay("@getsitid=12345");
                }
            }
            else if (comtype=="y" || comtype == "rem") 
            {
                if (index != -1) restrictions = llDeleteSubList(restrictions, index, index);
                if (behav == "unsit") sitid = NULL_KEY;
            }
        }
        else if (command=="!pong")
        {
            llOwnerSay("@sit:"+(string)sitid+"=force,"+llDumpList2String(restrictions, "=n,")+"=n");
            llSetTimerEvent(0);
        }
        else if(command == "!version")
        {
            llRegionSayTo(id, RLVRC, ident+","+(string)id+",!version,1100");
        }
        else if(command == "!implversion")
        {
            llRegionSayTo(id, RLVRC, ident+","+(string)id+",!implversion,ORG=0004/Hana's Relay");
        }
        else if(command == "!x-orgversions")
        {
            llRegionSayTo(id, RLVRC, ident+","+(string)id+",!x-orgversions,ORG=0004/who=001");
        }
        else if (command=="!release")
        {
            release();
        }
        else
        {
            llRegionSayTo(id, RLVRC, ident+","+(string)id+","+command+",ko");
        }
    }
    if(restrictions == [])
    {
        release();
    }
}

default
{
    changed(integer change)
    {
        if(change & CHANGED_OWNER) llResetScript();
    }

    state_entry()
    {
        wearer = llGetOwner();
        list tokens = llParseString2List(llGetScriptName(), [" "], []);
        integer amount = llGetListLength(tokens);
        if(amount > 1) rlvid = (integer)llList2String(tokens, 1);
    }

    listen(integer c, string w, key id, string msg)
    {
        if (c == 12345)
        {
            if(msg) sitid = (key)msg;
            llListenRemove(viewerlistener);
        }
    }

    link_message(integer sender_num, integer num, string str, key k)
    {
        if(num == API_RLV_HANDLE_CMD && (string)k == (string)rlvid && id != NULL_KEY)  
        {
            handlerlvrc(str);
        }
        else if(num == API_RLV_SET_SRC && str == (string)rlvid)                        
        {
            id = k;
        }
        else if(num == API_RLV_SAFEWORD)                                               
        {
            release();
        }
    }

    on_rez(integer i) 
    {
        if(id) 
        {
            llSleep(30);
            llRegionSayTo(id, RLVRC, "ping,"+(string)id+",ping,ping");
            llSetTimerEvent(30);
        }
    }
 
    timer()
    {
        release();
    }
}