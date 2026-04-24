namespace :cleanup do
  desc "Remove autodetection records and files older than 24 hours"
  task autodetections: :environment do
    puts "Cleaning up old autodetection records..."
    initial_count = Autodetection.count
    Autodetection.cleanup_old_records
    final_count = Autodetection.count
    puts "Done. Removed #{initial_count - final_count} records and their associated files."
  end
end
