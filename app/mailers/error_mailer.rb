class ErrorMailer < ApplicationMailer


  def welcome_email
    @customer = params[:customer]
    @errors = @customer.errors.messages

    # p params[:error]
    p "??"
    mail(to: 'th.rondio@gmail.com', subject: "Error - #{@customer.email}")

  end
end
