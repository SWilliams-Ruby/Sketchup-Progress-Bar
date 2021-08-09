require 'fiber'
# https://developer.apple.com/design/human-interface-guidelines/macos/indicators/progress-indicators/

#############################################
#
# Initializer:
#   new(on_complete, on_abort, user_task, [id:]) -> progressbar
#   new(on_complete, on_abort, [id:]) { |progressbar| block } -> result of block
#
# With no associated block, Progressbar.new will call the user_task with the
# progressbar instance as an argument and will return the progressbar instance
# to the caller. If the optional code block is given, it will be passed to the
# block as an argument. If an optional keyword argument 'id:' is given the screen
# location of the 'id'ed progress bar will be maintained across invocations.  The
# abort method will receive an exception object as an argument.
#
# params:
#   on_complete -  the Method to execute when the user_task has ended. 
#   on_abort -  the Method to execute when there is an Exception/Mouse/Keyboard action.
#   user_task - the user_task Method to execute. the user_task will receive the 
#   progressbar object as an argument. 
#
# raises:
#   ProgressBarError, 'ProgressBar on_complete argument must be a Method of Arity zero'
#   ProgressBarError, 'ProgressBar on_abort argument must be a Method of Arity one'
#   ProgressBarError, 'ProgressBar user_task argument must be a Method of Arity One'
#   ProgressBarAbort, 'Deactivate - Tool Change' on a tool change
#   ProgressBarAbort, 'User Menu-Click-Abort' on mouse click actions    
#
#
# Example of block form:
# 
#  module SOME_MODULE
#    def self.run_example()
#      SW::ProgressBar.new(method(:on_complete), method(:on_abort)) do |pbar|
#        for count in 1..10
#          pbar.label= "Step: #{count}"
#          pbar.set_value(count * 10)
#          pbar.refresh
#          sleep(0.3)
#        end
#      end
#    end
#  
#    def self.on_complete
#      puts 'completed'
#    end
#   
#    def self.on_abort(exception)
#      puts 'aborted'
#      raise exception
#    end
#
#    run_example
#  end   
# 
# 
# Example without a block:
#
#  module SOME_MODULE
#    def self.run_example()
#      SW::ProgressBar.new(method(:on_complete), method(:on_abort), method(:user_task))
#    end
#
#    def self.user_task(pbar)
#      for count in 1..10
#        pbar.label= "Step: #{count}"
#        pbar.set_value(count * 10)
#        pbar.refresh
#        sleep(0.3)
#      end
#    end
#
#   def self.on_complete
#     puts 'completed'
#   end
#
#   def self.on_abort(exception)
#      puts 'aborted'
#      raise exception
#   end
#   
#   run_example
# end
#
#
#######################################
# instance methods
#######################################
#
# label= "Label to Display"
# animate_cursor= true/false
# animate_label= true/false
# enable_redraw= true/false
#
# set_value(value)
#   Place the progress bar at 'value' percent.
#   'value' between 0 and 100 inclusive
#
#   raises ProgressBarError, "Value must be a Numeric type" \
#   raises ProgressBarError, "Value must be between 0 and 100" \
#
#
# advance_value(value)    
#   Advance the progress bar by 'value' percent.
#   'value' between 0 and 100 inclusive
#
#   raises ProgressBarError, "Value must be a Numeric type" \
#   raises ProgressBarError, "Value must be between 0 and 100" \
#
# refresh()
#
#
# update_interval=
# auto_mode= :full
# auto_interval=
#
#
#options=
#  location  - location of the progressbar window
#  width - width of the progressbar window
#  height - height of the progressbar window
#  screen_scale
#  box_color - background color of the progressbar window
#  bar_location - location of the bar relative to the progressbar window
#  bar_width
#  bar_height
#  bg_color - background color of the progress bar 
#  fg_color - color of the progress bar
#  outline_color - ouitline color of the progress bar
#  text_location - location of the text relative to the progressbar window
#  text_options - text options for the label 
#
#
#######################################
# class method(s)
#######################################
#
# display_safe_messagebox(&block) - 
#

