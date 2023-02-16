class AddProtectDatabaseExtensions < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::Base.connection.execute(File.read("/Users/jamessadler/cipherstash/ruby-conf/driver/database-extensions/postgresql/install.sql"))
  end

  def down
    ActiveRecord::Base.connection.execute(File.read("/Users/jamessadler/cipherstash/ruby-conf/driver/database-extensions/postgresql/uninstall.sql"))
  end
end
