require 'ucb_rails_ci'
require 'rails'
module UcbRailsCi
  class Railtie < Rails::Railtie
    railtie_name :ucb_rails_ci

    rake_tasks do
      load "lib/tasks/ucb_rails_ci.rake"
    end
  end
end
