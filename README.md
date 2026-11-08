# Terminal Quest for bash and zsh

Text adventures you play by typing real terminal commands. Every place is a folder and every note, map and treasure is
a file, so you find your way with `pwd`, `ls` and `cd`, read with `cat`, and later move, search, script and automate
your way through the story.

This is the same game as [Terminal Quest on ask-codey.com](https://www.ask-codey.com/games/terminal-quest), played in
your own terminal on your own computer. Online, the game earns XP, treasures and rare coins; here, it's free practice
and keeps a history of your games on your computer.

| # | Adventure | Level | You'll use |
| --- | --- | --- | --- |
| 1 | The Lighthouse | Novice | `pwd`, `ls`, `ls -a`, `cd`, `cat`, `history`, `clear`, Tab |
| 2 | Moving Day | Apprentice | `mkdir`, `cp`, `mv`, `rm`, `rmdir`, `echo >` and `>>`, wildcards, `head`, `tail` |
| 3 | The Archive | Journeyman | pipes, `grep`, `find`, `sort`, `uniq`, `wc`, `cut` |
| 4 | The Clockwork Workshop | Freelancer | `chmod`, `export`, `$PATH`, `alias`, `source`, `&&`, exit codes |
| 5 | Mission Control | Master | scripts, loops, `if`, arguments, `ps`, `kill`, `ln -s`, `xargs` |

## What you need

- **macOS or Linux.** A Mac's Terminal opens zsh; most Linux terminals open bash. Either works, and the game plays in the
  one you use.
- **On Windows**, use WSL (Windows Subsystem for Linux): it's a real Linux. Git Bash plays every adventure too, but
  Windows files don't keep Unix permissions, so the Workshop's permission puzzles are already solved there and
  `chmod` changes nothing. For the full Workshop, use WSL.
- **git**, to clone the repo (or download it as a ZIP from GitHub).

## Play

```bash
git clone https://github.com/ask-codey/terminal-quest-unix.git
cd terminal-quest-unix
./quest start lighthouse
```

The adventure opens in your terminal, with the story at the top. Type commands as you normally would. After each one,
the game tells you what happened in the story: a treasure found, a door opened, the next goal.

While you play:

| Type | What it does |
| --- | --- |
| `quest hint` | A nudge for your next goal. Type it again for more, and a third time to see the command. |
| `quest status` | Your goal, and the treasures you've found. |
| `exit` | Leaves the adventure. `./quest start lighthouse` brings you back where you were. |

Inside an adventure, your home folder (`~`) is this repo, so `cd ~/lighthouse` takes you back to the start of the
Lighthouse from anywhere. Your own home folder, settings and history are untouched, and each adventure keeps its own
command history (`history` shows it).

Everything you can do from the repo's folder:

| Command | What it does |
| --- | --- |
| `./quest list` | The adventures, and how far you've got in each. |
| `./quest start <adventure>` | Plays one: `lighthouse`, `new-place`, `archive`, `workshop`, `mission-control`, or its number. |
| `./quest start <adventure> --bash` | Plays it in bash even if your terminal opens zsh (or `--zsh` the other way). |
| `./quest reset <adventure>` | Starts it again from scratch. `./quest reset --all` resets every adventure you've started. |
| `./quest history` | Every game you've played. `./quest history lighthouse` shows one adventure's. |

## Start again whenever you like

Break things. Delete the wrong file. Move everything into the wrong folder. That's how you learn, and it's safe here:
`./quest reset lighthouse` puts back a fresh copy of the Lighthouse. You don't need git for it.

Your **game history** stays: `game-history.csv`, in the repo's folder, gets a line for every start, treasure, coin,
hint, finish and reset, and a reset never clears it. It's a plain CSV file, so it opens in a spreadsheet, and searching
it with `grep`, `sort` and `cut` is good practice for the Archive:

```bash
grep treasure game-history.csv | cut -d, -f2 | sort | uniq -c
```

## How the game notices what you do

The game checks the real world after every command: which folder you're in, which files and folders exist, their
permissions, the variables you've exported, your aliases, and the programs that are running. Any command that gets
the job done counts, not just the one in the hint.

Reading is the one thing a terminal doesn't leave a trace of, so the game reads the command you typed instead. A file
counts as read when you name it to `cat`, `less`, `more`, `head`, `tail`, `sort` and similar commands, when `grep`
prints a line from it, when you `source` it, or when `find`, `ls` or `grep` hand it to `xargs cat`. A loop that reads
files through a variable (`cat "$f"`) isn't noticed: name the file, and it counts.

## zsh notes

The game works the same in zsh, with two differences you may see:

- A wildcard that matches nothing is an error in zsh (`no matches found`); bash passes it on as it is.
- In the adventures, `#` starts a comment in both shells. (In your own zsh, comments at the prompt are off unless you
  turn them on with `setopt interactive_comments`.)

## Teachers

You're welcome to point students to this repo and to ask-codey.com, and to have them play it in class or as homework.
Please don't copy it into your own material: see [LICENSE](LICENSE). For anything else, ask: <support@ask-codey.com>

## How it's made

The adventures are written once and played in three places: online, here, and in
[terminal-quest-powershell](https://github.com/ask-codey/terminal-quest-powershell). Each adventure's files are in
`.quest/stories/<adventure>/`: `world/` is the fresh copy `start` and `reset` lay out, `story.sh` is the story's
triggers, treasures and goals, and `walkthrough.sh` is the commands the tests play. Those are generated from the online
game's stories, so please report a problem rather than editing them: <support@ask-codey.com>.

The tests play every adventure from start to finish, and then check resets and the history, on Linux and on macOS with
the bash 3.2 that macOS ships. To run them, install [bats](https://github.com/bats-core/bats-core) and type `bats tests`.

Copyright (c) 2026 FullStack Devs. All rights reserved. See [LICENSE](LICENSE).
