class BusstopDetail < ActiveRecord::Base
  acts_as_mappable default_units: :kms, lng_column_name: :long
  belongs_to :busstop, primary_key: 'busstop_id', foreign_key: 'busstop_id'

  validates :busstop_id, presence: true
  validates :road, presence: true

  # would be better, there are still some without coords, 
  # geocode with help of other API?
  # validates :lat, presence: true
  # validates :long, presence: true

  def self.stops_nearby_to(coord, dist)
    BusstopDetail.within(dist, origin: coord).pluck(:busstop_id)
  end

  def self.details_for(stop_id)
    BusstopDetail.where(busstop_id: stop_id).first
  end

  def self.without_coords
    BusstopDetail.where('lat IS NULL or long IS NULL')
  end

  def self.delete_without_coords
    ids = without_coords.pluck(:busstop_id)
    n = Busstop.where(busstop_id: ids).delete_all
    Rails.logger.info "Deleted #{n} busstops without busstop_details"

    n = without_coords.delete_all
    Rails.logger.info "Deleted #{n} busstops_details without coordinates."
  end
end
