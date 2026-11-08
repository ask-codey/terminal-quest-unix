# A quest's bash: started by ./quest start, with your home folder as the repo, a prompt that shows where you are, and
# a hook that checks the story after every command. Type exit to leave; quest start puts you back where you were.
# shellcheck disable=SC1091
. "$QUEST_HOME/.quest/lib/hook.bash"
HISTFILE="$QUEST_HOME/.quest/state/$QUEST_ADVENTURE/history"
HISTSIZE=2000
HISTFILESIZE=2000
HISTCONTROL=
HISTTIMEFORMAT=
shopt -s histappend cmdhist
PS1='\[\e[1;32m\]player@quest\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '

quest() { "$QUEST_HOME/quest" "$@"; }

__quest_prompt() {
  local status=$? n line
  history -a
  n=$(HISTTIMEFORMAT= history 1 | awk 'NR == 1 { print $1 }')
  if [ -z "${__quest_ready:-}" ]; then __quest_ready=1; __quest_seen=$n; return 0; fi
  [ -n "$n" ] && [ "$n" != "$__quest_seen" ] || return 0
  __quest_seen=$n
  line=$(HISTTIMEFORMAT= history 1 | sed '1s/^ *[0-9][0-9]*[* ] *//')
  __quest_after "$status" "$line"
}
PROMPT_COMMAND=__quest_prompt
trap '"$QUEST_HOME/quest" __leave' EXIT
