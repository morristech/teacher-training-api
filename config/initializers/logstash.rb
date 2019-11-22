LogStashLogger.configure do |config|
  config.customize_event do |event|
    event["application"] = MCBE.application
    event["environment"] = Rails.env
  end
end
