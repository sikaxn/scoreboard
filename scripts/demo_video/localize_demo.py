#!/usr/bin/env python3
"""Create the Simplified Chinese demo without duplicating the original captures."""
import argparse
import html
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import zipfile
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent

def run(*args):
    try: return subprocess.run(list(map(str,args)),check=True,capture_output=True)
    except subprocess.CalledProcessError as error:
        print(error.stderr.decode()[-5000:]);raise

def duration(path):
    return float(run('ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',path).stdout)

def stamp(seconds,separator=','):
    ms=round(seconds*1000)
    return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02}{separator}{ms%1000:03}'

def caption_parts(sentence):
    # Keep subtitles within two short lines, even for longer Chinese sentences.
    clauses=re.findall(r'[^，：；]+[，：；]?',sentence)
    parts=[];pending=''
    for clause in clauses:
        if len(pending+clause)>36 and pending:parts.append(pending);pending=''
        pending+=clause
    if pending:parts.append(pending)
    return parts

def wrap_caption(text):
    lines=[];line='';width=0
    for token in re.findall(r'[A-Za-z0-9]+|.',text):
        step=sum(2 if ord(char)>255 else 1 for char in token)
        if line and width+step>42 and token not in '，。！？；：、）》…':
            lines.append(line);line='';width=0
        line+=token;width+=step
    if line:lines.append(line)
    return '\n'.join(lines)

def prepare(source,folder,voice,native_ui=False):
    config=json.loads((HERE/'zh-Hans.json').read_text())
    originals=json.loads((source/'scenes.json').read_text())
    assert [s['id'] for s in originals]==[s['id'] for s in config['scenes']]
    audio=folder/'voiceover';audio.mkdir(parents=True,exist_ok=True)
    scenes=[];captions=[];transcript=[];script=[f"# {config['app_name']}：简体中文演示视频脚本\n",
        '总时长 3 分 08 秒；前 15 秒和前 60 秒均可独立使用。\n',
        '中文标题、设备标签、配音和字幕沿用已通过检查的实机应用模拟器录像。应用界面和浏览器页面保留原录像中的英文。观众端使用 Apple TV，点击位置以青色圆环高亮。\n']
    if native_ui:
        script[-1]='iPadOS 和 tvOS 使用简体中文重新录制，赛事、队伍、球员与浏览器画面使用中文。观众端使用 Apple TV，点击位置以青色圆环高亮。\n'
    with tempfile.TemporaryDirectory(prefix='scoreboard-zh-narration-') as temporary:
        temp=Path(temporary)
        for original,translation in zip(originals,config['scenes']):
            scene=dict(original);scene.update(translation);scene.update(locale='zh-Hans',voice=voice)
            identifier=scene['id'];text=scene['narration'];length=scene['duration']
            sentences=re.findall(r'[^。！？]+[。！？]?',text)
            pieces=[];times=[]
            for index,sentence in enumerate(sentences):
                part=temp/f'{identifier}-{index}.aiff'
                run('say','-v',voice,'-r',165,'-o',part,sentence)
                pieces.append(part);times.append(duration(part))
            listing=temp/f'{identifier}.txt';listing.write_text(''.join(f"file '{p}'\n" for p in pieces))
            spoken=sum(times);tempo=max(1,spoken/(length-.65))
            if tempo>1.35:raise ValueError(f'Chinese narration needs shortening: {identifier} ({spoken:.1f}s)')
            wav=audio/f'{identifier}.wav'
            run('ffmpeg','-y','-f','concat','-safe',0,'-i',listing,'-af',
                f'atempo={tempo:.6f},loudnorm=I=-16:TP=-1.5:LRA=7,adelay=250,apad',
                '-t',length,'-ar',48000,'-ac',1,'-c:a','pcm_s24le',wav)
            (audio/f'{identifier}.txt').write_text(text+'\n')
            cursor=scene['start']+.25
            for sentence,seconds in zip(sentences,times):
                parts=caption_parts(sentence)
                for part in parts:
                    end=cursor+(seconds/tempo)*len(part)/len(sentence)
                    captions.append((cursor,end,wrap_caption(part)));cursor=end
            scene.update(spoken_seconds=spoken/tempo,speech_tempo_adjustment=tempo,audio=f'voiceover/{identifier}.wav')
            if identifier=='11-end-card':scene.update(end_title=config['app_name'],end_tagline=scene['callout'])
            scenes.append(scene);transcript.append(text)
            script.extend([f"## {int(identifier[:2]):02} · {scene['title']}\n",
                f"时间：{stamp(scene['start'])[:-4]}—{stamp(scene['start']+length)[:-4]}\n",
                f"画面：{scene['shots']}\n",f"配音：\n\n> {text}\n",f"屏幕文字：{scene['callout']}\n"])
            print(f'NARRATION {identifier}: {spoken/tempo:.2f}s / {length}s; tempo {tempo:.3f}',flush=True)
        listing=temp/'master.txt';listing.write_text(''.join(f"file '{audio/s['id']}.wav'\n" for s in scenes))
        run('ffmpeg','-y','-f','concat','-safe',0,'-i',listing,'-c:a','pcm_s24le',audio/'full-voiceover.wav')
    for length in [15,60]:
        run('ffmpeg','-y','-i',audio/'full-voiceover.wav','-t',length,'-c:a','pcm_s24le',audio/f'{length}s-voiceover.wav')
    run('ffmpeg','-y','-i',audio/'full-voiceover.wav','-c:a','libmp3lame','-b:a','192k',audio/'full-voiceover.mp3')
    (audio/'narration.srt').write_text('\n\n'.join(f'{i}\n{stamp(a)} --> {stamp(b)}\n{text}' for i,(a,b,text) in enumerate(captions,1))+'\n')
    (audio/'narration.vtt').write_text('WEBVTT\n\n'+'\n\n'.join(f'{stamp(a,".")} --> {stamp(b,".")}\n{text}' for a,b,text in captions)+'\n')
    (audio/'narration-transcript.txt').write_text('\n\n'.join(transcript)+'\n')
    (folder/'scenes.json').write_text(json.dumps(scenes,ensure_ascii=False,indent=2)+'\n')
    (folder/'demo_video_script.zh-Hans.md').write_text('\n'.join(script))

