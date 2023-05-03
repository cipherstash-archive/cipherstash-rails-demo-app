Rails.application.routes.draw do
  # Defines the root path route ("/")
  root to: redirect('/admin')

  get '/admin', to: redirect('/admin/patients')
  ActiveAdmin.routes(self)
  resources :patients
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
end
