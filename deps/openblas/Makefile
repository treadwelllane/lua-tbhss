ifndef <% return var("PC_NAME") %>
<% return var("PC_NAME") %> = openblas
endif

results.mk: Makefile
	truncate -s0 results.mk
	echo "LIB_CFLAGS += $(shell pkg-config --cflags --static $(<% return var("PC_NAME") %>))" >> results.mk
	echo "LIB_LDFLAGS += $(shell pkg-config --libs --static $(<% return var("PC_NAME") %>))" >> results.mk

