#!/bin/bash

 ########################################################################
 #  MPDQ - The MPD Queuer
 #   by Steven Saus (c)2024
 #   Licensed under the MIT license
 #
 ########################################################################

########################################################################
# Definitions
########################################################################
VERSION=2.3.0

# This is an awful hack
if [ "$UID" == "0" ];then 
    loud "MPDQ is running as root. Note that /usr/local/share and"
    loud "/usr/local/state are being used as XDG directories."
    export XDG_CONFIG_HOME=/usr/local/share
    export XDG_STATE_HOME=/usr/local/state
fi

# Setting them here, will create if needed later
ConfigDir=${XDG_CONFIG_HOME:-$HOME/.config}/mpdq
StateDir=${XDG_STATE_HOME:-$HOME/.local/state}/mpdq
CacheDir=${XDG_CACHE_HOME:-$HOME/.local/state}/mpdq
# Defining some things. This is NOT the instruction file.
ConfigFile=${ConfigDir}/mpdq.ini
# This is used to communicate with running background program, including killing and instruction file changes
RelayName=${StateDir}/mpdq_cmd
# This file will contain time song was played, its filename, the album, and artist
ConfigLogFile=${StateDir}/playedsongs.log
ConfigLogFile2=${StateDir}/playedsongs2.log

# Global variables 
export SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
grep_bin=$(which grep)
MPDBASE=""
MPD_HOST=""
MPD_PASS=""
MPD_PORT=""
# How long the playlist should be
PLAYLIST_TRIGGER=""
# How long before a song/genre gets purged from the log, IN HOURS
ROTATE_TIME=""
# Longest time to not hear a song again. Must be LONGER than MAXIMUM "no repeat" 
# time for album and artist
NOREPLAY_ROTATE_TIME=""
# How long before a particular album or artist can be played again. SEPARATE
# from the main log, and should be SHORTER than NO_REPLAY_TIME. IN MINUTES  These 
# will be checked 
# dynamically against the current logfile for thier individual time periods.
ALBUM_MINS=""
ARTIST_MINS=""
# How long a song can be to be considered for the queue, in seconds
SONGLENGTH=""
# What tool to use to get song length
MUSICINFO=""
# Where you're getting instructions from
InstructionFile=""
# Default priority for GENRE weight
DefaultPriority=1
NUMGENRES=""
# noisy feedback or not?
LOUD=0
# if we have exhausted all available options, shorten logrotate time temporarily
EMERGENCY_ROTATE=0
# initialize choosing array 
export ChooseGenre=()


########################################################################
# Temporary Directories
########################################################################

SongFileToAdd=""

########################################################################
# Functions
########################################################################

function loud() {
    if [ $LOUD -eq 1 ];then
        echo "$@"
    fi
}

function already_running {
    if [ -f "${StateDir}"/mpdq.pid ];then
        checkpid=$(head -n 1 "${StateDir}"/mpdq.pid)
        bob=$(ps aux | grep -e " ${checkpid} "| grep -c "mpdq")
        if [ "${bob}" -gt 0 ];then
            loud "mpdq is already running with PID ${checkpid}." >&2
            exit 97
        else
            loud "stale mpdq.pid file found, deleting"
            rm -rf "${StateDir}"/mpdq.pid
        fi
    fi
}

function show_help {
    echo "mpdq [-c /path/to/file][-khe]"
    echo "  -c [instruction file to use]"
    echo "  -k Kill existing mpdq process "
    echo "  -e Create example instruction file "
    echo "  -h Show this help message"
    echo "  -f Force MPD to have the right playback settings"    
    echo "  --loud get more feedback on mpdq's execution"
}

function init_config() {
    if [ ! -d "$ConfigDir" ];then
        mkdir -p "$ConfigDir"
    fi
    if [ ! -d "$StateDir" ];then
        mkdir -p "$StateDir"
    fi

    if [ ! -d "$CacheDir" ];then
        mkdir -p "$CacheDir"
    fi
    if [ ! -f "$ConfigLogFile" ];then 
        touch "$ConfigLogFile"
    fi
    if [ ! -f "$ConfigLogFile2" ];then 
        touch "$ConfigLogFile2"
    fi

}

