# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/welcome
  def welcome
    # UserMailer.welcome
    mail(to: 'th.rondio@gmail.com', subject: 'Welcome to Le Wagon')

  end

end
