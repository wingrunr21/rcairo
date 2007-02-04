#!/usr/bin/env ruby

top = File.expand_path(File.join(File.dirname(__FILE__), ".."))
base = File.join(top, "packages", "cairo")
$LOAD_PATH.unshift File.join(base, "ext")
$LOAD_PATH.unshift File.join(base, "lib")

require 'optparse'
require 'ostruct'

require 'cairo'
require 'pango'

def parse(args=ARGV)
  options = OpenStruct.new
  options.width = 595.275590551181.round
  options.height = 841.889763779528.round
  options.font_description = "Monospace 12"
  options.fade_out = false

  opts = OptionParser.new do |opts|
    opts.on("--width=WIDTH", Integer, "paper width") {|options.width|}
    opts.on("--height=HEIGHT", Integer, "paper height") {|options.height|}
    opts.on("--font-description=DESCRIPTION",
            "font description (e.g. 'Monospace 14')") do |desc|
      options.font_description = desc
    end
    opts.on("--[no-]fade-out",
            "fade-out one-third of page") {|options.fade_out|}
  end

  opts.parse!(args)

  options
end

def render_background(cr)
  cr.set_source_rgba(1.0, 1.0, 1.0)
  cr.paint
end

def make_layout(cr, text, width, font_description)
  layout = cr.create_pango_layout
  layout.text = text
  layout.width = width * Pango::SCALE
  layout.font_description = Pango::FontDescription.new(font_description)
  cr.update_pango_layout(layout)
  layout
end

def setup_fade_out(cr, width)
  fade_out = Cairo::LinearPattern.new(0, 0, width, 0)
  fade_out.add_color_stop_rgba(0, 0, 0, 0, 1)
  fade_out.add_color_stop_rgba(0.66, 0, 0, 0, 1)
  fade_out.add_color_stop_rgba(1, 0, 0, 0, 0)

  cr.set_source(fade_out)
end

def render_layout(cr, layout, margin_left, margin_top, body_height)
  x = margin_left
  y = margin_top
  limit_y = margin_top + body_height

  iter = layout.iter
  prev_baseline = iter.baseline / Pango::SCALE
  begin
    line = iter.line
    ink_rect, logical_rect = iter.line_extents
    y_begin, y_end = iter.line_yrange
    if limit_y < (y + y_end / Pango::SCALE)
      cr.show_page
      y = margin_top - prev_baseline
    end
    baseline = iter.baseline / Pango::SCALE
    cr.move_to(x + logical_rect.x / Pango::SCALE, y + baseline)
    cr.show_pango_layout_line(line)
    prev_baseline = baseline
  end while iter.next_line!
end

def render(options, output, surface_class)
  text = options.text
  width = options.width
  height = options.height
  font_description = options.font_description
  fade_out = options.fade_out

  margin_left = (width * 0.05).ceil
  margin_right = (width * 0.05).ceil
  margin_top = (height * 0.05).ceil
  margin_bottom = (height * 0.05).ceil
  body_width = width - margin_left - margin_right
  body_height = height - margin_top - margin_bottom

  surface = surface_class.new(output, width, height)
  cr = Cairo::Context.new(surface)

  render_background(cr)
  layout = make_layout(cr, text, body_width, font_description)
  if fade_out
    setup_fade_out(cr, body_width)
  else
    cr.set_source_rgba(0, 0, 0, 1)
  end
  render_layout(cr, layout, margin_left, margin_top, body_height)

  cr.show_page

  cr.target.finish
  cr
end

def output(options, surface_class_name, suffix)
  if Cairo.const_defined?(surface_class_name)
    surface_class = Cairo.const_get(surface_class_name)
    render(options, "text2.#{suffix}", surface_class)
  else
    puts("#{surface_class_name} isn't supported.")
  end
end

options = parse
options.text = ARGF.read
output(options, "PSSurface", "ps")
output(options, "PDFSurface", "pdf")
output(options, "SVGSurface", "svg")
