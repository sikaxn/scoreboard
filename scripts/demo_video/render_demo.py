#!/usr/bin/env python3
"""Render a 1080p review edit using real footage, supplied bezels, and scene voiceovers."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
FONT='/System/Library/Fonts/Supplemental/Arial.ttf'
BOLD='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
FONT_INDEX=0
SPLIT={'01-result','03-live-controls','04-audience-views','07-remote-display-control','09-appearance-sound'}

def typeface(path,size): return ImageFont.truetype(path,size,index=FONT_INDEX)

def display_text(scene):
    if scene.get('locale')=='zh-Hans':
        return dict(brand='聪明的计分板',operator='操作端 iPad',audience='Apple TV · 观众屏幕',
                    controller='协同操作 iPad',web='内置浏览器画面',scoreboard='实时计分板',
                    overlay='直播比分叠层',commentator='解说员面板',
                    web_callout='实时比分 · 浏览器来源 · 解说员面板')
    return dict(brand='SMART SCOREBOARD',operator='OPERATOR IPAD',audience='APPLE TV · AUDIENCE SCREEN',
                controller='CONTROL IPAD',web='Built-in browser graphics',scoreboard='LIVE SCOREBOARD',
                overlay='LIVESTREAM OVERLAY',commentator='COMMENTATOR DASHBOARD',
                web_callout='Live scores • Browser sources • Commentator dashboard')

def run(*args):
    try: subprocess.run(list(map(str,args)),check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
    except subprocess.CalledProcessError as error:
        print(error.stderr.decode()[-5000:]); raise
def probe(path):
    return json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(path)]))

def graphic(scene, folder, bezel_path):
    labels=display_text(scene)
    base=Image.new('RGB',(1920,1080),(8,15,28))
    d=ImageDraw.Draw(base)
    # Subtle blue lower-right glow and a consistent product-video layout.
    for y in range(1080):
        ratio=y/1080
        d.line((0,y,1920,y),fill=(8+int(ratio*3),15+int(ratio*5),28+int(ratio*10)))
    d.rounded_rectangle((70,55,281,91),18,fill=(24,49,62))
    d.text((88,64),labels['brand'],font=typeface(BOLD,17),fill=(115,226,211))
    title_font=typeface(BOLD,54)
    d.text((70,109),scene['title'],font=title_font,fill='white')
    title_bounds=d.textbbox((70,109),scene['title'],font=title_font)
    d.text((70,1008),scene['callout'],font=typeface(FONT,27),fill=(186,203,220))
    d.text((1760,1013),f"{int(scene['id'][:2]):02} / 10",font=typeface(FONT,19),fill=(99,127,148))
    foreground=Image.new('RGBA',(1920,1080))
    bezel=Image.open(bezel_path).convert('RGBA')
    tv=Image.open(folder/'apple-tv-4k.png').convert('RGBA')
    boxes=[]
    if scene['id'] in SPLIT:
        placements=[(35,285,820,labels['operator'],bezel,(110,106,2420,1668)),
                    (880,285,1030,labels['audience'],tv,(103,119,3840,2160))]
        if scene['id']=='07-remote-display-control': placements[0]=(35,285,820,labels['controller'],bezel,(110,106,2420,1668))
    else:
        placements=[(415,214,1090,labels['operator'],bezel,(110,106,2420,1668))]
    layout=[]
    for x,y,width,label,art,aperture in placements:
        scale=width/art.width; height=round(art.height*scale)
        label_font=typeface(BOLD,20)
        label_bounds=d.textbbox((x+25,y-35),label,font=label_font)
        if max(title_bounds[0],label_bounds[0])<min(title_bounds[2],label_bounds[2]) and max(title_bounds[1],label_bounds[1])<min(title_bounds[3],label_bounds[3]):
            raise ValueError('Heading overlaps device label: '+scene['id'])
        d.text((x+25,y-35),label,font=label_font,fill=(123,156,181))
        foreground.alpha_composite(art.resize((width,height),Image.Resampling.LANCZOS),(x,y))
        ax,ay,aw,ah=aperture
        sx=x+round(ax*scale); sy=y+round(ay*scale)
        sw=round(aw*scale); sh=round(ah*scale)
        boxes.append((sx,sy,sw,sh))
        layout.append(dict(label=label,label_bounds=label_bounds,frame=[x,y,width,height],screen=[sx,sy,sw,sh]))
    backdrop=folder/f"{scene['id']}-background.png"; frame=folder/f"{scene['id']}-bezel.png"
    base.save(backdrop); foreground.save(frame)
    (folder/f"{scene['id']}-layout.json").write_text(json.dumps(dict(heading=title_bounds,devices=layout),indent=2))
    return backdrop,frame,boxes

def windows(capture, length):
    marks=capture['marks']
    if capture['id']=='08-livestream-tools':
        shots=[m for m in marks if m['name'] in ('web-api','companion-event-mapping')]
        return [(max(.3,m['seconds']-.6),3.6) for m in shots]
    if capture['id']=='03-live-controls':
        marks=[m for m in marks if m['name']!='official-pause']
    if len(marks)<=4:
        return [(max(.2,marks[0]['seconds']-.4),max(marks[-1]['seconds']-marks[0]['seconds']+1,3))]
    # Keep the action leading into each marked result; drop idle automation waits.
    spans=[]
    for mark in marks[1:]:
        end=mark['seconds']+.25
        start=max(.3,end-3.1)
        if spans: start=max(start,sum(spans[-1]))
        if end>start: spans.append((start,end-start))
    if capture['id']=='07-remote-display-control':
        # The second XCTest runner can finish well after its scoring tap.
        # Preserve the actual command, rather than the wait for that runner to exit.
        for touch in capture.get('touches',[]):
            if touch.get('device')=='controller': spans.append((max(.3,touch['seconds']-.7),3.5))
        combined=[]
        for start,duration in sorted(spans):
            if combined and start<=sum(combined[-1]):
                old_start,old_duration=combined[-1]
                combined[-1]=(old_start,max(old_start+old_duration,start+duration)-old_start)
            else: combined.append((start,duration))
        spans=combined
    return spans

def mapped_touches(capture, spans, speed, boxes):
    result=[]
    for touch in capture.get('touches',[]):
        device=touch.get('device','operator')
        panel=1 if device=='audience' else 0
        if panel>=len(boxes) or not (0<=touch['x']<=1 and 0<=touch['y']<=1): continue
        cursor=0
        for start,duration in spans:
            when=touch['seconds']+.15
            if start<=when<start+duration:
                x,y,w,h=boxes[panel]
                result.append(dict(seconds=(cursor+when-start)*speed,
                                   x=round(x+touch['x']*w),y=round(y+touch['y']*h),
                                   device=device,label=touch.get('label','')))
                break
            cursor+=duration
    return result

def main():
    global FONT,BOLD,FONT_INDEX
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=ROOT/'DemoVideo')
    parser.add_argument('--media-root',type=Path,help='Reuse raw recordings, browser captures, and bezels from another output folder.')
    parser.add_argument('--bezel',type=Path,default=Path('/Volumes/Bezel-iPad-Pro-(M5)/PNG/iPad Pro (M5) 11" - Space Black - Landscape.png'))
    parser.add_argument('--only')
    parser.add_argument('--assemble-only',action='store_true',help='Reuse rendered scenes to rebuild the full and short cuts.')
    args=parser.parse_args()
    folder=args.output.resolve(); media=args.media_root.resolve() if args.media_root else folder
    rendered=folder/'edit'; rendered.mkdir(exist_ok=True)
    assets=folder/'graphics'; assets.mkdir(exist_ok=True)
    bezel_copy=assets/'ipad-pro-m5-landscape.png'
    if not bezel_copy.exists(): shutil.copy2(media/'graphics'/bezel_copy.name if args.media_root else args.bezel,bezel_copy)
    tv_copy=assets/'apple-tv-4k.png'
    if not tv_copy.exists(): shutil.copy2(media/'graphics'/tv_copy.name if args.media_root else '/Volumes/Bezel-Apple-TV/PNG/Apple TV - 4K.png',tv_copy)
    pulse=Image.new('RGBA',(72,72)); pd=ImageDraw.Draw(pulse)
    pd.ellipse((5,5,67,67),fill=(71,225,221,35),outline=(9,20,30,200),width=7)
    pd.ellipse((7,7,65,65),outline=(102,255,237,245),width=4)
    pd.ellipse((29,29,43,43),fill=(255,255,255,230))
    pulse_path=assets/'tap-pulse.png'; pulse.save(pulse_path)
    scenes=json.loads((folder/'scenes.json').read_text()); paths=[]; edit_decisions=[]
    if scenes[0].get('locale')=='zh-Hans':
        FONT='/System/Library/Fonts/STHeiti Light.ttc'
        BOLD='/System/Library/Fonts/STHeiti Medium.ttc'
        FONT_INDEX=1
    for scene in scenes:
        if args.only and scene['id']!=args.only: continue
        destination=rendered/f"{scene['id']}.mp4"
        if args.assemble_only:
            if not destination.exists(): raise FileNotFoundError(destination)
            paths.append(destination)
            continue
        if scene['id']=='11-end-card':
            im=Image.new('RGB',(1920,1080),(8,15,28)); d=ImageDraw.Draw(im)
            icon=Image.open(ROOT/'icon.png').convert('RGBA'); icon.thumbnail((240,240))
            im.paste(icon,((1920-icon.width)//2,222),icon)
            for text,y,size,font,color in [(scene.get('end_title','Smart Scoreboard'),530,76,BOLD,'white'),(scene.get('end_tagline','Easy to run. Easy to show.'),648,36,FONT,(142,211,205))]:
                f=typeface(font,size); box=d.textbbox((0,0),text,font=f)
                d.text(((1920-(box[2]-box[0]))//2,y),text,font=f,fill=color)
            end=assets/'end-card.png'; im.save(end)
            run('ffmpeg','-y','-loop','1','-i',end,'-i',folder/scene['audio'],'-t',scene['duration'],
                '-r','30','-c:v','libx264','-preset','fast','-crf','19','-pix_fmt','yuv420p',
                '-c:a','aac','-b:a','192k','-movflags','+faststart',destination)
        else:
            raw=media/'raw'/scene['id']; capture=json.loads((raw/'capture.json').read_text())
            if not capture.get('passed'): raise RuntimeError(f"Scene has not passed capture checks: {scene['id']}")
            bg,frame,boxes=graphic(scene,assets,bezel_copy)
            spans=windows(capture,scene['duration']); total=sum(s[1] for s in spans)
            speed=scene['duration']/total
            # Apply identical cuts to the two independently recorded live devices.
            count=len(boxes); labels=['operator','audience'][:count]
            remote=scene['id']=='07-remote-display-control' and (raw/'controller.mov').exists()
            if remote: labels.append('controller')
            source_count=len(labels)
            command=['ffmpeg','-y','-filter_complex_threads','2','-loop','1','-i',str(bg)]
            for label in labels: command+=['-i',str(raw/f'{label}.mov')]
            command+=['-loop','1','-i',str(frame),'-i',str(folder/scene['audio'])]
            filters=[]
            for i in range(source_count):
                box=boxes[0] if i==2 else boxes[i]
                source=i+1; trims=[]
                # A source must split before it is referenced by multiple trims.
                # Simulator files are variable-frame-rate and can hold a static
                # screen for seconds. Fill those holds before trimming so every
                # device uses the same wall-clock cuts.
                filters.append(f'[{source}:v]tpad=stop_mode=clone:stop_duration={capture["duration"]+2:.3f},fps=30:start_time=0,split={len(spans)}'+''.join(f'[in{i}_{j}]' for j in range(len(spans))))
                for j,(start,dur) in enumerate(spans):
                    name=f'cut{i}_{j}'; trims.append(f'[{name}]')
                    filters.append(f'[in{i}_{j}]trim=start={start:.3f}:duration={dur:.3f},setpts=PTS-STARTPTS[{name}]')
                sx,sy,sw,sh=box
                filters.append(''.join(trims)+f'concat=n={len(spans)}:v=1:a=0,setpts={speed:.6f}*PTS,fps=30,scale={sw}:{sh},setsar=1[v{i}]')
            base='0:v'
            for i,(x,y,_,_) in enumerate(boxes):
                name=f'composite{i}'; filters.append(f'[{base}][v{i}]overlay=x={x}:y={y}:shortest=1[{name}]'); base=name
            filters.append(f'[{base}][{source_count+1}:v]overlay=0:0:shortest=1[framed]')
            touches=mapped_touches(capture,spans,speed,boxes)
            base='framed'
            extra_index=source_count+3
            if remote:
                remote_taps=[t for t in touches if t['device']=='controller']
                if not remote_taps: raise RuntimeError('Remote-control scene has no recorded control tap')
                change=max(0,remote_taps[0]['seconds']-1)
                x,y,_,_=boxes[0]
                filters.append(f'[{base}][v2]overlay=x={x}:y={y}:enable=gte(t\\,{change:.4f}):eof_action=pass[remoteControl]')
                base='remoteControl'
                touches=[t for t in touches if t['device']!='operator' or t['seconds']<change]
            if touches:
                command+=['-loop','1','-i',str(pulse_path)]
                filters.append(f'[{extra_index}:v]split={len(touches)}'+''.join(f'[pulseSource{j}]' for j in range(len(touches))))
                extra_index+=1
                for j,touch in enumerate(touches):
                    when=touch['seconds']
                    filters.append(f'[pulseSource{j}]trim=duration=0.7,setpts=PTS-STARTPTS,fade=t=out:st=0.25:d=0.45:alpha=1,setpts=PTS+{when:.4f}/TB[pulse{j}]')
                    name=f'tapped{j}'
                    filters.append(f'[{base}][pulse{j}]overlay=x={touch["x"]-36}:y={touch["y"]-36}:eof_action=pass:repeatlast=0[{name}]')
                    base=name
            if scene['id']=='08-livestream-tools':
                labels=display_text(scene)
                web=Image.new('RGB',(1920,1080),(8,15,28)); wd=ImageDraw.Draw(web)
                wd.text((70,75),labels['web'],font=typeface(BOLD,54),fill='white')
                for j,(name,label) in enumerate([('scoreboard',labels['scoreboard']),('overlay',labels['overlay'])]):
                    screenshot=Image.open(media/'web'/f'{name}.png').convert('RGB')
                    x=65+j*920
                    wd.text((x+10,235),label,font=typeface(BOLD,22),fill=(123,156,181))
                    if name=='overlay':
                        # The browser source is a transparent 1080p canvas with
                        # its score graphic in the lower-left corner.
                        screenshot=screenshot.crop((30,900,810,1050)).resize((870,167),Image.Resampling.LANCZOS)
                        web.paste(screenshot,(x,320))
                        wd.text((x+10,555),labels['commentator'],font=typeface(BOLD,22),fill=(123,156,181))
                        dashboard=Image.open(media/'web'/'commentator.png').convert('RGB')
                        dashboard.thumbnail((640,360))
                        web.paste(dashboard,(x+115,605))
                    else:
                        screenshot.thumbnail((870,600))
                        web.paste(screenshot,(x,290))
                wd.text((70,1008),labels['web_callout'],font=typeface(FONT,27),fill=(186,203,220))
                web_path=assets/'web-graphics.png'; web.save(web_path)
                # Add the graphic as a final input; audio keeps its existing index.
                command+=['-loop','1','-i',str(web_path)]
                filters.append(f'[{base}][{extra_index}:v]overlay=0:0:enable=between(t\\,5\\,14),format=yuv420p[out]')
            else:
                filters.append(f'[{base}]format=yuv420p[out]')
            command+=['-filter_complex',';'.join(filters),'-map','[out]','-map',f'{source_count+2}:a',
                      '-t',str(scene['duration']),'-r','30','-c:v','libx264','-threads','2','-preset','fast','-crf','19',
                      '-c:a','aac','-b:a','192k','-movflags','+faststart',str(destination)]
            try: run(*command)
            except subprocess.CalledProcessError as error:
                print(error.stderr.decode()[-5000:]); raise
            edit_decisions.append(dict(scene=scene['id'],source_windows=spans,playback_rate=1/speed,touch_highlights=touches,
                                       note='Review edit condenses automation timing; raw device recordings retain real time.'))
        paths.append(destination); print(destination,flush=True)
    if not args.assemble_only:
        decisions_path=rendered/'edit-decisions.json'
        if args.only and decisions_path.exists():
            previous=json.loads(decisions_path.read_text())
            edit_decisions=sorted([d for d in previous if d['scene']!=args.only]+edit_decisions,key=lambda d:d['scene'])
        decisions_path.write_text(json.dumps(edit_decisions,indent=2)+'\n')
    if args.only: return
    listing=rendered/'concat.txt'; listing.write_text(''.join(f"file '{p.name}'\n" for p in paths))
    master=folder/'smart-scoreboard-demo-full.mp4'
    run('ffmpeg','-y','-f','concat','-safe','0','-i',listing,'-c','copy','-movflags','+faststart',master)
    for length in [15,60]:
        run('ffmpeg','-y','-i',master,'-t',length,'-vf',f'fade=t=out:st={length-.5}:d=0.5',
            '-af',f'afade=t=out:st={length-.35}:d=0.35','-c:v','libx264','-preset','fast','-crf','19',
            '-c:a','aac','-b:a','192k','-movflags','+faststart',folder/f'smart-scoreboard-demo-{length}s.mp4')
    validation=[]
    for path in [master,folder/'smart-scoreboard-demo-15s.mp4',folder/'smart-scoreboard-demo-60s.mp4']:
        info=probe(path); validation.append(dict(file=path.name,duration=float(info['format']['duration']),streams=[{k:s.get(k) for k in ['codec_name','codec_type','width','height','sample_rate']} for s in info['streams']]))
    (folder/'media-validation.json').write_text(json.dumps(validation,indent=2)+'\n')
    print(master)

if __name__=='__main__': main()
