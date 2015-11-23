class Event < ActiveRecord::Base
  belongs_to :score

  validates_presence_of :identity

  scope :by_uid_and_kind, lambda { |uid, kind|
    joins(:score).where(:scores => {:external_uid => uid, :kind => kind})
  }

  serialize :document
  serialize :created_by_profile

  after_update  :create_or_update_score, prepend: true
  after_create  :create_or_update_score, prepend: true
  after_destroy :create_or_update_score, prepend: true

  def create_or_update_score
    score.refresh_from_events!
  end

  def uid
    klass = "event"
    klass += ".#{score.kind}" if score.kind
    "#{klass}:#{score.path}$#{id}"
  end

  def attributes_for_export
    template = "api/v1/views/event.pg"
    Petroglyph::Engine.new(File.read(template)).to_hash({:event => self}, template)
  end

end
