# frozen_string_literal: true

module Admin
  class UsersController < DashboardController
    before_action :set_user, only: %i[show edit update destroy]

    # GET /admin/users
    def index
      @users = if params[:q].present?
                 User.where(
                   '$or' => [
                     { name: /#{Regexp.escape(params[:q])}/i },
                     { email: /#{Regexp.escape(params[:q])}/i }
                   ]
                 )
               else
                 User.all
               end

      @page = (params[:page] || 1).to_i
      @per_page = 20
      @users = @users.desc(:created_at).skip((@page - 1) * @per_page).limit(@per_page)
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
      if @user.update(user_params)
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
      params.require(:user).permit(:name, :email, :admin)
    end
  end
end
