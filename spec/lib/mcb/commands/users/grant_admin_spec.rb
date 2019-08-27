require 'mcb_helper'

describe 'mcb users grant --admin' do
  def grant(id_or_email_or_sign_in_id, commands)
    stderr = ""
    output = with_stubbed_stdout(stdin: commands, stderr: stderr) do
      cmd.run([id_or_email_or_sign_in_id, "--admin"])
    end
    [output, stderr]
  end

  let(:lib_dir) { Rails.root.join('lib') }
  let(:cmd) do
    Cri::Command.load_file(
      "#{lib_dir}/mcb/commands/users/grant.rb"
    )
  end
  let!(:organisation1) { create(:organisation) }
  let!(:organisation2) { create(:organisation) }
  let!(:organisation3) { create(:organisation) } # no provider in this one
  let!(:provider) { create(:provider, organisations: [organisation1]) }
  let!(:provider) { create(:provider, organisations: [organisation2]) }

  let(:output) do
    combined_input = input_commands.map { |c| "#{c}\n" }.join
    grant(id_or_email_or_sign_in_id, combined_input).first
  end

  context 'admin email' do
    context 'when the user exists but is not a member of any orgs' do
      let(:user) { create(:user, :admin, organisations: []) }
      let(:id_or_email_or_sign_in_id) { user.email }
      let(:input_commands) { %w[y] }

      before do
        output
      end

      it 'grants membership of all organisations to that user' do
        expect(user.reload.organisations).to eq([organisation1, organisation2, organisation3])
      end
    end

    context 'when the user exists and is not a member of all orgs' do
      let(:user) { create(:user, :admin, organisations: [organisation2]) }
      let(:id_or_email_or_sign_in_id) { user.email }
      let(:input_commands) { %w[y] }

      before do
        output
      end

      it 'grants membership of all organisations to that user' do
        expect(user.reload.organisations).to eq([organisation1, organisation2, organisation3])
      end
    end
  end

  context 'non-admin email' do
    let(:user) { create(:user, organisations: [organisation2]) }
    let(:id_or_email_or_sign_in_id) { user.email }
    let(:input_commands) { %w[y] }

    before do
      output
    end

    it 'shows a message about refusing to act' do
      expect(output).to include("Refusing to give non-admin user #{user} access to all orgs")
    end

    it 'doesn\'t change the organisation membership of the user' do
      expect(user.reload.organisations).to eq([organisation2])
    end
  end
end