class InstallCustomDbTypes < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::ConnectionAdapters::CipherStashPG.install
  end

  def down
    ActiveRecord::ConnectionAdapters::CipherStashPG.uninstall
  end
end
