module Rack
  module Test
    module HarRecorder
      class Configuration
        attr_accessor :pageref_template, :path_template, :pretty_json

        def initialize(pageref_template: nil, path_template: nil, pretty_json: nil)
          @path_template = path_template
          @pageref_template = pageref_template
          @pretty_json = pretty_json
        end

        def recorder_parameters
          [
            @path_template,
            @pageref_template,
            { pretty_json: @pretty_json }
          ]
        end
      end

      def self.default_configuration
        Configuration.new(
          path_template: 'har/{slug}.har',
          pageref_template: nil,
          pretty_json: false
        )
      end

      def self.configuration
        @configuration ||= default_configuration
      end

      def self.configure
        yield(configuration)
      end
    end
  end
end
