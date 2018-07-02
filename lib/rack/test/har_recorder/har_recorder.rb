require 'addressable/template'
require 'json'

require_relative './http_archive'

module Rack
  module Test
    module HarRecorder
      class HarRecorder

        # Initializes a new recorder.
        # @param [String] path_template describes the file path new for new HAR
        #        files. It uses the rfc6570 template syntax (though you should
        #        only use local paths, as there is no actual URL writing
        #        support.)
        # @param [String] pageref_template is a template, like `path_template`
        #        but used to fill out the requestth
        # @param [Boolean] pretty_json indicates whether JSON request and
        #        response bodies should be pretty-printed inside the HAR
        #        files. Defaults to false.
        def initialize(path_template, pageref_template = nil, pretty_json: false)
          @path_template = path_template
          @pageref_template = pageref_template || path_template
          @pretty_json = pretty_json
        end

        private def interpolated_path(attrs)
          Addressable::Template.new(@path_template).expand(attrs)
        end

        # Records the given request and response from the `Rack::Test` objects,
        # using the provided naming attributes to generate the file path.
        # @param [Hash] attrs the set of attributes available to the file path
        #               template (see `#initialize`).
        # @param [Rack::Request] request the request to be recorded.
        # @param [Rack::Response] response the requestp to be recorded.
        def record_request_response_pair(attrs, request, response)
          path = interpolated_path(attrs)
          pretty_json = !!attrs.fetch(:pretty_json, Rack::Test::HarRecorder.configuration.pretty_json)

          pageref = Addressable::Template.new(@pageref_template).expand(attrs)
          request1 = archive_rack_request(request, pretty_json: @pretty_json)
          response1 = archive_rack_response(response, pretty_json: @pretty_json)

          entry = HttpArchive::EntryRecord.new(pageref, nil, nil, request1, response1, nil, nil, '127.0.0.1', nil, nil)
          archive = HttpArchive.new
          archive.append(entry)

          ::File.open(path, 'w') do |fil|
            fil.write(JSON.pretty_generate(archive.as_json))
            fil.puts
          end
        end

        # Parses the given JSON text and generates new JSON text based on the
        # `pretty_json` parameter.
        def regenerate_json(text, pretty_json: false)
          begin
            parsed = JSON.parse(text)
            if pretty_json
              JSON.pretty_generate(parsed)
            else
              JSON.generate(parsed)
            end
          rescue StandardError
            text
          end
        end

        # Copies the various fields from the given `Rack::Request` instance to
        # an instance of `HttpArchive::RequestRecord`.
        # @param [Rack::Request] rack_req the request from which the attributes
        #        will be copied.
        # @param [Boolean] pretty_json indicates whether a JSON request body
        #        should be formatted for human consumption. Due to the
        #        unreliability of the `Content-Type` header in requests, all
        #        request bodies go through a JSON parser. If the parser fails,
        #        the body text is passed through as-is.
        def archive_rack_request(rack_req, pretty_json: false)
          url = Addressable::URI.new(
            scheme: rack_req.scheme,
            host: rack_req.host,
            port: rack_req.port,
            path: rack_req.path_info,
          )

          cookies = rack_req.cookies.map do |cname, cvalue|
            HttpArchive::CookieRecord.new(cname, cvalue, '/', rack_req.host, nil, false, false, nil)
          end

          orig_headers = (rack_req.env[HEADERS_STATE_KEY] || [])
          orig_hdr_names = orig_headers.each_with_object(Hash.new) do |(hname, _), accum|
            accum[hname.downcase] = hname
          end
          rack_mangled_headers = rack_req.env.select do |nm, _|
            nm.start_with?('HTTP_')
          end
          headers = rack_mangled_headers.map do |nm, val|
            # Reformat the header to the historical convention, which is what
            # Rack::Test provided when I inspected some running tests. In the
            # future this is likely to change since the browsers now downcase all
            # headers.
            unmangled_name = nm.sub('HTTP_', '').downcase.tr('_', '-').gsub(/(^[a-z]|-[a-z])/, &:upcase)
            unmangled_name = orig_hdr_names.fetch(unmangled_name.downcase, unmangled_name)
            { 'name' => unmangled_name, 'value' => val, 'comment' => nil }
          end

          if rack_req.post? || rack_req.put?
            # Rails tests mimic the rails router feature of injecting a format
            # parameter into the rack env. If one exists, we want to use it to
            # avoid interpreting JSON requests as form requests. However since this
            # is also used from Sinatra tests, we need to be careful to not rely on
            # that parameter.
            rails_path_params = rack_req.env['action_dispatch.request.path_parameters'] || {}
            if rack_req.form_data? && rails_path_params[:format] != 'json'
              params = rack_req.POST.map do |pname, pvalue|
                if pvalue.is_a?(Hash) && !pvalue[:filename].nil?
                  HttpArchive::ParamRecord.new(pname, nil, pvalue[:filename], pvalue[:type], nil)
                else
                  # We don't support file attachments yet
                  HttpArchive::ParamRecord.new(pname, pvalue, nil, nil, nil)
                end
              end
              text = nil
            else
              input = rack_req.env['rack.input']
              input.rewind
              json_data = input.read
              text = regenerate_json(json_data, pretty_json: pretty_json)

              params = []

              []
            end
            post_data = HttpArchive::PostDataRecord.new(rack_req.content_type, params, text, nil)
          else
            post_data = nil
          end

          HttpArchive::RequestRecord.new(
            rack_req.request_method,
            url.to_s,
            'HTTP/1.0',
            HttpArchive::CookieSet.new(cookies),
            HttpArchive::HeaderSet.from_array(headers),
            rack_req.query_string,
            post_data,
            -1,
            -1,
            nil,
          )
        end

        # Copies the various fields from the given `Rack::Responset` instance
        # to an instance of `HttpArchive::ResponseRecord`.
        # @param [Rack::Response] rack_resp the response from which the
        #        attributes will be copied.
        # @param [Boolean] pretty_json indicates whether a JSON request body
        #        should be formatted for human consumption. Due to the
        #        unreliability of the `Content-Type` header in requests, all
        #        request bodies go through a JSON parser. If the parser fails,
        #        the body text is passed through as-is.
        def archive_rack_response(rack_resp, pretty_json: false)
          headers = rack_resp.header.map do |hname, hvalue|
            HttpArchive::HeaderRecord.new(hname, hvalue, nil)
          end

          if rack_resp.header['Set-Cookie']
            cookie_lines = rack_resp.header['Set-Cookie'].split("\n")
            cookies = cookie_lines.map do |ln|
              if ln =~ /^(.+?)=/
                chash = Rack::Utils.parse_query(ln, ';')
                HttpArchive::CookieRecord.new(Regexp.last_match(1), *chash.values_at(Regexp.last_match(1), 'path', 'expires', 'HttpOnly', 'secure', nil))
              end
            end
          else
            cookies = HttpArchive::CookieSet.new([])
          end

          resp_body = regenerate_json(rack_resp.body, pretty_json: pretty_json)

          HttpArchive::ResponseRecord.new(
            rack_resp.status,
            rack_resp.status.to_s, # This should lookup a description
            'HTTP/1.0',
            HttpArchive::CookieSet.new(cookies.compact),
            HttpArchive::HeaderSet.new(headers),
            resp_body,
            rack_resp.location,
            -1,
            rack_resp.body&.length || -1,
            nil,
          )
        end
      end
    end
  end
end

