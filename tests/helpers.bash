# Shared by the tests: a copy of the repo in a temporary folder, played without opening a shell. Each command of a
# walkthrough runs in this bash, then the same hook a quest's prompt runs, so the tests play the game as a player would.

setup_quest() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export QUEST_HOME="$BATS_TEST_TMPDIR/quest"
  mkdir -p "$QUEST_HOME"
  cp -R "$REPO/quest" "$REPO/.quest" "$QUEST_HOME/"
  rm -rf "$QUEST_HOME/.quest/state"
  export HOME="$QUEST_HOME"
  unset QUEST_ADVENTURE QUEST_SHELL
  LOG="$BATS_TEST_TMPDIR/play.log"
  : > "$LOG"
}

teardown_quest() {
  if [ -n "${QUEST_ADVENTURE:-}" ]; then "$QUEST_HOME/quest" __leave; fi
  return 0
}

# begin <adventure>: a fresh copy, and this bash inside it as a quest's shell would be.
begin() {
  QUEST_NO_SHELL=1 "$QUEST_HOME/quest" start "$1" >> "$LOG" 2>&1
  export QUEST_ADVENTURE="$1" QUEST_SHELL=bash QUEST_BASH="$BASH"
  # shellcheck disable=SC1091
  . "$QUEST_HOME/.quest/lib/hook.bash"
  cd "$(cat "$QUEST_HOME/.quest/state/$1/lastcwd")" || return 1
  shopt -s expand_aliases
}

# type_in <command>: runs it, then the prompt's hook, as pressing Enter in a quest does.
type_in() {
  local st
  printf '$ %s\n' "$1" >> "$LOG"
  st=0
  eval "$1" < /dev/null >> "$LOG" 2>&1 || st=$?
  __quest_after "$st" "$1" >> "$LOG" 2>&1
}

# play <adventure>: its whole walkthrough.
play() {
  local cmd
  begin "$1"
  # shellcheck disable=SC1090
  . "$QUEST_HOME/.quest/stories/$1/walkthrough.sh"
  for cmd in "${QS_WALKTHROUGH[@]}"; do type_in "$cmd"; done
}

state() {
  cat "$QUEST_HOME/.quest/state/$QUEST_ADVENTURE/$1" 2>/dev/null
}

# Everything found and the quest complete; the log of the play when not.
assert_complete() {
  local t treasures coin
  treasures=$(sed -n "s/^QS_TREASURES='\(.*\)'\$/\1/p" "$QUEST_HOME/.quest/stories/$1/story.sh")
  coin=$(sed -n "s/^QS_COIN=\(.*\)\$/\1/p" "$QUEST_HOME/.quest/stories/$1/story.sh")
  for t in $treasures; do
    state found | grep -Fxq "$t" || { cat "$LOG"; echo "Treasure not found: $t"; return 1; }
  done
  if [ "$coin" = 1 ] && [ ! -f "$QUEST_HOME/.quest/state/$1/coin" ]; then cat "$LOG"; echo 'The coin was not found'; return 1; fi
  [ -f "$QUEST_HOME/.quest/state/$1/finished" ] || { cat "$LOG"; echo 'The quest did not finish'; return 1; }
}

# Assertions that fail the test in every bash: a plain `! command` or `[[ ]]` doesn't, under bash 3.2's set -e.
has() {
  state "$1" | grep -Fxq -- "$2" || { echo "Expected $1 to have: $2"; cat "$LOG"; return 1; }
}

lacks() {
  if state "$1" | grep -Fxq -- "$2"; then echo "Expected $1 not to have: $2"; return 1; fi
}

contains() {
  case "$1" in *"$2"*) return 0 ;; esac
  printf 'Expected to find: %s\nin: %s\n' "$2" "$1"
  return 1
}
