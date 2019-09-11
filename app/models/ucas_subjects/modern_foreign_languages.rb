# Does the subject list mention languages but hasn't already been covered?
# TODO: this should be replaced with an explicit static mapping
module UCASSubjects
  class ModernForeignLanguages
    LANGUAGE_CATEGORIES = ["languages", "languages (african)", "languages (asian)", "languages (european)"].freeze
    MAIN_MODERN_FOREIGN_LANGUAGES = [
      "english as a second or other language",
      "french",
      "german",
      "italian",
      "japanese",
      "russian",
      "spanish",
    ].freeze
    MANDARIN_UCAS_SUBJECTS = %w[chinese mandarin].freeze

    def self.language_course?(ucas_subjects)
      (ucas_subjects & LANGUAGE_CATEGORIES).any?
    end

    def self.mandarin?(ucas_subjects)
      (ucas_subjects & MANDARIN_UCAS_SUBJECTS).any?
    end

    def self.main_mfl?(ucas_subjects)
      (ucas_subjects & MAIN_MODERN_FOREIGN_LANGUAGES).any?
    end
  end
end