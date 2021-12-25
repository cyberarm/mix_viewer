begin
  require_relative "../cyberarm_engine/lib/cyberarm_engine"
rescue LoadError
  require "cyberarm_engine"
end

require "rsvg2"

require_relative "lib/window"
require_relative "lib/mixer"
require_relative "lib/dds"
require_relative "lib/states/interface"

MixViewer::Window.new(resizable: true).show
