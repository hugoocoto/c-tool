# fish completion for template. `make install` puts it where fish finds it.
complete -c template -f
complete -c template -s h -l help -d 'Show the help and exit'
complete -c template -s v -l version -d 'Show the version and exit'
complete -c template -s c -l config -r -F -d 'Use this config file'
