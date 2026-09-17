## yukkuri-blank

Small scripts to automate TTS & subtitle generation for video creation.

https://github.com/user-attachments/assets/a821acb3-ee28-4f8b-81b8-50e1924d473a

---

### `yukkuri-tts.rb`

Takes an input text file and prompts user to select lines to TTS.

Outputs TTS `.wav` files to specified/default output directory.

Requires a [Voicevox Engine](https://github.com/VOICEVOX/voicevox_engine) server with a configured preset and [skim](https://github.com/skim-rs/skim) installed.

```
Usage: ./yukkuri-tts.rb [options] FILE
    -a, --all                        Generate TTS for every line in file
```

---

### `yukkuri-webm.rb`

Takes an input text file and prompts user to select lines to process.

Outputs transparent `.webm`s with styled subtitles, timed to the length of corresponding TTS.

Requires [skim](https://github.com/skim-rs/skim), [ffmpeg](https://github.com/ffmpeg/ffmpeg), [budoux](https://github.com/google/budoux) and optionally the [Akazukin Pop](https://flopdesign.booth.pm/items/1748058) font.

```
Usage: ./yukkuri-webm.rb [options] FILE
    -a, --all                        Generate WebM for every line in file
    -n, --max-line-length LENGTH     Override maximum line length
```
