Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  post "/lead-webhook" => "hubspot#lead_webhook"
  post "/site-visit-incomplete-webhook" => "hubspot#site_visit_incomplete_webhook"
  post "/disqualify-webhook" => "hubspot#disqualify_webhook"
  post '/sm-quote/',to: 'simpro#quote'
  post '/sm-job/',to: 'simpro#job'
  post '/create-job',to: 'hubspot#create_job'
  post '/contact-webhook',to: 'hubspot#contact_webhook'
  post '/create-support-quote',to: 'hubspot#create_support_quote'
  post '/create-hs-record',to: 'hubspot#create_hs_record'
  post '/create-ticket-job',to: 'hubspot#create_ticket_job'

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
