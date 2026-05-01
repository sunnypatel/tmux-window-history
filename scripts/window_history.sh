#!/usr/bin/env bash
# Guard: only run case dispatch when executed directly (not sourced for tests)
_main() {
  case "${1:-}" in
    push)  cmd_push  "$2" "$3" ;;
    back)  cmd_back  "$2"      ;;
    scrub) cmd_scrub "$2" "$3" ;;
    menu)  cmd_menu  "$2"      ;;
    jump)  cmd_jump  "$2" "$3" ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then _main "$@"; fi
