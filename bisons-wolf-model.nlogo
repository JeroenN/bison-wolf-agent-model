breed [bisons bison]
breed [wolves wolf]

globals [
  slowdown-speed-multiplier
  slowdown-energy-multiplier
  snow-clear-radius
  snow-clear-angle
  energy-consumption
  number-of-calves
  calf-stat-multiplier
  initial-slow-stacks   ;; make the slowing effect of snow last a few ticks

  catches
  losts
  lock-ons
  counter
  ordetect
  prevprey
]

bisons-own [
  calf?                  ;; is this a baby?
  visible-neighbors      ;; what birds can I see nearby?
  closest-neighbor       ;; who's the closest bird I can see?
  speed                  ;; allows for variation in base speed based on creature type
  tick-base-speed        ;; accounts for slowed speed                 ;; what speed am I flying at?
  happy?                 ;; am I content with my current place?
  angle
  energy                  ;; amount of energy left to do things
  tick-energy-consumption ;; accounts for slowed
  slowed                  ;; is the bison slowed by the snow?
  flockmates         ;; agentset of nearby turtles
  nearest-neighbor   ;; closest one of our flockmates
  slow-down
  slow-down-time
]

wolves-own [
  nearest-prey
  locked-on          ;; locked on prey if any
  delta-noise        ;; random rotation per update
  handle-time        ;; count down handle time
  slowed             ;; is the wolf slowed by snow?
  speed-wolf
]


;;
;; Setup Procedures
;;

to setup
  clear-all
  set slowdown-speed-multiplier 0.3
  set slowdown-energy-multiplier 2
  set snow-clear-radius 1
  set snow-clear-angle 60
  set energy-consumption 10
  set number-of-calves number-of-bisons * calve-pct / 100
  set calf-stat-multiplier 0.9
  set initial-slow-stacks 5

  create-bisons number-of-bisons [
    set calf? false
    setxy 50 + random-float 10 50 + random-float 10
    set heading 10 + random-float 10
    set speed base-speed
    set size 1.5 ; easier to see
    set happy? false
    set energy 9001
    set slowed 0
    set color yellow
    set flockmates no-turtles
    set slow-down false
    set slow-down-time 0
  ]
  create-bisons number-of-calves [
    set calf? true
    setxy 50 + random-float 10 50 + random-float 10
    set heading 10 + random-float 10
    set speed base-speed * calf-stat-multiplier
    set size 1.5
    set happy? false
    set energy 9001 * calf-stat-multiplier
    set slowed 0
    set color green
  ]
  set counter 0
  set lock-ons 0
  set ordetect 8
  reset-ticks
end

;;
;; Runtime Procedures
;;

to go
  ;; wolf prep
  ask wolves [
    set delta-noise 0.1 * (random-normal 0 wolf-noise-stddev)
  ]
  if ticks = 300
  [
   create-wolves wolf-population
   [
    set color green
    set size 2.0
    setxy random-xcor random-ycor
    set nearest-prey nobody
    set locked-on nobody
    set slowed 0
   ]
  ]
  ;; wolf prep end
  ask bisons
  [
    clear-snow  ;; also sets the agenent slowed? to true if it needs to clear snow
    if slowed > 0
    [
      set speed 0.18
      set slowed slowed - 1
    ]

    if slow-down = true
    [
      set speed 0.16
      set slow-down-time slow-down-time + 1
      if slow-down-time >= 20
      [
        set slow-down-time 0
        set slow-down false
        set speed base-speed
        ifelse calf? = false
        [
          set color yellow
        ]
        [
          set color green
        ]
      ]
    ]
    detect-neighbors
    find-flockmates
    if any? flockmates
    [ find-nearest-neighbor
      ifelse distance nearest-neighbor < minimum-separation
      [
        separate
      ]
      [
        align
        if distance nearest-neighbor > 0.5
        [
          cohere
        ]
      ]
    ]
  ]

  ;let escape-task select-escape-task
  let t 0
  repeat 10 [
    if t mod (11 - update-freq) = 0 [
      let dt 1 / update-freq
      ;; add escape task behavior
    ]
    if t mod (11 - wolf-update-freq) = 0 [
      let dt 1 / wolf-update-freq
      ask wolves [
        select-prey dt
        hunt dt
      ]
    ]
    ;; add bison fleeing
    ask wolves [
      clear-snow
      rt delta-noise
      set speed-wolf wolf-speed
      if slowed > 0
      [
        set speed-wolf speed-wolf - 0.02
        set slowed slowed - 1
      ]
      let nearest-bison min-one-of bisons with [calf? = false] [distance myself]
      if distance nearest-bison < 2
      [
        separate-wolf
      ]
    ]
    set t t + 1
  ]
  if not hunting?
  [
    set counter counter + 1
  ]
  if counter > 300
  [
    set hunting? true
    set detection-range ordetect
  ]

  move-forward-bisons-wolves
  tick
