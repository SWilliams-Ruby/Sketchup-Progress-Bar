module SW
# ProgressBarSpinnerManual
#   Spins the cursor each time the user code yields, 
#   Checks for keyboard or mouse at every redraw
#
  class ProgressBarSpinnerManual < ProgressBar
    def initialize(*args)
      super
      @animate_cursor = true
      @enable_redraw = false
    end
  end

# ProgressBarSpinnerAuto
#   Spins the cursor each @auto_interval, 
#   Checks for keyboard or mouse at every redraw
#
  class ProgressBarSpinnerAuto < ProgressBar
    def initialize(*args)
      super
      @animate_cursor = true
      @enable_redraw = false
      @auto_mode = :full
      @auto_interval = 1.0
    end
  end



# ProgressBarSpinnerAndLabelManual
#   Spins the cursor and redraws the label each time the user code calls redraw_label()
#   and checks for keyboard or mouse at every redraw
    
  class ProgressBarSpinnerAndLabelManual< ProgressBarSpinnerManual
    def initialize(*args)
      super
      @options[:height] = 35
      @is_first_redraw = true
    end
    
    # force a redraw
    def redraw_label(label)
      @label = label
      Sketchup.active_model.active_view.invalidate
      Fiber.yield
    end
    
    def draw(view)
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

        # Label
        if @label
          label = @label
          label = label + ' ' +('>' * @label_state) if animate_label
          #  15 and 8 will need to be variables that depend on screen resolution and text size
          point = Geom::Point3d.new(x + @options[:text_location][0] * scale,  y + @options[:text_location][1] * scale, 0)
          view.draw_text(point, label, @options[:text_options])
        end
    end # draw
  end
  
# ProgressBarSpinnerAndLabelAuto
#   Spins the cursor and redraws the label each time the user code calls redraw_label()
#   and at every @auto_interval
#   Checks for keyboard or mouse at every redraw
#
  class ProgressBarSpinnerAndLabelAuto < ProgressBarSpinnerAndLabelManual
    def initialize(*args)
      super
      @auto_mode = :full
      @auto_interval = 1.0
    end
  end

end
nil