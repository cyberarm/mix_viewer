class MixViewer
  class Window < CyberarmEngine::Window
    def setup
      self.caption = "Mix Viewer"
      push_state(States::Interface)
    end
  end
end
