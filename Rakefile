require 'fileutils'
require 'erb'
require 'yaml'
require 'ostruct'
require 'github_api'

sync = true

################################################################################
# Initialization
################################################################################
task :default => :deploy

desc "deploy the application"

task :do_deploy => [:symlink_configs, :disable_web, :tomcat_stop,
                    :deploy_war, :load_crontab, :tomcat_start, :enable_web]

task :deploy => [:parse_args, :svn_export, :do_deploy]
task :gdeploy => [:parse_args, :github_release_export, :do_deploy]

desc "Full restart without deploy"
task :restart => [:disable_web, :tomcat_stop, :tomcat_start, :enable_web]

task :parse_args do
  unless ENV['APP']
    $stderr.puts "Usage: rake APP=<app_name>"
    exit(1)
  end

  base_dir = ENV['DEPLOY_BASE'] || ENV['HOME']
  config_dir = "#{base_dir}/.deploy_config/#{ENV['APP']}"
  work_dir = "#{base_dir}/.deploy_work"

  $config             = OpenStruct.new(YAML.load_file("#{config_dir}/deploy.yml"))
  $config.config_dir  = config_dir
  $config.debug       = (ENV['DEBUG'] == 'true')
  $config.app_name    = ENV['APP']
  $config.app_user    = "app_#{ENV['APP']}"
  $config.tag         = ENV['TAG']
  $config.branch      = ENV['BRANCH'] || $config.tag || 'master'
  $config.war         = ENV['WAR'] || ($config.branch == 'master') ? 'trunk.war' : "#{$config.branch}.war"
  $config.release_url = "#{$config.svn_project_url}/#{$config.war}"
  $config.work_dir    = "#{work_dir}/#{$config.app_name}"

  if $config.github_api_token
    $github = Github.new do |c|
      c.oauth_token = $config.github_api_token
      c.user = 'ucb-ist-eas'
      c.repo = $config.app_name
    end
  end

  if $config.debug
    puts($config.inspect)
  end
end


################################################################################
# Deploy War
################################################################################
desc "Deploy the war file to tomcat webapps dir"
task :deploy_war => [:parse_args, :ensure_work_directory] do
  progress "Deploying war to tomcat" do

    webapps  = $config.webapps_dir
    app      = $config.app_name
    root     = "ROOT"
    app_user = $config.app_user

    FileUtils.cd($config.work_dir) do
      run_cmd "sudo -u #{app_user} rm -rf #{webapps}/#{root}/*"
      run_cmd "rm -rf #{webapps}/#{root}"
      run_cmd "cp -R . #{webapps}/#{app}"
      run_cmd "mv #{webapps}/#{app} #{webapps}/#{root}"
    end

  end
end


################################################################################
# Start/Stop Tomcat
################################################################################
desc "stop tomcat application server"
task :tomcat_stop => [:parse_args] do
  unless $dry_run
    status_cmd = "sudo service tomcat6-#{$config.app_name} status"
    stop_cmd = "sudo service tomcat6-#{$config.app_name} stop"

    output = `#{status_cmd}`.chomp
    if $?.exitstatus == 3
      puts(output)
    else
      output = `#{stop_cmd}`.chomp
      if $?.exitstatus == 0
        puts(output)
      else
        $stderr.puts(output)
        exit(1)
      end
    end
  end
end

desc "start tomcat application server"
task :tomcat_start => [:parse_args] do
  unless $dry_run
    output = `sudo service tomcat6-#{$config.app_name} start`.chomp
    puts(output)
  end
end


################################################################################
# Checkout Source Code
################################################################################
def copy_yml_configs
  Dir["#{$config.config_dir}/*.yml"].each do |file_path|
    file_name = File.basename(file_path)
    unless file_name == "deploy.yml"
      `cp #{file_path} ./WEB-INF/config/#{file_name}`
    end
  end
end

def configure_web_xml
  web_xml = "WEB-INF/web.xml"

  lines = File.readlines(web_xml)
  File.open(web_xml, "w") do |f|
    lines.each do |line|
      if line =~ /<param-value>production<\/param-value>/
        f.puts("<param-value>#{$config.rails_env}<\/param-value>")
      elsif line =~ /<param-value>ci<\/param-value>/
        f.puts("<param-value>#{$config.rails_env}<\/param-value>")
      else
        f.puts(line)
      end
    end
  end
end

def symlink_tmp_to_temp
  `ln -s /var/lib/tomcat6-#{$config.app_name}/temp WEB-INF/tmp`	
end

def extract_war
  `jar -xvf *.war`
  `rm -rf *.war`
end

desc "Embed and link configs"
task :symlink_configs => [:ensure_work_directory] do
  progress "Embedding configs and linking directories" do

    FileUtils.cd($config.work_dir) do
      extract_war
      copy_yml_configs
      configure_web_xml
      symlink_tmp_to_temp
    end	

  end
end

