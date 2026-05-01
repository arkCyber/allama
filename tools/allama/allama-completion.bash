#!/bin/bash
# Bash completion script for allama CLI

_allama_commands="pull list ps stop show rm cp add create search stats validate run serve mem catalog catalog-update"

_allama_completion() {
    local cur prev words cword
    _init_completion || return

    case $prev in
        pull|show|rm|stop|validate|run)
            # Complete with model names from registry
            local models=$(allama list 2>/dev/null | grep -E '^NAME:' | awk '{print $2}' | cut -d':' -f1)
            COMPREPLY=($(compgen -W "$models" -- "$cur"))
            ;;
        cp)
            # Complete with model names for source
            local models=$(allama list 2>/dev/null | grep -E '^NAME:' | awk '{print $2}' | cut -d':' -f1)
            COMPREPLY=($(compgen -W "$models" -- "$cur"))
            ;;
        add)
            # Complete with file paths
            COMPREPLY=($(compgen -f -- "$cur"))
            ;;
        create)
            # Complete with file paths
            COMPREPLY=($(compgen -f -- "$cur"))
            ;;
        search)
            # No completion needed for pattern
            ;;
        *)
            # Complete with allama commands
            COMPREPLY=($(compgen -W "$_allama_commands" -- "$cur"))
            ;;
    esac
}

complete -F _allama_completion allama
