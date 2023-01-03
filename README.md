# SecondLife-PopulationMeter
A simple LSL population meter for Second Life that shows a graph and some numbers in hovertext, keeps track of highest and lowest seen values.

Rez a prim, add the [script](https://github.com/0xc0ffea/SecondLife-PopulationMeter/blob/main/SL_Population.lsl), job done.

Default values for DEPTH and FREQUENCY update every 30 minutes and shows the last 12 hours as a chart.

The chart shows data collected by the script, so it will take 12 hours to draw the full chart as seen below (assuming default values).

![Plywood cube showing the output of the population meter](assets/SecondLIfe%20PopulationMeter%20Screenshot.png)

## Version History
### V2
 - DEBUG boolean variable that outputs to the Second Life debug console. (Off by default)
 - Store working dataset in linkset KVP memory to survive script resets, mainly for debugging at this point. What data is kept and how that's presented is likely to change in a future version.
 - Github based update checking, script will inform when there is a new version.
### V1
 - Initial release.
---

Second Life™ and Linden Lab™ are trademarks or registered trademarks of Linden Research, Inc. No infringement is intended.
