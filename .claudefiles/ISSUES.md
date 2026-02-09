# Issues - Session 2026-02-06

Reported issues from real-world testing (2 humans + 2 bots).

## Issue Tracker

| # | Issue | Severity | Status | Commit |
|---|-------|----------|--------|--------|
| 1 | Join screen redundancy - unnecessary confirm step | Medium | ✅ DONE | 0844507 |
| 2 | Point selector (500/1000) has no effect | High | ✅ DONE | 1aa9949 |
| 3 | Selector resets to 1000 when player joins | High | ✅ DONE | 1aa9949 |
| 4 | No way to rejoin ongoing game after disconnect | Medium | ✅ DONE | ce98719 |
| 5 | Game doesn't auto-continue after first hand | High | ✅ DONE | 3d1ce0a |
| 6 | Last trick card disappears + no winner indicator + no delay | Critical | ✅ DONE | ea045ab |
| 7 | Trump cards in hand have no visual indicator | Medium | ✅ DONE | 1c0b919 |

---

## Issue 1: Join screen redundancy

**Problem:** After typing a room code and pressing Enter, the user lands on an intermediate "confirm join" screen where they must click "Join Game" again. This is redundant.

**Expected:** Typing the room code and pressing Enter should join the game directly, skipping the intermediate screen.

**Files:** `game_lobby_live.ex` (lines 470-490, 60-103)

---

## Issue 2: Point selector (500/1000) has no effect

**Problem:** The host can select 500 or 1000 points in the lobby, but games always run to 1000 points regardless.

**Expected:** The selected target score should be persisted and used by the GameServer when determining victory.

**Files:** `game_lobby_live.ex` (lines 149-168, 554-564), `multiplayer.ex`, `game_server.ex`

---

## Issue 3: Selector resets to 1000 when player joins

**Problem:** When another player joins the room, `reload_game_state` is triggered via PubSub `:player_joined`, which reloads the game from DB and resets the selector UI even if 500 was selected.

**Expected:** The selector should preserve its value when players join.

**Files:** `game_lobby_live.ex` (lines 239-241, 283-290)

---

## Issue 4: No way to rejoin ongoing game

**Problem:** If a user accidentally closes their tab or navigates away, there's no easy way to get back to their ongoing game. They must know the URL with the room ID and "/play" suffix.

**Expected:** When a user with an active game visits the lobby, they should see a prominent banner/alert with a link to rejoin their active game.

**Files:** `lobby_live.ex`, `router.ex`, `multiplayer.ex`

---

## Issue 5: Game doesn't auto-continue after first hand

**Problem:** At the end of the first hand, the game didn't automatically continue to the second hand. It seemed to require user interaction (changing sound volume) to trigger the transition.

**Expected:** After a hand finishes, the game should automatically transition to the next hand after a short delay.

**Files:** `game_server.ex` (lines 603-727)

---

## Issue 6: Last trick card disappears + no winner indicator + no delay

**Problem:** Three sub-issues:
1. The very last card played in a trick is never visible on the board - the board is cleared immediately
2. There is no visual indicator showing which card is winning the trick
3. There should be a ~3s delay at the end of each trick to let players see the cards

**Expected:** All 4 cards should be visible, the winning card should be highlighted, and there should be a 3-second pause before clearing.

**Files:** `multiplayer_game_live.ex` (lines 782-795, 1009-1027), `game_server.ex`, `game.ex`

---

## Issue 7: Trump cards have no visual indicator

**Problem:** Trump cards in the player's hand look identical to other cards. There's no visual distinction.

**Expected:** Trump cards should have a distinctive visual indicator (e.g., golden border, glow, or badge) to help players identify them quickly.

**Files:** `multiplayer_game_live.ex` (lines 1144-1162, 798-822)
