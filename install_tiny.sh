#!/bin/sh
# Builds vim_tiny/ (the most important plugins) to copy to a server's ~/.vim.
# See bundle.sh. Usage: sh install_tiny.sh [DIR]
exec sh "$(dirname "$0")/bundle.sh" tiny "$@"
