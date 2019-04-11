#!/bin/bash
#
#   Copyright 2018 Carl Anderson
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
#   Modified by Nick Bradley


# Prevent errors from sourcing this file more than once.
#
# Under some circumstances ASH_SESSION_ID can be set but the functions not
# defined properly, so we explicitly check for the __ash_* functions before
# returning here.
if [[ -n "${ASH_SESSION_ID}" ]]; then
  declare -F |grep -q '__ash_'
  if [[ $? -eq 0 ]]; then
    return
  fi
fi

# Make sure we are running the shell we think we are running.
if ! ps ho command $$ | grep -q "bash"; then
  echo "The shell process name implies you're not running bash..."
  return
fi

# Display error and abort if PROMPT_COMMAND is (already) readonly.
if readonly -p | grep -q "^declare -[[:alpha:]]\+ PROMPT_COMMAND="; then
  if [[ "${PROMPT_COMMAND//__ash_/}" == "${PROMPT_COMMAND}" ]]; then
    echo "aw-watcher-shell ERROR: Make PROMPT_COMMAND writable to enable ActivityWatch tracking."
    return
  fi
fi
export PROMPT_COMMAND='ASH=1 __ash_begin_session'

# HISTCONTROL is emptied primarily to remove the options that de-dupe identical
# successive commands and remove comands with leading spaces from history.
export HISTCONTROL=""
readonly HISTCONTROL

# HISTTIMEFORMAT is changed to unix epoch time to allow easy duration
# calculations by subtracting start from end timestamps.
export HISTTIMEFORMAT="%s "
readonly HISTTIMEFORMAT

# Cause bash to log commands immediately, rather than upon shell exit.
shopt -s histappend

##
# This is invoked when a new user session begins.
#
function __ash_begin_session() {
  # Prevent users from manually invoking this function from the command line.
  [[ "${ASH:-0}" == "0" ]] && __ash_info __ash_begin_session && return

  export PROMPT_COMMAND="ASH=1 __ash_precmd \${?} \${PIPESTATUS[@]}"
  export ASH_SESSION_ID="$( __ash_generate_session_id )"
  readonly ASH_SESSION_ID PROMPT_COMMAND
}


##
# Log the previous command and execute the previous PROMPT_COMMAND (if any)
# afterward.  The previous command exit code is reset after this function.
#
function __ash_precmd() {
  # Do nothing if this variable is set.
  [[ -n "${ASH_DISABLED:-}" ]] && return

  # Prevent users from manually invoking this function from the command line.
  [[ "${ASH:-0}" == "0" ]] && __ash_info __ash_precmd && return

  __ash_log ${@:-0 0}
  history -a
  if typeset -p ASH_PROMPT_COMMAND &>/dev/null; then
    "${ASH_PROMPT_COMMAND}"
  fi
  # Causes the exit code to be reset to what it was before logging.
  local rval=${1:-0} && shift
  PIPEST_ASH=( ${@:-0} )
}


##
# Invoked by __ash_log.
#
function __ash_last_command() {
  # Prevent users from manually invoking this function from the command line.
  [[ "${ASH:-0}" == "0" ]] && __ash_info __ash_last_command && return

  local cmd_no start_ts end_ts="$( date +%s )" cmd
  read -r cmd_no start_ts cmd <<< "$( builtin history 1 )"
  echo ${cmd_no:-0} ${start_ts:-0} ${end_ts:-0} "${cmd:-UNKNOWN}"
}

##
# This is invoked immediately before each new prompt is displayed for the user.
#
# Args:
#   rval: The numeric exit code from the last user-entered command.
#   pipes: The set of pipe exit codes (one or more codes).
#
function __ash_log() {
  # Prevent users from manually invoking this function from the command line.
  [[ "${ASH:-0}" == "0" ]] && __ash_info __ash_log && return

  # ASH_SKIP is set only when the user presses Ctrl-C while entering a command.
  # Since this kills the command before it was executed, there's no history to
  # log before the next prompt is drawn.
  if [[ "${ASH_SKIP:-1}" == "1" ]]; then
    ASH_SKIP=0
    return
  fi

  local no start end cmd rval="${1}" && shift
  read -r no start end cmd <<< "$( __ash_last_command )"
  local pipes="$( sed -e 's: :_:g' <<< "${@}" )"

  local duration=$((${end}-${start}))
  aw_post_event ${duration} ${no} ${rval} "${cmd}"
}



# This avoids logging duplicate commands when the user presses Ctrl-C while
# entering a command.
# Only need to trap Ctrl-C in bash. zsh do not need to do it and no duplicate
# history in zsh. (Ctrl-C will stop works if do the same trap in zsh!)
trap 'ASH_SKIP=1' INT

# Protect the functions.
readonly -f __ash_begin_session
readonly -f __ash_last_command
readonly -f __ash_precmd

# Export functions used by subshells (not begin_session).
#export -f __ash_last_command
#export -f __ash_precmd
