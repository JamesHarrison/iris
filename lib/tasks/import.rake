namespace :iris do
  desc 'Imports files in the path specified in settings.yml under import_path'
  task :import => :environment do
    Dir.foreach(Settings.import_path) do |item|
      next if item == '.' or item == '..'
      puts "Processing item #{item}"
      u = Upload.new
      u.user_id = 1
      u.filename = item
      u.path = File.join(Settings.import_path, item)
      u.save
      u.atl("INFO", "FileImporter: Imported new file- #{item}")
      puts " - Queued for import"
    end
  end
end