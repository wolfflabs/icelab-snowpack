# frozen_string_literal: true

require "dry/inflector"
require "hanami/cli"
require "hanami/cli/command"
require "hanami/utils/files"
require "snowflakes/application"

module Snowflakes
  class CLI < Hanami::CLI
    module Commands
      class Command < Hanami::CLI::Command
        def self.inherited(klass)
          super

          klass.option :env, aliases: ["-e"], default: nil, desc: "Application environment"
        end

        attr_reader :application
        attr_reader :out
        attr_reader :inflector
        attr_reader :files

        # WIP: play with injecting `out, files` from Snowflakes::CLI?
        def initialize(command_name:, application: nil, out: $stdout, inflector: Dry::Inflector.new, files: Hanami::Utils::Files)
          super(command_name: command_name)

          @application = application
          @out = out
          @inflector = inflector
          @files = files
        end

        def with_application(application)
          self.class.new(
            command_name: @command_name,
            application: application,
            out: out,
            files: files,
          )
        end

        private

        def run_command(klass, *args)
          klass.new(
            command_name: klass.name,
            application: application,
            out: out,
            files: files,
          ).call(*args)
        end

        def measure(desc, &block)
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          block.call
          stop = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          out.puts "=> #{desc} in #{(stop - start).round(1)}s"
        end
      end
    end
  end
end