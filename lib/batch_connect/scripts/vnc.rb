module BatchConnect
  module Scripts
    # An object that describes a VNC server batch script view
    class VNC < Script
      # The module that describes the VNC environment
      # @return [String] the vnc module used
      attr_reader :vnc_mod

      # The VNC password file used for authentication
      # @return [String] path to vnc password file
      attr_reader :vnc_passwd

      # The VNC log file that contains the VNC server output
      # @return [String] path to vnc log file
      attr_reader :vnc_log

      # Name of VNC session
      # @return [String] name of vnc session
      attr_reader :name

      # Resolution of VNC session
      # @return [String] resolution of vnc session
      attr_reader :geometry

      # The DPI of the VNC session
      # @return [String] dpi of vnc session
      attr_reader :dpi

      # The comma delimited list of fonts used in the VNC session
      # @return [String] fonts used in vnc session
      attr_reader :fonts

      # The idle timeout set for the VNC session in seconds
      # @return [String] idle timeout in seconds of vnc session
      attr_reader :idle

      # The binary used to launch the noVNC websocket server
      # @return [String] novnc binary file
      attr_reader :novnc_bin

      # @param (see Script#initialize)
      # @param vnc_mod [#to_s] the vnc module used
      # @param vnc_passwd [#to_s] the vnc password file
      # @param vnc_log [#to_s] the vnc log file
      # @param name [#to_s] name of vnc session
      # @param geometry [#to_s] resolution of vnc session
      # @param dpi [#to_s] dpi of vnc session
      # @param fonts [#to_s] fonts used in vnc session
      # @param idle [#to_s] idle timeout of vnc session
      # @param novnc_bin [#to_s] novnc binary file
      def initialize(vnc_mod: "turbovnc/2.0", vnc_passwd: "${PBS_JOBID}.pass",
                     vnc_log: "$PBS_JOBID.log", name: "vnc",
                     geometry: "800x600", dpi: "96", fonts: "", idle: "0",
                     novnc_bin: "/usr/local/novnc/utils/launch.sh", **kwargs)
        super(**kwargs)

        @vnc_mod    = vnc_mod.to_s
        @vnc_passwd = vnc_passwd.to_s
        @vnc_log    = vnc_log.to_s
        @name       = name.to_s
        @geometry   = geometry.to_s
        @dpi        = dpi.to_s
        @fonts      = fonts.to_s
        @idle       = idle.to_s
        @novnc_bin  = novnc_bin.to_s
      end

      # @see Script#before
      def before
        <<-END.gsub(/^ {10}/, '')
          #{super}

          # Load up VNC server environment
          #{vnc_env}

          # Set up ever changing passwords and initialize VNC password
          function change_passwd () {
            echo "Setting VNC password..."
            password=$(create_passwd 8)
            spassword=${spassword:-$(create_passwd 8)}
            echo -ne "${password}\\n${spassword}" | vncpasswd -f > "#{vnc_passwd}"
            chmod 600 "#{vnc_passwd}"
          }
          change_passwd

          # Start up vnc server (if at first you don't succeed, try, try again)
          echo "Starting VNC server..."
          for i in `seq 1 10`; do
            # Clean up any old vnc sessions that weren't cleaned before
            #{vnc_cleanall}

            # Attempt to start VNC server
            VNC_OUT=$(vncserver #{vnc_args} 2>&1)
            VNC_PID=$(pgrep -s 0 Xvnc) # the script above will daemonize Xvnc process
            echo "${VNC_OUT}"

            # Sometimes Xvnc hangs if it fails to find working display, we
            # should kill it and try again
            kill -0 ${VNC_PID} 2>/dev/null && [[ ${VNC_OUT} =~ "Fatal server error" ]] && kill -TERM ${VNC_PID}

            # Check that Xvnc process is running, if not assume it died and
            # wait some random period of time before restarting
            kill -0 ${VNC_PID} 2>/dev/null || sleep 0.$(random 1 9)s

            # If running, then all is well and break out of loop
            kill -0 ${VNC_PID} 2>/dev/null && break
          done

          # If we fail to start it after so many tries, then just give up
          kill -0 ${VNC_PID} 2>/dev/null || clean_up 1

          # Parse output for ports used
          display=$(echo "${VNC_OUT}" | awk -F':' '/^Desktop/{print $NF}')
          port=$((5900+display))

          echo "Successfully started VNC server on ${host}:${port}..."
        END
      end

      # @see Script#after
      def after
        <<-END.gsub(/^ {10}/, '')
          #{novnc}

          # Set up background process that scans the log file for successful
          # connections by users, and change the password after every
          # connection
          echo "Scanning VNC log file for user authentications..."
          while read -r line; do
            if [[ ${line} =~ "Full-control authentication enabled for" ]]; then
              change_passwd
              create_yml
            fi
          done < <(tail -f --pid=${SCRIPT_PID} "#{vnc_log}") &

          #{super}
        END
      end

      # @see Script#clean
      def clean
        # this is indented by two spaces
        <<-END.gsub(/^ {10}/, '')
          #{super}
            #{vnc_cleanall}
            [[ -n ${display} ]] && vncserver -kill :${display}
        END
      end

      # @see Script#params
      def params
        (super + [:display, :websocket, :password, :spassword]).uniq
      end

      # @see Script#run_script
      def run_script
        %[DISPLAY=:${display} #{super}]
      end

      private
        # Load the environment required by VNC
        def vnc_env
          "module load #{vnc_mod}"
        end

        # Clean up any stale VNC sessions
        def vnc_cleanall
          %[vncserver -list | awk '/^:/{system("kill -0 "$2" 2>/dev/null || vncserver -kill "$1)}']
        end

        # Arguments sent to `vncserver` command
        def vnc_args
          "#{name_args} #{geometry_args} #{dpi_args} #{fonts_args} #{idle_args} #{log_args} #{auth_args} #{httpd_args} #{xstartup_args} #{extra_args}"
        end

        # Add a name to VNC session
        def name_args
          name.empty? ? "" : "-name #{name}"
        end

        # Add a resolution to VNC session
        def geometry_args
          geometry.empty? ? "" : "-geometry #{geometry}"
        end

        # Add a dpi to VNC session
        def dpi_args
          dpi.empty? ? "" : "-dpi #{dpi}"
        end

        # Add fonts to VNC session
        def fonts_args
          fonts.empty? ? "" : "-fp #{fonts}"
        end

        # Add an idletimeout (0 means no idle timout) to VNC session
        def idle_args
          idle.empty? ? "" : "-idletimeout #{idle}"
        end

        # Output stdout/stderr from VNC session to log
        def log_args
          "-log \"#{vnc_log}\""
        end

        # Use a password file for VNC authentication
        def auth_args
          "-nootp -nopam -rfbauth \"#{vnc_passwd}\""
        end

        # No Java http server for VNC session
        def httpd_args
          "-nohttpd"
        end

        # Do not have it run an xstartup script in VNC session
        def xstartup_args
          "-noxstartup"
        end

        # Any extra arguments to supply when starting VNC session
        def extra_args
          ""
        end

        # Launch a noVNC server that proxies to the local VNC session
        def novnc
          return "" if novnc_bin.empty?
          <<-END.gsub(/^ {12}/, '')
            # Launch noVNC websocket server
            echo "Starting websocket server..."
            websocket=$(find_port)
            #{novnc_bin} --vnc localhost:${port} --listen ${websocket} &
          END
        end
    end
  end
end
