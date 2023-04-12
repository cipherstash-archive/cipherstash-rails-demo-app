Rails.application.routes.draw do
  get '/admin', to: redirect('/admin/patients')
  ActiveAdmin.routes(self)
  resources :patients
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
