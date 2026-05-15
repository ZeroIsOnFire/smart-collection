# frozen_string_literal: true

class CarService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def create(params)
    params = apply_crop(params)
    user.cars.create(params)
  end

  def update(car_id, params)
    car = user.cars.find(car_id)
    params = apply_crop(params, existing_car: car)
    car.update(params)
    car
  end

  private

  def apply_crop(params, existing_car: nil)
    crop_x = params.delete(:crop_x)
    crop_y = params.delete(:crop_y)
    crop_w = params.delete(:crop_w)
    crop_h = params.delete(:crop_h)

    return params unless crop_x.present?

    # Determinar qual foto processar (a nova enviada ou a existente)
    photo_path = nil
    if params[:photo].present?
      photo_path = params[:photo].path
    elsif existing_car&.photo&.present?
      photo_path = existing_car.photo.path
    end

    if photo_path
      vertices = [
        { 'x' => crop_x.to_f, 'y' => crop_y.to_f },
        { 'x' => crop_x.to_f + crop_w.to_f, 'y' => crop_y.to_f },
        { 'x' => crop_x.to_f + crop_w.to_f, 'y' => crop_y.to_f + crop_h.to_f },
        { 'x' => crop_x.to_f, 'y' => crop_y.to_f + crop_h.to_f }
      ]
      cropped_file = ImageCropperService.crop(photo_path, vertices, padding: 0)
      params[:photo] = cropped_file if cropped_file
    end

    params
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
