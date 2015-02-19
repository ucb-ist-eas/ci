
require 'warbler'

namespace :ci do

  desc "Run CI setup tasks"
  task :setup => %w[ config:copy_defaults ]

  desc "Run Rspec for CI"
  task :spec => %w[ setup spec ]

  task :war => %w[ war:archive ]

  namespace :war do
    
    task :archive do
      if war_branch?
        Rake::Task['ci:war:prepare'].invoke
        Rake::Task['ci:war:create'].invoke
      else
        puts "Not creating a war because this is a personal branch (has a / in it)"
        exit 1
      end
    end

    task :create do
      create_war
    end

    task :prepare => %w[ assets:precompile ] do
      record_build_number
    end
  end

  def record_build_number
    if build_number = ENV['TRAVIS_BUILD_NUMBER']
      path = File.join(workspace_path, 'BUILD')
      File.open(path, "w") do |f|
        puts "Storing build number #{build_number} into #{path}"
        f.write(build_number)
      end
    end
  end

  def create_war
    RakeFileUtils.verbose_flag = true
    Warbler::Task.new(branch)

    $stdout.print("Building war file: ")
    Rake::Task[branch].invoke()
  end

  def branch
    branch = ENV['TRAVIS_BRANCH']

    unless branch
      branch = `git rev-parse --abbrev-ref HEAD`.strip
    end

    branch = 'trunk' if branch == 'master'
    branch
  end

  def war_name
    branch
  end

  def war_branch?
    !branch.include?('/')
  end

  def workspace_path
    ENV['TRAVIS_BUILD_DIR'] || '.'
  end
  
  def app_name
    if ENV['TRAVIS_REPO_SLUG']
      ENV['TRAVIS_REPO_SLUG'].split('/').last
    else
      url = `git config --get remote.origin.url`
      if url =~ /ucb-ist-eas\/(.*)\.git/
        $1
      else
        raise "cannot determine branch"
      end
    end
  end

  def run_cmd(cmd, env_vars = [])
    # TODO: Enable after qt47 is installed
    # env = (default_env_vars + env_vars).join(" ")

    env = env_vars.join(" ")
    full_cmd = "#{env} #{cmd}"
    $stdout.puts("#{full_cmd} ... ")

    output = `#{full_cmd} 2>&1`
    $stdout.puts(output)

    if $?.success?
      $stdout.puts("[OK]")
    else
      $stdout.puts("[FAILED]")
      $stdout.puts($?.exitstatus)
      exit($?.exitstatus)
    end

    output
  end

end

namespace :config do

  desc "copy .example files into their real locations"
  task :copy_defaults do
    Dir.glob("config/*.yml.example").each do |file_path|
      file_name = File.basename(file_path).split(".")[0..1].join(".")
      dir_name = File.dirname(file_path)
      FileUtils.cp(file_path, File.join(dir_name, file_name))
    end
  end

  desc "Generate .travis.yml file for use with Travis-CI"
  task :generate_travis_yml do

    require 'erb'

    `travis help`
    if $? == 1
      puts "This command requires the travis CLI.  Install it with 'gem install travis'"
      exit 1
    end

    filename = File.join(File.dirname(__FILE__), "..", "templates", "travis.yml.erb")
    input = File.read(filename)
    erb = ERB.new(input)

    print "App Name: "
    app_name = $stdin.gets.strip

    print "Github API Key: "
    api_key = $stdin.gets.strip

    print "Slack Integration Key (optional): "
    slack_key = $stdin.gets.strip
    slack_key = nil if slack_key == ''

    text = erb.result(binding)
    File.write(Rails.root.join('.travis.yml'), text)

    `travis encrypt --add deploy.api-key #{api_key}`

    if slack_key
      `travis encrypt --add notifications.slack #{slack_key}`
    end

    `travis lint`

  end
end
