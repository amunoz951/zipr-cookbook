name 'kitchen_zipr'

default_source :supermarket, 'https://supermarket.chef.io'

run_list 'zipr_test::default'

# which cookbooks to use
cookbook 'zipr', '>= 0.0.0', path: '.'
cookbook 'zipr_test', '>= 0.0.0', path: 'test/cookbooks/zipr_test'
