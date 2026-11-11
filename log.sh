# shellcheck shell=bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Canonical Ltd.
#
# log.sh - shared look of the action's output, sourced by its bash steps
#
# GitHub shows ANSI colours in job logs, and folds the lines between
# ::group:: and ::endgroup:: into one line that opens on a click. Groups do
# not nest: a group opened inside another closes it. The fold is shown with a
# triangle, so the marks here are never triangles or arrows, which would look
# like folds that do not open: ✔ done, ✘ failed, ⚠ warning, • information,
# and spread-output's ◆ for a task being executed.

c_reset=$'\e[0m'
c_dim=$'\e[2m'
c_red=$'\e[1;31m'
c_green=$'\e[1;32m'
c_yellow=$'\e[1;33m'
c_blue=$'\e[1;34m'
c_cyan=$'\e[1;36m'

# section TITLE: a heading, with a line of space before it.
section() {
	printf '\n%s━━ %s ━━%s\n' "$c_blue" "$*" "$c_reset"
}

# info, ok, warn, fail MESSAGE: a line of one kind, coloured as such.
info() {
	printf '%s•%s %s\n' "$c_cyan" "$c_reset" "$*"
}
ok() {
	printf '%s✔ %s%s\n' "$c_green" "$*" "$c_reset"
}
warn() {
	printf '%s⚠ %s%s\n' "$c_yellow" "$*" "$c_reset"
}
fail() {
	printf '%s✘ %s%s\n' "$c_red" "$*" "$c_reset"
}

# group TITLE, endgroup: fold the lines in between.
group() {
	echo "::group::$*"
}
endgroup() {
	echo "::endgroup::"
}

# elapsed SECONDS: SECONDS as 1m05s.
elapsed() {
	if [ "$1" -ge 60 ]; then
		printf '%dm%02ds' $(($1 / 60)) $(($1 % 60))
	else
		printf '%ds' "$1"
	fi
}

# plain: copy standard input to standard output as text the job log shows
# as it is. Colours stay. Every other terminal control sequence goes, such
# as the screen clearing and cursor movement of a virtual machine's
# firmware on its console, which the log does not understand and which
# breaks its folds, and so do other control characters. A carriage return
# that does not end a line starts a new one, as it would on a terminal.
plain() {
	perl -pe 'BEGIN { $| = 1 }
		s/\e\[[0-9;:=?<>]*[ -\/]*[\@-ln-~]//g;
		s/\e\][^\a\e]*(?:\a|\e\\)//g;
		s/\e[()*+][0-9A-Za-z]//g;
		s/\e[=>78cDEHMNOZ]//g;
		s/\r+$//;
		s/\r/\n/g;
		s/[\x00-\x08\x0b\x0c\x0e-\x1a\x1c-\x1f\x7f]//g;'
}

# folded TITLE COMMAND...: run COMMAND with its output folded under TITLE,
# then say how it went and how long it took. When COMMAND fails, the last
# lines of its output are shown again, unfolded, after the group, as that is
# where the reason usually is. Returns the exit status of COMMAND.
#
# The output goes through plain, and runner commands are turned off while
# it is shown (::stop-commands::), so that nothing COMMAND or a virtual
# machine it boots prints, such as ::endgroup::, acts on the log.
folded() {
	local title="$1" out status start token
	shift
	out="$(mktemp)"
	start=$SECONDS
	token="folded-$RANDOM$RANDOM$RANDOM"
	group "$title"
	echo "::stop-commands::$token"
	set +e
	"$@" 2>&1 | plain | tee "$out"
	status=${PIPESTATUS[0]}
	set -e
	echo "::$token::"
	endgroup
	if [ "$status" -eq 0 ]; then
		ok "$title ($(elapsed $((SECONDS - start))))"
	else
		fail "$title failed with exit status $status ($(elapsed $((SECONDS - start)))); the last lines of its output:"
		tail -n 40 "$out" | sed "s/^/  ${c_dim}│${c_reset} /"
	fi
	rm -f "$out"
	return "$status"
}
