#!/usr/bin/env bash
# Runs after every command in a quest (the prompt hook calls it): works out what the command did in the story, then
# fires the story's triggers and rules, and says which treasures, goals, the coin and the finish the world now shows.
#
#   checker.sh <the command line, as typed>
#
# The world is checked as it is: real folders, files, permissions, environment variables and programs. What a command
# READ can't be seen afterwards, so the command line is read instead: files named to cat, less, more, head, tail, sort,
# grep (only the files it printed from) and the like, and what find, ls or grep hand to xargs.
# shellcheck disable=SC1090,SC1091
. "$QUEST_HOME/.quest/lib/quest-lib.sh"
q_load "$QUEST_ADVENTURE" || exit 0
[ -d "$QS_ROOT" ] || exit 0
mkdir -p "$QS_STATE"

LINE="$1"
EVENTS="$QS_STATE/.events"
: > "$EVENTS"

emit() { printf '%s %s\n' "$1" "$2" >> "$EVENTS"; }

READERS=' cat tac less more head tail nl sort uniq cut sed awk strings od xxd source . '
PRODUCERS=' find ls echo printf grep egrep fgrep cat '

# q_mark_read <folder> <word>: the files a word names (wildcards too), when they are inside the adventure.
q_mark_read() {
  local base="$1" w="$2" abs key IFS='
'
  case "$w" in "~") w="$HOME" ;; "~/"*) w="$HOME/${w#\~/}" ;; esac
  case "$w" in /*) ;; *) w="$base/$w" ;; esac
  for abs in $w; do
    { [ -f "$abs" ] && [ -r "$abs" ]; } || continue
    key=$(q_key "$abs") || continue
    emit read "$key"
  done
}

# The files a grep printed from: the same grep again, asked for file names only (it reads, never writes).
grep_reads() {
  local base="$1" cmd="$2" w names=0 recursive=0 operands=0 pattern=1 skip=0 f
  shift 2
  for w in "$@"; do
    if [ $skip = 1 ]; then skip=0; continue; fi
    case "$w" in
      --count|--files-with-matches|--files-without-match|--quiet|--silent) names=1 ;;
      --recursive|--dereference-recursive) recursive=1 ;;
      --regexp=*|--file=*) pattern=0 ;;
      --*) ;;
      -e|-f) pattern=0; skip=1 ;;
      -A|-B|-C|-m|-d|-D) skip=1 ;;
      -*)
        case "$w" in -*[lLcq]*) names=1 ;; esac
        case "$w" in -*[rR]*) recursive=1 ;; esac
        case "$w" in -*e) pattern=0; skip=1 ;; esac
        ;;
      *) operands=$((operands + 1)) ;;
    esac
  done
  [ $names = 1 ] && return 0
  [ $((operands - pattern)) -gt 0 ] || [ $recursive = 1 ] || return 0
  (cd "$base" 2>/dev/null && command "$cmd" -l -s "$@" < /dev/null 2>/dev/null) | while IFS= read -r f; do
    q_mark_read "$base" "$f"
  done
}

# The files a reader names: its words that aren't options (and not the values options take, nor sed's or awk's program).
reader_reads() {
  local base="$1" cmd="$2" w skip=0 program=0
  shift 2
  case "$cmd" in sed|awk) program=1 ;; esac
  for w in "$@"; do
    if [ $skip = 1 ]; then skip=0; continue; fi
    case "$cmd:$w" in
      head:-n|head:-c|tail:-n|tail:-c|cut:-d|cut:-f|cut:-c|sort:-k|sort:-t|sort:-o|awk:-F|awk:-v) skip=1; continue ;;
      sed:-e|sed:-f|awk:-f) program=0; skip=1; continue ;;
    esac
    case "$w" in
      -) ;;
      -*) ;;
      *)
        if [ $program = 1 ]; then program=0; continue; fi
        q_mark_read "$base" "$w"
        ;;
    esac
  done
}

SIM="$(cat "$QS_STATE/lastcwd" 2>/dev/null)"
[ -d "$SIM" ] || SIM="$PWD"
WORDS=()
PREV=()
PIPED=0
REDIRECT=''

# One simple command: what it used, where it went, what it read.
segment() {
  local n=${#WORDS[@]} i=0 cmd lower next target dir key
  [ "$n" -gt 0 ] || return 0
  while [ $i -lt $n ] && [[ "${WORDS[$i]}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; do i=$((i + 1)); done
  while [ $i -lt $n ]; do
    cmd="${WORDS[$i]}"
    lower=$(q_lower "$cmd")
    q_add used "$lower"
    case "$cmd" in */*) q_add used "$(q_lower "$(basename "$cmd")")" ;; esac
    case "$lower" in
      sudo|command|builtin|exec|time|nohup|env)
        i=$((i + 1))
        while [ $i -lt $n ] && { [[ "${WORDS[$i]}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || [[ "${WORDS[$i]}" == -* ]]; }; do i=$((i + 1)); done
        continue
        ;;
    esac
    break
  done
  [ $i -lt $n ] || return 0
  local args=("${WORDS[@]:$((i + 1))}")
  case "$lower" in
    cd|pushd)
      target="${args[0]:-$HOME}"
      case "$target" in "~") target="$HOME" ;; "~/"*) target="$HOME/${target#\~/}" ;; -) return 0 ;; esac
      dir=$(cd "$SIM" 2>/dev/null && cd "$target" 2>/dev/null && pwd -P) || return 0
      SIM="$dir"
      key=$(q_key "$dir") && emit enter "$key"
      ;;
    grep|egrep|fgrep)
      grep_reads "$SIM" "$lower" "${args[@]}"
      ;;
    xargs)
      local j=0
      while [ $j -lt ${#args[@]} ] && [[ "${args[$j]}" == -* ]]; do j=$((j + 1)); done
      next=$(q_lower "${args[$j]:-}")
      [ -n "$next" ] && q_add used "$next"
      [ $PIPED = 1 ] && [ ${#PREV[@]} -gt 0 ] || return 0
      case "$PRODUCERS" in *" $(q_lower "${PREV[0]}") "*) ;; *) return 0 ;; esac
      case " ${PREV[*]} " in *" -exec "*|*" -execdir "*|*" -delete "*|*" -ok "*|*" -fprint"*) return 0 ;; esac
      local files=() f
      while IFS= read -r f; do files+=("$f"); done < <(cd "$SIM" 2>/dev/null && command "${PREV[@]}" < /dev/null 2>/dev/null)
      [ ${#files[@]} -gt 0 ] || return 0
      case "$next" in
        grep|egrep|fgrep) grep_reads "$SIM" "$next" "${args[@]:$((j + 1))}" "${files[@]}" ;;
        *) case "$READERS" in *" $next "*) for f in "${files[@]}"; do q_mark_read "$SIM" "$f"; done ;; esac ;;
      esac
      ;;
    *)
      case "$READERS" in *" $lower "*) reader_reads "$SIM" "$lower" "${args[@]}" ;; esac
      ;;
  esac
}

