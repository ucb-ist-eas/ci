require 'fileutils'
require 'erb'
require 'yaml'
require 'ostruct'
$stdout.sync = true


OK_MSG    = "[  OK  ]"
FAIL_MSG  = "[FAILED]"


################################################################################
# Initialization
################################################################################
task :default => :deploy
desc "deploy the application"
task :deploy => [:parse_args, :disable_web, :tomcat_stop, :svn_export, :deploy_war, :load_crontab, :tomcat_start, :enable_web]
task :gdeploy => [:parse_args, :git_checkout, :build_war, :disable_web, :tomcat_stop, :deploy_war, :load_crontab, :tomcat_start, :enable_web]

desc "Full restart without deploy"
task :restart => [:disable_web, :tomcat_stop, :tomcat_start, :enable_web]

task :parse_args do
  $dry_run = true

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
  $config.branch      = ENV['TAG'] || ENV['BRANCH'] || 'master'
  $config.war         = ENV['WAR'] || ($config.branch == 'master') ? 'trunk.war' : "#{$config.branch}.war"
  $config.release_url = "#{$config.svn_project_url}/#{$config.war}"
  $config.work_dir    = "#{work_dir}/#{$config.app_name}"

  if $config.debug
    $stdout.puts($config.inspect)
  end
end


################################################################################
# Build/Deploy War
################################################################################
desc "Deploy the war file to tomcat webapps dir"
task :deploy_war => [:svn_export, :parse_args] do
  $stdout.print("Deploying war to tomcat: ")

  webapps  = $config.webapps_dir
  app      = $config.app_name
  root     = "ROOT"
  app_user = $config.app_user

  `sudo -u #{app_user} rm -rf #{webapps}/#{root}/*`
  `rm -rf #{webapps}/#{root}`
  `cp -R #{app} #{webapps}/`
  `mv #{webapps}/#{app} #{webapps}/#{root}`

  $stdout.puts(OK_MSG)
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
     $stdout.puts(output)
    else
      output = `#{stop_cmd}`.chomp
      if $?.exitstatus == 0
        $stdout.puts(output)
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
    $stdout.puts(output)
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
task :symlink_configs do
  $stdout.print "Embedding configs and linking directories"

  app_dir = $config.app_name

  FileUtils.cd(app_dir) do
    extract_war
    copy_yml_configs
    configure_web_xml
    symlink_tmp_to_temp
  end	

  $stdout.puts(OK_MSG)
end

desc "download project from svn"
task :svn_export => [:svn_war_exists] do
  $stdout.print "Exporting code from SVN (#{$config.release_url}): "

  app_dir = $config.app_name

  if File.exists?(app_dir)
    puts "App dir #{app_dir} already exists.  Incomplete deploy?"
    exit(1)
  end

  run_cmd("svn export #{$config.release_url}")
  FileUtils.mkdir(app_dir)
  FileUtils.mv($config.war, app_dir)

  $stdout.puts(OK_MSG)
end

task :svn_war_exists => [:svn_project_exists] do
  run_cmd "svn ls #{$config.release_url} 2>&1",
    fail_msg: "SVN URL not found: #{$config.release_url}"
end

task :svn_project_exists => [:parse_args] do
  run_cmd "svn ls #{$config.svn_project_url} 2>&1",
    fail_msg: "SVN URL not found: #{$config.svn_project_url}"
end

desc "Build a war file localy"
task :build_war => [:git_checkout] do

  FileUtils.cd($config.work_dir) do
    File.open("BUILD", "w+") do |file|
      file.print $config.branch
    end
    run_cmd "bundle"
    run_cmd "bundle exec rake ci:war:archive"
  end
end

desc "Check out the requested branch/tag from git"
task :git_checkout => [:ensure_work_directory] do

  url = $config.git_project_url || raise("Missing git repo url")
  branch = "origin/#{$config.branch}"

  $stdout.puts "Checking out branch #{branch}"

  FileUtils.cd($config.work_dir) do

    if !File.directory?('.git')
      run_cmd "git clone #{url} .", fail_msg: "Git cannot clone #{url} into work dir"
    end

    run_cmd "git fetch --tags", fail_msg: "Cannot fetch from git"
    run_cmd "git checkout #{branch}", fail_msg: "Cannot checkout #{branch}"
  end
end

desc "Create work directory if necessary"
task :ensure_work_directory => [:parse_args] do
  run_cmd "mkdir -p #{$config.work_dir}", 
    fail_msg: "Cannot create work directory: #{$config.work_dir}"
end

################################################################################
# Enable/Disable web
################################################################################
desc "remove maintenance file and enable web access to app"
task :enable_web => [:parse_args] do
  $stdout.print("Enabling tomcat proxy, remove maint message: ")

  file = "/home/app_relmgt/#{$config.app_name}"
  FileUtils.rm_rf(file) if File.exists?(file)
  FileUtils.rm_rf($config.maint_file) if File.exists?($config.maint_file)

  $stdout.puts(OK_MSG)
end

desc "display maintenance file and disable web access to app"
task :disable_web => [:parse_args] do
  $stdout.print("Disabling tomcat proxy, display maint message: ")

  maint_start = Time.now.strftime("%m-%d-%Y %H:%M:%S")
  template = ERB.new($template)
  File.open($config.maint_file, "w") do |f|
    f.puts template.result(binding)
  end

  if File.exists?($config.maint_file)
    $stdout.puts(OK_MSG)
  else
    $stderr.puts(FAIL_MSG)
    exit(1)
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
  $stdout.print("Performing health check: ")

  result = `curl -m 10 -s localhost:#{$config.tomcat_port}/app_monitor`.chomp
  if result == "OK"
    $stdout.puts(OK_MSG)
  else
    $stdout.puts(FAIL_MSG)
    $stderr.puts(result)
    exit(1)
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
    $stdout.puts(FAIL_MSG)
    $stderr.puts(opts[:fail_msg])
    exit(1)
  end

end




