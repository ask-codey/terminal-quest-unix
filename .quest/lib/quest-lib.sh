# Terminal Quest's helpers for a real terminal. Sourced by the quest command, the checker that runs after every
# command, and every story object. Written for bash 3.2 (the bash macOS ships), so: no associative arrays, no mapfile,
# no ${x,,}.
#
# A story (.quest/stories/<adventure>/story.sh) is built from the same story the online game plays: its checks and
# effects call the q_ functions below.

# ------------------------------------------------------------------------------------------------ where things are

# q_load <adventure folder>: sets QS_DIR (the story), QS_ROOT (the play folder), QS_STATE (what has happened), and
# loads the story's functions.
q_load() {
  QS_NAME="$1"
  QS_DIR="$QUEST_HOME/.quest/stories/$QS_NAME"
  QS_ROOT="$QUEST_HOME/$QS_NAME"
  QS_STATE="$QUEST_HOME/.quest/state/$QS_NAME"
  if [ ! -f "$QS_DIR/story.sh" ]; then
    printf 'There is no adventure called "%s". Try: ./quest list\n' "$QS_NAME" >&2
    return 1
  fi
  # shellcheck disable=SC1090
  . "$QS_DIR/story.sh"
  QS_ROOT_P=''
  if [ -d "$QS_ROOT" ]; then QS_ROOT_P=$(cd "$QS_ROOT" && pwd -P); fi
}

