require 'bundler/capistrano'

# set :whenever_command, "bundle exec whenever"
# require 'whenever/capistrano'

set :application, "memp_app"
set :repository,  "git@github.com:StrataLabs/service-desk.git"
set :deploy_via, :remote_cache
set :scm, :git

set :scm_username, 'akil_rails'
set :use_sudo, false
ssh_options[:keys] = [File.join(ENV["HOME"], ".ssh", "id_rsa")]
delayed_job_flag = false

# set ssh password if passed through script
def deploy_password
  set :password, deploy_script_password rescue nil
end
deploy_password

def aws name
  task name do
    yield    
    set :default_environment, { "PATH" =>
    "/rails/common/ruby-2.0.0-rc1/bin:#{deploy_to}/shared/bundle/ruby/2.0.0/bin:$PATH",
    "LD_LIBRARY_PATH" => "/rails/common/oracle/instantclient_11_2",
    "TNS_ADMIN" => "/rails/common/oracle/network/admin" }
    role :app, location
    role :web, location
    role :db, location, :primary => true
    set :user, 'rails'
    ssh_options[:keys] = [File.join(ENV["HOME"], ".ssh", "id_rsa")]
  end
end

def aws_staging name
  task name do    
    set :branch, "master"   
    yield 
    set :default_environment, { "PATH" =>
    "/rails/common/ruby-2.0.0-rc1/bin:#{deploy_to}/shared/bundle/ruby/2.0.0/bin:$PATH" ,
    "LD_LIBRARY_PATH" => "/rails/common/oracle/instantclient_11_2",
    "TNS_ADMIN" => "/rails/common/oracle/network/admin" }
    role :app, location
    role :web, location
    role :db, location, :primary => true
    set :user, 'rails'
    ssh_options[:keys] = [File.join(ENV["HOME"], ".ssh", "id_rsa")]
  end
end


aws_staging :ec2_staging do
  set :branch, "master"
  set :application, "memp"
  set :deploy_to, "/rails/apps/service-desk"
  set :location, "107.23.108.186"
end


after "deploy:create_symlink", "deploy:update_crontab"
after "deploy:create_symlink", "deploy:delayed_job_restart"
after "deploy:update", "newrelic:notice_deployment"

namespace :deploy do
  after "deploy:update_code" do
    run "cp #{deploy_to}/shared/database.yml #{release_path}/config/database.yml"
    run "cp #{deploy_to}/shared/members_cross_ref.yml #{release_path}/config/members_cross_ref.yml"
    run "cp #{deploy_to}/shared/application.yml #{release_path}/config/application.yml"
    run "cp #{deploy_to}/shared/model_settings.yml #{release_path}/config/model_settings.yml"
    run "cp #{deploy_to}/shared/opac_settings.yml #{release_path}/config/opac_settings.yml"
    run "cp #{deploy_to}/shared/security.yml #{release_path}/config/security.yml"
    run "cp #{deploy_to}/shared/newrelic.yml #{release_path}/config/newrelic.yml"
    run "cp #{deploy_to}/shared/sunspot.yml #{release_path}/config/sunspot.yml"
    run "cp #{deploy_to}/shared/upload.yml #{release_path}/config/upload.yml"
    run "cp #{deploy_to}/shared/setup_mail.rb #{release_path}/config/initializers/setup_mail.rb"
    run "cp #{deploy_to}/shared/omniauth.rb #{release_path}/config/initializers/omniauth.rb"
    run "cp #{deploy_to}/shared/header.jpg #{release_path}/public/images/header.jpg"
    run "cp #{deploy_to}/shared/schedule.rb #{release_path}/config/schedule.rb"
  end

  desc "Update the crontab file"
  task :update_crontab, :roles => :db do
    run "cd #{release_path} && bundle exec whenever --update-crontab #{application}"
  end

  desc "Restart the delayed_job process"
  task :delayed_job_restart, :roles => :app do
    if delayed_job_flag
      run "cd #{current_path} && RAILS_ENV=production script/delayed_job restart"
    end
  end

  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end