name 'zipr'
maintainer 'Alex Munoz'
maintainer_email 'amunoz951@gmail.com'
license 'Apache-2.0'
description 'Provides idempotent compression and extraction resources for zip and 7-zip files'
source_url 'https://github.com/amunoz951/zipr'
issues_url 'https://github.com/amunoz951/zipr/issues'
chef_version '>= 12'
version '3.0.4'

supports 'windows'
supports 'centos' # Chef-client version '>= 14.14' appears to break building the native gem extensions for seven_zip_ruby
