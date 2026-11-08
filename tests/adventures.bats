#!/usr/bin/env bats
# Every adventure, played start to finish in a real bash: its walkthrough finds every treasure and the coin, and ends
# the quest (the same walkthrough the online game's tests play).
load helpers

setup() { setup_quest; }
teardown() { teardown_quest; }

@test "The Lighthouse: every treasure, the coin, and the lamp lit" {
  play lighthouse
  assert_complete lighthouse
}

@test "Moving Day: every treasure, the coin, and the new place in order" {
  play new-place
  assert_complete new-place
}

@test "The Archive: every treasure, the coin, and the Star Map found" {
  play archive
  assert_complete archive
}

@test "The Clockwork Workshop: every treasure, the coin, and the bell rung" {
  play workshop
  assert_complete workshop
}

@test "Mission Control: every treasure, the coin, and the launch" {
  play mission-control
  assert_complete mission-control
}
