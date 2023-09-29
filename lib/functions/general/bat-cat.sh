#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (c) 2013-2023 Igor Pecovnik, igor@armbian.com
#
# This file is a part of the Armbian Build Framework
# https://github.com/armbian/build/

function run_tool_batcat() {
	local BATCAT_BIN=bat
	# If any parameters passed, call ORAS, otherwise exit. We call it this way (sans-parameters) early to prepare ORAS tooling.
	if [[ $# -eq 0 ]]; then
		display_alert "No parameters passed to batcat" "batcat" "debug"
		return 0
	fi

	declare -i bat_cat_columns=$(("${COLUMNS:-"120"}" - 20)) # A bit shorter since might be prefixed by emoji etc
	if [[ "${bat_cat_columns}" -lt 60 ]]; then               # but lever less than 60
		bat_cat_columns=60
	fi
	display_alert "Calling batcat" "COLUMNS: ${bat_cat_columns} | $*" "debug"
	BAT_CONFIG_DIR="${DIR_BATCAT}/config" BAT_CACHE_PATH="${DIR_BATCAT}/cache" "${BATCAT_BIN}" --theme "Dracula" --paging=never --force-colorization --wrap auto --terminal-width "${bat_cat_columns}" "$@"
	wait_for_disk_sync "after running batcat"
}

function try_download_batcat_tooling() {
	display_alert "MACHINE: ${MACHINE}" "batcat" "debug"
	display_alert "Down URL: ${DOWN_URL}" "batcat" "debug"
	display_alert "BATCAT_BIN: ${BATCAT_BIN}" "batcat" "debug"
	display_alert "BATCAT_FN: ${BATCAT_FN}" "batcat" "debug"

	display_alert "Downloading required" "batcat tooling${RETRY_FMT_MORE_THAN_ONCE}" "info"
	run_host_command_logged wget --no-verbose --progress=dot:giga -O "${BATCAT_BIN}.tar.gz.tmp" "${DOWN_URL}" || {
		return 1
	}
	run_host_command_logged mv "${BATCAT_BIN}.tar.gz.tmp" "${BATCAT_BIN}.tar.gz"
	run_host_command_logged tar -xf "${BATCAT_BIN}.tar.gz" -C "${DIR_BATCAT}" "${BATCAT_FN}/bat"
	run_host_command_logged rm -rf "${BATCAT_BIN}.tar.gz"

	# EXTRA: get more syntaxes for batcat. We need Debian syntax for CONTROL files, etc.
	run_host_command_logged wget --no-verbose --progress=dot:giga -O "${DIR_BATCAT}/sublime-debian.tar.gz.tmp" "https://github.com/barnumbirr/sublime-debian/archive/refs/heads/master.tar.gz"
	run_host_command_logged mkdir -p "${DIR_BATCAT}/temp-debian-syntax"
	run_host_command_logged tar -xzf "${DIR_BATCAT}/sublime-debian.tar.gz.tmp" -C "${DIR_BATCAT}/temp-debian-syntax" sublime-debian-master/Syntaxes

	# Prepare the config and cache dir... clean it off and begin anew everytime
	run_host_command_logged rm -rf "${DIR_BATCAT}/config" "${DIR_BATCAT}/cache"
	run_host_command_logged mkdir -p "${DIR_BATCAT}/config" "${DIR_BATCAT}/cache" "${DIR_BATCAT}/config/syntaxes"

	# Move the sublime-debian syntaxes into the final syntaxes dir
	run_host_command_logged mv "${DIR_BATCAT}/temp-debian-syntax/sublime-debian-master/Syntaxes"/* "${DIR_BATCAT}/config/syntaxes/"

	# Delete the temps for sublime-debian
	run_host_command_logged rm -rf "${DIR_BATCAT}/temp-debian-syntax" "${DIR_BATCAT}/sublime-debian.tar.gz.tmp"

	# Finish up, mark done.
	run_host_command_logged mv "${DIR_BATCAT}/${BATCAT_FN}/bat" "${BATCAT_BIN}"
	run_host_command_logged rm -rf "${DIR_BATCAT}/${BATCAT_FN}"
	run_host_command_logged chmod +x -v "${BATCAT_BIN}"
}
