#
# Cookbook Name:: zipr
# Recipe:: default
#

build_essential 'Install required dev binaries' do
  action :install
  compile_time true
  not_if { node['platform'] == 'windows' }
end

chef_gem 'seven_zip_ruby' do
  action :install
  compile_time true
  version '1.2.5'
  source "#{Chef::Config[:file_cache_path]}/cookbooks/zipr/files/default/seven_zip_ruby-1.2.5.gem"
end

chef_gem 'rubyzip' do
  action :install
  compile_time true
  version '1.2.0'
  not_if { Gem::Version.new(Chef::VERSION) >= Gem::Version.new('13.0.0') }
end
