name 'kitchen_zipr'

default_source :supermarket, 'https://supermarket.chef.io'

run_list [
  'zipr_test::default',
]

# which cookbooks to use
cookbook 'zipr', path: '.'
cookbook 'zipr_test', path: 'test/cookbooks/zipr_test'
