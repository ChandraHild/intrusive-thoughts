#include <IT/globals.lsl>

key primary = NULL_KEY;
list owners = [];
integer publicaccess = FALSE;
integer groupaccess = FALSE;
list rlvclients = [];
list blacklist = [];
list whitelist = [];
key handlingk = NULL_KEY;
string handlingm;
integer handlingi;
integer templisten = -1;
integer tempchannel = DEBUG_CHANNEL;

makelisten(key who)
{
    if(templisten != -1) llListenRemove(templisten);
    tempchannel = ((integer)("0x"+llGetSubString((string)llGenerateKey(),-8,-1)) & 0x3FFFFFFF) ^ 0xBFFFFFF;
    templisten = llListen(tempchannel, "", who, "");
}

clearlisten()
{
    if(templisten != -1) llListenRemove(templisten);
    templisten = -1;
}

buildclients()
{
    integer ct = llGetInventoryNumber(INVENTORY_SCRIPT);
    integer i;
    integer handlers = 0;
    for(i = 0; i < ct; ++i)
    {
        if(contains(llToLower(llGetInventoryName(INVENTORY_SCRIPT, i)), "client")) handlers++;
    }
    while(llGetListLength(rlvclients) < handlers) rlvclients += [(key)NULL_KEY];
    while(llGetListLength(rlvclients) > handlers) rlvclients = llDeleteSubList(rlvclients, -1, -1);
}

