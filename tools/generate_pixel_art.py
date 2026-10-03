#!/usr/bin/env python3
"""Author CROWNFRONT's original integer-grid sprite rigs and bake PNG atlases.

No external packs or image tracing. Pillow is needed only to rebuild artwork;
Godot uses the committed PNGs. Eight views retain physical weapon handedness.
"""
from pathlib import Path
from math import sin, cos, pi
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/pixel_art'
CELL = (32, 40)
FRAMES = 6
ACTIONS = ['idle', 'attack', 'heavy', 'guard', 'guard_hit', 'dash', 'recovery',
           'stun', 'heal', 'gather', 'carry', 'flee', 'deposit', 'death', 'spawn', 'bow_ready', 'windup', 'walk', 'flee_carry']
ROLES = ['player', 'melee', 'ranged', 'tank', 'worker']
INK = '#14262e'
DARK = '#344552'
STEEL = '#92aeb8'
LIGHT = '#d8e5dc'
GOLD = '#dab366'
GOLD_LIGHT = '#f3d58e'
WOOD = '#8b593e'
WOOD_LIGHT = '#c18b53'
SKIN = '#c9946a'
SKIN_LIGHT = '#edc99a'
PALETTES = {'azure': ('#267aa6', '#154665', '#67b6d1'),
            'ember': ('#b65038', '#6c2f31', '#ec9560')}


