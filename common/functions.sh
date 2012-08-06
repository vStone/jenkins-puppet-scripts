## check_for_bash
#  Returns '0' if the script is running under bash
#  Returns '1' if it doesn't.
function check_for_bash() {
  pid=$$;
  if [[ -f "/proc/${pid}/cmdline" ]]; then
    if [[ -z $( cat "/proc/${pid}/cmdline" | sed "s|$0||g" | grep "bash" ) ]]; then
      return 1;
    else
      return 0;
    fi;
  fi;
}
