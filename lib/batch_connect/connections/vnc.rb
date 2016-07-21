module BatchConnect
  module Connections
    # A view object for the information required to make a connection to a VNC
    # web server running through batch job on some compute node
    class VNC < Connection
      # Template path for batch scripts
      self.template_path = File.expand_path('../../../../templates/connections/vnc', __FILE__)
    end
  end
end
