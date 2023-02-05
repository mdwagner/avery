class Avery::Pipeline
  getter begin_handlers = [] of Handler
  getter stream_handlers = [] of Handler
  getter end_handlers = [] of Handler
  @context = Context.new
  @has_run_begins = false

  def execute
    unless @has_run_begins
      begin_handlers.each do |handler|
        handler.call(@context)
      end
      @has_run_begins = true
    end

    @context.files.each do |file, ctx|
      @context.current_file = ctx
      stream_handlers.each do |handler|
        handler.call(@context)
      end
    end
    @context.current_file = nil

    end_handlers.each do |handler|
      handler.call(@context)
    end
  end

  def reset : Nil
    @context.files.clear
    @context.state.clear
    @has_run_begins = false
  end
end
