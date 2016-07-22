require 'mustache'
require 'yaml'

module BatchConnect
  # A view object for the information required to make a connection to a web
  # server running through batch job on some compute node
  class Connection < ::Mustache
    # Template path for batch scripts
    self.template_path = File.expand_path('../../../templates/connections', __FILE__)

    # An exception raised when attempting to resolve a yml file that doesn't exist
    class MissingYmlFile < StandardError; end

    # @param yml [#to_s] path to the yaml file with connection information
    # @raise [MissingYmlFile] if the requested yml file doesn't exist
    def initialize(yml:)
      yml = Pathname.new(yml).expand_path
      Dir.open(yml.dirname).close # flush NFS cache

      # Parse yaml
      raise MissingYmlFile, "cannot find yml file #{yml}" unless yml.file?
      YAML.load_file(yml).each do |k, v|
        self[k] = v
      end
    end
  end
end
