class MixViewer
  class States
    class Interface < CyberarmEngine::GuiState
      ITEM_BUTTON = {
        text_align: :left,
        width: 1.0,
        height: 24,
        text_size: 20,
        padding_bottom: 2,
        padding_top: 2,
        border_thickness: 0,
        margin_top: 0,
        margin_left: 0,
        margin_right: 0,
        background: 0xff_454545,
        hover: {
          background: 0xff_656565,
        },
        active: {
          background: 0xff_353535
        }
      }

      MENU_BUTTON = {
        text_size: 18,
        height: 1.0,
        padding_top: 2,
        padding_bottom: 2,
        border_thickness: 0,
        background: 0xff_454545,
        hover: {
          background: 0xff_656565,
        },
        active: {
          background: 0xff_353535
        }
      }

      def setup
        background 0xff_eeeeee
        self.show_cursor = true
        @reader = nil

        @menu_bar = flow(width: 1.0, height: 24) do
          background 0xff_252525

          button "File", **MENU_BUTTON do
          end
        end

        @container = flow(width: 1.0, height: 0.9, padding: 8) do
          @navigation = stack(width: 0.25, height: 1.0, margin_right: 8, scroll: true) do
            background 0xff_525252
          end

          @content = stack(width: 0.749, height: 1.0, scroll: true) do
            background 0xff_525252

            tagline "PREVIEW"
          end
        end

        populate_navigation(path: ARGV[0] || Dir.pwd)
      end

      def update
        super

        container_height = window.height - @menu_bar.style.height
        percentage = container_height.to_f / window.height

        if @container.height != container_height
          @container.style.height = percentage
          @container.recalculate
        end
      end

      def button_down(id)
        super

        if @reader && id == Gosu::KB_E && (Gosu.button_down?(Gosu::KB_LEFT_CONTROL) || Gosu.button_down?(Gosu::KB_RIGHT_CONTROL))
          puts "EXTRACTING..."
          @reader.package.files.each do |file|
            puts "  WRITE: #{file.name}"
            temp_path = "data/#{file.name.gsub("\\", "_")}"
            File.binwrite(temp_path, File.binread(@path, file.content_length, file.content_offset))
          end
        end
      end

      def populate_navigation(path:)
        @path = path

        @navigation.clear do
          if path.is_a?(String) && File.exists?(path) && File.directory?(path)
            @reader = nil
            @path = path

            GC.start
            entries = Dir.entries(path)

            files = entries.select { |e| !File.directory?("#{path}/#{e}") }.sort_by { |f| f.downcase }
            folders = entries.select { |e| File.directory?("#{path}/#{e}") }.sort_by { |f| f.downcase }

            entries = (folders + files).flatten

            entries.each do |ptr|
              button ptr, tip: ptr, **ITEM_BUTTON do |btn|
                entry_path = "#{path}/#{ptr}"

                if File.directory?(entry_path)
                  populate_navigation(path: entry_path)
                else
                  populate_content(file: entry_path)
                end
              end
            end
            puts "LOADING #{path} DIRECTORY"
          else
            puts "LOADING #{path} MIXER..."
            @reader = Mixer::Reader.new(file_path: path, metadata_only: true)
            @path = path

            ([Mixer::Package::File.new(name: "."), Mixer::Package::File.new(name: "..")] + @reader.package.files.sort_by { |f| f.name.downcase }).flatten.each do |file|
              button file.name, tip: file.name, **ITEM_BUTTON do |btn|

                if file.name == "." || file.name == '..'
                  populate_navigation(path: "#{File.dirname(path)}/#{file.name}")
                else
                  begin
                    temp_path = "data/#{file.name.gsub("\\", "_")}"
                    File.write(temp_path, File.read(path, file.content_length, file.content_offset))
                    populate_content(file: temp_path)
                  ensure
                    # File.delete(temp_path) if File.exists?(temp_path)
                  end
                end
              end
            end
          end

          @navigation.scroll_top = 0
        end
      end

      def populate_content(file:)
        if file.is_a?(String) && File.exist?(file)
          @sample&.stop

          @content.clear do
            p File.extname(file)
            case File.extname(file).downcase
            when ".png", ".jpeg", ".jpg", ".gif", ".tiff"
              image file, width: 1.0
            when ".svg"
              svg = RSVG::Handle.new_from_file(file)
              surface = Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, svg.width, svg.height)
              cr = Cairo::Context.new(surface)
              cr.render_rsvg_handle(svg)
              surface.write_to_png("data/#{File.basename(file)}")

              image "data/#{File.basename(file)}", height: 1.0

            when ".dds"
              dds = DDS.new(file: file, shallow: true)
              img = dds.images.first
              it = Gosu.milliseconds
              image Gosu::Image.from_blob(img.width, img.height, img.data), height: 1.0
              puts "Image set after: #{Gosu.milliseconds - it}ms"

            when ".wav", ".mp3", ".ogg"
              @sample = Gosu::Sample.new(file).play
              para File.basename(file)
              button("Stop") { @sample.stop }

            when ".mix", ".dat"
              populate_navigation(path: file)

            else
              initial_bytes = File.read(file, 1024)
              is_text = initial_bytes.length.zero? ? 1.0 : initial_bytes.bytes.select { |c| c >= 31 && c <= 126 }.count / initial_bytes.length.to_f

              if is_text > 0.65
                para File.read(file)
              else
                para "\"#{File.basename(file)}\" appears to be binary, cannot open."
              end
            end
          end

          @content.scroll_top = 0
        end
      end
    end
  end
end
