# Preview all emails at http://localhost:3000/rails/mailers/error_mailer
class ErrorMailerPreview < ActionMailer::Preview


  def welcome_email
    # @error = params[:error]
    # p params[:error]
    p "mm"
    mail(to: 'th.rondio@gmail.com', subject: 'Error')

  end
end