def sprite(role, team, action='idle', direction=2, frame=0, legs=False, moving=False):
    image = Image.new('RGBA', (32, 40))
    d = ImageDraw.Draw(image)
    cloth, cloth_dark, cloth_light = PALETTES[team]
    angle = direction * pi / 4
    forward = (cos(angle), sin(angle))
    right = (forward[1], -forward[0])
    back = forward[1] < -0.25
    side = abs(forward[0]) > 0.6
    scale = 1.0 if role == 'player' else (0.94 if role == 'tank' else 0.79)
    # Integer design coordinates use (12,27); padding makes the baked foot
    # anchor (16,31).
    def pt(x, y):
        return (4+round(12 + (x-12)*scale), 4+round(27 + (y-27)*scale))
    def rect(box, color, outline=None):
        a, b = pt(box[0], box[1]), pt(box[2], box[3])
        d.rectangle((*a, *b), fill=color, outline=outline)
    def poly(points, color, outline=None):
        d.polygon([pt(*p) for p in points], fill=color, outline=outline)
    def line(points, color, width=1):
        d.line([pt(*p) for p in points], fill=color, width=max(1, round(width*scale)))
    def ellipse(box, color, outline=None):
        d.ellipse((*pt(box[0],box[1]), *pt(box[2],box[3])), fill=color, outline=outline)
    progress = frame / (FRAMES-1)
    bob = (1 if frame in [1,4] else 0) if action == 'idle' else 0
    lean_x = forward[0] * (2 if action in ['dash','flee','flee_carry'] else 0)
    lean_y = 1 if action in ['guard','guard_hit','gather','recovery'] else 0
    if action == 'stun':
        lean_x = -forward[0]
        lean_y = 1
    if action == 'death':
        lean_y = round(progress * 5)
        lean_x = round(progress * 3)
    if legs:
        stride = sin(frame / FRAMES * 2*pi) * (2 if moving else 0)
        for foot in [-1,1]:
            x = 12 + foot*2.6 + forward[0]*stride*foot
            y = 25 + forward[1]*stride*foot
            if action in ['guard','heavy']:
                x += foot
            if action == 'dash':
                x -= forward[0]*2
            poly([(x-1,22),(x+1,22),(x+1, y+3),(x-1,y+3)], DARK, INK)
            rect((x-1,y+2,x+2,y+4), WOOD if role in ['ranged','worker'] else STEEL, INK)
            line([(x-1,y+2),(x+1,y+2)], WOOD_LIGHT if role in ['ranged','worker'] else LIGHT)
        return image

    cx, cy = 12+lean_x, 18+lean_y+bob
    h = (cx + forward[0]*0.5, 9+lean_y+bob)
    shoulder_width = 5.5 if role == 'tank' else 4.0
    # Cape is behind when facing away; visible to the side for front views.
    if role == 'player':
        trail = (-forward[0]*(4 if action == 'dash' else 1), -forward[1]*2)
        if action == 'walk':
            trail = (trail[0]+sin(progress*2*pi)*2,trail[1])
        poly([(cx-4,cy-5),(cx+4,cy-5),(cx+7+trail[0],26+trail[1]),
              (cx+trail[0],25+trail[1]),(cx-7+trail[0],26+trail[1])], cloth_dark, INK)
        line([(cx-3,cy-3),(cx-4+trail[0],24)], cloth)
        line([(cx+2,cy-3),(cx+3+trail[0],25)], cloth)
        line([(cx-5+trail[0],26+trail[1]),(cx-1+trail[0],25+trail[1])], GOLD)
    if role == 'ranged':
        poly([(cx-4,cy-6),(cx+4,cy-6),(cx+5,25),(cx,24),(cx-4,25)], cloth_dark, INK)
        for q in range(3):
            line([(cx-3+q,cy+3),(cx-2+q,25)], cloth)
        # Quiver stays opposite the bow rather than flipping with sprites.
        rect((cx-5,cy-4,cx-3,cy+4),WOOD,INK)
        for q in range(2):
            line([(cx-5+q*2,cy-7),(cx-4+q*2,cy-3)], GOLD_LIGHT)

    def hand_position(sign):
        hx, hy = cx+sign*right[0]*5, cy+sign*right[1]*3+2
        if sign > 0 and action == 'heavy':
            hx, hy = cx+right[0]*4, cy-3-progress*3
        elif sign < 0 and action in ['guard','guard_hit'] and role in ['player','melee','tank']:
            recoil = 2 if action == 'guard_hit' and frame < 3 else 0
            hx, hy = cx+forward[0]*(6-recoil), cy+forward[1]*(4-recoil)
        elif role == 'worker' and action in ['carry','flee_carry']:
            hx, hy = cx+sign*6, cy+3
        elif role == 'ranged':
            hx, hy = cx+forward[0]*(4 if sign>0 else -2), cy+forward[1]*3
        return hx, hy

    def weapon():
        if role == 'ranged':
            reach = 5 + (2*progress if action == 'bow_ready' else 0)
            bx, by = cx+forward[0]*reach, cy+forward[1]*reach*.6
            cross = right
            bend = 3
            points = [(bx+cross[0]*t+forward[0]*bend*(1-abs(t)/6),
                       by+cross[1]*t*.8+forward[1]*bend*.6*(1-abs(t)/6)) for t in [-6,-4,0,4,6]]
            line(points, INK,3)
            line(points, GOLD,1)
            pull = 3*progress if action == 'bow_ready' else (2*(1-progress) if action == 'attack' else 1)
            line([points[0],(bx-forward[0]*pull,by-forward[1]*pull*.6),points[-1]],LIGHT)
            if action != 'attack' or frame > 2:
                tip=(bx+forward[0]*7,by+forward[1]*4)
                line([(bx-forward[0]*3,by-forward[1]*2),tip],WOOD_LIGHT)
                rect((tip[0],tip[1],tip[0]+1,tip[1]+1),LIGHT)
            return
        if action in ['carry','flee_carry'] and role == 'worker':
            for q in range(3):
                y=cy+q*2
                rect((cx-6,y,cx+6,y+1),WOOD,INK)
                line([(cx-5,y),(cx+4,y)],WOOD_LIGHT)
                rect((cx+5,y,cx+5,y+1),GOLD_LIGHT)
            return
        if action in ['heal','deposit']:
            return
        hand = hand_position(1)
        theta = angle - 1.0
        if action == 'windup':
            theta = angle - 1.1 - progress*1.0
        elif action == 'attack':
            theta = angle - 0.25 + progress*1.8
        elif action == 'heavy':
            theta = -pi/2 - right[0]*.35
        elif action == 'gather':
            theta = angle - 2 + (sin(progress*pi*2)+1)*1.2
        elif action == 'recovery':
            theta = angle + 1.5 - progress*.6
        elif action in ['dash','flee','flee_carry']:
            theta = angle + 2.5
        elif action in ['guard','guard_hit']:
            theta = angle - 1.6
        if role in ['worker','tank']:
            length = 7 if role == 'tank' else 8
            tip = (hand[0]+cos(theta)*length,hand[1]+sin(theta)*length*.75-2)
            line([hand,tip],INK,3)
            line([hand,tip],WOOD_LIGHT)
            across=(-sin(theta)*3,cos(theta)*2)
            line([(tip[0]-across[0],tip[1]-across[1]),(tip[0]+across[0],tip[1]+across[1])],INK,5)
            line([(tip[0]-across[0],tip[1]-across[1]),(tip[0]+across[0],tip[1]+across[1])],STEEL,3)
            line([(tip[0]-across[0],tip[1]-across[1]-1),(tip[0]+across[0],tip[1]+across[1]-1)],LIGHT)
            if role == 'tank':
                rect((tip[0]-2,tip[1]-1,tip[0]+1,tip[1]+1),GOLD)
        else:
            tip = (hand[0]+cos(theta)*8,hand[1]+sin(theta)*7-2)
            line([hand,tip],INK,3)
            line([hand,tip],STEEL,2)
            line([(hand[0]+1,hand[1]-1),(tip[0],tip[1]-1)],LIGHT)
            cross=(-sin(theta)*2,cos(theta)*2)
            line([(hand[0]-cross[0],hand[1]-cross[1]),(hand[0]+cross[0],hand[1]+cross[1])],GOLD,2)

    def shield():
        if role not in ['player','melee','tank']:
            return
        sx,sy=cx-right[0]*5,cy-right[1]*3+2
        if action in ['guard','guard_hit']:
            sx,sy=cx+forward[0]*6,cy+forward[1]*4
            if action=='guard_hit':
                sx-=forward[0]*(2 if frame<3 else 0)
                sy-=forward[1]*(2 if frame<3 else 0)
        wide=4 if role in ['player','tank'] else 3
        poly([(sx-wide,sy-4),(sx+wide,sy-4),(sx+wide,sy+1),(sx,sy+5),(sx-wide,sy+1)],INK)
        poly([(sx-wide+1,sy-3),(sx+wide-1,sy-3),(sx+wide-1,sy+1),(sx,sy+3),(sx-wide+1,sy+1)],cloth)
        line([(sx-wide+1,sy-3),(sx+wide-1,sy-3)],GOLD)
        line([(sx,sy-2),(sx,sy+2)],GOLD_LIGHT)
        rect((sx-1,sy,sx+1,sy),GOLD_LIGHT)

    if back:
        shield()
        weapon()
    # Cloth body with armor highlights, waist belt and separate gloved hands.
    bw = 5 if role == 'tank' else 4
    poly([(cx-bw,cy-5),(cx+bw,cy-5),(cx+bw,cy+5),(cx-bw,cy+5)],cloth,INK)
    rect((cx-3,cy-4,cx+2,cy-1), STEEL if role in ['player','tank'] else cloth)
    if role in ['player','tank']:
        line([(cx-3,cy-4),(cx+2,cy-4)],LIGHT)
    rect((cx-4,cy+3,cx+4,cy+4),WOOD,INK)
    rect((cx,cy+3,cx+1,cy+4),GOLD)
    if not back and role!='worker':
        line([(cx,cy-1),(cx,cy+1)],GOLD)
        line([(cx-1,cy),(cx+1,cy)],GOLD_LIGHT)
    if role=='worker':
        poly([(cx-2,cy-3),(cx+2,cy-3),(cx+3,cy+6),(cx-3,cy+6)],WOOD_LIGHT,INK)
        line([(cx-2,cy-2),(cx+1,cy-2)],GOLD)
    for sign in [-1,1]:
        sx=cx+sign*shoulder_width
        sy=cy-3
        ellipse((sx-2,sy-2,sx+1,sy+1),STEEL if role in ['player','melee','tank'] else cloth,INK)
        if role in ['player','melee','tank']:
            line([(sx-1,sy-1),(sx,sy-1)],LIGHT)
        hx,hy=hand_position(sign)
        line([(sx,sy),(hx,hy)],INK,3)
        line([(sx,sy),(hx,hy)],STEEL if role in ['player','melee','tank'] else cloth,2)
        rect((hx-1,hy-1,hx+1,hy+1),SKIN if role in ['worker','ranged'] else STEEL,INK)
    if back and role == 'player':
        poly([(cx-4,cy-5),(cx+4,cy-5),(cx+5,25),(cx,26),(cx-5,25)],cloth_dark,INK)
        line([(cx-2,cy-3),(cx-2,24)],cloth)
        line([(cx+2,cy-3),(cx+3,24)],cloth)
        line([(cx-4,25),(cx+4,25)],GOLD)
    # Neck and heads include explicit back/side views, not mirrored front art.
    rect((h[0]-1,h[1]+3,h[0]+1,h[1]+5),WOOD if back else SKIN)
    if role=='worker':
        rect((h[0]-3,h[1]-1,h[0]+3,h[1]+4),SKIN,INK)
        if not back:
            rect((h[0]-2,h[1],h[0]+1,h[1]+2),SKIN_LIGHT)
            rect((h[0]+forward[0]*2,h[1]+1,h[0]+forward[0]*2,h[1]+1),INK)
            rect((h[0]-1,h[1]+3,h[0]+1,h[1]+4),WOOD)
        poly([(h[0]-5,h[1]-1),(h[0]-3,h[1]-2),(h[0]-2,h[1]-5),(h[0]+2,h[1]-5),
              (h[0]+3,h[1]-2),(h[0]+5,h[1]-1),(h[0]+4,h[1]),(h[0]-4,h[1])],GOLD,INK)
        line([(h[0]-2,h[1]-4),(h[0]+1,h[1]-4)],GOLD_LIGHT)
        line([(h[0]-4,h[1]-1),(h[0]+4,h[1]-1)],GOLD_LIGHT)
    elif role=='ranged':
        poly([(h[0],h[1]-5),(h[0]+4,h[1]-2),(h[0]+4,h[1]+4),
              (h[0]-4,h[1]+4),(h[0]-4,h[1]-2)],cloth_dark,INK)
        line([(h[0],h[1]-4),(h[0]+3,h[1]-1)],cloth_light)
        if not back:
            rect((h[0]-2+forward[0],h[1],h[0]+2+forward[0],h[1]+3),SKIN)
            line([(h[0]-1+forward[0],h[1]),(h[0]+1+forward[0],h[1])],INK)
            rect((h[0]+forward[0],h[1]+2,h[0]+forward[0]+1,h[1]+2),SKIN_LIGHT)
    else:
        poly([(h[0]-4,h[1]-2),(h[0]-2,h[1]-5),(h[0]+2,h[1]-5),(h[0]+4,h[1]-2),
              (h[0]+4,h[1]+4),(h[0]-3,h[1]+4)],STEEL,INK)
        rect((h[0]-2,h[1]-3,h[0],h[1]-1),LIGHT)
        line([(h[0]+2,h[1]-2),(h[0]+2,h[1]+3)],DARK)
        if not back:
            vx=h[0]+(1 if forward[0]>0 else -1 if forward[0]<0 else 0)
            line([(vx-2,h[1]),(vx+2,h[1])],INK)
            line([(vx,h[1]),(vx,h[1]+3)],LIGHT)
        else:
            line([(h[0]-2,h[1]+1),(h[0]+2,h[1]+1)],DARK)
        if role=='player':
            line([(h[0],h[1]-5),(h[0],h[1]-7)],GOLD)
            poly([(h[0],h[1]-7),(h[0]+2,h[1]-9),(h[0]+4,h[1]-8),(h[0]+3,h[1]-6)],cloth,INK)
            rect((h[0]+1,h[1]-8,h[0]+2,h[1]-8),cloth_light)
    if not back:
        weapon()
        shield()
    if back and role == 'worker' and action in ['carry','flee_carry']:
        weapon()
    if action=='death':
        image.alpha_composite(sprite(role,team,direction=direction,legs=True).resize((32,40),Image.Resampling.NEAREST))
        # Collapse about the fixed foot anchor; remains never affect simulation.
        fallen=Image.new('RGBA',(32,40))
        height=max(6,round(40-progress*20))
        small=image.resize((32,height),Image.Resampling.NEAREST)
        fallen.alpha_composite(small,(0,40-height))
        image=fallen
    return image.resize(CELL,Image.Resampling.NEAREST)


