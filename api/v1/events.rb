class KuduV1 < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
    also_reload 'lib/kudu/ack.rb'
  end

  # Get an event

  # @apidoc
  # Get a single event
  #
  # @category Kudu/Events
  # @path /events/:uid
  # @http GET
  # @example /api/kudu/v1/events/ack:acme.myapp.some.doc$1
  # @status 200 JSON
  get '/events/:uid' do |uid|
    id = Pebbles::Uid.oid(uid).to_i
    event = Event.find(id)
    pg :event, :locals => {:event => event}
  end

  get '/events/:external_uid/:kind' do |uid, kind|
    LOGGER.info("#{request.host}: HTTP_X_FORWARDED_FOR: #{request.env['HTTP_X_FORWARDED_FOR']}")

    events = Event.by_uid_and_kind(uid, kind)
    events, pagination = limit_offset_collection(events, :limit => params['limit'], :offset => params['offset'])
    pg :events, :locals => {:events => events, pagination: pagination}
  end

  post '/events/:uid/:kind' do |uid, kind|
    save_event(uid, kind)
  end

  private
  def save_event(uid, kind, options = {})
    require_identity

    document = params[:document]

    halt 500, "Missing document object in post body." if document.nil?
    halt 500, "Invalid document #{document.inspect}." unless document and document.is_a?(Hash)

    score = Score.by_uid_and_kind(uid, kind).first
    score ||= Score.create!(:external_uid => uid, :kind => kind)

    halt 404, "Score with uid \"#{uid}\" of kind \"#{kind}\"not found or not created" unless score

    event = Event.new(:score_id => score.id, :identity => current_identity.id)

    ip = request.env['HTTP_X_FORWARDED_FOR'] || request.ip
    ip = ip.sub("::ffff:", "") # strip away ipv6 compatible formatting
    event.ip = ip.split(/,\s*/).uniq.first  # HTTP_X_FORWARDED_FOR may contain multiple comma separated ips

    response.status = 201
    event.created_by_profile = current_profile.unwrap if current_profile
    event.document = document
    event.save!
    pg :event, :locals => {:event => event}
  end
end