module SW
  class ProgressBar
    attr_accessor(:on_complete, :on_abort, :user_task)
    attr_accessor(:animate_cursor, :animate_label, :enable_redraw)
    attr_accessor(:update_interval, :auto_mode, :auto_interval)
    attr_accessor(:label, :options)
    attr_reader(:value, :id)

    @@activated = false
    @@lookaway = true
    @lookaway = true
    
    @@busy_cursors = nil unless class_variable_defined?(:@@busy_cursors) # (ruby console hack)
    @@locations = {} unless class_variable_defined?(:@@locations)# saved progressbar locations
 
    # Exception class for Progress bar user code errors
    class ProgressBarError < RuntimeError; end
    
    # Exception class for user mouse and keyboard actions
    class ProgressBarAbort < RuntimeError; end
        
    
    ###################################
    # Sketchup Tool interface methods
    ###################################
     
    def activate
      # puts 'activate'
      @@activated = true
      @suspended = false
      @user_esc = false
      @cancel_reason = nil
      @enable_redraw = true
      
      # progress bar size and position
      @options = {
        location:  [50, 30],
        width:  300,
        height:  60,
        screen_scale: 1.0,
        box_color:  Sketchup::Color.new(240, 240, 240),
        outline_color:  Sketchup::Color.new(180, 180, 180),
        bar_location:  [10, 35],
        bar_width:  0,
        bar_height:  10,
        fg_color:  Sketchup::Color.new(120, 120, 200),
        bg_color:  Sketchup::Color.new(210, 210, 210),
        text_location:  [15, 8],
        text_options:  {size:  13, color: [80, 80, 80]}
      }
      @options[:bar_width] = @options[:width] * 0.95
      
      # restore a saved screen location if present in the @@locations cache
      if @id && @@locations[@id] 
        @options[:location] = @@locations[@id]
      end
      
      # progress  bar label and value
      @label = 'Thinking'
      @value = 0.0 # a float between 0 and 1

      # progress bar cursor and label animation state
      @label_state = 0
      @cursor_index = 0
      
      # update timing settings
      @update_interval = 0.25
      @update_flag = false 
      @auto_interval = 5.0
      @auto_mode  = nil
      @avg_redraw_delay = 0.0
      @is_first_redraw = true
      
      # hide the animated cursor?
      @mouse_in_viewport = false
    end

    def deactivate(view)
      # puts 'deactivate'
      @@activated = false
      @suspended = false
      @cancel_reason = 'Deactivate - Tool Change'
      stop_interrupter_thread()
      UI.set_cursor(633) if @animate_cursor # the select cursor
      # puts @log.join("\n") if @log
    end
    
    def onCancel(reason, view)
      # puts 'user esc'  
      # intentioanaly ignoring the reason arguement
      @user_esc = true
      @cancel_reason = 'User Escape'
    end
    
    def suspend(view)
      #puts 'suspend'
      @suspended = true
    end
    
    def resume(view)
      #puts 'resume'
      @suspended = false
    end
    
    def onSetCursor
      UI.set_cursor(@@busy_cursors[@cursor_index]) \
        if @animate_cursor && @@busy_cursors && @mouse_in_viewport
    end
    
    def onMouseLeave(view)
      #puts "onMouseLeave: view = #{view}"
      @mouse_in_viewport = false
    end
    
    def onMouseEnter(view)
      #puts "onMouseEnter: view = #{view}"
      @mouse_in_viewport = true
    end
    
    def onKeyDown(key, repeat, flags, view)
      if key = VK_CONTROL
        #p 'toggle' 
        if @@lookaway = !@@lookaway
          look_away()
        else
          look_back()
        end
      end
      
    end
    
    def active?
      @@activated
    end
    
    #############################
    # progressbar dragging functions
    #############################
    
    def onLButtonDown(flags, x, y, view)
      a, b = *@options[:location]
      return unless x > a && x < a + @options[:width]
      return unless y > b && y < b + @options[:height]
      @last_mouse_location = [x, y]
      @moving = true
    end
    
    def onLButtonUp(flags, x, y, view)
      @moving = false
    end
    
    def onMouseMove(flags, x, y, view)
      return unless @moving == true
      a, b = *@options[:location]
      new_location = [a + x - @last_mouse_location[0] , b + y - @last_mouse_location[1]]
      @last_mouse_location = [x, y] # save current mouse location
      @options[:location] = new_location
      @@locations[@id] = new_location if @id # save pbar location by id
      view.invalidate
    end
  
  
    ###################################
    # Progress bar update methods 
    ###################################
    
    def options=(options)
      @options.merge!(options)
    end
    
    # Place the progress bar at 'value' percent.
    # 'value' between 0 and 100 inclusive
    def set_value(value)
      raise ProgressBarError, "Value must be a Numeric type" \
        unless value.is_a?(Numeric)
      raise ProgressBarError, "Value must be between 0 and 100" \
        if (value < 0.0) || (value > 100.0)
      @value = value/100.0
      @value = 1.0 if @value > 1.0
    end
    
    # Advance the progress bar by 'value' percent.
    # 'value' between 0 and 100 inclusive
    def advance_value(value)
      raise ProgressBarError, "Value must be a Numeric type" \
        unless value.is_a?(Numeric)
      raise ProgressBarError, "Value must be between 0 and 100" \
        if (value < 0.0) || (value > 100.0)
      @value += value/100.0
      @value = 1.0 if @value > 1.0
    end

    # @update_flag is set to true at @update_interval
    def update?
      temp = @update_flag
      @update_flag = false
      temp
    end
    
    # Redraw the screen presentation of the progress bar 
    #   Rather than having the user insert yield statements in their code the
    #   refresh method hides the details and allows us to change the 
    #   implementation independantly of the user code
    
    def refresh()
      Fiber.yield
    end

    ###################################
    # animated cursor & label routines 
    ###################################

    def step_cursor()
      unless @@busy_cursors 
        self.class.send(:get_cursors)
      end
      
      @cursor_index = (@cursor_index + 1) % 8
      UI.set_cursor(@@busy_cursors[@cursor_index]) if @mouse_in_viewport
    end
  
    def step_label()
      @label_state = (@label_state + 1) % 8
    end
    
    
    ###################################
    #  Draw routines
    ###################################
    
    def draw(view)
      return unless @enable_redraw
      
      # skip the first redraw (it is a tool change)
      if @is_first_redraw
        @is_first_redraw = false
        return
      end
      
      # Background fill
      scale = @options[:screen_scale]
      x = @options[:location][0] * scale
      y = @options[:location][1] * scale
      width = @options[:width] * scale
      height = @options[:height] * scale
      
      points1 = [
        [x, y, 0],
        [x, y + height, 0],
        [x + width, y + height, 0],
        [x + width, y, 0]
      ]
      view.drawing_color = @options[:box_color]
      view.draw2d(GL_QUADS, points1)

      # Outline
      view.line_stipple = '' # Solid line
      view.line_width = 1
      view.drawing_color = @options[:outline_color]
      view.draw2d(GL_LINE_LOOP, points1)

      
      # Bar background
      xbar = x + @options[:bar_location][0] * scale
      ybar = y + @options[:bar_location][1] * scale
      barwidth = @options[:bar_width] * scale
      barheight = @options[:bar_height] * scale
      
      points2 = [
        [xbar, ybar, 0],
        [xbar, ybar + barheight, 0],
        [xbar + barwidth, ybar + barheight, 0],
        [xbar + barwidth, ybar, 0]
      ]
      view.drawing_color = @options[:bg_color]
      view.draw2d(GL_QUADS, points2)
      

      # Progress Bar Fill
      points2 = [
        [xbar, ybar, 0],
        [xbar, ybar + barheight, 0],
        [xbar + @value * barwidth, ybar + barheight, 0],
        [xbar + @value * barwidth, ybar, 0]
      ]
      view.drawing_color = @options[:fg_color]
      view.draw2d(GL_QUADS, points2)

      # Label
      if @label
        label = @label
        label = label + ' ' + ('>' * @label_state) if animate_label
        point = Geom::Point3d.new(x + @options[:text_location][0] * scale,  y + @options[:text_location][1] * scale, 0)
        view.draw_text(point, label, @options[:text_options])
      end
    end # draw


    #############################################
    #
    # Initializer:
    #   new(on_complete, on_abort, user_task, [id:] ) -> progressbar
    #   new(on_complete, on_abort, [id:]) { |progressbar| block } -> result of block
    #
    # With no associated block, Progressbar.new will call the user_task with the
    # progressbar instance as an argument and will return the progressbar
    # instance to the caller. If the optional code block is given, it will be
    # passed the progressbar instance as an argument. If the optional keyword
    # argument id: is present the screen location of the progress bar will
    # be maintained across invocations.
    #
    # params:
    #   on_complete -  the Method to execute when the user_task has ended. 
    #   on_abort -  the Method to execute when there is an Exception/Mouse/Keyboard action.
    #   user_task - the user_task Method to execute.
    #   id: - an object
    #   
    
    def initialize(on_complete, on_abort, user_task = nil, id: nil, &block)

      # Allow only one active progress bar. This is caused f.e. by a double click on a toolbar icon.
      return if active? 

      user_task = block if block_given?
      @id = id
          
      raise ProgressBarError, 'ProgressBar user_task argument must be a Method of Arity one'\
        unless user_task && [Method, Proc].include?(user_task.class) && user_task.arity == 1
      raise ProgressBarError, 'ProgressBar on_complete argument must be a Method of Arity zero'\
        unless on_complete && on_complete.is_a?(Method) && on_complete.arity == 0
      raise ProgressBarError, 'ProgressBar on_abort argument must be a Method of Arity one'\
        unless on_abort && on_abort.is_a?(Method) &&  on_abort.arity == 1
      
      @user_task = user_task
      @on_complete = on_complete
      @on_abort = on_abort
      
      look_away() if @@lookaway # from the model
      
      # Activate the tool
      Sketchup.active_model.tools.push_tool(self)

      # Start the user task
      redraw_progressbar()
    end
  
    # Schedule the user_task
    def redraw_progressbar()
      Sketchup.active_model.active_view.invalidate if @enable_redraw
      UI.start_timer(0, false) { resume_task() }
      @time_at_start_of_redraw = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
    private :redraw_progressbar
    
    # Execute the user_task 
    def resume_task()
    
      # re-queue the user_task during Orbit and Pan and Section Plane operations
      if active? && @suspended
        UI.start_timer(0.25, false) { resume_task() }
        @time_at_start_of_redraw = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        return
      end
      
      # advance the animated cursor and label
      step_cursor() if @animate_cursor
      step_label() if @animate_label
      
      # Calculate  redraw time
      @redraw_delay = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @time_at_start_of_redraw 
      # @log ? @log << @redraw_delay : @log = [@redraw_delay]
      
      begin
        
        # Abort after a user ESC or a tool change. Copy cancel_reason since
        # pop_tool in the rescue clause triggers deactivate which overwrites it.
        if @user_esc || !@@activated
          cancel_reason = @cancel_reason  
          raise ProgressBarAbort, cancel_reason
        end
        
        # Wrap the user_task (a Method or Proc) in a Fiber on first invocation.
        # This must be done in this stack context.  Start the update_flag thread
        if @fiber.nil?
          @fiber = Fiber.new {@user_task.call(self) }
          start_interrupter_thread()
        end

        # Let the fun begin!
        # Execute the user task until it yields, ends, or raises an exception
        result = @fiber.resume()
        
        # waiting, waiting, waiting
        if @fiber.alive?
          redraw_progressbar()
        else
          # The Fiber has ended naturally. Stop the updater thread.
          # Pop the ProgressBarTool and call the user's on_complete method.
          stop_interrupter_thread()
          look_back() if @@lookaway
          Sketchup.active_model.tools.pop_tool
          Sketchup.active_model.active_view.invalidate
          UI.start_timer(0, false) { @on_complete.call }
        end 

      # Bad things happen even when you have the best intentions. Catch all
      # StandardErrors and user actions that throw an exception
      rescue => exception   
      
        stop_interrupter_thread() 
        look_back() if @@lookaway
        
        # Because we have left @fiber in limbo, possibly with file handles open,
        # let's abandon the fiber and force a clean-up
        @fiber = nil
        GC.start

        # If the user clicked on a Sketchup Menu, dialog, etc. we'll receive an
        # exception: 'FiberError - fiber called across stack rewinding barrier'
        # In this case we raise the ProgressBarAbort exception
        if exception.is_a? FiberError
          exception = ProgressBarAbort.new('User Menu-Click Abort')
        end
        
        # Pop the progressbartool unless this is a tool change where sketchup
        # has already done that for you then call the on_abort method
        Sketchup.active_model.tools.pop_tool if @@activated
        Sketchup.active_model.active_view.invalidate
        UI.start_timer(0, false) { @on_abort.call(exception) }
        
      end # rescue
    end # resume_task
    private :resume_task


    ##############################################
    # look away from the model to save redraw time
    # 
    
    # alternative initializer
    # def self.new_with_lookaway(*args, &block)
    #   pbar = self.new(*args, &block)
    #   pbar.look_away()
    # end
    
    def look_away()
      model = Sketchup.active_model
      camera = model.active_view.camera
      @eye = camera.eye
      @target = camera.target
      @up = camera.up
      bounds = model.bounds
      camera.set(bounds.corner(0), bounds.corner(0) -  bounds.center, @up)
    end
    #protected :look_away 
   
    # restore the camera settings
    def look_back()
      camera = Sketchup.active_model.active_view.camera.set(@eye, @target, @up)
    end
    #private :look_back

    
    
    ###################################
    # Timed update routines 
    ###################################
    
    def start_interrupter_thread()
      interrupter_tracepoint_init() if @auto_mode == :full
      @interrupter_thread = Thread.new() {interrupter_loop()}
      @interrupter_thread.priority = 1
    end
    private :start_interrupter_thread
    
    def stop_interrupter_thread()
      @interrupter_thread.exit if @interrupter_thread.respond_to?(:exit)
      @interrupter_tracepoint = nil
    end
    private :stop_interrupter_thread

    
    # A simple thread which will set the @update_flag approximately 
    # every @update_interval seconds. 
    def interrupter_loop()
      begin
        auto_time =  Process.clock_gettime(Process::CLOCK_MONOTONIC) + @auto_interval
        while true
          sleep(@update_interval + @redraw_delay)
          next if @suspended
          
          # puts debug info to the ruby console
          #Sigint_Trap_for_ProgressBar.add_message("tic") if SW.const_defined?(:Sigint_Trap_for_ProgressBar) 

          @update_flag = true
          
          next unless @auto_mode == :full && auto_time < Process.clock_gettime(Process::CLOCK_MONOTONIC)
          auto_time += @auto_interval
          @stop_after = 2
          @interrupter_tracepoint.enable
        end 
      rescue => e
        # puts debug info to the ruby console
        Sigint_Trap_for_ProgressBar.add_message("#{e.to_s}, #{e.backtrace.join("\n")}") if SW.const_defined?(:Sigint_Trap_for_ProgressBar)
      end
    end
    private :interrupter_loop
    
    ###################################
    # The implementation of a tracepoint that will insert a Fiber.yield
    # instruction into the user_task each time the tracepoint is enabled
    #
    # The TracePoint tests each code line as it is loaded and will yield the
    # Fiber only if the current fiber is the user_task's fiber. The
    # user_task will be (or at least should be) the third line of code loaded
    # after the tracepoint.enable statement in the interrupter loop below.
    #
    # When the thread is executing code that is not the user_task's or if there
    # were to be an unexpected error, the @stop_after counter is the number of
    # lines of code that are tested before the tracepoint is disabled. Defensive
    # programming
    #
    # NOTE: Auto_mode is enabled by setting @auto_mode to :full. Auto_mode functions perfectly
    # as long as the user code is wrapped in a start_operation/commit_operation.
    # If the user code is not so wrapped then the yield statement can occur during
    # a call to an observer possibly causing a Fiber error. The utility of this feature is
    # demonstrated in the file progressbar_spinner.rb in the examples folder
    #
    # Note To Self - The Ruby source code logic for tracepoints appears is in vm_trace.c,
    # see function rb_tracepoint_disable(VALUE tpval) etc.

    def interrupter_tracepoint_init()
      @interrupter_tracepoint = TracePoint.new(:line) do |tp|
        if (@fiber == Fiber.current)
          @interrupter_tracepoint.disable
          Fiber.yield if !@suspended
        elsif (@stop_after -= 1) == 0
          @interrupter_tracepoint.disable
        end 
      end
    end
    private :interrupter_tracepoint_init
      
      
    ##########################
    # Class methods 
    ##########################

    # Load our animated cursor files only once and on demand. This seems like
    # the most logical place to park this code rather than implementing the
    # ProgressBarTool as a singleton and placing this code in the
    # ProgressBarTool (where it used to be).
    
    def self.get_cursors()
      @@busy_cursors ||= load_cursors()
    end
    private_class_method :get_cursors

    def self.load_cursors()
      #p 'load cursors'
      path = __FILE__
      path.force_encoding("UTF-8") if path.respond_to?(:force_encoding)
      cpath = File.join(File.dirname(path), 'cursors')
      set = 'synchro' #  'Beachball'
      busy_cursors = []
      busy_cursors << UI.create_cursor(File.join(cpath, "#{set}1.png"), 12, 12)
      busy_cursors << UI.create_cursor(File.join(cpath, "#{set}2.png"), 12, 12)
      busy_cursors << UI.create_cursor(File.join(cpath, "#{set}3.png"), 12, 12)
      busy_cursors << UI.create_cursor(File.join(cpath, "#{set}4.png"), 12, 12)
      busy_cursors << UI.create_cursor(File.join(cpath, "#{set}5.png"), 12, 12)
      busy_cursors << UI.create_cursor(File.join(cpath, "#{set}6.png"), 12, 12)
      busy_cursors << UI.create_cursor(File.join(cpath, "#{set}7.png"), 12, 12)
      busy_cursors << UI.create_cursor(File.join(cpath, "#{set}8.png"), 12, 12)
      busy_cursors
    end
    private_class_method :load_cursors
    
     
    # A hack for opening a UI::messagesbox from a timer event
    # https://github.com/SketchUp/sketchup-safe-observer-events/blob/master/src/safer_observer_events.rb
    #
    # Example call:
    # SW::ProgressBar.display_safe_messagebox() { UI.messagebox('Example Completed.') }
    #
     def self.display_safe_messagebox(&block)
      executed = false
      UI.start_timer( 0, false) {
        next if executed # use next when in a proc-closure (for ruby console)
        executed = true 
        block.call
      }
    end
    
  end # progressbar
  
  ##########################
  # degugging aids
  ##########################

  if false # Shall we load the signal trap?
    module Sigint_Trap_for_ProgressBar
      # Functional Description:
      # Module Sigint_Trap is a SIGINT handler that interrupts and executes code
      # on the main thread. By default it will 'puts' an object to the ruby
      # console or alternatively it will call a user supplied Proc object. This
      # mechanism allows a worker thread to execute code on the main Sketchup
      # thread which has the persmissions needed to interact with the Sketchup
      # API. See the warning below.
      #
      # init()                Sets up the SIGINT handler
      # add_message(message)  Add a message to the queue and throw the SIGINT interrupt
      #
      # WARNING - Do not blithely add a SIGINT handler to your ruby code, it is
      # not safe. This code is for debug purposes only!!! This is because signal
      # handlers are reentrant, that is, a signal handler can be interrupted by
      # another signal (or sometimes the same signal) which can cause mysterious
      # errors.
      #
      # further reading http://kirshatrov.com/2017/04/17/ruby-signal-trap/
      # also see self pipe https://gist.github.com/mvidner/bf12a0b3c662ca6a5784
      # and https://bugs.ruby-lang.org/issues/14222
      #
      
      @pending_messages = []

      def self.init()
        @old_signal_handler = Signal.trap("INT") do
          if @pending_messages.size != 0
            current_job = @pending_messages.shift
            if current_job.is_a?(Proc)
                current_job.call
            else
              puts current_job
            end
          else
            # Call the daisy chained signal handler if there is nothing in our
            # pending_messages queue. We should never get here in normal debugging 
            p 'old signal handler called'
            @old_signal_handler.call if @old_signal_handler.respond_to?(:call)
          end
        end #end of Signal.trap do
        
        puts "#{self} chained to the old SIGINT Handler: #{@old_signal_handler.to_s}" 
      end
      
      # Add a message to the queue and trigger the SIGINT on the main thread
      def self.add_message(message)
        @pending_messages << message
        Process.kill("INT", Process.pid)
      end
      
      Sigint_Trap_for_ProgressBar.init()
      
    end # end module Sigint_Trap_for_ProgressBar
  end # if true/false
end

