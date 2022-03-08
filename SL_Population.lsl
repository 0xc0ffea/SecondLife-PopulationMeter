// *** GLOBALS ***

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


// *** IMPORTANT STUFF ***

default {
    state_entry() {
        // Letsa Go! 
        
        // clear hover test
        llSetText("",ZERO_VECTOR,TRUE);
        // how many steps do we have graphics for?
        STEPS_COUNTS = llGetListLength(STEPS);
        // prefill the POP_COUNT list with zeros.
        integer x;
        for (x=0; x<DEPTH; x++) {
            POP_COUNT += [0];
        }
        
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

        // START THE CLOCK !
        llSetTimerEvent(0.1);
    }
    
    timer() {
        // request some data
        HTTP = llHTTPRequest("http://secondlife.com/httprequest/homepage.php", [], "");
        // See you back .. later
        llSetTimerEvent(FREQUENCY*60);
    }
    
    http_response(key request_id, integer status, list metadata, string body) {
        if (request_id != HTTP) {return;}
        if (status != 200) {
            // oh dear .. no data this time
            POP_COUNT = llDeleteSubList(POP_COUNT,0,0) + [0];
            return;
        }
        // dump everything into a list call temp
        list temp = llParseString2List(body, ["\n"], []);
        
        // temp looks like 
        // signups_updated_slt, 2020-09-08 15:55:01, signups_updated_unix, 1599605701, signups, 64419527, exchange_rate_updated_slt, 2022-03-07 18:15:01, exchange_rate_updated_unix, 1646705701, exchange_rate, 244.5049, inworld_updated_unix, 1646705717, inworld_updated_slt, 2022-03-07 18:15:17, inworld, 44512
        
        // grab the value we care about
        integer inworld = llList2Integer(temp,llListFindList(temp,["inworld"]) + 1); 
        string  inworld_updated_slt = llList2String(temp,llListFindList(temp,["inworld_updated_slt"]) + 1);
        
        // slap it onto the end of the numbers
        POP_COUNT = llDeleteSubList(POP_COUNT,0,0) + [inworld];
        
        // update the high pop and poop pop counts while were here
        integer x; integer y;
        for (x=0; x<llGetListLength(POP_COUNT); x++) {
            y = llList2Integer(POP_COUNT,x);
            // a new high score !!
            if ((inworld > y) && (inworld > POP_HIGH)) {
                POP_HIGH = inworld;
                POP_HIGH_WHEN = inworld_updated_slt; 
            }
            // a new low score :(
            if ((inworld < y) && (inworld < POP_POOP)) {
                POP_POOP = inworld;
                POP_POOP_WHEN = inworld_updated_slt;
            }
        }
        
        // work out the up down change from the last number
        integer diff = inworld - llList2Integer(POP_COUNT,-2);
        // a little + sign for when the pop is raising .. we dont need to worry about -
        string sign = "+";
        if (diff < 0) {sign = "";}
         
        // Render some hover text (and dont show garbage on the first pass)
        string hovertext = "SL POPULATION ("+CHART_SCALE+")\n"+(string)inworld+" online";
        if (POP_POOP != 0x0FFFFFFF) {hovertext += " ("+sign+(string)diff+")";}
        hovertext += "\n" + drawchart(POP_COUNT)+"\nHIGH:"+(string)POP_HIGH+" ("+POP_HIGH_WHEN+")";
        if (POP_POOP != 0x0FFFFFFF) {hovertext += "\nLOW:"+(string)POP_POOP+" ("+POP_POOP_WHEN+")";}
        
        llSetText(hovertext,<1,1,1>,1);

    }
}