end

to move-forward-bisons-wolves
  repeat 5
  [
    ask bisons
    [
      fd speed
    ]
    ask wolves
    [
      fd speed-wolf
    ]
    display
  ]
end
to detect-neighbors
  let look-right-distance 1
  let look-left-distance 1
  let n-turtles-right 0
  let n-turtles-left 0
  while [look-right-distance <= 3 ]
  [
    set n-turtles-right n-turtles-right + count turtles-on patch-right-and-ahead 90 look-right-distance
    set look-right-distance look-right-distance + 1
  ]
  while [look-left-distance <= 3 ]
  [
    set n-turtles-left n-turtles-left + count turtles-on patch-right-and-ahead 90 look-left-distance
    set look-left-distance look-left-distance + 1
  ]

  if n-turtles-right > 2 or n-turtles-left > 2
  [
    ;set color red
    set slow-down true
  ]
end
to find-flockmates  ;; turtle procedure
  set flockmates other turtles in-radius vision
end

to find-nearest-neighbor ;; turtle procedure
  set nearest-neighbor min-one-of flockmates [distance myself]
end

;;; SEPARATE

to separate  ;; turtle procedure
  turn-away ([heading] of nearest-neighbor) max-separate-turn
end

to separate-wolf
  let nearest-bison min-one-of bisons with [calf? = false] [distance myself]
  turn-away ([heading] of nearest-bison) max-separate-turn
end
;;; ALIGN

to align  ;; turtle procedure
  turn-towards average-flockmate-heading max-align-turn
end

to-report average-flockmate-heading  ;; turtle procedure
  ;; We can't just average the heading variables here.
  ;; For example, the average of 1 and 359 should be 0,
  ;; not 180.  So we have to use trigonometry.
  let x-component sum [dx] of flockmates
  let y-component sum [dy] of flockmates
  ifelse x-component = 0 and y-component = 0
    [ report heading ]
    [ report atan x-component y-component ]
end

;;; COHERE

to cohere  ;; turtle procedure
  turn-towards average-heading-towards-flockmates max-cohere-turn
end

to-report average-heading-towards-flockmates  ;; turtle procedure
  ;; "towards myself" gives us the heading from the other turtle
  ;; to me, but we want the heading from me to the other turtle,
  ;; so we add 180
  let x-component mean [sin (towards myself + 180)] of flockmates
  let y-component mean [cos (towards myself + 180)] of flockmates
  ifelse x-component = 0 and y-component = 0
    [ report heading ]
    [ report atan x-component y-component ]
end

;;; HELPER PROCEDURES


to turn-away [new-heading max-turn]  ;; turtle procedure
  turn-at-most (subtract-headings heading new-heading) max-turn
end

to clear-snow
  if ticks > 300
  [
    if pcolor = black or any? patches with [pcolor = black] in-cone snow-clear-radius snow-clear-angle [
      ;set pcolor red
      set slowed initial-slow-stacks
    ]
    ask patches in-cone snow-clear-radius snow-clear-angle
    [
      set pcolor grey
    ]
  ]
end

;;
;; bison UTILITY PROCEDURES, for turning gradually towards a new heading
;;

to turn-towards [new-heading max-turn]  ;; bison procedure
  turn-at-most (subtract-headings new-heading heading) max-turn
end

to turn-at-most [turn maximum-turn]  ;; bison procedure
  ifelse abs turn > maximum-turn [
    ifelse turn >= 0
      [ rt maximum-turn ]
      [ lt maximum-turn ]
  ] [
    rt turn
  ]
end

;;; wolf PROCEDURES

to select-prey [dt] ;; wolf procedure
  set handle-time handle-time - dt

  if handle-time <= 0
  [
    set nearest-prey min-one-of bisons with [calf? = true] in-cone wolf-vision wolf-FOV [distance myself]
    let nearest-bison min-one-of bisons  with [calf? = false] [distance myself]

    ifelse locked-on != nobody and
         ((nearest-prey = nobody or distance nearest-prey > lock-on-distance) or
         (nearest-prey != locked-on)) or distance nearest-bison < 1
    [
        ;; lost it
        release-locked-on
        set handle-time switch-penalty
        set losts losts + 1
        set color blue
        ;stop
    ]
    [
      set color orange  ;; hunting w/o lock-on
      if nearest-prey != nobody
      [
        if distance nearest-prey < lock-on-distance
        [
          set locked-on nearest-prey
          ask locked-on [set color magenta]
          if nearest-prey != prevprey
          [
            set lock-ons lock-ons + 1
          ]
          set color red
          set prevprey nearest-prey
          set hunting? true
        ]
      ]
    ]
  ]
