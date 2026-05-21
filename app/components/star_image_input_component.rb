# frozen_string_literal: true

class StarImageInputComponent < ViewComponent::Base
  VARIANTS = (1..5).to_a.freeze

  IDLE_PRIMARY = "Drag an image"
  IDLE_SECONDARY = "or click to choose a file"

  attr_reader :variant, :name, :id, :accept, :primary_text, :secondary_text

  def initialize(variant: 1, name: nil, id: nil, accept: "image/*",
                 primary_text: IDLE_PRIMARY, secondary_text: IDLE_SECONDARY)
    v = variant.to_i
    raise ArgumentError, "variant must be one of #{VARIANTS.inspect}, got #{variant.inspect}" unless VARIANTS.include?(v)

    @variant = v
    @name = name
    @id = id
    @accept = accept
    @primary_text = primary_text
    @secondary_text = secondary_text
  end

  def frame_classes
    "star-image-input__frame star-border star-border--variant-#{variant}"
  end
end
