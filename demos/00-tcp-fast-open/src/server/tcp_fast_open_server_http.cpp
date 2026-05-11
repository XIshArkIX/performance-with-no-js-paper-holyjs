#include <arpa/inet.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <unistd.h>

#include <filesystem>
#include <fstream>
#include <iostream>
#include <optional>
#include <sstream>
#include <string>

namespace {

std::optional<std::filesystem::path> locateExamplesHtml(
    const std::filesystem::path& start) {
  std::filesystem::path current = start;
  while (true) {
    auto candidate = current / "public" / "index.html";
    if (std::filesystem::exists(candidate)) {
      return candidate;
    }

    if (!current.has_parent_path() || current == current.parent_path()) {
      break;
    }
    current = current.parent_path();
  }
  return std::nullopt;
}

std::filesystem::path resolveHtmlPath() {
  std::error_code ec;
  std::filesystem::path exe_path =
      std::filesystem::read_symlink("/proc/self/exe", ec);

  if (auto found = locateExamplesHtml(std::filesystem::current_path())) {
    return *found;
  }
  if (!exe_path.empty()) {
    if (auto found = locateExamplesHtml(exe_path.parent_path())) {
      return *found;
    }
  }

  throw std::runtime_error("Failed to locate public/index.html");
}

std::string loadHtmlDocument(const std::filesystem::path& html_path) {
  std::ifstream html_file(html_path, std::ios::binary);
  if (!html_file.is_open()) {
    throw std::runtime_error("Unable to open " + html_path.string());
  }

  std::ostringstream buffer;
  buffer << html_file.rdbuf();
  return buffer.str();
}

bool sendAll(int fd, const std::string& payload) {
  size_t sent_total = 0;
  while (sent_total < payload.size()) {
    ssize_t sent =
        send(fd, payload.data() + sent_total, payload.size() - sent_total, 0);
    if (sent <= 0) {
      return false;
    }
    sent_total += static_cast<size_t>(sent);
  }
  return true;
}

}  // namespace

int main() {
  std::string html_document;
  std::string http_response;

  try {
    auto html_path = resolveHtmlPath();
    html_document = loadHtmlDocument(html_path);

    std::ostringstream response_builder;
    response_builder << "HTTP/1.1 200 OK\r\n"
                     << "Content-Type: text/html; charset=UTF-8\r\n"
                     << "Content-Length: " << html_document.size() << "\r\n"
                     << "Connection: close\r\n\r\n"
                     << html_document;
    http_response = response_builder.str();
  } catch (const std::exception& ex) {
    std::cerr << "Initialization error: " << ex.what() << '\n';
    return 1;
  }

  int server_fd = socket(AF_INET, SOCK_STREAM, 0);
  if (server_fd == -1) {
    std::cerr << "Failed to create socket\n";
    return 1;
  }

  int opt = 1;
  if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt)) ==
      -1) {
    std::cerr << "Failed to set SO_REUSEPORT\n";
    close(server_fd);
    return 1;
  }

  if (setsockopt(server_fd, IPPROTO_TCP, TCP_FASTOPEN, &opt, sizeof(opt)) ==
      -1) {
    std::cerr << "Failed to set TCP_FASTOPEN\n";
    close(server_fd);
    return 1;
  }

  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = INADDR_ANY;
  address.sin_port = htons(8080);

  if (bind(server_fd, reinterpret_cast<sockaddr*>(&address), sizeof(address)) ==
      -1) {
    std::cerr << "Failed to bind\n";
    close(server_fd);
    return 1;
  }

  if (listen(server_fd, 3) == -1) {
    std::cerr << "Failed to listen\n";
    close(server_fd);
    return 1;
  }

  std::cout << "HTTP server with TCP Fast Open listening on port 8080\n";

  while (true) {
    sockaddr_in client_addr{};
    socklen_t client_len = sizeof(client_addr);
    int client_fd = accept(server_fd, reinterpret_cast<sockaddr*>(&client_addr),
                           &client_len);
    if (client_fd == -1) {
      std::cerr << "Failed to accept connection\n";
      continue;
    }

    char recv_buffer[4096];
    ssize_t bytes_received =
        recv(client_fd, recv_buffer, sizeof(recv_buffer), 0);
    if (bytes_received > 0) {
      std::cout << "Received " << bytes_received
                << " bytes from client before responding\n";
    }

    if (!sendAll(client_fd, http_response)) {
      std::cerr << "Failed to send HTTP response\n";
    }

    close(client_fd);
  }

  close(server_fd);
  return 0;
}