end

to hunt [dt] ;; wolf procedure
  if nearest-prey != nobody
  [
    turn-towards towards nearest-prey max-hunt-turn * dt
    if locked-on != nobody [
      if locked-on = min-one-of bisons with [calf? = true] in-cone catch-distance 10 [distance myself]
      [
        set catches catches + 1
        release-locked-on
        set hunting? false
        set counter 0
        set detection-range ordetect  ;;;; was: 0
        set handle-time catch-handle-time
        rt random-normal 0 45
        set color green
      ]
    ]
  ]
end

to release-locked-on
  if locked-on != nobody
  [
    ask locked-on
    [
      ifelse calf? = false
      [
        set color yellow
      ]
      [
        set color green
      ]
    ]
  ]
  set locked-on nobody
  set nearest-prey nobody
  set prevprey nobody
end
@#$#@#$#@
GRAPHICS-WINDOW
200
10
705
516
-1
-1
7.0
1
10
1
1
1
0
1
1
1
-35
35
-35
35
1
1
1
ticks
45.0

SLIDER
10
115
190
148
vision-distance
vision-distance
0
20
10.0
1
1
NIL
HORIZONTAL

BUTTON
100
50
185
83
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
10
50
95
83
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
255
190
288
base-speed
base-speed
0
2
0.2
.01
1
NIL
HORIZONTAL

SLIDER
10
150
190
183
vision-cone
vision-cone
0
270
120.0
1
1
deg
HORIZONTAL

SLIDER
10
10
192
43
number-of-bisons
number-of-bisons
0
100
15.0
1
1
NIL
HORIZONTAL

TEXTBOX
40
95
175
113
Vision Parameters
13
0.0
1

TEXTBOX
40
235
170
253
Motion Parameters
13
0.0
1

SLIDER
10
290
190
323
speed-change-factor
speed-change-factor
0
1
0.1
.05
1
NIL
HORIZONTAL

SLIDER
10
500
190
533
calve-pct
calve-pct
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
950
10
1155
43
wolf-noise-stddev
wolf-noise-stddev
0
5
2.0
0.1
1
NIL
HORIZONTAL

SLIDER
730
10
930
43
wolf-population
wolf-population
0
5
1.0
1
1
NIL
HORIZONTAL

CHOOSER
980
95
1118
140
update-freq
update-freq
1 2 5 10
0

CHOOSER
980
155
1122
200
wolf-update-freq
wolf-update-freq
1 2 5 10
0

SLIDER
735
160
940
193
wolf-speed
wolf-speed
0
5
0.2
0.05
1
NIL
HORIZONTAL

SWITCH
770
110
887
143
hunting?
hunting?
0
1
-1000

SLIDER
735
335
940
368
detection-range
detection-range
0
50
8.0
1
1
NIL
HORIZONTAL

SLIDER
735
380
940
413
wolf-vision
wolf-vision
0
100
16.0
1
1
NIL
HORIZONTAL

SLIDER
735
430
940
463
wolf-FOV
wolf-FOV
0
360
270.0
1
1
NIL
HORIZONTAL

SLIDER
735
480
940
513
lock-on-distance
lock-on-distance
0
5
5.0
0.1
1
NIL
HORIZONTAL

SLIDER
950
50
1155
83
switch-penalty
switch-penalty
0
50
5.0
1
1
ticks
HORIZONTAL

SLIDER
735
205
940
238
max-hunt-turn
max-hunt-turn
0
20
10.0
0.25
1
NIL
HORIZONTAL

SLIDER
735
250
940
283
catch-distance
catch-distance
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
735
290
940
323
catch-handle-time
catch-handle-time
0
1000
50.0
1
1
ticks
HORIZONTAL

MONITOR
730
50
792
95
NIL
catches
17
1
11

MONITOR
800
50
857
95
NIL
losts
17
1
11

MONITOR
865
50
932
95
NIL
lock-ons
17
1
11

SLIDER
10
545
182
578
max-align-turn
max-align-turn
0
20
5.0
1
1
degrees
HORIZONTAL

SLIDER
10
590
197
623
max-cohere-turn
max-cohere-turn
0
20
3.0
1
1
 degrees
HORIZONTAL

SLIDER
10
630
180
663
max-separate-turn
max-separate-turn
0
10
1.5
0.5
1
degrees
HORIZONTAL

SLIDER
245
635
437
668
minimum-separation
minimum-separation
0
5
1.0
1
1
patches
HORIZONTAL

SLIDER
247
585
437
618
vision
vision
0
10
5.0
0.5
1
patches
HORIZONTAL

@#$#@#$#@
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
@#$#@#$#@
setup
repeat 1000 [ go ]
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
