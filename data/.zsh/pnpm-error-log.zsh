# pnpm/npm error logger
# Intercepts pnpm/npm commands, captures output, and saves to file only on error.
# Logs are saved in error-logs/ relative to the current directory.

function _run_with_error_log() {
  local bin=$1; shift
  local log_dir="error-logs"
  local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
  local cmd_name=$(echo "$@" | tr ' ' '-' | tr -cd '[:alnum:]-')
  local log_file="${log_dir}/${timestamp}__${cmd_name}.log"

  [[ ! -d "$log_dir" ]] && mkdir -p "$log_dir"

  local tmpfile=$(mktemp)
  command $bin "$@" 2>&1 | tee "$tmpfile"
  local exit_code=${PIPESTATUS[0]}

  local has_error=0
  [[ $exit_code -ne 0 ]] && has_error=1
  grep -qE 'ELIFECYCLE|ERROR.*exited \(1\)|Command failed with exit code' "$tmpfile" 2>/dev/null && has_error=1

  if [[ $has_error -eq 1 ]]; then
    { echo "Dir: $(pwd)"; echo "Cmd: $bin $@"; echo "---"; cat "$tmpfile"; } > "$log_file"
    rm -f "$tmpfile"
    echo ""
    echo "Erro registrado em: $(pwd)/$log_file"
  else
    rm -f "$tmpfile"
  fi

  return $exit_code
}

function pnpm() { _run_with_error_log pnpm "$@"; }
function npm()  { _run_with_error_log npm "$@"; }
