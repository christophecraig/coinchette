# 🔊 Game Sound Effects

This directory contains all sound effects for Coinchette.

## Required Sound Files

The game expects the following sound files to be present:

| File | Event | Description |
|------|-------|-------------|
| `card-play.mp3` | Playing a card | Short, crisp card snap sound |
| `card-shuffle.mp3` | Dealing cards | Shuffling/dealing sound effect |
| `trick-win.mp3` | Winning a trick | Satisfying "ding" or chime |
| `victory.mp3` | Winning the game | Triumphant fanfare (1-2s) |
| `defeat.mp3` | Losing the game | Sad trombone or gentle "aww" |
| `belote.mp3` | Belote/Rebelote | Regal announcement sound |
| `announcement.mp3` | Tierce/Cinquante/Cent | Trumpet fanfare |
| `button-click.mp3` | Button press | Subtle click |
| `bid-take.mp3` | Taking bid | Confident "ding" |
| `bid-pass.mp3` | Passing bid | Soft "whoosh" |

## Sound Specifications

**Format**: MP3 or OGG
**Sample Rate**: 44.1kHz recommended
**Bit Rate**: 128kbps minimum
**Duration**:
- UI sounds (click, play): 100-300ms
- Game events (win, belote): 500ms-1s
- Victory/defeat: 1-2s max

**Volume**: Normalize to -3dB to prevent clipping

## Free Sound Resources

### Recommended Sources (CC0 / Public Domain)

1. **Freesound.org**
   - https://freesound.org/
   - Tags: "card", "shuffle", "win", "lose", "ding", "button"
   - License: CC0 or CC-BY (credit in CREDITS.md)

2. **Zapsplat**
   - https://www.zapsplat.com/
   - Free tier: 10 downloads/day
   - Great UI sounds

3. **Mixkit**
   - https://mixkit.co/free-sound-effects/
   - 100% free, no attribution required
   - Good game sound effects

4. **Pixabay**
   - https://pixabay.com/sound-effects/
   - Free for commercial use
   - No attribution required

5. **BBC Sound Effects**
   - https://sound-effects.bbcrewind.co.uk/
   - 16,000+ effects
   - Free for personal/educational use

### Search Terms

- **card-play**: "card snap", "card flip", "paper flip"
- **card-shuffle**: "card shuffle", "deck shuffle", "cards dealing"
- **trick-win**: "ding", "bell", "chime", "success"
- **victory**: "fanfare", "win", "success", "trumpet"
- **defeat**: "lose", "fail", "sad", "trombone"
- **belote**: "announcement", "royal", "fanfare"
- **announcement**: "trumpet", "herald", "fanfare"
- **button-click**: "click", "button", "UI", "interface"
- **bid-take**: "confirm", "accept", "positive"
- **bid-pass**: "whoosh", "swipe", "negative"

## Creating Custom Sounds

### Using Audacity (Free)

1. **Download**: https://www.audacityteam.org/
2. **Generate tone** or **record sound**
3. **Effects** > **Normalize** (-3dB)
4. **Effects** > **Fade In/Out** (smooth edges)
5. **File** > **Export** > **MP3**
6. Choose 128kbps CBR

### Using JSFXR (Browser-based)

1. Visit: https://sfxr.me/
2. Generate random sound or use presets
3. Tweak parameters
4. Export as WAV
5. Convert to MP3 with online converter

### AI Sound Generation

1. **ElevenLabs Sound Effects** (limited free tier)
   - https://elevenlabs.io/sound-effects

2. **AudioCraft** (Meta, local/free)
   - https://github.com/facebookresearch/audiocraft

## Adding Sounds to the Game

1. **Place files** in `priv/static/sounds/`
2. **Restart server** (assets are cached)
3. **Test** by opening browser console:
   ```javascript
   window.liveSocket.hooks.Sound.play('cardPlay')
   ```

## Usage in LiveView

### Server-side trigger

```elixir
# In LiveView
def handle_event("play_card", _params, socket) do
  # ... game logic ...

  # Trigger sound on client
  {:noreply, push_event(socket, "play-sound", %{sound: "cardPlay"})}
end
```

### Client-side auto-play

```heex
<!-- Play sound when element mounts -->
<div phx-hook="Sound" data-sound="cardPlay" id={"card-play-#{@card.id}"}>
  <.card_component card={@card} />
</div>
```

### Volume control UI

```heex
<div phx-hook="VolumeControl" id="volume-control">
  <input type="range" min="0" max="100" value="50" />
  <button data-action="toggle-mute">🔊 Mute</button>
</div>
```

## Sound Attribution

If using CC-BY licensed sounds, add attribution to `CREDITS.md`:

```markdown
## Sound Effects

- "Card Snap" by UserName (freesound.org) - CC-BY 4.0
- "Victory Fanfare" by ArtistName (zapsplat.com) - Free License
```

## Troubleshooting

### Sounds not playing

1. Check browser console for errors
2. Verify file paths: `/sounds/card-play.mp3`
3. Check file format (MP3 supported by all browsers)
4. Ensure files are not muted (check localStorage: `game-muted`)

### Performance issues

1. Reduce file sizes (use 96kbps instead of 128kbps)
2. Use OGG format (smaller than MP3)
3. Limit sound duration (< 1s for most sounds)

### Browser autoplay policy

Modern browsers block autoplay. Sounds will only work after user interaction (click, tap). This is already handled by the hooks.

## License

Ensure all sounds are either:
- Public domain (CC0)
- Properly attributed (CC-BY)
- Licensed for commercial use

---

**Created**: 2026-01-31
**Last Updated**: 2026-01-31
