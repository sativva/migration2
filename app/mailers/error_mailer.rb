class ErrorMailer < ApplicationMailer


  def welcome_email
    # @error = params[:error]
    # p params[:error]
    p "??"
    mail(to: 'th.rondio@gmail.com', subject: 'Error')

  end
end
