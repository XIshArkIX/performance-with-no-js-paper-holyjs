#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cstring>
#include <iostream>

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
    return 1;
  }

  // Enable TCP Fast Open
  if (setsockopt(server_fd, IPPROTO_TCP, TCP_FASTOPEN, &opt, sizeof(opt)) ==
      -1) {
    std::cerr << "Failed to set TCP_FASTOPEN\n";
    return 1;
  }

  struct sockaddr_in address;
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = INADDR_ANY;
  address.sin_port = htons(8080);

  if (bind(server_fd, (struct sockaddr*)&address, sizeof(address)) == -1) {
    std::cerr << "Failed to bind\n";
    return 1;
  }

  if (listen(server_fd, 3) == -1) {
    std::cerr << "Failed to listen\n";
    return 1;
  }

  std::cout << "Server listening on port 8080\n";

  while (true) {
    struct sockaddr_in client_addr;
    socklen_t client_len = sizeof(client_addr);
    int client_fd =
        accept(server_fd, (struct sockaddr*)&client_addr, &client_len);
    if (client_fd == -1) {
      std::cerr << "Failed to accept connection\n";
      continue;
    }

    char buffer[1024];
    ssize_t bytes_received = recv(client_fd, buffer, sizeof(buffer), 0);
    if (bytes_received > 0) {
      std::cout << "Received " << bytes_received
                << " bytes in TCP Fast Open option\n";
      // Measure and log bytes_received as needed
    }

    close(client_fd);
  }

  close(server_fd);
  return 0;
}
