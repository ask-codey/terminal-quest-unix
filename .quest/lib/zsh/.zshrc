# A quest's zsh: started by ./quest start (the shell macOS opens), with your home folder as the repo, a prompt that
# shows where you are, and a hook that checks the story after every command. Type exit to leave.
setopt INTERACTIVE_COMMENTS INC_APPEND_HISTORY
HISTFILE="$QUEST_HOME/.quest/state/$QUEST_ADVENTURE/history-zsh"
HISTSIZE=2000
SAVEHIST=2000
PROMPT='%B%F{green}player@quest%f%b:%B%F{blue}%~%f%b$ '

quest() { "$QUEST_HOME/quest" "$@" }
q_pid() { cat "$QUEST_HOME/.quest/state/$QUEST_ADVENTURE/pids/$1" 2>/dev/null }

__quest_ready=0
__quest_seen=''
precmd() {
  local st=$? n line state="$QUEST_HOME/.quest/state/$QUEST_ADVENTURE" to
  n=${${(z)$(fc -l -1 2>/dev/null)}[1]}
  if (( ! __quest_ready )); then __quest_ready=1; __quest_seen=$n; return 0; fi
  [[ -n $n && $n != $__quest_seen ]] || return 0
  __quest_seen=$n
  line=$(fc -ln -1)
  mkdir -p "$state"
  alias -L > "$state/aliases"
  print -l ${(k)functions} > "$state/functions"
  "$QUEST_BASH" "$QUEST_HOME/.quest/lib/checker.sh" "$line"
  if [[ -s $state/teleport ]]; then
    to=$(<"$state/teleport")
    rm -f "$state/teleport"
    cd "$to" 2>/dev/null
  fi
}
zshexit() { "$QUEST_HOME/quest" __leave }
