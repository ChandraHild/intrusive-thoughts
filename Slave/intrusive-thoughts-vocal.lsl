#include <IT/globals.lsl>
key owner = NULL_KEY;
string name = "";
list speechblacklistfrom = [];
list speechblacklistto = [];
list speechblacklisttripped = [];
list speechfilterfrom = [];
list speechfilterto = [];
integer mute = FALSE;
string mutemsg = "";
string unmutemsg = "";
list mutecensor = [];
list mutecmd = [];
list unmutecmd = [];
string mutetype = "DROP";
integer blindmute = FALSE;

handleHear(key skey, string sender, string message)
{
    integer l1;
    if(mute)
    {
        if(skey == owner || llGetOwnerKey(skey) == owner)
        {
            l1 = llGetListLength(unmutecmd)-1;
            for(;l1 >= 0; --l1)
            {
                if(contains(llToLower(message), llList2String(unmutecmd, l1)))
                {
                    mute = FALSE;
                    llMessageLinked(LINK_SET, API_SELF_DESC, unmutemsg, NULL_KEY);
                    llRegionSayTo(owner, HUD_SPEAK_CHANNEL, name + " can speak again.");
                }
            }
        }
    }
    else
    {
        if(skey == owner || llGetOwnerKey(skey) == owner)
        {
            l1 = llGetListLength(mutecmd)-1;
            for(;l1 >= 0; --l1)
            {
                if(contains(llToLower(message), llList2String(mutecmd, l1)))
                {
                    mute = TRUE;
                    llMessageLinked(LINK_SET, API_SELF_DESC, mutemsg, NULL_KEY);
                    llRegionSayTo(owner, HUD_SPEAK_CHANNEL, name + " can no longer speak.");
                }
            }
        }
    }
}

handleSay(string message)
{
    if(startswith(message, "((") == TRUE && endswith(message, "))") == TRUE) return;
    integer emote = FALSE;
    if(startswith(llToLower(message), "/me") || startswith(llToLower(message), "/shout/me") || startswith(llToLower(message), "/shout /me") ||
       startswith(llToLower(message), "/whisper/me") || startswith(llToLower(message), "/whisper /me")) emote = TRUE;
    integer l1;
    string messagecopy;
    string word;
    string oldword;
    string newword;
    integer replaceidx;
    integer quotecnt = 0;
    
    l1 = llGetListLength(speechblacklistfrom)-1;
    for(;l1 >= 0; --l1)
    {
        if(contains(llToLower(message), llList2String(speechblacklistfrom, l1)))
        {
            message = llList2String(speechblacklisttripped, llList2Integer(speechblacklistto, l1));
            jump blacklisttripped;
        }
    }

    messagecopy = message;
    message = "";
    while(llStringLength(messagecopy) > 0)
    {
        word = llList2String(llParseStringKeepNulls(messagecopy, [" ", ",", "\"", ";", ":", ".", "!", "?"], []), 0);
        oldword = word;

        replaceidx = llListFindList(speechfilterfrom, [llToLower(word)]);
        if(replaceidx != -1)
        {
            word = llList2String(speechfilterto, replaceidx);
        }

        message += word;
        if(llStringLength(messagecopy) != llStringLength(oldword))
        {
            message += llGetSubString(messagecopy, llStringLength(oldword), llStringLength(oldword));
        }
        messagecopy = llDeleteSubString(messagecopy, 0, llStringLength(oldword));
    }

    @blacklisttripped;
    integer bypass = startswith(message, "/me") == TRUE && contains(message, "\"") == FALSE;
    if(mute == FALSE || bypass == TRUE) 
    {
        llMessageLinked(LINK_SET, API_SAY, message, (key)name);
    }
    else
    {
        if(mutetype == "DROP" || mutecensor == [])
        {
            llMessageLinked(LINK_SET, API_SELF_SAY, message, (key)name);
        }
        else if(mutetype == "REPLACE")
        {
            if(blindmute)
            {
                llMessageLinked(LINK_SET, API_SELF_SAY, message, (key)name);
                llMessageLinked(LINK_SET, API_ONLY_OTHERS_SAY, llList2String(mutecensor, llFloor(llFrand(llGetListLength(mutecensor)))), (key)name);
            }
            else
            {
                llMessageLinked(LINK_SET, API_SAY, llList2String(mutecensor, llFloor(llFrand(llGetListLength(mutecensor)))), (key)name);
            }
        }
        else
        {
            if(blindmute) llMessageLinked(LINK_SET, API_SELF_SAY, message, (key)name);
            messagecopy = message;
            message = "";
            while(llStringLength(messagecopy) > 0)
            {
                word = llList2String(llParseStringKeepNulls(messagecopy, [" ", ",", "\"", ";", ":", ".", "!", "?"], []), 0);
                oldword = word;

                if(emote == FALSE || quotecnt % 2 != 0)
                {
                    newword = llList2String(mutecensor, llFloor(llFrand(llGetListLength(mutecensor))));
                    if(llToUpper(word) == word)
                    {
                        word = llToUpper(newword);
                    }
                    else if(llToUpper(llGetSubString(word, 0, 0)) == llGetSubString(word, 0, 0))
                    {
                        word = llToUpper(llGetSubString(newword, 0, 0)) + llGetSubString(newword, 1, -1);
                    }
                    else
                    {
                        word = newword;
                    }
                }

                message += word;
                if(llStringLength(messagecopy) != llStringLength(oldword))
                {
                    message += llGetSubString(messagecopy, llStringLength(oldword), llStringLength(oldword));
                    if(llGetSubString(message, -1, -1) == "\"") quotecnt++;
                }
                messagecopy = llDeleteSubString(messagecopy, 0, llStringLength(oldword));
            }
            if(blindmute) llMessageLinked(LINK_SET, API_ONLY_OTHERS_SAY, message, (key)name);
            else          llMessageLinked(LINK_SET, API_SAY, message, (key)name);
        }
    }
}

