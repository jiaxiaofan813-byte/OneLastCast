from pathlib import Path
import random,re,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[3]
random.seed(31)
s=[]
def add(x): s.append(x)
def path(d,fill='none',stroke='#284f50',w=.8,extra=''):
 add(f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round" {extra}/>')
def ellipse(x,y,rx,ry,fill,stroke='none',w=.7,extra=''):
 add(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{w}" {extra}/>')
def line(x,y,a,b,c='#284f50',w=.6,extra=''):path(f'M{x} {y}L{a} {b}','none',c,w,extra)
add('''<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1920" viewBox="0 0 360 640"><title>One Last Cast — homeward light</title><desc>Original editable scene: a determined angler puts in one final cast as a cabin lamp glows over a freshwater lake.</desc><defs>
<linearGradient id="sky" x2="0" y2="1"><stop stop-color="#fff4d6"/><stop offset=".65" stop-color="#f4e6bd"/><stop offset="1" stop-color="#e7bf7d"/></linearGradient>
<linearGradient id="lake" x2="0" y2="1"><stop stop-color="#83b3a6"/><stop offset=".25" stop-color="#4c8b85"/><stop offset=".64" stop-color="#245b60"/><stop offset="1" stop-color="#173e49"/></linearGradient>
<linearGradient id="wood" x2="0" y2="1"><stop stop-color="#c79d61"/><stop offset="1" stop-color="#916844"/></linearGradient>
<linearGradient id="coat" x2="1" y2="1"><stop stop-color="#e1bc6d"/><stop offset="1" stop-color="#b88c4b"/></linearGradient>
<radialGradient id="sunGlow"><stop stop-color="#fff4cc" stop-opacity=".95"/><stop offset="1" stop-color="#ffe4a2" stop-opacity="0"/></radialGradient>
<radialGradient id="lamp"><stop stop-color="#ffedaa" stop-opacity=".5"/><stop offset="1" stop-color="#ffedaa" stop-opacity="0"/></radialGradient>
<pattern id="paper" width="9" height="11" patternUnits="userSpaceOnUse"><circle cx="2" cy="3" r=".22" fill="#6d7958" opacity=".12"/><circle cx="7" cy="8" r=".18" fill="#fff7dc" opacity=".35"/></pattern>
</defs>''')
add('<rect width="360" height="640" fill="url(#sky)"/>')
# Framing clouds, distant evening light. Middle deliberately quiet for the title.
for d in ['M-20 45 Q5 38 28 44 Q43 29 68 38 Q82 39 87 47 Q109 43 121 51 L-20 51Z','M270 63 Q282 50 301 57 Q309 44 326 50 Q337 48 348 58 Q371 53 380 66Z','M-12 214 Q10 202 28 209 Q36 196 54 203 Q67 203 72 212 L108 218 L-12 219Z']:
 path(d,'#fff8e2','none')
ellipse(282,242,68,68,'url(#sunGlow)');ellipse(282,242,24,24,'#ffe7ad')
path('M-10 272 L24 243 41 256 71 224 95 242 113 236 141 262 166 242 195 264 220 250 248 268 281 256 316 273 360 246 375 298H-10Z','#b5bd9c','none')
path('M37 260 L71 224 95 242 80 237 72 240 65 238Z','#e8ddaf','none')
path('M-10 286 Q47 260 89 274 Q121 280 157 270 Q194 253 229 271 Q289 290 365 268 L370 309H-10Z','#8da58b','none')
# Fine etched pines along far shore.
def pine(x,y,h,c):
 path(f'M{x} {y-h}L{x-h*.22} {y-h*.41}L{x-h*.1} {y-h*.42}L{x-h*.35} {y}H{x+h*.35}L{x+h*.1} {y-h*.42}L{x+h*.22} {y-h*.41}Z',c,'none');line(x,y,x,y+3,c,.7)
for i in range(62):
 x=i*6+random.uniform(-2,2); y=288+3*__import__('math').sin(x/26);pine(x,y,random.uniform(8,22),'#678f7e')
add('<rect y="294" width="360" height="346" fill="url(#lake)"/>')
path('M-5 292Q50 281 96 292Q137 299 165 290Q203 284 244 293Q285 298 365 286V301Q300 306 244 301Q194 291 164 298Q128 307 96 298Q40 290-5 300Z','#729986','none')
# Cabin on opposite shore, a single welcoming golden window.
path('M24 279L24 266L43 254L62 265V282Z','#bb9d6e','#5d7c68',.7)
path('M19 268L42 251L67 267L61 269L42 258L25 271Z','#506f63','#45665b',.7)
for y in range(268,282,3):line(26,y,61,y,'#9b885e',.45)
add('<path d="M51 259V251H56V263" fill="#697c66"/>');add('<rect x="31" y="269" width="7" height="10" rx=".8" fill="#ffe9a6"/>');line(34.5,269,34.5,279,'#8d875d',.5)
add('<rect x="47" y="270" width="7" height="12" fill="#66785e"/>')
path('M14 284Q39 280 73 285L74 288H13Z','#557b68','none')
for x in [18,61,68]:line(x,285,x,292,'#567668',1)
path('M53 249Q47 243 53 240Q59 237 54 231','none','#c4c4a0',1.5)
# Sunset reflection and sparse horizontal strokes.
for i in range(30):
 y=302+i*3.3;x=282+random.uniform(-5,5);width=(4+i*.65)*random.uniform(.3,1)
 line(x-width,y,x+width,y,'#e6d5a0',random.uniform(.5,1.1),f'opacity="{.5-i*.012}"')
for i in range(100):
 x=random.uniform(0,360); y=random.uniform(302,409);w=random.uniform(3,21)
 line(x,y,x+w,y,'#d1dec1',.4,f'opacity="{random.uniform(.12,.4):.2f}"')
# Very faint lake-depth rays; central menu area remains clear.
path('M8 303L61 640H111L24 303Z','#afc8a2','none',extra='opacity=".025"')
path('M324 303L243 640H273L337 303Z','#afc8a2','none',extra='opacity=".035"')
# Boat shadow and circles.
ellipse(176,382,110,8,'#315f60',extra='opacity=".35"')
for x,y,rx in [(169,389,108),(170,394,84),(314,360,13)]:
 path(f'M{x-rx} {y}Q{x} {y+6} {x+rx} {y}','none','#bdcfad',.7,extra='opacity=".55"')
# Fishing rod, line held in a long fine curve.
path('M204 325Q230 272 270 264Q304 256 318 281','none','#294e4a',1.9)
path('M205 324Q232 275 270 266Q302 258 318 281','none','#d7bc74',.6)
for x,y in [(229,289),(248,275),(270,264),(295,265),(315,277)]:ellipse(x,y,1.2,1.7,'none','#294e4a',.6)
path('M318 281C327 303 306 327 314 355','none','#f2dfaa',.65)
# Body is drawn behind the rail.
path('M145 324Q137 338 144 356L169 362L195 354L193 326Z','#43645c','#284f50',1)
path('M155 340Q167 336 183 339L205 350L218 352L221 359L202 362L177 350L165 359L147 356Z','#506c61','#284f50',1)
path('M203 350Q218 347 223 352L227 360L211 363L202 359Z','#364f49','#244b4d',.9)
line(211,353,219,354,'#a6af88',.6);line(212,356,221,357,'#a6af88',.6)
path('M146 300Q137 308 138 325L144 342Q163 349 186 338L187 308L175 297Z','url(#coat)','#284f50',1.2)
path('M146 304Q154 314 150 338M178 304Q170 316 177 340','none','#9c8049',.8)
path('M144 314L153 315L151 326L144 325Z','#dcc17d','#8d8250',.7)
path('M178 314L186 313L185 324L177 326Z','#dcc17d','#8d8250',.7)
line(163,308,163,338,'#746e47',1);ellipse(166,317,.8,.8,'#526f59');ellipse(165,327,.8,.8,'#526f59')
# Determined head, expressive nose and tiny scruffy beard.
path('M151 280L149 293Q150 306 165 309Q178 308 181 299L186 296Q188 292 181 291L178 279Z','#e6bc88','#294f4d',1)
path('M151 291Q147 288 146 293Q145 299 152 299','#e4b683','#294f4d',.8)
path('M152 300Q164 309 178 301L174 310Q161 314 153 307Z','#eee0b4','#516457',.65)
for x in range(155,175,3):line(x,304,x+1,308,'#b5ac85',.55)
path('M168 287L176 285','none','#31524b',1.6);ellipse(174,290,1.1,1.3,'#284c49');path('M178 298Q174 300 170 299','none','#775f43',.7)
# Oversized fishing hat, lures and stitch detail.
path('M145 278L147 264Q150 252 164 252Q177 252 182 276Z','#bbad6e','#284f50',1.1)
path('M151 260Q163 256 176 261M149 264Q163 260 179 266','none','#d9ca88',.7)
path('M145 271Q164 267 182 274L183 279Q163 273 145 277Z','#5e7861','#345650',.7)
path('M132 278Q147 272 167 276Q184 275 192 283Q186 288 166 285Q146 284 135 286Q129 284 132 278Z','#d3bd7b','#284f50',1.1)
path('M137 280Q162 277 184 282','none','#eee0a2',.8)
for x in range(140,181,4):line(x,281,x+1,283,'#a3965e',.45)
path('M152 270Q144 260 149 255Q157 261 152 270','#6d9987','#345650',.55);line(152,270,150,258,'#e5d8a1',.45)
ellipse(176,274,2.2,1,'#d58e62','#335651',.5)
# Arm and hand deliberately clear against coat and water.
path('M177 307Q185 307 190 318L202 316L206 322Q193 332 185 327L176 318Z','#cfa65f','#284f50',1)
path('M201 316L205 312Q208 310 210 313L210 317Q215 317 213 321L205 325L201 322Z','#e6bc88','#284f50',.8)
path('M198 326L211 308','none','#655039',3)
ellipse(207,326,4,4,'#c7bc87','#294f4d',.8);ellipse(207,326,2,2,'#637c67');line(211,326,214,329,'#294f4d',1);ellipse(214,330,1.4,1,'#294f4d')
# Wicker creel, flap, straps and woven hatch.
path('M105 334Q117 329 133 334L136 355Q121 363 106 355Z','#c5a267','#284f50',1)
for y in range(338,356,3):path(f'M107 {y}Q121 {y+4} 134 {y}','none','#8e794e',.55)
for x in range(109,134,3):path(f'M{x} 335L{x+1} 356','none','#e1c58a',.6)
path('M104 334Q117 326 133 332L135 337Q118 341 104 337Z','#d3b57b','#284f50',.8)
path('M113 331Q109 320 123 320Q132 321 130 332','none','#49685c',2)
add('<rect x="118" y="334" width="4" height="9" rx="1" fill="#64735b" stroke="#284f50" stroke-width=".5"/>')
# Lantern with honey glow, tea cup.
ellipse(242,344,25,25,'url(#lamp)')
path('M237 337Q236 329 242 328Q248 328 247 337','none','#355951',1)
path('M237 338L236 352L248 352L247 338Z','#ffe5a0','#365b54',.8)
path('M235 336Q242 332 249 336L248 339H236Z','#5b7661','#284f50',.7)
path('M236 352H248L250 355H234Z','#5b7661','#284f50',.7)
line(239,339,239,351,'#b99557',.6);line(245,339,245,351,'#b99557',.6)
path('M241 348Q239 345 242 341Q245 346 243 349Z','#fff6ca','none')
path('M88 347H98L97 355H89Z','#e6dbc0','#365b54',.8);path('M98 349Q104 347 103 351Q102 354 98 353','none','#365b54',.8)
# Boat top, hull and hand-scribed cedar planking.
path('M75 350Q162 368 275 344L257 372Q172 400 96 374Z','url(#wood)','#284f50',1.4)
path('M76 350Q165 366 275 344L271 350Q164 374 81 357Z','#e5c58c','#294f4e',1)
path('M89 364Q174 384 266 359M96 374Q173 395 257 371','none','#6e6245',.8)
path('M93 360Q171 379 263 355','none','#eed3a0',.55)
for i in range(26):
 x=98+i*6;y=371+9*__import__('math').sin((x-98)/160*3.14)
 path(f'M{x} {y}q4 1 8 0','none','#6d6547',.4)
for x,y in [(100,368),(118,373),(143,377),(171,378),(199,376),(226,371),(249,365)]:ellipse(x,y,.85,.85,'#4f5b47')
path('M113 365Q119 362 124 366Q118 369 113 365Z','none','#89724d',.55)
# Oar mounted across the stern; engraved blade.
path('M130 347L70 391','none','#284f50',4.5);path('M130 347L70 391','none','#d1af70',2.5)
path('M77 383Q72 380 67 385L48 398Q45 402 51 406Q57 409 63 403L80 389Z','#c5a168','#284f50',1)
path('M52 402L73 386M55 404L75 388','none','#e5c28a',.65)
# Actual freshwater species from the game's original SVG art, subdued at the edges.
for name,tx,ty,scale,opacity in [('bluegill',-19,445,.15,.23),('brook_trout',270,567,.16,.23)]:
 f=ROOT/'assets/fish20'/f'{name}.svg'
 if f.exists():
  v=f.read_text(); inner=v[v.find('>')+1:v.rfind('</svg>')]
  ids=re.findall(r'id="([^"]+)"',inner)
  for ident in ids:
   inner=inner.replace(f'id="{ident}"',f'id="cover_{name}_{ident}"').replace(f'url(#{ident})',f'url(#cover_{name}_{ident})')
  add(f'<g transform="translate({tx} {ty}) scale({scale})" opacity="{opacity}">{inner}</g>')
# Reeds, fine stems and seed heads frame the page rather than filling menu space.
for side in [0,1]:
 for i in range(15):
  x=(-5+i*2.2) if not side else (335+i*2.5); base=647;tip=random.uniform(562,625);bend=random.uniform(-14,14)
  path(f'M{x} {base}Q{x+bend} {tip+20} {x+bend*.7} {tip}','none','#3f7066',random.uniform(.6,1.3))
  if i%3==0:
   path(f'M{x+bend*.7} {tip+9}L{x+bend*.7} {tip-1}','none','#79917a',2.4)
  path(f'M{x} {base}Q{x+(-15 if side else 15)} {tip+25} {x+(-20 if side else 20)} {tip+19}Q{x+(-5 if side else 5)} {tip+41} {x} {base}','#315d58','none')
# Dragonfly near shore, float and small airborne birds.
line(314,350,314,360,'#304f4a',.7);ellipse(314,355,1.7,3,'#dba46e','#325951',.6);ellipse(314,353.5,1.5,1.4,'#fff0bf')
for x,y in [(237,226),(247,222),(229,231)]:path(f'M{x-3} {y+1}Q{x-1} {y-2} {x} {y}Q{x+2} {y-2} {x+4} {y}','none','#83937a',.65)
add('<rect width="360" height="640" fill="url(#paper)"/></svg>')
svg=''.join(s);ET.fromstring(svg)
out=ROOT/'assets/source/cover/cover.svg';out.write_text(svg)
print(out,len(svg))
