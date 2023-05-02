class Patient < ApplicationRecord
  # Note that the types of CipherStash-protected columns must be specified here in
  # order to drop the original plaintext columns and for "encrypted" mode to work.
  self.ignored_columns = %w[wildcardoperatorfix]
  ##### UNCOMMENT THE BELOW WHEN SWITCHING TO ENCRYPTED MODES#####

  # attribute :full_name, :string
  # attribute :email, :string
  # attribute :dob, :date
  # attribute :weight, :float
  # attribute :allergies, :string
  # attribute :medications, :string
  # The rails demo uses ActiveAdmin, which uses Ransack for the filters.
  # For the dob and weight filters to continue to work, the below types need to be added to the model.

  ##### UNCOMMENT THE BELOW WHEN SWITCHING TO ENCRYPTED MODES#####
  # ransacker :dob, type: :date
  # ransacker :weight, type: :numeric
end
