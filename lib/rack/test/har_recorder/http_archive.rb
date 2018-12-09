require 'addressable'
require 'json'

module Rack
  module Test
    module HarRecorder
      class HttpArchive
        class HeaderRecord < Struct.new(:name, :value, :comment)
          def as_json(*args)
            { name: name, value: value }.tap do |obj|
              obj[:comment] = comment
            end
          end

          def self.from_hash(input)
            new(*input.values_at('name', 'value', 'comment'))
          end
        end

        class HeaderSet < Array
          def self.from_array(input)
            new(input.map(&HeaderRecord.method(:from_hash)))
          end

          def as_json(*args)
            map do |item|
              item.as_json(*args)
            end
          end
        end

        class CacheRecord < Struct.new(:before_request, :after_request, :comment)
          def as_json(*args)
            # TODO: This doesn't yet support caching records.
            {}
          end
        end

        class CookieRecord < Struct.new(:name, :value, :path, :domain, :expires, :http_only, :secure, :comment)
          def as_json(*args)
            {
              'name' => name,
              'value' => value,
              'path' => path,
              'domain' => domain,
              'expires' => expires,
              'httpOnly' => http_only,
              'secure' => secure,
            }.tap do |obj|
              obj['comment'] = comment unless comment.nil?
            end
          end

          def self.from_hash(input)
            new(*input.values_at('name', 'value', 'path', 'domain', 'expires', 'httpOnly', 'secure', 'comment'))
          end
        end

        class CookieSet < Array
          def self.from_array(input)
            new(input.map(&CookieRecord.method(:from_hash)))
          end

          def as_json(*args)
            map do |item|
              item.as_json(*args)
            end
          end
        end

        class ParamRecord < Struct.new(:name, :value, :file_name, :content_type, :comment)
          def as_json(*args)
            {
              'name' => name,
            }.tap do |obj|
              obj['value'] = value unless value.nil?
              obj['fileName'] = file_name unless file_name.nil?
              obj['contentType'] = content_type unless content_type.nil?
              obj['comment'] = comment unless comment.nil?
            end
          end

          def self.from_hash(input)
            new(
              input['name'],
              input['value'],
              input['fileName'],
              input['contentType'],
              input['comment'],
            )
          end
        end

        class ParamSet < Array
          def self.from_array(input)
            new(input.map(&ParamRecord.method(:from_hash)))
          end

          def as_json(*args)
            map do |item|
              item.as_json(*args)
            end
          end
        end

        class PostDataRecord < Struct.new(:mime_type, :params, :text, :comment)
          def as_json(*args)
            {
              'mimeType' => mime_type,
              'params' => params.as_json(*args),
              'text' => text,
            }.tap do |obj|
              obj['comment'] = comment unless comment.nil?
            end
          end

          def self.from_hash(input)
            return unless input

            new(
              input['mimeType'],
              ParamSet.from_array(input['params']),
              input['text'],
              input['comment'],
            )
          end
        end

        class RequestRecord < Struct.new(:method_name, :url, :http_version, :cookies, :headers, :query_string, :post_data, :header_size, :body_size, :comment)
          def as_json(*args)
            {
              'method' => method_name,
              'url' => url,
              'httpVersion' => http_version,
              'cookies' => cookies.as_json(*args),
              'headers' => headers.as_json(*args),
              'queryString' => query_string,
              'headersSize' => header_size,
              'bodySize' => body_size,
            }.tap do |obj|
              obj['postData'] = post_data.as_json(*args) unless post_data.nil?
              obj['comment'] = comment unless comment.nil?
            end
          end

          def request
            self
          end

          def response
            self
          end

          def self.from_hash(input)
            new(
              input['method'],
              input['url'],
              input['httpVersion'],
              CookieSet.from_array(input['cookies']),
              HeaderSet.from_array(input['headers']),
              input['queryString'],
              PostDataRecord.from_hash(input['postData']),
              input['headerSize'] || -1,
              input['bodySize'] || -1,
              input['comment'],
            )
          end
        end

        class CurlRecord < RequestRecord
        end

        class ResponseRecord < Struct.new(:status, :status_text, :http_version, :cookies, :headers, :content, :redirect_url, :header_size, :body_size, :comment)
          def as_json(*args)
            {
              'status' => status,
              'statusText' => status_text,
              'httpVersion' => http_version,
              'cookies' => cookies.as_json(*args),
              'headers' => headers.as_json(*args),
              'content' => content,
              'headersSize' => header_size,
              'bodySize' => body_size,
            }.tap do |obj|
              obj['redirectURL'] = redirect_url unless redirect_url.nil?
              obj['comment'] = comment unless comment.nil?
            end
          end

          def request
            self
          end

          def response
            self
          end

          def self.from_hash(input)
            new(
              input['status'],
              input['statusText'],
              input['httpVersion'],
              CookieSet.from_array(input['cookies']),
              HeaderSet.from_array(input['headers']),
              input['content'],
              input['redirectURL'],
              input['headerSize'],
              input['bodySize'],
              input['comment'],
            )
          end
        end

        class EntryRecord < Struct.new(:pageref, :started_date_time, :time, :request, :response, :cache, :timings, :server_ip_address, :connection, :comment)
          def as_json(*args)
            {
              'startedDateTime' => started_date_time,
              'time' => time,
              'request' => request.as_json(*args),
              'response' => response.as_json(*args),
              'cache' => cache,
            }.tap do |obj|
              obj['serverIpAddress'] = server_ip_address unless server_ip_address.nil?
              obj['connection'] = connection unless connection.nil?
              obj['comment'] = comment unless comment.nil?
            end
          end

          def self.from_hash(input)
            new(
              input['pageref'],
              input['startedDateTime'],
              input['time'],
              RequestRecord.from_hash(input['request']),
              ResponseRecord.from_hash(input['response']),
              input['cache'],
              input['serverIpAddress'],
              input['connection'],
              input['comment'],
            )
          end
        end

        class EntrySet < Array
          def self.from_array(input)
            new(input.map(&EntryRecord.method(:from_hash)))
          end

          def as_json(*args)
            map do |item|
              item.as_json(*args)
            end
          end
        end

        # End of record types #############################################################

        def as_json(*args)
          {
            'entries' => @entries.map do |entry|
              entry.as_json(*args)
            end
          }
        end

        def append(entry_record)
          @entries << entry_record
          nil
        end

        def initialize(entries: nil)
          @entries = entries || []
          @pages = []
        end

        attr_reader :entries

        def self.from_file(path)
          parsed = JSON.parse(::File.read(path))
          entries = EntrySet.from_array(parsed['entries'])
          new(entries: entries)
        end
      end
    end
  end
end