while IFS= read -r token; do
  kind="${token:0:1}"
  value="${token:1}"
  if [ "$kind" = W ]; then
    if [ -n "$REDIRECT" ]; then
      [ "$REDIRECT" = '<' ] && q_mark_read "$SIM" "$value"
      REDIRECT=''
    else
      WORDS+=("$value")
    fi
    continue
  fi
  case "$value" in
    '>'|'>>'|'<'|'<<'|'<<<') REDIRECT="$value" ;;
    *)
      segment
      if [ "$value" = '|' ]; then PIPED=1; PREV=("${WORDS[@]}"); else PIPED=0; PREV=(); fi
      WORDS=()
      ;;
  esac
done < <(printf '%s\n' "$LINE" | awk -f "$QUEST_HOME/.quest/lib/words.awk")
segment

# Where the player ended up, however they got there (an alias, a function, a script they sourced).
if HERE_KEY=$(q_here); then
  SIM_KEY=$(q_key "$SIM") || SIM_KEY='/outside'
  [ "$SIM_KEY" != "$HERE_KEY" ] && emit enter "$HERE_KEY"
fi
printf '%s\n' "$PWD" > "$QS_STATE/lastcwd"

q_forget_stopped

# What the command did, in order: triggers fire as the story says.
while read -r kind key; do
  [ "$kind" = enter ] && q_add visits "$key"
  [ "$kind" = read ] && q_add reads "$key"
  qs_fire "$kind" "$key"
done < "$EVENTS"
rm -f "$EVENTS"

pass=0
while [ $pass -lt 10 ]; do
  qs_rules
  [ "$QS_FIRED" = 1 ] || break
  pass=$((pass + 1))
done

for t in $QS_TREASURES; do
  q_treasure "$t" && continue
  qs_treasure_found "$t" || continue
  q_add found "$t"
  name=$(qs_treasure_name "$t")
  printf '\n'
  q_gold "★ Treasure: $name"
  qs_treasure_text "$t"
  goal=$(qs_treasure_goal "$t")
  if [ -n "$goal" ] && q_has shown "$goal"; then q_history treasure "$name (after the hint showed the command)"; else q_history treasure "$name"; fi
done

if [ "$QS_COIN" = 1 ] && [ ! -f "$QS_STATE/coin" ] && qs_coin_found; then
  : > "$QS_STATE/coin"
  printf '\n'
  q_gold '◆ A rare coin!'
  qs_coin_text
  q_history coin 'the rare coin'
fi

done_one=0
for g in $QS_GOALS; do
  q_goal "$g" && continue
  qs_goal_done "$g" || continue
  q_add goals "$g"
  done_one=1
done

if [ ! -f "$QS_STATE/finished" ] && qs_finish_when; then
  : > "$QS_STATE/finished"
  printf '\n'
  qs_finish_text
  q_gold "★ Quest complete: $QS_TITLE"
  q_history finish "$QS_TITLE"
elif [ $done_one = 1 ] && next=$(q_current_goal); then
  printf '%sNext: %s   (stuck? quest hint)%s\n' "$Q_DIM" "$(qs_goal_title "$next")" "$Q_OFF"
fi
exit 0
