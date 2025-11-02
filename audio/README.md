# Audio Tools

Collection of audio processing utility scripts.

## Scripts

### split_cue.sh
Splits FLAC/APE/WavPack audio files into individual tracks using CUE sheets.

**Features:**
- Supports FLAC, APE, and WavPack formats
- Handles both external CUE files and embedded cue sheets
- Maintains original audio quality (lossless)
- Automatically converts APE/WV to FLAC during processing
- Handles character encoding issues in CUE files
- Recursively processes directories
- Preserves album metadata (artist, title, date)
- Moves original files to `_original/` subdirectory

**Usage:**
```bash
# Process current directory
./split_cue.sh

# Process specific directory
./split_cue.sh /path/to/music/folder
```

**Dependencies:**
Install required tools on macOS:
```bash
brew install flac shntool cuetools mac wavpack ffmpeg
```

On Linux (Debian/Ubuntu):
```bash
sudo apt install flac shntool cuetools monkeys-audio wavpack ffmpeg
```

**Output:**
- Creates individual FLAC files named: `01 - Track Title.flac`
- Preserves metadata (artist, album, track number, etc.)
- Moves original files to `_original/` subdirectory

**How it works:**
1. Scans for CUE files in the directory
2. Finds matching audio files (FLAC/APE/WV)
3. Converts APE/WV to FLAC if needed
4. Splits using either shnsplit or ffmpeg
5. Applies proper metadata to each track
6. Archives original files to `_original/` folder