#!/usr/bin/env zsh
# ─────────────────────────────────────────────────────────────
# Smart Terminal — Custom Commands
#
# Add your own command patterns here. These are checked BEFORE
# the built-in dictionary, so you can override defaults too.
#
# This file is never overwritten by updates or reinstalls.
#
# HOW TO ADD A COMMAND:
#   The function receives a lowercased query string.
#   Match patterns with case/esac and echo the command.
#   Return 0 if matched, return 1 if not (falls through to built-in).
#
# EXAMPLES:
#   *"deploy"*"staging"*)
#       echo "kubectl apply -f k8s/staging/"; return 0 ;;
#   *"my server"*|*"start server"*)
#       echo "cd ~/myproject && npm run dev"; return 0 ;;
#   *"vpn"*)
#       echo "open -a 'Cisco AnyConnect'"; return 0 ;;
# ─────────────────────────────────────────────────────────────

_st_custom_lookup() {
    local q="${(L)1}"  # lowercase the query

    case "$q" in
        # ─── Add your custom commands below ───

        # Example: deploy to staging
        # *"deploy"*"staging"*)
        #     echo "kubectl apply -f k8s/staging/"; return 0 ;;

        # Example: open your main project
        # *"my project"*|*"open project"*)
        #     echo "cd ~/Projects/myapp && code ."; return 0 ;;

        # Example: connect to work VPN
        # *"vpn"*|*"connect vpn"*)
        #     echo "open -a 'Cisco AnyConnect'"; return 0 ;;

        # Example: tail your app logs
        # *"app logs"*|*"my logs"*)
        #     echo "tail -f ~/Projects/myapp/logs/app.log"; return 0 ;;

        # ─── End of custom commands ───
        *)
            return 1 ;;
    esac
}
