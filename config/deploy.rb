# encoding: UTF-8
require 'bundler/capistrano'
require 'whenever/capistrano'

# Common options
set :use_sudo,   false
set :scm,        :git
set :user,       "delicious"
set :project,    "DeliciousLetter"
set :deploy_via, :copy
set :copy_cache, true
set :git_shallow_clone, 1
set :repository, "git://github.com/shakaman/#{project}.git"
set :application, "192.168.83.12"
set :deploy_to, "/home/#{user}/"
b = exists?(:branch) ? branch : 'master'
set :branch, b
server "#{user}@#{application}", :app, :web, :db, :primary => true
set :keep_releases, 5
set :dl_env, 'production'

default_run_options[:pty] = true # Temporary hack
default_run_options[:env] ||= {}
default_run_options[:env]['DL_ENV'] = dl_env

set :default_environment, {
  'PATH' => "/home/#{user}/.rbenv/shims:/home/#{user}/.rbenv/bin:/home/#{user}/shared/bundle/ruby/1.9.1/bin:$PATH"
}

desc 'help'
task :help do
  puts <<-eos
# You can specify the git branch with:
#   $ cap deploy -s branch=<GIT_BRANCH>
  eos
end

namespace :fs do
  desc "create filesystem required folders"
  task :create do
    run "cd #{release_path} && ln -s #{shared_path}/#{dl_env}.yml config/#{dl_env}.yml"
  end
end
after 'deploy:update_code', 'fs:create'

namespace :config do
  desc 'deploy config'
  task :deploy do
    upload "config/#{dl_env}.yml", "#{shared_path}/#{dl_env}.yml", :via => :scp
  end
end
after 'deploy:setup', 'config:deploy'

# The hard-core deployment rules
namespace :deploy do
  desc 'Start app'
  task :start, :roles => :app do
    # None
  end

  desc 'Stop app'
  task :stop, :roles => :app do
    # None
  end

  desc 'Restart app'
  task :restart, :roles => :app, :except => { :no_release => true }  do
    # None
  end

  desc 'Finalize update'
  task :finalize_update, :except => { :no_release => true } do
    run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)
  end
end
