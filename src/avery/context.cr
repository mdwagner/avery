class Avery::Context
  module State
  end

  getter files = {} of String => FileContext
  getter state = {} of String => State
  property! current_file : FileContext?
end
