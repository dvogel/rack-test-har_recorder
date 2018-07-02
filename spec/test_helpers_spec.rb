require 'rack/test'

RSpec.describe Rack::Test::HarRecorder::TestHelpers do

  class NoOpFakeTestBaseClass
    [:delete, :get, :post, :put].each do |method_name|
      define_method(method_name) do |*args|
        # no-op
      end
    end

    def header
      raise NotImplementedError, "canary exception"
    end
  end

  class NoOpFakeTestClass < NoOpFakeTestBaseClass
    include Rack::Test::HarRecorder::TestHelpers
  end

  describe NoOpFakeTestClass do
    subject(:fake_test) do
      NoOpFakeTestClass.new
    end

    it "overrides #delete" do
      expect(fake_test).to receive(:record_request_response_pair!).with('delete')
      fake_test.delete('/fake/path')
    end

    it "overrides #get" do
      expect(fake_test).to receive(:record_request_response_pair!).with('get')
      fake_test.get('/fake/path')
    end

    it "overrides #post" do
      expect(fake_test).to receive(:record_request_response_pair!).with('post')
      fake_test.post('/fake/path')
    end

    it "overrides #put" do
      expect(fake_test).to receive(:record_request_response_pair!).with('put')
      fake_test.put('/fake/path')
    end
  end


  describe "#har_record" do
    # Stand-in for a rack app.
    class RecordingFakeApp
      def call(env)
        [200, {'Content-Type' => 'text/plain'}, ["OK"]]
      end
    end

    class RecordingFakeTestBaseClass
      include Rack::Test::Methods

      def app
        @app ||= RecordingFakeApp.new
      end
    end

    class RecordingFakeTestClass < RecordingFakeTestBaseClass
      include Rack::Test::HarRecorder::TestHelpers
    end

    subject(:fake_test) do
      RecordingFakeTestClass.new
    end

    it "records to a file" do
      expect(::File).to receive(:open).with(%r/some-name/, any_args)
      fake_test.har_record(slug: 'some-name') do
        fake_test.get('/some/path')
        expect(fake_test.last_response.status).to eq(200)
        expect(fake_test.last_response.headers['Content-Type']).to eq('text/plain')
        expect(fake_test.last_response.body).to eq("OK")
      end
    end
  end
end

