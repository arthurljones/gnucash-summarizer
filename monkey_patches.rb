class Hash
  def self.recursive
    new { |hash, key| hash[key] = recursive }
  end

  def get(*keys)
    keys.inject(self){|h, k| h[k] if h}
  end
end
