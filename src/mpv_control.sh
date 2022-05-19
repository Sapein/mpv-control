#!/bin/sh

unset IFS

# Parse Opts
MPV_IPC_SERVER="${MPV_IPC_SERVER:-${XDG_RUNTIME_DIR}/mpvsocket}"
CMDLINE_ENABLED=false
COMMANDS=""

if [ -z $1 ]
then
    $0 --help
    return $?
fi

for opt in ${@}
do
    case $opt in
        --help)
            printf "Usage: mpv-ctrl (options) [commands]\n"
            printf "\n"
            printf "Commands:\n"
            printf "\tplay\n"
            printf "\t\tUnpause (if paused) mpv.\n"
            printf "\tpause\n"
            printf "\t\tPauses (if unpaused) mpv.\n"
            printf "\tmedia-title\n"
            printf "\t\tGets the media title from mpv (May include author)\n"
            printf "\tmetadata\n"
            printf "\t\tGets the metadata for the current track from MPV\n"
            printf "\n"
            printf "Options:\n"
            printf "\t--ipc-path=/path/to/mpv/socket [default:${XDG_RUNTIME_DIR}/mpvsocket]\n"
            printf "\t\tSets the Path to the IPC Socket\n"
            printf "\t--enable-cmdline\n"
            printf "\t\tEnables the cmdline command\n"
            return 0
            ;;
        --ipc-path=*)
            MPV_IPC_SERVER=$(echo "${opt}" | sed -e 's?--ipc-path=\(.*\)?\1?')
            ;;
        --enable-cmdline)
            CMDLINE_ENABLED=true
            ;;
        --*)
            printf "Invalid Options!\n"
            $0 --help
            return 1
            ;;
        *)
            COMMANDS="${COMMANDS} ${opt}"
            ;;
    esac
done

ccmd_r() {
    read cmds
    cmd='{ "command": ['

    for arg in $cmds
    do
        cmd="${cmd} \"${arg}\","
    done

    cmd="${cmd}"' ] }'
    printf "%s" "${cmd}"
}

construct_cmd() (
    cmd='{ "command": ['

    for arg in $@
    do
        cmd="${cmd} \"${arg}\","
    done

    cmd="${cmd}"' ] }'
    printf "%s" "${cmd}"
)

send_cmd() (
    read cmd
    echo $cmd

    echo $cmd | socat - "${MPV_IPC_SERVER}"
)

for cmd in ${COMMANDS}
do
    case $cmd in 
        pause)
            construct_cmd 'set' 'pause' 'yes' | send_cmd > /dev/null
            ;;
        play)
            construct_cmd 'set' 'pause' 'no' | send_cmd > /dev/null
            ;;
        media-title)
            construct_cmd 'get_property' 'media-title' | send_cmd
            ;;
        metadata)
            construct_cmd 'get_property' 'metadata' | send_cmd
            ;;
        percent-pos)
            construct_cmd 'get_property' 'percent-pos' | send_cmd
            ;;
        cmdline)
            # Acts as a commandline client.
            while $("${CMDLINE_ENABLED}")
            do
                read input
                echo $input | ccmd_r | send_cmd
                unset input
            done
            ;;
        *)
            printf "Unknown Command: %s!\n" "${cmd}"
            ;;
    esac
done
