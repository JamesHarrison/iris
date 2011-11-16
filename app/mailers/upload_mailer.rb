class UploadMailer < ActionMailer::Base
  default :from => Settings.email_from_address

  def filtered(upload)
    @upload = upload
    @user = upload.user
    to = []
    to << Settings.email_filter_address if Settings.email_filter_notification == true
    to << @user.email if @user.id != 1 and Settings.email_filter_notify_uploader
    if upload.title and upload.artist
      @upload_name = (upload.title+" - "+upload.artist)
    else
      @upload_name = upload.filename
    end
    @upload_name = "##{upload.id}: "+@upload_name
    if to.length > 0
      upload.atl("INFO","Emailing filter notification to: #{to.join(", ")}")
      mail(:to=>to, :subject=>"#{Settings.email_prefix}#{@upload_name} was filtered prior to upload")
    else
      upload.atl("INFO","Not emailing filter notification, not configured")
    end
  end
  def failure(upload)
    @upload = upload
    @user = upload.user
    to = []
    to << Settings.email_failure_address if Settings.email_failure_notification == true
    to << @user.email if @user.id != 1 and Settings.email_failure_notify_uploader
    if upload.title and upload.artist
      @upload_name = (upload.title+" - "+upload.artist)
    else
      @upload_name = upload.filename
    end
    @upload_name = "##{upload.id}: "+@upload_name rescue "unknown upload (#{upload.id})"
    if to.length > 0
      upload.atl("INFO","Emailing filter notification to: #{to.join(", ")}")
      mail(:to=>to, :subject=>"#{Settings.email_prefix}#{@upload_name} failed to import")
    else
      upload.atl("INFO","Not emailing filter notification, not configured")
    end
  end
end
