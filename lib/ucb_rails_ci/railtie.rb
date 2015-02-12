require 'ucb_rails_ci'
require 'rails'
module UcbRailsCi
  class Railtie < Rails::Railtie
    railtie_name :ucb_rails_ci

    rake_tasks do
      load File.join(File.dirname(__FILE__), '..', '..', 'tasks', 'ucb_rails_ci.rake')
    end
  end
end
