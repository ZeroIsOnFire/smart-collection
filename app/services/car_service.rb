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
    scope.desc(:created_at).skip((page - 1) * per_page).limit(per_page)
  end

  def search(query)
    # Dividimos a busca em palavras para permitir termos fora de ordem (ex: 'azul match' encontra 'Matchbox Azul')
    # Cada palavra deve ser encontrada em pelo menos um dos campos ($and de vários $or)
    words = query.to_s.split(/\s+/).reject(&:blank?)
    return user.cars if words.empty?

    query_conditions = words.map do |word|
      regex = /#{Regexp.escape(word)}/i
      { '$or' => [
        { name: regex },
        { brand: regex },
        { manufacturer: regex },
        { observations: regex },
        { size: regex },
        { tags: regex }
      ]}
    end

    user.cars.where('$and' => query_conditions)
  end
end
