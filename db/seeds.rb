# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Mayor.create(:name => 'Daley', :city => cities.first)
o = [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten
password = (0..20).map{ o[rand(o.length)]  }.join
u = User.new
u.email = 'example@changeme.com'
u.name = 'Default Administrator'
u.password = password
u.password_confirmation = password
u.role = 'board'
u.save!
puts "Created new user with email example@changeme.com and password '#{password}' (no quotes)."
puts "PLEASE LOG IN TO THIS ACCOUNT NOW AND CHANGE THE NAME, EMAIL AND PASSWORD."