def bake_effects():
    names = ['slash', 'heavy', 'block', 'dash', 'woodchip', 'heal', 'stun', 'death', 'deposit', 'spawn', 'arrow']
    atlas = Image.new('RGBA',(32*FRAMES*8,32*len(names)))
    for row,name in enumerate(names):
        for direction in range(8):
            heading=direction*pi/4
            for frame in range(FRAMES):
                t=frame/(FRAMES-1)
                tile=Image.new('RGBA',(32,32))
                d=ImageDraw.Draw(tile)
                alpha=round(255*(1-t*.85))
                gold=(243,213,142,alpha)
                light=(216,229,220,alpha)
                if name=='arrow':
                    tail=(round(16-cos(heading)*7),round(16-sin(heading)*7))
                    tip=(round(16+cos(heading)*6),round(16+sin(heading)*6))
                    d.line((*tail,*tip),fill=(193,139,83,255),width=1)
                    d.rectangle((tip[0]-1,tip[1]-1,tip[0]+1,tip[1]+1),fill=(216,229,220,255))
                    d.rectangle((tail[0]-1,tail[1]-1,tail[0]+1,tail[1]+1),fill=(218,179,102,255))
                elif name in ['slash','heavy']:
                    radius=12 if name=='heavy' else 10
                    for j in range(7 if name=='heavy' else 4):
                        a=heading-.8+t*1.4-j*.13
                        x,y=round(16+cos(a)*radius),round(16+sin(a)*radius*.8)
                        d.rectangle((x,y,x+1,y+1),fill=light if j==0 else gold)
                elif name=='dash':
                    for j in range(3):
                        x=round(16-cos(heading)*(4+j*4+t*4))
                        y=round(16-sin(heading)*(4+j*4+t*4))
                        d.rectangle((x,y,x+2,y+1),fill=(103,182,209,alpha))
                elif name=='heal':
                    for j in range(3):
                        x=10+j*6
                        y=round(25-t*15-j*3)
                        d.line((x-1,y,x+1,y),fill=(166,216,158,alpha))
                        d.line((x,y-1,x,y+1),fill=(166,216,158,alpha))
                elif name=='stun':
                    for j in range(3):
                        x=round(16+cos(t*2*pi+j*2*pi/3)*8)
                        y=round(14+sin(t*2*pi+j*2*pi/3)*3)
                        d.line((x-1,y,x+1,y),fill=gold)
                        d.line((x,y-1,x,y+1),fill=gold)
                elif name=='deposit':
                    x,y=16,round(23-t*15)
                    d.rectangle((x-2,y-2,x+2,y+2),fill=gold)
                    d.rectangle((x-1,y-1,x+1,y+1),fill=light)
                else:
                    count=4 if name in ['block','woodchip'] else 6
                    for j in range(count):
                        a=j*2*pi/count+heading
                        radius=3+t*9
                        x,y=round(16+cos(a)*radius),round(16+sin(a)*radius)
                        color=(193,139,83,alpha) if name=='woodchip' else (146,174,184,alpha) if name=='death' else gold
                        d.rectangle((x,y,x+1,y+1),fill=color)
                atlas.paste(tile,((direction*FRAMES+frame)*32,row*32))
    atlas.save(OUT/'effects.png',optimize=True)
    shadow=Image.new('RGBA',(48,24))
    sd=ImageDraw.Draw(shadow)
    for x,y,w in [(10,8,28),(6,10,36),(4,12,40),(8,14,32),(12,16,24)]:
        sd.rectangle((x,y,x+w-1,y+1),fill=(8,17,22,95))
    shadow.save(OUT/'shadow.png')


