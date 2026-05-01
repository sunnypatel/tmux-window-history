#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../scripts/window_history.sh"
}

# ── stack_push ─────────────────────────────────────────────────────────────────

@test "stack_push: empty stack gets single entry" {
  result=$(stack_push "" "@1" 10)
  [ "$result" = "@1" ]
}

@test "stack_push: prepends to existing stack" {
  result=$(stack_push "@1 @2 @3" "@4" 10)
  [ "$result" = "@4 @1 @2 @3" ]
}

@test "stack_push: deduplicates — moves existing ID to front" {
  result=$(stack_push "@1 @2 @3" "@2" 10)
  [ "$result" = "@2 @1 @3" ]
}

@test "stack_push: trims to max_size" {
  result=$(stack_push "@1 @2 @3" "@4" 3)
  [ "$result" = "@4 @1 @2" ]
}

@test "stack_push: max_size=1 keeps only newest entry" {
  result=$(stack_push "@1 @2" "@3" 1)
  [ "$result" = "@3" ]
}

@test "stack_push: dedup then trim — moved entry counts toward max" {
  result=$(stack_push "@1 @2 @3 @4" "@3" 3)
  [ "$result" = "@3 @1 @2" ]
}

# ── stack_scrub ────────────────────────────────────────────────────────────────

@test "stack_scrub: removes target from middle" {
  result=$(stack_scrub "@1 @2 @3" "@2")
  [ "$result" = "@1 @3" ]
}

@test "stack_scrub: removes target from front" {
  result=$(stack_scrub "@1 @2 @3" "@1")
  [ "$result" = "@2 @3" ]
}

@test "stack_scrub: removes target from end" {
  result=$(stack_scrub "@1 @2 @3" "@3")
  [ "$result" = "@1 @2" ]
}

@test "stack_scrub: no-op when ID not present" {
  result=$(stack_scrub "@1 @2 @3" "@99")
  [ "$result" = "@1 @2 @3" ]
}

@test "stack_scrub: empty stack returns empty string" {
  result=$(stack_scrub "" "@1")
  [ "$result" = "" ]
}

@test "stack_scrub: single-entry stack returns empty string" {
  result=$(stack_scrub "@1" "@1")
  [ "$result" = "" ]
}

# ── stack_get ──────────────────────────────────────────────────────────────────

@test "stack_get: retrieves element at index 0" {
  result=$(stack_get "@1 @2 @3" 0)
  [ "$result" = "@1" ]
}

@test "stack_get: retrieves element at index 1" {
  result=$(stack_get "@1 @2 @3" 1)
  [ "$result" = "@2" ]
}

@test "stack_get: retrieves last element" {
  result=$(stack_get "@1 @2 @3" 2)
  [ "$result" = "@3" ]
}

@test "stack_get: out-of-bounds index returns empty string" {
  result=$(stack_get "@1 @2" 5)
  [ "$result" = "" ]
}

# ── stack_count ────────────────────────────────────────────────────────────────

@test "stack_count: counts three entries" {
  result=$(stack_count "@1 @2 @3")
  [ "$result" = "3" ]
}

@test "stack_count: empty stack returns 0" {
  result=$(stack_count "")
  [ "$result" = "0" ]
}

@test "stack_count: single entry returns 1" {
  result=$(stack_count "@1")
  [ "$result" = "1" ]
}

# ── next_index ─────────────────────────────────────────────────────────────────

@test "next_index: increments from 0 to 1" {
  result=$(next_index 0 5)
  [ "$result" = "1" ]
}

@test "next_index: loops back to 0 at last entry" {
  result=$(next_index 4 5)
  [ "$result" = "0" ]
}

@test "next_index: size 1 always returns 0" {
  result=$(next_index 0 1)
  [ "$result" = "0" ]
}

@test "next_index: size 0 always returns 0" {
  result=$(next_index 0 0)
  [ "$result" = "0" ]
}
