require 'rho'
require 'rho/rhocontroller'
require 'rho/rhoerror'
require 'helpers/browser_helper'
require 'json'

class SettingsController < Rho::RhoController
  include BrowserHelper
  
  def index
    @msg = @params['msg']
    render
  end

  def login
    @msg = @params['msg']
    render :action => :login
  end

  def login_callback
    if @params['http_error']=='200'
      #Es necesario parsear a JSON para que tome bien la respuesta
      body=Rho::JSON.parse(@params['body'])
        
      resp=body['success'].split(' - ')[0]
      if resp =="True"
        WebView.navigate(url_for :action => :login_success)
        #Login Success
      else
        #Login Failed
        WebView.navigate ( url_for :action => :login, :query => {:msg => "Wrong user or password"} )
      end
    else
      #Error de otro tipo
      errCode = @params['error_code'].to_i
      msg = Rho::RhoError.new(errCode).message
      WebView.navigate ( url_for :action => :login, :query => {:msg => msg} )
    end
  end

  def login_success
    @user_name = @@username
  end
  
  def do_login
    if @params['login'] and @params['password']
    @@username = @params['login']  
      
        url = "http://www.liveandes.org/wcf/UserServiceRest.svc/json/ValidateUser"
        headers = {"Accept" =>"application/json","Host" =>"liveandesor.web711.discountasp.net","Content-type"=>"application/json; charset=utf-8"}
        body = {:user  => @params['login'],
          :password => encriptPassword(@params['password']), 
          :email => ""}
        # body to json
        body = ::JSON.generate(body)
        Rho::AsyncHttp.post(:url => url, :headers => headers, 
          :body=>body, :callback=>(url_for :action => :login_callback))
        #@response['headers']['Wait-Page'] = 'true'
        #render :action => :wait
      
    else
      @msg = Rho::RhoError.err_message(Rho::RhoError::ERR_UNATHORIZED) unless @msg && @msg.length > 0
      render :action => :login
    end
  end
  
  def encriptPassword(password)
    password = password.split(//)
    r = Random.new
    passwordCifrado = ""
    
    i = 0
    password.each do |char|
        newChar = char.unpack('C')[0] # Convierto a int 
        newChar = (159 - newChar).chr # Sumo y vuelvo a char
    
        if i%2 == 0
            # Agregamos ruido
            charRuido = r.rand(65..90).chr
            passwordCifrado = charRuido + passwordCifrado
        end
    
        # Agregamos el char real
        passwordCifrado = newChar + passwordCifrado
        
        i = i + 1
    end

    return passwordCifrado
  end
  
  def logout
    SyncEngine.logout
    @msg = "You have been logged out."
    render :action => :login
  end
  
  def reset
    render :action => :reset
  end
  
  def do_reset
    Rhom::Rhom.database_full_reset
    SyncEngine.dosync
    @msg = "Database has been reset."
    redirect :action => :index, :query => {:msg => @msg}
  end
  
  def do_sync
    SyncEngine.dosync
    @msg =  "Sync has been triggered."
    redirect :action => :index, :query => {:msg => @msg}
  end
  
  def sync_notify
    status = @params['status'] ? @params['status'] : ""
    
    # un-comment to show a debug status pop-up
    #Alert.show_status( "Status", "#{@params['source_name']} : #{status}", Rho::RhoMessages.get_message('hide'))
    
    if status == "in_progress"  
      # do nothing
    elsif status == "complete"
      WebView.navigate Rho::RhoConfig.start_path if @params['sync_type'] != 'bulk'
    elsif status == "error"
  
      if @params['server_errors'] && @params['server_errors']['create-error']
        SyncEngine.on_sync_create_error( 
          @params['source_name'], @params['server_errors']['create-error'].keys, :delete )
      end

      if @params['server_errors'] && @params['server_errors']['update-error']
        SyncEngine.on_sync_update_error(
          @params['source_name'], @params['server_errors']['update-error'], :retry )
      end
      
      err_code = @params['error_code'].to_i
      rho_error = Rho::RhoError.new(err_code)
      
      @msg = @params['error_message'] if err_code == Rho::RhoError::ERR_CUSTOMSYNCSERVER
      @msg = rho_error.message unless @msg && @msg.length > 0   

      if rho_error.unknown_client?( @params['error_message'] )
        Rhom::Rhom.database_client_reset
        SyncEngine.dosync
      elsif err_code == Rho::RhoError::ERR_UNATHORIZED
        WebView.navigate( 
          url_for :action => :login, 
          :query => {:msg => "Server credentials are expired"} )                
      elsif err_code != Rho::RhoError::ERR_CUSTOMSYNCSERVER
        WebView.navigate( url_for :action => :err_sync, :query => { :msg => @msg } )
      end    
  end
  end  
end
