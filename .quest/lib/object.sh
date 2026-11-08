#!/usr/bin/env bash
# Runs a story object (a file that does something when run): object.sh <adventure> <object> [its arguments].
# Every object file hands itself here on its second line; the rest of the file is what the story shows when read.
# shellcheck disable=SC1090,SC1091
. "$QUEST_HOME/.quest/lib/quest-lib.sh"
q_load "$1" || exit 127
QS_OBJECT_PATH="$2"
shift 2
QS_STDIN=''
[ -t 0 ] || QS_STDIN=$(cat)
qs_object "$QS_OBJECT_PATH" "$@"
