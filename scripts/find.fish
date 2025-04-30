function find_tasks
    # Define the argparse command to parse options
    argparse --name=find_tasks 'h/help' 'w' 'f/finished' 'n/not-started' 'd/dir=' -- $argv

    # Initialize variables

    set pattern ''
    set search_args ''

    # Process options
    if set -q _flag_w
        # Work in progress
        set pattern '\- \[v\]'
    else if set -q _flag_f
        # Task done
        set pattern '\- \[ *x *\]'
    else if set -q _flag_n
        # Task not started
        set pattern '\- \[ \]'
    else if set -q _flag_h
        echo "Usage: search_tasks [-w] [-f] [-n] [-d directory] [search patterns]"
        return
    else
        # No option specified, search for all tasks
        set pattern '\- *\[ *[ a-z] *\]'
    end

    if set -q _flag_d
        # Search in the specified directory
        set nodes_dir $_flag_d
    end
    # Any remaining arguments are treated as search patterns (hashtags or other filters)
    set search_args $argv

    # Perform the search using ag with the specified pattern and additional arguments
    if test -n "$pattern"
        if test -n "$search_args"
            rg "$pattern" --glob '*.md' -n $nodes_dir | grep $search_args
        else
            rg "$pattern" --glob '*.md' -n $nodes_dir
        end
    else
        echo "Please specify a valid option: -w (work in progress), -d (done), -n (not started)"
    end

end

# find_tasks $argv
