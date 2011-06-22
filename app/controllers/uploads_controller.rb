class UploadsController < ApplicationController
  before_filter :authenticate_user!
  # GET /uploads
  # GET /uploads.xml
  def index
    authorize! :read, Upload
    @uploads = Upload.accessible_by(current_ability).limit(25).order('id DESC').all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @uploads }
    end
  end

  # GET /uploads/1
  # GET /uploads/1.xml
  def show
    authorize! :read, Upload
    @upload = Upload.accessible_by(current_ability).find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @upload }
    end
  end

  # GET /uploads/new
  # GET /uploads/new.xml
  def new
    authorize! :upload, Upload
    @upload = Upload.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @upload }
    end
  end
  # POST /uploads/send_file
  def send_file
    # {"filename.name"=>"07. Now It's Overhead - Type A.mp3", "filename.content_type"=>"audio/mp3", 
    #  "filename.path"=>"/tmp/0000000002", "filename.md5"=>"49b2f16226385c9a8fa4ea0d67739a03", "filename.size"=>"4773535"}
    @upload = Upload.new
    @upload.user_id = current_user.id
    authorize! :upload, @upload
    @upload.filename = params["filename.name"]
    @upload.path = params["filename.path"]
    @upload.format = params["filename.content_type"]
    if @upload.save
      flash[:notice] = "Uploaded file successfully"
      @upload.atl("INFO", "WebUploader: Uploaded file, md5 #{params["filename.md5"]} - size #{params["filename.size"]}")
      redirect_to upload_path(@upload)
    else
      flash[:error] = "Unable to upload file, please contact a relevant board member"
      redirect_to new_upload_path
    end
  end
  def approve
    authorize! :manage, Upload
    @upload = Upload.accessible_by(current_ability).find(params[:id])
    @upload.approve
  end
  def reject
    authorize! :manage, Upload
    @upload = Upload.accessible_by(current_ability).find(params[:id])
    @upload.reject
  end
  def flagged
    authorize! :manage, Upload
    @uploads = Upload.accessible_by(current_ability).where(:state=>'needs_review').all
  end
end
