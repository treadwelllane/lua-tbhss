ifndef <% return var("PC_NAME") %>
<% return var("PC_NAME") %> = openblas
endif

results.mk: Makefile
	truncate -s0 results.mk
	echo "LIB_CFLAGS += $(shell pkg-config --cflags $(<% return var("PC_NAME") %>))" >> results.mk
	echo "LIB_LDFLAGS += $(shell pkg-config --libs $(<% return var("PC_NAME") %>))" >> results.mk

