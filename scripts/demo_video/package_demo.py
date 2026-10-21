#!/usr/bin/env python3
"""Create a browsable index, coverage manifest, and contact sheet for the demo assets."""
import argparse
import html
import json
from pathlib import Path
import shutil
import subprocess
import zipfile
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=ROOT/'DemoVideo')
    parser.add_argument('--archive',action='store_true',help='Also package the delivery assets, excluding build caches.')
    args=parser.parse_args()
    folder=args.output.resolve(); scenes=json.loads((folder/'scenes.json').read_text())
    shutil.copy2(ROOT/'demo_video_script.md',folder/'demo_video_script.md')
    captures=[]; cards=[]; rows=[]
    contact=Image.new('RGB',(1600,5*500),(8,15,28)); draw=ImageDraw.Draw(contact)
    font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf',25)
    for index,scene in enumerate(scenes[:10]):
        directory=folder/'raw'/scene['id']; data=json.loads((directory/'capture.json').read_text())
        if not data.get('passed'): raise RuntimeError('Incomplete capture: '+scene['id'])
        montage=folder/'edit'/f"{scene['id']}.mp4"
        thumb=folder/'graphics'/f"{scene['id']}-thumbnail.jpg"
        subprocess.run(['ffmpeg','-y','-ss',str(min(4,scene['duration']/2)),'-i',str(montage),'-frames:v','1','-q:v','3',str(thumb)],check=True,capture_output=True)
        im=Image.open(thumb); im.thumbnail((780,438))
        x=(index%2)*800+10; y=(index//2)*500+10
        contact.paste(im,(x,y+42)); draw.text((x+7,y+5),f"{index+1:02}  {scene['title']}",font=font,fill='white')
        video_count=len(list(directory.glob('*.mov'))); still_count=len(list(directory.glob('*.png')))
        captures.append(dict(scene=scene['id'],passed=True,duration=data['duration'],marks=data['marks'],
                             receiver=data.get('receiver'),xctest_result=data.get('xctest_result'),
                             result_bundle=data.get('result_bundle'),original_video_files=video_count,stills=still_count))
        title=html.escape(scene['title']); relative=str(thumb.relative_to(folder))
        cards.append(f'<article><h2>{index+1:02} · {title}</h2><a href="edit/{scene["id"]}.mp4"><img src="{relative}" alt="{title}"></a><p><a href="raw/{scene["id"]}/">Raw device recordings and stills</a> · <a href="voiceover/{scene["id"]}.wav">Voiceover WAV</a></p><p>{html.escape(scene["narration"])}</p></article>')
        rows.append(f'| {index+1:02} | {scene["title"]} | {video_count} | {still_count} | Passed |')
    contact.save(folder/'contact-sheet.jpg',quality=90)
    provenance=dict(commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                    source='Current working tree, including pre-existing uncommitted changes',
                    source_changes=subprocess.check_output(['git','status','--short'],cwd=ROOT,text=True).splitlines(),
                    script='demo_video_script.md',voice='macOS say / Samantha (synthetic)',
                    scenes=captures,total_original_videos=sum(c['original_video_files'] for c in captures),
                    total_stills=sum(c['stills'] for c in captures))
    (folder/'asset-manifest.json').write_text(json.dumps(provenance,indent=2)+'\n')
    (folder/'README.md').write_text('''# Smart Scoreboard demo assets

Open `index.html` for the preview gallery. The full review edit is 3:08, with
standalone 15-second and 60-second cuts. All edits are 1920×1080 at 30 fps.

Voiceover: locally synthesized English, Samantha. Scene WAVs are 48 kHz/24-bit;
full WAV/MP3 and short narration cuts are in `voiceover/`. The narration matches
the updated `demo_video_script.md`. Subtitles use estimated sentence timing.

Raw operator and audience recordings are in `raw/`; these preserve real time.
The review edit removes automation waits and adds cyan pulses at recorded tap positions. `edit/edit-decisions.json` records the
cuts. The opening verifies an actual score change on a second paired simulator.
Game and roster identities are fictional demo fixtures. Simulator footage has
no captured app audio, and no backing music is included. A separate Classic Buzzer
WAV, regenerated from the app's procedural sound parameters, is in `sound-effects/`.

An operator iPad, an audience Apple TV, and a remote-control iPad simulator are used. The second iPad receives control permission. Physical TV/AirPlay output, Apple TV hardware, and owner-offline host
handoff are not covered by these captures. Bezels are from your downloaded Apple
device artwork. Production app sources were not changed for recording.

| Scene | Content | Raw videos | Stills | XCTest |
| --- | --- | --- | --- | --- |
'''+ '\n'.join(rows)+'\n\nSee `asset-manifest.json`, `media-validation.json`, and the Xcode result bundles for evidence.\n')
    (folder/'index.html').write_text('''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Smart Scoreboard · Demo assets</title>
<style>body{margin:0;background:#080f1c;color:#e6eef7;font:17px system-ui;line-height:1.55}main{max-width:1400px;margin:auto;padding:42px}h1{font-size:42px}h2{font-size:23px}a{color:#74dccc}video,img{width:100%;border-radius:14px}nav{display:flex;gap:24px;margin:24px 0}.grid{display:grid;grid-template-columns:1fr 1fr;gap:32px}article{padding:22px;background:#111e30;border-radius:18px}p{color:#bccbdc}@media(max-width:850px){.grid{grid-template-columns:1fr}}</style>
<main><h1>Smart Scoreboard</h1><p>Current-app simulator footage · 10 scenes · synthesized English voiceover</p><video controls preload="metadata" src="smart-scoreboard-demo-full.mp4"></video>
<nav><a href="smart-scoreboard-demo-15s.mp4">15-second cut</a><a href="smart-scoreboard-demo-60s.mp4">60-second cut</a><a href="voiceover/full-voiceover.wav">Full voiceover WAV</a><a href="voiceover/narration.srt">Subtitles</a><a href="sound-effects/classic-buzzer.wav">Buzzer WAV</a><a href="contact-sheet.jpg">Contact sheet</a><a href="demo_video_script.md">Updated script</a></nav>
<div class="grid">'''+''.join(cards)+'</div></main>')
    print(json.dumps({k:provenance[k] for k in ['total_original_videos','total_stills']},indent=2))
    print(folder/'index.html')
    if args.archive:
        archive=folder/'smart-scoreboard-demo-assets.zip'
        roots=['index.html','README.md','demo_video_script.md','asset-manifest.json',
               'media-validation.json','scenes.json','contact-sheet.jpg','raw','edit',
               'graphics','voiceover','web','sound-effects',
               'smart-scoreboard-demo-full.mp4','smart-scoreboard-demo-15s.mp4','smart-scoreboard-demo-60s.mp4']
        with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_STORED,allowZip64=True) as bundle:
            for name in roots:
                path=folder/name
                files=sorted(path.rglob('*')) if path.is_dir() else [path]
                for file in files:
                    if file.is_file(): bundle.write(file,'Smart Scoreboard Demo/'+str(file.relative_to(folder)))
        print(archive)

if __name__=='__main__':main()
