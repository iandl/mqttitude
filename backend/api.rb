require 'sinatra'
require 'sinatra/base'

#require "api/authentication"
#require "api/error_handling"
#require "api/pagination"
 
module Sinatra
  module Api
    # register ::Sinatra::Namespace
    #h ::Sinatra::ErrorHandling
    #register ::Sinatra::Authentication
    #register ::Sinatra::Pagination
 
    # We want JSON all the time, use our custom error handlers
    #set :show_exceptions, false
 
    # Run the following before every API request
    #before do
   #   content_type :json
    ##  #permit_authentication
   # end
 
    # Global helper methods available to all namespaces
    helpers do
 
      # Shortcut to generate json from hash, make it look good
      def json(json)
        MultiJson.dump(json, pretty: true)
      end
 
      # Parse the request body and enforce that it is a JSON hash
      def parsed_request_body
        if request.content_type.include?("multipart/form-data;")
          parsed = params
        else
          parsed = MultiJson.load(request.body, symbolize_keys: true)
        end
        halt_with_400_bad_request("The request body you provide must be a JSON hash") unless parsed.is_a?(Hash)
        return parsed
      end
    end
  end
  register Api
end