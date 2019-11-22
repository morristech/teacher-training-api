ActionMailer::Base.add_delivery_method :govuk_notify, GovukNotifyRails::Delivery, api_key: MCBE.govuk_notify.api_key
