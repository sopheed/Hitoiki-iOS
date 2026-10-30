#!/usr/bin/env python3
"""Original Pota icon. Rasterize our native-style geometry with supersampling."""
from pathlib import Path
import math,json
from PIL import Image,ImageDraw,ImageFilter
root=Path(__file__).resolve().parents[1]
S=3; N=1024
def render(dark=False):
    im=Image.new('RGB',(N*S,N*S)); px=im.load()
    top,bottom=((21,50,40),(39,78,59)) if dark else ((244,247,228),(215,237,217))
    for y in range(N*S):
        t=y/(N*S-1); c=tuple(round(a+(b-a)*t) for a,b in zip(top,bottom))
        ImageDraw.Draw(im).line((0,y,N*S,y),fill=c)
    d=ImageDraw.Draw(im)
    def ellipse(box,fill): d.ellipse(tuple(int(v*S) for v in box),fill=fill)
    def line(points,fill,width): d.line([(int(x*S),int(y*S)) for x,y in points],fill=fill,width=int(width*S),joint='curve')
    def bez(points):
        start=points[0]; path=[start]
        for c1,c2,end in points[1:]:
            for i in range(1,61):
                t=i/60; u=1-t
                path.append((u**3*start[0]+3*u*u*t*c1[0]+3*u*t*t*c2[0]+t**3*end[0],u**3*start[1]+3*u*u*t*c1[1]+3*u*t*t*c2[1]+t**3*end[1]))
            start=end
        return path
    ellipse((207,827,823,890),(198,221,200) if not dark else (19,45,35))
    ellipse((286,796,463,867),(65,136,111)); ellipse((562,796,739,867),(65,136,111))
    shape=bez([(529,140),((560,275),(836,346),(840,598)),((853,799),(695,847),(512,846)),((313,849),(167,763),(181,596)),((188,411),(431,266),(529,140))])
    mask=Image.new('L',im.size); md=ImageDraw.Draw(mask); md.polygon([(round(x*S),round(y*S)) for x,y in shape],fill=255)
    grad=Image.new('RGB',im.size); gd=ImageDraw.Draw(grad)
    for y in range(N*S):
        t=min(1,max(0,(y/S-140)/706)); gd.line((0,y,N*S,y),fill=tuple(round(a+(b-a)*t) for a,b in zip((184,231,193),(101,192,160))))
    im.paste(grad,(0,0),mask); d=ImageDraw.Draw(im)
    # A soft highlight, little feet, warm cheeks, eyes, and a tiny smile.
    hi=bez([(365,421),((392,395),(400,418),(388,444)),((365,488),(342,500),(338,484)),((334,469),(342,444),(365,421))])
    d.polygon([(int(x*S),int(y*S)) for x,y in hi],fill=(216,244,216))
    ellipse((282,620,376,660),(232,164,139)); ellipse((650,620,744,660),(232,164,139))
    d.rounded_rectangle((389*S,547*S,418*S,597*S),radius=15*S,fill=(39,77,62))
    d.rounded_rectangle((610*S,547*S,639*S,597*S),radius=15*S,fill=(39,77,62))
    smile=[]
    for i in range(41):
        t=i/40; smile.append((481+64*t,627+27*math.sin(t*math.pi)))
    line(smile,(39,77,62),10)
    # A small four-point glint echoes a moment of clarity.
    d.polygon([(int(x*S),int(y*S)) for x,y in [(801,178),(812,209),(843,220),(812,231),(801,262),(790,231),(759,220),(790,209)]],fill=(97,143,108) if not dark else (184,219,178))
    ellipse((208,303,225,320),(114,160,122) if not dark else (184,219,178))
    return im.resize((N,N),Image.Resampling.LANCZOS)
for target in ['Hitoiki','HitoikiWatch']:
    catalog=root/target/'Assets.xcassets'; app=catalog/'AppIcon.appiconset'; app.mkdir(parents=True,exist_ok=True)
    (catalog/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}}))
    render().save(app/'AppIcon.png'); render(True).save(app/'AppIcon-dark.png')
    platform='watchos' if target=='HitoikiWatch' else 'ios'
    images=[{'filename':'AppIcon.png','idiom':'universal','platform':platform,'size':'1024x1024'}]
    if target=='Hitoiki': images.append({'appearances':[{'appearance':'luminosity','value':'dark'}],'filename':'AppIcon-dark.png','idiom':'universal','platform':'ios','size':'1024x1024'})
    else: (app/'AppIcon-dark.png').unlink()
    (app/'Contents.json').write_text(json.dumps({'images':images,'info':{'author':'xcode','version':1}},indent=2))
print('Generated original opaque 1024px iPhone and Watch icons')
