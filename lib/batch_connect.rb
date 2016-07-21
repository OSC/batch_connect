require 'batch_connect/version'
require 'batch_connect/script'
require 'batch_connect/connection'

# The main namespace for BatchConnect
module BatchConnect
  # A namespace to hold all subclasses of {Script}
  module Scripts
    require 'batch_connect/scripts/vnc'
  end

  # A namespace to hold all subclasses of {Connection}
  module Connections
    require 'batch_connect/connections/vnc'
  end
end
