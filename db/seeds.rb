# Create a default admin user
puts "Creating default admin user..."
User.find_or_create_by!(email: 'admin@example.com') do |user|
  user.name = 'Administrador'
  user.password = 'password123'
  user.password_confirmation = 'password123'
  user.admin = true
end
puts "Admin user created: admin@example.com / password123"

# Create a normal user for testing
User.find_or_create_by!(email: 'user@example.com') do |user|
  user.name = 'Usuário Padrão'
  user.password = 'password123'
  user.password_confirmation = 'password123'
  user.admin = false
end
puts "Normal user created: user@example.com / password123"
