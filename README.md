## yukkuri-blank

Small scripts to automate TTS & subtitle generation for video creation.

https://github.com/user-attachments/assets/540b4ffe-b7da-4cf7-bbea-88dea2956387

### `tts.rb`

Takes an input text file and prompts user to select lines to TTS.
Outputs TTS `.wav` files to specified/default output directory.

Requires a [Voicevox Engine](https://github.com/VOICEVOX/voicevox_engine) server set-up and [skim](https://github.com/skim-rs/skim) installed.

```
Usage: ./tts.rb [options] FILE
    -o, --output DIR                 Specify output directory for synthesized audio [default: ./wavs]
    -a, --all                        Generate TTS for every line in file
```

### `webm.rb`

Takes an input text file and prompts user to select lines to process.
Creates transparent `.webm`s with styled subtitles, timed to the length of corresponding TTS.

Requires [ffmpeg](https://github.com/ffmpeg/ffmpeg) and optionally the [Akazukin Pop](https://flopdesign.booth.pm/items/1748058) font.

```
Usage: ./webm.rb [options] FILE
    -i, --input DIR                  Specify output directory for synthesized audio [default: ./wavs]
    -o, --output DIR                 Specify output directory for synthesized audio [default: ./webms]
    -a, --all                        Generate WebM for every line in file
```