function read_variables() {
    if [ -f "$ConfigFile" ];then 
        config=$(cat "$ConfigFile")
    else
        loud "Configuration file not found; using defaults."
    fi
    # If there's no config file or a line is malformed or missing, sub in the default value

    MPDBASE="$(echo "$config" | ${grep_bin} -e "^musicdir=" | cut -d = -f 2- ||
        cat "$XDG_CONFIG_HOME/mpd/mpd.conf" | ${grep_bin} "^music" | cut -d'"' -f2 ||
        echo $HOME/Music)"
    MPD_HOST="$(echo "$config" | ${grep_bin} -e "^mpdserver=" | cut -d = -f 2- || echo localhost)"
    MPD_PASS=$(echo "$config" | ${grep_bin} -e "^mpdpass=" | cut -d = -f 2-) &&
    MPD_HOST="$MPD_PASS@$MPD_HOST"
    MPD_PORT=$(echo "$config" | ${grep_bin} -e "^mpdport=" | cut -d = -f 2- || echo 6600)
 
    if [[ `echo "$config" | ${grep_bin} -c -e "^queuesize="` -gt 0 ]];then PLAYLIST_TRIGGER=$(echo "$config" | ${grep_bin} -e "^queuesize=" | cut -d = -f 2- );else PLAYLIST_TRIGGER="10";fi
    if [[ `echo "$config" | ${grep_bin} -c -e "^rotate_time="` -gt 0 ]];then ROTATE_TIME=$(echo "$config" | ${grep_bin} -e "^rotate_time=" | cut -d = -f 2- );else ROTATE_TIME="8";fi
    if [[ `echo "$config" | ${grep_bin} -c -e "^no_replay_rotate="` -gt 0 ]];then NOREPLAY_ROTATE_TIME=$(echo "$config" | ${grep_bin} -e "^no_replay_rotate=" | cut -d = -f 2- );else NOREPLAY_ROTATE_TIME="8";fi
    if [[ `echo "$config" | ${grep_bin} -c -e "^album_mins="` -gt 0 ]];then ALBUM_MINS=$(echo "$config" | ${grep_bin} -e "^album_mins=" | cut -d = -f 2- );else ALBUM_MINS="15";fi
    if [[ `echo "$config" | ${grep_bin} -c -e "^artist_mins="` -gt 0 ]];then ARTIST_MINS=$(echo "$config" | ${grep_bin} -e "^artist_mins=" | cut -d = -f 2- );else ARTIST_MINS="15";fi    
    if [[ `echo "$config" | ${grep_bin} -c -e "^songlength="` -gt 0 ]];then SONGLENGTH=$(echo "$config" | ${grep_bin} -e "^songlength=" | cut -d = -f 2- );else SONGLENGTH="15";fi

    
    # Determining where/how to assess song length
    if [[ `echo "$config" | ${grep_bin} -c -e "^musicinfo="` -gt 0 ]];then 
        MUSICINFO=$(echo "$config" | ${grep_bin} -e "^musicinfo=" | cut -d = -f 2- )
    else 
        if [ -f $(which ffprobe) ];then
            MUSICINFO=ffprobe
        else
            if [ -f $(which exiftool) ];then
                MUSICINFO=exiftool
            else
                if [ -f $(which mp3info) ];then
                    MUSICINFO=mp3info
                else
                    MUSICINFO=""
                fi
            fi
        fi
    fi
    NUMGENRES=$(mpc --host $MPD_HOST --port $MPD_PORT list genre | wc -l)

}

function rotate_songlog {
    
    if [ -f "$ConfigLogFile" ];then
        tempfile=$(mktemp)
        currenttime=$(TZ=UTC0 printf '%(%s)T\n' '-1')
        difftime=$(( "$ROTATE_TIME" * 60 * 60 ))
        # Cuts the diff time in quarter; should handle most cases
        if [ ${EMERGENCY_ROTATE} -ne 0 ];then
            difftime=$(( "$difftime" / 4 ))
        fi
        hightime=$(( "$currenttime"-"$difftime" ))
        loud "Eliminating song log entries older than $ROTATE_TIME hours."
        #echo "$hightime / $difftime"
        cat "$ConfigLogFile" | awk -F '@@@' -v hightime="$hightime" '$1 > hightime'  > "$tempfile"
        mv -f "$tempfile" "$ConfigLogFile"
    else
        touch "$ConfigLogFile"
    fi
    if [ -f "$ConfigLogFile2" ];then
        tempfile=$(mktemp)
        currenttime=$(TZ=UTC0 printf '%(%s)T\n' '-1')
        difftime=$(( "$NOREPLAY_ROTATE_TIME" * 60 * 60 ))
        # Cuts the diff time in quarter; should handle most cases
        if [ ${EMERGENCY_ROTATE} -ne 0 ];then
            difftime=$(( "$difftime" / 4 ))
        fi
        hightime=$(( "$currenttime"-"$difftime" ))
        loud "Eliminating song log entries older than $NOREPLAY_ROTATE_TIME hours."
        #echo "$hightime / $difftime"
        cat "$ConfigLogFile2" | awk -F '@@@' -v hightime="$hightime" '$1 > hightime'  > "$tempfile"
        mv -f "$tempfile" "$ConfigLogFile2"
    else
        touch "$ConfigLogFile2"
    fi
    
}

