# config/initializers/smtp.rb
ActionMailer::Base.smtp_settings = {
  address: "smtp.gmail.com",
  port: 587,
  domain: 'gmail.com',
  user_name: "th.rondio@gmail.com",
  password: "yakevejvvbdexfuh",
  authentication: :login,
  enable_starttls_auto: true
}
