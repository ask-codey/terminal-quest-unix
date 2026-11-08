#!/usr/bin/env bats
# The quest command: the list, starting, resetting, hints, the history, and how the game notices what you read.
load helpers

setup() { setup_quest; }
teardown() { teardown_quest; }

@test "list: the five adventures in Level order, none started" {
  run "$QUEST_HOME/quest" list
  [ "$status" -eq 0 ]
  contains "${lines[0]}" "The Lighthouse"
  contains "${lines[0]}" "Novice"
  contains "${lines[0]}" "not started"
  contains "${lines[4]}" "mission-control"
  contains "${lines[4]}" "Master"
}

@test "start: an adventure that isn't there is named, with the list" {
  run "$QUEST_HOME/quest" start atlantis
  [ "$status" -eq 1 ]
  contains "$output" 'There is no adventure called "atlantis"'
  contains "$output" "The Lighthouse"
}

@test "start: by number, a fresh copy with its story, and a start in the history" {
  QUEST_NO_SHELL=1 run "$QUEST_HOME/quest" start 1
  [ "$status" -eq 0 ]
  contains "$output" "First, find out where you are. Type pwd and press Enter."
  [ -f "$QUEST_HOME/lighthouse/welcome.txt" ]
  [ -d "$QUEST_HOME/lighthouse/shore/.crab-shell" ]
  grep -q ',lighthouse,bash,1,start,' "$QUEST_HOME/game-history.csv"
}

@test "start: inside a quest, another can't start" {
  QUEST_ADVENTURE=lighthouse run "$QUEST_HOME/quest" start archive
  [ "$status" -eq 1 ]
  contains "$output" "Type exit to leave it"
}

@test "reading: cat counts, but ls -l, grep -c and a failed cat don't" {
  begin lighthouse
  type_in 'ls -l'
  type_in 'grep -c storm welcome.txt'
  type_in 'cat nothing-here.txt'
  [ -z "$(state reads)" ]
  type_in 'cat welcome.txt'
  [ "$(state reads)" = welcome.txt ]
  has goals look
}

@test "reading: grep counts only the files it printed from" {
  begin lighthouse
  type_in 'cd cottage'
  type_in 'grep -r compass .'
  has reads cottage/bedroom/diary.txt
  lacks reads cottage/kitchen/kettle.txt
}

@test "reading: a file with no read permission isn't read until chmod +r" {
  begin workshop
  type_in 'cat attic/music-box.txt'
  lacks found musicbox
  type_in 'chmod +r attic/music-box.txt'
  type_in 'cat attic/music-box.txt'
  has found musicbox
}

@test "moving: going into a folder tells its story once, and goals follow" {
  begin lighthouse
  type_in 'cd cottage'
  [ "$(grep -c 'The cottage smells of salt and old books.' "$LOG")" -eq 1 ]
  type_in 'cd .. && cd cottage'
  [ "$(grep -c 'The cottage smells' "$LOG")" -eq 1 ]
  has goals cottage
}

@test "hint: a nudge, the command's name, then the command itself" {
  begin lighthouse
  run "$QUEST_HOME/quest" hint
  contains "$output" "Ask the terminal where you are"
  run "$QUEST_HOME/quest" hint
  contains "$output" "Type pwd and press Enter."
  run "$QUEST_HOME/quest" hint
  contains "$output" "  pwd"
  [ "$(grep -c ',hint,' "$QUEST_HOME/game-history.csv")" -eq 3 ]
}

@test "status: the goal, and the treasures found and not yet" {
  begin lighthouse
  type_in 'pwd'
  run "$QUEST_HOME/quest" status
  contains "$output" "Goal 2 of 11: Look around"
  contains "$output" "☆ not found yet"
}

@test "reset: a fresh copy and a new run, and the history keeps the old one" {
  begin lighthouse
  type_in 'cd shore'
  type_in 'cat bottle.txt'
  rm -f "$QUEST_HOME/lighthouse/welcome.txt"
  unset QUEST_ADVENTURE
  run "$QUEST_HOME/quest" reset lighthouse
  [ "$status" -eq 0 ]
  [ -f "$QUEST_HOME/lighthouse/welcome.txt" ]
  [ ! -f "$QUEST_HOME/.quest/state/lighthouse/found" ]
  [ "$(cat "$QUEST_HOME/.quest/state/lighthouse/run")" = 2 ]
  grep -q ',lighthouse,bash,1,treasure,"the ship in a bottle"' "$QUEST_HOME/game-history.csv"
  grep -q ',lighthouse,bash,1,reset,' "$QUEST_HOME/game-history.csv"
  grep -q ',lighthouse,bash,2,start,' "$QUEST_HOME/game-history.csv"
}

@test "reset: not the adventure you are playing" {
  QUEST_ADVENTURE=lighthouse run "$QUEST_HOME/quest" reset lighthouse
  [ "$status" -eq 1 ]
  contains "$output" "Type exit to leave it"
}

@test "objects: one run outside a quest says how to play" {
  QUEST_NO_SHELL=1 "$QUEST_HOME/quest" start workshop > /dev/null
  run env -u QUEST_HOME bash "$QUEST_HOME/workshop/clock" --wind
  [ "$status" -ne 0 ]
  contains "$output" "Play this inside a quest: ./quest start workshop"
}

@test "processes: a story's program runs, and kill stops it for good" {
  begin mission-control
  kill -0 "$(q_pid alarm)"
  type_in 'kill "$(q_pid alarm)"'
  sleep 1
  type_in 'ls'
  lacks processes alarm
}
