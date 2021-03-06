# Sketchup-Progress-Bar
An Escape-able progreess bar

Example of block form:

 ```ruby
 module SOME_MODULE
  def self.run_example()
    SW::ProgressBar.new(method(:on_complete), method(:on_abort)) do |pbar|
      count = 1000
      count.times {|i|
        sleep(0.005)
        if pbar.update? # has the update time expired
          pbar.label= "Remaining: #{count - i}" # text
          pbar.set_value(i/10) # 0 to 100
          pbar.refresh
        end
      }
    end
  end

  def self.on_complete
    puts 'completed'
  end
 
  def self.on_abort(exception)
    puts 'aborted'
    raise exception
  end

  run_example
end   

Example without a block:

 module SOME_MODULE
   def self.run_example()
     SW::ProgressBar.new(method(:on_complete), method(:on_abort), method(:user_task))
   end

   def self.user_task(pbar)
     for count in 1..10
       pbar.label= "Step: #{count}"
       pbar.set_value(count * 10)
       pbar.refresh
       sleep(0.3)
     end
   end

  def self.on_complete
    puts 'completed'
  end

  def self.on_abort(exception)
     puts 'aborted'
     raise exception
  end
  
  run_example
end
```


