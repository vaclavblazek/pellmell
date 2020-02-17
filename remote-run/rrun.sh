#!/bin/bash

# Copyright (c) 2020 Vaclav Blazek <vaclav.blazek@gmail.com>
# All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:

# 1. Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.

# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.

# 3. Neither the name of the copyright holder nor the names of its contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

declare -A SCHROOT hash

CONFFILE="${HOME}/.rrun.conf"

test -f "${CONFFILE}" && source "${CONFFILE}"

# comment out to see diagnostics
NODEBUG=1

function debug() {
    if test -z "${NODEBUG}"; then
        echo "rrun: debug: $*" > /dev/stderr
    fi
}

function error() {
    echo "rrun: error: $*" > /dev/stderr
    exit 255
}

system=$(uname -s)

# canonical path
path="$(pwd)"
path=$(readlink -f "${path}")
info=( $(findmnt $(stat -c %m "$path") | tail -n1) )
fstype="${info[2]}"

function process_mount_point() {
    # mount point and source
    mpoint="${info[0]}"
    source="${info[1]}"

    IFS=':' host_path=( ${source} )
    host="${host_path[0]}"
    remote_root="${host_path[1]}"
    schroot="${SCHROOT[$mpoint]}"

    if test "${#remote_root}" -eq 0; then
        remote_root="~"
    fi

    local_path=${path/${mpoint}/}
    remote_path=$(echo ${remote_root}${local_path} | tr -s /)
    local_mount=${mpoint}

    ${1-echo} "cwd: ${path}"
    ${1-echo} "username@host: ${host}"
    ${1-echo} "remote_root: ${remote_root}"
    ${1-echo} "local_mount: ${local_mount}"
    ${1-echo} "local_path: ${local_path}"
    ${1-echo} "remote_path: ${remote_path}"
    ${1-echo} "schroot: ${schroot}"
}

function fix_paths() {
    if test "${WINDOWS:-0}" -gt 0; then
        args="s|\\\\|/|g;s|[cC]:/|/mnt/c/|g;s|users|Users|g;s|program files|Program Files|g;s|${remote_path}|${path}|g"
    else
        args="s|${remote_path}|${path}|g"

        if test "${remote_root}" = "/"; then
            args="${args};s|/usr/include|${local_mount}/usr/include|g"
            args="${args};s|/usr/lib|${local_mount}/usr/lib|g"
            args="${args};s|/usr/local|${local_mount}/usr/local|g"
        fi
    fi

    sed "${args}"
}

function mode_check() {
    if test ${system} != "Linux"; then
        debug "unsupported system (${system})"
        exit 1
    fi

    # find info about mount point

    case "${fstype}" in
        "fuse.sshfs" | "fuse.ssh" )
            exit 0
            ;;
    esac

    debug "path ${path} is not an sshfs path (fs type is ${fstype})"
    exit 1
}

function mode_info() {
    if test ${system} != "Linux"; then
        error "unsupported system (${system})"
    fi

    case "${fstype}" in
        "fuse.sshfs" | "fuse.ssh" )
            ;;

        *)
            error "path ${path} is not an sshfs path (fs type is ${fsytpe})"
            ;;
    esac

    process_mount_point echo

    exit 0
}

function mode_run() {
    if test ${system} != "Linux"; then
        error "unsupported system (${system})"
    fi

    # find info about mount point
    case "${fstype}" in
        "fuse.sshfs" | "fuse.ssh" )
            ;;

        *)
            error "path ${path} is not an sshfs path (fs type is ${fstype})"
            ;;
    esac

    process_mount_point debug

    # filters stdout and stderr via fix_path in parallel
    if test -z "${schroot}"; then
        echo "### Executing \`$@' on remote host ${host}..." > /dev/stderr
        ssh -t ${host} "test -f ~/.rrun.conf && source ~/.rrun.conf; cd ${remote_path}; $@"
    else
        echo "### Executing \`$@' in schroot ${schroot} on remote host ${host}..." > /dev/stderr
        ssh -t ${host} "schroot -pc ${schroot} -- /bin/bash -c \"test -f ~/.rrun.conf && source ~/.rrun.conf; cd ${remote_path}; $@\""
    fi > >(fix_paths) 2> >(fix_paths > /dev/stderr)

    exit $?
}

mode="${1}"
shift

case "${mode}" in
    run)
        mode_run "$@"
        ;;

    check)
        mode_check "$@"
        ;;

    info)
        mode_info "$@"
        ;;

    *)
        error "invalid mode ${mode}"
        ;;
esac
