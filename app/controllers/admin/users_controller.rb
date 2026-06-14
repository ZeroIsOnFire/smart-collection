# frozen_string_literal: true

module Admin
  class UsersController < DashboardController
    before_action :set_user, only: %i[show edit update destroy]

    # GET /admin/users
    def index
      @users = if params[:q].present?
                 User.where(
                   '$text' => { '$search' => params[:q] }
                 )
               else
                 User.all
               end

      @per_page = 20
      @users = @users.desc(:created_at).page(params[:page]).per(@per_page)
      @page = @users.current_page
    end

    # GET /admin/users/1
    def show
      @stats = {
        cars_count: @user.cars.count,
        autodetections_count: @user.autodetections.count
      }
    end

    # GET /admin/users/1/edit
    def edit; end

    # PATCH/PUT /admin/users/1
    def update
      @user.assign_attributes(user_params)
      @user.admin = params[:user][:admin] if params.dig(:user, :admin).present? || params[:user].key?(:admin)
      if @user.save
        redirect_to admin_user_path(@user), notice: 'Usuário atualizado com sucesso.'
      else
        render :edit, status: :unprocessable_content
      end
    end

    # DELETE /admin/users/1
    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: 'Você não pode deletar seu próprio usuário.'
      else
        @user.destroy
        redirect_to admin_users_path, notice: 'Usuário removido com sucesso.'
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.expect(user: %i[name email])
    end
  end
end
