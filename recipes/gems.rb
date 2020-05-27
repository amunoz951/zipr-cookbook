#
# Cookbook:: zipr
# Recipe:: gems
#
# Description:: Installs all gems required by this cookbook. Should be included before calling any zipr cookbook resources
#

chef_gem 'rubyzip' do
  action :install
  compile_time true
  version '2.3.0'
  not_if { Gem::Version.new(Chef::VERSION) >= Gem::Version.new('13.0.0') }
end

include_recipe 'zipr::seven_zip_ruby'

required_gems = {
  'os' => '~> 1.1', # dependency of zipr gem
  'tzinfo' => '~> 2.0', # dependency of easy_time
  'tzinfo-data' => '~> 1.2019', # dependency of easy_time
  'hashly' => '~> 0.1', # dependency of easy_json_config
  'easy_json_config' => '~> 0.3', # dependency of easy_io
  'easy_time' => '~> 0.1', # dependency of easy_io
  'logger' => '~> 1.4', # dependency of easy_io
  'open3' => '~> 0.1', # dependency of easy_io
  'easy_io' => '~> 0.4', # dependency of zipr gem
  'easy_format' => '~> 0.2', # dependency of zipr gem
  'zipr' => '~> 0.2',
}
required_gems.each do |gem_name, gem_version|
  chef_gem gem_name do
    version gem_version
    compile_time true
    action gem_version.nil? || gem_version.include?('>') ? :upgrade : :install
  end
end

require 'zipr'

EasyIO.logger = Chef::Log
