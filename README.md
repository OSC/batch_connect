# BatchConnect

Library used to generate batch scripts that start up web servers, VNC servers,
and etc., through batch jobs running on HPC resources. It is also used to
generate connection information from these batch jobs so that a user can
connect to their batch job server.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'batch_connect'
```

And then execute:

```sh
$ bundle
```

Or install it yourself as:

```sh
$ gem install batch_connect
```

## Usage

A simple batch script can be generated as such:

```ruby
require 'batch_connect'

# Generate batch script object
my_script = BatchConnect::Script.new

# Render the script and output it to a file
File.open("/path/to/my/batch_script.sh", 'w') {|f| f.write(my_script.render)}
```

This generates a batch script with no PBS directives written in Bash at:

```sh
/path/to/my/batch_script.sh
```

You can take a quick look at it:

```sh
$ cd /path/to/...
$ cat batch_script.sh
```

Notice it calls within the script the following scripts: `before.sh`,
`script.sh`, `after.sh`, and `clean.sh`. These should all be located in the
current working directory of the batch script during the batch job submission.

| file        | description                                                                                                                                 |
| ----        | -----------                                                                                                                                 |
| `before.sh` | this file is **sourced** before the main script is called so you can do any pre-processing such as setting connection information variables |
| `after.sh`  | this file is **sourced** after the main script is called so you can do any post-processing such as setting connection information variables |
| `clean.sh`  | this file is **sourced** during an exit of the batch script used to clean up anything the main script may leave behind                      |
| `script.sh` | this is the main script that starts and controls the web server of your choice                                                              |

You will need to set the connection information required for users to connect
to this server:

| variable | description                                                     |
| -------- | -----------                                                     |
| `$host`  | the host the server is running on (this is already set for you) |
| `$port`  | the port the server is listening on (**required**)              |

There are some Bash helper functions you can use in your **sourced** scripts
defined in [templates/scripts/_bash_helpers.mustache](templates/scripts/_bash_helpers.mustache).

For example, to define an available port that will be used by the server:

```sh
# before.sh

# Use the `find_port` helper function to find available port
port=$(find_port)
```

Then we can use this port in our main script when setting up the server:

```sh
# script.sh

python -m SimpleHTTPServer $port
```

make this script executable:

```sh
$ chmod 755 script.sh
```

For this example we don't necessarily need `after.sh` or `clean.sh`. Now let's
start up our server:

```sh
$ qsub batch_script.sh -N my_batch -j oe -l nodes=1:ppn=12 -l walltime=01:00:00
123456
```

Wait until the job is started. When it is running take a look at the yaml file
that is generated:

```sh
$ cat 123456.yml
host: 'node0001.hpc.edu'
port: '6584'
```

This is the yaml file that we will parse to get connection information for the
user to connect to our server. Lets do a simple SSH tunnel connection to our
new server:

```ruby
require 'batch_connect'

# Create a connection view for this server
my_conn = BatchConnect::Connection.new(yml: "/path/to/123456.yml")

# Render this view object for a terminal making an SSH tunnel. We do need to
# give it some help though.
my_conn.render(:terminal, {local_port: 1234, ssh_user: "my_username", ssh_host: "login.hpc.edu"})
#=> "ssh -L 1234:node0001.hpc.edu:6584 my_username@login.hpc.edu\n"
```

Copy this into your **local** machine terminal:

```sh
$ ssh -L 1234:node0001.hpc.edu:6584 my_username@login.hpc.edu
Password: ....
...
```

Now open your browser and navigate to:

```
http://localhost:1234
```

You should see the directory listing where you started your batch job.

### VNC Session

To start a VNC session you first need to create the batch script:

```ruby
require 'batch_connect'

# Generate VNC batch script object
my_script = BatchConnect::Scripts::VNC.new

# Render the script and output it to a file
File.open("/path/to/my/batch_script.sh", 'w') {|f| f.write(my_script.render)}
```

This generates a batch script with no PBS directives written in Bash at:

```sh
/path/to/my/batch_script.sh
```

You should not need to create `before.sh`, `after.sh`, or `clean.sh`. But you
will need to create the main script `script.sh`. This script is called within
the VNC session itself, so this is where you launch your GUI applications.

Let's create a script that starts up a Gnome desktop for RHEL6, so modify
`script.sh` as such:

```sh
#!/bin/bash -l

# Turn off screensaver
gconftool-2 --set -t boolean /apps/gnome-screensaver/idle_activation_enabled false

# Use browser window mode in nautilus
gconftool-2 --set -t boolean /apps/nautilus/preferences/always_use_browser true

# Remove any preconfigured monitors
if [ -f "${HOME}/.config/monitors.xml" ]; then
  mv "${HOME}/.config/monitors.xml" "${HOME}/.config/monitors.xml.bak"
fi

# Export the module function for the Gnome session
export -f module

# Start up Gnome desktop
/etc/X11/xinit/Xsession gnome-session
```

**Note**: You need to add the shebang `#!/bin/bash -l` at the top so that it
starts in login mode. This will initialize the `module` function within the
script.

Now we make this script executable:

```sh
$ chmod 755 script.sh
```

Now let's start up our server:

```sh
$ qsub batch_script.sh -N my_batch -j oe -l nodes=1:ppn=12 -l walltime=01:00:00
123456
```

Wait until the job is started. When it is running take a look at the yaml file
that is generated:

```sh
$ cat 123456.yml
host: 'node0001.hpc.edu'
port: '5901'
display: '1'
websocket: '6790'
password: '6SP7wldi'
spassword: 'rxsKg1dz'
```

This is the yaml file that we will parse to get connection information for the
user to connect to our server. Lets do a websocket connection to the VNC server
through our HPC center's OnDemand portal:

```ruby
require 'batch_connect'

# Create a connection view for this VNC server
my_conn = BatchConnect::Connections::VNC.new(yml: "/path/to/123456.yml")

# Render the connection information for a websocket connection with out HPC
# center's OnDemand portal
my_conn.render(:novnc, {local_port: 1234, ssh_user: "my_username", ssh_host: "login.hpc.edu"})
#=> "/rnode/node0001.hpc.edu/6790/vnc_auto.html?password=6SP7wldi&path=rnode/node0001.hpc.edu/6790/websockify\n"
```

Now open your browser and navigate to your HPC center's OnDemand portal with
the following sub-URI:

```
https://ondemand.hpc.edu/rnode/node0001.hpc.edu/6790/vnc_auto.html?password=6SP7wldi&path=rnode/node0001.hpc.edu/6790/websockify
```

and you should see a RHEL6 Gnome desktop accessed through the noVNC client.

#### VNC Options

You can specify different VNC options when you initialize the batch script object:

```ruby
# Generate VNC batch script object that starts a VNC session with the name
# "my_vnc" at a resolution of 1024x768
my_script = BatchConnect::Scripts::VNC.new(name: "my_vnc", geometry: "1024x768")
```

Possible options that developers may be interested in:

| option        | description                                                                              |
| ------        | -----------                                                                              |
| `:vnc_mod`    | The VNC module to load that sets up the VNC server environment (default: `turbovnc/2.0`) |
| `:name`       | Name of the VNC session (default: "vnc")                                                 |
| `:geometry`   | Resolution of VNC session (default: "800x600")                                           |
| `:dpi`        | DPI of VNC session (default: "96")                                                       |
| `:fonts`      | Comma delimited list of fonts to use in VNC session (default: "")                        |
| `:idle`       | The idle timeout of VNC session in seconds (default: "0", session runs until walltime)   |

## Contributing

1. Fork it ( https://github.com/[my-github-username]/batch_connect/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