def package(source,folder,voice,native_ui=False):
    scenes=json.loads((folder/'scenes.json').read_text());cards=[]
    contact=Image.new('RGB',(1600,2500),(8,15,28));draw=ImageDraw.Draw(contact)
    font=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',25,index=1)
    for i,scene in enumerate(scenes[:10]):
        thumbnail=folder/'graphics'/f"{scene['id']}-thumbnail.jpg"
        run('ffmpeg','-y','-ss',4,'-i',folder/'edit'/f"{scene['id']}.mp4",'-frames:v',1,'-q:v',3,thumbnail)
        image=Image.open(thumbnail);image.thumbnail((780,438));x=i%2*800+10;y=i//2*500+10
        contact.paste(image,(x,y+42));draw.text((x+7,y+5),f"{i+1:02}  {scene['title']}",font=font,fill='white')
        cards.append(f'<article><h2>{i+1:02} · {html.escape(scene["title"])}</h2><a href="edit/{scene["id"]}.mp4"><img src="graphics/{thumbnail.name}" alt="{html.escape(scene["title"])}"></a><p>{html.escape(scene["narration"])}</p><a href="voiceover/{scene["id"]}.wav">分段配音 WAV</a></article>')
    contact.save(folder/'contact-sheet.jpg',quality=90)
    readme=f'''# 聪明的计分板：简体中文演示视频

打开 `index.html` 预览。完整版 3:08，另有 15 秒和 60 秒短版，均为 1920×1080、30 帧/秒。

标题、设备标签、结束画面、配音、脚本与字幕已翻译为简体中文。应用界面和浏览器页面沿用原版英文录像。保留 Apple TV 观众屏幕、设备边框与实际点击位置高亮。

普通话配音由 macOS {voice} 语音合成。`voiceover/` 提供各场景及完整的 48 kHz、24 位 WAV、完整 MP3、短版配音、字幕和文稿。字幕按每句话的合成音频时长对齐；长句分段时间为估算值。字幕以 SRT/VTT 单独提供。

`edit/` 保存分段视频和剪辑、点击时间；`graphics/` 保存中文标题画面与设备边框；`demo_video_script.zh-Hans.md` 为中文脚本；`media-validation.json` 记录输出格式。

本版复用上一级 `raw/` 中已通过检查的十个场景，不重复存储原始录像。原始测试证据位于上一级 `evidence/`。中文素材 ZIP 包含本目录的成片、分段视频、配音与图形素材。

在仓库根目录重新生成：`python3 scripts/demo_video/localize_demo.py`。
'''
    if native_ui:
        readme=readme.replace('标题、设备标签、结束画面、配音、脚本与字幕已翻译为简体中文。应用界面和浏览器页面沿用原版英文录像。保留 Apple TV 观众屏幕、设备边框与实际点击位置高亮。',
            '本版在系统和应用语言设为简体中文的 iPadOS 和 tvOS 模拟器中重新录制，使用中文赛事、队伍和球员示例。浏览器按中文语言偏好加载，保留 Apple TV 观众屏幕、设备边框与实际点击高亮。录制副本使用指定中文名称“聪明的计分板”，并补充了配对页面的中文文案；产品源码未修改。')
        readme=readme.replace('本版复用上一级 `raw/` 中已通过检查的十个场景，不重复存储原始录像。原始测试证据位于上一级 `evidence/`。中文素材 ZIP 包含本目录的成片、分段视频、配音与图形素材。',
            '中文原始录像和截图位于 `raw/`，测试证据位于 `evidence/`。中文素材 ZIP 包含成片、原始素材、分段视频、配音、图形素材和测试日志。Xcode 结果包单独保留在本地 `evidence/`。此前的中文配音版本保留在上一级 `zh-Hans/`，未覆盖。')
        readme=readme.replace('`python3 scripts/demo_video/localize_demo.py`',
            '`python3 scripts/record_demo_video.py --language zh-Hans --output DemoVideo/zh-Hans-ios`；再使用本目录的分段配音和 `scripts/demo_video/render_demo.py` 渲染。')
    (folder/'README.md').write_text(readme)
    index='''<!doctype html><html lang="zh-Hans"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>聪明的计分板 · 中文演示视频</title>
<style>body{margin:0;background:#080f1c;color:#e6eef7;font:17px system-ui;line-height:1.65}main{max-width:1400px;margin:auto;padding:42px}h1{font-size:42px}h2{font-size:24px}a{color:#74dccc}video,img{width:100%;border-radius:14px}nav{display:flex;flex-wrap:wrap;gap:24px;margin:24px 0}.grid{display:grid;grid-template-columns:1fr 1fr;gap:32px}article{padding:22px;background:#111e30;border-radius:18px}p{color:#bccbdc}@media(max-width:850px){.grid{grid-template-columns:1fr}}</style>
<main><h1>聪明的计分板</h1><p>简体中文标题与普通话配音 · Apple TV 观众屏幕 · 点击高亮 · 应用画面保留英文</p><video controls preload="metadata" src="smart-scoreboard-demo-full.mp4"><track kind="subtitles" srclang="zh" label="简体中文" src="voiceover/narration.vtt"></video>
<nav><a href="smart-scoreboard-demo-15s.mp4">15 秒短版</a><a href="smart-scoreboard-demo-60s.mp4">60 秒短版</a><a href="voiceover/full-voiceover.wav">完整配音 WAV</a><a href="voiceover/narration.srt">中文字幕</a><a href="contact-sheet.jpg">分镜总览</a><a href="demo_video_script.zh-Hans.md">中文脚本</a></nav><div class="grid">'''+''.join(cards)+'</div></main></html>'
    if native_ui:
        index=index.replace('简体中文标题与普通话配音 · Apple TV 观众屏幕 · 点击高亮 · 应用画面保留英文','简体中文 iPadOS 与 tvOS 重新录制 · 普通话配音 · Apple TV 观众屏幕 · 点击高亮')
        index=index.replace('聪明的计分板 · 中文演示视频','聪明的计分板 · 中文界面实录')
    (folder/'index.html').write_text(index)
    (folder/'asset-manifest.json').write_text(json.dumps(dict(locale='zh-Hans',app_name='聪明的计分板',voice=f'macOS {voice} (synthetic Mandarin)',
        source_media='raw/' if native_ui else '../raw/',source_evidence='evidence/' if native_ui else '../evidence/',source_capture_results=json.loads((source/'evidence/capture-results.json').read_text()),
        app_interface_language='Simplified Chinese (new iPadOS and tvOS recordings)' if native_ui else 'English (original footage)',scenes=[s['id'] for s in scenes]),ensure_ascii=False,indent=2)+'\n')
    for p in [folder/'edit/concat.txt']:
        if p.exists():p.unlink()
    archive=folder/('congming-de-jifenban-zh-Hans-ios-assets.zip' if native_ui else 'congming-de-jifenban-zh-Hans-assets.zip')
    temporary=archive.with_suffix('.zip.tmp')
    with zipfile.ZipFile(temporary,'w',compression=zipfile.ZIP_STORED) as bundle:
        excluded={'source','DerivedData','DerivedDataTV','evidence'}
        for p in sorted(folder.rglob('*')):
            relative=p.relative_to(folder)
            evidence_file=native_ui and relative.parts[0]=='evidence' and not any(part.endswith('.xcresult') for part in relative.parts) and p.suffix in {'.json','.md','.log'}
            asset_file=relative.parts[0] not in excluded and not relative.parts[0].endswith('.xcresult') and p.suffix!='.log'
            if p.is_file() and (asset_file or evidence_file) and p not in (archive,temporary) and p.name!='.DS_Store':
                bundle.write(p,('聪明的计分板-中文界面实录/' if native_ui else '聪明的计分板-简体中文/')+str(relative))
    with zipfile.ZipFile(temporary) as bundle:assert bundle.testzip() is None
    temporary.replace(archive)
    parent_index=source/'index.html'
    if parent_index.exists():
        contents=parent_index.read_text()
        if 'href="zh-Hans/index.html"' not in contents and folder==source/'zh-Hans':
            parent_index.write_text(contents.replace('</nav>','<a href="zh-Hans/index.html" lang="zh-Hans">简体中文 · 聪明的计分板</a></nav>'))
    print(folder/'index.html',flush=True)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=ROOT/'DemoVideo')
    parser.add_argument('--output',type=Path,default=ROOT/'DemoVideo/zh-Hans')
    parser.add_argument('--voice',default='Tingting')
    parser.add_argument('--prepare-only',action='store_true')
    parser.add_argument('--package-only',action='store_true')
    parser.add_argument('--native-ui',action='store_true',help='Package newly captured Chinese app interfaces.')
    args=parser.parse_args();source=args.source.resolve();folder=args.output.resolve();folder.mkdir(parents=True,exist_ok=True)
    if not args.package_only:
        prepare(source,folder,args.voice,args.native_ui)
        if args.prepare_only:return
        subprocess.run([sys.executable,str(HERE/'render_demo.py'),'--output',str(folder),'--media-root',str(source)],check=True)
    package(source,folder,args.voice,args.native_ui)

if __name__=='__main__':main()
