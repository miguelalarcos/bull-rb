module MRelogin
  def self.panel= panel
    @panel = panel
  end
  def show_relogin val
    @panel.show val
  end
end