def build():
    OUT.mkdir(parents=True,exist_ok=True)
    for role in ROLES:
        for team in PALETTES:
            body=Image.new('RGBA',(CELL[0]*FRAMES*8,CELL[1]*len(ACTIONS)))
            legs=Image.new('RGBA',(CELL[0]*FRAMES*8,CELL[1]*3))
            for row,action in enumerate(ACTIONS):
                for direction in range(8):
                    for frame in range(FRAMES):
                        tile = sprite(role,team,action,direction,frame)
                        bounds = tile.getbbox()
                        if action != 'death' and bounds and (bounds[0] <= 0 or bounds[1] <= 0 or bounds[2] >= CELL[0] or bounds[3] >= CELL[1]):
                            raise ValueError(f'Clipped sprite: {role}/{team}/{action}/{direction}/{frame}: {bounds}')
                        body.paste(tile,((direction*FRAMES+frame)*CELL[0],row*CELL[1]))
            for row,moving in enumerate([False,True,False]):
                for direction in range(8):
                    for frame in range(FRAMES):
                        legs.paste(sprite(role,team,action='guard' if row==2 else 'idle',direction=direction,frame=frame,legs=True,moving=moving),
                                   ((direction*FRAMES+frame)*CELL[0],row*CELL[1]))
            body.save(OUT/f'{role}-{team}-body.png',optimize=True)
            legs.save(OUT/f'{role}-{team}-legs.png',optimize=True)
    (OUT/'atlas.json').write_text(json.dumps(dict(cell=list(CELL),anchor=[16,31],pixel_scale=2,frames=FRAMES,
        directions=['E','SE','S','SW','W','NW','N','NE'],actions=ACTIONS,roles=ROLES,teams=list(PALETTES)),indent=2)+'\n')
    bake_effects()
    # Contact sheet shows authentic source frames at nearest-neighbor 3x zoom.
    sheet=Image.new('RGB',(1220,690),'#101e27')
    d=ImageDraw.Draw(sheet)
    font=ImageFont.load_default(size=18)
    small=ImageFont.load_default(size=13)
    d.text((24,16),'CROWNFRONT / CRISP MEDIEVAL / ORIGINAL PIXEL RIGS',font=font,fill='#f3d58e')
    for r,role in enumerate(ROLES):
        y=70+r*118
        d.text((20,y+34),role.upper(),font=small,fill='#d8e5dc')
        for direction in range(8):
            tile=sprite(role,'azure',direction=direction).copy()
            tile.alpha_composite(sprite(role,'azure',direction=direction,legs=True))
            tile=tile.resize((72,96),Image.Resampling.NEAREST)
            x=135+direction*96
            sheet.paste(tile,(x,y),tile)
            d.text((x+22,y+96),['E','SE','S','SW','W','NW','N','NE'][direction],font=small,fill='#67b6d1')
        tile=sprite(role,'ember',direction=1)
        tile.alpha_composite(sprite(role,'ember',direction=1,legs=True))
        tile=tile.resize((72,96),Image.Resampling.NEAREST)
        sheet.paste(tile,(1040,y),tile)
    sheet.save(OUT/'facing-contact-sheet.png')
    # Commander and worker action sequences are reviewable before integration.
    rows=[('player','attack'),('player','heavy'),('player','guard_hit'),('worker','gather')]
    sample=Image.new('RGB',(1080,640),'#101e27')
    sd=ImageDraw.Draw(sample)
    sd.text((24,16),'ACTION POSES / EXISTING GAMEPLAY TIMING',font=font,fill='#f3d58e')
    for r,(role,action) in enumerate(rows):
        y=70+r*135
        sd.text((20,y+30),f'{role}\n{action}',font=small,fill='#d8e5dc')
        for f in range(FRAMES):
            tile=sprite(role,'azure',action,1,f)
            tile.alpha_composite(sprite(role,'azure',direction=1,legs=True))
            tile=tile.resize((96,128),Image.Resampling.NEAREST)
            sample.paste(tile,(175+f*140,y),tile)
    sample.save(OUT/'action-contact-sheet.png')
    print('Baked 20 sprite atlases, metadata and two review sheets.')


if __name__=='__main__':
    build()
