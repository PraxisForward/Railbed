# frozen_string_literal: true

module CredentialsHelpers
  # Reading config before the temp dir goes away keeps the decrypted values.
  def stub_credentials(yaml = "")
    credentials = Dir.mktmpdir do |dir|
      key_path = File.join(dir, "test.key")
      File.write(key_path, ActiveSupport::EncryptedConfiguration.generate_key)
      ActiveSupport::EncryptedConfiguration.new(
        config_path: File.join(dir, "test.yml.enc"),
        key_path:,
        env_key: "CREDENTIALS_SPEC_UNSET_KEY",
        raise_if_missing_key: true
      ).tap do |encrypted|
        encrypted.write(yaml)
        encrypted.config
      end
    end
    allow(Rails.application).to receive(:credentials).and_return(credentials)
  end

  def stub_missing_credentials
    missing = ActiveSupport::EncryptedConfiguration.new(
      config_path: Rails.root.join("tmp/missing.yml.enc"),
      key_path: Rails.root.join("tmp/missing.key"),
      env_key: "CREDENTIALS_SPEC_UNSET_KEY",
      raise_if_missing_key: false
    )
    allow(Rails.application).to receive(:credentials).and_return(missing)
  end
end

RSpec.configure do |config|
  config.include CredentialsHelpers

  config.before { stub_missing_credentials }
end