desc "download project from svn"
task :svn_export => [:parse_args, :svn_war_exists, :ensure_work_directory] do
  progress "Exporting code from SVN (#{$config.release_url})" do

    app_dir = $config.app_name

    if File.exists?(app_dir)
      puts "App dir #{app_dir} already exists.  Incomplete deploy?"
      exit(1)
    end

    run_cmd("svn export #{$config.release_url}")

  end
end

desc "download project from github"
task :github_release_export => [:parse_args, :ensure_work_directory] do 
  if $config.tag.nil?

    # Look at the list of releases and pick with the highest number matching the branch
    releases = $github.repos.releases.list('ucb-ist-eas', $config.app_name)
    branch_tags = releases.map(&:tag_name).select { |t| t =~ /\A#{$config.branch}-\d+\Z/ }
    branch_tags.sort_by! { |t| t =~ /-(\d+)\Z/; $1.to_i }
    
    if branch_tags.empty?
      puts "No tags found for BRANCH=#{$config.branch}. Use TAG variable to specify a particular tag."
      exit 1
    else
      $config.tag = branch_tags.last
    end
  end

  progress "Exporting build war file from Github for tag #{$config.tag}" do

    app_dir = $config.app_name
    orig_war = "#{$config.app_name}.war"

    cmd =  %{github-release download
             -s #{$config.github_api_token} 
             -u ucb-ist-eas
             -r #{$config.app_name}
             -t #{$config.tag}
             -n #{orig_war}}

    cmd.gsub!(/[[:space:]]+/, " ")

    run_cmd cmd, fail_msg: "Could not download the release.  Is the tag right?  Is github-release installed?"

    FileUtils.mv(orig_war, $config.war)

  end
end

task :svn_war_exists => [:svn_project_exists] do
  run_cmd "svn ls #{$config.release_url} 2>&1",
    fail_msg: "SVN URL not found: #{$config.release_url}"
end

task :svn_project_exists => [:parse_args] do
  run_cmd "svn ls #{$config.svn_project_url} 2>&1",
    fail_msg: "SVN URL not found: #{$config.svn_project_url}"
end

desc "Create work directory if necessary"
task :ensure_work_directory => [:parse_args] do
  run_cmd "mkdir -p #{$config.work_dir}", 
    fail_msg: "Cannot create work directory: #{$config.work_dir}"

  FileUtils.cd($config.work_dir)
end

################################################################################
# Enable/Disable web
################################################################################
desc "remove maintenance file and enable web access to app"
task :enable_web => [:parse_args] do
  progress "Enabling tomcat proxy, remove maint message" do

    file = $config.work_dir
    FileUtils.rm_rf(file) if File.exists?(file)
    FileUtils.rm_rf($config.maint_file) if File.exists?($config.maint_file)

  end
end

desc "display maintenance file and disable web access to app"
task :disable_web => [:parse_args] do
  progress "Disabling tomcat proxy, display maint message" do

    maint_start = Time.now.strftime("%m-%d-%Y %H:%M:%S")
    template = ERB.new($template)
    File.open($config.maint_file, "w") do |f|
      f.puts template.result(binding)
    end

    raise "file is missing" unless File.exists?($config.maint_file)
  end
end

$template = %q{
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
       "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">

<head>
  <meta http-equiv="content-type" content="text/html; charset=UTF-8" />
  <title>Site Maintenance</title>
  <style type="text/css">
  body { background-color: #fff; color: #666; text-align: center; font-family: arial, sans-serif; }
  div.dialog {
  width: 35em;
  padding: 0 3em;
  margin: 3em auto 0 auto;
  border: 1px solid #ccc;
  border-right-color: #999;
  border-bottom-color: #999;
  }
  h1 { font-size: 100%; color: #f00; line-height: 1.5em; }
  </style>
</head>

<body>
  <div class="dialog">
    <h1>Site Maintenance</h1>
    <p>
        The site is down for maintenance as of: <strong><%= maint_start %></strong> <br/>
        it should be available shortly.
    </p>
  </div>
</body>
</html>
}


################################################################################
# Cron Jobs
################################################################################

desc "load cron jobs from crontab"
task :load_crontab do
  crontab_file = "#{$config.app_name}/config/crontab.txt"
  if $config.rails_env == "production" && File.exists?(crontab_file)
    `/usr/bin/crontab -u app_#{$config.app_name} #{crontab_file}`
  end
end

################################################################################
# Misc
################################################################################

desc "curls the ~/app_monitor url and performs a basic health check"
task :health_check => [:parse_args] do
  progress "Performing health check" do 

    result = `curl -m 10 -s localhost:#{$config.tomcat_port}/app_monitor`.chomp

    raise result unless result == "OK"

  end
end

def run_cmd(cmd_str, opts = {})
  IO.popen(cmd_str) { |f|0
                      until f.eof?
                        str = f.gets
                        puts(str) if $debug_mode
                      end
  }

  if opts[:fail_msg] && $?.exitstatus.to_i != 0
    raise(opts[:fail_msg])
  end
end

def progress(msg)
  print "%-59s" % [msg + ":"]
  yield
  puts "[#{"  OK  ".green}]" 
rescue
  puts "[#{"FAILED".red}]"
  exit(1)
end

class String
  # colorization
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end
end




