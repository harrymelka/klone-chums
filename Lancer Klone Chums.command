#!/bin/zsh
set -e
cd "${0:A:h}"
python3 klone/start.py
printf '\nKlone Chums est prêt. Ouvre l’application sur ton iPhone.\n'
