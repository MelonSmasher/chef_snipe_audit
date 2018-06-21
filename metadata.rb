name 'snipe_audit'
maintainer 'Alex Markessinis'
maintainer_email 'markea125@gmail.com'
license 'MIT'
description 'Adds PC information to Snipe-IT.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
issues_url 'https://github.com/MelonSmasher/chef_snipe_audit/issues'
source_url 'https://github.com/MelonSmasher/chef_snipe_audit'
version '0.1.6'
chef_version ">= 12" if respond_to?(:chef_version)
supports 'windows'

