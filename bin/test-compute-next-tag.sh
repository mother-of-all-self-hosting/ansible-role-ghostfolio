#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at Ghostfolio 3.54.0 which has already
# seen two releases of it (v3.54.0-0 and v3.54.0-1), and older releases of
# earlier versions, in this repository's own tag style.
#
# The defaults file deliberately carries the traps this role's real one has: a
# commented-out `ghostfolio_version` line, other variables whose names end in
# `_version`, and variables which merely interpolate the version.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/meta" "$workdir/tasks" "$workdir/templates" "$workdir/docs" "$workdir/molecule/default"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	cat > defaults/main.yml <<-'YAML'
		# ghostfolio_version: 9.9.9
		# renovate: datasource=docker depName=ghostfolio/ghostfolio versioning=semver
		ghostfolio_version: 3.54.0
		ghostfolio_container_image_tag: "{{ ghostfolio_version }}"
		ghostfolio_container_image_self_build_repo_version: "{{ ghostfolio_version if ghostfolio_version != 'latest' else 'main' }}"
	YAML
	printf 'placeholder\n' > meta/main.yml
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md
	printf 'placeholder\n' > docs/configuring-ghostfolio.md
	printf 'placeholder\n' > molecule/default/verify.yml

	git add -A
	git commit -qm 'Initial commit'

	local release_number
	for release_number in 0; do
		git tag "v3.48.1-$release_number"
		git tag "v3.42.0-$release_number"
	done
	for release_number in 0 1; do
		git tag "v3.54.0-$release_number"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version="sed -i 's|^ghostfolio_version: 3.54.0|ghostfolio_version: 3.60.0|' defaults/main.yml"
revert_version="sed -i 's|^ghostfolio_version: 3.60.0|ghostfolio_version: 3.54.0|' defaults/main.yml"
patch_version="sed -i 's|^ghostfolio_version: 3.54.0|ghostfolio_version: 3.54.1|' defaults/main.yml"
prefixed_version="sed -i 's|^ghostfolio_version: 3.54.0|ghostfolio_version: v3.55.0|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_meta="printf 'a line\n' >> meta/main.yml"
edit_readme="printf 'documentation\n' >> README.md"
edit_docs="printf 'documentation\n' >> docs/configuring-ghostfolio.md"
edit_molecule="printf 'an assertion\n' >> molecule/default/verify.yml"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v3.60.0-0 "$(merge "$bump_version")"
expect 'task edit'    v3.60.0-1 "$(merge "$edit_task")"
expect 'template'     v3.60.0-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v3.54.0-2 "$(merge "$edit_task")"
expect 'version bump' v3.60.0-0 "$(merge "$bump_version")"

scenario 'Commits that do not affect what a playbook run does'
expect 'README'    ''         "$(merge "$edit_readme")"
expect 'docs'      ''         "$(merge "$edit_docs")"
expect 'a Molecule assertion' '' "$(merge "$edit_molecule")"
expect 'this script itself' '' "$(merge "$edit_script")"
expect 'role metadata' v3.54.0-2 "$(merge "$edit_meta")"

# Ghostfolio publishes the odd patch release (3.48.1, 3.59.1), and those are
# the ones the //patch-automerge preset would land unattended, so they have to
# come out as a release of their own rather than as a counter bump of 3.54.0.
scenario 'A patch release of the current version'
expect 'patch bump' v3.54.1-0 "$(merge "$patch_version")"
expect 'task edit'  v3.54.1-1 "$(merge "$edit_task")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v3.54.0-$release_number"
done
expect 'a task' v3.54.0-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v3.54.0-1 already published, so there is
# nothing new to release.
expect 'a revert' '' "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v3.54.0-2 "$(merge "$revert_version && $edit_task")"

# Every published tag carries a leading `v` while `ghostfolio_version` does
# not. Should the variable ever be written with one, the tag must not grow a
# second.
scenario 'A version which already carries a v'
expect 'v-prefixed version' v3.55.0-0 "$(merge "$prefixed_version")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
