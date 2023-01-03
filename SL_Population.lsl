//==========================================================================//
// SecondLife-PopulationMeter
// Copyright (C) 2022 Coffee Pancake
// Released under the MIT Licence (http://opensource.org/licenses/MIT)
// Source : https://github.com/0xc0ffea/SecondLife-PopulationMeter
//
// Displays a normalised running bar chart representing the last 12 hours of
// the Second Life population.
// Tracks the highest and lowest seen populations.
//
// Defaut values for DEPTH & FREQUENCY update every 30 minutes and shows the
// last 12 hours as a chart.
//
// V2
// - Store working dataset in linkset KVP memory to survive script resets.
// - Github based update checking.
// V1
// - Initial release.
//
//==========================================================================//
// *** GLOBALS ***
// do we want debuging output sent to the script warning / error floater ?
integer DEBUG           = FALSE;

// for the http, because it's needy like that
key     HTTP;

// unicode glyphs to draw a bar chart
integer STEPS_COUNTS;
list    STEPS = [
    "░", // 0 (no data)
    "▁", // 1 (a low number)
    "▂", // 2
    "▃", // 3
    "▄", // 4 (a middling, mediocre number with scalding parents)
    "▅", // 5
    "▆", // 6
    "▇", // 7
    "█"  // 8 (a high number)
];

// stores some numbers
list    POP_COUNT       = [];
// how many numbers do we store? (and how big will the chart be)
integer DEPTH           = 24;
// how often do we get new numbers? (in minutes)
integer FREQUENCY       = 30;
// how muuch time is the chart showing? (calculated at start up)
string  CHART_SCALE     = "";

// The highest pop we ever saw and when we saw it
integer POP_HIGH        = 0;
string  POP_HIGH_WHEN   = "";

// The lowst we ever saw and when that was ..
integer POP_POOP        = 0x0FFFFFFF;
string  POP_POOP_WHEN   = "";

//==========================================================================//
// TIMER CONTROL

// How frequently should the timer tick .. in seconds
integer TICK            = 60;
// when is the next data request due (so we dont have to recalc every tick!)
integer NEXT_CHECK_SLSTATS;
// when do we check for updates again again?
integer NEXT_CHECK_UPDATE;

//==========================================================================//
// SCRIPT VERSION
string PRODUCT          = "SecondLife-PopulationMeter";
// store version as an integer (no minor versions, no point releases)
integer VERSION         = 2;
// URL to to check for current version
string  VERSION_URL     = "https://raw.githubusercontent.com/0xc0ffea/SecondLife-PopulationMeter/main/VERSION";
// URL to the source repository
string  SOURCE          = "https://github.com/0xc0ffea/SecondLife-PopulationMeter";
// if the current http request is a version check, put it in here
key     HTTP_VERSION    =  NULL_KEY;
//==========================================================================//


// *** FUNCTIONS ***

// Takes a list of numbers and returns a normalized
// unicode bar graph 1 character high.
string drawchart(list da_numbers) {
    string chart;
    integer x; integer y;
    //first pass, find the current high and low so we can sort out a range
    integer lowest=0x0FFFFFFF; integer highest;
    for (x=0; x<llGetListLength(da_numbers); x++) {
        y = llList2Integer(da_numbers,x);
        if (y > highest) {highest = y;}
        if ((y < lowest) && (y != 0)) {lowest = y;}
    }
    integer delta = ((highest - lowest) / (STEPS_COUNTS-1)) + 1;
    //second pass draw that chart!
    for (x=0; x<llGetListLength(da_numbers); x++) {
        y = llList2Integer(da_numbers,x);
        if (y == 0) {
            chart += llList2String(STEPS,0);
        } else {
            chart += llList2String(STEPS,((y - lowest)/delta)+1);
        }
    }
    return chart;
}


