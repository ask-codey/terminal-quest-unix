# What runs after every command in a quest's bash (and in the tests): writes down the shell's own aliases and functions,
# runs the checker, and moves the player when the story says so. Sourced; needs QUEST_HOME and QUEST_ADVENTURE.

# q_pid <program>: the process number of a program the story runs (ps shows it too).
q_pid() { cat "$QUEST_HOME/.quest/state/$QUEST_ADVENTURE/pids/$1" 2>/dev/null; }

# __quest_after <exit status> <command line>
__quest_after() {
  local state="$QUEST_HOME/.quest/state/$QUEST_ADVENTURE" to
  mkdir -p "$state"
  alias -p > "$state/aliases" 2>/dev/null
  declare -F | awk '{ print $3 }' > "$state/functions"
  "${QUEST_BASH:-$BASH}" "$QUEST_HOME/.quest/lib/checker.sh" "$2"
  if [ -s "$state/teleport" ]; then
    to=$(cat "$state/teleport")
    rm -f "$state/teleport"
    cd "$to" 2>/dev/null || true
  fi
}
