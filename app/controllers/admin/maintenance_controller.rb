# frozen_string_literal: true

module Admin
  class MaintenanceController < DashboardController
    def index
      @autodetections_by_status = Autodetection.collection.aggregate([
                                                                       { '$group' => { _id: '$status',
                                                                                       count: { '$sum' => 1 } } }
                                                                     ]).to_a

      @old_records_count = Autodetection.where(:status.in => %w[completed error], :updated_at.lt => 24.hours.ago).count

      # Tenta obter o tamanho da pasta de uploads de forma simplificada
      @uploads_size = get_dir_size('public/uploads')

      # Carrega métricas do Sidekiq
      require 'sidekiq/api'
      @sidekiq_stats = Sidekiq::Stats.new
      @sidekiq_workers = Sidekiq::Workers.new.size
    end

    def cleanup
      CleanupAutodetectionsJob.perform_later
      redirect_to admin_maintenance_path, notice: 'Limpeza de arquivos temporários disparada com sucesso.'
    end

    private

    def get_dir_size(path)
      return 'N/A' unless File.directory?(path)

      size = 0
      Dir.glob(File.join(path, '**', '*')).each do |f|
        size += File.size(f) if File.file?(f)
      end

      format_size(size)
    rescue StandardError
      'Erro ao calcular'
    end

    def format_size(size)
      units = %w[B KB MB GB TB]
      return '0 B' if size.zero?

      exp = (Math.log(size) / Math.log(1024)).to_i
      exp = units.size - 1 if exp >= units.size

      format('%<size>.2f %<unit>s', size: size.to_f / (1024**exp), unit: units[exp])
    end
  end
end
