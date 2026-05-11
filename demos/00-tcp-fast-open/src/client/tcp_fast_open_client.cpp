#include <arpa/inet.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cstring>
#include <iostream>

int main() {
  int client_fd = socket(AF_INET, SOCK_STREAM, 0);
  if (client_fd == -1) {
    std::cerr << "Failed to create socket\n";
    return 1;
  }

  int opt = 1;
  if (setsockopt(client_fd, IPPROTO_TCP, TCP_FASTOPEN, &opt, sizeof(opt)) ==
      -1) {
    std::cerr << "Failed to set TCP_FASTOPEN\n";
    return 1;
  }

  struct sockaddr_in server_addr;
  server_addr.sin_family = AF_INET;
  server_addr.sin_addr.s_addr = inet_addr("127.0.0.1");
  server_addr.sin_port = htons(8080);

  if (connect(client_fd, (struct sockaddr*)&server_addr, sizeof(server_addr)) ==
      -1) {
    std::cerr << "Failed to connect\n";
    return 1;
  }

  const char* message = "Hello, TCP Fast Open!";
  ssize_t bytes_sent = send(client_fd, message, strlen(message), 0);
  if (bytes_sent == -1) {
    std::cerr << "Failed to send data\n";
    return 1;
  }

  std::cout << "Sent " << bytes_sent << " bytes using TCP Fast Open\n";

  close(client_fd);
  return 0;
}