update_hovertext(string data) {

        string hovertext = "SL POPULATION ("+CHART_SCALE+")\n";

        // do we have any data to process ?
        if (data) {
            // dump everything into a list call temp
            list temp = llParseString2List(data, ["\n"], []);
            if (DEBUG) {llSay(DEBUG_CHANNEL,"HTTP DATA : "+data);}

            // temp looks like 
            // signups_updated_slt, 2020-09-08 15:55:01, signups_updated_unix, 1599605701, signups, 64419527, exchange_rate_updated_slt, 2022-03-07 18:15:01, exchange_rate_updated_unix, 1646705701, exchange_rate, 244.5049, inworld_updated_unix, 1646705717, inworld_updated_slt, 2022-03-07 18:15:17, inworld, 44512
            
            // grab the value we care about
            integer inworld = llList2Integer(temp,llListFindList(temp,["inworld"]) + 1); 
            string  inworld_updated_slt = llList2String(temp,llListFindList(temp,["inworld_updated_slt"]) + 1);
            
            // slap it onto the end of the numbers
            POP_COUNT = llDeleteSubList(POP_COUNT,0,0) + [(string)inworld];
            llLinksetDataWrite("POP_COUNT",llDumpList2String(POP_COUNT, ","));
            llLinksetDataWrite("POP_CHECKED",(string)llGetUnixTime());

            // update the high pop and poop pop counts while were here
            integer x; integer y;
            for (x=0; x<llGetListLength(POP_COUNT); x++) {
                y = llList2Integer(POP_COUNT,x);
                // a new high score !!
                if ((inworld > y) && (inworld > POP_HIGH)) {
                    POP_HIGH = inworld;
                    POP_HIGH_WHEN = inworld_updated_slt; 
                    //save
                    llLinksetDataWrite("POP_HIGH",(string)POP_HIGH);
                    llLinksetDataWrite("POP_HIGH_WHEN",(string)POP_HIGH_WHEN);
                }
                // a new low score :(
                if ((inworld < y) && (inworld < POP_POOP)) {
                    POP_POOP = inworld;
                    POP_POOP_WHEN = inworld_updated_slt;
                    llLinksetDataWrite("POP_POOP",(string)POP_POOP);
                    llLinksetDataWrite("POP_POOP_WHEN",(string)POP_POOP_WHEN);
                }
            }

            // current population
            hovertext += (string)inworld+" online";

            // work out the up down change from the last number
            integer diff = inworld - llList2Integer(POP_COUNT,-2);
            // a little + sign for when the pop is raising .. we dont need to worry about -
            string sign = "+";
            if (diff < 0) {sign = "";}

            // If we have a low, show it.
            if (POP_POOP != 0x0FFFFFFF) {hovertext += " ("+sign+(string)diff+")";}
        
        } else {
            // no data, this must be a first run / script reboot

            // current population
            hovertext += "----- online";

        }
    
        // Draw the chart
        hovertext += "\n" + drawchart(POP_COUNT);
        // add all time highs and lows
        hovertext += "\nHIGH:"+(string)POP_HIGH+" ("+POP_HIGH_WHEN+")";
        if (POP_POOP != 0x0FFFFFFF) {hovertext += "\nLOW:"+(string)POP_POOP+" ("+POP_POOP_WHEN+")";}
        
        llSetText(hovertext,<1,1,1>,1);
}


// *** IMPORTANT STUFF ***

