function _run_with_error_log() {
  local bin=$1; shift
  local log_dir="error-logs"
  local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
  local cmd_name=$(echo "$@" | tr ' ' '-' | tr -cd '[:alnum:]-')
  local log_file="${log_dir}/${timestamp}__${cmd_name}.log"

  [[ ! -d "$log_dir" ]] && mkdir -p "$log_dir"

  local tmpfile=$(mktemp)

  export FORCE_COLOR=1
  export NODE_DISABLE_COLORS=0

  # Roda usando o script nativo
  script -q -e -c "command $bin $*" "$tmpfile"
  local exit_code=$?

  # Tratamento inteligente de erros e sinais de encerramento (SIGTERM = 143, SIGINT = 130)
  local has_error=0

  # Se saiu com código de erro real (e não interrupção voluntária/sinais de fechamento)
  if [[ $exit_code -ne 0 && $exit_code -ne 143 && $exit_code -ne 130 ]]; then
    has_error=1
  fi

  # Validação fina: procura termos clássicos de quebra, ignorando se o Next.js terminou em "Ready"
  if grep -qaE 'ELIFECYCLE|ERROR.*exited \(1\)|Command failed with exit code' "$tmpfile" 2>/dev/null; then
    # Se os servidores Next.js chegaram a ficar prontos, provavelmente o erro final foi só o inotify sendo cortado
    if grep -qa "Ready in" "$tmpfile" 2>/dev/null; then
      has_error=0
    else
      has_error=1
    fi
  fi

  if [[ $has_error -eq 1 ]]; then
    {
      echo "Dir: $(pwd)"
      echo "Cmd: $bin $@"
      echo "---"
      # Limpa os caracteres de escape ANSI antes de salvar
      sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" "$tmpfile" | col -b
    } > "$log_file"

    rm -f "$tmpfile"
    echo ""
    echo -e "\e[31m[!] Erro real detectado. Log salvo em: ${log_file}\e[0m"
  else
    rm -f "$tmpfile"
  fi

  return $exit_code
}
