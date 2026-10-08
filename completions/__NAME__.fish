# fish completion for __NAME__. `make install` puts it where fish finds it.
complete -c __NAME__ -f
complete -c __NAME__ -s h -l help -d 'Show the help and exit'
complete -c __NAME__ -s v -l version -d 'Show the version and exit'
complete -c __NAME__ -s c -l config -r -F -d 'Use this config file'
