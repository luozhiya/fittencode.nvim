.PHONY: curlua
curlua:
	cd cc && cmake -B build && make -C build
	cp cc/build/curlua/libcurlua.so ./api/libcurlua.so
	cp cc/build/gencpath/gencpath ./api/gencpath
	cd api && ./gencpath
