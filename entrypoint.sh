#!/bin/sh
# Rewrite of the entrypoint.sh by Jan Heinrich Reimer
# See: <https://github.com/heinrichreimer/action-github-changelog-generator>
set -e

##
# utility functions
istrue()
{
	case "$(lower "${1}")" in
	(true|yes|y)	return 0;;
	(*) return 1;;
	esac
}
upper()
{
	if test "$#" -gt '0'; then
		printf '%s' "${*}" | upper
	else
		tr '[a-z]' '[A-Z]'
	fi
}
lower()
{
	if test "$#" -gt '0'; then
		printf '%s' "${*}" | lower
	else
		tr '[A-Z]' '[a-z]'
	fi
}
get_content() { sed -e 's/%/%25/g' -e 's/$\n/%0A/g' -e 's/$\r/%0D/g' < "${1}"; }
get_input() { eval printf '%s' "\${INPUT_$(printf '%s' "${1}" |  tr -d '-' | upper)}"; }
get_optargs()
{
	github_changelog_generator --help | sed  -n -E 's/.*--(\S+)\s+([A-Z]{2,}).*/\1/p'
	github_changelog_generator --help | sed  -n -E 's/.*--(\S+)\s+([a-z](,[a-z])*).*/\1/p'
}
get_toggles()
{
	github_changelog_generator --help | sed -n -E 's/^.*--\[no-\](\S+).*/\1/p'
}
get_flags()
{
	github_changelog_generator --help | sed  -n -E 's/.*\s--([a-z-]+)\s+[A-Z][a-z]+.*/\1/p'
}

# Go to GitHub workspace.
cd "${GITHUB_WORKSPACE:=${PWD}}"

##
# Defaults
: INPUT_REPO="${INPUT_REPO:=${GITHUB_REPOSITORY}}"
: INPUT_USER="${INPUT_USER=${INPUT_REPO%%/*}}"
: INPUT_PROJECT="${INPUT_PROJECT:=${INPUT_REPO#*/}}"
: INPUT_TOKEN="${INPUT_TOKEN:=${GITHUB_TOKEN}}"
if istrue "$INPUT_ONLYLASTTAG"; then
	INPUT_DUETAG=
	INPUT_SINCETAG="$(git describe --abbrev=0 --tags "$(git rev-list --tags --skip=1 --max-count=1)")"
fi

##
# Build arguments.
set --
for input in $(get_optargs); do
	arg="$(get_input "${input}")"
	test -z "${arg}" || set -- "${@}" "--${input}" "${arg}"
done; unset arg
for input in $(get_toggles); do
	val="$(get_input "${input}")"
	if test -n "${val}"; then
		if istrue  "${val}"; then
			set -- "${@}" "--${input}"
		else
			set -- "${@}" "--no-${input}"
		fi
	fi
done; unset val
for input in unreleased-only usernames-as-github-logins simple-list \
	http-cache; do
	val="$(get_input "${input}")"
	! istrue "${val}" || set -- "${@}" "--${input}"
done; unset val

unset input

##
# Generate change log.
# shellcheck disable=SC2086 # We specifically want to allow word splitting.
github_changelog_generator "${@}"


##
# Post process
FILE="${INPUT_OUTPUT:-CHANGELOG.md}"

if test -e "${FILE}"; then
	if istrue "$(get_input strip-headers)"; then
		echo "Stripping headers."
		sed -i '/^#/d' "${FILE}"
	fi

	if istrue "$(get_input strip-generator-notice)"; then
		echo "Stripping generator notice."
		sed -i '/This Changelog was automatically generated/d' "${FILE}"
	fi

	echo "::set-output name=changelog::$(get_content "${FILE}")"
fi
