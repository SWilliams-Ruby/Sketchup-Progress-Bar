# Subclassing the ProgressBar class
# modify the on screen appearance by redefining the draw method

module SW
  class ProgressBarCustomDraw < SW::ProgressBar
    def initialize(*args)
      pbar = super
      @radius = 8
      @orb = get_marker()
      @perimeter = get_perimeter()
      @is_first_redraw = true
    end
    
    # set new window location
    def location=(loc)
      @options[:location] = loc
      @perimeter = get_perimeter()
    end
    
    def width=(width)
      @options[:width] = width
      @perimeter = get_perimeter()
    end 

    def height=(height)
      @options[:height] = height
      @perimeter = get_perimeter()
    end 
    
    def options=(options)
      @options.merge!(options)
      @perimeter = get_perimeter()
    end
    
    def onMouseMove(flags, x, y, view)
      super
      @perimeter = get_perimeter()
    end

    # 
    def get_perimeter()
      # a 1x1 rounded edge box
      roundedgebox = [[0.125, 0.0, 0.0], [0.875, 0.0, 0.0], [0.922835, 0.009515, 0.0],\
        [0.963388, 0.036612, 0.0], [0.990485, 0.077165, 0.0], [1.0, 0.125, 0.0],\
        [0.990485, 0.922835, 0.0], [0.963388, 0.963388, 0.0], [0.922835, 0.990485, 0.0],\
        [0.875, 1.0, 0.0], [0.875, 1.0, 0.0], [0.077165, 0.990485, 0.0], [0.036612, 0.963388, 0.0],\
        [0.009515, 0.922835, 0.0], [0.0, 0.875, 0.0], [0.0, 0.875, 0.0], [0.009515, 0.077165, 0.0],\
        [0.036612, 0.036612, 0.0], [0.077165, 0.009515, 0.0], [0.125, 0.0, 0.0]]

      scale_and_translate(roundedgebox, @options[:width], @options[:height], @options[:screen_scale], @options[:location])
    end
    
    # scale uniformly by the height value and scootch the right side 
    # points over to the correct width. Move to location on screen  
    def scale_and_translate(outline, width, height, scale, location)
      tr = Geom::Transformation.scaling(height * scale, height * scale,0)
      outline.collect!{|pt|
        pt.transform!(tr)
        pt[0] = pt[0] + width * scale - height * scale if pt[0] > height * scale/2
        pt
      }
      tr = Geom::Transformation.translation([location[0] * scale, location[1] * scale])
      outline.collect{|pt| pt.transform(tr)}
    end
      
    
    # make the dot indicator
    def get_marker()
      center = Geom::Point3d.new(0, 0, 0)
      rotate_around_vector = Geom::Vector3d.new(0, 0, 1)
      angle = 14.4.degrees
      tr = Geom::Transformation.rotation(center, rotate_around_vector, angle)
      vector = Geom::Vector3d.new(@radius, 0, 0)
      26.times.map {center + vector.transform!(tr) }
     end
    
    def draw(view)
      #skip the first redraw
      if @is_first_redraw
        @is_first_redraw = false
        return
      end
      
      # Background
      view.drawing_color = @options[:box_color]
      view.draw2d(GL_POLYGON, @perimeter)

      # Outline
      view.line_stipple = '' # Solid line
      view.line_width = 1
      view.drawing_color = @options[:outline_color]
      view.draw2d(GL_LINE_LOOP, @perimeter)
      
      # Bar Background
      scale = @options[:screen_scale]
      x = @options[:location][0] * scale
      y = @options[:location][1] * scale
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
  
      # Draw the value marker  
      tr = Geom::Transformation.translation([xbar + barwidth * @value, ybar + barheight/2, 0])
      orb_perimeter = @orb.collect{|pt| pt.transform(tr)}
      view.drawing_color = @options[:fg_color]
      view.draw2d(GL_POLYGON, orb_perimeter)
      
      # Label
      # 15 may need to be a variable that depends on screen resolution or text size
      if @label
        label = @label
        label = label + ' ' +('>' * @label_state) if animate_label
          point = Geom::Point3d.new(x + @options[:text_location][0] * scale,  y + @options[:text_location][1] * scale, 0)
          view.draw_text(point, label, @options[:text_options])
      end
    end  
  end
end