checkSetup()
{
    if(name != "" || mute == TRUE) llOwnerSay("@redirchat:" + (string)VOICE_CHANNEL + "=add,rediremote:" + (string)VOICE_CHANNEL + "=add");
    else                           llOwnerSay("@redirchat:" + (string)VOICE_CHANNEL + "=rem,rediremote:" + (string)VOICE_CHANNEL + "=rem");
}

default
{
    link_message(integer sender_num, integer num, string str, key id)
    {
        if(num == API_RESET && id == llGetOwner()) llResetScript();
        if(num == API_MUTE_TOGGLE)
        {
            if(mute)
            {
                mute = FALSE;
                llMessageLinked(LINK_SET, API_SELF_DESC, unmutemsg, NULL_KEY);
                if(name != "") llRegionSayTo(owner, HUD_SPEAK_CHANNEL, name + " can speak again.");
                else           llRegionSayTo(owner, HUD_SPEAK_CHANNEL, "secondlife:///app/agent/" + (string)llGetOwner() + "/about can speak again.");
                checkSetup();
            }
            else
            {
                mute = TRUE;
                llMessageLinked(LINK_SET, API_SELF_DESC, mutemsg, NULL_KEY);
                if(name != "") llRegionSayTo(owner, HUD_SPEAK_CHANNEL, name + " can no longer speak.");
                else           llRegionSayTo(owner, HUD_SPEAK_CHANNEL, "secondlife:///app/agent/" + (string)llGetOwner() + "/about can no longer speak.");
                checkSetup();
            }
        }
    }

    changed(integer change)
    {
        if(change & CHANGED_OWNER) llResetScript();
    }

    attach(key id)
    {
        if(id != NULL_KEY) checkSetup();
    }

    state_entry()
    {
        owner = llList2Key(llGetObjectDetails(llGetKey(), [OBJECT_LAST_OWNER_ID]), 0);
        llListen(MANTRA_CHANNEL, "", NULL_KEY, "");
        llListen(VOICE_CHANNEL, "", llGetOwner(), "");
        llListen(0, "", NULL_KEY, "");
    }

    listen(integer c, string n, key k, string m)
    {
        if((c == 0 || c == VOICE_CHANNEL) && k == llGetOwner() && contains(llToLower(m), "((red))") == TRUE)
        {
            llOwnerSay("Safeworded! Detaching immediately...");
            llOwnerSay("@clear,detachme=force");
            return;
        }
        else if(c == VOICE_CHANNEL)
        {
            handleSay(m);
            return;
        }
        else if(c == 0)
        {
            handleHear(k, n, m);
            return;
        }
        if(k != owner && llGetOwnerKey(k) != owner) return;
        if(m == "RESET")
        {
            name = "";
            speechblacklistfrom = [];
            speechblacklistto = [];
            speechblacklisttripped = [];
            speechfilterfrom = [];
            speechfilterto = [];
            mute = FALSE;
            mutemsg = "";
            unmutemsg = "";
            mutecmd = [];
            unmutecmd = [];
            mutecensor = [];
            blindmute = FALSE;
        }
        else if(startswith(m, "NAME"))
        {
            m = llDeleteSubString(m, 0, llStringLength("NAME"));
            name = m;
        }
        else if(startswith(m, "SPEECH_BLACKLIST_ENTRY"))
        {
            m = llDeleteSubString(m, 0, llStringLength("SPEECH_BLACKLIST_ENTRY"));
            list split = llParseString2List(m, ["="], []);
            speechblacklistfrom += [llToLower(llList2String(split, 0))];
            speechblacklistto += [(integer)llList2String(split, 1)];
        }
        else if(startswith(m, "SPEECH_BLACKLIST_TRIPPED"))
        {
            m = llDeleteSubString(m, 0, llStringLength("SPEECH_BLACKLIST_TRIPPED"));
            speechblacklisttripped += [m];
        }
        else if(startswith(m, "SPEECH_FILTER"))
        {
            m = llDeleteSubString(m, 0, llStringLength("SPEECH_FILTER"));
            list split = llParseString2List(m, ["="], []);
            speechfilterfrom += [llToLower(llList2String(split, 0))];
            speechfilterto += [llList2String(split, 1)];
        }
        else if(startswith(m, "MUTE_MSG"))
        {
            m = llDeleteSubString(m, 0, llStringLength("MUTE_MSG"));
            mutemsg = m;
        }
        else if(startswith(m, "UNMUTE_MSG"))
        {
            m = llDeleteSubString(m, 0, llStringLength("UNMUTE_MSG"));
            unmutemsg = m;
        }
        else if(startswith(m, "MUTE_CMD"))
        {
            m = llDeleteSubString(m, 0, llStringLength("MUTE_CMD"));
            mutecmd += [llToLower(m)];
        }
        else if(startswith(m, "UNMUTE_CMD"))
        {
            m = llDeleteSubString(m, 0, llStringLength("UNMUTE_CMD"));
            unmutecmd += [llToLower(m)];
        }
        else if(startswith(m, "MUTE_CENSOR"))
        {
            m = llDeleteSubString(m, 0, llStringLength("MUTE_CENSOR"));
            mutecensor += [llToLower(m)];
        }
        else if(startswith(m, "MUTE_TYPE"))
        {
            m = llToUpper(llDeleteSubString(m, 0, llStringLength("MUTE_TYPE")));
            if(m == "DROP" || m == "REPLACE" || m == "CENSOR") mutetype = m;
        }
        else if(startswith(m, "BLIND_MUTE"))
        {
            m = llDeleteSubString(m, 0, llStringLength("BLIND_MUTE"));
            if(m != "0") blindmute = TRUE;
            else         blindmute = FALSE;
        }
        else if(m == "END")
        {
            llRegionSayTo(owner, HUD_SPEAK_CHANNEL, "[" + llGetScriptName() + "]: " + (string)(llGetFreeMemory() / 1024.0) + "kb free.");
        }
        checkSetup();
    }
}