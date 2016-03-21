module RokuBuilder

  # Commands that the controller uses to interface with the rest of the gem.
  class ControllerCommands
    # Validate Config
    # @return [Integer] Success or Failure Code
    def self.validate()
      SUCCESS
    end
    # Run Sideload
    # @param configs [Hash] parsed configs
    # @return [Integer] Success or Failure Code
    def self.sideload(configs:)
      loader = Loader.new(**configs[:device_config])
      success = loader.sideload(**configs[:sideload_config])
      return FAILED_SIDELOAD unless success
      SUCCESS
    end
    # Run Package
    # @param options [Hash] user options
    # @param configs [Hash] parsed configs
    # @param logger [Logger] system logger
    # @return [Integer] Success or Failure Code
    def self.package(options:, configs:, logger:)
      keyer = Keyer.new(**configs[:device_config])
      loader = Loader.new(**configs[:device_config])
      packager = Packager.new(**configs[:device_config])
      inspector = Inspector.new(**configs[:device_config])
      logger.warn "Packaging working directory" if options[:working]
      # Sideload #
      build_version = loader.sideload(**configs[:sideload_config])
      return FAILED_SIGNING unless build_version
      # Key #
      success = keyer.rekey(**configs[:key])
      logger.info "Key did not change" unless success
      # Package #
      options[:build_version] = build_version
      configs = ConfigManager.update_configs(configs: configs, options: options)
      success = packager.package(**configs[:package_config])
      logger.info "Signing Successful: #{configs[:package_config][:out_file]}" if success
      return FAILED_SIGNING unless success
      # Inspect #
      if options[:inspect]
        info = inspector.inspect(configs[:inspect_config])
        logger.unknown "App Name: #{info[:app_name]}"
        logger.unknown "Dev ID: #{info[:dev_id]}"
        logger.unknown "Creation Date: #{info[:creation_date]}"
        logger.unknown "dev.zip: #{info[:dev_zip]}"
      end
      SUCCESS
    end
    # Run Build
    # @param options [Hash] user options
    # @param config [Hash] loaded config object
    # @param configs [Hash] parsed configs
    # @param logger [Logger] system logger
    # @return [Integer] Success or Failure Code
    def self.build(options:, configs:, logger:)
      ### Build ###
      loader = Loader.new(**configs[:device_config])
      build_version = ManifestManager.build_version(**configs[:manifest_config])
      options[:build_version] = build_version
      configs = ConfigManager.update_configs(configs: configs, options: options)
      outfile = loader.build(**configs[:build_config])
      logger.info "Build: #{outfile}"
      SUCCESS
    end
    # Run update
    # @param configs [Hash] parsed configs
    # @param logger [Logger] system logger
    # @return [Integer] Success or Failure Code
    def self.update(configs:, logger:)
      ### Update ###
      old_version = ManifestManager.build_version(**configs[:manifest_config])
      new_version = ManifestManager.update_build(**configs[:manifest_config])
      logger.info "Update build version from:\n#{old_version}\nto:\n#{new_version}"
      SUCCESS
    end
    # Run deeplink
    # @param configs [Hash] parsed configs
    # @return [Integer] Success or Failure Code
    def self.deeplink(configs:)
      ### Deeplink ###
      linker = Linker.new(**configs[:device_config])
      success = linker.link(**configs[:deeplink_config])
      return FAILED_DEEPLINKING unless success
      SUCCESS
    end
    # Run delete
    # @param configs [Hash] parsed configs
    # @return [Integer] Success or Failure Code
    def self.delete(configs:)
      loader = Loader.new(**configs[:device_config])
      loader.unload()
      SUCCESS
    end
    # Run Monitor
    # @param options [Hash] user options
    # @param config [Hash] loaded config object
    # @param configs [Hash] parsed configs
    # @param logger [Logger] system logger
    # @return [Integer] Success or Failure Code
    def self.monitor(options:, config:, configs:, logger:)
      monitor = Monitor.new(**configs[:device_config])
      monitor.monitor(**configs[:monitor_config])
      SUCCESS
    end
    # Run navigate
    # @param configs [Hash] parsed configs
    # @return [Integer] Success or Failure Code
    def self.navigate(configs:)
      navigator = Navigator.new(**configs[:device_config])
      success = navigator.nav(**configs[:navigate_config])
      return FAILED_NAVIGATING unless success
      SUCCESS
    end
    # Run screen
    # @param configs [Hash] parsed configs
    # @return [Integer] Success or Failure Code
    def self.screen(configs:)
      navigator = Navigator.new(**configs[:device_config])
      success = navigator.screen(**configs[:screen_config])
      return FAILED_NAVIGATING unless success
      SUCCESS
    end
    # Run screens
    # @param configs [Hash] parsed configs
    # @return [Integer] Success or Failure Code
    def self.screens(configs:)
      navigator = Navigator.new(**configs[:device_config])
      navigator.screens
      SUCCESS
    end
    # Run text
    # @param configs [Hash] parsed configs
    # @return [Integer] Success or Failure Code
    def self.text(configs:)
      navigator = Navigator.new(**configs[:device_config])
      navigator.type(**configs[:text_config])
      SUCCESS
    end
    # Run test
    # @param configs [Hash] parsed configs
    # @return [Integer] Success or Failure Code
    def self.test(configs:)
      tester = Tester.new(**configs[:device_config])
      tester.run_tests(**configs[:test_config])
      SUCCESS
    end
    # Run Screencapture
    # @param configs [Hash] parsed configs
    # @return [Integer] Success or Failure Code
    def self.screencapture( configs:)
      inspector = Inspector.new(**configs[:device_config])
      success = inspector.screencapture(**configs[:screencapture_config])
      return FAILED_SCREENCAPTURE unless success
      SUCCESS
    end
  end
end
