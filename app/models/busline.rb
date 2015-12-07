class Busline < ActiveRecord::Base
  has_many :busstops, foreign_key: 'busnumber', primary_key: 'busnumber'

  validates :busnumber, presence: true
  validates :start_code, presence: true
  validates :end_code, presence: true

  def coords
    line_coords = []
    busstops.pluck(:busstop_detail).each do |stop|
      unless stop.nil?
        if stop.long.nil? || stop.lat.nil?
          # log error: no coords
        else
          line_coords += [[stop.long, stop.lat]]
        end
      end
    end
    line_coords
  end

  def self.search_by_busnumber(number)
    Busline.where(busnumber: number).first
  end

  def self.search_by_attribute(attribute)
    if attribute.eql? 'night'
      Busline.where("freq_am_peak == '-' and freq_am_off == '-' and freq_pm_peak == '-' and freq_pm_off != '-'")
    end
  end

  def self.search_by_area(params)
    dist = params[:dist] ||= 100
    dist_in_km = dist.to_f / 1000
    if params.key?('lat') && params.key?('long')
      lat = params[:lat]
      long = params[:long]
    elsif params.key?('zipcode')
      loc = Geokit::Geocoders::GoogleGeocoder.geocode params[:zipcode] + 'Singapore'
      lat = loc.lat
      long = loc.lng
    elsif params.key?('busstation')
      stop = BusstopDetail.where(busstop_id: params[:busstation]).first
      lat = stop[:lat]
      long = stop[:long]
    end

    stops = BusstopDetail.within(dist_in_km, origin: [lat, long]).pluck(:busstop_id)
    Busstop.where(busstop_id: stops).pluck(:busnumber).uniq
  end
end
