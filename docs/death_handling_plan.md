# Death-Handling Implementation Plan

## Objectives
1. Bring death behaviour in line with design requirements:
   * Play death animation, wait until it finishes, pause 0.5 s, apply fade-out, then remove entity (queue_free).
   * Ensure turn does **not** advance until corpse is gone.
   * Remove unit from all gameplay systems (grid, turn order, UI, networking).
   * Trigger victory/defeat screens when appropriate.
2. Fully deterministic across multiplayer: host owns sequencing and broadcasts updates.
3. No XP/loot work in this pass.

---

## High-Level Flow (host authority)
1. **HP hits 0** → `CombatantResourcesComponent.resources_depleted` fires.
2. Signal caught by owning `BaseCharacter` (new connection for all units).
3. `BaseCharacter._on_resources_depleted()` delegates to `request_death()` (new unified handler).
4. `request_death()` (RPC-callable, executed on host only):
   1. Validate not already dead, set `is_dead = true`, stop AI & player input.
   2. Call `_play_animation("Die…")` (already direction-aware).
   3. Connect to `animated_sprite.animation_finished` → when finished, start a 0.5 s timer.
5. After timer, **fade-out**:
   * Option A: assign a simple shader that linearly lowers `ALPHA` over 0.6 s.
   * Option B: Tween the node’s `modulate.a` property.
6. On fade completion:
   1. Tell `GridManager.unregister_character(this)` so tile is free.
   2. Tell `TurnManager.remove_character(this)`.
   3. Queue-free the node.
   4. Emit global `character_died` signal.
   5. Host checks victory/defeat conditions and notifies clients.
7. **TurnManager**: if the dying unit was the active turn holder, wait for step 6 completion then call `_end_current_turn()`.

All steps after 4 are wrapped in an RPC so every client mirrors the animation, fade, and node removal timing.

---

## Module-by-Module Changes

### 1. CombatantResourcesComponent
* Already emits `resources_depleted` when HP ≤ 0.
* No changes.

### 2. BaseCharacter
* Add `_on_resources_depleted()` → calls `request_death()`.
* Create `request_death()` (RPC-callable but host-validated).
* Refactor existing `_handle_death()` logic into new coroutine `__do_death_sequence()` implementing the flow above.
* Add internal `death_sequence_completed` signal for TurnManager.

### 3. BaseEnemy / player scripts
* Delete their custom death code; rely on unified logic.
* BaseEnemy may still award loot in future, but stub for now.

### 4. TurnManager
* Maintain `characters` minus dead entries; skip them when cycling.
* If `current_character` dies, listen to its `death_sequence_completed` before calling `_end_current_turn()`.
* Provide `_on_character_died(character)` handler to refresh UI and maybe advance turn sooner when corpse removed.

### 5. GridManager
* No new code—already has `unregister_character()`.

### 6. GameController
* Subscribe to `character_died`:
  * If all enemies gone → change scene to `VictoryScreen.tscn` via RPC to all peers.
  * If all players gone → change scene to `DefeatScreen.tscn`.

### 7. Networking
* `request_death()` is `@rpc("any_peer", "call_remote", "reliable")`; only host processes, then calls `_start_death_sequence()` via `rpc` (call_local) so every peer runs identical timeline.
* Host is authority 1, verified in handler.

### 8. UI
* Turn-order panel updates when `TurnManager` emits updated list; dead units disappear immediately.
* End-turn button disabled while corpse is animating/fading.

### 9. Visual Fade Implementation
* Quick shader (`fade_shader.gdshader`) with uniform `u_alpha` 0-1; animate via Tween on material parameter.
* Fallback: Tween the node’s `modulate.a` property if shader unsupported.

---

## Victory / Defeat Screen Wiring
1. Add functions in `GameController`:
   * `_show_victory_screen()`
   * `_show_defeat_screen()`
2. Use `get_tree().change_scene_to_file()` with `res://UIs/VictoryScreen.tscn` or `res://UIs/DefeatScreen.tscn`.
3. Called by host when `character_died` leaves only one faction alive; host then `rpc` to change scene on all peers.

---

## Edge Cases & Guarantees
* Multiple characters can die from AoE; handle overlapping sequences safely.
* Host migration not supported – host dies = run ends.
* If a character dies outside its turn, no turn-logic impact.
* Grid tile becomes walkable right after `unregister_character`, before fade completes, so allies can step over corpses during fade.

---

## Out-of-Scope for This Pass
* XP / loot distribution.
* Automated tests / debug logging harness.

---

## Next Steps
1. Implement shader & helper for fade-out.
2. Code the unified death handler.
3. TurnManager and GameController integrations.
4. Wire victory/defeat screens.
5. Manual tests in single-player and multiplayer sessions. 