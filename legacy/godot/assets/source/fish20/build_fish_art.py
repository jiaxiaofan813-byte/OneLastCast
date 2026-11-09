#!/usr/bin/env python3
"""Original species illustrations for One Last Cast. No external image assets.
All geometry, fin rays and marks are authored here; deterministic regeneration.
"""
from pathlib import Path
import math, random, json, html
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'assets/fish20'
INK='#244e50'
# Each body is independently drawn, rather than a recolored template.
DATA=[
('bluegill','Bluegill','sun','#657d58','#bfad5d','#e0b45f', 'M125 180 C168 130 174 98 270 93 C364 81 437 104 482 147 Q515 162 525 184 L512 194 Q490 249 409 267 C301 303 204 262 160 207 Z', (476,162), 'M525 184 Q507 188 496 184', 10),
('pumpkinseed','Pumpkinseed','sun','#688c73','#d4ac5f','#ef974e','M125 181 C168 142 187 102 281 96 C378 90 451 116 488 151 Q515 165 523 185 L508 199 C484 251 405 272 327 273 C228 273 185 232 157 201 Z',(477,163),'M523 185 Q507 191 496 185',10),
('black_crappie','Black crappie','crappie','#668479','#acb9a3','#ecdfb5','M124 179 C159 156 174 114 254 101 C347 79 418 102 464 130 Q483 149 509 159 L538 168 L531 183 Q513 185 502 200 C464 250 373 274 280 260 C201 247 173 218 147 194 Z',(479,151),'M538 168 L500 181 L485 175',8),
('yellow_perch','Yellow perch','perch','#758449','#dbc260','#edcf79','M124 178 C177 152 205 131 283 124 C385 113 465 134 508 159 L540 178 L527 192 Q486 223 395 234 C273 249 203 214 151 194 Z',(493,161),'M540 178 L514 184 L500 180',13),
('largemouth_bass','Largemouth bass','bass','#537660','#92a774','#d4cd9b','M123 177 C188 135 264 121 357 125 C418 126 457 137 483 154 L541 169 L545 188 L505 203 C487 229 435 242 371 245 C259 249 188 216 148 195 Z',(482,157),'M545 188 L451 191 Q451 209 475 211',10),
('walleye','Walleye','perch','#5d7565','#a5ad77','#e3d7a3','M123 178 C172 149 259 126 344 131 C408 132 466 145 501 162 L545 177 L538 193 L514 196 C472 224 409 234 328 233 C236 230 180 204 148 193 Z',(490,162),'M545 177 L503 187 L478 184 L488 201',14),
('northern_pike','Northern pike','pike','#567b67','#91a67c','#d4cd9f','M125 179 C211 153 313 145 403 149 Q449 151 479 165 L532 167 L558 177 L554 187 L491 198 Q460 214 408 216 C288 221 203 203 147 191 Z',(480,170),'M558 177 L509 183 L475 183 L482 193',0),
('smallmouth_bass','Smallmouth bass','bass','#6e7960','#a99762','#dcc294','M125 177 C181 137 253 116 330 119 C400 119 451 139 488 157 L530 171 L531 188 Q509 193 497 204 C459 237 393 247 318 239 C235 232 180 211 147 194 Z',(480,160),'M531 188 L482 186 Q475 199 494 204',10),
('spotted_bass','Spotted bass','bass','#5e7e65','#9bae7b','#d6d5aa','M125 177 C190 141 267 125 348 127 C414 129 458 144 492 161 L537 174 L533 191 L507 201 C468 230 405 238 334 235 C246 230 187 210 148 193 Z',(485,162),'M537 174 L481 186 L482 198',10),
('white_bass','White bass','bass','#6f9290','#b7c5af','#f2e3b7','M125 178 C172 147 214 109 302 105 C394 103 456 133 494 159 L534 178 L522 196 C484 231 405 252 319 247 C230 239 181 209 148 194 Z',(484,163),'M534 178 L498 187 L491 196',9),
('striped_bass','Striped bass','bass','#547b7a','#adbbb0','#e4dcbb','M125 179 C202 145 283 129 357 131 C422 134 467 149 505 168 L546 180 L535 195 Q484 220 404 230 C289 239 204 209 147 192 Z',(495,166),'M546 180 L504 189 L497 198',9),
('rock_bass','Rock bass','sun','#707757','#a79b67','#dac294','M125 180 C176 137 213 104 296 108 C375 105 439 129 476 153 L529 176 L523 194 C499 222 463 246 402 259 C309 276 209 243 159 201 Z',(483,164),'M529 176 L484 187 L483 200',11),
('white_crappie','White crappie','crappie','#799b91','#c1c6ab','#ece3c2','M125 180 C179 148 207 118 285 113 C366 103 428 117 467 140 Q484 156 508 164 L539 176 L529 191 L505 203 C455 241 377 256 296 246 C222 237 180 213 148 195 Z',(484,158),'M539 176 L502 187 L487 181',6),
('green_sunfish','Green sunfish','sun','#527d6e','#91a367','#dcc16a','M125 180 C180 146 217 121 294 121 C371 117 438 135 478 158 L534 176 L527 197 Q497 225 450 242 C358 269 251 243 190 214 L148 194 Z',(484,164),'M534 176 L481 188 L481 202',10),
('redear_sunfish','Redear sunfish','sun','#71866c','#b4b184','#e4ce9d','M125 181 C170 137 206 97 293 95 C387 93 447 123 481 154 L524 181 L511 199 C477 251 393 280 310 269 C228 257 180 221 151 197 Z',(478,163),'M524 181 L499 189 L493 185',10),
('longear_sunfish','Longear sunfish','sun','#438d83','#c29b5e','#f2944d','M125 180 C163 138 193 105 271 99 C363 91 423 110 464 146 Q501 157 518 180 L507 198 C484 250 408 278 328 278 C235 279 186 238 153 199 Z',(473,160),'M518 180 Q504 188 493 184',10),
('channel_catfish','Channel catfish','cat','#537c83','#91a9a2','#e3d7b9','M124 178 C200 145 282 136 375 142 C439 145 496 157 531 177 L544 190 L529 204 C488 216 444 230 370 232 C266 235 189 205 145 193 Z',(496,176),'M544 190 Q517 194 494 192',1),
('blue_catfish','Blue catfish','cat','#486b7d','#83a4ad','#d6d8c3','M124 179 C184 147 266 119 361 127 C439 132 493 153 532 175 L546 188 L534 205 C476 229 409 241 339 235 C253 228 188 206 146 194 Z',(499,174),'M546 188 Q516 196 491 193',1),
('brook_trout','Brook trout','trout','#426c61','#7a9671','#e5a465','M125 179 C193 145 282 129 370 134 C433 138 472 151 506 168 L544 181 L533 198 L509 201 Q465 226 392 231 C285 238 208 211 148 194 Z',(496,165),'M544 181 L492 190 L483 201',0),
('rainbow_trout','Rainbow trout','trout','#4c827b','#9ab8a0','#e2d4b9','M125 179 C191 147 281 130 366 133 C432 134 477 150 510 168 L545 181 L532 197 L508 201 C468 225 402 232 335 232 C254 231 191 207 147 194 Z',(497,165),'M545 181 L499 190 L488 201',0)
]

