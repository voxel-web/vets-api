# frozen_string_literal: true
require 'faraday/error'
require 'rack/utils'

# FIXME: this needs to be adapted to use va-api-common style errors
module Common
  module Client
    # The error class defines the various error types that the client can encounter
    module Errors
      class Error < StandardError; end

      class NotAuthenticated < Error; end
      class Client < Error; end
      class Serialization < Error; end
      class RequestTimeout < ::Faraday::Error::TimeoutError; end
      class ConnectionFailed < ::Faraday::Error::ConnectionFailed; end

      # This error class is for wrapping errors returned from underlying services
      class ClientResponse < Error
        def initialize(status_code, parsed_json)
          @status_code = status_code
          @parsed_json = parsed_json
        end

        def error
          return @cause unless @cause.nil?
          self
        end

        def major
          @status_code
        end

        def minor
          @parsed_json['errorCode'] || major
        end

        def message
          @parsed_json['message'].try(:capitalize) || rack_default_message
        end

        def developer_message
          @parsed_json['developerMessage']
        end

        def as_json
          return debug_hash if defined?(Rails) && (Rails.env.development? || Rails.env.test?)
          base_json
        end

        delegate :to_json, to: :as_json

        def to_s
          to_json
        end

        private

        def rack_default_message
          Rack::Utils::HTTP_STATUS_CODES.fetch(major, 'Service Unavailable')
        end

        def base_json
          { major: major, minor: minor, message: message, developer_message: developer_message }
        end

        def cause_to_hash
          @cause.nil? ? {} : { message: @cause.message, backtrace: @cause.backtrace }
        end

        def debug_hash
          base_json.merge(error: backtrace, cause: cause_to_hash)
        end
      end
    end
  end
end
