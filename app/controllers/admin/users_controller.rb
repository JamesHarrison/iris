class Admin::UsersController < ApplicationController
  def index
    authorize! :manage, User
    @users = User.all
  end
  def edit
    @user = User.find(params[:id])
    authorize! :manage, User
  end
  def update
    @user = User.find(params[:id])
    authorize! :manage, User
    @user.update_attributes(params[:user])
    @user.role = params[:user][:role]
    if @user.save!
      flash[:notice] = "Updated user successfully"
      redirect_to '/admin/users'
    else
      flash[:error] = "Unable to update user"
      redirect_to edit_admin_user_path(@user)
    end
  end
end