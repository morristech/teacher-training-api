load 'bin/mcb'

RSpec.configure do |config|
  # Ensure all mcb specs are tagged up so that the below hooks run to stub out
  # the dangerous things that we wouldn't want to leak through to the user's
  # system or dirty the test environment.
  config.define_derived_metadata(
    file_path: %r{spec/lib/mcb.* | bin/mcb_spec.rb}x
  ) do |metadata|
    metadata[:mcb_cli] = true
  end


  # Certain methods can change stuff permanently in tests, causing intermittent
  # false positives or false negatives, or other issues. Any spec that tests
  # the mcb CLI should, to be safe, have the 'mcb_cli: true' metadata to ensure
  # it's safe.
  config.before(:each, mcb_cli: true) do |example|
    # This gets memoized so needs to be wiped out for every test.
    MCB.instance_eval { @config = nil }

    unless example.metadata[:stub_init_rails] == false
      # "init_rails" will try to exec the Rails runner if Rails isn't already
      # loaded.
      allow(MCB).to receive(:init_rails)
    end
    # "run_command" is used to run "az" and maybe more. Any test relying on
    # this must stub for it specifically.
    allow(MCB).to receive(:run_command)
  end

  # Ensure that if the config file that is read is not the user's real data,
  # and if saved for any reason it does not over-write the user's.
  config.around(:each, mcb_cli: true) do |example|
    @temp_config_file = Tempfile.new ['mcb_cli_config', '.yml']
    @temp_config_file.close
    MCB.config_file = @temp_config_file.path
    example.run
    @temp_config_file.unlink
  end
end