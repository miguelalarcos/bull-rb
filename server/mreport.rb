require 'liquid'

module MReport
  def reports
    MReport.reports
  end

  def self.load_reports
    @reports = {}
    Dir.glob(File.join('reports' , '*.html')).each do |file|
      html = File.read(file)
      @reports[File.basename(file, '.html')] = Liquid::Template.parse(html)
    end
    puts 'reports loaded'
    @reports
  end

  def self.reports
    return @reports if !@reports.nil?
    load_reports
  end
end