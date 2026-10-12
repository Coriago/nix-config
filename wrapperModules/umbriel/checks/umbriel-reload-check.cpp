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
  // Model constructFiles -> liveConfig.link -> checkout file, including the
  // atomic saves used by editors. Both links remain unchanged during edits.
  const fs::path checkout = fs::current_path() / "checkout/configExtras.toml";
  fs::create_directories(checkout.parent_path());
  std::ofstream(checkout) << "initial";
  const fs::path liveLink = fs::current_path() / "live-config.toml";
  const fs::path extra = config.parent_path() / "configExtras.toml";
  fs::create_symlink(checkout, liveLink);
  fs::create_symlink(liveLink, extra);
  std::string observed;
  for (const auto &watched : {config, extra}) {
    umbriel::ConfigWatcher watcher(loop, [&] {
      std::ifstream input(watched);
      std::getline(input, observed);
    });
    watcher.watch({watched});
    const auto target = fs::canonical(watched);
    // Repeated replacements must remain observable after the inode changes.
    for (const auto *value : {"scrolling", "master", "scrolling"}) {
      observed.clear();
      auto temporary = target;
      temporary += ".tmp";
      std::ofstream(temporary) << value;
      fs::rename(temporary, target);
      const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(3);
      while (observed != value && std::chrono::steady_clock::now() < deadline)
        wl_event_loop_dispatch(loop, 50);
      assert(observed == value);
    }
  }
  wl_event_loop_destroy(loop);
}
