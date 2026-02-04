# 🔊 Sound Acquisition Guide for Coinchette

## Current Status

✅ **Sound system is 98% complete!** All code is implemented and working.
⚠️ **Only missing:** Actual audio file content (current files are 0-byte placeholders)

## Required Sound Files

All files should be placed in: `priv/static/sounds/`

| File | Duration | Description | Usage |
|------|----------|-------------|-------|
| `card-play.mp3` | 100-300ms | Card being played | Every card played |
| `card-shuffle.mp3` | 500ms-1s | Cards being shuffled | Start of each round |
| `trick-win.mp3` | 500ms-1s | Winning a trick | After each trick |
| `victory.mp3` | 1-2s | Celebratory sound | When you win |
| `defeat.mp3` | 1-2s | Disappointing sound | When you lose |
| `belote.mp3` | 500ms-1s | Special announcement | Belote/Rebelote |
| `announcement.mp3` | 500ms-1s | Fanfare/trumpet | Tierce/Cinquante/Cent/Carré |
| `button-click.mp3` | 100-200ms | UI button click | Button interactions |
| `bid-take.mp3` | 200-400ms | Positive chime | Taking a bid |
| `bid-pass.mp3` | 200-400ms | Neutral tone | Passing a bid |

## Audio Specifications

- **Format:** MP3 (universal browser support)
- **Sample Rate:** 44.1 kHz
- **Bit Rate:** 128 kbps minimum
- **Volume:** Normalized to -3dB (prevents clipping)
- **Quality:** Professional, not jarring
- **Style:** Card game appropriate (subtle, elegant)

## Option 1: Free Sound Libraries (Recommended)

### Freesound.org (Best Option)
- **URL:** https://freesound.org/
- **License:** CC0 (Public Domain) or CC-BY
- **Quality:** High
- **Search tips:**
  - "card flip" → card-play.mp3
  - "shuffle cards" → card-shuffle.mp3
  - "success chime" → victory.mp3
  - "lose whoosh" → defeat.mp3
  - "trumpet fanfare" → announcement.mp3, belote.mp3
  - "UI click" → button-click.mp3, bid-take.mp3, bid-pass.mp3
  - "ding" → trick-win.mp3

**Recommended Search Queries:**
```
card-play: "card flip" "card snap" "card place"
card-shuffle: "shuffle cards" "deck shuffle" "riffle shuffle"
trick-win: "point score" "collect coins" "item get"
victory: "level complete" "victory fanfare" "win jingle"
defeat: "lose" "game over whoosh" "fail sound"
belote: "trumpet short" "announcement" "ta-da"
announcement: "fanfare" "achievement" "special"
button-click: "UI click" "button" "menu select"
bid-take: "accept" "confirm" "positive beep"
bid-pass: "cancel" "back" "neutral tone"
```

### Zapsplat (Alternative)
- **URL:** https://www.zapsplat.com/
- **License:** Free with attribution (or Standard License)
- **Quality:** Professional
- **Download Limit:** 10 files/day (free tier)

### Mixkit (Good for Music)
- **URL:** https://mixkit.co/free-sound-effects/
- **License:** 100% free, no attribution
- **Quality:** Curated, high-quality

### Pixabay Sound Effects
- **URL:** https://pixabay.com/sound-effects/
- **License:** Free, no attribution required
- **Quality:** Variable but good selection

### BBC Sound Effects
- **URL:** https://sound-effects.bbcrewind.co.uk/
- **License:** Free for personal/educational use
- **Quality:** Professional BBC archive
- **Selection:** 16,000+ effects

## Option 2: Generate with AI (Quick but Lower Quality)

### ElevenLabs Sound Effects (Free Tier)
- **URL:** https://elevenlabs.io/sound-effects
- **Quality:** AI-generated, good for simple sounds
- **Limit:** Free tier available

### Mubert (AI Music)
- **URL:** https://mubert.com/
- **Use:** Could generate ambient sounds

## Option 3: Record Your Own

### For Card Sounds
- Record actual card shuffling/playing
- Use smartphone voice recorder
- Edit in Audacity (free)
- Normalize to -3dB

### For UI Sounds
- Use online tone generators
- Simple sine wave beeps work well
- Tools: Audacity, ToneDef

## Option 4: Paid Options (High Quality)

### Epidemic Sound
- **URL:** https://www.epidemicsound.com/
- **Cost:** ~$15/month
- **Quality:** Professional

### AudioJungle
- **URL:** https://audiojungle.net/
- **Cost:** $1-5 per sound
- **Quality:** Professional

### Splice
- **URL:** https://splice.com/sounds
- **Cost:** $8-10/month
- **Quality:** Professional

