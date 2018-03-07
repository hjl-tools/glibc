#!/bin/bash

# Set to sde64
SDE=
SDE_FLAGS="-future -cet -cet-endbr-exe -cet-syscall \
	   -cet_call_stack -cet_call_stack_depth 40 \
	   -cet_shadow_stack_size 8192 \
"

timeoutfactor=$TIMEOUTFACTOR
while [ $# -gt 0 ]; do
  case "$1" in

    "--timeoutfactor")
      shift
      if [ $# -lt 1 ]; then
        break
      fi
      timeoutfactor="$1"
      ;;

    *)
      break
      ;;
  esac
  shift
done

if [ $# -lt 1 ]; then
  echo "Type '${progname} --help' for more detailed help." >&2
  exit 1
fi

# Print the sequence of arguments as strings properly quoted for the
# Bourne shell, separated by spaces.
bourne_quote ()
{
  local arg qarg
  for arg in "$@"; do
    qarg=${arg//\'/\'\\\'\'}
    echo -n "'$qarg' "
  done
}

for a in "$@"; do
  case $a in
  env)
    ;;
  *=*)
    ;;
  -*)
    ;;
  *)
    prog=$a
    break;
    ;;
  esac
done

# Transform the current argument list into a properly quoted Bourne shell
# command string.
command="$@"

# Add command to set the timeout factor, if required.
if [ "$timeoutfactor" ]; then
  export TIMEOUTFACTOR=$(bourne_quote "$timeoutfactor")
fi

# HOST's sshd simply concatenates its arguments with spaces and
# passes them to some shell.  We want to force the use of /bin/sh,
# so we need to re-quote the whole command to ensure it appears as
# the sole argument of the '-c' option.
$SDE $SDE_FLAGS -cet_output_file ${prog}.cetlog -- $command
