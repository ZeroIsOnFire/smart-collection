# frozen_string_literal: true

class CarService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def create(params)
    user.cars.create(params)
  end

  def update(car_id, params)
    car = user.cars.find(car_id)
    car.update(params)
    car
  end

  def destroy(car_id)
    car = user.cars.find(car_id)
    car.destroy
    car
  end

  def all(params = {})
    page = (params[:page] || 1).to_i
    per_page = params[:per_page] || 20
    query = params[:q]

    scope = query.present? ? search(query) : user.cars.all

    # Ordenação por data de criação decrescente e paginação manual
    scope.desc(:created_at).page(page).per(per_page)
  end

  def search(query)
    # Utilize MongoDB native text index search
    words = query.to_s.strip
    return user.cars if words.empty?

    user.cars.where('$text' => { '$search' => words })
  end
end
