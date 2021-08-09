# Subclassing the ProgressBar class

module SW
  class ProgressBarWebDialog < SW::ProgressBar
    def initialize(*args)
      super
      @enable_redraw = false
      @dlg = show_dialog()
    end
    
    def deactivate(view)
      super
      # puts 'dialog deactivate'
      @dlg.close
    end
    
    def set_value(value)
      @value = value/100
      sES = "'#{@label}', #{value}"
      @dlg.execute_script("setValues(#{sES});")
    end
    
    undef_method :onLButtonDown
    undef_method :onLButtonUp
    undef_method :onMouseMove
    
    def show_dialog()
    
      # dlg = UI::HtmlDialog.new(
        # {
        # :dialog_title => "Dialog Example",
        # :preferences_key => "com.sample.plugin",
        # :scrollable => true,
        # :resizable => true,
        # :width => 600,
        # :height => 400,
        # :left => 100,
        # :top => 100,
        # :min_width => 50,
        # :min_height => 50,
        # :max_width =>1000,
        # :max_height => 1000,
        # :style => UI::HtmlDialog::STYLE_UTILITY
        # }
      # )
      
      # dlg.set_can_close() {
        # @user_esc = true
        # @cancel_reason = 'User Cancel- Dialog'
        # true
      # }
      
   
      dlg = UI::WebDialog.new("WebDialog Example", false, "SW WebDialogExample", 0, 0, 0, 0, false)
     
      dlg.set_on_close{ 
        @user_esc = true
        @cancel_reason = 'User Cancel- Dialog'
        true
      }

      dlg.add_action_callback("setSize") { |dlg,ret|
        a = ret.split(/,/).collect! { |i| i.to_i }
        dlg.set_size(a[0], a[1])
      }

      dlg.add_action_callback("close") { |dlg,ret| 
        # puts 'close'
        dlg.close
        @user_esc = true
        @cancel_reason = 'User Cancel- Dialog'
      }
      
      dlg.add_action_callback("log") { |dlg,ret| 
        puts ret
      }
     
      html = getHTML()
      bg = dlg.get_default_dialog_color ## webdialog only
      html.sub!(/#F0F0F0/i, bg)  ## webdialog only
      dlg.set_html(getHTML)
      dlg.show

      dlg
    end
      
    #adapted from MSP-Greg's progressbar.rb
    def getHTML()
          css = <<-'00HERE!!'
          <html><meta http-equiv="X-UA-Compatible" content="IE=edge"/><head><title>Progress Bar Sample</title>
          <style type="text/css">
          html {overflow:hidden; border:0px none; margin:0px; padding:0px;}
          body {margin:0px; overflow:hidden; border:0px none; padding:0.5em; background-color:#f0f0f0;
                font-family:Arial, Helvetica, sans-serif; font-size:14px; align:center;
                width:25.0em; height: 10.5em; position:fixed; left:0px; top:0px;}
          button, div, fieldset, input, label {font-size:1.0em;}
          em	{text-decoration:underline; font-style:normal;}
          br	{line-height:1.4em;}

          #dDesc    {font-size:1.50em; margin-top:0.3em; text-align:center;}
          #dProgBar {height:0.75em; margin-top:0.5em; margin-bottom:0.5em; width:0.0%; background-color:#8080d0;
                     box-sizing:border-box; display:inline-block;}

          #dLwr {position:absolute; bottom:0.0em; width:100%;
                 padding:0em 0.5em 0.5em 0.5em; text-align:center;}

          button {width:7.0em; height:2.0em; font-size:1.25em; margin:auto; margin-bottom:0.3em;}

          #inCancel {display:none;}
          </style>
              00HERE!!

              script = <<-'00HERE!!'
          <script type="text/javascript">
          'use strict';
          var	sProgBar, oDesc,
              hasTextContent = ('textContent' in document),
              bAddEventListener = (typeof(window.addEventListener) === typeof(Function)),
              $ =  function(x) { return document.getElementById(x); },
              $$ = function(x) { return document.getElementById(x).style; },
              $SetTextVar, $SetTextId,
              inSU = true;

          if (hasTextContent) {
            $SetTextVar = function(el, text) { el.textContent = text; };
            $SetTextId =  function(id, text) { document.getElementById(id).textContent = text; };
          } else {
            $SetTextVar = function(el, text) { el.innerText = text; };
            $SetTextId =  function(id, text) { document.getElementById(id).innerText = text; };
          };

          function setVariables() {
            sProgBar = $$("dProgBar");
                oDesc = $("dDesc");
          };

          function setValues(sDesc, iProgBar) {
            $SetTextVar(oDesc, sDesc);
            sProgBar.width = iProgBar + "%";
          };

          function clkBtn(e) {
            talk('close');
          };

          function getSize() {
            var height = document.body.offsetHeight + window.outerHeight - window.innerHeight,
                width =  document.body.offsetWidth + window.outerWidth - window.innerWidth;
            talk('setSize@' + width + ',' + height);
          };

          function talk(sSend) {
            // NOTE - don't use 'setTimeout' in window.unload event!
            if (inSU)
              setTimeout(function() {window.location = 'skp:' + sSend;}, 1);
            else
              console.log(sSend);
          };

          function kuDoc(e) {
            var evt = e || event,
                tgt = evt.target || evt.srcElement,
                key = evt.keyCode,
                bEvtCancel = false,
                actElmt = document.activeElement;
            if (key == 27) {
                talk('close');
            };
          };

          function winLoad() {
            setVariables();
            if (window.addEventListener) {
              $("bCancel").addEventListener('click',   clkBtn, false);
                  document.addEventListener('keyup', kuDoc,	 false);
            } else {
              $("bCancel").attachEvent('onclick',  clkBtn);
                  document.attachEvent('onkeyup', kuDoc);
            };
            talk( getSize() );
          };

          if (bAddEventListener) {
            if ('DOMContentLoaded' in document)
              document.addEventListener('DOMContentLoaded', winLoad, false);
            else
              window.addEventListener('load', winLoad, false);
          } else {
            window.attachEvent('onload', winLoad);
          };

          </script></head>
              00HERE!!

              html = <<-'00HERE!!'
          <body>
          <div id="dDesc"></div>
          <div><div id="dProgBar"></div></div>
          <div id="dLwr"><input id="inCancel" type="text"/><button id="bCancel">Cancel</button></div></body></html>
          00HERE!!

      fullHTML = css + script + html
      fullHTML.sub!(/<title>/, '<title>Progress Bar Sample')
      css = script = html = nil
      return fullHTML
    end
  end
end


