class Error < ApplicationRecord
  after_create :send_email

  private

  def send_email
    ErrorMailer.with(error: self).welcome_email.deliver
  end
end
