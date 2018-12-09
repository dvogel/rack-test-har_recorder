module Rack
  module Test
    module HarRecorder
      # This module is used as a mixin for request specs. It overrides the
      # various methods named after HTTP methods (e.g. #get, #post, etc) in
      # order to record the request and response.
      #
      # In order to make effective use of the HTTP method helpers you will need
      # to wrap them in a block passed to the `#har_record` method.
      #
      # @example Record two entries inside artifacts/HAR/things_admin/post-and-get-cycle.har
      #   Rack::Test::HarRecorder.configure do |c|
      #     c.pretty_json = true
      #     c.path_template = 'artifacts/HAR/{api}/{slug}.har'
      #   end
      #
      #   RSpec.describe "some API" do
      #     include Rack::Test::Methods
      #     include Rack::Test::HarRecorder::TestHelpers
      #
      #     it "returns attributes from GET that are not included in the POST" do
      #       har_record(api: 'things_admin', slug: 'post-and-get-cycle') do
      #         create_params = { first_name: 'John', last_name: 'Doe' }
      #         post '/path', create_params.to_json
      #         expect(last_response.status).to eq(201)
      #
      #         get last_request.headers['Location']
      #         expect(last_response.status).to eq(200)
      #         parsed_response = JSON.parse(last_response.body)
      #         expect(parsed_response.keys).to have_key('uuid')
      #       end
      #     end
      #   end 
      module TestHelpers
        def initialize(*args)
          super(*args)
          @har_recorder = HarRecorder.new(
            *Rack::Test::HarRecorder.configuration.recorder_parameters
          )
        end

        # Wraps a block that uses Rack::Test::Methods helpers. All requests
        # and responses observed during the execution of that block will be
        # recorded to the same HAR file.
        # @params [Hash] attrs is a collection of parameters that are used to
        #         expand the `path_template` of the `HarRecorder` instance
        #         used by this test class.
        def har_record(attrs)
          previous_naming_parameters = @har_naming_parameters
          @har_naming_parameters = attrs
          yield if block_given?
        ensure
          @har_naming_parameters = previous_naming_parameters
          @har_headers = nil
        end

        private def record_request_response_pair!(helper_name)
          if @har_naming_parameters.nil?
            warn "HarRecorder::RackSessionTestHelpers::#{helper_name} called without @HAR_NAMING_PARAMETERS set."
            warn 'You probably meant to wrap your test in a call to the har_record method.'
          else
            recorded_request, recorded_response =
              if is_a?(Rack::Test::Methods)
                [last_request, last_response]
              elsif is_a?(ActionDispatch::Integration::Runner)
                [@request, @response]
              else
                warn "It appears that you've tried to use #{__METHOD__} in conjunction with a HTTP test helpers other than Rack::Test::Methods or ActionDispatch::Integration::Runner"
              end
            recorded_request.env[HEADERS_STATE_KEY] = har_headers
            @har_recorder.record_request_response_pair(@har_naming_parameters, recorded_request, recorded_response)
          end
        end

        # Overrides method provided by Rack::Test::Methods
        def put(*args)
          super(*args).tap do |response|
            record_request_response_pair!('put')
          end
        end

        # Overrides method provided by Rack::Test::Methods
        def get(*args)
          super(*args).tap do |response|
            record_request_response_pair!("get")
          end
        end

        # Overrides method provided by Rack::Test::Methods
        def post(*args)
          super(*args).tap do |response, *rest|
            record_request_response_pair!("post")
          end
        end

        # Overrides method provided by Rack::Test::Methods
        def delete(*args)
          super(*args).tap do |response|
            record_request_response_pair!('delete')
          end
        end

        # Overrides method provided by Rack::Test::Session, forwarded from ActionDispatch's request spec class.
        def header(name, value)
          har_headers << [name, value]
          super(name, value)
        end

        private def har_headers
          @har_headers ||= []
        end
      end
    end
  end
end