default
{
    changed(integer change)
    {
        if(change & CHANGED_INVENTORY) buildclients();
    }

    link_message(integer sender_num, integer num, string str, key k)
    {
        if(num == S_API_OWNERS)
        {
            owners = [];
            list new = llParseString2List(str, [","], []);
            integer n = llGetListLength(new);
            while(~--n)
            {
                owners += [(key)llList2String(new, n)];
            }
            primary = k;
        }
        else if(num == S_API_OTHER_ACCESS)
        {
            publicaccess = (integer)str;
            groupaccess = (integer)((string)k);
        }
        else if(num == RLV_API_CLR_SRC) rlvclients = llListReplaceList(rlvclients, [(key)NULL_KEY], (integer)str, (integer)str);
        else if(num == RLV_API_HANDOVER) rlvclients = llListReplaceList(rlvclients, [k], (integer)str, (integer)str);
    }

    state_entry()
    {
        llListen(RLVRC, "", NULL_KEY, "");
        llListen(0, "", llGetOwner(), "");
        llListen(MANTRA_CHANNEL, "", NULL_KEY, "");
        buildclients();
    }

    listen(integer c, string n, key id, string m)
    {
        if(c == RLVRC)
        {
            if(rlvclients == []) return;
            list args = llParseStringKeepNulls(m, [","], []);

            // We discard if the message is too short.
            if(llGetListLength(args)!=3) return;
            string ident = llList2String(args, 0);
            string target = llList2String(args, 1);
            string command = llList2String(args, 2);
            string firstcommand = llList2String(llParseString2List(command, ["|"], []), 0);
            string behavior = llList2String(llParseString2List(firstcommand, ["="], []), 0);
            string value = llList2String(llParseString2List(firstcommand, ["="], []), 1);

            // Or if the target is not us.
            if(target != (string)llGetOwner() && target != "ffffffff-ffff-ffff-ffff-ffffffffffff") return;

            integer inlist = llListFindList(rlvclients, [id]);
            if(inlist != -1)
            {
                // If we know the device, we just pass the message through.
                llMessageLinked(LINK_SET, RLV_API_HANDLE_CMD, m, (key)((string)inlist));
            }
            else
            {
                // If we do not know the device, first see if we have a pending request
                // and cancel if we do. Then we check if we have an available client.
                if(handlingk != NULL_KEY) return;
                if(llListFindList(blacklist, [id]) != -1) return;
                integer available = llListFindList(rlvclients, [(key)NULL_KEY]);
                if(available == -1) return;

#ifndef PUBLIC_SLAVE
                // If the device is owned by the owners, by us, or it is in the whitelist, allow it.
                if(isowner(id) || llGetOwnerKey(id) == llGetOwner() || llListFindList(whitelist, [id]) != -1)
                {
                    rlvclients = llListReplaceList(rlvclients, [id], available, available);
                    llMessageLinked(LINK_SET, RLV_API_SET_SRC, (string)available, id);
                    llMessageLinked(LINK_SET, RLV_API_HANDLE_CMD, m, (key)((string)available));
                }
                else
                {
                    // If it's not owned by the owner or us, we check if it's one of the allowed commands.
                    if(command == "!version") llRegionSayTo(id, RLVRC, ident+","+(string)id+",!version,1100");
                    else if(command == "!implversion") llRegionSayTo(id, RLVRC, ident+","+(string)id+",!implversion,ORG=0004/Hana's Relay");
                    else if(command == "!x-orgversions") llRegionSayTo(id, RLVRC, ident+","+(string)id+",!x-orgversions,ORG=0004/handover=001");
                    else if((behavior == "@version" || behavior == "@versionnew" || behavior == "@versionnum" || behavior == "@versionnumbl") && command == behavior + "=" + value) llOwnerSay(command);

                    // If not, we ask the owner for permission if they're available, or the
                    // wearer if they're not.
                    else
                    {
                        key target = llGetOwner();
                        if(llGetAgentSize(primary) != ZERO_VECTOR) target = primary;
                        handlingk = id;
                        handlingm = m;
                        handlingi = available;
                        makelisten(target);
                        llDialog(target, "The device '" + n + "' owned by secondlife:///app/agent/" + (string)llGetOwnerKey(id) + "/about wants to access the relay of secondlife:///app/agent/" + (string)llGetOwner() + "/about, will you allow this?\n \n(Timeout in 15 seconds.)", ["ALLOW", "DENY", "BLOCK"], tempchannel);
                        llSetTimerEvent(15.0);
                    }
                }
#else
                rlvclients = llListReplaceList(rlvclients, [id], available, available);
                llMessageLinked(LINK_SET, RLV_API_SET_SRC, (string)available, id);
                llMessageLinked(LINK_SET, RLV_API_HANDLE_CMD, m, (key)((string)available));
#endif
            }
        }
        else if(c == tempchannel && templisten != -1)
        {
            if(handlingk == NULL_KEY) return;
            if(m == "ALLOW")
            {
                llSetTimerEvent(0.0);
                if(llListFindList(whitelist, [handlingk]) == -1) whitelist += [handlingk];
                if(llGetListLength(whitelist) > 10) whitelist = llDeleteSubList(whitelist, 1, -1);
                rlvclients = llListReplaceList(rlvclients, [handlingk], handlingi, handlingi);
                llMessageLinked(LINK_SET, RLV_API_SET_SRC, (string)handlingi, handlingk);
                llMessageLinked(LINK_SET, RLV_API_HANDLE_CMD, handlingm, (key)((string)handlingi));
                handlingk = NULL_KEY;
            }
            else if(m == "DENY")
            {
                llSetObjectName("");
                llOwnerSay("RLV relay request denied.");
                llSetObjectName(slave_base);
                llSetTimerEvent(0.0);
                handlingk = NULL_KEY;
            }
            else if(m == "BLOCK")
            {
                llSetObjectName("");
                llOwnerSay("RLV relay request blocked. You can type ((blocklist)) to clear the block list.");
                llSetObjectName(slave_base);
                llSetTimerEvent(0.0);
                if(llListFindList(blacklist, [handlingk]) == -1) blacklist += [handlingk];
                handlingk = NULL_KEY;
            }
        }
        else if(c == MANTRA_CHANNEL)
        {
#ifndef PUBLIC_SLAVE
            if(!isowner(id)) return;
#endif
            if(m == "CLEAR")
            {
                llSetObjectName("");
                if(llGetAgentSize(llGetOwnerKey(id)) != ZERO_VECTOR) ownersay(id, "The " + VERSION_S + " relay worn by secondlife:///app/agent/" + (string)llGetOwner() + "/about has been cleared.", 0);
                llSetObjectName(slave_base);
                llMessageLinked(LINK_SET, RLV_API_SAFEWORD, "", NULL_KEY);
            }
            else if(m == "FORCECLEAR")
            {
                llSetObjectName("");
                if(llGetAgentSize(llGetOwnerKey(id)) != ZERO_VECTOR) ownersay(id, "The " + VERSION_S + " relay worn by secondlife:///app/agent/" + (string)llGetOwner() + "/about has been cleared and detached.", 0);
                llSetObjectName(slave_base);
                llMessageLinked(LINK_SET, RLV_API_SAFEWORD, "", NULL_KEY);
                llOwnerSay("@clear,detachme=force");
            }
            else if(m == "RESETRELAY")
            {
                llSetObjectName("");
                if(llGetAgentSize(llGetOwnerKey(id)) != ZERO_VECTOR) ownersay(id, "The " + VERSION_S + " relay worn by secondlife:///app/agent/" + (string)llGetOwner() + "/about has been reset and has been rebuilt.", 0);
                llSetObjectName(slave_base);
                llMessageLinked(LINK_SET, S_API_HARD_RESET, "", "");
            }
        }
        else if(c == 0)
        {
            if(contains(llToLower(m), "((red))"))
            {
                llSetObjectName("");
                llOwnerSay("You've safeworded. You're free from all RLV devices that grabbed you.");
                llMessageLinked(LINK_SET, RLV_API_SAFEWORD, "", NULL_KEY);
#ifndef PUBLIC_SLAVE
                if(llGetAgentSize(primary) != ZERO_VECTOR) ownersay(primary, "The " + VERSION_S + " relay has been safeworded by secondlife:///app/agent/" + (string)llGetOwner() + "/about at " + slurl() + ".", 0);
                else
                {
                    llSetObjectName(slave_base);
                    llInstantMessage(primary, "The " + VERSION_S + " relay has been safeworded by secondlife:///app/agent/" + (string)llGetOwner() + "/about at " + slurl() + ".");
                }
#endif
                llSetObjectName(slave_base);
            }
            else if(contains(llToLower(m), "((forcered))"))
            {
                llSetObjectName("");
                llOwnerSay("You've used the hard safeword. Freeing you and detaching.");
                llMessageLinked(LINK_SET, RLV_API_SAFEWORD, "", NULL_KEY);
#ifndef PUBLIC_SLAVE
                if(llGetAgentSize(primary) != ZERO_VECTOR) ownersay(primary, "The " + VERSION_S + " been detached by secondlife:///app/agent/" + (string)llGetOwner() + "/about at " + slurl() + " because of safeword.", 0);
                else
                {
                    llSetObjectName(slave_base);
                    llInstantMessage(primary, "The " + VERSION_S + " been detached by secondlife:///app/agent/" + (string)llGetOwner() + "/about at " + slurl() + " because of safeword.");
                }
#endif
                llSetObjectName(slave_base);
                llOwnerSay("@clear,detachme=force");
            }
            else if(contains(llToLower(m), "((blocklist))"))
            {
                llSetObjectName("");
                llOwnerSay("Clearing the block list.");
                llSetObjectName(slave_base);
                blacklist = [];
            }
        }
    }

    timer()
    {
        llSetTimerEvent(0.0);
        handlingk = NULL_KEY;
        clearlisten();
    }
}
