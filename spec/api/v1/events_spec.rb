require 'spec_helper'
require 'spec/utils/mockpoint'

describe 'API v1 acks' do
  include Rack::Test::Methods

  def app
    KuduV1
  end

  let(:id) { 1337 }

  let(:external_uid) { 'post:realm.some.fine.realm$l0ngAndFiNeUId4U' }
  let(:a_score) { Score.create!(:external_uid => external_uid, :kind => 'stream') }
  let(:an_event) do
    Event.create!(:score => a_score, :identity => id, :document => {count: 1})
  end

  let(:checkpoint) {
    Mockpoint.new(self)
  }

  let(:god) {
    DeepStruct.wrap(:identity => {:id => 0, :god => true, :realm => 'realm'})
  }

  let(:alice_profile) do
    {
      :provider => "twitter",
      :nickname => "alice",
      :name => "Alice Cooper",
      :profile_url => "http://twitter.com/RealAliceCooper",
      :image_url => "https://si0.twimg.com/profile_images/1281973459/twitter_profile.jpg",
      :description => "The ONLY Official Alice Cooper Twitter!"
    }
  end
  let(:alice) {
    DeepStruct.wrap(:identity => {:id => id, :god => false, :realm => 'safariman'},
      :profile => alice_profile)
  }

  let(:vincent) {
    DeepStruct.wrap(:identity => {:id => id + 1, :god => false, :realm => 'safariman'})
  }

  before :each do
    Pebblebed::Connector.any_instance.stub(:checkpoint).and_return checkpoint
  end

  describe 'GET /events/:uid' do

    it 'returns an event' do
      an_event
      get "/events/#{an_event.uid}"
      last_response.status.should eq 200
      response = JSON.parse(last_response.body)
      response['event']['id'].should eq an_event.id
      response['event']['kind'].should eq an_event.score.kind
      response['event']['uid'].should eq an_event.uid
    end

    it 'returns 404 if not found' do
      get "/events/post:realm.some.non.existing.post$1"
      last_response.status.should eq 404
    end

  end

  describe 'GET /events/:external_uid/:kind' do
    it 'returns all events of :kind for :external_uid' do
      Event.create!({
        :score => Score.create!(:external_uid => external_uid, :kind => 'somethingElse'),
        :identity => id,
        :document => {count: 1}
      })

      e1 = Event.create!(:score => a_score, :identity => id, :document => {count: 1})
      e2 = Event.create!(:score => a_score, :identity => id, :document => {count: 1})

      get "/events/#{e1.score.external_uid}/#{e1.score.kind}"
      last_response.status.should eq 200
      response = JSON.parse(last_response.body)
      events = response['events']
      events.size.should eq(2)

      event = events[0]['event']

      event['id'].should eq e1.id
      event['kind'].should eq 'stream'
      event['uid'].should eq e1.uid

      event = events[1]['event']
      event['id'].should eq e2.id
      event['kind'].should eq 'stream'
      event['uid'].should eq e2.uid

      document = event['document']
      document.class.should eq Hash
      document['count'].should eq 1
    end
  end

  describe 'POST /events/:uid/:kind' do
    let(:identity) { alice }
    let(:callback_response) { {'allowed' => 'default' } }
    let(:a_session) { {:session => "1234"} }

    it 'creates an event and a score' do
      post "/events/#{external_uid}/applause", a_session.merge(:document => {:timeOffset => 29})
      last_response.status.should eq 201
      response = JSON.parse(last_response.body)["event"]
      event = Event.find_by_id(response['id'])
      event.document['timeOffset'].should eq('29')
      event.ip.should eq('127.0.0.1')
      Score.find_by_external_uid(external_uid).total_count.should eq(1)
    end

    it "stores a copy of the identity's checkpoint profile" do
      post "/events/#{external_uid}/applause", a_session.merge(:document => {:timeOffset => 29})
      last_response.status.should eq 201
      response = JSON.parse(last_response.body)["event"]
      event = Event.find_by_id(response['id'])
      event.created_by_profile.should eq(alice.profile.unwrap)
      Score.find_by_external_uid(external_uid).total_count.should eq(1)
    end

    context 'when called by user with no profile' do
      let(:identity) { vincent }
      it "stores nothing as profile" do
        post "/events/#{external_uid}/applause", a_session.merge(:document => {:timeOffset => 29})
        last_response.status.should eq 201
        response = JSON.parse(last_response.body)["event"]
        event = Event.find_by_id(response['id'])
        event.created_by_profile.should eq(nil)
        Score.find_by_external_uid(external_uid).total_count.should eq(1)
      end
    end
  end
end

