# SSH Tunneling plugin for zsh

Using this plugin you can modify config on the fly so there is no need to rerun the ssh tunneling command every single time.

### How To

In this plugin there are two way of interacting with the SSH,

1. Run SSH like usual and forward the specified port. You still can interact with the remote machine like you usually do when SSH-ing.

2. Only run the tunneling process. SSH intances going to run in the background and you cannot interact with the remote machine.

#### Install the plugin

To install this plugin, you first need to clone this repository by,
```sh
git clone https://github.com/afikrim/zsh-ssh-tunnel.git
```

After cloning the repository, you can just source the plugin script from your zsh shell
```sh
source path/to/zsh-ssh-tunnel/ssh-tunnel.plugin.zsh
```

#### Running it like usual (on the foreground)

To run the ssh-tunnel command you can just specify the user, host, and forwarding rules
This command going to take you to the remote machine's shell.
```sh
ssh-tunnel -u user -h host 8080:localhost:8080 9090:localhost:9090
```

If you want to add more port or remove any existing port forwarding, you'll need to exit first from the remote machin shell
```sh
exit
```

After that you can type the forwarding rules to the terminal and hit Enter
```plaintext
# Use ! as prefix to the local port if you want to remove the forwarding rule, e.g.
!8080 8081:localhost:8081
```

In the input above we remove forwarding rule for port 8080 and add a new rule to forward remote 8081 to local 8081


Example video:

https://github.com/afikrim/zsh-ssh-tunnel/assets/45133910/aa7c4280-f49d-4d76-822b-846d25ad2d28



#### Running it in the background

To run the ssh-tunnel command you can just specify the user, host, and forwarding rules
This command going to take you to the remote machine's shell.
```sh
ssh-tunnel -N -u user -h host 8080:localhost:8080 9090:localhost:9090
```

If you want to add more port or remove any existing port forwarding, you can just type the forwarding rules to the terminal and hit Enter
```plaintext
# Use ! as prefix to the local port if you want to remove the forwarding rule, e.g.
!8080 8081:localhost:8081
```

In the input above we remove forwarding rule for port 8080 and add a new rule to forward remote 8081 to local 8081


Example video

https://github.com/afikrim/zsh-ssh-tunnel/assets/45133910/e5da0caa-e736-4e4d-8eb9-aa77ffd95de9

