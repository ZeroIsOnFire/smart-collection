class AutodetectionService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def create(params)
    autodetection = user.autodetections.create(params)
    
    if autodetection.persisted?
      AutodetectJob.perform_later(autodetection.id.to_s)
    end
    
    autodetection
  end

  def retry(autodetection_id)
    autodetection = user.autodetections.find(autodetection_id)
    
    if autodetection.status == 'error'
      autodetection.update!(status: 'pending', error_message: nil)
      AutodetectJob.perform_later(autodetection.id.to_s)
    end
    
    autodetection
  end
end
