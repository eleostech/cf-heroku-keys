require 'json'
require 'logger'
require 'net/http'

LOGGER = Logger.new($stderr)
LOGGER.level = Logger::INFO
LOGGER.formatter = proc do |severity, datetime, progname, msg|
  "[#{severity}] #{msg}\n"
end

def respond_signal(success, reason, event)
    response_keys = %w(Status StackId RequestId LogicalResourceId)
    response = event.select { |k, v| response_keys.include?(k) }

    response["Status"] = success ? "SUCCESS" : "FAILED"
    response["Reason"] = reason if reason
    response["PhysicalResourceId"] = "HerokuAPI"

    response_data = JSON.generate(response)
    LOGGER.debug("CloudFormation response signal JSON: #{response_data}")

    response_uri = URI.parse(event["ResponseURL"])
    http = Net::HTTP.new(response_uri.host, response_uri.port)
    http.use_ssl = response_uri.scheme == 'https'
    full_path = "#{response_uri.path}?#{response_uri.query}"
    headers = {"Content-Type" => " "}
    LOGGER.info("Posting CloudFormation signal to: #{response_uri}#{full_path}")
    result = http.send_request('PUT', full_path, response_data, headers)
    LOGGER.info("Signal response: #{result.body}")
end

def heroku_update_config(app_name, environment)
    token = ENV["HEROKU_API_KEY"]
    headers = {
        "Content-Type" => "application/json",
        "Accept" => "application/vnd.heroku+json; version=3",
        "Authorization" => "Bearer #{token}"
    }
    uri = URI.join("https://api.heroku.com/apps/", "#{app_name}/config-vars")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    LOGGER.info("Updating configuration on app `#{app_name}`")
    http.send_request('PATCH', uri.path, JSON.generate(environment), headers)
end

def lambda_handler(event:, context:)
    properties = event["ResourceProperties"]

    begin
        app_name = properties["AppName"]
        raise "AppName property must be specified" unless app_name
        if ["Create", "Update"].include?(event["RequestType"])
            key_value = properties["Key"]
            secret_value = properties["Secret"]
            raise "`Key` resource property must be set to the access key" unless key_value
            raise "`Secret` resource property must be set to the secret key" unless secret_value
        else
            key_value = nil
            secret_value = nil
        end

        response = heroku_update_config(app_name, {
            "AWS_ACCESS_KEY_ID" => key_value,
            "AWS_SECRET_ACCESS_KEY" => secret_value
        })
        unless response.kind_of? Net::HTTPSuccess
            raise "Unexpected response from Heroku API: #{response}: #{response.body}"
        end
        respond_signal(true, nil, event)
        {}
    rescue Exception => e
        respond_signal(false, e.to_s, event)
        raise e
    end
end
