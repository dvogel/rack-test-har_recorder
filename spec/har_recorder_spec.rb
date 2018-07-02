require 'rack/test'

RSpec.describe Rack::Test::HarRecorder::HarRecorder do
  let(:recorder) do
    described_class.new('path/to/har/files{/slug}.har')
  end

  let(:rack_request) do
    Rack::Request.new(Rack::MockRequest.env_for(
      "http://example.com:8080/",
      "REQUEST_METHOD" => request_method,
      "HTTP_COOKIE" => cookies,
      :input => input
    ))
  end

  let(:rack_response) do
    Rack::MockResponse.new(
      201,
      headers,
      body,
    )
  end

  describe '#archive_rack_request' do
    subject(:request_record) do
      recorder.archive_rack_request(rack_request)
    end

    before do
      rack_request.set_header 'HTTP_ACCEPT', 'application/json'
      rack_request.set_header 'CONTENT_TYPE', 'application/json'
      rack_request.set_header 'FORMAT', 'json'
    end

    context 'post request' do
      let(:input) {{foo: 'bar'}.to_json}
      let(:request_method) {"POST"}
      let(:cookies) {"foo=bar"}

      it 'returns the request params in the text fields' do
        expect(request_record.post_data.text).to eq(input)
      end

      it 'records headers' do
        header = request_record.headers.select {|h| h.name == "Accept"}
        expect(header.first.value).to eq('application/json')
      end

      it 'records the url' do
        expect(request_record.url).to eq('http://example.com:8080/')
      end

      it 'records the request method' do
        expect(request_record.method_name).to eq(request_method)
      end

      it 'records cookies' do
        expect(request_record.cookies.first.name).to eq('foo')
        expect(request_record.cookies.first.value).to eq('bar')
      end
    end
  end

  describe '#archive_rack_response' do
    subject(:response_record) do
      recorder.archive_rack_response(rack_response, pretty_json: true)
    end

    context 'JSON response' do
      let(:headers) do
        {'Content-Type' => 'application/json'}
      end

      let(:body) do
        '{"outcome": "created"}'
      end

      it 'records the response status' do
        expect(response_record.status).to eq(201)
      end

      it 'always pretends the request was HTTP/1.0' do
        expect(response_record.http_version).to eq('HTTP/1.0')
      end

      it 'reformats JSON body' do
        expect(response_record.content).to include("\n")
      end
    end

    context 'plain text response' do
      let(:headers) do
        {}
      end

      let(:body) do
        'foo'
      end

      it 'passes through the plain text body' do
        expect(response_record.content).to eq(body)
      end
    end
  end

  describe '#regenerate_json' do
    it 'passes through non-JSON text' do
      ['', 'hi', '}{'].each do |bogus_text|
        expect(recorder.regenerate_json(bogus_text)).to eq(bogus_text)
      end
    end

    it 'will pretty-print' do
      expect(recorder.regenerate_json('{"key": "value"}', pretty_json: true)).to include("\n")
    end
  end
end

