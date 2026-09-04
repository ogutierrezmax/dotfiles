# OpenCode wrapper
# Usage: opencode --sudo [args]  -> launches opencode with sudo permission enabled
opencode() {
  if [[ "$1" == "--sudo" ]]; then
    shift
    OPENCODE_CONFIG_CONTENT='{"permission":{"bash":{"*":"allow","sudo *":"allow"}}}' command opencode "$@"
  else
    command opencode "$@"
  fi
}
