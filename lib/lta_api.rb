require 'rest-client'
require 'json'

class LtaApi
  User_id = ENV['DATAMALL_USER_ID']
  Account_key = ENV['DATAMALL_ACCOUNT_KEY']
  Base_url = "http://datamall.mytransport.sg/ltaodataservice.svc/"
  Busstop_geoinfo_path = 'data/BusStop_Oct2015/busstops.json'

  def get_data_for(service) 
    geoinfo = ''
    if service.include?('BusStop')
      geoinfo = JSON.parse(File.read(Busstop_geoinfo_path))
    end

    url = Base_url + service + 'Set'
    offset = 0

    loop do
      response = RestClient.get url, params: { '$skip' => offset }, accept: :json, AccountKey: Account_key, UniqueUserID: User_id
      if response.code != 200
        Rails.logger.warn "URL: #{url} and params: #{params} returned with code: #{response.code}"
      end

      elements = JSON.parse response
      _save_elements(elements['d'], service, geoinfo)
      

      offset += 50
      break if elements['d'].size != 50
    end

  end

  def _save_elements(elements, service, geoinfo)  
    elements.each do |from|
      to = _map_elements(from, service, geoinfo)
      _save_element(to)
    end
  end

  def _save_element(e)
    if e.valid?
      e.save
    else
      Rails.logger.warn "Invalid #{e.class} object #{e.inspect}"
    end
  end

  def _map_elements(from, service, geoinfo)
    if service.include?('Info')
      to = _map_busline(from, service)
    elsif service.include?('BusStop')
      to = _map_busstop_details(from, service, geoinfo)
    else
      to = _map_busstop(from, service)
    end
  end

  def _map_busstop_details(b, service, geoinfo)
      bs = BusstopDetail.where(id: b[service + 'ID'].to_i).first_or_create
      bs['busstop_id'] = b['Code'].to_i
      bs['road'] = b['Road']
      bs['desc'] = b['Description']

      i = geoinfo['features'].index{ |x| x['properties']['BUS_STOP_N'] == b['Code'] }
      if !i.nil?
        bs['long'] = geoinfo['features'][i]['geometry']['coordinates'][0]
        bs['lat'] = geoinfo['features'][i]['geometry']['coordinates'][1]
      end

      bs
  end

  def _map_busline(b, service)
      bl = Busline.where(id: b[service + 'ID'].to_i).first_or_create
      bl['busnumber']    = b['SI_SVC_NUM']
      bl['direction']    = b['SI_SVC_DIR'].to_i
      bl['type_of_bus']  = b['SI_SVC_CAT']
      bl['start_code']   = b['SI_BS_CODE_ST'].to_i
      bl['end_code']     = b['SI_BS_CODE_END'].to_i
      bl['loop_code']    = b['SI_LOOP'].to_i
      bl['freq_am_peak'] = _sanitize_bus_freq(b['SI_FREQ_AM_PK'])
      bl['freq_am_off']  = _sanitize_bus_freq(b['SI_FREQ_AM_OF'])
      bl['freq_pm_peak'] = _sanitize_bus_freq(b['SI_FREQ_PM_PK'])
      bl['freq_pm_off']  = _sanitize_bus_freq(b['SI_FREQ_PM_OF'])
      bl
  end

  def _sanitize_bus_freq(s)
    s.nil? ? '-' : s.strip
  end

  def _map_busstop(b, service)
      bs = Busstop.where(id: b[service + 'ID'].to_i).first_or_create
      bs['busnumber']   = !b['SI_SVC_NUM'].to_s.empty? ? b['SI_SVC_NUM'] : b['SR_SVC_NUM']
      bs['direction']   = !b['SI_SVC_DIR'].to_s.empty? ? b['SI_SVC_DIR'].to_i : b['SR_SVC_DIR'].to_i
      bs['stop_number'] = b['SR_ROUT_SEQ'].to_i
      bs['busstop_id']  = b['SR_BS_CODE'].to_i
      bs
  end
end
