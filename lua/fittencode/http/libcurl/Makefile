.PHONY: hash clean

BUILD_DIR := build
TARGET := hash.so

hash: clean
	cmake -B $(BUILD_DIR) && $(MAKE) -C $(BUILD_DIR)
	cp $(BUILD_DIR)/$(TARGET) .

clean:
	rm -rf $(BUILD_DIR)
