#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (c) 2013-2023 Igor Pecovnik, igor@armbian.com
#
# This file is a part of the Armbian Build Framework
# https://github.com/armbian/build/

## Prepare/cleanup pair @TODO needs to be split between SDCARD and MOUNT, no sense doing both in rootfs trap anymore
# called by artifact-rootfs::artifact_rootfs_prepare_version()
# 准备 rootfs 相关的构建参数和 trap
function prepare_rootfs_build_params_and_trap() {
	# add handler to cleanup when done or if something fails or is interrupted.
	# 建立出错调用函数，出错时候会调用 trap_handler_cleanup_rootfs_and_image
	add_cleanup_handler trap_handler_cleanup_rootfs_and_image

	# stage: clean and create directories
	# 清除掉之前创建的目录
	run_host_command_logged rm -rfv "${SDCARD}" "${MOUNT}"
	run_host_command_logged mkdir -pv "${SDCARD}" "${MOUNT}" "${SRC}/cache/rootfs" "${DEST}/images" # @TODO images needs its own trap

	# stage: verify tmpfs configuration and mount
	# CLI needs ~2GiB, desktop ~5GiB
	# vs 60% of "available" RAM (free + buffers + magic)
	# 声明一个整型变量，用来存储空余的 RAM
	declare -i available_physical_memory_mib
	available_physical_memory_mib=$(($(awk '/MemAvailable/ {print $2}' /proc/meminfo) * 6 / 1024 / 10)) # MiB

	# @TODO: well those are very... arbitrary numbers. At least when using cached rootfs, we can be more precise.
	# predicting the size of tmpfs is hard/impossible, so would be nice to show the used size at the end so we can tune.
	declare -i tmpfs_estimated_size=2300                     # MiB - bumped from 2000, empirically
	# 如果带有桌面环境的 rootfs ,估计需要 5000M 的tmpfs
	[[ $BUILD_DESKTOP == yes ]] && tmpfs_estimated_size=5000 # MiB

	declare use_tmpfs=no                      # by default
	if [[ ${FORCE_USE_RAMDISK} == no ]]; then # do not use, even if it fits
		display_alert "Not using tmpfs for rootfs" "due to FORCE_USE_RAMDISK=no" "info"
	elif [[ ${FORCE_USE_RAMDISK} == yes || ${available_physical_memory_mib} -gt ${tmpfs_estimated_size} ]]; then # use, either force or fits
		# 会走到这里，使用 ramdisk , tmpfs 来构建 rootfs
		use_tmpfs=yes
		display_alert "Using tmpfs for rootfs build" "RAM available: ${available_physical_memory_mib}MiB > ${tmpfs_estimated_size}MiB estimated" "info"
	else
		display_alert "Not using tmpfs for rootfs" "RAM available: ${available_physical_memory_mib}MiB < ${tmpfs_estimated_size}MiB estimated" "info"
	fi

	declare -g -i tmpfs_estimated_size="${tmpfs_estimated_size}"
	declare -g -i available_physical_memory_mib="${available_physical_memory_mib}"

	if [[ $use_tmpfs == yes ]]; then
		# 挂载 tmpfs 到 SDCARD 指定的目录
		# 简单来说就是创建一个临时的目录用来保存 rootfs 相关的内容
		sudo mount -t tmpfs -o "size=99%" tmpfs "${SDCARD}" # size=50% is the Linux default, but we need more.
		sudo chown -R red:red "${SDCARD}"
		# this cleaned up by trap_handler_cleanup_rootfs_and_image, configured above
	fi
}

function trap_handler_cleanup_rootfs_and_image() {
	display_alert "Cleanup for rootfs and image" "trap_handler_cleanup_rootfs_and_image" "cleanup"

	debug_tmpfs_show_usage "before cleanup of rootfs"

	cd "${SRC}" || echo "Failed to cwd to ${SRC}" # Move pwd away, so unmounts work
	# those will loop until they're unmounted.
	umount_chroot_recursive "${SDCARD}" "SDCARD" || true
	umount_chroot_recursive "${MOUNT}" "MOUNT" || true

	# unmount tmpfs mounted on SDCARD if it exists. #@TODO: move to new tmpfs-utils scheme
	mountpoint -q "${SDCARD}" && umount "${SDCARD}"

	[[ $CRYPTROOT_ENABLE == yes ]] && cryptsetup luksClose "${ROOT_MAPPER}"

	if [[ "${PRESERVE_SDCARD_MOUNT}" == "yes" ]]; then
		display_alert "Preserving SD card mount" "trap_handler_cleanup_rootfs_and_image" "warn"
		return 0
	fi

	# shellcheck disable=SC2153 # global var.
	if [[ -b "${LOOP}" ]]; then
		display_alert "Freeing loop" "trap_handler_cleanup_rootfs_and_image ${LOOP}" "wrn"
		free_loop_device_insistent "${LOOP}" || true
	fi

	[[ -d "${SDCARD}" ]] && rm -rf --one-file-system "${SDCARD}"
	[[ -d "${MOUNT}" ]] && rm -rf --one-file-system "${MOUNT}"
	[[ -f "${SDCARD}".raw ]] && rm -f "${SDCARD}".raw

	return 0 # short-circuit above, so exit clean here
}
