Rails.application.routes.draw do

  namespace :api do
    resources :events, :only => :show
    resources :tickets, :only => :index
    resources :shows, :only => :show
    resources :organizations, :only => [] do
      resources :events
      resources :shows
      get :authorization
    end
  end

  namespace :store do
    resources :events, :only => :show
    resources :shows, :only => :show
    resource :order, :only => [:sync] do      
      post :sync, :on => :collection
    end
    resource :checkout, :only => :create
  end

  devise_for :users
  devise_scope :user do
    get "sign_up", :to => "devise/registrations#new"
  end

  resources :organizations do
    put :tax_info, :on => :member
    resources :memberships
    member do
      post :connect
    end
  end

  resources :ticket_offers do
    collection do
      post "/new", :to => "ticket_offers#new"
      get "/create", :to => "ticket_offers#create"
    end
    member do
      get :accept
      get :decline
    end
  end

  resources :export do
    collection do
      get :contacts
      get :donations
      get :ticket_sales
    end
  end

  resources :kits, :except => :index do
    get :alternatives, :on => :collection
    post :requirements, :on => :collection
    get :requirements, :on => :collection
  end

  resources :reports, :only => :index
  resources :statements, :only => [ :index, :show ] do
    resources :slices, :only => [ :index ] do
      collection do
        get :data
      end
    end
  end

  resources :people do
    resources :actions

    ["get_action", 
     "refund_action", 
     "join_action", 
     "hear_action", 
     "say_action", 
     "do_action", 
     "go_action",
     "give_action"].each { |action_type| resources :actions, :as => action_type }

    resources :notes
    resources :phones, :only => [:create, :destroy]
    resource  :address, :only => [:create, :update, :destroy]
  end
  resources :searches, :only => [:new, :create, :show] do
    resources :actions, :only => [:new, :create]
    member do
      post :tag
    end
  end
  resources :segments, :only => [:index, :show, :create, :destroy] do
    resources :actions, :only => [:new, :create]
    member do
      post :tag
    end
  end

  resources :events do
    member do
      get :widget
      get :storefront_link
      get :resell
      get :wp_plugin
      get :prices
      get :image
      get :messages
    end
    resources :discounts
    resources :shows do
      resource :sales, :only => [:new, :create, :show, :update]
      member do
        get :door_list
        post :duplicate
      end
      collection do
        post :built
        post :on_sale
        post :published
        post :unpublished
      end
    end
    resource :venue, :only => [:edit, :update]
  end

  resources :shows, :only => [] do
    resources :tickets, :only => [ :new, :create ] do
      collection do
        delete :delete
        put :on_sale
        put :off_sale
        put :bulk_edit
        put :change_prices
        get :set_new_price
      end
    end
  end

  resources :charts, :only => [:update] do
    resources :sections
  end

  resources :sections do
    collection do
      post :on_sale
      post :off_sale
    end
  end

  resources :orders do
    resource :assignment, :only => [ :new, :create ]
    collection do
      get :sales
    end
    member do
      get :resend
    end
  end

  resources :contributions

  resources :refunds, :only => [ :new, :create ]
  resources :exchanges, :only => [ :new, :create ]
  resources :returns, :only => :create
  resources :comps, :only => [ :new, :create ]
  resources :merges, :only => [ :new, :create ]

  resources :imports do
    member do
      get :approve
      get :recall
    end
    collection do
      get :template
    end
  end

  resources :discounts_reports, :only => [:index]

  match '/recent_activity' => 'index#recent_activity', :as => :recent_activity
  match '/events/:event_id/charts/' => 'events#assign', :as => :assign_chart, :via => "post"
  match '/people/:id/star/:type/:action_id' => 'people#star', :as => :star, :via => "post"
  match '/people/:id/tag/' => 'people#tag', :as => :new_tag, :via => "post"
  match '/people/:id/tag/:tag' => 'people#untag', :as => :untag, :via => "delete"

  match '/dashboard' => 'index#dashboard', :constraints => lambda{|r| r.env["warden"].authenticate?}

  root :to => 'index#dashboard'

end
