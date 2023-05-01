class Patient < ApplicationRecord
  # This will be removed when GA is released.
  self.ignored_columns = %w[wildcardoperatorworkaround]
  # This will be removed when GA is released.
  def self.columns
    super.reject {|column| column.name.starts_with?('__')}
  end

  attribute :full_name, :string
  attribute :email, :string
  attribute :dob, :date
  attribute :weight, :float
  attribute :allergies, :string
  attribute :medications, :string
  # The rails demo uses ActiveAdmin, which uses Ransack for the filters.
  # For the dob and weight filters to continue to work, the below types need to be added to the model.
  ransacker :dob, type: :date
  ransacker :weight, type: :numeric


  def self.full_name_filter_contains(value)

    where("full_name LIKE ?", "#{sanitize_sql_like(value)}")
  end

  def self.full_name_filter_equals(value)

    where(full_name: "#{sanitize_sql_like(value)}")
  end

  def self.email_filter_contains(value)

    where("email LIKE ?", "#{sanitize_sql_like(value)}")
  end

  def self.email_filter_equals(value)

    where(email: "#{sanitize_sql_like(value)}")
  end

  def self.allergies_filter_contains(value)

    where("allergies LIKE ?", "#{sanitize_sql_like(value)}")
  end

  def self.allergies_filter_equals(value)

    where(allergies: "#{sanitize_sql_like(value)}")
  end

  def self.medications_filter_contains(value)

    where("medications LIKE ?", "#{sanitize_sql_like(value)}")
  end

  def self.medications_filter_equals(value)

    where(medications: "#{sanitize_sql_like(value)}")
  end


  def self.ransackable_scopes(_auth_object = nil)
    %i(full_name_filter_contains full_name_filter_equals email_filter_contains email_filter_equals allergies_filter_contains allergies_filter_equals medications_filter_contains medications_filter_equals)
  end
end
