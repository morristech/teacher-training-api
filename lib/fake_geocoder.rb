class FakeGeocoder
  def set_coordinates(key, value)
    @values = { key => value }
  end

  def read_coordinates(key)
    @values.fetch(key)
  end

  def clear
    @values = {}
  end
end