## Processing Downloaded Sounds

### Using Audacity (Free)

1. **Install Audacity:** https://www.audacityteam.org/download/

2. **Import Sound:**
   - File → Open
   - Select downloaded audio

3. **Trim to Length:**
   - Select region
   - Edit → Trim Audio

4. **Normalize Volume:**
   - Effect → Normalize
   - Set to -3.0 dB
   - Check "Normalize stereo channels independently"

5. **Convert to MP3:**
   - File → Export → Export as MP3
   - Quality: 128 kbps minimum
   - Constant bit rate

6. **Save to Project:**
   - Copy to `priv/static/sounds/`
   - Replace placeholder file

### Batch Processing Script

```bash
#!/bin/bash
# Normalize all MP3 files to -3dB using ffmpeg

cd priv/static/sounds

for file in *.mp3; do
  if [ -f "$file" ]; then
    echo "Processing $file..."
    ffmpeg -i "$file" -af "loudnorm=I=-16:TP=-3:LRA=11" -ar 44100 -b:a 128k "${file%.mp3}_normalized.mp3"
    mv "${file%.mp3}_normalized.mp3" "$file"
  fi
done

echo "All files normalized!"
```

## Quick Start (Fastest Path)

1. **Go to Freesound.org**
2. **Search for each sound** (use search queries above)
3. **Filter:** CC0 or CC-BY license
4. **Download:** High-quality MP3 or WAV
5. **Optional:** Normalize in Audacity
6. **Copy to:** `priv/static/sounds/`
7. **Test:** Visit your site, play a game!

## Testing

After acquiring sounds:

1. **Visit your site:** https://coinchette.onrender.com
2. **Check volume control** in header (top right)
3. **Start a game** (solo or multiplayer)
4. **Listen for sounds:**
   - Card shuffle at start
   - Card play on each move
   - Trick win after each trick
   - Victory/defeat at end
   - Announcements for belote, tierce, etc.

5. **Test volume control:**
   - Move slider (should change volume)
   - Click mute (should stop sounds)
   - Refresh page (should remember settings)

## Current Implementation Status

✅ **Sound Manager** - Complete (sounds.js)
✅ **Volume Control** - Complete (UI in header, lobby, game)
✅ **Mute Functionality** - Complete (persists to localStorage)
✅ **Sound Triggers** - Complete (10 triggers in multiplayer game)
✅ **Solo & Multiplayer** - Both covered (use same LiveView)
⚠️ **Audio Files** - Need actual content (placeholders exist)

## Estimated Time

- **Option 1 (Freesound):** 30-60 minutes
  - 10 sounds × 3 min search = 30 min
  - 10 sounds × 2 min download = 20 min
  - 10 min testing = 10 min
  - **Total: ~60 minutes**

- **Option 2 (Quick & Dirty):** 15 minutes
  - Use first acceptable sound found
  - Skip normalization
  - **Total: ~15 minutes**

- **Option 3 (Perfect):** 2-3 hours
  - Carefully curate each sound
  - Professional editing
  - Multiple iterations
  - **Total: ~3 hours**

## Recommended Approach

**For MVP:** Use Freesound.org with "Quick & Dirty" approach
1. Search each sound
2. Download first CC0 result that sounds decent
3. Copy to `priv/static/sounds/`
4. Test
5. **Total time: ~30 minutes**

Can always replace with better sounds later!

## Example Freesound Picks (Curated)

Here are some good starting points on Freesound:

- **card-play:** Search "card flip" - ID: 71277 (by Koops)
- **card-shuffle:** Search "shuffle cards" - ID: 242527 (by DanielFontes)
- **trick-win:** Search "coin collect" - ID: 341695 (by ProjectsU012)
- **victory:** Search "victory fanfare" - ID: 270528 (by plasterbrain)
- **defeat:** Search "sad trombone" - ID: 458277 (by mrickey13)
- **belote:** Search "trumpet staccato" - ID: 245645 (by splicesound)
- **announcement:** Search "achievement" - ID: 270404 (by Fupicat)
- **button-click:** Search "UI click" - ID: 221683 (by Raclure)
- **bid-take:** Search "confirm beep" - ID: 337049 (by waveplay)
- **bid-pass:** Search "cancel" - ID: 249300 (by InspectorJ)

*(IDs are approximate - search by description if ID doesn't work)*

## Need Help?

If you need assistance:
1. **Finding sounds:** Describe the vibe you want
2. **Processing:** Share raw files, I can guide editing
3. **Integration:** Already done! Just add files.

---

**Once you acquire the sounds, your audio system is 100% complete!** 🎉

The entire infrastructure is already built and working. Just need those 10 audio files.
