require 'csv'

class ExportCsvService
  def initialize(cars)
    @cars = cars
  end

  def generate
    CSV.generate(headers: true) do |csv|
      csv << ['Nome', 'Marca', 'Fabricante', 'Escala', 'Ano', 'Cor', 'Observações', 'Tags', 'Data de Adição']

      @cars.each do |car|
        csv << [
          car.name,
          car.brand,
          car.manufacturer,
          car.size,
          car.year,
          car.color,
          car.observations,
          car.tags.join(', '),
          car.created_at.strftime('%d/%m/%Y %H:%M')
        ]
      end
    end
  end
end
