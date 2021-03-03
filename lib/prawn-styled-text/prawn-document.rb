# frozen_string_literal: true

require 'prawn'

Prawn::Document.class_eval do
  def styled_text(data, init_text_options = {}, init_extra_options = { margin_left: 0 })
    parts = []
    text_options = init_text_options.dup
    extra_options = init_extra_options.dup
    oga = Oga.parse_html data
    PrawnStyledText::traverse oga.children do |type, text, data|
      context =
        if type == :text_node
          PrawnStyledText::text_node(self, data)
        elsif type == :opening_tag
          PrawnStyledText::opening_tag(self, data)
        else
          PrawnStyledText::closing_tag(self, data)
        end
      if context[:flush] && parts.any? # flush current parts
        parts[0][:text] = parts[0][:text].lstrip
        parts.shift if parts[0][:text].empty?
        if parts.any?
          parts[-1][:text] = parts[-1][:text].rstrip
          parts.pop if parts[-1][:text].empty?
        end
        if parts.any?
          parts[0][:text] = extra_options[:pre] + parts[0][:text] if extra_options[:pre]
          indent(extra_options[:margin_left]) do
            formatted_text(parts, text_options)
          end
        end
        parts = []
        text_options = init_text_options.dup
        extra_options = init_extra_options.dup
      end
      options = context[:options]
      if type == :text_node
        text_options[:align] = options[:'text-align'].to_sym if options[:'text-align']
        margin_top = options.delete(:'margin-top').to_i
        move_down(margin_top) if margin_top.positive?
        margin_left = options.delete(:'margin-left').to_i
        extra_options[:margin_left] = margin_left if margin_left.positive?
        if !text_options[:leading] && (leading = options.delete(:'line-height').to_i).positive?
          text_options[:leading] = leading
        end
        text_options[:mode] = options[:mode].to_sym if options[:mode]
        extra_options[:pre] = context[:pre] if context[:pre]
        parts << { text: text }.merge(options) # push the data
      elsif type == :closing_tag
        formatted_text(context[:text]) if context[:text]
        if context[:tag] == :hr
          dash(options[:dash].include?(',') ? options[:dash].split(',').map(&:to_i) : options[:dash].to_i) if options[:dash]
          if options[:color]
            last_stroke_color = stroke_color
            stroke_color(options[:color])
          end
          stroke_horizontal_rule
          stroke_color(last_stroke_color) if options[:color]
          undash if options[:dash]
        elsif context[:tag] == :img && context[:src]
          image_options = {}
          image_options[:scale] = options[:'image-scale'].to_f if options[:'image-scale']
          if options[:'image-at']
            xy = options[:'image-at'].split(',').map &:to_i
            image_options[:at] = xy if xy.count == 2
          end
          if options[:'image-position']
            pos = options[:'image-position'].to_i
            image_options[:position] = pos.positive? ? pos : options[:'image-position']
          end
          image_options[:width]  = options[:width]  if options[:width]
          image_options[:height] = options[:height] if options[:height]
          image context[:src], image_options
        end
      end
    end
    formatted_text_box(parts, text_options)
  end
end
