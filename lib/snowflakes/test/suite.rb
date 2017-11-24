require 'rspec/core'

require 'snowflakes/application'
require 'snowflakes/config'

module Snowflakes
  module Test
    module Helpers
      module_function

      def suite
        @__suite__ ||= RSpec.configuration.suite
      end
    end

    class Suite
      DB_CLEANUP_PATH_REGEX = /(features|integration)/

      class << self
        attr_accessor :current

        def root
          @__root__ ||= Pathname(Dir.pwd).join("spec").freeze
        end

        def instance
          @__instance__ ||= new
        end
      end

      def self.inherited(klass)
        super
        Suite.current = klass
      end

      def self.configure(&block)
        RSpec.configure do |config|
          config.add_setting :suite

          config.suite = self.new

          config.include Helpers

          config.disable_monkey_patching!

          config.expect_with :rspec do |expectations|
            expectations.include_chain_clauses_in_custom_matcher_descriptions = true
          end

          config.mock_with :rspec do |mocks|
            mocks.verify_partial_doubles = true
          end

          config.filter_run :focus
          config.run_all_when_everything_filtered = true

          config.example_status_persistence_file_path = root.join("../tmp").realpath.join("spec/examples.txt").to_s

          if config.files_to_run.one?
            config.default_formatter = "doc"
          end

          config.profile_examples = 10

          config.order = :random

          Kernel.srand config.seed

          yield(config) if block_given?
        end
      end

      def self.application
        @__application__ ||= Application.new(Snowflakes.configure).freeze
      end

      attr_reader :root, :app

      def initialize(root = self.class.root.join('suite'))
        @root = root
        @app = Suite.application
      end

      def start_coverage
        return unless coverage?

        require 'simplecov'

        if parallel?
          SimpleCov.command_name(test_group_name)
        end

        SimpleCov.start do
          add_filter '/spec/'
          add_filter '/system/'
        end
      end

      def require_containers
        app.require_container
        app.require_sub_app_containers
      end

      def test_group_name
        @__test_group_name__ ||= "test_suite_#{build_idx}".freeze
      end

      def file_group(idx = build_idx)
        case idx
        when -1 then files
        when 0 then chdir(:integration).files + chdir(:main).files
        when 1 then chdir(:admin).files
        else
          files
        end
      end

      def chdir(name)
        self.class.new(root.join(name.to_s))
      end

      def files
        dirs.map { |dir| dir.join("**/*_spec.rb") }.flat_map { |path| Dir[path] }.sort
      end

      def groups
        dirs.map(&:basename).map(&:to_s).map(&:to_sym).sort
      end

      def dirs
        Dir[root.join("*")].map(&Kernel.method(:Pathname)).select(&:directory?)
      end

      def build_idx
        ENV.fetch('CIRCLE_NODE_INDEX', -1).to_i
      end

      def coverage?
        ENV['COVERAGE'] == 'true'
      end

      def ci?
        !ENV['CIRCLECI'].nil?
      end

      def parallel?
        ENV['CIRCLE_NODE_TOTAL'].to_i > 1
      end

      def capybara_server_port
        3001
      end

      def clean_db?(example)
        DB_CLEANUP_PATH_REGEX.match?(example.metadata[:file_path])
      end
    end
  end
end