# q_key <absolute path>: the path inside the adventure, with /, '' for the adventure's folder itself; fails outside it.
q_key() {
  local dir base p
  if [ -d "$1" ]; then
    p=$(cd "$1" 2>/dev/null && pwd -P) || return 1
  else
    dir=$(dirname "$1")
    base=$(basename "$1")
    dir=$(cd "$dir" 2>/dev/null && pwd -P) || return 1
    p="$dir/$base"
  fi
  [ -n "$QS_ROOT_P" ] || return 1
  if [ "$p" = "$QS_ROOT_P" ]; then printf '\n'; return 0; fi
  case "$p" in
    "$QS_ROOT_P"/*) printf '%s\n' "${p#"$QS_ROOT_P"/}" ;;
    *) return 1 ;;
  esac
}

# ------------------------------------------------------------------------------------------------ remembering

# The state is plain text files, one line per thing remembered: flags, reads, visits, used, ran, found, goals, ...
q_has() {
  [ -f "$QS_STATE/$1" ] && grep -Fxq -- "$2" "$QS_STATE/$1"
}

q_add() {
  q_has "$1" "$2" && return 0
  mkdir -p "$QS_STATE"
  printf '%s\n' "$2" >> "$QS_STATE/$1"
}

q_del() {
  local f="$QS_STATE/$1"
  [ -f "$f" ] || return 0
  grep -Fxv -- "$2" "$f" > "$f.tmp" || true
  mv "$f.tmp" "$f"
}

q_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# ------------------------------------------------------------------------------------------------ saying things

if [ -t 1 ]; then
  Q_STORY=$(printf '\033[33m'); Q_GOLD=$(printf '\033[1;33m'); Q_DIM=$(printf '\033[2m'); Q_OK=$(printf '\033[32m'); Q_OFF=$(printf '\033[0m')
else
  Q_STORY=''; Q_GOLD=''; Q_DIM=''; Q_OK=''; Q_OFF=''
fi

# q_say <text>: story text, in the story's color.
q_say() {
  printf '%s\n' "$1" | while IFS= read -r line || [ -n "$line" ]; do printf '%s%s%s\n' "$Q_STORY" "$line" "$Q_OFF"; done
}

q_gold() {
  printf '%s%s%s\n' "$Q_GOLD" "$1" "$Q_OFF"
}

# ------------------------------------------------------------------------------------------------ the game's history

# q_history <event> <detail>: one row of game-history.csv at the repo's root. A reset never clears it.
q_history() {
  local file="$QUEST_HOME/game-history.csv" detail
  [ -f "$file" ] || printf 'when,adventure,shell,run,event,detail\n' > "$file"
  detail=$(printf '%s' "$2" | sed 's/"/""/g')
  printf '%s,%s,%s,%s,%s,"%s"\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$QS_NAME" "${QUEST_SHELL:-bash}" "$(cat "$QS_STATE/run" 2>/dev/null || echo 1)" "$1" "$detail" >> "$file"
}

# ------------------------------------------------------------------------------------------------ checks

q_here() {
  q_key "$PWD"
}

q_cwd() {
  local here
  here=$(q_here) || return 1
  [ "$here" = "$1" ]
}

q_visited() { q_has visits "$1"; }
q_read() { q_has reads "$1"; }
q_ran() { q_has ran "$1"; }
q_flag() { q_has flags "$1"; }
q_treasure() { q_has found "$1"; }
q_goal() { q_has goals "$1"; }

q_exists() {
  [ -e "$QS_ROOT/$1" ] || [ -L "$QS_ROOT/$1" ]
}

# Follows a link, as reading the file would; case doesn't matter. (Lower case first: Git for Windows' grep -Fi crashes.)
q_contains() {
  [ -f "$QS_ROOT/$1" ] && tr '[:upper:]' '[:lower:]' < "$QS_ROOT/$1" | grep -Fq -- "$(q_lower "$2")"
}

q_executable() {
  [ -f "$QS_ROOT/$1" ] && [ -x "$QS_ROOT/$1" ]
}

# q_env <name> set|equals|includes <value>: an environment variable programs can see (exported).
q_env() {
  local value set
  eval "set=\${$1+x}; value=\${$1-}"
  [ "$set" = x ] || return 1
  case "$2" in
    equals) [ "$value" = "$3" ] ;;
    includes) case "$(q_lower "$value")" in *"$(q_lower "$3")"*) return 0 ;; *) return 1 ;; esac ;;
    *) return 0 ;;
  esac
}

# A shell variable that isn't exported: only PowerShell's stories ask, so never here.
q_variable() { return 1; }

# Aliases and functions are the player's shell's own: the prompt hook writes them down before every check.
q_alias() {
  [ -f "$QS_STATE/aliases" ] && grep -Eq "^alias (-- )?$1=" "$QS_STATE/aliases"
}

q_function() {
  q_has functions "$1"
}

q_used() {
  local name
  for name in "$@"; do
    q_has used "$(q_lower "$name")" && return 0
  done
  return 1
}

# q_count <wildcard> <n>: how many visible names the wildcard matches, inside the adventure.
q_count() {
  local n=0 f
  for f in "$QS_ROOT"/$1; do
    if [ -e "$f" ] || [ -L "$f" ]; then n=$((n + 1)); fi
  done
  [ "$n" -eq "$2" ]
}

q_pid() {
  cat "$QS_STATE/pids/$1" 2>/dev/null
}

q_running() {
  local pid
  pid=$(q_pid "$1")
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

# Objects: what was piped in.
q_stdin_has() {
  case "$QS_STDIN" in *"$1"*) return 0 ;; *) return 1 ;; esac
}

# ------------------------------------------------------------------------------------------------ the story's memory

q_trigger_ready() {
  [ "$2" = always ] && return 0
  ! q_has triggers "$1"
}
q_trigger_mark() { q_add triggers "$1"; }
q_rule_ready() { ! q_has rules "$1"; }
q_rule_mark() { q_add rules "$1"; }
q_ran_mark() { q_add ran "$1"; }

# ------------------------------------------------------------------------------------------------ effects

q_flag_set() { q_add flags "$1"; }
q_flag_clear() { q_del flags "$1"; }

q_mkdir() {
  mkdir -p "$QS_ROOT/$1"
}

q_write() {
  mkdir -p "$(dirname "$QS_ROOT/$1")"
  printf '%s' "$2" > "$QS_ROOT/$1"
}

q_chmod() {
  chmod "$1" "$QS_ROOT/$2" 2>/dev/null || true
}

# q_link <target> <path>: a symbolic link at path, its target written as the story gives it.
q_link() {
  mkdir -p "$(dirname "$QS_ROOT/$2")"
  (cd "$(dirname "$QS_ROOT/$2")" && ln -s "$1" "$(basename "$2")")
}

q_remove() {
  rm -rf "${QS_ROOT:?}/$1"
}

q_move() {
  [ -e "$QS_ROOT/$1" ] || return 0
  mkdir -p "$(dirname "$QS_ROOT/$2")"
  mv "$QS_ROOT/$1" "$QS_ROOT/$2"
}

# The player's shell moves after the command (the prompt hook reads this).
q_teleport() {
  mkdir -p "$QS_STATE"
  printf '%s\n' "$QS_ROOT/$1" > "$QS_STATE/teleport"
}

# q_spawn <name> <command>: a program the story starts. ps lists it and kill stops it, as any program.
q_spawn() {
  q_add processes "$1"
  q_add commands "$1 $2"
  q_start_process "$1"
}

q_start_process() {
  local name="$1" bin="$QS_STATE/bin/$1"
  q_running "$name" && return 0
  mkdir -p "$QS_STATE/bin" "$QS_STATE/pids"
  cat > "$bin" <<EOF
#!/usr/bin/env bash
# $name: a program Terminal Quest runs for the story. ps lists it; kill stops it.
trap 'kill \$! 2>/dev/null; exit 0' TERM INT HUP
sleep 28800 &
wait \$!
EOF
  chmod +x "$bin"
  nohup "$bin" > /dev/null 2>&1 &
  printf '%s\n' "$!" > "$QS_STATE/pids/$name"
}

# The story's programs that should be running and aren't (the player stopped them) are forgotten.
q_forget_stopped() {
  local name
  [ -f "$QS_STATE/processes" ] || return 0
  for name in $(cat "$QS_STATE/processes"); do
    q_running "$name" || { q_del processes "$name"; rm -f "$QS_STATE/pids/$name"; }
  done
}

# Leaving a quest pauses its programs; starting it again starts them again.
q_pause_processes() {
  local name pid
  [ -d "$QS_STATE/pids" ] || return 0
  for name in $(ls "$QS_STATE/pids"); do
    pid=$(q_pid "$name")
    [ -n "$pid" ] && kill "$pid" 2>/dev/null
    rm -f "$QS_STATE/pids/$name"
  done
}

q_resume_processes() {
  local name
  [ -f "$QS_STATE/processes" ] || return 0
  for name in $(cat "$QS_STATE/processes"); do q_start_process "$name"; done
}

# ------------------------------------------------------------------------------------------------ goals

# The first goal not done yet; nothing when every goal is done.
q_current_goal() {
  local g
  for g in $QS_GOALS; do
    q_goal "$g" || { printf '%s\n' "$g"; return 0; }
  done
  return 1
}