default {
//--========================================================================//
    state_entry() {
        // Letsa Go! 
        if (DEBUG) {llSay(DEBUG_CHANNEL,"====================\n"+llGetScriptName()+" Starting Up!");}

        // Uncomment to reset all the stored kvp data and halt execution, the recomment and restart.
        //llOwnerSay("RESET");llLinksetDataReset( );llSetScriptState(llGetScriptName(),FALSE);

        // prefill the POP_COUNT list with zeros.
        integer x;
        for (x=0; x<DEPTH; x++) {
            POP_COUNT += ["0"];
        }

        // Do we have any linkset data
        if (llLinksetDataCountKeys() == 0) {
            // nope, we're new here .. add some!
            if (DEBUG) {llSay(DEBUG_CHANNEL,"Setting up stored data .. ");}
            llLinksetDataWrite("PRODUCT",(string)PRODUCT);
            llLinksetDataWrite("VERSION",(string)VERSION);
            llLinksetDataWrite("DEPTH",(string)DEPTH);
            llLinksetDataWrite("FREQUENCY",(string)FREQUENCY);
            // no actual data here as first run
            llLinksetDataWrite("POP_HIGH",(string)POP_HIGH);
            llLinksetDataWrite("POP_HIGH_WHEN",(string)POP_HIGH_WHEN);
            llLinksetDataWrite("POP_POOP",(string)POP_POOP);
            llLinksetDataWrite("POP_POOP_WHEN",(string)POP_POOP_WHEN);
            llLinksetDataWrite("POP_CHECKED",(string)-1);
            llLinksetDataWrite("POP_COUNT",llDumpList2String(POP_COUNT, ","));

        } else {
            // we do have stored data .. 
            integer lsd_version = (integer)llLinksetDataRead("VERSION");
            string  lsd_product = llLinksetDataRead("PRODUCT");
            if  ((lsd_version == VERSION) && (lsd_product == PRODUCT)) {
                // script restarted
                if (DEBUG) {llSay(DEBUG_CHANNEL,"Loading stored data .. ("+(string)llLinksetDataCountKeys()+" stored keys, "+(string)(65535-llLinksetDataAvailable())+" bytes used).");}
                POP_HIGH        = (integer)llLinksetDataRead("POP_HIGH");
                POP_HIGH_WHEN   = llLinksetDataRead("POP_HIGH_WHEN");
                POP_POOP        = (integer)llLinksetDataRead("POP_POOP");
                POP_POOP_WHEN   = llLinksetDataRead("POP_POOP_WHEN");

                // append stored pop count to blank list, save the result
                POP_COUNT += llParseString2List(llLinksetDataRead("POP_COUNT"), [","], [""]);
                POP_COUNT = llList2List(POP_COUNT, -DEPTH, -1);
                // this is perhaps unnecassary .. 
                llLinksetDataWrite("POP_COUNT",llDumpList2String(POP_COUNT, ","));

            } else if ((lsd_version == 0) || (lsd_product != PRODUCT)) {
                // awkward .. there is data but no version. Is this even our data, whats going on?!!
                // bail out so we dont step on toes
                if (DEBUG) {llSay(DEBUG_CHANNEL,"Linkset Data Error - Halting script.");}
                llOwnerSay("Linkset Data Error - Please put this script in a brand new fresh prim!");
                llOwnerSay("Halting script.");
                llSetScriptState(llGetScriptName(),FALSE);

            } else if (lsd_version < VERSION) {
                // updated script!
                if (DEBUG) {llSay(DEBUG_CHANNEL,"Version change, updating stored data ...");}
                // handle any version related changes to stored data here

                // when done, update the stored version
                llLinksetDataWrite("VERSION",(string)VERSION);
                // and restart
                llResetScript();
            }

        } 

        // Still here? We must be good to go, and in our own prim.
        // clear hover test
        llSetText("",ZERO_VECTOR,TRUE);
        //set prim name
        llSetObjectName(PRODUCT+" V"+(string)VERSION);
        llSetObjectDesc("Source : "+SOURCE);

        // Do a version check
        llOwnerSay("Checking ["+SOURCE+" github repository] for update ..");
        HTTP = llHTTPRequest(VERSION_URL, [], "");
        HTTP_VERSION = HTTP;

        // Initalise some stuff and basic house keeping

        // how many steps do we have graphics for?
        STEPS_COUNTS = llGetListLength(STEPS);
        // work out the chart scale
        integer mintues = FREQUENCY * DEPTH;
        integer hours = mintues / 60;
        mintues = mintues % 60;
        integer days = hours / 24;
        hours = hours % 24;
        if (days)   {CHART_SCALE = (string)days+"days ";}
        if (hours)  {CHART_SCALE += (string)hours+"hours ";}
        if (mintues)  {CHART_SCALE += (string)mintues+"mintues ";}
        // clean up any excess whitespace at the end
        CHART_SCALE = llStringTrim(CHART_SCALE,STRING_TRIM);

        //Put up some hovertext
        update_hovertext("");

        // START THE CLOCK !
        integer last_checked = (integer)llLinksetDataRead("POP_CHECKED");
        if (DEBUG) {llSay(DEBUG_CHANNEL,"Last data : "+(string)last_checked);}
        if (last_checked == -1) {
            // we never got any data, get some right now
            if (DEBUG) {llSay(DEBUG_CHANNEL,"Initial data.");}
            NEXT_CHECK_SLSTATS = 0;
            llSetTimerEvent(0.1);
        } else {
            // we got some data already, schedule the next fetch
            if ((last_checked + (FREQUENCY*60)) < llGetUnixTime()) {
                // we're late! do it now!
                if (DEBUG) {llSay(DEBUG_CHANNEL,"Delayed data, catchup.");}
                NEXT_CHECK_SLSTATS = 0;
                llSetTimerEvent(0.1);
            } else {
                // pick up right where we left off, nice.
                NEXT_CHECK_SLSTATS = (FREQUENCY*60) - (llGetUnixTime() - last_checked);
                if (DEBUG) {llSay(DEBUG_CHANNEL,"Next check in "+(string)NEXT_CHECK_SLSTATS+" seconds.");}
                llSetTimerEvent(TICK);
            }
        }
    }
//--========================================================================//
    timer() {
        integer now = llGetUnixTime();
        // are we due to check for new stats?
        if (now >= NEXT_CHECK_SLSTATS) {
            // request some data
            if (DEBUG) {llSay(DEBUG_CHANNEL,"Requesting data ...");}
            HTTP = llHTTPRequest("http://secondlife.com/httprequest/homepage.php", [], "");
        } 

        // are we due an update check?
        else if (now >= NEXT_CHECK_UPDATE) {
            // Get version number from source repository
            llOwnerSay("Checking ["+SOURCE+" github repository] for update..");
            HTTP = llHTTPRequest(VERSION_URL, [], "");
            HTTP_VERSION = HTTP;
        }

        // See you back .. in a mo!
        llSetTimerEvent(TICK);
    }

//--========================================================================// 
    http_response(key request_id, integer status, list metadata, string body) {
        if (request_id != HTTP) {return;}
        // are we checking the version?
        if (request_id == HTTP_VERSION) {
            if (status != 200) {
                llOwnerSay("Version check failed, please manually check the ["+SOURCE+" github repository].");
                HTTP_VERSION = NULL_KEY;
                //uugg .. this isn't fun, try again tomrrow .. 
                NEXT_CHECK_UPDATE = llGetUnixTime() + (60*60*24);
                return;
            }
            if ((integer)body <= VERSION) {
                llOwnerSay("This script is up to date.");
            } else {
                llOwnerSay("Version "+body+" is available from the ["+SOURCE+" github repository]!");
                llInstantMessage(llGetOwner(), "An update to version "+body+" for the script in your "+PRODUCT+" is avilable from the ["+SOURCE+" github repository]!");
            }
            // check again in a week
            NEXT_CHECK_UPDATE = llGetUnixTime() + (60*60*24*7);
            return;
        }

        // We're here? We can only be fetching data for the pop counter.
        if (status != 200) {
            // oh dear .. no data this time, probably a temporary issue
            if (DEBUG) {llSay(DEBUG_CHANNEL,"HTTP ERROR : "+(string)status);}
            POP_COUNT = llDeleteSubList(POP_COUNT,0,0) + ["0"];
            // try again in a minute
            NEXT_CHECK_SLSTATS = llGetUnixTime() + 60;

        } else {
            // schedule next stats check at the usual time !
            NEXT_CHECK_SLSTATS = llGetUnixTime() + FREQUENCY*60;
            // sort out the data, render some hover text and do some things
            update_hovertext(body);
        }
    }

//--========================================================================//
// debugging only, dumps linkset data writes & deletes to debug console
    linkset_data(integer action, string name, string value) {
        if (!DEBUG) {return;}
        if (action == LINKSETDATA_RESET) {
            llSay(DEBUG_CHANNEL,"LSD CLeared.");
        }
        else if (action == LINKSETDATA_DELETE) {
            llSay(DEBUG_CHANNEL,"LSD DEL : \"" + name + "\"");
        }
        else if (action == LINKSETDATA_UPDATE) {
            llSay(DEBUG_CHANNEL,"LSD STO : \"" + name + "\"=\"" + value + "\"");
        }
    }
}
