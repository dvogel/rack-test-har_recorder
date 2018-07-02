require 'rack/test'

module Rack
  module Test
    module HarRecorder
      HEADERS_STATE_KEY = 'rack-test-har_recorder.headers'.freeze
    end
  end
end

require_relative './har_recorder/configuration'
require_relative './har_recorder/http_archive'
require_relative './har_recorder/har_recorder'
require_relative './har_recorder/test_helpers'

