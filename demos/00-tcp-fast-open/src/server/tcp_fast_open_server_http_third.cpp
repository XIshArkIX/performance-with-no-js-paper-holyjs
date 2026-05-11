#include <arpa/inet.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cstring>
#include <iostream>
#include <optional>
#include <sstream>
#include <string>

namespace {

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

std::string buildEchoResponse(const std::string& request_payload) {
  const std::string method = "POST ";
  if (request_payload.rfind(method, 0) != 0) {
    constexpr auto kMethodNotAllowed =
        "HTTP/1.1 405 Method Not Allowed\r\n"
        "Content-Length: 0\r\n"
        "Connection: close\r\n\r\n";
    return kMethodNotAllowed;
  }

  auto delimiter = request_payload.find("\r\n\r\n");
  std::string body;
  if (delimiter != std::string::npos) {
    body = request_payload.substr(delimiter + 4);
  }

  std::ostringstream response;
  response << "HTTP/1.1 200 OK\r\n"
           << "Content-Type: text/plain; charset=UTF-8\r\n"
           << "Content-Length: " << body.size() << "\r\n"
           << "Connection: close\r\n\r\n"
           << body;
  return response.str();
}

}  // namespace

int main() {
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

  std::cout << "HTTP echo server with TCP Fast Open listening on port 8080\n";

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
    if (bytes_received <= 0) {
      std::cerr << "Failed to receive request\n";
      close(client_fd);
      continue;
    }

    std::string request_payload(recv_buffer,
                                static_cast<size_t>(bytes_received));
    auto response = buildEchoResponse(request_payload);
    if (!sendAll(client_fd, response)) {
      std::cerr << "Failed to send HTTP response\n";
    }

    close(client_fd);
  }

  close(server_fd);
  return 0;
}
