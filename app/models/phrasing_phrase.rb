class PhrasingPhrase < ActiveRecord::Base

  validates_presence_of :key, :locale

  validate :uniqueness_of_key_on_locale_scope, on: :create

  has_many :versions, dependent: :destroy, class_name: "PhrasingPhraseVersion"

  after_update :version_it

  def self.search_i18n_and_create_phrase key
    begin
      value = I18n.t key, raise: true
      PhrasingPhrase.where(key: key, locale: I18n.locale).first
    rescue I18n::MissingTranslationData
      create_phrase(key)
    end
  end

  def self.create_phrase key, value = nil
      phrasing_phrase = PhrasingPhrase.new
      phrasing_phrase.locale = I18n.locale.to_s
      phrasing_phrase.key = key.to_s
      phrasing_phrase.value = value || key.to_s
      phrasing_phrase.save
      phrasing_phrase
  end

  module Serialize

    def import_yaml(yaml)
      number_of_changes = 0
      hash = YAML.load(yaml)
      hash.each do |locale, data|
        data.each do |key, value|
          phrase = where(key: key, locale: locale).first || new(key: key, locale: locale)
          if phrase.value != value
            phrase.value = value
            number_of_changes += 1
            phrase.save
          end
        end
      end
      number_of_changes
    end

    def export_yaml
      hash = {}
      where("value is not null").each do |phrase|
        hash[phrase.locale] ||= {}
        hash[phrase.locale][phrase.key] = phrase.value
      end
      hash.to_yaml
    end

  end

  extend Serialize

  private

    def uniqueness_of_key_on_locale_scope
      errors.add(:key, "Duplicate entry #{key} for locale #{locale}") unless PhrasingPhrase.where(key: key).where(locale: locale).empty?
    end

    def version_it
      PhrasingPhraseVersion.create_version(id, value) if value_was != value
    end
    
end
