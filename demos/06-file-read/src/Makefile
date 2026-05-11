CXX      ?= g++
CXXFLAGS ?= -std=c++17 -Wall -Wextra -O2 -g

.PHONY: all clean

all: trace_demo read_file

# --- The tracer demo (statically links the library object) ---
trace_demo: main.cpp syscall_tracer.o
	$(CXX) $(CXXFLAGS) -o $@ main.cpp syscall_tracer.o

# --- The simple target program to be traced ---
read_file: read_file.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<

# --- Library object ---
syscall_tracer.o: syscall_tracer.cpp syscall_tracer.h
	$(CXX) $(CXXFLAGS) -c -o $@ $<

clean:
	rm -f trace_demo read_file syscall_tracer.o
