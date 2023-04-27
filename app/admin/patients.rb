ActiveAdmin.register Patient do

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :full_name, :email, :dob, :weight, :allergies, :medications
  #
  # or
  #
  # permit_params do
  #   permitted = [:full_name, :dob, :weight, :allergies, :medications]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end

  # Comment this out to see all columns.
  index do
    column :full_name
    column :email
    column :dob
    column :weight
    column :allergies
    column :medications
    actions
  end

  filter :dob, as: :date_range
  filter :weight

  filter :full_name_filter,
  as: :string,
  label: 'Full name',
  filters: [:contains, :equals]

  filter :email_filter,
  as: :string,
  label: 'Email',
  filters: [:contains, :equals]

  filter :allergies_filter,
  as: :string,
  label: 'Allergies',
  filters: [:contains, :equals]

  filter :medications_filter,
  as: :string,
  label: 'Medications',
  filters: [:contains, :equals]

end
