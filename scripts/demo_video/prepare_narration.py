#!/usr/bin/env python3
"""Create scene narration, timed masters, subtitles, and an editable scene manifest."""
import argparse
import json
import math
from pathlib import Path
import re
import subprocess
import struct
import wave

ROOT = Path(__file__).resolve().parents[2]
IDS = ['01-result', '02-game-setup', '03-live-controls', '04-audience-views',
       '05-players-and-stations', '06-sports', '07-remote-display-control',
       '08-livestream-tools', '09-appearance-sound', '10-library-logs', '11-end-card']
DURATIONS = [15, 15, 15, 15, 25, 25, 25, 20, 15, 15, 3]
TITLES = ['Run the game. Share the score.', 'Set up your game', 'Every play, under control',
          'Choose the audience view', 'Players and focused control stations', 'More than one sport',
          'Pair displays and control boards', 'Ready for your livestream', 'Make it your event',
          'Save games. Keep the history.', 'Smart Scoreboard']
CALLOUTS = ['Your device controls • The audience screen follows', 'Choose a game • Add teams • Set the clock',
            'Scores • Clocks • Possession • Periods', 'Scoreboard • Players • Teams • Logos',
            'Rosters • Lineups • Fouls • Dedicated stations', 'Sports • Chess • Debate • Custom games',
            'Four-digit pairing • Control access per device', 'Browser graphics • Live scores • Companion events',
            'Themes • Logos • Clock warnings • Sounds', 'Game files • Logs • Backup and restore',
            'Easy to run. Easy to show.']

def run(*args): subprocess.run(list(map(str,args)), check=True, capture_output=True)
def duration(path):
    return float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(path)]))
def stamp(s, sep=','):
    ms=round(s*1000); return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02}{sep}{ms%1000:03}'

def classic_buzzer(folder):
    """Reproduce the app's procedural classic buzzer as a separate edit asset."""
    directory=folder/'sound-effects'; directory.mkdir(exist_ok=True)
    samples=bytearray(); rate=44100
    for index in range(rate*4):
        t=index/rate
        envelope=max(0,min(min(t/.015,1),min((4-t)/.08,1)))
        primary=1 if math.sin(2*math.pi*184*t)>=0 else -1
        octave=1 if math.sin(2*math.pi*184*2*t)>=0 else -1
        pulse=.82+.18*((math.sin(2*math.pi*8*t)+1)/2)
        value=(primary*.86+octave*.14)*.34*envelope*pulse
        samples.extend(struct.pack('<h',int(max(-1,min(1,value))*32767)))
    with wave.open(str(directory/'classic-buzzer.wav'),'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(rate); wav.writeframes(samples)
    (directory/'README.md').write_text('Classic Buzzer: regenerated from the procedural parameters in smartScoreboard/smartScoreboard/BuzzerPlayer.swift, classicBuzzerWaveformData(). 4 seconds, 44.1 kHz, mono, 16-bit PCM. This is an edit asset, not recorded system audio.\n')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=ROOT/'DemoVideo')
    parser.add_argument('--voice',default='Samantha')
    args=parser.parse_args(); folder=args.output.resolve(); audio=folder/'voiceover'; audio.mkdir(parents=True,exist_ok=True)
    classic_buzzer(folder)
    script=(ROOT/'demo_video_script.md').read_text()
    sections=re.split(r'^## (?:Scene \d+ - |Final End Card)',script,flags=re.M)[1:12]
    texts=[]
    for section in sections:
        match=re.search(r'Narration:\s*\n\n> (.*)',section)
        if not match: raise ValueError('Missing narration')
        texts.append(match.group(1))
    scenes=[]; start=0; captions=[]; caption_index=1
    for identifier,length,title,callout,text in zip(IDS,DURATIONS,TITLES,CALLOUTS,texts):
        source=audio/f'{identifier}.txt'; source.write_text(text+'\n')
        aiff=audio/f'{identifier}-source.aiff'; wav=audio/f'{identifier}.wav'
        rate=145
        run('say','-v',args.voice,'-r',rate,'-f',source,'-o',aiff)
        spoken=duration(aiff)
        # Keep each scene within the script's timing while retaining a short lead/tail.
        speed=max(1,spoken/(length-.65))
        run('ffmpeg','-y','-i',aiff,'-af',f'atempo={speed:.5f},loudnorm=I=-16:TP=-1.5:LRA=7,adelay=250|250,apad',
            '-t',length,'-ar',48000,'-ac',1,'-c:a','pcm_s24le',wav)
        # Sentence captions are aligned proportionally to the spoken word durations.
        sentences=re.findall(r'[^.!?]+[.!?]?',text)
        weights=[len(s.split()) for s in sentences]; cursor=start+.25
        effective=spoken/speed
        for sentence,weight in zip(sentences,weights):
            end=cursor+effective*weight/sum(weights)
            captions.append(f'{caption_index}\n{stamp(cursor)} --> {stamp(end)}\n{sentence.strip()}\n')
            caption_index+=1; cursor=end
        scenes.append(dict(id=identifier,start=start,duration=length,title=title,callout=callout,
                           narration=text,voice=args.voice,spoken_seconds=spoken/speed,
                           speech_tempo_adjustment=speed,audio=str(wav.relative_to(folder))))
        start+=length
    (folder/'scenes.json').write_text(json.dumps(scenes,indent=2)+'\n')
    (audio/'narration.srt').write_text('\n'.join(captions))
    (audio/'narration.vtt').write_text('WEBVTT\n\n'+re.sub(r'(\d\d:\d\d:\d\d),(\d{3})',r'\1.\2','\n'.join(captions)))
    (audio/'narration-transcript.txt').write_text('\n\n'.join(s['narration'] for s in scenes)+'\n')
    listing=audio/'concat.txt'; listing.write_text(''.join(f"file '{s['id']}.wav'\n" for s in scenes))
    run('ffmpeg','-y','-f','concat','-safe',0,'-i',listing,'-c:a','pcm_s24le',audio/'full-voiceover.wav')
    for seconds in [15,60]: run('ffmpeg','-y','-i',audio/'full-voiceover.wav','-t',seconds,'-c:a','pcm_s24le',audio/f'{seconds}s-voiceover.wav')
    run('ffmpeg','-y','-i',audio/'full-voiceover.wav','-c:a','libmp3lame','-b:a','192k',audio/'full-voiceover.mp3')
    print(f'{len(scenes)} scenes; {start} seconds; voice={args.voice}; audio={audio}')

if __name__=='__main__': main()