def path(d,fill,stroke=INK,sw=3,extra=''):
 return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'
def ellipse(x,y,rx,ry,fill,extra=''): return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" {extra}/>'
def line(x1,y1,x2,y2,color,sw=2,extra=''):return f'<path d="M{x1} {y1} L{x2} {y2}" fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" {extra}/>'
FIN_NUMBER=0
def fin(d,rays,color):
 global FIN_NUMBER
 FIN_NUMBER+=1
 cid='finclip'+str(FIN_NUMBER)
 return path(d,color,INK,3)+f'<defs><clipPath id="{cid}"><path d="{d}"/></clipPath></defs><g clip-path="url(#{cid})">'+''.join(path(r,'none',INK,1.5,'opacity=".36"') for r in rays)+'</g>' 
def dorsal_spiny(x,y,n,step,h,fall=0):
 # Individual counted hard rays, followed by membrane base.
 pts=[(x,y)]
 for k in range(n):
  xx=x+k*step; yy=y-fall*k
  pts.extend([(xx+step*.45,yy-h*(.65+.35*math.sin((k+1)/(n+1)*math.pi))),(xx+step*.95,yy-12)])
 pts.append((x+n*step,y+8))
 d='M'+' L'.join(f'{a:.1f} {b:.1f}' for a,b in pts)+' Z'
 rays=[f'M{x+k*step+step*.45:.1f} {y-fall*k-h*(.65+.35*math.sin((k+1)/(n+1)*math.pi)):.1f} L{x+k*step+step*.9:.1f} {y+9}' for k in range(n)]
 return d,rays

