module Result
  def self.success
    Success
  end

  def self.failure(reason)
    Failure.new(reason)
  end

  private
  class Success
    def self.unwrap(sucess_value)
      sucess_value
    end
  end

  class Failure
    def initialize(reason)
      @reason = reason
    end

    def unwrap(sucess_value)
      yield @reason if block_given?
    end

    def ==(other_result)
      return false unless other_result.is_a? Failure
      other_result.instance_variable_get(:@reason) == @reason
    end
  end
end
