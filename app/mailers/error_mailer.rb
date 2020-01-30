class ErrorMailer < ApplicationMailer
  default from: "th.rondio@gmail.com"


  def welcome_email
    @error = params[:error]
    p params[:error]
    mail(to: 'th.rondio@gmail.com', subject: 'Error')

  end
end
