# Preview all emails at http://localhost:3000/rails/mailers/error_mailer
class ErrorMailerPreview < ActionMailer::Preview
  default from: "th.rondio@gmail.com"


  def welcome_email
    @error = params[:error]
    p params[:error]
    mail(to: 'th.rondio@gmail.com', subject: 'Error')

  end
end
