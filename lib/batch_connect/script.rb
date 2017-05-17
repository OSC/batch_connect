require 'mustache'

module BatchConnect
  # A helper object that describes a generic batch script view
  class Script < ::Mustache
    # Template path for batch scripts
    self.template_path = File.expand_path('../../../templates/scripts', __FILE__)

    # The script that runs the web server
    # @return [String] path to script
    attr_reader :script

    # The output path where the yaml file are written to
    # @return [String] yaml path
    attr_reader :yml

    # Code that is run before the script is called meant to modify yaml
    # parameters before they are written to the yaml file
    # @return [String] code run before script called
    attr_reader :before

    # Code that is run after the script is called meant to modify yaml
    # parameters before they are written to the yaml file
    # @return [String] code run after script called
    attr_reader :after

    # Code that is run during the clean up process on exit
    # @return [String] clean up code
    attr_reader :clean

    # The yaml parameters used when reading the connection information
    # @return [Array<Symbols>] parameters used for yaml file
    def params
      (@params + [:host, :port]).uniq
    end

    # @param script [#to_s] path of script meant to be run as executable
    # @param yml [#to_s] output path of yaml file
    # @param before [#to_s] code run before script called
    # @param after [#to_s] code run after script called
    # @param clean [#to_s] code run during clean up upon exit
    # @param params [Array<#to_sym>] parameters used for yaml file
    def initialize(script: "./script.sh",
                   yml: "${PBS_JOBID}.yml",
                   before: "host=$(hostname)\n[[ -e before.sh ]] && source before.sh",
                   after:  "[[ -e after.sh  ]] && source after.sh",
                   clean:  "[[ -e clean.sh  ]] && source clean.sh",
                   params: [], **_)
      self.template_name = 'bash'

      @script = script.to_s
      @yml    = yml.to_s
      @before = before.to_s
      @after  = after.to_s
      @clean  = clean.to_s
      @params = params.map(&:to_sym)
    end

    # Command used to run the script in the batch job
    # @return [String] command used to run script
    def run_script
      %[timeout $((PBS_WALLTIME-300)) "#{script}"]
    end
  end
end
