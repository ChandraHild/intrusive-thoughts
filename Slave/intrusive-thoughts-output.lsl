#include <IT/globals.lsl>
key owner = NULL_KEY;
integer blindmute = FALSE;
integer speakon = 0;

handleSelfDescribe(string message)
{
    integer firstSpace = llSubStringIndex(message, " ");
    while(firstSpace == 0)
    {
        message = llDeleteSubString(message, 0, 0);
        firstSpace = llSubStringIndex(message, " ");
    }
    string currentObjectName = llGetObjectName();
    if(firstSpace == -1)
    {
        llSetObjectName(".");
        llOwnerSay("/me " + message);
    }
    else
    {
        llSetObjectName(llGetSubString(message, 0, firstSpace-1));
        message = llDeleteSubString(message, 0, firstSpace);
        llOwnerSay("/me " + message);
    }
    llSetObjectName(currentObjectName);
}

handleSelfSay(string name, string message)
{
    string currentObjectName = llGetObjectName();
    llSetObjectName(name);
    integer bytes = getstringbytes(message);
    while(bytes > 0)
    {
        if(bytes <= 1024)
        {
            if(blindmute) llRegionSayTo(llGetOwner(), 0, message);
            else          llOwnerSay(message);
            bytes = 0;
        }
        else
        {
            integer offset = 0;
            while(bytes >= 1024) bytes = getstringbytes(llGetSubString(message, 0, --offset));
            if(blindmute) llRegionSayTo(llGetOwner(), 0, llGetSubString(message, 0, offset));
            else          llOwnerSay(message);
            message = llDeleteSubString(message, 0, offset);
            bytes = getstringbytes(message);
        }
    }
    llSetObjectName(currentObjectName);
}

handleSay(string name, string message, integer excludeSelf)
{
    list agents;
    integer l;
    vector pos;
    float range;

    if(blindmute == TRUE || excludeSelf == TRUE)
    {
        agents = llGetAgentList(AGENT_LIST_REGION, []);
        l = llGetListLength(agents)-1;
        pos = llGetPos();
        range = 20.0;

        if(startswith(message, "/whisper")) 
        {
            message = llDeleteSubString(message, 0, 7);
            range = 10.0;
        }
        else if(startswith(message, "/shout"))
        {
            message = llDeleteSubString(message, 0, 5);
            range = 100.0;
        }
 
        for(; l >= 0; --l)
        {
            vector target = llList2Vector(llGetObjectDetails(llList2Key(agents,l), [OBJECT_POS]), 0);
            if(llVecDist(target, pos) > range) agents = llDeleteSubList(agents, l, l);
        }
    }

    string currentObjectName = llGetObjectName();
    llSetObjectName(name);
    integer bytes = getstringbytes(message);
    while(bytes > 0)
    {
        if(bytes <= 1024)
        {
            if(blindmute == TRUE || excludeSelf == TRUE)
            {
                l = llGetListLength(agents)-1;
                for(; l >= 0; --l)
                {
                    key a = llList2Key(agents,l);
                    if(a == llGetOwner()) 
                    {
                        if(excludeSelf == FALSE) llRegionSayTo(a, 0, message);
                    }
                    else
                    {
                        llRegionSayTo(a, speakon, message);
                    }
                }
            }
            else
            {
                llSay(speakon, message);
                if(speakon != 0 && blindmute == TRUE) llRegionSayTo(llGetOwner(), 0, message);
                if(speakon != 0 && blindmute == FALSE) llOwnerSay(message);
            }
            bytes = 0;
        }
        else
        {
            integer offset = 0;
            while(bytes >= 1024) bytes = getstringbytes(llGetSubString(message, 0, --offset));
            if(blindmute == TRUE || excludeSelf == TRUE)
            {
                l = llGetListLength(agents)-1;
                for(; l >= 0; --l)
                {
                    key a = llList2Key(agents,l);
                    if(a == llGetOwner())
                    {
                        if(excludeSelf == FALSE) llRegionSayTo(a, 0, llGetSubString(message, 0, offset));
                    }
                    else
                    {
                        llRegionSayTo(a, speakon, llGetSubString(message, 0, offset));
                    }
                }
            }
            else
            {
                llSay(speakon, llGetSubString(message, 0, offset));
                if(speakon != 0 && blindmute == TRUE) llRegionSayTo(llGetOwner(), 0, llGetSubString(message, 0, offset));
                if(speakon != 0 && blindmute == FALSE) llOwnerSay(llGetSubString(message, 0, offset));
            }
            message = llDeleteSubString(message, 0, offset);
            bytes = getstringbytes(message);
        }
    }
    llSetObjectName(currentObjectName);
}

default
{
    link_message(integer sender_num, integer num, string str, key id)
    {
        if(num == API_RESET && id == llGetOwner())                    llResetScript();
        else if(num == API_SELF_DESC && str != "")                    handleSelfDescribe(str);
        else if(num == API_SELF_SAY && str != "" && (string)id != "") handleSelfSay((string)id, str);
        else if(num == API_SAY && str != "")                          handleSay((string)id, str, FALSE);
        else if(num == API_ONLY_OTHERS_SAY && str != "")              handleSay((string)id, str, TRUE);
    }

    changed(integer change)
    {
        if(change & CHANGED_OWNER) llResetScript();
    }

    state_entry()
    {
        owner = llList2Key(llGetObjectDetails(llGetKey(), [OBJECT_LAST_OWNER_ID]), 0);
        llListen(MANTRA_CHANNEL, "", NULL_KEY, "");
    }

    listen(integer c, string n, key k, string m)
    {
        if(k != owner && llGetOwnerKey(k) != owner) return;
        if(m == "RESET")
        {
            blindmute = FALSE;
        }
        else if(startswith(m, "BLIND_MUTE"))
        {
            m = llDeleteSubString(m, 0, llStringLength("BLIND_MUTE"));
            if(m != "0") blindmute = TRUE;
            else         blindmute = FALSE;
        }
        else if(startswith(m, "DIALECT"))
        {
            m = llDeleteSubString(m, 0, llStringLength("DIALECT"));
            if(m != "0") speakon = SPEAK_CHANNEL;
            else         speakon = 0;
        }
        else if(m == "END")
        {
            llRegionSayTo(owner, HUD_SPEAK_CHANNEL, "[" + llGetScriptName() + "]: " + (string)(llGetFreeMemory() / 1024.0) + "kb free.");
        }
    }
}