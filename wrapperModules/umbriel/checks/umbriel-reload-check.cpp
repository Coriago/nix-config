#include "config/config_watcher.h"
#include <cassert>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <string>
#include <wayland-server-core.h>

int main() {
  namespace fs = std::filesystem;
  const fs::path config = fs::current_path() / "etc/umbriel/config.toml";
  fs::create_directories(config.parent_path());
  std::ofstream(config) << "initial";
  auto *loop = wl_event_loop_create();
  assert(loop);
  std::string observed;
  {
    umbriel::ConfigWatcher watcher(loop, [&] {
      std::ifstream input(config);
      std::getline(input, observed);
    });
    watcher.watch({config});
    // Repeated replacements must remain observable after the inode changes.
    for (const auto *value : {"scrolling", "master", "scrolling"}) {
      auto temporary = config;
      temporary += ".tmp";
      std::ofstream(temporary) << value;
      fs::rename(temporary, config);
      const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(3);
      while (observed != value && std::chrono::steady_clock::now() < deadline)
        wl_event_loop_dispatch(loop, 50);
      assert(observed == value);
    }
  }
  wl_event_loop_destroy(loop);
}
