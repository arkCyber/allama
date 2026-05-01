#compdef allama
# Zsh completion script for allama CLI

_allama() {
    local -a commands
    commands=(
        'pull:Pull a model from remote registry'
        'list:List all local models'
        'ps:List running models'
        'stop:Stop a running model'
        'show:Show detailed information about a model'
        'rm:Remove a model'
        'cp:Copy a model to a new name'
        'add:Add a local model to the registry'
        'create:Create a model from a Modelfile'
        'search:Search models by name pattern'
        'stats:Show registry statistics'
        'validate:Validate model file integrity'
        'run:Run a model for inference'
        'serve:Start the llama-server with model registry'
        'mem:Display memory usage and model memory requirements'
        'catalog:List available models from Hugging Face catalog'
        'catalog-update:Update model catalog from Hugging Face'
    )

    if (( CURRENT == 2 )); then
        _describe 'command' commands
    else
        local cmd=$words[2]
        case $cmd in
            pull|show|rm|stop|validate|run)
                # Complete with model names from registry
                local models=($(allama list 2>/dev/null | grep -E '^NAME:' | awk '{print $2}' | cut -d':' -f1))
                _describe 'model' models
                ;;
            cp)
                if (( CURRENT == 3 )); then
                    local models=($(allama list 2>/dev/null | grep -E '^NAME:' | awk '{print $2}' | cut -d':' -f1))
                    _describe 'model' models
                fi
                ;;
            add|create)
                # Complete with file paths
                _files
                ;;
            search)
                # No completion needed for pattern
                ;;
            *)
                # Default completion
                _files
                ;;
        esac
    fi
}

_allama "$@"
