summary 'Show UCAS preferences for provider with given code'
param :code

run do |_opts, args, _cmd|
  MCB.init_rails

  code = args[:code]

  provider = Provider.find_by(provider_code: code)

  if provider.ucas_preferences
    puts Terminal::Table.new rows: provider.ucas_preferences.attributes
  else
    puts 'no preferences found'
  end
end