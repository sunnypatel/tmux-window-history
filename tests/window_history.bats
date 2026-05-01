#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../scripts/window_history.sh"
}

@test "placeholder — always passes" {
  true
}
