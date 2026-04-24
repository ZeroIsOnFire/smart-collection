require 'csv'

class ExportCsvService
  def initialize(cars)
    @cars = cars
  end

  def generate
    CSV.generate(headers: true) do |csv|
      csv << ['Nome', 'Marca', 'Fabricante', 'Escala', 'Ano', 'Cor', 'Observações', 'Data de Adição']

      @cars.each do |car|
        csv << [
          car.name,
          car.brand,
          car.manufacturer,
          car.size,
          car.year,
          car.color,
          car.observations.to_s.squish,
          car.created_at.strftime('%Y-%m-%d %H:%M')
        ]
      end
    end
  end
end