function create_example(){
    ExampleFile="$ConfigDir/default_example.cfg"
    loud "Default=1" > "${ExampleFile}"
    mpc --host $MPD_HOST --port $MPD_PORT list genre | sed 's/$/=1/' >> "${ExampleFile}"
    loud "Example config placed at ${ExampleFile}"
    exit
}

function killing(){
    # This is probably overkill at this point, as we are avoiding subprocesses.
    while read VPID; do
        if [ $VPID != "$$" ];then
            kill -9 "$VPID" &> /dev/null
        fi
    done < /tmp/mpdq.pid
    rm /tmp/mpdq.pid
 
    exit
}

function read_our_relay {
    # this is intentionally simple at this point, only the most recent thing in,
    # then wipe it clean, if it doesn't parse, then yeet it.
    relay_command=(tail -1 "${RelayName}")
    rm -rf "${RelayName}"
    case ${relay_command} in
        kill) killing ;;
        *) 
            if [ -f "${relay_command}" ];then 
                InstructionFile="${relay_command}"
            fi
            ;;
    esac
}

function choose_next_song {
 
    SongFileToAdd=""
    GenreNumber=""
    OkayGenre=""
    
    
## NEED TO CHECK FOR SPLIT AND WHITESPACE FOR GENRE NAMES
    counter=1 # this is so that if we go through ALL the genres in an hour, it'll just go ahead anyway

    while [ -z "${OkayGenre}" ] && [ ${counter} -lt ${NUMGENRES} ] 
    do
        OIFS=$IFS
        IFS=$'\n'

        loud "Search run ${counter} of ${NUMGENRES}"
        TimesPlayed=""
        InInstruction=""
        GenreName=""
        CurrWeight=""
        # changing this to checking our array --  bot with number and what variable it spits back       
        #get random number for genre
        GenreNumber=$(shuf -i 1-${#ChooseGenre[@]} -n 1)            
        GenreName="${ChooseGenre[$GenreNumber]}"
        loud "Examining ${GenreName}"
        # Genre name is just a straight search of the logfile, as the rotation should fix this
        TimesPlayed=$(cat "${ConfigLogFile}" | sed -n /"@${GenreName}@"/p | wc -l)
        if [ -f "${InstructionFile}" ];then
            DefaultPriority=$(${grep_bin} -i -e "Default=" "${InstructionFile}" | cut -d = -f 2-)
            if [ "$DefaultPriority" == "" ];then
                DefaultPriority=0
            fi
            # switched to sed & wc -l due to spaces and stuff
            InInstruction=$(sed -n /"${GenreName}"/p "${InstructionFile}" "${InstructionFile}" | wc -l)
            if [ ${InInstruction} -eq 0 ];then
                CurrWeight=${DefaultPriority}
            else
                CurrWeight=$(sed -n /^"${GenreName}="/p "${InstructionFile}" | cut -d = -f 2-)
            fi
        else
            # this will take the default default priority of 1 for all genres if no instruction file foudn
            CurrWeight=${DefaultPriority}
        fi
        loud "Default ${DefaultPriority} :: Played ${TimesPlayed} :: Weight ${CurrWeight}"
        
        # does this need to be changed to a > ??? with quotes?
        
        if [[ ${TimesPlayed} -lt ${CurrWeight} ]];then
            # Use shuf to get us a random song from that genre
            SongStem=$(mpc --host "${MPD_HOST}" --port "${MPD_PORT}" find genre "${GenreName}" | shuf -n1 )
            # We will also use $SongFile as a continuing check 
            SongFile="$MPDBASE/$SongStem"
            #check selected song length
            length=""
            # The funky formatting is so that if a full path is specified, it'll still match. 
            
            SongInfo=$(mpc --format "%time%§%album%§%albumartist%" --host "${MPD_HOST}" --port "${MPD_PORT}" find filename "${SongStem}")
            hourcheck=$(echo "${SongInfo}" | awk -F '§' '{ print $1 }'| grep -c -e '\:'  )
            if [ $hourcheck -eq 1 ];then
                length=$(echo "${SongInfo}" | awk -F '§' '{print $1 }' | awk -F ':' '{print $1}')
            else
                length=$(echo "${SongInfo}" | awk -F '§' '{print $1 }' | awk -F ':' '{sum += 60*$1} {sum += $2 } END {print sum}')
            fi
            album=$(echo "${SongInfo}" | awk -F '§' '{print $2 }' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            artist=$(echo "${SongInfo}" | awk -F '§' '{print $3 }' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            if [ -z $length ];then
                loud "No song duration found. Do we have ffmpeg or exiftool?"
                length="0"
            fi
            if [ $length -gt $SONGLENGTH ];then
                loud "Song too long; kicking back"
                SongFile=""
            fi
            if [ -f "${SongFile}" ];then  # if it hasn't been rejected
                # Genres to omit from album/artist checking (because there's only a few in that genre)           
                DontCheckAlbumOrArtistTime=$(sed -n /^genres_exclude_album_check=/p "${ConfigFile}" | cut -d = -f 2-)
                if [[ $DontCheckAlbumOrArtistTime == *"${GenreName}" ]];then
                    currenttime=$(TZ=UTC0 printf '%(%s)T\n' '-1')
                    difftime=$(( "$ARTIST_MINS" * 60 )) #they're in minutes
                    difftime2=$(( "$ALBUM_MINS" * 60 )) #they're in minutes
                    # No need for difftime3 - it's literally the entire file
                    hightime=$(( "$currenttime"-"$difftime" ))
                    hightime2=$(( "$currenttime"-"$difftime2" ))
            
                    # because of quoting, artists with spaces may provide extra hits using grep counting.
                    # so we're going to use wc -l to count LINES returned which should hopefully help
            
                    if [[ `cat "$ConfigLogFile2" | awk -F '@@@' -v hightime="$hightime" '$1 > hightime' | grep -e "@${artist}@" | wc -l` > -gt ]];then echo "Artist found in log: ${artist}"; SongFile="";fi 
                    if [[ `cat "$ConfigLogFile2" | awk -F '@@@' -v hightime="$hightime2" '$1 > hightime' | grep -e "@#${album}@" | wc -l` -gt 0 ]] ;then echo "Album found in log: ${album}"; SongFile="";fi
                    if [[ `cat "$ConfigLogFile2" | grep -e "@#${SongFile}@" | wc -l` -gt 0 ]] ;then echo "Song found in log: ${album}"; SongFile="";fi
                fi
            fi           
        else 
            loud "Used up ${GenreName}"
            GenreName=""
            SongFile=""
        fi
        
        if [ -f "${SongFile}" ];then
            # adding to logfile here because we have the function variables here
            SongFileToAdd="$SongFile"
            #mark that we used it.
            nowtime=$(TZ=UTC0 printf '%(%s)T\n' '-1')
            echo "$nowtime@@@${SongFileToAdd}@${GenreName}@${artist}@#${album}" >> "$ConfigLogFile"
            echo "$nowtime@@@${SongFileToAdd}@${GenreName}@${artist}@#${album}" >> "$ConfigLogFile2"
            loud "Adding song from ${album} by ${artist} in the ${GenreName} genre."
                
            # at end to close out do-while loop
            OkayGenre="${GenreName}"
        else
            loud "Iteration!"
            ((counter++))
        fi
        if [ ${counter} -eq ${NUMGENRES} ];then
            EMERGENCY_ROTATE=1
            rotate_songlog
            EMERGENCY_ROTATE=0
        fi
    done    
    IFS=$OIFS
#TODO - What happens if it maxes the counter ( -- maybe reset the logfiles?)
}



function need_next_song {
    SongFileToAdd=""
    loud "Using instruction file at ${InstructionFile}"
    #until it returns a valid match
    while [ -z "$SongFileToAdd" ];do
        choose_next_song
    done
    
    SongFileToAdd=${SongFileToAdd#$MPDBASE/}

    `mpc --host $MPD_HOST --port $MPD_PORT add "$SongFileToAdd"`
    #reset match tests
    SongFileToAdd=""
}

function main {

    rotate_songlog


    
    if [ -f ${RelayName} ];then 
        read_our_relay
    fi
    # Messy, but closes all subprocesses out
    if [ ! -f /tmp/mpdq.pid ];then
        killing
    fi        
    
    playlist_length=$(mpc --host $MPD_PASS@$MPD_HOST --port $MPD_PORT playlist | wc -l)
    
    while [[ $playlist_length -lt $PLAYLIST_TRIGGER ]]; do
        need_next_song
        playlist_length=$(mpc --host $MPD_PASS@$MPD_HOST --port $MPD_PORT playlist | wc -l)
    done

# TODO - change this into an idle loop.  Since we read the instructionfile 
# dynamically now, it won't matter if we point it in a different direction through
# the relay.  


}

########################################################################
# Wherein we parse arguments
########################################################################
init_config
read_variables


while [ $# -gt 0 ]; do
option="$1"
    case $option in
        --loud|-l) 
            export LOUD=1
            shift
            ;;             
        -e) create_example
            exit
            ;;
        -c) already_running  # should abort if already running
            shift
            InstructionFile="$1"
            shift
            ;;
        -h)
            show_help
            exit
            ;;
        -r) 
            shift
            echo "$1" > ${RelayName}
            loud "${1} sent to mpdq relay file"
            exit
            ;;
        -f)
            mpc --host $MPD_HOST --port $MPD_PORT --quiet consume on
            mpc --host $MPD_HOST --port $MPD_PORT --quiet random off        
            ;;
        -k)
            already_running
            echo "kill" > ${RelayName}
            loud "Kill command sent to relay."
            # TODO - sleep here, wait to see if pidfile needs reaping
            ;;            
            
    esac    
