# ********** Copyright Viacom, Inc. Apache 2.0 **********

require_relative "../test_helper.rb"

module RokuBuilder
  class AnalyzerTest < Minitest::Test
    def setup
      Logger.set_testing
      RokuBuilder.class_variable_set(:@@dev, false)
      RokuBuilder.setup_plugins
      register_plugins(Analyzer)
      @config, @options = build_config_options_objects(AnalyzerTest, {analyze: true, working: true, quiet_analyze: true}, false)
      @root_dir = @config.root_dir
      @device_config = @config.device_config
      FileUtils.cp(File.join(@root_dir, "manifest_template"), File.join(@root_dir, "manifest"))
      @request_stubs = []
      analyzer_config = nil
      File.open(File.join(@root_dir, "analyzer_config.json")) do |file|
        analyzer_config = file.read
      end
      @request_stubs.push(stub_request(:get, "http://devtools.web.roku.com/static-code-analyzer/config.json").
        to_return(status: 200, body: analyzer_config, headers: {}))
    end
    def teardown
      FileUtils.rm(File.join(@root_dir, "manifest"))
      @request_stubs.each {|req| remove_request_stub(req)}
    end
    def test_analyzer_parse_commands
      parser = OptionParser.new
      options = {}
      Analyzer.parse_options(parser: parser, options: options)
      argv = ["roku", "--analyze"]
      parser.parse! argv
      assert options[:analyze]
    end
    def test_clean_app
      warnings = test_manifest
      assert_equal Array, warnings.class
    end
    def test_manifest_duplicate_attribute
      warnings = test_manifest("manifest_duplicate_attribute")
      assert_equal 1, warnings.count
      assert_match(/title/, warnings[0][:message])
      assert_equal 2, warnings[0][:line]
      assert_equal "manifest", warnings[0][:path]
    end
    def test_manifest_depricated_attribute
      warnings = test_manifest("manifest_depricated_attribute")
      assert_equal 1, warnings.count
      assert_match(/subtitle/, warnings[0][:message])
      assert_equal 2, warnings[0][:line]
      assert_equal "manifest", warnings[0][:path]
    end
    def test_manifest_empty_value
      warnings = test_manifest("manifest_empty_value")
      assert_equal 1, warnings.count
      assert_match(/empty/, warnings[0][:message])
      assert_equal 9, warnings[0][:line]
      assert_equal "manifest", warnings[0][:path]
    end
    def test_manifest_invalid_value_integer
      warnings = test_manifest("manifest_invalid_value_integer")
      assert_equal 1, warnings.count
      assert_match(/major_version/, warnings[0][:message])
      assert_match(/bad/, warnings[0][:message])
      assert_equal 2, warnings[0][:line]
      assert_equal "manifest", warnings[0][:path]
    end
    def test_manifest_invalid_value_float
      warnings = test_manifest("manifest_invalid_value_float")
      assert_equal 1, warnings.count
      assert_match(/rsg_version/, warnings[0][:message])
      assert_match(/1/, warnings[0][:message])
      assert_equal 9, warnings[0][:line]
      assert_equal "manifest", warnings[0][:path]
    end
    def test_manifest_invalid_value_negative
      warnings = test_manifest("manifest_invalid_value_negative")
      assert_equal 1, warnings.count
      assert_match(/major_version/, warnings[0][:message])
      assert_match(/-1/, warnings[0][:message])
      assert_equal 2, warnings[0][:line]
      assert_equal "manifest", warnings[0][:path]
    end
    def test_manifest_invalid_value_not_equal
      warnings = test_manifest("manifest_invalid_value_not_equal")
      assert_equal 1, warnings.count
      assert_match(/build_version/, warnings[0][:message])
      assert_match(/0/, warnings[0][:message])
      assert_equal 4, warnings[0][:line]
      assert_equal "manifest", warnings[0][:path]
    end
    def test_manifest_invalid_value_equals
      warnings = test_manifest("manifest_invalid_value_equals")
      assert_equal 1, warnings.count
      assert_match(/screensaver_private/, warnings[0][:message])
      assert_match(/2/, warnings[0][:message])
      assert_equal 9, warnings[0][:line]
      assert_equal "manifest", warnings[0][:path]
    end
    def test_manifest_invalid_value_starts_with
      warnings = test_manifest("manifest_invalid_value_starts_with")
      refute_equal 0, warnings.count
      assert_match(/mm_icon_focus_hd/, warnings[0][:message])
      assert_match(/bad/, warnings[0][:message])
      assert_match(/invalid value/, warnings[0][:message])
      assert_equal 5, warnings[0][:line]
      assert_equal "manifest", warnings[0][:path]
    end
    def test_manifest_has_value
      warnings = test_manifest("manifest_has_value")
      assert_equal 1, warnings.count
      assert_match(/rsg_version/, warnings[0][:message])
      assert_match(/1.0/, warnings[0][:message])
      assert_equal 9, warnings[0][:line]
      assert_equal "manifest", warnings[0][:path]
    end
    def test_manifest_missing_file
      warnings = test_manifest("manifest_missing_file")
      assert_equal 1, warnings.count
      assert_match(/mm_icon_focus_hd/, warnings[0][:message])
      assert_match(/missing.png/, warnings[0][:message])
      assert_equal 5, warnings[0][:line]
      assert_equal "manifest", warnings[0][:path]
    end
    def test_manifest_missing_attribute
      warnings = test_manifest("manifest_missing_attribute")
      assert_equal 1, warnings.count
      assert_match(/title/, warnings[0][:message])
      assert_equal "manifest", warnings[0][:path]
      refute warnings[0][:line]
    end
    def test_manifest_incorrect_image_resolution
      warnings = test_manifest("manifest_incorrect_image_resolution")
      assert_equal 1, warnings.count
      assert_match(/mm_icon_focus_hd/, warnings[0][:message])
      assert_match(/too_small.png/, warnings[0][:message])
      assert_match(/336x210/, warnings[0][:message])
      assert_match(/1x1/, warnings[0][:message])
      assert_equal 5, warnings[0][:line]
      assert_equal "manifest", warnings[0][:path]
    end
    def test_line_inspector_depricated_component
      warnings = test_file(text: "\"roVideoScreen\"")
      assert_equal 1, warnings.count
      assert_match(/deprecated/, warnings[0][:message])
      assert_match(/roVideoScreen/, warnings[0][:message])
    end
    def test_line_inspector_depricated_component_xml_file
      warnings = test_file(text: "\"roVideoScreen\"", file: "test.xml")
      assert_equal 1, warnings.count
      assert_match(/roVideoScreen/, warnings[0][:message])
    end
    def test_line_inspector_depricated_component_in_comment
      warnings = test_file(text: "'\"roVideoScreen\"")
      assert_equal 0, warnings.count
    end
    def test_line_inspector_depricated_component_before_comment
      warnings = test_file(text: "\"roVideoScreen\"'comment")
      assert_equal 1, warnings.count
      assert_match(/roVideoScreen/, warnings[0][:message])
    end
    def test_line_inspector_depricated_component_in_xml_comment
      warnings = test_file(text: "<!-- \"roVideoScreen\" -->", file: "test.xml")
      assert_equal 0, warnings.count
    end
    def test_line_inspector_depricated_component_before_xml_comment
      warnings = test_file(text: "\"roVideoScreen\" <!-- comment -->", file: "test.xml")
      assert_equal 1, warnings.count
    end
    def test_line_inspector_depricated_component_after_xml_comment
      warnings = test_file(text: "<!-- comment -->\"roVideoScreen\"", file: "test.xml")
      assert_equal 1, warnings.count
    end
    def test_line_inspector_depricated_component_in_xml_multiline_comment
      warnings = test_file(text: "<!-- line1 \n\"roVideoScreen\"\n line3 -->", file: "test.xml")
      assert_equal 0, warnings.count
    end
    def test_line_inspector_depricated_component_in_xml_multiline_comment_start
      warnings = test_file(text: "<!-- \"roVideoScreen\"\n line2 -->", file: "test.xml")
      assert_equal 0, warnings.count
    end
    def test_line_inspector_depricated_component_in_xml_multiline_comment
      warnings = test_file(text: "<!-- line1 \n\"roVideoScreen\"-->", file: "test.xml")
      assert_equal 0, warnings.count
    end
    def test_line_inspector_depricated_component_before_xml_multiline_comment
      warnings = test_file(text: "\"roVideoScreen\"<!-- line1 \n line2 -->", file: "test.xml")
      assert_equal 1, warnings.count
    end
    def test_line_inspector_depricated_component_after_xml_multiline_comment
      warnings = test_file(text: "<!-- line1 \n line2 -->\"roVideoScreen\"", file: "test.xml")
      assert_equal 1, warnings.count
    end
    def test_line_inspector_stop_command
      warnings = test_file(text: "test\nstop\n")
      assert_equal 1, warnings.count
      assert_equal 1, warnings[0][:line]
    end
    def test_raf_constructor_present_import_missing
      use_manifest("manifest_raf")
      warnings = test_file(text: "roku_ads()")
      assert warnings.count > 0
      assert_match(/constructor call is present.*import is missing/, warnings.first[:message])
    end
    def test_raf_constructor_present_manifest_missing
      warnings = test_file(text: "library \"roku_ads.brs\"\nroku_ads()")
      assert warnings.count > 0
      assert_match(/manifest entry is missing/, warnings.first[:message])
    end
    def test_raf_constructor_missing_manifest_present
      use_manifest("manifest_raf")
      warnings = test_file(text: "library \"roku_ads.brs\"")
      assert warnings.count > 0
      assert_match(/constructor call is not present/, warnings.first[:message])
    end
    def test_raf_manifest_present_import_missing
      use_manifest("manifest_raf")
      warnings = test_file(text: "roku_ads()")
      assert warnings.count > 0
      assert_match(/manifest entry is present.*import is missing/, warnings.last[:message])
    end
    def test_raf_constructor_missing_import_present
      use_manifest("manifest_raf")
      warnings = test_file(text: "library \"roku_ads.brs\"")
      assert warnings.count > 0
      assert_match(/constructor call is not present.*import is present/, warnings.last[:message])
    end
    def test_raf_proper_intergration
      use_manifest("manifest_raf")
      warnings = test_file(text: "library \"roku_ads.brs\"\nroku_ads()")
      assert_equal 1, warnings.count
      assert_match(/integrated properly/, warnings[0][:message])
    end


    private

    def test_manifest(manifest_file = nil)
      if manifest_file
        use_manifest(manifest_file)
      end
      analyzer = Analyzer.new(config: @config)
      analyzer.analyze(options: @options)
    end

    def use_manifest(manifest_file)
      FileUtils.cp(File.join(@root_dir, manifest_file), File.join(@root_dir, "manifest"))
    end

    def test_file(text:, file: nil)
      file ||= "test.brs"
      test_file = File.join(@root_dir, "source", file)
      File.open(test_file, "w") do |file|
        file.write(text)
      end
      analyzer = Analyzer.new(config: @config)
      warnings = analyzer.analyze(options: @options)
      FileUtils.rm(test_file) if File.exist?(test_file)
      warnings
    end

    def print_all(warnings)
      warnings.each do |warning|
        puts warning[:message]
      end
    end
  end
end

