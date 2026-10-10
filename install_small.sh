#!/bin/sh
# Builds vim_small/ (tiny plus the important plugins) to copy to a server's
# ~/.vim. See bundle.sh. Usage: sh install_small.sh [DIR]
exec sh "$(dirname "$0")/bundle.sh" small "$@"
