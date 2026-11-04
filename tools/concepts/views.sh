#!/bin/bash
# concept view: name json eye look sun sky lens
R=/home/claude/mow-and-grow/tools/concepts/render.py
D=$(dirname $(readlink -f $0))
r() { RES=1350x810 SAMPLES=18 python3 $R $D/concept_$1.json $D/$2.png "$3" "$4" "$5" "$6" ${7:-30} 2>&1 | grep -o "RENDERED.*\|Error.*"; }
case "$1" in
meadow)
 r meadow meadow_1_gate "10,40,-150" "-8,6,10" "45,120" "0.6,0.78,1.0" &
 r meadow meadow_2_over "150,150,-150" "0,0,10" "45,120" "0.6,0.78,1.0" 34 &
 wait
 r meadow meadow_3_bridge "4,9,-6" "-40,26,52" "45,120" "0.6,0.78,1.0" 26 &
 r meadow meadow_4_pond "-6,10,-60" "40,0,-20" "45,120" "0.6,0.78,1.0" 28 &
 wait;;
frost)
 r frost frost_1_gate "6,50,-150" "0,16,20" "55,160" "0.64,0.8,1.0" &
 r frost frost_2_over "-150,160,-150" "0,6,10" "55,160" "0.64,0.8,1.0" 34 &
 wait
 r frost frost_3_lake "-24,9,-26" "4,22,46" "55,160" "0.64,0.8,1.0" 26 &
 wait;;
ember)
 r ember ember_1_gate "6,50,-150" "4,14,20" "20,210" "0.66,0.42,0.34" &
 r ember ember_2_over "150,160,-150" "0,6,10" "20,210" "0.66,0.42,0.34" 34 &
 wait
 r ember ember_3_bridge "2,9,-50" "-30,4,-6" "20,210" "0.66,0.42,0.34" 26 &
 wait;;
esac
