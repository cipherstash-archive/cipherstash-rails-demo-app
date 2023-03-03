class Patient < ApplicationRecord
  # This will be removed when GA is released.
  self.ignored_columns = %w[wildcardoperatorworkaround]
  # This will be removed when GA is released.
  def self.columns
    super.reject {|column| column.name.starts_with?('__')}
  end
end
