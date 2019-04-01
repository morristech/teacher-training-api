require 'spec_helper'
require "#{Rails.root}/lib/mcb"

describe 'mcb command' do
  describe '#load_commands' do
    include FakeFS::SpecHelpers

    it 'loads the files in a directory' do
      FakeFS do
        commands_lib_dir = 'lib/mcb/commands'
        FileUtils.mkdir_p(commands_lib_dir)
        FileUtils.touch("#{commands_lib_dir}/test.rb")

        cmd = Cri::Command.define { name 'mcb' }
        MCB.load_commands(cmd, commands_lib_dir)

        expect(cmd.commands.count).to eq 1
        expect(cmd.commands.first.name).to eq 'test'
      end
    end

    it 'loads the files in a sub-directories as sub-commands' do
      FakeFS do
        commands_lib_dir = 'lib/mcb/commands'
        FileUtils.mkdir_p(commands_lib_dir)
        FileUtils.touch("#{commands_lib_dir}/test.rb")
        FileUtils.mkdir_p("#{commands_lib_dir}/test")
        FileUtils.touch("#{commands_lib_dir}/test/sub.rb")

        cmd = Cri::Command.define { name 'mcb' }
        MCB.load_commands(cmd, commands_lib_dir)

        expect(cmd.commands.count).to eq 1
        expect(cmd.commands.first.name).to eq 'test'
        expect(cmd.commands.first.commands.count).to eq 1
        expect(cmd.commands.first.commands.first.name).to eq 'sub'
      end
    end

    it 'raises a helpful error if an expected command is not defined' do
      FakeFS do
        commands_lib_dir = 'lib/mcb/commands'
        FileUtils.mkdir_p(commands_lib_dir)
        FileUtils.mkdir_p("#{commands_lib_dir}/test")
        FileUtils.touch("#{commands_lib_dir}/test/sub.rb")

        cmd = Cri::Command.define { name 'mcb' }
        expect {
          MCB.load_commands(cmd, commands_lib_dir)
        }.to raise_error(
          "Command lib/mcb/commands/test.rb must be defined to have sub-commands lib/mcb/commands/test"
        )
      end
    end
  end
end