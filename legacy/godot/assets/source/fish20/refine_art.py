from pathlib import Path
p=Path(__file__).with_name('build_fish_art.py')
s=p.read_text()
s=s.replace("def fin(d,rays,color):\n return path(d,color,INK,3)+''.join(path(r,'none',INK,1.5,'opacity=\".36\"') for r in rays)",'''FIN_NUMBER=0
def fin(d,rays,color):
 global FIN_NUMBER
 FIN_NUMBER+=1
 cid='finclip'+str(FIN_NUMBER)
 return path(d,color,INK,3)+f'<defs><clipPath id="{cid}"><path d="{d}"/></clipPath></defs><g clip-path="url(#{cid})">'+''.join(path(r,'none',INK,1.5,'opacity=".36"') for r in rays)+'</g>' ''')
s=s.replace('Q48 148 56 179 Q49 207 66','Q54 148 78 179 Q55 207 66')
s=s.replace("y=117 if ident=='green_sunfish' else 94", "y=117 if ident=='green_sunfish' else (108 if ident=='rock_bass' else 94)")
s=s.replace("a.append(fin(f'M188 150 Q191 80 236 77 Q266 77 292 {notch} L311 136 Z'", "soft_end=282 if ident in ['yellow_perch','walleye','white_bass','striped_bass'] else 311\n  a.append(fin(f'M188 150 Q191 80 236 77 Q266 77 {soft_end-15} {notch} L{soft_end} 136 Z'")
s=s.replace("r=random.uniform(2,5.6) if ident=='black_crappie'", "r=random.uniform(2.2,8) if ident=='black_crappie'")
s=s.replace("if ident=='bluegill': a.append(ellipse(210,90,17,9,'#244e50','opacity=\".9\"'))", "if ident=='bluegill':\n  a.append(ellipse(210,90,17,9,'#244e50','opacity=\".9\"'))\n  a.append(path('M458 182 Q475 180 487 195 Q475 212 454 220 Q460 198 458 182 Z','#638f9c','none',0,'opacity=\".7\"'))")
s=s.replace("for j in range(20):\n   xx=random.uniform(63,115)", "a.append(f'<defs><clipPath id=\"tailclip\"><path d=\"{tail}\"/></clipPath></defs><g clip-path=\"url(#tailclip)\">')\n  for j in range(20):\n   xx=random.uniform(63,115)")
s=s.replace("# Curved operculum, cheeks, head light.","  a.append('</g>')\n # Curved operculum, cheeks, head light.")
p.write_text(s)
