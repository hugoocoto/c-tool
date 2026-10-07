# bash completion for template. `make install` puts it where bash-completion
# finds it, or source it from ~/.bashrc.
_template_complete()
{
        local cur=${COMP_WORDS[COMP_CWORD]}
        local prev=${COMP_WORDS[COMP_CWORD - 1]}

        case $prev in
        -c | --config)
                compopt -o filenames
                mapfile -t COMPREPLY < <(compgen -f -- "$cur")
                return
                ;;
        esac
        mapfile -t COMPREPLY < <(compgen -W '--help -h --version -v --config -c' -- "$cur")
}
complete -F _template_complete template