done

# switch off if not set -- whoops.  
test_string=$(mpc --host $MPD_PASS@$MPD_HOST --port $MPD_PORT | tail -1)
# using xargs to strip whitespace here
random=$(echo "${test_string}" | awk -F 'random: ' '{print $2}' | awk '{print $1}')
repeat=$(echo "${test_string}" | awk -F 'repeat: ' '{print $2}' | awk '{print $1}')
consume=$(echo "${test_string}" | awk -F 'consume: ' '{print $2}' | awk '{print $1}')
if [ "$random" != "off" ] || [ "$repeat" != "off" ] || [ "$consume" != "on" ];then
    loud "Aborting run due to MPD settings being"
    loud "random: $random"
    loud "repeat: $repeat"
    loud "consume: $consume"
    exit 97
fi

# Normal operation, so check for already running, then write our PID
already_running
echo "$$" >> /tmp/mpdq.pid

# rotation now included in loop.

if [ ! -f "${InstructionFile}" ];then
    if [ -f "${ConfigDir}/default.cfg" ];then
        InstructionFile="${ConfigDir}/default.cfg"
    fi
fi

if [ -f "${InstructionFile}" ];then
     DefaultPriority=$(${grep_bin} -i -e "Default=" "${InstructionFile}" | cut -d = -f 2-)
    if [ "$DefaultPriority" == "" ];then
        DefaultPriority=0
    fi

fi 
  
loud "Loading instruction file commands"
# go through list of genres from mpc/mpd
while read -r line; do    
    # is it in our instruction file?
    CG="${line}"
    InInstruction=$(sed -n /^"${CG}"=/p "${InstructionFile}" "${InstructionFile}" | wc -l)
    if [ ${InInstruction} -eq 0 ];then
        # if not, weight=default
        CurrWeight=${DefaultPriority}
    else
        # if so, weight=value from instruction file    
        # tail included to catch in case there's a duplicate instruction, takes last
        CurrWeight=$(sed -n /^"${CG}="/p "${InstructionFile}" | tail -n 1 |cut -d = -f 2-)
    fi
    i=1
    # adds genre name to the array a number of times equal to the weight, so the RNG
    # has more of a chance to select it.
    loud "Adding ${CurrWeight}:${CG}"
    while [ $i -le $CurrWeight ];do
        ChooseGenre+=("${line}")
        ((i++))
    done
done < <(mpc --host $MPD_HOST --port $MPD_PORT list genre)


main

rm -rf /tmp/mpdq.pid
