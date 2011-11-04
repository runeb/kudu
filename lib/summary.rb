class Summary < ActiveRecord::Base

  has_many :acks

  scope :highscoring, lambda {|limit| order("count desc").limit(limit)}
  scope :in_collection, lambda {|collection| where(:collection => collection)}

  CONTRO_LIMIT = 4.freeze

  def self.calculate
    summaries = {}
    Ack.all.each do |ack|
      summary = summaries[ack.external_uid]
      unless summary
        summary = summaries[ack.external_uid] = Summary.new(:external_uid => ack.external_uid)
      end
      summary.apply_score! ack.score
    end
    summaries.each_pair do |external_uid, summary|
      $redis.set external_uid, summary.to_json
    end
  end

  def apply_score!(score)
    self.total_ack_count += 1
    if score > 0
      self.positive_ack_count += 1
    elsif score < 0
      self.negative_ack_count += 1
    else
      self.neutral_ack_count += 1
    end
    self.positive_score += score if score > 0
    self.negative_score -= score if score < 0
    self.controversiality = self.calculate_controversiality
    self.save
  end

  def rollback_score!(score)
    self.total_ack_count -= 1
    if score > 0
      self.positive_ack_count -= 1
    elsif score < 0
      self.negative_ack_count -= 1
    else
      self.neutral_ack_count -= 1
    end
    self.positive_score -= score if score > 0
    self.negative_score += score if score < 0
    self.controversiality = self.calculate_controversiality
    self.save
  end

  def calculate_controversiality
    contro = nil
    if self.positive_ack_count + self.negative_ack_count > Summary::CONTRO_LIMIT
      values = [self.positive_ack_count.to_f, self.negative_ack_count.to_f]
      contro = values.min / values.max
    end
    contro
  end

end