def art(row,index):
 ident,name,fam,back,mid,belly,body,eye,mouth,spines=row
 random.seed(700+index)
 defs=f'''<defs><linearGradient id="body" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{back}"/><stop offset=".48" stop-color="{mid}"/><stop offset="1" stop-color="{belly}"/></linearGradient><linearGradient id="fin" x1="0" y1="0" x2="0" y2="1"><stop stop-color="{back}"/><stop offset="1" stop-color="{belly}"/></linearGradient><clipPath id="bodyclip"><path d="{body}"/></clipPath></defs>'''
 a=[defs]
 # Caudal lobes: deeply forked cats/temperate bass, gently forked trout,
 # rounded sunfish; trout brook nearly square, rainbow shallow notch.
 if fam=='cat':
  tail='M153 174 C115 161 76 139 43 117 L68 166 L94 182 L66 205 L42 244 C86 224 121 205 153 194 Z'
 elif ident in ['white_bass','striped_bass','yellow_perch','walleye','northern_pike']:
  tail='M156 173 Q105 147 49 127 L66 157 L83 181 L66 207 L49 237 Q111 215 156 196 Z'
 elif ident=='brook_trout':
  tail='M154 173 Q102 153 51 144 Q60 180 52 220 Q107 211 155 196 Z'
 elif fam=='trout':
  tail='M155 174 Q109 150 49 134 Q63 167 77 183 Q61 202 50 231 Q111 213 155 195 Z'
 elif fam=='sun':
  tail='M155 169 Q112 134 65 124 Q54 148 78 179 Q55 207 66 237 Q111 224 155 197 Z'
 elif fam=='crappie':
  tail='M155 169 Q108 136 55 126 Q63 156 79 181 Q63 209 56 238 Q111 220 155 199 Z'
 else:
  tail='M154 170 Q105 146 55 133 Q53 159 67 182 Q53 206 55 231 Q111 216 154 198 Z'
 a.append(fin(tail,[f'M148 183 Q104 {yy} 60 {yy}' for yy in [143,157,170,195,208,223]],'url(#fin)'))
 # Anatomical fin architecture is not shared between families.
 if fam=='sun':
  y=117 if ident=='green_sunfish' else (108 if ident=='rock_bass' else 94)
  d,r=dorsal_spiny(273,y,spines,15,39)
  a.append(fin(d,r,'url(#fin)'))
  a.append(fin(f'M170 150 Q158 {y-25} 219 {y-40} Q251 {y-46} 280 {y} L279 131 Z',[f'M{177+i*10} {y+28-i*4} Q190 {y-5} {185+i*9} {y-26}' for i in range(9)],'url(#fin)'))
  a.append(fin('M190 212 Q169 268 215 286 Q253 303 286 258 L287 229 Z',[f'M{210+i*12} 237 L{191+i*12} {272+i*2}' for i in range(6)],'url(#fin)'))
  a.append(fin('M367 245 L347 283 Q382 286 404 255 Z',['M372 252 L357 280','M383 254 L375 282'],belly))
 elif fam=='crappie':
  y=109 if ident=='black_crappie' else 119
  d,r=dorsal_spiny(290,y,spines,15,57)
  a.append(fin(d,r,'url(#fin)'))
  a.append(fin(f'M171 151 Q162 69 230 58 Q267 53 300 {y} L291 147 Z',[f'M{188+i*12} 128 L{187+i*13} {85-i*2}' for i in range(9)],'url(#fin)'))
  a.append(fin('M177 208 Q166 285 224 297 Q268 303 324 249 L296 226 Z',[f'M{211+i*13} 239 L{184+i*15} {275+i*2}' for i in range(8)],'url(#fin)'))
  a.append(fin('M387 235 L357 270 Q384 277 409 244 Z',['M390 241 L370 270'],belly))
 elif fam in ['bass','perch']:
  y=122 if ident in ['smallmouth_bass','white_bass'] else 131
  # Rays slope toward head (right); rear soft dorsal is round.
  d,r=dorsal_spiny(300,y,spines,10,48)
  a.append(fin(d,r,'url(#fin)'))
  # Largemouth's very deep notch, spotted/smallmouth shallow notch.
  notch=142 if ident=='largemouth_bass' else 113
  soft_end=282 if ident in ['yellow_perch','walleye','white_bass','striped_bass'] else 311
  a.append(fin(f'M188 150 Q191 80 236 77 Q266 77 {soft_end-15} {notch} L{soft_end} 136 Z',[f'M{204+i*10} 136 L{207+i*10} {89+abs(3-i)*3}' for i in range(8)],'url(#fin)'))
  a.append(fin('M194 209 Q196 257 227 271 Q257 268 290 231 Z',[f'M{215+i*12} 220 L{209+i*12} {251+i*2}' for i in range(5)],'url(#fin)'))
  a.append(fin('M386 227 L355 267 Q388 270 411 236 Z',['M388 235 L367 263','M399 238 L383 261'], '#d6ac68' if ident=='yellow_perch' else belly))
 elif fam=='pike':
  a.append(fin('M155 168 Q149 113 190 107 L241 146 L244 164 Z',[f'M{171+i*12} 164 L{163+i*12} {125+i*3}' for i in range(6)],'url(#fin)'))
  a.append(fin('M166 197 L165 242 Q205 243 243 207 Z',[f'M{182+i*11} 204 L{178+i*11} {234-i*3}' for i in range(5)],'url(#fin)'))
  a.append(fin('M334 211 L319 253 Q346 251 365 213 Z',['M343 216 L333 246'],belly))
 elif fam=='cat':
  a.append(fin('M324 142 L332 64 Q358 91 391 148 Z',['M332 64 L348 145','M343 89 L361 143','M354 103 L373 145'],'url(#fin)'))
  a.append(fin('M176 161 Q182 128 204 130 Q221 133 234 149 Z',[],'url(#fin)'))
  if ident=='blue_catfish':
   a.append(fin('M175 199 L181 262 L305 265 L346 232 Z',[f'M{190+i*12} 216 L{190+i*12} 262' for i in range(11)],'url(#fin)'))
  else:
   a.append(fin('M178 200 Q173 257 211 267 Q260 278 319 232 Z',[f'M{192+i*12} 216 L{193+i*12} {255+int(10*math.sin(i/8*math.pi))}' for i in range(9)],'url(#fin)'))
  a.append(fin('M369 226 L349 269 Q384 266 404 230 Z',['M376 234 L362 262'],belly))
 elif fam=='trout':
  a.append(fin('M278 139 L288 78 Q311 69 345 132 Z',[f'M{290+i*9} 135 L{293+i*7} {84+i*4}' for i in range(6)],'url(#fin)'))
  a.append(fin('M170 164 Q169 132 186 132 Q202 131 216 151 Z',[],'url(#fin)'))
  a.append(fin('M194 205 L184 250 Q224 260 259 223 Z',[f'M{207+i*10} 219 L{195+i*10} 249' for i in range(4)],'#d7945a' if ident=='brook_trout' else 'url(#fin)'))
  a.append(fin('M345 225 L322 267 Q359 268 380 230 Z',['M351 234 L336 262'],'#d7945a' if ident=='brook_trout' else 'url(#fin)'))
  if ident=='brook_trout':
   a.append(path('M195 207 L185 250 M346 229 L323 266','none','#fff0d0',7))
   a.append(path('M201 210 L192 248 M351 232 L332 263','none',INK,3))
 a.append(path(body,'url(#body)',INK,4))
 # Subtle ventral reflection and hand-engraved scale arcs, all body-clipped.
 a.append('<g clip-path="url(#bodyclip)">')
 a.append(path('M133 201 Q322 263 535 198 L559 310 L110 309 Z','#fff1d1','none',0,'opacity=".15"'))
 if fam!='cat':
  for yy in range(143,249,15):
   for xx in range(155+(yy%2)*7,448,16):
    a.append(path(f'M{xx} {yy-4} q8 4 0 8','none',INK,1,'opacity=".09"'))
 if ident in ['bluegill','yellow_perch','smallmouth_bass','white_crappie']:
  n={'bluegill':6,'yellow_perch':7,'smallmouth_bass':9,'white_crappie':7}[ident]
  for k in range(n):
   xx=180+k*(265/(n-1)); w=13 if ident!='yellow_perch' else 19
   a.append(path(f'M{xx-6} 109 Q{xx+w} 153 {xx+1} 181 Q{xx+w/2} 211 {xx-3} 245 L{xx-w} 247 Q{xx-5} 201 {xx-w} 173 L{xx-w-3} 111 Z', '#3c6257','none',0,f'opacity="{.48 if ident=="yellow_perch" else .28}"'))
 if ident in ['largemouth_bass','spotted_bass']:
  # Broken broad lateral stripe extends through caudal peduncle.
  for k in range(12):
   xx=139+k*28
   a.append(path(f'M{xx} 174 l14 -6 l17 6 l-2 14 l-15 5 l-18 -7 Z','#365d4c','none',0,'opacity=".73"'))
 if ident in ['white_bass','striped_bass']:
  for k in range(7):
   yy=143+k*12
   # White bass lower lines broken, striped bass continuous.
   a.append(path(f'M135 {181+(yy-180)*.15} Q307 {yy-12} 468 {yy+3}','none','#3e6463',3.5, 'opacity=".8"'+(' stroke-dasharray="25 13 17 9"' if ident=='white_bass' and k>=3 else '')))
 if ident in ['black_crappie','rock_bass','spotted_bass','redear_sunfish']:
  for j in range(90 if ident=='black_crappie' else 65):
   xx=random.uniform(159,448); yy=random.uniform(115 if ident=='black_crappie' else 164,259)
   if ident in ['rock_bass','spotted_bass']:
    xx=165+(j%13)*22; yy=198+(j//13)*12
   r=random.uniform(2.2,8) if ident=='black_crappie' else random.uniform(1.8,3.4)
   a.append(ellipse(round(xx,1),round(yy,1),round(r,1),round(r*.7,1),'#355d52','opacity=".62"'))
 if ident=='pumpkinseed':
  for j in range(112):
   xx=random.uniform(170,444); yy=random.uniform(105,266)
   a.append(ellipse(round(xx,1),round(yy,1),3.3,2.2, '#57b6b1' if j%3 else '#e4804c','opacity=".85"'))
 if ident=='longear_sunfish':
  for j in range(75):
   xx=random.uniform(173,413); yy=random.uniform(105,269)
   a.append(ellipse(round(xx,1),round(yy,1),4,2.3,'#3ba5a4','opacity=".85"'))
  a.append(path('M220 210 Q332 264 438 224 L415 289 L224 280 Z','#f58c48','none',0,'opacity=".35"'))
 if ident=='green_sunfish':
  for j in range(60):
   a.append(ellipse(175+(j%12)*21,142+(j//12)*21,2.7,2,'#65c0bd','opacity=".8"'))
 if ident=='walleye':
  for j in range(42):
   xx=random.uniform(166,443); yy=random.uniform(132,213)
   a.append(ellipse(round(xx,1),round(yy,1),random.uniform(3,8),random.uniform(2,4),'#4a6953','opacity=".4"'))
 if ident=='northern_pike':
  for y in range(162,218,15):
   for x in range(170+(y%2)*12,461,28):
    a.append(ellipse(x,y,8.5,3.1,'#e7db9f','transform="rotate(-15 %s %s)" opacity=".9"'%(x,y)))
 if ident=='channel_catfish':
  for j in range(34):
   a.append(ellipse(round(random.uniform(187,453),1),round(random.uniform(147,209),1),2.8,2.4,'#244f59','opacity=".7"'))
 if ident=='brook_trout':
  for j in range(21):
   xx=159+j*14; yy=150+random.uniform(-13,5)
   a.append(path(f'M{xx:.1f} {yy:.1f} q-6 -11 5 -9 q10 0 6 -10 q-7 -8 5 -9','none','#c5c78c',2.7,'opacity=".9"'))
  for j in range(36):
   xx=random.uniform(170,459); yy=random.uniform(166,224)
   a.append(ellipse(round(xx,1),round(yy,1),4.5,3.5,'#e4d895'))
  for x,y in [(211,183),(252,205),(291,180),(334,210),(374,185),(416,204),(451,177)]:
   a.append(ellipse(x,y,6,5,'#8ebcc0'));a.append(ellipse(x,y,2.7,2.7,'#dc6652'))
 if ident=='rainbow_trout':
  a.append(path('M132 181 Q308 169 474 183','none','#d88486',19,'opacity=".72"'))
  for j in range(93):
   xx=random.uniform(150,492); yy=random.uniform(124,219)
   a.append(ellipse(round(xx,1),round(yy,1),2.5,2,'#335650','opacity=".8"'))
 a.append('</g>')
 # Species fin details outside the body: diagnostic marks.
 if ident=='bluegill':
  a.append(ellipse(210,90,17,9,'#244e50','opacity=".9"'))
  a.append(path('M458 182 Q475 180 487 195 Q475 212 454 220 Q460 198 458 182 Z','#638f9c','none',0,'opacity=".7"'))
 if ident=='walleye':
  a.append(path('M53 228 L67 208 L82 212 L52 237 Z','#fff1ce',INK,1));a.append(path('M302 108 L310 86 L323 122 Z','#244e50','none'))
 if ident in ['black_crappie','white_crappie','rainbow_trout','brook_trout','northern_pike']:
  a.append(f'<defs><clipPath id="tailclip"><path d="{tail}"/></clipPath></defs><g clip-path="url(#tailclip)">')
  for j in range(20):
   xx=random.uniform(63,115); yy=random.uniform(148,216)
   # Restrict to rays in tail lobes, not transparent fork gap.
   if xx<80 and abs(yy-182)<17: continue
   a.append(ellipse(round(xx,1),round(yy,1),2.4,1.8,'#35594f','opacity=".7"'))
  a.append('</g>')
 # Curved operculum, cheeks, head light. Deliberately no human smiles.
 gx=eye[0]-53; gy=eye[1]+18
 a.append(path(f'M{gx-1} {gy-35} Q{gx-36} {gy+4} {gx-7} {gy+55}','none',INK,2.8,'opacity=".7"'))
 a.append(path(f'M{gx+4} {gy-33} Q{gx-19} {gy+2} {gx+1} {gy+47}','none','#f7e8ba',2,'opacity=".45"'))
 a.append(path(f'M{eye[0]-15} {eye[1]-17} Q{eye[0]+12} {eye[1]-18} {eye[0]+22} {eye[1]-5}','none','#fff0c8',2.4,'opacity=".55"'))
 # Pectoral fin fans towards the tail, leaving face and stripe readable.
 py=210 if fam=='sun' else 199
 px=431 if fam=='sun' else 438
 if ident=='northern_pike':px=454;py=198
 a.append(fin(f'M{px} {py} Q{px-46} {py-5} {px-74} {py+23} Q{px-39} {py+39} {px-5} {py+9} Z',[f'M{px-4} {py+5} Q{px-35} {py+10+i*4} {px-61+i*6} {py+24+i*2}' for i in range(4)], '#d8b675' if fam=='sun' else '#b4b38c'))
 if fam=='sun':
  # Ear flap species signatures: bluegill black, red-ear rim, pumpkin red spot,
  # longear extended black lobe edged cream; green blue cheek and cream margins.
  if ident=='longear_sunfish':
   a.append(path('M438 178 Q410 173 379 185 Q381 207 425 203 L442 189 Z','#203f49','#eed3aa',3))
  elif ident=='redear_sunfish':
   a.append(ellipse(430,188,18,12,'#db6d4b'));a.append(ellipse(435,186,14,11,'#23484b'))
  elif ident=='pumpkinseed':
   a.append(ellipse(435,185,16,12,'#244a4e'));a.append(ellipse(421,187,5,6,'#f47e48'))
  elif ident=='bluegill':a.append(ellipse(432,184,18,13,'#24484b'))
  elif ident=='green_sunfish':a.append(ellipse(435,186,16,10,'#244a4e','stroke="#e8c779" stroke-width="3"'))
  if ident in ['pumpkinseed','longear_sunfish','green_sunfish']:
   for k in range(4):
    a.append(path(f'M{450+k*10} {179+k*3} Q{452+k*7} {201+k*3} {441+k*10} {213+k*4}','none','#60c4c1',3))
 # Eye iris is small and anatomical, with just one illustration highlight.
 ex,ey=eye; er=10 if fam!='cat' else 6
 iris='#df6a44' if ident=='rock_bass' else '#e6c770'
 if ident=='walleye':iris='#d8e1bb';er=12
 a.append(ellipse(ex,ey,er,er,iris,f'stroke="{INK}" stroke-width="2.5"'))
 a.append(ellipse(ex+2,ey,er*.53,er*.62,INK))
 a.append(ellipse(ex+3,ey-3,2.2 if fam!='cat' else 1.4,2.2 if fam!='cat' else 1.4,'#fff5dc'))
 a.append(path(mouth,'none',INK,3))
 if fam=='cat':
  # Four pairs of barbels: nasal, maxillary, chin, outer mandibular.
  a.append(path('M524 179 Q543 160 555 165 M518 179 Q536 151 543 156 M538 191 Q567 194 570 215 M529 194 Q550 204 552 228 M525 202 Q528 225 513 235 M512 206 Q506 226 493 229 M503 207 Q492 222 479 220 M493 207 Q482 216 470 216','none',INK,2.8))
 # Highlight on back and final outline protect the silhouette at game size.
 a.append(path('M174 159 Q275 105 419 139','none','#fff2cf',2.5,'clip-path="url(#bodyclip)" opacity=".3"'))
 return ''.join(a)

manifest=[]
for i,row in enumerate(DATA):
 ident,name,fam,*_=row
 inner=art(row,i)
 svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="600" height="360" viewBox="0 0 600 360"><title>{html.escape(name)}</title><desc>Original warm natural-history illustration; right-facing adult species, transparent background. Authored for One Last Cast.</desc>{inner}</svg>'
 ET.fromstring(svg)
 (OUT/f'{ident}.svg').write_text(svg)
 manifest.append({'index':i,'id':ident,'name':name,'family':fam,'svg':f'res://assets/fish20/{ident}.svg','png':f'res://assets/fish20/{ident}.png','canvas_px':[600,360],'anchor_px':[300,180],'visual_bounds_px':[40,45,535,255],'body_hitbox_px':[155,135 if fam not in ['sun','crappie'] else 110,370,100 if fam not in ['sun','crappie'] else 160],'facing':'right','license':'Original project artwork; no third-party image assets','anatomy_notes_source':'docs/fish-morphology.md'})
(OUT/'manifest.json').write_text(json.dumps({'version':1,'style':'Warm natural-history vector illustration with teal ink and cream highlights','species':manifest},ensure_ascii=False,indent=2))
# A pure SVG contact sheet embeds each complete authored image, no external refs.
for small in [False,True]:
 W,H=(1400,1700) if not small else (1100,780)
 cw,ch=(350,340) if not small else (275,156)
 pieces=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',f'<rect width="{W}" height="{H}" fill="#f6e9c6"/>']
 for i,row in enumerate(DATA):
  x=(i%4)*cw;y=(i//4)*ch
  pieces.append(f'<rect x="{x+7}" y="{y+7}" width="{cw-14}" height="{ch-14}" rx="16" fill="#fff3d6" stroke="#d3cfaa"/>')
  # Godot's SVG loader does not support text; labels are encoded as metadata in
  # this sheet and a companion numbered legend, raster render uses system font.
  scale=.53 if not small else .117
  px=x+(cw-600*scale)/2;py=y+(25 if not small else 35)
  unique=art(row,i).replace('id="','id="s%d_'%i).replace('url(#','url(#s%d_'%i)
  pieces.append(f'<g transform="translate({px} {py}) scale({scale})">{unique}</g>')
  if not small:
   for width,offset in [(33,223.9),(50,218.2),(70,211.4)]:
    unique2=art(row,i).replace('id="','id="m%d_%d_'%(i,width)).replace('url(#','url(#m%d_%d_'%(i,width))
    pieces.append(f'<g transform="translate({x+30+(width-33)*5} {y+offset}) scale({width/535})">{unique2}</g>')
  pieces.append(f'<text x="{x+cw/2}" y="{y+ch-30}" text-anchor="middle" font-family="sans-serif" font-size="17" fill="#244e50">{i+1:02}. {html.escape(row[1])}</text>')
 pieces.append('</svg>')
 ET.fromstring(''.join(pieces))
 (OUT/('contact-sheet-game-size.svg' if small else 'contact-sheet.svg')).write_text(''.join(pieces))
print('Wrote 20 SVG fish, manifest, two contact sheets to',OUT)
