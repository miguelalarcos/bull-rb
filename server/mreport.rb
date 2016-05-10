require 'liquid'

module MReport
  def reports
    MReport.reports
  end

  def self.reports
    return @reports if !@reports.nil?
    @reports = {}
    Dir.glob(File.join('reports' , '*.html')).each do |file|
      html = File.read(file)
      @reports[File.basename(file, '.html')] = Liquid::Template.parse(html)
    end
    puts 'reports loaded'
    @reports
  end
end