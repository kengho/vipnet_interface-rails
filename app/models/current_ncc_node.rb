class CurrentNccNode < NccNode
  validates :network, presence: true
  validates :vid, presence: true, uniqueness: true
end
