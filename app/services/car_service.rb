# frozen_string_literal: true

class CarService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def create(params)
    car = user.cars.build(params)
    process_car_image(car, params)
    car.save
    car
  end

  def update(car_id, params)
    car = user.cars.find(car_id)
    car.attributes = params
    process_car_image(car, params)
    car.save
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

  private

  def process_car_image(car, params)
    # 1. Aplicar recorte se houver coordenadas
    apply_crop(car, params)

    # 2. Limpar coordenadas para evitar duplo recorte em caso de erro de validação subsequente
    # Como a foto já foi recortada e salva no cache, não precisamos aplicar as mesmas coordenadas de novo.
    car.crop_x = car.crop_y = car.crop_w = car.crop_h = nil

    # 3. Detectar cor sincronamente se houver foto nova (ou recortada) e a cor estiver em branco
    return unless car.photo.present? && car.color.blank?

    detected_color = YoloDetectionService.classify_color(car.photo.path)
    car.color = detected_color if detected_color
  end

  def apply_crop(car, params)
    crop_x = params[:crop_x]
    crop_y = params[:crop_y]
    crop_w = params[:crop_w]
    crop_h = params[:crop_h]

    return unless crop_x.present? && car.photo.present?

    vertices = [
      { 'x' => crop_x.to_f, 'y' => crop_y.to_f },
      { 'x' => crop_x.to_f + crop_w.to_f, 'y' => crop_y.to_f },
      { 'x' => crop_x.to_f + crop_w.to_f, 'y' => crop_y.to_f + crop_h.to_f },
      { 'x' => crop_x.to_f, 'y' => crop_y.to_f + crop_h.to_f }
    ]

    cropped_file = ImageCropperService.crop(car.photo.path, vertices, padding: 0)
    car.photo = cropped_file if cropped_file
  end
end
