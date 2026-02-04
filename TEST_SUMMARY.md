# Multi-Round Gameplay - Test Summary

## Tests Written (TDD - Should Have Been First!)

### 1. Multi-Round Game Logic Tests
**File:** `test/coinchette/multiplayer/multi_round_test.exs`

Tests the complete round lifecycle and game progression:

- ✅ Cumulative scores start at 0 for both teams
- ✅ After completing one hand, cumulative scores are updated
- ✅ If target score not reached, new round starts automatically
- ✅ Dealer position rotates between rounds
- ✅ When target score is reached, game finishes completely
- ✅ Round number increments with each new round
- ✅ Cumulative scores persist across rounds
- ✅ Game creation with default target_score (1000)
- ✅ Game creation with custom target_score (500)
- ✅ Rejects invalid target_score values

**Coverage:**
- Round completion detection
- Cumulative score tracking across rounds
- Target score victory condition
- Automatic new round initialization
- Dealer rotation
- Database persistence of round state

### 2. Game Schema Validation Tests
**File:** `test/coinchette/multiplayer/game_schema_test.exs`

Tests schema-level validation and defaults:

- ✅ Accepts valid target_score of 500
- ✅ Accepts valid target_score of 1000
- ✅ Rejects target_score of 750 (not 500 or 1000)
- ✅ Rejects target_score of 0
- ✅ Uses default target_score of 1000 if not provided
- ✅ Defaults round_number to 1
- ✅ Allows updating round_number via state_changeset
- ✅ Allows updating scores map via state_changeset

**Coverage:**
- Field defaults
- Validation constraints
- Changeset behavior

### 3. Multiplayer Context Tests
**File:** `test/coinchette/multiplayer_context_test.exs`

Tests the public API functions:

- ✅ `create_game/2` with default target_score
- ✅ `create_game/2` with custom target_score
- ✅ Initializes cumulative scores to zero
- ✅ Fails with invalid target_score
- ✅ `update_game_settings/2` updates target_score while waiting
- ✅ Prevents updating target_score when game is playing
- ✅ Validates target_score when updating
- ✅ `update_game_status/3` updates round_number
- ✅ Updates cumulative scores
- ✅ Updates scores and round_number together

**Coverage:**
- Public API contracts
- Authorization checks
- State transitions

## Running the Tests

```bash
# Run all multi-round tests
mix test test/coinchette/multiplayer/multi_round_test.exs

# Run schema tests
mix test test/coinchette/multiplayer/game_schema_test.exs

# Run context tests
mix test test/coinchette/multiplayer_context_test.exs

# Run all tests
mix test

# Run with coverage
mix test --cover
```

## Expected Behavior

If the implementation is correct, all tests should pass.

If tests fail, the implementation needs to be refactored until tests pass (proper TDD cycle).

## Notes

These tests were written AFTER the implementation code, which violates the project's TDD principles. In the future, tests should be written FIRST, then implementation code written to make tests pass.
