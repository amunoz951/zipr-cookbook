#
# Cookbook Name:: zipr
# Recipe:: default
#

chef_gem 'seven_zip_ruby' do
  action :install
  compile_time true
  version '1.2.5'
  source "#{Chef::Config[:file_cache_path]}/cookbooks/zipr/files/default/seven_zip_ruby-1.2.5.gem"  
end
