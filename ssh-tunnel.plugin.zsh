# ssh-tunnel.plugin.zsh

function ssh-tunnel() {
    local verbose=false
    local user
    local host
    local should_exit=false
    local run_remote_command=false
    local ssh_pid

    while getopts ":vNu:h:" opt; do
        case $opt in
            v)
                verbose=true
                ;;
            N)
                run_remote_command=true
                ;;
            u)
                user=$OPTARG
                ;;
            h)
                host=$OPTARG
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                return 1
                ;;
        esac
    done

    shift $((OPTIND - 1))

    if [[ -z $host ]]; then
        echo "Error: Host must be specified."
        exit 1
    fi

    local previous_tunnel_configs=()
    local current_tunnel_configs=("$@")
    local new_tunnel_configs=("${current_tunnel_configs[@]}")

    while [ "$should_exit" = false ]; do
        if ! validate_input "${new_tunnel_configs[@]}" ; then
            if [[ -n $previous_tunnel_configs && ${#previous_tunnel_configs[@]} -gt 0 ]]; then
                if [[ $verbose == true ]]; then
                    echo "Reverting to previous SSH Tunnels configuration."
                fi

                current_tunnel_configs=("${previous_tunnel_configs[@]}")
            fi

            continue
        fi

        construct_tunnel_configs "${new_tunnel_configs[@]}"

        print_logs

        # Construct the SSH command with the specified tunnels and user if provided
        ssh_cmd=("ssh" "-o" "ServerAliveInterval=60" "-o" "ServerAliveCountMax=3")
        append_user_and_host_to_ssh_cmd
        append_run_remote_command_to_ssh_cmd
        append_current_tunnel_configs_to_ssh_cmd

        # Print the constructed SSH command
        print_ssh_command

        # Execute the SSH command
        execute_ssh_command

        # Check for new input to add additional port forwarding
        read_and_process_new_config
    done

    # Cleanup the SSH process
    cleanup "exit"

    echo "Exiting..."

    trap - INT  # Unset the trap before returning
}

# Function to print verbose logs
print_logs() {
    if [[ $verbose == true ]]; then
        if [[ -n $previous_tunnel_configs && ${#previous_tunnel_configs[@]} -gt 0 ]]; then
            echo "Previous SSH Tunnels:"
            for arg in "${previous_tunnel_configs[@]}"; do
                echo "  $arg"
            done
        fi
    fi

    echo "Current SSH Tunnels:"
    for arg in "${current_tunnel_configs[@]}"; do
        echo "  $arg"
    done
}

# Function to validate input
validate_input() {
    local bind_address_pattern='[a-zA-Z0-9.-]+'
    local port_pattern='[0-9]+'
    local host_pattern='[a-zA-Z0-9.-]+'
    local socket_pattern='/?.+\.sock$'
    local remove_pattern='^!'

    local bind_address_port_host_hostport_pattern="^(\[${bind_address_pattern}\]:)?${port_pattern}:${host_pattern}:${port_pattern}$"
    local bind_address_port_remote_socket_pattern="^(\[${bind_address_pattern}\]:)?${port_pattern}:${socket_pattern}$"
    local local_socket_host_hostport_pattern="^${socket_pattern}:${port_pattern}:${host_pattern}:${port_pattern}$"
    local local_socket_remote_socket="^${socket_pattern}:${port_pattern}:${socket_pattern}$"
    local remove_bind_address_port_pattern="^${remove_pattern}(\[${bind_address_pattern}\]:)?${port_pattern}$"
    local remove_local_socket_pattern="^${remove_pattern}${socket_pattern}$"

    if [[ $verbose == true ]]; then
        echo "Validating input..."
    fi

    for arg in "$@"; do
        if [[ $verbose == true ]]; then
            echo "Validating input: $arg"
        fi

        if [[ $arg =~ $bind_address_port_host_hostport_pattern ]]; then
            if [[ $verbose == true ]]; then
                echo "Valid input for pattern: [bind_address:]port:host:hostport"
            fi
        elif [[ $arg =~ $bind_address_port_remote_socket_pattern ]]; then
            if [[ $verbose == true ]]; then
                echo "Valid input for pattern: [bind_address:]port:remote_socket"
            fi
        elif [[ $arg =~ $local_socket_host_hostport_pattern ]]; then
            if [[ $verbose == true ]]; then
                echo "Valid input for pattern: local_socket:host:hostport"
            fi
        elif [[ $arg =~ $local_socket_remote_socket ]]; then
            if [[ $verbose == true ]]; then
                echo "Valid input for pattern: local_socket:remote_socket"
            fi
        elif [[ $arg =~ $remove_bind_address_port_pattern ]]; then
            if [[ $verbose == true ]]; then
                echo "Valid input for pattern: ![bind_address:]port"
            fi
        elif [[ $arg =~ $remove_local_socket_pattern ]]; then
            if [[ $verbose == true ]]; then
                echo "Valid input for pattern: !local_socket"
            fi
        else
            echo "Invalid input: $arg"
            echo "Valid input patterns:"
            echo "  [bind_address:]port:host:hostport"
            echo "  [bind_address:]port:remote_socket"
            echo "  local_socket:host:hostport"
            echo "  local_socket:remote_socket"
            echo "  ![bind_address:]port"
            echo "  !local_socket"

            return 1
        fi
    done

    if [[ $verbose == true ]]; then
        echo "Input validation successful."
    fi

    return 0
}

# Function to onstruct SSH Tunnel configurations
construct_tunnel_configs() {
    local remove_tunnel_configs=()

    if [[ $verbose == true ]]; then
        echo "Constructing SSH Tunnel configurations..."
    fi

    for arg in "$@"; do
        if [[ $arg =~ ^! ]]; then
            if [[ $verbose == true ]]; then
                echo "Marked SSH Tunnel configuration for removal: $arg"
            fi

            remove_tunnel_configs+=("$arg")
        fi
    done

    new_tunnel_configs=()
    for arg in "$@"; do
        skip_arg=false

        if [[ $arg =~ ^! ]]; then
            continue
        fi

        for remove_arg in "${remove_tunnel_configs[@]}"; do
            if [[ "!${arg}" == "${remove_arg}"* ]]; then
                skip_arg=true
                continue 2
            fi
        done

        if [[ $skip_arg == true ]]; then
            if [[ $verbose == true ]]; then
                echo "Skipping SSH Tunnel configuration marked for removal: $arg"
            fi

            continue
        fi

        if [[ $verbose == true ]]; then
            echo "Adding SSH Tunnel configuration: $arg"
        fi
        new_tunnel_configs+=("$arg")
    done

    previous_tunnel_configs=("${current_tunnel_configs[@]}")
    current_tunnel_configs=("${new_tunnel_configs[@]}")
}

# Function to construct the SSH command
append_user_and_host_to_ssh_cmd() {
    if [[ -n $user ]]; then
        ssh_cmd+=("$user@$host")
    else
        ssh_cmd+=("$host")
    fi
}

# Function to construct the SSH command
append_run_remote_command_to_ssh_cmd() {
    if [[ $run_remote_command == true ]]; then
        ssh_cmd+=("-N")
    fi
}

# Function to construct the SSH command
append_current_tunnel_configs_to_ssh_cmd() {
    for arg in "${current_tunnel_configs[@]}"; do
        ssh_cmd+=("-L" "$arg")
    done
}

# Function to print the constructed SSH command
print_ssh_command() {
    if [[ $verbose == true ]]; then
        echo "Executing SSH command:"
        echo "  ${ssh_cmd[@]}"
    fi
}

# Function to execute the SSH command
execute_ssh_command() {
    if [[ $run_remote_command == true ]]; then
        execute_ssh_command_in_background
    else
        execute_ssh_command_in_foreground
    fi
}

# Function to execute the SSH command in the background
execute_ssh_command_in_background() {
    local output_file=$(mktemp)

    (
        ${ssh_cmd[@]} &  # Note: Use the correct separator for your environment (e.g., space or null)
        echo $! # Print the PID of the SSH process
    ) > "$output_file"

    ssh_pid=$(<"$output_file")  # Read the PID of the SSH process from the output file
    rm "$output_file"  # Remove the output file

    if [[ $verbose == true ]]; then
        echo "SSH process PID: $ssh_pid"
    fi
}

# Function to execute the SSH command in the foreground
execute_ssh_command_in_foreground() {
    # Clear the shell
    clear

    ${ssh_cmd[@]}

    # Clear the shell
    clear
}

# Function to read and process new port forwarding configuration
read_and_process_new_config() {
    trap 'should_exit=true; return' INT  # Trap Ctrl+C to return from the function instead of exiting the script

    echo "Enter new port forwarding configuration (e.g., 9000:localhost:9000 !8080), or press Enter to restart tunneling, or Ctrl+C to exit:"
    IFS=' ' read -r -A new_config

    if [[ -n $new_config && ${#new_config[@]} -gt 0 ]]; then
        if [[ $verbose == true ]]; then
            echo "New port forwarding configuration: "
            echo "  ${new_config[@]}"
        fi

        # Append the new port forwarding configuration to the current tunnel configurations
        new_tunnel_configs+=("${new_config[@]}")
    else
        echo "Restarting tunneling..."
    fi

    # Cleanup the SSH process
    cleanup "restart"
}

# Function to perform cleanup tasks
cleanup() {
    echo "Cleaning up..."

    # Check if the ssh_pid is set before attempting to kill the process
    if [[ -n "$ssh_pid" && "$ssh_pid" -ne 0 ]]; then
        echo "Killing SSH process with PID: $ssh_pid"

        kill "$ssh_pid"
        unset ssh_pid  # Unset the variable after killing the process
    elif [[ "$ssh_pid" -eq 0 ]]; then
        echo "Error: SSH process PID is 0."
    else
        echo "Error: SSH process PID is not set."
    fi

    action=$1
    if [[ $action == "restart" ]]; then
        # Set interval of 1 seconds before restarting
        # echo "Restarting in 1 second..."
        # sleep 1

        # Clear the shell
        clear
    fi
}

