Sidekiq.configure_client do |config|
  config.redis = {
    password: MCBE.mcbg.redis_password,
  }
end

Sidekiq.configure_server do |config|
  config.redis = {
    password: MCBE.mcbg.redis_password,
  }

  if MCBE.bg_jobs
    Sidekiq::Cron::Job.load_from_hash MCBE.bg_jobs
  end
end
